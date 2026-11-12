#!/usr/bin/env python3
"""Build every sound effect and ambience bed from CC0 recordings.

    python3 tools/audio/build_sfx.py            # fetch, build, measure, write data + docs
    python3 tools/audio/build_sfx.py --only foot/  # rebuild keys with this prefix
    python3 tools/audio/build_sfx.py --no-fetch # fail instead of downloading

Everything is driven by tools/audio/sfx_manifest.json:

  sources  where each recording comes from (page, author, licence, files).
           Only CC0 sources are accepted; the build refuses anything else.
           Downloads are cached in raw/sfx/<id>/ (gitignored).
  sounds   one-shots: layers of source takes, trimmed, mixed, loudness
           normalised per family, written to assets/audio/sfx/<key>_<n>.wav
           (.ogg when longer than 2.5 s).
  beds     looping ambience layers and the state-wave sounds, written to
           assets/audio/ambience/.

A layer is "source_id:glob [tokens]". The glob is matched against the
source's files by basename and sorted; variant i of a sound takes match i.
Tokens: g<dB> gain, p<x> resample pitch, lp<Hz> hp<Hz> filters, @<s> delay,
s<s> start in the source (sv<s> more per variant), l<s> length, i<n> fixed take, o<n> take offset,
st<n> take stride, rev reverse, fi<s> fo<s> fades, raw (do not trim).

Outputs besides audio: the "sfx" block of data/audio.json (key -> variants
and mix), the measured tables in docs/audio/SFX.md, the spectrogram contact
sheets in docs/audio/, and the import loop flags for the beds.

Needs: python3 + numpy, scipy, matplotlib, py7zr; ffmpeg; vorbis-tools.
"""
import fnmatch
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.parse
import zipfile

import numpy as np
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MANIFEST = os.path.join(HERE, "sfx_manifest.json")
CACHE = os.environ.get("SFX_CACHE", os.path.join(ROOT, "raw", "sfx"))
OUT_SFX = os.path.join(ROOT, "assets", "audio", "sfx")
OUT_AMB = os.path.join(ROOT, "assets", "audio", "ambience")
DOCS = os.path.join(ROOT, "docs", "audio")
SR = 44100
AUDIO_EXT = ("wav", "ogg", "flac", "mp3")
UA = "Mozilla/5.0 (sfx build)"
CC0 = ("CC0",)

# ------------------------------------------------------------------ fetch


def _curl(url, out=None, referer=None):
    cmd = ["curl", "-sS", "-L", "--fail", "-m", "600", "-A", UA]
    if referer:
        cmd += ["-e", referer]
    if out:
        cmd += ["-o", out]
    cmd.append(url)
    r = subprocess.run(cmd, capture_output=True)
    if r.returncode != 0:
        raise RuntimeError(f"fetch failed: {url}: {r.stderr.decode()[:200]}")
    return r.stdout


def _extract(archive, dest):
    """Audio (and readme) files only, flattened, never outside dest."""
    os.makedirs(dest, exist_ok=True)

    def keep(name):
        b = os.path.basename(name)
        return b and not b.startswith(".") and b.lower().rsplit(".", 1)[-1] in AUDIO_EXT + ("txt",)

    if archive.endswith(".zip"):
        z = zipfile.ZipFile(archive)
        for i in z.infolist():
            if not i.is_dir() and keep(i.filename):
                with open(os.path.join(dest, os.path.basename(i.filename)), "wb") as f:
                    f.write(z.read(i))
    else:
        import py7zr
        tmp = dest + "_tmp"
        with py7zr.SevenZipFile(archive) as z:
            z.extractall(tmp)
        for r, _, fs in os.walk(tmp):
            for b in fs:
                if keep(b):
                    shutil.move(os.path.join(r, b), os.path.join(dest, b))
        shutil.rmtree(tmp)


def fetch(sid, src, allow=True):
    d = os.path.join(CACHE, sid)
    if os.path.exists(os.path.join(d, ".done")):
        return d
    if not allow:
        raise RuntimeError(f"source {sid} is not in the cache ({d})")
    if src["licence"] not in CC0:
        raise RuntimeError(f"source {sid} is {src['licence']}, not CC0")
    os.makedirs(d, exist_ok=True)
    urls = list(src.get("files", []))
    if src.get("kenney"):
        # Kenney serves a signed link per request: /download-link/<hex of "assets/<slug>">
        ident = ("assets/" + src["kenney"]).encode().hex()
        urls = [json.loads(_curl("https://kenney.nl/download-link/" + ident, referer=src["page"]))["url"] + "#" + src["kenney"] + ".zip"]
    for url in urls:
        name = urllib.parse.unquote(url.split("#")[-1].split("/")[-1])
        path = os.path.join(d, name)
        print(f"[fetch] {sid}: {name}")
        _curl(url.split("#")[0], path)
        if name.endswith((".zip", ".7z")):
            _extract(path, os.path.join(d, "x"))
            os.remove(path)
    open(os.path.join(d, ".done"), "w").write("ok\n")
    return d


_listing = {}


def source_files(sid):
    if sid not in _listing:
        out = []
        for r, _, fs in os.walk(os.path.join(CACHE, sid)):
            out += [os.path.join(r, f) for f in fs if f.lower().rsplit(".", 1)[-1] in AUDIO_EXT]
        _listing[sid] = sorted(out, key=lambda p: _natural(os.path.basename(p)))
    return _listing[sid]


def _natural(s):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]


# -------------------------------------------------------------------- dsp

_dec = {}


def decode(path):
    if path not in _dec:
        raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1",
                              "-ar", str(SR), "-"], check=True, capture_output=True).stdout
        x = np.frombuffer(raw, np.float32).astype(np.float64)
        if len(_dec) > 400:
            _dec.clear()
        _dec[path] = x
    return _dec[path]


def lp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, min(fc, SR * 0.45), "low", fs=SR, output="sos"), x)


def hp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, "high", fs=SR, output="sos"), x)


def resample(x, factor):
    """Pitch up by `factor` (and shorten), like playing the tape faster."""
    if abs(factor - 1.0) < 1e-4 or len(x) < 8:
        return x
    n = max(int(len(x) / factor), 8)
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def fade(x, head=0.0, tail=0.0):
    x = x.copy()
    h, t = min(int(head * SR), len(x) // 2), min(int(tail * SR), len(x) // 2)
    if h > 1:
        x[:h] *= np.sin(np.linspace(0, np.pi / 2, h)) ** 2
    if t > 1:
        x[-t:] *= np.cos(np.linspace(0, np.pi / 2, t)) ** 2
    return x


def trim(x, head_db=-36.0, tail_db=-52.0, pre=0.004):
    """Cut to the sound: from just before it first rises to head_db under
    its peak, to where it last falls under tail_db."""
    if len(x) < 64:
        return x
    w = 64
    n = len(x) // w
    e = np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1) + 1e-20)
    ed = 20 * np.log10(e / e.max())
    a = int(np.argmax(ed > head_db)) * w
    b = (n - int(np.argmax(ed[::-1] > tail_db))) * w
    a = max(a - int(pre * SR), 0)
    return x[a:max(b, a + 256)]


_KW = None


def _kweight(x):
    """ITU-R BS.1770 K-weighting at 44.1 kHz."""
    global _KW
    if _KW is None:
        def biquad(f0, g_db, q, kind):
            k = np.tan(np.pi * f0 / SR)
            if kind == "shelf":
                vh = 10 ** (g_db / 20)
                vb = vh ** 0.4996667741545416
                a0 = 1 + k / q + k * k
                b = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
                a = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
            else:
                a0 = 1 + k / q + k * k
                b = [1 / a0, -2 / a0, 1 / a0]
                a = [1, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
            return b, a
        _KW = (biquad(1681.974450955533, 3.999843853973347, 0.7071752369554196, "shelf"),
               biquad(38.13547087602444, 0.0, 0.5003270373238773, "hp"))
    for b, a in _KW:
        x = signal.lfilter(b, a, x)
    return x


def lufs(x):
    """Integrated loudness (BS.1770 gating). x is mono or (n, 2). A sound
    shorter than one 400 ms block is measured whole, as one block."""
    ch = [x] if x.ndim == 1 else [x[:, 0], x[:, 1]]
    k = [_kweight(c) for c in ch]
    n = len(k[0])
    blk, hop = int(0.4 * SR), int(0.1 * SR)
    if n < blk:
        ms = sum(float((c ** 2).mean()) for c in k)
        return -0.691 + 10 * np.log10(ms + 1e-20)
    z = []
    for s in range(0, n - blk + 1, hop):
        z.append(sum(float((c[s:s + blk] ** 2).mean()) for c in k))
    z = np.array(z)
    l = -0.691 + 10 * np.log10(z + 1e-20)
    keep = z[l > -70]
    if len(keep) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(keep.mean()) - 10
    keep = keep[(-0.691 + 10 * np.log10(keep + 1e-20)) > rel]
    return -0.691 + 10 * np.log10(keep.mean() + 1e-20) if len(keep) else -70.0


def to_lufs(x, target, ceiling_db=-1.0):
    """Gain to the target loudness; if that would clip, soft-limit the
    peaks rather than giving the loudness up."""
    g = 10 ** ((target - lufs(x)) / 20)
    y = x * g
    ceil = 10 ** (ceiling_db / 20)
    pk = np.abs(y).max()
    if pk > ceil:
        # tanh knee above 60% of the ceiling: transients round off, body stays
        knee = 0.6 * ceil
        over = np.abs(y) > knee
        y2 = y.copy()
        y2[over] = np.sign(y[over]) * (knee + (ceil - knee) * np.tanh((np.abs(y[over]) - knee) / (ceil - knee)))
        y = y2
    return y - y.mean()   # the knee is not symmetric on a one-sided thump


def room_ir(rt60, seed=7, damp_hz=4200.0):
    """A small decaying-noise impulse response (early taps + a tail whose
    highs die first) for placing a dry recording at a distance."""
    rng = np.random.default_rng(seed)
    n = int(rt60 * 1.3 * SR)
    t = np.arange(n) / SR
    tail = rng.standard_normal(n) * 10 ** (-3 * t / rt60)
    dark = lp(tail, damp_hz)
    mixk = np.clip(t / (rt60 * 0.5), 0, 1)
    ir = tail * (1 - mixk) + dark * mixk * 1.6
    ir[:int(0.008 * SR)] = 0
    for _ in range(8):
        ir[int(rng.uniform(0.006, 0.05) * SR)] += rng.uniform(0.3, 0.8) * rng.choice([-1, 1])
    return ir / np.sqrt((ir ** 2).sum())


def reverb(x, rt60, wet, seed=7):
    ir = room_ir(rt60, seed)
    y = signal.fftconvolve(np.concatenate([x, np.zeros(len(ir))]), ir)[:len(x) + len(ir)]
    out = y * wet
    out[:len(x)] += x
    return out


# ---------------------------------------------------------------- layers

TOKEN = re.compile(r"^(sv|st|lp|hp|fi|fo|max|g|p|@|s|l|i|o)(-?\d+(?:\.\d+)?)$")


def parse_layer(spec):
    parts = spec.split()
    sid, pat = parts[0].split(":", 1)
    opt = {"g": 0.0, "p": 1.0, "@": 0.0, "o": 0, "st": 1}
    for tok in parts[1:]:
        if tok in ("rev", "raw"):
            opt[tok] = True
            continue
        m = TOKEN.match(tok)
        if not m:
            raise ValueError(f"bad token {tok!r} in {spec!r}")
        opt[m.group(1)] = float(m.group(2))
    return sid, pat, opt


def matches(sid, pat):
    pat = pat.replace("+", " ")   # '+' stands for a space in a file name
    got = [p for p in source_files(sid) if fnmatch.fnmatch(os.path.basename(p), pat)]
    if not got:
        raise RuntimeError(f"no file in source {sid} matches {pat!r}")
    return got


def render_layer(spec, variant, used):
    sid, pat, o = parse_layer(spec)
    files = matches(sid, pat)
    idx = int(o["i"]) if "i" in o else (int(o["o"]) + variant * int(o["st"]))
    path = files[idx % len(files)]
    used.add((sid, os.path.basename(path)))
    x = decode(path)
    if "s" in o or "l" in o:
        a = int((o.get("s", 0.0) + o.get("sv", 0.0) * variant) * SR)
        b = a + int(o["l"] * SR) if "l" in o else len(x)
        x = x[a:b]
    x = hp(x, 25.0)   # DC and rumble out before anything is measured
    if not o.get("raw"):
        x = trim(x)
    if "max" in o and len(x) > o["max"] * SR:
        x = fade(x[:int(o["max"] * SR)], 0, min(0.08, o["max"] * 0.4))
    if o.get("rev"):
        x = x[::-1]
    x = resample(x, o["p"])
    if "hp" in o:
        x = hp(x, o["hp"])
    if "lp" in o:
        x = lp(x, o["lp"])
    # every layer enters the mix at the same loudness, so g is a mix level
    x = x * 10 ** ((-24.0 - lufs(x)) / 20) * 10 ** (o["g"] / 20)
    x = fade(x, o.get("fi", 0.002), o.get("fo", 0.012))
    return x, int(o["@"] * SR)


def render_sound(key, s, variant, used):
    layers = [render_layer(sp, variant, used) for sp in s["layers"]]
    n = max(len(x) + at for x, at in layers)
    buf = np.zeros(n)
    for x, at in layers:
        buf[at:at + len(x)] += x
    if "room" in s:
        buf = reverb(buf, float(s["room"][0]), float(s["room"][1]), seed=11 + variant)
    if "lp" in s:
        buf = lp(buf, float(s["lp"]))
    if "max" in s and len(buf) > s["max"] * SR:
        buf = buf[:int(s["max"] * SR)]
    buf = trim(buf, -60.0, -56.0, 0.002) if not s.get("raw") else buf
    buf = fade(buf, float(s.get("fi", 0.0015)), float(s.get("fo", min(0.03, len(buf) / SR * 0.3))))
    buf = buf - buf.mean()
    return to_lufs(buf, float(s["lufs"]))


# ------------------------------------------------------------------ beds


def _loop_xfade(x, n, xf):
    """An n-sample loop from at least n+xf samples: the overhang is
    crossfaded (equal power) onto the head, so the end runs into the start."""
    x = x[:n + xf].copy()
    t = np.linspace(0, np.pi / 2, xf)
    head = x[:xf] * np.sin(t) + x[n:n + xf] * np.cos(t)
    out = x[:n].copy()
    out[:xf] = head
    return out


def _take(path, start, need):
    x = decode(path)
    if len(x) < need:   # tile a short recording with crossfades
        xf = min(int(0.4 * SR), len(x) // 4)
        reps = [x]
        while sum(len(r) for r in reps) - xf * (len(reps) - 1) < need + SR:
            reps.append(x)
        out = reps[0].copy()
        t = np.linspace(0, np.pi / 2, xf)
        for r in reps[1:]:
            out[-xf:] = out[-xf:] * np.cos(t) + r[:xf] * np.sin(t)
            out = np.concatenate([out, r[xf:]])
        x = out
    a = int(start * SR) % max(len(x) - need, 1)
    return x[a:a + need]


def render_bed(name, b, used):
    n = int(float(b["len"]) * SR)
    once = bool(b.get("once", False))
    rng = np.random.default_rng(int(b.get("seed", 1)))
    out = np.zeros((n, 2))
    xf = int(float(b.get("xfade", 3.0)) * SR)
    for L in b["layers"]:
        sid, pat = L["src"].split(":", 1)
        files = matches(sid, pat)
        g = 10 ** (float(L.get("g", 0.0)) / 20)

        def shape(x):
            x = hp(x, float(L.get("hp", 30.0)))
            if "lp" in L:
                x = lp(x, float(L["lp"]), int(L.get("lp_order", 2)))
            return x

        if L.get("mode", "loop") == "loop":
            path = files[int(L.get("i", 0)) % len(files)]
            used.add((sid, os.path.basename(path)))
            p = float(L.get("p", 1.0))
            need = int((n + xf) * p) + 8
            starts = [float(L.get("s", 0.0)), float(L.get("s", 0.0)) + float(L.get("spread", 7.3))]
            chans = []
            for st in starts:   # two different stretches of the recording: a wide, decorrelated bed
                x = shape(resample(_take(path, st, need), p))[:n + xf]
                x = x * 10 ** ((-30.0 - lufs(x)) / 20)
                if "swell" in L:   # slow gusting: a smooth random gain curve that closes on itself
                    depth, period = L["swell"]
                    k = max(int(round(float(b["len"]) / float(period))), 1)
                    ph = rng.uniform(0, 2 * np.pi, 3)
                    tt = np.arange(n + xf) / n * 2 * np.pi
                    c = sum(np.sin(tt * (k * (h + 1)) + ph[h]) / (h + 1) for h in range(3)) / 1.6
                    x = x * 10 ** ((c * float(depth)) / 20)
                chans.append(x if once else _loop_xfade(x, n, xf))
            width = float(L.get("width", 0.7))
            mid, side = (chans[0] + chans[1]) * 0.5, (chans[0] - chans[1]) * 0.5
            lay = np.stack([mid + side * width, mid - side * width], 1)[:n] * g
            if once:
                env = np.ones(n)
                a, r = int(float(L.get("fi", 0.5)) * SR), int(float(L.get("fo", 1.0)) * SR)
                at, ln = int(float(L.get("at", 0.0)) * SR), int(float(L.get("dur", b["len"])) * SR)
                env[:at] = 0
                env[at:at + a] = np.sin(np.linspace(0, np.pi / 2, a)[:max(min(a, n - at), 0)]) ** 2
                e = min(at + ln, n)
                env[e:] = 0
                env[max(e - r, 0):e] *= np.cos(np.linspace(0, np.pi / 2, e - max(e - r, 0))) ** 2
                lay *= env[:, None]
            out += lay
        else:
            # scatter: single events dropped across the loop, each at its
            # own distance (level + low-pass), wrapped round the loop point
            count = int(L["count"])
            slots = (np.arange(count) + rng.uniform(0.15, 0.85, count)) / count * n
            if once:
                slots = np.sort(rng.uniform(float(L.get("from", 0.0)), float(L.get("to", b["len"])), count)) * SR
            for j, at in enumerate(slots):
                path = files[int(rng.integers(len(files)))] if not L.get("in_order") else files[j % len(files)]
                used.add((sid, os.path.basename(path)))
                x = trim(hp(decode(path), 30.0))
                if "max" in L:
                    x = fade(x[:int(float(L["max"]) * SR)], 0.0, 0.15)
                pr = L.get("p", [1.0, 1.0])
                x = resample(x, rng.uniform(pr[0], pr[1]) if isinstance(pr, list) else float(pr))
                far = rng.uniform(0.0, 1.0)
                x = shape(x)
                x = lp(x, float(L.get("near_lp", 9000.0)) * (1 - far) + float(L.get("far_lp", 2500.0)) * far)
                x = x * 10 ** ((-30.0 - lufs(x)) / 20) * g * 10 ** (-far * float(L.get("far_db", 8.0)) / 20)
                if float(L.get("room", 0.0)) > 0:
                    x = reverb(x, 1.6, float(L["room"]) * (0.4 + far), seed=31 + j)
                x = fade(x, 0.01, min(0.3, len(x) / SR * 0.3))
                pan = rng.uniform(0.15, 0.85)
                st = np.stack([x * np.cos(pan * np.pi / 2), x * np.sin(pan * np.pi / 2)], 1)
                idx = (int(at) + np.arange(len(x))) % n if not once else None
                if once:
                    e = min(int(at) + len(x), n)
                    out[int(at):e] += st[:e - int(at)]
                else:
                    np.add.at(out, idx, st)
    out -= out.mean(0)
    if once:
        e = int(float(b.get("fo", 1.5)) * SR)
        out[-e:] *= (np.cos(np.linspace(0, np.pi / 2, e)) ** 2)[:, None]
        a = int(float(b.get("fi", 0.3)) * SR)
        out[:a] *= (np.sin(np.linspace(0, np.pi / 2, a)) ** 2)[:, None]
    # to the target loudness; a few stray peaks (a near gull, a crack) are
    # rounded off rather than letting them hold the whole bed down
    for _ in range(3):
        out *= 10 ** ((float(b["lufs"]) - lufs(out)) / 20)
        over = np.abs(out) > 0.5
        out[over] = np.sign(out[over]) * (0.5 + 0.39 * np.tanh((np.abs(out[over]) - 0.5) / 0.39))
    return out


# -------------------------------------------------------------------- io


def write_wav(path, x):
    from scipy.io import wavfile
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rng = np.random.default_rng(len(x))   # TPDF dither, repeatable
    d = (rng.random(x.shape) - rng.random(x.shape)) / 32768.0
    wavfile.write(path, SR, np.clip(np.round((x + d) * 32767), -32768, 32767).astype(np.int16))


def write_ogg(path, x, quality=4):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x)
    subprocess.run(["oggenc", "-Q", "-q", str(quality), "-o", path, tmp], check=True)
    os.remove(tmp)


def measure(x):
    m = x if x.ndim == 1 else x.mean(1)
    w = 64
    n = len(m) // w
    e = np.sqrt((m[:n * w].reshape(n, w) ** 2).mean(1) + 1e-20)
    onset = float(np.argmax(e > e.max() * 10 ** (-20 / 20))) * w / SR
    step = np.abs(np.diff(m))
    return {
        "dur": len(m) / SR,
        "lufs": float(lufs(x)),
        "peak": float(20 * np.log10(np.abs(x).max() + 1e-12)),
        "dc": float(abs(m.mean())),
        # a click is a first/last sample well above silence, or one step far outside the rest
        "edge": float(max(abs(m[0]), abs(m[-1]))),
        "jump": float(step.max() / (np.percentile(step, 99.9) + 1e-9)),
        "onset": onset,
    }


# ------------------------------------------------------------------ main


def main():
    args = sys.argv[1:]
    only = args[args.index("--only") + 1] if "--only" in args else ""
    man = json.load(open(MANIFEST))
    sources = man["sources"]
    need = set()
    for s in man["sounds"].values():
        need |= {sp.split(":", 1)[0] for sp in s["layers"]}
    for b in man["beds"].values():
        need |= {L["src"].split(":", 1)[0] for L in b["layers"]}
    for sid in sorted(need):
        if sid not in sources:
            raise RuntimeError(f"layer names unknown source {sid}")
        fetch(sid, sources[sid], "--no-fetch" not in args)

    report = {"sounds": {}, "beds": {}}
    prev = os.path.join(DOCS, "sfx_report.json")
    if only and os.path.exists(prev):
        report = json.load(open(prev))

    for key, s in man["sounds"].items():
        if only and not key.startswith(only):
            continue
        n = int(s.get("n", 1))
        rows, used = [], set()
        for old in glob.glob(os.path.join(OUT_SFX, key + "_[0-9]*.*")):
            if not old.endswith(".import"):
                os.remove(old)
        ext = "wav"
        outs = []
        for v in range(n):
            x = render_sound(key, s, v, used)
            outs.append(x)
            if len(x) > 2.5 * SR:
                ext = "ogg"
        for v, x in enumerate(outs):
            path = os.path.join(OUT_SFX, f"{key}_{v + 1}.{ext}")
            (write_ogg if ext == "ogg" else write_wav)(path, x)
            rows.append(measure(x))
        report["sounds"][key] = {"family": s["family"], "n": n, "ext": ext, "target": s["lufs"],
                                 "rows": rows, "used": sorted(used), "what": s.get("what", "")}
        print(f"[sfx] {key} x{n} {ext}  {np.mean([r['lufs'] for r in rows]):.1f} LUFS  "
              f"{np.mean([r['dur'] for r in rows]):.2f} s")

    for name, b in man["beds"].items():
        if only and not ("bed/" + name).startswith(only):
            continue
        used = set()
        x = render_bed(name, b, used)
        path = os.path.join(OUT_AMB, name + ".ogg")
        os.makedirs(OUT_AMB, exist_ok=True)
        write_ogg(path, x, int(b.get("q", 3)))
        m = measure(x)
        m["seam"] = float(np.abs(x[0] - x[-1]).max() / (np.percentile(np.abs(np.diff(x[:, 0])), 99) + 1e-9))
        report["beds"][name] = {"target": b["lufs"], "row": m, "used": sorted(used), "loop": not b.get("once", False),
                                "what": b.get("what", "")}
        print(f"[bed] {name}  {m['lufs']:.1f} LUFS  {m['dur']:.1f} s  seam {m['seam']:.2f}")

    json.dump(report, open(prev, "w"), indent=1, sort_keys=True)
    write_data(man, report)
    write_docs(man, report)
    total = sum(os.path.getsize(p) for p in glob.glob(os.path.join(OUT_SFX, "**", "*.*"), recursive=True)
                if not p.endswith(".import"))
    total += sum(os.path.getsize(os.path.join(OUT_AMB, n + ".ogg")) for n in report["beds"])
    print(f"[sfx] total {total / 1e6:.1f} MB (budget 40)")
    if total > 40e6:
        raise SystemExit("over the 40 MB budget")


def write_data(man, report):
    """The 'sfx' block of data/audio.json: every key, its variants and mix."""
    path = os.path.join(ROOT, "data", "audio.json")
    data = json.load(open(path))
    sounds = {}
    for key, s in man["sounds"].items():
        r = report["sounds"].get(key)
        if r is None:
            continue
        e = {"n": r["n"], "ext": r["ext"]}
        e.update(s.get("mix", {}))
        sounds[key] = e
    data["sfx"] = {
        "_doc": "GENERATED by tools/audio/build_sfx.py from tools/audio/sfx_manifest.json: do not edit here. key -> n variants, file type and mix (db, pitch +-, vol +- dB, dist preset, bus).",
        "path": "res://assets/audio/sfx/%s_%d.%s",
        "sounds": sounds,
    }
    with open(path, "w") as f:
        json.dump(data, f, indent="\t", ensure_ascii=False)
        f.write("\n")


def write_docs(man, report):
    src = man["sources"]
    users = {}
    for key, r in report["sounds"].items():
        for sid, _ in r["used"]:
            users.setdefault(sid, set()).add(key.split("/")[0] + "/*")
    for name, r in report["beds"].items():
        for sid, _ in r["used"]:
            users.setdefault(sid, set()).add("ambience/" + name)
    lines = ["<!-- GENERATED by tools/audio/build_sfx.py: do not edit; edit tools/audio/sfx_manifest.json -->",
             "", "## Sources", "",
             "Every source is CC0 (public-domain dedication). The page is where the licence was read.", "",
             "| Source id | Page | Author | Licence | Used by |", "|---|---|---|---|---|"]
    for sid in sorted(users):
        s = src[sid]
        lines.append(f"| `{sid}` | {s['page']} | {s['author']} | {s['licence']} | {', '.join(sorted(users[sid]))} |")
    lines += ["", "## Sounds", "",
              "Loudness is BS.1770 integrated (a sound shorter than 400 ms is measured as one block). "
              "`edge` is the largest first or last sample (a click if it is not near zero), `dc` the mean.", "",
              "| Key | Family | n | Target LUFS | Measured LUFS (min to max) | Peak dBFS | Length s | Max edge | Max dc | Recordings |",
              "|---|---|---|---|---|---|---|---|---|---|"]
    for key in sorted(report["sounds"]):
        r = report["sounds"][key]
        rows = r["rows"]
        files = ", ".join(sorted({f"`{sid}`:{f}" for sid, f in r["used"]}))
        lines.append(f"| `{key}` | {r['family']} | {r['n']} | {r['target']} | "
                     f"{min(x['lufs'] for x in rows):.1f} to {max(x['lufs'] for x in rows):.1f} | "
                     f"{max(x['peak'] for x in rows):.1f} | {np.mean([x['dur'] for x in rows]):.2f} | "
                     f"{max(x['edge'] for x in rows):.4f} | {max(x['dc'] for x in rows):.5f} | {files} |")
    lines += ["", "## Ambience beds and the state wave", "",
              "| File | Loops | Target LUFS | Measured | Peak dBFS | Length s | Loop seam | Recordings |",
              "|---|---|---|---|---|---|---|---|"]
    for name in sorted(report["beds"]):
        r = report["beds"][name]
        m = r["row"]
        files = ", ".join(sorted({f"`{sid}`:{f}" for sid, f in r["used"]}))
        lines.append(f"| `ambience/{name}.ogg` | {'yes' if r['loop'] else 'no'} | {r['target']} | {m['lufs']:.1f} | "
                     f"{m['peak']:.1f} | {m['dur']:.1f} | {m['seam']:.2f} | {files} |")
    doc = os.path.join(DOCS, "SFX.md")
    mark = "<!-- GENERATED BELOW"
    head = open(doc).read() if os.path.exists(doc) else ""
    cut = head.find(mark)
    if cut >= 0:
        head = head[:head.index("\n", cut) + 1]
    open(doc, "w").write(head + "\n".join(lines[1:]) + "\n")


if __name__ == "__main__":
    main()
