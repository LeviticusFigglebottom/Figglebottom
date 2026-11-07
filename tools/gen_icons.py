#!/usr/bin/env python3
"""UI icons for Rimeholt: flat silhouettes drawn with PIL, in the UI palette
of docs/art/STYLE.md (bone-white and coal-ember on near-black). Drawn at 4x
and filtered down, so edges are smooth at any HUD size.
Usage: python3 tools/gen_icons.py   (writes assets/ui/icons/*.png)"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui", "icons")
S = 128
SS = 4                                   # supersampling factor
INK = (236, 228, 210, 255)               # bone
DARK = (104, 84, 70, 255)                # coal-brown: wood, iron, cord
ICE = (190, 214, 232, 255)
EMBER = (231, 120, 46, 255)              # the accent
HOT = (255, 196, 120, 255)               # the live coal's heart


class D:
    """ImageDraw in 128-px icon space, drawn at SS x."""
    def __init__(self, im):
        self.d = ImageDraw.Draw(im)

    @staticmethod
    def _p(pts):
        if pts and isinstance(pts[0], (tuple, list)):
            return [(x * SS, y * SS) for x, y in pts]
        return [v * SS for v in pts]

    def polygon(self, pts, **kw):
        self.d.polygon(self._p(pts), **kw)

    def ellipse(self, box, **kw):
        self.d.ellipse(self._p(box), **kw)

    def chord(self, box, a0, a1, width=1, **kw):
        self.d.chord(self._p(box), a0, a1, width=width * SS, **kw)

    def pieslice(self, box, a0, a1, width=1, **kw):
        self.d.pieslice(self._p(box), a0, a1, width=width * SS, **kw)

    def rectangle(self, box, **kw):
        self.d.rectangle(self._p(box), **kw)

    def rounded_rectangle(self, box, radius=0, **kw):
        self.d.rounded_rectangle(self._p(box), radius=radius * SS, **kw)

    def arc(self, box, a0, a1, width=1, **kw):
        self.d.arc(self._p(box), a0, a1, width=width * SS, **kw)

    def line(self, pts, width=1, **kw):
        self.d.line(self._p(list(pts)) if not isinstance(pts[0], (int, float)) else self._p(list(pts)),
                    width=width * SS, joint="curve", **kw)


class Icon:
    def __init__(self):
        self.im = Image.new("RGBA", (S * SS, S * SS), (0, 0, 0, 0))

    def save(self, path):
        self.im.resize((S, S), Image.LANCZOS).save(path)


def canvas():
    ic = Icon()
    return ic, D(ic.im)


def rot(points, deg, c=(64, 64)):
    a = math.radians(deg)
    out = []
    for x, y in points:
        dx, dy = x - c[0], y - c[1]
        out.append((c[0] + dx * math.cos(a) - dy * math.sin(a), c[1] + dx * math.sin(a) + dy * math.cos(a)))
    return out


def blade(d, length, width, guard, deg):
    body = [(64 - width, 104 - length), (64 + width, 104 - length), (64 + width, 96), (64 - width, 96)]
    tip = [(64 - width, 104 - length), (64, 104 - length - width * 2), (64 + width, 104 - length)]
    g = [(64 - guard, 94), (64 + guard, 94), (64 + guard, 100), (64 - guard, 100)]
    grip = [(62, 100), (66, 100), (66, 118), (62, 118)]
    d.polygon(rot(body, deg), fill=INK)
    d.polygon(rot(tip, deg), fill=INK)
    d.polygon(rot(g, deg), fill=DARK)
    d.polygon(rot(grip, deg), fill=DARK)


def icon_hewing_blade():
    im, d = canvas(); blade(d, 70, 5, 16, 35); return im


def icon_greatblade():
    im, d = canvas(); blade(d, 84, 8, 22, 35); return im


def icon_maul():
    im, d = canvas()
    d.polygon(rot([(61, 30), (67, 30), (67, 118), (61, 118)], 35), fill=DARK)
    d.polygon(rot([(44, 14), (84, 14), (84, 38), (44, 38)], 35), fill=INK)
    return im


def icon_spear():
    im, d = canvas()
    d.polygon(rot([(62, 30), (66, 30), (66, 124), (62, 124)], 40), fill=DARK)
    d.polygon(rot([(64, 2), (72, 22), (64, 34), (56, 22)], 40), fill=INK)
    return im


def icon_bow():
    im, d = canvas()
    d.arc((24, 10, 84, 118), -80, 80, fill=INK, width=7)
    d.line((60, 14, 60, 114), fill=DARK, width=2)
    return im


def icon_torch():
    im, d = canvas()
    d.polygon(rot([(60, 52), (68, 52), (66, 120), (62, 120)], 20), fill=DARK)
    d.ellipse((46, 14, 82, 58), fill=EMBER)
    d.ellipse((54, 26, 74, 52), fill=(255, 220, 140, 255))
    return im


def icon_gourd():
    im, d = canvas()
    d.ellipse((30, 50, 98, 118), fill=INK)
    d.ellipse((46, 22, 82, 62), fill=INK)
    d.rectangle((58, 10, 70, 26), fill=DARK)
    return im


def icon_warmth():
    im, d = canvas()
    d.ellipse((24, 24, 104, 104), fill=EMBER)
    d.ellipse((44, 44, 84, 84), fill=(255, 226, 160, 255))
    return im


def icon_song():
    """A hum: three breaths rising, wavering, from a low note."""
    im, d = canvas()
    for k, (y, amp, w) in enumerate(((92, 5, 7), (66, 7, 6), (40, 9, 5))):
        pts = [(24 + i * 2.0, y + amp * math.sin(i * 0.22 + k)) for i in range(41)]
        d.line(pts, fill=INK if k < 2 else EMBER, width=w)
    return im


def icon_bog_iron():
    im, d = canvas()
    d.polygon([(30, 80), (50, 40), (86, 34), (102, 70), (78, 100), (42, 102)], fill=(110, 100, 92, 255))
    d.polygon([(50, 44), (84, 38), (74, 60)], fill=(160, 150, 140, 255))
    return im


def icon_arrows():
    im, d = canvas()
    for k in (-10, 0, 10):
        d.line((30 + k, 108, 98 + k, 20), fill=DARK, width=4)
        d.polygon([(98 + k, 20), (88 + k, 26), (96 + k, 34)], fill=INK)
    return im


def icon_relic():
    im, d = canvas()
    d.rounded_rectangle((36, 36, 92, 92), radius=10, fill=INK)
    return im


def icon_crest():
    """The house crest: the Fostering Horn with its live coal (SLICE.md §8)."""
    im, d = canvas()
    # the horn: a curved, tapering cow's horn, mouth up-right
    pts_out, pts_in = [], []
    for i in range(25):
        t = i / 24.0
        a = math.radians(200 - 150 * t)
        r = 46 - 4 * t
        cx, cy = 64 + r * math.cos(a), 58 + r * math.sin(a) * 0.82
        w = 3 + 15 * t
        nx, ny = math.cos(a), math.sin(a) * 0.82
        ln = math.hypot(nx, ny)
        pts_out.append((cx + nx / ln * w, cy + ny / ln * w))
        pts_in.append((cx - nx / ln * w, cy - ny / ln * w))
    d.polygon(pts_out + pts_in[::-1], fill=INK)
    # bands of darker horn, across the curve
    for t in (0.3, 0.55):
        a = math.radians(200 - 150 * t)
        r = 46 - 4 * t
        cx, cy = 64 + r * math.cos(a), 58 + r * math.sin(a) * 0.82
        nx, ny = math.cos(a), math.sin(a) * 0.82
        ln = math.hypot(nx, ny)
        w = 3 + 15 * t
        d.line([(cx + nx / ln * w, cy + ny / ln * w), (cx - nx / ln * w, cy - ny / ln * w)], fill=DARK, width=4)
    # the soapstone stopper and the coal glowing at the draught-hole
    a = math.radians(50)
    mx, my = 64 + 42 * math.cos(a), 58 + 42 * math.sin(a) * 0.82
    d.ellipse((mx - 17, my - 26, mx + 17, my - 6), fill=EMBER)
    d.ellipse((mx - 8, my - 21, mx + 8, my - 11), fill=HOT)
    return im


def icon_rye_sack():
    im, d = canvas()
    d.rounded_rectangle((22, 50, 106, 112), radius=22, fill=INK)
    d.polygon([(44, 54), (58, 30), (70, 30), (84, 54)], fill=INK)
    d.line([(52, 44), (76, 44)], fill=DARK, width=5)
    d.polygon([(92, 98), (106, 88), (106, 112), (90, 112)], fill=(0, 0, 0, 0))   # the chewed corner
    d.ellipse((86, 92, 100, 106), fill=DARK)
    return im


def icon_net_float():
    im, d = canvas()
    d.line([(64, 6), (64, 34)], fill=DARK, width=4)
    d.ellipse((30, 30, 98, 98), fill=INK)
    d.ellipse((40, 40, 88, 88), outline=EMBER, width=4)       # the burned knot
    d.line([(48, 64), (80, 64)], fill=EMBER, width=4)
    d.line([(64, 98), (64, 122)], fill=DARK, width=4)
    return im


def icon_needle():
    im, d = canvas()
    d.polygon(rot([(56, 14), (72, 14), (74, 112), (64, 124), (54, 112)], 35), fill=INK)
    d.polygon(rot([(60, 22), (68, 22), (64, 50)], 35), fill=(0, 0, 0, 0))
    d.line(rot([(64, 60), (64, 100)], 35), fill=DARK, width=6)
    return im


def icon_mask():
    im, d = canvas()
    d.ellipse((28, 14, 100, 118), fill=INK)
    d.ellipse((42, 48, 58, 60), fill=(0, 0, 0, 0))
    d.ellipse((70, 48, 86, 60), fill=(0, 0, 0, 0))
    d.line([(40, 40), (88, 40)], fill=DARK, width=4)          # the carved brow
    d.rectangle((28, 66, 100, 74), fill=(70, 104, 150, 255))  # the woad band
    return im


# --- armour (Pack: the Armour leaf) ------------------------------------------
GHOST = (120, 104, 80, 150)
WOOL = (150, 150, 146, 255)
OIL = (70, 62, 48, 255)
HORN = (226, 214, 186, 255)


def _coat(d, fill, trim):
    # a long coat: shoulders, sleeves, skirt flaring to the knee
    d.polygon([(44, 20), (84, 20), (100, 34), (96, 112), (32, 112), (28, 34)], fill=fill)
    d.polygon([(28, 34), (12, 76), (22, 80), (38, 46)], fill=fill)
    d.polygon([(100, 34), (116, 76), (106, 80), (90, 46)], fill=fill)
    d.polygon([(54, 20), (74, 20), (64, 40)], fill=trim)
    d.line((64, 40, 64, 112), fill=trim, width=3)


def icon_armour_coat():
    im, d = canvas()
    _coat(d, WOOL, DARK)
    for i, y in enumerate((52, 66, 80)):
        d.rounded_rectangle((60, y - 2, 70, y + 2), radius=2, fill=HORN if i != 1 else EMBER)
    return im


def icon_armour_oilskins():
    im, d = canvas()
    d.polygon([(40, 10), (88, 10), (96, 30), (32, 30)], fill=OIL)   # the hood
    _coat(d, OIL, (150, 130, 92, 255))
    d.line((34, 100, 94, 100), fill=(150, 130, 92, 255), width=3)
    return im


def icon_slot_head():
    im, d = canvas()
    d.chord((30, 26, 98, 100), 180, 360, fill=GHOST)
    d.rectangle((30, 62, 98, 72), fill=GHOST)
    return im


def icon_slot_body():
    im, d = canvas()
    _coat(d, GHOST, (0, 0, 0, 0))
    return im


def icon_slot_hands():
    im, d = canvas()
    d.rounded_rectangle((38, 46, 84, 104), radius=12, fill=GHOST)
    d.rounded_rectangle((80, 56, 100, 82), radius=8, fill=GHOST)
    d.rectangle((40, 30, 82, 48), fill=GHOST)
    return im


def icon_slot_legs():
    im, d = canvas()
    d.polygon([(36, 16), (92, 16), (96, 112), (70, 112), (64, 50), (58, 112), (32, 112)], fill=GHOST)
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in list(globals().items()):
        if name.startswith("icon_"):
            fn().save(os.path.join(OUT, name[5:] + ".png"))
            print("[icons]", name[5:])
