"""Package real camera output and count only the exact reserved effect inks."""
from pathlib import Path
import json
from PIL import Image

base = Path(__file__).resolve().parents[2] / ".runtime/phase_dash_20261022"
inks = [(12,236,188),(65,110,246),(162,65,246),(245,62,149),(245,191,62)]
for folder in sorted(base.glob("color_live*")):
    if not folder.is_dir() or not (folder / "result.json").exists():
        continue
    count = json.loads((folder / "result.json").read_text(encoding="utf-8"))["captures"]
    frames = [Image.open(folder / f"frame_{i:02d}.png").convert("RGB") for i in range(count)]
    if not frames:
        continue
    totals = [0]*5
    for frame in frames:
        colors = frame.getcolors(frame.width*frame.height)
        for n, c in colors:
            for i, ink in enumerate(inks):
                if sum((c[k]-ink[k])**2 for k in range(3))<=36:
                    totals[i] += n
    frames[0].save(folder / "color_dash.gif",save_all=True,append_images=frames[1:],duration=65,loop=0)
    (folder / "ink_counts.json").write_text(json.dumps(dict(zip(map(str, inks),totals)),indent=2),encoding="utf-8")
    print(folder.name, "reserved_ink_pixels", totals)
