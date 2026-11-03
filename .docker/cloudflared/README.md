# Cloudflare Tunnel connector

The `cloudflared` Compose service uses the official Cloudflare image and runs
the remotely managed tunnel. It reads `TUNNEL_TOKEN` from the repository root
`.env`. Keep that file local and out of Git.

Configure `grimreach.mozrin.com` with path `/play` to
`http://grimreach_server:8081`. This route carries game WebSockets. If the
hostname also serves a website, configure its separate route and service in
the deployment that owns that website. This connector needs no Dockerfile or
extra support files.

Inspect connectivity with `docker compose logs cloudflared`.
