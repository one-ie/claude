// Proof 2 of text/claude-code-integration.md — the channel forwards only the pinned sender's
// rows into a session that has shell access. Each case names the row that must NOT reach it.
import { describe, expect, test } from 'bun:test'
import { shouldForward } from '../channel/forward.ts'

const NOW = 1_800_000_000_000
const pairing = { uid: 'm-uid', regKey: 'k', sender: 'alice', pairedAt: 1, channelsUrl: 'http://127.0.0.1:1' }
const row = (over: Record<string, unknown> = {}) =>
  ({ id: 'sig-1', sender: 'alice', content: 'hi', reply_to: null, tags: null, ...over }) as Parameters<typeof shouldForward>[0]

describe('shouldForward — fail closed on the sender pin', () => {
  test('no pairing: a row from anyone is NOT forwarded', () => {
    expect(shouldForward(row({ sender: 'mallory' }), null, NOW)).toEqual({ forward: false, reason: 'unpaired' })
  })
  test('a pairing with an empty pin forwards nothing', () => {
    expect(shouldForward(row({ sender: '' }), { ...pairing, sender: '' }, NOW)).toEqual({ forward: false, reason: 'unpaired' })
  })
  test('pinned: another sender is dropped', () => {
    expect(shouldForward(row({ sender: 'mallory' }), pairing, NOW)).toEqual({ forward: false, reason: 'sender' })
  })
  test('pinned: the pinned sender is forwarded', () => {
    expect(shouldForward(row(), pairing, NOW)).toEqual({ forward: true })
  })
  test("the machine's own rows (sender === uid) are dropped as self", () => {
    expect(shouldForward(row({ sender: 'm-uid' }), pairing, NOW)).toEqual({ forward: false, reason: 'self' })
  })
  test('a reply (reply_to set) is dropped even from the pinned sender', () => {
    expect(shouldForward(row({ reply_to: 'sig-0' }), pairing, NOW)).toEqual({ forward: false, reason: 'reply' })
  })
})

describe('shouldForward — deadline tags arrive as a JSON string', () => {
  test('a passed deadline:<ms> is dropped — no late delivery', () => {
    expect(shouldForward(row({ tags: `["deadline:${NOW - 1}"]` }), pairing, NOW)).toEqual({ forward: false, reason: 'expired' })
  })
  test('a future deadline is forwarded', () => {
    expect(shouldForward(row({ tags: `["deadline:${NOW + 60_000}"]` }), pairing, NOW)).toEqual({ forward: true })
  })
  test('null tags (the /stream shape for an untagged row) are forwarded', () => {
    expect(shouldForward(row({ tags: null }), pairing, NOW)).toEqual({ forward: true })
  })
  test('a tag merely CONTAINING "deadline:" is not a deadline — parsed, not substring-matched', () => {
    expect(shouldForward(row({ tags: `["x-deadline:${NOW - 1}"]` }), pairing, NOW)).toEqual({ forward: true })
  })
  test('unparseable tags fail closed', () => {
    expect(shouldForward(row({ tags: '["deadline:' }), pairing, NOW)).toEqual({ forward: false, reason: 'tags' })
  })
  test('a non-numeric deadline fails closed', () => {
    expect(shouldForward(row({ tags: '["deadline:soon"]' }), pairing, NOW)).toEqual({ forward: false, reason: 'expired' })
  })
})
