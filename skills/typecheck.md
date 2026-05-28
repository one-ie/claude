---
name: typecheck
description: Run `tsc --noEmit` strict checks across the ONE workspace — `one.ie/web/`, `agents/`, `api/`, `sync/`, `backup/`, `packages/*`. Use when the user asks to "typecheck", "check types", before committing TypeScript changes, or as the stability gate. Each package has its own `tsconfig.json`; run in the package directory or via `bun run --filter '*' typecheck` from `packages/`.
user-invocable: true
allowed-tools: Bash
---

# TypeScript Type Check

**Skills:** `/do` (W4 verify runs this — types must be clean for rubric `stability` dim) · `/deploy` (W0 baseline gate — `scripts/typecheck.sh` wraps tsc and suppresses the known internal stack-overflow bug per memory `feedback_typecheck_crash.md`: real errors start with `TS####`)

Run TypeScript compiler in check mode without emitting files.

## Commands

```bash
# Single package
cd one.ie/web && bunx tsc --noEmit

# All packages (workspace)
cd packages && bun run --filter '*' typecheck
```

## Expected Output

Success:
```
✓ No type errors found
```

Errors:
```
src/components/workspace/AgentWorkspace.tsx:42:5 - error TS2322: Type 'X' is not assignable to type 'Y'.
```

## Configuration

TypeScript config is in `tsconfig.json`:

```json
{
  "extends": "astro/tsconfigs/strict",
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "jsx": "preserve",
    "jsxImportSource": "react"
  }
}
```

## Common Issues

1. **Missing type imports**: Add `import type { X } from '...'`
2. **Path alias not resolving**: Check `tsconfig.json` paths
3. **JSX errors**: Ensure `"jsx": "preserve"` is set

## Astro Check (includes TypeScript)

```bash
bunx astro check
```

This also validates Astro components and frontmatter.
