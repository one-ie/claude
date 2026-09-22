#!/usr/bin/env node
// wf-check — syntax-check dynamic workflow scripts the way the RUNTIME parses them.
//
// Why this exists: a syntax error in a workflow script doesn't fail loudly, it stops
// the workflow from launching at all. do-engine.js already carries a scar comment
// about one such case (a second top-level `export` is illegal in a workflow body).
//
// Why the obvious checkers are wrong for this file shape:
//   node --check <f>.js   → silently exits 0 for ANY file starting with `export`
//                           (verified on node v24.15.0 — the ESM path is a no-op).
//   node --check <f>.mjs  → real ESM parse, but rejects the top-level `return` and
//                           `await` that every workflow body legitimately uses.
// The runtime wraps the body in an async function, so that is what we parse it as.
//
// Usage:  node .claude/scripts/wf-check.mjs [file ...]
//         (no args → every .js under .claude/workflows/)
// Exit 0 = all green. Exit 1 = at least one script would fail to launch.

import { readFileSync, readdirSync, existsSync } from 'node:fs'
import { join } from 'node:path'

const WF_DIR = '.claude/workflows'
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor
const HOOKS = ['args', 'budget', 'agent', 'parallel', 'pipeline', 'log', 'phase', 'workflow']

function check(file) {
  let src
  try {
    src = readFileSync(file, 'utf8')
  } catch (e) {
    return { file, ok: false, msg: `unreadable: ${e.message}` }
  }

  // The loader permits exactly one top-level export: the leading `export const meta`.
  const exports = src.match(/^export\s/gm) ?? []
  if (exports.length > 1) {
    return { file, ok: false, msg: `${exports.length} top-level exports — only the leading \`export const meta\` is permitted` }
  }
  if (!/^export\s+const\s+meta\s*=/m.test(src)) {
    return { file, ok: false, msg: 'missing the required leading `export const meta = {...}`' }
  }

  try {
    new AsyncFunction(...HOOKS, src.replace(/^export\s+const\s+meta/m, 'const meta'))
  } catch (e) {
    return { file, ok: false, msg: e.message }
  }

  // Syntax is only half of "would this launch and behave". The seam checks below
  // catch the read/write divergences that launch fine and then quietly corrupt
  // the run — see the block above them for the three that actually happened.
  const seam = seamChecks(file, src)
  if (seam.length) return { file, ok: false, msg: `${seam.length} seam violation(s):\n        - ${seam.join('\n        - ')}` }
  return { file, ok: true }
}


// ── Seam checks ───────────────────────────────────────────────────────────
// Three of the five engine bugs fixed on 2026-08-31 were ONE defect: a fact the
// engine depends on lived in two places and only one of them was real.
//   · the tick   — done-ness lived in W4's verdict AND the todo checkbox; nothing
//                  copied one to the other, so proven work was rebuilt forever.
//   · the census — the model lived in Q.w1[0] AND in a 'haiku' string literal;
//                  they diverged under quality:'max', teaching world:pick-model
//                  that the cheap model had done the expensive model's work.
//   · the clobber— an append instruction lived in the prompt text AND in the
//                  agent's tool grant; W2 has no Bash, so it read-modify-wrote
//                  the census and clobbered every parallel sibling.
// The repo's own rule (CLAUDE.md): two instances of one defect shape ⇒ fix the
// SEAM, never the sites. These are that seam, asserted at edit time by the
// post-edit hook. Prove they can go RED with `--self-test`.

// Read the balanced argument list of the call that starts at `open` (index of '(').
function balancedArgs(src, open) {
  let depth = 0
  for (let i = open; i < src.length; i++) {
    const c = src[i]
    if (c === '(' || c === '[' || c === '{') depth++
    else if (c === ')' || c === ']' || c === '}') {
      depth--
      if (depth === 0) return src.slice(open + 1, i)
    } else if (c === '`' || c === "'" || c === '"') {
      // skip the string body so its brackets never move the depth
      const q = c
      i++
      while (i < src.length && src[i] !== q) i += src[i] === '\\' ? 2 : 1
    }
  }
  return null
}

// SEAM 1 — the recorded model must BE the model, never a copy of it.
// censusAppend(cid, [['W1', <model>], ...]) — every <model> slot must be an
// identifier expression (Q.w1[0], w2Model). A quoted literal is a second source
// of truth for a fact the router LEARNS from, and it silently rots.
function checkCensusLiterals(src) {
  const out = []
  const re = /censusAppend\s*\(/g
  let m
  while ((m = re.exec(src))) {
    const argsSrc = balancedArgs(src, re.lastIndex - 1)
    if (!argsSrc) continue
    for (const pair of argsSrc.match(/\[\s*(['"`])W\d+\1\s*,[^\]]*\]/g) ?? []) {
      const model = pair.split(',').slice(1).join(',').replace(/\]\s*$/, '').trim()
      if (/^(['"`]).*\1$/.test(model)) {
        out.push(`census records a HARDCODED model ${model} in ${pair.trim()} — it must be the same expression that SPAWNS the agent (e.g. Q.w1[0]), or the census teaches world:pick-model a model that never ran`)
      }
    }
  }
  return out
}

// SEAM 2 — never ask an agent to run what its grant forbids.
// If a prompt tells the agent to run a shell command, the agentType receiving it
// must hold Bash in .claude/agents/<type>.md. W2 (Read/Grep/Glob/Write) was told
// to `printf >> census`; unable to run it, it rewrote the whole file instead.
const SHELL_INSTRUCTION = /(?:^|\W)(?:run (?:this|these) (?:exact|one) |printf |>>\s*\$?\{?\w|bash \.claude\/scripts\/|cd \$\{WT\})/
function grantOf(type) {
  const f = `.claude/agents/${type}.md`
  if (!existsSync(f)) return null
  const m = readFileSync(f, 'utf8').match(/^tools:\s*"?([^"\n]+)"?/m)
  return m ? m[1].split(',').map((t) => t.trim()) : null
}
function checkInstructionGrant(src) {
  const out = []
  const re = /\bagent\s*\(/g
  let m
  while ((m = re.exec(src))) {
    const argsSrc = balancedArgs(src, re.lastIndex - 1)
    if (!argsSrc) continue
    const type = argsSrc.match(/agentType:\s*['"`]([\w-]+)['"`]/)?.[1]
    if (!type) continue
    const prompt = argsSrc.slice(0, argsSrc.indexOf('agentType:'))
    if (!SHELL_INSTRUCTION.test(prompt)) continue
    const tools = grantOf(type)
    if (!tools) {
      out.push(`agent(agentType:'${type}') is handed a shell instruction but .claude/agents/${type}.md has no readable tools: line — the grant cannot be checked`)
    } else if (!tools.includes('Bash')) {
      out.push(`agent(agentType:'${type}') is told to RUN a command, but its grant is [${tools.join(', ')}] — no Bash. It cannot comply and will do something else instead (W2 read-modify-wrote the census and clobbered its siblings). Move the command to an agent that has Bash.`)
    }
  }
  return out
}

// SEAM 3 — behavioural parity of the cycle-line shape across its four
// implementations is proven by a separate runner, because it spans three
// languages and two files this checker does not parse:
//     bash .claude/scripts/do-cycle-shape-check.sh
function seamChecks(file, src) {
  if (!/\bagent\s*\(/.test(src)) return []
  return [...checkCensusLiterals(src), ...checkInstructionGrant(src)]
}

const args = process.argv.slice(2)
const files = args.length
  ? args
  : existsSync(WF_DIR)
    ? readdirSync(WF_DIR).filter((f) => f.endsWith('.js')).map((f) => join(WF_DIR, f))
    : []

if (!files.length) {
  console.log('wf-check: no workflow scripts found')
  process.exit(0)
}

let failed = 0
for (const f of files) {
  const r = check(f)
  if (r.ok) {
    console.log(`  ok    ${r.file}`)
  } else {
    failed++
    console.log(`  FAIL  ${r.file}: ${r.msg}`)
  }
}

console.log(`wf-check: ${files.length - failed}/${files.length} green`)
process.exit(failed ? 1 : 0)
