#!/usr/bin/env python3
"""Cut the painted icon sheets into the game's icon set.

Reads raw/ui_icons/<sheet>.png (see tools/ui/icon_sheets.json and
tools/ui/icon_prompts.py) and writes assets/ui/icons/<name>.png at 256 px.
Every icon gets the same treatment, so sheets painted on slightly different
grounds still read as one set:
  - the sheet's own ground is measured from each tile's border and taken out;
  - the object is reframed to the same size in the frame;
  - it is set back on one shared ground: a warm-dark vignette, rounded
    corners and a soft bone rim.
A sheet that is not on disk is skipped (its icons are left as committed).
Usage: python3 tools/ui/build_icons.py [--sheet NAME] [--contact OUT.png]"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
RAW = os.path.join(ROOT, "raw", "ui_icons")
OUT = os.path.join(ROOT, "assets", "ui", "icons")
S = 256
INSET = 0.10        # of a grid cell: clears the gutters and any painted tile edge
FILL = 0.78         # the object's longest side, as a share of the frame
GROUND_MID = np.array([50.0, 43.0, 37.0])    # vignette centre (warm coal)
GROUND_EDGE = np.array([19.0, 16.0, 14.0])   # vignette corner
RIM = (236, 228, 210)                        # bone


def fit_ground(tile):
    """A smooth quadratic ground fitted to the tile's border ring, with the
    worst third of the ring dropped so an object that reaches the edge does
    not drag the fit."""
    h, w, _ = tile.shape
    yy, xx = np.mgrid[0:h, 0:w]
    x = xx / (w - 1.0) - 0.5
    y = yy / (h - 1.0) - 0.5
    ring = (np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) < 0.07 * w)
    basis = np.stack([np.ones_like(x), x, y, x * x, y * y, x * y], axis=-1)
    a = basis[ring]
    b = tile[ring]
    keep = np.ones(len(a), bool)
    for _ in range(3):
        coef, *_ = np.linalg.lstsq(a[keep], b[keep], rcond=None)
        res = np.abs(a @ coef - b).max(axis=1)
        keep = res <= np.percentile(res, 67)
    return basis @ coef


def vignette():
    yy, xx = np.mgrid[0:S, 0:S]
    r = np.hypot((xx - S * 0.46) / S, (yy - S * 0.42) / S) / 0.72
    t = np.clip(r, 0, 1)[..., None] ** 1.6
    return GROUND_MID * (1 - t) + GROUND_EDGE * t


def finish(obj, look):
    """obj: float (S,S,3) difference-from-ground. Returns the RGBA icon."""
    if look == "ghost":
        grey = obj.mean(axis=2, keepdims=True)
        obj = (grey * 0.8 + obj * 0.2) * 0.42
    rgb = np.clip(obj + vignette(), 0, 255).astype(np.uint8)
    im = Image.fromarray(rgb, "RGB").convert("RGBA")
    # rounded corners, feathered
    k = 4
    mask = Image.new("L", (S * k, S * k), 0)
    ImageDraw.Draw(mask).rounded_rectangle([k, k, S * k - k - 1, S * k - k - 1], radius=26 * k, fill=255)
    mask = mask.resize((S, S), Image.LANCZOS)
    # the soft rim: a bone line just inside the edge, brighter along the top-left
    rim = Image.new("L", (S * k, S * k), 0)
    ImageDraw.Draw(rim).rounded_rectangle([3 * k, 3 * k, S * k - 3 * k - 1, S * k - 3 * k - 1],
                                          radius=24 * k, outline=255, width=2 * k)
    rim = rim.resize((S, S), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
    yy, xx = np.mgrid[0:S, 0:S]
    lit = 0.16 + 0.26 * np.clip(1.0 - (xx + yy) / (1.3 * S), 0, 1)
    rim_a = (np.asarray(rim, float) / 255.0 * lit)[..., None]
    arr = np.asarray(im, float)
    arr[..., :3] = arr[..., :3] * (1 - rim_a) + np.array(RIM) * rim_a
    arr[..., 3] = np.asarray(mask, float)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def cut(sheet_im, cols, rows, i):
    w, h = sheet_im.size
    cw, ch = w / cols, h / rows
    cx, cy = i % cols, i // cols
    box = [int(round(cx * cw + cw * INSET)), int(round(cy * ch + ch * INSET)),
           int(round((cx + 1) * cw - cw * INSET)), int(round((cy + 1) * ch - ch * INSET))]
    tile = np.asarray(sheet_im.crop(box).convert("RGB"), float)
    diff = tile - fit_ground(tile)
    # feather the tile's own edge away: a painted tile border or the gutter
    # must not come through as a faint box when the frame is wider than the tile
    th, tw = diff.shape[:2]
    ty, tx = np.mgrid[0:th, 0:tw]
    tedge = np.minimum(np.minimum(tx, tw - 1 - tx), np.minimum(ty, th - 1 - ty))
    diff = diff * np.clip((tedge - 0.02 * tw) / (0.07 * tw), 0, 1)[..., None]
    # where the object is: anything that differs from the ground
    m = Image.fromarray(((np.abs(diff).max(axis=2) > 16) * 255).astype(np.uint8), "L")
    m = m.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5))
    bb = m.getbbox() or (0, 0, tile.shape[1], tile.shape[0])
    side = max(bb[2] - bb[0], bb[3] - bb[1]) / FILL
    side = max(side, 0.55 * tile.shape[1])        # a very small object is not blown up
    mx, my = (bb[0] + bb[2]) / 2.0, (bb[1] + bb[3]) / 2.0
    x0, y0 = mx - side / 2.0, my - side / 2.0
    # resample the difference image (zero outside the tile = plain ground)
    chans = []
    for c in range(3):
        ch_im = Image.fromarray(diff[..., c].astype(np.float32), "F")
        chans.append(np.asarray(ch_im.transform((S, S), Image.AFFINE,
                     (side / S, 0, x0, 0, side / S, y0), resample=Image.BICUBIC, fillcolor=0.0)))
    obj = np.stack(chans, axis=-1)
    # fade the last few pixels so a cropped edge never shows as a line
    yy, xx = np.mgrid[0:S, 0:S]
    edge = np.minimum(np.minimum(xx, S - 1 - xx), np.minimum(yy, S - 1 - yy))
    return obj * np.clip(edge / 10.0, 0, 1)[..., None]


def main():
    man = json.load(open(os.path.join(HERE, "icon_sheets.json")))
    only = sys.argv[sys.argv.index("--sheet") + 1] if "--sheet" in sys.argv else None
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for name, sh in man["sheets"].items():
        if only and name != only:
            continue
        path = os.path.join(RAW, name + ".png")
        if not os.path.exists(path):
            print("skip %s (no %s)" % (name, os.path.relpath(path, ROOT)))
            continue
        im = Image.open(path)
        cols, rows = sh["grid"]
        for i, t in enumerate(sh["tiles"]):
            if t[0].startswith("_"):
                continue
            look = t[2] if len(t) > 2 else ("ghost" if t[0].startswith("slot_") else "")
            finish(cut(im, cols, rows, i), look).save(os.path.join(OUT, t[0] + ".png"), optimize=True)
            n += 1
    print("wrote %d icons" % n)
    if "--contact" in sys.argv:
        contact(sys.argv[sys.argv.index("--contact") + 1])


def contact(out, cell=112, cols=12):
    names = sorted(f for f in os.listdir(OUT) if f.endswith(".png"))
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell + 8, rows * cell + 8), (8, 7, 6))
    for i, f in enumerate(names):
        ic = Image.open(os.path.join(OUT, f)).convert("RGBA").resize((cell - 8, cell - 8), Image.LANCZOS)
        sheet.paste(ic, (8 + (i % cols) * cell, 8 + (i // cols) * cell), ic)
    sheet.save(out)
    print("contact sheet: %s (%d icons)" % (out, len(names)))


if __name__ == "__main__":
    main()
