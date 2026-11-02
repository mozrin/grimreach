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

Open `client/project.godot` in Godot and run the project. The client connects to `127.0.0.1:7777` automatically. Use WASD to walk and Q/E or right drag to turn the third-person camera. The client uses a portrait viewport that also works as a resizable desktop window. The server owns the avatar position; other connected players appear blue.

To export and run a native Ubuntu build:

```sh
mkdir -p build
godot --headless --path client --export-debug Linux ../build/grimreach-linux.x86_64
./build/grimreach-linux.x86_64
```

The server exposes `http://127.0.0.1:8081/health` for a basic health and player-count check.

The world covers coordinates from -8192 to +8192 on each horizontal axis. The client streams a 5-by-5 set of 48-unit terrain regions around the player and regenerates them deterministically from seed `76341`. The server continues to own player movement. Run the region smoke check with `godot --headless --path client --script res://tests/terrain_smoke.gd`.

Nearby regions contain tree cover, stone outcrops, grass, and flower patches. Broad ridges and rolling hills vary the ground height; wet, meadow, and dry climates give regions different vegetation colors and grass heights. An ancient stone courtyard stands northeast of spawn, with further ruins every seven regions in each direction. Terrain and decoration placement are deterministic and unload with each region.

The opening area has three destinations: the Fallen Court, Wayfarer Camp, and Old Star Shrine. Sandy routes lead out from spawn, and a wider route grid continues across the world. Camps, shrines, and courts recur with varied names at deterministic region coordinates and stable IDs. Solid tents, shrines, and walls are blocked by the Linux server; the site grounds and routes remain walkable.

Edda the Wayfinder stands at Wayfarer Camp, southwest of spawn. Examine the camp and begin her trail, then examine the Old Star Shrine and Fallen Court and collect any mineral sample. Return to Edda to earn a persistent Wayfinder's Mark and a lead toward the north road. The journal tracks each objective and recognizes findings made before accepting the trail. The mark is awarded once.

Approaching a site records it in a local exploration journal. Tap **Journal** to see starting leads, bearings, distances, discoveries, and findings. A nearby **Examine** button reveals a short story and records a finding once per site; press F on Ubuntu. The journal persists in Godot's per-user application data and supports light and dark views. Open views stop player movement until Back returns to the world. Check the journal contract with `godot --headless --path client --script res://tests/journal_smoke.gd`.

Glowing mineral veins also appear across streamed regions, with one close to spawn. Move near a vein and tap **Survey** to see its stable name and conductivity, hardness, malleability, and purity values (100–1000). **Collect sample** adds that exact variant to the local journal; the same vein refreshes after 60 seconds. Samples and cooldowns survive client restarts. This is a first exploration activity; extraction machines, trading, crafting effects, and server-persistent inventories are later work. Check deterministic vein identities and quality with `godot --headless --path client --script res://tests/veins_smoke.gd`.

The Linux server mirrors the solid placement rules for tree trunks, stone outcrops, and ruin walls. It rejects movement through those objects and lets the character slide along their edges. Grass, flowers, and ruin floors remain walkable.

The explorer turns toward travel and swings arms and legs while walking. A purple dragon circles above the land north of spawn; more can appear across distant regions. Dragon wings flap and the creature bobs in flight. These are exploratory visual models built from original primitives; interaction and combat remain future work.

## Run on Android over ADB

With the Linux server running and an Android phone connected through ADB:

```sh
adb reverse tcp:7777 tcp:7777
godot --headless --path client --export-debug Android ../build/grimreach-android.apk
adb install -r build/grimreach-android.apk
adb shell monkey -p com.mozrin.grimreach 1
```

The ADB reverse command makes the phone's `127.0.0.1:7777` reach the Linux server. In portrait mode, touch open world space and drag in the direction you want to walk. A temporary joystick appears under your thumb; release to stop. Drag with a second finger to turn the camera. For use without ADB, enter the Linux server's reachable IP address in the client.

## Proof-of-concept verification

On Ubuntu 24.04, the Go server accepted Godot clients, its health endpoint reported connected players, and the separate analytics client displayed their live positions. The native Linux client exported and ran. On a physical CPH2505 Android phone, the debug APK installed, rendered the portrait third-person scene, and connected through ADB reverse. Dragging the floating joystick changed the server-owned position; releasing it stopped further movement. `go test ./...`, `go vet ./...`, and both Godot exports completed successfully. This is the first source version, recorded in `VERSION`.

The client and server in this proof of concept are for local development. Accounts, persistence, secure remote networking, towns, mining, and quests are later work.
