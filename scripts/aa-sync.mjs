#!/usr/bin/env node
// aa-sync.mjs — fetch Artificial Analysis' benchmark table and join it to
// OpenRouter's catalog, writing one.ie/web/src/lib/chat/model-intel.json.
//
// classification: needs-env  (ARTIFICIAL_ANALYSIS_API_KEY)
//
// WHY A SNAPSHOT AND NOT A REQUEST-PATH FETCH. `model-rank.ts` is pure and
// unit-testable, and the substrate's own law is that the request path reads a
// snapshot rather than reaching for a far-away thing (root CLAUDE.md § The
// brain and the edge). So this runs out of band, writes a file with its own
// provenance, and the deck reads the file.
//
// WHY A SNAPSHOT IS ALLOWED TO BE A FACT. The objection `model-rank.ts` records
// is to a HAND-WRITTEN benchmark map: "no provenance, cannot be re-derived, and
// rots the day a model ships". This has provenance (a named source, a fetch
// timestamp, a row count), re-derives on every run, and reports its own match
// rate so a reader can see how much of the catalog it actually covers.
//
// THE JOIN IS THE HARD PART, AND IT IS REPORTED, NEVER ASSUMED. AA keys by its
// own slug, OpenRouter by `vendor/model`. Three normalisations close most of
// the gap and each is a rule, not a lookup table:
//   1. reasoning-effort suffixes — AA ships claude-opus-5, -high, -xhigh,
//      -medium as separate rows. The bare slug is the vendor default and wins.
//   2. date suffixes — OpenRouter carries qwen3.8-max-0902, AA carries the base.
//   3. Anthropic reverses family and version: OpenRouter claude-haiku-4.5 is
//      AA claude-4-5-haiku. Rule, applied to any vendor, not a special case.
// Everything else is left UNMATCHED on purpose. A fuzzy match that silently
// attaches Sonnet's score to Haiku's card is worse than a blank bar.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const ROOT = join(dirname(new URL(import.meta.url).pathname), "..", "..");
const OUT = join(ROOT, "one.ie/web/src/lib/chat/model-intel.json");

function key() {
  if (process.env.ARTIFICIAL_ANALYSIS_API_KEY) return process.env.ARTIFICIAL_ANALYSIS_API_KEY;
  // ONE_ENV_FILE indirection, so a shipped copy never hardcodes a path.
  for (const f of [process.env.ONE_ENV_FILE, process.env.DO_ENV_FILE, join(ROOT, "one.ie/web/.env")]) {
    if (!f) continue;
    try {
      const m = readFileSync(f, "utf8").match(/^ARTIFICIAL_ANALYSIS_API_KEY=(.*)$/m);
      if (m) return m[1].trim().replace(/^["']|["']$/g, "");
    } catch {}
  }
  return "";
}

const norm = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/-+/g, "-").replace(/^-|-$/g, "");
const EFFORT = /-(xhigh|high|medium|low|minimal|thinking|reasoning|adaptive|non-reasoning)$/;
const DATE = /-(\d{4}|\d{6}|\d{8})$/;
// claude-haiku-4.5 -> claude-4-5-haiku : move a trailing version ahead of the
// family word. Applied to every vendor; it only ever produces a candidate.
function reorder(t) {
  const m = t.match(/^([a-z]+)-([a-z]+)-([\d-]+)$/);
  return m ? `${m[1]}-${m[3]}-${m[2]}` : null;
}

const AA_KEY = key();
if (!AA_KEY) {
  console.error("aa-sync: no ARTIFICIAL_ANALYSIS_API_KEY (env, ONE_ENV_FILE, or one.ie/web/.env)");
  process.exit(2);
}

const aaRes = await fetch("https://artificialanalysis.ai/api/v2/data/llms/models", {
  headers: { "x-api-key": AA_KEY, Accept: "application/json" },
});
if (!aaRes.ok) {
  // A 401 here must never write a file — a stale snapshot beats an empty one.
  console.error(`aa-sync: AA returned ${aaRes.status} ${await aaRes.text()}`);
  process.exit(1);
}
const aa = (await aaRes.json()).data;
const or = (await (await fetch("https://openrouter.ai/api/v1/models")).json()).data;

// AA index: base slug -> row, the bare (default-effort) row winning.
const idx = new Map();
for (const m of aa) {
  const i = m.evaluations?.artificial_analysis_intelligence_index;
  if (i === null || i === undefined) continue;
  const s = norm(m.slug);
  const base = s.replace(EFFORT, "");
  const cur = idx.get(base);
  if (!cur || (s === base && norm(cur.slug) !== base)) idx.set(base, m);
}

function lookup(id) {
  const tail = norm(id.split("/").slice(1).join("-"));
  const cands = [tail, tail.replace(EFFORT, ""), tail.replace(DATE, ""), tail.replace(DATE, "").replace(EFFORT, "")];
  const ro = reorder(tail.replace(DATE, ""));
  if (ro) cands.push(ro);
  for (const c of cands) if (idx.has(c)) return { row: idx.get(c), via: c };
  return null;
}

const models = {};
let matched = 0, seen = 0;
for (const m of or) {
  if (m.id.includes(":") || m.id.startsWith("~")) continue;
  seen++;
  const hit = lookup(m.id);
  if (!hit) continue;
  matched++;
  const ev = hit.row.evaluations ?? {};
  const num = (v) => (typeof v === "number" && v > 0 ? v : undefined);
  models[m.id] = {
    aaSlug: hit.row.slug,
    intelligence: ev.artificial_analysis_intelligence_index,
    coding: num(ev.artificial_analysis_coding_index),
    math: num(ev.artificial_analysis_math_index),
    gpqa: num(ev.gpqa),
    hle: num(ev.hle),
    // AA's OWN speed numbers, independent of ours in model-speed.json. Kept
    // separate and never merged: theirs measure a provider directly, ours
    // measure what a caller waits for through our door. A 0 means AA has not
    // measured it, and is dropped rather than stored as a zero.
    aaTokS: num(hit.row.median_output_tokens_per_second),
    aaTtftS: num(hit.row.median_time_to_first_token_seconds),
  };
}

const out = {
  _: "Artificial Analysis benchmark scores, joined to OpenRouter ids. GENERATED - do not hand-edit. Re-run: node .claude/scripts/aa-sync.mjs",
  _source: "https://artificialanalysis.ai/api/v2/data/llms/models",
  _fetchedAt: new Date().toISOString(),
  _aaRows: aa.length,
  _aaScored: idx.size,
  _openRouterModels: seen,
  _matched: matched,
  _matchRate: `${Math.round((100 * matched) / seen)}%`,
  _unmatchedIsBlank: "A model absent here renders its Smarts bar as an ESTIMATE, exactly as before. A fuzzy match that attached the wrong model's score would be worse than a blank bar.",
  models,
};
writeFileSync(OUT, `${JSON.stringify(out, null, 1)}\n`);
console.log(`aa-sync: ${matched}/${seen} OpenRouter models matched (${out._matchRate}), from ${idx.size} AA-scored rows -> ${OUT}`);
