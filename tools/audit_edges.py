#!/usr/bin/env python3
"""Edge audit (ADR 0003 §6): every walkable boundary must be classed.

For each terrain area and each world state (thaw, rime) this floods the
walkable land from the start position on the committed heightmap (1 m grid),
honouring building walls (doors open, gates barred), the state's extra floors
(rime ice) and the hazard volumes. Every edge between a reached cell and a
cell you cannot step onto is classed:

    cliff     a sheer drop or rise (> 3 m within 3 m)
    steep     a slope too steep to climb (> walk_max_deg)
    water     deep water (drowning depth)
    building  a building's own fabric (walls, a barred gate)
    thicket   inside a declared thicket polygon

An edge that is none of these (the grid's edge, a walkable step into nothing)
is UNCLASSED and fails. A cliff drop of more than 6 m whose landing is not
covered by a hazard volume (fall / kill / drown) fails as UNGUARDED. Every
hearth, pickup and the start must be reachable in the states they exist in.

Areas without a terrain block fall back to a no-op (they have no open land).
Usage: python3 tools/audit_edges.py [area_id ...]
"""
import json
import math
import os
import sys
from collections import Counter, deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))


def load_terrain(tb):
    gen = tb.get("generator", "")
    mod_name = os.path.splitext(os.path.basename(gen))[0]
    mod = __import__(mod_name)
    return mod


def in_box(p, hz):
    mn, mx = hz["min"], hz["max"]
    return all(mn[k] <= p[k] <= mx[k] for k in range(3))


def building_mask(buildings, X0, Z0, NX, NZ):
    """Cells on a building's wall line (doors left open). -> set of (i, j)."""
    out = set()
    for b in buildings:
        cx, cz = b["center"]
        hw, hl = b["size"][0] / 2.0, b["size"][1] / 2.0
        a = math.radians(b["yaw"])
        ca, sa = math.cos(a), math.sin(a)
        doors = b.get("doors", [])
        opens = set(b.get("open", []))
        r = int(max(hw, hl)) + 3
        ci, cj = int(round(cx - X0)), int(round(cz - Z0))
        for j in range(cj - r, cj + r + 1):
            for i in range(ci - r, ci + r + 1):
                if not (0 <= i < NX and 0 <= j < NZ):
                    continue
                x, z = X0 + i, Z0 + j
                dx, dz = x - cx, z - cz
                # inverse of the generator's rot_off
                lx = dx * ca - dz * sa
                lz = dx * sa + dz * ca
                on = False
                if abs(abs(lz) - hl) < 0.6 and abs(lx) <= hw + 0.6:
                    side = "S" if lz > 0 else "N"
                    on = side not in opens
                if abs(abs(lx) - hw) < 0.6 and abs(lz) <= hl + 0.6:
                    side = "E" if lx > 0 else "W"
                    on = on or side not in opens
                if not on:
                    continue
                if any(math.hypot(x - d[0], z - d[1]) < 0.96 for d in doors):
                    continue
                out.add((i, j))
    return out


def audit(area_id):
    path = os.path.join(ROOT, "data", "areas", f"{area_id}.json")
    d = json.load(open(path))
    tb = d.get("terrain")
    if not tb:
        print(f"[{area_id}] no terrain; edge audit not applicable")
        return 0
    T = load_terrain(tb)
    g = T.load_grid()
    X0, Z0 = tb["origin"]
    NX, NZ = tb["size"]
    E = d.get("edges", {})
    max_step = math.tan(math.radians(E.get("walk_max_deg", 45.0)))   # rise per 1 m
    deep = E.get("water_level", 0.0) - E.get("drown_depth", 1.15)
    hazards = d.get("hazards", [])
    kills = [h for h in hazards if h["kind"] in ("kill", "drown")]
    guards = hazards
    walls = building_mask(E.get("buildings", []), X0, Z0, NX, NZ)
    gate_cells = set()
    for gt in E.get("gates", []):
        gx, _, gz = gt["at"]
        for dx in range(-2, 3):
            gate_cells.add((int(round(gx - X0)) + dx, int(round(gz - Z0))))

    def H(i, j):
        return g[j * NX + i]

    def slope_ok(i, j, hh):
        # steepest of the four one-metre steps around the cell
        worst = 0.0
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ii, jj = i + di, j + dj
            if 0 <= ii < NX and 0 <= jj < NZ:
                worst = max(worst, abs(hh.get((ii, jj), H(ii, jj)) - hh.get((i, j), H(i, j))))
        return worst <= max_step + 1e-6

    total_bad = 0
    for state in ("thaw", "rime"):
        # state floors (rime ice over the channel)
        hh = {}
        for sf in E.get("state_floors", []):
            if sf.get("tag", "base") not in ("base", state):
                continue
            for j in range(int(sf["min"][1] - Z0), int(sf["max"][1] - Z0) + 1):
                for i in range(int(sf["min"][0] - X0), int(sf["max"][0] - X0) + 1):
                    if 0 <= i < NX and 0 <= j < NZ:
                        hh[(i, j)] = max(H(i, j), sf["y"])

        def h(i, j):
            return hh.get((i, j), H(i, j))

        def killed(i, j):
            p = (X0 + i, h(i, j) + 0.5, Z0 + j)
            return h(i, j) < deep or any(in_box(p, k) for k in kills
                                          if k.get("tag", "base") in ("base", state))

        def walkable(i, j):
            if (i, j) in walls or (i, j) in gate_cells:
                return False
            if killed(i, j):
                return False
            return slope_ok(i, j, hh)

        sx, _, sz = d["start"]["pos"]
        start = (int(round(sx - X0)), int(round(sz - Z0)))
        seen = {start}
        q = deque([start])
        while q:
            i, j = q.popleft()
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (i + di, j + dj)
                if n in seen or not (0 <= n[0] < NX and 0 <= n[1] < NZ):
                    continue
                if not walkable(*n) or abs(h(*n) - h(i, j)) > max_step + 1e-6:
                    continue
                seen.add(n)
                q.append(n)

        classes = Counter()
        bad = []
        unguarded = []
        thickets = E.get("thickets", [])
        for (i, j) in seen:
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (i + di, j + dj)
                if n in seen:
                    continue
                x, z = X0 + n[0], Z0 + n[1]
                if not (0 <= n[0] < NX and 0 <= n[1] < NZ):
                    bad.append((x, z, "grid edge"))
                    continue
                if n in walls or n in gate_cells:
                    classes["building"] += 1
                    continue
                if h(*n) < deep:
                    classes["water"] += 1
                    continue
                if killed(*n):
                    classes["cliff"] += 1     # a lethal ravine
                    continue
                if any(_in_poly(x, z, t["poly"]) for t in thickets):
                    classes["thicket"] += 1
                    continue
                dh = h(*n) - h(i, j)
                # look three cells on: a cliff keeps going, a slope does not
                k = 3
                ii, jj = i + di * k, j + dj * k
                far = h(min(max(ii, 0), NX - 1), min(max(jj, 0), NZ - 1)) - h(i, j)
                if abs(far) > 3.0 or abs(dh) > 2.0:
                    classes["cliff"] += 1
                    if far < -6.0:
                        # where does a fall land? follow the drop to its foot
                        li, lj = i, j
                        h0 = h(i, j)
                        for st in range(1, 40):
                            ni, nj = i + di * st, j + dj * st
                            n2 = (min(max(ni + 2 * di, 0), NX - 1), min(max(nj + 2 * dj, 0), NZ - 1))
                            if not (0 <= ni < NX and 0 <= nj < NZ):
                                break
                            li, lj = ni, nj
                            if h(ni, nj) < h0 - 6.0 and abs(h(ni, nj) - h(*n2)) < 1.0:
                                break     # the foot of the drop
                        land = (X0 + li, h(li, lj) + 0.5, Z0 + lj)
                        if not any(in_box(land, gz) for gz in guards
                                   if gz.get("tag", "base") in ("base", state)):
                            unguarded.append((X0 + i, Z0 + j, land))
                    continue
                if abs(dh) > max_step or not slope_ok(*n, hh):
                    classes["steep"] += 1
                    continue
                bad.append((x, z, f"open step dh={dh:.2f}"))
        # reachability of what the player must reach in this state
        unreached = []
        for key in ("hearths", "pickups"):
            for e in d.get(key, []):
                if e.get("tag", "base") not in ("base", state):
                    continue
                ex, _, ez = e["at"]
                c = (int(round(ex - X0)), int(round(ez - Z0)))
                near = any((c[0] + a, c[1] + b) in seen for a in (-1, 0, 1) for b in (-1, 0, 1))
                if not near:
                    unreached.append(f"{key[:-1]} {e.get('id')}")
        nb = E.get("nav_bounds")
        outside = 0
        if nb:
            outside = sum(1 for (i, j) in seen if not (nb[0] <= X0 + i <= nb[2] and nb[1] <= Z0 + j <= nb[3]))
        summary = ", ".join(f"{k} {v}" for k, v in sorted(classes.items()))
        print(f"[{area_id}:{state}] {len(seen)} m2 walkable; edges: {summary}")
        for (x, z, why) in bad[:20]:
            print(f"   UNCLASSED  edge at ({x:.0f}, {z:.0f}): {why}")
        if len(bad) > 20:
            print(f"   ... {len(bad) - 20} more unclassed edges")
        for (x, z, land) in unguarded[:10]:
            print(f"   UNGUARDED  drop at ({x:.0f}, {z:.0f}) lands at {tuple(round(v, 1) for v in land)} with no hazard volume")
        for u in unreached:
            print(f"   UNREACHABLE {u}")
        if outside:
            xs = [X0 + i for (i, j) in seen]
            zs = [Z0 + j for (i, j) in seen]
            print(f"   OUTSIDE-NAV {outside} walkable cells fall outside nav_bounds "
                  f"(walkable spans x {min(xs):.0f}..{max(xs):.0f}, z {min(zs):.0f}..{max(zs):.0f})")
        total_bad += len(bad) + len(unguarded) + len(unreached) + (1 if outside else 0)
    return total_bad


def _in_poly(x, z, poly):
    inside = False
    n = len(poly)
    for k in range(n):
        ax, az = poly[k]
        bx, bz = poly[(k + 1) % n]
        if (az > z) != (bz > z) and x < ax + (z - az) / (bz - az) * (bx - ax):
            inside = not inside
    return inside


def main():
    ids = sys.argv[1:] or [f[:-5] for f in sorted(os.listdir(os.path.join(ROOT, "data", "areas")))
                           if f.endswith(".json") and f != "index.json"]
    bad = sum(audit(a) for a in ids)
    if bad:
        print(f"edge audit: {bad} problems")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
