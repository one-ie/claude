// /pair — enrol this machine as its own small group and have the human adopt it
// (text/claude-code-integration.md § Pairing, steps 1-6). The human runs it in a terminal:
//
//   bun ${CLAUDE_PLUGIN_ROOT}/channel/pair.ts [--base https://one.ie] [--channels https://channels.one.ie]
//
// A script, not a slash command: a slash command runs bash with no terminal, so the keypress that
// decides who may drive this session could only come from the model — the one party that must
// not answer it. No terminal on stdin → refuse before anything is minted.
//
// packages/cli/src/device-flow.ts is NOT reused: it sends no grant_type or bearer and reads a 200
// without access_token as an error, after token.ts has already burned the row.
//
// Only node:* and pairing-file.ts — this runs before the MCP server ever starts.
import { hostname } from 'node:os'
import { createInterface } from 'node:readline'
import { pairingPath, readPairing, writePairing } from './pairing-file.ts'

const CLIENT_ID = 'one-channel'
const DEFAULT_BASE = 'https://one.ie'
const DEFAULT_CHANNELS = 'https://channels.one.ie'
const DEFAULT_TTL_DAYS = 90 // provision/agent.ts's own default; the key and the pairing end together
const UID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

export type PairOptions = { baseUrl: string; channelsUrl: string; name: string; ttlDays: number }
export type PairIO = {
  input: NodeJS.ReadableStream
  isTty: boolean
  out: (s: string) => void
  err: (s: string) => void
}
type Deps = { sleep?: (ms: number) => Promise<void>; now?: () => number }

// The regKey rides as a bearer to both hosts, so neither may be plain http off this machine.
function safeUrl(raw: string): string | null {
  let u: URL
  try {
    u = new URL(raw)
  } catch {
    return null
  }
  const loopback = u.hostname === '127.0.0.1' || u.hostname === 'localhost' || u.hostname === '[::1]'
  if (u.protocol !== 'https:' && !(u.protocol === 'http:' && loopback)) return null
  return u.origin
}

async function postJson(url: string, body: unknown, bearer?: string) {
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...(bearer ? { Authorization: `Bearer ${bearer}` } : {}) },
    body: JSON.stringify(body),
  })
  const json = (await res.json().catch(() => null)) as Record<string, unknown> | null
  return { status: res.status, ok: res.ok, body: json ?? {} }
}

function readLine(input: NodeJS.ReadableStream): Promise<string> {
  return new Promise((resolve) => {
    const rl = createInterface({ input, terminal: false })
    let answered = false
    rl.once('line', (line) => {
      answered = true
      rl.close()
      resolve(line)
    })
    rl.once('close', () => {
      if (!answered) resolve('')
    })
  })
}

/** Returns the exit code. 0 only when the human said yes and the pairing file was written. */
export async function pair(opts: PairOptions, io: PairIO, deps: Deps = {}): Promise<number> {
  const sleep = deps.sleep ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)))
  const now = deps.now ?? Date.now
  const fail = (msg: string) => {
    io.err(`pair: ${msg}\n`)
    return 1
  }

  if (!io.isTty) {
    io.err(`pair: stdin is not a terminal. Run it yourself, in a terminal: bun ${import.meta.path}\nNothing was provisioned and nothing was pinned.\n`)
    return 2
  }
  const base = safeUrl(opts.baseUrl)
  const channelsUrl = safeUrl(opts.channelsUrl)
  if (!base) return fail(`refusing base URL ${opts.baseUrl} — https only (plain http to loopback is allowed)`)
  if (!channelsUrl) return fail(`refusing channels URL ${opts.channelsUrl} — https only (plain http to loopback is allowed)`)

  // 1. Enrol. Keep uid + regKey; the scoped apiKey is a second live credential the channel never needs.
  const prov = await postJson(`${base}/api/provision/agent`, { name: opts.name, ttlDays: opts.ttlDays })
  const uid = typeof prov.body.uid === 'string' ? prov.body.uid : ''
  const regKey = typeof prov.body.regKey === 'string' ? prov.body.regKey : ''
  if (!prov.ok || !UID.test(uid) || !regKey) {
    return fail(`enrolment failed (HTTP ${prov.status}${typeof prov.body.error === 'string' ? `, ${prov.body.error}` : ''})`)
  }
  // The pin, the stream and the divert all key on uid as the group; a different workspace breaks all three.
  if (prov.body.workspace !== undefined && prov.body.workspace !== uid) {
    return fail(`enrolment answered workspace ${String(prov.body.workspace)} for machine ${uid}; refusing to pair a split identity`)
  }

  // 2. Ask for an adopt code for this machine's OWN group — the SELF case at device/code.ts.
  const code = await postJson(
    `${base}/api/auth/mcp/device/code`,
    { client_id: CLIENT_ID, grant_type: 'adopt', requester_workspace: uid },
    regKey,
  )
  const deviceCode = typeof code.body.device_code === 'string' ? code.body.device_code : ''
  const userCode = typeof code.body.user_code === 'string' ? code.body.user_code : ''
  if (!code.ok || !deviceCode || !userCode) {
    return fail(`adopt code refused (HTTP ${code.status}${typeof code.body.error === 'string' ? `, ${code.body.error}` : ''})`)
  }

  // 3. Show the code and where to type it.
  io.out(`\nMachine "${opts.name}" is enrolled as ${uid}.\n`)
  io.out(`Open ${base}/device, sign in, and enter:\n\n    ${userCode}\n\n`)
  io.out(`The page shows this machine's IP and location. Approve only if they are this machine.\nWaiting…\n`)

  // 4. Poll. Every non-receipt answer is HTTP 400 with an OAuth error body — branch on the body.
  let intervalMs = Math.max(1, Number(code.body.interval) || 5) * 1000
  const deadline = now() + Math.max(1, Number(code.body.expires_in) || 600) * 1000
  let receipt: Record<string, unknown> | null = null
  while (now() < deadline) {
    await sleep(intervalMs)
    const t = await postJson(`${base}/api/auth/mcp/device/token`, { device_code: deviceCode, client_id: CLIENT_ID })
    if (t.body.granted !== undefined) {
      receipt = t.body
      break
    }
    const e = t.body.error
    if (e === 'authorization_pending') continue
    if (e === 'slow_down') {
      intervalMs += 5000
      continue
    }
    if (e === 'access_denied') return fail('the adoption was denied at /device. Nothing was pinned.')
    if (e === 'expired_token') return fail('the code expired before anyone approved it. Nothing was pinned.')
    return fail(`unexpected answer from device/token (HTTP ${t.status}${typeof e === 'string' ? `, ${e}` : ''}). Nothing was pinned.`)
  }
  if (!receipt) return fail('the code expired before anyone approved it. Nothing was pinned.')

  const userId = receipt.userId
  if (receipt.granted !== 'adopt' || receipt.workspace !== uid || typeof userId !== 'string' || !userId || userId.trim() !== userId) {
    return fail('the approval receipt does not name this machine and one person. Nothing was pinned.')
  }

  // 5. The human confirms who approved. Whoever wins a guessed code would otherwise become the
  //    one sender this session obeys (threat model, "A guessed adopt code").
  const current = readPairing()
  if (current) io.out(`This replaces the current pairing (sender ${current.sender}).\n`)
  io.out(`Paired to ${userId}? [y/N] `)
  const answer = (await readLine(io.input)).trim().toLowerCase()
  if (answer !== 'y' && answer !== 'yes') {
    io.err(`\nNot pinned — nothing was written. ${userId} still owns machine group ${uid} on ONE until its key expires.\n`)
    return 1
  }

  // 6. Pin userId as the only sender this channel forwards.
  writePairing({ uid, regKey, sender: userId, pairedAt: now(), channelsUrl })
  io.out(`\nPinned. The channel forwards messages from ${userId} only. Pairing: ${pairingPath()}\n`)
  return 0
}

function flag(args: string[], name: string): string | undefined {
  const i = args.indexOf(name)
  return i >= 0 ? args[i + 1] : undefined
}

/** The command line as the entrypoint reads it. Nothing here can touch the terminal check. */
export function resolveArgs(args: string[], env: Record<string, string | undefined> = process.env): PairOptions {
  const ttl = Number(flag(args, '--ttl-days'))
  return {
    baseUrl: flag(args, '--base') ?? env.ONE_BASE_URL ?? DEFAULT_BASE,
    channelsUrl: flag(args, '--channels') ?? env.ONE_CHANNELS_URL ?? DEFAULT_CHANNELS,
    name: flag(args, '--name') ?? hostname(),
    ttlDays: Number.isFinite(ttl) && ttl > 0 ? ttl : DEFAULT_TTL_DAYS,
  }
}

if (import.meta.main) {
  const code = await pair(
    resolveArgs(process.argv.slice(2)),
    {
      input: process.stdin,
      // Read from the process, never from a flag or env var: an override would be a bypass.
      isTty: process.stdin.isTTY === true,
      out: (s) => process.stdout.write(s),
      err: (s) => process.stderr.write(s),
    },
  )
  process.exit(code)
}
