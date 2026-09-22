#!/usr/bin/env bash
# do-plan-json.sh <slug> — thin wrapper over do-plan-json.mjs (the parser).
# manifest: portable
# Kept as a .sh so callers match every other script in this dir; the parser is a
# real .mjs file rather than a quoted heredoc, because embedding it inline is how
# a stray backslash silently became invalid JSON.
set -euo pipefail
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/do-plan-json.mjs" "$@"
