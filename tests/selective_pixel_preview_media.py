"""Package captured gameplay frames; does not generate or modify game assets."""
from pathlib import Path
from PIL import Image

runtime = Path(__file__).resolve().parents[1] / ".runtime"
frames = []
for path in sorted((runtime / "unified_pixel_clip").glob("frame_*.png")):
    with Image.open(path) as image:
        frames.append(image.resize((960, 540), Image.Resampling.NEAREST).convert("RGB"))
if not frames:
    raise SystemExit("Capture frames are missing")
frames[0].save(runtime / "unified_pixel_movement_shooting.gif", save_all=True,
               append_images=frames[1:], duration=100, loop=0, optimize=False)
print(f"Packed {len(frames)} silent frames")
