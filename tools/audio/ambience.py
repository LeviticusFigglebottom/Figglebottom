#!/usr/bin/env python3
"""Rimeholt ambience beds, synthesized. Each is a seamless whole-file loop:
continuous layers (wind, sea) ride exactly periodic modulators and are
crossfade-looped; event layers (gulls, surf breaks, voices, ice) are
folded so whatever rings past the loop point lands on its head.

    python3 tools/audio/ambience.py [thaw rime]

Writes assets/audio/ambience/*.ogg.
"""
import os
import sys

import numpy as np

import dsp
from dsp import SR, Mix, samples

OUT = os.path.join(dsp.AUDIO, "ambience")
L = 64.0


def xfade_loop(x, L_s, X):
    out = x[:L_s].copy()
    c = np.sin(np.linspace(0, np.pi / 2, X)) ** 2
    if out.ndim == 2:
        c = c[:, None]
    out[:X] = out[:X] * c + x[L_s:L_s + X] * (1 - c)
    return out


def continuous(fn, rng, X=4.0):
    """Render a continuous layer for L + X and crossfade-loop it to L."""
    x = fn(L + X)
    return xfade_loop(x, samples(L), samples(X))


# ------------------------------------------------------------------ sea

def wave_on_shingle(rng, dur=7.0, size=1.0):
    """One wave on a shingle strand: the swell coming in, the break, the
    wash running up, and the long rattling drag of stones going back."""
    n = samples(dur)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    # approach + break
    t_b = 1.6 * size
    rise = np.clip(t / t_b, 0, 1) ** 2.5
    after = np.exp(-np.maximum(t - t_b, 0) / 0.9)
    body = dsp.lp(dsp.pink(n, rng), 900) * rise * after
    crash = dsp.lp(dsp.hp(dsp.pink(n, rng), 300), 4500) * np.exp(-np.maximum(t - t_b, 0) / 0.45) * (t > t_b - 0.05)
    wash = dsp.bp(dsp.pink(n, rng), 2500, 0.8) * np.clip((t - t_b) / 0.4, 0, 1) * np.exp(-np.maximum(t - t_b - 0.4, 0) / 1.0)
    # the drag: stones pulled back down the beach, dense then thinning
    t_d = t_b + 1.2
    drag_env = np.clip((t - t_d) / 0.5, 0, 1) * np.exp(-np.maximum(t - t_d, 0) / 1.3)
    clicks = np.zeros(n)
    k = int(2600 * size)
    pos = rng.uniform(t_d, min(t_d + 3.8, dur - 0.05), k)
    pos.sort()
    keep = rng.random(k) < np.exp(-(pos - t_d) / 1.6)
    for p in pos[keep]:
        clicks[samples(p)] += rng.uniform(-1, 1)
    rattle = np.zeros(n)
    for f in (1900, 2900, 4100, 5600):
        rattle += dsp.reson(clicks, f * rng.uniform(0.92, 1.08), 9)
    rattle = rattle * drag_env + dsp.hp(rng.normal(0, 1, n), 3000) * drag_env * 0.02
    for ch, pp in enumerate((-0.15, 0.15)):
        g = 1.0 + 0.15 * (ch - 0.5) * rng.uniform(-1, 1)
        out[:, ch] = (body * 0.9 + crash * 0.55 + wash * 0.35) * g + rattle * (0.32 if ch == 0 else 0.26)
    return out


def surf(rng, muffled=False):
    """Eight waves to the loop, never quite evenly spaced."""
    buf = np.zeros((samples(L + 10), 2))
    at = 0.4
    for i in range(8):
        size = rng.uniform(0.8, 1.15)
        w = wave_on_shingle(rng, 8.0, size)
        if muffled:
            w = dsp.lp(w, 260, 2)
        dsp.mix_into(buf, w, at, size)
        at += L / 8 + rng.uniform(-0.6, 0.6) if i < 7 else 0
    # the sea's constant roar beneath the waves
    roar = continuous(lambda d: dsp.lp(dsp.pink(samples(d), rng), 220 if muffled else 450), rng)
    bed = dsp.fold_loop(buf, samples(L))
    return bed, roar


# ----------------------------------------------------------------- wind

def wind_grass(rng):
    """A warm evening breeze moving through long grass: soft, high hiss
    whose loudness follows slow gusts."""
    def mk(d):
        n = samples(d)
        gust = dsp.periodic_curve(n, rng, cycles=5 * d / L, lo=0.25, hi=1.0)
        hiss = dsp.hp(dsp.lp(dsp.pink(n, rng), 6500), 1400) * gust
        low = dsp.lp(dsp.brown(n, rng), 180) * (0.4 + 0.6 * gust) * 0.5
        return np.stack([hiss + low, np.roll(hiss, 9000) + low], axis=1)
    return continuous(mk, rng)


def wind_cold(rng):
    """The RIME wind: lower, longer gusts, and the whistle of air finding
    a gap in a frozen net or a door that will not shut."""
    def mk(d):
        n = samples(d)
        gust = dsp.periodic_curve(n, rng, cycles=3 * d / L, lo=0.15, hi=1.0, harmonics=5)
        body = dsp.lp(dsp.brown(n, rng), 260) * (0.3 + 0.7 * gust) * 0.7
        hiss = dsp.hp(dsp.lp(dsp.pink(n, rng), 5000), 900) * gust ** 1.6 * 0.4
        # a whistle whose pitch follows the gust (the gap sings louder and higher)
        whistle = np.zeros(n)
        src = dsp.pink(n, rng)
        blk = 2048
        for i in range(0, n, blk):
            g = gust[i:i + blk].mean()
            whistle[i:i + blk] = dsp.reson(src[max(i - blk, 0):i + blk], 420 + 380 * g, 40)[-len(src[i:i + blk]):]
        whistle = whistle * gust ** 4 * 0.3
        l = body + hiss + whistle
        r = np.roll(body, 4000) + np.roll(hiss, 11000) + whistle * 0.7
        return np.stack([l, r], axis=1)
    return continuous(mk, rng)


# ---------------------------------------------------------------- gulls

def gull_note(rng, f0, dur, laugh=False):
    """One herring-gull 'kyow': a squealing harmonic note that lifts and
    falls, nasal, with a raspy edge."""
    n = samples(dur)
    t = np.arange(n) / n
    contour = (1 + 0.28 * np.sin(np.pi * t ** 0.7)) if not laugh else (1.12 - 0.2 * t)
    f = f0 * contour * (1 + 0.01 * rng.normal(0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.zeros(n)
    for h, a in [(1, 0.7), (2, 1.0), (3, 0.65), (4, 0.4), (5, 0.2), (6, 0.12)]:
        x += a * np.sin(h * ph)
    x *= 1 + 0.35 * np.sin(2 * np.pi * 70 * t * dur)        # rasp
    x = dsp.reson(x, 2600, 3) + x * 0.3
    env = np.sin(np.pi * np.clip(t / 0.15, 0, 1) / 2) * np.clip((1 - t) / 0.35, 0, 1)
    return x * env


def gull_call(rng):
    """A long call: a couple of drawn-out mews, then the 'laughing' run."""
    parts = []
    f0 = rng.uniform(700, 900)
    for _ in range(rng.integers(1, 3)):
        parts.append((gull_note(rng, f0 * rng.uniform(0.97, 1.03), rng.uniform(0.45, 0.65)), 0.12))
    k = rng.integers(3, 8)
    for i in range(k):
        parts.append((gull_note(rng, f0 * (1.05 - 0.04 * i), rng.uniform(0.16, 0.22), laugh=True),
                      0.05 + 0.01 * i))
    total = sum(len(p) / SR + g for p, g in parts)
    out = np.zeros(samples(total + 0.2))
    at = 0.0
    for p, g in parts:
        s = samples(at)
        out[s:s + len(p)] += p[:len(out) - s]
        at += len(p) / SR + g
    return out


# --------------------------------------------------------------- voices

VOWELS = [(800, 1200, 2500), (500, 1800, 2500), (320, 2200, 2950), (500, 900, 2400), (360, 820, 2300),
          (650, 1100, 2450)]


def murmur(rng, dur, f0, words_s=4.2):
    """A voice talking, too far off to make out: glottal pulses through
    moving formants, syllabic rhythm, falling phrase pitch, pauses. It is
    texture, never language."""
    n = samples(dur)
    f0c = np.zeros(n)
    amp = np.zeros(n)
    F = np.zeros((n, 3))
    t = 0.2
    while t < dur - 1.0:
        ulen = rng.uniform(1.2, 3.6)
        end = min(t + ulen, dur - 0.3)
        p0 = f0 * rng.uniform(1.05, 1.25)
        p1 = f0 * rng.uniform(0.8, 0.95)
        s = t
        while s < end:
            syl = rng.uniform(0.11, 0.26)
            a, b = samples(s), samples(min(s + syl, end))
            if b <= a:
                break
            u = np.linspace(0, 1, b - a)
            prog = (s - t) / ulen
            accent = 1.0 + (0.12 if rng.random() < 0.25 else 0.0)
            f0c[a:b] = (p0 + (p1 - p0) * prog) * accent * (1 + 0.03 * np.sin(np.pi * u))
            amp[a:b] = np.sin(np.pi * u) ** 0.6 * rng.uniform(0.6, 1.0)
            v = VOWELS[rng.integers(len(VOWELS))]
            F[a:b] = v
            s += syl + (rng.uniform(0.02, 0.07) if rng.random() < 0.4 else 0.0)
        # someone laughs, now and then
        if rng.random() < 0.18:
            for k in range(rng.integers(3, 6)):
                a = samples(end + 0.05 + k * 0.17)
                b = min(a + samples(0.11), n)
                if b <= a:
                    break
                u = np.linspace(0, 1, b - a)
                f0c[a:b] = f0 * 1.4 * (1 - 0.05 * k)
                amp[a:b] = np.sin(np.pi * u) * 0.8
                F[a:b] = VOWELS[0]
            end += 1.0
        t = end + rng.uniform(0.6, 2.8)
    f0c[f0c == 0] = f0
    F[F[:, 0] == 0] = VOWELS[0]
    amp = dsp.lp(amp, 30, 1)
    # source: glottal pulses (a shaped saw) with breath
    ph = np.cumsum(f0c) / SR
    src = (2 * (ph % 1.0) - 1)
    src = dsp.lp(src, 3500, 1) + rng.normal(0, 1, n) * 0.08
    src *= np.clip(amp, 0, 1)
    out = np.zeros(n)
    blk = 256
    from scipy import signal as sg
    zis = [np.zeros(2) for _ in range(3)]
    for i in range(0, n, blk):
        seg = src[i:i + blk]
        fv = F[min(i + blk // 2, n - 1)]
        acc = np.zeros(len(seg))
        for k, (fq, g, q) in enumerate(zip(fv, (1.0, 0.55, 0.22), (7, 10, 12))):
            w = 2 * np.pi * fq / SR
            r = np.exp(-np.pi * fq / (q * SR))
            y, zis[k] = sg.lfilter([1 - r], [1, -2 * r * np.cos(w), r * r], seg, zi=zis[k])
            acc += y * g
        out[i:i + blk] = acc
    return out


def voices(rng):
    """The steading at evening, heard from the yard: a few people talking
    by the boats, a child, someone laughing. Far enough to be no words."""
    buf = np.zeros((samples(L + 4), 2))
    for f0, p, g in [(108, -0.6, 1.0), (196, -0.45, 0.9), (124, 0.5, 0.8), (215, 0.35, 0.75), (290, 0.1, 0.4)]:
        v = murmur(rng, L + 2, f0)
        dsp.mix_into(buf, dsp.pan(v, p), 0, g / (np.std(v) + 1e-9))
    # distance: the air takes the consonants first
    buf = dsp.lp(dsp.hp(buf, 140), 1300, 3)
    return dsp.fold_loop(buf, samples(L))


# ------------------------------------------------------------------ ice

def ice_creak(rng, dur):
    """Ice under strain: stick-slip pulses whose rate swells and slows,
    through the low modes of a frozen sheet."""
    n = samples(dur)
    t = np.arange(n) / n
    rate = 18 + 60 * np.sin(np.pi * t) ** 1.5 * rng.uniform(0.6, 1.2)
    ph = np.cumsum(rate) / SR
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float) * rng.uniform(0.5, 1.0, n)
    y = np.zeros(n)
    for f, q, a in [(180, 12, 1.0), (310, 14, 0.7), (520, 16, 0.5), (900, 18, 0.25)]:
        y += dsp.reson(pulses, f * rng.uniform(0.85, 1.15), q) * a
    return y * np.sin(np.pi * t) ** 0.5


def ice_layer(rng):
    buf = np.zeros((samples(L + 6), 2))
    for at in sorted(rng.uniform(0.5, L - 1, 9)):
        c = ice_creak(rng, rng.uniform(0.8, 2.2))
        dsp.mix_into(buf, dsp.pan(c, rng.uniform(-0.7, 0.7)), at, rng.uniform(0.5, 1.0))
    # the frozen strand 'singing': long dispersive pew-ows, far off
    for at in sorted(rng.uniform(0.5, L - 3, 6)):
        p = dsp.ice_ping(rng.uniform(2500, 4500), rng.uniform(180, 420), rng.uniform(1.2, 2.4), rng)
        dsp.mix_into(buf, dsp.pan(dsp.lp(p, 3500), rng.uniform(-0.9, 0.9)), at, rng.uniform(0.25, 0.5))
    # fine crackle of rime growing on things
    for at in sorted(rng.uniform(0, L - 1, 14)):
        c = dsp.crackle(0.6, rng, rate=40, f_lo=2500, f_hi=8000, decay=np.exp(-dsp.t_axis(0.6) / 0.2))
        dsp.mix_into(buf, dsp.pan(c, rng.uniform(-0.8, 0.8)), at, 0.06)
    return dsp.fold_loop(buf, samples(L))


# --------------------------------------------------------------- scenes

def amb_thaw():
    rng = np.random.default_rng(611)
    m = Mix(L)
    bed, roar = surf(rng)
    m.add(bed, -4)
    m.add(roar, -16)
    m.add(wind_grass(rng), -11)
    m.add(voices(rng), -15)
    g = np.zeros((samples(L + 4), 2))
    for at in [3.0, 11.5, 19.0, 24.5, 35.0, 41.0, 52.5, 58.0]:
        c = gull_call(rng)
        dist = rng.uniform(0.3, 1.0)
        c = dsp.lp(c, 2500 + 3500 * dist)
        dsp.mix_into(g, dsp.pan(c, rng.uniform(-0.9, 0.9)), at + rng.uniform(-0.6, 0.6), dist)
    ir = dsp.make_ir(rt60=1.1, pre=0.03, damp_hz=5000, width=1.0, seed=21, early=4)
    g = dsp.fold_loop(dsp.reverb(g, ir, wet=0.35), samples(L))
    m.add(g, -12)
    return m.buf


def amb_rime():
    rng = np.random.default_rng(622)
    m = Mix(L)
    m.add(wind_cold(rng), -2)
    bed, roar = surf(rng, muffled=True)
    m.add(bed, -12)
    m.add(roar, -18)
    ir = dsp.make_ir(rt60=3.0, pre=0.04, damp_hz=4000, width=1.0, seed=22)
    ice = dsp.fold_loop(dsp.reverb(ice_layer(rng), ir, wet=0.45), samples(L))
    m.add(ice, -4)
    return m.buf


def finish(x, rms_db):
    pre = samples(3.0)
    y = np.concatenate([x[-pre:], x])
    y = dsp.hp(y, 30)[pre:]
    y = y * (10 ** (rms_db / 20) / (np.sqrt(np.mean(y ** 2)) + 1e-12))
    pk = np.max(np.abs(y))
    if pk > 0.95:
        y = np.tanh(y / pk * 1.5) / np.tanh(1.5) * 0.95
    return y


SCENES = {"thaw": ("amb_thaw", amb_thaw, -24.0), "rime": ("amb_rime", amb_rime, -25.0)}

if __name__ == "__main__":
    want = set(sys.argv[1:])
    for k, (name, fn, lvl) in SCENES.items():
        if want and k not in want:
            continue
        x = finish(fn(), lvl)
        print(f"[ambience] {name}: seam ratio {dsp.seam_report(x):.2f}")
        dsp.write_ogg(os.path.join(OUT, name + ".ogg"), x, quality=3)
