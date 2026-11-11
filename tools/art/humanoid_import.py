#!/usr/bin/env python3
"""Humanoid retarget setup for every rigged character in tools/art/manifest.json.

Writes:
  assets/anim/mixamo_bone_map.tres  BoneMap: SkeletonProfileHumanoid -> mixamorig_* bones
  <glb>.import _subresources        retarget options on the Skeleton3D node (ADR 0004)

Bones keep their mixamorig_* names (rename off) so BoneAttachment3D targets and
clip tracks read the same on every Tripo rig. The rest fixer overwrites the
bone axes to the profile's standard frame, so a rotation track authored on one
model means the same pose on another; hips position tracks are normalised by
hips height and replayed through Skeleton3D.motion_scale.

Run from the repo root, then `godot --headless --path . --import`.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BONE_MAP = "assets/anim/mixamo_bone_map.tres"

# SkeletonProfileHumanoid bone -> Mixamo bone (without the mixamorig_ prefix)
MAP = {
    "Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2",
    "Neck": "Neck", "Head": "Head",
    "LeftUpperLeg": "LeftUpLeg", "LeftLowerLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToes": "LeftToeBase",
    "RightUpperLeg": "RightUpLeg", "RightLowerLeg": "RightLeg", "RightFoot": "RightFoot", "RightToes": "RightToeBase",
}
for side in ("Left", "Right"):
    MAP.update({
        f"{side}Shoulder": f"{side}Shoulder", f"{side}UpperArm": f"{side}Arm",
        f"{side}LowerArm": f"{side}ForeArm", f"{side}Hand": f"{side}Hand",
        f"{side}ThumbMetacarpal": f"{side}HandThumb1", f"{side}ThumbProximal": f"{side}HandThumb2",
        f"{side}ThumbDistal": f"{side}HandThumb3",
    })
    for prof, mix in (("Index", "Index"), ("Middle", "Middle"), ("Ring", "Ring"), ("Little", "Pinky")):
        MAP[f"{side}{prof}Proximal"] = f"{side}Hand{mix}1"
        MAP[f"{side}{prof}Intermediate"] = f"{side}Hand{mix}2"
        MAP[f"{side}{prof}Distal"] = f"{side}Hand{mix}3"


def bone_map_tres() -> str:
    lines = ['[gd_resource type="BoneMap" load_steps=2 format=3]', "",
             '[sub_resource type="SkeletonProfileHumanoid" id="SkeletonProfileHumanoid_mixamo"]', "",
             "[resource]", 'profile = SubResource("SkeletonProfileHumanoid_mixamo")']
    for prof, mix in MAP.items():
        lines.append(f'bone_map/{prof} = &"mixamorig_{mix}"')
    return "\n".join(lines) + "\n"


def subresources(name: str, loops: list) -> str:
    skel = f"PATH:{name}_rig/Skeleton3D"
    opts = [
        f'"retarget/bone_map": Resource("res://{BONE_MAP}")',
        '"retarget/bone_renamer/rename_bones": false',
        '"retarget/bone_renamer/unique_node/make_unique": false',
        '"retarget/remove_tracks/except_bone_transform": false',
        '"retarget/remove_tracks/unimportant_positions": true',
        '"retarget/remove_tracks/unmapped_bones": false',
        '"retarget/rest_fixer/apply_node_transforms": true',
        '"retarget/rest_fixer/normalize_position_tracks": true',
        '"retarget/rest_fixer/overwrite_axis": true',
        '"retarget/rest_fixer/reset_all_bone_poses_after_import": true',
        '"retarget/rest_fixer/fix_silhouette/enable": true',   # A-posed rests (the bulky bodies) are straightened to the profile's T
    ]
    anims = ",\n".join(f'"{a}": {{\n"settings/loop_mode": 1\n}}' for a in loops)
    return ('_subresources={\n"animations": {\n' + anims + '\n},\n"nodes": {\n"' + skel + '": {\n'
            + ",\n".join(opts) + "\n}\n}\n}")


def main() -> int:
    (ROOT / BONE_MAP).parent.mkdir(parents=True, exist_ok=True)
    (ROOT / BONE_MAP).write_text(bone_map_tres())
    manifest = json.loads((ROOT / "tools/art/manifest.json").read_text())
    for a in manifest["assets"]:
        if a.get("kind") != "character" or "mixamo" not in a.get("source", {}).get("rig", ""):
            continue
        imp = ROOT / (a["output"] + ".import")
        text = imp.read_text()
        sub = subresources(a["name"], a.get("loop", []))
        text, n = re.subn(r"^_subresources=\{.*?^\}$|^_subresources=\{\}$", sub, text, flags=re.S | re.M)
        if n != 1:
            print(f"!! {imp}: no _subresources line", file=sys.stderr)
            return 1
        if "/bosses/" in a["output"]:
            # a boss fills the screen: the importer's LODs crack a skinned,
            # seam-split mesh at fighting distance, so bosses keep one mesh
            text = text.replace("meshes/generate_lods=true", "meshes/generate_lods=false")
        imp.write_text(text)
        print(f"retarget -> {imp.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
