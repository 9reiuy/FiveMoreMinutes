"""Package real GPU screenshots; preserve recorded wall-clock timing in GIFs."""
from pathlib import Path
import json
import argparse
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / '.runtime/phone_settings_sample_20261018'
parser = argparse.ArgumentParser()
parser.add_argument('--source', default='camera_tall')
parser.add_argument('--previous', default='camera_final')
parser.add_argument('--output', default='delivery')
parser.add_argument('--screen-revision', action='store_true')
parser.add_argument('--body-revision', action='store_true')
parser.add_argument('--left', action='store_true')
args = parser.parse_args()
SOURCE = BASE / args.source
OUT = BASE / args.output
OUT.mkdir(parents=True, exist_ok=True)
FONT = ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc', 18)
REPORT = json.loads((SOURCE / 'report.json').read_text(encoding='utf-8'))
CROP_WIDTH = 720 if args.left else 660
PANEL_WIDTH = CROP_WIDTH // 2


def label(im, title):
    out = Image.new('RGB', (im.width, im.height + 32), '#171b22')
    out.paste(im, (0, 32))
    ImageDraw.Draw(out).text((10, 5), title, font=FONT, fill='white')
    return out


def phone_crop(source, title, left=False):
    crop = (0, 0, CROP_WIDTH, 1080) if left else (1920-CROP_WIDTH, 0, 1920, 1080)
    im = Image.open(source).convert('RGB').crop(crop)
    return label(im.resize((PANEL_WIDTH, 540), Image.Resampling.NEAREST), title)


old_title = '上一版：右侧黑面板' if args.left else ('上一版：平面绘制机身' if args.body_revision else ('上一版：紫灰屏与大块高亮' if args.screen_revision else '上一版：上屏偏方'))
new_title = '新版：左侧银白窄框' if args.left else ('新版：实体机身与铰链' if args.body_revision else ('新版：深蓝屏与紧凑列表' if args.screen_revision else '新版：竖长屏，键盘出画'))
old = phone_crop(BASE / args.previous / 'sound_settings.png', old_title)
new = phone_crop(SOURCE / 'sound_settings.png', new_title, args.left)
compare = Image.new('RGB', (PANEL_WIDTH*2, 572))
compare.paste(old, (0, 0)); compare.paste(new, (PANEL_WIDTH, 0))
compare.save(OUT / ('body_before_after.png' if args.body_revision else ('screen_before_after.png' if args.screen_revision else 'tall_screen_compare.png')))

gallery = Image.new('RGB', (PANEL_WIDTH*4, 572))
for i, (name, title) in enumerate([
    ('sound_settings', '声音 · 即时保存'), ('graphics_settings', '画面 · 三项设置'),
    ('chat_page', '真实聊天 · 支持滚动'), ('shop_page', '真实购物 · 原购买逻辑'),
]):
    gallery.paste(phone_crop(SOURCE / (name + '.png'), title, args.left), (i * PANEL_WIDTH, 0))
gallery.save(OUT / 'phone_pages.png')

if (SOURCE / 'lighting_warm.png').exists():
    lights = Image.new('RGB', (PANEL_WIDTH*3, 572))
    for i, (name, title) in enumerate([
        ('lighting_warm', '实际场景暖灯'), ('lighting_cool', '同姿态切换冷灯'),
        ('glass_without', '倾斜后关闭环境反射'),
    ]):
        lights.paste(phone_crop(SOURCE / (name + '.png'), title, args.left), (i * PANEL_WIDTH, 0))
    lights.save(OUT / 'light_response.png')
    glass = Image.new('RGB', (PANEL_WIDTH*2, 572))
    for i, (name, title) in enumerate([
        ('glass_with', '倾斜屏幕 · 实际环境反射'),
        ('glass_without', '同一姿态 · 关闭环境反射'),
    ]):
        glass.paste(phone_crop(SOURCE / (name + '.png'), title, args.left), (i * PANEL_WIDTH, 0))
    glass.save(OUT / 'glass_before_after.png')

metadata = {}
clips_to_package = {
    'open_settings': [('menu_open', '翻盖展开 · 正常速度'), ('settings_input', '设置操作 · 正常速度')],
    'bedroom_pause': [('bedroom_pages', '聊天与购物 · 正常速度'), ('pause_flow', '暂停与返回 · 正常速度')],
}
if 'phone_close' in REPORT['clips']:
    clips_to_package['hinge_motion'] = [('menu_open', '提起与翻盖 · 正常速度'), ('phone_close', '真实铰链合拢 · 正常速度')]
if 'scene_lighting' in REPORT['clips']:
    clips_to_package['scene_lighting'] = [('scene_lighting', '真实场景灯光与玻璃反射 · 正常速度')]
for name, parts in clips_to_package.items():
    images, durations = [], []
    for clip, title in parts:
        records = REPORT['clips'][clip]
        for i, record in enumerate(records):
            im = Image.open(SOURCE / record['file']).convert('RGB').resize((960, 540), Image.Resampling.NEAREST)
            images.append(label(im, title))
            dt = records[i + 1]['seconds'] - record['seconds'] if i + 1 < len(records) else .16
            durations.append(max(10, round(dt * 100) * 10))
    samples = images[::max(1, len(images) // 12)][:12]
    atlas = Image.new('RGB', (960, 572 * len(samples)))
    for i, im in enumerate(samples): atlas.paste(im, (0, i * 572))
    palette = atlas.quantize(colors=256)
    indexed = [im.quantize(palette=palette, dither=Image.Dither.NONE) for im in images]
    indexed[0].save(OUT / (name + '.gif'), save_all=True, append_images=indexed[1:],
                    duration=durations, loop=0, optimize=False, disposal=2)
    metadata[name] = {'frames': len(images), 'seconds': sum(durations) / 1000, 'speed': 'recorded wall-clock, no slow motion'}

metadata['scope'] = 'Actual Main GPU screenshots only. Nearest resizing/cropping and labels; no repainted interface pixels.'
(OUT / 'media.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(metadata, ensure_ascii=False))
