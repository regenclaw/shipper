# Coolify Skill

Manage deployments on the RegenHub Coolify instance via HTTP API.

## Setup

- **Base URL:** Stored in `~/.openclaw/secrets/credentials.json` → `coolify.baseUrl`
- **API Key:** Stored in `~/.openclaw/secrets/credentials.json` → `coolify.apiKey`
- **Allowlist:** Stored in `~/.openclaw/secrets/shipper-allowlist.json`

## Available Scripts

All scripts live in `coolify/scripts/` relative to this skill.

### Overview
```bash
./scripts/overview.sh
```
Returns a summary of all servers, projects, applications, and their status.

### List Applications
```bash
./scripts/apps.sh [list|get|logs|start|stop|restart|deploy] [uuid]
```

### List Projects
```bash
./scripts/projects.sh [list|get] [uuid]
```

### Deploy Application
```bash
./scripts/deploy.sh <app-uuid>
```
Triggers a deployment and logs it to the audit trail.

### Create Application
```bash
./scripts/create-app.sh <project-uuid> <name> <git-repo> [branch]
```
Creates a new application from a git repository.

### Environment Variables
```bash
./scripts/env.sh <app-uuid> [list|set|delete] [key] [value]
```

## Access Control

Before any write operation (deploy, create, start/stop/restart, env changes):
1. Check `coolify/allowlist.json` for the requesting user
2. Log the action to `audit/deployments.jsonl`

## Guardrails

- **Pre-deploy check:** Warn if deploying something that looks resource-heavy
- **Audit everything:** All mutations logged with timestamp, user, action, target
- **No destructive ops without confirmation:** Deleting apps/projects requires explicit confirmation

## API Reference

Base: `{COOLIFY_BASE_URL}/api/v1`
Auth: `Authorization: Bearer {COOLIFY_ACCESS_TOKEN}`

Key endpoints:
- `GET /servers` — list servers
- `GET /projects` — list projects
- `GET /applications` — list apps
- `GET /applications/{uuid}` — app details
- `POST /applications/{uuid}/restart` — restart
- `GET /applications/{uuid}/logs` — logs
- `POST /deploy` — trigger deploy
