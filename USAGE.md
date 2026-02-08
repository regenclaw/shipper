# Shipper Usage

## SSH Commands (from compute-2)

```bash
# Create a tunnel (exposes a local port as a subdomain)
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh create <name> <port>"
# Example: ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh create myapp 3000"
# Result: https://myapp.regenhub.build -> localhost:3000

# Remove a tunnel
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh remove <name>"

# List active tunnels
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh list"
```

## Setup

1. Install `cloudflared` on compute-1
2. Copy `config.example` to `/etc/shipper/config` and fill in real values
3. Deploy `tunnel.sh` to `/opt/shipper/tunnel.sh`
4. SSH key from compute-2 must be in compute-1's `authorized_keys`

## Architecture

- **compute-1**: Runs Coolify + cloudflared tunnels (the actual services)
- **compute-2**: RegenClaw orchestrates from here via SSH
- **Cloudflare**: Manages DNS + tunnel routing, free tier (1000 tunnels)
- Each deploy gets its own tunnel → `name.regenhub.build`

## Active Tunnels

| Name | Hostname | Port | Service |
|------|----------|------|---------|
| coolify | regenhub.build + admin.regenhub.build | 8000 | Coolify dashboard |
