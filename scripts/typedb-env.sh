#!/usr/bin/env bash
# typedb-env.sh — switch one.ie/web/.env between the local (dev) and cloud (prod)
# TypeDB substrate. Rewrites only the four TYPEDB_* lines; everything else in
# .env is untouched.
#
#   .claude/scripts/typedb-env.sh            # status
#   .claude/scripts/typedb-env.sh dev        # point at local OrbStack container
#   .claude/scripts/typedb-env.sh prod       # point back at TypeDB Cloud
#   .claude/scripts/typedb-env.sh up         # start the local container
#   .claude/scripts/typedb-env.sh down       # stop the local container
#
# Profiles live in .claude/typedb/{dev,prod}.env (gitignored — prod holds a
# password). Re-snapshot prod at any time with:  cp-from-env prod
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENVF="$ROOT/one.ie/web/.env"
PROFILES="$ROOT/.claude/typedb"
KEYS='TYPEDB_URL TYPEDB_DATABASE TYPEDB_USERNAME TYPEDB_PASSWORD'
CONTAINER=typedb
# Pinned to the version TypeDB Cloud runs (checked via GET $TYPEDB_URL/v1/version).
# Dev mirrors the substrate, it does not lead it — bump only when prod does.
# Prod moved to 3.12.1 on 2026-07-29 and the local container was migrated in place
# the same day; this pin was left at 3.8.3, so a container rebuild would have
# silently DOWNGRADED local back under the two 3.8.3 server-killing bugs
# (`\uXXXX` in a literal, and the same var in two roles → PANIC, not an error).
IMAGE=typedb/typedb:3.12.1
VOLUME=typedb-data
# The path the SERVER actually writes to, not the one the tarball layout suggests.
# `docker inspect typedb` -> `server --storage.data-directory=/var/lib/typedb/data`.
# The old value mounted the named volume at /opt/... where nothing was ever written,
# so every local database lived in an ANONYMOUS volume — one `docker rm` from being
# orphaned, and no local backup would have contained anything.
DATA_DIR=/var/lib/typedb/data

die() { echo "typedb-env: $*" >&2; exit 1; }
val() { grep -E "^$1=" "$ENVF" | tail -1 | cut -d= -f2-; }

# Which profile does the live .env currently match? (compare URL only)
current() {
  local url; url=$(val TYPEDB_URL)
  for p in dev prod; do
    [ -f "$PROFILES/$p.env" ] || continue
    if [ "$url" = "$(grep -E '^TYPEDB_URL=' "$PROFILES/$p.env" | cut -d= -f2-)" ]; then
      echo "$p"; return
    fi
  done
  echo "custom"
}

status() {
  local cur; cur=$(current)
  echo "profile : $cur"
  echo "url     : $(val TYPEDB_URL)"
  echo "database: $(val TYPEDB_DATABASE)"
  local st; st=$(docker ps -a --filter "name=^${CONTAINER}$" --format '{{.Status}}' 2>/dev/null || true)
  echo "local   : ${st:-not created}"
  local url; url=$(val TYPEDB_URL)
  if curl -sf -m 5 -X POST "$url/v1/signin" -H 'content-type: application/json' \
       -d "{\"username\":\"$(val TYPEDB_USERNAME)\",\"password\":\"$(val TYPEDB_PASSWORD)\"}" \
       >/dev/null 2>&1; then
    echo "signin  : ok"
  else
    echo "signin  : FAILED"
  fi
  echo "scope   : one.ie/web/.env only — api/wrangler.toml stays pinned to cloud,"
  echo "          as do tools that default to it when env is unset (pay/tools/"
  echo "          simulate-market.ts, text/seed-tasks-typedb.ts, text/backfill-task-context.ts)"
}

use() {
  local p="$1" src="$PROFILES/$1.env"
  [ -f "$src" ] || die "no profile $p (expected $src)"
  [ -f "$ENVF" ] || die "no env file at $ENVF"
  # Snapshot named for the profile being LEFT, so a rollback target is never
  # clobbered by the next switch (a single .bak slot ends up holding the very
  # profile you were trying to get away from).
  cp "$ENVF" "$ENVF.bak.$(current)"
  for k in $KEYS; do
    local line; line=$(grep -E "^$k=" "$src" | tail -1) || die "$p profile missing $k"
    # in-place replace; portable sed needs the value escaped for & and /
    local esc; esc=$(printf '%s' "$line" | sed -e 's/[\/&]/\\&/g')
    if grep -qE "^$k=" "$ENVF"; then
      sed -i '' -E "s/^$k=.*/$esc/" "$ENVF"
    else
      printf '%s\n' "$line" >> "$ENVF"
    fi
  done
  echo "switched to $p"
  status
}

up() {
  docker info >/dev/null 2>&1 || { open -a OrbStack; echo "starting OrbStack..."; }
  for _ in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
  docker info >/dev/null 2>&1 || die "docker daemon did not come up"
  if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    docker start "$CONTAINER" >/dev/null
  else
    docker volume create "$VOLUME" >/dev/null
    docker run -d --name "$CONTAINER" --restart unless-stopped \
      -p 1729:1729 -p 8000:8000 -v "$VOLUME:$DATA_DIR" "$IMAGE" >/dev/null
  fi
  for _ in $(seq 1 30); do
    curl -sf -m 3 -X POST http://127.0.0.1:8000/v1/signin -H 'content-type: application/json' \
      -d '{"username":"admin","password":"password"}' >/dev/null 2>&1 && { echo "local TypeDB ready"; return; }
    sleep 2
  done
  die "local TypeDB did not become ready — docker logs $CONTAINER"
}

down() { docker stop "$CONTAINER" >/dev/null 2>&1 && echo "local TypeDB stopped" || echo "not running"; }

# Canonical load order — schema/CLAUDE.md § Files, narrowed to what production
# actually carries (probed via GET $TYPEDB_URL/v1/databases/one/schema, 2026-07-28).
# Deliberately excluded, because prod does NOT have them and dev must mirror the
# substrate rather than lead it:
#   factory-*.tql            — "DEFINES CLEAN, NOT DEPLOYED" per schema/CLAUDE.md
#   marketing/contact/education-schema.tql
#                            — documented "LOAD-SAFE against prod 2026-07-08", but
#                              absent from the live schema AND they fail to commit
#                              on a clean 3.8.3 db (INF11: `incremental_roas` and
#                              `recommend_strategy` read attributes off variables
#                              whose inferred types can't own them). Loading them
#                              is a schema fix, not an env switch.
SCHEMA_STACK='one.tql roles.tql do.tql reason.tql router.tql channels.tql'

# seed — create the local `one` database and define the canonical stack.
# LOCAL ONLY: refuses to run unless the active profile is dev, so a stray
# invocation can never define schema against TypeDB Cloud.
seed() {
  [ "$(current)" = dev ] || die "refusing: active profile is '$(current)', not dev. Run 'typedb-env.sh dev' first."
  local url; url=$(val TYPEDB_URL)
  local db;  db=$(val TYPEDB_DATABASE)
  local tok
  tok=$(curl -s -m 15 -X POST "$url/v1/signin" -H 'Content-Type: application/json' \
        -d "{\"username\":\"$(val TYPEDB_USERNAME)\",\"password\":\"$(val TYPEDB_PASSWORD)\"}" \
        | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))' 2>/dev/null)
  [ -n "$tok" ] || die "signin failed at $url"

  if curl -s -m 10 "$url/v1/databases/$db" -H "Authorization: Bearer $tok" | grep -q '"name"'; then
    echo "database '$db' exists"
  else
    curl -sf -m 30 -X POST "$url/v1/databases/$db" -H "Authorization: Bearer $tok" >/dev/null \
      || die "could not create database '$db'"
    echo "created database '$db'"
  fi

  for f in $SCHEMA_STACK; do
    local path="$ROOT/schema/$f"
    [ -f "$path" ] || die "missing $path"
    python3 - "$path" "$db" > /tmp/typedb-seed.json <<'PY'
import json, sys
print(json.dumps({
    "databaseName": sys.argv[2],
    "transactionType": "schema",
    "query": open(sys.argv[1]).read(),
}))
PY
    local out
    out=$(curl -s -m 120 -X POST "$url/v1/query" -H "Authorization: Bearer $tok" \
          -H 'Content-Type: application/json' --data-binary @/tmp/typedb-seed.json)
    if printf '%s' "$out" | grep -q '"code"'; then
      echo "  FAIL $f"
      printf '%s\n' "$out" | head -c 600; echo
      die "schema load aborted at $f"
    fi
    echo "  ok   $f"
  done
  rm -f /tmp/typedb-seed.json
  echo "local schema loaded ($(printf '%s' "$SCHEMA_STACK" | wc -w | tr -d ' ') files)"
}

case "${1:-status}" in
  dev)    up; use dev ;;
  prod)   use prod ;;
  up)     up ;;
  down)   down ;;
  seed)   seed ;;
  status) status ;;
  *)      die "usage: typedb-env.sh [status|dev|prod|up|down|seed]" ;;
esac
