#!/usr/bin/env bash
# tunnel.sh — Manage Cloudflare Tunnels for regenhub.build
# Lives on compute-1, called via SSH from compute-2
# Usage:
#   tunnel.sh create <name> <local-port>
#   tunnel.sh remove <name>
#   tunnel.sh list

set -euo pipefail

# Config — loaded from /etc/shipper/config or env
CONFIG_FILE="${SHIPPER_CONFIG:-/etc/shipper/config}"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

CF_TOKEN="${CF_TOKEN:?CF_TOKEN required}"
CF_ACCOUNT_ID="${CF_ACCOUNT_ID:?CF_ACCOUNT_ID required}"
CF_ZONE_ID="${CF_ZONE_ID:?CF_ZONE_ID required}"
DOMAIN="${DOMAIN:-regenhub.build}"
TUNNEL_DIR="${TUNNEL_DIR:-/etc/shipper/tunnels}"
SYSTEMD_DIR="/etc/systemd/system"

CF_API="https://api.cloudflare.com/client/v4"

# --- Helpers ---

cf_api() {
  local method="$1" endpoint="$2"
  shift 2
  curl -sf -X "$method" "${CF_API}${endpoint}" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

# --- Commands ---

cmd_create() {
  local name="${1:?Usage: tunnel.sh create <name> <local-port>}"
  local port="${2:?Usage: tunnel.sh create <name> <local-port>}"
  local hostname="${name}.${DOMAIN}"

  # Validate name (alphanumeric + hyphens only)
  [[ "$name" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$ ]] || die "Invalid name: use lowercase alphanumeric + hyphens"

  # Check if tunnel already exists locally
  [[ -f "${TUNNEL_DIR}/${name}.json" ]] && die "Tunnel '${name}' already exists"

  info "Creating tunnel '${name}'..."
  local result
  result=$(cf_api POST "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel" \
    -d "{\"name\":\"shipper-${name}\",\"tunnel_secret\":\"$(openssl rand -base64 32)\"}")

  local tunnel_id
  tunnel_id=$(echo "$result" | jq -r '.result.id')
  local tunnel_token
  tunnel_token=$(echo "$result" | jq -r '.result.token // empty')

  [[ -n "$tunnel_id" && "$tunnel_id" != "null" ]] || die "Failed to create tunnel: $(echo "$result" | jq -r '.errors')"

  # If no token in create response, fetch it
  if [[ -z "$tunnel_token" ]]; then
    tunnel_token=$(cf_api GET "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/token" | jq -r '.result // empty')
  fi

  info "Tunnel created: ${tunnel_id}"

  # Save tunnel metadata
  mkdir -p "$TUNNEL_DIR"
  cat > "${TUNNEL_DIR}/${name}.json" <<EOF
{
  "name": "${name}",
  "tunnel_id": "${tunnel_id}",
  "hostname": "${hostname}",
  "local_port": ${port},
  "created": "$(date -Iseconds)"
}
EOF

  # Create DNS CNAME record
  info "Creating DNS record: ${hostname} -> ${tunnel_id}.cfargotunnel.com"
  local dns_result
  dns_result=$(cf_api POST "/zones/${CF_ZONE_ID}/dns_records" \
    -d "{\"type\":\"CNAME\",\"name\":\"${name}\",\"content\":\"${tunnel_id}.cfargotunnel.com\",\"proxied\":true}")

  local dns_id
  dns_id=$(echo "$dns_result" | jq -r '.result.id // empty')
  [[ -n "$dns_id" ]] || echo "WARNING: DNS record creation may have failed: $(echo "$dns_result" | jq -r '.errors')"

  # Save DNS record ID for cleanup
  echo "$dns_id" > "${TUNNEL_DIR}/${name}.dns_id"

  # Create systemd service for cloudflared
  info "Creating systemd service..."
  cat > "${SYSTEMD_DIR}/shipper-tunnel-${name}.service" <<EOF
[Unit]
Description=Shipper Tunnel: ${name} (${hostname})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel run --token ${tunnel_token}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  # Configure tunnel ingress via API
  info "Configuring tunnel ingress..."
  cf_api PUT "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/configurations" \
    -d "{\"config\":{\"ingress\":[{\"hostname\":\"${hostname}\",\"service\":\"http://localhost:${port}\"},{\"service\":\"http_status:404\"}]}}" > /dev/null

  # Start the tunnel
  systemctl daemon-reload
  systemctl enable --now "shipper-tunnel-${name}.service"

  info "✅ Tunnel live: https://${hostname} -> localhost:${port}"
  echo "${tunnel_id}"
}

cmd_remove() {
  local name="${1:?Usage: tunnel.sh remove <name>}"
  local meta="${TUNNEL_DIR}/${name}.json"

  [[ -f "$meta" ]] || die "No tunnel found: ${name}"

  local tunnel_id
  tunnel_id=$(jq -r '.tunnel_id' "$meta")

  info "Stopping tunnel service..."
  systemctl stop "shipper-tunnel-${name}.service" 2>/dev/null || true
  systemctl disable "shipper-tunnel-${name}.service" 2>/dev/null || true
  rm -f "${SYSTEMD_DIR}/shipper-tunnel-${name}.service"
  systemctl daemon-reload

  # Remove DNS record
  if [[ -f "${TUNNEL_DIR}/${name}.dns_id" ]]; then
    local dns_id
    dns_id=$(cat "${TUNNEL_DIR}/${name}.dns_id")
    if [[ -n "$dns_id" ]]; then
      info "Removing DNS record..."
      cf_api DELETE "/zones/${CF_ZONE_ID}/dns_records/${dns_id}" > /dev/null 2>&1 || true
    fi
    rm -f "${TUNNEL_DIR}/${name}.dns_id"
  fi

  # Delete tunnel (must clean up connections first)
  info "Deleting tunnel ${tunnel_id}..."
  cf_api DELETE "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}" > /dev/null 2>&1 || \
    echo "WARNING: Could not delete tunnel from Cloudflare (may need manual cleanup)"

  rm -f "$meta"
  info "✅ Tunnel '${name}' removed"
}

cmd_list() {
  if [[ ! -d "$TUNNEL_DIR" ]] || [[ -z "$(ls -A "$TUNNEL_DIR"/*.json 2>/dev/null)" ]]; then
    echo "No active tunnels"
    return
  fi

  printf "%-20s %-36s %-30s %-6s %-10s\n" "NAME" "TUNNEL_ID" "HOSTNAME" "PORT" "STATUS"
  for meta in "$TUNNEL_DIR"/*.json; do
    local name tunnel_id hostname port status
    name=$(jq -r '.name' "$meta")
    tunnel_id=$(jq -r '.tunnel_id' "$meta")
    hostname=$(jq -r '.hostname' "$meta")
    port=$(jq -r '.local_port' "$meta")
    status=$(systemctl is-active "shipper-tunnel-${name}.service" 2>/dev/null || echo "unknown")
    printf "%-20s %-36s %-30s %-6s %-10s\n" "$name" "$tunnel_id" "$hostname" "$port" "$status"
  done
}

# --- Main ---

case "${1:-}" in
  create) shift; cmd_create "$@" ;;
  remove) shift; cmd_remove "$@" ;;
  list)   cmd_list ;;
  *)      echo "Usage: tunnel.sh {create|remove|list} [args...]"; exit 1 ;;
esac
