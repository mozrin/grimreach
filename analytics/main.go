package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
)

type message struct {
	Type    string `json:"type"`
	Tick    uint64 `json:"tick"`
	Count   int    `json:"count"`
	Text    string `json:"text"`
	Players []struct {
		ID string  `json:"id"`
		X  float64 `json:"x"`
		Z  float64 `json:"z"`
	} `json:"players"`
}

func main() {
	server := flag.String("server", "127.0.0.1:7777", "world server address")
	flag.Parse()
	connection, err := net.Dial("tcp", *server)
	if err != nil {
		log.Fatal(err)
	}
	defer connection.Close()
	if _, err := fmt.Fprintln(connection, `{"type":"hello","role":"analytics"}`); err != nil {
		log.Fatal(err)
	}
	log.Printf("watching %s", *server)
	scanner := bufio.NewScanner(connection)
	for scanner.Scan() {
		var value message
		if json.Unmarshal(scanner.Bytes(), &value) != nil {
			continue
		}
		switch value.Type {
		case "event":
			fmt.Printf("tick %d: %s\n", value.Tick, value.Text)
		case "metrics":
			fmt.Printf("tick %d: %d players", value.Tick, value.Count)
			for _, avatar := range value.Players {
				fmt.Printf(" | %s (%.1f, %.1f)", avatar.ID, avatar.X, avatar.Z)
			}
			fmt.Println()
		}
	}
	if err := scanner.Err(); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}
