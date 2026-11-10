#!/usr/bin/env python3
"""Pull one hue band of a GLB's base-colour texture toward a target colour.

Tripo painted the sheiling's turf roof a lime green that no grade in the
shader can reach without dragging the stone walls with it. This rewrites the
embedded base-colour JPEG in place: pixels inside the hue band (and above a
saturation floor) keep their own light and dark but take the target's hue and
saturation, feathered at the band's edges.

Usage: python3 tools/art/regrade_glb.py GLB --hue 50 115 --target 0.30 0.33 0.17 [--sat-min 0.28] [--value 0.8]
(hue in degrees; target sRGB 0..1; value scales the regraded pixels' brightness)
Idempotent enough: a second run finds almost nothing left in the band.
"""
import argparse
import colorsys
import io
import json
import struct

import numpy as np
from PIL import Image


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("--hue", nargs=2, type=float, default=[50.0, 115.0])
    ap.add_argument("--target", nargs=3, type=float, default=[0.30, 0.33, 0.17])
    ap.add_argument("--sat-min", type=float, default=0.28)
    ap.add_argument("--value", type=float, default=0.8)
    a = ap.parse_args()
    raw = open(a.glb, "rb").read()
    jlen = struct.unpack("<I", raw[12:16])[0]
    gltf = json.loads(raw[20:20 + jlen])
    bstart = 20 + jlen
    blen = struct.unpack("<I", raw[bstart:bstart + 4])[0]
    binbuf = raw[bstart + 8:bstart + 8 + blen]
    done = set()
    for mat in gltf["materials"]:
        tex = mat.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if tex is None:
            continue
        img_i = gltf["textures"][tex["index"]]["source"]
        if img_i in done:
            continue
        done.add(img_i)
        bv = gltf["bufferViews"][gltf["images"][img_i]["bufferView"]]
        off, ln = bv.get("byteOffset", 0), bv["byteLength"]
        im = np.asarray(Image.open(io.BytesIO(binbuf[off:off + ln])).convert("RGB"), dtype=np.float32) / 255.0
        mx, mn = im.max(axis=2), im.min(axis=2)
        sat = (mx - mn) / np.maximum(mx, 1e-4)
        r, g, b = im[..., 0], im[..., 1], im[..., 2]
        d = np.maximum(mx - mn, 1e-5)
        hue = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) * 60.0
        lo, hi = a.hue
        band = np.clip((hue - lo) / 10.0, 0, 1) * np.clip((hi - hue) / 10.0, 0, 1)
        mask = band * np.clip((sat - a.sat_min) / 0.12, 0, 1)
        th, ts, _ = colorsys.rgb_to_hsv(*a.target)
        # keep each pixel's own value (the blades, the shade); take hue and sat
        val = mx * a.value
        tgt = np.stack(np.vectorize(colorsys.hsv_to_rgb)(np.full_like(val, th), np.full_like(val, ts), val), axis=2)
        out = im * (1.0 - mask[..., None]) + tgt * mask[..., None]
        buf = io.BytesIO()
        Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(buf, "JPEG", quality=90)
        new = buf.getvalue()
        new += b"\x00" * ((4 - len(new) % 4) % 4)
        binbuf = binbuf[:off] + new + binbuf[off + ln + ((4 - ln % 4) % 4 if (off + ln) % 4 else 0):]
        delta = len(new) - (len(binbuf[:off]) + len(new) - off)  # 0; offsets fixed below
        shift = len(new) - ln - ((4 - ln % 4) % 4 if (off + ln) % 4 else 0)
        bv["byteLength"] = len(buf.getvalue())
        for other in gltf["bufferViews"]:
            if other is not bv and other.get("byteOffset", 0) > off:
                other["byteOffset"] += shift
        print("%s: regraded %.1f%% of %s" % (a.glb, 100.0 * float((mask > 0.5).mean()), gltf["images"][img_i].get("name")))
    gltf["buffers"][0]["byteLength"] = len(binbuf)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    binbuf += b"\x00" * ((4 - len(binbuf) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binbuf)
    with open(a.glb, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<I", len(js)) + b"JSON" + js)
        f.write(struct.pack("<I", len(binbuf)) + b"BIN\x00" + binbuf)


if __name__ == "__main__":
    main()
