#!/usr/bin/env python3
"""Perimeter audit: rasterize an area's floor fills on a 1m grid, walk the
boundary, and check every 4m boundary segment for a blocking piece (wall /
window / portal / fence / blocker / gate). Segments open in ONE state only
are fine if that's a designed state-route; anything open in BOTH states is
an out-of-bounds hole.

Usage: python3 tools/audit_walls.py [area_id ...]
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BLOCKING = {"wall_4x4", "wall_low_4m", "portal_4m", "arch_4m", "fence_iron_4m",
            "column_4m", "pillar", "stair_4m", "gate_iron"}
# pieces that block travel but are passable doorways (still "not a fall")
OPEN_DOOR = {"portal_4m", "arch_4m"}


def pieces_of(def_):
    out = []
    for spec in def_.get("pieces", []):
        out.append(spec)
    for spec in def_.get("props", []):
        out.append(spec)
    for row in def_.get("rows", []):
        fr = row.get("from", [0, 0, 0])
        d = row.get("dir", [1, 0, 0])
        step = row.get("step", 4.0)
        for i in range(int(row.get("count", 1))):
            if i in row.get("skip", []):
                continue
            sub = dict(row)
            sub["at"] = [fr[0] + d[0] * step * i, fr[1], fr[2] + d[2] * step * i]
            out.append(sub)
    return out


def audit(area_id):
    path = os.path.join(ROOT, "data", "areas", f"{area_id}.json")
    def_ = json.load(open(path))
    # floor cells (1m); track top height per cell for drop checks
    cells = set()
    cell_y = {}
    for f in def_.get("fills", []):
        if f.get("kit") == "burg_floor_3m":
            continue   # 3m interior rowhouse upper floors sit above the walkable plateau
        mn, mx = f["min"], f["max"]
        for x in range(int(mn[0]), int(mx[0])):
            for z in range(int(mn[2]), int(mx[2])):
                cells.add((x, z))
                cell_y[(x, z)] = max(cell_y.get((x, z), -1e9), float(mn[1]))
    # walkable low ground (e.g. the peat flats): boxes marked walkable seal any
    # edge that merely steps down onto them
    low = {}
    for b in def_.get("boxes", []):
        if not b.get("walkable", False):
            continue
        mn, mx = b["min"], b["max"]
        for x in range(int(mn[0]), int(mx[0])):
            for z in range(int(mn[2]), int(mx[2])):
                low[(x, z)] = max(low.get((x, z), -1e9), float(mx[1]))
    if not cells:
        print(f"[{area_id}] no floor fills; skipping")
        return []

    # boundary edges between floor and void, grouped into 4m segments
    # edge key: (x, z, 'N'|'S'|'E'|'W') on cell
    segs = {}   # (axis, fixed_coord, seg_start) -> set of state coverage
    edge_list = []
    for (x, z) in cells:
        for (dx, dz, side) in ((0, -1, 'N'), (0, 1, 'S'), (-1, 0, 'W'), (1, 0, 'E')):
            if (x + dx, z + dz) in cells:
                continue
            if side in ('N', 'S'):
                line_z = z if side == 'N' else z + 1
                seg = ('x', line_z, (x // 4) * 4)
            else:
                line_x = x if side == 'W' else x + 1
                seg = ('z', line_x, (z // 4) * 4)
            segs.setdefault(seg, set())
            edge_list.append(seg)

    # blocking pieces cover segments
    pieces = pieces_of(def_)
    for spec in pieces:
        kit = spec.get("kit", "")
        if kit not in BLOCKING:
            continue
        at = spec.get("at", [0, 0, 0])
        if float(at[1]) > 3.0:
            continue    # high decor (gargoyles etc.) seals nothing; landing
                        # walls at raised floors (y<=3) do count
        rot = float(spec.get("rot", 0)) % 360
        tag = spec.get("tag", "base")
        along_x = abs(math.sin(math.radians(rot))) < 0.5   # rot 0/180 -> runs along x
        # a piece spans 4m along its line; credit every boundary segment it
        # overlaps by >=1.9m (pieces may sit half-offset from the seg grid)
        if along_x:
            axis_p, fixed_p, lo = 'x', at[2], at[0] - 2.0
        else:
            axis_p, fixed_p, lo = 'z', at[0], at[2] - 2.0
        for cand in list(segs.keys()):
            if cand[0] != axis_p:
                continue
            if abs(cand[1] - fixed_p) > 0.55:
                continue
            overlap = min(lo + 4.0, cand[2] + 4.0) - max(lo, cand[2])
            if overlap >= 1.9:
                segs[cand].add(tag if kit not in OPEN_DOOR else "door")
    # blockers
    for b in def_.get("blockers", []):
        mn, mx = b["min"], b["max"]
        tag = b.get("tag", "base")
        for cand in list(segs.keys()):
            axis, fixed, start = cand
            if axis == 'x' and mn[2] - 0.6 <= fixed <= mx[2] + 0.6 and mn[0] <= start + 2 <= mx[0]:
                segs[cand].add(tag)
            if axis == 'z' and mn[0] - 0.6 <= fixed <= mx[0] + 0.6 and mn[2] <= start + 2 <= mx[2]:
                segs[cand].add(tag)

    def wading_edge(seg) -> bool:
        axis, fixed, start = seg
        for off in (1, 2):
            for side in (-1, 1):
                if axis == 'x':
                    p = (start + off, int(fixed) + (0 if side > 0 else -1))
                    q = (start + off, int(fixed) - (1 if side > 0 else 0))
                else:
                    p = (int(fixed) + (0 if side > 0 else -1), start + off)
                    q = (int(fixed) - (1 if side > 0 else 0), start + off)
                if p in low and q in cells and cell_y[q] - low[p] <= 2.6:
                    return True
        return False

    holes = []
    for seg, cover in sorted(segs.items()):
        if "door" in cover:
            continue   # archway onto... verify it leads to floor on both sides? doors to void ARE holes
        if "base" in cover:
            continue
        if not cover and wading_edge(seg):
            continue   # steps down onto walkable low ground (the peat flats)
        if "thaw" in cover and "rime" in cover:
            continue
        state = "BOTH STATES" if not cover else \
            ("rime only -> open in thaw" if cover == {"rime"} else "thaw only -> open in rime")
        holes.append((seg, state))
    # doors that lead into void (portal segments on outer boundary with no floor beyond)
    for seg, cover in sorted(segs.items()):
        if "door" in cover and not (cover - {"door"}):
            axis, fixed, start = seg
            # check floor on both sides of the line at segment middle
            if axis == 'x':
                a = (start + 2, fixed - 1) in cells or (start + 1, fixed - 1) in cells
                b = (start + 2, fixed) in cells or (start + 1, fixed) in cells
            else:
                a = (fixed - 1, start + 2) in cells or (fixed - 1, start + 1) in cells
                b = (fixed, start + 2) in cells or (fixed, start + 1) in cells
            if not (a and b):
                holes.append((seg, "DOORWAY TO VOID"))
    return holes


def main():
    ids = sys.argv[1:] or [f[:-5] for f in os.listdir(os.path.join(ROOT, "data", "areas"))
                           if f.endswith(".json") and f != "index.json"]
    bad = 0
    for aid in ids:
        holes = audit(aid)
        for (axis, fixed, start), state in holes:
            bad += 1
            if axis == 'x':
                where = f"z={fixed}, x {start}..{start + 4}"
            else:
                where = f"x={fixed}, z {start}..{start + 4}"
            print(f"[{aid}] HOLE  {where}   ({state})")
        if not holes:
            print(f"[{aid}] perimeter sealed")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
