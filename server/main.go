package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math"
	"net"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

type message struct {
	Type    string   `json:"type"`
	Role    string   `json:"role,omitempty"`
	ID      string   `json:"id,omitempty"`
	X       float64  `json:"x,omitempty"`
	Z       float64  `json:"z,omitempty"`
	DX      float64  `json:"dx,omitempty"`
	DZ      float64  `json:"dz,omitempty"`
	Tick    uint64   `json:"tick,omitempty"`
	Players []player `json:"players,omitempty"`
	Count   int      `json:"count,omitempty"`
	Text    string   `json:"text,omitempty"`
}

type player struct {
	ID string  `json:"id"`
	X  float64 `json:"x"`
	Z  float64 `json:"z"`
	DX float64 `json:"-"`
	DZ float64 `json:"-"`
}

type peer struct {
	connection net.Conn
	outbound   chan message
	role       string
	id         string
}

type world struct {
	mu      sync.Mutex
	peers   map[*peer]struct{}
	players map[string]*player
	tick    uint64
	nextID  uint64
}

func main() {
	listen := flag.String("listen", ":7777", "game TCP listener")
	health := flag.String("health", ":8081", "health HTTP listener")
	flag.Parse()

	w := &world{peers: make(map[*peer]struct{}), players: make(map[string]*player)}
	listener, err := net.Listen("tcp", *listen)
	if err != nil {
		log.Fatal(err)
	}
	defer listener.Close()

	http.HandleFunc("/health", func(response http.ResponseWriter, request *http.Request) {
		w.mu.Lock()
		count := len(w.players)
		tick := w.tick
		w.mu.Unlock()
		response.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(response).Encode(message{Type: "health", Count: count, Tick: tick})
	})
	go func() {
		if err := http.ListenAndServe(*health, nil); err != nil {
			log.Printf("health server: %v", err)
		}
	}()
	go w.run()
	log.Printf("Grimreach world listening on %s; health on %s", *listen, *health)
	for {
		connection, err := listener.Accept()
		if err != nil {
			log.Print(err)
			continue
		}
		go w.accept(connection)
	}
}

func (w *world) accept(connection net.Conn) {
	defer connection.Close()
	_ = connection.SetReadDeadline(time.Now().Add(10 * time.Second))
	scanner := bufio.NewScanner(connection)
	scanner.Buffer(make([]byte, 4096), 65536)
	if !scanner.Scan() {
		return
	}
	var hello message
	if json.Unmarshal(scanner.Bytes(), &hello) != nil || hello.Type != "hello" {
		return
	}
	if hello.Role != "player" && hello.Role != "analytics" {
		return
	}
	_ = connection.SetReadDeadline(time.Time{})
	p := &peer{connection: connection, outbound: make(chan message, 64), role: hello.Role}
	if p.role == "player" {
		p.id = fmt.Sprintf("player-%d", atomic.AddUint64(&w.nextID, 1))
	}
	go p.write()
	w.mu.Lock()
	w.peers[p] = struct{}{}
	if p.role == "player" {
		w.players[p.id] = &player{ID: p.id}
		p.send(message{Type: "welcome", ID: p.id})
		w.event("joined " + p.id)
	} else {
		p.send(message{Type: "welcome", Role: "analytics"})
	}
	w.mu.Unlock()
	defer func() {
		w.mu.Lock()
		delete(w.peers, p)
		if p.role == "player" {
			delete(w.players, p.id)
			w.event("left " + p.id)
		}
		close(p.outbound)
		w.mu.Unlock()
	}()

	for scanner.Scan() {
		if p.role != "player" {
			continue
		}
		var input message
		if json.Unmarshal(scanner.Bytes(), &input) != nil || input.Type != "input" {
			continue
		}
		if math.IsNaN(input.DX) || math.IsNaN(input.DZ) || math.IsInf(input.DX, 0) || math.IsInf(input.DZ, 0) {
			continue
		}
		w.mu.Lock()
		if avatar := w.players[p.id]; avatar != nil {
			avatar.DX, avatar.DZ = input.DX, input.DZ
		}
		w.mu.Unlock()
	}
}

func (w *world) run() {
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		w.mu.Lock()
		w.tick++
		players := make([]player, 0, len(w.players))
		for _, avatar := range w.players {
			dx, dz := avatar.DX, avatar.DZ
			length := math.Hypot(dx, dz)
			if length > 1 {
				dx, dz = dx/length, dz/length
			}
			avatar.X = math.Max(-48, math.Min(48, avatar.X+dx*0.4))
			avatar.Z = math.Max(-48, math.Min(48, avatar.Z+dz*0.4))
			players = append(players, *avatar)
		}
		for p := range w.peers {
			if p.role == "player" {
				p.send(message{Type: "snapshot", Tick: w.tick, Players: players})
			} else if w.tick%10 == 0 {
				p.send(message{Type: "metrics", Tick: w.tick, Count: len(players), Players: players})
			}
		}
		w.mu.Unlock()
	}
}

func (w *world) event(text string) {
	for p := range w.peers {
		if p.role == "analytics" {
			p.send(message{Type: "event", Text: text, Tick: w.tick})
		}
	}
	log.Print(text)
}

func (p *peer) send(value message) {
	select {
	case p.outbound <- value:
	default:
		_ = p.connection.Close()
	}
}

func (p *peer) write() {
	defer p.connection.Close()
	encoder := json.NewEncoder(p.connection)
	for value := range p.outbound {
		if err := encoder.Encode(value); err != nil {
			return
		}
	}
}
