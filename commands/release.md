# /release

Release the ONE OSS template and/or npm packages.

**Template direction flipped 2026-07-23 — `apps/one/` is now the SINGLE SOURCE OF TRUTH.**
Real development happens directly in the public clone; `one-ie/template/` is a read-only-by-
convention **mirror** kept inside the monorepo so `packages/` and `/do` cycles can reference it
without a second clone. Edit `apps/one` directly, then pull it back:
**`apps/one/` → `one-ie/template/` (+ `apps/oo/site/`)**. There is deliberately **no**
template → apps/one push path; the old direction would have destroyed apps/one-only work.

**npm packages:** `packages/{sdk,react,mcp,cli}` → npm registry (a separate job — the release
script does not publish; see Step 4)

---

## Invocations

| Command | What |
|---|---|
| `/release` | Full pipeline: template pull + npm packages |
| `/release template` | Pull apps/one into the template mirror and commit in one-ie (no npm publish) |
| `/release npm` | Bump + build + publish npm packages only |
| `/release --dry-run` | Print what would happen, no writes |

---

## Step 1 — Preflight checks

```bash
# Verify clean working tree
git diff --exit-code && git diff --cached --exit-code || echo "WARN: uncommitted changes"

# Verify apps/one is cloned
test -d /Users/toc/Server/apps/one/.git || {
  echo "Clone first: git clone git@github.com:one-ie/one.git apps/one"
  exit 1
}

# Run strip guard — zero moat/do-engine source in the template's site/src/
# (maintainer-only tooling lives in template-release/, a SIBLING of template/,
#  and never ships in the published repo)
cd one-ie/template-release && bash scripts/strip-guard.sh

# Run test suite
cd one-ie/template-release && bun vitest run
```

---

## Step 2 — Pull apps/one into the template mirror

```bash
cd one-ie/template-release
bash scripts/release.sh --message "release: $(date +%Y-%m-%d)"
# flags: --dry-run | --no-push | --message "<note>"
```

The script (`template-release/scripts/release.sh`):
1. `rsync` apps/one/ → one-ie/template/ (excludes local-only / secret files)
2. Sync per-package LICENSE files (`sync-licenses.sh`)
3. `git commit` (+ push unless `--no-push`) **inside the one-ie monorepo — NOT apps/one.**
   Nothing here writes to apps/one or to github.com/one-ie/one; that clone owns its own history.
4. `rsync` apps/one/site/ → apps/oo/site/ (keeps the agency node current, if apps/oo exists)

**Paid plugins are not stubbed by this script.** The 5 paid plugins backing `PAID_FEATURES`
(`one.ie/web/src/lib/billing/gate.ts`) — `plugin-{admin,course,dashboard,premium,shop}` — live in
`apps/one/packages/` and are mirrored into `template/packages/` unpublished. Their delivery
mechanism is still undecided: `text/plugin-delivery-plan.md` § Scope correction.

---

## Step 3 — Bump npm package versions (if releasing npm)

Bump order: SDK first, then react/mcp/cli which depend on it.

```bash
# Check current versions
grep '"version"' packages/sdk/package.json packages/react/package.json packages/mcp/package.json packages/cli/package.json

# Bump (patch | minor | major)
cd packages/sdk   && npm version patch && cd ../..
cd packages/react && npm version patch && cd ../..
cd packages/mcp   && npm version patch && cd ../..
cd packages/cli   && npm version patch && cd ../..

# Sync workspace:* deps — update sdk version in react/mcp/cli package.json if pinning
```

**CRITICAL:** Run `npm version` from each package dir, not the monorepo root (triggers lockfile relock).

---

## Step 4 — Build + publish npm packages

SDK must publish before react/mcp/cli (they declare `@oneie/sdk` as a dependency).

```bash
# Build all packages
cd packages && bun run build && cd ..

# Verify npm token is set
npm whoami

# Publish SDK first
cd packages/sdk && npm publish --access public && cd ../..

# Then react, mcp, cli (parallel is fine — SDK is already on registry)
cd packages/react && npm publish --access public && cd ../..
cd packages/mcp   && npm publish --access public && cd ../..
cd packages/cli   && npm publish --access public && cd ../..
```

**Gotcha:** `workspace:*` deps must be temporarily pinned to `^x.y.z` before publishing, then restored. See memory entry `reference_oneie_npm_publish_workspace`.

**The other npm packages have their own door.** `@oneie/design`, `@oneie/frontend`, and the 9
free plugins (auth/backend/blog/booking/chat/docs/mail/media/track) publish per-package via
`bash packages/publish-plugin.sh <plugin-dir-name> [--dry-run]` — it rewrites `workspace:*`
peers to a loose optional `*` and restores `package.json` on exit. It **hard-refuses** the 5
paid plugins unconditionally, even with `--dry-run`: public npm has no purchase gate. Do not
remove that block to work around it.

---

## Step 5 — Tag + report

```bash
# Tag the release on main
VERSION=$(node -p "require('./packages/sdk/package.json').version")
git tag "v$VERSION" && git push origin "v$VERSION"
```

Report format:
```
Template:  strip-guard ✓  N/N tests ✓  pulled apps/one → template/  committed in one-ie
npm:       @oneie/sdk@0.14.0 ✓  @oneie/react@0.14.0 ✓  @oneie/mcp@0.14.0 ✓  @oneie/cli@0.14.0 ✓
Tag:       v0.14.0 → main
```

---

## x402-gated plugins

**Design, not shipped.** `release.sh` does not stub paid plugins and there is no `PAID_PLUGINS`
array in it — the x402 delivery path (`pay.one.ie/x/<name>.js`) is the undecided half of
`text/plugin-delivery-plan.md`. What IS enforced today is the refusal: `packages/publish-plugin.sh`
blocks the 5 paid plugins from npm, and they ship to nobody until that plan lands.

The paid set is defined in one place — `PAID_FEATURES` in `one.ie/web/src/lib/billing/gate.ts`,
mirrored by the `PAID_PLUGINS` string in `packages/publish-plugin.sh`. Adding a paid plugin means
editing both, not a release-script array.

---

## Gotchas

- **`workspace:*` must be pinned before publish** — bun/npm won't rewrite it; pin → publish → restore
- **npm token** — automation token stored in memory as `reference_npm_token` (expires 2026-08-26)
- **SDK publishes first** — registry must have it before react/mcp/cli resolve it
- **Paid plugin source never ships** — `strip-guard.sh` verifies this; if it fails, fix before publish
- **`apps/one` is never written by `release.sh`** — it is the SSOT and owns its own history; the commit lands in the one-ie monorepo. Anything the mirror has that apps/one lacks must be moved by hand, deliberately.

---

*apps/one is the source; the template mirrors it via rsync. Paid plugins ship to nobody yet. npm packages publish in dependency order.*
