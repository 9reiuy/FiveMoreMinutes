"""Read-only deep audit (no files modified):

A) 死配置字段: fields declared in demo_config.gd but never referenced anywhere else
   (.gd scripts, .tscn scenes). Indicates doc promises a knob that isn't wired.
B) 内联魔法数字: numeric literals written directly into logic lines in gameplay scripts
   (not const / var / @export declarations, not comments).
C) 场景级参数: numeric properties overridden inside .tscn files.

Usage: python tools/param_usage_audit.py
"""
import os, re, json, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG = os.path.join(ROOT, "scripts", "data", "demo_config.gd")
SKIP_DIRS = {"build", "tmp", "export_templates", "Godot", "backups", ".godot", ".git",
             "5min more", "5min more-backup"}   # nested duplicate copies must be excluded

# ---------- gather files ----------
gd, tscn = [], []
for dp, dns, fns in os.walk(ROOT):
    dns[:] = [d for d in dns if d not in SKIP_DIRS and not d.startswith(".")]
    for f in fns:
        p = os.path.join(dp, f)
        if f.endswith(".gd"): gd.append(p)
        elif f.endswith(".tscn"): tscn.append(p)

def rel(p): return os.path.relpath(p, ROOT).replace("\\", "/")
CONFIG_REL = "scripts/data/demo_config.gd"

def read(p):
    try: return open(p, encoding="utf-8", errors="ignore").read()
    except Exception: return ""

# ---------- A) central config fields ----------
cfg_fields = []          # (name, default, line)
for i, line in enumerate(read(CONFIG).splitlines(), 1):
    s = line.strip()
    if not ("@export" in s or s.startswith("var ")): continue
    m = re.search(r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)", s)
    if not m: continue
    d = re.search(r"=\s*(-?[0-9][0-9_.]*)", s)
    cfg_fields.append((m.group(1), d.group(1) if d else "", i))
cfg_names = {n for n, _, _ in cfg_fields}
print(f"config fields: {len(cfg_fields)}   gd files: {len(gd)}   tscn files: {len(tscn)}")

# ---------- token frequency across all other files ----------
tok = collections.Counter()
for p in gd + tscn:
    if rel(p) == CONFIG_REL: continue
    txt = read(p)
    for w in re.findall(r"[A-Za-z_][A-Za-z0-9_]*", txt):
        tok[w] += 1

dead = [(n, d, i) for (n, d, i) in cfg_fields if tok.get(n, 0) == 0]
print(f"\n=== A) 死配置字段（声明了但其它 .gd/.tscn 从未引用）: {len(dead)} ===")
for n, d, i in dead:
    print(f"  {n:52s} default={d or '-':>9s}  (config line {i})")

# ---------- B) inline magic numbers in gameplay scripts ----------
GAMEPLAY_DIRS = ("scripts/entities", "scripts/dream", "scripts/systems", "scripts/weapons", "scripts/combat")
NUM = re.compile(r"(?<![\w.])(\d+\.\d+|\.\d+|\d+)(?![\w.])")
decl = re.compile(r"^\s*(?:@export(?:\([^)]*\))?\s+)?(?:const|var|enum|signal|class|func|static func)\b|^\s*(?:if|for|while|return|elif|else|break|continue|pass|extends|class_name|@\w+)")
KEYWORD = re.compile(r"(damage|speed|cooldown|duration|interval|radius|range|distance|health|hp|chance|"
                     r"weight|threshold|margin|limit|cap|count|delay|rate|time|timer|scale|angle|"
                     r"impulse|strength|amount|alpha|width|height|length|offset|multiplier|probab)", re.I)

mag = []
for p in gd:
    r = rel(p)
    if r == CONFIG_REL: continue
    if not r.startswith(GAMEPLAY_DIRS): continue
    for i, line in enumerate(read(p).splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("#"): continue
        if decl.match(s): continue                 # skip declarations
        if "=" not in s and not re.search(r"[<>]=?|==|!=", s): continue
        if not KEYWORD.search(s): continue
        nums = NUM.findall(s)
        if not nums: continue
        # skip pure 0/1 booleans and index-ish small ints on their own
        sig = [n for n in nums if n not in ("0", "1", "2")]
        if not sig: continue
        mag.append((r, i, s[:110], sig[:4]))

print(f"\n=== B) 内联魔法数字候选（gameplay 脚本逻辑行）: {len(mag)} ===")
for r, i, s, sig in mag[:60]:
    print(f"  {r}:{i}  [{','.join(sig)}]  {s}")

# ---------- C) scene-level numeric overrides ----------
scene_props = []
for p in tscn:
    for i, line in enumerate(read(p).splitlines(), 1):
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_/]*)\s*=\s*(-?[0-9][0-9_.]*)\s*$", line.strip())
        if m and KEYWORD.search(m.group(1)):
            scene_props.append((rel(p), i, m.group(1), m.group(2)))
print(f"\n=== C) .tscn 场景级数值参数: {len(scene_props)} ===")
byname = collections.defaultdict(set)
for r, i, n, v in scene_props:
    byname[n].add(v)
for n in sorted(byname):
    vals = sorted(byname[n])
    print(f"  {n:44s} = {','.join(vals)}")

json.dump({
    "dead_config_fields": [{"name": n, "default": d, "line": i} for n, d, i in dead],
    "inline_magic": [{"file": r, "line": i, "code": s, "nums": sig} for r, i, s, sig in mag],
    "scene_params": [{"file": r, "line": i, "name": n, "value": v} for r, i, n, v in scene_props],
}, open(os.path.join(ROOT, "tools", "param_usage_audit.json"), "w", encoding="utf-8"),
    ensure_ascii=False, indent=1)
print("\nwrote tools/param_usage_audit.json")
