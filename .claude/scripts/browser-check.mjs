#!/usr/bin/env node
/**
 * browser-check.mjs — Playwright browser diagnostic tool.
 *
 * Usage:
 *   node .claude/scripts/browser-check.mjs [url] [--send "message"] [--screenshot] [--network]
 *
 * Requires: playwright in /tmp/node_modules (installed once, persists across sessions)
 * Install:  cd /tmp && npm install playwright && npx playwright install chromium
 *
 * What it checks:
 *   - Page load (status, title, console errors)
 *   - Chat rail text before/after sending a message (--send)
 *   - API request/response monitoring (--network)
 *   - Screenshot saved to /tmp/browser-check.png (--screenshot)
 *   - JS errors, React hydration errors
 */

import pkg from '/tmp/node_modules/playwright/index.js'
const { chromium } = pkg
import { writeFileSync } from 'fs'

const args = process.argv.slice(2)
const urlArg = args.find(a => a.startsWith('http')) ?? 'http://localhost:4321'
const sendMsg = args.find((_, i) => args[i - 1] === '--send') ?? null
const doScreenshot = args.includes('--screenshot')
const doNetwork = args.includes('--network')

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage()

// Capture console output
const consoleLogs = []
const jsErrors = []
page.on('console', m => consoleLogs.push({ type: m.type(), text: m.text() }))
page.on('pageerror', e => jsErrors.push(String(e)))

// Network monitoring
const apiRequests = []
const apiResponses = []
if (doNetwork) {
  page.on('request', req => {
    if (req.url().includes('/api/')) {
      apiRequests.push({ method: req.method(), url: req.url().split('?')[0] })
    }
  })
}

// Patch fetch to capture chat API body + stream
await page.addInitScript(() => {
  const orig = window.fetch
  window.__chatCapture = []
  window.fetch = async (...args) => {
    const url = args[0]?.toString() || ''
    if (url.includes('/api/chat') && !url.includes('warmup') && !url.includes('tts')) {
      const method = args[1]?.method || 'GET'
      const body = typeof args[1]?.body === 'string' ? args[1].body : ''
      if (method === 'POST') {
        window.__chatCapture.push({ type: 'request', body: body.substring(0, 200) })
        const resp = await orig(...args)
        const clone = resp.clone()
        const reader = clone.body?.getReader()
        if (reader) {
          let chunks = ''
          while (true) {
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

// Load page
const res = await page.goto(urlArg, { waitUntil: 'load', timeout: 15000 }).catch(e => ({ status: () => 0, error: e.message }))
const httpStatus = typeof res?.status === 'function' ? res.status() : 0
await page.waitForTimeout(2500)

const title = await page.title().catch(() => '(no title)')
const chatRailBefore = await page.evaluate(() => document.querySelector('.chat-rail')?.innerText?.substring(0, 200) || null)

// Send message if requested
let chatRailAfter = null
if (sendMsg) {
  const ta = await page.$('textarea')
  if (ta) {
    await ta.fill(sendMsg)
    await ta.press('Enter')
    await page.waitForTimeout(12000)
    chatRailAfter = await page.evaluate(() => document.querySelector('.chat-rail')?.innerText?.substring(0, 400) || null)
  }
}

// Screenshot
if (doScreenshot) {
  await page.screenshot({ path: '/tmp/browser-check.png', fullPage: false })
}

const chatCapture = await page.evaluate(() => window.__chatCapture || [])

await browser.close()

// Report
const report = {
  url: urlArg,
  httpStatus,
  title,
  jsErrors,
  consoleErrors: consoleLogs.filter(l => l.type === 'error').map(l => l.text),
  chatRailBefore,
  chatRailAfter: sendMsg ? chatRailAfter : undefined,
  chatCapture: sendMsg ? chatCapture : undefined,
  apiRequests: doNetwork ? apiRequests : undefined,
  screenshot: doScreenshot ? '/tmp/browser-check.png' : undefined,
}

console.log(JSON.stringify(report, null, 2))
