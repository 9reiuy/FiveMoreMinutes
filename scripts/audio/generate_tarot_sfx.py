#!/usr/bin/env python3
"""
Procedural Audio Synthesis for Tarot Card Sound Effects
Project: 5MinuteMore
Target Directory: res://sfx/tarot/ (sfx/tarot/)

Generates 4 distinct high-quality procedural Foley & mystic paper sound effects:
  1) tarot_shuffle.wav: Card shuffling sound (approx 0.60s) - thumb riffle cascade, paper friction, deck squaring tap
  2) tarot_deal.wav: Crisp card flick/deal sound (approx 0.15s) - fast friction swipe, sharp thumb snap release
  3) tarot_flip.wav: Quick card flip Foley (approx 0.18s) - tactile paper turn-over whip, landing slap
  4) tarot_select.wav: Firm card impact / selection with subtle mystic crystalline shimmer (approx 0.50s)

Specifications:
  - 16-bit PCM 44100Hz mono audio
  - Pure Python standard library (wave, math, struct, random, os, sys, pathlib)
  - Zero DC offset (25Hz DC-blocker highpass)
  - Smooth fade-in and fade-out to prevent clicks/pops
  - Soft saturation (tanh) and peak normalization to -1.0 dBFS
"""

import argparse
import math
import os
import random
import struct
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 44100
TARGET_PEAK_DBFS = -1.0
TARGET_PEAK_AMP = 10.0 ** (TARGET_PEAK_DBFS / 20.0)  # ~0.8912509


# ==============================================================================
# DSP Building Blocks
# ==============================================================================

class BiquadFilter:
    """Standard Audio EQ Cookbook Biquad Filter (Direct Form I)."""

    def __init__(self, ftype="lowpass", freq=1000.0, q=0.707, sr=SAMPLE_RATE):
        self.sr = sr
        self.x1 = 0.0
        self.x2 = 0.0
        self.y1 = 0.0
        self.y2 = 0.0
        self.set_params(ftype, freq, q)

    def set_params(self, ftype, freq, q=0.707):
        self.ftype = ftype
        freq = max(10.0, min(float(freq), self.sr * 0.48))
        omega = 2.0 * math.pi * freq / self.sr
        cos_w = math.cos(omega)
        sin_w = math.sin(omega)
        alpha = sin_w / (2.0 * max(float(q), 0.001))

        if ftype == "lowpass":
            b0 = (1.0 - cos_w) / 2.0
            b1 = 1.0 - cos_w
            b2 = (1.0 - cos_w) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cos_w
            a2 = 1.0 - alpha
        elif ftype == "highpass":
            b0 = (1.0 + cos_w) / 2.0
            b1 = -(1.0 + cos_w)
            b2 = (1.0 + cos_w) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cos_w
            a2 = 1.0 - alpha
        elif ftype == "bandpass":
            b0 = alpha
            b1 = 0.0
            b2 = -alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cos_w
            a2 = 1.0 - alpha
        elif ftype == "notch":
            b0 = 1.0
            b1 = -2.0 * cos_w
            b2 = 1.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cos_w
            a2 = 1.0 - alpha
        else:
            raise ValueError(f"Unknown filter type: {ftype}")

        self.b0 = b0 / a0
        self.b1 = b1 / a0
        self.b2 = b2 / a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0

    def process(self, x):
        y = (self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2
             - self.a1 * self.y1 - self.a2 * self.y2)
        self.x2 = self.x1
        self.x1 = x
        self.y2 = self.y1
        self.y1 = y
        return y


def filter_signal(samples, ftype, freq, q=0.707, sr=SAMPLE_RATE):
    """Filters a buffer of audio samples using BiquadFilter."""
    flt = BiquadFilter(ftype, freq, q, sr)
    out = [0.0] * len(samples)
    for i, s in enumerate(samples):
        out[i] = flt.process(s)
    return out


def dc_block(samples, cutoff=25.0, sr=SAMPLE_RATE):
    """Highpass DC blocking filter."""
    return filter_signal(samples, "highpass", cutoff, q=0.707, sr=sr)


def generate_white_noise(length, rng):
    """Generates uniform white noise [-1.0, 1.0]."""
    return [rng.uniform(-1.0, 1.0) for _ in range(length)]


def generate_pink_noise(length, rng):
    """Generates approximate pink noise using Paul Kellet's filter."""
    b0, b1, b2, b3, b4, b5, b6 = 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
    out = [0.0] * length
    for i in range(length):
        white = rng.uniform(-1.0, 1.0)
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
        b6 = white * 0.115926
    return out


def apply_master_envelope_and_normalize(samples, sr=SAMPLE_RATE, attack_ms=1.5, release_fade_ms=12.0):
    """
    Cleans audio:
      1) DC blocking highpass at 25Hz
      2) 1.5ms smooth Hann attack fade-in
      3) Smooth Hann release fade-out at tail to ensure exact zero
      4) Soft saturation (tanh)
      5) Peak normalization to TARGET_PEAK_DBFS (-1.0 dBFS)
    """
    # 1. DC blocking
    processed = dc_block(samples, cutoff=25.0, sr=sr)
    n = len(processed)
    attack_samples = max(1, int(attack_ms * 0.001 * sr))
    fade_samples = max(1, int(release_fade_ms * 0.001 * sr))

    # 2. Smooth attack fade-in
    for i in range(min(attack_samples, n)):
        fade = 0.5 * (1.0 - math.cos(math.pi * i / attack_samples))
        processed[i] *= fade

    # 3. Smooth release fade-out at tail
    for i in range(max(0, n - fade_samples), n):
        idx_from_end = n - 1 - i
        fade = 0.5 * (1.0 - math.cos(math.pi * idx_from_end / fade_samples))
        processed[i] *= fade

    # 4. Soft saturation (tanh)
    processed = [math.tanh(s) for s in processed]

    # 5. Peak normalization
    max_val = max(abs(s) for s in processed) if processed else 0.0
    if max_val > 1e-7:
        scale = TARGET_PEAK_AMP / max_val
        processed = [s * scale for s in processed]

    return processed


def write_wav_file(filepath, samples, sr=SAMPLE_RATE):
    """Writes 16-bit mono PCM WAV file."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(str(filepath), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        packed_frames = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            val = int(round(clamped * 32767.0))
            packed_frames.extend(struct.pack("<h", val))
        wf.writeframes(packed_frames)


def compute_audio_stats(samples):
    """Computes peak dBFS and RMS dBFS."""
    if not samples:
        return -999.0, -999.0
    peak = max(abs(s) for s in samples)
    peak_db = 20.0 * math.log10(peak) if peak > 1e-9 else -120.0
    sum_sq = sum(s * s for s in samples)
    rms = math.sqrt(sum_sq / len(samples))
    rms_db = 20.0 * math.log10(rms) if rms > 1e-9 else -120.0
    return peak_db, rms_db


# ==============================================================================
# Foley & Mystic Synthesizers
# ==============================================================================

def synthesize_tarot_shuffle(sr=SAMPLE_RATE, duration=0.60, seed=777):
    """
    1. tarot_shuffle.wav (~0.60s):
    Card shuffling sound:
      - Phase 1: Rapid cascade of paper card riffles/flicks (26 micro card snaps spaced ~10-18ms)
        accelerating slightly then decelerating as thumbs release the deck.
      - Phase 2: Textured card-on-card sliding friction (filtered bandpass noise modulated by card movement).
      - Phase 3: Final satisfying squaring/tap of the card deck against the felt/table surface at ~0.49s.
    """
    rng = random.Random(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # Layer A: Ambient paper sliding friction (pink noise through dynamic bandpass)
    friction_raw = generate_pink_noise(num_samples, rng)
    # Bandpass filter around 2800Hz with moderate Q
    flt_fric = BiquadFilter("bandpass", 2800.0, q=1.5, sr=sr)
    for i in range(num_samples):
        t = i / sr
        # Modulate envelope: build up during riffle, dip slightly, swell into bridge, then finish
        if t < 0.45:
            # Riffle phase friction
            env = math.sin(math.pi * t / 0.45) ** 1.3 * 0.45
        elif t < 0.52:
            # Waterfall bridge gather
            env = 0.35 * (1.0 - (t - 0.45) / 0.07)
        else:
            env = 0.05 * math.exp(-(t - 0.52) / 0.03)

        sample = flt_fric.process(friction_raw[i])
        buffer[i] += sample * env

    # Layer B: Individual card riffle snaps (26 cards)
    # Timing profile: start at t=0.04s, accelerate towards center, decelerate until 0.42s
    card_times = []
    t_curr = 0.035
    for c in range(26):
        progress = c / 25.0
        # Interval ranges from 18ms at edges to 11ms in the middle
        interval = 0.018 - 0.007 * math.sin(math.pi * progress) + rng.uniform(-0.0015, 0.0015)
        card_times.append(t_curr)
        t_curr += interval
        if t_curr >= 0.44:
            break

    # Synthesize each card snap
    for c_idx, ct in enumerate(card_times):
        start_sample = int(ct * sr)
        snap_duration = rng.uniform(0.012, 0.018)  # 12-18ms snap
        snap_len = int(snap_duration * sr)
        freq = rng.uniform(3200.0, 5200.0)  # High paper snap resonant frequency
        q = rng.uniform(2.5, 4.0)
        snap_flt = BiquadFilter("bandpass", freq, q=q, sr=sr)
        snap_amp = rng.uniform(0.35, 0.65) * (0.7 + 0.3 * math.sin(math.pi * c_idx / len(card_times)))

        for j in range(snap_len):
            idx = start_sample + j
            if idx >= num_samples:
                break
            tj = j / sr
            # Sharp attack, fast exponential decay
            snap_env = math.exp(-tj / 0.0035)
            # Noise burst + slight resonant tone
            burst = rng.uniform(-1.0, 1.0) * 0.8 + 0.2 * math.sin(2.0 * math.pi * freq * tj)
            filtered = snap_flt.process(burst)
            # Low card body micro-thump (240Hz)
            thump = math.sin(2.0 * math.pi * 240.0 * tj) * math.exp(-tj / 0.005) * 0.35
            buffer[idx] += (filtered * 0.85 + thump) * snap_env * snap_amp

    # Layer C: Final squaring / table deck tap at t=0.485s
    tap_start = int(0.485 * sr)
    tap_len = int(0.09 * sr)
    tap_flt = BiquadFilter("bandpass", 2400.0, q=2.0, sr=sr)
    for j in range(tap_len):
        idx = tap_start + j
        if idx >= num_samples:
            break
        tj = j / sr
        # Firm felt/paper impact: 140Hz damped thud
        thud = math.sin(2.0 * math.pi * 140.0 * tj) * math.exp(-tj / 0.022) * 0.75
        # Crisp edge snap
        snap_burst = tap_flt.process(rng.uniform(-1.0, 1.0)) * math.exp(-tj / 0.008) * 0.7
        buffer[idx] += (thud + snap_burst) * 0.9

    return apply_master_envelope_and_normalize(buffer, sr=sr, attack_ms=2.0, release_fade_ms=18.0)


def synthesize_tarot_deal(sr=SAMPLE_RATE, duration=0.15, seed=888):
    """
    2. tarot_deal.wav (~0.15s):
    Crisp card flick/deal sound:
      - 0 to 25ms: Smooth paper slide across deck (rising friction frequency).
      - ~25ms: Sharp, crisp thumb flick & release transient (3500-6000Hz).
      - 35 to 140ms: Soft tactile paper body flutter & air whisper decaying cleanly.
    """
    rng = random.Random(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # 1. Slide across deck (0 - 35ms)
    slide_len = int(0.045 * sr)
    slide_noise = generate_pink_noise(slide_len, rng)
    flt_slide = BiquadFilter("bandpass", 2200.0, q=2.0, sr=sr)
    for i in range(slide_len):
        t = i / sr
        # Upward sweep in cutoff
        freq = 2000.0 + (t / 0.045) * 2200.0
        flt_slide.set_params("bandpass", freq, q=1.8)
        env = math.sin(math.pi * t / 0.045) * 0.5
        buffer[i] += flt_slide.process(slide_noise[i]) * env

    # 2. Main crisp card flick / snap transient at t=0.026s
    flick_sample = int(0.026 * sr)
    flick_len = int(0.055 * sr)
    flt_flick_hi = BiquadFilter("bandpass", 4600.0, q=3.2, sr=sr)
    flt_flick_mid = BiquadFilter("bandpass", 2600.0, q=2.5, sr=sr)
    for j in range(flick_len):
        idx = flick_sample + j
        if idx >= num_samples:
            break
        tj = j / sr
        # Rapid transient envelope (attack 0.5ms, decay 6ms)
        if tj < 0.0005:
            env = tj / 0.0005
        else:
            env = math.exp(-(tj - 0.0005) / 0.007)

        noise = rng.uniform(-1.0, 1.0)
        hi_click = flt_flick_hi.process(noise) * 0.8
        mid_click = flt_flick_mid.process(noise) * 0.5
        # Pitch chirp (4800Hz down to 2400Hz in 5ms)
        chirp_f = 2400.0 + 2400.0 * math.exp(-tj / 0.004)
        chirp = math.sin(2.0 * math.pi * chirp_f * tj) * 0.35

        buffer[idx] += (hi_click + mid_click + chirp) * env * 1.25

    # 3. Low body thud & card release flutter (leaving the deck)
    thump_sample = int(0.028 * sr)
    thump_len = int(0.07 * sr)
    for j in range(thump_len):
        idx = thump_sample + j
        if idx >= num_samples:
            break
        tj = j / sr
        # 160Hz damped card cardboard thud
        thud = math.sin(2.0 * math.pi * 155.0 * tj) * math.exp(-tj / 0.018) * 0.55
        buffer[idx] += thud

    # 4. Trailing air whisper
    air_len = int(0.08 * sr)
    air_start = int(0.045 * sr)
    flt_air = BiquadFilter("bandpass", 3200.0, q=1.2, sr=sr)
    for j in range(air_len):
        idx = air_start + j
        if idx >= num_samples:
            break
        tj = j / sr
        env = math.exp(-tj / 0.035) * 0.22
        air = flt_air.process(rng.uniform(-1.0, 1.0))
        buffer[idx] += air * env

    return apply_master_envelope_and_normalize(buffer, sr=sr, attack_ms=1.0, release_fade_ms=10.0)


def synthesize_tarot_flip(sr=SAMPLE_RATE, duration=0.18, seed=999):
    """
    3. tarot_flip.wav (~0.18s):
    Quick card flip Foley:
      - Lift & friction scrape (0 - 30ms)
      - Dynamic whipping turn-over snap at ~35ms
      - Landing slap / table contact at ~75ms with warm body thump
      - Crisp, tactile, and natural paper elasticity
    """
    rng = random.Random(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # 1. Card lift & thumb edge release friction (0 - 35ms)
    lift_len = int(0.035 * sr)
    flt_lift = BiquadFilter("bandpass", 2400.0, q=2.0, sr=sr)
    for i in range(lift_len):
        t = i / sr
        env = math.sin(math.pi * t / 0.035) * 0.4
        noise = rng.uniform(-1.0, 1.0)
        buffer[i] += flt_lift.process(noise) * env

    # 2. Main card turn-over snap / whip (t=0.035s)
    snap1_sample = int(0.035 * sr)
    snap1_len = int(0.045 * sr)
    flt_snap1 = BiquadFilter("bandpass", 4200.0, q=3.0, sr=sr)
    for j in range(snap1_len):
        idx = snap1_sample + j
        if idx >= num_samples:
            break
        tj = j / sr
        env = math.exp(-tj / 0.006)
        noise = rng.uniform(-1.0, 1.0)
        click = flt_snap1.process(noise)
        # Fluttering card resonance
        res = math.sin(2.0 * math.pi * 780.0 * tj) * 0.3 * math.exp(-tj / 0.012)
        buffer[idx] += (click * 0.9 + res) * env * 1.1

    # 3. Card landing slap on felt/table (t=0.072s)
    slap_sample = int(0.072 * sr)
    slap_len = int(0.085 * sr)
    flt_slap = BiquadFilter("bandpass", 2800.0, q=2.2, sr=sr)
    for j in range(slap_len):
        idx = slap_sample + j
        if idx >= num_samples:
            break
        tj = j / sr
        env = math.exp(-tj / 0.015)
        # Low paper-on-table thump (135Hz)
        thump = math.sin(2.0 * math.pi * 135.0 * tj) * math.exp(-tj / 0.025) * 0.65
        # Crisp edge contact
        click = flt_slap.process(rng.uniform(-1.0, 1.0)) * math.exp(-tj / 0.008) * 0.6
        buffer[idx] += (thump + click) * env * 1.0

    # 4. Subtle trailing paper settle flutter (80ms - 170ms)
    settle_start = int(0.080 * sr)
    settle_len = int(0.090 * sr)
    flt_settle = BiquadFilter("bandpass", 3400.0, q=1.5, sr=sr)
    for j in range(settle_len):
        idx = settle_start + j
        if idx >= num_samples:
            break
        tj = j / sr
        env = math.exp(-tj / 0.030) * 0.25
        buffer[idx] += flt_settle.process(rng.uniform(-1.0, 1.0)) * env

    return apply_master_envelope_and_normalize(buffer, sr=sr, attack_ms=1.2, release_fade_ms=12.0)


def synthesize_tarot_select(sr=SAMPLE_RATE, duration=0.50, seed=1234):
    """
    4. tarot_select.wav (~0.50s):
    Firm card impact / selection with a subtle mystic crystalline shimmer:
      - Layer 1: Firm tactile card placement / selection impact:
        * Sharp edge click (3200Hz, 8ms decay)
        * Solid low-end velvet table thud (110Hz -> 65Hz body thump, 50ms decay)
      - Layer 2: Subtle mystic crystalline shimmer / celestial bell layer:
        * High-purity crystalline chimes (E6, G#6, B6, E7 celestial harmonics)
        * Gentle tremolo shimmer (6.5Hz) & exponential decay lingering gracefully to ~0.48s
        * Sparkling high-shelf aura without harshness
    """
    rng = random.Random(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # ==========================
    # Layer 1: Tactile Card Impact (0 - 100ms)
    # ==========================
    impact_len = int(0.12 * sr)
    flt_impact_snap = BiquadFilter("bandpass", 3200.0, q=2.8, sr=sr)
    flt_impact_mid = BiquadFilter("bandpass", 1600.0, q=2.0, sr=sr)

    for i in range(impact_len):
        t = i / sr
        # Low body thump: pitch sweeps smoothly 120Hz -> 68Hz
        thump_pitch = 68.0 + 52.0 * math.exp(-t / 0.02)
        thump_env = math.exp(-t / 0.038)
        thump = math.sin(2.0 * math.pi * thump_pitch * t) * thump_env * 0.75

        # Crisp paper edge snap
        snap_env = math.exp(-t / 0.007)
        noise = rng.uniform(-1.0, 1.0)
        snap = (flt_impact_snap.process(noise) * 0.7 + flt_impact_mid.process(noise) * 0.4) * snap_env

        buffer[i] += (thump + snap) * 0.95

    # ==========================
    # Layer 2: Mystic Crystalline Shimmer (0 - 500ms)
    # ==========================
    # Celestial crystal chord harmonics (clean, ethereal, magical)
    # Base frequencies: E6 (1318.5Hz), G#6 (1661.2Hz), B6 (1975.5Hz), D#7 (2489.0Hz), E7 (2637.0Hz), G#7 (3322.4Hz)
    chimes = [
        (1318.5, 0.42, 0.16),  # (freq, amp, decay_tau)
        (1661.2, 0.38, 0.14),
        (1975.5, 0.32, 0.12),
        (2489.0, 0.22, 0.10),
        (2637.0, 0.28, 0.11),
        (3322.4, 0.18, 0.08),
        (3951.0, 0.12, 0.07),  # sparkle overtone
    ]

    for freq, amp, decay_tau in chimes:
        phase = rng.uniform(0.0, 2.0 * math.pi)
        # Detune partner for chorus shimmer
        freq2 = freq + rng.uniform(-1.8, 1.8)
        phase2 = rng.uniform(0.0, 2.0 * math.pi)

        for i in range(num_samples):
            t = i / sr
            # Crystal chime envelope: fast soft bloom (3ms attack) then long smooth decay
            bloom = min(1.0, t / 0.006)
            env = bloom * math.exp(-t / decay_tau)
            # Subtle mystic shimmer tremolo (~6.5Hz modulation)
            tremolo = 1.0 + 0.18 * math.sin(2.0 * math.pi * 6.5 * t)

            wave_val = (math.sin(2.0 * math.pi * freq * t + phase) * 0.65
                        + math.sin(2.0 * math.pi * freq2 * t + phase2) * 0.35)
            buffer[i] += wave_val * env * tremolo * amp * 0.55

    # Layer 3: Airy fairy-dust sparkle burst (bandpass filtered noise 6500Hz)
    sparkle_len = int(0.25 * sr)
    flt_sparkle = BiquadFilter("bandpass", 6800.0, q=3.5, sr=sr)
    for j in range(sparkle_len):
        tj = j / sr
        env = math.sin(math.pi * min(1.0, tj / 0.04)) * math.exp(-tj / 0.07) * 0.15
        noise = rng.uniform(-1.0, 1.0)
        buffer[j] += flt_sparkle.process(noise) * env

    return apply_master_envelope_and_normalize(buffer, sr=sr, attack_ms=1.5, release_fade_ms=25.0)


# ==============================================================================
# Main Generation Runner
# ==============================================================================

SOUND_REGISTRY = {
    "tarot_shuffle.wav": (synthesize_tarot_shuffle, 0.60, "Card shuffling sound (0.60s)"),
    "tarot_deal.wav": (synthesize_tarot_deal, 0.15, "Crisp card flick/deal sound (0.15s)"),
    "tarot_flip.wav": (synthesize_tarot_flip, 0.18, "Quick card flip Foley (0.18s)"),
    "tarot_select.wav": (synthesize_tarot_select, 0.50, "Firm card impact & mystic shimmer (0.50s)"),
}


def main():
    parser = argparse.ArgumentParser(description="Generate procedural Tarot SFX WAV files.")
    parser.add_argument(
        "--output-dir",
        type=str,
        default=r"e:\Agent\5MinuteMore\5min more\sfx\tarot",
        help="Target output directory for WAV files"
    )
    args = parser.parse_args()

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"=== Generating Tarot SFX into: {out_dir} ===")

    for filename, (synth_fn, expected_dur, desc) in SOUND_REGISTRY.items():
        filepath = out_dir / filename
        samples = synth_fn(sr=SAMPLE_RATE, duration=expected_dur)
        write_wav_file(filepath, samples, sr=SAMPLE_RATE)
        peak_db, rms_db = compute_audio_stats(samples)
        actual_dur = len(samples) / SAMPLE_RATE
        print(f"  [OK] {filename:<18} | {desc}")
        print(f"       Duration: {actual_dur:.3f}s ({len(samples)} samples) | Peak: {peak_db:.2f} dBFS | RMS: {rms_db:.2f} dBFS")

    print("\nAll 4 Tarot SFX generated successfully.")


if __name__ == "__main__":
    main()
