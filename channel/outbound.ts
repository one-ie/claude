// What the channel posts back to channels — the reply and the ack. No MCP import, so it runs under
// `bun test` without the SDK installed.
import type { Frame } from './forward.ts'

export type ReplyBody = { content: string; replyTo: string; mirror: boolean; tags?: string[] }
export type ReplyDecision = { ok: true; body: ReplyBody } | { ok: false; error: string }

// The divert keeps machine turns in their own thread; a mirrored reply lands in an inbox thread too.
// Off unless the operator opts in for their own debugging.
export function mirrorOn(env: Record<string, string | undefined> = process.env): boolean {
  return env.ONE_CHANNEL_MIRROR === '1'
}

// The ids this channel forwarded and has not yet answered. replyTo must be one of them: channels drops
// a replyTo it cannot find in the group, so a chat_id the model mistyped would post an orphan and the
// panel would read an answered turn as a timeout. Bounded by count, oldest out first — NOT by the
// row's `deadline:` tag: the divert sets that to the end of its ACK window (delivery), and the turn
// deadline it waits for an answer is longer, so an expiry here would refuse honest slow answers.
export class Forwarded {
  private ids = new Set<string>()
  constructor(private max = 64) {}

  add(frame: Frame): void {
    this.ids.delete(frame.id)
    this.ids.add(frame.id)
    while (this.ids.size > this.max) this.ids.delete(this.ids.values().next().value as string)
  }

  has(id: string): boolean {
    return this.ids.has(id)
  }

  consume(id: string): void {
    this.ids.delete(id)
  }
}

export function replyBody(chatId: string, text: string, forwarded: Forwarded, mirror: boolean): ReplyDecision {
  if (!forwarded.has(chatId)) {
    return { ok: false, error: `Not sent: chat_id "${chatId}" is not a message this channel delivered, or it was already answered. Copy chat_id exactly from the <channel> tag.` }
  }
  return { ok: true, body: { content: text, replyTo: chatId, mirror } }
}

export function ackBody(id: string): ReplyBody {
  return { content: 'ack', replyTo: id, tags: ['ack'], mirror: false }
}
