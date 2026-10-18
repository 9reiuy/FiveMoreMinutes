"""Actual Camera frames; normal speed preserves recorded timestamps."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

source = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1] / '.runtime/nyangeon_vfx_sample_20261016/camera_final'
report = json.loads((source / 'report.json').read_text(encoding='utf-8'))
output = Path(sys.argv[2]).resolve() if len(sys.argv)>2 else source.parent / 'delivery'
output.mkdir(exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 18)
names = {'walk_stop': '玩家与敌人走动、停下', 'fire_basic': '手枪开火与命中',
         'fire_assault_rifle': '步枪开火与命中', 'fire_shotgun': '霰弹枪开火与命中',
         'lethal_hit': '致死命中', 'enemy_fire': '敌人开火', 'hall_walk': '塔罗大厅脚步烟雾'}
montage, montage_slow, montage_time, montage_slow_time = [], [], [], []

def labelled(im, text):
    canvas = Image.new('RGB', (im.width, im.height + 30), '#171b22')
    canvas.paste(im, (0, 30))
    ImageDraw.Draw(canvas).text((10, 3), text, font=font, fill='#f0eede')
    return canvas

for label in names:
    samples = report['clips'][label]
    normal, detail = [], []
    for sample in samples:
        with Image.open(source / sample['file']) as im:
            normal.append(im.convert('RGB').resize((960, 540), Image.Resampling.NEAREST))
            # Unwarped fixed crop of the gameplay Camera, not a separate camera.
            region = (500, 120, 1460, 840) if label != 'hall_walk' else (500, 160, 1460, 880)
            detail.append(im.convert('RGB').crop(region))
    durations = [max(20, round((b['seconds'] - a['seconds']) * 100) * 10)
                 for a, b in zip(samples, samples[1:])]
    durations.append(600)
    normal = [labelled(im, '正常速度｜' + names[label]) for im in normal]
    slow = [labelled(im, '三倍慢放 · 原游戏摄像机局部｜' + names[label]) for im in detail]
    normal[0].save(output / f'{label}.gif', save_all=True, append_images=normal[1:],
                   duration=durations, loop=0, optimize=False, disposal=2)
    slow[0].save(output / f'{label}_slow_3x.gif', save_all=True, append_images=slow[1:],
                   duration=[x * 3 for x in durations[:-1]] + [600], loop=0, optimize=False, disposal=2)
    if label in ('fire_basic', 'fire_assault_rifle', 'fire_shotgun', 'lethal_hit'):
        montage.extend([labelled(im, '正常速度 · 原游戏摄像机局部｜' + names[label]) for im in detail])
        montage_slow.extend(slow)
        montage_time.extend(durations)
        montage_slow_time.extend([x * 3 for x in durations[:-1]] + [600])
for name, frames, times in [('gun_hit', montage, montage_time), ('gun_hit_slow_3x', montage_slow, montage_slow_time)]:
    frames[0].save(output / f'{name}.gif', save_all=True, append_images=frames[1:],
                   duration=times, loop=0, optimize=False, disposal=2)
print(json.dumps({'checks': report['checks'], 'failures': report['failures'],
                  'metrics': report['metrics'], 'output': str(output)}, ensure_ascii=False))
