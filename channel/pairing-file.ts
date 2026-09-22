// The pairing — the one place the channel's key lives. A file readable by the user alone, never an
// env var and never .mcp.json. Wave 3's /pair writes it; the channel only reads it. No MCP import.
import { chmodSync, mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'

export type Pairing = { uid: string; regKey: string; sender: string; pairedAt: number; channelsUrl: string }

// Resolved per call, so a test (or a second profile) can point ONE_CHANNEL_HOME elsewhere.
function pairingDir(): string {
  return process.env.ONE_CHANNEL_HOME ?? join(homedir(), '.one', 'channel')
}

export function pairingPath(): string {
  return join(pairingDir(), 'pairing.json')
}

export function readPairing(): Pairing | null {
  const path = pairingPath()
  let mode: number
  try {
    mode = statSync(path).mode
  } catch {
    return null
  }
  // A key another local user can read is a key we no longer hold alone — refuse it rather than use it.
  if (mode & 0o077) {
    console.error(`one-channel: refusing ${path} — mode ${(mode & 0o777).toString(8)}; run chmod 600 on it`)
    return null
  }
  let raw: Record<string, unknown>
  try {
    raw = JSON.parse(readFileSync(path, 'utf8'))
  } catch {
    console.error(`one-channel: refusing ${path} — not valid JSON`)
    return null
  }
  const str = (k: string) => (typeof raw?.[k] === 'string' && raw[k] ? (raw[k] as string) : '')
  const p: Pairing = {
    uid: str('uid'),
    regKey: str('regKey'),
    sender: str('sender'),
    pairedAt: typeof raw?.pairedAt === 'number' ? raw.pairedAt : Number.NaN,
    channelsUrl: str('channelsUrl'),
  }
  if (!p.uid || !p.regKey || !p.sender || !p.channelsUrl || !Number.isFinite(p.pairedAt)) {
    console.error(`one-channel: refusing ${path} — a field is missing or empty`)
    return null
  }
  return p
}

export function writePairing(p: Pairing): void {
  const dir = pairingDir()
  mkdirSync(dir, { recursive: true, mode: 0o700 })
  chmodSync(dir, 0o700) // mkdirSync's mode does not tighten a directory that already exists
  const path = pairingPath()
  // Write a fresh 0600 file and rename it over the old one, so the key never sits in a
  // pre-existing file that was group- or world-readable, not even for one write.
  const tmp = `${path}.${process.pid}.tmp`
  writeFileSync(tmp, `${JSON.stringify(p, null, 2)}\n`, { mode: 0o600 })
  chmodSync(tmp, 0o600)
  renameSync(tmp, path)
}
