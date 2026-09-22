#!/usr/bin/env bun
// govern.ts — the machine-wide concurrency governor, as ONE Bun program.
//
// manifest: portable
//
// WHY THIS EXISTS AS TYPESCRIPT (§ GATES item 5, text/factory-do.md)
// The DESIGN of the governor is proven — slots, bound, claims, the two memo
// keys, four-state gates. The RUNTIME was the recurring defect: bash 3.2 on
// macOS has no flock(1), no timeout(1) and no BASHPID; `set -m` needs job
// control; a watchdog subshell cannot own the sleep it forks; and the
// `find | sort -z | xargs` pipeline plus zsh-vs-bash word splitting produced
// four separate measured bugs on 2026-09-04 alone. Every one of those lives in
// a MECHANISM, not in a decision. So the mechanisms moved here and the
// decisions did not change.
//
// lib/govern.sh is now a thin shim that keeps the shell function NAMES and EXIT
// CODES every caller sources (gate-run.sh, do-fleet.sh, session-start.sh,
// tsc-cached.sh, do-reconcile.sh, machine-check.sh, the hooks …), so no caller
// changed. Two seams deliberately STAY in bash, because three of the six
// governor proofs stub them as bash functions and the acceptance is that those
// proofs are unchanged:
//
//   _gv_alive    (kill -0)   — govern-claims-check.sh R1/R2 stubs it true
//   _gv_vm_stat / _gv_swapusage / _gv_memsize — govern-mem-check.sh drives a
//                              synthetic machine through them
//
// Neither carries any of the runtime defects above (one signal, one exec), so
// leaving them in the shell costs nothing and keeps the red proofs honest. The
// shim pipes their output in: vm_stat text on stdin, liveness as
// GOVERN_ALIVE_PIDS when (and only when) the caller has stubbed it.
//
// Owner pid: the LOCK/CLAIM owner is the CALLING SHELL ($$ passed as
// GOVERN_OWNER_PID), never this short-lived bun process. A lock owned by a
// process that exits the moment it is taken is reaped by the next contender —
// which would silently break governor-doors-check.sh's re-entrancy RED half.

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import { createHash } from "node:crypto";

const E = process.env;

function envInt(name: string, dflt: number): number {
  const v = E[name];
  if (v === undefined || v === "" || !/^[0-9]+$/.test(v)) return dflt;
  return parseInt(v, 10);
}

const GOVERN_DIR = E.GOVERN_DIR || `${E.TMPDIR || "/tmp"}/one-govern`;
const CLAIMS_DIR = E.GOVERN_CLAIMS_DIR || `${GOVERN_DIR}/claims`;
const CLAIM_TTL = envInt("GOVERN_CLAIM_TTL_SECS", 5400);
const MAX_GATES = envInt("GOVERN_MAX_GATES", 2);
// The shell whose LIFETIME a lock/claim tracks. Falls back to our own pid so a
// direct `bun govern.ts …` invocation still behaves, but every shim call sets it.
const OWNER_PID = envInt("GOVERN_OWNER_PID", process.pid);
// claim_take/claim_release key on GOVERN_CLAIM_PID when set (a short-lived
// emitter claiming ground FOR a worker); claim_release_all keys on the plain
// shell pid. That asymmetry exists in the bash original and is preserved
// verbatim — normalising it while porting would change behaviour no proof covers.
const CLAIM_PID = envInt("GOVERN_CLAIM_PID", OWNER_PID);
const SHELL_PID = OWNER_PID;

function log(msg: string) {
  if (E.GOVERN_DEBUG) process.stderr.write(`[govern] ${msg}\n`);
}

// ─── liveness ────────────────────────────────────────────────────────────────
// GOVERN_ALIVE_SET=1 means the CALLER has already decided who is alive (its
// _gv_alive may be stubbed). Otherwise ask the kernel, which is what lets a long
// gate_lock wait notice an owner dying mid-wait.
const ALIVE_SET = E.GOVERN_ALIVE_SET === "1";
const ALIVE_PIDS = new Set(
  (E.GOVERN_ALIVE_PIDS || "").split(",").filter((s) => s !== ""),
);

function alive(pid: string | undefined): boolean {
  if (!pid) return false;
  if (ALIVE_SET) return ALIVE_PIDS.has(pid);
  const n = parseInt(pid, 10);
  if (!Number.isFinite(n) || n <= 0) return false;
  try {
    process.kill(n, 0);
    return true;
  } catch (e: any) {
    // EPERM means it exists and is not ours — `kill -0` reports the same.
    return e && e.code === "EPERM";
  }
}

function rmrf(p: string) {
  try {
    fs.rmSync(p, { recursive: true, force: true });
  } catch {}
}

function readTrim(p: string): string {
  try {
    return fs.readFileSync(p, "utf8").trim();
  } catch {
    return "";
  }
}

function now(): number {
  return Math.floor(Date.now() / 1000);
}

// ─── locks · slots ───────────────────────────────────────────────────────────
// mkdir(2) is the arbiter, exactly as in the bash original: atomic on every
// POSIX fs, so N racers produce exactly one winner and no coordinator exists.

function reapLock(d: string): boolean {
  if (!fs.existsSync(d)) return false;
  const owner = readTrim(`${d}/pid`);
  if (!alive(owner)) {
    log(`reaping stale lock ${d} (owner ${owner} gone)`);
    rmrf(d);
    return true;
  }
  return false;
}

function tryLock(name: string): boolean {
  const d = `${GOVERN_DIR}/lock-${name}`;
  try {
    fs.mkdirSync(d);
    fs.writeFileSync(`${d}/pid`, `${OWNER_PID}\n`);
    log(`acquired ${name}`);
    return true;
  } catch {
    return false;
  }
}

async function sleep(ms: number) {
  await new Promise((r) => setTimeout(r, ms));
}

// One non-blocking attempt, INCLUDING the reap-and-retake a dead owner earns.
// `gate_lock <name> 0` did exactly this in the bash original and gate_slot leans
// on it: a slot whose holder died must be takeable on this pass, not 2s later.
function acquireNoWait(name: string): boolean {
  if (tryLock(name)) return true;
  if (reapLock(`${GOVERN_DIR}/lock-${name}`)) return tryLock(name);
  return false;
}

async function cmdLock(name: string, waitS: number): Promise<number> {
  let waited = 0;
  for (;;) {
    if (tryLock(name)) return 0;
    const d = `${GOVERN_DIR}/lock-${name}`;
    if (reapLock(d)) continue; // dead owner -> retry immediately
    if (waited >= waitS) {
      log(`busy ${name}`);
      return 1;
    }
    await sleep(1000);
    waited += 1;
  }
}

function cmdUnlock(name: string): number {
  const d = `${GOVERN_DIR}/lock-${name}`;
  if (readTrim(`${d}/pid`) === String(OWNER_PID)) rmrf(d);
  return 0;
}

// gate_slot — take one of the effective slots. The effective cap is the SMALLER
// of the configured GOVERN_MAX_GATES and what memory can actually fund. A static
// config must never authorise more than the box can pay for; a broken sensor
// (headroom 99) must never silently serialise the fleet. Floored at 1: work
// slows down, it never stops.
async function cmdSlot(waitS: number): Promise<number> {
  let waited = 0;
  for (;;) {
    let cap = MAX_GATES;
    const head = headroom(readVmStat());
    if (head < cap) cap = head;
    if (cap < 1) cap = 1;
    for (let i = 1; i <= cap; i++) {
      if (acquireNoWait(`slot-${i}`)) {
        process.stdout.write(`slot-${i}\n`);
        return 0;
      }
    }
    if (waited >= waitS) return 1;
    await sleep(2000);
    waited += 2;
  }
}

// gate_sweep_stale — _gv_reap only fires when someone CONTENDS for a lock, so a
// session that died holding a slot would shrink the effective cap until the next
// contender happened along. Run at session start. Echoes the number swept.
function cmdSweepStale(): number {
  let n = 0;
  let ents: string[] = [];
  try {
    ents = fs.readdirSync(GOVERN_DIR);
  } catch {
    process.stdout.write("0\n");
    return 0;
  }
  for (const e of ents) {
    if (!e.startsWith("lock-")) continue;
    const d = `${GOVERN_DIR}/${e}`;
    try {
      if (!fs.statSync(d).isDirectory()) continue;
    } catch {
      continue;
    }
    if (!alive(readTrim(`${d}/pid`))) {
      rmrf(d);
      n++;
    }
  }
  process.stdout.write(`${n}\n`);
  return 0;
}

// ─── run_bounded ─────────────────────────────────────────────────────────────
// A hard wall-clock cap that kills the whole PROCESS GROUP. Replaces the missing
// timeout(1), and replaces the bash watchdog whose two measured failures were:
//   1. it inherited the caller's stdout (then stderr), so `$(run_bounded …)` and
//      `run_bounded … 2>&1 | tail` blocked for the FULL timeout after the
//      command had already answered — read as a hang, killed at 144 = UNRUN;
//   2. `kill $watch_pid` reaped the subshell but not the `sleep` it forked — 21
//      orphaned `sleep 1800` (ppid 1) were on the box at once, each holding
//      whatever pipe its dead parent held.
// Neither can happen here: the timer is an in-process setTimeout (it forks
// nothing and holds no fd) and this process holds no pipe of its own — stdio is
// inherited straight through to the child.
//
// `detached: true` is load-bearing: it is the only way to give the child its own
// process group, and the group is the point. `bun run verify` is
// bash -> bun -> node -> N vitest forks; killing the shell alone reparents all
// of them to launchd, which is exactly how orphaned verify trees leaked here.
function cmdRunBounded(secs: number, argv: string[]): Promise<number> {
  return new Promise((resolve) => {
    if (argv.length === 0) return resolve(0);
    const child = spawn(argv[0]!, argv.slice(1), {
      stdio: "inherit",
      detached: true,
    });
    let timedOut = false;
    let done = false;
    let killer: ReturnType<typeof setTimeout> | undefined;

    const killGroup = (sig: NodeJS.Signals) => {
      try {
        process.kill(-child.pid!, sig);
      } catch {}
    };

    const timer = setTimeout(() => {
      if (done) return; // the command answered first — nothing to kill
      timedOut = true;
      killGroup("SIGTERM");
      killer = setTimeout(() => killGroup("SIGKILL"), 5000);
    }, secs * 1000);

    // Forward a signal aimed at us to the group, so a killed gate does not
    // reparent its whole tree to launchd.
    const fwd = (sig: NodeJS.Signals) => {
      if (!done) killGroup(sig);
    };
    process.on("SIGTERM", () => fwd("SIGTERM"));
    process.on("SIGINT", () => fwd("SIGINT"));
    process.on("SIGHUP", () => fwd("SIGHUP"));

    child.on("error", () => {
      done = true;
      clearTimeout(timer);
      if (killer) clearTimeout(killer);
      resolve(127);
    });

    child.on("exit", (code, signal) => {
      done = true;
      clearTimeout(timer);
      if (killer) clearTimeout(killer);
      if (timedOut) {
        // The PARENT prints, from a shell that is allowed to — after the wait,
        // never from inside the watchdog.
        process.stderr.write(
          `[govern] TIMEOUT ${secs}s — killed process group ${child.pid}\n`,
        );
      }
      if (code !== null && code !== undefined) return resolve(code);
      // bash `wait` reports 128+signum; keep the numbers callers already compare.
      const SIGNUM: Record<string, number> = {
        SIGHUP: 1, SIGINT: 2, SIGQUIT: 3, SIGILL: 4, SIGABRT: 6, SIGFPE: 8,
        SIGKILL: 9, SIGSEGV: 11, SIGPIPE: 13, SIGALRM: 14, SIGTERM: 15,
      };
      resolve(128 + (SIGNUM[signal as string] ?? 0));
    });
  });
}

// ─── memory probe ────────────────────────────────────────────────────────────
// The honest quantities are in vm_stat, never memory_pressure's "free
// percentage" (which counts file cache, purgeable and already-compressed pages
// as free — measured 74% on a box with 1.3% of its RAM actually free and 9.4 GB
// in swap). Available = free + purgeable + min(file-backed, inactive). No swap
// term, deliberately: swap in use is a scar, not a signal.
//
// The vm_stat TEXT arrives on stdin, produced by the shim's _gv_vm_stat — the
// stub seam govern-mem-check.sh drives.

function readStdin(): string {
  try {
    return fs.readFileSync(0, "utf8");
  } catch {
    return "";
  }
}

let _vmCache: string | null = null;
function readVmStat(): string {
  if (_vmCache !== null) return _vmCache;
  // Only used by paths the shim does NOT feed (gate_slot's internal headroom).
  try {
    const out = Bun.spawnSync(["vm_stat"]);
    _vmCache = out.success ? out.stdout.toString() : "";
  } catch {
    _vmCache = "";
  }
  return _vmCache;
}

function fieldPages(vs: string, prefix: string): string | null {
  for (const line of vs.split("\n")) {
    if (!line.startsWith(prefix)) continue;
    const colon = line.indexOf(":");
    if (colon < 0) return "";
    return line.slice(colon + 1).replace(/[^0-9]/g, "");
  }
  return null;
}

function isNum(s: string | null | undefined): s is string {
  return typeof s === "string" && s !== "" && /^[0-9]+$/.test(s);
}

// Available RAM in MB, or null when ANY field is unreadable. Every caller treats
// null as "do not constrain": a broken sensor must never serialise the fleet.
function memAvailMb(vs: string): number | null {
  if (vs.replace(/\n+$/, "") === "") return null;
  const m = vs.match(/page size of ([0-9]+) bytes/);
  const psz = m ? m[1]! : "";
  const free = fieldPages(vs, "Pages free");
  let purge = fieldPages(vs, "Pages purgeable");
  const inact = fieldPages(vs, "Pages inactive");
  const filebk = fieldPages(vs, "File-backed pages");
  if (purge === null || purge === "") purge = "0";
  if (!isNum(psz)) return null;
  if (!isNum(free)) return null;
  if (!isNum(purge)) return null;
  if (!isNum(inact)) return null;
  if (!isNum(filebk)) return null;
  const p = parseInt(psz, 10);
  if (p <= 0) return null;
  const cold = Math.min(parseInt(filebk, 10), parseInt(inact, 10));
  return Math.floor(
    ((parseInt(free, 10) + parseInt(purge, 10) + cold) * p) / 1048576,
  );
}

// What ONE gate slot actually costs in RAM. Derived from the LIVE fork count,
// never a stale constant — that drift is the defect: vitest maxWorkers moved
// 4 -> 8 and test-lanes.sh runs two drivers in one slot, so the same gate had
// two different costs depending on who launched it. Constants measured
// 2026-09-03 (125 fork samples, 65 driver samples). All overridable; an explicit
// GOVERN_GB_PER_CYCLE is still the operator's override and wins.
function priceMb(): number {
  const ovr = E.GOVERN_GB_PER_CYCLE;
  if (ovr !== undefined && ovr !== "") {
    const n = parseInt(ovr, 10);
    return (Number.isFinite(n) ? n : 0) * 1024;
  }
  let forks = envInt("VITEST_MAX_FORKS", 8);
  let lanes = envInt("GOVERN_TEST_LANES", 2);
  if (lanes < 1) lanes = 1;
  if (forks < 1) forks = 1;
  return (
    lanes * envInt("GOVERN_MB_PER_DRIVER", 300) +
    (forks + lanes - 1) * envInt("GOVERN_MB_PER_FORK", 200) +
    envInt("GOVERN_MB_TSC", 400) +
    envInt("GOVERN_MB_OVERHEAD", 300)
  );
}

// How many concurrent heavy CYCLES this box can afford right now. >= 1 always;
// 99 ("don't constrain") when memory cannot be read. The floor is load-bearing:
// do-fleet.sh clamps its slot count to this with no floor of its own, so a 0
// here would launch nothing at all.
function headroom(vs: string): number {
  const avail = memAvailMb(vs);
  if (avail === null) return 99;
  let price = priceMb();
  if (price < 1) price = 1024;
  const reserve = envInt("GOVERN_RESERVE_GB", 2) * 1024;
  let usable = avail - reserve;
  if (usable < 0) usable = 0;
  const slots = Math.floor(usable / price);
  return slots < 1 ? 1 : slots;
}

// 0 = the machine has headroom, 1 = it is already thrashing. Two conditions,
// either fires: what is available cannot fund one more gate at its measured
// price, or the free percentage is under the floor. Unreadable sensor -> 0.
function pressure(vs: string, memsize: string): number {
  const avail = memAvailMb(vs);
  if (avail === null) return 0;
  if (avail < envInt("GOVERN_RESERVE_GB", 2) * 1024 + priceMb()) return 1;
  if (!isNum(memsize)) return 0;
  const total = Math.floor(parseInt(memsize, 10) / 1048576);
  if (total < 1) return 0;
  const pct = Math.floor((avail * 100) / total);
  if (pct < envInt("GOVERN_MIN_FREE_PCT", 12)) return 1;
  return 0;
}

function memReport(vs: string, memsize: string, swapusage: string): string {
  const avail = memAvailMb(vs);
  let total = 0;
  if (isNum(memsize)) total = Math.floor(parseInt(memsize, 10) / 1048576);
  const sm = swapusage.match(/used = ([0-9]+)\.?[0-9]*M/);
  const swap = sm ? sm[1]! : "0";
  const tail = `swap_used_mb=${swap} price_mb=${priceMb()} slots=${headroom(vs)}`;
  if (avail === null) return `avail_mb=? total_mb=${total} avail_pct=? ${tail}`;
  const pct = total > 0 ? Math.floor((avail * 100) / total) : 0;
  return `avail_mb=${avail} total_mb=${total} avail_pct=${pct} ${tail}`;
}

// ─── claims ──────────────────────────────────────────────────────────────────
// A machine-wide registry of who is working on WHICH REGION right now. NOT a
// queue, no coordinator: a worker that finds its region claimed takes the next
// candidate, so contention costs a re-rank and never a wait.
//
// EVAPORATION is the whole contract — a claim expires with no human in the loop,
// two ways: the owner pid is dead, or the lease expired. Both fire on the READ
// path, so the next contender reclaims dead ground by itself.
//
// The KEY is computed by the shim (`cksum` is the POSIX CRC, not zlib's, and
// re-deriving it here would be a second definition of an injective mapping the
// checkers read directly off disk). It arrives as an argument.

function claimGet(d: string, field: string): string {
  let txt = "";
  try {
    txt = fs.readFileSync(`${d}/meta`, "utf8");
  } catch {
    return "";
  }
  for (const line of txt.split("\n")) {
    if (line.startsWith(`${field}=`)) return line.slice(field.length + 1);
  }
  return "";
}

// true = reaped (the ground is now free), false = still held by a live, in-lease
// owner.
function claimReap(d: string): boolean {
  if (!fs.existsSync(d)) return true;
  const owner = claimGet(d, "pid");
  const started = claimGet(d, "started");
  if (!alive(owner)) {
    // `minhold` is the grace window for a claim taken FOR a worker by a
    // short-lived emitter: without it the very next racer reaps the claim in the
    // moment between it landing and the worker adopting it. Opt-in — a claim
    // written without one reaps on a dead pid exactly as it always did.
    const minhold = claimGet(d, "minhold");
    if (minhold !== "" && started !== "" && now() - parseInt(started, 10) < parseInt(minhold, 10)) {
      return false;
    }
    log(`reaping claim ${d} (owner ${owner} gone)`);
    rmrf(d);
    return true;
  }
  let ttl = claimGet(d, "ttl");
  if (started === "") return false;
  if (ttl === "") ttl = String(CLAIM_TTL);
  const age = now() - parseInt(started, 10);
  if (age >= parseInt(ttl, 10)) {
    log(`reaping claim ${d} (lease expired: ${age}s >= ${ttl}s)`);
    rmrf(d);
    return true;
  }
  return false;
}

function claimTake(key: string, region: string, slug: string): number {
  try {
    fs.mkdirSync(CLAIMS_DIR, { recursive: true });
  } catch {}
  const d = `${CLAIMS_DIR}/${key}`;
  try {
    fs.mkdirSync(d);
    let meta =
      `pid=${CLAIM_PID}\n` +
      `slug=${slug}\n` +
      `region=${region}\n` +
      `started=${now()}\n` +
      `ttl=${CLAIM_TTL}\n`;
    const mh = E.GOVERN_CLAIM_MIN_HOLD_SECS;
    if (mh) meta += `minhold=${mh}\n`;
    fs.writeFileSync(`${d}/meta`, meta);
    log(`claimed ${region} (${slug})`);
    return 0;
  } catch {}
  // Held. Re-claiming your own region is idempotent — do-fleet re-claims on
  // every launch, including relaunches into an existing worktree.
  if (claimGet(d, "pid") === String(CLAIM_PID)) return 0;
  if (!claimReap(d)) return 1;
  return claimTake(key, region, slug); // ground reaped — take it
}

function claimDirs(): string[] {
  try {
    return fs
      .readdirSync(CLAIMS_DIR)
      .map((e) => `${CLAIMS_DIR}/${e}`)
      .filter((p) => {
        try {
          return fs.statSync(p).isDirectory();
        } catch {
          return false;
        }
      });
  } catch {
    return [];
  }
}

// ─── tsc_tree_fingerprint ────────────────────────────────────────────────────
// ONE hash of everything tsc READS for <folder>, keyed BY CONTENT, never by
// mtime: two checkouts of one commit have identical bytes and different mtimes,
// so N worktrees each paid a full tsc and wrote their own stamp (28 unshared
// stamps, measured 2026-09-03). Same bytes ⇒ same key, in any checkout; a doc
// edit moves nothing.
//
// node_modules / .git / dist / .wrangler are pruned (dependency drift is covered
// by the lockfile), and dot-entries are pruned EXCEPT .astro — without that the
// key carried .w2-spec.json and friends, cycle receipts that move every wave and
// are not tsc inputs, so the memo missed on every wave.
//
// The BYTES hashed are identical to the shell pipeline this replaces
// (`find -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256` folded into one
// shasum), so the shared `tsc-<folder>.<fp>` namespace is unchanged and
// do-reconcile.sh `types` — the other caller of this one derivation — still
// shares the memo.

const FP_PRUNE = new Set(["node_modules", ".git", "dist", ".wrangler"]);
const FP_EXT = [".ts", ".tsx", ".mts", ".cts", ".json"];
const FP_NAME = new Set(["bun.lock", "package-lock.json"]);

function fpMatches(name: string): boolean {
  if (FP_NAME.has(name)) return true;
  return FP_EXT.some((x) => name.endsWith(x));
}

function fpWalk(start: string, out: string[]) {
  const stack = [start];
  while (stack.length) {
    const dir = stack.pop()!;
    let ents: fs.Dirent[];
    try {
      ents = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const e of ents) {
      const name = e.name;
      // The find(1) prune expression, verbatim: the four heavy dirs plus every
      // dot-entry that is not .astro. It prunes FILES too — that is what keeps
      // .w2-spec.json out of the key.
      if (FP_PRUNE.has(name) || (name.startsWith(".") && name !== ".astro")) continue;
      const full = `${dir}/${name}`;
      if (e.isDirectory()) stack.push(full);
      else if (e.isFile() && fpMatches(name)) out.push(full);
    }
  }
}

function fingerprint(inputs: string[]): string {
  const chunks: Buffer[] = [];
  for (const d of inputs) {
    let isDir = false;
    try {
      isDir = fs.statSync(d).isDirectory();
    } catch {}
    if (!isDir) {
      // The shell emitted `ABSENT <dir>` into the same NUL-delimited stream.
      chunks.push(Buffer.from(`ABSENT ${d}\n`));
      continue;
    }
    const files: string[] = [];
    fpWalk(d, files);
    for (const f of files) chunks.push(Buffer.concat([Buffer.from(f), Buffer.from([0])]));
  }
  const raw = Buffer.concat(chunks);
  const recs: Buffer[] = [];
  let start = 0;
  for (let i = 0; i < raw.length; i++) {
    if (raw[i] === 0) {
      recs.push(raw.subarray(start, i));
      start = i + 1;
    }
  }
  if (start < raw.length) recs.push(raw.subarray(start));
  recs.sort(Buffer.compare); // LC_ALL=C sort -z — byte-wise
  const outer = createHash("sha256");
  for (const r of recs) {
    const p = r.toString("utf8");
    let st: fs.Stats;
    try {
      st = fs.statSync(p);
    } catch {
      continue; // an ABSENT record is not a file; shasum printed nothing for it
    }
    if (!st.isFile()) continue;
    let buf: Buffer;
    try {
      buf = fs.readFileSync(p);
    } catch {
      continue;
    }
    outer.update(`${createHash("sha256").update(buf).digest("hex")}  ${p}\n`);
  }
  return outer.digest("hex");
}

// ─── the second memo key: test-cached.sh's per-file hash ──────────────────────
// `<hash>  <repo-relative path>` — the shape `shasum <file>` prints, minus
// $ROOT. Repo-relative is load-bearing: an absolute path puts the WORKTREE into
// the key, and the same bytes hashed from two checkouts then produced two keys.
// A missing file hashes to the empty string, exactly as
// `$(shasum -a 256 < missing | cut -d' ' -f1)` did.
function hashRel(root: string, rels: string[]): number {
  let out = "";
  for (const rel of rels) {
    let h = "";
    try {
      h = createHash("sha256").update(fs.readFileSync(`${root}/${rel}`)).digest("hex");
    } catch {}
    out += `${h}  ${rel}\n`;
  }
  process.stdout.write(out);
  return 0;
}

// ─── dispatch ────────────────────────────────────────────────────────────────

async function main(): Promise<number> {
  const [cmd, ...rest] = process.argv.slice(2);
  switch (cmd) {
    case "lock":
      return cmdLock(rest[0]!, parseInt(rest[1] || "0", 10) || 0);
    case "unlock":
      return cmdUnlock(rest[0]!);
    case "slot":
      return cmdSlot(parseInt(rest[0] || "900", 10) || 0);
    case "sweep-stale":
      return cmdSweepStale();
    case "run-bounded": {
      const secs = parseInt(rest[0] || "0", 10) || 0;
      return cmdRunBounded(secs, rest.slice(1));
    }

    case "mem-avail-mb": {
      const v = memAvailMb(readStdin());
      if (v === null) return 1;
      process.stdout.write(`${v}\n`);
      return 0;
    }
    case "price-mb":
      process.stdout.write(`${priceMb()}\n`);
      return 0;
    case "headroom":
      process.stdout.write(`${headroom(readStdin())}\n`);
      return 0;
    case "pressure":
      return pressure(readStdin(), E.GOVERN_MEMSIZE || "");
    case "mem-report":
      process.stdout.write(
        `${memReport(readStdin(), E.GOVERN_MEMSIZE || "", E.GOVERN_SWAPUSAGE || "")}\n`,
      );
      return 0;

    case "claim-take":
      return claimTake(rest[0]!, rest[1]!, rest[2] || "");
    case "claim-owner": {
      const d = `${CLAIMS_DIR}/${rest[0]!}`;
      if (!fs.existsSync(d)) return 0;
      if (claimReap(d)) return 0;
      process.stdout.write(`${claimGet(d, "slug")} ${claimGet(d, "pid")}\n`);
      return 0;
    }
    case "claim-release": {
      const d = `${CLAIMS_DIR}/${rest[0]!}`;
      if (claimGet(d, "pid") === String(CLAIM_PID)) rmrf(d);
      return 0;
    }
    case "claim-release-all": {
      // keys on the plain shell pid, not GOVERN_CLAIM_PID — see the note at
      // CLAIM_PID above. Preserved verbatim from the bash original.
      for (const d of claimDirs()) {
        if (claimGet(d, "pid") === String(SHELL_PID)) rmrf(d);
      }
      return 0;
    }
    case "claim-list": {
      let out = "";
      for (const d of claimDirs()) {
        if (claimReap(d)) continue;
        out += `${claimGet(d, "region")}\t${claimGet(d, "slug")}\t${claimGet(d, "pid")}\n`;
      }
      process.stdout.write(out);
      return 0;
    }
    case "claim-sweep": {
      let n = 0;
      if (fs.existsSync(CLAIMS_DIR)) {
        for (const d of claimDirs()) if (claimReap(d)) n++;
      }
      process.stdout.write(`${n}\n`);
      return 0;
    }
    case "claim-pids": {
      // every pid the registry currently names — the shim filters these through
      // its own (stubbable) _gv_alive before handing back an alive set.
      const seen = new Set<string>();
      for (const d of claimDirs()) {
        const p = claimGet(d, "pid");
        if (p) seen.add(p);
      }
      process.stdout.write([...seen].join("\n") + (seen.size ? "\n" : ""));
      return 0;
    }

    case "fingerprint":
      if (rest.length === 0 || !rest[0]) return 1;
      process.stdout.write(`${fingerprint(rest)}\n`);
      return 0;
    case "hash-rel":
      return hashRel(rest[0]!, rest.slice(1));

    default:
      process.stderr.write(`govern.ts: unknown command '${cmd ?? ""}'\n`);
      return 2;
  }
}

process.exitCode = await main();
