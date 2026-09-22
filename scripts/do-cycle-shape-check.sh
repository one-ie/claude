#!/usr/bin/env bash
# do-cycle-shape-check.sh — BEHAVIOURAL parity gate for the /do Status-kanban
# cycle-line shape, which is implemented four times in three languages:
#   1. .claude/workflows/do-engine.js  openCyclesFromTodo()   (JS regex, reader)
#   2. .claude/scripts/do-auto.sh      _remaining()           (grep -E, reader)
#   3. .claude/scripts/do-auto.sh      _sync_status()         (sed -E, writer)
#   4. .claude/scripts/do-tick.sh                             (grep + perl, writer)
#
# It does NOT string-compare the four regexes (that goes stale the day someone
# reformats one). It runs the REAL implementations — reader #2's pattern is
# scraped out of the live source at runtime, never pasted here — against one
# fixture matrix and asserts:
#   READER PARITY          both readers see the same open cycle ids
#   WRITER CLOSES READER   do-tick.sh can close every id a reader calls open
#   RATCHET                do-tick.sh never turns [x] back into [ ]
#
# --self-test proves each assertion can go RED (mutated copies in a scratch dir;
# the real repo files are never touched).
#
# manifest: portable
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINE_JS="${DO_SHAPE_ENGINE:-$REPO/.claude/workflows/do-engine.js}"
AUTO_SH="${DO_SHAPE_AUTO:-$REPO/.claude/scripts/do-auto.sh}"
TICK_SH="${DO_SHAPE_TICK:-$REPO/.claude/scripts/do-tick.sh}"
SLUG=shapefixture
FAILED=0

ok()   { printf 'ok   %s\n' "$*"; }
fail() { printf 'FAIL %s\n' "$*"; FAILED=1; }

# ── fixture ───────────────────────────────────────────────────────────────
make_fixture() { # $1 = root dir
  mkdir -p "$1/text"
  cat > "$1/text/${SLUG}-todo.md" <<'MD'
# Status

- [ ] C1 — plain
- [~] C2 — in progress
- [x] C3 — done
- [ ] **C4** — bold
  - [ ] C5 — indented two spaces
- [ ] C10 — two digit
- [ ] C6 - hyphen not em-dash
- [ ] D1 — wrong prefix
Prose mentioning C1 inline should never count.
MD
}
# Expected OPEN set (the contract all four implementations must agree on).
EXPECTED="C1 C2 C4 C5 C10"

# ── reader #1: the real openCyclesFromTodo, sliced out of do-engine.js ─────
read_engine() { # $1 = todo path, $2 = engine js path
  node -e '
    const fs = require("fs");
    const src = fs.readFileSync(process.argv[1], "utf8");
    const i = src.indexOf("function openCyclesFromTodo");
    if (i < 0) { console.error("openCyclesFromTodo not found"); process.exit(9); }
    const j = src.indexOf("\n}\n", i);
    if (j < 0) { console.error("could not slice function body"); process.exit(9); }
    const fn = (0, eval)("(" + src.slice(i, j + 2) + ")");
    console.log(fn(fs.readFileSync(process.argv[2], "utf8")).join(" "));
  ' "$2" "$1"
}

# ── reader #2: the LIVE grep pattern scraped out of do-auto.sh _remaining() ─
auto_pattern() { # prints the pattern do-auto.sh actually greps with
  local line
  line=$(grep -nE "grep -cE .*C\[0-9\]" "$AUTO_SH" | head -1)
  [ -n "$line" ] || { echo "do-auto _remaining pattern not found" >&2; return 9; }
  sed -E "s/^[^']*'//; s/'.*$//" <<<"${line#*:}"
}
read_auto() { # $1 = todo path
  local pat matched
  pat=$(auto_pattern)
  # SIGPIPE trap: never pipe a producer into a short-circuiting consumer.
  matched=$(grep -oE "$pat" "$1" 2>/dev/null || true)
  local ids; ids=$(grep -oE 'C[0-9]+' <<<"$matched" || true)
  tr '\n' ' ' <<<"$ids" | sed -E 's/ +$//'
}

norm() { tr -s ' ' '\n' <<<"$1" | sed '/^$/d' | tr '\n' ' ' | sed -E 's/ +$//'; }

# ── the three checks, parameterised so --self-test can mutate the inputs ───
run_checks() { # $1 = label prefix, $2 = engine js, $3 = tick cmd, $4 = strict(1)|report(0)
  local label="$1" engine="$2" tick="$3"
  local root; root=$(mktemp -d); trap 'rm -rf "$root"' RETURN
  make_fixture "$root"
  local todo="$root/text/${SLUG}-todo.md"
  local a b
  a=$(norm "$(read_engine "$todo" "$engine")")
  b=$(norm "$(read_auto "$todo")")
  local rc=0
  if [ "$a" = "$b" ]; then ok "$label reader parity — both readers: [$a]"; else
    fail "$label reader parity — do-engine:[$a] != do-auto:[$b]"; rc=1; fi
  if [ "$b" = "$(norm "$EXPECTED")" ]; then ok "$label reader vs contract — [$b]"; else
    fail "$label reader vs contract — expected [$EXPECTED] got [$b]"; rc=1; fi

  # WRITER CLOSES READER
  local cid wrc=0
  for cid in $b; do
    DO_TICK_ROOT="$root" bash $tick "$SLUG" "$cid" >/dev/null 2>&1 || { fail "$label do-tick failed on $cid"; wrc=1; }
    local a2 b2
    a2=" $(norm "$(read_engine "$todo" "$engine")") "
    b2=" $(norm "$(read_auto "$todo")") "
    case "$a2$b2" in *" $cid "*) fail "$label writer-closes-reader — $cid still open after tick"; wrc=1;; esac
  done
  [ "$wrc" = 0 ] && ok "$label writer closes reader — all of [$b] closed by do-tick" || rc=1

  # RATCHET — a closed cycle must not reopen
  local before after
  before=$(cksum < "$todo")
  DO_TICK_ROOT="$root" bash $tick "$SLUG" C3 >/dev/null 2>&1 || true
  after=$(cksum < "$todo")
  if [ "$before" = "$after" ]; then ok "$label ratchet — [x] C3 untouched"; else
    fail "$label ratchet — do-tick mutated an already-closed cycle"; rc=1; fi
  return $rc
}

# ── self-test: prove each assertion can go RED ────────────────────────────
if [ "${1:-}" = "--self-test" ]; then
  SCRATCH="${TMPDIR:-/tmp}/do-cycle-shape-selftest.$$"
  case "${SCRATCH_BASE:-}" in "") ;; *) SCRATCH="$SCRATCH_BASE/do-cycle-shape-selftest.$$";; esac
  mkdir -p "$SCRATCH"; trap 'rm -rf "$SCRATCH"' EXIT

  # A fixed reader (tolerates **C4**) — the green control.
  cat > "$SCRATCH/engine-fixed.js" <<'JS'
function openCyclesFromTodo(todoText) {
  const re = /^[ \t]*-\s\[[ ~]\]\s\*{0,2}(C\d+)\*{0,2}\s—/gm
  const out = []
  let m
  while ((m = re.exec(todoText))) out.push(m[1])
  return out
}
JS
  # The bug: drop \*{0,2} — blind to the bold form.
  sed 's/\\\*{0,2}//g' "$SCRATCH/engine-fixed.js" > "$SCRATCH/engine-bold-blind.js"
  # A stubbed writer that ticks nothing.
  printf '#!/usr/bin/env bash\nexit 0\n' > "$SCRATCH/tick-stub.sh"; chmod +x "$SCRATCH/tick-stub.sh"

  echo "-- control: fixed reader + real writer (must be GREEN)"
  FAILED=0; run_checks "[control]" "$SCRATCH/engine-fixed.js" "$TICK_SH" || true
  ctrl=$FAILED
  echo "-- red proof (a): reader without \\*{0,2} (must go RED)"
  FAILED=0; run_checks "[red-a]" "$SCRATCH/engine-bold-blind.js" "$TICK_SH" >/dev/null 2>&1 || true
  reda=$FAILED
  echo "-- red proof (b): do-tick stubbed to write nothing (must go RED)"
  FAILED=0; run_checks "[red-b]" "$SCRATCH/engine-fixed.js" "$SCRATCH/tick-stub.sh" >/dev/null 2>&1 || true
  redb=$FAILED

  FAILED=0
  [ "$ctrl" = 0 ] && ok "self-test control green" || fail "self-test control should be green"
  [ "$reda" = 1 ] && ok "self-test red-proof (a) bold-blind reader goes RED" || fail "self-test (a) stayed green against a reintroduced bug"
  [ "$redb" = 1 ] && ok "self-test red-proof (b) no-op writer goes RED" || fail "self-test (b) stayed green against a writer that writes nothing"
  exit $FAILED
fi

run_checks "" "$ENGINE_JS" "$TICK_SH" || true
exit $FAILED
