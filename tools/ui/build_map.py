#!/usr/bin/env python3
"""Bake the Map's base images from the real land.

Reads data/areas/index.json, every area's JSON and its terrain grids
(data/terrain/*_h.bin heights, *_splat.bin painted layers, *_far.bin the
coarse horizon) and draws the highland the way a careful hand would on
parchment: height wash and hill shading, contour lines, hachured cliffs,
water with shore lines, worn paths, shingle, woods, hedges, and buildings
(houses, barrows, and the landmark models that are buildings) as small marks. Nothing is invented: every mark is where the game has it.

Writes
  assets/ui/map/base.webp      the whole highland, dark: land nobody has
                               walked yet (the fog), 1 px per metre
  assets/ui/map/<area>.webp    one parchment sheet per region, 3 px per
                               metre, torn-edged alpha, laid over the base
                               when the region is discovered
  data/map.json                where each image sits in world metres
Markers (Hearthstones, the Bearer, seams, veils, places, the pinned
objective) are not baked: src/ui/map_view.gd draws them from the save.

Usage: python3 tools/ui/build_map.py [--only AREA]
Re-run after any terrain or area generator changes the land."""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "ui", "map")
PPM = 3                                  # region sheets: pixels per metre
PAD = 12.0                               # world margin round the regions, metres

# landmark models that are buildings somebody could shelter in: the map marks
# them as it marks houses (a standing stone or a cairn is not a building)
BUILDING_LANDMARKS = {"lm_cutters_bothy", "lm_sheiling"}

PAPER_LOW = np.array([226.0, 212.0, 180.0])
PAPER_HIGH = np.array([198.0, 178.0, 142.0])
INK = np.array([62.0, 44.0, 30.0])       # sepia
WATER = np.array([52.0, 60.0, 62.0])
SHORE = np.array([150.0, 150.0, 136.0])
PATH = np.array([126.0, 86.0, 48.0])
FOG_LAND = np.array([50.0, 45.0, 39.0])
FOG_LINE = np.array([78.0, 69.0, 57.0])
FOG_SEA = np.array([21.0, 23.0, 24.0])


def res(path):
    return os.path.join(ROOT, path.replace("res://", ""))


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def noise(shape, scale, seed):
    """Smooth value noise in 0..1."""
    rng = np.random.default_rng(seed)
    h, w = shape
    small = rng.random((max(2, int(h / scale) + 2), max(2, int(w / scale) + 2)))
    big = ndimage.zoom(small, (h / (small.shape[0] - 1.0), w / (small.shape[1] - 1.0)), order=3)
    return np.clip(big[:h, :w], 0.0, 1.0)


def load_area(aid):
    d = json.load(open(os.path.join(ROOT, "data", "areas", aid + ".json")))
    t = d["terrain"]
    nx, nz = t["size"]
    h = np.fromfile(res(t["source"]), dtype="<f4").reshape(nz, nx)
    sp = np.fromfile(res(t["splat"]), dtype=np.uint8).reshape(nz, nx, 4)
    fn = t["far_size"]
    far = np.fromfile(res(t["far"]), dtype="<f4").reshape(fn, fn)
    return d, h, sp, far


def water_mask(d, h, ox, oz, cell):
    """Open water as the land has it in THAW: under a water plane's level,
    inside its footprint."""
    nz, nx = h.shape
    zz, xx = np.mgrid[0:nz, 0:nx]
    wx = ox + xx * cell
    wz = oz + zz * cell
    m = np.zeros(h.shape, bool)
    for w in d.get("water", []):
        if w.get("tag", "base") == "rime":
            continue
        cx, y, cz = w["at"]
        if "radius" in w:
            inside = np.hypot(wx - cx, wz - cz) <= w["radius"]
        else:
            sx, sz = w["size"]
            inside = (np.abs(wx - cx) <= sx / 2.0) & (np.abs(wz - cz) <= sz / 2.0)
        m |= inside & (h < y)
    return m


def draw_region(aid, seed):
    d, h, sp, _far = load_area(aid)
    t = d["terrain"]
    ox, oz = t["origin"]
    cell = t["cell"]
    nz, nx = h.shape
    wm = water_mask(d, h, ox, oz, cell)
    # work at PPM pixels a metre
    k = PPM * cell
    H = ndimage.zoom(h, k, order=3)
    hh, ww = H.shape
    W = ndimage.zoom(wm.astype(float), k, order=1)[:hh, :ww] > 0.5
    S = np.stack([ndimage.zoom(sp[..., c].astype(float) / 255.0, k, order=1)[:hh, :ww] for c in range(4)], -1)
    gz, gx = np.gradient(ndimage.gaussian_filter(H, 1.2), 1.0 / PPM)
    slope = np.hypot(gx, gz)

    land = H[~W]
    lo, hi = np.percentile(land, 2), np.percentile(land, 98)
    tone = np.clip((H - lo) / max(hi - lo, 1.0), 0, 1)[..., None]
    img = PAPER_LOW * (1 - tone) + PAPER_HIGH * tone
    # the paper itself: blotches and a fine tooth
    img *= (0.94 + 0.10 * noise(H.shape, 90, seed))[..., None]
    img *= (0.975 + 0.05 * noise(H.shape, 3, seed + 1))[..., None]
    # hill shading, light from the north-west
    shade = np.clip(0.5 + 0.5 * ((-gx * -0.7 - gz * -0.7) / np.sqrt(1.0 + slope ** 2)), 0, 1)
    img *= (0.80 + 0.26 * shade)[..., None]

    def ink(mask, colour=INK):
        nonlocal img
        m = np.clip(mask, 0, 1)[..., None]
        img = img * (1 - m) + colour * m

    # contours every 4 m, heavier every 20 m
    for step, width, alpha in ((4.0, 0.9, 0.20), (20.0, 1.3, 0.34)):
        d_m = np.abs(((H / step + 0.5) % 1.0) - 0.5) * step      # metres of height to the line
        d_px = d_m / (slope + 1e-3) * PPM
        ink(smooth(width, width * 0.4, d_px) * alpha * (slope < 1.3))
    # cliffs: hachures down the fall line, in eight directions so they stay coherent
    cliff = smooth(0.85, 1.5, slope)
    ang = np.round(np.arctan2(ndimage.gaussian_filter(gz, 4), ndimage.gaussian_filter(gx, 4)) / (math.pi / 4)) * (math.pi / 4)
    yy, xx = np.mgrid[0:hh, 0:ww]
    phase = (xx * -np.sin(ang) + yy * np.cos(ang)) * (2 * math.pi / 6.0)
    hatch = smooth(0.1, 0.6, np.sin(phase + 3.0 * noise(H.shape, 14, seed + 2)))
    ink(cliff * (0.14 + 0.42 * hatch))
    # shingle: stipple
    rng = np.random.default_rng(seed + 3)
    dots = ndimage.maximum_filter((rng.random(H.shape) < 0.035).astype(float), 2)
    ink(dots * smooth(0.4, 0.7, S[..., 0]) * 0.55)
    # worn paths
    path = ndimage.gaussian_filter(S[..., 1], 0.8)
    ink(smooth(0.58, 0.74, path) * 0.85, PATH)
    ink(smooth(0.46, 0.58, path) * smooth(0.74, 0.58, path) * 0.30)      # a darker edge to the way
    # water: a dark wash, lighter lines following the shore, an inked coast
    if W.any():
        wash = WATER * (0.92 + 0.14 * noise(H.shape, 40, seed + 4))[..., None]
        m = W[..., None].astype(float)
        img = img * (1 - m) + wash * m
        dist = ndimage.distance_transform_edt(W)
        for dpx, a in ((4, 0.55), (10, 0.34), (18, 0.2)):
            ink(smooth(1.6, 0.4, np.abs(dist - dpx)) * a * W, SHORE)
        coast = ndimage.binary_dilation(W, iterations=2) & ~ndimage.binary_erosion(W, iterations=1)
        ink(ndimage.gaussian_filter(coast.astype(float), 0.7) * 0.85)

    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    dr = ImageDraw.Draw(im, "RGBA")

    def px(x, z):
        return ((x - ox) * PPM, (z - oz) * PPM)

    def on_land(x, z, max_path=0.2):
        i, j = int((x - ox) * PPM), int((z - oz) * PPM)
        return 0 <= i < ww and 0 <= j < hh and not W[j, i] and S[j, i, 1] <= max_path and slope[j, i] < 1.2

    # woods: one small tuft per few trees, where the trees are
    forest = d.get("forest", {})
    if isinstance(forest, dict):
        clear = forest.get("clear", [])
        r2 = np.random.default_rng(int(forest.get("seed", seed)))
        for grp in forest.get("trees", []):
            x0, z0, x1, z1 = grp["region"]
            pine = grp.get("kind") == "pine"
            for _ in range(int(grp["count"] * 0.8)):
                x, z = r2.uniform(x0, x1), r2.uniform(z0, z1)
                if any(math.hypot(x - c[0], z - c[1]) < c[2] for c in clear) or not on_land(x, z):
                    continue
                cx, cy = px(x, z)
                r = 4.2 if pine else 3.6
                dr.ellipse([cx - r + 1.2, cy - r + 1.6, cx + r + 1.2, cy + r + 1.6], fill=(54, 40, 28, 90))
                dr.ellipse([cx - r, cy - r, cx + r, cy + r],
                           fill=(104, 108, 70, 235) if pine else (142, 140, 88, 235), outline=(58, 54, 34, 255))
        for hd in forest.get("hedges", []):
            if hd.get("tag", "base") == "rime":
                continue
            pts = [px(p[0], p[1]) for p in hd["pts"]]
            if len(pts) > 1:
                dr.line(pts, fill=(70, 78, 44, 255), width=4)
        for pl in forest.get("place", []):
            cx, cy = px(pl["at"][0], pl["at"][1])
            dr.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(84, 92, 58, 255), outline=(40, 34, 24, 255), width=2)
    # buildings: houses as inked blocks, barrows as mounds. A landmark that is
    # a roofed building (BUILDING_LANDMARKS) is drawn the same way, on the
    # footprint of its blocker.
    built = list(d.get("houses", []))
    for lm in d.get("landmarks", []):
        name = os.path.splitext(os.path.basename(lm.get("scene", "")))[0]
        if name in BUILDING_LANDMARKS and "blocker" in lm and lm.get("tag", "base") != "rime":
            built.append({"center": [lm["at"][0], lm["at"][2]], "size": [lm["blocker"][0], lm["blocker"][2]],
                          "yaw": lm.get("rot", 0.0)})
    for hs in built:
        cx, cz = hs["center"]
        sx, sz = hs["size"]
        yaw = math.radians(float(hs.get("yaw", 0.0)))
        c, s = math.cos(yaw), math.sin(yaw)
        corners = [px(cx + lx * c + lz * s, cz - lx * s + lz * c)
                   for lx, lz in ((-sx / 2, -sz / 2), (sx / 2, -sz / 2), (sx / 2, sz / 2), (-sx / 2, sz / 2))]
        if hs.get("kind") == "barrow":
            dr.polygon(corners, fill=(150, 132, 92, 255), outline=(52, 38, 26, 255))
            mid = [((corners[0][0] + corners[1][0]) / 2, (corners[0][1] + corners[1][1]) / 2),
                   ((corners[2][0] + corners[3][0]) / 2, (corners[2][1] + corners[3][1]) / 2)]
            dr.line(mid, fill=(52, 38, 26, 200), width=2)
        else:
            sh = [(x + 3, y + 4) for x, y in corners]
            dr.polygon(sh, fill=(40, 28, 20, 110))
            dr.polygon(corners, fill=(92, 62, 40, 255), outline=(36, 24, 16, 255))
            dr.line([((corners[0][0] + corners[1][0]) / 2, (corners[0][1] + corners[1][1]) / 2),
                     ((corners[2][0] + corners[3][0]) / 2, (corners[2][1] + corners[3][1]) / 2)],
                    fill=(36, 24, 16, 255), width=2)     # the roof ridge
    # the sheet's edge: torn, soft
    yy, xx = np.mgrid[0:hh, 0:ww]
    edge = np.minimum(np.minimum(xx, ww - 1 - xx), np.minimum(yy, hh - 1 - yy)) / PPM       # metres
    edge = edge + (noise(H.shape, 26, seed + 5) - 0.5) * 16.0 + (noise(H.shape, 6, seed + 6) - 0.5) * 4.0
    alpha = smooth(4.0, 9.0, edge)
    arr = np.asarray(im, float).copy()
    burn = smooth(16.0, 6.0, edge)[..., None]                 # the edge darkens, as old paper does
    arr[..., :3] = arr[..., :3] * (1 - 0.35 * burn)
    arr[..., 3] = alpha * 255.0
    out = Image.fromarray(arr.astype(np.uint8), "RGBA")
    out.save(os.path.join(OUT, aid + ".webp"), quality=90, method=6)
    zones = d.get("zones", [])
    zx = [z["min"][0] for z in zones] + [z["max"][0] for z in zones]
    zz_ = [z["min"][1] for z in zones] + [z["max"][1] for z in zones]
    lab = [(min(zx) + max(zx)) / 2.0, (min(zz_) + max(zz_)) / 2.0] if zones else [ox + nx * cell / 2, oz + nz * cell / 2]
    lab = [min(max(lab[0], ox + 40), ox + (nx - 1) * cell - 40), min(max(lab[1], oz + 30), oz + (nz - 1) * cell - 30)]
    return {"name": d.get("name", aid), "origin": [ox, oz], "size_m": [(nx - 1) * cell, (nz - 1) * cell],
            "ppm": PPM, "image": "res://assets/ui/map/%s.webp" % aid, "label_at": lab}


def draw_base(areas, bbox):
    """The whole highland, dim: each region's coarse horizon grid, blended by
    nearness so the seams between them do not show."""
    x0, z0, x1, z1 = bbox
    w, h = int(round(x1 - x0)), int(round(z1 - z0))
    zz, xx = np.mgrid[0:h, 0:w]
    wx, wz = x0 + xx, z0 + zz
    acc = np.zeros((h, w))
    wsum = np.zeros((h, w))
    for aid in areas:
        d, hm, _sp, far = load_area(aid)
        t = d["terrain"]
        fo, fc = t["far_origin"], t["far_cell"]
        fi = np.clip((wx - fo[0]) / fc, 0, far.shape[1] - 1)
        fj = np.clip((wz - fo[1]) / fc, 0, far.shape[0] - 1)
        hv = ndimage.map_coordinates(far, [fj, fi], order=1)
        ox, oz = t["origin"]
        nz_, nx_ = hm.shape
        cx, cz = ox + nx_ * t["cell"] / 2, oz + nz_ * t["cell"] / 2
        wgt = 1.0 / (1.0 + (np.hypot(wx - cx, wz - cz) / 120.0) ** 4)
        acc += hv * wgt
        wsum += wgt
    H = ndimage.gaussian_filter(acc / wsum, 7.0)
    gz, gx = np.gradient(H)
    slope = np.hypot(gx, gz)
    sea = H < 0.6
    shade = np.clip(0.5 + 0.5 * ((gx * 0.7 + gz * 0.7) / np.sqrt(1.0 + slope ** 2)), 0, 1)
    img = FOG_LAND * (0.72 + 0.5 * shade)[..., None] * (0.9 + 0.2 * noise(H.shape, 60, 11))[..., None]
    d_px = np.abs(((H / 25.0 + 0.5) % 1.0) - 0.5) * 25.0 / (slope + 1e-3)
    m = (smooth(1.2, 0.4, d_px) * 0.22 * (slope < 2.0))[..., None]
    img = img * (1 - m) + FOG_LINE * m
    s = sea[..., None].astype(float)
    img = img * (1 - s) + FOG_SEA * (0.9 + 0.2 * noise(H.shape, 50, 12))[..., None] * s
    dist = ndimage.distance_transform_edt(sea)
    for dpx, a in ((3, 0.5), (8, 0.25)):
        m = (smooth(1.4, 0.3, np.abs(dist - dpx)) * a * sea)[..., None]
        img = img * (1 - m) + FOG_LINE * m
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(
        os.path.join(OUT, "base.webp"), quality=88, method=6)
    return {"origin": [x0, z0], "size_m": [w, h], "ppm": 1, "image": "res://assets/ui/map/base.webp"}


def main():
    os.makedirs(OUT, exist_ok=True)
    index = json.load(open(os.path.join(ROOT, "data", "areas", "index.json")))
    areas = index["areas"]
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    meta_path = os.path.join(ROOT, "data", "map.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    regions = meta.get("regions", {})
    for i, aid in enumerate(areas):
        if only and aid != only:
            continue
        regions[aid] = draw_region(aid, 100 + i * 17)
        print("[map] %s" % aid)
    xs = [r["origin"][0] for r in regions.values()] + [r["origin"][0] + r["size_m"][0] for r in regions.values()]
    zs = [r["origin"][1] for r in regions.values()] + [r["origin"][1] + r["size_m"][1] for r in regions.values()]
    bbox = (math.floor(min(xs) - PAD), math.floor(min(zs) - PAD), math.ceil(max(xs) + PAD), math.ceil(max(zs) + PAD))
    world = meta.get("world", {})
    if not only or not world:
        world = draw_base(areas, bbox)
        print("[map] base %s" % str(bbox))
    out = {"doc": "Written by tools/ui/build_map.py. Where each baked map image sits in world metres (x east, z south). Do not edit by hand.",
           "order": areas, "graph": index.get("graph", {}), "world": world, "regions": regions}
    json.dump(out, open(meta_path, "w"), indent=1)
    open(meta_path, "a").write("\n")


if __name__ == "__main__":
    main()
