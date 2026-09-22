import json, pathlib, sys
# Patch the ASTRO-GENERATED config (which carries `main` + the assets binding)
# rather than hand-rolling one: wrangler.toml omits `main` by design, so a
# standalone copy deploys as an assets-only Worker and is rejected.
p = pathlib.Path("dist/server/wrangler.json")
if not p.exists():
    print("[gen-dev-config] FATAL: dist/server/wrangler.json missing - build first"); sys.exit(1)
c = json.loads(p.read_text())
c["name"] = "one-dev"
c["routes"] = [{"pattern": "dev.one.ie", "custom_domain": True}]
# STRIP CRONS. The dev worker shares production's D1/KV bindings, so inheriting
# prod's schedules means TWO workers running the same handlers against the same
# rows - double sends, double syncs, races. Dev observes prod data; it must not
# also drive prod's clock. (Measured 2026-08-25: the first dev deploy shipped
# 6 schedules including */5 * * * *.)
for k in ("triggers", "crons"):
    c.pop(k, None)
out = pathlib.Path("dist/server/wrangler.dev.json")
out.write_text(json.dumps(c, indent=2))
print(f"[gen-dev-config] {out} -> name={c['name']} routes={c['routes']} main={c.get('main')}")
