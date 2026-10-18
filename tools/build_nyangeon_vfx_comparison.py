"""Two real Main captures, same seeded office and route; not pixel-identical replay."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

base = Path(__file__).resolve().parents[1] / '.runtime/nyangeon_vfx_sample_20261016'
before, after = base / 'camera_variation', base / 'camera_strong'
old = json.loads((before / 'report.json').read_text(encoding='utf-8'))
new = json.loads((after / 'report.json').read_text(encoding='utf-8'))
out = base / 'delivery_strong'
out.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 19)

def frame(folder, samples, time):
    sample = next((s for s in reversed(samples) if s['seconds'] <= time), samples[0])
    return Image.open(folder / sample['file']).convert('RGB').crop((560,150,1400,780))

def save(name, frames, durations):
    frames[0].save(out / name, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=False, disposal=2)

for key, title in [('walk_stop', '脚步烟雾：大小与疏密'), ('fire_assault_rifle', '枪击命中：白色亮斑与扩散')]:
    samples_old, samples_new = old['clips'][key], new['clips'][key]
    end = min(samples_old[-1]['seconds'], samples_new[-1]['seconds'])
    for multiplier, suffix in [(1, 'normal'), (3, 'slow_3x')]:
        frames = []
        for tick in range(round(end / .05) + 1):
            seconds = tick * .05
            canvas = Image.new('RGB', (1680, 690), '#171b22')
            canvas.paste(frame(before, samples_old, seconds), (0, 60))
            canvas.paste(frame(after, samples_new, seconds), (840, 60))
            draw = ImageDraw.Draw(canvas)
            speed = '正常速度' if multiplier == 1 else '三倍慢放'
            draw.text((12, 4), f'{speed}｜{title}｜左：上一版    右：本次', font=font, fill='#f0eede')
            draw.text((12, 31), '同一生成场景、同一路线，两次独立实机录制；按各段时间戳对齐', font=font, fill='#aeb5c2')
            frames.append(canvas)
        save(f'compare_{key}_{suffix}.gif', frames, [50 * multiplier] * (len(frames) - 1) + [800])
print(str(out))
