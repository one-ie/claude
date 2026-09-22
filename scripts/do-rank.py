#!/usr/bin/env python3
"""do-rank.py — cross-plan priority ranker for /do.

Read-only. Walks every text/*-todo.md, scores it on five traceable signals,
and emits a dependency-aware queue: READY (ranked) · BLOCKED (with blocker) · DONE.

No agents, no tokens — pure parse + graph. The input to do-fleet.sh.

Signals:  score = 2*Strategic + 2*Leverage + 1*round(3*Proximity) + 2*Priority + 2*round(Momentum)
  Strategic  — north-star keyword hits in tags+title (capped 6; agent economy is the vision)
  Leverage   — how many OPEN plans TRANSITIVELY depend on this slug (keystones rank up)
  Proximity  — checkbox completion ratio (SOFT — denominators include AC bullets)
  Priority   — explicit `priority:` frontmatter, human override (0-3)
  Momentum   — recent high-rubric closes (path strength) — warm proven work pulls the fleet
  Readiness  — gate: all depends_on slugs must be DONE, else BLOCKED

Fleet disjointness keys on SUBTREE dirs (containing dir of each deliverable file);
do-fleet.sh reads them via `--dirs`. `--lint` flags phantom/unscoped deliverables.

DONE = 0 open checkboxes OR a dated close in text/learnings.md.

Usage:
  do-rank.py                 human table
  do-rank.py --json          machine queue for the fleet
  do-rank.py --top N         the N highest READY slugs, one per line
  do-rank.py --board-check   perform the live board read (floors print as `>=N`)
  do-rank.py --untriaged [ws]  the triage queue as JSON — tasks:board, every page
"""
import json
import os
import re
import signal
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

# Exit cleanly when piped into head/etc. (closes our stdout early).
try:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
except (AttributeError, ValueError):
    pass

# Repo root = two levels up from .claude/scripts/
ROOT = Path(__file__).resolve().parents[2]
TEXT = ROOT / "text"
LEARNINGS = TEXT / "learnings.md"

# The local path tier — the on-disk mirror of `path.strength` for the task layer
# (the same role tasks-seed.json plays for the on-chain tier; three-layer data model:
# TypeDB truth → KV snapshot → local). `do-rank.py --mark <slug>` writes it; the
# momentum loader reads it. This is the seam do-rank.py always named: when a slug has
# live path strength here, it OVERRIDES the learnings.md count — so a mark() visibly
# moves the next pick. Absent slug → fall back to learnings.md (no regression).
# The loop closes here: close → mark → strength↑ → next rank picks it. See text/loop-plan.md.
TASK_PATHS = TEXT / "task-paths.json"

# North-star keywords (from vision.md / the economic-peer thesis). Weighted by pull.
NORTH_STAR = {
    "agent": 3, "economic": 3, "billing": 3, "payment": 3, "pay": 3, "x402": 3,
    "substrate": 2, "auth": 2, "roles": 2, "authority": 2, "typedb": 2, "schema": 2,
    "workflow": 2, "composition": 2, "inbox": 2, "channels": 2, "skill": 2,
    "lifecycle": 1, "memory": 1, "analytics": 1, "tracking": 1,
}

EXCLUDE = {"template", "todo"}  # template-todo.md and this index's own todo.md

# Real top-level dirs of the monorepo. The fleet's disjointness check keys on
# the first two path segments of each `deliverables:` entry. Filtering to these
# roots kills prose false-positives ("mark/warn", "SUI/ETH", "A/B") that the bare
# dir1/dir2 regex otherwise turns into phantom file-locks. Keep in sync with
# do-fleet.sh deliverable_dirs() — this is the canonical list.
REPO_DIRS = {
    "one.ie", "api", "packages", "channels", "schema", "sync", "backup",
    "apps", "text", ".claude", "migrations", "oo", "pay", "scripts",
}

_DIR_TOKEN = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+")


def deliverable_dirs(text):
    """Set of SUBTREE dirs a plan ships into, from its `deliverables:` block — the
    containing dir of each declared file (the filename dropped), e.g.
    `one.ie/web/src/lib/billing/expiry.ts` → `one.ie/web/src/lib/billing`.

    This is the fleet's disjointness key: two plans are safe to run in parallel iff
    their subtree sets don't overlap. Subtree (not `top/second`) is the granularity
    that gives real parallelism — under `top/second` every one.ie/web plan collapsed
    to a single token and serialized; under full-file two plans editing different
    files in a tightly-coupled family (puck components) looked disjoint and clobbered.
    The containing dir is the unit of coupling: same dir ⇒ treat as one lock.

    do-fleet.sh consumes this via `do-rank.py --dirs <slug>` — ONE extractor, no
    second markdown parser to drift. Empty set ⇒ the plan declares no parseable
    deliverables (a fleet hazard, see waves view + `--lint`).
    """
    dirs = set()
    for tok in deliverable_paths(text):
        parts = tok.split("/")
        # `text/` is the ONE family where the containing-dir rule is wrong. The
        # coupling argument above holds for code (two plans in one component family
        # clobber each other); it does not hold here, because text/ is one flat dir
        # of per-slug documents — `text/<slug>-docs.md` is named after the plan that
        # owns it, so two plans there edit two different files BY CONSTRUCTION and
        # cannot collide. Keying them to the shared `text` dir made every plan with a
        # `doc:` deliverable mutually exclusive with every other: measured 2026-08-31,
        # it serialized all four lifecycle children (and voice-agents, identity,
        # playbook-run, agent-wallet-guardian) behind one another for no real conflict.
        # File granularity here, containing-dir everywhere else.
        if parts[0] == "text" and len(parts) == 2 and "." in parts[-1]:
            dirs.add(tok)
            continue
        # Drop the leaf if it names a file (has an extension); else the path IS a dir.
        sub = "/".join(parts[:-1]) if "." in parts[-1] else tok
        if sub:
            dirs.add(sub)
    return dirs


def transitive_dependents(slug, direct, seen=None):
    """All slugs that TRANSITIVELY depend on `slug`, walking the depends_on graph.
    `direct` maps slug -> set of slugs that directly depend on it. The keystone
    metric: namespace ← tasks-mine ← tasks-push ← tasks-bridge ⇒ 3 dependents, so
    unblocking it frees the whole chain, not just the one child."""
    if seen is None:
        seen = set()
    for child in direct.get(slug, ()):
        if child not in seen:
            seen.add(child)
            transitive_dependents(child, direct, seen)
    return seen


def deliverable_paths(text):
    """Every repo-root path token in the `deliverables:` block (full path, not the
    top/second dir). The granularity-independent source — deliverable_dirs() and the
    linter both derive from it. Path column only (before the em-dash), REPO_DIRS-rooted."""
    # The key line may carry a trailing YAML comment — `deliverables:   # note`.
    # It legally does in 12 tracked plans INCLUDING text/template-todo.md, the
    # file every new plan is copied from, so a `\s*$` anchor here made plans
    # born unscoped: the block never matched, zero paths came back, and the
    # fleet read that as "declares no dirs" and refused to pack them.
    m = re.search(r"^deliverables:[ \t]*(?:#[^\n]*)?$(.*?)(?=^[a-z_]+:|^---\s*$|\Z)",
                  text, re.MULTILINE | re.DOTALL)
    if not m:
        return []
    out = []
    for line in m.group(1).splitlines():
        path_col = line.split("—", 1)[0]
        for tok in _DIR_TOKEN.findall(path_col):
            if tok.split("/")[0] in REPO_DIRS:
                out.append(tok)
    return out


def lint_paths(text):
    """Mechanical hygiene check on a plan's deliverable paths. Returns a list of
    (token, reason) for paths that don't resolve on disk — the phantom-dir failure
    (e.g. `api/invites` written for `one.ie/web/src/pages/api/invites/create.ts`)
    that silently turns a plan into a fleet false-parallel.

    A token is VALID when it (a) exists on disk as a file or dir, or (b) names a
    NEW file (has an extension) up to ONE new directory level under a real parent —
    i.e. its grandparent dir exists (a planned file, optionally in a new subdir of a
    real package, like a new api/ask/gate/ route). Otherwise it's a phantom: a
    URL-style route (`api/composio/connections`) or a wrong-rooted path
    (`apps/pay/backend/...` when the package is `pay/backend/...`) — which silently
    turns the plan into a fleet false-parallel, claiming a dir it never ships into."""
    bad = []
    for tok in deliverable_paths(text):
        p = ROOT / tok
        if p.exists():
            continue
        if "." in p.name and p.parent.parent.exists():  # planned file, real grandparent
            continue
        bad.append((tok, "no such path; not a planned file under a real dir — phantom/wrong-rooted"))
    return bad


# ── Tasks layer ────────────────────────────────────────────────────────────
# Every todo is a task `thing` tagged from the world ontology + weighted. The
# department tag is canonical (FN_TAGS in one.ie/web/src/lib/in/spaces.ts); the
# build/infra lens is `builds` (tag `do-event`) — "engineering" is not yet a
# first-class fn:* department (a one-line FN_TAGS add, deferred — see tasks-plan.md).
# Design: text/tasks-plan.md.
DEPT_TAG = {
    "marketing": "marketing", "sales": "sales", "service": "service",
    "education": "education", "builds": "builds",
}
# Keyword → department vote. Domain-specific depts win ties over the catch-all
# `builds` (most substrate work is build work, so builds must not swallow everything).
DEPT_KW = {
    "marketing": ["marketing", "funnel", "campaign", "seo", "ads", "content",
                  "newsletter", "social", "landing", "copy", "brand", "tracking",
                  "analytics", "visitor", "lead", "showcase", "playbook"],
    "sales": ["sales", "billing", "payment", "pay", "checkout", "stripe", "pricing",
              "revenue", "invoice", "deal", "offer", "sell", "x402", "escrow", "crm",
              "people", "contact", "invitation", "invite", "client"],
    "service": ["service", "support", "chat", "inbox", "ticket", "booking", "help",
                "channels", "conversation", "memory", "message", "sanitize"],
    "education": ["education", "learning", "course", "tutorial", "skill", "certify",
                  "competence", "docs", "rag"],
    "builds": ["schema", "sdk", "api", "infra", "gateway", "auth", "roles", "workflow",
               "migration", "typedb", "mcp", "cli", "system", "ui", "frontend", "react",
               "astro", "deploy", "sync", "backup", "performance", "realtime", "do",
               "agent", "composio", "oo", "rubrics", "features", "boq", "signal"],
}
_TIE_ORDER = ["sales", "marketing", "service", "education", "builds"]


def classify_dept(slug, fm):
    """Vote a todo into one canonical department from its slug + title + tags."""
    hay = " ".join([slug, fm.get("title", "")] + fm.get("tags", [])).lower()
    hay = re.sub(r"[^a-z0-9]+", " ", hay)
    toks = set(hay.split())
    scores = {d: sum(1 for kw in kws if kw in toks) for d, kws in DEPT_KW.items()}
    best = max(scores.values())
    if best == 0:
        return "builds"  # no signal → it's substrate/build work
    winners = [d for d in _TIE_ORDER if scores[d] == best]
    return winners[0]


def task_weight(p):
    """1–100. New task = 50; proven work (momentum) + human priority earn more.
    Derived every run from learnings.md — never frozen into a frontmatter."""
    w = 50 + 10 * p["momentum"] + 3 * p["priority"]
    return max(1, min(100, round(w)))


def _task_tags(p):
    """A task's full tag set: its department tag + freeform topic tags."""
    return [DEPT_TAG[p["dept"]]] + [t for t in p["tags"] if t]


def tag_combinations(active):
    """Seed a weight for every co-occurring tag PAIR across active tasks.
    new pair = 50; pairs that recur, and pairs on proven (momentum>0) work, earn
    more. This weight is what a later cycle lets you STAKE on (see tasks-plan.md)."""
    from itertools import combinations
    count, proven = {}, {}
    for p in active:
        proven_hit = 1 if p["momentum"] > 0 else 0
        for a, b in combinations(sorted(set(_task_tags(p))), 2):
            count[(a, b)] = count.get((a, b), 0) + 1
            proven[(a, b)] = proven.get((a, b), 0) + proven_hit
    combos = []
    for pair, c in count.items():
        if c < 2:  # a pair seen once carries no signal yet — skip the long tail
            continue
        w = max(1, min(100, 50 + 5 * proven[pair] + 2 * (c - 1)))
        combos.append({"tags": list(pair), "weight": w,
                       "seen": c, "proven": proven[pair]})
    combos.sort(key=lambda x: (-x["weight"], -x["seen"]))
    return combos


def tasks_view(active):
    """Human-readable, department-grouped, weighted task list — the hero artifact,
    appended to todo.md. active = ready + blocked (open work; done is excluded)."""
    out = []
    LABEL = {"builds": "builds (engineering)", "marketing": "marketing",
             "sales": "sales", "service": "service", "education": "education"}
    out.append("  TASKS — every todo is a tagged, weighted signal (new=50 · proven earns more)")
    out.append("")
    for dept in ["builds", "marketing", "sales", "service", "education"]:
        rows = sorted([p for p in active if p["dept"] == dept],
                      key=lambda x: -x["weight"])
        if not rows:
            continue
        out.append(f"  ┌─ {DEPT_TAG[dept]:<14} {LABEL[dept]}")
        for p in rows:
            topics = " ".join(t for t in p["tags"][:4])
            sub = f"·{len(p['cycles'])} sub" if p["cycles"] else ""
            blk = " (blocked)" if p.get("waiting_on") else ""
            out.append(f"  │  {p['weight']:>3}  {p['slug']:<22} {topics}{sub}{blk}")
        out.append("  └─")
    combos = tag_combinations(active)
    if combos:
        out.append("")
        out.append("  TAG COMBINATIONS — seeded weights (the stakeable quantity → path-context.context-strength)")
        for c in combos[:15]:
            mark = " ✓proven" if c["proven"] else ""
            out.append(f"    {c['weight']:>3}  {c['tags'][0]} + {c['tags'][1]:<16} (×{c['seen']}{mark})")
    out.append("")
    out.append("  → signal(receiver:\"tasks:announce\", payload:task, tags:task.tags) — live; agents follow fn:*+topics, mark() moves weight")
    out.append("  seed: do-rank.py --tasks-json > text/tasks-seed.json · design: text/tasks-plan.md")
    return out


# Which doc-family suffixes an agent should load to work a task, in read order.
# The promise first (the contract), then how/what, then the cycles, then the spec.
_CONTEXT_SUFFIXES = ("", "-plan", "-features", "-ui", "-todo", "-docs")


def task_context_for(p):
    """Build the context a picked-up task carries — the keystone for auto-pickup.

    Returns (notes, context_docs):
      • notes       — human prose description → `thing.notes` (shown on the row / detail).
                      Fallback chain: title em-dash detail → outcome_asserts → title.
      • context_docs— the doc *stems* that exist for this slug → `thing.task-context`
                      (multi-valued, one per stem). An agent reads these files to know
                      HOW to do the work — literally "get context" for `/do <slug>`.
    """
    slug, title = p["slug"], (p.get("title") or p["slug"])
    # detail = the part after the em-dash / en-dash in the title ("Tasks — the loop…")
    m = re.match(r"^\s*(.+?)\s+[—–-]\s+(.+)$", title)
    detail = m.group(2).strip() if m else title.strip()
    asserts = (p.get("outcome_asserts") or "").strip()
    notes = detail
    if asserts and asserts.lower() not in detail.lower():
        notes = f"{detail}\n\nDone when: {asserts}" if detail else asserts
    docs = [f"{slug}{sfx}" for sfx in _CONTEXT_SUFFIXES
            if (TEXT / f"{slug}{sfx}.md").exists()]
    return notes, docs


def _gateway_key():
    """Same lookup as do-signal.sh's _gateway_key() — first file that has it wins.

    GATEWAY_API_KEY, not SERVER_SECRET: /api/ask/<receiver> decides isServiceCaller off
    env.GATEWAY_API_KEY (one.ie/web/src/pages/api/ask/[...receiver].ts). Presenting
    SERVER_SECRET there resolves to no service caller, no ctx.ownerSlug, and every
    tasks:* resolver answers {error:"workspace required"} — which this fetch used to
    swallow as an empty board, so the ranker silently ran file-only forever."""
    # UPDATE 2026-07-26 — prefer the WORLD key. The service-caller path described above is
    # real but fragile: it grants identity only when the receiver's request schema declares
    # `workspace`/`slug`, because /api/ask reads the nomination off validation.payload —
    # i.e. AFTER zod, which strips undeclared keys. tasks:mine and tasks:everywhere did not
    # declare it, so GATEWAY_API_KEY could never address them (fixed in 73dbeca7a, live only
    # after a one-prod deploy).
    #
    # A world key (`one-`/`osk_`) has no such dependency: verifyWorldKey resolves it to an
    # actual actor, so ctx.ownerSlug comes from the key itself and no nomination is needed.
    # It is what the MCP server has always used (ONEIE_API_KEY — packages/mcp/src/env.ts)
    # and it reads the board TODAY. Verified 2026-07-26: POST /api/ask/tasks:everywhere
    # returns ok:true with the world key and "forbidden: authentication required" with
    # GATEWAY_API_KEY. World key first; GATEWAY_API_KEY stays as the fallback.
    candidates = [os.environ.get("DO_ENV_FILE", "")] if os.environ.get("DO_ENV_FILE") else []
    candidates += [str(ROOT / "one.ie/web/.env"), str(ROOT / "one.ie/web/.secrets.generated.local"),
                   str(ROOT / "one.ie/web/.dev.vars")]
    # An explicit env var wins over any file — how a fleet/CI run injects its own identity.
    for var in ("ONEIE_API_KEY", "ONE_API_KEY", "GATEWAY_API_KEY"):
        if os.environ.get(var):
            return os.environ[var].strip()

    # Rank by KEY GENERATION, not by which file we happened to read first. Both `one-` and
    # legacy `osk_` authenticate (ok:true either way), but they resolve to DIFFERENT actors —
    # and on 2026-07-26 the `osk_` key in one.ie/web/.env resolved to an actor that could see
    # nothing, so every board read came back green-and-empty while the operator's own board
    # showed 11 open tasks. A green empty read is the worst failure this script has: it is
    # indistinguishable from "no work queued". So: modern world key > legacy > service secret.
    found = {"one-": "", "osk_": "", "gw": ""}

    def offer(tok):
        if tok.startswith("one-"):
            found["one-"] = found["one-"] or tok
        elif tok.startswith("osk_"):
            found["osk_"] = found["osk_"] or tok

    # The working credential lives in the MCP server config, not in any repo .env — that is
    # what the MCP tools authenticate with, and it is the one proven to read the board.
    # Read it in place; never copy key bytes into a repo file.
    mcp_cfg = Path.home() / ".claude.json"
    if mcp_cfg.exists():
        try:
            def walk(o):
                if isinstance(o, dict):
                    for k, v in o.items():
                        if k in ("ONEIE_API_KEY", "ONE_API_KEY") and isinstance(v, str) and v.strip():
                            offer(v.strip())
                        else:
                            walk(v)
                elif isinstance(o, list):
                    for v in o:
                        walk(v)
            walk(json.loads(mcp_cfg.read_text(errors="ignore")))
        except Exception:
            pass  # a malformed config must never break ranking

    for f in candidates:
        p = Path(f)
        if not p.exists():
            continue
        for line in p.read_text(errors="ignore").splitlines():
            for var in ("ONEIE_API_KEY=", "ONE_API_KEY="):
                if line.startswith(var):
                    offer(line.split("=", 1)[1].strip().strip('"'))
            if line.startswith("GATEWAY_API_KEY=") and not found["gw"]:
                found["gw"] = line.split("=", 1)[1].strip().strip('"')

    return found["one-"] or found["osk_"] or found["gw"]


# ── the cap, and whether it bit ───────────────────────────────────────────────
# Both board doors can hand back a PAGE and let it read as the board, and until
# 2026-09-13 neither caller here looked. The two doors do not mean the same thing
# by `total`, so they are not read the same way:
#   tasks:everywhere — `total` is "visible rows BEFORE the limit was applied"
#     (receivers.ts) and `truncated` is true when more exist. Both usable.
#   /api/things      — `total` is `tasks.length` of the slice it JUST CUT
#     (api/things/index.ts:396: "We do NOT claim a grand total we never
#     measured"). Only its `truncated` object is usable; printing its `total`
#     as a board total would be a NEW dishonesty, so it is deliberately dropped.
# What this records is what the last read can honestly say. A number that is a
# floor prints as a floor — `>=N` — because the rows past the cap were never seen.
LAST_BOARD_READ = {"door": "", "returned": 0, "total": None, "truncated": False, "why": ""}


def _note_board_read(door, returned, total=None, truncated=False, asked=None):
    """Record what the last board read can honestly say about its own cap. Called by
    EVERY board read, including the failing ones, so a stale note can never be read
    as this read's answer.

    `asked` is the limit WE SENT, and it is the load-bearing argument. Measured
    2026-09-13 against prod: `tasks:everywhere` returned exactly 200 rows — our own
    limit — with NO `total` and NO `truncated`, because those two fields are
    declared in receivers.ts and the deployed worker does not yet send them. So a
    cap that reports itself is a contract, not a fact, and trusting it would have
    printed a silent floor as a clean count: exactly the defect this exists to fix.
    A full page is structural evidence of a cap — it is derived from what we asked
    for, so it holds whether or not the door is honest yet."""
    truncated = bool(truncated)
    why = "the door reported a cap" if truncated else ""
    if not truncated and isinstance(asked, int) and asked > 0 and returned >= asked:
        truncated, why = True, f"the page came back FULL at our own limit of {asked}, and the door reported no cap"
    LAST_BOARD_READ.update(
        door=door, returned=returned,
        total=total if isinstance(total, int) else None,
        truncated=truncated, why=why,
    )
    return LAST_BOARD_READ


def board_count_phrase(n=None):
    """How many rows the last board read actually PROVES, as words.

    Uncapped → the count. Capped with a usable pre-limit total → `N of T (capped)`.
    Capped with no honest total → `>=N (capped)`. Never a bare count over a cap."""
    r = LAST_BOARD_READ
    n = r["returned"] if n is None else n
    if not r["truncated"]:
        return str(n)
    if isinstance(r["total"], int) and r["total"] > n:
        return f"{n} of {r['total']} (CAPPED — {r['total'] - n} row(s) never read)"
    return f">={n} (CAPPED — {r['why'] or 'the door returned a page, not the board'})"


def fetch_tasks_everywhere(timeout=None):
    """Board-origin open tasks — the substrate half of the ranked queue (tasks-do C2).

    Returns (rows, reason): rows is the raw `tasks:everywhere` list, reason is "" on a
    real answer or a SHORT diagnostic on any degrade. The ranker still never crashes and
    still falls back to file-only — but the caller can now tell "no key configured" from
    "auth rejected" from "the board is genuinely empty" (closed-loop rule: no silent
    returns). TASKS_EVERYWHERE marker below is what the demo gate greps for."""
    # tasks:everywhere is a four-phase read (actor groups → task scan → strength reads);
    # measured 10.9s against a warm dev server. The old 5s default meant that even a
    # correctly-authenticated ranker timed out every time — the auth bug was masking a
    # latency bug.
    #
    # Two budgets, because this script has two very different callers. The SessionStart
    # hook and the *-todo.md PostToolUse hook run it on EVERY session open and EVERY plan
    # edit; blocking those for 25s to enrich a ranking that degrades gracefully is a bad
    # trade, so hook-driven runs get a short budget and fall back to file-only. An explicit
    # queue read (/do next, the fleet) waits for the real answer.
    if timeout is None:
        default = "4" if os.environ.get("DO_RANK_HOOK") else "25"
        timeout = float(os.environ.get("DO_RANK_BOARD_TIMEOUT", default))
    secret = _gateway_key()
    if not secret:
        return [], "no GATEWAY_API_KEY in one.ie/web/.env"  # TASKS_EVERYWHERE: file-only fallback
    url = os.environ.get("DO_SIGNAL_URL", "https://one.ie") + "/api/ask/tasks:everywhere"
    # `workspace` is load-bearing, not decoration: /api/ask reads the service caller's
    # nominated slug off payload.slug|payload.workspace and that becomes ctx.ownerSlug.
    # Omit it and tasks:everywhere answers {ok:false,error:"forbidden: authentication
    # required"} because a service call carries no session actor of its own.
    ws = os.environ.get("CC_TASKS_WORKSPACE", "one")
    body = json.dumps({"data": {"limit": 200, "workspace": ws}}).encode()
    req = urllib.request.Request(
        url, data=body, method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {secret}",
            # Cloudflare answers the default urllib UA with 403 "error code: 1010"
            # (browser-integrity block) before the Worker ever runs. curl gets through,
            # which is why do-signal.sh never hit this and the ranker always did.
            "User-Agent": "one-do-rank/1.0 (+https://one.ie)",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:  # TASKS_EVERYWHERE: fetch failed — file-only fallback
        detail = "CF bot block (UA rejected)" if e.code == 403 else ""
        return [], f"HTTP {e.code}{' — ' + detail if detail else ''}"
    except Exception as e:  # TASKS_EVERYWHERE: fetch failed — file-only fallback
        return [], f"unreachable ({type(e).__name__})"
    if not isinstance(payload, dict):
        return [], "malformed response (not an object)"
    # /api/ask wraps every answer: {outcome, result:{ok, tasks}, signalId, receiver}.
    # Reading ok/tasks off the TOP level (as this did) makes even a good answer look
    # like a failure — the merge could never have fired, key or no key.
    inner = payload.get("result")
    inner = inner if isinstance(inner, dict) else payload
    if not inner.get("ok"):
        err = str(inner.get("error") or payload.get("error") or payload.get("outcome") or "unknown")
        hint = ""
        if "authentication" in err or err == "workspace required":
            # This used to read "local key may not match prod", which is WRONG and cost two
            # sessions chasing a secret that was never broken (73dbeca7a). A `forbidden` here
            # is almost never the key: /api/ask resolves a service caller's workspace from
            # validation.payload.slug|workspace — i.e. AFTER zod has run — and z.object()
            # strips any key the request schema doesn't declare. If the receiver's schema
            # omits `workspace`, `nominated` is undefined, ctx.ownerSlug stays empty, and you
            # get this exact error no matter which key you present. Browser calls are immune
            # (locals.slug supplies the workspace), so it fails only for the harness.
            hint = (
                " — check the RECEIVER SCHEMA before the key: /api/ask reads the nominated"
                " workspace off validation.payload (post-zod), so a receiver whose request"
                " schema omits `workspace` can never be addressed by a service caller."
                " Verify the key separately against a receiver that DOES declare it."
            )
        return [], f"receiver refused: {err}{hint}"
    rows = inner.get("tasks", [])
    if not isinstance(rows, list):
        _note_board_read("tasks:everywhere", 0)
        return [], "malformed response (tasks is not a list)"
    # The receiver declares both (receivers.ts § tasks:everywhere) and this dropped
    # them: a 595-row queue answered as 200 and read as the whole board.
    _note_board_read("tasks:everywhere", len(rows), inner.get("total"), inner.get("truncated"), asked=200)
    # tasks:everywhere answers "workspaces I BELONG TO" — assignment/follow/ownership. A key
    # whose actor belongs to nothing (the MCP bootstrap agent is one) gets ok:true and an
    # empty list while the operator's own board is full. That green-empty read is worse than
    # a refusal: it is indistinguishable from "no work queued", and it is exactly how the
    # ranker ran file-only for months. So an empty answer is not accepted as the final word —
    # fall back to the WORKSPACE BOARD read, which is what /u/<slug>/tasks and the MCP
    # tasks_list tool both make (GET /api/things?type=task&workspace=…). Verified 2026-07-26:
    # everywhere → 0 rows, board → 11.
    if not rows:
        board, why = fetch_workspace_board(timeout=timeout)
        if board:
            return board, ""
        if why:
            return [], f"everywhere empty; board read also failed ({why})"
    return rows, ""


def fetch_workspace_board(timeout=None, workspace=None):
    """The workspace board — every task on it, not just what this actor subscribes to.

    Same read the /u/<slug>/tasks page and the MCP tasks_list tool make. Returns
    (rows, reason) on the same contract as fetch_tasks_everywhere: no silent returns."""
    if timeout is None:
        timeout = float(os.environ.get("DO_RANK_BOARD_TIMEOUT", "25"))
    secret = _gateway_key()
    if not secret:
        return [], "no world key"
    ws = workspace or os.environ.get("CC_TASKS_WORKSPACE", "one")
    base = os.environ.get("DO_SIGNAL_URL", "https://one.ie")
    q = urllib.parse.urlencode({"type": "task", "workspace": ws, "status": "open", "limit": 200})
    req = urllib.request.Request(
        f"{base}/api/things?{q}", method="GET",
        headers={
            "Authorization": f"Bearer {secret}",
            # Cloudflare 403s the default urllib UA before the Worker runs.
            "User-Agent": "one-do-rank/1.0 (+https://one.ie)",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return [], f"HTTP {e.code}"
    except Exception as e:
        return [], f"unreachable ({type(e).__name__})"
    rows = payload.get("things") if isinstance(payload, dict) else None
    if not isinstance(rows, list):
        _note_board_read("/api/things", 0)
        return [], "malformed response (things is not a list)"
    # `limit=200` above is a HARD cap and this read is the ranker's last word on
    # what is on the board. /api/things reports its own cap as a `truncated`
    # OBJECT (absent = nothing was cut) — truthy is the whole test. Its `total` is
    # the length of the slice, so it is NOT passed on as a board total.
    _note_board_read("/api/things", len(rows), None, bool(payload.get("truncated")), asked=200)
    return rows, ""


def board_ask(receiver, data, timeout=None):
    """POST one receiver through the same door fetch_tasks_everywhere uses, with the
    /api/ask envelope unwrapped. Returns (inner, reason) — never a silent empty."""
    if timeout is None:
        timeout = float(os.environ.get("DO_RANK_BOARD_TIMEOUT", "25"))
    secret = _gateway_key()
    if not secret:
        return None, "no GATEWAY_API_KEY in one.ie/web/.env"
    url = os.environ.get("DO_SIGNAL_URL", "https://one.ie") + "/api/ask/" + receiver
    req = urllib.request.Request(
        url, data=json.dumps({"data": data}).encode(), method="POST",
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {secret}",
            # Cloudflare 403s the default urllib UA before the Worker runs.
            "User-Agent": "one-do-rank/1.0 (+https://one.ie)",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detail = "CF bot block (UA rejected)" if e.code == 403 else ""
        return None, f"HTTP {e.code}{' — ' + detail if detail else ''}"
    except Exception as e:
        return None, f"unreachable ({type(e).__name__})"
    if not isinstance(payload, dict):
        return None, "malformed response (not an object)"
    inner = payload.get("result")
    inner = inner if isinstance(inner, dict) else payload
    if not inner.get("ok"):
        return None, str(inner.get("error") or payload.get("outcome") or "unknown")
    return inner, ""


# What triage treats as already-shaped. A row whose prose goal opens with this has
# a one-line check that proves it done, which is the whole output of a triage pass.
TRIAGED_PREFIX = "accept:"


def fetch_untriaged(workspace=None, pages=None, timeout=None):
    """Every OPEN row whose notes do NOT begin `accept:` — the triage queue, read
    deterministically.

    Why this is a script and not a prompt: triage.js used to hand a model the ONE
    LINE `--board-check` prints and ask it for `{id,title,notes}[]`. That line
    carries no rows, so the only possible answers were an invented list or an empty
    one, and the only guard was the words "Do not invent rows." A fact the harness
    needs gets a script (.claude/CLAUDE.md).

    ONE door — tasks:board — followed to the LAST page. `nextCursor` is present iff
    more rows match, so stopping at page one reports a page as the board; that is
    the exact failure this mode exists to refuse. `include:["notes"]` is required:
    a compact row carries no notes and the accept: test IS the filter. There is no
    server-side notes filter, so the test runs here, over every page.

    `truncated` is a DIFFERENT cut from paging — it means the snapshot itself hit a
    budget, so `total` is only a floor. It is carried through verbatim."""
    ws = workspace or os.environ.get("CC_TASKS_WORKSPACE", "one")
    # A ceiling on the cursor walk so a runaway board cannot loop forever. 20 pages
    # x 500 rows is 10,000 — far past any real board, and reported when it bites.
    pages = int(pages or os.environ.get("DO_RANK_UNTRIAGED_PAGES", "20"))
    out, cursor, total, truncated, seen, page = [], None, None, None, 0, 0
    while page < pages:
        req = {"workspace": ws, "status": "open", "view": "rows",
               "include": ["notes"], "limit": 500, "sort": "priority"}
        if cursor:
            req["cursor"] = cursor
        inner, reason = board_ask("tasks:board", req, timeout=timeout)
        if reason:
            # A failure mid-walk leaves a PARTIAL answer, and it must never read as
            # the whole board: truncated=True is the honest state, always a 3-tuple.
            _note_board_read("tasks:board", seen, total, True)
            return out, f"page {page + 1}: {reason}", {
                "workspace": ws, "scanned": seen, "total": total,
                "truncated": truncated or None, "pagesExhausted": True, "pages": page,
            }
        rows = inner.get("tasks")
        rows = rows if isinstance(rows, list) else []
        if total is None and isinstance(inner.get("total"), int):
            total = inner["total"]
        if inner.get("truncated") and truncated is None:
            truncated = inner["truncated"]
        seen += len(rows)
        for r in rows:
            notes = str(r.get("notes") or "")
            if notes.lstrip().lower().startswith(TRIAGED_PREFIX):
                continue
            out.append({"id": r.get("tid", ""), "title": r.get("name", ""),
                        "notes": notes, "priority": r.get("priority", 0),
                        "assignee": r.get("assignee", ""), "tags": r.get("tags") or []})
        page += 1
        cursor = inner.get("nextCursor")
        if not cursor:
            break
    # Two independent cuts, reported separately: `truncated` = the snapshot was
    # capped (total is a floor); `pagesExhausted` = WE stopped following cursors.
    # `asked` is the third and it needs no cooperation from the door: a LAST page
    # that came back full with no nextCursor is a cap that did not announce itself
    # (measured on tasks:everywhere the day this was written — it returned exactly
    # our limit and declared neither field).
    pages_exhausted = bool(cursor)
    _note_board_read("tasks:board", seen, total, bool(truncated) or pages_exhausted,
                     asked=None if cursor else 500 * page or None)
    return out, "", {"workspace": ws, "scanned": seen, "total": total,
                     "truncated": truncated or None, "pagesExhausted": pages_exhausted,
                     "pages": page, "capNote": LAST_BOARD_READ["why"] or None}


def board_task_entry(row):
    """Shape one tasks:everywhere row as a plan-like dict — the same keys tasks_view()/
    tasks_seed() already read off a local todo's `plans[slug]` entry, so a board-created
    task renders in the SAME ranked list with no second code path."""
    tags = [t for t in (row.get("tags") or []) if not t.startswith(("workspace:", "@"))]
    slug_tag = next((t[len("slug:"):] for t in tags if t.startswith("slug:")), "")
    slug = slug_tag or str(row.get("id", "")).split(":", 1)[-1]
    dept = classify_dept(slug, {"title": row.get("name", ""), "tags": tags})
    weight = row.get("weight")
    weight = max(1, min(100, round(weight))) if isinstance(weight, (int, float)) else 50
    return {
        "slug": slug, "title": row.get("name", slug), "outcome_asserts": "",
        "tier": "?", "tags": tags, "priority": row.get("priority", 0) or 0,
        "depends_on": [], "done_boxes": 0, "total_boxes": 0, "is_done": False,
        "gated": False, "strategic": 0, "proximity": 0.0, "momentum": 0.0,
        "_dirs": [], "cycles": [], "dept": dept, "leverage": 0,
        "weight": weight, "waiting_on": [], "_board_origin": True,
    }


def merge_board_tasks(active, plans):
    """Merge tasks:everywhere rows into the local `active` list. A board row carrying a
    `slug:` tag that matches a local todo file is authoritative — the local file entry is
    dropped (task-paths.json becomes a cache, not a second source of truth); a row with no
    local match is a pure board-created task and is simply added. Empty/failed fetch is a
    no-op — file-only ranking, unchanged."""
    rows, reason = fetch_tasks_everywhere()
    door = LAST_BOARD_READ["door"] or "tasks:everywhere"
    if not rows:
        why = reason or "board is empty (0 open tasks)"
        print(f"[do-rank] {door}: 0 rows — {why} — file-only fallback", file=sys.stderr)
        return active
    board_entries = [board_task_entry(r) for r in rows]
    matched_slugs = {e["slug"] for e in board_entries if e["slug"] in plans}
    # The door is named because the fallback inside fetch_tasks_everywhere can
    # answer from /api/things, and this line said "tasks:everywhere" either way.
    # The count is a FLOOR whenever that door capped — say so, don't round it off.
    print(f"[do-rank] {door}: merged {board_count_phrase(len(board_entries))} row(s), "
          f"{len(matched_slugs)} superseding a local todo", file=sys.stderr)
    return [p for p in active if p["slug"] not in matched_slugs] + board_entries


def tasks_seed(active):
    """The same data shaped to the substrate, so testnet seeding is a LOAD not a
    reshape: task→thing+tag, combo-weight→path-context.context-strength, payload→signal."""
    return {
        "version": "testnet-seed-1",
        "weightModel": {
            "new": 50, "min": 1, "max": 100,
            "formula": "clamp(50 + 10*momentum + 3*priority, 1, 100)",
            "basis": "momentum = recency-weighted rubric-scaled closes from learnings.md",
        },
        "departments": DEPT_TAG,
        "tasks": [
            {
                "tid": f"task:{p['slug']}",
                "thingType": "task",
                "name": p["title"] or p["slug"],
                # context = what the task IS + which docs load it, so an agent (or a
                # human) that picks it up knows the goal and where to read. notes →
                # thing.notes (prose); contextDocs → thing.task-context (doc stems).
                "notes": task_context_for(p)[0],
                "contextDocs": task_context_for(p)[1],
                "tag": _task_tags(p),
                "taskStatus": "blocked" if p.get("waiting_on") else "open",
                "taskPriority": round(p["priority"] / 3, 2),
                "weight": p["weight"],
                "dept": p["dept"],
                "subtasks": [
                    {"tid": f"task:{p['slug']}:C{c}", "thingType": "task",
                     "tag": _task_tags(p), "taskStatus": "open", "weight": 50}
                    for c in p["cycles"]
                ],
                "waitingOn": p.get("waiting_on", []),
            }
            for p in active
        ],
        "tagCombinations": [
            {"tags": c["tags"], "contextStrength": c["weight"],
             "seen": c["seen"], "proven": c["proven"]}
            for c in tag_combinations(active)
        ],
        "signal": {
            "shape": "signal(sender, receiver, payload, tags)",
            "receiver": "tasks:announce",
            "routing": "tag-intersection fan-out (one.ie/web/src/lib/world-receivers.ts) + subscriptions:register (declared, not yet persisted)",
            "note": "tasks:* receivers are LIVE (one.ie/web/src/lib/resolvers/tasks.ts) — create/claim/status/link/launch and the announce fan-out. This seed is the bulk-load shape; weights here are what a stake moves.",
        },
    }


def pack_waves(ready):
    """Greedily pack the score-sorted ready queue into file-disjoint fleet waves.

    Each wave is a set of plans whose deliverable dirs don't overlap — the fleet
    can run a whole wave in parallel without one plan clobbering another's tree.
    A plan joins the first wave it doesn't collide with (preserves score order
    within a wave). Plans with NO declared deliverables are NOT packed — the fleet
    would treat them as conflict-free and parallelize them blindly, so they're
    returned separately as a hazard list to be scoped before fleeting.
    """
    waves, unscoped = [], []
    for p in ready:
        dirs = p.get("_dirs", set())
        if not dirs:
            unscoped.append(p["slug"])
            continue
        for w in waves:
            if not (w["dirs"] & dirs):
                w["slugs"].append(p["slug"])
                w["dirs"] |= dirs
                break
        else:
            waves.append({"slugs": [p["slug"]], "dirs": set(dirs)})
    return waves, unscoped


def parse_frontmatter(text):
    """Minimal YAML frontmatter parse — no pyyaml dependency."""
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    fm = {}
    if not m:
        return fm
    body = m.group(1)
    # outcome_asserts is a single-line quoted string that describes what "done" looks
    # like in the reader's language — the richest one-line description a task can carry.
    # Pulled here (not just title/tier/mode/priority) so tasks_seed can hand an agent
    # real context: what the task IS, not just its name. See § "context on task".
    for key in ("title", "tier", "mode", "priority", "outcome_asserts"):
        km = re.search(rf"^{key}:\s*(.+)$", body, re.MULTILINE)
        if km:
            val = km.group(1)
            val = re.sub(r"\s+#.*$", "", val)  # strip trailing YAML inline comment
            fm[key] = val.strip().strip('"').strip("'")
    # list fields: tags / depends_on — inline [a, b] form
    for key in ("tags", "depends_on"):
        km = re.search(rf"^{key}:\s*\[(.*?)\]", body, re.MULTILINE)
        if km:
            items = [x.strip().strip('"').strip("'") for x in km.group(1).split(",")]
            fm[key] = [x for x in items if x]
        else:
            fm[key] = []
    return fm


def is_gated(text):
    """A todo with a `build_gate:` frontmatter field is human-approval-required and is
    EXCLUDED from ready/--top/fleet — so a blanket `do-fleet.sh --top N --go` (or do-auto
    --next-cycle) can NEVER auto-launch a gated cycle (e.g. the real-money x402-settlement,
    build_gate'd in ef92bd64). Detection is the presence of a non-empty build_gate line
    INSIDE the `---` frontmatter (a build_gate mention in the body never gates). Scoped to
    frontmatter because `parse_frontmatter` only parses an allowlist (title/tier/mode/
    priority/tags/depends_on) — build_gate is not in it, so fm.get('build_gate') is always
    None; we read the raw frontmatter instead. Excluded from ready, NOT deleted: a human who
    approves still runs it by explicit slug (`/do <slug>`), which never reads --top."""
    m = re.match(r"^---\n(.*?)\n---", text, re.DOTALL)
    body = m.group(1) if m else ""
    return bool(re.search(r"(?m)^build_gate:\s*\S", body))


def checkbox_state(text):
    done = len(re.findall(r"^\s*- \[[xX]\]", text, re.MULTILINE))
    openb = len(re.findall(r"^\s*- \[ \]", text, re.MULTILINE))
    return done, openb


# ── Toxic classifier — the `guard` for the task queue ────────────────────────
# Mirrors one.ie/web/src/lib/ingress.ts classify(): a cold+stale todo carrying a noise
# signal is QUARANTINED (excluded from the live queue), not merely down-weighted —
# score-0 plans (features/crx/people) can't be faded below path_momentum's 0 floor, so
# exclusion is the ONLY way to remove them. NECESSARY gate (both must hold): momentum==0
# (no close in the learnings window — cold) AND stale (untouched past STALE_DAYS by the
# repo's own HEAD clock — engine.md Rule 2's external-deadline exception, used ONLY behind
# the structural momentum gate). A warm plan (momentum>0, e.g. analytics) or a fresh one
# (committed today, e.g. speed-channels) can NEVER be toxic, by construction. A large
# open-box count is never sufficient on its own — that protects the most valuable plans,
# which are the warm ones with the most open work. Both protections are locked by selftest.
STALE_DAYS = 7
MEGA_OPEN = 80
MEGA_PROXIMITY = 0.15


def is_toxic(momentum, done, openb, proximity, stale, has_deliverables=False):
    """Reasons a todo is toxic (empty list ⇒ not toxic). Pure — unit-testable without git.
    Necessary: cold (momentum==0) AND stale. Then any sufficient signal fires.
    `empty` requires NO deliverables too: a plan that declares a `deliverables:` block is a
    real build plan, not a stub — even if its checkboxes are in a form the ranker can't parse
    (e.g. foundation-ui's backtick `[ ]`). Without this guard the hourly loop would fade a
    real in-flight plan once it crossed STALE_DAYS — a silent, unattended false-positive."""
    if momentum > 0 or not stale:
        return []
    reasons = []
    if done + openb == 0 and not has_deliverables:
        reasons.append("empty")           # no checkbox AND no deliverables — a doc/stub, not a plan
    if done == 0 and openb > 0:
        reasons.append("zero-progress")   # has work, never ticked one box
    if openb > MEGA_OPEN and proximity < MEGA_PROXIMITY:
        reasons.append("mega-stale")      # hundreds of boxes, <15% done — never converges
    return reasons


def repo_now():
    """The repo's 'now' = HEAD commit unix time. Like learnings.md's ref=max(date), 'now'
    is the newest commit, not the wall clock (engine.md Rule 2). None on git failure."""
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "log", "-1", "--format=%ct"],
                             capture_output=True, text=True, timeout=5)
        ts = out.stdout.strip()
        return int(ts) if ts else None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def days_since_commit(path, now_ct):
    """Days since `path`'s last commit, measured against repo HEAD time (now_ct).
    Untracked / never-committed → None ⇒ NOT stale: a brand-new uncommitted file is the
    opposite of abandoned (staleness measures 'committed then left to rot', not 'never
    committed'). now_ct None / git failure → None too (no regression). Lazy: call only
    where staleness actually gates a decision (momentum==0 todos · frontier plans)."""
    if now_ct is None:
        return None
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "log", "-1", "--format=%ct", "--", str(path)],
                             capture_output=True, text=True, timeout=5)
        ts = out.stdout.strip()
        if not ts:
            return None
        return (now_ct - int(ts)) // 86400
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def toxic_reasons(p, now_ct):
    """Toxic reasons for a built plan dict. Lazy git staleness — only when momentum==0,
    so the live queue's ~10 cold candidates trigger git, not all 196 todos."""
    if p["momentum"] > 0:
        return []
    days = days_since_commit(TEXT / f"{p['slug']}-todo.md", now_ct)
    stale = days is not None and days >= STALE_DAYS
    openb = p["total_boxes"] - p["done_boxes"]
    has_deliverables = bool(p.get("_dirs"))
    return is_toxic(p["momentum"], p["done_boxes"], openb, p["proximity"], stale, has_deliverables)


# ── fade — the decay verb for the task layer (C2) ────────────────────────────
def _fade_one(strength, resistance, rate):
    """One asymmetric decay step. Matches world.fade (engine.md): RESISTANCE DECAYS 2×
    FASTER than strength — earned weight (good trails) persists, penalties (warnings) are
    forgiven quickly so a warned plan can recover. Pure — selftest checks this without IO."""
    r = max(0.0, min(1.0, rate))
    return round(strength * (1 - r), 4), round(max(0.0, resistance * (1 - 2 * r)), 4)


def fade_paths(rate=0.1):
    """The `fade` verb for the task layer — the genuinely-hourly action. Decays LIVE path
    weight: `strength` (from --mark / agent picks) cools so an old live mark drifts down
    unless renewed; `resistance` heals 2× faster (forgiveness). `closed` is NOT touched —
    it's reconciled from learnings.md by --sync-closes every render and already fades via
    momentum_score's 30-day recency window, so fading it here would just be overwritten.
    Returns the count of entries whose weight actually moved."""
    paths = load_task_paths()
    touched = 0
    for e in paths.values():
        s0, r0 = float(e.get("strength", 0)), float(e.get("resistance", 0))
        s1, r1 = _fade_one(s0, r0, rate)
        if s1 != s0 or r1 != r0:
            e["strength"], e["resistance"] = s1, r1
            touched += 1
    TASK_PATHS.write_text(json.dumps(paths, indent=2, sort_keys=True) + "\n")
    return touched


# ── frontier — what's next past every armed todo (C4) ────────────────────────
def frontier(now_ct, log):
    """Designed-but-unarmed plans: `*-plan.md` slugs with NO `*-todo.md`. The edge past the
    live queue — 'what's next after every todo is done or faded'. Two kinds are counted but
    hidden, leaving only the genuine edge: (1) CLOSED — a plan whose close is recorded in
    learnings.md (reuses plan_closed, the same close-rule the todo walk trusts — a documented-
    shipped plan is built work, not a next move); (2) STALE — untouched ≥STALE_DAYS (the 2026
    bulk-import backlog, import-noise). The rest rank by strategic pull (north-star keyword
    weight), freshest first. Returns (fresh_rows[(strat, days, slug, title)], stale_count,
    closed_count). The substrate's frontiers_global (TypeDB hypotheses) is the beyond."""
    todo_slugs = {f.name[: -len("-todo.md")] for f in TEXT.glob("*-todo.md")}
    fresh, stale, closed = [], 0, 0
    for f in sorted(TEXT.glob("*-plan.md")):
        slug = f.name[: -len("-plan.md")]
        if slug in EXCLUDE or slug in todo_slugs:
            continue
        if plan_closed(slug, log):        # close recorded ⇒ shipped, not an edge (same rule as the todo walk)
            closed += 1
            continue
        days = days_since_commit(f, now_ct)
        if days is not None and days >= STALE_DAYS:
            stale += 1
            continue
        fm = parse_frontmatter(f.read_text(errors="ignore"))
        fresh.append((strategic_score(slug, fm), days if days is not None else 0,
                      slug, fm.get("title", "")[:48]))
    fresh.sort(key=lambda x: (-x[0], x[1], x[2]))
    return fresh, stale, closed


def _slug_matcher(slug):
    r"""Match the slug as a WHOLE token. \b treats '-' as a boundary, so \binbox\b
    wrongly matches 'inbox-simple' — cross-contaminating slug families (inbox*,
    roles*, chat*) in both momentum and done-detection, silently dropping real
    work. Forbid an adjacent word char OR hyphen on either side."""
    return re.compile(rf"(?<![\w-]){re.escape(slug)}(?![\w-])")


# A learnings line that records a PLAN-level close (not just a cycle). Covers the
# real formats: "· <slug> PLAN · CLOSE", "· <slug> · plan · …", "all N cycles
# shipped/closed", "kill-switch … GREEN/exits 0". Matched in the line's subject zone.
_CLOSE_MARKER = re.compile(
    r"\bPLAN\b.*\bCLOSE\b"
    r"|\bplan\b.*\bclose\b"
    r"|all \d+ cycles (?:shipped|closed)"
    r"|kill-switch.*(?:GREEN|exits 0|green)",
    re.IGNORECASE,
)


def plan_closed(slug, log):
    """True if learnings.md records a PLAN-level close for this slug.

    Per-slug + close-marker, so it's robust to the line format that the old
    regex choked on (e.g. 'visitor-to-people PLAN · CLOSE'). Subject-zone match
    avoids common-word false positives, same as momentum.
    """
    pat = _slug_matcher(slug)
    for _d, _r, ln in log:
        segs = ln.split("·")
        subject = " ".join(segs[1:3]) if len(segs) > 1 else ln
        if pat.search(subject) and _CLOSE_MARKER.search(ln):
            return True
    return False


def strategic_score(slug, fm):
    haystack = " ".join([slug, fm.get("title", "")] + fm.get("tags", [])).lower()
    return sum(w for kw, w in NORTH_STAR.items() if kw in haystack)


def load_learnings_log():
    """Every dated cycle line: (date, rubric|None, line). The loop's own output.

    MIGRATION TARGET: today this reads learnings.md (the file the loop appends to).
    The end-state reads path.strength / rubric-* attributes from TypeDB — the
    substrate the verbs already write. momentum() is the seam: swap this loader,
    the scoring stays. (text/orchestrator-plan.md · the Sense→Close seam.)
    """
    from datetime import date
    log = []
    if not LEARNINGS.exists():
        return log, None
    ref = None
    for ln in LEARNINGS.read_text(errors="ignore").splitlines():
        dm = re.match(r"-\s*(\d{4})-(\d{2})-(\d{2})", ln)
        if not dm:
            continue
        try:
            d = date(int(dm.group(1)), int(dm.group(2)), int(dm.group(3)))
        except ValueError:
            continue
        rm = re.search(r"rubric[=≈~]\s*(\d?\.\d+)", ln)
        rub = float(rm.group(1)) if rm else None
        log.append((d, rub, ln))
        ref = d if ref is None or d > ref else ref
    # newest entry = "now" → recency is relative + deterministic (no wall clock)
    ref = max((d for d, _, _ in log), default=None)
    return log, ref


def load_task_paths():
    """The local path-strength store: { 'task:<slug>': {strength, resistance, traversals} }.
    Mirror of the substrate `path` for the task layer. Missing/corrupt → empty (no regression)."""
    try:
        return json.loads(TASK_PATHS.read_text())
    except (FileNotFoundError, ValueError):
        return {}


def path_momentum(slug, paths):
    """Momentum from path strength (the closed-loop source), on the same 0–3 scale as
    learnings momentum so scoring is unchanged. Strength has three writers, all summed:
      • `closed`  — reconciled from learnings.md closes by --sync-closes (idempotent)
      • `strength`/`resistance` — LIVE marks (agent picks, manual --mark)
      • `prod.strength`/`prod.resistance` — production outcomes pulled in by
        outcome-pull.ts (text/self-improving-outcome.md): a settled promise, a /do
        cycle that really closed in a live workspace, or a graded delivery. Full
        overwrite per pull, never accumulated — see outcome-pull.ts's merge law.
    net = closed + strength − resistance + prod.strength − prod.resistance. Returns
    None when this slug has no path yet → caller falls back to learnings.md
    (bootstrap for never-closed, never-marked work)."""
    e = paths.get(f"task:{slug}")
    if not e:
        return None
    prod = e.get("prod") or {}
    net = max(0.0, float(e.get("closed", 0)) + float(e.get("strength", 0)) - float(e.get("resistance", 0))
              + float(prod.get("strength", 0)) - float(prod.get("resistance", 0)))
    return round(min(3.0, net / 2.0), 2)


def sync_closes(log, ref):
    """Reconcile the path store's `closed` field from learnings.md closes — the close
    SIGNAL feeding path strength, idempotent (recompute, never increment, so the hook
    can fire it on every learnings edit without double-counting). Live `strength`/
    `resistance` from --mark are preserved untouched. learnings momentum is in 0–3
    units; ×2 puts it in strength units (so path_momentum returns the same number for a
    closed-but-unmarked slug — no regression — and live marks stack on top)."""
    paths = load_task_paths()
    touched = 0
    for f in sorted(TEXT.glob("*-todo.md")):
        slug = f.name[: -len("-todo.md")]
        if slug in EXCLUDE:
            continue
        closed = round(momentum_score(slug, log, ref) * 2.0, 2)
        key = f"task:{slug}"
        if closed <= 0 and key not in paths:
            continue
        e = paths.get(key) or {"strength": 0.0, "resistance": 0.0, "traversals": 0}
        if e.get("closed") != closed:
            e["closed"] = closed
            touched += 1
        paths[key] = e
    TASK_PATHS.write_text(json.dumps(paths, indent=2, sort_keys=True) + "\n")
    return touched


def mark_task(slug, outcome, amount):
    """The `mark`/`warn` verb for the task layer — closes the loop by moving path strength.
    success → strength += amount ; failure → resistance += amount. traversals always ++.
    Writes the local path tier; the next `--tasks`/queue run reads it. Returns the entry."""
    paths = load_task_paths()
    key = f"task:{slug}"
    e = paths.get(key) or {"strength": 0.0, "resistance": 0.0, "traversals": 0, "closed": 0.0}
    if outcome == "failure":
        e["resistance"] = round(float(e.get("resistance", 0)) + amount, 3)
    else:
        e["strength"] = round(float(e.get("strength", 0)) + amount, 3)
    e["traversals"] = int(e.get("traversals", 0)) + 1
    paths[key] = e
    TASK_PATHS.write_text(json.dumps(paths, indent=2, sort_keys=True) + "\n")
    return e


def momentum_score(slug, log, ref):
    """How warm + proven this plan is, from the loop's own closes.

    Recency-weighted count of cycle lines mentioning the slug, scaled by their
    rubric. Recent high-rubric closes ⇒ warm, proven, cheap to continue ⇒ pull
    the fleet toward finishing it rather than starting cold. Capped at 3 to sit
    on the same scale as the other signals. Zero if the plan has no closes.
    """
    if not log or ref is None:
        return 0.0
    pat = _slug_matcher(slug)
    score = 0.0
    for d, rub, ln in log:
        # Match only the SUBJECT zone (the "DATE · slug · phase ·" head), not the
        # prose tail — else common-word slugs ("clean", "people") false-match
        # adjectives like "clean pattern" and inflate momentum. learnings.md puts
        # the slug right after the date, before the 2nd separator.
        segs = ln.split("·")
        subject = " ".join(segs[1:3]) if len(segs) > 1 else ln
        if not pat.search(subject):
            continue
        days = (ref - d).days
        if days >= 30:            # older than the window contributes nothing
            continue
        recency = 1.0 - days / 30.0
        quality = rub if rub is not None else 0.75
        score += recency * quality
    return round(min(3.0, score), 2)


# The eight-field close-line vector (text/rubrics.md § Code Rubric — eight dimensions).
# Fixed field order, self-labeling short codes → the full dimension name do-rank prints.
DIM_FIELDS = [
    ("sec", "security"),
    ("simp", "simplicity"),
    ("struct", "structure"),
    ("speed", "speed"),
    ("integ", "integration"),
    ("reuse", "code-reuse"),
    ("test", "test-coverage"),
    ("ux", "ux"),
]
_VECTOR_RE = re.compile(
    r"\[sec(\d*\.\d+)\s+simp(\d*\.\d+)\s+struct(\d*\.\d+)\s+speed(\d*\.\d+)\s+"
    r"integ(\d*\.\d+)\s+reuse(\d*\.\d+)\s+test(\d*\.\d+)\s+ux(\d*\.\d+)\]"
)


def parse_vector(line):
    """The eight-field close-line vector, if present: {dim_name: float}. None for a
    close-line with no vector (every close before the self-improving-ratchet plan —
    back-compat: those still count toward the composite trend only)."""
    m = _VECTOR_RE.search(line)
    if not m:
        return None
    return {name: float(v) for (_short, name), v in zip(DIM_FIELDS, m.groups())}


def trailing_median(values):
    """Median of a list of floats; 0.0 for an empty list (no prior closes yet)."""
    if not values:
        return 0.0
    s = sorted(values)
    n = len(s)
    mid = n // 2
    return s[mid] if n % 2 else round((s[mid - 1] + s[mid]) / 2.0, 4)


def _slope(points):
    """Least-squares slope of value-over-day-offset. 0.0 with fewer than 2 points
    (insufficient data to trend — printed as flat, not a false rising/slipping)."""
    n = len(points)
    if n < 2:
        return 0.0
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    mx = sum(xs) / n
    my = sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    den = sum((x - mx) ** 2 for x in xs)
    return round(num / den, 4) if den else 0.0


def ratchet_trend(log, ref, window_days=30):
    """Per-dimension trend over the momentum module's own recency window — reuses
    load_learnings_log's ledger, no second parser. Returns (dims, composite):
      dims      — [(short, name, last_value|None, slope, 'rising'|'flat'|'slipping'), ...]
                  in DIM_FIELDS order; last_value is None until the first vectored close.
      composite — (last_composite|None, trailing_median, 'rising'|'flat'|'slipping') —
                  the gate C3 reads: composite-ratchet = composite ≥ max(0.65, median).
    """
    if ref is None:
        return [], (None, None, "flat")

    window = [(d, rub, parse_vector(ln)) for d, rub, ln in log if (ref - d).days < window_days]
    window.sort(key=lambda t: t[0])  # oldest → newest, so slope reads left-to-right in time
    composites = [rub for _d, rub, _v in window if rub is not None]
    vectored = [(d, rub, v) for d, rub, v in window if v is not None]

    dims = []
    for short, name in DIM_FIELDS:
        if not vectored:
            dims.append((short, name, None, 0.0, "flat"))
            continue
        origin = vectored[0][0]
        pts = [((d - origin).days, v[name]) for d, _rub, v in vectored]
        slope = _slope(pts)
        last_val = pts[-1][1]
        label = "rising" if slope > 0.01 else "slipping" if slope < -0.01 else "flat"
        dims.append((short, name, last_val, slope, label))

    last_composite = vectored[-1][1] if vectored else (composites[-1] if composites else None)
    median = trailing_median(composites)
    if last_composite is None or not composites:
        direction = "flat"
    elif last_composite > median:
        direction = "rising"
    elif last_composite < median:
        direction = "slipping"
    else:
        direction = "flat"
    return dims, (last_composite, median, direction)


def selftest():
    """Lock the three bugs found building the momentum gate. Pure, no mocks,
    real learnings-shaped strings. Run: do-rank.py --selftest"""
    from datetime import date
    ref = date(2026, 6, 20)
    fails = []

    def check(name, cond):
        if not cond:
            fails.append(name)

    # 1. hyphen boundary: slug 'inbox' must NOT match 'inbox-simple'
    check("hyphen: inbox≠inbox-simple", not _slug_matcher("inbox").search("inbox-simple"))
    check("hyphen: inbox==inbox", bool(_slug_matcher("inbox").search("· inbox · plan")))

    # 2. plan_closed: detects 'PLAN · CLOSE' format, scoped to the right slug
    vlog = [(ref, None, "- 2026-06-17 · visitor-to-people PLAN · CLOSE · all 5 cycles shipped; kill-switch exits 0")]
    check("close: visitor-to-people DONE", plan_closed("visitor-to-people", vlog))
    check("close: inbox NOT marked by inbox-simple",
          not plan_closed("inbox", [(ref, None, "- 2026-06-20 · inbox-simple · plan · close GREEN")]))

    # 3. momentum subject-zone: 'clean' as prose adjective must NOT count
    plog = [(ref, 0.70, "- 2026-06-20 · plugins · C1 · INSERT OR IGNORE is the clean pattern · rubric=0.70")]
    check("momentum: clean prose ignored", momentum_score("clean", plog, ref) == 0.0)
    check("momentum: plugins subject counts", momentum_score("plugins", plog, ref) > 0.0)
    # recency decay: a 40-day-old close contributes nothing
    old = [(date(2026, 5, 1), 0.9, "- 2026-05-01 · sell · plan · x")]
    check("momentum: stale close decays to 0", momentum_score("sell", old, ref) == 0.0)

    # 4. lint_paths: phantom/wrong-rooted flagged; real + planned-new-file accepted.
    # Uses real on-disk paths so the rule (exists OR leaf-file-with-real-grandparent)
    # is checked against the actual repo, same culture as the rest of selftest.
    real_dir = "one.ie/web/src/lib"           # a dir that exists
    new_file = "one.ie/web/src/lib/in/zzz-not-real.ts"  # planned file, real grandparent
    phantom_url = "api/composio/connections"  # URL-style route, fake top/second dir
    fm_real = f"deliverables:\n  - lib: {real_dir} — x\n"
    fm_new = f"deliverables:\n  - lib: {new_file} — x\n"
    fm_bad = f"deliverables:\n  - api: {phantom_url} — x\n"
    check("lint: real dir accepted", lint_paths(fm_real) == [])
    check("lint: planned new file accepted", lint_paths(fm_new) == [])
    check("lint: phantom url-route flagged", len(lint_paths(fm_bad)) == 1)

    # 5. deliverable_dirs subtree granularity: a file → its CONTAINING dir (filename
    # dropped); a bare dir → itself. This is the fleet's disjointness key.
    fm_sub = ("deliverables:\n"
              "  - lib: one.ie/web/src/lib/billing/expiry.ts — x\n"
              "  - dir: channels/src — y\n")
    check("dirs: file → parent subtree",
          "one.ie/web/src/lib/billing" in deliverable_dirs(fm_sub))
    check("dirs: filename dropped",
          "one.ie/web/src/lib/billing/expiry.ts" not in deliverable_dirs(fm_sub))
    check("dirs: bare dir kept", "channels/src" in deliverable_dirs(fm_sub))
    # text/ file granularity — two plans' docs must NOT collapse to one `text` lock.
    fm_t1 = "deliverables:\n  - doc: text/alpha-docs.md — x\n"
    fm_t2 = "deliverables:\n  - doc: text/beta-docs.md — x\n"
    check("dirs: text/ keeps the filename",
          "text/alpha-docs.md" in deliverable_dirs(fm_t1))
    check("dirs: text/ does not collapse to the bare dir",
          "text" not in deliverable_dirs(fm_t1))
    check("dirs: two text/ docs are disjoint",
          not (deliverable_dirs(fm_t1) & deliverable_dirs(fm_t2)))
    # RED half — the old behaviour must be genuinely gone, not merely untested.
    check("dirs: text/ nested path still uses its containing dir",
          "text/world" in deliverable_dirs("deliverables:\n  - doc: text/world/homepage-text.md — x\n"))

    # 6. transitive leverage: a→b→c chain ⇒ a has 2 dependents (b and c), not 1.
    direct = {"a": {"b"}, "b": {"c"}, "c": set()}
    check("leverage: transitive chain a→b→c == 2",
          len(transitive_dependents("a", direct)) == 2)
    check("leverage: leaf c == 0", len(transitive_dependents("c", direct)) == 0)

    # 7. toxic classifier (the queue's guard): cold+stale+signal ⇒ toxic; warm OR fresh
    # ⇒ NEVER toxic. The two protection cases (analytics warm, speed-channels fresh) are
    # load-bearing — they lock that a large open-box count can't demote a valuable plan.
    check("toxic: warm never toxic (analytics mom>0)", is_toxic(0.82, 33, 349, 0.09, True) == [])
    check("toxic: fresh never toxic (speed not stale)", is_toxic(0.0, 0, 4, 0.0, False) == [])
    check("toxic: empty cold stale (features)", "empty" in is_toxic(0.0, 0, 0, 0.0, True))
    check("toxic: deliverables block ⇒ not empty (foundation-ui)",
          "empty" not in is_toxic(0.0, 0, 0, 0.0, True, has_deliverables=True))
    check("toxic: zero-progress cold stale (crx)", "zero-progress" in is_toxic(0.0, 0, 250, 0.0, True))
    check("toxic: mega cold stale (people)", "mega-stale" in is_toxic(0.0, 30, 239, 0.11, True))

    # 8. fade (C2): asymmetric decay — resistance decays 2× faster than strength (world.fade).
    s1, r1 = _fade_one(1.0, 1.0, 0.1)
    check("fade: strength ×(1-r)", s1 == 0.9)
    check("fade: resistance 2× faster", r1 == 0.8)
    check("fade: resistance falls faster than strength", r1 < s1)
    check("fade: resistance floors at 0 (rate>0.5)", _fade_one(1.0, 1.0, 0.6)[1] == 0.0)

    # 9. frontier (C4): every returned slug is a plan WITHOUT a todo (set difference holds).
    # now_ct=None skips git staleness, empty log skips close-filtering → pure set-difference.
    fr, _fstale, _fclosed = frontier(None, [])
    todo_set = {f.name[: -len("-todo.md")] for f in TEXT.glob("*-todo.md")}
    check("frontier: no returned slug has a todo", all(slug not in todo_set for _s, _d, slug, _t in fr))
    check("frontier: queue-frontier itself excluded (has a todo)",
          all(slug != "queue-frontier" for _s, _d, slug, _t in fr))

    # 10. closed-plan filter (C5): frontier() reuses plan_closed (the todo walk's close-rule)
    # to hide shipped plans — power-through-simplicity, one close-rule for both. Unit-test the
    # reused detector directly: format match, no false positive, and the hyphen-family guard.
    cl = [(None, None, "- 2026-06-30 · braindo PLAN · CLOSE · all 3 cycles shipped; kill-switch exits 0")]
    check("plan_closed: recorded PLAN·CLOSE detected", plan_closed("braindo", cl) is True)
    check("plan_closed: unrelated slug not matched", plan_closed("wallet", cl) is False)
    check("plan_closed: hyphen-family not cross-matched (brain≠braindo)", plan_closed("brain", cl) is False)

    # 11. gated exclusion (build_gate): a human-approval cycle is held OUT of ready/--top/
    # fleet so a blanket do-fleet/do-auto run never auto-launches it (e.g. real-money
    # x402-settlement). Detection is frontmatter-scoped: a build_gate in the BODY never
    # gates (else any doc mentioning the field would vanish from the queue), and an empty
    # build_gate line does not gate (requires a value). Locks the full is_gated contract.
    check("gated: frontmatter build_gate ⇒ gated",
          is_gated('---\ntitle: x\nbuild_gate: "human-approval"\n---\nbody') is True)
    check("gated: no build_gate ⇒ not gated",
          is_gated('---\ntitle: x\npriority: 2\n---\nbody') is False)
    check("gated: build_gate in BODY only ⇒ not gated (frontmatter-scoped)",
          is_gated('---\ntitle: x\n---\nbuild_gate: y in prose') is False)
    check("gated: empty build_gate value ⇒ not gated (needs a reason)",
          is_gated('---\ntitle: x\nbuild_gate:\n---\nbody') is False)

    # 12. ratchet-trend (C2): per-dimension rising/flat/slipping from vectored closes,
    # plus composite-vs-trailing-median direction. Pure synthetic vectors, deterministic —
    # security climbs .70→.80→.90 (rising), speed falls .70→.60→.50 (slipping), simplicity
    # holds flat at .70 throughout.
    rlog = [
        (date(2026, 6, 1), 0.70,
         "- 2026-06-01 · x · c · a [sec.70 simp.70 struct.70 speed.70 integ.70 reuse.70 test.70 ux.70]"),
        (date(2026, 6, 10), 0.75,
         "- 2026-06-10 · x · c · b [sec.80 simp.70 struct.70 speed.60 integ.70 reuse.70 test.70 ux.70]"),
        (date(2026, 6, 19), 0.85,
         "- 2026-06-19 · x · c · c [sec.90 simp.70 struct.70 speed.50 integ.70 reuse.70 test.70 ux.70]"),
    ]
    rdims, (rcomp, rmed, rdir) = ratchet_trend(rlog, date(2026, 6, 19))
    rd = {name: (label, slope) for _short, name, _val, slope, label in rdims}
    check("ratchet: security rising", rd["security"][0] == "rising" and rd["security"][1] > 0)
    check("ratchet: speed slipping", rd["speed"][0] == "slipping" and rd["speed"][1] < 0)
    check("ratchet: simplicity flat (no change)", rd["simplicity"][0] == "flat")
    check("ratchet: composite above trailing median ⇒ rising", rcomp == 0.85 and rdir == "rising")
    check("ratchet: no closes ⇒ empty dims, no crash", ratchet_trend([], None)[0] == [])
    check("ratchet: parse_vector back-compat (no vector ⇒ None)",
          parse_vector("- 2026-06-01 · x · c · plain rubric=0.80") is None)

    # 13. outcome-weight (self-improving-outcome): path_momentum() folds prod.strength/
    # prod.resistance in alongside closed/live — a slug the world MARKED (prod.strength)
    # ranks strictly above an identical slug the world WARNED (prod.resistance), same
    # closed/local strength/resistance otherwise. Load-bearing assertion, not a label
    # grep — this is the exact trap this family already hit once (a green string with no
    # real check behind it). See text/self-improving-outcome-plan.md § Pre-mortem.
    marked_paths = {"task:x": {"closed": 1.0, "strength": 0.0, "resistance": 0.0,
                                "prod": {"strength": 2.0, "resistance": 0.0}}}
    warned_paths = {"task:x": {"closed": 1.0, "strength": 0.0, "resistance": 0.0,
                                "prod": {"strength": 0.0, "resistance": 2.0}}}
    check("outcome-weight: prod.strength raises momentum above an identical warned slug",
          path_momentum("x", marked_paths) > path_momentum("x", warned_paths))
    check("outcome-weight: no prod key ⇒ unchanged behaviour (back-compat)",
          path_momentum("x", {"task:x": {"closed": 1.0, "strength": 0.0, "resistance": 0.0}}) == 0.5)

    # 14. provenance (self-improving-outcome): --trails' NET calc surfaces prod+/prod-
    # separately from closed/live/resist, so the operator can see WHY a rank moved (world
    # vs. local). Exercise the same arithmetic --trails prints, not just path_momentum.
    prov_entry = {"closed": 0.0, "strength": 0.0, "resistance": 0.0,
                  "prod": {"strength": 1.5, "resistance": 0.4}}
    prov_prod = prov_entry.get("prod") or {}
    prov_net = round(float(prov_entry.get("closed", 0)) + float(prov_entry.get("strength", 0))
                      - float(prov_entry.get("resistance", 0))
                      + float(prov_prod.get("strength", 0)) - float(prov_prod.get("resistance", 0)), 2)
    check("provenance: --trails NET includes prod+/prod- terms", prov_net == 1.1)
    check("provenance: prod+/prod- readable independent of closed/live/resist",
          float(prov_prod.get("strength", 0)) == 1.5 and float(prov_prod.get("resistance", 0)) == 0.4)

    if fails:
        print("SELFTEST FAIL:")
        for f in fails:
            print("  ✗", f)
        sys.exit(1)
    print("SELFTEST: 45/45 pass (hyphen-boundary · plan-close · momentum subject-zone · "
          "decay · deliverables-lint · subtree-dirs · transitive-leverage · toxic-classifier · "
          "deliverables-guard · fade-asymmetry · frontier-setdiff · frontier-closed-filter · "
          "gated-exclusion · ratchet-trend · outcome-weight · provenance)")


def main():
    args = sys.argv[1:]
    as_json = "--json" in args
    toxic_report = "--toxic" in args
    tasks_human = "--tasks" in args
    tasks_seed_out = "--tasks-json" in args
    task_context_out = "--task-context-json" in args  # backfill source: context for ALL plans
    top_n = None
    if "--top" in args:
        i = args.index("--top")
        top_n = int(args[i + 1])
    if "--selftest" in args:
        return selftest()

    # `--worktags <slug>` — the plan's task-vocabulary tags (dept + topics), comma-joined,
    # one line. do-auto.sh passes these to the cycle-close do-event so the reputation harvest
    # credits the SAME tag-nodes real tasks carry (text/reputation.md § Slice A). Self-contained
    # (one frontmatter read) so the emit stays cheap.
    if "--worktags" in args:
        i = args.index("--worktags")
        slug = args[i + 1] if i + 1 < len(args) else ""
        f = TEXT / f"{slug}-todo.md"
        if not f.exists():
            f = TEXT / f"{slug}-plan.md"
        tags = []
        if f.exists():
            fm = parse_frontmatter(f.read_text(errors="ignore"))
            dept = classify_dept(slug, {"title": fm.get("title", ""), "tags": fm.get("tags", [])})
            tags = _task_tags({"dept": dept, "tags": fm.get("tags", [])})
        print(",".join(t for t in tags if t))
        return

    # `--dirs <slug>` — the subtree dirs a plan ships into, one per line. The SINGLE
    # disjointness extractor: do-fleet.sh calls this instead of re-parsing markdown in
    # bash, so the displayed waves and the fleet's live conflict check can never drift.
    if "--dirs" in args:
        i = args.index("--dirs")
        slug = args[i + 1]
        f = TEXT / f"{slug}-todo.md"
        if f.exists():
            for d in sorted(deliverable_dirs(f.read_text(errors="ignore"))):
                print(d)
        return

    # `--board-check` — the one failure mode source-greps cannot catch. do-tasks-wire-check.sh
    # asserts the SHAPE of the board read; this actually performs it. A key that doesn't match
    # the deployed worker's GATEWAY_API_KEY passes every static check and still leaves the
    # ranker file-only forever — which is exactly how the original break hid for months.
    # Deliberately NOT part of any promise `proof:` (a contract must not depend on the network);
    # run it explicitly when the board looks empty.
    if "--board-check" in args:
        target = os.environ.get("DO_SIGNAL_URL", "https://one.ie")
        rows, reason = fetch_tasks_everywhere()
        if reason:
            print(f"[board-check] RED — {target}: {reason}", file=sys.stderr)
            return 1
        door = LAST_BOARD_READ["door"] or "tasks:everywhere"
        print(f"[board-check] OK — {target}: {board_count_phrase(len(rows))} "
              f"open task(s) readable (door: {door})")
        return 0

    # `--untriaged [workspace]` — the triage queue as JSON on stdout, read through
    # tasks:board and followed to the last page. This is what .claude/workflows/
    # triage.js consumes: it used to ask a model to enumerate rows out of
    # --board-check's single summary line, which carries none. Deterministic fact,
    # deterministic script. Always prints an object; `ok:false` carries the reason.
    if "--untriaged" in args:
        i = args.index("--untriaged")
        ws = args[i + 1] if len(args) > i + 1 and not args[i + 1].startswith("-") else None
        rows, reason, meta = fetch_untriaged(workspace=ws)
        out = {"ok": not reason, "tasks": rows, "returned": len(rows)}
        out.update(meta)
        if reason:
            out["error"] = reason
        print(json.dumps(out))
        return 0 if not reason else 1

    # `--lint` — mechanical deliverables hygiene across all OPEN plans. Flags phantom
    # paths (under-qualified/wrong-rooted) that make a plan a fleet false-parallel, and
    # plans with NO parseable deliverables (a fleet hazard). Exit 1 if any plan is dirty.
    if "--lint" in args:
        log, _ = load_learnings_log()
        dirty = 0
        for f in sorted(TEXT.glob("*-todo.md")):
            slug = f.name[: -len("-todo.md")]
            if slug in EXCLUDE:
                continue
            text = f.read_text(errors="ignore")
            done_b, open_b = checkbox_state(text)
            if (done_b + open_b > 0 and open_b == 0) or plan_closed(slug, log):
                continue  # closed/done — not a live fleet candidate
            bad = lint_paths(text)
            scoped = bool(deliverable_paths(text))
            if not bad and scoped:
                continue
            dirty += 1
            print(f"\n  ✗ {slug}")
            if not scoped:
                print("      UNSCOPED — no parseable deliverable paths (fleet excludes it; not fleet-safe)")
            for tok, why in bad:
                print(f"      PHANTOM  {tok}  — {why}")
        if dirty:
            print(f"\n  {dirty} plan(s) need deliverables hygiene before fleeting. "
                  f"Fix paths to repo-root-relative (one.ie/web/src/...).\n")
            sys.exit(1)
        print("  deliverables lint: all open plans scoped + all paths resolve ✓")
        return

    # `--sync-closes` — reconcile path strength from learnings.md closes (idempotent).
    # The autonomous close→weight wire: the sync-priority-todo hook runs this on every
    # learnings.md edit, so a cycle close moves the weight with no human in the loop.
    if "--sync-closes" in args:
        log, ref = load_learnings_log()
        n = sync_closes(log, ref)
        print(f"  synced closes → {n} task path(s) updated in {TASK_PATHS.name}")
        return

    # `--trails` — track the loop: show the trails outcomes have worn into the path
    # store. A trail = accumulated path strength (closes + live marks + prod outcomes)
    # minus resistance. Strong trails are highways the next pick follows; resistance-
    # heavy ones are fading. `prod+`/`prod-` (self-improving-outcome) show provenance —
    # what production confirmed, separate from local closes/marks — so the operator can
    # tell WHY a rank moved, not just that it did.
    if "--trails" in args:
        paths = load_task_paths()
        rows = []
        for key, e in paths.items():
            closed = float(e.get("closed", 0))
            strength = float(e.get("strength", 0))
            resistance = float(e.get("resistance", 0))
            prod = e.get("prod") or {}
            prod_strength = float(prod.get("strength", 0))
            prod_resistance = float(prod.get("resistance", 0))
            net = round(closed + strength - resistance + prod_strength - prod_resistance, 2)
            rows.append((net, key, closed, strength, resistance, int(e.get("traversals", 0)), prod_strength, prod_resistance))
        rows.sort(reverse=True)
        print("\n  TRAILS — paths the loop has worn (weighed by outcome · close + live mark + prod − resistance)\n")
        if not rows:
            print("  (no trails yet — a cycle close or a mark wears the first one)\n")
            return
        print(f"  {'NET':>5}  {'closed':>6} {'live':>5} {'resist':>6} {'×':>4} {'prod+':>5} {'prod-':>5}  TRAIL")
        print(f"  {'-'*5}  {'-'*6} {'-'*5} {'-'*6} {'-'*4} {'-'*5} {'-'*5}  {'-'*30}")
        for net, key, c, s, r, tv, ps, pr in rows[:25]:
            band = "🛣 highway" if net >= 4 else "· trail" if net >= 2 else "  forming"
            if r + pr > c + s + ps:
                band = "✗ fading"
            print(f"  {net:>5.1f}  {c:>6.1f} {s:>5.1f} {r:>6.1f} {tv:>4} {ps:>5.1f} {pr:>5.1f}  {key:<26} {band}")
        print(f"\n  {len(rows)} trail(s). A close → --sync-closes wears it deeper; warn/--fail lets it fade.")
        print(f"  prod+/prod- come from outcome-pull.ts (production D1, session-cadence) — provenance, never local.")
        print(f"  These are the task-layer trails (text/task-paths.json); the substrate trail is claw_paths/path.strength.\n")
        return

    # `--mark <slug> [--fail] [--amount N]` — the mark/warn verb for the task layer.
    # Closes the loop: moves path strength, then the next --tasks/queue run reads it.
    if "--mark" in args:
        i = args.index("--mark")
        slug = args[i + 1]
        outcome = "failure" if "--fail" in args else "success"
        amount = 1.0
        if "--amount" in args:
            amount = float(args[args.index("--amount") + 1])
        e = mark_task(slug, outcome, amount)
        pm = path_momentum(slug, load_task_paths()) or 0.0
        delta = round(10 * pm, 1)
        print(f"  {outcome:>7}  task:{slug}  →  strength={e['strength']} resistance={e['resistance']} "
              f"traversals={e['traversals']}")
        print(f"  path-momentum={pm}  ⇒  weight gains +{delta} over base 50 on the next --tasks run")
        return

    # `--fade [--rate R]` — the fade verb for the task layer (C2). Asymmetric decay of LIVE
    # weight (resistance 2× faster). The hourly action: unworked live marks cool, warnings
    # heal. `closed` is left to --sync-closes (already recency-decayed). Default rate 0.1.
    if "--fade" in args:
        rate = 0.1
        if "--rate" in args:
            rate = float(args[args.index("--rate") + 1])
        n = fade_paths(rate)
        r = max(0.0, min(1.0, rate))
        print(f"  faded {n} live task path(s) at rate {r}  →  strength ×{1 - r:.2f}, "
              f"resistance ×{max(0.0, 1 - 2 * r):.2f} (engine.md: resistance decays 2× faster)")
        print(f"  closed weight untouched (owned by --sync-closes · learnings 30-day recency window)")
        return

    # `--frontier` — what's next past every armed todo (C4): designed-but-unarmed plans,
    # import-stale ones hidden, ranked by strategic pull. The 'after all done or toxic' edge.
    if "--frontier" in args:
        now_ct = repo_now()
        flog, _fref = load_learnings_log()
        fresh, stale, closed = frontier(now_ct, flog)
        print(f"\n  FRONTIER — {len(fresh)} designed-but-unarmed plan(s) past the live queue "
              f"(no todo yet; {closed} shipped/closed + {stale} import-stale hidden)\n")
        if fresh:
            print(f"  {'STRAT':>5}  {'AGE':>4}  SLUG")
            print(f"  {'-' * 5}  {'-' * 4}  {'-' * 30}")
            for strat, days, slug, title in fresh[:20]:
                print(f"  {strat:>5}  {days:>3}d  {slug:<28} {title}")
        print(f"\n  past these: the substrate's own frontiers_global (TypeDB hypotheses) — "
              f"the migration target (not wired this cycle).\n")
        return

    # `--ratchet` (C2, self-improving-ratchet) — read-only projection: each of the eight
    # rubric dimensions' 30-day trend (rising/flat/slipping), reusing load_learnings_log +
    # the momentum recency window. Composite vs its trailing median is the number C3's W4
    # gate reads (composite-ratchet: composite ≥ max(0.65, median)) — this prints it, the
    # gate (C3) enforces it. Answers "are we getting better?" as a command, not a vibe.
    if "--ratchet" in args:
        rlog, rref = load_learnings_log()
        dims, (last_composite, median, direction) = ratchet_trend(rlog, rref)
        n_vectored = sum(1 for _d, _r, ln in rlog if parse_vector(ln) is not None)
        print(f"\n  RATCHET — eight dimensions (30-day trend, n={n_vectored} vectored close(s))\n")
        if n_vectored == 0:
            print("  no vectored closes yet — the eight-field vector starts accumulating from")
            print("  the first close-line carrying `[sec.. simp.. …]` (text/rubrics.md § the")
            print("  close-line vector). Composite-only trend is not shown here — use the")
            print("  existing momentum/toxic reports for that.\n")
            return
        arrow = {"rising": "▲", "flat": "▬", "slipping": "▼"}
        for short, name, last_val, slope, label in dims:
            val_s = f"{last_val:.2f}" if last_val is not None else " n/a"
            warn_s = "  ⚠ warn" if label == "slipping" else ""
            print(f"    {name:<13} {arrow[label]} {label:<9} {val_s}  ({slope:+.2f}){warn_s}")
        comp_s = f"{last_composite:.2f}" if last_composite is not None else "n/a"
        med_s = f"{median:.2f}" if median else "n/a"
        print(f"\n  composite {comp_s}  {arrow.get(direction, '▬')}  "
              f"(trailing median {med_s} — gate floor; no regression)\n")
        return

    # `--ratchet-json` (C3 rescope, self-improving-ratchet) — machine-readable sibling of
    # `--ratchet`: the one source of truth for the trailing numbers so w4-rubric.ts shells
    # out instead of re-implementing a vector-regex parser in TypeScript. Read-only, no
    # exit-code contract — safe under any C3 rescope option.
    if "--ratchet-json" in args:
        import json as _json
        rlog, rref = load_learnings_log()
        dims, (last_composite, median, direction) = ratchet_trend(rlog, rref)
        n_vectored = sum(1 for _d, _r, ln in rlog if parse_vector(ln) is not None)
        print(_json.dumps({
            "last_composite": last_composite,
            "trailing_median": median,
            "direction": direction,
            "n": len(rlog),
            "n_vectored": n_vectored,
            "dims": [
                {"short": short, "name": name, "last_value": last_val, "slope": slope, "label": label}
                for short, name, last_val, slope, label in dims
            ],
        }))
        return

    # `--ratchet-dry-run` (C3 rescope calibration receipt) — replays every close against
    # the trailing median of ITS OWN priors (not the current median), and counts how many
    # would fail a strict `composite ≥ median-of-priors` gate. This is the number the W2
    # escape check argued from prose; this prints it from the real ledger so the author's
    # rescope decision (warn vs block vs rewrite-the-escape) is made on a receipt, not an
    # estimate. Never touches an exit code.
    if "--ratchet-dry-run" in args:
        rlog, _rref = load_learnings_log()
        chron = sorted(((d, rub) for d, rub, _ln in rlog if rub is not None), key=lambda t: t[0])
        reblocked = []
        for i, (d, rub) in enumerate(chron):
            priors = [r for _d, r in chron[:i]]
            if len(priors) < 2:
                continue
            med = trailing_median(priors)
            if rub < med:
                reblocked.append((d, rub, med))
        print(f"\n  RATCHET DRY-RUN — {len(chron)} composite-bearing close(s), "
              f"{len(reblocked)} would fail composite ≥ median-of-priors\n")
        for d, rub, med in reblocked[-15:]:
            print(f"    {d}  composite={rub:.2f}  <  median-of-priors={med:.2f}")
        print(f"\n  {len(reblocked)}/{len(chron) - 2 if len(chron) > 2 else 0} eligible closes "
              f"would have been re-blocked by a hard median gate.\n")
        return

    log, ref = load_learnings_log()
    task_paths = load_task_paths()
    plans = {}

    for f in sorted(TEXT.glob("*-todo.md")):
        slug = f.name[: -len("-todo.md")]
        if slug in EXCLUDE:
            continue
        text = f.read_text(errors="ignore")
        fm = parse_frontmatter(text)
        done_b, open_b = checkbox_state(text)
        total = done_b + open_b
        # DONE = all boxes ticked, OR a PLAN-level close in learnings.md, OR the
        # todo's outcome line is already ticked ("[x] Plan outcome command exits 0").
        # The last case catches plans where do-auto ticked the outcome but left
        # stale sub-items unchecked — the ranker and do-auto must agree on "done".
        outcome_ticked = bool(re.search(
            r"-\s*\[x\].*(?:Plan outcome command exits 0|outcome.*exits 0)", text, re.IGNORECASE
        ))
        is_done = (total > 0 and open_b == 0) or plan_closed(slug, log) or outcome_ticked
        pr_raw = re.match(r"\d+", str(fm.get("priority", "0")))
        priority = int(pr_raw.group(0)) if pr_raw else 0
        plans[slug] = {
            "slug": slug,
            "title": fm.get("title", ""),
            "outcome_asserts": fm.get("outcome_asserts", ""),
            "tier": fm.get("tier", "?"),
            "tags": fm.get("tags", []),
            "priority": priority,
            "depends_on": fm.get("depends_on", []),
            "done_boxes": done_b,
            "total_boxes": total,
            "is_done": is_done,
            # build_gate: human-approval-required → never auto-selected (held out of ready/--top/fleet)
            "gated": is_gated(text),
            # strategic capped at 6 so the keyword heuristic can't drown out
            # proven momentum — warm, clean-building work should pull, not buzzwords.
            "strategic": min(strategic_score(slug, fm), 6),
            "proximity": round(done_b / total, 2) if total else 0.0,
            # momentum = LIVE path strength when this slug has been marked (the closed
            # loop), else the learnings.md count (the bootstrap). A mark() here changes
            # the next pick — that is the self-improving loop, proven on one entity.
            "momentum": (lambda pm: pm if pm is not None else momentum_score(slug, log, ref))(
                path_momentum(slug, task_paths)
            ),
            "_dirs": deliverable_dirs(text),
            # subtasks = the plan's cycle ids, from cycle/wave headings (light parse)
            "cycles": sorted(
                set(re.findall(r"(?mi)^#{1,4}.*\bC(\d+)\b", text)), key=int
            ),
        }

    # Leverage: how many OPEN plans transitively depend on each slug — unblocking a
    # keystone frees its whole downstream chain, not just direct children. Example:
    # namespace ← tasks-mine ← tasks-push ← tasks-bridge → namespace's leverage is 3,
    # not 1, so the keystone ranks above plans that unblock nothing. Done plans don't
    # count (nothing waits on them). Built by walking depends_on edges to a fixpoint.
    direct = {s: set() for s in plans}  # slug -> set of slugs that directly depend on it
    for p in plans.values():
        for dep in p["depends_on"]:
            if dep in plans:
                direct[dep].add(p["slug"])

    for p in plans.values():
        deps = transitive_dependents(p["slug"], direct)
        p["leverage"] = sum(1 for s in deps if not plans[s]["is_done"])
        p["dept"] = classify_dept(p["slug"], {"title": p["title"], "tags": p["tags"]})
        p["weight"] = task_weight(p)

    now_ct = repo_now()  # the repo's HEAD time = "now" for staleness (no wall clock)
    ready, blocked, done, faded, gated = [], [], [], [], []
    for p in plans.values():
        if p["is_done"]:
            done.append(p["slug"])
            continue
        # GATED = build_gate: human-approval-required → held OUT of the auto-selection feed
        # (ready/--top/fleet/do-auto) so no blanket run launches it; surfaced in its own
        # bucket (visible, never deleted). Checked before toxic/blocked: a gated cycle is
        # withheld regardless of warmth or deps — a human runs it by explicit slug or not at
        # all. This is the do-fleet × build_gate safety gap: do-fleet feeds from --top, which
        # had ZERO build_gate awareness, so a gated real-money cycle ranked like any other.
        if p["gated"]:
            gated.append(p)
            continue
        # Toxic = cold (momentum==0) + stale + a noise signal → QUARANTINE out of the
        # live queue (a separate bucket, not a score penalty: a score-0 plan can't be
        # faded lower, so exclusion is the only removal). Checked before blocked: cold
        # noise is noise whether or not a dependency is also unmet.
        tox = toxic_reasons(p, now_ct)
        if tox:
            p["toxic_reasons"] = tox
            faded.append(p)
            continue
        unmet = [d for d in p["depends_on"]
                 if d in plans and not plans[d]["is_done"]]
        if unmet:
            p["waiting_on"] = unmet
            blocked.append(p)
            continue
        # The closed loop: momentum (what the loop LEARNED) now steers what it
        # builds NEXT. 2·strategic + 2·leverage + 1·proximity + 2·priority + 2·momentum.
        p["score"] = (2 * p["strategic"] + 2 * p["leverage"]
                      + 1 * round(p["proximity"] * 3) + 2 * p["priority"]
                      + 2 * round(p["momentum"]))
        ready.append(p)

    ready.sort(key=lambda x: (-x["score"], -x["momentum"], -x["priority"], x["slug"]))
    blocked.sort(key=lambda x: x["slug"])

    # active = open work (ready + blocked); done AND faded plans are not live tasks.
    active = ready + blocked
    # C2 — rank FROM tasks:everywhere too: board-created tasks (never a todo file) join
    # the same list; a substrate row whose slug: tag matches a local plan wins (see
    # merge_board_tasks docstring). No-op on fetch failure — file-only, unchanged.
    active = merge_board_tasks(active, plans)

    if toxic_report:
        # Read-only report — the `--toxic` deliverable. Nothing is written or deleted;
        # this is purely a projection of file state, recomputed every run.
        if not faded:
            print("  no toxic todos — the live queue is clean ✓")
            return
        print(f"\n  TOXIC — {len(faded)} cold+stale todo(s) demoted from the live queue "
              f"(read-only; nothing deleted)\n")
        for p in sorted(faded, key=lambda x: x["slug"]):
            print(f"  {p['slug']:<22} {', '.join(p['toxic_reasons'])}")
        print(f"\n  gate: momentum==0 (no close in window) AND stale (≥{STALE_DAYS}d since commit) "
              f"AND a noise signal. warm or fresh ⇒ never toxic.\n")
        return

    if tasks_seed_out:
        print(json.dumps(tasks_seed(active), indent=2))
        return
    if task_context_out:
        # Context for EVERY plan (done/blocked/ready), keyed by tid — the backfill reads
        # this to add notes + task-context to tasks already seeded into TypeDB (which the
        # forward `seed-tasks-typedb.ts` skips because they exist). Idempotent by design.
        contexts = []
        for p in sorted(plans.values(), key=lambda x: x["slug"]):
            notes, docs = task_context_for(p)
            contexts.append({"tid": f"task:{p['slug']}", "notes": notes, "contextDocs": docs})
        print(json.dumps({"version": "context-backfill-1", "contexts": contexts}, indent=2))
        return
    if tasks_human:
        print("\n" + "\n".join(tasks_view(active)) + "\n")
        return

    if top_n is not None:
        for p in ready[:top_n]:
            print(p["slug"])
        return

    if as_json:
        print(json.dumps({
            "ready": [{k: p[k] for k in
                       ("slug", "score", "strategic", "leverage", "proximity",
                        "priority", "momentum", "tier", "title")} for p in ready],
            "blocked": [{"slug": p["slug"], "waiting_on": p["waiting_on"]}
                        for p in blocked],
            "faded": [{"slug": p["slug"], "reasons": p["toxic_reasons"]}
                      for p in sorted(faded, key=lambda x: x["slug"])],
            "done": sorted(done),
        }, indent=2))
        return

    # Human table
    print(f"\n  PRIORITY QUEUE — {len(ready)} ready · {len(blocked)} blocked · "
          f"{len(faded)} faded · {len(done)} done\n")

    # RATCHET — C4: one compact line surfacing C2's eight-dimension trend so the
    # operator sees "are we getting better?" at session start without running
    # --ratchet. Reuses `log`/`ref` (already computed above) + ratchet_trend();
    # the full 8-row table stays behind --ratchet. Degrades to a "no data" line
    # (still carrying the word "ratchet") when no vectored closes exist yet.
    r_dims, (r_comp, r_med, r_dir) = ratchet_trend(log, ref)
    if r_comp is None:
        print("  RATCHET  no vectored closes yet — trend starts at the first "
              "[sec.. simp.. …] close\n")
    else:
        r_arrow = {"rising": "▲", "flat": "▬", "slipping": "▼"}.get(r_dir, "▬")
        n_slip = sum(1 for _sh, _nm, _lv, _sl, label in r_dims if label == "slipping")
        slip_s = f"  ·  {n_slip} dim(s) slipping ⚠" if n_slip else ""
        r_med_s = f"{r_med:.2f}" if r_med else "n/a"
        print(f"  RATCHET  composite {r_comp:.2f} {r_arrow}  "
              f"(median {r_med_s}){slip_s}\n")

    print(f"  {'SCORE':>5}  {'S':>2} {'L':>2} {'P':>4} {'Pr':>2} {'M':>4}  {'TIER':<8} SLUG")
    print(f"  {'-'*5}  {'-'*2} {'-'*2} {'-'*4} {'-'*2} {'-'*4}  {'-'*8} {'-'*30}")
    for p in ready[:40]:
        print(f"  {p['score']:>5}  {p['strategic']:>2} {p['leverage']:>2} "
              f"{p['proximity']:>4} {p['priority']:>2} {p['momentum']:>4}  "
              f"{p['tier']:<8} {p['slug']}")
    if blocked:
        print(f"\n  BLOCKED ({len(blocked)}) — waiting on a dependency:")
        for p in blocked:
            print(f"    {p['slug']:<30} ← {', '.join(p['waiting_on'])}")

    # GATED — build_gate: human-approval-required. Held OUT of ready/--top/fleet/do-auto so
    # no blanket run auto-launches it (e.g. the real-money x402-settlement). Visible, never
    # deleted; a human runs it by explicit slug after approving. Surfaced prominently because
    # it is the safety signal — the operator must SEE what the fleet will not touch.
    if gated:
        print(f"\n  GATED ({len(gated)}) — build_gate: human-approval-required; held OUT of ready/--top/fleet (run only by explicit /do <slug>):")
        for p in sorted(gated, key=lambda x: x["slug"]):
            print(f"    {p['slug']:<30} {p['title'][:48]}")

    # FADED — cold + stale + a noise signal. Demoted out of the live queue (NOT deleted);
    # the file is untouched, this is recomputed every run. See `--toxic` for the gate.
    if faded:
        print(f"\n  FADED ({len(faded)}) — cold + stale, demoted from the live queue (not deleted):")
        for p in sorted(faded, key=lambda x: x["slug"]):
            print(f"    {p['slug']:<30} {', '.join(p['toxic_reasons'])}")

    # FLEET WAVES — which ready plans are file-disjoint (safe to run in parallel).
    # do-fleet.sh launches the top slots; this shows the human the natural batches.
    waves, unscoped = pack_waves(ready)
    if waves:
        print(f"\n  FLEET WAVES — file-disjoint batches (do-fleet.sh --slots N --go):")
        for i, w in enumerate(waves, 1):
            print(f"    wave {i} ({len(w['slugs'])}):  {' · '.join(w['slugs'])}")
    if unscoped:
        print(f"\n  ⚠ UNSCOPED ({len(unscoped)}) — no deliverables: declared, NOT fleet-safe.")
        print(f"    The fleet sees zero dirs ⇒ would parallelize these blindly and clobber")
        print(f"    shared trees (e.g. one.ie/web). Add a deliverables: block before fleeting:")
        for s in unscoped:
            print(f"      {s}")
    # FRONTIER — surfaces only when the live queue thins (everything done or faded). The
    # answer to "what's next after they're all done or toxic": designed-but-unarmed plans.
    if len(ready) <= 3:
        fresh, fstale, fclosed = frontier(now_ct, log)
        if fresh:
            print(f"\n  FRONTIER — queue is thin; next designed-but-unarmed plans "
                  f"({fclosed} shipped/closed + {fstale} import-stale hidden):")
            for strat, days, slug, _title in fresh[:5]:
                print(f"    {slug:<30} strat={strat} ({days}d since design)")
            print(f"    → past these: frontiers_global (substrate hypotheses) · full list: do-rank.py --frontier")

    print(f"\n  legend: S=strategic ×2 (cap 6) · L=leverage ×2 · P=proximity ×1 · Pr=priority ×2 · M=momentum ×2")
    print(f"  M = the loop reading its own output: recent high-rubric closes from learnings.md")
    print(f"  → warm, proven work pulls the fleet (cheaper to continue than start cold)")
    print(f"  run with --json for the fleet, --top N for the top slugs\n")

    # The tasks layer: every todo as a tagged, weighted signal (text/tasks-plan.md).
    print("\n".join(tasks_view(active)))


if __name__ == "__main__":
    # `or 0` so every path that returns None (the vast majority) still exits 0 — only a
    # mode that deliberately returns a non-zero int (e.g. --board-check RED) sets a code.
    sys.exit(main() or 0)
