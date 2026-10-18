"""Package actual Main Camera captures, preserving wall-clock animation timing."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '.runtime/phone_tab_20261018'
SOURCE = BASE / 'camera_release'
OUT = BASE / 'delivery'
OUT.mkdir(parents=True, exist_ok=True)
FONT = ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc', 17)
REPORT = json.loads((SOURCE / 'report.json').read_text(encoding='utf-8'))

def title(image, text):
    result = Image.new('RGB', (image.width, image.height + 32), '#182332')
    result.paste(image, (0, 32))
    ImageDraw.Draw(result).text((10, 5), text, font=FONT, fill='#e3edf7')
    return result

gallery = Image.new('RGB', (1280, 572))
for i, (name, caption) in enumerate([
    ('home_reception', '四宫格 · 大厅正式入口'),
    ('sounds', '声音 · 三条滑杆'),
    ('messages', '讯息 · 真实内容与滚动'),
    ('shop_readonly', '楼层购物 · 只浏览'),
]):
    image = Image.open(SOURCE / f'{name}.png').convert('RGB').crop((0, 0, 640, 1080))
    gallery.paste(title(image.resize((320, 540), Image.Resampling.NEAREST), caption), (i * 320, 0))
gallery.save(OUT / 'phone_pages.png')

old = ROOT / '.runtime/phone_settings_sample_20261018/camera_silver_review/sound_settings.png'
if old.exists():
    comparison = Image.new('RGB', (640, 572))
    for i, (path, caption) in enumerate([(old, '之前 · 小字深色界面'), (SOURCE / 'sounds.png', '现在 · 浅冷色 12px 中文')]):
        image = Image.open(path).convert('RGB').crop((0, 0, 640, 1080))
        comparison.paste(title(image.resize((320, 540), Image.Resampling.NEAREST), caption), (i * 320, 0))
    comparison.save(OUT / 'ui_before_after.png')

metadata = {}
for clip, name, caption in [
    ('camera_repeat', 'tab_camera', '正式大厅 Tab 开合与镜头恢复 · 正常速度 · 预热后'),
    ('bedroom_tab', 'apps_and_keys', '卧室正式入口、按键与应用操作 · 正常速度'),
    ('pointer_and_return', 'pointer_return', '鼠标轻摆、实际应用、右键返回 · 正常速度'),
]:
    records = REPORT['clips'][clip]
    images, durations = [], []
    for i, record in enumerate(records):
        image = Image.open(SOURCE / record['file']).convert('RGB').resize((960, 540), Image.Resampling.NEAREST)
        images.append(title(image, caption))
        dt = records[i + 1]['seconds'] - record['seconds'] if i + 1 < len(records) else .16
        durations.append(max(10, round(dt * 100) * 10))
    atlas = Image.new('RGB', (960, 572 * min(12, len(images))))
    for i, image in enumerate(images[::max(1, len(images)//12)][:12]): atlas.paste(image, (0, i*572))
    palette = atlas.quantize(colors=256)
    frames = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in images]
    frames[0].save(OUT / f'{name}.gif', save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2, optimize=False)
    metadata[name] = {'frames': len(frames), 'seconds': sum(durations)/1000, 'speed': 'recorded wall-clock'}
metadata['scope'] = 'Actual Main GPU output. Cropping, nearest resizing, captions only. No repainted UI pixels.'
(OUT / 'media.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(metadata, ensure_ascii=False))
