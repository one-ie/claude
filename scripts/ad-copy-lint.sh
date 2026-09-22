#!/usr/bin/env bash
# ad-copy-lint.sh — no forbidden sentence ships.
#
# Portability: monorepo-only. It hard-asserts against THIS tree — it reads the
# LIVE worker config at one.ie/web/wrangler.toml and refuses (exit 3) when a
# subject is absent. The classification of record is the manifest in
# factory-repo.sh; this line is the copy that travels with the script.
#
# ── THE SUBJECT IS THE COPY THAT REACHES A VISITOR ─────────────────────────
# Until 2026-09-08 the subject was text/ad-sovereign-keys.md, a 94-line file
# that arrived CLEAN in the same commit as this script and never contained the
# four claims. Production /ad meanwhile carried all of them. The accept string
# was green for a day while the page lied — a lint aimed at a mirror does not
# merely miss, it MANUFACTURES a green. The subject is now three surfaces, each
# one something a visitor actually receives:
#
#   1. one.ie/web/src/lib/chat/meta/commerce.ts, the '/ad' entry only. This
#      ships from source in the worker; a visitor gets these sentences from the
#      chat on /ad. Scoped to '/ad' because this is the ad lint — '/sell' and
#      '/pricing' carry their own card claims and belong to whoever owns those
#      pages.
#   2. text/ad.md, the fenced copy blocks under "## 4. The page, as shipped"
#      plus the quoted paragraph under "### The cleared paragraph".
#      EXTRACTED POSITIVELY, never grep-minus-exclusions: §2/§3 record
#      withdrawn claims and §8 is a list of FORBIDDEN EXAMPLE sentences. Both
#      are prose ABOUT copy, not copy, and a sweep over the whole file refuses
#      the very records it is supposed to preserve. mask_subject blanks every
#      line that is not shipped copy, so reported line numbers stay true.
#   3. --live: https://one.ie/ad as served. Production /ad canonicals to
#      /u/one/p/ad and renders from the D1 `pages` row (workspace='one'
#      slug='ad', copy in the `data` column — there is no `content` column).
#      NOTHING IN THIS REPO IS THAT ROW'S SOURCE; it is edited in place. The
#      served HTML is therefore the only readable subject for it, and a public
#      GET reads no environment. Unreachable is exit 3 — no subject, no proof —
#      never 0. It is OPT-IN: do-promise-settle.sh runs the accept string
#      verbatim and a promise must not settle BROKEN on a network hiccup, so
#      the no-arg run stays offline and files 2 and 1 are what it reads. Say
#      plainly, then, what the default does NOT cover: the D1 row. Run --live
#      after any edit to it.
#
# Deliverable 5 of text/bring-one-to-life.md. The launch copy may say only what
# was measured true. Four claims were measured FALSE on 2026-09-07 and are
# refused here:
#
#   fee     "free" as a fee claim.  pay/backend/src/agent.ts:220 — the claim
#           path is "Gas + 1% fee auto-deducted". Something is deducted, so
#           nothing on this rail is free.
#   chains  "all major blockchains". There are FOUR, and they are named:
#           Sui, Ethereum, Solana, Bitcoin
#           (one.ie/web/tests/unit/vault/multichain.test.ts derives exactly
#           those four addresses and asserts they are distinct).
#   wallet  "restore it in any wallet". sui keytool takes the phrase through
#           BIP39's PBKDF2 and a BIP32 path; one.ie/web/src/lib/vault.ts:237
#           takes mnemonicToEntropy STRAIGHT into HKDF (vault.ts:281). Same
#           twenty-four words, different key. A stranger who follows that
#           sentence lands on an empty address.
#   card    any card / Apple Pay / Google Pay claim while the surface under lint
#           is not in live Stripe mode. This one is CONFIG-DERIVED: the mode is
#           read from one.ie/web/wrangler.toml at run time, never hardcoded here.
#
# THE MODE IS PER-PAGE NOW, so this rule asks a per-page question. The worker
# holds both a test and a live Stripe pair, and STRIPE_LIVE_PAGES names the exact
# page paths permitted to charge a real card (one.ie/web/src/lib/stripe-mode.ts,
# resolveStripeForPage). Two questions, one answer each:
#
#   no --page   the GLOBAL question. Copy that is not tied to one page — an ad,
#               a landing headline — may claim a card only if the whole worker is
#               live (STRIPE_MODE = "live"). One page being armed does not license
#               a sentence that appears everywhere. This is the default and it is
#               unchanged, byte for byte, from before pages existed.
#   --page P    the PAGE question. Copy that ships on page P may claim a card if
#               P is a member of STRIPE_LIVE_PAGES. Exact membership, no globs —
#               the list is normalised the same way the resolver normalises it.
#
# The card rule is the point of the whole script. It goes green two ways and
# only two ways — the CONFIG changes (STRIPE_MODE = "live", or the page joins
# STRIPE_LIVE_PAGES) or the COPY changes (the claim comes out). Editing the lint
# is not one of them, and at 2am it is the only kind of check that does not get
# argued with.
#
# It reads NO environment. do-promise-settle.sh runs the accept string verbatim,
# so an opt-in flag would settle the promise BROKEN while every check is green.
#
# Usage:
#   ad-copy-lint.sh              lint every default subject against the real config
#   ad-copy-lint.sh --page P [F] ask the PAGE question for path P (copy file F,
#                                default: every subject). Exit codes unchanged.
#   ad-copy-lint.sh --live [URL] lint the SERVED page (default https://one.ie/ad),
#                                which is the only readable form of the D1 row.
#                                Unreachable is exit 3, never 0.
#   ad-copy-lint.sh --self-test  drive every rule RED against fixtures, both
#                                ways for the config branch, then assert the
#                                clean fixture is green
#
# Exit: 0 = no forbidden sentence · 1 = a forbidden claim ships · 3 = the
#       SUBJECT is missing (the proof has no subject).
#       A missing or unparseable config is NOT exit 3 — it ARMS the card rule
#       and reports through the normal 0/1. A config the lint cannot read must
#       never read as permission, and it must never read as an error either:
#       copy with no rail sentence in it stays green whatever the toml says.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TOML_DEFAULT="$ROOT/one.ie/web/wrangler.toml"
LIVE_URL_DEFAULT="https://one.ie/ad"

# The default subjects, in order. Each is masked to its shipped copy by
# mask_subject before a single rule is applied.
subjects() {
  printf '%s\n' \
    "$ROOT/one.ie/web/src/lib/chat/meta/commerce.ts" \
    "$ROOT/text/ad.md"
}

# ---------------------------------------------------------------------------
# The rules. One line per pattern: id %% extended-regex %% why.
# Matched case-insensitively over every line of the copy, including HTML
# comments — a claim that is hidden is still a claim that shipped.
# Word edges are written (^|[^[:alpha:]]) … ([^[:alpha:]]|$) rather than \b,
# which is not portable across the greps on this box.
# ---------------------------------------------------------------------------
rules() {
  cat <<'RULES'
fee %% (^|[^[:alpha:]])(fee|gas)[- ]free([^[:alpha:]]|$) %% a fee denial. pay/backend/src/agent.ts:221 — "1% protocol fee per transaction. Paid by merchant. Gas also merchant-covered." Something is deducted per transaction, so no transaction is fee-free.
fee %% (no|zero|without)[[:space:]]+(any[[:space:]]+)?(fee|fees)([^[:alpha:]]|$) %% a no-fee claim. The protocol fee is 1% per transaction and gas is deducted on top (pay/backend/src/agent.ts:220-221).
fee %% costs?[[:space:]]+(you[[:space:]]+)?nothing %% an unqualified no-cost claim. Gas plus one percent is deducted per transaction (pay/backend/src/agent.ts:220-221). Name what is free instead of saying nothing costs.
fee %% (free|no[[:space:]]+cost)[^.]{0,50}(transaction|transfer|on-chain|gas|withdraw|payout|settle) %% "free" attached to the TRANSACTION rail. That rail is 1% plus gas (pay/backend/src/agent.ts:220-221). "Free" is true of the keys, the wallets, the shop and taking a payment — it is not true of a transaction.
fee %% (transaction|transfer|payout|withdrawal|settlement|gas)[^.]{0,50}(is|are|costs?)[[:space:]]+(free|nothing) %% the same claim as a sentence. 1% per transaction, gas on top (pay/backend/src/agent.ts:220-221).
fee %% unlimited[[:space:]]+free %% banned verbatim by text/ad.md §8 "Money and free". There is no overdraft: findFunder refuses rather than lends (one.ie/web/src/lib/credits.ts:122), and a free signup has 100 credits.
fee %% free[[:space:]]+forever[^.]{0,40}credits? %% "free forever" must never attach to credits (text/ad.md §8; free-offer.md §9). Credits are the priced product.
fee %% credits?[^.]{0,40}free[[:space:]]+forever %% the same claim, other order. "Free and sovereign forever" attaches to the keys and the wallets only.
fee %% first[[:space:]]+[a-z0-9,]+[[:space:]]+(messages|credits)[[:space:]]+are[[:space:]]+free %% banned verbatim by text/ad.md §8. There is no overdraft (credits.ts:122); a free signup has 100 credits and then buys more.
chains %% (all|any|every)[[:space:]]+(major[[:space:]]+)?(block)?chains? %% there are FOUR chains and they are named: Sui, Ethereum, Solana, Bitcoin (one.ie/web/tests/unit/vault/multichain.test.ts). Name them; do not generalise.
chains %% (all|any|every)[[:space:]]+(major[[:space:]]+)?(crypto|cryptocurrency|coin|token)s? %% the same over-claim wearing a different noun. Four chains, named.
wallet %% (any|another|other|standard|external|third[- ]party|hardware|your[[:space:]]+own)[[:space:]]+wallet %% the twenty-four words do NOT reconstruct this key elsewhere. A standard tool runs BIP39 PBKDF2 + BIP32; one.ie/web/src/lib/vault.ts:237 takes the entropy straight into HKDF (vault.ts:281). Same words, different key.
wallet %% (restore|recover|import|open)[a-z]*[[:space:]]+(it|them|the[[:space:]]+(key|keys|wallet|words|phrase))[[:space:]]+(in|into|with|on)[[:space:]]+(any|another|other|a[[:space:]]+standard) %% the same claim as a sentence. The words restore the key HERE.
card %% (^|[^[:alpha:]])cards?([^[:alpha:]]|$) %% a card claim, and the worker is not in live Stripe mode. A WITHDRAWAL is not a claim — see withdrawals() for the two exact sentences that may carry the word.
card %% (credit|debit)[- ]card %% a card claim, and the worker is not in live Stripe mode.
card %% apple[[:space:]]+pay %% an Apple Pay claim, and the worker is not in live Stripe mode.
card %% google[[:space:]]+pay %% a Google Pay claim, and the worker is not in live Stripe mode.
card %% (^|[^[:alpha:]])(stripe|visa|mastercard|amex)([^[:alpha:]]|$) %% a card-rail claim, and the worker is not in live Stripe mode.
RULES
}

# ---------------------------------------------------------------------------
# WITHDRAWALS — the exact sentences in which a withdrawn claim may name itself.
#
# Prod's honest copy is "Card checkout is not live yet. Crypto checkout is."
# The word "card" is in it, and a bare pattern refuses the very sentence that
# tells the truth. So a card token is permitted ONLY inside one of the literals
# below, which are stripped from a line before the card rules see it.
#
# They are whole cells and whole sentences, never the token "Card checkout" on
# its own — an allowlisted token would permit "Card checkout is instant", and
# "Cards are not live yet, but Apple Pay is" must still go red (it does: the
# literal does not match, and Apple Pay has its own rule). Each is licensed by
# one.ie/web/wrangler.toml:110 STRIPE_MODE = "test"; when that says "live" the
# card rules are skipped wholesale and these strip to no effect.
# ---------------------------------------------------------------------------
withdrawals() {
  cat <<'W'
Card checkout is not live yet. Crypto checkout is.
"feature":"Card checkout","us":"Not yet available","alt1":"Not yet available"
W
}

# NEGATIVE EXAMPLES — a phrase quoted as a BAN is not a claim.
#
# commerce.ts's '/ad' system prompt tells the model which phrases to refuse, and
# it does that by naming them verbatim, which is the only way that instruction
# works. Linting them as claims would force the copy to stop naming what it
# refuses — the §8 failure one file over. Each literal below is stripped from
# every subject before any rule runs.
#
# The first four carry their QUOTE MARKS. That is the whole safety property:
# "no fees, ever" as a quoted ban is permitted, no fees, ever as a sentence
# still goes red. The fifth is a refusal instruction that cannot be read as a
# claim in any grammar. The sixth is the CONFIG VARIABLE the card rule reads:
# copy that cites `one.ie/web/wrangler.toml:110 is STRIPE_MODE = "test"` as its
# reason for withdrawing a claim is naming the guard, not naming a payment
# option, and the literal stops matching the day that line says "live" — at
# which point the card rules are skipped wholesale anyway.
#
# Adding a literal here is a reviewed act, not a regex
# tweak — it is the one place this script can be widened, and it is deliberately
# a list of exact strings so that widening it is legible in a diff.
negative_examples() {
  cat <<'N'
"no fees, ever"
"get paid instantly"
"instant settlement"
"sell anything"
any card, Apple Pay or Google Pay claim whatsoever
STRIPE_MODE = "test"
N
}

strip_literals() { # $1 = producer fn name; stdin -> stdout, its literals removed
  local w esc out
  out="$(cat)"
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    esc="$(printf '%s' "$w" | sed -E 's/[][\\.*^$/&|?+(){}]/\\&/g')"
    out="$(printf '%s' "$out" | sed "s/$esc//g")"
  done <<L
$("$1")
L
  printf '%s\n' "$out"
}

strip_negatives()   { strip_literals negative_examples; }

strip_withdrawals() { strip_literals withdrawals; }

# ---------------------------------------------------------------------------
# mask_subject — POSITIVE extraction. Prints the file with every line that is
# NOT shipped copy blanked, so the line count (and therefore every reported
# line number) is the real one. An unrecognised file is passed through whole:
# --self-test's fixtures and an explicit file argument are linted entire.
# ---------------------------------------------------------------------------
mask_subject() { # $1 = path
  case "$(basename "${1:-}")" in
    ad.md)       mask_ad_md "$1" ;;
    commerce.ts) mask_commerce_ad "$1" ;;
    *)           cat "$1" ;;
  esac
}

# text/ad.md: the fenced blocks under "## 4. The page, as shipped", plus the
# blockquote under "### The cleared paragraph". Nothing else is copy.
mask_ad_md() {
  awk '
    /^## /                          { sec = $0; fence = 0 }
    /^### The cleared paragraph/    { cleared = 1 }
    /^### /                         { if ($0 !~ /^### The cleared paragraph/) cleared = 0 }
    {
      keep = 0
      if (sec ~ /^## 4\. The page, as shipped/) {
        if ($0 ~ /^```/) { fence = !fence; keep = 0 }
        else if (fence)  { keep = 1 }
      }
      if (cleared && $0 ~ /^>/) keep = 1
      print keep ? $0 : ""
    }
  ' "$1"
}

# commerce.ts: the "/ad" entry only, from its key to the next top-level key.
mask_commerce_ad() {
  awk "
    /^  '\/ad': \{/       { inad = 1; print; next }
    inad && /^  '\//      { inad = 0 }
    { print inad ? \$0 : \"\" }
  " "$1"
}

# ---------------------------------------------------------------------------
# fetch_live — the served page. Public GET, no environment, no credentials.
# Entities are unescaped, then the COPY-BEARING props are extracted positively:
# a whole-page grep would refuse <meta name="twitter:card">, which is a protocol
# token and not a sentence anyone reads. Prints nothing on failure; the caller
# turns that into exit 3.
# ---------------------------------------------------------------------------
fetch_live() { # $1 = url
  local html norm objs props tmp
  html="$(curl -fsS --max-time 25 "$1" 2>/dev/null)" || return 1
  [ -n "$html" ] || return 1
  tmp="$(mktemp -d)"

  # Unescape, then flatten Astro's island serialisation ("k":[0,"v"] -> "k":"v")
  # so a copy object reads exactly as it does in text/ad.md's fenced blocks.
  norm="$tmp/norm"
  printf '%s' "$html" \
    | sed -e 's/&quot;/"/g' -e 's/&#39;/'"'"'/g' -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g' \
    | sed -E 's/"([a-zA-Z0-9_]+)":\[0,"([^"]*)"\]/"\1":"\2"/g' > "$norm"

  # A COPY OBJECT STAYS ON ONE LINE. A pricing row is one claim, not four
  # fragments: split into props, its cell reads "Card checkout" with the
  # withdrawal that qualifies it on some other line, and the guard would refuse
  # the honest sentence. Objects first, then the props that live outside one.
  objs="$tmp/objs"; props="$tmp/props"
  grep -oE '\{[^{}]*\}' "$norm" 2>/dev/null \
    | grep -E '"(feature|question|label|title|eyebrow|heading|welcome|headline)":' > "$objs" || true
  grep -oE '"(label|description|detail|note|feature|us|alt1|question|answer|title|subtitle|usLabel|eyebrow|heading|headline|body|sub|welcome|kicker|cta)":"[^"]*"' "$norm" 2>/dev/null \
    | sort -u > "$props" || true
  grep -oE '"(label|description|detail|note|feature|us|alt1|question|answer|title|subtitle|usLabel|eyebrow|heading|headline|body|sub|welcome|kicker|cta)":"[^"]*"' "$objs" 2>/dev/null \
    | sort -u > "$tmp/inobj" || true

  { cat "$objs"; grep -Fxv -f "$tmp/inobj" "$props" 2>/dev/null || cat "$props"; } | grep -v '^$'
  local rc=$?
  rm -rf "$tmp"
  return 0
}

# ---------------------------------------------------------------------------
# The live config read. FAILS CLOSED: anything that is not exactly one
# assignment whose value is "live" arms the card rule. A config the lint cannot
# parse must never read as permission. The same rule governs the page list — an
# absent, empty or unparseable STRIPE_LIVE_PAGES yields NO live pages, so every
# page question answers "not live".
# ---------------------------------------------------------------------------
read_stripe_mode() { # $1 = wrangler.toml path -> prints the mode, or a reason
  local f="${1:-}"
  if [ ! -f "$f" ]; then printf 'unreadable(no such file)'; return 0; fi
  local hits
  hits="$(grep -nE '^[[:space:]]*STRIPE_MODE[[:space:]]*=' "$f" 2>/dev/null || true)"
  if [ -z "$hits" ]; then printf 'unreadable(no STRIPE_MODE assignment)'; return 0; fi
  local seen="" v line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    v="${line#*=}"
    v="$(printf '%s' "$v" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]]*#.*$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/; s/[[:space:]]*$//')"
    case " $seen " in *" $v "*) ;; *) seen="${seen:+$seen }$v" ;; esac
  done <<HITS
$hits
HITS
  case "$seen" in
    *" "*) printf 'conflicting(%s)' "$seen" ;;
    "")    printf 'unreadable(empty value)' ;;
    *)     printf '%s' "$seen" ;;
  esac
}

# One spelling of a page path, matching normalisePagePath() in
# one.ie/web/src/lib/stripe-mode.ts: lowercase, no query, no fragment, leading
# slash, no doubled or trailing slash. A path carrying whitespace or a wildcard
# normalises to nothing and is therefore a member of no list.
norm_page() { # $1 = raw path -> prints the normalised path, or nothing
  local p="${1:-}"
  p="$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -n "$p" ] || return 0
  case "$p" in *://*) p="/${p#*://}"; p="/${p#*/}" ;; esac
  p="${p%%\?*}"; p="${p%%#*}"
  case "$p" in /*) ;; *) p="/$p" ;; esac
  p="$(printf '%s' "$p" | sed -E 's#/{2,}#/#g')"
  [ "$p" = "/" ] || p="$(printf '%s' "$p" | sed -E 's#/+$##')"
  case "$p" in *[[:space:]]*|*'*'*) return 0 ;; esac
  printf '%s' "$p"
}

read_stripe_live_pages() { # $1 = wrangler.toml -> prints normalised paths, one per line
  local f="${1:-}" hits line v part n
  [ -f "$f" ] || return 0
  hits="$(grep -nE '^[[:space:]]*STRIPE_LIVE_PAGES[[:space:]]*=' "$f" 2>/dev/null || true)"
  [ -n "$hits" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    v="${line#*=}"
    v="$(printf '%s' "$v" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*#.*$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
    v="$(printf '%s' "$v" | tr ',' ' ')"
    for part in $v; do
      n="$(norm_page "$part")"
      [ -n "$n" ] && printf '%s\n' "$n"
    done
  done <<HITS
$hits
HITS
}

page_is_live() { # $1 = toml, $2 = page path -> exit 0 when the page may charge a card
  local want p
  want="$(norm_page "${2:-}")"
  [ -n "$want" ] || return 1
  while IFS= read -r p; do
    [ "$p" = "$want" ] && return 0
  done <<PAGES
$(read_stripe_live_pages "$1")
PAGES
  return 1
}

# ---------------------------------------------------------------------------
lint() { # $1 = copy file, $2 = wrangler.toml, $3 = page path (optional), $4 = label -> 0 clean, 1 forbidden, 3 missing
  local copy="$1" toml="$2" page="${3:-}" label="${4:-}"
  local failed=0
  [ -n "$label" ] || label="${copy#"$ROOT"/}"

  if [ ! -f "$copy" ]; then
    printf 'ad-copy-lint: MISSING SUBJECT — %s does not exist.\n' "$copy" >&2
    printf '  The proof has no subject. Deliverable 5 of text/bring-one-to-life.md\n' >&2
    printf '  names this file as the copy that carries the launch claims.\n' >&2
    return 3
  fi

  # The subject is the SHIPPED COPY inside this file, extracted positively.
  # Masking blanks every other line rather than deleting it, so a reported line
  # number is the real one in the real file.
  local work work_card
  work="$(mktemp)"; work_card="$(mktemp)"
  mask_subject "$copy" | strip_negatives > "$work"
  strip_withdrawals < "$work" > "$work_card"

  # Two ways a card claim is permitted, and only two: the whole worker is live,
  # or the PAGE under lint is a member of STRIPE_LIVE_PAGES. With no --page there
  # is no page to be a member of anything, so only the global switch can permit —
  # a sentence that is not tied to a page ships on every page, including the ones
  # still taking 4242 4242 4242 4242.
  local mode card_armed scope pages
  mode="$(read_stripe_mode "$toml")"
  if [ "$mode" = "live" ]; then
    card_armed=0; scope="STRIPE_MODE=$mode (whole worker)"
  elif [ -n "$page" ] && page_is_live "$toml" "$page"; then
    card_armed=0; scope="STRIPE_LIVE_PAGES lists $(norm_page "$page")"
  elif [ -n "$page" ]; then
    card_armed=1; scope="STRIPE_MODE=$mode, and $(norm_page "$page") is not in STRIPE_LIVE_PAGES"
  else
    card_armed=1; scope="STRIPE_MODE=$mode, no --page (the global question)"
  fi
  pages="$(read_stripe_live_pages "$toml" | tr '\n' ' ' | sed -E 's/[[:space:]]+$//')"

  printf 'ad-copy-lint\n'
  printf '  copy:        %s\n' "$label"
  printf '  config:      %s\n' "${toml#"$ROOT"/}"
  printf '  page:        %s\n' "${page:-<none — global question>}"
  printf '  live pages:  %s\n' "${pages:-<none>}"
  printf '  verdict:     %s  ->  card/Apple Pay/Google Pay claims %s\n' \
    "$scope" "$( [ "$card_armed" -eq 1 ] && printf 'FORBIDDEN' || printf 'permitted' )"
  printf '\n'

  local id re why hits l lineno text
  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    id="$(printf '%s' "$rule"   | sed -E 's/^([^ ]+) %% .*$/\1/')"
    re="$(printf '%s' "$rule"   | sed -E 's/^[^ ]+ %% (.*) %% .*$/\1/')"
    why="$(printf '%s' "$rule"  | sed -E 's/^[^ ]+ %% .* %% (.*)$/\1/')"
    if [ "$id" = "card" ] && [ "$card_armed" -eq 0 ]; then continue; fi
    # A withdrawal is not a claim: the card rules never see the exact sentences
    # in withdrawals(). Every other rule reads the copy as written.
    local src; src="$work"; [ "$id" = "card" ] && src="$work_card"
    hits="$(grep -nEi "$re" "$src" 2>/dev/null || true)"
    [ -n "$hits" ] || continue
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      lineno="${l%%:*}"
      text="$(printf '%s' "${l#*:}" | sed -E 's/^[[:space:]]+//')"
      printf 'FORBIDDEN [%s] %s:%s\n' "$id" "$label" "$lineno"
      printf '  line: %s\n' "$text"
      printf '  why:  %s\n' "$why"
      printf '\n'
      failed=$((failed + 1))
    done <<HITS
$hits
HITS
  done <<RULESIN
$(rules)
RULESIN

  if [ "$failed" -gt 0 ]; then
    rm -f "$work" "$work_card"
    printf 'RED — %d forbidden claim(s) in %s.\n' "$failed" "$label" >&2
    printf 'Go green by changing the COPY, or (for the card rule) the CONFIG. Not this file.\n' >&2
    return 1
  fi
  rm -f "$work" "$work_card"
  printf 'ok — no forbidden sentence. %d rule(s) applied, %d skipped as config-permitted.\n' \
    "$( [ "$card_armed" -eq 1 ] && rules | grep -c . || rules | grep -vc '^card ' )" \
    "$( [ "$card_armed" -eq 1 ] && printf 0 || rules | grep -c '^card ' )"
  return 0
}

# ---------------------------------------------------------------------------
# lint_all — every default subject, worst status wins. A missing subject is
# exit 3 and stays exit 3: it outranks a clean pass, because a proof with no
# subject is what this whole script was rebuilt to stop reporting as green.
# ---------------------------------------------------------------------------
lint_all() { # $1 = toml, $2 = page (optional) -> 0 clean · 1 forbidden · 3 missing
  local toml="$1" page="${2:-}" worst=0 f rc
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    lint "$f" "$toml" "$page"; rc=$?
    printf '\n'
    case "$rc" in
      3) worst=3 ;;
      1) [ "$worst" -eq 3 ] || worst=1 ;;
    esac
  done <<SUBJ
$(subjects)
SUBJ
  return "$worst"
}

# --live — the served page, which is the only readable form of the D1 row.
lint_live() { # $1 = toml, $2 = url, $3 = page (optional)
  local toml="$1" url="$2" page="${3:-}" tmp rc
  tmp="$(mktemp)"
  if ! fetch_live "$url" > "$tmp" || [ ! -s "$tmp" ]; then
    rm -f "$tmp"
    printf 'ad-copy-lint: MISSING SUBJECT — could not read the served copy at %s.\n' "$url" >&2
    printf '  Production /ad renders from the D1 pages row and nothing in this repo\n' >&2
    printf '  is its source, so the served page is the only subject there is. An\n' >&2
    printf '  unreachable subject is exit 3 — no subject, no proof. Never a pass.\n' >&2
    return 3
  fi
  lint "$tmp" "$toml" "$page" "$url (served copy — line N is the Nth extracted string)"; rc=$?
  rm -f "$tmp"
  return "$rc"
}

# ---------------------------------------------------------------------------
# --self-test — the red proofs, run against fixtures so the real copy is never
# touched. A lint that has never gone red proves nothing.
# ---------------------------------------------------------------------------
self_test() {
  local tmp bad=0
  tmp="$(mktemp -d)"
  # expanded NOW, not at exit — $tmp is function-local and gone by then
  trap "rm -rf '$tmp'" EXIT

  printf 'STRIPE_MODE = "test"\n' > "$tmp/test.toml"
  printf 'STRIPE_MODE = "live"\n' > "$tmp/live.toml"
  printf 'PLATFORM_SLUG = "one"\n' > "$tmp/none.toml"
  # The shipped shape: global mode still test, exactly one page armed.
  printf 'STRIPE_MODE = "test"\nSTRIPE_LIVE_PAGES = "/shop/pay-playbook, /Credits/"\n' > "$tmp/pages.toml"
  printf 'STRIPE_MODE = "test"\nSTRIPE_LIVE_PAGES = "/shop/*"\n'                      > "$tmp/glob.toml"
  printf 'STRIPE_MODE = "test"\nSTRIPE_LIVE_PAGES = ""\n'                             > "$tmp/empty.toml"

  clean() { cat > "$tmp/copy.md" <<'CLEAN'
# Sovereign keys
Gas plus one percent of the transaction is deducted (pay/backend/src/agent.ts:220).
Four chains derive from one key: Sui, Ethereum, Solana, Bitcoin.
Twenty-four words bring the key back here, on one.ie.
CLEAN
  }

  expect() { # $1 = want-exit, $2 = label, $3 = toml, [$4 = needle] [$5 = page] [$6 = subject file]
    local want="$1" label="$2" toml="$3" needle="${4:-}" page="${5:-}" subj="${6:-$tmp/copy.md}" out rc
    out="$(lint "$subj" "$toml" "$page" 2>&1)"; rc=$?
    if [ "$rc" -ne "$want" ]; then
      printf '  FAIL %s — exit %d, wanted %d\n' "$label" "$rc" "$want"; bad=1; return
    fi
    if [ -n "$needle" ]; then
      case "$out" in *"$needle"*) ;; *) printf '  FAIL %s — output never named [%s]\n' "$label" "$needle"; bad=1; return ;; esac
    fi
    printf '  ok   %s (exit %d)\n' "$label" "$rc"
  }

  printf '== self-test: the clean fixture is green\n'
  clean; expect 0 'clean copy, STRIPE_MODE=test' "$tmp/test.toml"

  printf '\n== self-test: each forbidden claim is bitten\n'
  clean; printf 'Every transaction is free.\n'               >> "$tmp/copy.md"; expect 1 'plant "transaction is free"'   "$tmp/test.toml" 'FORBIDDEN [fee]'
  clean; printf 'Sending money is free, with no cost on transfer.\n' >> "$tmp/copy.md"; expect 1 'plant "no cost on transfer"'  "$tmp/test.toml" 'FORBIDDEN [fee]'
  clean; printf 'Sell with no fees at all.\n'                >> "$tmp/copy.md"; expect 1 'plant "no fees"'               "$tmp/test.toml" 'FORBIDDEN [fee]'
  clean; printf 'Gas-free claims, every time.\n'             >> "$tmp/copy.md"; expect 1 'plant "gas-free"'              "$tmp/test.toml" 'FORBIDDEN [fee]'
  clean; printf 'Unlimited free credits while you test.\n'   >> "$tmp/copy.md"; expect 1 'plant "unlimited free"'        "$tmp/test.toml" 'FORBIDDEN [fee]'
  clean; printf 'Credits are free forever.\n'                >> "$tmp/copy.md"; expect 1 'plant "free forever" @ credits' "$tmp/test.toml" 'FORBIDDEN [fee]'
  clean; printf 'It costs you nothing to mint.\n'            >> "$tmp/copy.md"; expect 1 'plant "costs you nothing"'     "$tmp/test.toml" 'FORBIDDEN [fee]'
  clean; printf 'One key, all major blockchains.\n'          >> "$tmp/copy.md"; expect 1 'plant "all major blockchains"' "$tmp/test.toml" 'FORBIDDEN [chains]'
  clean; printf 'Restore it in any wallet you like.\n'       >> "$tmp/copy.md"; expect 1 'plant "any wallet"'            "$tmp/test.toml" 'FORBIDDEN [wallet]'
  clean; printf 'Pay with a card in one tap.\n'              >> "$tmp/copy.md"; expect 1 'plant "card" @ test'           "$tmp/test.toml" 'FORBIDDEN [card]'
  clean; printf 'Apple Pay and Google Pay both work.\n'      >> "$tmp/copy.md"; expect 1 'plant "Apple Pay" @ test'      "$tmp/test.toml" 'FORBIDDEN [card]'

  printf '\n== self-test: TRUE claims are not refused (the rule the old one broke)\n'
  # These sentences ship on production /ad right now and every one of them is
  # measured true. A "free" rule that refuses them is not strict, it is wrong —
  # pay/backend/src/agent.ts:221 prices the TRANSACTION, not the key.
  clean; printf '{"feature":"Your key and your wallets","us":"Free","alt1":"Free"}\n' >> "$tmp/copy.md"
  expect 0 'true: the keys and wallets are Free'   "$tmp/test.toml"
  clean; printf 'Free and sovereign forever.\n'                >> "$tmp/copy.md"
  expect 0 'true: "Free and sovereign forever"'    "$tmp/test.toml"
  clean; printf 'Taking a payment never costs a credit, at any balance.\n' >> "$tmp/copy.md"
  expect 0 'true: taking a payment costs 0 credits' "$tmp/test.toml"
  clean; printf 'Switch your shop on and crypto checkout costs you 0%%.\n' >> "$tmp/copy.md"
  expect 0 'true: crypto checkout is 0%'           "$tmp/test.toml"

  printf '\n== self-test: a WITHDRAWAL may name the rail; a claim wearing one may not\n'
  clean; printf 'Card checkout is not live yet. Crypto checkout is.\n' >> "$tmp/copy.md"
  expect 0 'the withdrawal sentence                    -> GREEN' "$tmp/test.toml"
  clean; printf '{"feature":"Card checkout","us":"Not yet available","alt1":"Not yet available","note":"Card checkout is not live yet. Crypto checkout is."}\n' >> "$tmp/copy.md"
  expect 0 'the withdrawn pricing row                  -> GREEN' "$tmp/test.toml"
  # The discriminating test. A negation is not a licence: smuggling a live claim
  # alongside a withdrawal must still go red, or the allowlist is a heuristic.
  clean; printf 'Cards are not live yet, but Apple Pay is.\n' >> "$tmp/copy.md"
  expect 1 'a claim smuggled beside a withdrawal      -> RED'   "$tmp/test.toml" 'FORBIDDEN [card]'
  clean; printf 'Card checkout is not live yet. Crypto checkout is. Visa works today.\n' >> "$tmp/copy.md"
  expect 1 'a claim appended to the withdrawal        -> RED'   "$tmp/test.toml" 'FORBIDDEN [card]'
  clean; printf 'Card checkout is instant.\n' >> "$tmp/copy.md"
  expect 1 'the allowlisted words in a NEW sentence   -> RED'   "$tmp/test.toml" 'FORBIDDEN [card]'

  printf '\n== self-test: the card rule is CONFIG-derived, both ways\n'
  clean; printf 'Pay with a card in one tap.\n' >> "$tmp/copy.md"
  expect 1 'card copy + STRIPE_MODE=test  -> RED'   "$tmp/test.toml" 'FORBIDDEN [card]'
  expect 0 'card copy + STRIPE_MODE=live  -> GREEN' "$tmp/live.toml"
  expect 1 'card copy + no STRIPE_MODE    -> RED (fails closed)' "$tmp/none.toml" 'FORBIDDEN [card]'
  clean
  expect 0 'clean copy + no STRIPE_MODE   -> green (card rule armed, nothing to bite)' "$tmp/none.toml"

  printf '\n== self-test: the card rule is PAGE-derived\n'
  clean; printf 'Pay with a card in one tap.\n' >> "$tmp/copy.md"
  expect 0 'card copy on a LISTED page                 -> GREEN' "$tmp/pages.toml" '' '/shop/pay-playbook'
  expect 0 'card copy on a listed page, spelt /Credits -> GREEN' "$tmp/pages.toml" '' '/credits/?ref=x'
  expect 1 'card copy on an UNLISTED page              -> RED'   "$tmp/pages.toml" 'FORBIDDEN [card]' '/pricing'
  expect 1 'card copy on a near-miss of a listed page  -> RED'   "$tmp/pages.toml" 'FORBIDDEN [card]' '/shop/pay-playbook-2'
  expect 1 'card copy, pages armed but NO --page       -> RED'   "$tmp/pages.toml" 'FORBIDDEN [card]'
  expect 1 'a GLOB in the config opens nothing         -> RED'   "$tmp/glob.toml"  'FORBIDDEN [card]' '/shop/pay-playbook'
  expect 1 'a GLOB in the question matches nothing     -> RED'   "$tmp/pages.toml" 'FORBIDDEN [card]' '/shop/*'
  expect 1 'an EMPTY list means no page is live        -> RED'   "$tmp/empty.toml" 'FORBIDDEN [card]' '/shop/pay-playbook'
  expect 1 'no STRIPE_LIVE_PAGES at all                -> RED'   "$tmp/none.toml"  'FORBIDDEN [card]' '/shop/pay-playbook'
  clean
  expect 0 'clean copy on a listed page                -> green' "$tmp/pages.toml" '' '/shop/pay-playbook'

  printf '\n== self-test: POSITIVE extraction — copy is linted, records are not\n'
  # The whole reason the subject is extracted rather than grepped. §2/§3 record
  # withdrawn claims and §8 is a list of sentences that must never ship; a sweep
  # over the file refuses the very records it exists to preserve.
  mk_admd() { # $1 = a line to put in the SHIPPED block, $2 = a line for §8
    cat > "$tmp/ad.md" <<ADMD
## 3. The offer
| 6 | Card checkout at Stripe plus 2% | migrations/0109 | **NO — withdrawn, wrangler.toml:110 is test** |

## 4. The page, as shipped
\`\`\`json
{"type":"Pricing","props":{"rows":[
  {"feature":"Crypto checkout","us":"0%"}${1:+,}
  ${1:-}
]}}
\`\`\`

Prose outside a fence that mentions a card and Stripe is not copy.

## 8. Forbidden sentences
> ${2:-"nothing"}
ADMD
  }
  mk_admd '' ''
  expect 0 'records in §3 + prose + a bare §8 are not copy' "$tmp/test.toml" '' '' "$tmp/ad.md"
  mk_admd '' '"Pay with any card, no fees, ever, on all major blockchains"'
  expect 0 'a forbidden EXAMPLE in §8 is not a claim'       "$tmp/test.toml" '' '' "$tmp/ad.md"
  mk_admd '{"feature":"Card checkout","us":"Stripe + 2%"}' ''
  expect 1 'the same claim INSIDE a copy block            -> RED' "$tmp/test.toml" 'FORBIDDEN [card]' '' "$tmp/ad.md"

  printf '\n== self-test: a missing subject is exit 3, never a pass\n'
  rm -f "$tmp/copy.md"
  local rc; lint "$tmp/copy.md" "$tmp/test.toml" >/dev/null 2>&1; rc=$?
  if [ "$rc" -eq 3 ]; then printf '  ok   missing subject (exit 3)\n'; else printf '  FAIL missing subject — exit %d, wanted 3\n' "$rc"; bad=1; fi

  printf '\n'
  if [ "$bad" -eq 0 ]; then printf 'self-test: all red proofs bite.\n'; return 0; fi
  printf 'self-test: FAILED — the lint cannot go red where it must.\n' >&2
  return 1
}

case "${1:-}" in
  --self-test) self_test ;;
  -h|--help)   sed -n '2,90p' "$0"; exit 0 ;;
  # The SERVED page. Opt-in, because do-promise-settle.sh runs the accept string
  # verbatim and a promise must not settle BROKEN on a network hiccup.
  --live)      lint_live "$TOML_DEFAULT" "${2:-$LIVE_URL_DEFAULT}" ;;
  # The PAGE question. Note the default (no argument) is untouched: do-promise-settle.sh
  # runs the accept string verbatim, so the global question must keep answering with
  # no flag, no env and no page.
  --page)      [ -n "${2:-}" ] || { printf 'ad-copy-lint: --page needs a path\n' >&2; exit 2; }
               if [ -n "${3:-}" ]; then lint "$3" "$TOML_DEFAULT" "$2"; else lint_all "$TOML_DEFAULT" "$2"; fi ;;
  "")          lint_all "$TOML_DEFAULT" ;;
  *)           printf 'ad-copy-lint: unknown argument %s (--page <path> [copy] · --live [url] · --self-test · nothing)\n' "$1" >&2; exit 2 ;;
esac
