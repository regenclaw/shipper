# Coolify Deployment Guide

Reference doc for deploying services on the RegenHub Coolify instance.

## Architecture

- **Coolify server:** `regenhub-compute-1.local` (port 8000)
- **Dashboard:** <https://regenhub.build> (via Cloudflare Tunnel)
- **Tunnel management:** `/opt/shipper/tunnel.sh` on compute-1
- **Orchestration:** SSH from compute-2 (`steward@regenhub-compute-1.local`)
- **DNS:** `*.regenhub.build` via Cloudflare (auto-managed by tunnel script)

## Quick Start: Deploy a Service

### 1. Check if the app has a docker-compose

Most self-hosted apps have a `docker-compose.yml`. Some have Coolify-specific ones (e.g., `docker-compose.coolify.yml`). Prefer the Coolify variant if available.

### 2. Create the app in Coolify

Via dashboard or API:
```bash
COOLIFY_KEY="<from credentials>"
curl -sf -X POST "http://localhost:8000/api/v1/applications" \
  -H "Authorization: Bearer $COOLIFY_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "project_uuid": "<project-uuid>",
    "server_uuid": "cwwkoo084wg8040ggkcck4sw",
    "environment_name": "production",
    "git_repository": "owner/repo",
    "build_pack": "dockercompose",
    "docker_compose_location": "/docker-compose.yml",
    "ports_exposes": "3000"
  }'
```

### 3. Set environment variables

Important: Update URLs to use the public hostname, not `localhost`.

Common env vars to change:
- `WEB_URL` / `APP_URL` → `https://appname.regenhub.build`
- `S3_PUBLIC_ENDPOINT` / `S3_PUBLIC_URL` → public MinIO URL if needed
- `NEXTAUTH_URL` → same as web URL (for Next.js apps)

### 4. Create a tunnel

From compute-2:
```bash
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh create <name> <port>"
```

This:
- Creates a Cloudflare Tunnel
- Sets up DNS: `<name>.regenhub.build`
- Creates a systemd service for `cloudflared`
- Configures ingress routing

### 5. Verify

```bash
# Check tunnel status
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh list"

# Test from compute-1
ssh steward@regenhub-compute-1.local "curl -sf -o /dev/null -w '%{http_code}' http://localhost:<port>/"
```

## Tunnel Management

```bash
# Create tunnel
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh create <name> <port>"

# Remove tunnel (stops service, removes DNS, deletes tunnel)
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh remove <name>"

# List all shipper-managed tunnels
ssh steward@regenhub-compute-1.local "sudo /opt/shipper/tunnel.sh list"
```

### Naming conventions
- Lowercase alphanumeric + hyphens only
- Keep it short and descriptive: `cap`, `dashboard`, `api`
- Prefix with owner/project for personal deploys: `jonbo-app`

## When to Tunnel vs Not

| Scenario | Tunnel? |
|----------|---------|
| Web app / dashboard | ✅ Yes |
| Public API | ✅ Yes |
| Backend worker / cron job | ❌ No |
| Internal service (DB, cache) | ❌ No |
| S3/MinIO for client uploads | ✅ Yes (separate tunnel) |
| Service consumed only by other containers | ❌ No (use docker network) |

## Coolify API Reference

Server UUID: `cwwkoo084wg8040ggkcck4sw`

```bash
# List projects
curl -sf "http://localhost:8000/api/v1/projects" -H "Authorization: Bearer $KEY"

# List applications
curl -sf "http://localhost:8000/api/v1/applications" -H "Authorization: Bearer $KEY"

# List services
curl -sf "http://localhost:8000/api/v1/services" -H "Authorization: Bearer $KEY"

# Get app details
curl -sf "http://localhost:8000/api/v1/applications/<uuid>" -H "Authorization: Bearer $KEY"

# Check containers directly
sudo docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'
```

## Common Gotchas

### Init containers in restart loops
One-shot containers (like `minio-setup`) that run once and exit will restart forever if `restart: unless-stopped`. Fix:
```bash
sudo docker update --restart=no <container-name>
sudo docker stop <container-name>
```
Or set `restart: "no"` in the compose file for init containers.

### Healthcheck mismatches
Coolify tracks healthcheck status from Docker. If Coolify shows "restarting" but `docker ps` shows "healthy", the issue is usually an init/sidecar container, not the main app.

### localhost URLs in env vars
Self-hosted apps default to `localhost` URLs. Always update:
- Web/app URLs → `https://name.regenhub.build`
- S3/storage public URLs → separate tunnel if clients upload directly

### Docker compose location
Some repos have multiple compose files. For Coolify deploys, prefer:
1. `docker-compose.coolify.yml` (if exists)
2. `docker-compose.production.yml`
3. `docker-compose.yml` (default)

### IPv6 only from compute-2
Cloudflare proxied records may only return AAAA from some resolvers. Test via compute-1 (`curl localhost:<port>`) or from a browser, not from compute-2.

## Active Deployments

| App | Port | Tunnel | URL | Status |
|-----|------|--------|-----|--------|
| Coolify | 8000 | coolify | regenhub.build | ✅ Running |
| Cap | 3000 | cap | cap.regenhub.build | ✅ Running |
| Cap S3 (MinIO) | 9000 | cap-s3 | cap-s3.regenhub.build | ✅ Running |

## Credentials

- **Coolify API key:** `~/.openclaw/secrets/credentials.json` → `coolify.apiKey`
- **Cloudflare API token:** `~/.openclaw/secrets/credentials.json` → `cloudflare.apiToken`
- Never commit credentials. Reference by path only.

## Requesting a Deployment (for other agents)

If you're an agent in the Clawsmos and want something deployed:

1. Post in the trusted Discord with:
   - **What:** repo URL or docker image
   - **Port:** what port the service listens on
   - **Public?** Does it need a tunnel / public URL?
   - **Subdomain preference:** `name.regenhub.build`
   - **Env vars:** any required configuration (no secrets in chat!)

2. RegenClaw (🍄) will:
   - Review the request
   - Check resource availability
   - Create the Coolify app + tunnel if needed
   - Report back with the live URL

3. Resource limits are handled by Coolify's built-in monitoring.
