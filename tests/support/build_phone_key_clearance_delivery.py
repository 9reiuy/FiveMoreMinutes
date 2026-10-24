"""Package real before/after key geometry and normal-speed original Camera GIFs."""
from pathlib import Path
import json
import argparse
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--source-base',default='.runtime/phone_key_clearance_20261019')
parser.add_argument('--refine-fit',action='store_true')
args=parser.parse_args()
BASE = ROOT / args.source_base
SOURCE, OUT = BASE / 'camera', BASE / 'delivery'
OUT.mkdir(parents=True, exist_ok=True)
REPORT = json.loads((SOURCE / 'report.json').read_text(encoding='utf-8'))
FONT = ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc', 18)

def caption(image, text):
    out = Image.new('RGB', (image.width, image.height + 32), '#182434')
    out.paste(image, (0, 32));ImageDraw.Draw(out).text((10, 5), text, font=FONT, fill='white')
    return out

def keys(path):
    return Image.open(path).convert('RGB').crop((0, 690, 720, 1080))

comparison = Image.new('RGB', (1440, 422))
old = ROOT / ('.runtime/phone_key_clearance_20261019/camera/right.png' if args.refine_fit else '.runtime/phone_feedback_20261019/camera/dpad_held.png')
comparison.paste(caption(keys(old), '上一版 · 深槽与方形底座' if args.refine_fit else '修复前 · 右侧下压陷入底座'), (0, 0))
comparison.paste(caption(keys(SOURCE/'right.png'), '现在 · 窄缝与平齐机身' if args.refine_fit else '修复后 · 实际槽体与按压间隙'), (720, 0))
comparison.save(OUT/'geometry_before_after.png')

gallery = Image.new('RGB', (1440, 844))
for i, (file, text) in enumerate([
    ('upper_right','右上组合 · 倾角受限'),('centre_and_ring','中心与方向同时按下'),
    ('left_softkey','左软键 · 字样随动'),('right_softkey','右软键 · 箭头随动'),
]):
    gallery.paste(caption(keys(SOURCE/f'{file}.png'),text), ((i%2)*720, (i//2)*422))
gallery.save(OUT/'maximum_poses.png')

metadata={}
for clip, title in [('directional_clearance','直向、四个斜向、松开 · 正常速度'),('buttons_and_labels','软键、中心与组合按压 · 正常速度')]:
    records=REPORT['clips'][clip];images=[];durations=[]
    for i, record in enumerate(records):
        images.append(caption(keys(SOURCE/record['file']),title))
        dt=records[i+1]['seconds']-record['seconds'] if i+1<len(records) else .16
        durations.append(max(10, round(dt*100)*10))
    atlas=Image.new('RGB',(720,422*min(12,len(images))))
    for i, image in enumerate(images[::max(1,len(images)//12)][:12]):atlas.paste(image,(0,i*422))
    palette=atlas.quantize(colors=256)
    frames=[image.quantize(palette=palette,dither=Image.Dither.NONE) for image in images]
    frames[0].save(OUT/f'{clip}.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
    metadata[clip]={'frames':len(frames),'seconds':sum(durations)/1000,'speed':'recorded wall-clock'}
metadata['scope']='Actual Main original Camera; cropping and captions only; no repainted geometry.'
(OUT/'media.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(metadata,ensure_ascii=False))
