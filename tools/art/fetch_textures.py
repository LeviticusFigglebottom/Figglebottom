#!/usr/bin/env python3
"""Fetch and process the CC0 PBR texture sets every tiling surface uses.

Reproducible: the MANIFEST below lists every set (source, asset id,
resolution, grade). Raw downloads go to raw/textures/ (gitignored); the
processed, graded maps go to assets/textures/<set>/ and are committed.

Per set we write three JPEGs (Godot imports them VRAM-compressed with mipmaps):
  T_<set>_albedo.jpg  graded base colour (sRGB)
  T_<set>_normal.jpg  OpenGL (+Y) tangent normal
  T_<set>_orh.jpg     R = ambient occlusion, G = roughness, B = height
and append the set's linear mean colour to assets/textures/sets.json:
MaterialLib divides by it so each family's authored albedo stays the
authority for the mean colour while the photo supplies the detail.

Grading pulls each photo toward the muted STYLE.md palette so it sits with
the Tripo albedos: desaturate, compress contrast around the mean, and nudge
the hue toward a target (grey-green schist, silvered timber, oat wool...).

Sources (both CC0, no attribution required; recorded in assets/PROVENANCE.md):
  Poly Haven  https://api.polyhaven.com/files/<id>
  ambientCG   https://ambientcg.com/get?file=<id>_<res>-JPG.zip

Usage: python3 tools/art/fetch_textures.py [--only set] [--skip-download]
"""
import argparse
import io
import json
import os
import sys
import urllib.request
import zipfile

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "raw", "textures")
OUT = os.path.join(ROOT, "assets", "textures")

# set -> source, id, res (k), grade: sat (0..1 keep), contrast, hue target
# (sRGB 0..1) and how far to pull toward it, rough_bias (added), notes.
MANIFEST = {
    # timber: silvered, split and adzed. One grain set for staves, posts,
    # beams and driftwood (families tint it); a plank set for decks.
    "timber":    {"src": "polyhaven", "id": "rough_wood", "res": 2, "sat": 0.55, "contrast": 0.95,
                  "hue": [0.46, 0.42, 0.37], "pull": 0.45},
    "planks":    {"src": "polyhaven", "id": "weathered_planks", "res": 2, "sat": 0.6, "contrast": 0.9,
                  "hue": [0.42, 0.37, 0.31], "pull": 0.35},
    # ground
    "turf":      {"src": "polyhaven", "id": "forrest_ground_01", "res": 2, "sat": 0.75, "contrast": 0.9,
                  "hue": [0.30, 0.33, 0.20], "pull": 0.3},
    "heather":   {"src": "polyhaven", "id": "brown_mud_leaves_01", "res": 2, "sat": 0.6, "contrast": 0.9,
                  "hue": [0.33, 0.27, 0.21], "pull": 0.35},
    "shingle":   {"src": "polyhaven", "id": "ganges_river_pebbles", "res": 2, "sat": 0.45, "contrast": 0.95,
                  "hue": [0.45, 0.44, 0.41], "pull": 0.4},
    "path":      {"src": "polyhaven", "id": "rocky_trail", "res": 2, "sat": 0.55, "contrast": 0.9,
                  "hue": [0.36, 0.30, 0.24], "pull": 0.4},
    "peat":      {"src": "polyhaven", "id": "brown_mud_02", "res": 1, "sat": 0.6, "contrast": 0.95,
                  "hue": [0.22, 0.18, 0.14], "pull": 0.4},
    # rock: layered dark schist for cliffs (strata), lichened field rock for
    # boulders and scatter, a cracked face for footing stones
    "schist":    {"src": "polyhaven", "id": "dark_rock_02", "res": 2, "sat": 0.5, "contrast": 0.9,
                  "hue": [0.38, 0.40, 0.37], "pull": 0.55},
    "rock":      {"src": "polyhaven", "id": "lichen_rock", "res": 2, "sat": 0.5, "contrast": 0.9,
                  "hue": [0.40, 0.41, 0.37], "pull": 0.5},
    "fieldstone": {"src": "polyhaven", "id": "rock_face_04", "res": 1, "sat": 0.45, "contrast": 0.9,
                  "hue": [0.42, 0.41, 0.37], "pull": 0.55},
    "drystone":  {"src": "polyhaven", "id": "stacked_stone_wall", "res": 2, "sat": 0.4, "contrast": 0.95,
                  "hue": [0.40, 0.41, 0.37], "pull": 0.6},
    # cold
    "snow":      {"src": "ambientcg", "id": "Snow006", "res": 2, "sat": 0.3, "contrast": 1.0,
                  "hue": [0.86, 0.89, 0.94], "pull": 0.6},
    "snow_packed": {"src": "polyhaven", "id": "snow_01", "res": 1, "sat": 0.3, "contrast": 1.0,
                  "hue": [0.80, 0.84, 0.90], "pull": 0.6},
    "ice":       {"src": "ambientcg", "id": "Ice003", "res": 1, "sat": 0.5, "contrast": 0.85,
                  "hue": [0.66, 0.78, 0.86], "pull": 0.6},
    # craft
    "wool":      {"src": "ambientcg", "id": "Fabric031", "res": 1, "sat": 0.4, "contrast": 1.0,
                  "hue": [0.55, 0.52, 0.46], "pull": 0.6},
    "felt":      {"src": "ambientcg", "id": "Fabric034", "res": 1, "sat": 0.4, "contrast": 1.0,
                  "hue": [0.52, 0.50, 0.45], "pull": 0.6},
    "rope":      {"src": "ambientcg", "id": "Rope001", "res": 1, "sat": 0.5, "contrast": 1.0,
                  "hue": [0.50, 0.44, 0.34], "pull": 0.4},
    "iron":      {"src": "polyhaven", "id": "rust_coarse_01", "res": 1, "sat": 0.45, "contrast": 1.0,
                  "hue": [0.24, 0.20, 0.17], "pull": 0.5},
    "leather":   {"src": "polyhaven", "id": "fabric_leather_01", "res": 1, "sat": 0.6, "contrast": 1.0,
                  "hue": [0.32, 0.23, 0.16], "pull": 0.4},
    # look pass 5: frozen thorn (tools/art/procedural/thorn_rime.py bakes it
    # into the thorn atlas with the snow set)
    "bark":      {"src": "polyhaven", "id": "bark_brown_02", "res": 1, "sat": 0.5, "contrast": 0.95,
                  "hue": [0.30, 0.25, 0.21], "pull": 0.45},
    # biomes (docs/art/BIOMES.md): two to four sets of its own per region, 1K.
    # Prefix = region (sf Saltfell, lw Lowe, kf Kettle, th Tarnhall, tw Thornwold,
    # sr Shepherd's Reach, cw Coldwell). Bound per layer in data/biomes/<area>.json.
    "sf_shingle": {"src": "polyhaven", "id": "large_pebbles", "res": 1, "sat": 0.5, "contrast": 0.92,
                  "hue": [0.55, 0.53, 0.47], "pull": 0.35},
    "sf_wrack": {"src": "polyhaven", "id": "coast_sand_rocks_02", "res": 1, "sat": 0.6, "contrast": 0.92,
                  "hue": [0.36, 0.29, 0.22], "pull": 0.35},
    "sf_turf": {"src": "polyhaven", "id": "aerial_grass_rock", "res": 1, "sat": 0.7, "contrast": 0.92,
                  "hue": [0.44, 0.48, 0.31], "pull": 0.35},
    "lw_peat": {"src": "polyhaven", "id": "brown_mud_03", "res": 1, "sat": 0.6, "contrast": 0.92,
                  "hue": [0.17, 0.13, 0.11], "pull": 0.35},
    "kf_shore": {"src": "polyhaven", "id": "damp_sand", "res": 1, "sat": 0.4, "contrast": 0.92,
                  "hue": [0.42, 0.44, 0.44], "pull": 0.35},
    "kf_granite": {"src": "polyhaven", "id": "cliff_side", "res": 1, "sat": 0.4, "contrast": 0.92,
                  "hue": [0.64, 0.62, 0.59], "pull": 0.35},
    "th_mud": {"src": "polyhaven", "id": "muddy_tracks", "res": 1, "sat": 0.6, "contrast": 0.92,
                  "hue": [0.35, 0.29, 0.23], "pull": 0.35},
    "th_slate": {"src": "polyhaven", "id": "slate_driveway", "res": 1, "sat": 0.45, "contrast": 0.92,
                  "hue": [0.34, 0.38, 0.42], "pull": 0.35},
    "th_grass": {"src": "polyhaven", "id": "grass_path_2", "res": 1, "sat": 0.7, "contrast": 0.92,
                  "hue": [0.49, 0.52, 0.28], "pull": 0.35},
    "th_rock": {"src": "polyhaven", "id": "rock_face_03", "res": 1, "sat": 0.45, "contrast": 0.92,
                  "hue": [0.34, 0.38, 0.42], "pull": 0.35},
    "tw_needles": {"src": "polyhaven", "id": "forest_ground_04", "res": 1, "sat": 0.75, "contrast": 0.92,
                  "hue": [0.54, 0.35, 0.21], "pull": 0.35},
    "tw_leaves": {"src": "polyhaven", "id": "forest_leaves_02", "res": 1, "sat": 0.75, "contrast": 0.92,
                  "hue": [0.48, 0.38, 0.22], "pull": 0.35},
    "tw_mud": {"src": "polyhaven", "id": "mud_forest", "res": 1, "sat": 0.6, "contrast": 0.92,
                  "hue": [0.29, 0.23, 0.16], "pull": 0.35},
    "tw_rock": {"src": "polyhaven", "id": "mossy_rock", "res": 1, "sat": 0.6, "contrast": 0.92,
                  "hue": [0.33, 0.41, 0.23], "pull": 0.35},
    "sr_turf": {"src": "polyhaven", "id": "sparse_grass", "res": 1, "sat": 0.8, "contrast": 0.92,
                  "hue": [0.49, 0.6, 0.29], "pull": 0.35},
    "sr_scree": {"src": "polyhaven", "id": "rocky_gravel", "res": 1, "sat": 0.4, "contrast": 0.92,
                  "hue": [0.6, 0.6, 0.56], "pull": 0.35},
    "sr_rock": {"src": "polyhaven", "id": "marble_rock_01", "res": 1, "sat": 0.3, "contrast": 0.92,
                  "hue": [0.79, 0.78, 0.72], "pull": 0.35},
    "cw_gravel": {"src": "polyhaven", "id": "gravelly_sand", "res": 1, "sat": 0.4, "contrast": 0.92,
                  "hue": [0.56, 0.56, 0.57], "pull": 0.35},
    "cw_cobble": {"src": "polyhaven", "id": "river_small_rocks", "res": 1, "sat": 0.45, "contrast": 0.92,
                  "hue": [0.56, 0.56, 0.57], "pull": 0.35},
    "cw_moss": {"src": "polyhaven", "id": "rock_pitted_mossy", "res": 1, "sat": 0.75, "contrast": 0.92,
                  "hue": [0.44, 0.63, 0.27], "pull": 0.35},
    "cw_moraine": {"src": "polyhaven", "id": "dry_riverbed_rock", "res": 1, "sat": 0.4, "contrast": 0.92,
                  "hue": [0.48, 0.49, 0.52], "pull": 0.35},
}


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "rimeholt-art-pipeline/1.0"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def download(name: str, m: dict) -> dict:
    """Return {albedo, normal, rough, ao, height} -> raw file paths."""
    d = os.path.join(RAW, name)
    os.makedirs(d, exist_ok=True)
    res = "%dk" % m["res"]
    out = {}
    if m["src"] == "polyhaven":
        files = json.loads(_get("https://api.polyhaven.com/files/" + m["id"]))
        keys = {"albedo": "Diffuse", "normal": "nor_gl", "rough": "Rough", "ao": "AO", "height": "Displacement"}
        for k, pk in keys.items():
            if pk not in files or res not in files[pk]:
                continue
            fmt = files[pk][res]
            url = (fmt.get("jpg") or fmt.get("png"))["url"]
            p = os.path.join(d, k + os.path.splitext(url)[1])
            if not os.path.exists(p):
                print("  get", url)
                with open(p, "wb") as f:
                    f.write(_get(url))
            out[k] = p
    else:
        z = os.path.join(d, "src.zip")
        if not os.path.exists(z):
            url = "https://ambientcg.com/get?file=%s_%s-JPG.zip" % (m["id"], res.upper())
            print("  get", url)
            with open(z, "wb") as f:
                f.write(_get(url))
        suffix = {"albedo": "_Color", "normal": "_NormalGL", "rough": "_Roughness",
                  "ao": "_AmbientOcclusion", "height": "_Displacement"}
        with zipfile.ZipFile(z) as zf:
            for n in zf.namelist():
                for k, s in suffix.items():
                    if n.endswith(s + ".jpg") or n.endswith(s + ".png"):
                        p = os.path.join(d, k + os.path.splitext(n)[1])
                        if not os.path.exists(p):
                            with open(p, "wb") as f:
                                f.write(zf.read(n))
                        out[k] = p
    return out


def _load(p, mode, size):
    im = Image.open(p)
    if im.mode in ("I;16", "I;16B", "I"):
        a = np.asarray(im).astype(np.float32)
        a = a / max(1.0, a.max())
        im = Image.fromarray((a * 255).astype(np.uint8))
    im = im.convert(mode)
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def grade(alb: np.ndarray, m: dict) -> np.ndarray:
    luma = alb @ np.array([0.299, 0.587, 0.114], np.float32)
    c = luma[..., None] + (alb - luma[..., None]) * m["sat"]
    mean = c.reshape(-1, 3).mean(0)
    c = mean + (c - mean) * m["contrast"]
    # pull the mean hue toward the palette target, keeping local variation
    tgt = np.array(m["hue"], np.float32)
    gain = 1.0 + (tgt / np.maximum(mean, 1e-3) - 1.0) * m["pull"]
    c = c * gain
    return np.clip(c, 0.0, 1.0)


def process(name: str, m: dict, raw: dict, sets: dict) -> None:
    size = 1024 * m["res"]
    od = os.path.join(OUT, name)
    os.makedirs(od, exist_ok=True)
    alb = grade(_load(raw["albedo"], "RGB", size), m)
    Image.fromarray((alb * 255 + 0.5).astype(np.uint8)).save(
        os.path.join(od, "T_%s_albedo.jpg" % name), quality=90, optimize=True)
    nrm = _load(raw["normal"], "RGB", size)
    Image.fromarray((nrm * 255 + 0.5).astype(np.uint8)).save(
        os.path.join(od, "T_%s_normal.jpg" % name), quality=92, optimize=True)
    ao = _load(raw["ao"], "L", size) if "ao" in raw else np.ones((size, size), np.float32)
    rough = _load(raw["rough"], "L", size) if "rough" in raw else np.full((size, size), 0.8, np.float32)
    if "height" in raw:
        h = _load(raw["height"], "L", size)
        lo, hi = np.percentile(h, 1), np.percentile(h, 99)
        h = np.clip((h - lo) / max(hi - lo, 1e-3), 0, 1)
    else:
        h = np.full((size, size), 0.5, np.float32)
    orh = np.stack([ao, rough, h], -1)
    Image.fromarray((orh * 255 + 0.5).astype(np.uint8)).save(
        os.path.join(od, "T_%s_orh.jpg" % name), quality=90, optimize=True)
    lin = srgb_to_lin(alb).reshape(-1, 3).mean(0)
    sets[name] = {"id": m["id"], "src": m["src"], "res": m["res"],
                  "mean_lin": [round(float(v), 4) for v in lin],
                  "rough_mean": round(float(rough.mean()), 3)}
    print("  %s: mean_lin %s rough %.2f" % (name, sets[name]["mean_lin"], rough.mean()))


IMPORT_TMPL = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://%(rel)s"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=%(nm)d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_imports(name: str) -> None:
    """VRAM-compressed with mipmaps (Godot's default for a plain JPG is
    lossless without mipmaps, which shimmers at distance). Godot adds the uid
    and dest_files on the next --import; existing files are left alone."""
    od = os.path.join(OUT, name)
    for f in sorted(os.listdir(od)):
        if not f.endswith(".jpg"):
            continue
        ip = os.path.join(od, f + ".import")
        if os.path.exists(ip):
            continue
        rel = os.path.relpath(os.path.join(od, f), ROOT).replace(os.sep, "/")
        with open(ip, "w") as fh:
            fh.write(IMPORT_TMPL % {"rel": rel, "nm": 1 if f.endswith("_normal.jpg") else 0})


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--skip-download", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    sj = os.path.join(OUT, "sets.json")
    sets = json.load(open(sj)) if os.path.exists(sj) else {}
    for name, m in MANIFEST.items():
        if a.only and name != a.only:
            continue
        print(name, "<-", m["src"], m["id"], "%dk" % m["res"])
        raw = download(name, m)
        if "albedo" not in raw or "normal" not in raw:
            print("  !! missing maps", raw)
            return 1
        process(name, m, raw, sets)
        write_imports(name)
    with open(sj, "w") as f:
        json.dump(dict(sorted(sets.items())), f, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
