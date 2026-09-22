#!/usr/bin/env bun
export {}
// Stop hook — remove session flag files so watcher.ts exits cleanly.
let stdin = ''
try {
  for await (const chunk of (process as unknown as { stdin: AsyncIterable<Uint8Array> }).stdin) {
    stdin += new TextDecoder().decode(chunk)
  }
} catch {}

let ctx: { session_id?: string } = {}
try { ctx = JSON.parse(stdin) } catch {}

const sessionId = ctx.session_id
if (sessionId) {
  Bun.spawn(['rm', '-f', `/tmp/one-announced-${sessionId}`, `/tmp/one-ts-${sessionId}`])
}
