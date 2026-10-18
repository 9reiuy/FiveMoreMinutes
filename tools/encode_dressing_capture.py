"""Encode muted runtime image samples; does not alter game assets."""
from pathlib import Path
import sys
from PIL import Image

directory = Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1] / '.runtime' / 'room_dressing'
pattern = sys.argv[2] if len(sys.argv)>2 else 'motion_*.png'
output_name = sys.argv[3] if len(sys.argv)>3 else 'dressing_movement.gif'
frames = []
for source in sorted(directory.glob(pattern)):
    with Image.open(source) as image:
        frames.append(image.resize((640, 360), Image.Resampling.NEAREST).convert('P', palette=Image.Palette.ADAPTIVE, colors=256))
if not frames:
    raise SystemExit('No runtime samples')
frames[0].save(directory / output_name, save_all=True, append_images=frames[1:], duration=33, loop=0, optimize=False)
print(f'Encoded {len(frames)} movement samples (illustrative playback, not a performance recording).')
