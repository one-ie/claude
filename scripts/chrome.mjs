#!/usr/bin/env node
/**
 * chrome.mjs — headless-shell browser driver. Replaces the `claude-in-chrome`
 * MCP tools for every non-interactive job: PROVE gates, page diagnostics,
 * scraping, form drills, screenshots.
 *
 * Engine: chrome-headless-shell, launched through Playwright's
 * `chromium-headless-shell` channel. No extension, no Chrome profile, no
 * running desktop browser, no human in the loop. One process per invocation.
 *
 * Usage:
 *   node .claude/scripts/chrome.mjs <url> [flags]
 *
 * Flags:
 *   --text                 include page innerText (truncated, see --max)
 *   --html                 include page HTML (truncated, see --max)
 *   --sel <css>            scope --text/--html to a selector
 *   --screenshot [path]    PNG (default /tmp/chrome-shot.png); --full-page for the whole document
 *   --console              include ALL console lines (errors are always included)
 *   --network              include every request/response (default: /api/ only, on --network-all)
 *   --network-all          widen --network past /api/
 *   --eval <js>            evaluate an expression in the page, return its value
 *   --do <json>            run a step list — see STEPS below
 *   --send <msg>           chat drill: fill the first textarea, Enter, capture the SSE stream
 *   --wait <ms>            settle time after load (default 2500)
 *   --timeout <ms>         navigation timeout (default 20000)
 *   --state <path>         persist cookies + localStorage to <path> and reuse them next
 *                          run — the one thing a fresh process cannot have on its own
 *   --cookie <n=v>         add a cookie for the target host (repeatable)
 *   --header <k: v>        extra HTTP header (repeatable)
 *   --ua <string>          user agent
 *   --viewport <WxH>       viewport (default 1280x800)
 *   --reduced-motion       emulate `prefers-reduced-motion: reduce` for the run, so a
 *                          reduced-motion rule can be CHECKED instead of believed:
 *                          drive the same route twice and diff the computed styles
 *   --headed               use full Chromium with a visible window instead of the shell
 *   --max <n>              truncation ceiling for text/html/eval (default 4000)
 *
 * STEPS (--do) — a JSON array, executed in order, each a single-key object:
 *   {"goto":"https://…"}            navigate
 *   {"click":"<css|text=…>"}        click
 *   {"fill":"<css>","value":"…"}    fill an input
 *   {"press":"Enter","sel":"<css>"} key press (sel optional → page-level)
 *   {"select":"<css>","value":"…"}  <select> option
 *   {"dblclick":"<css>"}            double click
 *   {"hover":"<css>"}               hover
 *   {"check":"<css>","value":false} check / uncheck a box (value defaults true)
 *   {"upload":"<css>","files":[…]}  set file inputs
 *   {"scroll":600} | {"scroll":"<css>"}  wheel by px, or scroll a node into view
 *   {"wait":1500}                   sleep ms
 *   {"waitFor":"<css>"}             wait for a selector
 *   {"eval":"<js>"}                 evaluate, appended to steps[].result
 *   {"screenshot":"/path.png"}      capture mid-run
 * Every step reports {step, ok, error?, result?} — a failed step does not abort the run.
 *
 * Env:
 *   PROVE_SESSION_COOKIE   "name=value" — same contract as browser-check.mjs
 *   ONE_PLAYWRIGHT_DIR     explicit path to a node_modules dir holding playwright
 *
 * Output: one JSON report on stdout. Exit 0 = the run completed (read httpStatus
 * and jsErrors for the verdict); exit 1 = the browser could not run at all.
 */

import { createRequire } from 'node:module'
import { existsSync, readdirSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'

const HERE = dirname(fileURLToPath(import.meta.url))
const REPO = resolve(HERE, '../..')

// ---------------------------------------------------------------- playwright
// No package name is hardcoded — this must work in any tree that has Playwright
// somewhere, at the root or in a workspace member. A linked worktree has no
// node_modules of its own, so the main worktree is probed too, via git's common
// dir. Never hardcode an absolute user path.
const SKIP_DIR = /^(\.|node_modules$|dist$|build$|target$|\.git$)/

function subdirs(dir) {
  try {
    return readdirSync(dir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && !SKIP_DIR.test(d.name))
      .map((d) => join(dir, d.name))
  } catch { return [] }
}

function playwrightRoots() {
  const roots = []
  if (process.env.ONE_PLAYWRIGHT_DIR) roots.push(process.env.ONE_PLAYWRIGHT_DIR)

  const trees = [REPO]
  try {
    const common = execFileSync('git', ['rev-parse', '--path-format=absolute', '--git-common-dir'], {
      cwd: REPO, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim()
    if (common) trees.push(dirname(common))
  } catch { /* not a git tree — fine */ }

  // Root first, then workspace members up to two levels down. Bounded on
  // purpose: deep enough for `<app>/<surface>/node_modules`, shallow enough
  // never to walk a whole tree.
  for (const t of trees) {
    roots.push(join(t, 'node_modules'))
    for (const d1 of subdirs(t)) {
      roots.push(join(d1, 'node_modules'))
      for (const d2 of subdirs(d1)) roots.push(join(d2, 'node_modules'))
    }
  }
  roots.push('/tmp/node_modules') // legacy browser-check location
  return [...new Set(roots)]
}

function loadPlaywright() {
  for (const root of playwrightRoots()) {
    const entry = join(root, 'playwright', 'index.js')
    if (!existsSync(entry)) continue
    try {
      return { mod: createRequire(join(root, 'noop.js'))('playwright'), from: root }
    } catch { /* try the next root */ }
  }
  return null
}

const pw = loadPlaywright()
if (!pw) {
  console.error(JSON.stringify({
    error: 'playwright_not_found',
    searched: playwrightRoots(),
    fix: 'install playwright in this tree, then: npx playwright install chromium-headless-shell',
  }, null, 2))
  process.exit(1)
}
const { chromium } = pw.mod

// ---------------------------------------------------------------------- args
const argv = process.argv.slice(2)
const flag = (name) => argv.includes(`--${name}`)
const val = (name, fallback = null) => {
  const i = argv.indexOf(`--${name}`)
  if (i === -1) return fallback
  const v = argv[i + 1]
  return v === undefined || v.startsWith('--') ? true : v
}
const all = (name) => argv.flatMap((a, i) => (a === `--${name}` && argv[i + 1] && !argv[i + 1].startsWith('--') ? [argv[i + 1]] : []))

const url = argv.find((a) => /^(https?|file):\/\//.test(a)) ?? 'http://localhost:4321'
const MAX = Number(val('max', 4000)) || 4000
const waitMs = Number(val('wait', 2500)) || 0
const timeout = Number(val('timeout', 20000)) || 20000
const cut = (s) => (typeof s === 'string' && s.length > MAX ? `${s.slice(0, MAX)}…[+${s.length - MAX}]` : s)

let steps = []
const doArg = val('do')
if (typeof doArg === 'string') {
  try { steps = JSON.parse(doArg) } catch (e) {
    console.error(JSON.stringify({ error: 'bad_steps_json', detail: e.message }, null, 2))
    process.exit(1)
  }
  if (!Array.isArray(steps)) { console.error(JSON.stringify({ error: 'steps_must_be_array' })); process.exit(1) }
}

// ------------------------------------------------------------------- browser
const headed = flag('headed')
let browser
try {
  browser = headed
    ? await chromium.launch({ headless: false })
    : await chromium.launch({ channel: 'chromium-headless-shell' })
} catch (e) {
  // Channel missing (shell not installed) → plain headless chromium still works.
  try {
    browser = await chromium.launch({ headless: !headed })
  } catch (e2) {
    console.error(JSON.stringify({
      error: 'browser_launch_failed', shell: e.message, fallback: e2.message,
      fix: 'npx playwright install chromium-headless-shell',
    }, null, 2))
    process.exit(1)
  }
}

// --state gives this tool the one thing a fresh process cannot have: a session
// that survives the run. Sign in once with --state, and every later invocation
// reuses the cookies and localStorage instead of re-authenticating.
const statePath = typeof val('state') === 'string' ? val('state') : null
const stateLoaded = Boolean(statePath && existsSync(statePath))

const [vw, vh] = String(val('viewport', '1280x800')).split('x').map(Number)
// THE FLAG text/ehc-motion.md ASKED FOR, and what it buys.
//
// That page could not write an `accept:` for its own central rule — "reduced
// motion must reach the same final frame" — because this harness had no way to
// ask for the flag, so every reduced-motion block in the repo was believed
// rather than checked, and one of them (`Layout.astro:599`) had already been
// correct, reviewed, and DEAD because its sheet was not on the page. An
// animation is the one kind of code whose failure looks exactly like success.
//
// Playwright emulates it per context (CDP `Emulation.setEmulatedMedia`), so the
// same route can be driven twice and the two `getComputedStyle` readings
// compared. `--reduced-motion` asks for `reduce`; the default stays `no-preference`
// so every existing caller reads exactly what it read before.
const reducedMotion = flag('reduced-motion') ? 'reduce' : 'no-preference'
const context = await browser.newContext({
  viewport: { width: vw || 1280, height: vh || 800 },
  reducedMotion,
  ...(stateLoaded ? { storageState: statePath } : {}),
  ...(typeof val('ua') === 'string' ? { userAgent: val('ua') } : {}),
  ...(all('header').length
    ? { extraHTTPHeaders: Object.fromEntries(all('header').map((h) => {
        const i = h.indexOf(':')
        return [h.slice(0, i).trim(), h.slice(i + 1).trim()]
      })) }
    : {}),
})

const cookieSpecs = [...all('cookie'), ...(process.env.PROVE_SESSION_COOKIE ? [process.env.PROVE_SESSION_COOKIE] : [])]
if (cookieSpecs.length && /^https?:/.test(url)) { // a file:// url has no host to scope a cookie to
  const { hostname } = new URL(url)
  await context.addCookies(cookieSpecs.flatMap((spec) => {
    const [name, ...rest] = spec.split('=')
    const value = rest.join('=')
    return name && value ? [{ name, value, domain: hostname, path: '/' }] : []
  }))
}

const page = await context.newPage()

// ------------------------------------------------------------------ recorders
const consoleLogs = []
const jsErrors = []
const requests = []
page.on('console', (m) => consoleLogs.push({ type: m.type(), text: m.text().slice(0, 500) }))
page.on('pageerror', (e) => jsErrors.push(String(e).slice(0, 500)))

const wantNetwork = flag('network') || flag('network-all')
const netAll = flag('network-all')
if (wantNetwork) {
  page.on('response', async (r) => {
    const u = r.url()
    if (!netAll && !u.includes('/api/')) return
    requests.push({ method: r.request().method(), status: r.status(), url: u.split('?')[0] })
  })
}

// SSE/chat capture — kept byte-for-byte compatible with browser-check.mjs so
// `--send` reports the same chatCapture shape /do PROVE steps already read.
const sendMsg = typeof val('send') === 'string' ? val('send') : null
if (sendMsg) {
  await page.addInitScript(() => {
    const orig = window.fetch
    window.__chatCapture = []
    window.fetch = async (...args) => {
      const u = args[0]?.toString() || ''
      if (u.includes('/api/chat') && !u.includes('warmup') && !u.includes('tts')) {
        const method = args[1]?.method || 'GET'
        const body = typeof args[1]?.body === 'string' ? args[1].body : ''
        if (method === 'POST') {
          window.__chatCapture.push({ type: 'request', body: body.substring(0, 200) })
          const resp = await orig(...args)
          const reader = resp.clone().body?.getReader()
          if (reader) {
            let chunks = ''
            for (;;) {
              const { done, value } = await reader.read()
              if (done) break
              chunks += new TextDecoder().decode(value)
            }
            window.__chatCapture.push({ type: 'stream', status: resp.status, body: chunks.substring(0, 800) })
          }
          return resp
        }
      }
      return orig(...args)
    }
  })
}

// ---------------------------------------------------------------------- load
let httpStatus = 0
let navError = null
try {
  const res = await page.goto(url, { waitUntil: 'load', timeout })
  httpStatus = res ? res.status() : 0
} catch (e) {
  navError = e.message
}
if (waitMs) await page.waitForTimeout(waitMs)

const title = await page.title().catch(() => null)
const railBefore = sendMsg
  ? await page.evaluate(() => document.querySelector('.chat-rail')?.innerText?.substring(0, 200) || null).catch(() => null)
  : undefined

// --------------------------------------------------------------------- steps
const stepResults = []
for (const [i, step] of steps.entries()) {
  const kind = Object.keys(step)[0]
  const rec = { step: i, kind, ok: true }
  try {
    if (step.goto) { const r = await page.goto(step.goto, { waitUntil: 'load', timeout }); rec.result = r?.status() ?? 0 }
    else if (step.click) await page.click(step.click, { timeout: 8000 })
    else if (step.fill !== undefined) await page.fill(step.fill, String(step.value ?? ''), { timeout: 8000 })
    else if (step.press) { step.sel ? await page.press(step.sel, step.press) : await page.keyboard.press(step.press) }
    else if (step.select) await page.selectOption(step.select, String(step.value ?? ''))
    else if (step.dblclick) await page.dblclick(step.dblclick, { timeout: 8000 })
    else if (step.hover) await page.hover(step.hover, { timeout: 8000 })
    else if (step.check) await page.setChecked(step.check, step.value !== false, { timeout: 8000 })
    else if (step.upload) await page.setInputFiles(step.upload, [].concat(step.files ?? step.value ?? []), { timeout: 8000 })
    else if (step.scroll !== undefined) {
      // window.scrollBy, not mouse.wheel — the wheel needs a pointer parked over
      // the document and silently scrolls nothing in the headless shell when it
      // isn't (measured: {"scroll":1200} left scrollY at 0 on a 4000px page).
      typeof step.scroll === 'string'
        ? await page.evaluate((s) => document.querySelector(s)?.scrollIntoView({ block: 'center' }), step.scroll)
        : await page.evaluate((px) => window.scrollBy(0, px), Number(step.scroll))
    }
    else if (step.wait) await page.waitForTimeout(Number(step.wait))
    else if (step.waitFor) await page.waitForSelector(step.waitFor, { timeout: 10000 })
    else if (step.eval) rec.result = cut(JSON.stringify(await page.evaluate(step.eval)))
    else if (step.screenshot) { await page.screenshot({ path: step.screenshot, fullPage: flag('full-page') }); rec.result = step.screenshot }
    else { rec.ok = false; rec.error = `unknown step kind: ${kind}` }
  } catch (e) {
    rec.ok = false
    rec.error = e.message.split('\n')[0].slice(0, 300)
  }
  stepResults.push(rec)
}

// ---------------------------------------------------------------- chat drill
let chatCapture
let railAfter
if (sendMsg) {
  const ta = await page.$('textarea')
  if (ta) {
    await ta.fill(sendMsg)
    await ta.press('Enter')
    await page.waitForTimeout(Number(val('send-wait', 12000)) || 12000)
    railAfter = await page.evaluate(() => document.querySelector('.chat-rail')?.innerText?.substring(0, 400) || null)
  }
  chatCapture = await page.evaluate(() => window.__chatCapture || [])
}

// ------------------------------------------------------------------- extract
const sel = typeof val('sel') === 'string' ? val('sel') : null
let text
let html
if (flag('text')) {
  text = cut(await page.evaluate((s) => (s ? document.querySelector(s)?.innerText : document.body?.innerText) || '', sel))
}
if (flag('html')) {
  html = cut(await page.evaluate((s) => (s ? document.querySelector(s)?.outerHTML : document.documentElement?.outerHTML) || '', sel))
}

let evalResult
const evalJs = typeof val('eval') === 'string' ? val('eval') : null
if (evalJs) {
  try { evalResult = cut(JSON.stringify(await page.evaluate(evalJs))) }
  catch (e) { evalResult = `ERROR: ${e.message.split('\n')[0]}` }
}

let screenshot
if (flag('screenshot')) {
  screenshot = typeof val('screenshot') === 'string' ? val('screenshot') : '/tmp/chrome-shot.png'
  await page.screenshot({ path: screenshot, fullPage: flag('full-page') }).catch((e) => { screenshot = `ERROR: ${e.message}` })
}

let stateSaved
if (statePath) {
  try { await context.storageState({ path: statePath }); stateSaved = statePath }
  catch (e) { stateSaved = `ERROR: ${e.message}` }
}

await browser.close()

// -------------------------------------------------------------------- report
console.log(JSON.stringify({
  url,
  finalUrl: page.url(),
  engine: headed ? 'chromium (headed)' : 'chrome-headless-shell',
  playwrightFrom: pw.from,
  stateLoaded: statePath ? stateLoaded : undefined,
  stateSaved,
  httpStatus,
  navError,
  title,
  jsErrors,
  consoleErrors: consoleLogs.filter((l) => l.type === 'error').map((l) => l.text),
  console: flag('console') ? consoleLogs : undefined,
  network: wantNetwork ? requests : undefined,
  steps: steps.length ? stepResults : undefined,
  chatCapture,
  chatRailBefore: railBefore,
  chatRailAfter: sendMsg ? railAfter : undefined,
  text,
  html,
  eval: evalResult,
  screenshot,
}, null, 2))
