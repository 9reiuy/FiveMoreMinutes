"""Arrange unchanged actual Camera frames for the promoted actor rim report."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
source = root / '.runtime/character_rim_promotion_20261113'
out = source / 'delivery'
out.mkdir(parents=True, exist_ok=True)
font_path = root / 'assets/fonts/fusion_pixel/fusion-pixel-12px-proportional-zh_hans.ttf'
font = ImageFont.truetype(str(font_path), 24)
small = ImageFont.truetype(str(font_path), 12)

comparison = Image.new('RGB', (888, 398), '#111a24')
draw = ImageDraw.Draw(comparison)
for x, name, label in [(0, 'both_lights_after', '红、蓝两灯同时照射'),
                        (453, 'red_blocked_blue_visible_after', '红灯被遮挡，蓝灯仍照射')]:
    image = Image.open(source / 'native' / (name+'.png')).convert('RGB')
    comparison.paste(image.crop((270,70,415,185)).resize((435,345),Image.Resampling.NEAREST),(x,40))
    draw.text((x+6,6),label,font=font,fill='#dae5f0')
draw.text((6,385),'实际 Camera / 真实灯光与阴影 / Nearest 3x 局部放大，未对截图调色',font=small,fill='#dae5f0')
comparison.save(out / 'multilight_and_occlusion.png')

frames=[]
for i in range(120):
    frame=Image.new('RGB',(952,504),'#111a24')
    draw=ImageDraw.Draw(frame)
    for x, name, label in [(0,'before','原版'),(484,'after','正式角色受光')]:
        image=Image.open(source/'animation/motion'/f'{name}_{i:03}.png').convert('RGB')
        frame.paste(image.crop((264,52,420,200)).resize((468,444),Image.Resampling.NEAREST),(x,42))
        draw.text((x+12,8),label,font=font,fill='#dae5f0')
    draw.text((12,487),'实际 Camera / 原动作 1x 时间轴 / 20fps / 刘海同步 / Nearest 3x 放大',font=small,fill='#dae5f0')
    frames.append(frame)
frames[0].save(out/'eight_directions_normal.gif',save_all=True,append_images=frames[1:],duration=50,loop=0,optimize=False,disposal=2)
print(out)
