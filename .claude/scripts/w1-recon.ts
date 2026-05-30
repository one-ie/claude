#!/usr/bin/env bun
/**
 * w1-recon.ts — W1 recon with Anthropic SDK prompt caching
 *
 * Caches the static rules + agent-prompt block so repeated W1 calls on the
 * same codebase skip re-tokenizing those layers (~1k tokens / call).
 * Also writes findings to .w1-cache/ (sha-keyed) so the next cycle is free.
 *
 * Usage:
 *   bun .claude/scripts/w1-recon.ts --targets <file,...> [--mode RECON|SURVEY|INVESTIGATE]
 *
 * Falls back gracefully: if ANTHROPIC_API_KEY is missing, exits 2 (caller uses Agent spawn).
 */

import Anthropic from "@anthropic-ai/sdk";
import { readFileSync, existsSync, mkdirSync, writeFileSync } from "fs";
import { execFileSync } from "child_process";
import { join } from "path";

const SCRIPTS_DIR = new URL(".", import.meta.url).pathname;
const AGENTS_DIR = join(SCRIPTS_DIR, "../agents");
const RULES_DIR = join(SCRIPTS_DIR, "../rules");
const CACHE_DIR = ".w1-cache";

if (!process.env.ANTHROPIC_API_KEY) {
  process.stderr.write("[w1-recon] no ANTHROPIC_API_KEY — falling back to agent spawn\n");
  process.exit(2);
}

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { targets: [] as string[], mode: "RECON" };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--targets" && args[i + 1]) out.targets = args[++i].split(",").filter(Boolean);
    if (args[i] === "--mode" && args[i + 1]) out.mode = args[++i].toUpperCase();
  }
  return out;
}

// Recon is read-only mapping — it needs the locked-rule vocabulary (engine) and
// doc conventions, NOT the UI rules (astro/react/ui/design) that guide W3 edits.
// Curating here cuts ~7k tokens of irrelevant context from every recon call AND
// keeps the merged static block comfortably above Haiku's 4,096-token cache floor.
const W1_RULES = ["engine.md", "documentation.md"];

function loadRules(): string {
  return W1_RULES
    .map(f => join(RULES_DIR, f))
    .filter(existsSync)
    .map(p => readFileSync(p, "utf8"))
    .join("\n\n---\n\n");
}

function loadAgentPrompt(): string {
  const path = join(AGENTS_DIR, "w1-recon.md");
  if (!existsSync(path)) return "";
  return readFileSync(path, "utf8").replace(/^---[\s\S]*?---\n/, "").trim();
}

function fileSha(path: string): string {
  try { return execFileSync("git", ["hash-object", path], { encoding: "utf8" }).trim(); }
  catch { return ""; }
}

function checkCache(shas: string[]): string | null {
  if (!existsSync(CACHE_DIR) || shas.some(s => !s)) return null;
  const entries: string[] = [];
  for (const sha of shas) {
    const p = join(CACHE_DIR, `${sha}.json`);
    if (!existsSync(p)) return null;
    entries.push(readFileSync(p, "utf8"));
  }
  return entries.join("\n\n");
}

function writeCache(sha: string, findings: string) {
  mkdirSync(CACHE_DIR, { recursive: true });
  writeFileSync(join(CACHE_DIR, `${sha}.json`), findings);
}

async function main() {
  const { targets, mode } = parseArgs();
  if (!targets.length) { process.stderr.write("--targets required\n"); process.exit(1); }

  const shas = targets.map(fileSha);
  const hit = checkCache(shas);
  if (hit) {
    process.stderr.write(`[w1-recon] cache hit (${targets.length} file(s))\n`);
    process.stdout.write(hit);
    return;
  }

  const client = new Anthropic();
  const rulesText = loadRules();
  const agentPrompt = loadAgentPrompt();

  const targetContents = targets
    .map(t => {
      try { return `### ${t}\n\`\`\`\n${readFileSync(t, "utf8").slice(0, 4000)}\n\`\`\``; }
      catch { return `### ${t}\n[not found]`; }
    })
    .join("\n\n");

  const improvements = existsSync(".w4-improvements.json")
    ? `\n\n## Open improvements\n\`\`\`json\n${readFileSync(".w4-improvements.json", "utf8")}\n\`\`\``
    : "";

  // ONE merged cached block. Rules + agent prompt are both static, so a single
  // breakpoint at the end caches the whole prefix. Splitting them would leave the
  // ~1.4k-token agent block below Haiku's 4,096 cache floor — it would never cache.
  const staticPrefix = [rulesText && `# Rules\n\n${rulesText}`, agentPrompt]
    .filter(Boolean)
    .join("\n\n---\n\n");
  const system: Anthropic.TextBlockParam[] = [
    { type: "text", text: staticPrefix, cache_control: { type: "ephemeral" } } as any,
  ];

  const res = await client.messages.create({
    model: "claude-haiku-4-5-20251001",
    max_tokens: 1024,
    system: system as any,
    messages: [{
      role: "user",
      content: `Mode: ${mode}\n\nTarget files:\n${targetContents}${improvements}\n\nProduce the findings report. Under 400 words. End with the W1 receipt line.`,
    }],
  });

  const findings = res.content.filter(b => b.type === "text").map(b => (b as Anthropic.TextBlock).text).join("\n");

  // Write to sha-keyed cache
  shas.filter(Boolean).forEach(sha => writeCache(sha, findings));

  const u = res.usage as any;
  process.stderr.write(`[w1-recon] tokens in=${u.input_tokens} cache_write=${u.cache_creation_input_tokens ?? 0} cache_read=${u.cache_read_input_tokens ?? 0}\n`);

  process.stdout.write(findings);
}

main().catch(e => { process.stderr.write(`[w1-recon] error: ${e}\n`); process.exit(1); });
