#!/usr/bin/env python3
"""Make Smudge (docs/lore/POI.md 7.2) from the Reach's rigged ewe: the same
mesh, rig and walk clip, with her face repainted. The flock's faces are dark;
Smudge's is pale, with a dark smear down her nose.

The embedded base-colour image is edited in UV space: every texel of a
triangle skinned to the head bones that is dark (the face, not the fleece on
the poll) is lifted to fleece cream, except a band down the middle of the
nose, which is left as it was.

Usage: python3 tools/art/smudge_ewe.py assets/models/kit/kit_sr_ewe.glb assets/models/kit/kit_sr_smudge.glb
"""
import io
import json
import struct
import sys

import numpy as np
from PIL import Image

CT = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def main(src, dst):
    raw = open(src, "rb").read()
    jlen = struct.unpack("<I", raw[12:16])[0]
    g = json.loads(raw[20:20 + jlen])
    bstart = 20 + jlen
    blen = struct.unpack("<I", raw[bstart:bstart + 4])[0]
    binbuf = raw[bstart + 8:bstart + 8 + blen]

    def acc(i):
        a = g["accessors"][i]
        bv = g["bufferViews"][a["bufferView"]]
        n = NC[a["type"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        dt = np.dtype("<" + CT[a["componentType"]])
        stride = bv.get("byteStride", dt.itemsize * n)
        out = np.empty((a["count"], n), dtype=dt)
        for k in range(n):
            out[:, k] = np.frombuffer(binbuf, dt, a["count"] * stride // dt.itemsize, off)[k::stride // dt.itemsize][:a["count"]] if stride != dt.itemsize * n \
                else np.frombuffer(binbuf, dt, a["count"] * n, off).reshape(-1, n)[:, k]
        return out

    pr = g["meshes"][0]["primitives"][0]
    pos = acc(pr["attributes"]["POSITION"]).astype(np.float32)
    uv = acc(pr["attributes"]["TEXCOORD_0"]).astype(np.float32)
    jn = acc(pr["attributes"]["JOINTS_0"]).astype(np.int32)
    wt = acc(pr["attributes"]["WEIGHTS_0"]).astype(np.float32)
    if wt.max() > 1.5:
        wt /= 255.0 if wt.max() <= 255 else 65535.0
    idx = acc(pr["indices"]).astype(np.int64).reshape(-1, 3)
    joints = [g["nodes"][j]["name"] for j in g["skins"][0]["joints"]]
    head = np.array(["Head" in n for n in joints])
    hw = (wt * head[jn]).sum(axis=1)

    img_i = g["textures"][g["materials"][pr["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]["source"]
    bv = g["bufferViews"][g["images"][img_i]["bufferView"]]
    off, ln = bv.get("byteOffset", 0), bv["byteLength"]
    im = np.asarray(Image.open(io.BytesIO(binbuf[off:off + ln])).convert("RGB"), dtype=np.float32) / 255.0
    H, W = im.shape[:2]
    # the fleece's own colour, taken from the body
    body = im[(im.mean(axis=2) > 0.45)]
    cream = body.mean(axis=0) if len(body) else np.array([0.74, 0.68, 0.56], np.float32)
    front = pos[:, 2].max() if abs(pos[hw > 0.5][:, 2].max()) > abs(pos[hw > 0.5][:, 2].min()) else pos[:, 2].min()
    sign = 1.0 if front > 0 else -1.0
    mask = np.zeros((H, W), np.float32)      # 1 = lift to cream
    n = 0
    for tri in idx[(hw[idx] > 0.5).all(axis=1)]:
        p, t = pos[tri], uv[tri] * np.array([W, H], np.float32)
        x0, x1 = int(np.floor(t[:, 0].min())), int(np.ceil(t[:, 0].max()))
        y0, y1 = int(np.floor(t[:, 1].min())), int(np.ceil(t[:, 1].max()))
        if x1 - x0 > W // 3 or y1 - y0 > H // 3:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (t[1, 1] - t[2, 1]) * (t[0, 0] - t[2, 0]) + (t[2, 0] - t[1, 0]) * (t[0, 1] - t[2, 1])
        if abs(d) < 1e-9:
            continue
        a = ((t[1, 1] - t[2, 1]) * (xs - t[2, 0]) + (t[2, 0] - t[1, 0]) * (ys - t[2, 1])) / d
        b = ((t[2, 1] - t[0, 1]) * (xs - t[2, 0]) + (t[0, 0] - t[2, 0]) * (ys - t[2, 1])) / d
        c = 1 - a - b
        inside = (a >= -0.02) & (b >= -0.02) & (c >= -0.02)
        px = a * p[0, 0] + b * p[1, 0] + c * p[2, 0]
        pz = (a * p[0, 2] + b * p[1, 2] + c * p[2, 2]) * sign
        # the smear: a thumb's width down the middle of the nose, the front half of the face
        smear = (np.abs(px) < 0.03) & (pz > pos[hw > 0.5][:, 2].__abs__().max() - 0.2)
        m = inside & ~smear
        yy, xx = (ys[m] - 0.5).astype(int) % H, (xs[m] - 0.5).astype(int) % W
        mask[yy, xx] = 1.0
        n += 1
    luma = im.mean(axis=2)
    dark = np.clip((0.42 - luma) / 0.12, 0, 1) * mask
    detail = im / np.maximum(luma[..., None], 0.05)
    lifted = np.clip(cream * (0.82 + 0.5 * (luma[..., None] - 0.2)) * (0.6 + 0.4 * detail / np.maximum(detail.mean(), 1e-3)), 0, 1)
    out = im * (1 - dark[..., None]) + lifted * dark[..., None]
    buf = io.BytesIO()
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(buf, "JPEG", quality=90)
    new = buf.getvalue()
    pad_old = (4 - ln % 4) % 4
    new_p = new + b"\x00" * ((4 - len(new) % 4) % 4)
    binbuf = binbuf[:off] + new_p + binbuf[off + ln + pad_old:]
    shift = len(new_p) - (ln + pad_old)
    bv["byteLength"] = len(new)
    for other in g["bufferViews"]:
        if other is not bv and other.get("byteOffset", 0) > off:
            other["byteOffset"] += shift
    g["buffers"][0]["byteLength"] = len(binbuf)
    js = json.dumps(g, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    binbuf += b"\x00" * ((4 - len(binbuf) % 4) % 4)
    with open(dst, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, 12 + 8 + len(js) + 8 + len(binbuf)))
        f.write(struct.pack("<I", len(js)) + b"JSON" + js)
        f.write(struct.pack("<I", len(binbuf)) + b"BIN\x00" + binbuf)
    print("smudge: %d head triangles, %.2f%% of the image lifted -> %s" % (n, 100.0 * float((dark > 0.5).mean()), dst))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
