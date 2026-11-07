"""Shared DSP for the Rimeholt audio tools: filters, physical-model voices,
a generated-IR convolution reverb, seamless loop folding and file output.

Everything is deterministic: every random draw comes from a seeded
generator passed in (or derived from a fixed seed).
"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO = os.path.join(ROOT, "assets", "audio")


def secs(n):
    return n / SR


def samples(t):
    return int(round(t * SR))


def t_axis(dur):
    return np.arange(samples(dur)) / SR


# ------------------------------------------------------------------ filters

def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.999), "low")
    return signal.lfilter(b, a, x, axis=0)


def hp(x, fc, order=2):
    b, a = signal.butter(order, max(fc / (SR / 2), 1e-5), "high")
    return signal.lfilter(b, a, x, axis=0)


def bp(x, f0, q=2.0, order=2):
    lo = max(f0 * (1 - 0.5 / q), 10.0)
    hi = min(f0 * (1 + 0.5 / q), SR / 2 * 0.98)
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x, axis=0)


def reson(x, f0, q):
    """Two-pole resonator (a body mode, a formant, a ringing ice sheet)."""
    w = 2 * np.pi * f0 / SR
    r = np.exp(-np.pi * f0 / (q * SR))
    b = [1 - r]
    a = [1, -2 * r * np.cos(w), r * r]
    return signal.lfilter(b, a, x, axis=0)


def tv_lowpass(x, fc_curve):
    """One-pole lowpass whose cutoff follows a per-sample curve (gusts,
    bow pressure, a wave drawing back). Processed in short blocks."""
    y = np.zeros_like(x)
    z = 0.0
    blk = 256
    for i in range(0, len(x), blk):
        fc = float(np.mean(fc_curve[i:i + blk]))
        a = np.exp(-2 * np.pi * max(fc, 5.0) / SR)
        seg, zf = signal.lfilter([1 - a], [1, -a], x[i:i + blk], zi=[z])
        y[i:i + blk] = seg
        z = zf[0]
    return y


def pink(n, rng):
    """Pink noise by spectral shaping (-3 dB/oct)."""
    X = np.fft.rfft(rng.normal(0, 1, n))
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1]
    X /= np.sqrt(f)
    x = np.fft.irfft(X, n)
    return x / (np.std(x) + 1e-12)


def brown(n, rng):
    x = np.cumsum(rng.normal(0, 1, n))
    x = hp(x, 15.0)
    return x / (np.std(x) + 1e-12)


def smooth_curve(n, rng, rate_hz, lo=0.0, hi=1.0):
    """A slow random curve (gusts, swells) at roughly rate_hz changes/s."""
    k = max(int(n / SR * rate_hz) + 4, 4)
    pts = rng.uniform(0, 1, k)
    xs = np.linspace(0, n, k)
    c = np.interp(np.arange(n), xs, pts)
    c = lp(c, max(rate_hz, 0.05), 1)
    c = (c - c.min()) / (np.ptp(c) + 1e-9)
    return lo + (hi - lo) * c


def periodic_curve(n, rng, cycles, lo=0.0, hi=1.0, harmonics=4):
    """A slow random curve that is exactly periodic over n samples, so a
    loop built on it has no seam at all."""
    t = np.arange(n) / n
    c = np.zeros(n)
    for h in range(1, harmonics + 1):
        c += rng.uniform(0.3, 1.0) / h * np.sin(2 * np.pi * cycles * h * t + rng.uniform(0, 6.28))
    c = (c - c.min()) / (np.ptp(c) + 1e-9)
    return lo + (hi - lo) * c


# ------------------------------------------------------ physical models

def ks_pluck(f0, dur, rng, bright=0.5, decay=0.996, pos=0.18):
    """Karplus-Strong plucked string as an IIR (lfilter), with a pluck
    position comb. The integer loop is re-tuned by resampling so it plays
    in tune (a kantele / lyre is a folk instrument, not an out-of-tune one)."""
    N = max(int(round(SR / f0 - 0.5)), 2)
    f_act = SR / (N + 0.5)
    n = samples(dur * f_act / f0) + 2
    exc = rng.uniform(-1, 1, N)
    exc = lp(exc, 800 + 7000 * bright, 1)
    k = max(int(N * pos), 1)                   # pluck position: comb notch
    exc[k:] -= exc[:-k] * 0.9
    x = np.zeros(n)
    x[:N] = exc
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -decay * 0.5
    a[N + 1] = -decay * 0.5
    y = signal.lfilter([1.0], a, x)
    m = samples(dur)
    y = np.interp(np.arange(m) * f_act / f0, np.arange(n), y)
    return y * np.minimum(1.0, (m - np.arange(m)) / (0.02 * SR))


def bowed(f0, dur, rng, bright=0.5, vib_rate=5.2, vib_depth=0.004, swell=None,
          pressure=0.6, body=None):
    """A bowed string, waveguide-flavoured: a slip-stick sawtooth whose
    corner rounds with bow pressure, jittered per period (rosin noise),
    through a wooden body (fixed resonances). Not a true waveguide solve,
    but it has the three things the ear hears in a bow: the Helmholtz saw,
    the scratch and the box."""
    n = samples(dur)
    t = np.arange(n) / SR
    vib_on = np.clip((t - 0.25) / 0.6, 0, 1)
    f = f0 * (1 + vib_depth * vib_on * np.sin(2 * np.pi * vib_rate * t + rng.uniform(0, 6)))
    f *= 1 + 0.0015 * smooth_curve(n, rng, 3.0, -1, 1)
    ph = np.cumsum(f) / SR
    saw = 2 * (ph % 1.0) - 1
    # pressure: more pressure, sharper corner, brighter
    saw = lp(saw, 900 + 4200 * pressure * bright, 2)
    scratch = hp(rng.normal(0, 1, n), 2500) * 0.05 * pressure
    scratch *= 0.5 + 0.5 * np.abs(np.sin(np.pi * ph))       # noise rides the slip
    x = saw + scratch
    if body is None:
        body = [(280, 6, 1.0), (460, 8, 0.7), (1150, 5, 0.5), (2900, 4, 0.35)]
    y = x * 0.35
    for bf, bq, ba in body:
        y = y + reson(x, bf, bq) * ba
    if swell is None:
        a = min(0.35, dur * 0.3)
        r = min(0.5, dur * 0.4)
        swell = np.clip(np.minimum(t / a, (dur - t) / r), 0, 1) ** 0.8
    return y * swell


def breath_noise(dur, rng, f_lo=500, f_hi=2600, shape=None):
    """Breath through lips or a flute embouchure: band-limited noise."""
    n = samples(dur)
    x = bp(rng.normal(0, 1, n), (f_lo + f_hi) / 2, (f_lo + f_hi) / 2 / (f_hi - f_lo + 1))
    if shape is not None:
        x *= shape
    return x


def flute(f0, dur, rng, breath=0.22, vib=4.8):
    """A breathy wooden flute: near-sine with a soft second and third,
    chiff on the attack, and breath noise shaped by the tone."""
    n = samples(dur)
    t = np.arange(n) / SR
    vib_on = np.clip((t - 0.3) / 0.8, 0, 1)
    f = f0 * (1 + 0.005 * vib_on * np.sin(2 * np.pi * vib * t + rng.uniform(0, 6)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) + 0.22 * np.sin(2 * ph + 0.4) + 0.08 * np.sin(3 * ph + 1.1)
    a = min(0.09, dur * 0.2)
    env = np.clip(np.minimum(t / a, (dur - t) / min(0.25, dur * 0.3)), 0, 1)
    br = reson(rng.normal(0, 1, n), f0 * 2, 6) * 0.4 + bp(rng.normal(0, 1, n), 3000, 1.2) * 0.6
    chiff = bp(rng.normal(0, 1, n), f0 * 3, 3) * np.exp(-t / 0.03) * 1.2
    return tone * env + (br * breath * (0.4 + 0.6 * env)) + chiff * 0.3


def formant_voice(f0_curve, rng, vowels, breath=0.08):
    """A sung/hummed voice: glottal pulse source through vowel formants.
    f0_curve: per-sample pitch. vowels: per-sample (F1, F2, F3) array."""
    n = len(f0_curve)
    ph = np.cumsum(f0_curve) / SR
    frac = ph % 1.0
    # Rosenberg-ish glottal pulse: open phase rises then closes sharply
    op = 0.6
    g = np.where(frac < op, 0.5 - 0.5 * np.cos(np.pi * frac / op),
                 np.cos(np.pi * (frac - op) / (2 * (1 - op))))
    src = np.diff(g, prepend=g[0]) * SR / np.maximum(f0_curve, 50) * 0.02
    src += rng.normal(0, 1, n) * breath
    out = np.zeros(n)
    blk = 512
    for i in range(0, n, blk):
        F = vowels[min(i + blk // 2, n - 1)]
        seg = src[max(i - 2048, 0):i + blk]
        y = np.zeros(len(seg))
        for k, (fq, amp, q) in enumerate(zip(F, (1.0, 0.6, 0.25), (8, 12, 14))):
            y += reson(seg, fq, q) * amp
        out[i:i + blk] = y[-min(blk, n - i):]
    return out


def membrane(f0, dur, rng, damp=0.25, slap=0.3, bend=0.12):
    """A frame drum: circular-membrane modes (Bessel ratios) with a small
    pitch fall as the skin relaxes, and the hand's slap."""
    n = samples(dur)
    t = np.arange(n) / SR
    ratios = [1.0, 1.594, 2.136, 2.296, 2.653, 2.918, 3.156]
    amps = [1.0, 0.55, 0.36, 0.3, 0.2, 0.14, 0.1]
    x = np.zeros(n)
    fall = 1 + bend * np.exp(-t / 0.03)
    for r, a in zip(ratios, amps):
        tau = damp / (r ** 1.3)
        x += a * np.sin(2 * np.pi * np.cumsum(f0 * r * fall) / SR + rng.uniform(0, 6)) * np.exp(-t / tau)
    x += lp(rng.normal(0, 1, n), 1800) * np.exp(-t / 0.012) * slap
    return x * np.minimum(t / 0.0015, 1)


def modal(freqs, amps, taus, dur, rng, strike=0.002):
    """A struck object as a sum of decaying modes (iron, ice, wood)."""
    n = samples(dur)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f, a, tau in zip(freqs, amps, taus):
        if f < SR / 2:
            x += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) * np.exp(-t / tau)
    return x * np.minimum(t / max(strike, 1e-4), 1)


def ice_ping(f_hi, f_lo, dur, rng):
    """The sound frozen lakes make: a dispersive chirp falling from f_hi
    to f_lo (high frequencies travel faster through the sheet)."""
    n = samples(dur)
    t = np.arange(n) / SR
    f = f_lo + (f_hi - f_lo) * np.exp(-t / (dur * 0.18))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (dur * 0.35))
    return x * np.minimum(t / 0.001, 1)


def crackle(dur, rng, rate=60.0, f_lo=1500, f_hi=7000, decay=None):
    """Sparse clicks through random resonators: ice forming, embers."""
    n = samples(dur)
    x = np.zeros(n)
    k = int(rate * dur)
    for _ in range(k):
        i = rng.integers(0, max(n - 400, 1))
        x[i] += rng.uniform(-1, 1) * rng.uniform(0.2, 1.0)
    y = np.zeros(n)
    for f in np.geomspace(f_lo, f_hi, 5):
        y += reson(x, f * rng.uniform(0.9, 1.1), 18)
    if decay is not None:
        y *= decay
    return y


# ------------------------------------------------------------ space

def make_ir(rt60=2.6, dur=None, pre=0.012, damp_hz=5200, early=10, width=1.0, seed=99,
            lo_rt=None):
    """A generated room impulse response (stereo): a sparse cluster of early
    reflections then a diffuse tail of decaying noise whose highs die
    faster than its lows (air and timber absorb treble). A timber hall,
    not a cathedral: rt60 ~ 1.8-3 s."""
    rng = np.random.default_rng(seed)
    dur = dur or rt60 * 1.3
    n = samples(dur)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    p0 = samples(pre)
    for ch in range(2):
        noise = rng.normal(0, 1, n)
        # frequency-dependent decay: split into lows and highs
        lo_n = lp(noise, 700)
        hi_n = noise - lo_n
        lo_rt = lo_rt or rt60 * 1.15
        tail = lo_n * np.exp(-6.9 * t / lo_rt) + hi_n * np.exp(-6.9 * t / (rt60 * 0.6))
        tail = lp(tail, damp_hz)
        tail *= np.clip((t - pre) / 0.04, 0, 1)      # the tail builds in
        for _ in range(early):
            d = samples(rng.uniform(pre, pre + 0.07))
            if d < n:
                tail[d] += rng.uniform(-1, 1) * 2.5 * np.exp(-d / SR / 0.05)
        ir[:, ch] = tail
    # stereo decorrelation width
    mid = ir.mean(axis=1, keepdims=True)
    ir = mid + (ir - mid) * width
    ir[:p0] = 0
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def convolve(x, ir):
    """Convolve a mono or stereo signal with a stereo IR -> stereo."""
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    out = np.zeros((len(x) + len(ir) - 1, 2))
    for ch in range(2):
        out[:, ch] = signal.fftconvolve(x[:, ch], ir[:, ch])
    return out


def reverb(x, ir, wet=0.3, dry=1.0):
    y = convolve(x, ir)
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    y[:len(x)] = y[:len(x)] * wet + x * dry
    y[len(x):] *= wet
    return y


def pan(x, p):
    """Equal-power pan, p in [-1, 1] -> stereo."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def to_stereo(x):
    return x if x.ndim == 2 else np.stack([x, x], axis=1)


def mix_into(buf, x, at, gain=1.0):
    """Add x (mono or stereo) into stereo buf at time `at` (s)."""
    x = to_stereo(x)
    s = samples(at)
    if s >= len(buf):
        return
    if s < 0:
        x = x[-s:]
        s = 0
    m = min(len(x), len(buf) - s)
    buf[s:s + m] += x[:m] * gain


def active_rms(x, frame=0.1):
    """RMS of the louder half of the frames: the level of a part while it
    is actually playing, so sparse and continuous layers mix by ear."""
    m = x.mean(axis=1) if x.ndim == 2 else x
    h = samples(frame)
    k = len(m) // h
    if k < 2:
        return float(np.sqrt(np.mean(m ** 2)) + 1e-12)
    fr = np.sqrt(np.mean(m[:k * h].reshape(k, h) ** 2, axis=1))
    fr = np.sort(fr)[k // 2:]
    return float(np.sqrt(np.mean(fr ** 2)) + 1e-12)


class Mix:
    """A stereo bus where every part is added at a level relative to the
    others (dB re an active RMS of -20 dBFS), not at whatever level its
    synth happened to produce."""

    def __init__(self, dur):
        self.buf = np.zeros((samples(dur), 2))

    def add(self, x, db, at=0.0, p=None):
        if p is not None:
            x = pan(x.mean(axis=1) if x.ndim == 2 else x, p)
        g = 10 ** ((db - 20) / 20) / active_rms(x)
        mix_into(self.buf, x, at, g)

    def bus(self):
        return np.zeros_like(self.buf)


# --------------------------------------------------------------- loops

def fold_loop(x, loop_len):
    """Seamless loop: everything rendered past loop_len (release tails,
    reverb) is the sound that would ring on into the next pass, so add it
    back onto the head. Exact for anything that does not start before 0."""
    L = samples(loop_len) if isinstance(loop_len, float) else loop_len
    out = x[:L].copy()
    tail = x[L:]
    while len(tail):
        m = min(len(tail), L)
        out[:m] += tail[:m]
        tail = tail[m:]
    return out


def seam_report(x):
    """How big is the jump at the loop point, relative to typical
    sample-to-sample motion (99th percentile)? Below 1 means the seam is
    no bigger than an ordinary sample step: inaudible."""
    x = to_stereo(x)
    d = np.percentile(np.abs(np.diff(x, axis=0)), 99)
    j = np.abs(x[0] - x[-1]).max()
    return float(j / (d + 1e-12))


def fade(x, head=0.0, tail=0.0):
    y = x.copy()
    if head > 0:
        h = samples(head)
        y[:h] *= (np.sin(np.linspace(0, np.pi / 2, h)) ** 2)[:, None] if y.ndim == 2 else np.sin(np.linspace(0, np.pi / 2, h)) ** 2
    if tail > 0:
        h = samples(tail)
        c = np.cos(np.linspace(0, np.pi / 2, h)) ** 2
        y[-h:] *= c[:, None] if y.ndim == 2 else c
    return y


# ----------------------------------------------------------------- io

def normalize(x, peak=0.9):
    return x / (np.max(np.abs(x)) + 1e-12) * peak


def loudness_match(x, rms_db):
    """Scale to a target RMS (dBFS) then soft-limit peaks."""
    r = np.sqrt(np.mean(x ** 2)) + 1e-12
    y = x * (10 ** (rms_db / 20) / r)
    return np.tanh(y * 1.05) / np.tanh(1.05) if np.max(np.abs(y)) > 0.98 else y


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch = w.getnchannels()
        sw = w.getsampwidth()
        raw = w.readframes(w.getnframes())
    if sw == 2:
        a = np.frombuffer(raw, np.int16).astype(np.float64) / 32768
    elif sw == 4:
        a = np.frombuffer(raw, np.float32).astype(np.float64)
    else:
        raise ValueError("unsupported width")
    return a.reshape(-1, ch)


def _pcm16(x):
    return (np.clip(x, -1, 1) * 32767).astype(np.int16)


def write_wav(path, x):
    x = np.asarray(x)
    ch = 1 if x.ndim == 1 else x.shape[1]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(_pcm16(x).tobytes())


def write_ogg(path, x, quality=4):
    """Vorbis via oggenc (vorbis-tools). The sample count is exact, so a
    whole-file loop stays seamless in Godot."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as td:
        tmp = os.path.join(td, "x.wav")
        write_wav(tmp, x)
        subprocess.run(["oggenc", "-Q", "-q", str(quality), "-o", path, tmp], check=True)
    kb = os.path.getsize(path) / 1024
    print(f"[audio] {os.path.relpath(path, ROOT)}  {len(x)/SR:.1f}s  {kb:.0f} KB")
