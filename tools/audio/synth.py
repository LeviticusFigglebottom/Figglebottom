#!/usr/bin/env python3
"""Rimeholt audio pack synthesizer. Everything the game plays is generated
here — highland folk colour (lyre, horn, drone fiddle). Deterministic.

Usage: python3 tools/audio/synth.py [name ...]
Writes assets/audio/*.wav (44.1 kHz mono 16-bit).
"""
import os
import sys
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "audio")
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_ad(n, attack, decay_tau, sr=SR):
    """Attack (linear) + exponential decay envelope of length n samples."""
    e = np.ones(n)
    a = max(int(attack * sr), 1)
    e[:a] = np.linspace(0, 1, a)
    d = np.arange(n - a) / sr
    e[a:] = np.exp(-d / decay_tau)
    return e


def lowpass(x, cutoff):
    """One-pole lowpass."""
    dt = 1.0 / SR
    rc = 1.0 / (2 * np.pi * cutoff)
    alpha = dt / (rc + dt)
    y = np.empty_like(x)
    acc = 0.0
    # vectorized one-pole via lfilter-style recursion
    b = alpha
    a = 1 - alpha
    y[0] = b * x[0]
    for i in range(1, len(x)):   # fallback loop only for short buffers
        y[i] = b * x[i] + a * y[i - 1]
    return y


def lowpass_fft(x, cutoff, order=2.0):
    """FFT brick-ish lowpass with soft knee (fast for long buffers)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = 1.0 / (1.0 + (f / max(cutoff, 1.0)) ** (2 * order))
    return np.fft.irfft(X * H, len(x))


def highpass_fft(x, cutoff, order=2.0):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    H = 1.0 - 1.0 / (1.0 + (f / max(cutoff, 1.0)) ** (2 * order))
    return np.fft.irfft(X * H, len(x))


def bandpass_sweep(noise, f0, f1, bw=0.5):
    """Cheap bandpass whose center sweeps f0->f1 over the buffer (chunked)."""
    n = len(noise)
    out = np.zeros(n)
    chunks = 24
    cs = n // chunks
    for i in range(chunks):
        seg = noise[i * cs:(i + 1) * cs if i < chunks - 1 else n]
        fc = f0 * (f1 / f0) ** (i / (chunks - 1))
        lo = lowpass_fft(seg, fc * (1 + bw))
        out[i * cs:i * cs + len(seg)] = lo - lowpass_fft(seg, fc * (1 - bw * 0.7))
    return out


BELL_PARTIALS = [(0.56, 1.0), (0.92, 0.72), (1.19, 0.5), (1.71, 0.42),
                 (2.00, 0.36), (2.74, 0.22), (3.00, 0.18), (3.76, 0.12), (4.07, 0.08)]


def bell(f0, dur, strike=1.0, dark=0.0):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for i, (ratio, amp) in enumerate(BELL_PARTIALS):
        f = f0 * ratio * (1 + rng.normal(0, 0.0012))
        decay = dur * (0.5 / (0.6 + ratio)) * (1.6 - 0.5 * dark)
        x += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / max(decay, 0.05))
    # hum reinforcement + strike noise
    x += 0.5 * np.sin(2 * np.pi * f0 * 0.5 * t) * np.exp(-t / (dur * 0.8))
    ns = rng.normal(0, 1, len(t)) * np.exp(-t / 0.02) * 0.6 * strike
    x += lowpass_fft(ns, 3000)
    return x


def choir_note(f0, dur, vib=4.6, breath=0.25):
    """Vowel-ish sustained tone: few harmonics + formant noise + vibrato."""
    t = t_axis(dur)
    vibr = 1 + 0.006 * np.sin(2 * np.pi * vib * t + rng.uniform(0, 6)) * np.minimum(t / 1.2, 1)
    x = np.zeros_like(t)
    for h, a in [(1, 1.0), (2, 0.42), (3, 0.30), (4, 0.14), (5, 0.07)]:
        x += a * np.sin(2 * np.pi * f0 * h * np.cumsum(vibr) / SR + rng.uniform(0, 6))
    br = lowpass_fft(rng.normal(0, 1, len(t)), f0 * 4) * breath
    x = x + br
    a = min(dur * 0.35, 1.6)
    e = np.minimum(t / a, 1) * np.minimum((dur - t) / a, 1) ** 1.2
    return x * np.clip(e, 0, 1)


def organ_note(f0, dur, gain=1.0):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for h, a in [(1, 1.0), (2, 0.5), (3, 0.33), (4, 0.2), (6, 0.1), (8, 0.05)]:
        x += a * np.sin(2 * np.pi * f0 * h * t + 0.1 * h)
    e = np.minimum(t / 0.4, 1) * np.minimum((dur - t) / 0.8, 1)
    return x * np.clip(e, 0, 1) * gain


def wind(dur, base_cut=400, gust=0.35, seed=3):
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    x = r.normal(0, 1, n)
    x = lowpass_fft(x, base_cut)
    # slow gust envelope
    gn = r.normal(0, 1, 200)
    ge = np.interp(np.linspace(0, 199, n), np.arange(200), gn)
    ge = lowpass_fft(ge, 2.0 / dur * 4) if False else ge
    ge = (ge - ge.min()) / (np.ptp(ge) + 1e-9)
	# smooth
    k = int(SR * 0.8)
    ge = np.convolve(ge, np.ones(k) / k, mode="same")
    return x * (0.35 + gust * ge)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def place(buf, x, at, gain=1.0):
    """Mix x into buf starting at `at` seconds (clipped to buf)."""
    s = int(at * SR)
    if s >= len(buf) or s < 0:
        return
    seg = x[:len(buf) - s]
    buf[s:s + len(seg)] += seg * gain


def loopify(x, tail=6.0):
    """Bake a seamless whole-track loop: the last `tail` seconds are folded
    into the head with an equal-power crossfade and cut off, so the final
    sample runs straight on into the first when the stream loops."""
    n_t = int(tail * SR)
    body = x[:-n_t].copy()
    tl = x[-n_t:]
    t = np.linspace(0, 1, n_t)
    body[:n_t] = body[:n_t] * np.sqrt(t) + tl * np.sqrt(1 - t)
    return body


def fade_ends(x, head=4.5, tail=8.0, hold=1.2):
    """A piece that ENDS and BEGINS: fade in from silence over `head`, fade
    out to true silence over `tail` with a `hold` of near-silence at the very
    end. Looping such a track reads as the music finishing and, after a
    breath, starting again — no vamp seam to notice."""
    y = x.copy()
    n_h = int(head * SR)
    y[:n_h] *= np.sqrt(np.linspace(0, 1, n_h))
    n_t = int(tail * SR)
    n_hold = int(hold * SR)
    y[-(n_t + n_hold):-n_hold] *= np.sqrt(np.linspace(1, 0, n_t))
    y[-n_hold:] = 0.0
    return y


def write(name, x, peak=0.9):
    os.makedirs(OUT, exist_ok=True)
    data = (norm(x, peak) * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"[audio] {name}.wav  {len(x)/SR:.1f}s")


# ------------------------------------------------------------------ pieces

def pluck(f0, dur, bright=0.5):
    """Karplus-Strong-ish plucked string (lyre/kantele colour)."""
    n = int(dur * SR)
    period = max(int(SR / f0), 2)
    buf = rng.uniform(-1, 1, period) * (0.6 + 0.4 * bright)
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % period]
        out[i] = v
        buf[i % period] = 0.5 * (v + buf[(i + 1) % period]) * 0.996
    return out * env_ad(n, 0.002, dur * 0.45)


def horn(f0, dur, gain=1.0):
    """A cow-horn / lur call: buzzy odd harmonics, slow swell, soft fall."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for k, a in [(1, 1.0), (2, 0.35), (3, 0.5), (5, 0.18)]:
        x += a * np.sin(2 * np.pi * f0 * k * t * (1 + 0.002 * np.sin(2 * np.pi * 4.2 * t)))
    env = np.minimum(t / 0.35, 1.0) * np.exp(-np.maximum(t - dur * 0.6, 0) / (dur * 0.2))
    return lowpass_fft(x, 2400) * env * gain


def gen_horn_low():
    x = np.zeros(int(3.4 * SR))
    place(x, horn(98.0, 3.2), 0.0)
    place(x, horn(147.0, 3.0), 0.1, 0.5)
    write("horn_low", x, 0.8)

def gen_rest_chime():
    x = np.zeros(int(3.0 * SR))
    for f, at in [(220.0, 0.0), (329.6, 0.28), (440.0, 0.56), (392.0, 0.9)]:
        place(x, pluck(f, 2.0), at, 0.7)
    write("rest_chime", x, 0.6)

def gen_warmth_pickup():
    t = t_axis(0.5)
    x = np.zeros_like(t)
    for f, d in [(1318, 0.0), (1760, 0.06), (1975, 0.12)]:
        i = int(d * SR)
        seg = np.sin(2 * np.pi * f * t[:len(t) - i]) * env_ad(len(t) - i, 0.004, 0.09)
        x[i:] += seg * 0.5
    write("warmth", x, 0.5)

def gen_levelup():
    x = np.zeros(int(2.4 * SR))
    for f, at in [(220.0, 0.0), (277.2, 0.18), (329.6, 0.36), (440.0, 0.6)]:
        place(x, pluck(f, 1.7, 0.8), at, 0.8)
    write("levelup", x, 0.62)

def _swoosh(dur, f_hi, f_lo, body_cut, peak_at=0.45, edge=0.6):
    """A blade cutting air: a bright edge band sweeping down through a broad
    low body, with an S-curve build-peak-release so it reads as a SWING, not
    a burst. Light saturation rounds it."""
    n = int(dur * SR)
    t = np.arange(n) / n
    arc = np.clip(np.sin(np.pi * np.clip((t / peak_at) * 0.5, 0, 0.5)) * (t < peak_at)
                  + np.cos(np.pi * 0.5 * np.clip((t - peak_at) / (1 - peak_at), 0, 1)) * (t >= peak_at), 0, 1) ** 1.3
    hi = bandpass_sweep(rng.normal(0, 1, n), f_hi, f_lo, 0.55) * edge
    lo = lowpass_fft(rng.normal(0, 1, n), body_cut)
    x = (hi + lo * 0.8) * arc
    return np.tanh(x * 2.2)


def gen_whooshes():
    # the raise/draw of a light and a heavy arm
    write("whoosh_l", _swoosh(0.30, 3400, 900, 1100, 0.42, 0.75), 0.55)
    write("whoosh_h", _swoosh(0.48, 2300, 380, 700, 0.5, 0.6), 0.65)
    # the CUT itself, played as the hitbox opens — short, keen, airy
    write("swing", _swoosh(0.26, 4200, 1300, 1500, 0.38, 0.9), 0.6)
    n = int(0.3 * SR)
    x = lowpass_fft(rng.normal(0, 1, n), 900) * env_ad(n, 0.03, 0.09)
    write("roll", x, 0.4)

def gen_impacts():
    t = t_axis(0.3)
    f = 130 * np.exp(-t * 9)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.002, 0.07)
    crack = lowpass_fft(rng.normal(0, 1, len(t)), 2400) * env_ad(len(t), 0.001, 0.025) * 0.8
    write("impact_flesh", thud * 1.2 + crack, 0.8)

    # the SLASH: a landed CLEAVE — a long bright steel shear with a quick
    # metallic sing and only a whisper of wet underneath. No punch.
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    shear = bandpass_sweep(rng.normal(0, 1, n), 6800, 1900, 0.62) * env_ad(n, 0.001, 0.10)
    sing = np.zeros(n)
    for f0, a in [(2350, 1.0), (3620, 0.55), (5240, 0.34)]:
        sing += a * np.sin(2 * np.pi * f0 * t * (1.0 + 0.012 * t)) * np.exp(-t / 0.05)
    wet = lowpass_fft(rng.normal(0, 1, n), 540) * env_ad(n, 0.002, 0.04) * 0.45
    write("slash", np.tanh((shear * 1.5 + sing * 0.5 + wet) * 1.9), 0.76)

    t = t_axis(0.42)
    x = np.zeros_like(t)
    for f0, a in [(760, 1.0), (1290, 0.6), (2140, 0.42), (3200, 0.2)]:
        x += a * np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.07)
    thud2 = np.sin(2 * np.pi * 90 * t) * env_ad(len(t), 0.001, 0.05)
    write("impact_blocked", x + thud2, 0.7)

    # shield ding: a strike click into an inharmonic steel ring — bright,
    # quick, unmistakably metal-on-metal
    t = t_axis(0.5)
    x = np.zeros_like(t)
    for ratio, a, tau in [(1.0, 1.0, 0.16), (2.32, 0.62, 0.11), (3.01, 0.45, 0.085),
                          (4.27, 0.3, 0.06), (6.13, 0.18, 0.045)]:
        f = 1480.0 * ratio
        x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    click = highpass_fft(rng.normal(0, 1, len(t)), 2400) * env_ad(len(t), 0.001, 0.012) * 1.2
    write("shield_ding", x + click, 0.66)

    # parry: a hard crack, then a rising shimmer that hangs — the reward note
    t = t_axis(1.1)
    x = np.zeros_like(t)
    for f0, a, tau in [(1180, 1.0, 0.22), (1770, 0.72, 0.2), (2650, 0.55, 0.17),
                       (3980, 0.36, 0.14), (5340, 0.2, 0.11)]:
        f = f0 * (1.0 + 0.02 * np.minimum(t / 0.25, 1.0))    # partials lift a hair
        x += a * np.sin(2 * np.pi * np.cumsum(f) / SR + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    crack = highpass_fft(rng.normal(0, 1, len(t)), 1800) * env_ad(len(t), 0.001, 0.02) * 1.6
    sparkle = bandpass_sweep(rng.normal(0, 1, len(t)), 5200, 8200, 0.5) * np.exp(-t / 0.28) * 0.3
    write("parry", x + crack + sparkle, 0.74)

def gen_gourd():
    t = t_axis(1.2)
    x = np.zeros_like(t)
    for i in range(3):
        s = int((0.15 + i * 0.22) * SR)
        f = 300 - i * 40
        seg_t = t_axis(0.12)
        blip = np.sin(2 * np.pi * (f - 60 * seg_t / 0.12) * seg_t) * env_ad(len(seg_t), 0.01, 0.05)
        x[s:s + len(blip)] += blip * 0.7
    place(x, pluck(330.0, 0.45, 0.5) * 0.3, 0.75)
    write("gourd", x, 0.55)

def gen_death():
    t = t_axis(3.4)
    f = np.linspace(110, 82, len(t))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR)
    x += 0.5 * np.sin(2 * np.pi * np.cumsum(f * 1.06) / SR)
    x *= np.exp(-t / 1.4)
    air = lowpass_fft(rng.normal(0, 1, len(t)), 500) * np.exp(-t / 2.0) * 0.4
    write("death", x + air, 0.75)

def gen_swells():
    # warm: rising shimmer into warm bloom
    dur = 6.5
    t = t_axis(dur)
    n = len(t)
    sw = bandpass_sweep(rng.normal(0, 1, n), 300, 4200, 0.7) * (t / dur) ** 1.6
    bloom = np.zeros(n)
    for f, at in [(294, 3.4), (370, 3.9), (440, 4.3), (587, 4.7)]:
        b = choir_note(f, 2.4) * 0.5
        s = int(at * SR)
        bloom[s:min(s + len(b), n)] += b[:max(n - s, 0)]
    place(bloom, pluck(440.0, 2.0, 0.7) * 0.6, 4.6)
    write("swell_warm", sw * 0.7 + bloom, 0.8)

    # still: breath sucked out of the world, down into a low horn
    t = t_axis(6.5)
    n = len(t)
    rev = bandpass_sweep(rng.normal(0, 1, n), 3800, 240, 0.8) * (t / 6.5) ** 1.3
    f = np.linspace(180, 55, n)
    moan = np.sin(2 * np.pi * np.cumsum(f) / SR) * (t / 6.5) ** 2 * 0.8
    moan += np.sin(2 * np.pi * np.cumsum(f * 1.032) / SR) * (t / 6.5) ** 2 * 0.5
    out = rev * 0.75 + moan
    place(out, horn(73.4, 2.0) * 0.9, 4.4)
    write("swell_still", out, 0.82)

## ------------------------------------------------------------------ themes
## Rimeholt's underscores: highland folk colour — drone fiddle, plucked
## lyre, cow-horn, frame drum — in A aeolian/dorian. Each piece is through-
## composed and loops whole via loopify()/fade_ends().

def fiddle(f0, dur, gain=1.0, vib=5.0):
    """Bowed drone string: lowpassed saw with slow vibrato and bow swell."""
    t = t_axis(dur)
    f = f0 * (1 + 0.004 * np.sin(2 * np.pi * vib * t))
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1.0) - 1
    env = np.minimum(t / 0.6, 1.0) * np.minimum((dur - t) / 0.8, 1.0)
    return lowpass_fft(saw, 1600) * np.clip(env, 0, 1) * gain


def frame_drum(gain=1.0):
    t = t_axis(0.6)
    f = 82 * np.exp(-t * 7)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.002, 0.22)
    x += lowpass_fft(rng.normal(0, 1, len(t)), 700) * env_ad(len(t), 0.001, 0.04) * 0.4
    return x * gain


# A aeolian scale degrees (A3 = 220)
_A = {"A2": 110.0, "E3": 164.8, "G3": 196.0, "A3": 220.0, "B3": 246.9, "C4": 261.6,
      "D4": 293.7, "E4": 329.6, "F4": 349.2, "G4": 392.0, "A4": 440.0, "C5": 523.3}


def _tune(x, at, notes, step, inst="pluck", gain=0.4):
    for k, nm in enumerate(notes):
        if nm == "-":
            continue
        f = _A[nm]
        seg = pluck(f, step * 2.2, 0.6) if inst == "pluck" else fiddle(f, step * 1.1, 0.5)
        place(x, seg * gain, at + k * step)


def gen_theme_thaw():
    """Midsummer Evening — drone fiddle on A/E, a lilting lyre tune in 6/8,
    the frame drum keeping a slow dance; ~64 s, loops whole."""
    dur, tail = 64.0, 4.0
    n = int((dur + tail) * SR)
    x = np.zeros(n)
    x += fiddle(110.0, dur + tail, 0.22) + fiddle(164.8, dur + tail, 0.12)
    x += wind(dur + tail, 900, 0.2, seed=71) * 0.06
    tune_a = ["A3", "C4", "E4", "D4", "C4", "B3", "A3", "-", "E4", "G4", "A4", "G4", "E4", "D4", "E4", "-"]
    tune_b = ["C4", "D4", "E4", "G4", "E4", "D4", "C4", "B3", "A3", "B3", "C4", "E4", "D4", "B3", "A3", "-"]
    step = 0.5
    for rep, tune in enumerate([tune_a, tune_a, tune_b, tune_a, tune_b, tune_b, tune_a, tune_b]):
        _tune(x, 2.0 + rep * 8.0, tune, step, "pluck", 0.36)
    for b in range(int(dur / 1.5)):
        place(x, frame_drum(0.35 if b % 2 == 0 else 0.18), b * 1.5)
    place(x, horn(220.0, 4.0) * 0.12, 33.0)
    write("theme_thaw", loopify(lowpass_fft(x, 5000), tail), 0.6)


def gen_theme_rime():
    """The Long Winter — a frozen drone, a lone fiddle bowing the same falling
    figure, wind, ice ticks; ~64 s, loops whole."""
    dur, tail = 64.0, 6.0
    n = int((dur + tail) * SR)
    t = t_axis(dur + tail)
    x = np.zeros(n)
    x += (np.sin(2 * np.pi * 55.0 * t) * 0.35 + np.sin(2 * np.pi * 55.4 * t) * 0.3) \
        * (0.6 + 0.4 * np.sin(2 * np.pi * t / 23.0))
    x += wind(dur + tail, 300, 0.6, seed=72) * 0.32
    fig = [("E4", 0.0), ("D4", 2.5), ("C4", 5.0), ("B3", 7.5), ("A3", 10.0)]
    for at in (6.0, 26.0, 46.0):
        for nm, off in fig:
            place(x, fiddle(_A[nm], 2.8, 0.18, vib=3.0), at + off)
    r = np.random.default_rng(73)
    for at in r.uniform(0, dur, 18):
        t3 = t_axis(0.06)
        place(x, np.sin(2 * np.pi * r.uniform(2400, 3600) * t3) * env_ad(len(t3), 0.001, 0.015) * 0.08, at)
    place(x, horn(55.0, 5.0) * 0.18, 40.0)
    write("theme_rime", fade_ends(lowpass_fft(x, 3200), 5.0, 8.0), 0.6)


def gen_theme_boss():
    """The Holdfast — frame drums in a driving 7/8, horn calls, a sawing
    fiddle ostinato on A-C-B-E; ~55 s, loops whole."""
    beat = 0.22
    bar = beat * 7
    bars = 36
    dur, tail = bar * bars, bar * 2
    n = int((dur + tail) * SR)
    t = t_axis(dur + tail)
    x = np.zeros(n)
    for b in range(bars + 1):
        s0 = b * bar
        for k, g in [(0, 1.0), (2, 0.55), (4, 0.8), (5, 0.4)]:
            place(x, frame_drum(g), s0 + k * beat)
    x += np.sin(2 * np.pi * 55.0 * t) * 0.18
    ost = ["A3", "C4", "B3", "E3"]
    for b in range(8, bars - 2):
        for k, nm in enumerate(ost):
            place(x, fiddle(_A[nm], beat * 1.7, 0.2, vib=6.0), b * bar + k * beat * 1.75)
    for at in (0.5, bar * 12, bar * 24):
        place(x, horn(110.0, 3.0) * 0.32, at)
        place(x, horn(164.8, 3.0) * 0.16, at)
    write("theme_boss", loopify(lowpass_fft(x, 4400), tail), 0.7)


def gen_theme_title():
    """Title — horn over a low drone, then the lyre recalls the summer tune
    once, slowly; ~40 s."""
    dur, tail = 40.0, 4.0
    n = int((dur + tail) * SR)
    x = np.zeros(n)
    x += fiddle(110.0, dur + tail, 0.18)
    x += wind(dur + tail, 400, 0.4, seed=74) * 0.18
    place(x, horn(110.0, 5.0) * 0.3, 1.0)
    place(x, horn(164.8, 4.0) * 0.22, 7.0)
    _tune(x, 14.0, ["A3", "C4", "E4", "D4", "C4", "B3", "A3", "-"], 1.0, "pluck", 0.4)
    _tune(x, 24.0, ["E4", "G4", "A4", "G4", "E4", "D4", "E4"], 1.1, "pluck", 0.32)
    write("theme_title", fade_ends(lowpass_fft(x, 4200), 3.0, 6.0), 0.62)

def birdsong(f0, dur=0.5, warble=28.0):
    """Tiny birdsong motif: chirp with pitch warble and quick decay."""
    t = t_axis(dur)
    f = f0 * (1 + 0.09 * np.sin(2 * np.pi * warble * t)) * (1 + 0.25 * np.exp(-t * 9))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR)
    return x * env_ad(len(t), 0.02, dur * 0.3)


def crow_caw(dur=0.42):
    """Harsh descending croak: AM noise over a falling saw."""
    t = t_axis(dur)
    f = np.linspace(620, 380, len(t))
    saw = 2 * ((np.cumsum(f) / SR) % 1.0) - 1
    am = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 42 * t))
    x = saw * am + lowpass_fft(rng.normal(0, 1, len(t)), 1800) * 0.5
    return lowpass_fft(x, 1500) * env_ad(len(t), 0.03, 0.16)


def gen_ambiences():
    """Long ambience beds (~42 s heard length), looped whole like the themes
    so their event patterns don't telegraph a short cycle."""
    dur, tail = 42.0, 4.0
    # thaw: soft warm air, birds about the yard
    g = wind(dur + tail, 600, 0.25, seed=21) * 0.5

    r2 = np.random.default_rng(33)
    for at in (2.2, 7.6, 12.4, 18.0, 22.8, 28.3, 34.0, 38.6):
        for k in range(r2.integers(2, 4)):
            place(g, birdsong(r2.uniform(1900, 3200), r2.uniform(0.22, 0.5)) * 0.055,
                  at + k * 0.35 + r2.uniform(0, 0.1))
    write("amb_thaw", loopify(g, tail), 0.4)
    # rime: hollow wind, timber groans, drips, carrion birds
    r = wind(dur + tail, 260, 0.6, seed=22) * 0.8
    for at in (6.0, 17.5, 29.0, 38.5):
        t2 = t_axis(1.2)
        creak_f = np.linspace(90, 60, len(t2))
        place(r, np.sin(2 * np.pi * np.cumsum(creak_f) / SR) * env_ad(len(t2), 0.3, 0.3) * 0.16, at)
    for at in (3.2, 9.7, 15.1, 21.4, 27.8, 33.2, 40.1):
        t3 = t_axis(0.09)
        place(r, np.sin(2 * np.pi * 2900 * t3) * env_ad(len(t3), 0.002, 0.02) * 0.12, at)
    r4 = np.random.default_rng(44)
    for at in (5.4, 13.8, 25.6, 35.2):
        for k in range(r4.integers(1, 3)):
            place(r, crow_caw(r4.uniform(0.3, 0.5)) * 0.11, at + k * 0.5)
    write("amb_rime", loopify(r, tail), 0.45)

def gen_creature():
    # rimewalker moan: wobbling formant
    t = t_axis(1.8)
    f = 120 + 22 * np.sin(2 * np.pi * 1.4 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR)
    x += 0.5 * np.sin(2 * np.pi * np.cumsum(f * 2.02) / SR)
    x = lowpass_fft(x, 800) + lowpass_fft(rng.normal(0, 1, len(t)), 400) * 0.3
    write("rimewalker_moan", x * env_ad(len(t), 0.4, 0.5), 0.5)
    # holdfast roar: a deep bellow bent down + growl
    t = t_axis(2.6)
    f = 95 * np.exp(-t * 0.25)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
    growl = lowpass_fft(rng.normal(0, 1, len(t)) * np.sin(2 * np.pi * 30 * t), 500)
    write("holdfast_roar", (lowpass_fft(x, 900) * 0.7 + growl * 0.6) * env_ad(len(t), 0.06, 1.0), 0.8)

def gen_misc():
    # frost veil pass: muffled whoomp + hush
    t = t_axis(1.4)
    f = 220 * np.exp(-t * 6)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.01, 0.3)
    x += lowpass_fft(rng.normal(0, 1, len(t)), 300) * np.exp(-t / 0.8) * 0.5
    write("veil_enter", x, 0.6)
    # footsteps
    for i, name in enumerate(["step1", "step2"]):
        t = t_axis(0.16)
        f = (95 if i == 0 else 82) * np.exp(-t * 26)
        x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_ad(len(t), 0.001, 0.03)
        x += lowpass_fft(np.random.default_rng(30 + i).normal(0, 1, len(t)), 1400) * env_ad(len(t), 0.001, 0.015) * 0.5
        write(name, x, 0.35)
    # ui tick
    t = t_axis(0.07)
    x = np.sin(2 * np.pi * 1100 * t) * env_ad(len(t), 0.001, 0.015)
    write("ui_tick", x, 0.3)
    # breathmark recover: warm minor->major shimmer
    t = t_axis(1.6)
    x = np.zeros_like(t)
    for f, a in [(392, 0.8), (494, 0.55), (587, 0.6)]:
        x += a * np.sin(2 * np.pi * f * t) * np.exp(-t / 0.7)
    write("breathmark", x, 0.55)
    # guard break
    t = t_axis(0.6)
    x = np.zeros_like(t)
    for f0, a in [(320, 1.0), (475, 0.5), (710, 0.4)]:
        x += a * np.sin(2 * np.pi * f0 * t) * np.exp(-t / 0.1)
    x += lowpass_fft(rng.normal(0, 1, len(t)), 900) * env_ad(len(t), 0.002, 0.08)
    write("guard_break", x, 0.7)




ALL = {
    "horn_low": gen_horn_low, "rest_chime": gen_rest_chime, "warmth": gen_warmth_pickup,
    "levelup": gen_levelup, "whooshes": gen_whooshes, "impacts": gen_impacts,
    "gourd": gen_gourd, "death": gen_death, "swells": gen_swells,
    "theme_thaw": gen_theme_thaw, "theme_rime": gen_theme_rime, "theme_boss": gen_theme_boss,
    "theme_title": gen_theme_title, "ambiences": gen_ambiences, "creature": gen_creature, "misc": gen_misc,
}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    for name, fn in ALL.items():
        if only and name not in only:
            continue
        fn()
    print("[audio] done")
