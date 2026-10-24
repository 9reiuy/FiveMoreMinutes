"""Measure the muzzle plume in captured frames against a pre-shot baseline.

The scene itself is full of #131333 (the palette's dark tone) and white HUD pixels,
so absolute colour counts are meaningless. Everything here is a diff against the
first frame of the clip, which is captured before the round leaves the barrel.
"""
import glob
import os
import sys

from PIL import Image

RAMP = [
    ("orange", (0xC2, 0x71, 0x32)),
    ("yellow", (0xEF, 0xCD, 0x4C)),
    ("purple", (0x6E, 0x39, 0x8B)),
    ("grey", (0x3D, 0x34, 0x45)),
    ("edge", (0x13, 0x13, 0x33)),
    ("white", (0xFF, 0xFF, 0xFF)),
]


def nearest(px):
    best = None
    best_d = 1 << 30
    for name, ref in RAMP:
        d = (px[0] - ref[0]) ** 2 + (px[1] - ref[1]) ** 2 + (px[2] - ref[2]) ** 2
        if d < best_d:
            best_d = d
            best = name
    # Anything far from every ramp entry is scene bleed-through, not plume.
    return best if best_d <= 900 else None


def load(path):
    im = Image.open(path).convert("RGB")
    return im, im.size, list(im.get_flattened_data())


def main():
    d = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else "fire_assault_rifle"
    pad = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    frames = sorted(glob.glob(os.path.join(d, prefix + "_*.png")))
    if not frames:
        print("no frames in", d)
        return
    base_im, (w, h), base = load(frames[0])
    print("dir=%s frames=%d size=%dx%d" % (d, len(frames), w, h))
    prev = None
    for f in frames[1:]:
        im, _, data = load(f)
        counts = {name: 0 for name, _ in RAMP}
        counts["other"] = 0
        xs = []
        ys = []
        for i in range(w * h):
            a = base[i]
            b = data[i]
            if abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]) < 24:
                continue
            name = nearest(b)
            if name is None:
                counts["other"] += 1
                continue
            counts[name] += 1
            xs.append(i % w)
            ys.append(i // w)
        total = sum(counts.values())
        if total == 0:
            print("%-34s EMPTY" % os.path.basename(f))
            continue
        cx = sum(xs) / len(xs)
        cy = sum(ys) / len(ys)
        bw = max(xs) - min(xs) + 1
        bh = max(ys) - min(ys) + 1
        move = "" if prev is None else " d=(%+.0f,%+.0f)" % (cx - prev[0], cy - prev[1])
        print("%-34s px=%5d bbox=%3dx%-3d c=(%4.0f,%4.0f)%s  %s" % (
            os.path.basename(f), total, bw, bh, cx, cy, move,
            " ".join("%s=%d" % (k, v) for k, v in counts.items() if v)))
        prev = (cx, cy)
        if pad:
            box = (max(0, min(xs) - pad), max(0, min(ys) - pad),
                   min(w, max(xs) + pad), min(h, max(ys) + pad))
            im.crop(box).resize((box[2] - box[0], box[3] - box[1]), Image.NEAREST) \
                .save(os.path.join(d, "crop_" + os.path.basename(f)))


if __name__ == "__main__":
    main()
