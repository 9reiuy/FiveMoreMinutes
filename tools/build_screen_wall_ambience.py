"""Encode the complete user-provided Quasi Drone WAV for the menu bed."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess

import imageio_ffmpeg


def wav_info(path):
    with path.open("rb") as source:
        if source.read(12)[0:4] != b"RIFF":
            raise ValueError("Expected a RIFF WAV source")
        info = {}
        while header := source.read(8):
            tag, size = struct.unpack("<4sI", header)
            offset = source.tell()
            if tag == b"fmt ":
                fmt, channels, rate, _, block_size, bits = struct.unpack(
                    "<HHIIHH", source.read(16)
                )
                info.update(format=fmt, channels=channels, sample_rate=rate,
                            block_size=block_size, bit_depth=bits)
            if tag == b"data":
                info["duration_seconds"] = size / info["block_size"] / info["sample_rate"]
                return info
            source.seek(offset + size + (size & 1))
    raise ValueError("WAV has no audio data")


def levels(ffmpeg, path):
    result = subprocess.run(
        [ffmpeg, "-hide_banner", "-nostdin", "-i", str(path),
         "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", check=True
    )
    return {name + "_dbfs": float(re.search(name + r"_volume: ([-\d.]+) dB", result.stderr)[1])
            for name in ("mean", "max")}


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path,
                        default=Path(__file__).resolve().parents[1] / ".runtime/screen_wall_ambience_20261108")
    args = parser.parse_args()
    info = wav_info(args.source)
    if (info["channels"], info["sample_rate"], info["bit_depth"]) != (2, 48000, 32):
        raise ValueError("Expected the approved 48 kHz stereo 32-bit original")
    if abs(info["duration_seconds"] - 607.988) > 0.001:
        raise ValueError("Expected the complete 607.988-second recording")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / "screen_wall_ambience.ogg"
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    # Preserve the complete timeline, pitch and gain. Only soften the outer
    # 10 ms edges so repeated playback cannot produce a waveform discontinuity.
    fade = 0.010
    filters = (f"afade=t=in:st=0:d={fade},"
               f"afade=t=out:st={info['duration_seconds'] - fade:.6f}:d={fade}")
    subprocess.run(
        [ffmpeg, "-hide_banner", "-nostdin", "-loglevel", "error", "-y",
         "-i", str(args.source), "-map", "0:a:0", "-map_metadata", "-1",
         "-af", filters, "-c:a", "libvorbis", "-q:a", "5",
         "-metadata", "title=Quasi Drone - A Low Frequency Ambient Drone Soundscape",
         "-metadata", "artist=bassimat", "-metadata", "license=CC0 1.0",
         str(output)], check=True
    )
    recipe = {
        "source_title": "Quasi Drone - A Low Frequency Ambient Drone Soundscape",
        "creator": "bassimat", "source_url": "https://freesound.org/people/bassimat/sounds/840934/",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "source_path": str(args.source.resolve()), "source_sha256": sha256(args.source),
        "source_info": info, "source_levels": levels(ffmpeg, args.source),
        "output_path": str(output.resolve()), "ogg_sha256": sha256(output),
        "ogg_bytes": output.stat().st_size, "ogg_levels": levels(ffmpeg, output),
        "encoding": "Vorbis quality 5, original sample rate/stereo/timeline/pitch/gain",
        "edge_fade_seconds": fade, "runtime_gain_db": -30.0,
        "runtime_fade_in_seconds": 2.0, "runtime_fade_out_seconds": 1.2,
        "runtime_bus": "SFX", "loop": True
    }
    (args.output_dir / "ambience_recipe.json").write_text(
        json.dumps(recipe, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps(recipe, ensure_ascii=False))


if __name__ == "__main__":
    main()
