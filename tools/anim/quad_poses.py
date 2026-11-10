#!/usr/bin/env python3
"""Keyed strike poses for the quadrupeds (QuadRig, ADR 0006/0012 pass 3),
written into data/anim/clip_meta.json models.<id>.poses and .strikes.

Each animal's strike is six keyed beats, not scaled walk frames:
  load     chest dropped between folded forelegs, rump HIGH and coiled, eyes
           up on the prey (a crouch that reads as a spring, not a sit)
  launch   hind legs driving straight, forelegs snatched up, nose up
  extend   flat in the air: forelegs reaching, hind legs trailing
  bite     the head driven through (a hound), or thrown up and over (a stag)
  land     forelegs braced out ahead, chest sunk onto them, rump still high
  recover  gathered low over all four, before it stands
Poses are skeleton-space Euler offsets in degrees per bone (+X swings a leg
forward and lifts a nose) plus "_root": a lift in skeleton units. A pose is
written per JOINT (J below maps joints to each Tripo rig's bones, which
differ animal to animal and even side to side).

strikes.<clip> is what CharVisual.play_timed hands QuadRig.strike: the load
pose is struck at once and held for the telegraph; the launch leaves `lead`
seconds before the attack's DATA windup, then each beat follows
[pose, seconds after the one before, blend]. No windup is stored here.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
T = "tripo__"


def lr(fmt):
    return [T + fmt.format("Left"), T + fmt.format("Right")]


# joint -> bones. f1/f2/f3: foreleg upper, fore, pastern. h1/h2/h3: thigh,
# shin, hock. front: the spine bone that tips the forehand. body: the root.
J = {
    "hearthhound": {
        "body": [T + "Root"], "front": [T + "Spine_0"], "neck": [T + "Head_1"], "head": [T + "Head_2"],
        "jaw": [T + "Head_3"], "tail": ["bone_25"],
        "f1": lr("0_{}_Limb_1"), "f2": lr("0_{}_Limb_2"), "f3": lr("0_{}_Limb_3"),
        "h1": lr("1_{}_Limb_0") + ["bone_17"], "h2": lr("1_{}_Limb_1") + ["bone_18"],
        "h3": lr("1_{}_Limb_2") + ["bone_19"]},
    "sledge_dog": {
        "body": [T + "Root"], "front": [T + "Spine_2"], "neck": [T + "Head_0"], "head": [T + "Head_1"],
        "jaw": [T + "Head_2"], "tail": [T + "Tail_0"],
        "f1": lr("0_{}_Limb_0"), "f2": lr("0_{}_Limb_1"), "f3": lr("0_{}_Limb_2"),
        "h1": lr("1_{}_Limb_0"), "h2": lr("1_{}_Limb_1"), "h3": lr("1_{}_Limb_2")},
    # the stag's right legs each have one more bone than its left (the right
    # shoulder is 0_Right_Limb_0 where the left's is Spine_3; 1_Right_Limb_0
    # is the rump, so the right thigh is 1_Right_Limb_1)
    "rime_stag": {
        "body": [T + "Root"], "front": [T + "Spine_2"], "neck": [T + "Head_0"], "head": [T + "Head_1"],
        "jaw": [T + "Head_2"], "tail": ["bone_17"],
        "f1": [T + "0_Left_Limb_0", T + "0_Right_Limb_1"], "f2": [T + "0_Left_Limb_1", T + "0_Right_Limb_2"],
        "f3": [T + "0_Left_Limb_2", T + "0_Right_Limb_3"],
        "h1": [T + "1_Left_Limb_0", T + "1_Right_Limb_1"], "h2": [T + "1_Left_Limb_1", T + "1_Right_Limb_2"],
        "h3": [T + "1_Left_Limb_2", T + "1_Right_Limb_3"]},
}

# pose -> {joint: degrees about X, "lift": root lift}
DOG = {
    "crouch": {"lift": -0.075, "body": -6, "front": -7, "f1": -60, "f2": 100, "f3": -40,
               "h1": 26, "h2": -44, "h3": 20, "neck": 14, "head": 8, "tail": -34},
    "launch": {"lift": 0.03, "body": 15, "front": 6, "f1": 34, "f2": -62, "f3": 30,
               "h1": -40, "h2": 18, "h3": -12, "neck": -4, "head": 6, "tail": 12},
    "lunge": {"lift": 0.13, "body": 7, "front": 5, "f1": 66, "f2": -12, "f3": 8,
              "h1": -64, "h2": 20, "h3": -10, "neck": 10, "head": 10, "jaw": 14, "tail": 28},
    "bite": {"lift": 0.09, "body": -2, "front": 2, "f1": 50, "f2": -20, "f3": 10,
             "h1": -52, "h2": 4, "h3": -4, "neck": -16, "head": -12, "jaw": -8, "tail": 34},
    "land": {"lift": -0.035, "body": -5, "front": -3, "f1": 34, "f2": -8, "f3": -14,
             "h1": -14, "h2": -18, "h3": 10, "neck": 12, "head": 4, "tail": 20},
    "recover": {"lift": -0.045, "body": -2, "front": -3, "f1": -12, "f2": 22, "f3": -8,
                "h1": 20, "h2": -32, "h3": 14, "neck": 6, "head": 2, "tail": -10},
}
STAG = {
    # gore: the tines dropped to the ground line, forehand sunk, a foreleg's weight back
    "lower": {"lift": -0.05, "body": -5, "front": -8, "f1": -16, "f2": 26, "f3": -10,
              "h1": 14, "h2": -22, "h3": 10, "neck": -46, "head": -22},
    "drive": {"lift": -0.01, "body": 4, "front": -2, "f1": 30, "f2": -44, "f3": 20,
              "h1": -30, "h2": 12, "h3": -8, "neck": -40, "head": -16},
    "gore": {"lift": 0.07, "body": 11, "front": 6, "f1": 52, "f2": -30, "f3": 12,
             "h1": -44, "h2": 14, "h3": -8, "neck": 20, "head": 8},
    # bound: back on the haunches, forefeet off the ground
    "rear": {"lift": 0.08, "body": 24, "front": 8, "f1": 44, "f2": -78, "f3": 34,
             "h1": 22, "h2": -34, "h3": 14, "neck": -22, "head": -8},
    "launch": {"lift": 0.10, "body": 18, "front": 4, "f1": 54, "f2": -60, "f3": 26,
               "h1": -42, "h2": 16, "h3": -10, "neck": -8, "head": 0},
    "leap": {"lift": 0.26, "body": 6, "front": 3, "f1": 64, "f2": -14, "f3": 8,
             "h1": -66, "h2": 22, "h3": -10, "neck": 10, "head": 6},
    "land": {"lift": -0.035, "body": -5, "front": -3, "f1": 30, "f2": -6, "f3": -14,
             "h1": -16, "h2": -16, "h3": 8, "neck": -14, "head": -6},
    "recover": {"lift": -0.035, "body": -2, "front": -2, "f1": -8, "f2": 16, "f3": -6,
                "h1": 14, "h2": -24, "h3": 10, "neck": 4, "head": 2},
}

SPEC = {
    "hearthhound": {"poses": DOG, "gain": {}, "alias": {"atk_lunge": "crouch", "bite": "lunge"},
                    "strikes": {"atk_lunge": {"load": "crouch", "lead": 0.10, "chain": [
                        ["launch", 0.0, 0.05], ["lunge", 0.06, 0.05], ["bite", 0.08, 0.04],
                        ["land", 0.17, 0.08], ["recover", 0.17, 0.14]]}}},
    # its glb faces the other way from the hound's, so every angle flips
    "sledge_dog": {"poses": DOG, "sign": -1.0, "gain": {"front": 1.3, "lift": 1.1},
                   "alias": {"atk_lunge": "crouch", "bite": "lunge"},
                   "strikes": {"atk_lunge": {"load": "crouch", "lead": 0.10, "chain": [
                       ["launch", 0.0, 0.05], ["lunge", 0.06, 0.05], ["bite", 0.08, 0.04],
                       ["land", 0.16, 0.08], ["recover", 0.17, 0.14]]}}},
    "rime_stag": {"poses": STAG, "gain": {},
                  "alias": {"gore": "lower", "atk_lunge": "lower", "bound": "rear"},
                  "strikes": {
                      "gore": {"load": "lower", "lead": 0.11, "chain": [
                          ["drive", 0.0, 0.06], ["gore", 0.09, 0.05], ["land", 0.22, 0.10], ["recover", 0.18, 0.15]]},
                      # the leap is held for the length of the strip (the attack's active time is its flight)
                      "bound": {"load": "rear", "rise": 0.22, "lead": 0.09, "chain": [
                          ["launch", 0.0, 0.05], ["leap", 0.07, 0.07], ["land", 0.62, 0.09], ["recover", 0.20, 0.16]]}}},
}


def build(mid, pose, gain, sign=1.0):
    out = {"_root": [0, round(pose.get("lift", 0.0) * gain.get("lift", 1.0), 3), 0]}
    for joint, bones in J[mid].items():
        if joint in pose:
            for b in bones:
                out[b] = [round(pose[joint] * gain.get(joint, 1.0) * sign, 1), 0, 0]
    return out


def main():
    path = ROOT / "data/anim/clip_meta.json"
    meta = json.loads(path.read_text())
    for mid, sp in SPEC.items():
        m = meta["models"].get(mid)
        if not m:
            continue
        m.pop("_src_poses", None)
        m.pop("pose_seq", None)
        for name, pose in sp["poses"].items():
            m["poses"][name] = build(mid, pose, sp["gain"], sp.get("sign", 1.0))
        m.setdefault("pose_alias", {}).update(sp["alias"])
        m["strikes"] = dict(sp["strikes"], _doc="clip -> load pose, launch `lead` s before the data windup, "
                            "then [pose, seconds after the beat before, blend] (tools/anim/quad_poses.py)")
        print(mid, "->", ", ".join(sp["poses"]))
    path.write_text(json.dumps(meta, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
