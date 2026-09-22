#!/usr/bin/env bun
// w1-recon.ts — defers to Claude Code agent spawn (Max subscription path).
// Direct SDK caching only matters on API billing; exit 2 sends the caller to
// the Agent tool which uses the active Claude Code session.
process.stderr.write("[w1-recon] using agent spawn\n");
process.exit(2);
