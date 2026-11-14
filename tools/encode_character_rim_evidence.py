"""Arrange actual Camera captures only. No recolouring or synthetic rendering."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / '.runtime/character_rim_20261113/extended'
OUT = ROOT / '.runtime/character_rim_20261113/delivery'
OUT.mkdir(parents=True, exist_ok=True)
FONT = ROOT / 'assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf'
font = ImageFont.truetype(str(FONT), 24)
small = ImageFont.truetype(str(FONT), 12)
BG = '#111a24'
INK = '#dae5f0'

def canvas(size):
    return Image.new('RGB', size, BG)

overview = canvas((1288, 410))
d = ImageDraw.Draw(overview)
d.text((12, 9), '原版', font=font, fill=INK)
d.text((660, 9), '轮廓受光小样', font=font, fill=INK)
for x, name in [(0, 'overall_before'), (648, 'overall_after')]:
    overview.paste(Image.open(SOURCE / f'{name}.png').convert('RGB'), (x, 42))
overview.save(OUT / 'camera_comparison.png')

# Fixed source-pixel crop contains player and enemy, including extended guns.
# Integer Nearest zoom only. No edge drawing, bloom or colour edits.
crop = (264, 52, 420, 200)
frames = []
for i in range(120):
    frame = canvas((952, 504))
    d = ImageDraw.Draw(frame)
    d.text((12, 8), '原版', font=font, fill=INK)
    d.text((490, 8), '轮廓受光小样', font=font, fill=INK)
    for x, name in [(0, 'before'), (484, 'after')]:
        image = Image.open(SOURCE / 'motion' / f'{name}_{i:03}.png').convert('RGB')
        frame.paste(image.crop(crop).resize((468, 444), Image.Resampling.NEAREST), (x, 42))
    light = '左侧冷光' if i < 80 else ('右侧冷光' if i < 100 else '背后冷光')
    d.text((12, 487), f'实际 Camera / 原有动作 1x 时间轴 / 20fps / Nearest 3x 局部放大 / {light}', font=small, fill=INK)
    frames.append(frame)
frames[0].save(OUT / 'walk_eight_directions_bangs_fixed_1x.gif', save_all=True,
               append_images=frames[1:], duration=50, loop=0, optimize=False, disposal=2)
frames[0].save(OUT / 'detail_comparison.png')

previous = ROOT / '.runtime/character_rim_20261113/bangs_correction/before'
if previous.exists():
    comparison = canvas((1296, 388))
    d = ImageDraw.Draw(comparison)
    labels = ['正面', '左下', '左侧', '左上', '背面', '右上', '右侧', '右下']
    d.text((8, 6), '旧录制：头部已转向，刘海未同步', font=small, fill=INK)
    d.text((8, 198), '修正后：使用正式刘海更新，原定位与贴图不变', font=small, fill=INK)
    for n, i in enumerate(range(0, 80, 10)):
        d.text((n*162+6, 24), labels[n], font=small, fill=INK)
        d.text((n*162+6, 216), labels[n], font=small, fill=INK)
        for y, path in [(40, previous / f'after_{i:03}.png'),
                        (232, SOURCE / 'motion' / f'after_{i:03}.png')]:
            image = Image.open(path).convert('RGB')
            comparison.paste(image.crop((270,114,350,190)).resize((160,152),Image.Resampling.NEAREST), (n*162,y))
    comparison.save(OUT / 'bangs_alignment_corrected.png')
print(OUT)
