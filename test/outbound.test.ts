// The divert (one.ie/web/src/lib/chat/machine-turn.ts) takes the first row with reply_to = the id it
// sent. Two ways the channel's answer used to miss it: a chat_id the model mistyped (channels drops a
// replyTo that is not in the group → an answered turn reads as data-machine-timeout), and a reply
// mirrored into an inbox thread the divert keeps machine turns out of.
import { describe, expect, test } from 'bun:test'
import { ackBody, Forwarded, mirrorOn, replyBody } from '../channel/outbound.ts'

const NOW = 1_800_000_000_000 // only builds deadline tags; replyBody takes no clock
const frame = (id: string, tags: string | null = null) => ({ id, sender: 'alice', content: 'q', reply_to: null, tags })

describe('mirror is OFF unless the operator opts in', () => {
  test('no env → reply does not mirror into an inbox thread', () => {
    expect(mirrorOn({})).toBe(false)
  })
  test('ONE_CHANNEL_MIRROR=1 opts in', () => {
    expect(mirrorOn({ ONE_CHANNEL_MIRROR: '1' })).toBe(true)
  })
  test('any other value stays off', () => {
    expect(mirrorOn({ ONE_CHANNEL_MIRROR: 'true' })).toBe(false)
    expect(mirrorOn({ ONE_CHANNEL_MIRROR: '0' })).toBe(false)
  })
  test('a default reply body carries mirror:false', () => {
    const f = new Forwarded()
    f.add(frame('sig-1'))
    const d = replyBody('sig-1', 'four', f, mirrorOn({}))
    expect(d).toEqual({ ok: true, body: { content: 'four', replyTo: 'sig-1', mirror: false } })
  })
  test('the ack never mirrors', () => {
    expect(ackBody('sig-1')).toEqual({ content: 'ack', replyTo: 'sig-1', tags: ['ack'], mirror: false })
  })
})

describe('the channel owns replyTo — a chat_id it never forwarded is refused, not posted as an orphan', () => {
  test('a mistyped chat_id is refused with an error the model can read', () => {
    const f = new Forwarded()
    f.add(frame('sig-1789-abc123'))
    const d = replyBody('sig-1789-abc124', 'four', f, false)
    expect(d.ok).toBe(false)
    if (!d.ok) expect(d.error).toContain('sig-1789-abc124')
  })
  test('with nothing forwarded, every reply is refused', () => {
    expect(replyBody('sig-1', 'four', new Forwarded(), false).ok).toBe(false)
  })
  test('a forwarded row whose deadline: tag has since passed can still be answered — the tag bounds delivery (the ack window), not the answer', () => {
    const f = new Forwarded()
    f.add(frame('sig-1', `["deadline:${NOW - 1}"]`))
    expect(replyBody('sig-1', 'slow but honest', f, false).ok).toBe(true)
  })
  test('exactly once: a consumed id refuses a second reply', () => {
    const f = new Forwarded()
    f.add(frame('sig-1'))
    expect(replyBody('sig-1', 'four', f, false).ok).toBe(true)
    f.consume('sig-1')
    expect(replyBody('sig-1', 'again', f, false).ok).toBe(false)
  })
  test('bounded: past the cap the oldest id is forgotten', () => {
    const f = new Forwarded(3)
    for (const id of ['a', 'b', 'c', 'd']) f.add(frame(id))
    expect(replyBody('a', 'x', f, false).ok).toBe(false)
    expect(replyBody('d', 'x', f, false).ok).toBe(true)
  })
})
