#!/usr/bin/env node
// speed-check.mjs — the Lighthouse ratchet. "We should always be getting faster."
//
// WHY IT EXISTS: this repo HAD Lighthouse gates and they went dark. The runners
// (one.ie/web/scripts/lighthouse-{dashboard,in}.sh), the thresholds, the vitest
// tests and the npm dep all still exist — but both tests are
// `describe.skipIf(process.env.LIGHTHOUSE !== '1')` and LIGHTHOUSE=1 is set
// NOWHERE: not in package.json, not in either .github workflow, not in
// deploy.sh. So they skipped silently on every run for months and reported
// green — nobody could have told you whether the site got slower.
//
// That is the same failure as a cron whose expression is absent from
// wrangler.toml — registered in code, dark in practice. The fix is not "run
// Lighthouse", it is "make an unrun check impossible to mistake for a pass".
// Hence exit 2, everywhere, for anything that is not a real measurement.
//
// RATCHET DIRECTION (the actual ask): scores may not FALL, timings may not
// RISE. `--update` only ever moves a baseline in the improving direction; it
// will refuse to record a regression. A baseline you can rewrite on demand is
// fail-open, which is how the last one died.
//
// WHAT WE GATE ON, AND WHY (measured 2026-08-18, do not undo without redoing
// the measurement): the enforced ratchet runs against the PRODUCTION BUILD
// SERVED LOCALLY, not against https://one.ie.
//
//   same page, 4-5 consecutive runs, identical code:
//     prod over the internet ....... perf 62 · 64 · 91 · 94   (spread 32)
//     localhost, prod build ........ perf 90 · 93 · 97 · 99 · 99 (spread 9)
//
// Remote measurement from a laptop is dominated by network and CDN jitter, in
// BOTH throttling modes — `simulate` still measures the real server response
// and only synthesises the transfer on top. A 32-point spread cannot ratchet
// anything: it is red on noise every other run, which is how the previous gate
// earned its reputation and got switched off. Localhost isolates the variable
// we can actually control and act on: our own code and bundle.
//
//   (default)  localhost prod build — ENFORCED. Committed baseline
//              text/perf-baseline.json. Same code -> comparable everywhere.
//   --prod     https://one.ie — ADVISORY ONLY, never gates. Answers a
//              different question (is the live site fast for users right now),
//              which needs RUM or many samples over time, not one CI run.
//
// TOLERANCE: Lighthouse varies run to run on identical code even locally
// (90-99 above). Without a band this goes red on noise inside a week and
// someone disables it — exactly how it died before. Each route takes the BEST
// of N runs (default 3) and then still allows a small band. Best-of-N is the
// honest estimator: noise only ever makes a page look slower, never faster, so
// the best sample is the closest reading of what the code actually does.
//
// USAGE
//   speed-check.mjs                    ENFORCED gate (localhost prod build)
//   speed-check.mjs --prod             advisory reading of the live site
//   speed-check.mjs --update           record improvements (refuses regressions)
//   speed-check.mjs --update --force   overwrite baseline regardless (rare;
//                                      e.g. a deliberate feature that costs perf)
//   speed-check.mjs --route /chat      just one route
//   speed-check.mjs --host mover.chat  just the tenant row(s) for that host
//   speed-check.mjs --runs 5           more samples per route
//   speed-check.mjs --check-gate       SELF-TEST: prove the lighthouse gate can go red
//   speed-check.mjs --check-tenant-gate  SELF-TEST: prove the tenant preamble gate
//                                      (auth/det/ttfb via Server-Timing) can go red
//
// EXIT  0 pass (nothing regressed) · 1 REGRESSION · 2 INCONCLUSIVE (could not
//       measure — never treat as green; callers must not map 2 to "skip")
//
// TWO MEASUREMENT KINDS, ONE GATE (added for the tenant-preamble gap — see
// text/speed-plan.md): a route's `kind` decides HOW it is measured, but the
// same METRICS table, regressed()/improved() logic, baseline shape and
// --update/--check flow apply to both, so this stays one mechanism, not two.
//
//   kind: 'lighthouse' (default)  a full-page Lighthouse audit (perf/a11y/…).
//   kind: 'timing'                a direct HTTP request (curl) reading the
//        `Server-Timing` response header perf.ts/perf-middleware.ts already
//        emit on every request. WHY NOT LIGHTHOUSE HERE: Lighthouse drives
//        real Chrome navigation, and Chrome does not let a page override the
//        `Host` header the way `mainMiddleware` needs to pick a tenant branch
//        (host.startsWith('localhost') short-circuits to the PRIMARY branch —
//        `src/middleware.ts` reads `ctx.request.headers.get('host')`, and every
//        localhost/127.0.0.1 request IS that branch by definition, so Lighthouse
//        against localhost:4331 can never reach the tenant preamble at all).
//        A raw HTTP request has no such restriction — `curl -H "Host:
//        mover.chat" http://localhost:4331/` makes middleware take the
//        custom-domain branch while the socket still points at the local
//        build, exactly like the curl-based measurements already cited in
//        perf-middleware.ts's header comment. `--prod` measures the same kind
//        by hitting the tenant's real host directly (no Host override needed).

import { execFileSync, spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const RUNNER = join(REPO, '.claude', 'scripts', 'lighthouse-run.sh');

const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const val = (f, d) => { const i = argv.indexOf(f); return i >= 0 && argv[i + 1] ? argv[i + 1] : d; };

const PROD = has('--prod');       // advisory reading of the live site
const LOCAL = !PROD;              // default: the enforced localhost ratchet
const UPDATE = has('--update');
const FORCE = has('--force');
const CHECK_GATE = has('--check-gate');
const CHECK_TENANT_GATE = has('--check-tenant-gate');
const CHECK_TTFT_GATE = has('--check-ttft-gate');
const RUNS = Math.max(1, Number(val('--runs', '3')) || 3);
const ONLY = val('--route', null);
const ONLY_HOST = val('--host', null);

// The committed baseline is the LOCAL one — it is the one that means the same
// thing on every machine, because every machine builds the same code.
// SPEED_BASELINE_FILE lets a self-test point at a throwaway file instead of
// the committed one — --check-tenant-gate uses it so proving the gate can go
// red never touches text/perf-baseline.json.
const BASELINE = process.env.SPEED_BASELINE_FILE || (LOCAL
  ? join(REPO, 'text', 'perf-baseline.json')
  : join(REPO, 'text', 'perf-baseline.prod.json'));

// --- the route matrix -------------------------------------------------------
// Deliberately small. Every route here must render WITHOUT a session: a
// signed-out /u/<slug>/* 302s to /signin and Lighthouse will happily score the
// LOGIN PAGE at 99 and call it green (this repo's own do-prove landing rule
// exists because that exact bug scored routes as passing for months). Authed
// routes need the dev-session work do-prove.sh already does — until that is
// wired here, they stay out rather than ratchet a lie.
//
// `where` scopes a route to a mode. MOBILE IS PROD-ONLY, and that is a
// measured limitation, not laziness: mobile emulation (4x CPU throttle) against
// the local wrangler server returns runtimeError NO_FCP on every attempt, in
// both throttling methods, while the SAME mobile run against https://one.ie
// scores 65 and the SAME localhost server scores 98 on desktop. The server
// serves byte-identical HTML to both user agents, so this is a Lighthouse
// emulation/localhost interaction, not a bug in the page. Rather than ratchet a
// number we cannot reproduce, mobile lives in the advisory prod run — where it
// is also the weakest surface we have and most worth watching.
// Tenant `kind: 'timing'` rows (below) measure the preamble Server-Timing
// already emits — no `mode` (no Chrome involved), and `host` names the Host
// header to send (LOCAL) or the real host to hit directly (--prod). Measured
// 2026-08-19 prod, the reason these rows exist:
//   one.ie/          auth 0.0ms      det 0.0ms     TTFB 0.32-0.43s
//   app.one.ie/      auth 243-492ms  det 1.9-2.5s  TTFB 2.9-5.3s
//   mover.chat/      auth 224-655ms  det 1.9-3.0s  TTFB 3.2-4.2s
const ROUTES = [
  { path: '/',     mode: 'desktop', where: 'both', kind: 'lighthouse', why: 'homepage — the public speed claim' },
  { path: '/chat', mode: 'desktop', where: 'both', kind: 'lighthouse', why: 'the TTFT showcase surface' },
  { path: '/',     mode: 'mobile',  where: 'prod', kind: 'lighthouse', why: 'homepage on mobile — the weakest surface' },
  { path: '/', where: 'both', kind: 'timing', host: 'mover.chat',
    why: 'tenant preamble (custom-domain rewrite) — a request must not re-derive what a publish already knew' },
  { path: '/', where: 'both', kind: 'timing', host: 'app.one.ie',
    why: 'tenant preamble (app-kind domain, subdomain branch) — same gate for the other tenant shape' },
  // C2 (speed round 2): a real chat TURN, not the /chat page paint. `dd` (the
  // start frame's data+dispatch phases — channels' own trace, all `det`, all
  // BEFORE the model is called) is the gated metric; `ttfb` (total wall time
  // to the SSE start) is recorded but `advisory` because it is hostage to
  // model latency and flaps 3.1-7.4s on identical code — gating it would
  // repeat the exact Lighthouse-spread failure this file's band table exists
  // to prevent. See measureTurn() below for why `dd` alone is trustworthy.
  { path: '/api/chat', where: 'both', kind: 'turn', advisory: ['ttfb'],
    why: 'a chat TURN\'s deterministic prefix (data+dispatch) — the real TTFT showcase, replacing the page-paint proxy' },
];

// Port 4331, not 4321: 4321 is `astro dev` (unoptimised, and often already
// running someone else's worktree). The ratchet must measure the BUILT output.
//   cd one.ie/web && bun run build \
//     && npx wrangler dev --config dist/server/wrangler.json --port 4331 --local
const PROD_ORIGIN  = process.env.SPEED_ORIGIN || 'https://one.ie';
const LOCAL_ORIGIN = process.env.SPEED_ORIGIN || 'http://localhost:4331';
const ORIGIN = LOCAL ? LOCAL_ORIGIN : PROD_ORIGIN;

// Higher-is-better vs lower-is-better, and the noise band each gets.
// Bands are generous on timing (network jitter dominates) and tight on scores.
const METRICS = {
  perf:  { dir: 'up',   band: 3,    label: 'performance' },
  a11y:  { dir: 'up',   band: 0,    label: 'accessibility' },
  bp:    { dir: 'up',   band: 3,    label: 'best-practices' },
  seo:   { dir: 'up',   band: 0,    label: 'seo' },
  lcp:   { dir: 'down', band: 0.40, label: 'LCP', pct: true },
  tbt:   { dir: 'down', band: 0.50, label: 'TBT', pct: true, floor: 50 },
  cls:   { dir: 'down', band: 0.02, label: 'CLS' },
  bytes: { dir: 'down', band: 0.10, label: 'page bytes', pct: true },
  // `timing`-kind rows only. Bands are wide (50%) because Server-Timing on a
  // cold isolate swings hard on D1/KV cold-start — the same reason the
  // lighthouse bands above are generous on ms and tight on scores. `floor`
  // absorbs a near-zero baseline the same way `tbt`'s does (a homepage row
  // with auth=0 would otherwise regress on any nonzero reading at all).
  auth:  { dir: 'down', band: 0.50, label: 'auth phase', pct: true, floor: 20 },
  det:   { dir: 'down', band: 0.50, label: 'det total',  pct: true, floor: 50 },
  ttfb:  { dir: 'down', band: 0.40, label: 'TTFB',       pct: true, floor: 100 },
  // `turn`-kind rows only (C2). Same 50%+floor shape as `det` above — a real
  // chat turn's pre-model window swings on cold KV/Composio/D1 reads the same
  // way the tenant preamble does (measured 567-890ms same code, same host).
  dd:    { dir: 'down', band: 0.50, label: 'chat det (data+dispatch)', pct: true, floor: 50 },
};

const key = (r) => `${r.path}::${r.mode ?? 'timing'}${r.host ? '::' + r.host : ''}`;
const routeLabel = (r) => `${r.path} (${r.host ?? r.mode ?? r.kind})`;
const c = { red: '\x1b[31m', grn: '\x1b[32m', yel: '\x1b[33m', dim: '\x1b[2m', off: '\x1b[0m' };

function parseLine(line) {
  const out = {};
  for (const tok of line.trim().split(/\s+/)) {
    const [k, v] = tok.split('=');
    if (k && v !== undefined) out[k] = Number(v);
  }
  return Number.isFinite(out.perf) ? out : null;
}

// One measurement = best-of-RUNS. Noise makes a page look slower, never faster,
// so the max score / min timing is the closest thing to the true value.
function measure(url, mode) {
  const samples = [];
  for (let i = 0; i < RUNS; i++) {
    let stdout;
    try {
      stdout = execFileSync('bash', [RUNNER, url, mode], {
        encoding: 'utf8', timeout: 180_000, stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (e) {
      // exit 2 from the runner = inconclusive; a single bad sample is ok if
      // others land, so keep going and decide after the loop.
      if (e.stderr) process.stderr.write(c.dim + String(e.stderr).trim() + c.off + '\n');
      continue;
    }
    const p = parseLine(stdout);
    if (p) samples.push(p);
  }
  if (!samples.length) return null;
  const best = {};
  for (const [m, spec] of Object.entries(METRICS)) {
    const vals = samples.map((s) => s[m]).filter((v) => Number.isFinite(v) && v >= 0);
    if (!vals.length) continue;
    best[m] = spec.dir === 'up' ? Math.max(...vals) : Math.min(...vals);
  }
  best._samples = samples.length;
  return best;
}

// Where a `timing`-kind route's request goes: LOCAL spoofs the Host header
// against the built server on :4331 (the only way to reach a non-primary
// middleware branch without owning DNS for the tenant host); --prod hits the
// tenant's real host directly, no override needed.
function timingTarget(r) {
  if (LOCAL) return { url: LOCAL_ORIGIN.replace(/\/$/, '') + r.path, hostHeader: r.host };
  return { url: `https://${r.host}${r.path}`, hostHeader: null };
}

// `Server-Timing: auth;dur=4.0;desc="det", det;dur=120.3;desc="deterministic total", …`
// -> { auth: 4, det: 120.3, … }. One regex per comma-separated token; anything
// that doesn't match `name;dur=N` is ignored rather than throwing — a header
// this parser can't fully read should degrade, not crash the whole route.
function parseServerTiming(headerLine) {
  const out = {};
  for (const part of headerLine.split(',')) {
    const m = part.trim().match(/^([A-Za-z0-9_-]+);dur=([\d.]+)/);
    if (m) out[m[1]] = Number(m[2]);
  }
  return out;
}

// One measurement = best-of-RUNS over a raw HTTP request, reading the
// `Server-Timing` header perf-middleware.ts already attaches to every
// response (see perf.ts). No Chrome, no Lighthouse — this is the mechanism
// that CAN see a spoofed Host header, which is the whole reason it exists.
function measureTiming(r) {
  const { url, hostHeader } = timingTarget(r);
  const samples = [];
  for (let i = 0; i < RUNS; i++) {
    const args = ['-s', '-D', '-', '-o', '/dev/null', '--max-time', '15', '-L'];
    if (hostHeader) args.push('-H', `Host: ${hostHeader}`);
    args.push('-w', '\nTTFB_S=%{time_starttransfer}\n', url);
    let stdout;
    try {
      stdout = execFileSync('curl', args, { encoding: 'utf8', timeout: 20_000 });
    } catch (e) {
      if (e.stderr) process.stderr.write(c.dim + String(e.stderr).trim() + c.off + '\n');
      continue;
    }
    const lines = stdout.split('\n');
    const stLine = lines.find((l) => /^server-timing:/i.test(l));
    const ttfbLine = lines.find((l) => l.startsWith('TTFB_S='));
    if (!stLine) continue;
    const parsed = parseServerTiming(stLine.replace(/^server-timing:\s*/i, ''));
    if (ttfbLine) {
      const s = Number(ttfbLine.slice('TTFB_S='.length));
      if (Number.isFinite(s)) parsed.ttfb = s * 1000;
    }
    if (Number.isFinite(parsed.det)) samples.push(parsed);
  }
  if (!samples.length) return null;
  const best = {};
  for (const m of ['auth', 'det', 'ttfb']) {
    const vals = samples.map((s) => s[m]).filter((v) => Number.isFinite(v) && v >= 0);
    if (vals.length) best[m] = Math.min(...vals); // lower-is-better: noise only ever adds latency
  }
  best._samples = samples.length;
  return best;
}

// A unique, non-cached probe text — never one of chat.ts's STARTER_PROMPTS.
// A starter prompt hits chat.ts's KV edge-cache short-circuit (T3-P11) and
// replays a PAST turn's cached SSE body verbatim, including its stale `start`
// frame — that would measure whatever the cache held, not a live turn.
const TURN_PROBE_TEXT = 'speed-check ttft probe — do not cache this turn';

// One measurement = best-of-RUNS over a REAL POST to /api/chat, reading the
// `start` frame's `messageMetadata.phases` (channels' own trace — see
// channels/src/lifecycle.ts PHASE_OF/tracePhases/visibleTrace). `dd` sums the
// `data`+`dispatch` phases, all `kind:'det'`, all emitted BEFORE the model is
// ever called — that is our half. `ttfb` is the total wall time to the first
// SSE byte, recorded for visibility but never compared (see `advisory` on the
// ROUTES entry) because it also carries the model's own latency.
function measureTurn(r) {
  const url = ORIGIN.replace(/\/$/, '') + r.path;
  const samples = [];
  for (let i = 0; i < RUNS; i++) {
    const body = JSON.stringify({
      messages: [{ id: `speed-check-${Date.now()}-${i}`, role: 'user', parts: [{ type: 'text', text: TURN_PROBE_TEXT }] }],
    });
    const args = [
      '-s', '-o', '-', '--max-time', '30', '-X', 'POST',
      '-H', 'Content-Type: application/json',
      '-H', `Referer: ${ORIGIN}/chat`,
      '-d', body,
      '-w', '\n__TTFB_S__=%{time_starttransfer}\n',
      url,
    ];
    let stdout;
    try {
      stdout = execFileSync('curl', args, { encoding: 'utf8', timeout: 35_000 });
    } catch (e) {
      if (e.stderr) process.stderr.write(c.dim + String(e.stderr).trim() + c.off + '\n');
      continue;
    }
    const lines = stdout.split('\n');
    const ttfbLine = lines.find((l) => l.startsWith('__TTFB_S__='));
    const startLine = lines.find((l) => l.startsWith('data: ') && l.includes('"type":"start"'));
    if (!startLine) continue;
    let phases;
    try {
      phases = JSON.parse(startLine.slice('data: '.length)).messageMetadata?.phases;
    } catch {
      continue;
    }
    if (!Array.isArray(phases)) continue;
    const dataMs = phases.find((p) => p.name === 'data')?.ms ?? 0;
    const dispatchMs = phases.find((p) => p.name === 'dispatch')?.ms ?? 0;
    const sample = { dd: dataMs + dispatchMs };
    if (ttfbLine) {
      const s = Number(ttfbLine.slice('__TTFB_S__='.length));
      if (Number.isFinite(s)) sample.ttfb = s * 1000;
    }
    samples.push(sample);
  }
  if (!samples.length) return null;
  const best = {};
  for (const m of ['dd', 'ttfb']) {
    const vals = samples.map((s) => s[m]).filter((v) => Number.isFinite(v) && v >= 0);
    if (vals.length) best[m] = Math.min(...vals); // lower-is-better: noise only ever adds latency
  }
  best._samples = samples.length;
  return best;
}

// Is `now` worse than `base` beyond the noise band?
function regressed(metric, base, now) {
  const s = METRICS[metric];
  if (!s || !Number.isFinite(base) || !Number.isFinite(now)) return false;
  if (s.dir === 'up') return now < base - s.band;
  // lower-is-better
  const allowed = s.pct ? base * (1 + s.band) + (s.floor ?? 0) : base + s.band;
  return now > allowed;
}
function improved(metric, base, now) {
  const s = METRICS[metric];
  if (!s || !Number.isFinite(base) || !Number.isFinite(now)) return false;
  return s.dir === 'up' ? now > base : now < base;
}

// --- self-test: prove the gate can go red -----------------------------------
// A checker that has never been observed failing is not evidence of anything.
if (CHECK_GATE) {
  let bad = 0;
  const t = (name, got, want) => {
    const ok = got === want;
    console.log(`  ${ok ? c.grn + 'ok  ' : c.red + 'FAIL'}${c.off} ${name} ${c.dim}(got ${got}, want ${want})${c.off}`);
    if (!ok) bad++;
  };
  console.log('speed-check --check-gate — proving the ratchet bites\n');
  t('perf 92 -> 80 is a regression',      regressed('perf', 92, 80), true);
  t('perf 92 -> 90 is inside the band',   regressed('perf', 92, 90), false);
  t('perf 92 -> 88 breaks the band',      regressed('perf', 92, 88), true);
  t('a11y 100 -> 99 regresses (band 0)',  regressed('a11y', 100, 99), true);
  t('LCP 1000 -> 2000 is a regression',   regressed('lcp', 1000, 2000), true);
  t('LCP 1000 -> 1200 inside 40% band',   regressed('lcp', 1000, 1200), false);
  t('TBT 0 -> 40 inside floor',           regressed('tbt', 0, 40), false);
  t('TBT 0 -> 500 regresses',             regressed('tbt', 0, 500), true);
  t('bytes 100k -> 130k regresses',       regressed('bytes', 100_000, 130_000), true);
  t('CLS 0 -> 0.2 regresses',             regressed('cls', 0, 0.2), true);
  t('perf 56 -> 61 is an improvement',    improved('perf', 56, 61), true);
  t('LCP 6600 -> 3900 is an improvement', improved('lcp', 6600, 3900), true);
  // THE ROT ITSELF, tested for real: a run that can measure nothing must exit
  // 2, never 0. This spawns the actual script against a dead origin — not a
  // tautology about the function's type.
  let unmeasurableExit = null;
  try {
    execFileSync(process.execPath, [fileURLToPath(import.meta.url), '--runs', '1'], {
      env: { ...process.env, SPEED_ORIGIN: 'http://127.0.0.1:1' },
      encoding: 'utf8', timeout: 120_000, stdio: ['ignore', 'pipe', 'pipe'],
    });
    unmeasurableExit = 0;
  } catch (e) {
    unmeasurableExit = e.status ?? -1;
  }
  t('unmeasurable run exits 2, not 0', unmeasurableExit, 2);

  // THE --prod EXIT-CODE ROT ITSELF, tested for real: deploy.sh's Step 9 was
  // observed printing a red "SLOWER" block immediately followed by a green
  // "speed: nothing got slower (live site)" tick, because a --prod regression
  // and a --prod clean run both exited 0. Fixed by exit 3 = "regression
  // detected, advisory, not gated"; exit 0 stays reserved for "measured
  // clean". Proved against a real spawned child hitting a real local Chrome
  // via lighthouse-run.sh — not a stub of the exit-code function — with a
  // synthetic baseline so the outcome is deterministic either way.
  {
    const tmp = mkdtempSync(join(tmpdir(), 'speed-prod-exit-'));
    // The fake page server runs as a SEPARATE CHILD PROCESS, not an in-process
    // http.createServer() — same reason the other self-tests' fake servers do
    // below: this self-test's own measurement calls are execFileSync, which
    // blocks this process's event loop for the whole subprocess run, so an
    // in-process server cannot accept a connection while this thread waits.
    //
    // lighthouse-run.sh also treats a page under 100000 total-byte-weight as a
    // partial load ("INCONCLUSIVE: partial load") rather than a real
    // measurement — pad the body well past that floor so the runner scores a
    // real page instead of bailing before it ever reaches the exit-code
    // branch this test exists to prove.
    const serverScript = join(tmp, 'fake-page-server.mjs');
    writeFileSync(serverScript, [
      "import { createServer } from 'node:http';",
      "const pad = '<!-- pad -->'.repeat(10000);",
      'const server = createServer((_req, res) => {',
      "  res.setHeader('content-type', 'text/html');",
      "  res.end('<!doctype html><html><head><title>t</title>' +",
      "    '<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head>' +",
      "    `<body><h1>speed-check self-test page</h1>${pad}</body></html>`);",
      '});',
      "server.listen(0, '127.0.0.1', () => console.log(`PORT=${server.address().port}`));",
    ].join('\n'));

    const startServer = () => new Promise((resolve, reject) => {
      const proc = spawn(process.execPath, [serverScript], { stdio: ['ignore', 'pipe', 'pipe'] });
      let buf = '';
      const timer = setTimeout(
        () => reject(new Error('fake page server did not report a port in time')), 5000,
      );
      proc.stdout.on('data', (d) => {
        buf += d.toString();
        const m = buf.match(/PORT=(\d+)/);
        if (m) { clearTimeout(timer); resolve({ proc, port: Number(m[1]) }); }
      });
      proc.once('error', (e) => { clearTimeout(timer); reject(e); });
    });

    let server = null;
    try {
      server = await startServer();
      const origin = `http://127.0.0.1:${server.port}`;

      // Baseline the /chat::desktop route cannot possibly meet: lcp=1ms is
      // guaranteed to regress (dir:'down', 40% band) no matter how fast the
      // synthetic page loads, so the regression branch is deterministic.
      const regressedBaseline = join(tmp, 'regressed-baseline.json');
      writeFileSync(regressedBaseline, JSON.stringify({
        routes: { '/chat::desktop': { perf: 100, a11y: 100, bp: 100, seo: 100, lcp: 1, tbt: 1, cls: 0, bytes: 1 } },
      }));
      let prodRegressExit = null;
      try {
        execFileSync(process.execPath, [
          fileURLToPath(import.meta.url), '--prod', '--runs', '1', '--route', '/chat',
        ], {
          env: { ...process.env, SPEED_ORIGIN: origin, SPEED_BASELINE_FILE: regressedBaseline },
          encoding: 'utf8', timeout: 180_000, stdio: ['ignore', 'pipe', 'pipe'],
        });
        prodRegressExit = 0;
      } catch (e) {
        prodRegressExit = e.status ?? -1;
      }
      t('--prod run with a forced regression exits 3, not 0', prodRegressExit, 3);

      // Baseline no real measurement can beat downward (huge timings) and
      // cannot regress upward from (zero scores) — the clean-run control.
      const cleanBaseline = join(tmp, 'clean-baseline.json');
      writeFileSync(cleanBaseline, JSON.stringify({
        routes: { '/chat::desktop': { perf: 0, a11y: 0, bp: 0, seo: 0, lcp: 1e9, tbt: 1e9, cls: 1e9, bytes: 1e9 } },
      }));
      let prodCleanExit = null;
      try {
        execFileSync(process.execPath, [
          fileURLToPath(import.meta.url), '--prod', '--runs', '1', '--route', '/chat',
        ], {
          env: { ...process.env, SPEED_ORIGIN: origin, SPEED_BASELINE_FILE: cleanBaseline },
          encoding: 'utf8', timeout: 180_000, stdio: ['ignore', 'pipe', 'pipe'],
        });
        prodCleanExit = 0;
      } catch (e) {
        prodCleanExit = e.status ?? -1;
      }
      t('--prod run with nothing to regress against exits 0', prodCleanExit, 0);
    } finally {
      if (server?.proc) server.proc.kill();
      rmSync(tmp, { recursive: true, force: true });
    }
  }

  console.log(bad === 0
    ? `\n${c.grn}gate proven: it fails on regressions and passes on improvements${c.off}`
    : `\n${c.red}${bad} self-test(s) FAILED — the gate is not trustworthy${c.off}`);
  process.exit(bad === 0 ? 0 : 1);
}

// --- self-test: prove the TENANT preamble gate can go red -------------------
// Same idea as --check-gate, but for `kind: 'timing'` rows: a synthetic HTTP
// server stands in for the tenant host so this proves the real round trip
// (curl -> Server-Timing header -> parseServerTiming -> regressed() -> exit
// code) without needing a live wrangler build on :4331.
if (CHECK_TENANT_GATE) {
  let bad = 0;
  const t = (name, got, want) => {
    const ok = got === want;
    console.log(`  ${ok ? c.grn + 'ok  ' : c.red + 'FAIL'}${c.off} ${name} ${c.dim}(got ${got}, want ${want})${c.off}`);
    if (!ok) bad++;
  };
  console.log('speed-check --check-tenant-gate — proving the tenant preamble gate bites\n');

  // Pure regressed()/improved() coverage for the three new metrics.
  t('auth 50 -> 500 is a regression (10x, past 50% band+floor)', regressed('auth', 50, 500), true);
  t('auth 50 -> 60 is inside the band',                          regressed('auth', 50, 60), false);
  t('det 200 -> 2000 is a regression',                           regressed('det', 200, 2000), true);
  t('det 200 -> 280 is inside the band',                         regressed('det', 200, 280), false);
  t('ttfb 400 -> 4000 is a regression',                          regressed('ttfb', 400, 4000), true);
  t('auth 0 -> 15 stays inside the floor',                       regressed('auth', 0, 15), false);
  t('det 2000 -> 200 is an improvement',                         improved('det', 2000, 200), true);

  // parseServerTiming reads the real header shape perf.ts (Timer.header())
  // emits: raw phase marks plus the `det`/`llm`/`chain` roll-ups.
  const parsed = parseServerTiming(
    'auth;dur=243.5;desc="det", data;dur=1900.2;desc="det", ' +
    'det;dur=2143.7;desc="deterministic total", render;dur=12.0;desc="det"',
  );
  t('parseServerTiming reads the auth phase', parsed.auth, 243.5);
  t('parseServerTiming reads the det roll-up', parsed.det, 2143.7);

  // THE ROT ITSELF, tested for real: a synthetic tenant server, measured
  // through the actual CLI (spawned as a child, exactly like --check-gate's
  // unmeasurable-run test), must PASS when timings match the baseline and
  // REGRESS when they blow past it. Asserted on the full curl -> parse ->
  // compare -> exit-code path, never on a function in isolation.
  let passExit = null;
  let regressExit = null;
  // The fake tenant server runs as a SEPARATE CHILD PROCESS, not an in-process
  // http.createServer(). This self-test's own measurement calls are
  // execFileSync — synchronous, so they block this process's event loop for
  // their whole duration. An in-process server can't accept a connection
  // while its own thread is blocked waiting on that subprocess (verified:
  // curl against an in-process server hung to its --max-time ceiling on every
  // attempt, 0 bytes received, until it was moved out of process).
  const tmp = mkdtempSync(join(tmpdir(), 'speed-tenant-gate-'));
  const baselineFile = join(tmp, 'baseline.json');
  const serverScript = join(tmp, 'fake-tenant-server.mjs');
  let child = null;
  try {
    writeFileSync(serverScript, [
      "import { createServer } from 'node:http';",
      'const [authMs, detMs] = process.argv.slice(2).map(Number);',
      'const server = createServer((_req, res) => {',
      '  res.setHeader(',
      "    'Server-Timing',",
      "    `auth;dur=${authMs};desc=\"det\", det;dur=${detMs};desc=\"deterministic total\"`,",
      '  );',
      "  res.end('ok');",
      '});',
      "server.listen(0, '127.0.0.1', () => console.log(`PORT=${server.address().port}`));",
    ].join('\n'));

    const startServer = (authMs, detMs) => new Promise((resolve, reject) => {
      const proc = spawn(process.execPath, [serverScript, String(authMs), String(detMs)], {
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      let buf = '';
      const timer = setTimeout(
        () => reject(new Error('fake tenant server did not report a port in time')), 5000,
      );
      const onData = (d) => {
        buf += d.toString();
        const m = buf.match(/PORT=(\d+)/);
        if (m) { clearTimeout(timer); proc.stdout.off('data', onData); resolve({ proc, port: Number(m[1]) }); }
      };
      proc.stdout.on('data', onData);
      proc.once('error', reject);
    });

    const runOnce = (port) => {
      try {
        execFileSync(process.execPath, [
          fileURLToPath(import.meta.url), '--route', '/', '--host', 'mover.chat', '--runs', '1',
        ], {
          env: { ...process.env, SPEED_ORIGIN: `http://127.0.0.1:${port}`, SPEED_BASELINE_FILE: baselineFile },
          encoding: 'utf8', timeout: 60_000, stdio: ['ignore', 'pipe', 'pipe'],
        });
        return 0;
      } catch (e) {
        return e.status ?? -1;
      }
    };

    // Baseline written ONCE, at 50/200, and never rewritten — the whole test
    // is whether a measurement against that fixed baseline passes or fails.
    writeFileSync(baselineFile, JSON.stringify({
      _mode: 'local-build', _origin: 'http://127.0.0.1:0',
      routes: {
        '/::timing::mover.chat': { auth: 50, det: 200, _measured: 'test', _why: 'check-tenant-gate self-test' },
      },
    }));

    const passServer = await startServer(50, 200);
    child = passServer.proc;
    passExit = runOnce(passServer.port);
    child.kill();

    // 10x — well past the 50% band + floor on both auth and det.
    const regressServer = await startServer(500, 2000);
    child = regressServer.proc;
    regressExit = runOnce(regressServer.port); // same baseline file, server now answers 10x slower
    child.kill();
    child = null;
  } finally {
    if (child) child.kill();
    rmSync(tmp, { recursive: true, force: true });
  }
  t('matching timings pass (exit 0)',        passExit, 0);
  t('10x-inflated timings regress (exit 1)', regressExit, 1);

  console.log(bad === 0
    ? `\n${c.grn}tenant gate proven: it fails on a preamble regression and passes on matching timings${c.off}`
    : `\n${c.red}${bad} self-test(s) FAILED — the tenant gate is not trustworthy${c.off}`);
  process.exit(bad === 0 ? 0 : 1);
}

// --- self-test: prove the chat TURN (TTFT) gate can go red ------------------
// Same idea as --check-tenant-gate, but for the `turn`-kind row: a synthetic
// HTTP server stands in for /api/chat and answers a POST with a real SSE
// `start` frame carrying a chosen `data`+`dispatch` value, so this proves the
// real path (curl POST -> parse SSE -> measureTurn -> regressed() -> exit
// code) without ever hitting the live model or spending a real credit.
if (CHECK_TTFT_GATE) {
  let bad = 0;
  const t = (name, got, want) => {
    const ok = got === want;
    console.log(`  ${ok ? c.grn + 'ok  ' : c.red + 'FAIL'}${c.off} ${name} ${c.dim}(got ${got}, want ${want})${c.off}`);
    if (!ok) bad++;
  };
  console.log('speed-check --check-ttft-gate — proving the chat-turn gate bites\n');

  // Pure regressed()/improved() coverage for the new `dd` metric.
  t('dd 100 -> 1000 is a regression (10x, past 50% band+floor)', regressed('dd', 100, 1000), true);
  t('dd 100 -> 130 is inside the band',                          regressed('dd', 100, 130), false);
  t('dd 1000 -> 100 is an improvement',                          improved('dd', 1000, 100), true);

  let child = null;
  let passExit = null;
  let regressExit = null;
  const tmp = mkdtempSync(join(tmpdir(), 'speed-ttft-gate-'));
  const baselineFile = join(tmp, 'baseline.json');
  const serverScript = join(tmp, 'fake-chat-server.mjs');
  try {
    writeFileSync(serverScript, [
      "import { createServer } from 'node:http';",
      'const [ddMs] = process.argv.slice(2).map(Number);',
      'const server = createServer((_req, res) => {',
      "  res.setHeader('Content-Type', 'text/event-stream');",
      '  const frame = { type: "start", messageMetadata: { phases: [',
      '    { name: "data", kind: "det", ms: ddMs }, { name: "dispatch", kind: "det", ms: 0 },',
      '  ] } };',
      "  res.end('data: ' + JSON.stringify(frame) + '\\n\\n');",
      '});',
      "server.listen(0, '127.0.0.1', () => console.log(`PORT=${server.address().port}`));",
    ].join('\n'));

    const startServer = (ddMs) => new Promise((resolve, reject) => {
      const proc = spawn(process.execPath, [serverScript, String(ddMs)], {
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      let buf = '';
      const timer = setTimeout(
        () => reject(new Error('fake chat server did not report a port in time')), 5000,
      );
      const onData = (d) => {
        buf += d.toString();
        const m = buf.match(/PORT=(\d+)/);
        if (m) { clearTimeout(timer); proc.stdout.off('data', onData); resolve({ proc, port: Number(m[1]) }); }
      };
      proc.stdout.on('data', onData);
      proc.once('error', reject);
    });

    const runOnce = (port) => {
      try {
        execFileSync(process.execPath, [
          fileURLToPath(import.meta.url), '--route', '/api/chat', '--runs', '1',
        ], {
          env: { ...process.env, SPEED_ORIGIN: `http://127.0.0.1:${port}`, SPEED_BASELINE_FILE: baselineFile },
          encoding: 'utf8', timeout: 60_000, stdio: ['ignore', 'pipe', 'pipe'],
        });
        return 0;
      } catch (e) {
        return e.status ?? -1;
      }
    };

    // Baseline written ONCE, at dd=100, ttfb omitted (advisory-only — it must
    // never gate even if a base value existed).
    writeFileSync(baselineFile, JSON.stringify({
      _mode: 'local-build', _origin: 'http://127.0.0.1:0',
      routes: {
        '/api/chat::timing': { dd: 100, _measured: 'test', _why: 'check-ttft-gate self-test' },
      },
    }));

    const passServer = await startServer(100);
    child = passServer.proc;
    passExit = runOnce(passServer.port);
    child.kill();

    // 10x on `dd` — well past the 50% band + floor.
    const regressServer = await startServer(1000);
    child = regressServer.proc;
    regressExit = runOnce(regressServer.port); // same baseline file, server now answers 10x slower
    child.kill();
    child = null;
  } finally {
    if (child) child.kill();
    rmSync(tmp, { recursive: true, force: true });
  }
  t('matching dd passes (exit 0)',    passExit, 0);
  t('10x-inflated dd regresses (exit 1)', regressExit, 1);

  console.log(bad === 0
    ? `\n${c.grn}ttft gate proven: it fails on a dd regression and passes on matching timings; ttfb never gates${c.off}`
    : `\n${c.red}${bad} self-test(s) FAILED — the ttft gate is not trustworthy${c.off}`);
  process.exit(bad === 0 ? 0 : 1);
}

// --- main -------------------------------------------------------------------
const baseline = existsSync(BASELINE)
  ? JSON.parse(readFileSync(BASELINE, 'utf8'))
  : { _mode: LOCAL ? 'local-build' : 'live-site', _origin: ORIGIN, routes: {} };
baseline.routes ??= {};

const applicable = ROUTES.filter((r) => r.where === 'both' || r.where === (LOCAL ? 'local' : 'prod'));
const byPath = ONLY ? applicable.filter((r) => r.path === ONLY) : applicable;
const targets = ONLY_HOST ? byPath.filter((r) => r.host === ONLY_HOST) : byPath;
if (!targets.length) {
  console.error(`no route matching path=${ONLY ?? '*'} host=${ONLY_HOST ?? '*'}. Known: ${ROUTES.map((r) => r.host ? `${r.path}@${r.host}` : r.path).join(', ')}`);
  process.exit(2);
}

console.log(`speed-check ${LOCAL ? '(local build, ENFORCED)' : '(live site, ADVISORY)'} — ${ORIGIN}`);
console.log(`${c.dim}best of ${RUNS} runs per route · baseline ${BASELINE.replace(REPO + '/', '')}${c.off}\n`);

const results = [];
let measuredNone = true;

for (const r of targets) {
  const isTiming = r.kind === 'timing';
  const isTurn = r.kind === 'turn';
  const label = isTiming ? `${r.path} ${c.dim}(${r.host})${c.off}`
    : isTurn ? `${r.path} ${c.dim}(turn)${c.off}`
    : `${r.path} ${c.dim}(${r.mode})${c.off}`;
  process.stdout.write(`${label} … `);
  const now = isTiming ? measureTiming(r) : isTurn ? measureTurn(r) : measure(ORIGIN.replace(/\/$/, '') + r.path, r.mode);
  if (!now) { console.log(`${c.yel}INCONCLUSIVE${c.off}`); results.push({ r, now: null }); continue; }
  measuredNone = false;
  const base = baseline.routes[key(r)];
  console.log(
    isTiming
      ? `auth=${now.auth ?? '-'}ms det=${now.det ?? '-'}ms ttfb=${Number.isFinite(now.ttfb) ? Math.round(now.ttfb) : '-'}ms ${c.dim}(${now._samples}/${RUNS} samples)${c.off}`
      : isTurn
      ? `dd=${now.dd ?? '-'}ms ttfb=${Number.isFinite(now.ttfb) ? Math.round(now.ttfb) : '-'}ms (advisory) ${c.dim}(${now._samples}/${RUNS} samples)${c.off}`
      : `perf=${now.perf} a11y=${now.a11y} lcp=${now.lcp}ms tbt=${now.tbt}ms ` +
        `cls=${now.cls} ${Math.round(now.bytes / 1024)}KB ${c.dim}(${now._samples}/${RUNS} samples)${c.off}`
  );
  results.push({ r, now, base });
}

if (measuredNone) {
  console.error(`\n${c.yel}INCONCLUSIVE — nothing could be measured. This is NOT a pass.${c.off}`);
  console.error(LOCAL
    ? 'Local build server not up. Start it with:\n' +
      '  cd one.ie/web && bun run build && \\\n' +
      '    npx wrangler dev --config dist/server/wrangler.json --port 4331 --local'
    : `Is ${ORIGIN} reachable?`);
  process.exit(2);
}

// --- compare ----------------------------------------------------------------
const regressions = [];
const improvements = [];
for (const { r, now, base } of results) {
  if (!now) continue;
  if (!base) { console.log(`${c.dim}  ${routeLabel(r)}: no baseline yet${c.off}`); continue; }
  for (const m of Object.keys(METRICS)) {
    // C2: a route's `advisory` list names metrics that are recorded but never
    // gated — the chat turn's total `ttfb` is hostage to model latency, and
    // gating it would repeat the exact Lighthouse-spread failure this file's
    // band table exists to prevent (see the ROUTES comment on the turn row).
    if (r.advisory?.includes(m)) continue;
    if (regressed(m, base[m], now[m])) {
      regressions.push({ r, m, from: base[m], to: now[m] });
    } else if (improved(m, base[m], now[m])) {
      improvements.push({ r, m, from: base[m], to: now[m] });
    }
  }
}

if (improvements.length) {
  console.log(`\n${c.grn}faster${c.off}`);
  for (const i of improvements) {
    console.log(`  ${routeLabel(i.r)} ${METRICS[i.m].label}: ${i.from} → ${c.grn}${i.to}${c.off}`);
  }
}
if (regressions.length) {
  console.log(`\n${c.red}SLOWER — beyond the noise band${c.off}`);
  for (const g of regressions) {
    console.log(`  ${routeLabel(g.r)} ${METRICS[g.m].label}: ${g.from} → ${c.red}${g.to}${c.off}`);
  }
}

// --- update -----------------------------------------------------------------
if (UPDATE) {
  if (regressions.length && !FORCE) {
    console.error(
      `\n${c.red}refusing to record a regression.${c.off} The ratchet only moves one way.\n` +
      `If this slowdown is deliberate, re-run with --force and say why in the commit.`
    );
    process.exit(1);
  }
  let written = 0;
  for (const { r, now, base } of results) {
    if (!now) continue;
    const next = { ...(base ?? {}) };
    for (const m of Object.keys(METRICS)) {
      if (!Number.isFinite(now[m])) continue;
      // improve-only, unless forced
      if (base === undefined || FORCE || improved(m, base[m], now[m]) || !Number.isFinite(base[m])) {
        next[m] = now[m];
      }
    }
    next._measured = new Date().toISOString().slice(0, 10);
    next._why = r.why;
    baseline.routes[key(r)] = next;
    written++;
  }
  baseline._mode = LOCAL ? 'local-build' : 'live-site';
  baseline._origin = ORIGIN;
  baseline._runs = RUNS;
  baseline._bands = Object.fromEntries(
    Object.entries(METRICS).map(([m, s]) => [m, s.pct ? `${s.band * 100}%` : s.band])
  );
  writeFileSync(BASELINE, JSON.stringify(baseline, null, 2) + '\n');
  console.log(`\n${c.grn}baseline updated${c.off} — ${written} route(s) → ${BASELINE.replace(REPO + '/', '')}`);
  process.exit(0);
}

// A missing baseline must not read as "pass" — that is fail-open, the same
// class of bug as a skipped test reporting green. Seed it explicitly.
const unbaselined = results.filter((r) => r.now && !r.base);
if (!UPDATE && unbaselined.length && LOCAL) {
  console.error(
    `\n${c.yel}INCONCLUSIVE — ${unbaselined.length} route(s) have no baseline.${c.off}\n` +
    `Nothing to ratchet against, so this is not a pass. Seed it with:\n` +
    `  cd one.ie/web && bun run speed:update`
  );
  process.exit(2);
}

if (regressions.length) {
  if (PROD) {
    console.log(
      `\n${c.yel}advisory only (--prod) — not gating.${c.off} Live-site numbers swing ` +
      `~30 points on network jitter; treat this as a signal to investigate, not a failure.`
    );
    // Exit 3, NOT 0. "I found a regression and am not gating on it" and "nothing
    // got slower" are different statements, and exiting 0 let deploy.sh collapse
    // them into `ok speed: nothing got slower (live site)` — printed directly
    // beneath this script's own SLOWER block, in the same log, twice on
    // 2026-08-26 while / (mobile) went 86 -> 82. A caller cannot be trusted to
    // read prose; the exit code has to carry the distinction.
    process.exit(3);
  }
  console.error(`\n${c.red}FAIL: ${regressions.length} regression(s). We are meant to be getting faster.${c.off}`);
  process.exit(1);
}

console.log(`\n${c.grn}pass — nothing got slower${c.off}`);
process.exit(0);
