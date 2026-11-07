#!/usr/bin/env python3
"""Rimeholt's score. Every piece is composed here as data (melody, drone,
harmony), rendered through sampled instruments (FluidR3 GM soundfont via
fluidsynth) for the bowed, blown and sung voices, and mixed with the
physical models in dsp.py (kantele pluck, frame drum, sympathetic strings,
breath, ice) inside a convolution reverb built from a generated IR.

Deterministic: same inputs, same bytes in (bar the Vorbis encoder).
Needs: numpy, scipy, fluidsynth, fluid-soundfont-gm, vorbis-tools.

    python3 tools/audio/music.py [thaw rime outsong boss title ...]

Writes assets/audio/music/*.ogg. See docs/audio/MUSIC.md for the pieces.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal

import dsp
import midi
from dsp import SR, Mix, samples

SF2 = os.environ.get("RH_SF2", "/usr/share/sounds/sf2/FluidR3_GM.sf2")
OUT = os.path.join(dsp.AUDIO, "music")

# GM programs used (FluidR3): the bowed, blown and sung voices
FIDDLE, VIOLIN, VIOLA, CELLO, BASS = 110, 40, 41, 42, 43
FLUTE, RECORDER, OOHS, AAHS, PIZZ = 73, 74, 53, 52, 45

# D dorian, the steading's mode: D E F G A B C (the raised sixth, B, is
# the warmth in it). The Outsong flattens it to aeolian (Bb) for grief.
DORIAN = [midi.n(x) for x in "D3 E3 F3 G3 A3 B3 C4 D4 E4 F4 G4 A4 B4 C5 D5 E5 F5 G5 A5".split()]


def scale_step(p, k, scale=DORIAN):
    """The scale note k steps from pitch p (for ornaments)."""
    if p not in scale:
        return p + (2 if k > 0 else -2)
    i = scale.index(p) + k
    return scale[max(0, min(i, len(scale) - 1))]


def parse(s):
    """'A3:2 D4:1 r:1 |' -> [(pitch|None, units)]. Bars are just for eyes."""
    out = []
    for tok in s.replace("|", " ").split():
        nm, u = tok.split(":")
        out.append((None if nm == "r" else midi.n(nm), float(u)))
    return out


# ------------------------------------------------------------ the tunes

# THE REMEMBERED TUNE (6/8, eighth units). The tune Saltfell sang on Long
# Light evenings; its first three notes (A-D-F) are the Bearer's idle hum.
TUNE_A = parse("A3:2 D4:1 F4:2 E4:1 | D4:2 E4:1 F4:1 G4:1 A4:1 | B4:3 A4:2 G4:1 | A4:3 F4:2 D4:1 |"
               "E4:2 F4:1 G4:2 E4:1 | F4:2 E4:1 D4:2 C4:1 | D4:2 F4:1 E4:2 C4:1 | D4:6")
TUNE_B = parse("A4:2 C5:1 D5:3 | C5:2 A4:1 G4:2 A4:1 | B4:2 A4:1 G4:2 F4:1 | E4:3 A4:3 |"
               "D5:2 C5:1 A4:2 G4:1 | F4:2 G4:1 A4:2 B4:1 | A4:2 F4:1 E4:2 C4:1 | D4:6")
HUM = parse("A3:2 D4:1 F4:3")

# THE OUTSONG (free 4/4, quarter units), D aeolian, with the dorian B
# natural only where the song tells the dead where the door is.
OUT_P1 = parse("A3:1 D4:2 E4:1 | F4:2 E4:1 D4:1 | C4:1 D4:1 A3:2 | D4:4")
OUT_P2 = parse("F4:1 G4:2 A4:1 | Bb4:2 A4:1 G4:1 | F4:1 E4:1 D4:1 E4:1 | A3:4")
OUT_P3 = parse("D4:1 F4:1 A4:2 | B4:2 C5:1 A4:1 | G4:1 F4:1 E4:1 G4:1 | A4:4")
OUT_P4 = parse("A4:1 C5:1 D5:2 | E5:2 D5:1 C5:1 | Bb4:1 A4:1 G4:1 A4:1 | D5:3 r:1")
OUT_P5 = parse("D5:1 C5:1 A4:2 | G4:2 F4:1 E4:1 | F4:1 E4:1 D4:1 C4:1 | D4:4")


class Score:
    """A set of MIDI tracks rendered as separate stems (one fluidsynth pass
    per stem, so each can be placed and reverberated on its own)."""

    def __init__(self, length):
        self.length = length
        self.stems = {}

    def track(self, stem, program, ch=0):
        tr = midi.Track(ch, program, stem)
        self.stems.setdefault(stem, []).append(tr)
        return tr

    def render(self, stem, gain=0.5):
        trs = self.stems[stem]
        # a late no-op so the render runs past every release tail
        trs[0].cc(self.length + 8.0, 91, 0)
        with tempfile.TemporaryDirectory() as td:
            mid = os.path.join(td, "s.mid")
            wav = os.path.join(td, "s.wav")
            midi.write(mid, trs)
            subprocess.run(["fluidsynth", "-ni", "-q", "-g", str(gain), "-r", str(SR),
                            "-o", "synth.reverb.active=0", "-o", "synth.chorus.active=0",
                            "-F", wav, SF2, mid], check=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
            return dsp.read_wav(wav)


def play_line(tr, notes, t0, unit, rng, vel=78, legato=1.0, ornament=0.0, arch=True,
              bend_sag=0.0, cut_after=None, octave=0, slide=0.0, scale=DORIAN):
    """Perform a melody with a folk player's habits: slight rubato, phrase
    arch in the bow (CC11), grace notes before long notes, portamento.
    bend_sag sags held notes flat (a memory going out of tune); cut_after
    stops the line after that many notes, the last one clipped short."""
    t = t0
    total = sum(u for _, u in notes) * unit
    if arch:
        tr.ramp(t0 - 0.05, t0 + total * 0.6, 11, 70, 118, 0.1)
        tr.ramp(t0 + total * 0.6, t0 + total, 11, 118, 82, 0.1)
    prev = None
    for i, (p, u) in enumerate(notes):
        d = u * unit
        if cut_after is not None and i >= cut_after:
            break
        if p is not None:
            p += 12 * octave
            jit = rng.normal(0, 0.012)
            on = max(t + jit, 0.0)
            dur = d * legato
            if cut_after is not None and i == cut_after - 1:
                dur = d * 0.55
            if ornament and u >= 2 and rng.random() < ornament:
                g = scale_step(p, 1, [s + 12 * octave for s in scale])
                tr.note(on - 0.07, 0.075, g, vel - 12)
            if slide and prev is not None and prev != p and abs(prev - p) <= 4:
                tr.bend(on - 0.001, np.clip((prev - p), -2, 2) * 0.5)
                for k in range(1, 6):
                    tr.bend(on + slide * k / 5, np.clip((prev - p), -2, 2) * 0.5 * (1 - k / 5))
            elif bend_sag or slide:
                tr.bend(on - 0.001, 0.0)
            v = vel + rng.normal(0, 4) + (6 if u >= 2 else 0)
            tr.note(on, dur, p, v)
            if bend_sag and d > unit * 1.5:
                steps = 8
                for k in range(1, steps + 1):
                    tr.bend(on + d * k / steps, -bend_sag * (k / steps) ** 1.5)
            prev = p
        t += d
    return t


def bow_drone(tr, pitches, t0, t1, bow=3.6, vel=64, ch2=None):
    """A drone re-bowed every `bow` seconds, alternating two channels so
    each bow change overlaps (no gap where the old note releases)."""
    t = t0
    k = 0
    while t < t1 - 0.01:
        use = tr if (ch2 is None or k % 2 == 0) else ch2
        d = min(bow, t1 - t) + 0.35
        for p in pitches:
            use.note(t, d, p, vel)
        use.ramp(t, t + 0.6, 11, 60, 110, 0.1)
        use.ramp(t + d - 0.8, t + d, 11, 110, 70, 0.1)
        t += bow
        k += 1


def sympathetic(x, pitches, fb=0.9985, amt=0.25):
    """Nyckelharpa resonance strings: lightly damped string loops tuned to
    the mode, excited by whatever is played near them."""
    mono = x.mean(axis=1) if x.ndim == 2 else x
    y = np.zeros_like(mono)
    for p in pitches:
        f = 440 * 2 ** ((p - 69) / 12)
        N = int(round(SR / f))
        a = np.zeros(N + 2)
        a[0] = 1
        a[N] = -fb / 2
        a[N + 1] = -fb / 2
        y += signal.lfilter([1.0], a, dsp.hp(mono, 300) * 0.02)
    y = dsp.hp(y, 200)
    return dsp.to_stereo(y / (np.std(y) + 1e-9) * np.std(mono) * amt)


def heartbeat(buf, t0, t1, beat, rng, gain=1.0, ramp=None):
    """The frame drum: lub on the beat, a softer, higher dub after it."""
    t = t0
    while t < t1:
        g = gain if ramp is None else gain * ramp(t)
        lub = dsp.membrane(68 + rng.normal(0, 0.6), 1.2, rng, damp=0.32, slap=0.18)
        dub = dsp.membrane(80 + rng.normal(0, 0.6), 0.9, rng, damp=0.22, slap=0.1)
        dsp.mix_into(buf, dsp.pan(lub, -0.12), max(t + rng.normal(0, 0.006), 0.0), 0.9 * g)
        dsp.mix_into(buf, dsp.pan(dub, -0.12), t + beat * 0.32 + rng.normal(0, 0.006), 0.45 * g)
        t += beat


def kantele(buf, notes, rng, gain=1.0, p=0.25):
    for at, pitch, vel in notes:
        f = 440 * 2 ** ((pitch - 69) / 12)
        x = dsp.ks_pluck(f, 3.2, rng, bright=0.25, decay=0.9975)
        x = dsp.lp(x, 3200, 4)          # a gut-strung kantele, not a steel click
        dsp.mix_into(buf, dsp.pan(x, p + rng.normal(0, 0.05)), at, gain * vel)


def breath(dur, rng, inhale=True, gain=1.0):
    """One human breath in the cold: noise through a moving mouth formant."""
    n = samples(dur)
    t = np.arange(n) / n
    env = np.sin(np.pi * t) ** (1.6 if inhale else 0.9)
    if not inhale:
        env *= np.exp(-t * 1.2)
    x = dsp.pink(n, rng)
    f = (900 + 900 * t) if inhale else (1300 - 600 * t)
    y = dsp.tv_lowpass(x, f * 1.6) - dsp.tv_lowpass(x, f * 0.35)
    y += dsp.reson(x, 1500 if inhale else 1100, 4) * 0.25
    y = dsp.hp(dsp.lp(y, 2600 if inhale else 2000, 4), 220, 2)
    return y * env * gain / (np.std(y) + 1e-9) * 0.2


def ice_ticks(buf, t0, t1, rng, count, gain=1.0):
    for _ in range(count):
        at = rng.uniform(t0, t1)
        if rng.random() < 0.5:
            x = dsp.ice_ping(rng.uniform(3000, 6500), rng.uniform(500, 1400), rng.uniform(0.25, 0.7), rng)
        else:
            x = dsp.modal([rng.uniform(2800, 5200) * r for r in (1, 1.47, 2.31)], [1, 0.5, 0.3],
                          [0.03, 0.02, 0.012], 0.15, rng, 0.0003)
        dsp.mix_into(buf, dsp.pan(x, rng.uniform(-0.8, 0.8)), at, gain * rng.uniform(0.3, 1.0))


def shepard(dur, rng, period=24.0, f_lo=110.0, octaves=5, gain=1.0):
    """Rising strain that never arrives: a Shepard-Risset glissando of
    bowed-ish partials (octave-spaced, bell-shaped spectral weight)."""
    n = samples(dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for i in range(octaves):
        pos = ((t / period) + i / 1.0) % octaves      # 0..octaves
        f = f_lo * 2 ** pos
        w = np.exp(-0.5 * ((pos - octaves / 2) / (octaves / 5)) ** 2)
        ph = 2 * np.pi * np.cumsum(f) / SR
        # a little bow saw in each partial, so it reads as strings straining
        x += w * (np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph))
    trem = 1 + 0.08 * np.sin(2 * np.pi * 5.5 * t)
    return x * trem * gain


def xfade_loop(x, L, X):
    """For continuous (non-event) layers: loop by crossfading the overrun
    back over the head. Needs len(x) >= L + X."""
    out = x[:L].copy()
    c = np.sin(np.linspace(0, np.pi / 2, X)) ** 2
    if out.ndim == 2:
        c = c[:, None]
    out[:X] = out[:X] * c + x[L:L + X] * (1 - c)
    return out


def master(x, rms_db=-20.0, lp_hz=None, hp_hz=35.0, loop=True):
    """Final EQ and level. For a loop the filters run on a circular pre-roll
    (the end of the loop placed before its start), so their state at
    sample 0 is what it would be on the second pass: no seam."""
    pre = samples(3.0) if loop else 0
    if pre:
        x = np.concatenate([x[-pre:], x], axis=0)
    x = dsp.hp(x, hp_hz)
    if lp_hz:
        x = dsp.lp(x, lp_hz)
    x = x[pre:]
    r = np.sqrt(np.mean(x ** 2)) + 1e-12
    y = x * (10 ** (rms_db / 20) / r)
    pk = np.max(np.abs(y))
    if pk > 0.95:      # gentle peak taming, not loudness
        y = np.tanh(y / pk * 1.6) / np.tanh(1.6) * 0.95
    return y


def piece_thaw():
    """Midsummer Evening. A remembered tune in D dorian over a bowed drone,
    the frame drum keeping a heartbeat. 48 bars of 6/8, loops whole."""
    rng = np.random.default_rng(101)
    e = 0.3                      # eighth
    bar = 6 * e                  # 1.8 s; the dotted quarter = 67/min, a resting heart
    L = 48 * bar
    sc = Score(L)
    dr1 = sc.track("drone", FIDDLE, 0)
    dr2 = sc.track("drone", FIDDLE, 1)
    bow_drone(dr1, [midi.n("D3"), midi.n("A3")], 0.0, L, bow=2 * bar, vel=54, ch2=dr2)

    fid = sc.track("fiddle", FIDDLE, 2)
    t = 4 * bar
    t = play_line(fid, TUNE_A, t, e, rng, vel=84, ornament=0.5)              # bars 4-11
    play_line(fid, TUNE_A, t, e, rng, vel=74, ornament=0.6)                  # 12-19 (flute joins)
    t = 20 * bar
    t = play_line(fid, TUNE_B, t, e, rng, vel=86, ornament=0.5)              # 20-27
    # 28-35: the flute has the tune; the fiddle walks a low second line
    low = parse("D4:6 | C4:6 | G3:6 | A3:6 | F3:6 | G3:3 A3:3 | A3:6 | D4:6")
    play_line(fid, low, t, e, rng, vel=60, arch=False)
    play_line(fid, TUNE_A, 36 * bar, e, rng, vel=70, ornament=0.4)           # 36-43, alone

    fl = sc.track("flute", FLUTE, 3)
    play_line(fl, TUNE_A, 12 * bar, e, rng, vel=60, octave=1, legato=0.95)
    play_line(fl, TUNE_B, 28 * bar, e, rng, vel=78, octave=0, legato=0.97, ornament=0.3)

    m = Mix(L + 8)
    drone = sc.render("drone")
    m.add(drone, -10)
    m.add(sc.render("fiddle"), 0, p=-0.15)
    m.add(sc.render("flute"), -4, p=0.3)
    m.add(sympathetic(m.buf, [midi.n(p) for p in ("D4", "A4", "D5", "F4", "E5", "B4")]), -17)

    # kantele: the chord tones on the downbeats while the tune is in B
    chords = ["D3 A3 D4 F4", "C3 G3 C4 E4", "G3 D4 G4 B4", "A3 E4 A4 C5",
              "D3 A3 D4 F4", "F3 C4 F4 A4", "A3 E4 A4 C5", "D3 A3 D4 F4"]
    kn = []
    for rep in (20, 28):
        for i, ch in enumerate(chords):
            ps = [midi.n(c) for c in ch.split()]
            for k, p in enumerate(ps):
                kn.append(((rep + i) * bar + k * e * 0.5 + rng.normal(0, 0.005), p, 1.0 - 0.12 * k))
            kn.append(((rep + i) * bar + 3 * e, ps[-1] + (2 if i % 2 else 0), 0.5))
    kb = m.bus()
    kantele(kb, kn, rng, 1.0, 0.35)
    m.add(dsp.lp(kb, 3800), -9)

    hb = m.bus()
    heartbeat(hb, 0.0, L, 3 * e, rng, 1.0,
              ramp=lambda tt: 0.6 if (tt < 4 * bar or tt > 44 * bar) else 1.0)
    m.add(dsp.lp(hb, 900), -13)
    ir = dsp.make_ir(rt60=1.7, pre=0.018, damp_hz=6000, width=0.9, seed=11)
    wet = dsp.reverb(m.buf, ir, wet=0.3)
    return master(dsp.fold_loop(wet, samples(L)), -19.5, lp_hz=9500), True


def piece_rime():
    """The Long Winter. Breath, a low bowed drone, ice ticking, and the
    remembered tune coming back slowed, sagging flat and breaking off."""
    rng = np.random.default_rng(202)
    L = 96.0
    sc = Score(L)
    c1 = sc.track("drone", CELLO, 0)
    c2 = sc.track("drone", CELLO, 1)
    bow_drone(c1, [midi.n("D2"), midi.n("A2")], 0.0, L, bow=8.0, vel=46, ch2=c2)
    b1 = sc.track("bass", BASS, 2)
    bow_drone(b1, [midi.n("D2")], 0.0, L, bow=12.0, vel=40)

    e = 0.62                     # the tune at half speed and then some
    mem = sc.track("memory", FIDDLE, 3)
    play_line(mem, TUNE_A, 9.0, e, rng, vel=66, bend_sag=0.35, cut_after=9, legato=1.05)
    play_line(mem, TUNE_B, 62.0, e * 1.1, rng, vel=62, bend_sag=0.5, cut_after=3, legato=1.05)
    play_line(mem, HUM, 84.0, e * 1.3, rng, vel=38, bend_sag=0.2, cut_after=2)
    fl = sc.track("flute", FLUTE, 4)
    play_line(fl, TUNE_A, 38.0, e * 1.15, rng, vel=56, octave=-1, bend_sag=0.3, cut_after=6)

    m = Mix(L + 14)
    m.add(dsp.lp(sc.render("drone"), 1400), -3)
    m.add(dsp.lp(sc.render("bass"), 600), -10)
    # the memory heard through ice: dull, distant, a little to one side
    m.add(dsp.lp(sc.render("memory"), 2400), -6, p=0.25)
    m.add(dsp.lp(sc.render("flute"), 1800), -8, p=-0.35)

    # a synth bow an octave under the drone, nearly still
    sb = m.bus()
    for at in np.arange(0.0, L, 16.0):
        tt = dsp.t_axis(19.0)
        sw = np.clip(np.minimum(tt / 5.0, (19.0 - tt) / 5.0), 0, 1) ** 1.5
        x = dsp.bowed(36.71, 19.0, rng, bright=0.25, vib_depth=0.0015, vib_rate=3.0, swell=sw, pressure=0.3)
        dsp.mix_into(sb, dsp.lp(x, 500), at)
    m.add(sb, -14)

    # breath: someone near, in the cold, slow
    br = m.bus()
    for at, inh in [(3.0, True), (6.5, False), (27.0, True), (30.8, False), (51.0, True),
                    (54.6, False), (75.5, True), (79.0, False)]:
        dsp.mix_into(br, dsp.pan(breath(3.2 if inh else 4.4, rng, inh), -0.1), at)
    m.add(dsp.lp(br, 2800), -17)
    it = m.bus()
    ice_ticks(it, 0.0, L, rng, 26, 1.0)
    m.add(it, -16)

    ir = dsp.make_ir(rt60=4.2, pre=0.03, damp_hz=4200, width=1.0, seed=12)
    wet = dsp.reverb(m.buf, ir, wet=0.5, dry=0.8)
    return master(dsp.fold_loop(wet, samples(L)), -23.0, lp_hz=8000), True


def piece_outsong():
    """The rite, at the hearth. The Leadvoice alone; then the household,
    humming; then the neighbours outside the door; then the voice alone
    again with the three notes of the hum, and the room lets go."""
    rng = np.random.default_rng(303)
    q = 0.95
    aeol = [midi.n(x) for x in "D3 E3 F3 G3 A3 Bb3 C4 D4 E4 F4 G4 A4 Bb4 C5 D5 E5 F5".split()]
    ph = 16 * q                  # one phrase
    T = [2.0 + i * ph for i in range(7)]
    L = T[6] + 18.0
    sc = Score(L)
    solo = sc.track("solo", VIOLA, 0)
    kw = dict(rng=rng, slide=0.09, scale=aeol, legato=1.02)
    play_line(solo, OUT_P1, T[0], q * 1.08, vel=74, ornament=0.3, **kw)      # alone
    play_line(solo, OUT_P2, T[1], q * 1.04, vel=78, ornament=0.3, **kw)
    play_line(solo, OUT_P3, T[2], q, vel=84, ornament=0.4, **kw)             # household
    play_line(solo, OUT_P4, T[3], q, vel=96, ornament=0.4, **kw)             # the door
    play_line(solo, OUT_P5, T[4], q, vel=88, ornament=0.3, **kw)             # neighbours
    play_line(solo, OUT_P1, T[5], q, vel=86, ornament=0.5, octave=1, **kw)   # all, solo above
    # coda: alone. The hum, then a held E that does not resolve; the room does.
    t = play_line(solo, HUM, T[6], q * 0.6, vel=64, arch=False, **kw)
    solo.note(t + 0.2, 4.5, midi.n("E4"), 58)
    solo.ramp(t + 0.2, t + 4.7, 11, 100, 40, 0.1)

    hum = sc.track("household", OOHS, 1)
    hum2 = sc.track("household", OOHS, 2)
    chords3 = ["D3 A3 D4", "D3 G3 B3", "C3 G3 E4", "A2 E3 C4"]     # under P3 (B natural)
    chords4 = ["D3 A3 F4", "C3 G3 E4", "G2 D3 Bb3", "D3 A3 F4"]
    chords5 = ["D3 A3 F4", "C3 G3 E4", "Bb2 F3 D4", "D3 A3 F4"]
    chords6 = ["D3 A3 F4", "Bb2 F3 D4", "A2 E3 C4", "D3 A3 D4"]

    def pad(trs, chords, t0, vel, bar=4 * q):
        for i, ch in enumerate(chords):
            tr = trs[i % 2]
            for p in ch.split():
                tr.note(t0 + i * bar, bar + 0.5, midi.n(p), vel)
            tr.ramp(t0 + i * bar, t0 + i * bar + 1.2, 11, 50, 105, 0.1)
            tr.ramp(t0 + i * bar + bar - 0.9, t0 + i * bar + bar + 0.5, 11, 105, 60, 0.1)

    pad([hum, hum2], chords3, T[2], 52)
    pad([hum, hum2], chords4, T[3], 60)
    pad([hum, hum2], chords5, T[4], 62)
    pad([hum, hum2], chords6, T[5], 66)
    # the room's answer to the unresolved E: an open D, no third
    for p in ("D3", "A3", "D4"):
        hum.note(t + 2.4, 9.0, midi.n(p), 50)
    hum.ramp(t + 2.4, t + 5.0, 11, 30, 96, 0.1)
    hum.ramp(t + 7.0, t + 11.4, 11, 96, 0, 0.1)

    out = sc.track("neighbours", AAHS, 3)
    out2 = sc.track("neighbours", OOHS, 4)
    pad([out, out2], ["D3 F3 A3 D4", "C3 E3 G3 C4", "Bb2 D3 F3 Bb3", "D3 F3 A3 D4"], T[4], 48)
    pad([out, out2], ["D3 F3 A3 D4", "Bb2 D3 F3 Bb3", "A2 C3 E3 A3", "D3 A3 D4 F4"], T[5], 58)

    near = Mix(L + 6)
    near.add(sc.render("solo"), 0, p=0.0)
    near.add(sc.render("household"), -7)
    far = Mix(L + 6)
    far.add(dsp.lp(sc.render("neighbours"), 1500), -11)
    # the hearth itself: a fire under the whole rite, quiet
    fire = dsp.crackle(L, rng, rate=7, f_lo=900, f_hi=4800)
    fire += dsp.lp(dsp.pink(samples(L), rng), 300) * 0.02
    fade = np.clip(np.minimum(dsp.t_axis(L) / 3.0, (L - dsp.t_axis(L)) / 6.0), 0, 1)
    near.add(fire * fade, -26, p=-0.4)
    room = dsp.make_ir(rt60=2.3, pre=0.012, damp_hz=5200, width=0.8, seed=13)
    yard = dsp.make_ir(rt60=3.6, pre=0.05, damp_hz=3000, width=1.0, seed=14)
    mix = dsp.reverb(near.buf, room, wet=0.32)
    farw = dsp.reverb(far.buf, yard, wet=0.9, dry=0.25)
    n = min(len(mix), len(farw))
    mix = mix[:n] + farw[:n]
    mix = dsp.fade(mix[:samples(L + 4)], head=0.5, tail=3.0)
    return master(mix, -20.0, lp_hz=10000, loop=False), False


def piece_boss_netmender():
    """The Netmender. A knot figure in 7/8 (over, under, through) that
    never stops being tied; a strain that keeps rising and never arrives;
    and once a loop, the net cut open and begun again."""
    rng = np.random.default_rng(404)
    e = 0.16
    bar = 7 * e                         # 1.12 s
    L = 64 * bar
    knot = ["D4", "F4", "E4", "D4", "G4", "F4", "E4"]
    accents = [1.0, 0.6, 0.85, 0.6, 0.95, 0.7, 0.65]
    sc = Score(L)
    fid = sc.track("knot", FIDDLE, 0)
    can = sc.track("canon", VIOLA, 1)
    vln = sc.track("strain", VIOLIN, 2)
    cel = sc.track("pulse", CELLO, 3)
    cel2 = sc.track("low", CELLO, 4)

    def root_for(b):
        if 32 <= b < 36:
            return -2           # onto C
        if 40 <= b < 44:
            return 1            # the phrygian Eb: the knot pulls tight
        return 0

    kn = []
    for b in range(60):
        r = root_for(b)
        for k, nm in enumerate(knot):
            at = b * bar + k * e + rng.normal(0, 0.004)
            p = midi.n(nm) + r
            v = 64 + 34 * accents[k] + (10 if b >= 48 else 0)
            fid.note(max(at, 0.0), e * 0.7, p, v)
            kn.append((max(at, 0.0), p, accents[k] * (0.6 if b < 16 else 1.0)))
            if 16 <= b < 60:   # the canon: the same knot tied over itself, an eighth late, a fifth up
                can.note(at + e, e * 0.6, p + 7, v - 14)
        cel.note(b * bar, e * 1.6, midi.n("D2") + r, 100)
    for b in range(8, 60, 4):
        r = root_for(b)
        for p in ("D2", "A2"):
            cel2.note(b * bar, 4 * bar + 0.2, midi.n(p) + r, 58 if b < 32 else 72)
        cel2.ramp(b * bar, b * bar + 1.5, 11, 60, 115, 0.1)
    # the strain: long violin notes, each a step higher, crescendo, pressing sharp
    strain = [(16, "A4"), (20, "Bb4"), (24, "C5"), (28, "D5"), (32, "C5"), (36, "D5"),
              (40, "Eb5"), (44, "E5"), (48, "F5"), (52, "G5"), (56, "A5")]
    for b, nm in strain:
        vln.note(b * bar, 4 * bar + 0.05, midi.n(nm), 66 + (b - 16) * 1.0)
        vln.ramp(b * bar, b * bar + 4 * bar, 11, 64, 127, 0.1)
        for k in range(1, 9):
            vln.bend(b * bar + 4 * bar * k / 8, 0.12 * k / 8)
        vln.bend(b * bar + 4 * bar, 0.0)

    m = Mix(L + 10)
    m.add(sc.render("knot"), 0, p=-0.25)
    m.add(sc.render("canon"), -5, p=0.35)
    m.add(sc.render("strain"), -4, p=0.1)
    m.add(sc.render("pulse"), -6)
    m.add(sc.render("low"), -9)
    # the twine itself: a dry pluck on every knot note (net-needle on cord)
    kb = m.bus()
    kantele(kb, kn, rng, 1.0, -0.3)
    m.add(dsp.lp(kb, 3000), -10)
    # frame drum on the 2+2+3 pulse; denser from bar 32, but always hand-sized
    db = m.bus()
    for b in range(60):
        for k, g in [(0, 1.0), (2, 0.55), (4, 0.75)] + ([(6, 0.35)] if b >= 32 else []):
            d = dsp.membrane(72 + rng.normal(0, 0.8), 0.9, rng, damp=0.2, slap=0.3)
            dsp.mix_into(db, dsp.pan(d, 0.05), max(b * bar + k * e + rng.normal(0, 0.004), 0.0),
                         g * (0.6 if b < 8 else 1.0))
    m.add(dsp.lp(db, 1500), -10)
    # the net cut: a frost-crack on bar 60, then air
    m.add(dsp.ice_ping(5200, 700, 0.8, rng), -8, at=60 * bar, p=0.0)
    ir = dsp.make_ir(rt60=2.0, pre=0.01, damp_hz=5000, width=0.9, seed=15)
    wet = dsp.reverb(m.buf, ir, wet=0.3)
    looped = dsp.fold_loop(wet, samples(L))
    # rising strain under everything (continuous, crossfade-looped)
    sh = dsp.lp(shepard(L + 4.0, rng, period=bar * 16, f_lo=110), 3000)
    sh_l = xfade_loop(sh, samples(L), samples(4.0))
    looped += dsp.to_stereo(sh_l) * (10 ** (-38 / 20) / dsp.active_rms(sh_l))
    return master(looped, -18.0, lp_hz=11000), True


def piece_title():
    """The coal in the horn. A low drone and a breath; the remembered tune
    once, slowly, on a lone flute; then the Outsong's first phrase on the
    viola, far off, as if the game already knows how it ends."""
    rng = np.random.default_rng(505)
    L = 76.0
    sc = Score(L)
    c1 = sc.track("drone", CELLO, 0)
    c2 = sc.track("drone", CELLO, 1)
    bow_drone(c1, [midi.n("D2"), midi.n("A2")], 0.0, L, bow=9.5, vel=48, ch2=c2)
    fl = sc.track("flute", FLUTE, 2)
    play_line(fl, TUNE_A, 6.0, 0.44, rng, vel=70, ornament=0.4, legato=0.98)
    play_line(fl, HUM, 66.0, 0.6, rng, vel=54, arch=False)
    va = sc.track("viola", VIOLA, 3)
    play_line(va, OUT_P1, 34.0, 1.0, rng, vel=66, slide=0.09, legato=1.02,
              scale=[midi.n(x) for x in "D3 E3 F3 G3 A3 Bb3 C4 D4 E4 F4 G4 A4 Bb4 C5".split()])
    va.note(51.5, 7.0, midi.n("A3"), 52)
    hum = sc.track("hum", OOHS, 4)
    for at, ch in [(34.0, "D3 A3"), (41.6, "Bb2 F3"), (49.2, "A2 E3"), (56.8, "D3 A3")]:
        for p in ch.split():
            hum.note(at, 7.8, midi.n(p), 44)
        hum.ramp(at, at + 2.0, 11, 30, 90, 0.1)
        hum.ramp(at + 5.8, at + 7.8, 11, 90, 30, 0.1)

    m = Mix(L + 12)
    m.add(dsp.lp(sc.render("drone"), 1500), -8)
    m.add(sc.render("flute"), 0, p=-0.2)
    m.add(dsp.lp(sc.render("viola"), 3200), -2, p=0.25)
    m.add(sc.render("hum"), -10)
    m.add(sympathetic(m.buf, [midi.n(p) for p in ("D4", "A4", "D5", "F4")]), -18)
    # embers: the coal, sparse plucks low in the kantele like a fire ticking
    kb = m.bus()
    kantele(kb, [(at, midi.n(p), 1.0) for at, p in
                 [(2.0, "D3"), (14.5, "A3"), (27.0, "D3"), (31.5, "F3"), (60.0, "D3"), (70.5, "A3")]],
            rng, 1.0, 0.3)
    m.add(dsp.lp(kb, 3000), -8)
    br = m.bus()
    for at, inh in [(0.5, False), (24.0, True), (28.0, False), (62.0, True)]:
        dsp.mix_into(br, breath(3.4, rng, inh), at)
    m.add(br, -19)
    ir = dsp.make_ir(rt60=3.2, pre=0.02, damp_hz=4800, width=1.0, seed=16)
    wet = dsp.reverb(m.buf, ir, wet=0.4)
    return master(dsp.fold_loop(wet, samples(L)), -21.0, lp_hz=9000), True


PIECES = {
    "thaw": ("theme_thaw", piece_thaw),
    "rime": ("theme_rime", piece_rime),
    "outsong": ("outsong", piece_outsong),
    "boss": ("boss_netmender", piece_boss_netmender),
    "title": ("theme_title", piece_title),
}


def main(names):
    os.makedirs(OUT, exist_ok=True)
    for key, (fname, fn) in PIECES.items():
        if names and key not in names:
            continue
        x, loops = fn()
        if loops:
            print(f"[music] {fname}: seam ratio {dsp.seam_report(x):.2f} (1 = seamless)")
        dsp.write_ogg(os.path.join(OUT, fname + ".ogg"), x, quality=4)
        if os.environ.get("RH_KEEP_WAV"):
            dsp.write_wav(os.path.join(os.environ["RH_KEEP_WAV"], fname + ".wav"), x)


if __name__ == "__main__":
    main(set(sys.argv[1:]))
