# /m — call any model, in one line

Run `bash .claude/scripts/m.sh $ARGUMENTS` and report the answer verbatim.

Measured 2026-09-21 on this box: **1.3s** warm, **0.038s** cached, 8.7s the very
first time a given model is used (it mints that model's passthrough persona once,
then never again).

## Usage

```bash
/m kimi "in one sentence, what is HKDF for"
/m best -f text/key.md "review this document"       # best = openai/gpt-5.2
/m --tags open,cheap,long "summarise this"           # route by tags
/m --models kimi,best,glm "one question"             # fan out, parallel
/m --rank tps --filter long                          # who is fastest at generating
/m --list                                            # aliases, checked LIVE
```

## Picking a model

Three MEASURED axes, and **they disagree** — ranking a job on the wrong one
misses by 5x:

| | ttft | tok/s | 700-word answer |
|---|---|---|---|
| `fast` gemini-3.5-flash-lite | **894ms** | **259** | **3.9s** |
| `best` gpt-5.2 | 900ms | 76 | 20.4s |
| `kimi` kimi-k3 — smartest open | 1575ms | 136 | 11.1s |
| `qwen` qwen3.8-flash | 2381ms | 9 | **130.9s** |

`--rank ttft` (default) for a short interactive answer · `--rank tps` for
generation · `--rank intel` for the Artificial Analysis Intelligence Index.

## What it will not do

- **Claim an answer is complete.** This transport returns no `finish_reason`, so
  truncation is UNDETECTABLE. It prints the character count and says so.
- **Guess.** An unmeasured model sorts LAST on every axis; an unsatisfiable tag
  set refuses (exit 1) rather than quietly dropping a tag.
- **Re-roll by default.** The same question returns the same words until
  `--fresh` — right while iterating on a document, wrong when you want variety.

Full contract: `.claude/skills/models/SKILL.md` · why it goes through `agent:run`
and not OpenRouter directly: `CLAUDE.md § Calling any model`.
