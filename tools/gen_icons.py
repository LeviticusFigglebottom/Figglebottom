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


# --- the Lowe and Kettle Fjord (LOWE.md 9, KETTLE.md 8) -------------------
WOAD = (70, 104, 150, 255)


def icon_turf_spade():
    """A long ash haft, a T-grip, a narrow blade with one side wing."""
    im, d = canvas()
    d.polygon(rot([(62, 30), (66, 30), (66, 118), (62, 118)], 35), fill=DARK)
    d.polygon(rot([(54, 116), (74, 116), (74, 122), (54, 122)], 35), fill=DARK)
    d.polygon(rot([(56, 6), (72, 6), (72, 34), (56, 34)], 35), fill=INK)
    d.polygon(rot([(72, 10), (80, 10), (80, 30), (72, 30)], 35), fill=INK)
    return im


def icon_ice_auger():
    """An auger: a T-handle, a shaft, a spiral bit."""
    im, d = canvas()
    d.polygon(rot([(62, 40), (66, 40), (66, 116), (62, 116)], 40), fill=DARK)
    d.polygon(rot([(50, 112), (78, 112), (78, 120), (50, 120)], 40), fill=DARK)
    for k in range(5):
        y = 8 + k * 7
        d.polygon(rot([(56, y + 6), (72, y), (72, y + 3), (56, y + 9)], 40), fill=INK)
    d.polygon(rot([(62, 40), (66, 40), (64, 6)], 40), fill=INK)
    return im


def icon_harpoon():
    """A barbed head on a long shaft, a coil of line below it."""
    im, d = canvas()
    d.polygon(rot([(62, 28), (66, 28), (66, 124), (62, 124)], 40), fill=DARK)
    d.polygon(rot([(64, 2), (71, 20), (66, 18), (66, 30), (62, 30), (62, 18), (57, 20)], 40), fill=INK)
    d.polygon(rot([(66, 22), (74, 30), (66, 26)], 40), fill=INK)
    c = rot([(64, 48)], 40)[0]
    d.ellipse((c[0] - 12, c[1] - 9, c[0] + 12, c[1] + 9), outline=INK, width=3)
    return im


def icon_mitten():
    im, d = canvas()
    d.rounded_rectangle((36, 22, 88, 96), radius=26, fill=WOOL)
    d.rounded_rectangle((80, 50, 104, 84), radius=12, fill=(118, 118, 116, 255))   # the darned thumb
    d.line([(84, 60), (100, 72)], fill=INK, width=2)
    d.line([(84, 70), (98, 80)], fill=INK, width=2)
    d.rectangle((36, 92, 88, 110), fill=(110, 110, 108, 255))                    # the cuff
    return im


def icon_knot_cord():
    """A cord with knots along it, the last one loose and different."""
    im, d = canvas()
    pts = [(14 + i * 2.5, 64 + 22 * math.sin(i * 0.16)) for i in range(41)]
    d.line(pts, fill=DARK, width=4)
    for k in range(1, 7):
        x, y = pts[k * 5]
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=INK)
    x, y = pts[38]
    d.ellipse((x - 8, y - 8, x + 8, y + 8), outline=EMBER, width=3)
    return im


def icon_ladle():
    im, d = canvas()
    d.polygon(rot([(62, 10), (66, 10), (66, 92), (62, 92)], 30), fill=DARK)
    c = rot([(64, 100)], 30)[0]
    d.ellipse((c[0] - 18, c[1] - 14, c[0] + 18, c[1] + 14), fill=INK)
    h = rot([(64, 10)], 30)[0]
    d.arc((h[0] - 8, h[1] - 8, h[0] + 8, h[1] + 8), 180, 360, fill=DARK, width=4)
    return im


def icon_tally():
    """A hazel stick, notched down both edges; the last two cut halfway."""
    im, d = canvas()
    body = [(58, 8), (70, 8), (70, 120), (58, 120)]
    d.polygon(rot(body, 35), fill=(150, 116, 80, 255))
    for k in range(9):
        y = 16 + k * 9
        side = 58 if k % 2 else 64
        d.polygon(rot([(side, y), (side + 6, y), (side + 6, y + 3), (side, y + 3)], 35), fill=DARK)
    for y in (104, 110):
        d.polygon(rot([(64, y), (67, y), (67, y + 3), (64, y + 3)], 35), fill=EMBER)
    return im


def icon_tongs():
    im, d = canvas()
    d.line(rot([(52, 120), (60, 40), (66, 14)], 0), fill=(110, 100, 92, 255), width=6)
    d.line(rot([(76, 120), (68, 40), (62, 14)], 0), fill=(110, 100, 92, 255), width=6)
    d.ellipse((58, 36, 70, 48), fill=INK)
    return im


def icon_spindles():
    im, d = canvas()
    for dx, worn in ((-16, True), (16, False)):
        d.line([(64 + dx, 10), (64 + dx, 118)], fill=(150, 116, 80, 255) if not worn else (120, 120, 116, 255), width=5)
        d.ellipse((64 + dx - 14, 80, 64 + dx + 14, 96), fill=INK if worn else (200, 192, 176, 255))
    d.line([(48, 40), (80, 40)], fill=EMBER, width=3)    # tied together with yarn
    return im


def icon_woad_thread():
    im, d = canvas()
    d.polygon([(30, 70), (56, 52), (96, 58), (104, 84), (74, 100), (36, 94)], fill=(130, 130, 124, 255))
    d.line([(26, 80), (110, 74)], fill=WOAD, width=6)
    d.line([(64, 76), (52, 30), (40, 18)], fill=WOAD, width=4)
    return im


def icon_armour_cloak():
    im, d = canvas()
    d.polygon([(40, 14), (88, 14), (110, 112), (18, 112)], fill=(122, 92, 62, 255))
    d.ellipse((76, 22, 90, 36), fill=INK)     # the iron pin at the right shoulder
    d.line((64, 20, 64, 112), fill=DARK, width=3)
    return im


def icon_armour_icefur():
    im, d = canvas()
    d.polygon([(40, 8), (88, 8), (96, 30), (32, 30)], fill=(196, 196, 190, 255))   # the hood
    _coat(d, (170, 170, 164, 255), (226, 222, 212, 255))
    d.line((30, 108, 98, 108), fill=(226, 222, 212, 255), width=6)                 # fleece at the hem
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


# --- Tarnhall (TARNHALL.md 8)
def icon_cleaver():
    """The Host's carving cleaver: a broad square blade, a knotwork handle, a ring at the butt."""
    im, d = canvas()
    d.polygon(rot([(46, 14), (82, 14), (82, 60), (46, 66)], 30), fill=INK)
    d.polygon(rot([(60, 64), (68, 64), (68, 108), (60, 108)], 30), fill=DARK)
    for y in (74, 84, 94):
        d.polygon(rot([(60, y), (68, y + 4), (68, y + 6), (60, y + 2)], 30), fill=(150, 116, 80, 255))
    c = rot([(64, 114)], 30)[0]
    d.ellipse((c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7), outline=DARK, width=3)
    return im


def icon_host_cup():
    """A big horn standing on a turned foot, tin at the rim; nothing in it."""
    im, d = canvas()
    d.polygon([(40, 112), (88, 112), (76, 100), (52, 100)], fill=(200, 180, 140, 255))   # the birch foot
    d.polygon([(58, 100), (70, 100), (90, 30), (40, 30)], fill=(170, 140, 96, 255))       # the horn
    d.ellipse((38, 22, 92, 38), fill=(70, 62, 54, 255))                                    # dry inside
    d.arc((38, 22, 92, 38), 0, 360, fill=ICE, width=4)                                      # the tin rim
    return im


def icon_guest_tally():
    """A coiled cord knotted all round; the knots at its end bunched together."""
    im, d = canvas()
    d.ellipse((22, 22, 106, 106), outline=(196, 160, 80, 255), width=8)
    d.ellipse((36, 36, 92, 92), outline=(214, 200, 164, 255), width=6)
    for k in range(12):
        a = k * math.pi * 2 / 12
        x, y = 64 + 42 * math.cos(a), 64 + 42 * math.sin(a)
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=INK)
    for k in range(4):   # the same knot, tied again
        x, y = 100 + k * 3, 74 + k * 7
        d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=EMBER if k == 3 else INK)
    return im


def icon_stick():
    """A rowan walking stick: bark grip, a horn cap, mud on the tip."""
    im, d = canvas()
    d.polygon(rot([(61, 18), (67, 18), (67, 120), (61, 120)], 30), fill=(150, 112, 76, 255))
    d.polygon(rot([(60, 18), (68, 18), (68, 44), (60, 44)], 30), fill=DARK)
    c = rot([(64, 14)], 30)[0]
    d.ellipse((c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7), fill=(220, 196, 150, 255))
    d.polygon(rot([(61, 110), (67, 110), (66, 122), (62, 122)], 30), fill=(70, 50, 34, 255))
    return im


def icon_barrel_head():
    """A round barrel head of boards, a knot-in-a-ring brand, nails half out."""
    im, d = canvas()
    d.ellipse((16, 16, 112, 112), fill=(176, 144, 100, 255))
    for x in (46, 64, 82):
        d.line([(x, 20), (x, 108)], fill=(140, 110, 74, 255), width=2)
    d.ellipse((44, 44, 84, 84), outline=DARK, width=5)
    d.ellipse((58, 58, 70, 70), fill=DARK)
    for x, y in ((30, 50), (96, 78)):
        d.line([(x, y), (x + 6, y - 10)], fill=ICE, width=3)
    return im


# --- Thornwold (THORNWOLD.md 8)
def icon_bill():
    """A hedging bill: a long haft, a hooked blade with a back spike."""
    im, d = canvas()
    d.polygon(rot([(62, 30), (66, 30), (66, 124), (62, 124)], 35), fill=DARK)
    d.polygon(rot([(58, 6), (70, 6), (78, 14), (76, 34), (66, 36), (62, 36), (62, 26), (70, 22), (66, 14), (58, 14)], 35), fill=INK)
    d.polygon(rot([(56, 22), (62, 24), (62, 28), (52, 26)], 35), fill=INK)    # the back spike
    return im


def icon_song_cord():
    """A coiled cord knotted all along, the knots of every size; a bone toggle."""
    im, d = canvas()
    pts = [(64 + (40 - k * 0.55) * math.cos(k * 0.21), 64 + (40 - k * 0.55) * math.sin(k * 0.21)) for k in range(60)]
    d.line(pts, fill=(196, 170, 110, 255), width=4)
    for k in range(4, 58, 5):
        x, y = pts[k]
        r = 3 + (k * 7) % 5
        d.ellipse((x - r, y - r, x + r, y + r), fill=INK)
    x, y = pts[0]
    d.rounded_rectangle((x - 4, y - 12, x + 4, y + 12), radius=3, fill=HORN)
    return im


def icon_birch_ring():
    """A ring of birch bark plaited round on itself."""
    im, d = canvas()
    d.ellipse((30, 30, 98, 98), outline=(232, 226, 210, 255), width=14)
    for k in range(10):
        a = k * math.pi * 2 / 10
        x, y = 64 + 34 * math.cos(a), 64 + 34 * math.sin(a)
        d.line([(x - 5 * math.sin(a + 0.8), y + 5 * math.cos(a + 0.8)), (x + 5 * math.sin(a + 0.8), y - 5 * math.cos(a + 0.8))],
               fill=DARK, width=2)
    return im


def icon_knucklebone():
    """A sheep's knucklebone, worn smooth, a tooth-mark in it."""
    im, d = canvas()
    d.rounded_rectangle((38, 46, 90, 82), radius=16, fill=INK)
    d.ellipse((30, 40, 54, 64), fill=INK)
    d.ellipse((74, 64, 98, 88), fill=INK)
    d.arc((52, 50, 72, 64), 200, 340, fill=DARK, width=3)                     # the tooth-mark
    return im


def icon_armour_collier():
    im, d = canvas()
    _coat(d, (58, 52, 48, 255), (180, 168, 140, 255))
    d.polygon([(46, 44), (82, 44), (86, 112), (42, 112)], fill=(36, 32, 30, 255))   # the leather apron
    d.line((30, 108, 98, 108), fill=EMBER, width=3)                                  # scorched at the hem
    return im


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in list(globals().items()):
        if name.startswith("icon_"):
            fn().save(os.path.join(OUT, name[5:] + ".png"))
            print("[icons]", name[5:])
