"""Package actual muted game-camera captures, not an asset transformation."""
from pathlib import Path
from PIL import Image

folder = Path(__file__).resolve().parents[1] / ".runtime" / "face_art"
frames = []
for path in sorted(folder.glob("frame_*.png")):
    with Image.open(path) as frame:
        frames.append(frame.convert("RGB"))
if not frames:
    raise SystemExit("No runtime frames")
frames[0].save(folder / "face_room_motion.gif", save_all=True,
               append_images=frames[1:], duration=100, loop=0, optimize=False)
print(f"Packaged {len(frames)} silent runtime frames")
