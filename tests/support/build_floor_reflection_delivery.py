"""Package unaltered gameplay Camera frames; normal speed uses recorded timestamps."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

source = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=True)
report = json.loads((source / "report.json").read_text(encoding="utf-8"))
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
names = {"restroom": "瓷砖", "reception": "大理石", "corridor": "水磨石", "conference": "木地板", "office": "地毯"}
previous = "reception_previous" in report["clips"]
baseline_suffix = "previous" if previous else "before"
baseline_label = " · 上一版" if previous else " · 原受光"

def label(im, text):
    canvas = Image.new("RGB", (im.width, im.height + 32), "#171b22")
    canvas.paste(im, (0, 32))
    ImageDraw.Draw(canvas).text((10, 3), text, font=font, fill="white")
    return canvas

sheet = Image.new("RGB", (1280, 392 * 5), "#171b22")
for row, (key, name) in enumerate(names.items()):
    for col, suffix in enumerate([baseline_suffix, "after"]):
        clip = report["clips"][key + "_" + suffix]
        with Image.open(source / clip[len(clip)//2]["file"]) as image:
            image = image.convert("RGB").resize((640, 360), Image.Resampling.NEAREST)
        sheet.paste(label(image, name + (baseline_label if col == 0 else " · 新版宽亮斑与细碎光泽")), (640 * col, 392 * row))
    left, right = report["clips"][key+"_"+baseline_suffix], report["clips"][key+"_after"]
    frames, times = [], []
    for i, sample in enumerate(right):
        before = min(left, key=lambda f: abs(f["seconds"] - sample["seconds"]))
        pair = Image.new("RGB", (1200, 482), "#171b22")
        for col, item in enumerate([before, sample]):
            with Image.open(source / item["file"]) as image:
                view = image.crop((480, 180, 1440, 900)).convert("RGB").resize((600, 450), Image.Resampling.NEAREST)
            pair.paste(label(view, name + (baseline_label if col == 0 else " · 新版")), (600 * col, 0))
        frames.append(pair)
        times.append(max(20, round((right[i+1]["seconds"]-sample["seconds"])*1000)) if i+1<len(right) else 700)
    frames[0].save(output / (key+"_comparison.gif"), save_all=True, append_images=frames[1:], duration=times, loop=0, disposal=2)
sheet.save(output / "five_materials.png")

clip = report["clips"]["moving_reflection"]
for speed in [1, 3]:
    frames, times = [], []
    for i, sample in enumerate(clip):
        with Image.open(source / sample["file"]) as image:
            frame = label(image.crop((480,180,1440,900)).convert("RGB"), ("正常速度" if speed==1 else "三倍慢放") + " · 实际游戏 Camera 局部 · 倒影最高15Hz")
        frames.append(frame)
        times.append(max(20,round((clip[i+1]["seconds"]-sample["seconds"])*1000*speed)) if i+1<len(clip) else 700)
    frames[0].save(output / ("moving_reflection.gif" if speed==1 else "moving_reflection_slow_3x.gif"), save_all=True, append_images=frames[1:], duration=times, loop=0, disposal=2)
print(json.dumps({"checks":report["checks"],"failures":report["failures"],"output":str(output)},ensure_ascii=False))
