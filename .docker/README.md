# Docker services

The root `docker-compose.yaml` defines the deployable services and their private
`appnet` network. Docker build files and service-specific instructions live in
this directory. The root `.dockerignore` limits the server build context.

| Folder | Purpose |
| --- | --- |
| [`server/`](server/README.md) | Builds the Go world server. |
| [`cloudflared/`](cloudflared/README.md) | Documents the Cloudflare Tunnel connector and routing. |

Run `docker compose up -d --build` from the repository root after setting
`TUNNEL_TOKEN` in the root `.env`. The tunnel is the only public ingress; Compose
does not publish container ports.
