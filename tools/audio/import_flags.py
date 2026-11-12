#!/usr/bin/env python3
"""Set the Godot import loop flag on every music/ambience stream from the
data (state_profiles.json: every state's music and ambience loop;
audio.json: each music entry says loop true/false). Run after a Godot
--import has written the .import files; re-run the import afterwards.

    python3 tools/audio/import_flags.py
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def res(p):
    return os.path.join(ROOT, p.replace("res://", ""))


def wanted():
    out = {}
    prof = json.load(open(os.path.join(ROOT, "data", "state_profiles.json")))
    for st in prof.values():
        if isinstance(st, dict):
            for k in ("music", "ambience"):
                if st.get(k):
                    out[st[k]] = True
    audio = json.load(open(os.path.join(ROOT, "data", "audio.json")))
    for e in audio.get("music", {}).values():
        out[e["path"]] = bool(e.get("loop", True))
    # every ambience layer loops; the two state-wave bridges play once
    rep = os.path.join(ROOT, "docs", "audio", "sfx_report.json")
    if os.path.exists(rep):
        for name, b in json.load(open(rep))["beds"].items():
            out.setdefault(f"res://assets/audio/ambience/{name}.ogg", bool(b["loop"]))
    return out


def main():
    changed = 0
    for path, loop in wanted().items():
        imp = res(path) + ".import"
        if not os.path.exists(imp):
            print(f"[import] missing {imp} (run godot --import first)")
            continue
        s = open(imp).read()
        new = re.sub(r"^loop=(true|false)$", f"loop={'true' if loop else 'false'}", s, flags=re.M)
        if new != s:
            open(imp, "w").write(new)
            changed += 1
        print(f"[import] {path}: loop={loop}")
    print(f"[import] {changed} file(s) changed")


if __name__ == "__main__":
    main()
