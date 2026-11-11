#!/usr/bin/env python3
"""Print the image-generation request for one sheet of the painted icon set
(tools/ui/icon_sheets.json), as the JSON the Tripo Studio image tool takes.
Usage: python3 tools/ui/icon_prompts.py SHEET [OUT_DIR]
       python3 tools/ui/icon_prompts.py --list
The image tool is free; it makes no 3D. Save its PNG as
raw/ui_icons/SHEET.png, then run tools/ui/build_icons.py."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def request(sheet, out_dir=None):
    man = json.load(open(os.path.join(HERE, "icon_sheets.json")))
    s = man["sheets"][sheet]
    cols, rows = s["grid"]
    tiles = s["tiles"]
    head = man["style"].format(cols=cols, rows=rows, n=len(tiles))
    body = "; ".join("%d) %s" % (i + 1, t[1]) for i, t in enumerate(tiles)) + "."
    req = {"prompt": head + body, "aspect_ratio": "1:1", "resolution": "2K", "wait_seconds": 400}
    if out_dir:
        req["out_dir"] = out_dir
    return req


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "--list":
        print("\n".join(json.load(open(os.path.join(HERE, "icon_sheets.json")))["sheets"]))
    else:
        print(json.dumps(request(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)))
