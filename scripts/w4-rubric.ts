#!/usr/bin/env bun
// w4-rubric.ts — the TASK rubric judge (5 axes, no goal-fit).
//
// This computes the `task` rubric, NOT the in-cycle W4 cycle gate. The two are
// different by design: a diff handed to this script carries no plan context, so
// goal-fit cannot be scored here. The cycle gate adds goal-fit at 0.30 and gates
// on it at >= 0.50 — see .claude/commands/do.md § W4. Its output is labelled
// `task-composite` so it can never be read as a cycle verdict.
//
// Weights and axis definitions come from rubric-weights.json — the single
// source. Do not restate them here.
//
// Usage: w4-rubric.ts [edge] [--self-test] [--gate 0.65]
// Reads diff from stdin. Exits 0=pass, 1=fail, 2=defer-to-agent.
import { readFileSync, existsSync } from 'fs'

const args = process.argv.slice(2)
const selfTest = args.includes('--self-test')
const edge = args.find(a => !a.startsWith('--')) ?? (process.env.DO_SLUG ? `do/${process.env.DO_SLUG}` : 'do/unknown')

// The weights file sits beside this script. A missing or malformed file is a
// hard failure, never a fallback to inlined numbers — a silent divergence
// between the file and a hardcoded copy is the exact drift this file removes.
const WEIGHTS_PATH = new URL('./rubric-weights.json', import.meta.url).pathname
type Rubric = {
  gate: number
  task: { weights: Record<string, number> }
  definitions: Record<string, string>
}
function loadRubric(): Rubric {
  try {
    return JSON.parse(readFileSync(WEIGHTS_PATH, 'utf8')) as Rubric
  } catch (e) {
    process.stderr.write(`[w4-rubric] cannot read ${WEIGHTS_PATH}: ${(e as Error).message}\n`)
    process.exit(1)
    throw e // unreachable — process.exit never returns; satisfies the checker without @types/node
  }
}
const RUBRIC = loadRubric()
const W = RUBRIC.task.weights
const AXES = Object.keys(W)
const wSum = AXES.reduce((n, k) => n + W[k], 0)
if (Math.abs(wSum - 1) > 1e-9) {
  process.stderr.write(`[w4-rubric] task weights sum to ${wSum}, not 1.00 — refusing to score\n`)
  process.exit(1)
}

const gate = parseFloat(args.find(a => a.startsWith('--gate='))?.slice(7) ?? String(RUBRIC.gate))
// integration is deterministic when the caller knows it (W4 computes it from
// .w2-surface-checklist.json + do-reconcile.sh sdk|navigation|docs and passes
// --integration=0.NN); only when absent does the LLM score it from the diff.
const integrationArg = args.find(a => a.startsWith('--integration='))?.slice(14)

function composite(s: Record<string,number>) {
  return AXES.reduce((n, k) => n + s[k] * W[k], 0)
}

// --self-test vectors. `pass` is the historical fixture; `fail` exists so the
// gate can be shown going RED. A gate that has only ever been observed passing
// is indistinguishable from a gate that cannot fail.
const SELF_TEST_SCORES: Record<string, number> =
  { security: 0.90, stability: 1.00, simplicity: 0.80, integration: 0.85, speed: 0.75 }
const SELF_TEST_FAIL: Record<string, number> =
  { security: 0.40, stability: 0.40, simplicity: 0.40, integration: 0.40, speed: 0.40 }

async function judge(diff: string): Promise<Record<string,number>> {
  const envFile = process.env.ONE_ENV_FILE ?? process.env.DO_ENV_FILE ?? 'one.ie/web/.env'
  let key = process.env.OPENROUTER_API_KEY ?? ''
  if (!key && existsSync(envFile)) {
    const m = readFileSync(envFile,'utf8').split('\n').find(l => l.startsWith('OPENROUTER_API_KEY='))
    if (m) key = m.slice(m.indexOf('=')+1).replace(/^["']|["']$/g,'')
  }
  if (!key) { process.stderr.write('[w4-rubric] no OPENROUTER_API_KEY — deferring\n'); process.exit(2) }
  const gwAccount = process.env.CF_AI_GATEWAY_ACCOUNT_ID
  const gwId = process.env.CF_AI_GATEWAY_ID
  const orBase = gwAccount && gwId
    ? `https://gateway.ai.cloudflare.com/v1/${gwAccount}/${gwId}/openrouter`
    : 'https://openrouter.ai/api/v1'
  const res = await fetch(`${orBase}/chat/completions`, {
    method:'POST', headers:{'Authorization':`Bearer ${key}`,'Content-Type':'application/json'},
    body:JSON.stringify({ model:'anthropic/claude-haiku-4-5', max_tokens:80,
      messages:[
        // Every axis carries its definition from rubric-weights.json. An axis
        // scored without one is scored against whatever the model invents that
        // run — `stability` carried 0.25 weight undefined until 2026-08-02.
        {role:'system',content:
          `Score this diff on ${AXES.join('/')} (0-1). Definitions:\n`
          + AXES.map(k => `- ${k}: ${RUBRIC.definitions[k] ?? '(UNDEFINED — score 0 and say so)'}`).join('\n')
          + `\nJSON only, exactly these keys: {${AXES.map(k => `"${k}":0.8`).join(',')}}`},
        {role:'user',content:diff.slice(0,3000)}
      ]})
  })
  const raw = ((await res.json()) as {choices?:{message?:{content?:string}}[]}).choices?.[0]?.message?.content ?? ''
  const m2 = raw.match(/\{[^}]+\}/)
  if (!m2) { process.stderr.write('[w4-rubric] bad LLM response — deferring\n'); process.exit(2) }
  const d = JSON.parse(m2[0]) as Record<string,unknown>
  const c = (v:unknown) => Math.max(0, Math.min(1, Number(v)||0))
  // An axis the model omitted must not silently become 0 inside a weighted sum —
  // that reads as "scored badly" when it means "not scored at all".
  const missing = AXES.filter(k => d[k] === undefined)
  if (missing.length) {
    process.stderr.write(`[w4-rubric] LLM omitted ${missing.join(',')} — deferring\n`)
    process.exit(2)
  }
  return Object.fromEntries(AXES.map(k => [k, c(d[k])])) as Record<string, number>
}

async function main() {
  const failFixture = args.includes('--self-test-fail')
  const scores: Record<string, number> = (selfTest || failFixture)
    ? Object.fromEntries(AXES.map(k => [k, (failFixture ? SELF_TEST_FAIL : SELF_TEST_SCORES)[k] ?? 0.80]))
    : await judge(await new Promise<string>(r => { let s=''; process.stdin.on('data',c=>s+=c); process.stdin.on('end',()=>r(s)) }))
  // deterministic override wins: the surface checklist is truth, not vibes
  if (integrationArg !== undefined) scores.integration = Math.max(0, Math.min(1, parseFloat(integrationArg)||0))
  const comp = composite(scores)
  const baseUrl = process.env.DO_SIGNAL_URL ?? 'https://one.ie'
  if (!selfTest && edge !== 'do/unknown') {
    // /api/mark-dims is gate()-guarded (security-gates #5) — it authenticates a service
    // caller by Bearer === GATEWAY_API_KEY. Resolve it the same way judge() resolves the
    // OpenRouter key (process.env → DO_ENV_FILE). Without it the marks silently 401 and
    // the /do rubric-learning signal stops landing — a break the #5 gate introduced.
    const envFile = process.env.ONE_ENV_FILE ?? process.env.DO_ENV_FILE ?? 'one.ie/web/.env'
    let gwKey = process.env.GATEWAY_API_KEY ?? ''
    if (!gwKey && existsSync(envFile)) {
      const m = readFileSync(envFile,'utf8').split('\n').find(l => l.startsWith('GATEWAY_API_KEY='))
      if (m) gwKey = m.slice(m.indexOf('=')+1).replace(/^["']|["']$/g,'')
    }
    await fetch(`${baseUrl}/api/mark-dims`, {
      method:'POST',
      headers:{'Content-Type':'application/json', ...(gwKey ? {'Authorization':`Bearer ${gwKey}`} : {})},
      body:JSON.stringify({edge,dims:scores}),
    }).catch(()=>{})
  }
  // `task-composite`, never bare `composite` — the cycle gate carries goal-fit
  // at 0.30 and this number does not. Anything that logs, compares, or ratchets
  // on it is comparing a task score, and the label has to say so.
  const dims = AXES.map(k => `${k}=${scores[k].toFixed(2)}`).join(' ')
  process.stdout.write(
    `[w4-rubric] task-composite=${comp.toFixed(2)} ${dims} gate=${gate} ${comp>=gate?'PASS':'FAIL'}`
    + ` (task rubric — no goal-fit; NOT the in-cycle W4 verdict)\n`)
  process.exit(comp >= gate ? 0 : 1)
}

main()
