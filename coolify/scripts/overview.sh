#!/usr/bin/env bash
# Get a quick overview of the Coolify instance
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api.sh"

echo "=== Servers ==="
coolify_api GET /servers | jq '[.[] | {name, ip, uuid}]'

echo ""
echo "=== Projects ==="
coolify_api GET /projects | jq '[.[] | {name, uuid}]'

echo ""
echo "=== Applications ==="
coolify_api GET /applications | jq '[.[] | {name, status, fqdn, uuid}]'

echo ""
echo "=== Services ==="
coolify_api GET /services | jq '[.[] | {name, status, uuid}]' 2>/dev/null || echo "[]"
