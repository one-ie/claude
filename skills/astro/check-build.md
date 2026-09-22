# Check Astro Build

**Category:** astro
**Version:** 2.0.0
**Used By:** `astro` skill · `/do` W4 verify wave

## Purpose

Verify `one.ie/web` compiles before shipping. `astro check` emits **human-readable
text, not JSON** — parse the exit code, not the stdout.

## Example

```bash
cd one.ie/web

bun run verify     # THE gate: builds @oneie/sdk, then tsc --noEmit, then vitest run
bun run check      # astro check — types inside .astro templates
bun run typecheck  # tsc --noEmit only (fastest signal on .ts/.tsx)
bun run build      # full production build; the only thing that catches bundler breaks
```

`astro check` prints a summary line of the form
`Result (N files): X errors, Y warnings, Z hints` and exits non-zero on errors.

**Build the SDK first.** `bun run typecheck` on its own reports phantom `TS2307`
module-not-found errors when `packages/sdk/dist` is stale or missing — `bun run verify`
already does the SDK build, which is why it is the gate. In a `/do` worktree also
confirm `node_modules` is present; a partial install fakes a ratchet violation.

## Version History

- **2.0.0** (2026-08-02): Replaced the invented JSON output with the real commands and
  exit-code contract; added the build-SDK-first trap.
- **1.0.0** (2025-10-18): Initial implementation
