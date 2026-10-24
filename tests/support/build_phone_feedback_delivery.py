"""Package actual Camera output. GIF frame intervals retain recorded time."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '.runtime/phone_feedback_20261019'
SOURCE, OUT = BASE / 'camera', BASE / 'delivery'
OUT.mkdir(parents=True, exist_ok=True)
REPORT = json.loads((SOURCE / 'report.json').read_text(encoding='utf-8'))
FONT = ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc', 18)

def caption(image, text):
    out = Image.new('RGB', (image.width, image.height + 32), '#172433')
    out.paste(image, (0, 32))
    ImageDraw.Draw(out).text((10, 5), text, font=FONT, fill='white')
    return out

comparison = Image.new('RGB', (960, 302))
for i, (file, label) in enumerate([
    ('previous_dim', '同镜头 · 恢复旧压暗参数作对照'),
    ('current_undimmed', '现在 · 取消手机全屏压暗'),
]):
    image = Image.open(SOURCE / f'{file}.png').convert('RGB').resize((480, 270), Image.Resampling.NEAREST)
    comparison.paste(caption(image, label), (i * 480, 0))
comparison.save(OUT / 'brightness_comparison.png')

footer = Image.new('RGB', (660, 572))
for i, (file, label) in enumerate([('footer_settings', '原位置 · 选中设置'), ('footer_back', '原位置 · 选中返回')]):
    image = Image.open(SOURCE / f'{file}.png').convert('RGB').crop((0, 0, 660, 1080)).resize((330, 540), Image.Resampling.NEAREST)
    footer.paste(caption(image, label), (i * 330, 0))
footer.save(OUT / 'footer_selection.png')

metadata = {}
for clip, label, crop in [
    ('footer_navigation', 'WASD 选择原有底部软键 · 正常速度', False),
    ('button_feedback', '真实实体按压、松开和快速点按 · 正常速度', True),
]:
    images, durations = [], []
    records = REPORT['clips'][clip]
    for i, record in enumerate(records):
        image = Image.open(SOURCE / record['file']).convert('RGB')
        image = image.crop((0, 690, 720, 1080)).resize((720, 390), Image.Resampling.NEAREST) if crop else image.resize((960, 540), Image.Resampling.NEAREST)
        images.append(caption(image, label))
        dt = records[i+1]['seconds'] - record['seconds'] if i+1 < len(records) else .16
        durations.append(max(10, round(dt * 100) * 10))
    atlas = Image.new('RGB', (images[0].width, images[0].height * min(12, len(images))))
    for i, image in enumerate(images[::max(1, len(images)//12)][:12]): atlas.paste(image, (0, i*image.height))
    palette = atlas.quantize(colors=256)
    frames = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in images]
    frames[0].save(OUT / f'{clip}.gif', save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=False, disposal=2)
    metadata[clip] = {'frames': len(frames), 'seconds': sum(durations)/1000, 'speed': 'recorded wall-clock; no slow motion'}
metadata['scope'] = 'Actual Main Camera only. Cropping, nearest resizing and captions; no repainted UI.'
(OUT / 'media.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(metadata, ensure_ascii=False))
