#!/usr/bin/env bun
// ONE channel. A Claude Code Channel (research preview): an MCP server
// Claude Code spawns on the user's machine. It pushes messages into the user's
// OWN running session and takes the answer back through a `reply` tool.
// ONE never holds a Claude credential and never runs the turn.
// Plan: text/claude-code-integration.md § The plugin. Terms gate: Gate 0 — do not ship before it answers.
//
// Two inbound sources, both outward-only from the user's machine:
//   the pairing file (pairing-file.ts) → SSE from channels /stream/<uid> with the machine's regKey (SELF rung)
//   ONE_CHANNEL_TEST_PORT              → 127.0.0.1 loopback POST /in, for local proof only; off unless set
// Both pass shouldForward (forward.ts): no pairing, no pinned sender → nothing is forwarded.
import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js'
import { appendFileSync } from 'node:fs'
import { type Frame, shouldForward } from './forward.ts'
import { ackBody, Forwarded, mirrorOn, replyBody, type ReplyBody } from './outbound.ts'
import { type Pairing, readPairing } from './pairing-file.ts'

const TEST_PORT = Number(process.env.ONE_CHANNEL_TEST_PORT ?? 0)
const OUT_LOG = process.env.ONE_CHANNEL_OUT_LOG ?? ''
const MIRROR = mirrorOn()
const forwarded = new Forwarded()

// Re-read on every stream (re)connect, so deleting the file unpairs a running channel.
let pairing: Pairing | null = readPairing()
if (!pairing) console.error('one-channel: not paired — forwarding nothing')

const mcp = new Server(
  { name: 'one-channel', version: '0.0.2' },
  {
    capabilities: { experimental: { 'claude/channel': {} }, tools: {} },
    instructions:
      'Messages from the user\'s ONE chat panel arrive as <channel source="one-channel" chat_id="...">. ' +
      'Answer with the reply tool exactly once per message. ' +
      'Pass the chat_id from the tag. Reply in plain text.',
  },
)

mcp.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'reply',
      description: 'Send an answer back to the ONE chat panel',
      inputSchema: {
        type: 'object',
        properties: {
          chat_id: { type: 'string', description: 'The chat_id from the channel tag' },
          text: { type: 'string', description: 'The answer' },
        },
        required: ['chat_id', 'text'],
      },
    },
  ],
}))

// Same path cc-connect send uses; the server binds the sender to this key (#14).
async function post(p: Pairing, body: ReplyBody): Promise<void> {
  const res = await fetch(`${p.channelsUrl}/signal/${p.uid}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${p.regKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`signal ${res.status}`)
}

mcp.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name !== 'reply') throw new Error(`unknown tool: ${req.params.name}`)
  const { chat_id, text } = req.params.arguments as { chat_id: string; text: string }
  const decision = replyBody(String(chat_id ?? ''), String(text ?? ''), forwarded, MIRROR)
  if (!decision.ok) return { content: [{ type: 'text', text: decision.error }], isError: true }
  if (OUT_LOG) appendFileSync(OUT_LOG, JSON.stringify({ chat_id, text, at: Date.now() }) + '\n')
  if (!pairing) throw new Error('one-channel is not paired — nothing was sent')
  await post(pairing, decision.body)
  forwarded.consume(decision.body.replyTo)
  return { content: [{ type: 'text', text: 'sent' }] }
})

const safe = (s: string) => s.replace(/[^\w]/g, '_').slice(0, 64)

async function push(frame: Frame): Promise<boolean> {
  const p = pairing
  const verdict = shouldForward(frame, p, Date.now())
  if (!verdict.forward) {
    // Replies are this channel's own loop traffic; every other drop is worth a local line. Never the content.
    if (verdict.reason !== 'reply') console.error(`one-channel: dropped ${safe(frame.id)} from ${safe(frame.sender)} — ${verdict.reason}`)
    return false
  }
  // Remembered before the push, so a reply can never race ahead of the id it answers.
  forwarded.add(frame)
  await mcp.notification({
    method: 'notifications/claude/channel',
    params: { content: frame.content, meta: { chat_id: frame.id, sender: safe(frame.sender) } },
  })
  // notification() resolves when the message is written to the transport, not when Claude has read
  // it — so the ack proves delivery to the session, and only the reply proves it was read.
  await post(p as Pairing, ackBody(frame.id)).catch((e: Error) =>
    console.error(`one-channel: ack for ${safe(frame.id)} failed — ${e.message}`),
  )
  return true
}

await mcp.connect(new StdioServerTransport())

if (TEST_PORT) {
  Bun.serve({
    port: TEST_PORT,
    hostname: '127.0.0.1',
    async fetch(req) {
      if (req.method !== 'POST' || new URL(req.url).pathname !== '/in') return new Response('not found', { status: 404 })
      const b = (await req.json().catch(() => ({}))) as Partial<Frame> & { chat_id?: string }
      const ok = await push({ id: b.chat_id ?? 'test', sender: b.sender ?? '', content: b.content ?? '', reply_to: b.reply_to ?? null, tags: b.tags ?? null })
      return Response.json({ forwarded: ok })
    },
  })
}

// SSE listener — outward connection only. Reconnect with Last-Event-ID via ?since.
let since = Date.now()
for (;;) {
  pairing = readPairing()
  const p = pairing
  if (!p) {
    await new Promise((r) => setTimeout(r, 30_000))
    continue
  }
  try {
    const res = await fetch(`${p.channelsUrl}/stream/${p.uid}?since=${since}`, { headers: { Authorization: `Bearer ${p.regKey}` } })
    if (!res.ok || !res.body) throw new Error(`stream ${res.status}`)
    const dec = new TextDecoder()
    let buf = ''
    for await (const chunk of res.body as unknown as AsyncIterable<Uint8Array>) {
      buf += dec.decode(chunk, { stream: true })
      let i: number
      while ((i = buf.indexOf('\n\n')) >= 0) {
        const frame = buf.slice(0, i)
        buf = buf.slice(i + 2)
        const data = frame.split('\n').find((l) => l.startsWith('data: '))
        if (!data) continue
        const m = JSON.parse(data.slice(6)) as Frame & { ts: number }
        since = Math.max(since, m.ts)
        await push(m)
      }
    }
  } catch {
    await new Promise((r) => setTimeout(r, 2000))
  }
}
