"""Update only the independent Windows preset from the audited resource list."""
import json
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / ".runtime/prologue_export_20261111/resources.json").read_text(encoding="utf-8"))
if manifest["missing"]:
    raise SystemExit(f"Required resources are missing: {manifest['missing']}")
validation = "--validation" in sys.argv
template = Path(sys.argv[sys.argv.index("--template") + 1])
config_path = root / "export_presets.cfg"
original = config_path.read_text(encoding="utf-8")
parts = re.split(r"(?m)(?=^\[preset\.\d+(?:\.options)?\]\s*$)", original)
index = None
for part in parts:
    if re.search(r'^name="PrologueWindows"$', part, re.M):
        index = int(re.match(r"\[preset\.(\d+)\]", part)[1])
if index is None:
    index = max(map(int, re.findall(r"(?m)^\[preset\.(\d+)\]", original)), default=-1) + 1
else:
    parts = [p for p in parts if not re.match(rf"\[preset\.{index}(?:\.options)?\]", p)]
quote = lambda value: json.dumps(str(value), ensure_ascii=False)
selected = [path for path in manifest["files"] if validation or path != "res://scripts/testing/prologue_package_validation.gd"]
files = ", ".join(quote(path) for path in selected)
features = "prologue_demo,prologue_validation" if validation else "prologue_demo"
exclusions = "tests/*,.runtime/*,build/*,docs/*,export_templates/*"
if not validation:
    exclusions += ",scripts/testing/prologue_package_validation.gd"
section = f'''
[preset.{index}]

name="PrologueWindows"
platform="Windows Desktop"
dedicated_server=false
custom_features="{features}"
export_filter="resources"
export_files=PackedStringArray({files})
include_filter="data/*,assets/fonts/boutique_bitmap/OFL-*.txt,assets/fonts/fusion_pixel/OFL.txt"
exclude_filter="{exclusions}"
export_path="build/Prologue_0-1_0-6_Windows/FiveMinuteMore_Prologue.exe"
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.{index}.options]

custom_template/debug=""
custom_template/release={quote(template.as_posix())}
debug/export_console_wrapper=0
binary_format/embed_pck=false
binary_format/architecture="x86_64"
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
shader_baker/enabled=false
codesign/enable=false
application/modify_resources=true
application/file_version="0.5.0"
application/product_version="0.5.0"
application/product_name="FiveMinuteMore Prologue"
application/file_description="Standalone chapter 0-1 to 0-6"
application/company_name=""
application/export_angle=0
application/export_d3d12=0
'''
config_path.write_text("".join(parts).rstrip() + "\n" + section, encoding="utf-8")
print(f"Preset {index}: {len(selected)} resources, {manifest['bytes'] / 1024**2:.1f} MiB audited source assets, features={features}")
if manifest.get("unresolved_literals"):
    print("Optional literal paths for review: " + ", ".join(manifest["unresolved_literals"]))
