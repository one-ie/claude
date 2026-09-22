// The forward gate — which inbound rows reach the user's session, which has shell access.
// No MCP import, so it runs under `bun test` without the SDK installed.
import type { Pairing } from './pairing-file.ts'

// `tags` is the stored JSON string on a /stream frame (channels stringifies on write), or null.
export type Frame = { id: string; sender: string; content: string; reply_to?: string | null; tags?: string | string[] | null }
export type Verdict = { forward: true } | { forward: false; reason: 'unpaired' | 'reply' | 'self' | 'sender' | 'tags' | 'expired' }

// null = unparseable. A raw `.includes('deadline:')` on the string half-works, which is why this parses.
export function parseTags(tags: Frame['tags']): string[] | null {
  if (tags == null || tags === '') return []
  if (Array.isArray(tags)) return tags.map(String)
  try {
    const parsed = JSON.parse(tags)
    return Array.isArray(parsed) ? parsed.map(String) : null
  } catch {
    return null
  }
}

export function shouldForward(frame: Frame, pairing: Pairing | null, now: number): Verdict {
  // Fail closed: no pinned sender forwards nothing. The spike's `if (SENDER && …)` forwarded everyone.
  if (!pairing || !pairing.sender) return { forward: false, reason: 'unpaired' }
  // A reply carries reply_to. The user's panel and this channel share one conversation, so without
  // this guard the channel would feed its own answer back into the session forever.
  if (frame.reply_to) return { forward: false, reason: 'reply' }
  // The machine's own rows — and anything posted with a stolen machine key.
  if (frame.sender === pairing.uid) return { forward: false, reason: 'self' }
  // Gate on the sender's identity, never the room's.
  if (frame.sender !== pairing.sender) return { forward: false, reason: 'sender' }
  const tags = parseTags(frame.tags)
  if (!tags) return { forward: false, reason: 'tags' }
  for (const t of tags) {
    if (!t.startsWith('deadline:')) continue
    // The panel already told the human "nothing was delivered"; a late row must keep that true.
    const deadline = Number(t.slice('deadline:'.length))
    if (!Number.isFinite(deadline) || deadline <= now) return { forward: false, reason: 'expired' }
  }
  return { forward: true }
}
