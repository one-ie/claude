---
name: models
description: Call ANY model in one line, and pick the right one on measured evidence. Use whenever a task wants a second opinion from another model, a cheap bulk pass, a long-context read, a frontier judgement, or an answer to "which model should this run on". Triggers — "ask kimi/gpt-5.2/gemini", "call another model", "which model is fastest", "second opinion", "run this past a bigger model", "cheapest model that can do X", "compare models on this".
---

# Calling any model

`bash .claude/scripts/m.sh <model|alias> "<prompt>"` — an answer in ~1-4s.

```bash
m.sh kimi "in one sentence, what is HKDF for"
m.sh best -f text/key.md "review this document"      # best = openai/gpt-5.2
m.sh --tags open,cheap,long "summarise this"          # route by tags
cat notes.md | m.sh flash "summarise"                 # stdin pipes
m.sh --models kimi,best,glm "one question"            # fan out
```
(`m.sh` is `.claude/scripts/m.sh`. Alias it to `m` for speed.)

## The one thing to know first

**The repo's own `OPENROUTER_API_KEY` is REVOKED** — it answers 401
`{"message":"User not found"}`, and so does the auth-only `GET /api/v1/key`, so
it is the credential and not the payload. There is no live `sk-or-v1-` key
anywhere in the monorepo, `~/Server`, `~/.claude`, the shell rc files or the
keychain. **Do not write a direct OpenRouter call.** `m.sh` goes through the
substrate's own `agent:run`, paid for by prod's key.

## Why it works the way it does

There is **no per-call model parameter** anywhere in the stack: `/run` reads
`persona.model` and nothing else (`channels/src/index.ts`), set in an agent's R2
frontmatter and read at `channels/src/context.ts:592`. So `m.sh` mints one
throwaway passthrough persona per model, `m-<sanitised-id>`, and reuses it.
`resolveBaseModel` (`channels/src/middleware.ts`) hands an id with no provider
prefix to `openrouter(modelId)` **verbatim**, and only the `openai/` and
`cerebras/` branches carry fallback middleware — so a valid id cannot be
silently answered by a different model.

**The slug trap.** `runAgent` does `requireSlug(ctx)` = `ctx.ownerSlug` with **no
authority walk**, and a world key's ownerSlug IS its actor id. Publish to the
wrong slug and the publish SUCCEEDS while `agent:run` answers
`persona_not_found`. `m.sh` resolves this once and caches it; `ONE_SLUG=<slug>`
overrides.

## Picking a model — three MEASURED axes, and they disagree

```bash
m.sh --filter open,cheap,long          # who matches, ranked, with live price
m.sh --rank tps   --filter long        # rank by throughput
m.sh --rank intel --filter frontier    # rank by Artificial Analysis index
m.sh --tags frontier,reason "..."      # route and run
```

| axis | what it is | source |
|---|---|---|
| `ttft` (default) | ms to the FIRST token | `model-speed.json` — our own door, p50, n=5-7 |
| `tps` | tokens/sec AFTER the first | `model-speed.json` — ~700-word answer, n=3 |
| `intel` | Artificial Analysis Intelligence Index | `model-intel.json` — `aa-sync.mjs` |

**Rank a short interactive answer by `ttft` and a generation job by `tps`.**
Getting this wrong misses by 5x: `gpt-5.2` is 2nd fastest to START (900ms) and
2nd SLOWEST to FINISH a 700-word answer (20.4s). `gemini-3.5-flash-lite` wins
both (894ms, 259 tok/s, 3.9s). `qwen3.8-flash` looks mid-table on ttft and takes
**131 seconds**.

An **unmeasured** model sorts LAST on every axis rather than bluffing, and an
unsatisfiable tag set **refuses** (exit 1) instead of quietly dropping a tag.

## Aliases worth knowing

`best` gpt-5.2 · `fast` gemini-3.5-flash-lite · `kimi` kimi-k3 (smartest open) ·
`glm-flash` glm-5.3-flash ($0.09/$0.30, 1.31M ctx) · `flash` gemini-3.8-flash ·
`opus` `sonnet` `haiku` `grok` `astra` `deepseek` `minimax` `qwen` · full list
and a LIVE check against OpenRouter's catalog: `m.sh --list`.
Tags: `open frontier fast cheap long code reason cn vision`.

## Answers are cached

Keyed on model + system + prompt + stdin + the BYTES of every attached file, so
a hit can never be another question's answer; only successful answers are
stored. Measured 7.9s -> 0.049s on a repeat. **`--fresh` re-asks** — the same
question returns the same words until you do, which is right while iterating on
a document and wrong when you want it re-rolled. `--gc` clears personas and cache.

## Traps when you measure anything here

1. **Benchmark SEQUENTIALLY.** An 8-11 way parallel burst once produced a fake
   "17x provider effect" that was pure self-inflicted contention.
2. **Use a unique nonce per call** — an identical prompt measures the answer
   cache and reports impossible 60ms "model calls".
3. **A model asked to be X will say it is X.** A self-report is never evidence
   of which model ran. The control is a twin persona pinned to a NONEXISTENT id:
   it must fail while the real one answers.
4. `server-timing` on `/api/ask/*` (`curl -D -`) decomposes the call —
   `auth;dur=…` is our walk, `data;dur=…` is the model. Use `data`, never wall
   clock.
