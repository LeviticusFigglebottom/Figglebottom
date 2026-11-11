#!/usr/bin/env python3
"""Build the ground-cover card atlases (grass, heather, sedge).

Source: one 2x2 sprite sheet per kind from Tripo Studio's image generator
(free on the plan; prompts in docs/art/LOOK_PASS_2.md and PROVENANCE), saved as
raw/veg/<kind>.png (gitignored, like every raw Tripo download). Each sheet is
four side-on clumps on a flat black (or white) background.

Per kind this writes assets/textures/veg/T_veg_<kind>.png: RGBA, 2x2 cells,
each clump scaled to fill its cell's width with its root at the cell's
bottom centre (the card mesh in Scatter pivots there). Alpha is keyed from
the background, the colour is un-premultiplied and then bled outward into
the transparent area so mipmaps do not pull a dark halo onto the blade
edges, and the result is graded toward the STYLE.md palette.

Usage: python3 tools/art/veg_atlas.py [--only kind]
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "raw", "veg")
OUT = os.path.join(ROOT, "assets", "textures", "veg")
CELL = 512

# kind -> key gain (how hard the background is keyed), sat (0..1 keep),
# gain (brightness), fill (how much of the cell width a clump takes)
KINDS = {
    "grass":   {"gain": 5.0, "sat": 0.85, "bright": 1.0, "fill": 0.98},
    "heather": {"gain": 7.0, "sat": 0.9, "bright": 1.15, "fill": 0.98},
    "sedge":   {"gain": 5.0, "sat": 0.8, "bright": 0.95, "fill": 0.98},
    # region species (docs/art/BIOMES.md column 2; prompts in PROVENANCE).
    # Flowers keep their colour: they are what tells one region from the next.
    # Saltfell
    "thrift":      {"gain": 7.0, "sat": 0.95, "bright": 1.1, "fill": 0.98},
    "campion":     {"gain": 7.0, "sat": 0.9, "bright": 1.05, "fill": 0.98},
    "marram":      {"gain": 6.0, "sat": 0.85, "bright": 1.0, "fill": 0.98},
    "scurvy":      {"gain": 8.0, "sat": 0.9, "bright": 1.1, "fill": 0.98},
    # the Lowe
    "cotton":      {"gain": 6.0, "sat": 0.9, "bright": 1.05, "fill": 0.98},
    "asphodel":    {"gain": 7.0, "sat": 0.95, "bright": 1.0, "fill": 0.98},
    "rush":        {"gain": 7.0, "sat": 0.9, "bright": 1.15, "fill": 0.98},
    # Kettle Fjord
    "roseroot":    {"gain": 7.0, "sat": 0.9, "bright": 1.05, "fill": 0.98},
    "frostflower": {"gain": 5.0, "sat": 0.7, "bright": 1.1, "fill": 0.98},
    # Tarnhall
    "horsetail":   {"gain": 8.0, "sat": 0.9, "bright": 1.1, "fill": 0.98},
    "dock":        {"gain": 8.0, "sat": 0.9, "bright": 1.15, "fill": 0.98},
    # Thornwold
    "bracken":     {"gain": 8.0, "sat": 0.95, "bright": 1.2, "fill": 0.98},
    "bilberry":    {"gain": 8.0, "sat": 0.95, "bright": 1.15, "fill": 0.98},
    # Shepherd's Reach
    "avens":       {"gain": 8.0, "sat": 0.9, "bright": 1.1, "fill": 0.98},
    "thistle":     {"gain": 7.0, "sat": 0.95, "bright": 1.1, "fill": 0.98},
    "matgrass":    {"gain": 5.0, "sat": 0.85, "bright": 1.0, "fill": 0.98},
    "wooltuft":    {"gain": 6.0, "sat": 0.85, "bright": 1.0, "fill": 0.98},
    # the Coldwell
    "marigold":    {"gain": 8.0, "sat": 1.0, "bright": 1.1, "fill": 0.98},
    "smock":       {"gain": 7.0, "sat": 0.95, "bright": 1.1, "fill": 0.98},
    "hoarfeather": {"gain": 5.0, "sat": 0.7, "bright": 1.1, "fill": 0.98},
}


def key(img: np.ndarray, gain: float) -> np.ndarray:
    """RGB float 0..1 on a flat background -> RGBA, un-premultiplied."""
    corner = np.median(np.concatenate([img[:8, :8].reshape(-1, 3), img[-8:, -8:].reshape(-1, 3)]), axis=0)
    white = corner.mean() > 0.5
    if white:
        # distance from white: the darkest channel carries the blade
        cover = 1.0 - img.min(axis=2)
    else:
        cover = img.max(axis=2)
    a = np.clip((cover - 0.035) * gain, 0.0, 1.0)
    a3 = np.maximum(a, 1e-3)[..., None]
    bg = 1.0 if white else 0.0
    rgb = np.clip((img - bg * (1.0 - a3)) / a3, 0.0, 1.0)
    return np.dstack([rgb, a])


def bleed(rgba: np.ndarray, rounds: int = 24) -> np.ndarray:
    """Push edge colour into the transparent area (no dark mip halos)."""
    rgb = rgba[..., :3].copy()
    known = rgba[..., 3] > 0.5
    rgb[~known] = 0.0
    w = known.astype(np.float32)
    for _ in range(rounds):
        acc = np.zeros_like(rgb)
        cnt = np.zeros_like(w)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            acc += np.roll(rgb * w[..., None], (dy, dx), axis=(0, 1))
            cnt += np.roll(w, (dy, dx), axis=(0, 1))
        grow = (w == 0) & (cnt > 0)
        rgb[grow] = acc[grow] / cnt[grow][..., None]
        w[grow] = 1.0
    # whatever is still unknown takes the mean blade colour
    mean = rgba[..., :3][known].mean(axis=0) if known.any() else np.array([0.3, 0.3, 0.2])
    rgb[w == 0] = mean
    return np.dstack([rgb, rgba[..., 3]])


def grade(rgb: np.ndarray, sat: float, bright: float) -> np.ndarray:
    luma = (rgb * np.array([0.3, 0.59, 0.11])).sum(axis=2, keepdims=True)
    return np.clip((luma + (rgb - luma) * sat) * bright, 0.0, 1.0)


def build(kind: str) -> None:
    cfg = KINDS[kind]
    src = np.asarray(Image.open(os.path.join(RAW, kind + ".png")).convert("RGB"), dtype=np.float32) / 255.0
    h, w, _ = src.shape
    rgba = key(src, cfg["gain"])
    atlas = np.zeros((CELL * 2, CELL * 2, 4), dtype=np.float32)
    for cy in range(2):
        for cx in range(2):
            cell = rgba[cy * h // 2:(cy + 1) * h // 2, cx * w // 2:(cx + 1) * w // 2]
            a = cell[..., 3]
            ys, xs = np.where(a > 0.3)
            y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            # the root: where the lowest rows of the clump sit
            low = a[y1 - max(4, (y1 - y0) // 12):y1]
            root_x = float((low.sum(axis=0) * np.arange(a.shape[1])).sum() / max(low.sum(), 1e-3))
            half = max(root_x - x0, x1 - root_x)
            scale = (CELL * 0.5 * cfg["fill"]) / half
            scale = min(scale, (CELL * 0.98) / (y1 - y0))
            crop = cell[y0:y1, x0:x1]
            im = Image.fromarray((crop * 255).astype(np.uint8), "RGBA")
            nw, nh = max(1, int(round(crop.shape[1] * scale))), max(1, int(round(crop.shape[0] * scale)))
            im = im.resize((nw, nh), Image.LANCZOS)
            px = int(round(cx * CELL + CELL * 0.5 - (root_x - x0) * scale))
            py = (cy + 1) * CELL - nh
            px = min(max(px, cx * CELL), (cx + 1) * CELL - nw)
            arr = np.asarray(im, dtype=np.float32) / 255.0
            atlas[py:py + nh, px:px + nw] = arr
    atlas[..., :3] = grade(atlas[..., :3], cfg["sat"], cfg["bright"])
    atlas = bleed(atlas)
    out = Image.fromarray((np.clip(atlas, 0, 1) * 255).astype(np.uint8), "RGBA")
    # a hair of blur on alpha only: the generator's edges are stair-stepped
    r, g, b, al = out.split()
    out = Image.merge("RGBA", (r, g, b, al.filter(ImageFilter.GaussianBlur(0.6))))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "T_veg_%s.png" % kind)
    out.save(path, optimize=True)
    lin = (np.asarray(out, dtype=np.float32)[..., :3] / 255.0) ** 2.2
    m = lin[np.asarray(out)[..., 3] > 128].mean(axis=0)
    print("%s: %s  linear mean %.3f %.3f %.3f" % (kind, os.path.relpath(path, ROOT), m[0], m[1], m[2]))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    args = ap.parse_args()
    for kind in KINDS:
        if args.only and kind != args.only:
            continue
        if not os.path.exists(os.path.join(RAW, kind + ".png")):
            print("%s: no raw sheet (raw/ is not committed), kept as it is" % kind)
            continue
        build(kind)


if __name__ == "__main__":
    main()
