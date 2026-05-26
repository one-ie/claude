# API Changelog

Entries are auto-emitted from OpenAPI diff in CI. Deprecation entries include a `Sunset:` date.

---

## 2026-05-14 — Substrate verbs + dimension reads (Wave 4.6)

### Added

- `POST /signal/{receiver}` — route a signal; 5-mode addressing grammar
- `POST /ask/{receiver}` — signal and await one of 4 outcomes; always HTTP 200
- `POST /mark/{edge}` — strengthen a path; optional atomic payment via `weight` + `currency`
- `POST /warn/{edge}` — weaken a path
- `POST /fade` — decay all paths (SERVER_SECRET gated)
- `GET /follow` — read best deterministic path for a tag
- `GET /select` — sample best path probabilistically (ant-colony routing)
- `POST /sub` / `DELETE /sub` — webhook subscription lifecycle
- `GET /groups` — list groups (worlds, teams, orgs); `x-dimension: groups`
- `GET /actors` — list actors (humans, agents, worlds); `x-dimension: actors`
- `GET /things` — list things (skills, tasks, tokens); `x-dimension: things`
- `GET /paths` — list paths with strength/resistance; `x-dimension: paths`
- `GET /events` — list signal events; `x-dimension: events`
- `GET /learning` — list hypotheses ordered by confidence; `x-dimension: learning`
- `GET /api/reference` — OpenAPI spec rendered via Redoc

### Changed

- `POST /api/agents/publish` — now enforces per-billing-tier publish limits (free=5, starter=20, pro=100, agency=∞); returns 402 with `upgrade` URL when exceeded

---

## 2026-04-01 — Agent lifecycle (Wave 0-4)

### Added

- `POST /api/agents/publish` — publish agent markdown to R2
- `GET /api/agents/history` — version history for an agent
- `POST /api/agents/rollback` — restore a previous version (byte-identical)
- `GET /api/agents/{id}` — agent metadata
- `DELETE /api/agents/{id}` — delete an agent
- `POST /api/admin/agents/freeze` — freeze an agent (admin only); returns 451 in chat
- `POST /api/abuse/report` — report a message for moderation

---

## Deprecations

| Endpoint | Deprecated | Sunset | Replacement |
|----------|-----------|--------|-------------|
| *(none yet)* | — | — | — |

---

*Deprecation policy: 6 months minimum between `Deprecation: true` header and `Sunset` date. Legacy endpoints forward to substrate verbs — see PL8 shims.*
