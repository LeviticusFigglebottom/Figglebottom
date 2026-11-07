#!/usr/bin/env python3
"""Rimeholt foley and SFX, synthesized. Deterministic.

The engine's generic set (swings, impacts, UI) keeps its names and its
job, retuned for this world: iron and wool and ice, not polished steel.
The world-specific foley (footsteps per surface, frost-taken hits, the
parry ring, the coal catching, the last breath, the frost/melt wave) is
built from the physical models in dsp.py.

Music and ambience live in music.py and ambience.py.

Usage: python3 tools/audio/synth.py [name ...]
Writes assets/audio/*.wav, assets/audio/foley/*.wav (44.1 kHz 16-bit) and
the two long transition breaths as .ogg.
"""
import os
import sys

import numpy as np

import dsp
from dsp import SR, samples, t_axis

OUT = dsp.AUDIO
FOLEY = os.path.join(OUT, "foley")
rng = np.random.default_rng(7)


def write(name, x, peak=0.9, folder=OUT):
    x = dsp.normalize(np.asarray(x, dtype=float), peak)
    path = os.path.join(folder, name + ".wav")
    dsp.write_wav(path, x)
    print(f"[sfx] {os.path.relpath(path, dsp.ROOT)}  {len(x)/SR:.2f}s")


def env_ad(n, attack, tau):
    e = np.ones(n)
    a = max(samples(attack), 1)
    e[:a] = np.linspace(0, 1, a)
    e[a:] = np.exp(-np.arange(n - a) / SR / tau)
    return e


def noise(n, r=None):
    return (r or rng).normal(0, 1, n)


def place(buf, x, at, gain=1.0):
    s = samples(at)
    if s >= len(buf):
        return
    seg = x[:len(buf) - s]
    buf[s:s + len(seg)] += seg * gain


def pluck(f0, dur, bright=0.4):
    return dsp.lp(dsp.ks_pluck(f0, dur, rng, bright=bright, decay=0.997), 3500, 2)


# ------------------------------------------------------------ footsteps

def step_turf(r):
    """Boot on turf: a soft, damp thud and the grass brushed aside."""
    n = samples(0.32)
    t = np.arange(n) / SR
    thud = dsp.lp(noise(n, r), 220, 2) * env_ad(n, 0.004, 0.035) * 1.4
    thud += np.sin(2 * np.pi * np.cumsum(70 * np.exp(-t * 18) + 45) / SR) * env_ad(n, 0.002, 0.03) * 0.5
    swish = dsp.bp(noise(n, r), r.uniform(2800, 4200), 1.5) * env_ad(n, 0.015, 0.045) * 0.15
    return thud + swish


def step_shingle(r):
    """Boot into shingle: the heel's crunch then the stones settling, a
    shower of small hard clicks ringing in pebble-sized resonances."""
    n = samples(0.42)
    clicks = np.zeros(n)
    k = r.integers(70, 110)
    pos = np.abs(r.exponential(0.06, k)) + r.uniform(0, 0.02, k)
    for p in pos[pos < 0.38]:
        clicks[samples(p)] += r.uniform(-1, 1)
    y = np.zeros(n)
    for f in (1800, 2700, 3900, 5400):
        y += dsp.reson(clicks, f * r.uniform(0.9, 1.1), 10)
    thud = dsp.lp(noise(n, r), 260, 2) * env_ad(n, 0.003, 0.03)
    return y * 0.9 + thud * 0.7


def step_plank(r):
    """Boot on an adzed plank floor: a hollow wooden knock (board modes)
    with the faint tick of the heel and sometimes a short creak."""
    f0 = r.uniform(115, 150)
    x = dsp.modal([f0, f0 * 2.6, f0 * 4.1, f0 * 6.3], [1.0, 0.55, 0.3, 0.12],
                  [0.07, 0.04, 0.025, 0.015], 0.4, r)
    tick = dsp.hp(noise(len(x), r), 1800) * env_ad(len(x), 0.0005, 0.006) * 0.35
    out = x + tick
    if r.random() < 0.4:
        cr = np.zeros(len(x))
        ph = np.cumsum(np.full(len(x), r.uniform(35, 60))) / SR
        cr[np.diff(np.floor(ph), prepend=0) > 0] = 1.0
        cr = dsp.reson(cr, r.uniform(500, 800), 12) * np.sin(np.pi * np.clip((t_axis(0.4) - 0.08) / 0.25, 0, 1))
        out += cr * 0.15
    return out


def step_snow(r):
    """Boot into crusted snow: the crust breaking, then the dry squeak of
    packed crystals (dense granular noise, bandpassed, no ring)."""
    n = samples(0.38)
    t = np.arange(n) / SR
    g = np.zeros(n)
    k = r.integers(350, 520)
    pos = r.exponential(0.07, k) + r.uniform(0, 0.015, k)
    for p in pos[pos < 0.34]:
        g[samples(p)] += r.uniform(-1, 1)
    crunch = dsp.bp(g, r.uniform(1100, 1600), 0.7) * 1.2 + dsp.hp(g, 4000) * 0.3
    crunch *= np.clip(t / 0.01, 0, 1) * np.exp(-t / 0.12)
    crust = dsp.hp(noise(n, r), 2500) * env_ad(n, 0.0005, 0.008) * 0.4
    body = dsp.lp(noise(n, r), 300, 2) * env_ad(n, 0.004, 0.04) * 0.5
    return crunch + crust + body


SURFACES = (("turf", step_turf, 11), ("shingle", step_shingle, 23), ("plank", step_plank, 37),
            ("snow", step_snow, 53))


def gen_footsteps():
    for surf, fn, seed in SURFACES:
        for i in range(4):
            write(f"step_{surf}_{i + 1}", fn(np.random.default_rng(1000 + seed * 10 + i)), 0.5, FOLEY)
    # the generic pair (enemies and NPCs, who carry no surface probe)
    write("step1", step_turf(np.random.default_rng(31)), 0.35)
    write("step2", step_turf(np.random.default_rng(32)), 0.35)


# ------------------------------------------------------- frost-taken hits

def gen_frost_hits():
    """A blade into the frost-taken: rime shattering off frozen wool, the
    dull thump of cloth gone stiff, and a few ice chips skittering."""
    for i in range(3):
        r = np.random.default_rng(2000 + i)
        n = samples(0.6)
        t = np.arange(n) / SR
        shatter = dsp.crackle(0.6, r, rate=260, f_lo=2200, f_hi=9000, decay=np.exp(-t / 0.05)) * 0.5
        snap = dsp.hp(noise(n, r), 3000) * env_ad(n, 0.0003, 0.012) * 1.2
        cloth = dsp.lp(noise(n, r), 650, 2) * env_ad(n, 0.002, 0.05) * 1.3
        cloth += np.sin(2 * np.pi * np.cumsum(110 * np.exp(-t * 12) + 60) / SR) * env_ad(n, 0.002, 0.05) * 0.6
        chips = np.zeros(n)
        for _ in range(r.integers(3, 6)):     # chips: tiny dry ticks, not tones
            p = dsp.crackle(0.05, r, rate=60, f_lo=3000, f_hi=8000, decay=np.exp(-t_axis(0.05) / 0.008))
            place(chips, p, r.uniform(0.07, 0.35), r.uniform(0.1, 0.25))
        write(f"hit_frost_{i + 1}", snap + shatter + cloth + chips, 0.8, FOLEY)
    # a frost-taken falling: the whole crust giving way, then stillness
    r = np.random.default_rng(2100)
    n = samples(1.6)
    t = np.arange(n) / SR
    crust = dsp.crackle(1.6, r, rate=400, f_lo=1500, f_hi=8000, decay=np.exp(-t / 0.35))
    slump = dsp.lp(noise(n, r), 400, 2) * np.clip((t - 0.1) / 0.1, 0, 1) * np.exp(-np.maximum(t - 0.1, 0) / 0.25)
    sigh = dsp.bp(noise(n, r), 900, 1.2) * np.sin(np.pi * np.clip(t / 1.4, 0, 1)) ** 2 * 0.15
    write("frost_fall", crust * 0.6 + slump + sigh, 0.75, FOLEY)


# ---------------------------------------------------------------- parry

def gen_parry():
    """The parry: iron struck on iron, rung out over ice. A bog-iron bar's
    free-free modes (inharmonic, darker than steel), a crack of ice, and a
    cold shimmer of ice pings hanging after."""
    r = np.random.default_rng(3000)
    f0 = 520.0
    modes = [f0 * k for k in (1.0, 2.756, 5.404, 8.933, 13.34)]
    iron = dsp.modal(modes, [1.0, 0.7, 0.42, 0.22, 0.1], [0.5, 0.32, 0.2, 0.12, 0.07], 1.6, r, 0.0004)
    n = len(iron)
    t = np.arange(n) / SR
    crack = dsp.hp(noise(n, r), 2200) * env_ad(n, 0.0003, 0.015) * 1.4
    crack += dsp.crackle(1.6, r, rate=120, f_lo=3000, f_hi=9000, decay=np.exp(-t / 0.06)) * 0.4
    shimmer = np.zeros(n)
    for k in range(6):
        p = dsp.ice_ping(r.uniform(5000, 8000), r.uniform(1800, 3000), 0.5, r)
        place(shimmer, p, 0.05 + k * r.uniform(0.04, 0.09), 0.12)
    write("parry", iron + crack + shimmer, 0.78)


# ------------------------------------------------------------- hearth

def gen_coal_catch():
    """The coal set in a cold hearthstone: a breath drawn in across it,
    the soft 'whump' of the kindling catching, and a crackle as it takes."""
    r = np.random.default_rng(4000)
    dur = 2.6
    n = samples(dur)
    t = np.arange(n) / SR
    draw = dsp.pink(n, r)
    fc = 300 + 2200 * np.clip(t / 0.9, 0, 1) ** 2
    gate = np.clip(t / 0.9, 0, 1) ** 2 * np.clip((1.0 - t) / 0.08, 0, 1)
    draw = (dsp.tv_lowpass(draw, fc) - dsp.tv_lowpass(draw, fc * 0.3)) * gate
    t_c = 0.95
    after = np.maximum(t - t_c, 0)
    whump = dsp.lp(noise(n, r), 180, 2) * np.clip((t - t_c) / 0.03, 0, 1) * np.exp(-after / 0.22) * 2.0
    whump += np.sin(2 * np.pi * np.cumsum(90 * np.exp(-after * 8) + 45) / SR) * (t > t_c) * np.exp(-after / 0.18) * 0.8
    roar = dsp.bp(dsp.pink(n, r), 700, 0.6) * np.clip((t - t_c) / 0.08, 0, 1) * np.exp(-after / 0.6) * 0.6
    crack = dsp.crackle(dur, r, rate=30, f_lo=1200, f_hi=6000) * (t > t_c + 0.1) * np.exp(-after / 0.9) * 0.6
    write("coal_catch", draw * 0.5 + whump + roar + crack, 0.8, FOLEY)


# --------------------------------------------------------------- death

def gen_death():
    """STILLED: the Bearer's last breath going out into the cold, long and
    unforced, and a faint tick of frost forming where it went."""
    r = np.random.default_rng(5000)
    dur = 3.6
    n = samples(dur)
    t = np.arange(n) / SR
    x = dsp.pink(n, r)
    shape = np.clip(t / 0.25, 0, 1) * np.exp(-t / 1.2)
    fc = 1500 - 900 * np.clip(t / 2.5, 0, 1)
    br = dsp.tv_lowpass(x, fc * 1.6) - dsp.tv_lowpass(x, fc * 0.3)
    br += dsp.reson(x, 950, 5) * 0.2
    br = dsp.hp(dsp.lp(br, 2400, 4), 180) * shape
    voice = np.sin(2 * np.pi * np.cumsum(np.linspace(118, 96, n)) / SR) * shape * 0.06 * np.exp(-t / 0.6)
    frost = dsp.crackle(dur, r, rate=14, f_lo=3500, f_hi=9000) * np.clip((t - 1.8) / 0.5, 0, 1) * 0.15
    write("death", br + voice + frost, 0.75)


# -------------------------------------------------------- the wavefront

def _breath_long(r, dur, inhale):
    n = samples(dur)
    t = np.arange(n) / n
    x = dsp.pink(n, r)
    if inhale:
        env = np.clip(t / 0.75, 0, 1) ** 1.6 * np.clip((1 - t) / 0.05, 0, 1)    # drawn in, then held
        fc = 500 + 1800 * t
    else:
        env = np.clip(t / 0.08, 0, 1) * (1 - t) ** 1.3
        fc = 1700 - 1100 * t
    y = dsp.tv_lowpass(x, fc * 1.7) - dsp.tv_lowpass(x, fc * 0.3)
    y += dsp.reson(x, 1300 if inhale else 900, 4) * 0.25
    return dsp.hp(dsp.lp(y, 3000, 4), 160) * env


def gen_wave():
    """The state wave. To RIME the world draws one long breath in and holds
    it, and ice cracks race out as the frost line passes. To THAW it lets
    the breath go, and the ice gives: softer cracks, drips, a warm swell."""
    dur = 6.8
    n = samples(dur)
    t = np.arange(n) / SR
    # ---- to RIME
    r = np.random.default_rng(6000)
    br = _breath_long(r, dur, True)
    growl = dsp.lp(dsp.brown(n, r), 120) * np.clip(t / dur, 0, 1) ** 2 * 0.5   # the sheet tightening
    frost = dsp.crackle(dur, r, rate=90, f_lo=3000, f_hi=9500) * np.clip(t / dur, 0, 1) * 0.25
    rime = dsp.pan(br * 1.2 + growl, 0) + dsp.to_stereo(frost)
    for ch in (0, 1):            # cracks racing outward: more, sharper, further apart in the field
        cc = np.zeros(n)
        for k in range(12):
            c = dsp.ice_ping(r.uniform(3000, 6500), r.uniform(300, 900), r.uniform(0.3, 0.8), r)
            c += dsp.hp(noise(len(c), r), 2500) * env_ad(len(c), 0.0003, 0.01) * 0.6
            place(cc, c, 0.4 + k * 0.45 + r.uniform(-0.12, 0.12), 0.25 + 0.05 * k)
        rime[:, ch] += cc
    held = np.exp(-np.maximum(t - dur * 0.92, 0) / 0.08)
    rime *= held[:, None]
    dsp.write_ogg(os.path.join(OUT, "wave_to_rime.ogg"), dsp.normalize(rime, 0.8), 5)
    # ---- to THAW
    r = np.random.default_rng(6100)
    br = _breath_long(r, dur, False)
    give = np.zeros(n)
    for k in range(10):          # ice giving: duller, lower cracks
        c = dsp.ice_ping(r.uniform(1800, 3000), r.uniform(200, 500), r.uniform(0.4, 0.9), r)
        place(give, dsp.lp(c, 2500), 0.2 + k * 0.5 + r.uniform(-0.1, 0.1), 0.4 * (1 - k / 14))
    drips = np.zeros(n)
    for _ in range(26):
        f = r.uniform(900, 1700)
        d = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.6 * np.exp(-t_axis(0.12) / 0.02))) / SR) \
            * env_ad(samples(0.12), 0.001, 0.025)
        place(drips, d, r.uniform(1.0, dur - 0.3), r.uniform(0.05, 0.14))
    warm = dsp.lp(dsp.pink(n, r), 400) * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 2 * 0.3
    thaw = dsp.pan(br * 1.2 + warm, 0)
    thaw[:, 0] += give + drips
    thaw[:, 1] += np.roll(give, 900) + np.roll(drips, 3000)
    dsp.write_ogg(os.path.join(OUT, "wave_to_thaw.ogg"), dsp.normalize(dsp.fade(thaw, 0, 1.2), 0.8), 5)


# --------------------------------------------- the engine set, retuned

def gen_horn_low():
    """A cow-horn call, for the slam: buzzy odd harmonics, slow swell."""
    def horn(f0, dur):
        t = t_axis(dur)
        x = np.zeros_like(t)
        for k, a in [(1, 1.0), (2, 0.35), (3, 0.5), (5, 0.18)]:
            x += a * np.sin(2 * np.pi * f0 * k * t * (1 + 0.002 * np.sin(2 * np.pi * 4.2 * t)))
        env = np.minimum(t / 0.35, 1.0) * np.exp(-np.maximum(t - dur * 0.6, 0) / (dur * 0.2))
        return dsp.lp(x, 2400) * env
    x = np.zeros(samples(3.4))
    place(x, horn(98.0, 3.2), 0.0)
    place(x, horn(147.0, 3.0), 0.1, 0.5)
    write("horn_low", x, 0.8)


def gen_rest_chime():
    """Resting at a hearth: the kantele's open strings, D-A-D-F."""
    x = np.zeros(samples(3.0))
    for f, at in [(146.8, 0.0), (220.0, 0.22), (293.7, 0.44), (349.2, 0.7)]:
        place(x, pluck(f, 2.2), at, 0.7)
    write("rest_chime", x, 0.6)


def gen_warmth_pickup():
    """Warmth gathered: an ember's tick and a soft high pluck."""
    x = np.zeros(samples(0.7))
    place(x, dsp.crackle(0.3, rng, rate=30, f_lo=1500, f_hi=5000, decay=np.exp(-t_axis(0.3) / 0.06)), 0.0, 0.5)
    place(x, pluck(587.3, 0.6, 0.5), 0.03, 0.8)
    place(x, pluck(880.0, 0.5, 0.5), 0.09, 0.5)
    write("warmth", x, 0.5)


def gen_levelup():
    x = np.zeros(samples(2.4))
    for f, at in [(220.0, 0.0), (293.7, 0.18), (349.2, 0.36), (440.0, 0.6), (587.3, 0.82)]:
        place(x, pluck(f, 1.7, 0.6), at, 0.8)
    write("levelup", x, 0.62)


def _swoosh(dur, f_hi, f_lo, body_cut, peak_at=0.45, edge=0.6):
    """An iron blade (or a heavy wool sleeve) through cold air."""
    n = samples(dur)
    tt = np.arange(n) / n
    arc = np.where(tt < peak_at, np.sin(np.pi / 2 * tt / peak_at),
                   np.cos(np.pi / 2 * np.clip((tt - peak_at) / (1 - peak_at), 0, 1))) ** 1.3
    fc = f_hi * (f_lo / f_hi) ** tt
    nz = noise(n)
    hi = (dsp.tv_lowpass(nz, fc * 1.4) - dsp.tv_lowpass(nz, fc * 0.6)) * edge
    lo = dsp.lp(noise(n), body_cut) * 0.8
    cloth = dsp.bp(noise(n), 500, 0.8) * 0.3
    return np.tanh((hi + lo + cloth) * arc * 2.0)


def gen_whooshes():
    write("whoosh_l", _swoosh(0.30, 2800, 800, 900, 0.42, 0.75), 0.55)
    write("whoosh_h", _swoosh(0.48, 1900, 350, 600, 0.5, 0.6), 0.65)
    write("swing", _swoosh(0.26, 3400, 1100, 1200, 0.38, 0.9), 0.6)
    n = samples(0.34)
    x = dsp.lp(noise(n), 800) * env_ad(n, 0.03, 0.09) + dsp.bp(noise(n), 3000, 1) * env_ad(n, 0.02, 0.05) * 0.2
    write("roll", x, 0.4)


def gen_impacts():
    t = t_axis(0.3)
    n = len(t)
    thud = np.sin(2 * np.pi * np.cumsum(130 * np.exp(-t * 9)) / SR) * env_ad(n, 0.002, 0.07)
    wool = dsp.lp(noise(n), 1200) * env_ad(n, 0.001, 0.03) * 0.8
    write("impact_flesh", thud * 1.2 + wool, 0.8)
    # the cut landing: bog-iron edge through wool, darker than a steel shear
    n = samples(0.32)
    tt = np.arange(n) / SR
    nz = noise(n)
    fc = 4200 * (1300 / 4200) ** (tt / 0.32)
    shear = (dsp.tv_lowpass(nz, fc * 1.3) - dsp.tv_lowpass(nz, fc * 0.6)) * env_ad(n, 0.001, 0.09)
    ring = dsp.modal([1450, 3990, 7830], [1.0, 0.45, 0.2], [0.04, 0.025, 0.012], 0.32, rng)
    body = dsp.lp(noise(n), 500) * env_ad(n, 0.002, 0.04) * 0.6
    write("slash", np.tanh((shear * 1.4 + ring * 0.3 + body) * 1.8), 0.76)
    # blocked: iron on a wooden board-shield
    t = t_axis(0.42)
    n = len(t)
    board = dsp.modal([180, 410, 690, 1150], [1.0, 0.6, 0.4, 0.2], [0.05, 0.035, 0.025, 0.015], 0.42, rng)
    thud2 = np.sin(2 * np.pi * 90 * t) * env_ad(n, 0.001, 0.05)
    write("impact_blocked", board + thud2 + dsp.hp(noise(n), 2000) * env_ad(n, 0.0005, 0.008) * 0.3, 0.7)
    # the iron boss of a board shield, struck
    x = dsp.modal([980 * k for k in (1.0, 2.32, 3.01, 4.27)], [1.0, 0.6, 0.45, 0.25],
                  [0.12, 0.08, 0.06, 0.04], 0.5, rng, 0.0004)
    click = dsp.hp(noise(len(x)), 2400) * env_ad(len(x), 0.001, 0.012)
    write("shield_ding", x + click, 0.66)


def gen_gourd():
    """The Gourd: stopper out, a swallow or two of hot broth, a breath."""
    x = np.zeros(samples(1.3))
    place(x, dsp.modal([620, 1500], [1.0, 0.4], [0.02, 0.01], 0.08, rng, 0.0003), 0.05, 0.6)
    for i in range(2):
        tt = t_axis(0.16)
        g = dsp.lp(noise(len(tt)), 600) * np.sin(np.pi * tt / 0.16) * 0.8
        g += np.sin(2 * np.pi * np.cumsum(260 - 80 * tt / 0.16) / SR) * np.sin(np.pi * tt / 0.16) * 0.4
        place(x, g, 0.3 + i * 0.28)
    place(x, dsp.bp(noise(samples(0.5)), 1000, 1) * np.sin(np.pi * t_axis(0.5) / 0.5) ** 2 * 0.25, 0.8)
    write("gourd", x, 0.55)


def gen_swells():
    """swell_warm: the generic 'something remembered' bloom (gates,
    plaques, the hum). A warm breath out and the kantele's D chord."""
    r = np.random.default_rng(6200)
    x = np.zeros(samples(4.0))
    place(x, _breath_long(r, 2.5, False), 0.0, 0.8)
    for f, at in [(146.8, 0.5), (220.0, 0.62), (293.7, 0.74), (349.2, 0.86), (440.0, 1.0)]:
        place(x, pluck(f, 3.0, 0.3), at, 0.45)
    write("swell_warm", x, 0.7)


def gen_creature():
    t = t_axis(1.8)
    f = 120 + 22 * np.sin(2 * np.pi * 1.4 * t)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(f * 2.02) / SR)
    x = dsp.lp(x, 800) + dsp.lp(noise(len(t)), 400) * 0.3
    x += dsp.crackle(1.8, rng, rate=20, f_lo=2500, f_hi=7000) * 0.2       # rime on its breath
    write("rimewalker_moan", x * env_ad(len(t), 0.4, 0.5), 0.5)
    t = t_axis(2.6)
    f = 95 * np.exp(-t * 0.25)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(2 * np.pi * np.cumsum(f * 1.5) / SR)
    growl = dsp.lp(noise(len(t)) * np.sin(2 * np.pi * 30 * t), 500)
    write("holdfast_roar", (dsp.lp(x, 900) * 0.7 + growl * 0.6) * env_ad(len(t), 0.06, 1.0), 0.8)


def gen_misc():
    # frost veil: a muffled whump and a hush of ice closing behind
    t = t_axis(1.4)
    n = len(t)
    x = np.sin(2 * np.pi * np.cumsum(220 * np.exp(-t * 6)) / SR) * env_ad(n, 0.01, 0.3)
    x += dsp.lp(noise(n), 300) * np.exp(-t / 0.8) * 0.5
    x += dsp.crackle(1.4, rng, rate=60, f_lo=3000, f_hi=9000, decay=np.exp(-t / 0.5)) * 0.15
    write("veil_enter", x, 0.6)
    # ui tick: a small wooden tick (a tally notch)
    write("ui_tick", dsp.modal([1800, 4100], [1.0, 0.4], [0.012, 0.006], 0.07, rng, 0.0002), 0.3)
    # breathmark recovered: a breath taken back, and the kantele answering
    x = np.zeros(samples(1.8))
    place(x, _breath_long(np.random.default_rng(7100), 1.0, True), 0.0, 0.7)
    for f, at in [(293.7, 0.85), (440.0, 0.95), (587.3, 1.05)]:
        place(x, pluck(f, 0.8, 0.4), at, 0.6)
    write("breathmark", x, 0.55)
    # guard break: a board shield splitting
    t = t_axis(0.6)
    n = len(t)
    x = dsp.modal([210, 480, 730], [1.0, 0.5, 0.4], [0.08, 0.05, 0.04], 0.6, rng)
    x += dsp.crackle(0.6, rng, rate=220, f_lo=900, f_hi=4000, decay=np.exp(-t / 0.07)) * 0.6
    x += dsp.lp(noise(n), 900) * env_ad(n, 0.002, 0.08)
    write("guard_break", x, 0.7)


ALL = {
    "footsteps": gen_footsteps, "frost_hits": gen_frost_hits, "parry": gen_parry,
    "coal_catch": gen_coal_catch, "death": gen_death, "wave": gen_wave,
    "horn_low": gen_horn_low, "rest_chime": gen_rest_chime, "warmth": gen_warmth_pickup,
    "levelup": gen_levelup, "whooshes": gen_whooshes, "impacts": gen_impacts,
    "gourd": gen_gourd, "swells": gen_swells, "creature": gen_creature, "misc": gen_misc,
}

if __name__ == "__main__":
    only = set(sys.argv[1:])
    os.makedirs(FOLEY, exist_ok=True)
    for name, fn in ALL.items():
        if only and name not in only:
            continue
        fn()
    print("[sfx] done")
