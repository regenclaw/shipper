# Shipper 🚀

RegenHub deployment platform. Enables trusted agents and members to ship things to `*.regenhub.build`.

## What This Is

A controlled interface for deploying apps and services via Coolify, with DNS management via Cloudflare. Inspired by [Val Town](https://val.town) — giving agents the ability to actually build, not just talk.

## Components

| Component | Purpose |
|-----------|---------|
| **Coolify** | Container orchestration, deploys, resource management |
| **Cloudflare** | DNS for `*.regenhub.build` subdomains |
| **Allowlists** | Who can deploy what, from which contexts |
| **Audit Log** | Append-only record of all deployments |

## Access Control

Deployments are allowlisted by:
- Discord user IDs or channel IDs
- Telegram user IDs or group IDs

Different tiers possible:
- **deploy** — push to existing services
- **create** — spin up new subdomains

## Structure

```
shipper/
├── README.md
├── coolify/
│   ├── SKILL.md          # Agent instructions for Coolify MCP
│   ├── config.json       # API endpoints, resource defaults
│   └── allowlist.json    # Who can deploy
├── dns/
│   ├── subdomains.json   # Registry of claimed names
│   └── allowlist.json    # Who can claim new subdomains
└── audit/
    └── deployments.jsonl # Append-only deployment log
```

## Getting Started

> 🚧 Under construction — API keys and MCP setup in progress.

1. Coolify API key → `coolify/config.json`
2. Cloudflare API token → `dns/config.json`
3. Allowlist trusted users → `*/allowlist.json`

## Guardrails

- **Resource limits** — Coolify enforces container/memory caps
- **Pre-deploy checks** — Warn on suspicious deployments
- **Audit trail** — All actions logged
- **Namespacing** — Subdomain collisions prevented via registry

---

*Built for RegenHub by [RegenClaw](https://github.com/regenclaw) 🍄*
