"""Package original GPU Camera frames, with no repainting or invented frames."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / ".runtime/melee_sweep_20261021/camera"
OUT = SOURCE.parent / SOURCE.name.replace("camera", "delivery", 1)
OUT.mkdir(parents=True, exist_ok=True)
report = json.loads((SOURCE / "report.json").read_text(encoding="utf-8"))
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 18)

def caption(image, text):
    result = Image.new("RGB", (image.width, image.height + 32), "#17202b")
    result.paste(image, (0, 32))
    ImageDraw.Draw(result).text((10, 3), text, fill="white", font=font)
    return result

def frame(file, close=False):
    with Image.open(SOURCE / file) as image:
        image = image.convert("RGB")
        return image.crop((590, 290, 1320, 870)) if close else image.resize((960,540), Image.Resampling.NEAREST)

comparison = Image.new("RGB", (960, 604), "#17202b")
for row, pixel in enumerate([0,1]):
    for col, palette in enumerate([0,1]):
        image = frame(f"bat_pixel_{pixel}_palette_{palette}_006.png").resize((480,270), Image.Resampling.NEAREST)
        comparison.paste(caption(image, f"像素化{'开' if pixel else '关'} · Palette {'1' if palette else '关'}"), (col*480,row*302))
comparison.save(OUT / "display_modes.png")

directions = Image.new("RGB", (1280, 564), "#17202b")
for index in range(8):
    image = frame(f"direction_{index}.png", True).resize((320,254),Image.Resampling.NEAREST)
    directions.paste(caption(image, f"方向 {index+1} · 正式Camera局部"), ((index%4)*320,(index//4)*282))
directions.save(OUT / "eight_directions.png")

metadata = {}
for name, title in [("bat_pixel_1_palette_1", f"球棍{report.get('bat_reach',56):g}px/160° · 固定60Hz动作采样"), ("books_moving", f"书本{report.get('books_reach',44):g}px/150° · 移动挥击")]:
    records = report["clips"][name]
    images = [caption(frame(item["file"], True), title) for item in records[::2]]
    palette = images[len(images)//2].quantize(colors=256)
    images = [image.quantize(palette=palette, dither=Image.Dither.NONE) for image in images]
    # Twelve samples cover 0.4s of the controlled 60Hz action. GIF uses 10ms ticks.
    durations = [30,40,30] * 4
    images[0].save(OUT / (name + ".gif"), save_all=True, append_images=images[1:], duration=durations, loop=0, disposal=2)
    metadata[name] = {"frames":len(images), "action_seconds":0.4, "silent":True,
        "scope":"Controlled 60Hz action playback from original GPU frames; not a live-FPS recording."}

frame("bat_pixel_1_palette_1_006.png", True).save(OUT / "bat_closeup.png")
cover = Image.new("RGB", (1460,612), "#17202b")
for index, (kind, title) in enumerate([("cabinet","高柜阻挡 · 柜后敌人不受伤"),("desk","低桌可越过 · 桌后敌人受到挥击")]):
    cover.paste(caption(frame(f"cover_{kind}_006.png", True),title),(index*730,0))
cover.save(OUT / "cover_comparison.png")
(OUT / "delivery.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
if "hair_stationary" in report["clips"]:
    x, y = report["player_torso_screen"]
    images = []
    for item in report["clips"]["hair_stationary"][::2]:
        with Image.open(SOURCE / item["file"]) as image:
            image = image.convert("RGB").crop((int(x)-65,int(y)-85,int(x)+65,int(y)+45))
            images.append(caption(image.resize((520,520),Image.Resampling.NEAREST), "原Camera像素 ×4 · 站立挥击与刘海回弹"))
    palette = images[0].quantize(colors=256)
    contact = Image.new("RGB", (1040,1104))
    for i, sample in enumerate([0,3,7,14]):
        contact.paste(images[sample], ((i%2)*520,(i//2)*552))
    contact.save(OUT / "hair_stationary_contact.png")
    images = [im.quantize(palette=palette,dither=Image.Dither.NONE) for im in images]
    images[0].save(OUT / "hair_stationary.gif",save_all=True,append_images=images[1:],duration=([30,40,30]*12)[:len(images)],loop=0,disposal=2)
print(json.dumps({"checks":report["checks"],"failures":report["failures"],"output":str(OUT)}, ensure_ascii=False))
