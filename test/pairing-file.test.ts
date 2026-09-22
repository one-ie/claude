// Rule 5 of text/claude-code-integration.md § The plugin — the key lives in a file only the user
// can read. A group- or world-readable pairing file must be refused, not trusted.
import { afterEach, beforeEach, describe, expect, spyOn, test } from 'bun:test'
import { chmodSync, mkdtempSync, rmSync, statSync, writeFileSync, mkdirSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { readPairing, writePairing, type Pairing } from '../channel/pairing-file.ts'

const P: Pairing = { uid: 'm-uid', regKey: 'reg-secret-value', sender: 'alice', pairedAt: 1, channelsUrl: 'http://127.0.0.1:1' }
let home = ''
beforeEach(() => {
  home = mkdtempSync(join(tmpdir(), 'one-channel-'))
  process.env.ONE_CHANNEL_HOME = join(home, 'channel')
})
afterEach(() => {
  delete process.env.ONE_CHANNEL_HOME
  rmSync(home, { recursive: true, force: true })
})

describe('pairing file', () => {
  test('no file → null (the channel forwards nothing)', () => {
    expect(readPairing()).toBeNull()
  })
  test('writePairing makes the file 0600 and the dir 0700, and readPairing round-trips it', () => {
    writePairing(P)
    expect(statSync(join(home, 'channel', 'pairing.json')).mode & 0o777).toBe(0o600)
    expect(statSync(join(home, 'channel')).mode & 0o777).toBe(0o700)
    expect(readPairing()).toEqual(P)
  })
  test('writePairing tightens a pre-existing 0644 file and 0755 dir', () => {
    mkdirSync(join(home, 'channel'), { mode: 0o755 })
    chmodSync(join(home, 'channel'), 0o755)
    writeFileSync(join(home, 'channel', 'pairing.json'), '{}', { mode: 0o644 })
    chmodSync(join(home, 'channel', 'pairing.json'), 0o644)
    writePairing(P)
    expect(statSync(join(home, 'channel', 'pairing.json')).mode & 0o777).toBe(0o600)
    expect(statSync(join(home, 'channel')).mode & 0o777).toBe(0o700)
  })
  test('a group- or world-readable file is REFUSED, and the key is not logged', () => {
    writePairing(P)
    chmodSync(join(home, 'channel', 'pairing.json'), 0o644)
    const err = spyOn(console, 'error').mockImplementation(() => {})
    expect(readPairing()).toBeNull()
    const logged = err.mock.calls.flat().join(' ')
    expect(logged).toContain('pairing.json')
    expect(logged).not.toContain(P.regKey)
    err.mockRestore()
  })
  test('a file missing a field is refused', () => {
    writePairing({ ...P, sender: '' } as Pairing)
    const err = spyOn(console, 'error').mockImplementation(() => {})
    expect(readPairing()).toBeNull()
    err.mockRestore()
  })
})
