"""Package real Camera frames, retaining captured normal-speed timestamps."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

source, output = map(lambda p: Path(p).resolve(), sys.argv[1:3])
output.mkdir(parents=True, exist_ok=True)
report = json.loads((source / "report.json").read_text(encoding="utf-8"))
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 20)
names = {"hall": "塔罗大厅", **{f"floor_{s}": f"正式楼层 {s}" for s in ["A1", "B2", "C3", "V3"]}}

def label(image, text):
    frame = Image.new("RGB", (image.width, image.height + 32), "#171b22")
    frame.paste(image, (0, 32))
    ImageDraw.Draw(frame).text((10, 3), text, font=font, fill="white")
    return frame

sheet = Image.new("RGB", (1280, 392*len(names)), "#171b22")
for row, (key, name) in enumerate(names.items()):
    left, right = [report["clips"][key+"_"+s] for s in ["before", "after"]]
    for col, clip in enumerate([left, right]):
        with Image.open(source / clip[len(clip)//2]["file"]) as image:
            view = image.convert("RGB").resize((640,360), Image.Resampling.NEAREST)
        sheet.paste(label(view, name+(" · 原受光" if col==0 else " · 已接入反光与倒影")), (640*col,392*row))
    frames, durations = [], []
    for i, sample in enumerate(right):
        before = min(left, key=lambda f: abs(f["seconds"]-sample["seconds"]))
        pair = Image.new("RGB", (1280,392), "#171b22")
        for col, item in enumerate([before,sample]):
            with Image.open(source / item["file"]) as image:
                view = image.convert("RGB").resize((640,360), Image.Resampling.NEAREST)
            pair.paste(label(view,name+(" · 原受光" if col==0 else " · 正式效果")),(640*col,0))
        frames.append(pair)
        durations.append(max(20,round((right[i+1]["seconds"]-sample["seconds"])*1000)) if i+1<len(right) else 500)
    frames[0].save(output / (key+"_comparison.gif"), save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2)
sheet.save(output / "formal_rooms.png")
for key, name in [("hall_walk","大厅走动"),("floor_walk","正式楼层走动")]:
    clip = report["clips"][key]
    frames, durations = [], []
    for i, sample in enumerate(clip):
        with Image.open(source / sample["file"]) as image:
            frame=label(image.convert("RGB").resize((960,540),Image.Resampling.NEAREST),name+" · 正常速度 · 实际游戏 Camera")
        frames.append(frame)
        durations.append(max(20,round((clip[i+1]["seconds"]-sample["seconds"])*1000)) if i+1<len(clip) else 500)
    frames[0].save(output/(key+".gif"),save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2)
print(json.dumps({"checks":report["checks"],"failures":report["failures"],"output":str(output)},ensure_ascii=False))
