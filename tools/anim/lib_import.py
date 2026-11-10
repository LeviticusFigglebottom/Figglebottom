#!/usr/bin/env python3
"""Retarget import options for assets/anim/combat_lib.glb (run after the first
`godot --import` has written its .import, then import again). Same options
as every Mixamo character (tools/art/humanoid_import.py), so the library's
keys land in the shared standard bone frame."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/art"))
from humanoid_import import subresources  # noqa: E402

LOOPS = []   # loop flags are data (clip_meta.json clips.<name>.loop)


def main() -> int:
    imp = ROOT / "assets/anim/combat_lib.glb.import"
    if not imp.exists():
        print("run `godot --headless --path . --import` first", file=sys.stderr)
        return 1
    text = imp.read_text()
    text, n = re.subn(r"^_subresources=\{.*?^\}$|^_subresources=\{\}$", subresources("combat_lib", LOOPS),
                      text, flags=re.S | re.M)
    if n != 1:
        print(f"!! {imp}: no _subresources line", file=sys.stderr)
        return 1
    imp.write_text(text)
    print(f"retarget -> {imp.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
