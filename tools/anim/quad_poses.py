#!/usr/bin/env python3
"""Strike poses for the quadrupeds (QuadRig, ADR 0006/0012), written into
data/anim/clip_meta.json models.<id>.poses / pose_seq.

The art pass's first poses were timid. This derives a three-beat strike from
each animal's ORIGINAL wind-up and extension poses (kept under "_src" so the
script is re-runnable): a deep crouch-load (haunches under, chest and head
low, nose-down pitch), a full extension (forelegs reaching, hind legs
trailing, nose-up pitch, lifted off the ground), and a braced landing
(forelegs planted ahead, chest dropped, rear still high). pose_seq chains
extension -> landing on a timer so every bite, bound and gore lands.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# id -> (load pose, extension pose, root bone, {gain per beat})
SPEC = {
    "hearthhound": {"load": "crouch", "ext": "lunge", "root": "tripo__Root",
                    "fore": ["tripo__0_Left_Limb_1", "tripo__0_Right_Limb_1"],
                    "head": ["tripo__Head_1", "tripo__Head_2"]},
    "sledge_dog": {"load": "crouch", "ext": "lunge", "root": "tripo__Root",
                   "fore": ["tripo__0_Left_Limb_0", "tripo__0_Right_Limb_0"],
                   "head": ["tripo__Head_1", "tripo__Head_2"], "pitch": 0.0, "load_gain": 1.2, "ext_gain": 1.15, "root_gain": 1.0,
                   "lift": 1.5},   # its long spine chain already carries the pitch
    "rime_stag": {"load": "lower", "ext": "leap", "root": "tripo__Root",
                  "fore": ["tripo__0_Left_Limb_0", "tripo__0_Right_Limb_0"],
                  "head": ["tripo__Head_0", "tripo__Head_1"], "load_gain": 1.5, "drop": 0.07,
                  "head_load": 1.5, "lift": 1.2},   # a stag loads by dropping its tines
}


def scaled(p, k, root_k=None):
    out = {}
    for b, v in p.items():
        g = (root_k if root_k is not None else k) if b == "_root" else k
        out[b] = [round(x * g, 3) for x in v]
    return out


def main():
    path = ROOT / "data/anim/clip_meta.json"
    meta = json.loads(path.read_text())
    for mid, sp in SPEC.items():
        m = meta["models"].get(mid)
        if not m:
            continue
        poses = m["poses"]
        src = m.setdefault("_src_poses", {k: poses[k] for k in (sp["load"], sp["ext"])})
        load0, ext0 = src[sp["load"]], src[sp["ext"]]
        load = scaled(load0, sp.get("load_gain", 1.9), sp.get("root_gain", 2.2))
        for b in sp["head"]:                   # the head stays up and on the prey
            if b in load0:
                load[b] = [round(x * sp.get("head_load", 0.5), 2) for x in load0[b]]
        load["_root"][1] -= sp.get("drop", 0.0)
        load[sp["root"]] = [-5 * sp.get("pitch", 1.0), 0, 0]          # nose down over the forelegs: coiled
        ext = scaled(ext0, sp.get("ext_gain", 1.35), sp.get("lift", 2.5))
        ext[sp["root"]] = [9 * sp.get("pitch", 1.0), 0, 0]            # nose up: flung flat through the air
        land = {"_root": [0, round(load["_root"][1] * 0.7, 3), 0], sp["root"]: [-12 * sp.get("pitch", 1.0), 0, 0]}
        for b in sp["fore"]:                   # forelegs braced out ahead
            land[b] = [round(ext0.get(b, [40, 0, 0])[0] * 0.55, 2), 0, 0]
        for b, v in load0.items():             # haunches folding back under
            if b not in land and b != "_root" and b not in sp["head"]:
                land[b] = [round(x * 0.8, 2) for x in v]
        for i, b in enumerate(sp["head"]):
            land[b] = [-6 if i == 0 else 0, 0, 0]
        poses[sp["load"]] = load
        poses[sp["ext"]] = ext
        poses["land"] = land
        m["pose_seq"] = {"_doc": "pose -> [next pose, seconds held before it, blend]: an extension always lands",
                         sp["ext"]: ["land", 0.24, 0.07]}
        print(mid, "->", sp["load"], sp["ext"], "land")
    path.write_text(json.dumps(meta, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
