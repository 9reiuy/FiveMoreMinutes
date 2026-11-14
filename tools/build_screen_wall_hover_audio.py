"""Extract the user-marked tail of Modern Neon Breathe for screen hover.

Only trims the source, adds 4 ms edge fades, and exports stereo PCM WAV.
Requires FFmpeg on PATH, --ffmpeg, or the installed imageio_ffmpeg package.
"""

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import wave


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--start", type=float, default=0.340)
    parser.add_argument("--end", type=float, default=1.140)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--ffmpeg")
    args = parser.parse_args()
    if not 0 <= args.start < args.end:
        parser.error("Require 0 <= start < end")
    executable = args.ffmpeg or shutil.which("ffmpeg")
    if not executable:
        import imageio_ffmpeg
        executable = imageio_ffmpeg.get_ffmpeg_exe()
    duration = args.end - args.start
    fade = min(0.004, duration / 4)
    filters = (
        f"atrim=start={args.start:.6f}:end={args.end:.6f},asetpts=PTS-STARTPTS,"
        f"afade=t=in:st=0:d={fade:.6f},"
        f"afade=t=out:st={duration-fade:.6f}:d={fade:.6f}"
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [executable, "-hide_banner", "-loglevel", "error", "-y",
         "-i", str(args.source), "-map", "0:a:0", "-map_metadata", "-1",
         "-af", filters, "-ar", "48000", "-ac", "2", "-c:a", "pcm_s16le",
         str(args.output)], check=True,
    )
    with wave.open(str(args.output), "rb") as audio:
        rate, channels, width, frames = (audio.getframerate(), audio.getnchannels(),
                                         audio.getsampwidth(), audio.getnframes())
        samples = array.array("h", audio.readframes(frames))
    expected_frames = round(duration * rate)
    if (rate, channels, width, frames) != (48000, 2, 2, expected_frames):
        raise RuntimeError("Unexpected exported audio format or duration")
    peak = max(abs(value) for value in samples) / 32768
    rms = math.sqrt(sum(value * value for value in samples) / len(samples)) / 32768
    if max(abs(value) for value in samples) >= 32767:
        raise RuntimeError("Clipped PCM samples in export")
    manifest = {
        "source": str(args.source.resolve()),
        "source_sha256": hashlib.sha256(args.source.read_bytes()).hexdigest(),
        "start_seconds": args.start,
        "end_seconds": args.end,
        "duration_seconds": frames / rate,
        "sample_rate": rate,
        "channels": channels,
        "encoding": "PCM signed 16 bit",
        "edge_fade_seconds": fade,
        "playback_rate": 1.0,
        "gain_db": 0.0,
        "filter": filters,
        "peak_dbfs": 20 * math.log10(max(1e-12, peak)),
        "rms_dbfs": 20 * math.log10(max(1e-12, rms)),
        "clipped_samples": 0,
        "output_sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
    }
    args.work_dir.mkdir(parents=True, exist_ok=True)
    (args.work_dir / "clip_recipe.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8",
    )
    print(json.dumps(manifest, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()