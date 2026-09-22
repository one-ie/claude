#!/usr/bin/env bash
# factory-secret-gate.sh — the secret scan, and the thing that makes it
# unskippable. A3 of text/do-factory-plan.md.
#
#   bash .claude/scripts/factory-secret-gate.sh --scan [--staged|--worktree] [--repo <dir>]
#   bash .claude/scripts/factory-secret-gate.sh --install [--repo <dir>] [--quiet]
#   bash .claude/scripts/factory-secret-gate.sh --self-test
#
# WHY THIS IS A GIT HOOK AND NOT A PROMPT LINE.
# do-auto.sh runs `_secret_gate` as SHELL before it commits, so the model cannot
# skip it. In the factory executor, Build is one agent() spawn and the commit is
# a numbered rule in that spawn's prompt — a sentence a doer under pressure is
# asked to obey, after which `committed:true` is self-reported. Moving the scan
# to another sentence is not a port. A `pre-commit` hook runs on the commit
# whether or not anybody remembered it. `--no-verify` is the one remaining door
# and .claude/hooks/commit-verify-guard.sh closes it for agents.
#
# THE RECEIPT that one install covers every tree: `git rev-parse --git-path
# hooks` from a LINKED worktree prints the MAIN repo's hooks dir (measured in
# .claude/worktrees/dev: `<repo>/.git/hooks`), and core.hooksPath is unset
# (exit 1). Worktrees share one hooks directory, so one installed `pre-commit`
# covers all of them — including a worktree a prompt line created by hand.
#
# THE PATTERNS ARE OURS, AND HERE IS THE TRADEOFF. do-w4-gates.sh's shape is
# `absent tool ⇒ unrun ⇒ blocks`; gitleaks and trufflehog are BOTH ABSENT on
# this box. Installing that shape repo-wide would refuse every commit in every
# tree from the moment it landed, including the commit that lands it. So the
# builtin pattern set always runs and a real scanner is an UPGRADE WHEN PRESENT,
# never a precondition. Fail closed therefore means A MATCH BLOCKS — and both
# do-auto.sh's degrade-to-pass and do-w4-gates.sh's absent⇒unrun are refused,
# for different reasons. Cost, named: a hand-rolled pattern set has a
# false-negative surface a real scanner does not. That is the price of a gate
# that can be installed on this box today, and it is the right trade only
# because the alternative is a gate that is never installed at all.
#
# NOTHING MATCHED IS EVER ECHOED. A refusal names the path, the pattern LABEL
# and a line number; never the line. The register is packages/recover's CLI:
# "an unknown argument may BE your recovery phrase, and printing it would put it
# on your screen and in your scrollback". do-auto.sh:999 prints `hits`; that is
# the half of the old gate this port deliberately drops.
#
# Exit codes are distinct and named:
#   0  clean / installed / self-test green
#   3  a secret-shaped string is in the change  (the refusal)
#   4  usage
#   5  the tracked hook body could not be resolved (emitted by the installed
#      shim, not by this file) — an absent scanner is not a clean scan
#   6  install refused: a foreign pre-commit hook is already there
#   7  self-test red
#
# `set -uo pipefail`, never `-e`: this script reads exit codes as answers.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BODY_REL=".claude/hooks/git/pre-commit"
SHIM_MARK="factory-secret-gate:shim:v1"

# ── the pattern set ──────────────────────────────────────────────────────────
# `label regex` per line; the label is the first word, the regex is the rest of
# the line (so a regex may contain spaces). The first six are do-auto.sh:998
# verbatim. The seventh is one of this repo's own recorded leak shapes: a Stripe
# LIVE secret/restricted key, which the `sk-` pattern cannot see because Stripe
# uses an underscore. Publishable keys (`pk_`) are deliberately absent — they
# are not secrets and flagging them would teach people to pass --no-verify.
#
# None of these self-matches this file: every one is written here with a bracket
# expression or a quantifier immediately after its literal prefix, so the
# literal text `AKIA[0-9A-Z]{16}` is not an `AKIA` followed by 16 alnums.
#
# FSG_PATTERNS overrides the set with a file of the same shape. It exists so the
# self-test can hand the scanner a DELIBERATELY BROKEN matcher and prove the
# scanner refuses instead of reporting clean — see the matcher-failure case.
_patterns() {
  if [ -n "${FSG_PATTERNS:-}" ]; then cat "$FSG_PATTERNS"; return; fi
  cat <<'PAT'
aws-access-key-id AKIA[0-9A-Z]{16}
private-key-block -----BEGIN [A-Z ]*PRIVATE KEY-----
api-key-sk sk-[A-Za-z0-9]{20,}
github-token gh[pousr]_[A-Za-z0-9]{20,}
slack-token xox[baprs]-[A-Za-z0-9-]{10,}
google-api-key AIza[0-9A-Za-z_-]{30,}
stripe-live-secret-key (sk|rk)_live_[A-Za-z0-9]{16,}
PAT
}

# ── the scan ─────────────────────────────────────────────────────────────────
# Added lines only, of the STAGED change. Staged and not `diff HEAD`: a
# pre-commit hook that read the whole worktree would refuse YOUR commit because
# a NEIGHBOUR left an unstaged file open — ten worktrees share this repo. The
# `^+++` header is dropped explicitly: a path can match a pattern.
#
# Line numbers come from the hunk headers, computed here rather than by awk's
# match(), because BSD awk's ERE support for {n,m} intervals is not something to
# bet a security gate on. grep -E does the matching; awk only counts.
_added_numbered() { # <repo> <diffmode> <file>  → "<newline-no>:<content>" per added line
  local repo="$1" mode="$2" f="$3"
  if [ "$mode" = "staged" ]; then
    git -C "$repo" diff --cached -U0 -- "$f" 2>/dev/null
  else
    git -C "$repo" diff HEAD -U0 -- "$f" 2>/dev/null
  fi | awk '
    /^@@/ { p = index($0, "+"); s = substr($0, p + 1); split(s, g, /[ ,]/); ln = g[1] + 0; next }
    /^\+\+\+/ { next }
    /^\+/ { print ln ":" substr($0, 2); ln++ }
  '
}

_changed_files() { # <repo> <diffmode>
  local repo="$1" mode="$2"
  if [ "$mode" = "staged" ]; then
    git -C "$repo" diff --cached --name-only --diff-filter=ACMR 2>/dev/null
  else
    git -C "$repo" diff HEAD --name-only --diff-filter=ACMR 2>/dev/null
  fi
}

# scan_change <repo> <staged|worktree> → 0 clean, 3 hit. Prints the refusal on
# stderr. Never prints a matched line.
scan_change() {
  local repo="$1" mode="$2" rc=0
  local f label re added lines n first

  # AN UNRUN SCAN IS NOT A CLEAN SCAN. Everything below reads `git` output, and
  # every read is `|| true`-shaped by construction — so a git that cannot run at
  # all produces an empty file list and the gate reports CLEAN. Measured
  # 2026-09-21: run with /usr/bin first on PATH, macOS's Xcode git shim exits 69
  # ("You have not agreed to the Xcode license agreements") on EVERY invocation,
  # and this scanner passed a repo with a planted key. gate-run.sh's 127 wearing
  # a different hat. So the repository is proven readable before anything is
  # trusted to be absent.
  local grv
  grv="$(git -C "$repo" rev-parse --git-dir 2>&1)"
  if [ $? -ne 0 ] || [ -z "$grv" ]; then
    echo "[factory-secret-gate] REFUSED: cannot read the repository at $repo." >&2
    echo "  git said: ${grv:-<nothing>}" >&2
    echo "  An unrun scan is not a clean scan." >&2
    return 3
  fi

  while IFS= read -r f; do
    [ -z "$f" ] && continue
    added="$(_added_numbered "$repo" "$mode" "$f")"
    [ -z "$added" ] && continue
    while IFS=' ' read -r label re; do
      [ -z "$label" ] && continue
      # `-- "$re"` is load-bearing, not tidiness. The private-key pattern starts
      # with `-----`, and without the `--` grep parses it as OPTIONS: it printed
      # `unrecognized option` to stderr and exited 2, the pipeline read 2 as
      # "no lines", and the whole gate reported CLEAN while one of its seven
      # patterns had never run. Measured 2026-09-21 on the commit that lands
      # this file — the self-test was green at the time, because it only ever
      # planted an AKIA fixture. Every pattern now gets its own fixture, and a
      # matcher that FAILS is a refusal, never a pass: grep exits 0 on a match,
      # 1 on none, and ≥2 on an error, so only 1 may mean "clean".
      local matched grc
      matched="$(printf '%s\n' "$added" | grep -E -- "$re")"; grc=$?
      if [ "$grc" -gt 1 ]; then
        echo "[factory-secret-gate] REFUSED: the matcher for [$label] failed (grep exit $grc)." >&2
        echo "  A broken scanner is not a clean scan." >&2
        rc=3; continue
      fi
      [ "$grc" -ne 0 ] && continue
      lines="$(printf '%s\n' "$matched" | cut -d: -f1 | head -5 | tr '\n' ' ')"
      n="$(printf '%s\n' "$matched" | wc -l | tr -d ' ')"
      first="$(printf '%s' "$lines" | sed 's/[[:space:]]*$//')"
      if [ "$rc" -eq 0 ]; then
        echo "[factory-secret-gate] REFUSED: a secret-shaped string is in this change." >&2
        echo "  The matched text is NOT printed — an unknown string may BE the secret." >&2
      fi
      printf '    %s  [%s]  %s match(es), line(s): %s\n' "$f" "$label" "$n" "$first" >&2
      rc=3
    done < <(_patterns)
  done < <(_changed_files "$repo" "$mode")

  # A real scanner is an UPGRADE, never a precondition. Absence is not a verdict:
  # the builtin sweep above has already run either way.
  if [ -z "${FSG_FORCE_BUILTIN:-}" ]; then
    if command -v gitleaks >/dev/null 2>&1 && [ "$mode" = "staged" ]; then
      gitleaks protect --staged --redact -q --source "$repo" >/dev/null 2>&1 || {
        echo "[factory-secret-gate] gitleaks flagged the staged change (output suppressed — it may quote the secret)." >&2
        rc=3
      }
    fi
  fi

  if [ "$rc" -ne 0 ]; then
    echo "" >&2
    echo "  Remove it, or move it to a secret store, then commit again." >&2
    echo "  Look at it yourself:  git diff --cached -- <path>" >&2
    echo "  This gate is a git pre-commit hook on purpose: --no-verify is refused for agents" >&2
    echo "  by hook:commit-verify-guard. A human overriding a false positive owns that call." >&2
  fi
  return "$rc"
}

# ── the installer ────────────────────────────────────────────────────────────
# `.git/hooks/` is UNTRACKED, so the tracked body cannot install itself — this
# does, idempotently and silently, from hooks/session-start.sh.
#
# THE SHIM PINS AN ABSOLUTE BODY PATH, and that is not a detail. Ten worktrees
# share one hooks dir and most of them sit on branches cut BEFORE this body
# existed; a shim that resolved the body only from the committing tree would
# fail closed in every one of them and take `git commit` away from nine agents
# at the next session start. So the shim resolves in order: the committing
# tree's own body (a tree's own rules win), then the pinned absolute path, then
# — and only then — it REFUSES, naming both paths it looked at.
#
# `--git-path hooks` is the receipt AND the mechanism: from a linked worktree it
# prints the MAIN repo's hooks dir, which is why one install covers every tree.
# It can answer RELATIVELY (`.git/hooks`) — relative to the repo root, not to
# this process's cwd — so an absolute form is rebuilt here or the installer
# writes into whatever directory it happened to be launched from.
hooks_dir() { # <repo>
  local repo="$1" hp top
  top="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null)"
  [ -z "$top" ] && return 1
  hp="$(git -C "$repo" config --get core.hooksPath 2>/dev/null)"
  [ -z "$hp" ] && hp="$(git -C "$repo" rev-parse --git-path hooks 2>/dev/null)"
  [ -z "$hp" ] && return 1
  case "$hp" in
    /*) printf '%s' "$hp" ;;
    *)  printf '%s/%s' "$top" "$hp" ;;
  esac
}

_shim_text() { # <abs body path>
  cat <<SHIM
#!/usr/bin/env bash
# $SHIM_MARK — generated by .claude/scripts/factory-secret-gate.sh --install.
# DO NOT EDIT: --install rewrites it. Untracked by design; .git/hooks is shared
# by every worktree of this repo, which is why one install covers all of them.
set -uo pipefail
_top="\$(git rev-parse --show-toplevel 2>/dev/null)"
_pinned="$1"
_body=""
[ -n "\$_top" ] && [ -r "\$_top/$BODY_REL" ] && _body="\$_top/$BODY_REL"
[ -z "\$_body" ] && [ -r "\$_pinned" ] && _body="\$_pinned"
if [ -z "\$_body" ]; then
  echo "[factory-secret-gate] REFUSING this commit: the tracked hook body is missing." >&2
  echo "  looked for: \${_top:-<no worktree>}/$BODY_REL" >&2
  echo "          and: \$_pinned" >&2
  echo "  An absent scanner is not a clean scan. Restore the body, or run:" >&2
  echo "    bash .claude/scripts/factory-secret-gate.sh --install" >&2
  exit 5
fi
exec bash "\$_body" "\$@"
SHIM
}

install_hook() { # <repo> <quiet?>
  local repo="$1" quiet="${2:-}" hd target body cur want
  body="${FSG_BODY:-$ROOT/$BODY_REL}"
  # Never pin a body that is not there: a session started in a worktree whose
  # branch predates this rung would otherwise DEGRADE a working shim.
  if [ ! -r "$body" ] && [ -z "${FSG_ALLOW_MISSING_BODY:-}" ]; then
    [ -z "$quiet" ] && echo "[factory-secret-gate] no hook body at $body — nothing installed" >&2
    return 0
  fi
  hd="$(hooks_dir "$repo")"
  [ -z "$hd" ] && { [ -z "$quiet" ] && echo "[factory-secret-gate] not a git repo: $repo" >&2; return 0; }
  mkdir -p "$hd" 2>/dev/null
  target="$hd/pre-commit"
  want="$(_shim_text "$body")"
  if [ -e "$target" ] && ! grep -q "$SHIM_MARK" "$target" 2>/dev/null; then
    echo "[factory-secret-gate] a foreign pre-commit hook is already installed at $target — refusing to overwrite it." >&2
    return 6
  fi
  cur=""
  [ -r "$target" ] && cur="$(cat "$target" 2>/dev/null)"
  if [ "$cur" = "$want" ] && [ -x "$target" ]; then
    [ -z "$quiet" ] && echo "[factory-secret-gate] pre-commit already installed at $target"
    return 0
  fi
  printf '%s\n' "$want" > "$target" || return 6
  chmod +x "$target" 2>/dev/null
  [ -z "$quiet" ] && echo "[factory-secret-gate] installed pre-commit at $target"
  return 0
}

# ── the self-test ────────────────────────────────────────────────────────────
# Six cases, all in temp repos — NEVER against this tree's .git/hooks, whose
# contents are untracked and differ per clone. Case (1) is the rung: a doer that
# skips the scan is refused anyway. Case (6) is the one that makes the other
# five mean anything.
BAD=0
ok()   { printf '  ok    %s\n' "$*"; }
nope() { printf '  FAIL  %s\n' "$*"; BAD=$((BAD + 1)); }

# Composed, never written whole: a literal fixture in this file would be matched
# by this file's own scan the moment someone staged an edit to it. Every one is
# split immediately after its literal prefix, so the file's own added lines can
# never match the pattern the fixture is for.
FIXTURE_KEY="AKIA""1234567890ABCDEF"

# One fixture PER PATTERN. Without this the gate could ship with a pattern that
# never runs and a self-test that stays green — which is exactly what happened
# to the private-key pattern (see the `--` note in scan_change).
_fixture_for() { # <label> → a string that pattern must catch
  case "$1" in
    aws-access-key-id)      printf '%s' "AKIA""1234567890ABCDEF" ;;
    private-key-block)      printf '%s' "-----BEGIN ""RSA PRIVATE KEY-----" ;;
    api-key-sk)             printf '%s' "sk-""abcdefghijklmnopqrstuvwxyz0123" ;;
    github-token)           printf '%s' "ghp_""abcdefghijklmnopqrstuvwxyz0123" ;;
    slack-token)            printf '%s' "xoxb-""1234567890-abcdefghij" ;;
    google-api-key)         printf '%s' "AIza""SyAbcdefghijklmnopqrstuvwxyz0123456" ;;
    stripe-live-secret-key) printf '%s' "sk_live_""abcdefghijklmnop" ;;
    *)                      printf '' ;;
  esac
}

_mkrepo() {
  local d; d="$(mktemp -d)"
  git -C "$d" init -q >/dev/null 2>&1
  git -C "$d" config user.email gate@test.invalid
  git -C "$d" config user.name gate
  git -C "$d" config commit.gpgsign false
  printf 'seed\n' > "$d/seed.txt"
  git -C "$d" add seed.txt >/dev/null 2>&1
  git -C "$d" commit -q -m seed >/dev/null 2>&1
  printf '%s' "$d"
}

# A doer's commit: no scan called, nothing but `git commit`.
_doer_commits() { # <repo> <file> <content> → echoes "rc=<n> head=<sha>"
  local d="$1" f="$2" c="$3" rc head
  printf '%s\n' "$c" > "$d/$f"
  git -C "$d" add "$f" >/dev/null 2>&1
  git -C "$d" commit -q -m "doer commit" >/dev/null 2>&1; rc=$?
  head="$(git -C "$d" rev-parse HEAD 2>/dev/null)"
  printf 'rc=%s head=%s' "$rc" "$head"
}

self_test() {
  echo "== factory-secret-gate --self-test"

  # ---------------------------------------------------------------- case 1
  echo "== 1. the doer that SKIPS the scan is refused anyway"
  local d before after out rc
  d="$(_mkrepo)"; before="$(git -C "$d" rev-parse HEAD)"
  install_hook "$d" quiet >/dev/null 2>&1
  [ -x "$d/.git/hooks/pre-commit" ] && ok "shim installed into the repo's shared hooks dir" \
    || nope "shim not installed"
  out="$(_doer_commits "$d" "leak.txt" "aws_key = \"$FIXTURE_KEY\"")"
  rc="${out#rc=}"; rc="${rc%% *}"; after="${out##*head=}"
  [ "$rc" -ne 0 ] && ok "git commit refused (exit $rc) — the doer never called the scan" \
    || nope "git commit SUCCEEDED with a secret staged (exit $rc)"
  [ "$after" = "$before" ] && ok "HEAD unchanged — nothing was committed" \
    || nope "HEAD moved $before → $after"
  # and the refusal does not echo the secret
  local refusal
  refusal="$(cd "$d" && git commit -m x 2>&1)"
  case "$refusal" in
    *"$FIXTURE_KEY"*) nope "the refusal ECHOED the matched secret" ;;
    *) ok "the refusal names the path and the label, never the matched text" ;;
  esac
  case "$refusal" in
    *"aws-access-key-id"*) ok "the refusal names which pattern bit" ;;
    *) nope "the refusal does not name the pattern" ;;
  esac
  rm -rf "$d"

  # ---------------------------------------------------------------- case 2
  echo "== 2. a clean change still commits"
  d="$(_mkrepo)"; before="$(git -C "$d" rev-parse HEAD)"
  install_hook "$d" quiet >/dev/null 2>&1
  out="$(_doer_commits "$d" "fine.txt" "just some ordinary prose, no keys here")"
  rc="${out#rc=}"; rc="${rc%% *}"; after="${out##*head=}"
  [ "$rc" -eq 0 ] && ok "clean commit allowed" || nope "clean commit REFUSED (exit $rc)"
  [ "$after" != "$before" ] && ok "HEAD moved — the gate is not a blanket refusal" \
    || nope "HEAD did not move on a clean commit"
  rm -rf "$d"

  # ---------------------------------------------------------------- case 3
  echo "== 3. tool absence is not a verdict — builtin blocks, and still passes clean"
  command -v gitleaks >/dev/null 2>&1 && echo "       (note: gitleaks IS present on this box; forcing the builtin path)"
  d="$(_mkrepo)"
  printf 'k = "%s"\n' "$FIXTURE_KEY" > "$d/x.txt"; git -C "$d" add x.txt >/dev/null 2>&1
  FSG_FORCE_BUILTIN=1 scan_change "$d" staged >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] && ok "builtin-only scan BLOCKS a match (exit 3)" \
    || nope "builtin-only scan returned $rc on a planted secret"
  git -C "$d" reset -q >/dev/null 2>&1
  printf 'nothing to see\n' > "$d/y.txt"; git -C "$d" add y.txt >/dev/null 2>&1
  FSG_FORCE_BUILTIN=1 scan_change "$d" staged >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && ok "builtin-only scan PASSES a clean diff (exit 0)" \
    || nope "builtin-only scan returned $rc on a clean diff"
  rm -rf "$d"

  # ---------------------------------------------------------------- case 3b
  echo "== 3b. EVERY pattern has a fixture, and a BROKEN matcher refuses"
  local lbl re fx
  while IFS=' ' read -r lbl re; do
    [ -z "$lbl" ] && continue
    fx="$(_fixture_for "$lbl")"
    if [ -z "$fx" ]; then nope "pattern [$lbl] has no fixture — it may never have run"; continue; fi
    d="$(_mkrepo)"
    printf 'v = "%s"\n' "$fx" > "$d/p.txt"; git -C "$d" add p.txt >/dev/null 2>&1
    FSG_FORCE_BUILTIN=1 scan_change "$d" staged >/dev/null 2>&1; rc=$?
    [ "$rc" -eq 3 ] && ok "pattern [$lbl] catches its fixture" \
      || nope "pattern [$lbl] did NOT catch its fixture (exit $rc)"
    rm -rf "$d"
  done < <(_patterns)
  # A matcher that ERRORS must refuse, never report clean. grep exits ≥2 on a
  # bad regex; the first draft read that as "no lines" and passed.
  d="$(_mkrepo)"; local badpat; badpat="$(mktemp)"
  printf 'deliberately-broken [unclosed-bracket\n' > "$badpat"
  printf 'ordinary text\n' > "$d/q.txt"; git -C "$d" add q.txt >/dev/null 2>&1
  FSG_FORCE_BUILTIN=1 FSG_PATTERNS="$badpat" scan_change "$d" staged >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] && ok "a matcher that ERRORS refuses (exit 3) — a broken scanner is not a clean scan" \
    || nope "a broken matcher returned $rc — the gate would report clean with a dead pattern"
  rm -rf "$d" "$badpat"
  # A repository it cannot read is a REFUSAL, not a clean bill of health.
  scan_change "/nonexistent/not-a-repository" staged >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 3 ] && ok "an unreadable repository REFUSES (exit 3) — an unrun scan is not a clean scan" \
    || nope "an unreadable repository returned $rc — a broken git would pass every commit"

  # ---------------------------------------------------------------- case 4
  echo "== 4. the --no-verify door: the REAL guard, driven with a REAL payload"
  local guard deny
  guard="$ROOT/.claude/hooks/commit-verify-guard.sh"
  if [ ! -r "$guard" ]; then
    nope "commit-verify-guard.sh is missing"
  else
    local chfile; chfile="$(mktemp)"
    deny="$(printf '%s' '{"tool_name":"Bash","cwd":".","tool_input":{"command":"git commit --no-verify -m x"}}' \
      | HOOK_CHANNEL_OUT="$chfile" CLAUDE_PROJECT_DIR="$ROOT" bash "$guard" 2>/dev/null)"
    case "$deny" in
      *'"permissionDecision":"deny"'*) ok "guard DENIES git commit --no-verify" ;;
      *) nope "guard did not deny --no-verify; got: ${deny:0:80}" ;;
    esac
    # Name the channel, do not assume it: a guard reported live on a channel
    # nobody measured is the 2026-08-21 bug (hook.sh:67-73).
    [ "$(cat "$chfile" 2>/dev/null)" = "stdin" ] \
      && ok "…and it read the payload on the STDIN channel, measured not assumed" \
      || nope "the guard's payload channel was '$(cat "$chfile" 2>/dev/null)', not stdin"
    rm -f "$chfile"
    deny="$(printf '%s' '{"tool_name":"Bash","cwd":".","tool_input":{"command":"git commit -n -m x"}}' \
      | CLAUDE_PROJECT_DIR="$ROOT" bash "$guard" 2>/dev/null)"
    case "$deny" in
      *'"permissionDecision":"deny"'*) ok "guard DENIES the short form git commit -n" ;;
      *) nope "guard did not deny git commit -n" ;;
    esac
    deny="$(printf '%s' '{"tool_name":"Bash","cwd":".","tool_input":{"command":"git -c core.hooksPath=/dev/null commit -m x"}}' \
      | CLAUDE_PROJECT_DIR="$ROOT" bash "$guard" 2>/dev/null)"
    case "$deny" in
      *'"permissionDecision":"deny"'*) ok "guard DENIES the core.hooksPath override" ;;
      *) nope "guard did not deny the core.hooksPath override" ;;
    esac
    # The allow direction matters as much: a guard with false positives gets
    # switched off, which is worse than no guard at all.
    local allow
    for c in \
      'git commit -m "fix: never use --no-verify"' \
      'grep -rn "git commit --no-verify" text/' \
      'git commit -m x' \
      'echo "the escape is git commit --no-verify"'
    do
      allow="$(printf '{"tool_name":"Bash","cwd":".","tool_input":{"command":%s}}' "$(printf '%s' "$c" | sed 's/\\/\\\\/g; s/"/\\"/g; s/^/"/; s/$/"/')" \
        | CLAUDE_PROJECT_DIR="$ROOT" bash "$guard" 2>/dev/null)"
      case "$allow" in
        *'"deny"'*) nope "FALSE POSITIVE — guard denied: $c" ;;
        *) ok "allowed: $c" ;;
      esac
    done
    # DARK channel must ALLOW, never wedge the session (hook.sh:84-86).
    allow="$(CLAUDE_PROJECT_DIR="$ROOT" bash "$guard" < /dev/null 2>/dev/null)"
    case "$allow" in
      *'"deny"'*) nope "guard denied on an EMPTY payload — that wedges every session" ;;
      *) ok "an empty/DARK payload ALLOWS — the git hook carries fail-closed, not this" ;;
    esac
  fi

  # ---------------------------------------------------------------- case 5
  echo "== 5. the shim's own fail-open surface: a missing body REFUSES, naming the path"
  d="$(_mkrepo)"; before="$(git -C "$d" rev-parse HEAD)"
  FSG_BODY="/nonexistent/factory-secret-gate/pre-commit" FSG_ALLOW_MISSING_BODY=1 \
    install_hook "$d" quiet >/dev/null 2>&1
  printf 'harmless\n' > "$d/z.txt"; git -C "$d" add z.txt >/dev/null 2>&1
  refusal="$(cd "$d" && git commit -m x 2>&1)"; rc=$?
  after="$(git -C "$d" rev-parse HEAD)"
  [ "$rc" -ne 0 ] && ok "a shim whose body is gone REFUSES (exit $rc) — an absent scanner is not a clean scan" \
    || nope "a shim with no body let the commit through (exit $rc)"
  [ "$after" = "$before" ] && ok "HEAD unchanged" || nope "HEAD moved despite the missing body"
  case "$refusal" in
    */nonexistent/factory-secret-gate/pre-commit*) ok "the refusal NAMES the missing path" ;;
    *) nope "the refusal does not name the missing path" ;;
  esac
  rm -rf "$d"

  # ---------------------------------------------------------------- case 6
  echo "== 6. THE RED PROOF — gut the body and case 1 must FAIL"
  local stub; stub="$(mktemp -d)"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/pre-commit"; chmod +x "$stub/pre-commit"
  d="$(_mkrepo)"; before="$(git -C "$d" rev-parse HEAD)"
  FSG_BODY="$stub/pre-commit" install_hook "$d" quiet >/dev/null 2>&1
  out="$(_doer_commits "$d" "leak.txt" "aws_key = \"$FIXTURE_KEY\"")"
  rc="${out#rc=}"; rc="${rc%% *}"; after="${out##*head=}"
  if [ "$rc" -eq 0 ] && [ "$after" != "$before" ]; then
    ok "with the body gutted the secret COMMITS — case 1 is measuring the body, not the shim"
  else
    nope "gutted body still refused (exit $rc) — case 1 would stay green against a dead gate"
  fi
  rm -rf "$d" "$stub"

  echo ""
  if [ "$BAD" -eq 0 ]; then echo "factory-secret-gate: all checks green"; return 0; fi
  echo "factory-secret-gate: $BAD check(s) RED"; return 7
}

# ── dispatch ─────────────────────────────────────────────────────────────────
usage() {
  sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  return 4
}

MODE=""; REPO=""; DIFFMODE="staged"; QUIET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --scan)      MODE="scan" ;;
    --install)   MODE="install" ;;
    --self-test) MODE="self-test" ;;
    --manifest)  echo "portable       factory-secret-gate.sh"; exit 0 ;;
    --staged)    DIFFMODE="staged" ;;
    --worktree)  DIFFMODE="worktree" ;;
    --quiet|-q)  QUIET="quiet" ;;
    --repo)      shift; REPO="${1:-}" ;;
    -h|--help)   usage; exit 4 ;;
    *)           echo "[factory-secret-gate] unrecognised argument (not repeated — it may be a secret)" >&2; exit 4 ;;
  esac
  shift
done

[ -z "$REPO" ] && REPO="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO" ] && REPO="$PWD"

case "$MODE" in
  scan)      scan_change "$REPO" "$DIFFMODE"; exit $? ;;
  install)   install_hook "$REPO" "$QUIET"; exit $? ;;
  self-test) self_test; exit $? ;;
  *)         usage; exit 4 ;;
esac
