# D1 Time-Travel Recovery Runbook

D1 binding: `DB` | Database: `one-owners` | ID: `0559422e-37de-4c27-9667-a43895578e6f`

Time-Travel retains up to 30 days of history. Enable in the CF dashboard under D1 → `one-owners` → Settings → Time-Travel, or:

```bash
wrangler d1 time-travel info one-owners
```

## Recovery procedure

### 1. Identify the target timestamp

```bash
# List recent bookmarks
wrangler d1 time-travel info one-owners

# Or pick an ISO timestamp
TARGET="2026-01-15T12:00:00Z"
```

### 2. Preview the restore (dry-run)

```bash
wrangler d1 time-travel restore one-owners \
  --timestamp "$TARGET" \
  --json \
  --dry-run
```

Confirm row counts match expectations before writing.

### 3. Restore to a new database

Never restore directly to `one-owners` in production. Restore to a shadow DB first:

```bash
wrangler d1 time-travel restore one-owners \
  --timestamp "$TARGET" \
  --database-name one-owners-restore
```

### 4. Validate the shadow DB

```bash
wrangler d1 execute one-owners-restore --command "SELECT COUNT(*) FROM owners"
wrangler d1 execute one-owners-restore --command "SELECT slug, plan, ts FROM owners ORDER BY ts DESC LIMIT 20"
```

### 5. Promote (if validated)

Update `wrangler.toml` binding `DB.database_id` to the restored database ID, then deploy.
Alternatively, copy rows back using `INSERT OR REPLACE` via a migration script.

### 6. Post-restore checks

- Verify session cookies still work (HMAC secret unchanged)
- Verify domains table integrity: `SELECT * FROM domains WHERE verified = 1`
- Verify owners_keys counter values are plausible

## Required before 4d (delete workspace)

Per roles-todo.md: `H11` must ship before `4d` (DangerSection) because irreversible deletes require a recovery path. This runbook IS that path.
