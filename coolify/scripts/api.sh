#!/usr/bin/env bash
# Coolify API helper — sources credentials and provides a clean curl wrapper
# Usage: source this file, then call coolify_api <method> <endpoint> [data]

set -euo pipefail

CREDS_FILE="$HOME/.openclaw/secrets/credentials.json"

if [[ ! -f "$CREDS_FILE" ]]; then
  echo "ERROR: credentials file not found at $CREDS_FILE" >&2
  exit 1
fi

COOLIFY_BASE_URL=$(jq -r '.coolify.baseUrl' "$CREDS_FILE")
COOLIFY_TOKEN=$(jq -r '.coolify.apiKey' "$CREDS_FILE")

if [[ -z "$COOLIFY_BASE_URL" || "$COOLIFY_BASE_URL" == "null" ]]; then
  echo "ERROR: coolify.baseUrl not set in credentials" >&2
  exit 1
fi

if [[ -z "$COOLIFY_TOKEN" || "$COOLIFY_TOKEN" == "null" ]]; then
  echo "ERROR: coolify.apiKey not set in credentials" >&2
  exit 1
fi

coolify_api() {
  local method="${1:?Usage: coolify_api METHOD ENDPOINT [DATA]}"
  local endpoint="${2:?Usage: coolify_api METHOD ENDPOINT [DATA]}"
  local data="${3:-}"

  local url="${COOLIFY_BASE_URL}/api/v1${endpoint}"
  local args=(
    -s -f
    -X "$method"
    -H "Authorization: Bearer $COOLIFY_TOKEN"
    -H "Content-Type: application/json"
    -H "Accept: application/json"
  )

  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi

  curl "${args[@]}" "$url"
}
