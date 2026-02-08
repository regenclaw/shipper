#!/usr/bin/env bash
# Manage Coolify projects
# Usage: projects.sh <action> [uuid]
#   list              — list all projects
#   get <uuid>        — get project details with environments
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api.sh"

ACTION="${1:?Usage: projects.sh <list|get> [uuid]}"
UUID="${2:-}"

case "$ACTION" in
  list)
    coolify_api GET /projects | jq '[.[] | {name, uuid, description}]'
    ;;
  get)
    [[ -z "$UUID" ]] && echo "ERROR: uuid required" >&2 && exit 1
    coolify_api GET "/projects/$UUID" | jq '{name, uuid, description, environments}'
    ;;
  *)
    echo "ERROR: unknown action '$ACTION'" >&2
    exit 1
    ;;
esac
