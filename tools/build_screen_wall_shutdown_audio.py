"""Author a quiet CRT switch-off cue and match it to the existing hover level.

No external samples: damped relay click, falling flyback tone and discharge hiss.
The WAV is the editable master; Godot's encoder script writes the runtime .res.
"""
import array
import hashlib
import json
import math
from pathlib import Path
import random
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "sfx/preview/screen_wall_power_off.wav"
REFERENCE = ROOT / "sfx/preview/screen_wall_hover.wav"
RATE = 48000
DURATION = 0.180


def main():
    with wave.open(str(REFERENCE), "rb") as audio:
        reference = array.array("h", audio.readframes(audio.getnframes()))
    reference_rms = math.sqrt(sum(x * x for x in reference) / len(reference)) / 32768
    reference_peak = max(abs(x) for x in reference) / 32768
    random_source = random.Random(11072026)
    mono = []
    phase = 0.0
    low_noise = 0.0
    for i in range(round(RATE * DURATION)):
        t = i / RATE
        # Fast falling pitch, with a low resonant cabinet/relay impulse.
        frequency = 78.0 + 1320.0 * math.exp(-t / 0.021)
        phase += math.tau * frequency / RATE
        flyback = (math.sin(phase) + 0.18 * math.sin(phase * 2.01)) * math.exp(-t / 0.023)
        relay = 0.46 * math.sin(math.tau * 185.0 * t) * math.exp(-t / 0.011)
        noise = random_source.uniform(-1, 1)
        low_noise += (noise - low_noise) * 0.35
        discharge = 0.28 * (noise - low_noise) * math.exp(-t / 0.014)
        edge = min(1.0, t / 0.0015) * min(1.0, (DURATION - t) / 0.012)
        mono.append((flyback + relay + discharge) * edge)
    peak = max(abs(x) for x in mono)
    # A soft tube-like limiter permits an average-level match without a
    # louder transient than the hover cue. The whole sequence is one voice.
    drive = 1.0
    while True:
        shaped = [math.tanh(value / peak * drive) for value in mono]
        rms = math.sqrt(sum(x * x for x in shaped) / len(shaped))
        shaped_peak = max(abs(x) for x in shaped)
        if shaped_peak / rms <= reference_peak / reference_rms:
            mono = shaped
            peak = shaped_peak
            break
        drive *= 1.10
    # Match average level, with a ceiling at the hover sample's peak.
    gain = min(reference_rms / rms, reference_peak / peak)
    pcm = array.array("h")
    for value in mono:
        sample = round(value * gain * 32767)
        pcm.extend((sample, sample))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as audio:
        audio.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        audio.writeframes(pcm.tobytes())
    result_rms = math.sqrt(sum(x * x for x in pcm) / len(pcm)) / 32768
    result_peak = max(abs(x) for x in pcm) / 32768
    assert result_peak <= reference_peak and result_peak < 1
    metadata = {
        "authoring": "original deterministic procedural CRT power-loss cue; no external samples",
        "duration_seconds": DURATION, "rate": RATE, "channels": 2, "pcm_bits": 16,
        "reference_rms_dbfs": 20 * math.log10(reference_rms),
        "reference_peak_dbfs": 20 * math.log10(reference_peak),
        "rms_dbfs": 20 * math.log10(result_rms), "peak_dbfs": 20 * math.log10(result_peak),
        "output_sha256": hashlib.sha256(OUT.read_bytes()).hexdigest(),
        "soft_limiter_drive": drive,
        "playback": "UI bus, same -9 dB player trim as hover, one voice, no overlap gain",
    }
    OUT.with_suffix(".json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(json.dumps(metadata))


if __name__ == "__main__":
    main()
