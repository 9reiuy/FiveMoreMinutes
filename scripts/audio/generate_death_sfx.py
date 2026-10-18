#!/usr/bin/env python3
"""
Procedural Audio Synthesis for Visceral Enemy Death Sound Effects
Project: 5MinuteMore
Target Directory: sfx/audition_candidates/

Generates 5 distinct high-quality visceral/meaty death sound effects in 16-bit 44.1kHz PCM mono:
  1) enemy_death_visceral_heavy.wav    (~0.22s, deep sub 50->30Hz, wet flesh tear, heavy body collapse)
  2) enemy_death_visceral_crunch.wav   (~0.18s, sharp bone crack 1800Hz, wet crunch splatter, 65Hz thump)
  3) enemy_death_visceral_squelch.wav  (~0.20s, multi-bubble wet blood splatter, gore burst, 55Hz sub)
  4) enemy_death_visceral_cinematic.wav(~0.15s, ultra-tight cinematic transient, visceral punch, fast decay)
  5) enemy_death_visceral_neoretro.wav (~0.16s, 12-bit retro texture, low-pass filter, crisp transient)

Features:
  - Pure Python standard library (wave, math, struct, random, os, sys, pathlib)
  - Soft saturation (tanh) for punch and body without harsh digital clipping
  - Smooth 1ms fade-in attack and exponential release fade-out to prevent clicks/pops
  - Peak normalization to -1.0 dBFS (~0.89125 amplitude)
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
        freq = max(10.0, min(float(freq), self.sr * 0.49))
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
    """Filters a whole buffer of audio samples using BiquadFilter."""
    flt = BiquadFilter(ftype, freq, q, sr)
    out = [0.0] * len(samples)
    for i, s in enumerate(samples):
        out[i] = flt.process(s)
    return out


def apply_master_envelope_and_normalize(samples, sr=SAMPLE_RATE, attack_ms=1.0, release_fade_ms=8.0):
    """
    Applies:
      1) 1ms smooth Hann attack fade-in
      2) Smooth exponential / Hann release fade-out at tail to ensure exact zero
      3) Soft saturation (tanh)
      4) Normalization to -1.0 dBFS (~0.89125 peak amplitude)
    """
    n = len(samples)
    attack_samples = max(1, int(attack_ms * 0.001 * sr))
    fade_samples = max(1, int(release_fade_ms * 0.001 * sr))

    processed = list(samples)

    # 1ms smooth attack fade-in
    for i in range(min(attack_samples, n)):
        fade = 0.5 * (1.0 - math.cos(math.pi * i / attack_samples))
        processed[i] *= fade

    # Release fade-out at the tail
    for i in range(max(0, n - fade_samples), n):
        idx_from_end = n - 1 - i
        fade = 0.5 * (1.0 - math.cos(math.pi * idx_from_end / fade_samples))
        processed[i] *= fade

    # Soft saturation (tanh)
    processed = [math.tanh(s) for s in processed]

    # Peak normalization to -1.0 dBFS
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


# ==============================================================================
# Sound Synthesizers
# ==============================================================================

def synthesize_death_heavy(sr=SAMPLE_RATE, duration=0.22, seed=101):
    """
    Candidate 1: enemy_death_visceral_heavy.wav (~0.22s)
    - Deep Sub-thud (50Hz -> 30Hz)
    - Thick wet flesh tearing (squelch bandpass noise)
    - Heavy body collapse
    """
    random.seed(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # 1. Deep Sub-thud (50Hz -> 30Hz) with saturated harmonics
    phase = 0.0
    for i in range(num_samples):
        t = i / sr
        # Pitch drops smoothly from 62Hz down towards 28Hz, settling at 30Hz
        freq = 30.0 + 32.0 * math.exp(-t / 0.075)
        phase += 2.0 * math.pi * freq / sr

        # Saturated sub waveform with 2nd and 3rd harmonics
        sub = (
            math.sin(phase)
            + 0.32 * math.sin(2.0 * phase)
            + 0.12 * math.sin(3.0 * phase)
        )
        # Deep body envelope
        env = math.exp(-t / 0.085)
        buffer[i] += sub * env * 1.05

    # 2. Thick wet flesh tearing (squelch bandpass noise with micro-tears)
    tear_flt1 = BiquadFilter("bandpass", 1500.0, q=2.8, sr=sr)
    tear_flt2 = BiquadFilter("bandpass", 850.0, q=3.2, sr=sr)
    squelch_flt = BiquadFilter("bandpass", 2200.0, q=4.0, sr=sr)

    for i in range(num_samples):
        t = i / sr
        white = random.uniform(-1.0, 1.0)

        # Dynamic filter sweep simulating tearing skin & muscle tissue
        cf1 = 500.0 + 1100.0 * math.exp(-t / 0.065)
        tear_flt1.set_params("bandpass", cf1, q=2.8)

        cf2 = 300.0 + 750.0 * math.exp(-t / 0.09)
        tear_flt2.set_params("bandpass", cf2, q=3.2)

        # Flesh squelch resonance
        cf_sq = 900.0 + 1400.0 * math.exp(-t / 0.04)
        squelch_flt.set_params("bandpass", cf_sq, q=3.8)

        tear_val = (
            0.65 * tear_flt1.process(white)
            + 0.55 * tear_flt2.process(white)
            + 0.40 * squelch_flt.process(white)
        )

        # Tearing micro-bursts envelope: jagged pulses at t=8ms, 25ms, 45ms, 70ms
        micro_flutter = (
            1.0
            + 0.45 * math.sin(2.0 * math.pi * 55.0 * t)
            + 0.25 * math.sin(2.0 * math.pi * 115.0 * t)
        )
        tear_env = (t / 0.008) * math.exp(-t / 0.055) if t < 0.008 else math.exp(-t / 0.055)
        tear_env *= micro_flutter

        buffer[i] += tear_val * tear_env * 0.95

    # 3. Heavy body collapse (low rumble impact hitting floor at ~35ms)
    collapse_flt = BiquadFilter("lowpass", 130.0, q=1.2, sr=sr)
    collapse_phase = 0.0
    for i in range(num_samples):
        t = i / sr
        if t >= 0.025:
            t_col = t - 0.025
            white = random.uniform(-1.0, 1.0)
            rumble = collapse_flt.process(white)

            col_freq = 42.0 + 20.0 * math.exp(-t_col / 0.05)
            collapse_phase += 2.0 * math.pi * col_freq / sr
            thud = math.sin(collapse_phase)

            col_env = (t_col / 0.01) * math.exp(-t_col / 0.065) if t_col < 0.01 else math.exp(-t_col / 0.065)
            buffer[i] += (rumble * 0.7 + thud * 0.6) * col_env * 0.85

    # 4. Initial transient punch click (first 4ms)
    click_flt = BiquadFilter("highpass", 1200.0, q=1.5, sr=sr)
    for i in range(min(num_samples, int(0.006 * sr))):
        t = i / sr
        click_val = click_flt.process(random.uniform(-1.0, 1.0))
        click_env = math.exp(-t / 0.0018)
        buffer[i] += click_val * click_env * 0.65

    return apply_master_envelope_and_normalize(buffer, sr, attack_ms=1.0, release_fade_ms=10.0)


def synthesize_death_crunch(sr=SAMPLE_RATE, duration=0.18, seed=202):
    """
    Candidate 2: enemy_death_visceral_crunch.wav (~0.18s)
    - Sharp transient bone crack (1800Hz transient)
    - Wet crunch splatter
    - Punchy 65Hz body thump
    """
    random.seed(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # 1. Sharp transient bone crack (1800Hz resonant crack with secondary fracture)
    crack_flt1 = BiquadFilter("bandpass", 1800.0, q=4.5, sr=sr)
    crack_flt2 = BiquadFilter("bandpass", 3200.0, q=3.5, sr=sr)
    crack_flt3 = BiquadFilter("highpass", 2400.0, q=2.0, sr=sr)

    # Sharp initial crack impulse cluster (staggered micro-fractures at 0ms, 1.8ms, 5.2ms, 11ms)
    fracture_times = [0.0, 0.0018, 0.0052, 0.011]
    fracture_weights = [1.0, 0.75, 0.55, 0.35]

    for i in range(num_samples):
        t = i / sr
        # Calculate instantaneous fracture impulse + white noise
        fracture_burst = 0.0
        for f_t, f_w in zip(fracture_times, fracture_weights):
            if t >= f_t:
                dt = t - f_t
                fracture_burst += f_w * random.uniform(-1.0, 1.0) * math.exp(-dt / 0.0035)

        c1 = crack_flt1.process(fracture_burst)
        c2 = crack_flt2.process(fracture_burst)
        c3 = crack_flt3.process(fracture_burst)

        # Bone crack crisp asymmetric fold
        crack_sum = 0.75 * c1 + 0.50 * c2 + 0.30 * c3
        if crack_sum > 0.35:
            crack_sum = 0.35 + (crack_sum - 0.35) * 0.25
        elif crack_sum < -0.35:
            crack_sum = -0.35 + (crack_sum + 0.35) * 0.25

        crack_env = math.exp(-t / 0.032)
        buffer[i] += crack_sum * crack_env * 1.45

    # 2. Wet crunch splatter (viscous fluid splattering around broken bone)
    splat_flt1 = BiquadFilter("bandpass", 1400.0, q=2.5, sr=sr)
    splat_flt2 = BiquadFilter("bandpass", 2400.0, q=3.0, sr=sr)
    for i in range(num_samples):
        t = i / sr
        white = random.uniform(-1.0, 1.0)

        # Rapidly modulate splatter center frequencies
        cf1 = 700.0 + 800.0 * math.exp(-t / 0.045)
        splat_flt1.set_params("bandpass", cf1, q=2.5)

        cf2 = 1200.0 + 1400.0 * math.exp(-t / 0.06)
        splat_flt2.set_params("bandpass", cf2, q=3.0)

        splat_val = 0.6 * splat_flt1.process(white) + 0.4 * splat_flt2.process(white)
        # Wet droplets AM modulation
        splat_am = 1.0 + 0.6 * math.sin(2.0 * math.pi * 75.0 * t)
        splat_env = (t / 0.005) * math.exp(-t / 0.048) if t < 0.005 else math.exp(-t / 0.048)
        buffer[i] += splat_val * splat_env * splat_am * 0.85

    # 3. Punchy 65Hz body thump (95Hz dropping quickly to 65Hz)
    sub_phase = 0.0
    for i in range(num_samples):
        t = i / sr
        freq = 65.0 + 35.0 * math.exp(-t / 0.028)
        sub_phase += 2.0 * math.pi * freq / sr

        sub_val = math.sin(sub_phase) + 0.25 * math.sin(2.0 * sub_phase)
        sub_env = math.exp(-t / 0.055)
        buffer[i] += sub_val * sub_env * 0.95

    return apply_master_envelope_and_normalize(buffer, sr, attack_ms=1.0, release_fade_ms=8.0)


def synthesize_death_squelch(sr=SAMPLE_RATE, duration=0.20, seed=303):
    """
    Candidate 3: enemy_death_visceral_squelch.wav (~0.20s)
    - Multi-bubble wet blood splatter
    - Visceral gore burst
    - 55Hz sub impact
    """
    random.seed(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # 1. 55Hz Sub Impact (75Hz -> 55Hz punch)
    sub_phase = 0.0
    for i in range(num_samples):
        t = i / sr
        freq = 55.0 + 28.0 * math.exp(-t / 0.035)
        sub_phase += 2.0 * math.pi * freq / sr

        sub_val = math.sin(sub_phase) + 0.22 * math.sin(2.0 * sub_phase)
        sub_env = math.exp(-t / 0.075)
        buffer[i] += sub_val * sub_env * 0.90

    # 2. Visceral Gore Burst (broadband gooey rupture at t=0)
    gore_flt1 = BiquadFilter("bandpass", 950.0, q=2.0, sr=sr)
    gore_flt2 = BiquadFilter("bandpass", 1750.0, q=2.8, sr=sr)
    gore_low = BiquadFilter("lowpass", 280.0, q=1.0, sr=sr)

    for i in range(num_samples):
        t = i / sr
        white = random.uniform(-1.0, 1.0)

        # Formant squelch sweep
        cf1 = 450.0 + 700.0 * math.exp(-t / 0.05)
        gore_flt1.set_params("bandpass", cf1, q=2.2)

        cf2 = 800.0 + 1200.0 * math.exp(-t / 0.07)
        gore_flt2.set_params("bandpass", cf2, q=3.0)

        g1 = gore_flt1.process(white)
        g2 = gore_flt2.process(white)
        glow = gore_low.process(white)

        gore_env = (t / 0.004) * math.exp(-t / 0.052) if t < 0.004 else math.exp(-t / 0.052)
        buffer[i] += (0.6 * g1 + 0.45 * g2 + 0.4 * glow) * gore_env * 1.10

    # 3. Multi-bubble wet blood splatter (8 distinct micro-bubbles popping)
    bubbles = [
        # (t_start, f_start, f_end, decay_ms, amp)
        (0.003, 1400.0, 520.0, 0.012, 0.55),
        (0.014, 1150.0, 420.0, 0.015, 0.60),
        (0.028, 1600.0, 680.0, 0.011, 0.50),
        (0.045, 980.0,  340.0, 0.018, 0.65),
        (0.068, 1300.0, 480.0, 0.016, 0.55),
        (0.095, 850.0,  310.0, 0.022, 0.60),
        (0.125, 1100.0, 400.0, 0.018, 0.45),
        (0.150, 750.0,  280.0, 0.020, 0.40),
    ]

    for b_t, b_fstart, b_fend, b_decay, b_amp in bubbles:
        start_idx = int(b_t * sr)
        b_phase = random.uniform(0.0, 2.0 * math.pi)
        flt_bubble = BiquadFilter("bandpass", b_fstart, q=3.5, sr=sr)

        for i in range(start_idx, num_samples):
            dt = (i - start_idx) / sr
            # Rapid downward pitch sweep of bubble resonance
            freq = b_fend + (b_fstart - b_fend) * math.exp(-dt / (b_decay * 0.75))
            b_phase += 2.0 * math.pi * freq / sr

            bubble_sine = math.sin(b_phase)
            # Add tiny splash noise to the bubble pop
            splash_noise = flt_bubble.process(random.uniform(-1.0, 1.0))
            bubble_val = bubble_sine * 0.75 + splash_noise * 0.45

            b_env = (dt / 0.002) * math.exp(-dt / b_decay) if dt < 0.002 else math.exp(-dt / b_decay)
            buffer[i] += bubble_val * b_env * b_amp * 0.85

    return apply_master_envelope_and_normalize(buffer, sr, attack_ms=1.0, release_fade_ms=9.0)


def synthesize_death_cinematic(sr=SAMPLE_RATE, duration=0.15, seed=404):
    """
    Candidate 4: enemy_death_visceral_cinematic.wav (~0.15s)
    - Ultra-tight cinematic impact transient
    - Visceral punch
    - Fast clean decay
    """
    random.seed(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # 1. Ultra-tight transient click / slap (0 - 5ms)
    # Shaped Dirac-like wave + high frequency slap
    click_flt = BiquadFilter("highpass", 2200.0, q=1.8, sr=sr)
    click_mid = BiquadFilter("bandpass", 900.0, q=2.5, sr=sr)

    for i in range(min(num_samples, int(0.015 * sr))):
        t = i / sr
        w = random.uniform(-1.0, 1.0)
        c_high = click_flt.process(w)
        c_mid = click_mid.process(w)

        # Ultra-sharp front pulse
        pulse = math.sin(2.0 * math.pi * 3200.0 * t) * math.exp(-t / 0.0012)
        click_val = 0.55 * pulse + 0.45 * c_high + 0.35 * c_mid
        click_env = math.exp(-t / 0.0025)
        buffer[i] += click_val * click_env * 1.35

    # 2. Visceral punch (cinematic pitch sweep 165Hz -> 48Hz in 25ms)
    phase = 0.0
    for i in range(num_samples):
        t = i / sr
        # Steep cinematic exponential pitch drop
        freq = 46.0 + 120.0 * math.exp(-t / 0.016)
        phase += 2.0 * math.pi * freq / sr

        # Saturated punch wave with heavy sub fundamental
        punch = (
            math.sin(phase)
            + 0.38 * math.sin(2.0 * phase)
            + 0.16 * math.sin(3.0 * phase)
            + 0.08 * math.sin(4.0 * phase)
        )
        punch_env = math.exp(-t / 0.038)
        buffer[i] += punch * punch_env * 1.15

    # 3. Compressed mid-range visceral body burst (400-1100Hz noise punch)
    body_flt = BiquadFilter("bandpass", 650.0, q=1.6, sr=sr)
    for i in range(num_samples):
        t = i / sr
        w = random.uniform(-1.0, 1.0)
        cf = 400.0 + 500.0 * math.exp(-t / 0.025)
        body_flt.set_params("bandpass", cf, q=1.8)
        body_noise = body_flt.process(w)
        body_env = math.exp(-t / 0.028)
        buffer[i] += body_noise * body_env * 0.70

    # Fast clean decay: decay rate ensures no lingering tail
    for i in range(num_samples):
        t = i / sr
        decay_factor = math.exp(-t / 0.034)
        # Apply exponential decay shaping to overall mix
        buffer[i] *= (0.3 + 0.7 * decay_factor)

    return apply_master_envelope_and_normalize(buffer, sr, attack_ms=1.0, release_fade_ms=6.0)


def synthesize_death_neoretro(sr=SAMPLE_RATE, duration=0.16, seed=505):
    """
    Candidate 5: enemy_death_visceral_neoretro.wav (~0.16s)
    - 12-bit / saturated visceral punch with retro texture
    - Low-pass filter and crisp transient
    """
    random.seed(seed)
    num_samples = int(duration * sr)
    buffer = [0.0] * num_samples

    # 1. Visceral Punch core (115Hz -> 50Hz pitch drop)
    sub_phase = 0.0
    for i in range(num_samples):
        t = i / sr
        freq = 50.0 + 68.0 * math.exp(-t / 0.032)
        sub_phase += 2.0 * math.pi * freq / sr

        sub_val = math.sin(sub_phase) + 0.35 * math.sin(2.0 * sub_phase)
        sub_env = math.exp(-t / 0.052)
        buffer[i] += sub_val * sub_env * 1.05

    # 2. Mid punch & retro noise burst (saturated crunch)
    noise_flt = BiquadFilter("bandpass", 1100.0, q=1.8, sr=sr)
    for i in range(num_samples):
        t = i / sr
        w = random.uniform(-1.0, 1.0)
        n_val = noise_flt.process(w)
        n_env = math.exp(-t / 0.036)
        buffer[i] += n_val * n_env * 0.75

    # 3. Retro 12-bit Quantization + Sample & Hold vintage texture
    # Quantize to 12-bit (4096 discrete steps: -2048 to +2047)
    hold_val = 0.0
    for i in range(num_samples):
        # 2-sample hold to simulate 22.05kHz clock rate
        if i % 2 == 0:
            val = buffer[i]
            # Saturated drive into 12-bit quantizer
            val_driven = math.tanh(1.8 * val)
            # 12-bit quantization step
            hold_val = round(val_driven * 2048.0) / 2048.0
        buffer[i] = hold_val

    # 4. Low-pass filter (warm retro 2-pole smoothing filter at 2500Hz)
    lpf = BiquadFilter("lowpass", 2500.0, q=1.1, sr=sr)
    for i in range(num_samples):
        buffer[i] = lpf.process(buffer[i])

    # 5. Crisp transient overlay (sharp click so the hit cuts cleanly)
    click_hpf = BiquadFilter("highpass", 2800.0, q=2.0, sr=sr)
    for i in range(min(num_samples, int(0.008 * sr))):
        t = i / sr
        w = random.uniform(-1.0, 1.0)
        click_val = click_hpf.process(w)
        click_env = math.exp(-t / 0.0018)
        buffer[i] += click_val * click_env * 0.75

    return apply_master_envelope_and_normalize(buffer, sr, attack_ms=1.0, release_fade_ms=7.0)


# ==============================================================================
# Verification and File Summary
# ==============================================================================

def analyze_wav_file(filepath):
    """Inspects header, file size, peak amplitude, and duration."""
    path = Path(filepath)
    if not path.is_file():
        raise FileNotFoundError(f"File not found: {filepath}")

    file_size = path.stat().st_size

    with wave.open(str(path), "rb") as wf:
        nchannels = wf.getnchannels()
        sampwidth = wf.getsampwidth()
        framerate = wf.getframerate()
        nframes = wf.getnframes()
        duration = nframes / float(framerate)
        frames_bytes = wf.readframes(nframes)

    # Unpack 16-bit PCM mono
    samples = struct.unpack(f"<{nframes}h", frames_bytes)
    norm_samples = [s / 32767.0 for s in samples]

    peak_amp = max(abs(s) for s in norm_samples) if norm_samples else 0.0
    peak_dbfs = 20.0 * math.log10(max(1e-7, peak_amp))

    rms = math.sqrt(sum(s * s for s in norm_samples) / max(1, len(norm_samples)))
    rms_dbfs = 20.0 * math.log10(max(1e-7, rms))

    return {
        "path": str(path.resolve()),
        "name": path.name,
        "size_bytes": file_size,
        "channels": nchannels,
        "bit_depth": sampwidth * 8,
        "sample_rate": framerate,
        "n_frames": nframes,
        "duration_sec": duration,
        "peak_amplitude": peak_amp,
        "peak_dbfs": peak_dbfs,
        "rms_dbfs": rms_dbfs,
    }


# ==============================================================================
# Main Generation Pipeline
# ==============================================================================

CANDIDATES = [
    {
        "filename": "enemy_death_visceral_heavy.wav",
        "synthesizer": synthesize_death_heavy,
        "duration": 0.22,
        "desc": "Deep Sub-thud (50Hz -> 30Hz) + thick wet flesh tearing + heavy body collapse (~0.22s)",
        "freq_profile": "Sub: 50->30Hz sweep, Flesh: 1500->500Hz bandpass, Collapse: 130Hz lowpass",
    },
    {
        "filename": "enemy_death_visceral_crunch.wav",
        "synthesizer": synthesize_death_crunch,
        "duration": 0.18,
        "desc": "Sharp transient bone crack (1800Hz) + wet crunch splatter + punchy 65Hz body thump (~0.18s)",
        "freq_profile": "Transient: 1800Hz / 3200Hz crack, Splatter: 1400Hz bandpass, Sub: 95->65Hz",
    },
    {
        "filename": "enemy_death_visceral_squelch.wav",
        "synthesizer": synthesize_death_squelch,
        "duration": 0.20,
        "desc": "Multi-bubble wet blood splatter + visceral gore burst + 55Hz sub impact (~0.20s)",
        "freq_profile": "Sub: 55Hz impact, Rupture: 950Hz bandpass, 8x Bubbles: 1600->280Hz chirps",
    },
    {
        "filename": "enemy_death_visceral_cinematic.wav",
        "synthesizer": synthesize_death_cinematic,
        "duration": 0.15,
        "desc": "Ultra-tight cinematic impact transient + visceral punch + fast clean decay (~0.15s)",
        "freq_profile": "Click: 3200Hz pulse + 2200Hz HPF, Sub: 165->46Hz punch, Body: 650Hz burst",
    },
    {
        "filename": "enemy_death_visceral_neoretro.wav",
        "synthesizer": synthesize_death_neoretro,
        "duration": 0.16,
        "desc": "12-bit / saturated visceral punch with retro texture, low-pass filter and crisp transient (~0.16s)",
        "freq_profile": "Punch: 115->50Hz, Saturation: 12-bit quantize (2048 steps), LPF: 2500Hz, Click: 2800Hz HPF",
    },
]


def generate_all_death_sfx(output_dir=None):
    if output_dir is None:
        script_dir = Path(__file__).resolve().parent
        project_dir = script_dir.parent.parent
        output_dir = project_dir / "sfx" / "audition_candidates"
    else:
        output_dir = Path(output_dir)

    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"[Audio Generator] Output directory: {output_dir}")

    results = []

    for item in CANDIDATES:
        filename = item["filename"]
        target_path = output_dir / filename
        synth_fn = item["synthesizer"]
        duration = item["duration"]

        print(f"[Synthesizing] {filename} (target ~{duration:.2f}s)...")
        samples = synth_fn(sr=SAMPLE_RATE, duration=duration)
        write_wav_file(target_path, samples, sr=SAMPLE_RATE)

        # Inspect and verify
        stats = analyze_wav_file(target_path)
        stats["desc"] = item["desc"]
        stats["freq_profile"] = item["freq_profile"]
        results.append(stats)
        print(f"  -> Generated: {stats['size_bytes']} bytes, {stats['duration_sec']:.3f}s, "
              f"Peak: {stats['peak_dbfs']:.2f} dBFS, RMS: {stats['rms_dbfs']:.2f} dBFS")

    return results


def print_summary_report(results):
    print("\n" + "=" * 90)
    print("ENEMY DEATH SFX SYNTHESIS REPORT (5 Candidates)")
    print("=" * 90)
    for i, res in enumerate(results, 1):
        print(f"Candidate #{i}: {res['name']}")
        print(f"  - Full Path   : {res['path']}")
        print(f"  - File Size   : {res['size_bytes']} bytes")
        print(f"  - Format      : {res['sample_rate']} Hz, {res['bit_depth']}-bit PCM Mono ({res['channels']} ch)")
        print(f"  - Duration    : {res['duration_sec']:.4f} seconds ({res['n_frames']} frames)")
        print(f"  - Peak / RMS  : {res['peak_dbfs']:.2f} dBFS (Amp: {res['peak_amplitude']:.4f}) / {res['rms_dbfs']:.2f} dBFS")
        print(f"  - Profile     : {res['freq_profile']}")
        print(f"  - Description : {res['desc']}")
        print("-" * 90)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate procedural visceral enemy death sound effects.")
    parser.add_argument("--output-dir", type=str, default=None, help="Directory to save generated WAV files.")
    args = parser.parse_args()

    results = generate_all_death_sfx(args.output_dir)
    print_summary_report(results)
