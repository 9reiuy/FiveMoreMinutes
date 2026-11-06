"""Package real Camera screenshots and wall-clock paced walking frames."""
from pathlib import Path
import json
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.runtime/coast_spatial_lighting_20261030'
if '--city' in sys.argv:
    OUT = ROOT / '.runtime/coast_city_cliff_20261030'
comparison = Image.new('RGB', (1280, 384), '#10151f')
for index, (phase, label) in enumerate([('before', 'BEFORE'), ('after', 'AFTER / REAL CAMERA')]):
    comparison.paste(Image.open(OUT / phase / 'approach.png').convert('RGB'), (640 * index, 24))
    ImageDraw.Draw(comparison).text((640 * index + 12, 7), label, fill='#d9e3ee')
comparison.save(OUT / 'lighting_comparison.png')

records = json.loads((OUT / 'walk/timing.json').read_text(encoding='utf-8'))
frames = []
for index in range(len(records)):
    image = Image.new('RGB', (640, 384), '#10151f')
    image.paste(Image.open(OUT / f'walk/frame_{index:04d}.png').convert('RGB'), (0, 24))
    ImageDraw.Draw(image).text((12, 7), 'ACTUAL CHAPTER CAMERA / NORMAL SPEED', fill='#d9e3ee')
    frames.append(image)
palette_source = Image.new('RGB', (640, 384 * 12))
for index in range(12):
    palette_source.paste(frames[min(len(frames) - 1, index * len(frames) // 12)], (0, 384 * index))
palette = palette_source.quantize(colors=256)
encoded = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
durations = []
for index, record in enumerate(records):
    end = records[index + 1]['time_ms'] if index + 1 < len(records) else record['time_ms'] + 67
    durations.append(max(10, round(end / 10) * 10 - round(record['time_ms'] / 10) * 10))
encoded[0].save(OUT / 'walking_normal.gif', save_all=True, append_images=encoded[1:], duration=durations, loop=0, disposal=2, optimize=False)
print(json.dumps({'frames': len(frames), 'gif_duration_ms': sum(durations), 'source_time_span_ms': records[-1]['time_ms'] - records[0]['time_ms']}, indent=2))

if '--city' in sys.argv:
    signal_records = json.loads((OUT / 'signal/timing.json').read_text(encoding='utf-8'))
    signal_frames = []
    red_states = []
    beacon_colors = set()
    for index, record in enumerate(signal_records):
        source = Image.open(OUT / f'signal/frame_{index:04d}.png').convert('RGB')
        candidates = [(r,g,b) for r,g,b in source.crop((280,0,350,50)).getdata() if r>23 and r>g*2 and r>b*1.5]
        peak_color = max(candidates,key=lambda rgb:rgb[0],default=(0,0,0))
        peak = peak_color[0]
        if peak>23: beacon_colors.add(peak_color)
        red_states.append(peak > 23)
        canvas = Image.new('RGB', (840,274), '#10151f')
        canvas.paste(source.crop((80,0,500,125)).resize((840,250), Image.Resampling.NEAREST),(0,24))
        ImageDraw.Draw(canvas).text((12,7),'ACTUAL CAMERA CROP x2 / NORMAL SPEED / ROOFTOP MORSE',(217,227,238))
        signal_frames.append(canvas)
    # Tiny lamps occupy too few pixels for a generic median-cut palette.
    # Reserve their real captured peak colours; otherwise GIF encoding can
    # erase a correctly rendered Morse flash. Never paint extra lamp pixels.
    palette_atlas = Image.new('RGB',(840,274*8))
    for row in range(8):
        palette_atlas.paste(signal_frames[min(len(signal_frames)-1,row*len(signal_frames)//8)],(0,row*274))
    background_palette = palette_atlas.quantize(colors=224).getpalette()[:224*3]
    peaks = sorted(beacon_colors,key=lambda rgb:rgb[0])
    if len(peaks)>32: peaks=[peaks[round(i*(len(peaks)-1)/31)] for i in range(32)]
    palette_values = background_palette+[channel for color in peaks for channel in color]
    palette_values += [0]*(768-len(palette_values))
    signal_palette=Image.new('P',(1,1)); signal_palette.putpalette(palette_values)
    signal_encoded = [im.quantize(palette=signal_palette,dither=Image.Dither.NONE) for im in signal_frames]
    signal_durations = []
    for index, record in enumerate(signal_records):
        end = signal_records[index+1]['time_ms'] if index+1<len(signal_records) else record['time_ms']+67
        signal_durations.append(max(10,round(end/10)*10-round(record['time_ms']/10)*10))
    signal_encoded[0].save(OUT/'roof_signal_normal.gif',save_all=True,append_images=signal_encoded[1:],duration=signal_durations,loop=0,disposal=2,optimize=False)
    flashes = sum(on and (index==0 or not red_states[index-1]) for index,on in enumerate(red_states))
    print(json.dumps({'signal_frames':len(signal_frames),'roof_flashes_in_live_capture':flashes,'duration_ms':sum(signal_durations)}))
