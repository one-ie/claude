# /rag

Search, synthesize, verify, and ingest notes from the OO-Brain corpus (Obsidian vault → Supabase pgvector, hybrid RRF retrieval).

**MCP tools:** `mcp__oo-brain__search_notes` · `mcp__oo-brain__mark_retrieval` · `mcp__oo-brain__ingest_note`

**Closed-loop rule (non-negotiable):** every `search_notes` call MUST be followed by `mark_retrieval(query_id, mark|warn|unsure)` before the turn ends. Skipping pollutes the corpus feedback loop.

---

## Modes

| Invocation | What | Skill |
|---|---|---|
| `/rag <query>` | Quick inline search — top 5 chunks, inline display | direct |
| `/rag synthesize <topic>` | Wide-slice brief: cited, themed, 2–3 pages | rag-synthesize |
| `/rag fanout <question>` | Multi-angle: 5–10 sub-queries → synthesized answer | rag-fanout |
| `/rag triangulate <claim>` | Verify one claim from 3+ angles | rag-triangulate |
| `/rag adversarial <belief>` | Stress-test: find contradicting evidence | rag-adversarial |
| `/rag canary <thing>` | Check if something has been flagged/warned | rag-canary |
| `/rag discover [--vault X]` | Coverage audit: what topics are thin? | rag-skill-discovery |
| `/rag ingest <title> -- <content>` | Add a note to the corpus | direct |

**Flags (all modes):**
- `--vault oo-brain|agency-operator|personal-brain|all` — override auto-routing (default: auto)
- `--k <N>` — chunk count (default 5 for quick, 15 for synthesize, 3 per sub-query for fanout)
- `--dry-run` — show the query + vault + k, don't fire

---

## Vault auto-routing

| Topic signals | Vault |
|---|---|
| Frameworks, courses, YouTube intel, books, research | `oo-brain` |
| SOPs, clients, ops, agency processes, rules | `agency-operator` |
| Personal notes, journal, daily notes | `personal-brain` |
| Unclear / cross-cutting | `all` |

---

## Steps per mode

**"Delegate to `<name>` skill" below means: Read `.claude/skills/<name>.md` and
follow it.** Those six files are flat `.md`, not `<name>/SKILL.md` directories,
so the runtime does not register them — the Skill tool cannot invoke them by
name even though each carries valid `name`/`description` frontmatter. Read the
file directly; it is the live contract either way.

### `/rag <query>` — Quick Search

1. Auto-route vault from query topic.
2. Call `search_notes(query=<query>, k=5, vault=<vault>)`. Capture `query_id`.
3. Display results inline:
   ```
   RAG: "<query>" · vault=<vault> · <N> chunks

   1. [<score>] <file_path>
      "<excerpt>"

   2. [<score>] <file_path>
      "<excerpt>"
   …
   ```
4. Synthesize a 3–5 sentence answer from the chunks, with inline `[source: <file>]` citations.
5. Call `mark_retrieval(query_id, mark|warn|unsure)` — `mark` if chunks informed the answer.
6. Print: `↩ loop closed · query_id=<uuid>`

If 0 chunks: say "corpus has no coverage of '<query>'" — do not pad.

---

### `/rag synthesize <topic>` — Written Brief

Delegate to `rag-synthesize` skill. Pass `<topic>` + any `--vault`, `--k`, `--out`, `--audience` flags from `$ARGUMENTS`.

---

### `/rag fanout <question>` — Multi-Angle

Delegate to `rag-fanout` skill. Pass `<question>` + flags.

---

### `/rag triangulate <claim>` — Verify a Claim

Delegate to `rag-triangulate` skill. Pass `<claim>` + flags.

---

### `/rag adversarial <belief>` — Stress-Test

Delegate to `rag-adversarial` skill. Pass `<belief>` + flags.

---

### `/rag canary <thing>` — Canary Check

Delegate to `rag-canary` skill. Pass `<thing>` + flags.

---

### `/rag discover [--vault X]` — Coverage Audit

Delegate to `rag-skill-discovery` skill. Pass `--vault` if provided.

---

### `/rag ingest <title> -- <content>` — Add to Corpus

1. Parse: everything before ` -- ` is `<title>`, everything after is `<content>`.
2. Auto-detect vault: operational content → `agency-operator`; everything else → `oo-brain`.
3. Call `ingest_note(title=<title>, content=<content>, vault=<vault>, source="tony-cc")`.
4. Report: `INGESTED: "<title>" → <vault> · immediately retrievable via /rag`

If `--dry-run`: print `DRY: would ingest "<title>" → <vault>` and stop.

---

## Output contract

Every mode prints a summary line on completion:

```
RAG ✓ · mode=<mode> · vault=<vault> · chunks=<N> · loop=closed
```

If retrieval returned 0 chunks, print:
```
RAG ∅ · corpus has no coverage of "<query>" · try --vault all or /rag fanout
```

---

## Example invocations

```
/rag what do we know about email deliverability
/rag synthesize AI SEO strategies --vault oo-brain
/rag fanout "how should we price our AI agency retainer?"
/rag triangulate "long-form content ranks better than short-form"
/rag adversarial "we should focus on LinkedIn over email"
/rag ingest "Client Onboarding Checklist" -- Step 1: send welcome email. Step 2: schedule kickoff…
/rag discover --vault agency-operator
/rag what are our best performing landing page frameworks --dry-run
```

---

*Every `/rag` call closes its loop. No orphaned retrievals.*
