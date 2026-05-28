# one-ie — system structure

## Layout

```
one-ie/
├── one.ie/       # main site — Astro + React (web only, source of truth)
├── channels/     # agent runtime worker — Hono + AI SDK on CF Workers (was agents/, "claw")
├── api/          # gateway — TypeDB proxy → api.one.ie
├── schema/       # TypeDB .tql schema + migrations
├── sync/         # scheduled CF Worker — TypeDB ↔ KV ↔ D1 ↔ SUI
├── backup/       # scheduled CF Worker — KV snapshots → R2 daily
├── sdk/          # @oneie/sdk — TypeScript SDK
├── mcp/          # @oneie/mcp — MCP server
├── cli/          # @oneie/cli — CLI (one + oneie bins)
└── python/       # oneie — Python SDK
```

## Principles

- `one.ie/` is the source of truth for the main site. Cherry-pick from `dev.one.ie/` as needed.
- `channels/` handles agent/AI ingress (Telegram, Discord, HTTP, web → LLM → substrate).
- `api/` is a thin proxy only — no business logic, just TypeDB + WebSocket hub.
- All packages (`sdk`, `mcp`, `cli`, `python`) are standalone — no local path deps.
- `dev.one.ie/` is the legacy monolith — reference only, being phased out.

## Deployed surfaces

| Package  | URL            |
|----------|----------------|
| one.ie   | https://one.ie |
| api      | https://api.one.ie |
| agents   | CF Worker (subdomain TBD) |
| sync     | CF Scheduled Worker |
| backup   | CF Scheduled Worker |
