#!/usr/bin/env python3
"""Migrate an existing checkout's extracted Tripo textures to VRAM compression.

The GLB importer extracts textures as assets/models/**/*.jpg, and their .import
files are generated locally (gitignored). They used to get the texture
importer's defaults, Lossless plus "detect 3D -> VRAM compress". That flip only
happens in an interactive editor session, so headless imports (CI, the lead,
exports) shipped every 2048^2 map as raw RGBA: about 4x the VRAM.

project.godot now sets [importer_defaults] texture to VRAM compressed, so a
fresh clone is right on its own. A checkout that imported before that change
keeps its old .import files; this script rewrites their [params] to match what
a fresh clone gets, then you import again. (Committing the .jpg.import files
was tried: Godot then skips extraction and embeds raw textures in the .scn.)

Usage: python3 tools/art/texture_imports.py [--check]
  then: godot --headless --path . --import
--check exits 1 if any extracted map is still not VRAM compressed."""
import glob
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
# the same as [importer_defaults] texture in project.godot, so migrated and
# fresh checkouts import identically
WANT = {"compress/mode": "2", "compress/normal_map": "0", "mipmaps/generate": "true",
        "detect_3d/compress_to": "0"}


def wanted(path):
    return WANT


def patch(path, check):
    lines = open(path, encoding="utf-8").read().split("\n")
    w = wanted(path)
    seen, out, in_params, changed = set(), [], False, False
    for ln in lines:
        if ln.startswith("["):
            in_params = ln.strip() == "[params]"
        elif in_params and "=" in ln:
            k, v = ln.split("=", 1)
            if k in w:
                seen.add(k)
                if v != w[k]:
                    ln, changed = "%s=%s" % (k, w[k]), True
        out.append(ln)
    if not lines or "[params]" not in lines:
        return True   # no params yet (never imported): flag it
    missing = [k for k in w if k not in seen]
    if missing:
        i = out.index("[params]") + 1
        while i < len(out) and out[i].strip() != "":
            i += 1
        out[i:i] = ["%s=%s" % (k, w[k]) for k in missing]
        changed = True
    if changed and not check:
        open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    return changed


def main():
    check = "--check" in sys.argv
    files = sorted(glob.glob(os.path.join(ROOT, "assets/models/**/*.jpg.import"), recursive=True))
    imgs = glob.glob(os.path.join(ROOT, "assets/models/**/*.jpg"), recursive=True)
    orphans = [i for i in imgs if not os.path.exists(i + ".import")]
    bad = [f for f in files if patch(f, check)]
    for f in bad:
        print(("unpinned: " if check else "pinned: ") + os.path.relpath(f, ROOT))
    for o in orphans:
        print("no .import yet (run godot --headless --import): " + os.path.relpath(o, ROOT))
    print("%d maps, %d %s" % (len(files), len(bad), "unpinned" if check else "updated"))
    sys.exit(1 if check and (bad or orphans) else 0)


if __name__ == "__main__":
    main()
