"""Build a contact sheet from a muzzle capture: crops around the plume, enlarged
with nearest-neighbour so single pixels (the 1px outline) stay countable."""
import json
import os
import sys

from PIL import Image, ImageDraw

STEP_TINT = {
    "orange": (0xC2, 0x71, 0x32),
    "yellow": (0xEF, 0xCD, 0x4C),
    "purple": (0x6E, 0x39, 0x8B),
    "grey": (0x3D, 0x34, 0x45),
}


def main():
    d = sys.argv[1]
    clip = sys.argv[2] if len(sys.argv) > 2 else "fire_assault_rifle"
    zoom = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    report = json.load(open(os.path.join(d, "report.json"), encoding="utf-8"))
    entries = report["clips"][clip]
    shots = [e for e in entries if e.get("puffs")]
    if not shots:
        print("no puffs mirrored for", clip)
        return
    # One box that contains the whole plume across the whole clip, so every crop is
    # the same window and motion is readable frame to frame.
    xs = [p["x"] for e in shots for p in e["puffs"]]
    ys = [p["y"] for e in shots for p in e["puffs"]]
    pad = 70
    x0 = max(0, int(min(xs)) - pad)
    y0 = max(0, int(min(ys)) - pad)
    x1 = int(max(xs)) + pad
    y1 = int(max(ys)) + pad
    print("plume window x=%d..%d y=%d..%d (%dx%d)" % (x0, x1, y0, y1, x1 - x0, y1 - y0))
    muzzle = shots[0].get("muzzle_px", [0, 0])
    print("muzzle_px =", muzzle)

    tiles = []
    for e in shots:
        im = Image.open(os.path.join(d, e["file"])).convert("RGB")
        crop = im.crop((x0, y0, min(im.width, x1), min(im.height, y1)))
        out = crop.resize((crop.width * zoom, crop.height * zoom), Image.NEAREST)
        draw = ImageDraw.Draw(out)
        mx = (muzzle[0] - x0) * zoom
        my = (muzzle[1] - y0) * zoom
        draw.ellipse((mx - 5, my - 5, mx + 5, my + 5), outline=(255, 0, 0), width=2)
        for p in e["puffs"]:
            cx = (p["x"] - x0) * zoom
            cy = (p["y"] - y0) * zoom
            r = max(2.0, p["scale"] * zoom * 0.5)
            tint = (255, 255, 255) if p["white"] else STEP_TINT.get(p["step"], (255, 0, 255))
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=tint, width=2)
        tiles.append((e["file"], e["seconds"], out))

    tw, th = tiles[0][2].size
    cols = 4
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (tw * cols, th * rows), (24, 24, 32))
    for i, (_, _, t) in enumerate(tiles):
        sheet.paste(t, ((i % cols) * tw, (i // cols) * th))
    sheet.save(os.path.join(d, "sheet_%s.png" % clip))
    print("wrote sheet_%s.png  %dx%d  tiles=%d" % (clip, sheet.width, sheet.height, len(tiles)))

    gif = [t for _, _, t in tiles]
    gif[0].save(os.path.join(d, "plume_%s.gif" % clip), save_all=True,
                append_images=gif[1:], duration=55, loop=0)
    print("wrote plume_%s.gif" % clip)
    for f, s, _ in tiles:
        print("  %-34s t=%.3fs" % (f, s))


if __name__ == "__main__":
    main()
