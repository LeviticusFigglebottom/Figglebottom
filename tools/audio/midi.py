"""Minimal Standard MIDI File writer (type 1), so the score needs no
third-party MIDI library. Times are in seconds at a fixed tempo map of
120 bpm / 960 ppq: one tick = 1/1920 s, plenty for expressive timing."""
import struct

PPQ = 960
TEMPO_US = 500000            # 120 bpm: a quarter = 0.5 s
TICKS_PER_S = PPQ * 1_000_000 / TEMPO_US


def _vlq(n):
    n = int(n)
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))


class Track:
    """One instrument on one channel. Events: (time_s, order, bytes)."""

    def __init__(self, channel, program, name="", bank=0):
        self.ch = channel
        self.ev = []
        self.name = name
        if channel != 9:
            if bank:
                self.cc(0.0, 0, bank)
            self.ev.append((0.0, 0, bytes([0xC0 | channel, program])))

    def cc(self, t, num, val):
        self.ev.append((t, 1, bytes([0xB0 | self.ch, num, max(0, min(127, int(val)))])))

    def bend(self, t, semis, rng=2.0):
        v = int(8192 + max(-1.0, min(1.0, semis / rng)) * 8191)
        self.ev.append((t, 1, bytes([0xE0 | self.ch, v & 0x7F, (v >> 7) & 0x7F])))

    def note(self, t, dur, pitch, vel=80):
        self.ev.append((t, 2, bytes([0x90 | self.ch, int(pitch), max(1, min(127, int(vel)))])))
        self.ev.append((t + dur, 0, bytes([0x80 | self.ch, int(pitch), 0])))

    def ramp(self, t0, t1, num, v0, v1, step=0.05):
        """A controller swell (expression, volume): bow pressure, breath."""
        n = max(int((t1 - t0) / step), 1)
        for i in range(n + 1):
            self.cc(t0 + (t1 - t0) * i / n, num, v0 + (v1 - v0) * i / n)

    def chunk(self):
        data = b""
        if self.name:
            nm = self.name.encode()
            data += _vlq(0) + b"\xff\x03" + _vlq(len(nm)) + nm
        last = 0
        for t, _o, b in sorted(self.ev, key=lambda e: (e[0], e[1])):
            tick = int(round(max(t, 0.0) * TICKS_PER_S))
            data += _vlq(tick - last) + b
            last = tick
        data += _vlq(0) + b"\xff\x2f\x00"
        return b"MTrk" + struct.pack(">I", len(data)) + data


def write(path, tracks):
    tempo = _vlq(0) + b"\xff\x51\x03" + struct.pack(">I", TEMPO_US)[1:] + _vlq(0) + b"\xff\x2f\x00"
    head = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks) + 1, PPQ)
    with open(path, "wb") as f:
        f.write(head + b"MTrk" + struct.pack(">I", len(tempo)) + tempo)
        for tr in tracks:
            f.write(tr.chunk())


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name):
    """'D4' -> 62, 'F#3' -> 54, 'Bb2' -> 46."""
    p = NOTE[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        p += 1 if name[i] == "#" else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + p
