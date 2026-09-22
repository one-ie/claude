# /oo-push

Push changes in the standalone `oo` clone to `github.com/one-ie/oo`.

**Path (verified 2026-08-02): `/Users/toc/Server/one-ie.pre-mono/oo`.**
`apps/oo/` does **not** exist — that path was wrong and any command using it
fails with "no such file or directory". The clone is the canonical repo: its own
git history, `origin` = `https://github.com/one-ie/oo.git`. The monorepo subtree
was removed 2026-06-20.

Resolve the path before pushing rather than trusting this line — the clone has
moved once already:

```bash
git -C /Users/toc/Server/one-ie.pre-mono/oo remote -v   # must show one-ie/oo.git
```

## Usage

```
/oo-push              # push the oo clone to github.com/one-ie/oo main
/oo-push <branch>     # push to a specific branch
```

## Steps

1. **Resolve branch** — use `$ARGUMENTS` if provided, else `main`

2. **Check for uncommitted changes**
   ```bash
   git -C /Users/toc/Server/one-ie.pre-mono/oo status --short
   ```
   If anything is uncommitted, surface a warning and ask whether to stage + commit
   first. As of 2026-08-02 this tree has uncommitted edits (`README.md`,
   `TUTORIAL.md`, `features.md`) and untracked files under `docs/` — a bare push
   ships none of them, so expect this warning and do not treat it as noise.

3. **Push**
   ```bash
   git -C /Users/toc/Server/one-ie.pre-mono/oo push origin <branch>
   ```

4. **Report**
   ```
   Pushed one-ie.pre-mono/oo → github.com/one-ie/oo (<branch>)
   ```

## Notes

- The monorepo `one-ie/` still carries a stale `oo` remote pointing at the same
  URL — do **not** use `git subtree push --prefix=oo oo main`; the `oo/` prefix
  was deleted from this repo and the subtree rotted.
