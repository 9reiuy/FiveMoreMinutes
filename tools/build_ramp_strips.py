"""Builds one strip per cooling-ramp candidate: the four colour steps of that ramp
side by side, all cropped from the same window so the only thing that differs
between strips is the palette itself."""
import glob
import json
import os
import sys

from PIL import Image

# Fixed crop: identical for every candidate, so strips are directly comparable.
WINDOW = (760, 180, 1160, 600)
STEP_KEYS = ["orange", "yellow", "purple", "grey"]


def pick_frames(d):
    """One frame per ramp step, in order. Falls back to the nearest later frame."""
    report = json.load(open(os.path.join(d, "report.json"), encoding="utf-8"))
    shots = [e for e in report["clips"]["fire_assault_rifle"] if e.get("puffs") and len(e["puffs"]) >= 9]
    if not shots:
        return []
    chosen = []
    used = 0
    for key in STEP_KEYS:
        hit = None
        for e in shots[used:]:
            steps = set(("W" if p["white"] else p["step"]) for p in e["puffs"])
            if key in steps:
                hit = e
                break
        if hit is None:
            hit = shots[min(used, len(shots) - 1)]
        else:
            used = shots.index(hit)
        chosen.append(hit)
    return chosen


def build(d, tag, out_dir, zoom=2):
    frames = pick_frames(d)
    if not frames:
        print("  skip", tag, "(no plume frames)")
        return None
    tiles = []
    for e in frames:
        im = Image.open(os.path.join(d, e["file"])).convert("RGB").crop(WINDOW)
        tiles.append(im.resize((im.width * zoom, im.height * zoom), Image.NEAREST))
    w, h = tiles[0].size
    strip = Image.new("RGB", (w * len(tiles), h), (24, 24, 32))
    for i, t in enumerate(tiles):
        strip.paste(t, (i * w, 0))
    path = os.path.join(out_dir, "strip_%s.png" % tag)
    strip.save(path)
    return path


def main():
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    # Remaining args are tag=path pairs.
    made = []
    for pair in sys.argv[2:]:
        tag, d = pair.split("=", 1)
        if not os.path.exists(os.path.join(d, "report.json")):
            print("  skip", tag, "(missing report)")
            continue
        p = build(d, tag, out_dir)
        if p:
            made.append((tag, p))
            print("  %-14s %s" % (tag, p))
    print("strips:", len(made))


if __name__ == "__main__":
    main()
