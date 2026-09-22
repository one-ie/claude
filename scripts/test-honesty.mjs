#!/usr/bin/env node
// test-honesty — find tests that CANNOT FAIL.
//
// Written 2026-08-18 after an audit found 8 security tests whose bodies were
// comment-only. They backed a SETTLED contract: text/SECURITY-plan.md names the
// UC9 and UC26 canaries as its proof observable, and the kill-switch grepped
// `[1-9][0-9]+ passed` over the same file — satisfied by ~130 unrelated tests in
// it. An empty body cannot fail, so the contract rested on nothing.
//
// It reports two classes, and only ever counts what it can prove from the source:
//
//   EMPTY   a test body containing no assertion at all. Always a defect: the
//           test is scored as a pass and can never go red.
//   SKIP    a conditional skip (skipIf / it.skip / runIf / ternary-gated it).
//           Not a defect by itself — but a suite that skips is INDISTINGUISHABLE
//           from one that passes, so the count must be visible. 31 tests in this
//           repo sat behind an env var vitest could not see and had never once
//           executed on any machine.
//
// Deliberately NOT a linter. It makes no style judgements and flags nothing it
// cannot demonstrate from the text of the file.
//
// Usage:  node .claude/scripts/test-honesty.mjs [--json] [dir ...]
// Exit:   1 if any EMPTY body is found, else 0.

import { readdirSync, statSync, readFileSync } from 'node:fs'
import path from 'node:path'

const ROOT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..')
const args = process.argv.slice(2)
const JSON_OUT = args.includes('--json')
const dirs = args.filter((a) => !a.startsWith('--'))
const TARGETS = dirs.length ? dirs : ['one.ie/web/tests', 'channels/test', 'channels/tests']

function walk(dir, out = []) {
  let entries
  try { entries = readdirSync(dir) } catch { return out }
  for (const e of entries) {
    const full = path.join(dir, e)
    let st
    try { st = statSync(full) } catch { continue }
    if (st.isDirectory()) walk(full, out)
    else if (/\.(test|spec)\.[tj]sx?$/.test(e)) out.push(full)
  }
  return out
}

// Walk from the opening brace, tracking strings/comments, and return the body.
function bodyFrom(src, openIdx) {
  let depth = 0, i = openIdx
  let inS = null, inLine = false, inBlock = false
  for (; i < src.length; i++) {
    const c = src[i], n = src[i + 1]
    if (inLine) { if (c === '\n') inLine = false; continue }
    if (inBlock) { if (c === '*' && n === '/') { inBlock = false; i++ } continue }
    if (inS) { if (c === '\\') { i++; continue } if (c === inS) inS = null; continue }
    if (c === '/' && n === '/') { inLine = true; i++; continue }
    if (c === '/' && n === '*') { inBlock = true; i++; continue }
    if (c === '"' || c === "'" || c === '`') { inS = c; continue }
    if (c === '{') depth++
    else if (c === '}') { depth--; if (depth === 0) return src.slice(openIdx + 1, i) }
  }
  return null
}

function stripInert(s) {
  return s
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:])\/\/[^\n]*/g, '$1')
}

// An assertion, or a call that defers to one. `expect.assertions`, a bare
// `await somethingThatThrows()`, and custom helpers all count — the point is to
// catch bodies with NOTHING, not to police assertion style.
const ASSERTS = /\b(expect|assert|should|chai|\.rejects|\.resolves|toMatchSnapshot|toThrow|fail\()/

const findings = { empty: [], declared: [], indirect: [], skips: [] }

for (const target of TARGETS) {
  for (const file of walk(path.join(ROOT, target))) {
    const src = readFileSync(file, 'utf8')
    const rel = path.relative(ROOT, file)

    // conditional skips
    for (const m of src.matchAll(/\b(?:it|test|describe)\.(skipIf|runIf|skip)\b|\b(?:skipWithout\w*|maybeIt|maybeDescribe)\s*\(/g)) {
      const line = src.slice(0, m.index).split('\n').length
      findings.skips.push({ file: rel, line, form: m[0].trim() })
    }

    // assertion-free bodies
    const re = /\b(?:it|test)(\.\w+)?\s*\(\s*(['"`])([\s\S]*?)\2\s*,\s*(?:async\s*)?\(\s*\)\s*=>\s*\{/g
    for (const m of re.exec_all ? [] : [...src.matchAll(re)]) {
      const open = src.indexOf('{', m.index + m[0].length - 1)
      const body = bodyFrom(src, open)
      if (body === null) continue
      const code = stripInert(body).trim()
      // Two classes, deliberately unequal. A body with NO CODE is provably
      // unable to fail — a hard error. A body with code but no visible assertion
      // token is only a SUSPICION: it may delegate to a helper that asserts
      // internally (engine-golden.test.ts does exactly that via goldenCheck()).
      // Reporting the second as a failure would make this checker the very thing
      // it exists to catch — confident, and wrong.
      const rec = {
        file: rel,
        line: src.slice(0, m.index).split('\n').length,
        name: m[3].slice(0, 100),
      }
      // An empty body under .skip/.todo is HONEST — vitest reports it as
      // skipped/todo, never as passed, and it documents intent. The defect is an
      // empty body that WILL BE SCORED: it reports a pass and can never go red.
      // That is exactly the shape of the 8 security tests that backed a settled
      // contract while asserting nothing.
      const declared = /^\.(skip|todo|fails)$/.test(m[1] ?? '')
      if (code.length === 0 && !declared) findings.empty.push({ ...rec, reason: 'empty body that will be SCORED AS A PASS' })
      else if (code.length === 0) findings.declared.push({ ...rec, reason: `honest placeholder (${m[1]})` })
      else if (!ASSERTS.test(code)) findings.indirect.push({ ...rec, reason: 'no assertion token — verify it delegates to one' })
    }
  }
}

if (JSON_OUT) {
  console.log(JSON.stringify(findings, null, 2))
} else {
  const bySkipFile = new Map()
  for (const s of findings.skips) bySkipFile.set(s.file, (bySkipFile.get(s.file) ?? 0) + 1)
  console.log(`test-honesty: scanned ${TARGETS.join(', ')}`)
  console.log(`\nSKIP — conditional skips (visible, not failures): ${findings.skips.length} across ${bySkipFile.size} file(s)`)
  for (const [f, n] of [...bySkipFile].sort((a, b) => b[1] - a[1]).slice(0, 15)) console.log(`  ${String(n).padStart(3)}  ${f}`)
  console.log(`\nDECLARED — empty but honestly marked .skip/.todo: ${findings.declared.length}`)
  console.log(`\nINDIRECT — no assertion token; verify each delegates to one: ${findings.indirect.length}`)
    for (const e of findings.indirect.slice(0, 8)) console.log(`  ${e.file}:${e.line}  ${e.name}`)
    if (findings.indirect.length > 8) console.log(`  … ${findings.indirect.length - 8} more (--json for all)`)
    console.log(`\nEMPTY — tests that CANNOT FAIL: ${findings.empty.length}`)
  for (const e of findings.empty) console.log(`  ${e.file}:${e.line}  ${e.reason}\n      ${e.name}`)
}

process.exit(findings.empty.length > 0 ? 1 : 0)
