"""Package rendered Camera frames into a preview, without modifying game assets."""
import argparse
import json
from pathlib import Path

from PIL import Image

parser = argparse.ArgumentParser()
parser.add_argument("capture", type=Path)
parser.add_argument("--start", type=float, default=0.0)
parser.add_argument("--stop", type=float, default=float("inf"))
parser.add_argument("--crop", type=int, nargs=4, metavar=("LEFT", "TOP", "RIGHT", "BOTTOM"))
parser.add_argument("--name", default="death_sequence.gif")
args = parser.parse_args()
report = json.loads((args.capture / "report.json").read_text(encoding="utf-8-sig"))
samples = [sample for sample in report["samples"]
           if args.start <= sample["game_seconds"] <= args.stop]
if not samples:
    parser.error("No frames in the requested game-time interval")
if Path(args.name).name != args.name or not args.name.lower().endswith(".gif"):
    parser.error("Preview name must be a GIF filename")
images = []
durations = []
for index, sample in enumerate(samples):
    frame = Image.open(args.capture / sample["file"]).convert("RGB")
    images.append(frame.crop(args.crop) if args.crop else frame)
    seconds = (samples[index + 1]["game_seconds"] - sample["game_seconds"]
               if index + 1 < len(samples) else 0.8)
    # GIF stores centiseconds. Round the cumulative clock so 60fps frames
    # alternate 10/20ms instead of all rounding to 20ms and slowing the clip.
    elapsed = sample["game_seconds"] - samples[0]["game_seconds"]
    durations.append(max(10, (round((elapsed + seconds) * 100) - round(elapsed * 100)) * 10))
output = args.capture / args.name
images[0].save(output, save_all=True, append_images=images[1:], duration=durations,
               loop=0, disposal=1, optimize=True)
print(json.dumps({"output": str(output), "frames": len(images),
                  "game_seconds": samples[-1]["game_seconds"],
                  "crop": args.crop,
                  "note": "GIF preview; original full-resolution Camera PNGs remain authoritative."}))
