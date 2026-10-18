"""Package timestamped, actual Main Camera captures without speeding up loading."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

source = Path(sys.argv[1]).resolve()
report = json.loads((source / 'report.json').read_text(encoding='utf-8'))
output = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else source.parent / 'delivery'
output.mkdir(exist_ok=True)
clips = report['clips']

def picture(sample, width=960):
    im = Image.open(source / sample['file']).convert('RGB')
    return im.resize((width, round(im.height * width / im.width)), Image.Resampling.NEAREST)

def save(name, frames, durations):
    frames[0].save(output / name, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=False, disposal=2)

for name in ('after', 'reception', 'game_entry', 'elevator'):
    samples = clips[name]
    durations = [max(20, round((b['seconds'] - a['seconds']) * 1000 / 10) * 10)
                 for a, b in zip(samples, samples[1:])]
    # Only the final still is held for readability; active transitions retain real time.
    durations.append(700)
    save(name + '.gif', [picture(sample) for sample in samples], durations)

frames = []
end = max(clips['before'][-1]['seconds'], clips['after'][-1]['seconds'])
for tick in range(int(end / .05) + 1):
    now = tick * .05
    canvas = Image.new('RGB', (1280, 388), '#16191f')
    draw = ImageDraw.Draw(canvas)
    for col, name, label in ((0, 'before', 'BEFORE - triangle overlay'),
                              (1, 'after', 'AFTER - 4px pixel blocks')):
        sample = next((s for s in reversed(clips[name]) if s['seconds'] <= now), clips[name][0])
        canvas.paste(picture(sample, 640), (col * 640, 28))
        draw.text((col * 640 + 12, 8), label, fill='#eeeeee')
    frames.append(canvas)
save('comparison.gif', frames, [50] * (len(frames) - 1) + [700])
print(json.dumps({'output': str(output), 'checks': report['checks'],
                  'failures': report['failures'], 'timings': report['timings']}, ensure_ascii=False))
