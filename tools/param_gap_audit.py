"""Read-only audit: find gameplay numeric parameters that are NOT centralized in demo_config.gd.

Scans all .gd scripts for named numeric constants / exports / vars whose names look
gameplay-tunable, and reports those absent from the central config.

Does NOT modify anything (project rule: 严禁直接动手).
"""
import os, re, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "scripts", "data", "demo_config.gd")

# 1) collect central config field names
cfg = set()
if os.path.exists(CONFIG):
    for line in open(CONFIG, encoding="utf-8", errors="ignore"):
        s = line.strip()
        # any @export... var NAME  or plain  var NAME
        m = re.search(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)", s)
        if m and ("@export" in s or s.startswith("var ")):
            cfg.add(m.group(1))
print("central config fields:", len(cfg))

KEY = re.compile(
    r"(damage|speed|cooldown|duration|interval|radius|count|hp|health|chance|multiplier|"
    r"distance|range|weight|probab|time|seconds|margin|threshold|limit|cap|target|"
    r"delay|rate|scale|alpha|offset|width|height|length|strength|amount|value|xp|exp|"
    r"ammo|reload|spread|knockback|angle|impulse|mass|energy|zoom|fps|rows|cols|depth)",
    re.I)

NUM = re.compile(r"^-?\d+(?:\.\d+)?$")

found = []   # (file, line, name, value, kind)
gd_files = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in
                   ("build", "tmp", "export_templates", "Godot", ".godot", "backups")]
    for f in filenames:
        if f.endswith(".gd"):
            gd_files.append(os.path.join(dirpath, f))
print("gd files:", len(gd_files))

for path in gd_files:
    rel = os.path.relpath(path, ROOT)
    if rel.replace("\\", "/").endswith("scripts/data/demo_config.gd"):
        continue
    try:
        lines = open(path, encoding="utf-8", errors="ignore").read().splitlines()
    except Exception:
        continue
    for i, line in enumerate(lines, 1):
        s = line.strip()
        if s.startswith("#"): continue
        # const NAME = <num>   /  var NAME = <num>  /  @export var NAME = <num>
        m = re.match(r"^(?:@export(?:\([^)]*\))?\s+)?(?:const|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*[\w\[\]]+)?\s*=\s*([-0-9][0-9_.]*)", s)
        if not m: continue
        name, val = m.group(1), m.group(2)
        if not NUM.match(val): continue
        try: fv = float(val)
        except Exception: continue
        if not KEY.search(name): continue
        if name in cfg: continue
        kind = "const" if "const " in s else ("export" if s.startswith("@export") else "var")
        found.append((rel, i, name, val, kind))

# group by name (dedupe: same name in several files)
byname = {}
for rel, i, name, val, kind in found:
    byname.setdefault(name, []).append((rel, i, val, kind))

print("\n=== named numeric params NOT in central config (gameplay-ish) ===")
print("total distinct:", len(byname))
out = []
for name in sorted(byname):
    occ = byname[name]
    vals = sorted({o[2] for o in occ})
    files = sorted({o[0] for o in occ})
    out.append({
        "name": name,
        "values": vals,
        "files": files,
        "kind": occ[0][3],
        "lines": [o[1] for o in occ][:5],
    })
    if len(vals) == 1:
        print(f"  {name:44s} = {vals[0]:>10s}   [{occ[0][3]}] {files[0]}")
    else:
        print(f"  {name:44s} = {str(vals)[:40]:>10s}  [{occ[0][3]}] {files[0]} (+{len(files)-1} files)")

json.dump(out, open(os.path.join(ROOT, "tools", "param_gap_audit.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print("\nwrote tools/param_gap_audit.json")
