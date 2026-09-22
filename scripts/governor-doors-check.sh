#!/usr/bin/env bash
# governor-doors-check.sh — the DOORS half of the governor guard.
#
#   bash .claude/scripts/governor-doors-check.sh          # audit + reentrancy
#   bash .claude/scripts/governor-doors-check.sh --list    # every heavy script
#   bash .claude/scripts/governor-doors-check.sh --self-test
#
# hook:governor-escape guards what an executor TYPES. This guards what the tree
# OFFERS. They are different holes and only the second one explains the real
# failure: `cd channels && bun run test` is an ungoverned 135-file two-runner
# suite, and nothing about that command string looks like an escape. The hole
# was the package script, not the command.
#
# Enumerated from `git ls-files` at run time, never from a hardcoded package
# list -- the rot test-lanes.sh explicitly avoided. A NEW package, or a new
# heavy script in an existing one, is therefore a failure the day it lands
# rather than the day someone remembers to look.
#
# WHAT COUNTS AS A DOOR: a package.json script that reaches a runner pool --
# vitest / bun test / playwright / astro check -- directly, or one hop through
# `bash <script>.sh`. `channels`' test is the one-hop case and the reason the
# hop is followed: its own file, not its package.json, holds the two runners.
#
# WHAT IS DELIBERATELY NOT A DOOR is in SKIP below, each with its reason. That
# list is the argument, not an allowlist of convenience.
#
# A LOCK IS NOT A SLOT. Until 2026-09-07 the typecheck skip below read "tsc
# already has its own lock via tsc-cached.sh", and that reasoning is wrong in a
# way that cost the machine: gate_lock is keyed by FOLDER and dedupes identical
# work, while a SLOT caps concurrent heavy work machine-wide. N worktrees are N
# folders, so N locks are all uncontended while N typecheckers run. Measured that
# day: three 2.5GB tsc processes at once, load 171, localhost at 8.4s a page, and
# THIS CHECKER REPORTING "0 open". The "2-second typecheck" half was wrong too --
# the measured runs were 2.5GB and 7+ minutes. The compute sites now take a slot
# (see the `compute sites` section below, which is what would have caught it).
# SHIPS (needs-env). In a generated factory clone this enumerates THAT repo
# package.json files, while every line in the skip list names a monorepo path
# that can never match there -- so it may report open doors it has no opinion
# about. That is loud rather than wrong: the doors it names really are
# ungoverned in that tree. Read the skip list as this repo argument, not as a
# universal one.
set -uo pipefail
# GOV_DOORS_ROOT lets --self-test point the REAL audit at a sandbox tree.
# Without it the red proof has to duplicate the classifier, and a duplicated
# classifier is the drift this file exists to avoid.
ROOT="${GOV_DOORS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT" || exit 1

HEAVY_RE='vitest|tsc[[:space:]]+--noEmit|astro[[:space:]]+check|playwright[[:space:]]+test|(^|[^a-zA-Z0-9_-])bun[[:space:]]+test([^a-zA-Z0-9_:-]|$)'

# ── the reasoned skips ──────────────────────────────────────────────────────
# <pkg-relpath>::<script>   why
skips() {
  cat <<'SKIP'
*::typecheck                routes through tsc-cached.sh, which since 2026-09-07 takes a real SLOT around its compute (gate-run.sh), not merely its dedupe lock -- and since 2026-09-13 takes that slot BEFORE the lock, never while holding it (govern-order-check.sh proves both halves). Enforced by the `compute sites` section, not asserted here
*::test:watch               a watch never exits; a wall-clock bound would kill it
*::test:raw                 an escape hatch by definition -- ungoverned is the whole point
*::verify:raw               an escape hatch by definition
*::test:coverage            watch-mode vitest (no `run`); a bound would kill it
one.ie/web::test:e2e:pw     opt-in e2e needing a live server; a 1800s bound could kill a legitimate long run
one.ie/web::test:e2e:pw:ui  interactive -- a bound would kill a human's session
one.ie/web::test:e2e:pw:debug interactive -- a bound would kill a human's session
backup::test                2 test files under `bun test`, no fork pool -- cannot be the memory driver
packages/evals::test        1 test file -- cannot be the memory driver
packages/plugin-pages::test 1 test file -- cannot be the memory driver
packages/plugin-pages::build tsc --noEmit wearing a build's name; same reason as typecheck
pay/packages/one-protocol::test watch-mode vitest (no `run`) AND 0 test files -- see FINDINGS
pay/packages/sdk::test      0 test files
oo-brain::typecheck         not a deployed service
template/site::typecheck    Astro 7 template, not a deployed service
template-release::test      a release template, not a live package
template-release::verify    a TEMPLATE: it is copied out to users WITHOUT .claude/, so wrapping it would bake in a gate-run.sh path that does not exist downstream and break the template itself
SKIP
}

is_skipped() { # is_skipped <pkgdir> <script>
  local pkg="$1" name="$2" k v
  while read -r k v; do
    [ -z "$k" ] && continue
    case "$k" in
      "*::$name")      return 0 ;;
      "$pkg::$name")   return 0 ;;
    esac
  done < <(skips)
  return 1
}

# ── enumerate ───────────────────────────────────────────────────────────────
# Emits: <state> <pkgdir> <script> <command>   state = GOVERNED|OPEN|SKIP
# Tracked files in a repo; a plain walk in a sandbox. Never node_modules.
_list_package_jsons() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git ls-files '*package.json' | grep -v node_modules
  else
    find . -name package.json -not -path '*/node_modules/*' | sed 's|^\./||'
  fi
}

enumerate() {
  local pj
  while IFS= read -r pj; do
    [ -f "$pj" ] || continue
    node -e '
      const fs=require("fs"), path=require("path");
      const pj=process.argv[1], dir=path.dirname(pj);
      let j; try{ j=JSON.parse(fs.readFileSync(pj,"utf8")); }catch(e){ process.exit(0); }
      const heavy=/vitest|tsc\s+--noEmit|astro\s+check|playwright\s+test|(^|[^\w-])bun\s+test([^\w:-]|$)/;
      const scripts=j.scripts||{};
      for(const [k,v] of Object.entries(scripts)){
        let reaches=heavy.test(v), via="", hopGoverned=false;
        // ONE HOP: `bash scripts/test.sh` hides its runners in its own file.
        // Two traps, both hit on the FIRST run of this checker:
        //  - install-hooks.sh only NAMES tsc, in a comment and an echo. A bare
        //    mention is not an invocation, so the hop is position-anchored the
        //    same way hook:governor-escape is. It is the same scar
        //    this repo already carries under "a hook greps the whole
        //    command"; reproducing it here made the checker cry wolf
        //    on six innocent scripts.
        //  - verify-fast.sh IS governed: it routes everything through
        //    gate-run.sh internally. Governance can live in the HOPPED file,
        //    so it has to be read there too, not only in package.json.
        if(!reaches){
          // Take EVERY `bash <x>.sh` in the value and skip gate-run.sh itself:
          // once a one-hop script is wrapped, the first .sh in the string is the
          // wrapper, and matching only that made channels and the three demos
          // vanish from this audit the moment they were fixed. A guard that goes
          // blind on the thing it just repaired cannot detect a later regression.
          const all=[...v.matchAll(/bash\s+([^\s;&|]+\.sh)/g)].map(function(x){return x[1];});
          const wrapped=all.some(function(x){return /gate-run\.sh$/.test(x);});
          const m=all.filter(function(x){return !/gate-run\.sh$/.test(x);}).map(function(x){return [null,x];})[0];
          if(m){
            const hp=path.join(dir,m[1]);
            try{
              // Comments are prose, never invocations. install-hooks.sh
              // line 2 reads "(astro check + tsc)" -- the bare paren made
              // it look like a command position. Strip comments first.
              const body=fs.readFileSync(hp,"utf8")
                .split("\n").filter(function(l){return !/^\s*#/.test(l);}).join("\n");
              const invoked=new RegExp(
                "(^|[;&|(]|&&|\\|\\|)[ \\t]*([A-Za-z_][A-Za-z0-9_]*=[^ \\t]*[ \\t]+)*"+
                "((bunx|npx|bun|npm|xargs)[ \\t]+)*"+
                "(vitest|tsc[ \\t]+--noEmit|astro[ \\t]+check|playwright[ \\t]+test|bun[ \\t]+test)","m");
              if(invoked.test(body)){
                reaches=true; via=" [via "+m[1]+"]";
                // governed either by the wrapper in package.json, or because the
                // hopped file routes through gate-run.sh internally (verify-fast).
                if(wrapped || /gate-run\.sh/.test(body)) hopGoverned=true;
              }
            }catch(e){}
          }
        }
        if(!reaches) continue;
        const governed=/gate-run\.sh/.test(v) || hopGoverned;
        console.log((governed?"GOVERNED":"OPEN")+"\t"+dir+"\t"+k+"\t"+v+via);
      }
    ' "$pj"
  done < <(_list_package_jsons)
}

bad=0
ok()   { printf '  ok    %s\n' "$*"; }
nope() { printf '  FAIL  %s\n' "$*"; bad=$((bad + 1)); }

audit() {
  echo "== doors — every heavy package script is governed, or skipped for a stated reason"
  local state pkg name cmd n_gov=0 n_skip=0
  while IFS=$'\t' read -r state pkg name cmd; do
    [ -z "${state:-}" ] && continue
    if [ "$state" = "GOVERNED" ]; then n_gov=$((n_gov+1)); continue; fi
    if is_skipped "$pkg" "$name"; then n_skip=$((n_skip+1)); continue; fi
    nope "UNGOVERNED heavy script: (cd $pkg && bun run $name)  ->  $cmd"
    printf '        fix: wrap it — bash <rel>/.claude/scripts/gate-run.sh %s -- %s\n' "$name" "$cmd"
  done < <(enumerate)
  [ "$bad" -eq 0 ] && ok "$n_gov governed, $n_skip skipped with a reason, 0 open"
}

# ── the wrapped paths must actually resolve ────────────────────────────────
# Every wrap names gate-run.sh RELATIVELY, resolved from the package dir that
# `bun run` cd's into. A wrong `../` count is the one way wrapping can break a
# script, and it would surface only when somebody ran it -- months later, as a
# "test command is broken" that nobody connects to this change. Derived from the
# enumeration, never from a list, so a package wrapped tomorrow is checked too.
paths() {
  echo "== wrapped paths — every relative gate-run.sh resolves from its package dir"
  local state pkg name cmd rel n=0
  while IFS=$'\t' read -r state pkg name cmd; do
    [ "${state:-}" = "GOVERNED" ] || continue
    rel=$(printf '%s' "$cmd" | sed -nE 's|.*bash ([^ ]*gate-run\.sh) .*|\1|p' | head -1)
    [ -n "$rel" ] || continue
    case "$rel" in /*) [ -f "$rel" ] && { n=$((n+1)); continue; } ;; esac
    if [ -f "$pkg/$rel" ]; then
      n=$((n+1))
    else
      nope "$pkg :: $name names $rel, which does NOT resolve from $pkg"
    fi
  done < <(enumerate)
  [ "$bad" -eq 0 ] && ok "$n wrapped scripts, every relative path resolves"
}

# ── re-entrancy: the one way wrapping could make things WORSE ───────────────
# gate-run is re-entrant by design (GOVERN_IN_GATE), so a wrapped `test` called
# from a wrapped `verify` must inherit the outer slot rather than queue behind
# it. With the cap at 1 a non-re-entrant nest DEADLOCKS -- which is exactly what
# the red half below forces, so this check is not taking re-entrancy on trust.
reentrancy() {
  echo "== re-entrancy — a wrapped gate nested in a wrapped gate must not deadlock"
  local sandbox G o e
  sandbox="$(mktemp -d)"
  G="$ROOT/.claude/scripts/gate-run.sh"
  o="$sandbox/out"; e="$sandbox/err"
  local T=30   # bound the whole experiment; the commands under test are echoes

  # NEVER capture a gate with `out=$(gate-run ... 2>&1)`. run_bounded
  # (govern.sh:130-134) forks a watchdog holding `sleep $GOVERN_GATE_TIMEOUT`,
  # deliberately detached from STDOUT on 2026-09-01 so a command substitution
  # would not block on it -- but `2>&1` reattaches it to the captured pipe, and
  # the substitution then hangs for the FULL timeout after the command has
  # already finished. Measured here: 1800s of nothing, killed at 144.
  # Redirect to files and read the files.

  # GREEN: the nested gate inherits the outer slot even with the cap at 1.
  GOVERN_DIR="$sandbox" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=8 GOVERN_GATE_TIMEOUT=$T \
    bash "$G" outer -- bash -c \
    "GOVERN_DIR='$sandbox' GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=8 GOVERN_GATE_TIMEOUT=$T bash '$G' inner -- echo NESTED_OK" \
    >"$o" 2>"$e"
  if grep -q NESTED_OK "$o"; then
    ok "nested gate inherited the outer slot at cap 1 (no deadlock)"
  else
    nope "nested gate did NOT complete at cap 1 — deadlock. out=[$(cat "$o")] err=[$(cat "$e")]"
  fi

  # RED: clear GOVERN_IN_GATE inside, so the nest asks for a SECOND slot at cap
  # 1. It must starve -- proving the green above was re-entrancy doing the work
  # and not merely a cap that never bound.
  : > "$o"; : > "$e"
  GOVERN_DIR="$sandbox" GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=4 GOVERN_GATE_TIMEOUT=$T \
    bash "$G" outer2 -- bash -c \
    "unset GOVERN_IN_GATE; GOVERN_DIR='$sandbox' GOVERN_MAX_GATES=1 GOVERN_QUEUE_WAIT=4 GOVERN_GATE_TIMEOUT=$T bash '$G' inner2 -- echo SHOULD_NOT_RUN" \
    >"$o" 2>"$e"
  if grep -q SHOULD_NOT_RUN "$o"; then
    nope "a second slot was granted at cap 1 — the cap does not bind, so the green proves nothing"
  elif grep -q "no slot after" "$e"; then
    ok "without re-entrancy the same nest starves at cap 1 (the cap really binds)"
  else
    nope "unexpected red-half output. out=[$(cat "$o")] err=[$(cat "$e")]"
  fi
  # RED PROOF for `compute sites`: a script that spawns a heavy compute with no
  # gate-run.sh must turn compute_sites red. This is the exact shape tsc-cached.sh
  # had before 2026-09-07 -- a gate_lock, and a bare bunx tsc inside it.
  local probe_dir probe
  probe_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # NOT a dotfile: `for f in "$d"/*.sh` does not glob dotfiles, so a probe named
  # .zz-*.sh is invisible to the very check it is supposed to drive red -- the
  # proof would pass by never being seen. Named plainly, and rm'd below.
  probe="$probe_dir/zz-compute-probe.sh"
  cat > "$probe" <<'PROBE'
#!/usr/bin/env bash
# a lock, and a heavy compute with no slot -- the 2026-09-07 defect, in miniature
gate_lock "probe" 10 && bunx tsc --noEmit
PROBE
  local b0=$bad
  compute_sites >/dev/null 2>&1
  if [ "$bad" -gt "$b0" ]; then
    ok "a lock-without-slot compute site turns the audit RED"
    bad=$b0
  else
    nope "compute_sites stayed green against a bare 'bunx tsc --noEmit' with no gate-run"
  fi
  rm -f "$probe"

  rm -rf "$sandbox"
}

# ── compute sites — a gate_lock is not a slot ───────────────────────────────
#
# The `doors` section above audits PACKAGE SCRIPTS. It cannot see the defect
# that actually cost the machine on 2026-09-07, because that one lived one layer
# down: tsc-cached.sh held a per-folder gate_lock and spawned `bunx tsc` with no
# slot at all. Every door was green, the skip list had a stated reason, and three
# 2.5GB typecheckers ran concurrently while the governor reported 1 of 2 slots.
#
# The rule this enforces: ANY script here that spawns a heavy compute must also
# reference gate-run.sh. Not "takes a lock" -- a lock dedupes identical work, a
# slot bounds the machine, and only one of those is a concurrency cap.
compute_sites() {
  echo "== compute sites — a heavy compute behind a lock still needs a SLOT"
  local d f n_ok=0 hits
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for f in "$d"/*.sh; do
    case "$(basename "$f")" in
      gate-run.sh|governor-doors-check.sh|governor-escape-check.sh|machine-check.sh) continue ;;
      # FIXTURES — these NAME a heavy command as test data and spawn nothing:
      #   load-guard-check.sh   passes command STRINGS to the hook  ( check 1 "bunx ..." )
      #   govern-mem-check.sh   embeds them in JSON tool_input payloads
      #   deploy-gate-check.sh  greps deploy.sh for the command as a PATTERN
      # Each was verified by reading the matching lines, not assumed.
      load-guard-check.sh|govern-mem-check.sh|deploy-gate-check.sh) continue ;;
    esac
    # PRESENCE, not command-position. The first version of this asked "is the
    # compute in command position", blanking quoted regions -- and it could not
    # see the very defect it was written for: tsc-cached.sh spawned its tsc from
    # inside a quoted `bash -c "... ${TSC_CACHE_CMD:-bunx tsc --noEmit} ..."`.
    # Reverting tsc-cached.sh to its pre-fix state left that check GREEN, which
    # is the only test of a checker that matters.
    #
    # So the rule is blunt on purpose: if a heavy token appears outside a comment,
    # this file must reference gate-run.sh somewhere. Scripts that only NAME a
    # command as a test fixture are handled by FIXTURES below, by name and with a
    # reason -- the same "the skip list is the argument" doctrine as the doors.
    hits=$(grep -nE '(bunx|npx|bun x) +(tsc +--noEmit|vitest +run)' "$f" 2>/dev/null \
           | grep -vE '^[0-9]+:[[:space:]]*#' || true)
    [ -n "$hits" ] || continue
    if grep -q 'gate-run\.sh' "$f"; then
      n_ok=$((n_ok+1))
    else
      nope "$(basename "$f") spawns a heavy compute with no gate-run.sh anywhere:
$(printf '%s' "$hits" | head -3 | sed 's/^/          /')"
    fi
  done
  [ "$bad" -eq 0 ] && ok "$n_ok script(s) spawn a heavy compute, every one routes through gate-run.sh"
}

# ── red proof ───────────────────────────────────────────────────────────────
self_test() {
  echo "== self-test — plant an open door, the REAL audit must go RED"
  local sandbox out rc
  sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/planted"
  cat > "$sandbox/planted/package.json" <<'PKG'
{ "name": "planted", "scripts": { "test": "vitest run" } }
PKG
  # Drive audit() itself, in a sandbox tree, through the same enumerate().
  out=$(GOV_DOORS_ROOT="$sandbox" GOV_DOORS_INNER=1 bash "${BASH_SOURCE[0]}" 2>&1); rc=$?
  if [ $rc -ne 0 ] && printf '%s' "$out" | grep -q 'UNGOVERNED heavy script'; then
    ok "a planted ungoverned test makes the real audit go RED"
  else
    nope "planted open door did not turn the audit red (rc=$rc): $out"
  fi

  # And the inverse: wrapping the SAME script must clear the SAME audit.
  cat > "$sandbox/planted/package.json" <<'PKG'
{ "name": "planted", "scripts": { "test": "bash ../.claude/scripts/gate-run.sh t -- vitest run" } }
PKG
  out=$(GOV_DOORS_ROOT="$sandbox" GOV_DOORS_INNER=1 bash "${BASH_SOURCE[0]}" 2>&1); rc=$?
  if [ $rc -eq 0 ]; then
    ok "wrapping the same script clears the same audit"
  else
    nope "wrapped script still reads open: $out"
  fi
  rm -rf "$sandbox"
}

case "${1:-}" in
  --list)      enumerate | sort | column -t -s$'\t' 2>/dev/null || enumerate | sort; exit 0 ;;
  --self-test) self_test ;;
  *)           if [ -n "${GOV_DOORS_INNER:-}" ]; then audit
               else audit; echo; paths; echo; compute_sites; echo; reentrancy; echo; self_test; fi ;;
esac

echo
if [ "$bad" -eq 0 ]; then echo "RESULT: PASS — no ungoverned heavy door, and nesting does not deadlock"
else echo "RESULT: RED — $bad failure(s)"; exit 1; fi
