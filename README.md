# rustdesk-server-rions

Patched `hbbs` image for the RionsDesk self-hosted server.

Adds the server-side secure handshake for API-account signed-in clients (RustDesk
>= 1.4.1). Without it, logged-in clients fail to connect with
`Failed to secure tcp: deadline has elapsed` (rustdesk/rustdesk#16691).

CI builds `ghcr.io/vinyljackers/rustdesk-server-rions:latest`.

## Deploy (Synology / docker compose)

Run `hbbs` from this image **with a key** (`-k _`); the handshake only happens
when the server has a key:

```yaml
  hbbs:
    image: ghcr.io/vinyljackers/rustdesk-server-rions:latest
    command: hbbs -k _
    network_mode: host
    volumes:
      - ./data:/root
    restart: unless-stopped
```

`hbbr` can stay on the same image (relay binary is unchanged) or the stock
`rustdesk/rustdesk-server:latest`.

Patch credit: upsoftt/rustdesk-selfhosted-account-fix.
