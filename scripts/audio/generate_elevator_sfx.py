#!/usr/bin/env python3
"""
Procedural Audio Synthesis for Elevator Sound Effects
Project: 5MinuteMore
Target Directory: res://sfx/elevator_candidates/ (sfx/elevator_candidates/)

Produces an AUDITION PACK only.  Nothing here is wired into the game; the
player-facing integration (SFX event registration + elevator hookup) happens
after the project owner picks a candidate.

Candidates
----------
Arrival chime, round 2 -- pure voiced chimes (discrete, non-looping).
These replace round 1: sine-driven, harmonic-leaning partials, bowed-in attack,
small metallic-cab reverb.  No square wave, no striker noise.
  1) ding_classic_dingdong.wav  Descending G5->C5, canonical elevator, 1.50s
  2) ding_soft_modern.wav       C6+E6 major third with shimmer, 2.00s
  3) ding_bright_single.wav     Single bright E6, brief and clean, 1.00s
  4) ding_airy_gong.wav         Long airy slightly-inharmonic E5, 2.75s

Arrival chime, round 1 -- industrial mechanical bells.  REJECTED by the project
owner, kept only so this script reproduces everything ever delivered.  They are
excluded from the audition page via their `rejected` flag.
  5) ding_industrial_standard.wav
  6) ding_industrial_single.wav
  7) ding_industrial_dry.wav

Ride rumble -- seamless loops (no tail fade; loop point must not click):
  8) rumble_power_station_reuse.wav SELECTED. Reused in-project ambience, 4.0s
  9) rumble_motor_air.wav           Motor harmonic stack + air noise, 4.0s
 10) rumble_sub_pressure.wav        Sub-bass pressure bed, no clear pitch, 6.0s
 11) rumble_cable_friction.wav      Sheave/cable groan, periodic squeal, 5.0s

Engineering rules honoured here (mirrors generate_tarot_sfx.py / generate_death_sfx.py):
  - Pure Python standard library (wave, math, struct, random, array, pathlib)
  - 16-bit PCM 44100Hz mono output
  - 25Hz DC-blocker highpass, soft tanh saturation
  - Discrete cues: Hann fade in/out, peak-normalised to -1.0 dBFS
  - Seamless loops: every deterministic partial is snapped to a WHOLE number of
    periods inside the loop, and every stochastic layer is ring-crossfaded;
    loops are RMS-normalised instead of peak-normalised and get NO tail fade.
"""

import argparse
import array
import json
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
# Sustained ambience sits far below a transient cue on purpose.  A loop
# normalised to -1.0 dBFS peak would be unusably loud under gameplay.
TARGET_LOOP_RMS_DBFS = -20.0
TARGET_LOOP_RMS = 10.0 ** (TARGET_LOOP_RMS_DBFS / 20.0)
LOOP_PEAK_CEILING = 10.0 ** (-3.0 / 20.0)

## Audition metadata.  Titles and notes are what the project owner reads while
## choosing, so they describe intent and construction rather than marketing.
CANDIDATE_META = {
    # ---- Round 2: pure voiced chimes (replaces the rejected industrial set) ----
    "ding_classic_dingdong": {
        "group": "ding",
        "selected": True,
        "role": "楼层到达音",
        "title": "经典电梯钟 · 下行双音 G5→C5",
        "notes": "最标准的电梯「叮-咚」：两声下行、纯净正弦钟声、柔和起音、轻微金属厢体混响。没有方波、没有敲击噪声，靠分音比例和衰减塑形。辨识度最高、语义最直白的一个。",
        "trigger": "角色进入电梯到达楼层时触发（_commit_staged_transition_exit / _perform_game_start_cab_exit）。",
    },
    "ding_soft_modern": {
        "group": "ding",
        "title": "现代柔和 Chime · C6+E6 大三度",
        "notes": "两个音同时起（大三度），每个都带一条微失谐副线产生缓慢 shimmer（3.5/4.5Hz 拍频），起音 9ms 极柔、尾音近 2 秒。商场/写字楼现代电梯那种「高级但不刺耳」的听感。",
    },
    "ding_bright_single": {
        "group": "ding",
        "title": "明亮单声 Ding · E6",
        "notes": "只有一声、干脆明亮、1 秒收尾。欧美电梯的单音风格，最不占时间、最不容易在连续转场中变烦。信息量最小，但也最干净。",
    },
    "ding_airy_gong": {
        "group": "ding",
        "selected": True,
        "role": "员工卡获取音",
        "title": "空灵长尾 · E5 微非谐",
        "notes": "2.75 秒长尾、更暗（低通 2.5kHz）、分音带轻微非谐（2.05/3.12/4.61），空间感最大。最贴合 Dream 的压抑氛围，但存在感也最强、最容易拖慢节奏。",
        "trigger": "角色拿到本楼层员工卡后触发（collect_employee_badge，每层仅一次）。",
    },
    # ---- Round 1: rejected ----
    "ding_industrial_standard": {
        "group": "ding",
        "rejected": True,
        "title": "工业机械铃 · 标准双音 G5→C5（首轮·已否决）",
        "notes": "两声先后敲击（间隔 0.20s），非谐金属模态簇 + 带电方波边缘 + 继电器锤击咔声。",
    },
    "ding_industrial_single": {
        "group": "ding",
        "rejected": True,
        "title": "工业机械铃 · 单声重击 D6（首轮·已否决）",
        "notes": "单声、更沉，叠加 0.5×/0.667× 碗体低频模态。",
    },
    "ding_industrial_dry": {
        "group": "ding",
        "rejected": True,
        "title": "工业机械铃 · 干硬复古 E6（首轮·已否决）",
        "notes": "最短最干、方波成分最重，像老式继电器电子铃。",
    },
    "rumble_motor_air": {
        "group": "rumble",
        "title": "轰鸣 · 电机 + 风噪（写实向）",
        "notes": "55Hz 电机基频的 14 次谐波列，叠加 55.25Hz 微失谐副音形成 0.25Hz 缓慢「负载呼吸」，再加带通风噪与轿厢金属共振。听感就是一台真电梯在运行。",
    },
    "rumble_sub_pressure": {
        "group": "rumble",
        "title": "轰鸣 · 次低频压迫（氛围向）",
        "notes": "30/38/45/62Hz 四个互不谐和的低频 + 缓慢扫动的暗噪声底。刻意不给出明确基频，所以它读起来是「不安」而不是「机器」，压迫感最强。",
    },
    "rumble_cable_friction": {
        "group": "rumble",
        "title": "轰鸣 · 缆索金属摩擦（细节向）",
        "notes": "低频底噪 + 钢缆振动模态 + 每循环 6 次周期性金属吱嘎。信息量最大、最「老旧电梯」，但也最容易在长循环里被听出重复节奏。",
    },
    "rumble_power_station_reuse": {
        "group": "rumble",
        "selected": True,
        "role": "轿厢运行轰鸣",
        "title": "轰鸣 · 复用项目已有素材",
        "notes": "直接取用工程内 art/wallpaper/weather/AMBIENCE_UNDERGROUND_POWER_STATION_LOOP.wav（24-bit 原素材）做环形无缝化。零新增音频制作，风格与现有环境音天然统一。",
        "trigger": "进轿厢起 → 到达出轿厢停，带淡入淡出（_transition_to_independent_cab → _commit_staged_transition_exit）。",
    },
}

OUTPUT_DIR = Path(__file__).resolve().parent.parent.parent / "sfx" / "elevator_candidates"
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
POWER_STATION_SOURCE = (
    PROJECT_ROOT / "art" / "wallpaper" / "weather"
    / "AMBIENCE_UNDERGROUND_POWER_STATION_LOOP.wav"
)


# ==============================================================================
# DSP Building Blocks  (same Audio EQ Cookbook biquad as the tarot/death scripts)
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


def filter_signal(samples, ftype, freq, q=0.707, sr=SAMPLE_RATE, warmup_samples=0):
    """
    Filters a buffer of audio samples using a single BiquadFilter.

    `warmup_samples` pre-runs the filter over the tail of the buffer so its
    recursive state is already in steady state before sample 0 is produced.
    This matters enormously for looped material: without it, every filter
    starts from zero state and the first few thousand samples drift, which
    shows up as a step discontinuity at the loop splice.
    """
    flt = BiquadFilter(ftype, freq, q, sr)
    n = len(samples)
    if warmup_samples > 0 and n > 0:
        start = max(0, n - min(warmup_samples, n))
        for i in range(start, n):
            flt.process(samples[i])
    out = [0.0] * n
    for i in range(n):
        out[i] = flt.process(samples[i])
    return out


def dc_block(samples, cutoff=25.0, sr=SAMPLE_RATE, warmup_samples=0):
    """Highpass DC blocking filter."""
    return filter_signal(samples, "highpass", cutoff, q=0.707, sr=sr,
                         warmup_samples=warmup_samples)


def generate_white_noise(length, rng):
    """Generates uniform white noise in [-1.0, 1.0]."""
    return [rng.uniform(-1.0, 1.0) for _ in range(length)]


def generate_pink_noise(length, rng):
    """Generates approximate pink noise using Paul Kellet's filter."""
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
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


# ==============================================================================
# Discrete-cue post-processing (arrival chimes)
# ==============================================================================

def apply_master_envelope_and_normalize(samples, sr=SAMPLE_RATE, attack_ms=1.2,
                                        release_fade_ms=18.0):
    """
    Cleans a one-shot cue:
      1) DC blocking highpass at 25Hz
      2) short Hann attack fade-in (kills the click on a hard onset)
      3) Hann release fade-out at the tail to land exactly on zero
      4) soft saturation (tanh)
      5) peak normalisation to TARGET_PEAK_DBFS
    """
    processed = dc_block(samples, cutoff=25.0, sr=sr)
    n = len(processed)
    attack_samples = max(1, int(attack_ms * 0.001 * sr))
    fade_samples = max(1, int(release_fade_ms * 0.001 * sr))

    for i in range(min(attack_samples, n)):
        processed[i] *= 0.5 * (1.0 - math.cos(math.pi * i / attack_samples))

    for i in range(max(0, n - fade_samples), n):
        idx_from_end = n - 1 - i
        processed[i] *= 0.5 * (1.0 - math.cos(math.pi * idx_from_end / fade_samples))

    processed = [math.tanh(s) for s in processed]

    max_val = max(abs(s) for s in processed) if processed else 0.0
    if max_val > 1e-7:
        scale = TARGET_PEAK_AMP / max_val
        processed = [s * scale for s in processed]

    return processed


# ==============================================================================
# Seamless-loop machinery
# ==============================================================================

def snap_frequency(freq, loop_duration):
    """
    Snaps a frequency so a WHOLE number of periods fits the loop.

    This is the single most important trick for click-free ambience: if every
    deterministic partial completes an integer number of cycles between loop
    start and loop end, its phase (and therefore its sample value) matches
    exactly across the splice, so no discontinuity can be heard.
    """
    cycles = max(1, int(round(freq * loop_duration)))
    return cycles / loop_duration


def make_seamless_loop(extended, loop_len, xfade_len):
    """
    Ring-crossfade a longer-than-loop buffer down to exactly `loop_len`.

    `extended` must contain at least `loop_len + xfade_len` samples.  The head
    of the loop is crossfaded (equal-power sin/cos law) against the material
    that would have continued past the loop end, so the join is spectrally and
    energetically continuous.
    """
    if len(extended) < loop_len + xfade_len:
        raise ValueError("extended buffer is shorter than loop_len + xfade_len")
    out = list(extended[:loop_len])
    for i in range(xfade_len):
        t = i / float(xfade_len)
        fade_in = math.sin(t * math.pi * 0.5)
        fade_out = math.cos(t * math.pi * 0.5)
        out[i] = extended[loop_len + i] * fade_out + extended[i] * fade_in
    return out


def normalize_loop(samples, target_rms=TARGET_LOOP_RMS,
                   peak_ceiling=LOOP_PEAK_CEILING, sr=SAMPLE_RATE):
    """
    Prepares a sustained loop for playback.

    Unlike a one-shot cue this performs NO tail fade (that would create an
    audible gap every time the loop wraps).  It only DC-blocks, scales to a
    sane ambience RMS, and -- if the crest factor would push the peak too high
    -- backs the overall gain off so transients never clip.

    The DC blocker runs with a warmed-up filter state: an IIR filter starting
    from zero state would superimpose a settling transient on the head of the
    loop, which is precisely the step that clicks at the splice.
    """
    processed = dc_block(samples, cutoff=25.0, sr=sr,
                         warmup_samples=int(0.5 * sr))

    sum_sq = sum(s * s for s in processed)
    rms = math.sqrt(sum_sq / len(processed)) if processed else 0.0
    if rms > 1e-9:
        processed = [s * (target_rms / rms) for s in processed]

    peak = max(abs(s) for s in processed) if processed else 0.0
    if peak > peak_ceiling:
        processed = [s * (peak_ceiling / peak) for s in processed]

    return processed


def verify_loop_seam(samples, report_label):
    """
    Reports the discontinuity at the loop splice so a bad loop cannot slip
    through unnoticed.  `seam_delta` is the sample-to-sample step across the
    wrap; `seam_ratio` compares it to the largest step inside the loop.  A
    well-formed loop keeps the seam far below the material's own motion.
    """
    n = len(samples)
    if n < 4:
        return {}
    seam_delta = abs(samples[0] - samples[n - 1])
    internal_max = 0.0
    for i in range(1, n):
        d = abs(samples[i] - samples[i - 1])
        if d > internal_max:
            internal_max = d
    ratio = seam_delta / internal_max if internal_max > 1e-12 else 0.0
    print(f"      loop seam[{report_label}]: delta={seam_delta:.6f} "
          f"internal_max={internal_max:.6f} ratio={ratio:.3f}")
    return {"seam_delta": seam_delta, "ratio": ratio}


# ==============================================================================
# Industrial mechanical bell synthesis (arrival chime)
# ==============================================================================

# Modal ratios of a struck metal plate/tube.  Genuinely inharmonic -- this
# inharmonicity is what the ear reads as "metal" rather than "musical tone".
BELL_MODAL_RATIOS = (1.0, 2.76, 5.40, 8.93, 13.34)
BELL_MODAL_DECAYS = (0.55, 0.34, 0.22, 0.13, 0.08)
BELL_MODAL_AMPS = (1.00, 0.62, 0.40, 0.24, 0.15)


def band_limited_square(t, freq, sr=SAMPLE_RATE, odd_harmonics=13, rolloff=1.0):
    """
    Additive (band-limited) square wave.

    A naive square is a discontinuity generator and aliases badly; summing only
    the odd harmonics 1/k leaves the same buzzing, hard-edged character while
    staying clean at 44.1kHz.  `rolloff` controls how aggressively the upper
    harmonics are tamed (1.0 = classic square, higher = softer).
    """
    value = 0.0
    for k in range(1, odd_harmonics * 2, 2):
        if freq * k >= sr * 0.45:
            break
        value += math.sin(2.0 * math.pi * freq * k * t) / (k ** rolloff)
    return value


def bell_strike(
    freq,
    duration,
    sr=SAMPLE_RATE,
    modal_ratios=BELL_MODAL_RATIOS,
    modal_decays=BELL_MODAL_DECAYS,
    modal_amps=BELL_MODAL_AMPS,
    square_mix=0.34,
    square_harmonics=13,
    square_rolloff=1.1,
    square_decay=0.30,
    body_ratios=(),
    body_decay=0.90,
    body_amp=0.0,
):
    """
    A struck metal bell body: inharmonic modal cluster + hard square layer +
    optional low sub-modal "bowl" weight.
    """
    n = int(duration * sr)
    out = [0.0] * n

    for i in range(n):
        t = i / float(sr)
        v = 0.0

        # Inharmonic metal modes: the identity of the bell.
        for ratio, tau, amp in zip(modal_ratios, modal_decays, modal_amps):
            v += amp * math.exp(-t / tau) * math.sin(2.0 * math.pi * freq * ratio * t)

        # Hard, electrically-driven edge.
        if square_mix > 0.0:
            v += square_mix * math.exp(-t / square_decay) * band_limited_square(
                t, freq, sr, square_harmonics, square_rolloff)

        # Low modal weight (a larger bell/bowl body).
        for ratio in body_ratios:
            v += body_amp * math.exp(-t / body_decay) * math.sin(
                2.0 * math.pi * freq * ratio * t)

        out[i] = v

    return out


def hammer_transient(duration, rng, sr=SAMPLE_RATE, bands=(1800.0, 3200.0, 5400.0),
                     decays=(0.006, 0.004, 0.0025), amps=(0.34, 0.24, 0.15)):
    """
    The striker's contact noise: a very short, filtered burst of wideband
    energy.  Without this a bell sounds like it faded in rather than got hit.
    """
    n = int(duration * sr)
    noise = generate_white_noise(n, rng)
    out = [0.0] * n
    inv_sr = 1.0 / float(sr)
    for band, tau, amp in zip(bands, decays, amps):
        layer = filter_signal(noise, "bandpass", band, q=1.4, sr=sr)
        for i in range(n):
            out[i] += amp * math.exp(-(i * inv_sr) / tau) * layer[i]
    return out


def mix_into(target, source, offset_samples, gain=1.0):
    """Adds `source` into `target` starting at a sample offset."""
    limit = min(len(target) - offset_samples, len(source))
    for i in range(limit):
        target[offset_samples + i] += source[i] * gain
    return target


def build_ding_industrial_standard(rng):
    """Two-tone G5 -> C5 mechanical bell.  Classic elevator language, industrial voicing."""
    sr = SAMPLE_RATE
    total = 1.35
    out = [0.0] * int(total * sr)

    strike_hi = bell_strike(784.0, 0.95, sr)          # G5
    strike_lo = bell_strike(523.25, 1.15, sr,         # C5
                            modal_decays=(0.62, 0.38, 0.24, 0.14, 0.09),
                            square_mix=0.30,
                            square_decay=0.34)
    click_hi = hammer_transient(0.05, rng, sr)
    click_lo = hammer_transient(0.06, rng, sr, bands=(1500.0, 2800.0, 4800.0))

    mix_into(out, strike_hi, 0, 1.0)
    mix_into(out, click_hi, 0, 0.42)
    mix_into(out, strike_lo, int(0.20 * sr), 0.95)
    mix_into(out, click_lo, int(0.20 * sr), 0.40)

    return apply_master_envelope_and_normalize(out, sr)


def build_ding_industrial_single(rng):
    """One heavy D6 strike with a large bowl body.  Authoritative, no second note."""
    sr = SAMPLE_RATE
    total = 1.25
    out = [0.0] * int(total * sr)

    body = bell_strike(
        1174.66, 1.25, sr,
        modal_decays=(0.78, 0.48, 0.31, 0.18, 0.11),
        square_mix=0.36,
        square_harmonics=15,
        square_rolloff=1.05,
        square_decay=0.42,
        body_ratios=(0.5, 0.667),      # sub-octave and fifth of the bowl
        body_decay=0.85,
        body_amp=0.42,
    )
    click = hammer_transient(0.07, rng, sr,
                             bands=(1200.0, 2400.0, 4600.0, 7000.0),
                             decays=(0.0075, 0.005, 0.0032, 0.0018),
                             amps=(0.50, 0.34, 0.22, 0.12))

    mix_into(out, body, 0, 1.0)
    mix_into(out, click, 0, 0.55)

    return apply_master_envelope_and_normalize(out, sr)


def build_ding_industrial_dry(rng):
    """Short, dry, square-forward E6.  Retro industrial relay bell."""
    sr = SAMPLE_RATE
    total = 0.62
    out = [0.0] * int(total * sr)

    body = bell_strike(
        1318.51, 0.62, sr,
        modal_decays=(0.19, 0.125, 0.078, 0.046, 0.030),
        square_mix=0.62,               # square dominates: hard, digital edge
        square_harmonics=9,
        square_rolloff=0.85,
        square_decay=0.16,
    )
    click = hammer_transient(0.03, rng, sr,
                             bands=(2400.0, 4200.0),
                             decays=(0.0035, 0.0022),
                             amps=(0.40, 0.24))

    mix_into(out, body, 0, 1.0)
    mix_into(out, click, 0, 0.45)

    return apply_master_envelope_and_normalize(out, sr)


# ==============================================================================
# Voiced chime synthesis  (round 2 -- the non-mechanical directions)
# ==============================================================================

def simple_reverb(samples, sr=SAMPLE_RATE, mix=0.16,
                  combs=((0.0297, 0.805), (0.0371, 0.827), (0.0411, 0.783)),
                  allpasses=((0.0050, 0.70), (0.0017, 0.70))):
    """
    Lightweight Schroeder reverb: parallel combs, then series allpasses.

    A chime with no space around it sounds like a test tone.  A short tail is
    what makes it read as "a bell inside a metal cab".  Delays are in seconds;
    longer delays imply a larger space.
    """
    n = len(samples)
    wet = [0.0] * n
    comb_count = float(len(combs))
    for seconds, feedback in combs:
        delay = max(1, int(seconds * sr))
        buf = [0.0] * delay
        idx = 0
        for i in range(n):
            y = buf[idx]
            buf[idx] = samples[i] + y * feedback
            wet[i] += y / comb_count
            idx += 1
            if idx >= delay:
                idx = 0
    for seconds, g in allpasses:
        delay = max(1, int(seconds * sr))
        buf = [0.0] * delay
        idx = 0
        for i in range(n):
            buf_out = buf[idx]
            v = wet[i] + g * buf_out
            buf[idx] = v
            wet[i] = buf_out - g * v
            idx += 1
            if idx >= delay:
                idx = 0
    dry_gain = 1.0 - mix
    return [samples[i] * dry_gain + wet[i] * mix for i in range(n)]


def struck_chime(
    freq,
    duration,
    sr=SAMPLE_RATE,
    partials=(1.0, 2.0, 3.0, 4.2),
    decays=(0.70, 0.45, 0.30, 0.18),
    amps=(1.0, 0.34, 0.16, 0.08),
    attack_ms=4.0,
    lowpass_hz=5000.0,
    detune_hz=0.0,
):
    """
    Pure voiced chime: sine-driven, harmonic-leaning partials, gentle attack.

    This is intentionally the opposite construction to `bell_strike()`.  That
    one is square-driven, strongly inharmonic and hammered, which is exactly
    what makes it read as an industrial relay.  Here the ratios sit close to
    the harmonic series (so it still rings like a bell rather than an organ),
    the onset is bowed in rather than struck, and there is no striker noise at
    all.  `detune_hz` fans the whole partial stack into two near-unison voices
    which beat slowly against each other -- the shimmer of a modern chime.
    """
    n = int(duration * sr)
    inv_sr = 1.0 / float(sr)
    attack = max(1e-5, attack_ms * 0.001)

    if detune_hz > 0.0:
        voices = ((freq - detune_hz * 0.5, 0.76), (freq + detune_hz * 0.5, 0.76))
    else:
        voices = ((freq, 1.0),)

    out = [0.0] * n
    for i in range(n):
        t = i * inv_sr
        v = 0.0
        for vfreq, vgain in voices:
            for ratio, tau, amp in zip(partials, decays, amps):
                v += vgain * amp * math.exp(-t / tau) * math.sin(
                    2.0 * math.pi * vfreq * ratio * t)
        out[i] = v * (1.0 - math.exp(-t / attack))

    if lowpass_hz > 0.0:
        out = filter_signal(out, "lowpass", lowpass_hz, q=0.707, sr=sr)
    return out


def build_ding_classic_dingdong(rng):
    """Canonical descending two-tone elevator chime: G5 then C5. Pure, not industrial."""
    sr = SAMPLE_RATE
    total = 1.50
    out = [0.0] * int(total * sr)

    hi = struck_chime(784.0, 1.05, sr,
                      partials=(1.0, 2.0, 3.0, 4.2, 5.4),
                      decays=(0.68, 0.44, 0.29, 0.17, 0.10),
                      amps=(1.0, 0.34, 0.16, 0.075, 0.035),
                      attack_ms=4.0, lowpass_hz=5200.0)
    lo = struck_chime(523.25, 1.44, sr,
                      partials=(1.0, 2.0, 3.0, 4.2, 5.4),
                      decays=(0.86, 0.56, 0.36, 0.21, 0.13),
                      amps=(1.0, 0.36, 0.17, 0.080, 0.040),
                      attack_ms=4.5, lowpass_hz=4600.0)

    mix_into(out, hi, 0, 1.0)
    mix_into(out, lo, int(0.22 * sr), 0.92)

    wet = simple_reverb(out, sr, mix=0.15)
    return apply_master_envelope_and_normalize(wet, sr, attack_ms=1.0,
                                               release_fade_ms=40.0)


def build_ding_soft_modern(rng):
    """Warm major third (C6+E6) with slow shimmer. Modern lobby / premium elevator."""
    sr = SAMPLE_RATE
    total = 2.00
    out = [0.0] * int(total * sr)

    c6 = struck_chime(1046.50, 1.90, sr,
                      partials=(1.0, 1.5, 2.0),
                      decays=(1.25, 0.72, 0.42),
                      amps=(1.0, 0.20, 0.090),
                      attack_ms=9.0, lowpass_hz=3400.0, detune_hz=3.5)
    e6 = struck_chime(1318.51, 1.65, sr,
                      partials=(1.0, 1.5, 2.0),
                      decays=(1.05, 0.60, 0.34),
                      amps=(0.78, 0.16, 0.070),
                      attack_ms=9.0, lowpass_hz=3400.0, detune_hz=4.5)

    mix_into(out, c6, 0, 1.0)
    mix_into(out, e6, 0, 1.0)

    wet = simple_reverb(out, sr, mix=0.20)
    return apply_master_envelope_and_normalize(wet, sr, attack_ms=1.0,
                                               release_fade_ms=50.0)


def build_ding_bright_single(rng):
    """Single bright clean ding (E6). Western elevator style: unambiguous and brief."""
    sr = SAMPLE_RATE
    total = 1.00
    out = [0.0] * int(total * sr)

    bell = struck_chime(1318.51, 0.92, sr,
                        partials=(1.0, 2.0, 2.99, 4.5),
                        decays=(0.42, 0.24, 0.13, 0.065),
                        amps=(1.0, 0.28, 0.12, 0.050),
                        attack_ms=2.5, lowpass_hz=6800.0)
    mix_into(out, bell, 0, 1.0)

    wet = simple_reverb(out, sr, mix=0.12)
    return apply_master_envelope_and_normalize(wet, sr, attack_ms=0.8,
                                               release_fade_ms=30.0)


def build_ding_airy_gong(rng):
    """Long, airy, gently inharmonic single tone (E5). Fits the Dream / uneasy mood."""
    sr = SAMPLE_RATE
    total = 2.75
    out = [0.0] * int(total * sr)

    body = struck_chime(659.25, 2.62, sr,
                        partials=(1.0, 2.05, 3.12, 4.61, 6.20),
                        decays=(1.70, 1.15, 0.78, 0.46, 0.28),
                        amps=(1.0, 0.34, 0.18, 0.10, 0.050),
                        attack_ms=14.0, lowpass_hz=2500.0, detune_hz=2.2)
    mix_into(out, body, 0, 1.0)

    # Bigger implied space than the other chimes: longer comb delays.
    wet = simple_reverb(out, sr, mix=0.26,
                        combs=((0.0351, 0.830), (0.0457, 0.850), (0.0533, 0.810)))
    return apply_master_envelope_and_normalize(wet, sr, attack_ms=2.0,
                                               release_fade_ms=80.0)


# ==============================================================================
# Ride rumble synthesis (seamless loops)
# ==============================================================================

def build_rumble_motor_air(rng):
    """Motor harmonic stack + forced-air noise + cab metal resonance, 4.0s.

    Two slightly detuned motor fundamentals beat against each other (0.25Hz,
    one full cycle per loop) which is what makes a machine sound like it is
    *running* rather than just droning.
    """
    sr = SAMPLE_RATE
    loop_dur = 4.0
    loop_len = int(loop_dur * sr)
    xfade = int(0.5 * sr)
    total_len = loop_len + xfade

    base = 55.0
    fund_a = snap_frequency(base, loop_dur)        # 220 cycles
    fund_b = snap_frequency(base + 0.25, loop_dur)  # 221 cycles -> 0.25Hz beat
    lfo_freq = snap_frequency(0.25, loop_dur)      # 1 cycle per loop

    motor = [0.0] * total_len
    for i in range(total_len):
        t = i / float(sr)
        v = 0.0
        # Harmonic stack of the mains-driven motor.
        for k in range(1, 15):
            f = snap_frequency(base * k, loop_dur)
            v += math.sin(2.0 * math.pi * f * t) / (k ** 1.25)
        v *= 0.42
        v += 0.30 * math.sin(2.0 * math.pi * fund_a * t)
        v += 0.22 * math.sin(2.0 * math.pi * fund_b * t)
        # Slow load swell.
        v *= 1.0 + 0.18 * math.sin(2.0 * math.pi * lfo_freq * t)
        motor[i] = v

    warm = int(0.5 * sr)
    air_noise = generate_pink_noise(total_len, rng)
    air = filter_signal(air_noise, "bandpass", 900.0, q=0.6, sr=sr, warmup_samples=warm)
    air = filter_signal(air, "highpass", 250.0, q=0.707, sr=sr, warmup_samples=warm)
    air = filter_signal(air, "lowpass", 2800.0, q=0.707, sr=sr, warmup_samples=warm)

    metal_noise = generate_white_noise(total_len, rng)
    metal = [0.0] * total_len
    for band, q, amp in ((185.0, 8.0, 0.42), (430.0, 9.0, 0.30), (1160.0, 10.0, 0.18)):
        layer = filter_signal(metal_noise, "bandpass", band, q=q, sr=sr,
                              warmup_samples=warm)
        for i in range(total_len):
            metal[i] += amp * layer[i]

    mixed = [0.0] * total_len
    for i in range(total_len):
        mixed[i] = motor[i] + 0.35 * air[i] + 0.12 * metal[i]

    looped = make_seamless_loop(mixed, loop_len, xfade)
    return normalize_loop(looped, sr=sr)


def build_rumble_sub_pressure(rng):
    """Sub-bass pressure bed with no discernible pitch, 6.0s.

    Four mutually inharmonic low tones plus a slowly swept dark noise floor.
    The absence of a clear fundamental is what makes this read as dread rather
    than as a machine.
    """
    sr = SAMPLE_RATE
    loop_dur = 6.0
    loop_len = int(loop_dur * sr)
    xfade = int(0.6 * sr)
    total_len = loop_len + xfade
    warm = int(0.5 * sr)

    swells = [
        (30.0, 0.46), (30.1667, 0.22),   # close pair -> slow beating
        (38.0, 0.30), (45.0, 0.26),
        (62.0, 0.14),
    ]
    body = [0.0] * total_len
    inv_sr = 1.0 / float(sr)
    body_lfo = snap_frequency(1.0 / loop_dur, loop_dur)   # exactly 1 cycle per loop
    snapped = [(snap_frequency(f, loop_dur), a) for f, a in swells]
    for i in range(total_len):
        t = i * inv_sr
        v = 0.0
        for f, amp in snapped:
            v += amp * math.sin(2.0 * math.pi * f * t)
        v *= 1.0 + 0.15 * math.sin(2.0 * math.pi * body_lfo * t)
        body[i] = v

    # Dark noise floor with a slow filter sweep.  Coefficients are refreshed
    # every 128 samples (a ~344Hz control rate) which is far above what a
    # 0.17Hz sweep needs, and one whole sweep per loop keeps it periodic.
    noise = generate_pink_noise(total_len, rng)
    dark = [0.0] * total_len
    flt = BiquadFilter("lowpass", 120.0, 0.707, sr)
    sweep_rate = 1.0 / loop_dur
    control_interval = 128
    # Warm the recursive state at the sweep's midpoint so the head of the loop
    # does not carry a filter settling step into the splice.
    for i in range(max(0, total_len - warm), total_len):
        flt.set_params("lowpass", 260.0, 0.707)
        flt.process(noise[i])
    for i in range(total_len):
        if i % control_interval == 0:
            sweep = 0.5 * (1.0 + math.sin(2.0 * math.pi * sweep_rate * (i * inv_sr)))
            flt.set_params("lowpass", 120.0 + sweep * 280.0, 0.707)
        dark[i] = flt.process(noise[i])

    mixed = [0.0] * total_len
    for i in range(total_len):
        mixed[i] = body[i] + 0.25 * dark[i]

    looped = make_seamless_loop(mixed, loop_len, xfade)
    return normalize_loop(looped, sr=sr)


def build_rumble_cable_friction(rng):
    """Sheave/cable groan with periodic metal squeal, 5.0s.

    Six discrete friction events per loop (a whole number, so the rhythm does
    not stumble at the splice) over a low steel-cable vibration.
    """
    sr = SAMPLE_RATE
    loop_dur = 5.0
    loop_len = int(loop_dur * sr)
    # Deliberately short: the crossfade window must not overlap any friction
    # transient, otherwise the ring splice would eat the first squeal.
    xfade = int(0.15 * sr)
    total_len = loop_len + xfade

    warm = int(0.5 * sr)
    bed_noise = generate_pink_noise(total_len, rng)
    bed = filter_signal(bed_noise, "bandpass", 140.0, q=0.8, sr=sr, warmup_samples=warm)
    bed = filter_signal(bed, "lowpass", 220.0, q=0.707, sr=sr, warmup_samples=warm)

    # Steel cable vibration: modal, long decay, snapped to whole periods.
    cable = [0.0] * total_len
    for i in range(total_len):
        t = i / float(sr)
        v = 0.0
        for ratio, amp in ((1.0, 1.0), (2.4, 0.45), (4.7, 0.22)):
            f = snap_frequency(96.0 * ratio, loop_dur)
            v += amp * math.sin(2.0 * math.pi * f * t)
        cable[i] = v * 0.18

    # Periodic friction squeals.  Six per loop is a whole number, so the
    # rhythm never stumbles at the splice; the half-period phase offset keeps
    # every transient clear of the crossfade window.
    events = 6
    period = loop_dur / events
    phase = period * 0.5
    squeal = [0.0] * total_len
    for e in range(events):
        start = int((phase + e * period) * sr)
        dur = 0.22
        n = int(dur * sr)
        if start + n > total_len:
            n = total_len - start
        if n <= 0:
            continue
        amp = rng.uniform(0.25, 0.42)
        f0 = rng.uniform(1400.0, 1900.0)
        layer = generate_white_noise(n, rng)
        layer = filter_signal(layer, "bandpass", f0, q=2.6, sr=sr)
        layer = filter_signal(layer, "bandpass", f0 * 2.1, q=3.2, sr=sr)
        for i in range(n):
            t = i / float(sr)
            env = math.exp(-t / 0.055) * (1.0 - math.exp(-t / 0.0035))
            squeal[start + i] += amp * env * layer[i]

    mixed = [0.0] * total_len
    for i in range(total_len):
        mixed[i] = 0.30 * bed[i] + cable[i] + squeal[i]

    looped = make_seamless_loop(mixed, loop_len, xfade)
    return normalize_loop(looped, sr=sr)


def read_wav_mono(path, target_sr=SAMPLE_RATE):
    """Reads any PCM WAV, downmixes to mono and linearly resamples to target_sr."""
    with wave.open(str(path), "rb") as wf:
        nch = wf.getnchannels()
        sw = wf.getsampwidth()
        sr = wf.getframerate()
        nframes = wf.getnframes()
        raw = wf.readframes(nframes)

    if sw == 1:
        buf = array.array("B")
        buf.frombytes(raw)
        scale = 128.0
        vals = [(v - 128) / scale for v in buf]
    elif sw == 2:
        buf = array.array("h")
        buf.frombytes(raw)
        scale = 32768.0
        vals = [v / scale for v in buf]
    elif sw == 3:
        # 24-bit is not an array typecode, so sign-extend the three bytes by
        # hand.  The shipped power-station ambience is authored at 24-bit.
        count = len(raw) // 3
        vals = [0.0] * count
        inv = 1.0 / 8388608.0
        for i in range(count):
            o = i * 3
            v = raw[o] | (raw[o + 1] << 8) | (raw[o + 2] << 16)
            if v & 0x800000:
                v -= 0x1000000
            vals[i] = v * inv
    elif sw == 4:
        buf = array.array("i")
        buf.frombytes(raw)
        scale = 2147483648.0
        vals = [v / scale for v in buf]
    else:
        raise ValueError(f"Unsupported sample width: {sw * 8} bit")

    if nch == 1:
        mono = vals
    else:
        mono = [0.0] * nframes
        inv = 1.0 / nch
        for i in range(nframes):
            s = 0.0
            base = i * nch
            for c in range(nch):
                s += vals[base + c]
            mono[i] = s * inv

    if sr != target_sr:
        ratio = target_sr / float(sr)
        out_len = int(len(mono) * ratio)
        resampled = [0.0] * out_len
        last = len(mono) - 1
        for i in range(out_len):
            pos = i / ratio
            i0 = int(pos)
            if i0 >= last:
                resampled[i] = mono[last]
                continue
            frac = pos - i0
            resampled[i] = mono[i0] * (1.0 - frac) + mono[i0 + 1] * frac
        mono = resampled

    return mono


def build_rumble_power_station_reuse(rng):
    """Reuses the in-project underground power station ambience as a 4.0s loop."""
    sr = SAMPLE_RATE
    loop_dur = 4.0
    loop_len = int(loop_dur * sr)
    xfade = int(0.7 * sr)

    if not POWER_STATION_SOURCE.exists():
        raise FileNotFoundError(f"Missing source ambience: {POWER_STATION_SOURCE}")

    source = read_wav_mono(POWER_STATION_SOURCE, target_sr=sr)
    needed = loop_len + xfade
    if len(source) < needed:
        raise ValueError("Source ambience is shorter than one loop plus crossfade")

    # Start a third of the way in to skip any authored fade-in on the source.
    start = len(source) // 3
    if start + needed > len(source):
        start = len(source) - needed
    segment = source[start:start + needed]

    looped = make_seamless_loop(segment, loop_len, xfade)
    return normalize_loop(looped, sr=sr)


# ==============================================================================
# Output helpers
# ==============================================================================

def write_wav_file(filepath, samples, sr=SAMPLE_RATE):
    """Writes 16-bit mono PCM WAV file."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(str(filepath), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sr)
        packed = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            packed.extend(struct.pack("<h", int(round(clamped * 32767.0))))
        wf.writeframes(packed)


def compute_audio_stats(samples):
    """Computes peak dBFS and RMS dBFS."""
    if not samples:
        return -999.0, -999.0
    peak = max(abs(s) for s in samples)
    peak_db = 20.0 * math.log10(peak) if peak > 1e-9 else -120.0
    rms = math.sqrt(sum(s * s for s in samples) / len(samples))
    rms_db = 20.0 * math.log10(rms) if rms > 1e-9 else -120.0
    return peak_db, rms_db


def emit(filename, samples, is_loop, rng_label, meta):
    """Writes one candidate, prints its measured stats and verifies loop seams."""
    path = OUTPUT_DIR / filename
    write_wav_file(path, samples)
    peak_db, rms_db = compute_audio_stats(samples)
    duration = len(samples) / float(SAMPLE_RATE)
    kind = "LOOP" if is_loop else "ONE-SHOT"
    print(f"[{kind}] {filename}  {duration:.3f}s  peak={peak_db:+.2f}dBFS  "
          f"rms={rms_db:+.2f}dBFS")
    seam = None
    if is_loop:
        seam = verify_loop_seam(samples, rng_label)
    return {
        "file": filename,
        "group": meta["group"],
        "title": meta["title"],
        "kind": kind,
        "duration": round(duration, 3),
        "peak_db": round(peak_db, 2),
        "rms_db": round(rms_db, 2),
        "seam_ratio": round(seam["ratio"], 3) if seam else None,
        "rejected": bool(meta.get("rejected", False)),
        "selected": bool(meta.get("selected", False)),
        "role": meta.get("role", ""),
        "trigger": meta.get("trigger", ""),
        "notes": meta["notes"],
        "wave": downsample_wave(samples),
    }


def downsample_wave(samples, buckets=260):
    """Peak-envelope downsampling so the audition page can draw a waveform."""
    n = len(samples)
    if n == 0:
        return []
    step = max(1, n // buckets)
    out = []
    i = 0
    while i < n:
        end = min(n, i + step)
        peak = 0.0
        for j in range(i, end):
            a = abs(samples[j])
            if a > peak:
                peak = a
        out.append(round(peak, 5))
        i = end
    return out


AUDITION_TEMPLATE = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>电梯音效候选试听 · Elevator SFX Audition</title>
<style>
  :root {
    --ink: #1f2429;
    --ink-soft: #5b6672;
    --ink-faint: #8a949e;
    --header: #1a1d21;
    --header-ink: #e8ecef;
    --accent: #517b98;
    --accent-soft: #eaf1f6;
    --canvas: #ffffff;
    --grid: #eef1f4;
    --line: #dde3e9;
    --ok: #3f8f6a;
    --warn: #b8802f;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body {
    font-family: "Segoe UI", "Microsoft YaHei", system-ui, -apple-system, sans-serif;
    color: var(--ink);
    background-color: var(--canvas);
    background-image:
      linear-gradient(var(--grid) 1px, transparent 1px),
      linear-gradient(90deg, var(--grid) 1px, transparent 1px);
    background-size: 32px 32px;
    -webkit-font-smoothing: antialiased;
  }
  header {
    background: var(--header);
    color: var(--header-ink);
    padding: 20px 34px 22px;
    border-bottom: 3px solid var(--accent);
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 24px;
    flex-wrap: wrap;
  }
  header h1 { margin: 0; font-size: 21px; font-weight: 650; letter-spacing: .4px; }
  header .sub { margin: 6px 0 0; font-size: 12px; color: #9aa6b1; letter-spacing: .6px; }
  .switch {
    display: inline-flex; align-items: center; gap: 9px;
    font-size: 13px; color: #cfd8df; cursor: pointer; user-select: none;
    background: rgba(255,255,255,.06);
    border: 1px solid rgba(255,255,255,.14);
    padding: 8px 14px; border-radius: 6px;
  }
  .switch input { accent-color: var(--accent); width: 15px; height: 15px; cursor: pointer; }

  .intro {
    max-width: 1180px; margin: 26px auto 0; padding: 0 34px;
  }
  .intro-box {
    background: var(--canvas);
    border: 1px solid var(--line);
    border-left: 3px solid var(--accent);
    border-radius: 6px;
    padding: 16px 20px;
    font-size: 13px; line-height: 1.75; color: var(--ink-soft);
  }
  .intro-box strong { color: var(--ink); font-weight: 650; }
  .intro-box code {
    background: var(--accent-soft); color: #3d6078;
    padding: 1px 6px; border-radius: 3px; font-size: 12px;
  }

  main { max-width: 1180px; margin: 0 auto; padding: 8px 34px 40px; }

  section.group { margin-top: 34px; }
  section.group > h2 {
    font-size: 15px; font-weight: 650; margin: 0 0 4px;
    padding-bottom: 9px; border-bottom: 1px solid var(--line);
    letter-spacing: .3px;
  }
  section.group > p.gdesc {
    margin: 10px 0 18px; font-size: 12.5px; line-height: 1.7; color: var(--ink-soft);
    max-width: 900px;
  }

  .card {
    background: var(--canvas);
    border: 1px solid var(--line);
    border-radius: 7px;
    padding: 16px 18px 14px;
    margin-bottom: 14px;
    transition: border-color .15s, box-shadow .15s;
  }
  .card:hover { border-color: #c6d0d9; }
  .card.playing {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(81,123,152,.12);
  }
  .card-head {
    display: flex; align-items: flex-start; justify-content: space-between;
    gap: 18px; margin-bottom: 12px;
  }
  .title-wrap { min-width: 0; }
  .card h3 { margin: 0 0 5px; font-size: 14.5px; font-weight: 650; }
  .meta {
    margin: 0; font-size: 11.5px; color: var(--ink-faint);
    font-variant-numeric: tabular-nums; letter-spacing: .2px;
  }
  .badge {
    display: inline-block; margin-top: 7px;
    font-size: 11px; padding: 3px 9px; border-radius: 3px;
    font-variant-numeric: tabular-nums;
  }
  .badge.ok { background: #e8f4ee; color: var(--ok); border: 1px solid #c9e3d6; }
  .badge.warn { background: #fbf2e2; color: var(--warn); border: 1px solid #ecd9b6; }
  .badge.selected {
    background: var(--accent); color: #fff; border: 1px solid var(--accent);
    font-weight: 600;
  }
  .trigger {
    margin-top: 7px; font-size: 11.5px; line-height: 1.5;
    color: var(--ink-soft); border-left: 2px solid var(--accent);
    padding-left: 8px;
  }

  button.play {
    flex: 0 0 auto;
    display: inline-flex; align-items: center; gap: 7px;
    font: inherit; font-size: 12.5px; font-weight: 600;
    color: var(--accent); background: var(--accent-soft);
    border: 1px solid #cfe0ea; border-radius: 5px;
    padding: 9px 16px; cursor: pointer;
    transition: background .13s, color .13s, border-color .13s;
    white-space: nowrap;
  }
  button.play:hover { background: #dceaf3; border-color: #a9c6da; }
  .card.playing button.play { background: var(--accent); color: #fff; border-color: var(--accent); }

  canvas.wave {
    display: block; width: 100%; height: 66px;
    border: 1px solid var(--line); border-radius: 4px;
    background: #fbfcfd;
  }
  .notes {
    margin: 11px 0 0; font-size: 12.5px; line-height: 1.7; color: var(--ink-soft);
  }

  footer {
    max-width: 1180px; margin: 0 auto; padding: 0 34px 54px;
    font-size: 11.5px; color: var(--ink-faint); line-height: 1.8;
  }
  footer code {
    background: #f2f4f7; padding: 1px 6px; border-radius: 3px; font-size: 11px;
  }
  @media (max-width: 640px) {
    header, .intro, main, footer { padding-left: 18px; padding-right: 18px; }
  }
</style>
</head>
<body>

<header>
  <div>
    <h1>电梯音效候选试听</h1>
    <p class="sub">ELEVATOR SFX AUDITION · 5MINUTEMORE · CANDIDATES ONLY</p>
  </div>
  <label class="switch">
    <input type="checkbox" id="loopToggle" checked>
    循环播放（轰鸣类）
  </label>
</header>

<div class="intro">
  <div class="intro-box">
    <strong>第二批「叮」候选 —— 替换上一轮已否决的工业机械铃。</strong>
    上一轮是方波驱动 + 强非谐分音 + 锤击噪声，听感偏硬偏机械，那正是它像继电器而不像电梯的原因。
    这一批改为<strong>纯正弦驱动、接近谐波的乐音化分音、柔和起音、带金属厢体混响</strong>，
    四个方向覆盖从「最标准电梯」到「最空灵氛围」的光谱。<br><br>
    轰鸣方向已定：<code>rumble_power_station_reuse</code>（复用工程内地下电站环境音做环形无缝化），
    播放时机为「进轿厢 → 到达出轿厢」，带淡入淡出。
    轰鸣类全部为无缝循环，判定标准是<strong>环回跳变必须小于素材自身的内部运动</strong>（接缝比 &lt; 1）。<br><br>
    以上仍全部为候选，<strong>尚未接入游戏</strong>；首轮三个工业机械铃文件保留在目录中，但已从本页移出。
  </div>
</div>

<main id="app"></main>

<footer>
  波形为包络显示（每条按自身峰值归一化）。<br>
  生成脚本可从 <code>--seed</code> 完全复现；<code>--only ding</code> 可只重生成某一组。
</footer>

<script>
const DATA = __DATA__;

const GROUPS = [
  {
    id: "ding",
    title: "到达提示音 · ARRIVAL CHIME（第二批）",
    desc: "电梯抵达楼层时触发的一次性提示音，对应 _play_elevator_arrival_chime()。四个方向：经典下行双音 / 现代柔和大三度 / 明亮单声 / 空灵长尾。建议重点比较「辨识度」与「连续转场时会不会变烦」。"
  },
  {
    id: "rumble",
    title: "运行轰鸣 · RIDE RUMBLE（已选定）",
    desc: "轿厢运行期间持续循环播放的环境床声，对应转场中「进轿厢 → 到达出轿厢」这段时间窗。已选定 rumble_power_station_reuse，其余三个作为备份保留。"
  }
];

const PLAY_SVG = '<svg viewBox="0 0 16 16" width="13" height="13" aria-hidden="true"><path d="M4 2.5v11l9-5.5z" fill="currentColor"/></svg>';
const PAUSE_SVG = '<svg viewBox="0 0 16 16" width="13" height="13" aria-hidden="true"><rect x="4" y="3" width="2.7" height="10" fill="currentColor"/><rect x="9.3" y="3" width="2.7" height="10" fill="currentColor"/></svg>';

const app = document.getElementById("app");
const loopToggle = document.getElementById("loopToggle");
const audioCache = {};
const canvases = [];
let active = null;

function getAudio(file) {
  if (!audioCache[file]) {
    const a = new Audio("./" + file);
    a.preload = "auto";
    audioCache[file] = a;
  }
  return audioCache[file];
}

function stopActive() {
  if (!active) return;
  active.audio.pause();
  try { active.audio.currentTime = 0; } catch (e) {}
  active.card.classList.remove("playing");
  active.btn.innerHTML = PLAY_SVG;
  active = null;
}

function togglePlay(item, card, btn) {
  const audio = getAudio(item.file);
  if (active && active.audio === audio) { stopActive(); return; }
  stopActive();
  audio.loop = (item.kind === "LOOP") ? loopToggle.checked : false;
  try { audio.currentTime = 0; } catch (e) {}
  const p = audio.play();
  if (p && p.catch) { p.catch(function () {}); }
  card.classList.add("playing");
  btn.innerHTML = PAUSE_SVG;
  active = { audio: audio, card: card, btn: btn };
  audio.onended = function () { if (active && active.audio === audio) stopActive(); };
}

function drawWave(canvas, wave) {
  const dpr = window.devicePixelRatio || 1;
  const w = Math.max(1, canvas.clientWidth);
  const h = Math.max(1, canvas.clientHeight);
  canvas.width = Math.round(w * dpr);
  canvas.height = Math.round(h * dpr);
  const ctx = canvas.getContext("2d");
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);

  ctx.fillStyle = "#fbfcfd";
  ctx.fillRect(0, 0, w, h);

  ctx.strokeStyle = "#eef1f4";
  ctx.lineWidth = 1;
  for (let x = 32; x < w; x += 32) {
    ctx.beginPath(); ctx.moveTo(x + .5, 0); ctx.lineTo(x + .5, h); ctx.stroke();
  }
  ctx.strokeStyle = "#e2e7ec";
  ctx.beginPath(); ctx.moveTo(0, Math.round(h / 2) + .5); ctx.lineTo(w, Math.round(h / 2) + .5); ctx.stroke();

  if (!wave || !wave.length) return;
  const peak = Math.max.apply(null, wave) || 1;
  const mid = h / 2;
  const scale = (h * 0.44) / peak;
  const bw = w / wave.length;
  ctx.fillStyle = "#517b98";
  for (let i = 0; i < wave.length; i++) {
    const amp = Math.max(wave[i] * scale, 0.6);
    ctx.fillRect(i * bw, mid - amp, Math.max(bw, 0.9), amp * 2);
  }
}

function buildCard(item) {
  const card = document.createElement("article");
  card.className = "card";

  const head = document.createElement("div");
  head.className = "card-head";

  const wrap = document.createElement("div");
  wrap.className = "title-wrap";

  const h3 = document.createElement("h3");
  h3.textContent = item.title;
  wrap.appendChild(h3);

  const meta = document.createElement("p");
  meta.className = "meta";
  meta.textContent = [
    item.kind === "LOOP" ? "无缝循环" : "一次性",
    item.duration.toFixed(3) + "s",
    "峰值 " + item.peak_db.toFixed(2) + " dBFS",
    "RMS " + item.rms_db.toFixed(2) + " dBFS"
  ].join(" · ");
  wrap.appendChild(meta);

  if (item.selected) {
    const sel = document.createElement("span");
    sel.className = "badge selected";
    sel.textContent = item.role ? ("已选定 · " + item.role) : "已选定";
    wrap.appendChild(sel);
  }

  if (item.trigger) {
    const trig = document.createElement("div");
    trig.className = "trigger";
    trig.textContent = "触发时机：" + item.trigger;
    wrap.appendChild(trig);
  }

  if (item.kind === "LOOP" && item.seam_ratio !== null) {
    const badge = document.createElement("span");
    const ok = item.seam_ratio < 1;
    badge.className = "badge " + (ok ? "ok" : "warn");
    badge.textContent = "接缝比 " + item.seam_ratio.toFixed(3) + " · " + (ok ? "无缝" : "需检查");
    wrap.appendChild(badge);
  }

  const btn = document.createElement("button");
  btn.className = "play";
  btn.type = "button";
  btn.innerHTML = PLAY_SVG + "<span>播放</span>";

  head.appendChild(wrap);
  head.appendChild(btn);
  card.appendChild(head);

  const canvas = document.createElement("canvas");
  canvas.className = "wave";
  card.appendChild(canvas);

  const notes = document.createElement("p");
  notes.className = "notes";
  notes.textContent = item.notes;
  card.appendChild(notes);

  btn.addEventListener("click", function () { togglePlay(item, card, btn); });
  canvas.addEventListener("click", function () { togglePlay(item, card, btn); });

  canvases.push({ canvas: canvas, wave: item.wave });
  return card;
}

GROUPS.forEach(function (g) {
  const items = DATA.filter(function (d) { return d.group === g.id && !d.rejected; });
  if (!items.length) return;

  const section = document.createElement("section");
  section.className = "group";

  const h2 = document.createElement("h2");
  h2.textContent = g.title;
  section.appendChild(h2);

  const desc = document.createElement("p");
  desc.className = "gdesc";
  desc.textContent = g.desc;
  section.appendChild(desc);

  items.forEach(function (item) { section.appendChild(buildCard(item)); });
  app.appendChild(section);
});

function redrawAll() {
  canvases.forEach(function (c) { drawWave(c.canvas, c.wave); });
}
redrawAll();
window.addEventListener("resize", redrawAll);

loopToggle.addEventListener("change", function () {
  if (active) { active.audio.loop = loopToggle.checked; }
});
</script>
</body>
</html>
"""


def write_audition_page(entries):
    """
    Writes a self-contained audition page.

    Waveform envelopes are embedded as data instead of being decoded in the
    browser: a page opened straight off disk (file://) cannot fetch() the WAVs
    for Web Audio decoding, so canvas-ready envelopes keep it dependency-free
    and guaranteed to render.
    """
    payload = json.dumps(entries, ensure_ascii=False)
    html = AUDITION_TEMPLATE.replace("__DATA__", payload)
    path = OUTPUT_DIR / "audition.html"
    path.write_text(html, encoding="utf-8")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", default="", help="Generate only ids containing this substring")
    parser.add_argument("--seed", type=int, default=20260830, help="Deterministic RNG seed")
    args = parser.parse_args()

    only = args.only.lower()
    rng = random.Random(args.seed)

    jobs = [
        # Round 2 arrival chimes (current offer)
        ("ding_classic_dingdong", build_ding_classic_dingdong, False),
        ("ding_soft_modern", build_ding_soft_modern, False),
        ("ding_bright_single", build_ding_bright_single, False),
        ("ding_airy_gong", build_ding_airy_gong, False),
        # Ride rumble (selection already made, regenerated for completeness)
        ("rumble_power_station_reuse", build_rumble_power_station_reuse, True),
        ("rumble_motor_air", build_rumble_motor_air, True),
        ("rumble_sub_pressure", build_rumble_sub_pressure, True),
        ("rumble_cable_friction", build_rumble_cable_friction, True),
        # Round 1 arrival chimes -- rejected, kept so the script reproduces
        # everything that was ever delivered.
        ("ding_industrial_standard", build_ding_industrial_standard, False),
        ("ding_industrial_single", build_ding_industrial_single, False),
        ("ding_industrial_dry", build_ding_industrial_dry, False),
    ]

    print(f"Elevator audition pack -> {OUTPUT_DIR}")
    print(f"Spec: 16-bit PCM {SAMPLE_RATE}Hz mono | seed={args.seed}")
    print("-" * 74)

    written = []
    for name, builder, is_loop in jobs:
        if only and only not in name.lower():
            continue
        samples = builder(rng)
        written.append(emit(f"{name}.wav", samples, is_loop, name, CANDIDATE_META[name]))

    print("-" * 74)
    if written:
        page = write_audition_page(written)
        print(f"Audition page -> {page}")
    print(f"Done. {len(written)} candidate(s) written to {OUTPUT_DIR}")
    print("Selection status: the three `selected` entries above are wired into "
          "gameplay -- ding_classic_dingdong and ding_airy_gong via the "
          "elevator_ding / elevator_badge events in scripts/audio/sfx_manager.gd, "
          "and rumble_power_station_reuse via ELEVATOR_RUMBLE_STREAM.  The "
          "remaining files are audition-only; regenerating this pack reproduces "
          "every wav byte-for-byte, so it never disturbs what is already shipped.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
