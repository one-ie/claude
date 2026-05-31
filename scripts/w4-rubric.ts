#!/usr/bin/env bun
/**
 * w4-rubric.ts — W4 rubric scoring with Anthropic SDK prompt caching
 *
 * Runs 6 Haiku calls in parallel (goal-fit, security, stability, simplicity,
 * speed, adversarial). The static rubric + spec block is cached — each call
 * pays only for the unique diff/files suffix.
 *
 * Usage:
 *   bun .claude/scripts/w4-rubric.ts --files <file,...>
 *
 * Output: JSON to stdout — { composite, gate, dimensions, adversarial }
 * Falls back: exits 2 if ANTHROPIC_API_KEY missing (caller spawns agents).
 */

import Anthropic from "@anthropic-ai/sdk";
import { readFileSync, existsSync } from "fs";
import { execFileSync } from "child_process";
import { join } from "path";

if (!process.env.ANTHROPIC_API_KEY) {
  process.stderr.write("[w4-rubric] no ANTHROPIC_API_KEY — falling back to agent spawn\n");
  process.exit(2);
}

const SCRIPTS_DIR = new URL(".", import.meta.url).pathname;
const RUBRICS_PATH = join(SCRIPTS_DIR, "../../plans/rubrics.md");
const SPEC_PATH = ".w2-spec.json";

const DIMS = [
  { key: "goal-fit",    weight: 0.35, instruction: "Score goal-fit: does the diff advance the plan outcome? Read Goal/deliverable from the spec. 0 = no movement, 1 = fully delivers." },
  // These are grep-pattern strings sent to the LLM for it to search — not code being executed.
  { key: "security",    weight: 0.20, instruction: "Score security: check for hardcoded secrets, calls to eval, dangerouslySetInnerHTML, missing Zod at API boundaries, wildcard CORS, TypeQL string concat. 1 = all greps return 0." },
  { key: "stability",   weight: 0.20, instruction: "Score stability: check new `any`, @ts-ignore without comment, silent returns, retired names (knowledge|connections|people|node|scent|alarm|trail|colony). 1 = all zero." },
  { key: "simplicity",  weight: 0.15, instruction: "Score simplicity: focused single-purpose files, functions under 20 lines, no backwards-compat shims or WHAT comments. 1 = tight, no ceremony." },
  { key: "speed",       weight: 0.10, instruction: "Score speed: does the diff increase bundle size or build time? Any new client:load where client:idle suffices? 1 = no regressions." },
  { key: "adversarial", weight: 0,    instruction: "Adversarial check: is there any finding that should block this cycle? If yes, name it briefly. If nothing blocks, return null for 'finding'." },
] as const;

function loadRubrics(): string {
  if (existsSync(RUBRICS_PATH)) return readFileSync(RUBRICS_PATH, "utf8");
  return "Score each dimension 0.0–1.0. Explain why in one sentence. Name the specific gap in 'improve', or 'clean' if 1.0.";
}

function loadSpec(): string {
  if (existsSync(SPEC_PATH)) return readFileSync(SPEC_PATH, "utf8").slice(0, 3000);
  return "{}";
}

function diffStat(): string {
  try { return execFileSync("git", ["diff", "HEAD", "--stat"], { encoding: "utf8" }).slice(0, 1000); }
  catch { return "(no diff)"; }
}

function fileSnippets(files: string[]): string {
  return files
    .map(f => {
      try { return `### ${f}\n\`\`\`\n${readFileSync(f, "utf8").slice(0, 1500)}\n\`\`\``; }
      catch { return `### ${f}\n[not found]`; }
    })
    .join("\n\n");
}

type DimResult = { key: string; score: number; why: string; improve: string; finding?: string | null };

async function scoreDim(
  client: Anthropic,
  cachedSystem: Anthropic.TextBlockParam[],
  dim: typeof DIMS[number],
): Promise<DimResult> {
  const res = await client.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 256,
    system: cachedSystem as any,
    messages: [{
      role: "user",
      content: `${dim.instruction}

The rubric, cycle spec, diff summary, and touched files are in the system context above.

Return compact JSON only:
${dim.key === "adversarial"
  ? '{"finding": "<what blocks or null>"}'
  : '{"score": 0.0–1.0, "why": "<one sentence>", "improve": "<gap or clean>"}'}`,
    }],
  });

  const text = res.content.filter(b => b.type === "text").map(b => (b as Anthropic.TextBlock).text).join("");
  try {
    const match = text.match(/\{[\s\S]*?\}/);
    if (match) return { key: dim.key, score: 0.5, why: "", improve: "", ...JSON.parse(match[0]) };
  } catch {}
  return { key: dim.key, score: 0.5, why: "parse error", improve: text.slice(0, 80) };
}

async function main() {
  const args = process.argv.slice(2);
  const filesIdx = args.indexOf("--files");
  const files = filesIdx >= 0 ? args[filesIdx + 1].split(",").filter(Boolean) : [];

  const client = new Anthropic();
  const rubricText = loadRubrics();
  const spec = loadSpec();
  const diff = diffStat();
  const snippets = fileSnippets(files);

  // ONE cached block — rubric + spec + diff + snippets are byte-identical across all
  // 6 parallel dimension calls. Caching them here (instead of repeating diff+snippets
  // in each user message) turns 6× re-tokenization into 1 cache write + 5 cache reads.
  const cachedSystem: Anthropic.TextBlockParam[] = [{
    type: "text",
    text: `# Rubric Reference\n\n${rubricText}\n\n# Cycle Spec\n\`\`\`json\n${spec}\n\`\`\`\n\n# Diff summary\n${diff}\n\n# Touched files\n${snippets}`,
    cache_control: { type: "ephemeral" },
  } as any];

  const results = await Promise.all(
    DIMS.map(dim => scoreDim(client, cachedSystem, dim))
  );

  const scored = results.filter(r => r.key !== "adversarial");
  const composite = scored.reduce((sum, r) => {
    const w = DIMS.find(d => d.key === r.key)!.weight;
    return sum + r.score * w;
  }, 0);

  const goalFit = scored.find(r => r.key === "goal-fit")?.score ?? 0;
  const adversarial = results.find(r => r.key === "adversarial");

  const output = {
    composite: Math.round(composite * 100) / 100,
    gate: composite >= 0.65 && goalFit >= 0.50,
    dimensions: Object.fromEntries(
      scored.map(r => [r.key, { score: r.score, why: r.why, improve: r.improve }])
    ),
    adversarial: adversarial?.finding ?? null,
  };

  process.stderr.write(`[w4-rubric] composite=${output.composite} gate=${output.gate}\n`);
  process.stdout.write(JSON.stringify(output, null, 2));
}

main().catch(e => { process.stderr.write(`[w4-rubric] error: ${e}\n`); process.exit(1); });
