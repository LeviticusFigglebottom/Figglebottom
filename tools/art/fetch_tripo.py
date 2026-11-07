#!/usr/bin/env python3
"""Re-download every Tripo source listed in tools/art/manifest.json into raw/.

Needs the session-local Tripo Studio MCP client; the cookie never enters the repo:
  TRIPO_CLIENT=/path/to/scratchpad/tripo/client.mjs python3 tools/art/fetch_tripo.py [--only NAME ...]

What it fetches (Studio projects keep the *latest* model version, so after a quad remesh
the project model is an FBX and the original high-poly GLB is gone):
  static/weapon  -> raw/<name>/remesh.fbx       (tripo_download format=fbx)
  character      -> raw/<name>/rigged.fbx + raw/<name>/anims/<preset>.fbx
                    (tripo_download animated+animation_only per preset, namespaced by source.rig; Studio serves these as FBX
                     even though the tool names them .glb, so they are renamed)
Costs 0 credits: downloads are free.
"""
import argparse
import json
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def call(client, tool, args):
    r = subprocess.run(["node", client, tool, json.dumps(args)], capture_output=True, text=True)
    out = json.loads(r.stdout)
    if not out.get("ok"):
        raise SystemExit(f"{tool} failed: {out.get('result')}")
    return out["result"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    a = ap.parse_args()
    client = os.environ.get("TRIPO_CLIENT")
    if not client:
        sys.exit("set TRIPO_CLIENT to the session's tripo client.mjs")
    man = json.load(open(os.path.join(ROOT, "tools/art/manifest.json")))
    for asset in man["assets"]:
        if a.only and asset["name"] not in a.only:
            continue
        pid = asset.get("source", {}).get("project_id")
        if not pid:
            continue
        inp = os.path.join(ROOT, asset["input"])
        os.makedirs(os.path.dirname(inp), exist_ok=True)
        if inp.endswith(".fbx"):
            call(client, "tripo_download", {"project_id": pid, "format": "fbx", "out_path": inp})
            print("fetched", asset["input"])
        # preset names are namespaced by rig type: preset:biped:walk, preset:quadruped:walk
        rig_type = asset.get("source", {}).get("rig", "biped").split("/")[0]
        for clip, path in asset.get("anims", {}).items():
            preset = os.path.splitext(os.path.basename(path))[0]
            dst = os.path.join(ROOT, path)
            tmp = dst[:-4] + ".glb"
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            call(client, "tripo_download", {"project_id": pid, "animated": True, "animation_only": True,
                                            "animation_name": f"preset:{rig_type}:{preset}", "out_path": tmp})
            os.replace(tmp, dst)
            print("fetched", path)


if __name__ == "__main__":
    main()
