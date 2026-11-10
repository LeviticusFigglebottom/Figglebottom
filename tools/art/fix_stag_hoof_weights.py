#!/usr/bin/env python3
"""Rebind the rime stag's stray fore-hoof vertices (ADR 0012 pass 3).

Tripo's auto-rig weighted a few hundred vertices of the fore hooves to the
RIGHT HIND hoof tip (1_Right_Limb_4), so any pose that trails the hind legs
dragged a spike out of a fore hoof. This rewrites those joint indices, in
place, to the nearest fore-hoof bone. Idempotent; the buffer size and every
other byte stay as they were. Run once after re-processing the model:
  python3 tools/art/fix_stag_hoof_weights.py
"""
import json
import struct
from pathlib import Path

GLB = Path(__file__).resolve().parents[2] / "assets/models/enemies/rime_stag.glb"
BAD = "tripo::1_Right_Limb_4"
FORE = ["tripo::0_Left_Limb_3", "tripo::0_Right_Limb_4"]
FMT = {5121: ("B", 1), 5123: ("H", 2), 5126: ("f", 4)}


def main():
    b = bytearray(GLB.read_bytes())
    n = struct.unpack_from("<I", b, 12)[0]
    j = json.loads(b[20:20 + n])
    bin0 = 20 + n + 8
    names = [j["nodes"][i]["name"] for i in j["skins"][0]["joints"]]
    bad = names.index(BAD)
    fore = [names.index(f) for f in FORE]

    def view(i):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        f, sz = FMT[a["componentType"]]
        nc = {"VEC3": 3, "VEC4": 4}[a["type"]]
        off = bin0 + bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        return a["count"], "<" + f * nc, off, bv.get("byteStride", sz * nc)

    fixed = 0
    for mesh in j["meshes"]:
        for pr in mesh["primitives"]:
            at = pr["attributes"]
            cnt, pf, po, ps = view(at["POSITION"])
            _, jf, jo, js = view(at["JOINTS_0"])
            _, wf, wo, ws = view(at["WEIGHTS_0"])
            pos = [struct.unpack_from(pf, b, po + k * ps) for k in range(cnt)]
            jn = [list(struct.unpack_from(jf, b, jo + k * js)) for k in range(cnt)]
            wt = [struct.unpack_from(wf, b, wo + k * ws) for k in range(cnt)]
            # where each fore hoof is: the centre of the vertices it already owns
            centre = {}
            for f in fore:
                own = [pos[k] for k in range(cnt) if any(jn[k][c] == f and wt[k][c] > 0.3 for c in range(4))]
                centre[f] = [sum(p[a] for p in own) / len(own) for a in range(3)]
            hind_z = min(c[2] for c in centre.values()) - 0.3   # anything this far forward is no hind hoof
            for k in range(cnt):
                if pos[k][2] < hind_z:
                    continue
                for c in range(4):
                    if jn[k][c] == bad and wt[k][c] > 0.0:
                        near = min(fore, key=lambda f: sum((pos[k][a] - centre[f][a]) ** 2 for a in range(3)))
                        jn[k][c] = near
                        struct.pack_into(jf, b, jo + k * js, *jn[k])
                        fixed += 1
    GLB.write_bytes(bytes(b))
    print(f"rime_stag: rebound {fixed} stray fore-hoof weights")


if __name__ == "__main__":
    main()
