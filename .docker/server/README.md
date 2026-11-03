# World server container

`server.Dockerfile` builds the Go world server in a Go builder image and copies
the binary into a minimal, nonroot runtime image. The root Compose file builds
it with the repository root as context, so `go.mod`, `go.sum`, and `server/` are
available to the build.

The process listens on port 8081 for HTTP health checks and WebSocket play at
`/play`. Cloudflared reaches it as `http://grimreach_server:8081` on `appnet`.
The legacy TCP listener remains inside the container network; Compose does not
publish it to the host.

Build from the repository root with `docker compose build server`. Inspect the
running service with `docker compose logs server`.
