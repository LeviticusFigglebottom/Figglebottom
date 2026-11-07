#!/usr/bin/env python3
"""Greybox UI icons for Rimeholt: flat silhouettes drawn with PIL.
Usage: python3 tools/gen_icons.py   (writes assets/ui/icons/*.png)"""
import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "ui", "icons")
S = 128
INK = (226, 214, 186, 255)
DARK = (120, 96, 64, 255)
ICE = (176, 212, 240, 255)
EMBER = (240, 150, 70, 255)


def canvas():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


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
    im, d = canvas()
    for i, r in enumerate((44, 32, 20)):
        d.arc((64 - r, 64 - r, 64 + r, 64 + r), 200, 340, fill=INK, width=6)
    d.ellipse((56, 70, 72, 86), fill=INK)
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
    im, d = canvas()
    d.polygon([(64, 8), (112, 30), (104, 88), (64, 120), (24, 88), (16, 30)], fill=DARK)
    d.polygon([(64, 24), (80, 64), (64, 104), (48, 64)], fill=ICE)
    d.line((30, 64, 98, 64), fill=ICE, width=5)
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
