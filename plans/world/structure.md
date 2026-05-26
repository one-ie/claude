# Server — current structure

```
Server/
├── .claude/                      # Claude Code config (commands, skills, memory)
├── .obsidian/                    # Obsidian vault config
├── .zed/                         # Zed editor config
│
├── *.md  (31 files)              # Design plan cluster — source of truth
│   ├── CLAUDE.md                 # Workspace instructions
│   ├── README.md                 # Entry point + glossary
│   ├── simple.md  website.md  chat.md  wallet.md  agents.md
│   ├── mac.md  secrets.md  passkeys.md  lifecycle.md  owner.md
│   └── homepage-*  security-*  todo.md  world.md  …
│
├── one.ie/                       # PRODUCT CODE → ships to https://one.ie
│   ├── CLAUDE.md  README.md  package.json  astro.config.mjs
│   ├── src/                      # Astro 6 + React 19 app
│   ├── packages/                 # @oneie/sdk, @oneie/mcp, cli
│   ├── workers/  gateway/        # Cloudflare Workers
│   ├── migrations/  scripts/  ops/  test/  tests/
│   ├── one/  (300 files)         # Internal spec/plan cluster ← MISFIT
│   │   ├── template-plan.md  template-todo.md   (classifier)
│   │   ├── personas.md  speed-verified.md  marketplace.md  pricing.md
│   │   ├── backend-tutorial.md  telemetry.md  do.md  …
│   │   ├── archive/
│   │   └── lessons/
│   ├── plans/  prompts/  templates/  interfaces/
│   ├── agents/  python/  nanoclaw/
│   └── docs/  public/  dist/  audits/  backups/  node_modules/
│
├── one-ie/                       # OPENSOURCE MIRROR → github.com/one-ie/one
│   └── one/
│       ├── CLAUDE.md  README.md  AGENTS.md  LICENSE
│       ├── sdk/                  # @oneie/sdk source
│       ├── mcp/                  # @oneie/mcp source
│       ├── agents/               # example agents
│       ├── web/                  # demo site
│       └── one/                  # nested specs (mirror subset)
│
├── apps/                         # Reference repos — read-only
│   ├── enoki-play/               # MIT, sponsored-tx shape reference
│   ├── agent-launch-toolkit/
│   ├── one-core/
│   ├── one.ie.old/               # archived prior version
│   ├── owner-daemon/
│   └── sui-skills/
│
├── transcripts/                  # Session logs (history; don't edit)
│   ├── raw/
│   └── text/
│
├── com.tonyoconnell.owner-daemon.plist
└── key.md
```

## At a glance

| Folder | Role | Audience |
| --- | --- | --- |
| `*.md` (root) | Design / specs / plans | Internal — source of truth |
| `one.ie/` | Product code (Astro + Workers) | https://one.ie |
| `one.ie/one/` | 300 internal spec docs | Build system (template-plan classifier) |
| `one-ie/one/` | Opensource SDK + MCP + CLI | github.com/one-ie/one |
| `apps/` | Reference repos | Read-only patterns |
| `transcripts/` | Session history | Archive |

## Known frictions

- **`one.ie/` vs `one-ie/`** — easy to confuse; both contain a nested `one/`.
- **`one.ie/one/`** — 300 spec files live inside product code, but they're plans (root principle says plans live in root).
- **Brand name `ONE`** has no top-level home — neither `Server/one/` nor a clean canonical folder.
