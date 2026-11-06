"""Assemble actual Camera captures, preserving recorded wall-clock playback."""
import json
from bisect import bisect_right
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '.runtime/shared_wall_dash_20261102'
FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 20)
SMALL = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 16)
CASES = [
    ('wall', '墙体：碎块与持续缺口'),
    ('door', '门：原材质碎块与扬尘'),
    ('glass', '玻璃：顶部框随整格移除'),
    ('fixture', '挂墙装饰：随支撑墙清理'),
]

def panel(case, title, frame):
    result = Image.new('RGB', (640, 392), '#101421')
    ImageDraw.Draw(result).text((12, 4), title, font=FONT, fill='#d9e6f4')
    result.paste(frame, (0, 32))
    return result

def main():
    clocks = json.loads((OUT / 'final_clips.json').read_text(encoding='utf8'))
    clips = []
    comparison = Image.new('RGB', (1280, len(CASES) * 392 + 32), '#101421')
    ImageDraw.Draw(comparison).text((12, 4), '实际游戏 Camera｜左：破坏前；右：破坏后', font=FONT, fill='#d9e6f4')
    for row, (case, title) in enumerate(CASES):
        times = clocks[f'final_{case}_motion']
        times = [value - times[0] for value in times]
        frames = [Image.open(OUT / f'final_{case}_motion/{i:03d}.png').convert('RGB') for i in range(len(times))]
        before = Image.open(OUT / f'final_{case}_before.png').convert('RGB')
        after = Image.open(OUT / f'final_{case}_after.png').convert('RGB')
        clips.append((case, title, times, frames, before, after))
        comparison.paste(panel(case, title, before), (0, 32 + row * 392))
        comparison.paste(panel(case, title, after), (640, 32 + row * 392))
    comparison.save(OUT / 'before_after_review.png')
    duration = max(clip[2][-1] for clip in clips) + 1000
    output = []
    for tick in range(0, duration, 80):
        canvas = Image.new('RGB', (1280, 816), '#101421')
        ImageDraw.Draw(canvas).text((12, 4), '实际 Camera｜按录制时间播放，无慢放；截图过程会影响帧间隔', font=SMALL, fill='#bdcde4')
        for index, (case, title, times, frames, before, after) in enumerate(clips):
            elapsed = tick - 400
            frame = before if elapsed < 0 else after if elapsed > times[-1] else frames[max(0, bisect_right(times, elapsed)-1)]
            canvas.paste(panel(case, title, frame), ((index % 2)*640, 32+(index//2)*392))
        output.append(canvas)
    output[0].save(OUT / 'destruction_review.gif', save_all=True, append_images=output[1:], duration=80, loop=0, optimize=False)
    print(json.dumps({'frames': len(output), 'duration_ms': len(output)*80, 'gif': str(OUT / 'destruction_review.gif')}, ensure_ascii=False))

if __name__ == '__main__':
    main()
