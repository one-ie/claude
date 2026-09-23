#!/usr/bin/env bun
export {}
// UserPromptSubmit hook — announce Claude Code session to space:<slug> #staff once per session.
// Reads ONE_WORKSPACE_SLUG + ONE_API_KEY from $CLAUDE_PROJECT_DIR/.env.local.

const projectDir = process.env.CLAUDE_PROJECT_DIR ?? process.cwd()

async function readEnv(): Promise<Record<string, string>> {
  const out: Record<string, string> = {}
  for (const src of ['.env', '.env.local']) {
    const f = Bun.file(`${projectDir}/${src}`)
    if (!await f.exists()) continue
    for (const line of (await f.text()).split('\n')) {
      const [k, ...rest] = line.split('=')
      if (k && rest.length) out[k.trim()] = rest.join('=').trim()
    }
  }
  // Also honour process.env overrides
  for (const k of ['ONE_API_KEY', 'ONE_WORKSPACE_SLUG', 'ONE_API_URL', 'ONE_ANNOUNCE_SESSIONS']) {
    if (process.env[k]) out[k] = process.env[k]!
  }
  return out
}

async function main(): Promise<void> {
  let stdin = ''
  try {
    for await (const chunk of (process as unknown as { stdin: AsyncIterable<Uint8Array> }).stdin) {
      stdin += new TextDecoder().decode(chunk)
    }
  } catch { /* no payload */ }

  let ctx: { session_id?: string } = {}
  try { ctx = JSON.parse(stdin) } catch {}

  const sessionId = ctx.session_id
  if (!sessionId) return

  const flagFile = `/tmp/one-announced-${sessionId}`
  if (await Bun.file(flagFile).exists()) return
  await Bun.write(flagFile, '1')
  await Bun.write(`/tmp/one-ts-${sessionId}`, String(Date.now()))

  const env = await readEnv()
  const slug = env.ONE_WORKSPACE_SLUG
  const key  = env.ONE_API_KEY
  const base = env.ONE_API_URL ?? 'https://one.ie'
  if (!slug || !key) return

  // Start SSE listener for macOS notifications (best-effort).
  const ccConnect = `${projectDir}/node_modules/@oneie/claude/scripts/cc-connect.sh`
  try {
    Bun.spawn(['bash', ccConnect, 'join', `space:${slug}`], { stdout: 'pipe', stderr: 'pipe' })
  } catch {}

  // Start watcher daemon.
  try {
    Bun.spawn(['bun', `${projectDir}/node_modules/@oneie/claude/hooks/scripts/watcher.ts`, sessionId], {
      stdout: 'ignore', stderr: 'ignore', cwd: projectDir,
    })
  } catch {}

  // Announce to space:<slug> #staff — opt-in. On by default it posted once per
  // session, headless review runs included: 12 posts in ~11h to space:vespio
  // (2026-09-23), all from one operator's Mac, read by the group as activity.
  if (env.ONE_ANNOUNCE_SESSIONS !== '1') return
  try {
    await fetch(`${base}/api/ask/space:post`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify({ data: { space: slug, content: `Claude Code session started (${slug})`, tags: ['staff'] } }),
      signal: AbortSignal.timeout(5000),
    })
  } catch {}
}

await main()
