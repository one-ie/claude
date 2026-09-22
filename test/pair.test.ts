// Proof 8 of text/claude-code-integration.md — the terminal shows the receipt's userId and pins
// NOTHING until the human answers y. A fake one.ie on 127.0.0.1 plays provision → code → token;
// each case names the answer (or the server reply) that must leave no pairing file behind.
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, test } from 'bun:test'
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from 'node:fs'
import { hostname, tmpdir } from 'node:os'
import { join } from 'node:path'
import { PassThrough } from 'node:stream'
import { pair, resolveArgs } from '../channel/pair.ts'

const UID = '3f1c9a2e-7b4d-4e8a-9c21-5d6e7f8a9b0c'
const REG_KEY = 'reg-key-SECRET-7f3a'
const API_KEY = 'scoped-api-key-SECRET-91bc'
const DEVICE_CODE = 'd'.repeat(64)

type Seen = { path: string; auth: string | null; body: Record<string, unknown> }
let seen: Seen[] = []
// What the token door answers, poll by poll; the last entry repeats.
let tokenReplies: Array<{ status: number; body: Record<string, unknown> }> = []
let provisionReply: Record<string, unknown> = {}

let server: ReturnType<typeof Bun.serve>
let base = ''
beforeAll(() => {
  server = Bun.serve({
    hostname: '127.0.0.1',
    port: 0,
    async fetch(req) {
      const path = new URL(req.url).pathname
      const body = (await req.json().catch(() => ({}))) as Record<string, unknown>
      seen.push({ path, auth: req.headers.get('authorization'), body })
      if (path === '/api/provision/agent') return Response.json(provisionReply)
      if (path === '/api/auth/mcp/device/code') {
        return Response.json({ device_code: DEVICE_CODE, user_code: 'BCDF-GHJK', verification_uri: `${base}/device`, expires_in: 600, interval: 5 })
      }
      if (path === '/api/auth/mcp/device/token') {
        const polls = seen.filter((s) => s.path === path).length
        const r = tokenReplies[Math.min(polls, tokenReplies.length) - 1]
        return Response.json(r.body, { status: r.status })
      }
      return new Response('not found', { status: 404 })
    },
  })
  base = `http://127.0.0.1:${server.port}`
})
afterAll(() => server.stop(true))

let home = ''
beforeEach(() => {
  seen = []
  provisionReply = { uid: UID, workspace: UID, apiKey: API_KEY, regKey: REG_KEY, expiresAt: 1 }
  tokenReplies = [
    { status: 400, body: { error: 'authorization_pending' } },
    { status: 200, body: { granted: 'adopt', workspace: UID, userId: 'tony' } },
  ]
  home = mkdtempSync(join(tmpdir(), 'one-pair-'))
  process.env.ONE_CHANNEL_HOME = join(home, 'channel')
})
afterEach(() => {
  delete process.env.ONE_CHANNEL_HOME
  rmSync(home, { recursive: true, force: true })
})

const pairingFile = () => join(home, 'channel', 'pairing.json')

/** Runs pair() with a typed answer on a stream standing in for the terminal. */
async function run(answer: string | null, over: { isTty?: boolean; baseUrl?: string } = {}) {
  const input = new PassThrough()
  let printed = ''
  const sleeps: number[] = []
  const io = {
    input,
    isTty: over.isTty ?? true,
    out: (s: string) => {
      printed += s
      // Type the answer only once the question is on screen, as a human would.
      if (answer !== null && s.includes('[y/N]')) input.end(`${answer}\n`)
    },
    err: (s: string) => {
      printed += s
    },
  }
  const code = await pair(
    { baseUrl: over.baseUrl ?? base, channelsUrl: 'http://127.0.0.1:9', name: 'toc-mbp', ttlDays: 30 },
    io,
    { sleep: async (ms: number) => void sleeps.push(ms) },
  )
  if (answer === null) input.end()
  return { code, printed, sleeps }
}

function expectNoSecretPrinted(printed: string) {
  expect(printed).not.toContain(REG_KEY)
  expect(printed).not.toContain(API_KEY)
}

describe('pair — the terminal confirms before anything is pinned', () => {
  test('answer "n": the receipt userId is shown, NOTHING is written, exit non-zero', async () => {
    const { code, printed } = await run('n')
    expect(printed).toContain('Paired to tony? [y/N]')
    expect(code).not.toBe(0)
    expect(existsSync(pairingFile())).toBe(false)
    expectNoSecretPrinted(printed)
  })

  test('answer "" (just Enter) is a no: nothing written', async () => {
    const { code } = await run('')
    expect(code).not.toBe(0)
    expect(existsSync(pairingFile())).toBe(false)
  })

  test('answer "y": pairing written 0600 with sender = receipt userId, regKey kept, apiKey never stored', async () => {
    const { code, printed } = await run('y')
    expect(code).toBe(0)
    expect(statSync(pairingFile()).mode & 0o777).toBe(0o600)
    const raw = readFileSync(pairingFile(), 'utf8')
    expect(raw).not.toContain(API_KEY)
    const p = JSON.parse(raw)
    expect(p).toMatchObject({ uid: UID, regKey: REG_KEY, sender: 'tony', channelsUrl: 'http://127.0.0.1:9' })
    expect(Number.isFinite(p.pairedAt)).toBe(true)
    expect(Object.keys(p).sort()).toEqual(['channelsUrl', 'pairedAt', 'regKey', 'sender', 'uid'])
    expectNoSecretPrinted(printed)
    // The wire: provision by hostname, then an adopt code for the machine's OWN group with its regKey.
    expect(seen[0]).toMatchObject({ path: '/api/provision/agent', body: { name: 'toc-mbp', ttlDays: 30 } })
    expect(seen[1]).toEqual({
      path: '/api/auth/mcp/device/code',
      auth: `Bearer ${REG_KEY}`,
      body: { client_id: 'one-channel', grant_type: 'adopt', requester_workspace: UID },
    })
    expect(seen.slice(2).every((s) => s.path === '/api/auth/mcp/device/token' && s.body.client_id === 'one-channel')).toBe(true)
  })

  test('"YES" is accepted; "yep" is not', async () => {
    expect((await run('YES')).code).toBe(0)
    rmSync(pairingFile())
    expect((await run('yep')).code).not.toBe(0)
    expect(existsSync(pairingFile())).toBe(false)
  })

  test('stdin not a terminal: refused BEFORE provisioning — no request, nothing written', async () => {
    const { code, printed } = await run('y', { isTty: false })
    expect(code).not.toBe(0)
    expect(seen).toHaveLength(0)
    expect(existsSync(pairingFile())).toBe(false)
    expect(printed).toContain('not a terminal')
  })

  test('token access_denied: nothing pinned, the question is never asked', async () => {
    tokenReplies = [{ status: 400, body: { error: 'access_denied' } }]
    const { code, printed } = await run('y')
    expect(code).not.toBe(0)
    expect(printed).not.toContain('[y/N]')
    expect(existsSync(pairingFile())).toBe(false)
  })

  test('token expired_token: nothing pinned', async () => {
    tokenReplies = [{ status: 400, body: { error: 'expired_token' } }]
    const { code, printed } = await run('y')
    expect(code).not.toBe(0)
    expect(printed).not.toContain('[y/N]')
    expect(existsSync(pairingFile())).toBe(false)
  })

  test('slow_down widens the poll interval and polling continues to the receipt', async () => {
    tokenReplies = [
      { status: 400, body: { error: 'slow_down' } },
      { status: 200, body: { granted: 'adopt', workspace: UID, userId: 'tony' } },
    ]
    const { code, sleeps } = await run('y')
    expect(code).toBe(0)
    expect(sleeps).toEqual([5000, 10000])
  })

  test('a receipt with no userId (token.ts: user_slug ?? undefined) pins nothing', async () => {
    tokenReplies = [{ status: 200, body: { granted: 'adopt', workspace: UID } }]
    const { code, printed } = await run('y')
    expect(code).not.toBe(0)
    expect(printed).not.toContain('[y/N]')
    expect(existsSync(pairingFile())).toBe(false)
  })

  test('a receipt for another workspace pins nothing', async () => {
    tokenReplies = [{ status: 200, body: { granted: 'adopt', workspace: 'someone-else', userId: 'tony' } }]
    const { code } = await run('y')
    expect(code).not.toBe(0)
    expect(existsSync(pairingFile())).toBe(false)
  })

  test('plain http to a non-loopback host is refused before the regKey could cross it', async () => {
    const { code } = await run('y', { baseUrl: 'http://one.example' })
    expect(code).not.toBe(0)
    expect(seen).toHaveLength(0)
    expect(existsSync(pairingFile())).toBe(false)
  })
})

describe('pair.ts as the human runs it', () => {
  test('no flags, no env: production hosts, the hostname, 90 days', () => {
    expect(resolveArgs([], {})).toEqual({ baseUrl: 'https://one.ie', channelsUrl: 'https://channels.one.ie', name: hostname(), ttlDays: 90 })
  })
  test('flags outrank env; a garbage --ttl-days falls back to 90, never "permanent"', () => {
    const env = { ONE_BASE_URL: 'https://env.example', ONE_CHANNELS_URL: 'https://env-ch.example' }
    expect(resolveArgs(['--base', 'http://127.0.0.1:1', '--channels', 'http://127.0.0.1:2', '--name', 'box', '--ttl-days', '7'], env)).toEqual({
      baseUrl: 'http://127.0.0.1:1',
      channelsUrl: 'http://127.0.0.1:2',
      name: 'box',
      ttlDays: 7,
    })
    expect(resolveArgs(['--ttl-days', 'forever'], env)).toMatchObject({ baseUrl: 'https://env.example', channelsUrl: 'https://env-ch.example', ttlDays: 90 })
  })

  test('piped stdin (what a slash command or `echo y |` gives it) is not a TTY: no request, nothing pinned', async () => {
    const proc = Bun.spawn(['bun', join(import.meta.dir, '..', 'channel', 'pair.ts'), '--base', base, '--channels', 'http://127.0.0.1:9'], {
      stdin: 'pipe',
      stdout: 'pipe',
      stderr: 'pipe',
      env: { ...process.env, ONE_CHANNEL_HOME: join(home, 'channel') },
    })
    proc.stdin.write('y\n')
    proc.stdin.end()
    const code = await proc.exited
    const printed = (await new Response(proc.stdout).text()) + (await new Response(proc.stderr).text())
    expect(code).not.toBe(0)
    expect(printed).toContain('not a terminal')
    expect(seen).toHaveLength(0)
    expect(existsSync(pairingFile())).toBe(false)
  })
})
