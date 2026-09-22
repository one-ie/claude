#!/usr/bin/env python3
"""do-rubric.py — standalone 5-axis code rubric for any package.

Scores security · stability · simplicity · integration · speed against the code
rubric in text/rubrics.md. Writes a W0 baseline JSON the /do loop reads so W4
measures genuine delta, not absolute state. All five axes are deterministic
heuristics — zero LLM calls; integration = wired-not-orphaned (exports consumed,
files imported), the repo-level twin of W4's surface-checklist gate.

Usage:
  python3 .claude/scripts/do-rubric.py sync
  python3 .claude/scripts/do-rubric.py one.ie/web/src/lib/billing.ts
  python3 .claude/scripts/do-rubric.py channels --json
  python3 .claude/scripts/do-rubric.py --all       (scan every package)

Output:
  Console: score card with per-axis findings + improvement paths
  File:    text/<slug>-w0-rubric.json   (W0 baseline the /do loop reads)
"""

import sys
import re
import os
import json
import datetime
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
TEXT = ROOT / "text"

# ── Deterministic heuristics ─────────────────────────────────────────────────

def collect_ts_files(target: Path) -> list[Path]:
    if target.is_file():
        return [target]
    return [
        f for f in target.rglob("*.ts")
        if "node_modules" not in f.parts
        and "dist" not in f.parts
        and ".wrangler" not in f.parts
        and not f.name.endswith(".d.ts")
    ] + [
        f for f in target.rglob("*.tsx")
        if "node_modules" not in f.parts and "dist" not in f.parts
    ]


def read_all(files: list[Path]) -> str:
    parts = []
    for f in files:
        try:
            parts.append(f"// === {f.relative_to(ROOT)} ===\n" + f.read_text(errors="ignore"))
        except Exception:
            pass
    return "\n".join(parts)


# ── Security axis ─────────────────────────────────────────────────────────────
def score_security(src: str, files: list[Path]) -> tuple[float, list[str], list[str]]:
    findings = []
    improvements = []

    # Auth checks
    auth_routes = sum(1 for f in files if "/api/" in str(f))
    auth_gates  = len(re.findall(r"requireAuth|canWalk|hasAuthorityOver|authorizeWorkspace|staffRole", src))
    if auth_routes > 0 and auth_gates == 0:
        findings.append(f"API routes ({auth_routes}) with 0 auth gates")
        improvements.append("add requireAuth or authorizeWorkspace to every /api/ handler")
    elif auth_routes > 0 and auth_gates < auth_routes:
        findings.append(f"{auth_routes} API routes, only {auth_gates} auth gate(s) found — possible ungated handlers")

    # Injection vectors
    typeql_interp = len(re.findall(r'`[^`]*\$\{[^}]*\}[^`]*`', src))
    typeql_files  = [f for f in files if "typedb" in str(f).lower() or "query" in str(f).lower()]
    if typeql_interp > 5 and typeql_files:
        findings.append(f"~{typeql_interp} template literals in TypeDB context — verify escaping")
        improvements.append("audit escapeTypeQLString() coverage in TypeDB query files")

    # Secrets exposure — only flag high-entropy literal strings (≥20 non-space chars),
    # not env.VAR or process.env.VAR reads or error message strings
    hardcoded = len(re.findall(
        r'(?<!env\.)(?<!process\.env\.)(?<!env\[[\'""])\b'
        r'(api[_-]?key|secret|password|token)\s*[:=]\s*["\'][A-Za-z0-9/+_=-]{20,}["\']',
        src, re.IGNORECASE
    ))
    if hardcoded:
        findings.append(f"{hardcoded} possible hardcoded secret(s) — high-entropy literal")
        improvements.append("move to env vars / KV secrets binding")

    # Missing HTTPS enforcement
    http_only = len(re.findall(r'http://(?!localhost|127)', src))
    if http_only > 2:
        findings.append(f"{http_only} non-localhost http:// URLs (should be https://)")
        improvements.append("force https:// on all external fetch calls")

    # body actorId IDOR pattern — only flag in auth/authorization context
    idor = len(re.findall(
        r'(data|body)\.actorId[^)]*(?:auth|owner|slug|grant|role|token)|'
        r'(?:auth|owner|grant|role)\w*\(?[^)]*(?:data|body)\.(actorId|slug)',
        src, re.IGNORECASE
    ))
    if idor:
        findings.append(f"possible IDOR: body actorId used in auth context ({idor} hits)")
        improvements.append("use ctx.ownerSlug / locals.slug for auth — never body fields")

    # Untyped any in critical paths
    any_casts = len(re.findall(r'as any', src))
    if any_casts > 3:
        findings.append(f"{any_casts} `as any` casts — type erasure")

    penalty = 0.0
    if "possible hardcoded secret" in " ".join(findings): penalty += 0.4
    if "IDOR" in " ".join(findings):                      penalty += 0.35
    if "0 auth gates" in " ".join(findings):              penalty += 0.25
    if "ungated handlers" in " ".join(findings):          penalty += 0.15
    penalty += min(any_casts * 0.02, 0.10)

    score = max(0.0, 1.0 - penalty)
    return round(score, 2), findings, improvements


# ── Stability axis ─────────────────────────────────────────────────────────────
def score_stability(src: str, files: list[Path], target: Path) -> tuple[float, list[str], list[str]]:
    findings = []
    improvements = []

    # Error handling
    try_count   = len(re.findall(r'\btry\s*\{', src))
    catch_count = len(re.findall(r'\bcatch\s*\(', src))
    empty_catch = len(re.findall(r'catch\s*\([^)]*\)\s*\{[\s\n]*\}', src))
    if empty_catch:
        findings.append(f"{empty_catch} empty catch block(s) — swallowed errors")
        improvements.append("log or re-throw in every catch block")

    # Silent catch / console.error only
    silent = len(re.findall(r'catch.*\n.*console\.\w+.*\n\s*\}', src))
    if silent > 2:
        findings.append(f"{silent} catch-and-log-only blocks (no signal/warn emit)")
        improvements.append("emit warn() after console.error for observability")

    # Test coverage
    pkg_root = target if target.is_dir() else target.parent
    test_files = list(pkg_root.rglob("*.test.ts")) + list(pkg_root.rglob("*.test.tsx")) + list(pkg_root.rglob("*.spec.ts"))
    test_files = [f for f in test_files if "node_modules" not in f.parts]
    if not test_files:
        findings.append("0 test files in package")
        improvements.append("add at minimum a smoke test verifying the scheduled handler runs without throwing")

    # Promise.all without error handling
    pall_bare = len(re.findall(r'await Promise\.all\([^)]+\)(?!\s*\.catch)', src))
    if pall_bare > 1:
        findings.append(f"{pall_bare} bare Promise.all (no .catch — one rejection aborts all)")
        improvements.append("wrap Promise.all items in try/catch or use .allSettled")

    # TypeScript strict
    ts_config = (pkg_root / "tsconfig.json")
    strict_on = False
    if ts_config.exists():
        try:
            tc = json.loads(ts_config.read_text())
            strict_on = tc.get("compilerOptions", {}).get("strict", False)
        except Exception:
            pass
    if not strict_on:
        findings.append("strict mode not enabled in tsconfig.json")
        improvements.append("add \"strict\": true to tsconfig.json")

    # Closed-loop check: signals should close with mark/warn
    emit_signal = len(re.findall(r'mark\(|warn\(|signal\(', src))
    open_returns = len(re.findall(r'return\s+(null|undefined|{}\s*)\s*;', src))
    if open_returns > emit_signal and emit_signal == 0:
        findings.append("no mark()/warn() calls — loop may not be closed")
        improvements.append("emit warn() on failure paths per Rule 1 (closed loop)")

    penalty = 0.0
    if empty_catch:                  penalty += 0.20
    if not test_files:               penalty += 0.20
    if pall_bare > 1:                penalty += 0.10
    if silent > 2:                   penalty += 0.10
    if "loop may not be closed" in " ".join(findings): penalty += 0.15

    score = max(0.0, 1.0 - penalty)
    return round(score, 2), findings, improvements


# ── Simplicity axis ────────────────────────────────────────────────────────────
def score_simplicity(src: str, files: list[Path]) -> tuple[float, list[str], list[str]]:
    findings = []
    improvements = []

    total_loc = src.count("\n")
    file_count = len(files)
    avg_loc = total_loc // max(file_count, 1)

    # Function size
    fn_bodies = re.findall(r'\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}', src)
    long_fns  = sum(1 for b in fn_bodies if b.count("\n") > 40)
    if long_fns > 2:
        findings.append(f"{long_fns} function(s) > 40 lines — hard to test in isolation")
        improvements.append("split long functions into named helpers with single responsibilities")

    # Comment ratio (too much = docs rot; too little = implicit logic)
    comment_lines = len(re.findall(r'^\s*//|^\s*/\*', src, re.MULTILINE))
    comment_ratio = comment_lines / max(total_loc, 1)
    if comment_ratio > 0.30:
        findings.append(f"comment ratio {comment_ratio:.0%} — possible over-documentation")
        improvements.append("remove comments that restate the code; keep only the WHY")

    # Duplicate patterns
    todos = len(re.findall(r'TODO|FIXME|HACK', src, re.IGNORECASE))
    if todos > 3:
        findings.append(f"{todos} TODO/FIXME markers in source")
        improvements.append("resolve or file as a cycle in the plan; don't leave in code")

    # Abstraction depth (import depth)
    deep_imports = len(re.findall(r"from '\.\.\/\.\.\/\.\.", src))
    if deep_imports > 3:
        findings.append(f"{deep_imports} imports reaching 3+ dirs up — coupling")
        improvements.append("extract shared logic to a lib/ module; reduce cross-dir coupling")

    penalty = 0.0
    if long_fns > 2:              penalty += min(long_fns * 0.04, 0.20)
    if todos > 3:                 penalty += min(todos * 0.02, 0.10)
    if comment_ratio > 0.30:      penalty += 0.10
    if deep_imports > 3:          penalty += 0.10

    score = max(0.0, 1.0 - penalty)
    return round(score, 2), findings, improvements


# ── Speed axis ────────────────────────────────────────────────────────────────
def score_speed(src: str, files: list[Path]) -> tuple[float, list[str], list[str]]:
    findings = []
    improvements = []

    # Sync operations on hot path (top-level await outside handlers)
    top_level_await = len(re.findall(r'^(?!.*function|.*=>|.*catch|.*try).*\bawait\b', src, re.MULTILINE))

    # Large global-scope initialisation
    global_scope_lines = 0
    in_fn = False
    for line in src.split("\n"):
        stripped = line.strip()
        if re.match(r'(export\s+)?(async\s+)?function|=>\s*\{|class\s+', stripped):
            in_fn = True
        if not in_fn and stripped and not stripped.startswith("//") and not stripped.startswith("import"):
            global_scope_lines += 1

    if global_scope_lines > 20:
        findings.append(f"~{global_scope_lines} lines in global scope — increases cold-start cost")
        improvements.append("move non-constant initialisation inside handlers (lazy init)")

    # Sequential awaits that could be parallel
    seq_awaits = len(re.findall(r'await [^;]+;\s*\n\s*(?:const|let) \w+ = await', src))
    if seq_awaits > 3:
        findings.append(f"{seq_awaits} sequential await pairs — potential Promise.all candidate")
        improvements.append("group independent awaits into Promise.all / Promise.allSettled")

    # Response size / payload
    json_stringify = len(re.findall(r'JSON\.stringify', src))
    if json_stringify > 5:
        findings.append(f"{json_stringify} JSON.stringify calls — verify payload sizes")
        improvements.append("stream large payloads; avoid stringify in hot path")

    # Bundle contributor: heavy imports
    heavy = re.findall(r"from '@?(typedb|openai|anthropic|langchain|tensorflow|torch)'", src)
    if heavy:
        findings.append(f"heavy imports in bundle: {set(heavy)}")
        improvements.append("lazy-import heavy deps inside handlers, not at top of file")

    penalty = 0.0
    if global_scope_lines > 20:  penalty += 0.15
    if seq_awaits > 3:           penalty += 0.10
    if heavy:                    penalty += 0.10
    if json_stringify > 5:       penalty += 0.05

    score = max(0.0, 1.0 - penalty)
    return round(score, 2), findings, improvements


# ── Integration axis ──────────────────────────────────────────────────────────
# Wired, never orphaned. Deterministic twin of W4's surface-checklist gate:
# an export nobody consumes and a file nobody imports are integration debt —
# code that exists but isn't reachable from the system around it.
def score_integration(src: str, files: list[Path]) -> tuple[float, list[str], list[str]]:
    findings = []
    improvements = []

    # Entry points are consumed from OUTSIDE the target — exempt from orphan checks.
    def is_entrypoint(f: Path) -> bool:
        rel = str(f)
        return (
            f.name in ("index.ts", "index.tsx", "main.ts", "cli.ts")
            or f.name.endswith((".test.ts", ".test.tsx", ".spec.ts", ".d.ts"))
            or "/pages/" in rel or "/migrations/" in rel or "/commands/" in rel
            or "/generated/" in rel or "/tools/" in rel or "/scripts/" in rel
        )

    # Orphan exports: exported symbols never referenced beyond their declaration.
    exported = set(re.findall(r'export\s+(?:async\s+)?(?:function|const|class|interface|type)\s+(\w+)', src))
    orphans = []
    for name in exported:
        uses = len(re.findall(rf'\b{re.escape(name)}\b', src))
        decls = len(re.findall(rf'export\s+(?:async\s+)?(?:function|const|class|interface|type)\s+{re.escape(name)}\b', src))
        if uses <= decls:
            orphans.append(name)
    orphan_ratio = len(orphans) / len(exported) if exported else 0.0
    if orphans and orphan_ratio > 0.30:
        sample = ", ".join(sorted(orphans)[:5])
        findings.append(f"{len(orphans)}/{len(exported)} exports never referenced in-target (e.g. {sample})")
        improvements.append("wire orphan exports into a caller/surface, re-export from the package barrel, or delete them")

    # Orphan files: no other file in the target imports them (by stem), and they
    # aren't entry points the outside world reaches directly.
    stems_imported = set(re.findall(r"from\s+['\"][^'\"]*/(\w[\w.-]*)['\"]", src))
    orphan_files = [
        f for f in files
        if not is_entrypoint(f) and f.stem not in stems_imported and len(files) > 1
    ]
    if len(orphan_files) > 2:
        sample = ", ".join(str(f.name) for f in orphan_files[:4])
        findings.append(f"{len(orphan_files)} files with no in-target importer (e.g. {sample})")
        improvements.append("register orphan modules (route/nav/barrel) or remove them — reachable, never dangling")

    penalty = 0.0
    if orphan_ratio > 0.30:      penalty += 0.15
    if orphan_ratio > 0.60:      penalty += 0.10
    if len(orphan_files) > 2:    penalty += 0.10
    if len(orphan_files) > 8:    penalty += 0.10

    score = max(0.0, 1.0 - penalty)
    return round(score, 2), findings, improvements


# ── Composite & report ────────────────────────────────────────────────────────
# Weights come from rubric-weights.json — the single source. This script scores a
# PACKAGE source tree, so it has no plan context and goal-fit (0.30) is genuinely
# unavailable: its omission is correct, not drift. What that costs is comparability
# — this number is a BASELINE, never a gate verdict, and it is emitted as
# `composite_partial` so nothing can compare it to a cycle composite that does
# carry goal-fit. See the `package` block in rubric-weights.json.
_WEIGHTS_PATH = Path(__file__).with_name("rubric-weights.json")
try:
    _RUBRIC = json.loads(_WEIGHTS_PATH.read_text())
    WEIGHTS = _RUBRIC["package"]["weights"]
except (OSError, KeyError, json.JSONDecodeError) as e:
    raise SystemExit(f"do-rubric: cannot read {_WEIGHTS_PATH}: {e}")


def composite(scores: dict) -> float:
    """Partial composite over the code axes only, normalised. NOT a gate verdict."""
    total_w = sum(WEIGHTS.values())
    return round(sum(scores[k] * WEIGHTS[k] for k in WEIGHTS) / total_w, 2)


def bar(score: float, width: int = 20) -> str:
    filled = round(score * width)
    color = "\033[92m" if score >= 0.80 else "\033[93m" if score >= 0.65 else "\033[91m"
    reset = "\033[0m"
    return f"{color}{'█' * filled}{'░' * (width - filled)}{reset} {score:.2f}"


def run(target_str: str, as_json: bool = False) -> dict:
    target = ROOT / target_str
    if not target.exists():
        print(f"error: {target} not found", file=sys.stderr)
        sys.exit(1)

    files = collect_ts_files(target)
    if not files:
        print(f"no .ts/.tsx files found under {target}", file=sys.stderr)
        sys.exit(1)

    src = read_all(files)
    slug = target_str.rstrip("/").replace("/", "-").replace(".", "-")

    sec_s,  sec_f,  sec_i  = score_security(src, files)
    sta_s,  sta_f,  sta_i  = score_stability(src, files, target)
    sim_s,  sim_f,  sim_i  = score_simplicity(src, files)
    int_s,  int_f,  int_i  = score_integration(src, files)
    spd_s,  spd_f,  spd_i  = score_speed(src, files)

    scores = {"security": sec_s, "stability": sta_s, "simplicity": sim_s, "integration": int_s, "speed": spd_s}
    comp   = composite(scores)

    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None).isoformat()
    result = {
        "slug":      slug,
        "target":    target_str,
        "scored_at": now,
        "files":     len(files),
        "loc":       src.count("\n"),
        "scores":    scores,
        # `composite` is kept for the existing readers (do-auto.sh writes the W0
        # baseline from it). The two fields beside it say what it actually is, so
        # a reader can tell a partial baseline from a cycle verdict instead of
        # assuming they are the same scale.
        "composite": comp,
        "composite_partial": comp,
        "rubric":    "package",
        "goal_fit_included": False,
        "findings":  {
            "security":    sec_f,
            "stability":   sta_f,
            "simplicity":  sim_f,
            "integration": int_f,
            "speed":       spd_f,
        },
        "improvements": {
            "security":    sec_i,
            "stability":   sta_i,
            "simplicity":  sim_i,
            "integration": int_i,
            "speed":       spd_i,
        },
        "gate": comp >= 0.65,
    }

    if as_json:
        print(json.dumps(result, indent=2))
        return result

    # Pretty print
    gate_sym = "\033[92m✓\033[0m" if result["gate"] else "\033[91m✗\033[0m"
    print(f"\n  CODE RUBRIC — {target_str}  ({len(files)} files · {src.count(chr(10)):,} LOC)\n")
    print(f"  {'AXIS':<14}  SCORE                           WEIGHT")
    print(f"  {'────':<14}  {'──────────────────────':22}  ──────")
    for axis, w in WEIGHTS.items():
        s = scores[axis]
        print(f"  {axis:<14}  {bar(s)}  ×{w:.2f}")
    print(f"\n  {'composite':<14}  {bar(comp)}  {gate_sym} {'PASS' if result['gate'] else 'FAIL'} (≥ 0.65)")

    for axis, items in result["findings"].items():
        if items:
            print(f"\n  ── {axis.upper()} findings ──")
            for f in items:
                print(f"     · {f}")
            impr = result["improvements"][axis]
            for i in impr:
                print(f"       → {i}")

    # Write baseline
    out = TEXT / f"{slug}-w0-rubric.json"
    out.write_text(json.dumps(result, indent=2))
    print(f"\n  baseline written → text/{slug}-w0-rubric.json")
    print(f"  /do {slug} will read this as W0 and measure delta in W4\n")

    return result


def main():
    args = sys.argv[1:]
    as_json = "--json" in args
    args = [a for a in args if a != "--json"]

    if not args or "--help" in args:
        print(__doc__)
        sys.exit(0)

    if "--all" in args:
        packages = ["sync", "channels", "api", "one.ie/web/src/lib", "packages/sdk/src"]
        results = []
        for p in packages:
            try:
                results.append(run(p, as_json=False))
            except SystemExit:
                pass
        if as_json:
            print(json.dumps(results, indent=2))
        return

    run(args[0], as_json=as_json)


if __name__ == "__main__":
    main()
