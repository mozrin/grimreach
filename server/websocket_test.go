package main

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestWebSocketPlayerUsesAuthoritativeWorld(t *testing.T) {
	w := &world{peers: make(map[*peer]struct{}), players: make(map[string]*player)}
	server := httptest.NewServer(w.httpHandler())
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	go w.run(ctx)
	connection, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"/play", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer connection.CloseNow()
	if err := connection.Write(ctx, websocket.MessageText, []byte("{\"type\":\"hello\",\"role\":\"player\"}\n")); err != nil {
		t.Fatal(err)
	}
	var welcome message
	for welcome.Type != "welcome" {
		_, packet, err := connection.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		if err := json.Unmarshal(packet, &welcome); err != nil {
			t.Fatal(err)
		}
	}
	if welcome.ID == "" {
		t.Fatal("WebSocket player did not receive an identity")
	}
	if err := connection.Write(ctx, websocket.MessageText, []byte("{\"type\":\"input\",\"dx\":1,\"dz\":0}\n")); err != nil {
		t.Fatal(err)
	}
	for {
		_, packet, err := connection.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		var update message
		if err := json.Unmarshal(packet, &update); err != nil {
			t.Fatal(err)
		}
		if update.Type == "snapshot" && len(update.Players) == 1 && update.Players[0].X > 0 {
			if update.Players[0].ID != welcome.ID {
				t.Fatal("Snapshot player identity changed")
			}
			break
		}
	}
}
