"""Package actual Camera readbacks using their recorded wall-clock timing."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.runtime/projectile_history_projection_20261030'
timing = json.loads((OUT / 'live/timing.json').read_text(encoding='utf-8'))
records = timing['frames']
frames = []
for index, record in enumerate(records):
    source = Image.open(OUT / f'live/frame_{index:04d}.png').convert('RGB')
    canvas = Image.new('RGB', (640, 384), '#10151f')
    canvas.paste(source, (0, 24))
    ImageDraw.Draw(canvas).text((12, 7), f'ACTUAL CAMERA / NORMAL SPEED / {record["label"]}', fill='#d4e2ee')
    frames.append(canvas)
durations = []
for index in range(len(records)):
    # Round cumulative boundaries, so 33ms frames do not all become 30ms
    # (which would speed the review up by about 10 percent).
    boundary = records[index]['time_ms'] - records[0]['time_ms']
    next_boundary = records[index + 1]['time_ms'] - records[0]['time_ms'] if index + 1 < len(records) else boundary + 34
    durations.append(max(10, (round(next_boundary / 10) - round(boundary / 10)) * 10))
sample_indices = list(range(0, len(frames), max(1, len(frames) // 12)))
atlas = Image.new('RGB', (640, 384 * len(sample_indices)))
for row, index in enumerate(sample_indices):
    atlas.paste(frames[index], (0, 384 * row))
palette = atlas.quantize(colors=256)
converted = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
converted[0].save(OUT / 'actual_fire_normal.gif', save_all=True, append_images=converted[1:], duration=durations, loop=0, disposal=2, optimize=False)
# A separate zoom keeps the short-lived pixels legible without slowing time.
zoom_frames = []
for index, record in enumerate(records):
    source = Image.open(OUT / f'live/frame_{index:04d}.png').convert('RGB')
    canvas = Image.new('RGB', (440, 354), '#10151f')
    canvas.paste(source.crop((230, 85, 450, 250)).resize((440, 330), Image.Resampling.NEAREST), (0, 24))
    ImageDraw.Draw(canvas).text((8, 7), f'CAMERA CROP x2 / NORMAL SPEED / {record["label"]}', fill='#d4e2ee')
    zoom_frames.append(canvas.quantize(palette=palette, dither=Image.Dither.NONE))
zoom_frames[0].save(OUT / 'actual_fire_crop_normal.gif', save_all=True, append_images=zoom_frames[1:], duration=durations, loop=0, disposal=2, optimize=False)
print(json.dumps({'frames': len(frames), 'wall_clock_ms': records[-1]['time_ms'] - records[0]['time_ms'], 'gif_duration_ms': sum(durations), 'fired': timing['fired'], 'gpu_checks': timing['checks']}, indent=2))
