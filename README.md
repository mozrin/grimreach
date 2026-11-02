# Grimreach

Grimreach is an original, player-built fantasy world. This first proof of concept tests a native third-person 3D client against an authoritative Linux world server, with a separate live analytics client. It uses no code or assets from the older Grimreach repositories or Star Wars Galaxies projects.

## Requirements

- Go 1.24 or newer
- Godot 4.7.2 with Linux and Android export templates
- Android SDK and ADB for phone export and installation

## Run on Ubuntu

From the repository root, start the server:

```sh
go run ./server
```

In another terminal, start analytics:

```sh
go run ./analytics
```

Open `client/project.godot` in Godot and run the project. The client connects to `127.0.0.1:7777` automatically. Use WASD to walk and Q/E or right drag to turn the third-person camera. The server owns the avatar position; other connected players appear blue.

To export and run a native Ubuntu build:

```sh
mkdir -p build
godot --headless --path client --export-debug Linux ../build/grimreach-linux.x86_64
./build/grimreach-linux.x86_64
```

The server exposes `http://127.0.0.1:8081/health` for a basic health and player-count check.

## Run on Android over ADB

With the Linux server running and an Android phone connected through ADB:

```sh
adb reverse tcp:7777 tcp:7777
godot --headless --path client --export-debug Android ../build/grimreach-android.apk
adb install -r build/grimreach-android.apk
adb shell am start -n com.mozrin.grimreach/com.godot.game.GodotApp
```

The ADB reverse command makes the phone's `127.0.0.1:7777` reach the Linux server. The four touch buttons move the character; dragging on the right side turns the camera. For use without ADB, enter the Linux server's reachable IP address in the client.

The client and server in this proof of concept are for local development. Accounts, persistence, secure remote networking, towns, mining, and quests are later work.
