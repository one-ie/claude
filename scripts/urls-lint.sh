#!/usr/bin/env bash
# urls-lint.sh — shrink-only root lint (text/urls.md § reserved prefix set).
#
# one.ie's root-level src/pages/*.astro is frozen at the set below (verified
# 2026-07-20). A new top-level page must be added to this allowlist by hand —
# an amendment to the law, never a silent file drop. The set can only shrink
# (a deletion needs no allowlist change); any file NOT on the list fails.
set -euo pipefail

PAGES_DIR="one.ie/web/src/pages"

# The frozen baseline — every root .astro page that existed at promise-making,
# grouped by text/urls-plan.md's route-classification buckets (platform /
# console-slugless / identity / system / redirect-pending-deletion / dead).
FROZEN_ROOT_PAGES=(
  # platform — marketing/product
  index pricing agents agency affiliates brand chatbots components contracts
  crm-platform design developers "enterprise-license" "free-license" "get-yours"
  join leaderboard license marketing "marketing-studio" marketplace models
  partners playbook proof scale security showcase speed sui teams tools
  upgrade "thankyou-playbook"
  # console-slugless
  dashboard settings analytics chat skills build create editor in memory
  profile credits payments rewards tracking watch stream meet classroom
  learning activity do cc device motion "self-improving"
  # console-slugless — AMENDMENT 2026-08-26 (slugless-doors). Two deliberate
  # additions, each a session-resolved door that rewrites/redirects into
  # /u/<workspace>/<room> and renders nothing of its own. Both words are
  # declared in RESERVED_PREFIXES (src/lib/urls/law.ts) and added to
  # RESERVED_SLUGS so no future workspace can claim them.
  tasks w
  # platform — AMENDMENT 2026-09-05 (ad front door). `ad` is a paid-traffic
  # landing page, not a door: it renders one `auraHeroes` split-test variant
  # full-bleed and resolves nothing about the viewer. It is listed in
  # ASTRO_PORTABLE (src/lib/urls/law.ts) so one host's brand is the only thing
  # that changes between one.ie/ad, app.one.ie/ad and a tenant domain — which
  # is a routing BYPASS, and takes the bare word away from workspace `one`'s
  # published page of the same slug (still served at /p/ad and /u/one/p/ad).
  ad
  # console-slugless — AMENDMENT 2026-09-20 (the nineteen root words). The
  # operator's rule: "every icon should point to a page on the top level of the
  # same name" — so the dock's nineteen words are addresses a person types and
  # shares, and the workspace is resolved from who is asking. Eleven need a new
  # root page; the other eight already had one (dashboard · agents · skills ·
  # tools · motion are files, workflows · documents are directories, sound has
  # no surface and therefore no page).
  #
  # THIS IS THE AMENDMENT THE HEADER DEMANDS, not a silent file drop — and it
  # is the first one that GROWS root by more than two. Stated plainly so the
  # next reader can weigh it: "the set can only shrink" was written when root
  # was a junk drawer of marketing pages. These eleven are not that. Each one
  # renders nothing of its own, resolves through one table (`lib/nav/doors.ts`)
  # and one resolver (`lib/nav/door-resolve.ts`), and is reserved in
  # CONSOLE_WORDS + RESERVED_SLUGS in the same change. Root grows once, by a
  # closed set, to become the console's address space.
  people messages pictures video campaigns posts wallets products customers
  tracking learning sound
  # identity
  signin signup recover "recovery-codes" "auth-security" unsubscribe
  # system
  404 500
  # redirect — superseded, C4 deletes these; kept on the allowlist so the lint
  # is green both before and after that deletion (shrinking, never growing)
  "index-new" "index-open" home
  # dead — unreferenced, flagged for a future lever-4 cycle, not this promise
  dotsdemo
  # NOT GRANDFATHERED, on purpose (noted 2026-08-26 by slugless-doors): nine root
  # pages are committed to main with no allowlist amendment, so this lint — and
  # therefore text/urls.md's proof: — is RED for reasons that predate and are
  # unrelated to the slugless doors:
  #   asi1 · chat-block · factory · loading · media · pay-blocks · sell ·
  #   speed-metrics · x402
  # They are deliberately left OFF this list. Absorbing them would turn nine live
  # violations into permanent grandfathering and make a green lint mean less than
  # it does. Whoever added them owns the amendment or the deletion.
)

is_allowed() {
  local name="$1"
  for allowed in "${FROZEN_ROOT_PAGES[@]}"; do
    [ "$name" = "$allowed" ] && return 0
  done
  return 1
}

fail=0
for file in "$PAGES_DIR"/*.astro; do
  [ -e "$file" ] || continue
  base="$(basename "$file" .astro)"
  if ! is_allowed "$base"; then
    echo "urls-lint: FAIL — '$base.astro' is not on the frozen root allowlist (text/urls.md § reserved prefix set). Root can only shrink." >&2
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "urls-lint: OK — every root page is accounted for."
fi
exit "$fail"
