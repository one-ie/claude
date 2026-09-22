#!/usr/bin/env node
/**
 * browser-check.mjs — DEPRECATED SHIM. Kept so existing callers keep working.
 *
 * The engine is now `.claude/scripts/chrome.mjs` (chrome-headless-shell via
 * Playwright). This file maps the old flag set onto it and renames the report
 * fields back to the shape `do-prove.sh` and `/browser` already parse.
 *
 * New work calls chrome.mjs directly — it has steps, network, eval, selectors,
 * cookies and headers this shim does not expose.
 *
 * Old usage (unchanged):
 *   node .claude/scripts/browser-check.mjs [url] [--send "msg"] [--screenshot] [--network]
 *
 * Old prerequisite (`npm install playwright` into /tmp) is GONE. chrome.mjs
 * finds Playwright wherever this tree installed it, including from a linked
 * worktree. The /tmp copy had already evaporated, which silently degraded every
 * browser PROVE to a curl fallback.
 */

import { spawnSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = dirname(fileURLToPath(import.meta.url))
const args = process.argv.slice(2)

const url = args.find((a) => a.startsWith('http')) ?? 'http://localhost:4321'
const sendMsg = args.find((_, i) => args[i - 1] === '--send') ?? null
const doScreenshot = args.includes('--screenshot')
const doNetwork = args.includes('--network')

const argv = [join(HERE, 'chrome.mjs'), url]
if (sendMsg) argv.push('--send', sendMsg)
if (doScreenshot) argv.push('--screenshot', '/tmp/browser-check.png')
if (doNetwork) argv.push('--network')

const run = spawnSync(process.execPath, argv, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 })
if (run.status !== 0) {
  process.stderr.write(run.stderr || 'chrome.mjs failed\n')
  process.exit(run.status ?? 1)
}

let r
try {
  r = JSON.parse(run.stdout)
} catch {
  process.stdout.write(run.stdout)
  process.exit(0)
}

console.log(JSON.stringify({
  url: r.url,
  httpStatus: r.httpStatus,
  title: r.title ?? '(no title)',
  jsErrors: r.jsErrors,
  consoleErrors: r.consoleErrors,
  chatRailBefore: r.chatRailBefore ?? null,
  chatRailAfter: sendMsg ? (r.chatRailAfter ?? null) : undefined,
  chatCapture: sendMsg ? (r.chatCapture ?? []) : undefined,
  apiRequests: doNetwork ? (r.network ?? []).map((n) => ({ method: n.method, url: n.url })) : undefined,
  screenshot: doScreenshot ? '/tmp/browser-check.png' : undefined,
}, null, 2))
