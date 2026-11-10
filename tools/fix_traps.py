#!/usr/bin/env python3
"""Give every terrain trap a way out (docs/art/WORLD_FIDELITY.md, "Traps").

tools/audit_edges.py finds ground the Bearer can drop or slide onto and
cannot walk back out of. For each such trap this builds a ramp of fill: the
cheapest line from the walkable land down into the trap, graded at RAMP_RISE
per metre and three cells wide with banked sides, like a bank that has
slumped. The raised cells are written to data/terrain/patches/<area>.json,
which every terrain generator applies when it writes its grid
(terrain_patch.apply), so regenerating the land keeps the ramps.

A trap whose ramp would need more than MAX_FILL metres of fill, or would run
longer than MAX_LEN, gets no ramp: those are slides off the edge of the
country. Their cells are written to data/terrain/traps/<area>.json, and in
game the TrapWarden carries a Bearer who is stranded there back to the last
safe ground he stood on.

A ramp gets one try: if the trap is still there after it, the trap is marked.

Usage: python3 tools/fix_traps.py [--dry] [--no-ramps] [area_id ...]
"""
import heapq
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
os.environ["AUDIT_NO_WARDEN"] = "1"      # mark from the raw traps, not from what is already marked
import audit_edges as A  # noqa: E402
import terrain_patch  # noqa: E402

RAMP_RISE = 0.42      # metres of rise per metre of ramp (about 23 degrees)
MAX_FILL = 7.5
MAX_LEN = 46
SIDE = (0.0, 0.28, 0.95, 1.8, 2.8)    # how far the bank falls away, by cells from the line
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def ramp_for(comp, G):
    """-> ({cell: new height}, max fill, length) or None."""
    h, seen, blocked = G["h"], G["seen"], G["blocked"]
    NX, NZ = G["size"]
    comp_s = set(comp)
    # cheapest descent from the walkable land to a cell of the trap
    dist, prev = {}, {}
    pq = []
    rim = set()
    for c in seen:
        for d in N4:
            n = (c[0] + d[0], c[1] + d[1])
            if n not in seen and 0 <= n[0] < NX and 0 <= n[1] < NZ and n not in blocked:
                rim.add(c)
    for c in rim:
        dist[c] = 0.0
        heapq.heappush(pq, (0.0, c))
    end = None
    while pq:
        dc, c = heapq.heappop(pq)
        if dc > dist.get(c, 1e18):
            continue
        if c in comp_s:
            end = c
            break
        for d in N4:
            n = (c[0] + d[0], c[1] + d[1])
            if not (0 <= n[0] < NX and 0 <= n[1] < NZ) or n in blocked or (n in seen and n not in rim):
                continue
            drop = h[c] - h[n]
            cost = 1.0 + 6.0 * max(0.0, drop - RAMP_RISE) + 6.0 * max(0.0, -drop - RAMP_RISE)
            if dc + cost < dist.get(n, 1e18):
                dist[n] = dc + cost
                prev[n] = c
                heapq.heappush(pq, (dc + cost, n))
    if end is None:
        return None
    line = [end]
    while line[-1] in prev:
        line.append(prev[line[-1]])
    line.reverse()                      # from the walkable land down into the trap
    # carry on down the trap until the ramp lands
    r = h[line[0]]
    heights = [r]
    for c in line[1:]:
        r = max(h[c], r - RAMP_RISE)
        heights.append(r)
    guard = 0
    while heights[-1] > h[line[-1]] + 0.05 and guard < 80:
        c = line[-1]
        best = None
        for d in N4:
            n = (c[0] + d[0], c[1] + d[1])
            if n in comp_s and n not in line and (best is None or h[n] < h[best]):
                best = n
        if best is None:
            break
        line.append(best)
        heights.append(max(h[best], heights[-1] - RAMP_RISE))
        guard += 1
    patch = {}
    for c, r in zip(line, heights):
        for di in range(-4, 5):
            for dj in range(-4, 5):
                n = (c[0] + di, c[1] + dj)
                k = max(abs(di), abs(dj))
                if not (0 <= n[0] < NX and 0 <= n[1] < NZ) or n in blocked:
                    continue
                want = r - SIDE[k]
                if want > max(h[n], patch.get(n, -1e9)) + 0.01:
                    patch[n] = want
    fill = max((v - h[c] for c, v in patch.items()), default=0.0)
    return patch, fill, len(line)


def write_mask(area):
    """The traps a ramp cannot reach, as runs of cells per state:
    data/terrain/traps/<area>.json {"thaw": [[z, x0, x1], ...], "rime": [...]}.
    TrapWarden reads it in game; the audit counts those cells as guarded."""
    out = {}
    for (aid, state), G in sorted(A.TRAPS.items()):
        X0, Z0 = G["origin"]
        rows = {}
        for comp in G["traps"]:
            for (i, j) in comp:
                rows.setdefault(int(Z0 + j), []).append(int(X0 + i))
        runs = []
        for z in sorted(rows):
            xs = sorted(rows[z])
            a = b = xs[0]
            for x in xs[1:]:
                if x == b + 1:
                    b = x
                else:
                    runs.append([z, a, b])
                    a = b = x
            runs.append([z, a, b])
        out[state] = runs
    path = os.path.join(ROOT, "data", "terrain", "traps", area + ".json")
    old = {}
    if os.path.exists(path):
        old = json.load(open(path))
    # keep what an earlier pass marked: marked cells no longer show as traps
    for st in ("thaw", "rime"):
        out[st] = sorted([list(r) for r in {tuple(r) for r in out.get(st, []) + old.get(st, [])}])
    if not out["thaw"] and not out["rime"]:
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(out, f, separators=(",", ":"))
        f.write("\n")
    print("[%s] warden mask: %d thaw runs, %d rime runs" % (area, len(out["thaw"]), len(out["rime"])))


def main():
    dry = "--dry" in sys.argv
    no_ramps = "--no-ramps" in sys.argv
    ids = [a for a in sys.argv[1:] if not a.startswith("--")] or [
        f[:-5] for f in sorted(os.listdir(os.path.join(ROOT, "data", "areas"))) if f.endswith(".json") and f != "index.json"]
    for area in ids:
        for rounds in range(6):
            A.TRAPS.clear()
            for mod in list(sys.modules.values()):
                if hasattr(mod, "_cache") and getattr(mod, "__name__", "").startswith("terrain_"):
                    mod._cache = None
            sys.stdout = open(os.devnull, "w")
            try:
                A.audit(area)
            finally:
                sys.stdout = sys.__stdout__
            done = set()
            patch_all = {}
            left = []
            for (aid, state), G in sorted(A.TRAPS.items()):
                for comp in G["traps"]:
                    key = min(comp)
                    if key in done:
                        continue
                    done.add(key)
                    res = ramp_for(comp, G)
                    xs = [G["origin"][0] + c[0] for c in comp]
                    zs = [G["origin"][1] + c[1] for c in comp]
                    where = "x %d..%d, z %d..%d (%d m2, %s)" % (min(xs), max(xs), min(zs), max(zs), len(comp), state)
                    if no_ramps or res is None or res[1] > MAX_FILL or res[2] > MAX_LEN or rounds > 0:
                        left.append(where + (": no line found" if res is None else ": ramp would need %.1f m of fill over %d m" % (res[1], res[2])))
                        continue
                    print("[%s] ramp into trap at %s: %d cells raised, %.1f m of fill at most, %d m long" % (area, where, len(res[0]), res[1], res[2]))
                    for c, v in res[0].items():
                        patch_all[c] = max(v, patch_all.get(c, -1e9))
            for w in left:
                print("[%s] too deep to ramp, marked for the warden: %s" % (area, w))
            if not patch_all or dry:
                if not dry:
                    write_mask(area)
                break
            X0, Z0 = next(iter(A.TRAPS.values()))["origin"]
            terrain_patch.add(area, {(X0 + c[0], Z0 + c[1]): v for c, v in patch_all.items()})
            terrain_patch.rewrite_grid(area)


if __name__ == "__main__":
    main()
