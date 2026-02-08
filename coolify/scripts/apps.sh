#!/usr/bin/env bash
# Manage Coolify applications
# Usage: apps.sh <action> [uuid] [extra-args...]
#   list              — list all applications
#   get <uuid>        — get full details for an app
#   logs <uuid>       — get recent logs
#   start <uuid>      — start an app
#   stop <uuid>       — stop an app
#   restart <uuid>    — restart an app
#   deploy <uuid>     — trigger deployment
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/api.sh"

ACTION="${1:?Usage: apps.sh <list|get|logs|start|stop|restart|deploy> [uuid]}"
UUID="${2:-}"

case "$ACTION" in
  list)
    coolify_api GET /applications | jq '[.[] | {name, status, fqdn, uuid}]'
    ;;
  get)
    [[ -z "$UUID" ]] && echo "ERROR: uuid required" >&2 && exit 1
    coolify_api GET "/applications/$UUID" | jq '{name, status, fqdn, uuid, git_repository, git_branch, build_pack, docker_compose_location, ports_mappings}'
    ;;
  logs)
    [[ -z "$UUID" ]] && echo "ERROR: uuid required" >&2 && exit 1
    coolify_api GET "/applications/$UUID/logs?since=60"
    ;;
  start)
    [[ -z "$UUID" ]] && echo "ERROR: uuid required" >&2 && exit 1
    coolify_api POST "/applications/$UUID/start"
    echo "Started $UUID"
    ;;
  stop)
    [[ -z "$UUID" ]] && echo "ERROR: uuid required" >&2 && exit 1
    coolify_api POST "/applications/$UUID/stop"
    echo "Stopped $UUID"
    ;;
  restart)
    [[ -z "$UUID" ]] && echo "ERROR: uuid required" >&2 && exit 1
    coolify_api POST "/applications/$UUID/restart"
    echo "Restarted $UUID"
    ;;
  deploy)
    [[ -z "$UUID" ]] && echo "ERROR: uuid required" >&2 && exit 1
    coolify_api POST "/applications/$UUID/restart"
    echo "Deployed $UUID"
    # Audit log
    AUDIT_DIR="$(cd "$SCRIPT_DIR/../../audit" && pwd)"
    mkdir -p "$AUDIT_DIR"
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"action\":\"deploy\",\"uuid\":\"$UUID\",\"user\":\"${SHIPPER_USER:-agent}\"}" >> "$AUDIT_DIR/deployments.jsonl"
    ;;
  *)
    echo "ERROR: unknown action '$ACTION'" >&2
    echo "Usage: apps.sh <list|get|logs|start|stop|restart|deploy> [uuid]" >&2
    exit 1
    ;;
esac
