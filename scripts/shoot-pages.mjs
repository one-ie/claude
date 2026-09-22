#!/usr/bin/env node
/**
 * shoot-pages.mjs — full-page screenshots of local pages, for the dev loop.
 *
 * WHY THIS EXISTS. `/api/og/screenshot.png` captures by asking Cloudflare's
 * browser-rendering API to fetch a URL. No Cloudflare browser can reach a
 * laptop's localhost, so in dev that door can only ever fall back to the
 * generated SVG card — which makes the screenshot card (RecordGrid's
 * `cardShape="screenshot"`) undesignable locally: no real capture, nothing
 * taller than the window, and therefore no hover scroll to look at.
 *
 * So dev captures locally. This writes PNGs to
 *   one.ie/web/public/og-screenshots/full/<path>.png
 * which Astro serves statically, and which the route redirects to on localhost.
 * A path with no file 404s and the card swaps to its own fallback — the capture
 * being absent must look like an absent capture, never like a broken page.
 *
 *   node .claude/scripts/shoot-pages.mjs                    # every published + draft page
 *   node .claude/scripts/shoot-pages.mjs /p/my-page /about  # just these paths
 *   node .claude/scripts/shoot-pages.mjs --base http://localhost:4321
 *
 * Captures at 1200 wide, fullPage, which is the same shape cfScreenshot asks
 * Cloudflare for — so what you tune against locally is what ships.
 *
 * manifest: monorepo-only
 */

import { mkdirSync, existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const HERE = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(HERE, '../..')
const WEB = join(ROOT, 'one.ie/web')
const OUT = join(WEB, 'public/og-screenshots/full')

const args = process.argv.slice(2)
const baseIdx = args.indexOf('--base')
const BASE = baseIdx >= 0 ? args[baseIdx + 1] : 'http://localhost:4321'
const WIDTH = 1200
// Matches SCREENSHOT_MAX_FULL_PX in lib/render.ts — a local capture that is
// taller than production would ever produce is a preview of something that
// cannot ship.
const MAX_H = 5000

const explicit = args.filter((a) => a.startsWith('/'))

/** Playwright lives in the web package; find it from there, not from cwd. */
function loadChromium() {
  const req = createRequire(join(WEB, 'package.json'))
  try {
    return req('playwright-core').chromium
  } catch {
    try {
      return req('playwright').chromium
    } catch {
      console.error('shoot-pages: playwright not found under one.ie/web. Run `bun install` there.')
      process.exit(1)
    }
  }
}

/** Every page path this workspace serves, read from the same door the UI uses. */
async function listPagePaths() {
  try {
    const r = await fetch(`${BASE}/api/ask/pages:list`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ data: { slug: process.env.DEV_SLUG ?? 'one' } }),
      signal: AbortSignal.timeout(15_000),
    })
    const json = await r.json()
    const pages = json?.result?.pages ?? []
    return pages.map((p) => `/p/${p.slug}`)
  } catch (err) {
    console.error(`shoot-pages: could not list pages (${err.message}). Pass paths explicitly.`)
    return []
  }
}

const paths = explicit.length ? explicit : await listPagePaths()
if (!paths.length) {
  console.error('shoot-pages: nothing to capture.')
  process.exit(1)
}

const chromium = loadChromium()
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: WIDTH, height: 630 } })

let ok = 0
let failed = 0
for (const p of paths) {
  const url = `${BASE}${p}`
  const leaf = p.endsWith('/') ? `${p}index` : p
  const file = join(OUT, `${leaf}.png`)
  mkdirSync(dirname(file), { recursive: true })
  try {
    // `load`, never `networkidle` — lib/render.ts records the measurement: a
    // page carrying a chat island holds an open SSE connection, so the network
    // never goes idle and the capture times out.
    await page.goto(url, { waitUntil: 'load', timeout: 20_000 })
    await page.waitForTimeout(3000)

    // CAPTURE BY RESIZING THE VIEWPORT, NOT BY `clip`.
    // `screenshot({ clip })` without `fullPage` is clipped to the VIEWPORT, so
    // asking for a 5000px region of a 630px viewport silently returns 630px.
    // Measured the first time this ran: every one of 23 files was 1200x630
    // while the log printed 3629, 5000, 2133 — because the log printed the
    // height it had COMPUTED, never the height it had written. Playwright also
    // rejects `clip` together with `fullPage`, so the way to get a capped
    // full-page shot is to make the viewport the height you want and take a
    // plain viewport capture.
    const h0 = await page.evaluate(() => document.documentElement.scrollHeight)
    const height = Math.max(630, Math.min(h0 || 630, MAX_H))
    await page.setViewportSize({ width: WIDTH, height })
    // Re-settle: a taller viewport loads lazy content and can reflow.
    await page.waitForTimeout(600)
    await page.screenshot({ path: file })
    await page.setViewportSize({ width: WIDTH, height: 630 })

    // READ THE FILE BACK. The whole reason this script was wrong once is that
    // it reported an intention rather than a result.
    const png = readFileSync(file)
    const realW = png.readUInt32BE(16)
    const realH = png.readUInt32BE(20)
    const flag = realH < 700 && h0 > 900 ? '  <-- SHORT, page is taller than this' : ''
    console.log(`  ok   ${p}  ${realW}x${realH} (page ${h0})${flag}`)
    ok++
  } catch (err) {
    console.log(`  FAIL ${p}  ${err.message.split('\n')[0]}`)
    failed++
  }
}

await browser.close()
console.log(`shoot-pages: ${ok} captured, ${failed} failed → ${OUT.replace(ROOT + '/', '')}`)
if (!existsSync(OUT)) process.exit(1)
process.exit(failed && !ok ? 1 : 0)
