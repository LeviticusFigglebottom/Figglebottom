#!/usr/bin/env python3
"""Systematic anomaly audit for every area's JSON: catches props floating off
the floor, duplicate/overlapping props, placements off any floor, and interior
holes in the walkable floor. Complements audit_edges.py (classed terrain edges).

Run: python3 tools/audit_areas.py [area_id]
Exit non-zero if any anomaly is found."""
import json, glob, math, os, sys

# props that are meant to sit ABOVE the floor (wall/ceiling/window mounted), so
# a high Y is expected and must not be flagged as "floating".
MOUNTED = {"beam_4m", "roof_slab_4m", "gable_8m", "gable_12m", "gable_end_8m", "gable_end_12m"}
# kits that are architecture (not decor); they define floors/walls, skip float check
ARCH = {"floor_4x4", "wall_4x4", "wall_low_4m", "portal_4m", "arch_4m", "column_4m", "pillar",
        "stair_4m", "ramp_4m", "fence_iron_4m", "gate_iron", "frost_veil_frame"}
# railings sit ON their floor and INSIDE its edge — they must NOT float or overhang.
RAILING = set()
RAIL_TOL = 0.18     # a railing more than this off its floor top is a defect


def v3(a):
    return (float(a[0]), float(a[1]), float(a[2]))


def expand_row(r):
    out = []
    frm = v3(r["from"]); d = v3(r.get("dir", [1, 0, 0]))
    step = float(r.get("step", 4.0)); n = int(r.get("count", 1))
    skip = set(int(x) for x in r.get("skip", []))
    for i in range(n):
        if i in skip:
            continue
        # carry rot/scale: plane-sensitive checks (WALL-OVERLAP) need them —
        # dropping rot silently put row-placed windows on the wrong plane
        out.append({"kit": r["kit"], "at": [frm[0] + d[0] * step * i,
                    frm[1] + d[1] * step * i, frm[2] + d[2] * step * i],
                    "tag": r.get("tag", "base"), "rot": r.get("rot", 0),
                    "scale": r.get("scale", [1, 1, 1])})
    return out


TERRAIN = None   # sampler(x, z) of the area's committed heightmap, if any
STATE_FLOORS = []


def floors_at(fills, x, z, margin=0.05):
    """All floor heights whose tile covers (x,z) — an area can be multi-level.
    On a terrain area the land itself is a floor everywhere it spans.
    `margin` widens the footprint: railings legitimately line a floor's edge
    (hanging their depth over the drop they guard), so they need a looser reach
    to find the floor they belong to; grounded decor uses the tight default."""
    ys = []
    if TERRAIN is not None:
        ys.append(TERRAIN(x, z))
    for sf in STATE_FLOORS:          # jetties, platforms, ice: floors too
        if "min" in sf and sf["min"][0] - margin <= x <= sf["max"][0] + margin \
                and sf["min"][1] - margin <= z <= sf["max"][1] + margin:
            ys.append(sf["y"])
        elif "radius" in sf and math.hypot(x - sf["center"][0], z - sf["center"][1]) <= sf["radius"]:
            ys.append(sf["y"])
    for f in fills:
        mn, mx = v3(f["min"]), v3(f["max"])
        if mn[0] - margin <= x <= mx[0] + margin and mn[2] - margin <= z <= mx[2] + margin:
            ys.append(mx[1])
    return ys


def cells_of(regions, y_from="min"):
    """Rasterize a list of {min,max} regions to 4 m cell centres -> {(cx,cz): {y}}."""
    out = {}
    for r in regions:
        mn, mx = v3(r["min"]), v3(r["max"])
        yv = mn[1] if y_from == "min" else mx[1]
        x = mn[0] + 2.0
        while x < mx[0] - 0.01:
            z = mn[2] + 2.0
            while z < mx[2] - 0.01:
                out.setdefault((round(x), round(z)), set()).add(round(yv, 1))
                z += 4.0
            x += 4.0
    return out


def wall_boxes(d):
    """Every wall/architecture segment as (axis, cx, span_lo, span_hi, y, tag, kit),
    for clipping tests. axis 'x' spans X (thin in Z), 'z' spans Z (thin in X)."""
    boxes = []
    WALLS = {"wall_4x4", "ossuary_wall_4m", "arcade_4m"}
    def add(kit, at, rot, tag):
        if kit not in WALLS:
            return
        x, y, z = v3(at)
        if abs(float(rot)) % 90 > 0.01:
            return     # a house turned to the land: the plane test is axis-only
        r = ((int(rot) % 180) + 180) % 180
        if r == 90:                      # spans Z
            boxes.append(("z", x, z - 2, z + 2, y, tag, kit))
        else:                            # spans X
            boxes.append(("x", z, x - 2, x + 2, y, tag, kit))
    for p in d.get("pieces", []):
        if "at" in p:
            add(p.get("kit", ""), p["at"], p.get("rot", 0), p.get("tag", "base"))
    for r in d.get("rows", []):
        for p in expand_row(r):
            add(p["kit"], p["at"], r.get("rot", 0), p.get("tag", "base"))
    return boxes


def opposite_state(a, b):
    """True when two tags are on mutually-exclusive world states (never co-present)."""
    return {a, b} == {"thaw", "rime"}


def flags_exclusive(a, b):
    """True when two specs can never coexist because one requires a world
    flag the other requires absent (a story swap: knight before, note after)."""
    return (a.get("require_flag") and a.get("require_flag") == b.get("absent_flag")) \
        or (b.get("require_flag") and b.get("require_flag") == a.get("absent_flag"))


def audit(area_id):
    global TERRAIN, STATE_FLOORS
    d = json.load(open(f"data/areas/{area_id}.json"))
    TERRAIN = None
    STATE_FLOORS = d.get("edges", {}).get("state_floors", [])
    if d.get("terrain"):
        sys.path.insert(0, "tools")
        mod = __import__(os.path.splitext(os.path.basename(d["terrain"]["generator"]))[0])
        TERRAIN = mod.sample
    fills = d.get("fills", [])
    # a walkable box's TOP is a floor too (the Marches' peat flats, landing
    # skirts): fold box tops in as faux fills for grounding/roof checks
    for b in d.get("boxes", []):
        if b.get("walkable", False):
            fills = fills + [{"min": [b["min"][0], b["max"][1], b["min"][2]],
                              "max": [b["max"][0], b["max"][1], b["max"][2]]}]
    # cells that are intentionally open to the sky (exterior courts, terraces):
    # named explicitly, or covered by an open_air_regions {min,max} box.
    open_air = set(tuple(c) for c in d.get("open_air_cells", []))
    for reg, ys in cells_of(d.get("open_air_regions", [])).items():
        open_air.add(reg)
    issues = []

    # 0) roof coverage: any floored cell with no vault_field (roof) at its level
    #    exposes the sky. open_air_cells whitelists intentional outdoor tiles.
    #    A dome prop IS a roof: its shell closes the crossing it sits over
    #    (collar covers the hole corners), so its footprint counts.
    floor_cells = cells_of(fills, "max")
    roof_cells = cells_of(d.get("vault_fields", []), "min")
    # circular domes cover a radius; the cove dome covers its full rectangle
    ROOF_PROPS = {}
    for p in d.get("props", []):
        shape = ROOF_PROPS.get(p.get("kit", ""))
        if not shape:
            continue
        ax, ay, az = v3(p.get("at", [0, 0, 0]))
        for (cx, cz), fys in floor_cells.items():
            hit = (math.hypot(cx - ax, cz - az) <= shape[1]) if shape[0] == "disc" \
                else (abs(cx - ax) <= shape[1] and abs(cz - az) <= shape[2])
            if hit:
                for fy in fys:
                    if fy <= ay:   # the bowl roofs every floor beneath its rim
                        roof_cells.setdefault((cx, cz), set()).add(fy)
    for (cx, cz), fys in floor_cells.items():
        if (cx, cz) in open_air:
            continue
        rys = roof_cells.get((cx, cz), set())
        for fy in fys:
            # roofed if a vault springs at or below this floor (its lid is above),
            # OR another storey's floor covers the cell overhead (a tower level's
            # ceiling IS the slab of the storey above)
            storey_above = any(fy + 2.0 <= oy <= fy + 20.0 for oy in fys)
            if not storey_above and not any(ry <= fy + 0.5 for ry in rys):
                issues.append(f"UNROOFED   floor cell ~({cx},{cz}) at y={fy} has no roof (sky leak)")
                break

    # gather all placed decor props (pieces + props + rows of decor)
    placed = []
    for key in ("pieces", "props"):
        for p in d.get(key, []):
            if "at" in p:
                placed.append(p)
    for r in d.get("rows", []):
        placed += expand_row(r)

    # every floor-standing entity list joins the grounding check: a pickup or
    # hearth authored 0.2 m off the floor floats just as visibly as a statue
    for key in ("pickups", "hearths", "npcs", "plaques", "spawners"):
        for p in d.get(key, []):
            if "at" in p:
                e = {"kit": "(%s)" % key[:-1], "at": p["at"],
                     "tag": p.get("tag", "base")}
                # story swaps (knight in thaw, his note after the reckoning)
                # share a spot on purpose — carry the gating flags through so
                # the duplicate/overlap checks can see they never coexist
                for f in ("require_flag", "absent_flag"):
                    if f in p:
                        e[f] = p[f]
                placed.append(e)

    # 1) props floating off the floor (grounded decor + railings). Railings are in
    #    ARCH (so wall/overlap checks skip them) but opt back IN here: a balustrade
    #    that floats above its floor, or sits past the floor edge over the drop, is
    #    exactly the terrace defect and must trip. Grounded decor uses a tight
    #    0.15 m tolerance: the old 0.6 m waved through statues hovering 0.2 m up.
    for p in placed:
        kit = p.get("kit", "")
        if kit in MOUNTED or (kit in ARCH and kit not in RAILING):
            continue
        if p.get("embed"):
            continue      # afloat or frozen into the ice on purpose
        if p.get("on"):
            continue      # set down on furniture (a table top), not on the floor
        at = v3(p["at"])
        is_rail = kit in RAILING
        # railings reach a bit further to find the floor edge they line; vertical
        # tolerance stays tight so a rail that doesn't SIT on that floor still trips
        ys = floors_at(fills, at[0], at[2], 0.4 if is_rail else 0.05)
        tol = RAIL_TOL if is_rail else 0.15
        if not ys:
            tail = " (railing floats past floor edge, over the drop)" if is_rail else " (over no floor)"
            issues.append(f"OFF-FLOOR  {kit} at {p['at']}{tail}")
        elif not any(abs(at[1] - y) <= tol for y in ys):
            # nearest floor the prop could rest on
            near = min(ys, key=lambda y: abs(at[1] - y))
            if near < at[1]:
                issues.append(f"FLOATING   {kit} at {p['at']} (nearest floor y={near:.1f}, {at[1]-near:.1f} m up)")
            else:
                issues.append(f"SUNK       {kit} at {p['at']} (nearest floor y={near:.1f}, {near-at[1]:.1f} m below)")

    # 1c) structural overlap on a shared wall plane: a wall_4x4 whose 4 m footprint
    #     overlaps a window/portal panel on the same line buries half the window in
    #     masonry (the porch's "incomplete stained glass"). Openings are compared
    #     against every wall segment on their plane.
    # portal_4m is deliberately absent: a portal dressed flush against a sealing
    # wall is the intended pattern for area transitions (dark doorway, no void
    # leak). Windows/gates/arcades are see-through — burying them is always wrong.
    OPENINGS = {"window_lancet_4m": 4.0, "rose_window": 4.4,
                "arcade_4m": 4.0, "gate_iron": 4.0}
    wboxes = wall_boxes(d)
    for p in placed:
        kit = p.get("kit", "")
        if kit not in OPENINGS:
            continue
        x, y, z = v3(p["at"])
        rot = ((int(p.get("rot", 0)) % 180) + 180) % 180
        sc = p.get("scale", [1, 1, 1])
        sx = float(sc[0]) if isinstance(sc, list) else float(sc)
        half = OPENINGS[kit] * sx * 0.5
        paxis = "z" if rot == 90 else "x"       # matches wall_boxes convention
        pc = x if paxis == "z" else z           # plane coordinate
        plo = (z if paxis == "z" else x) - half
        phi = (z if paxis == "z" else x) + half
        for (axis, c, lo, hi, wy, wtag, wkit) in wboxes:
            if axis != paxis or abs(c - pc) > 0.3 or abs(wy - y) > 3.5:
                continue
            if opposite_state(p.get("tag", "base"), wtag):
                continue
            # an arcade IS a wall segment in wall_boxes — don't match a piece
            # against its own entry (same kit, identical span). A DIFFERENT kit
            # with an identical span is a full burial — the worst case, keep it.
            if wkit == kit and abs(lo - plo) < 0.02 and abs(hi - phi) < 0.02:
                continue
            ov = min(hi, phi) - max(lo, plo)
            if ov > 0.25:
                issues.append(f"WALL-OVERLAP {kit} at {p['at']} buried {ov:.1f} m deep in a wall "
                              f"segment [{lo:.0f},{hi:.0f}] on the same plane")
                break

    # 1b) free-standing decor buried inside a wall (embedded/clipping)
    WALL_HUG = {"banner", "banner_torn", "sconce_torch", "candle_cluster", "ivy_sheet_a",
                "ivy_sheet_b", "candle_cluster_dead", "glass_lancet", "glass_lancet_broken",
                "plaque", "cobweb", "censer_hanging", "chime_stone", "bone_pile"}
    boxes = wall_boxes(d)
    for p in placed:
        kit = p.get("kit", "")
        if kit in ARCH or kit in MOUNTED or kit in WALL_HUG:
            continue
        x, y, z = v3(p["at"]); ptag = p.get("tag", "base")
        for (axis, c, lo, hi, wy, wtag, wkit) in boxes:
            if abs(y - wy) > 3.5 or opposite_state(ptag, wtag):
                continue                   # a rime prop can sit where a thaw wall stood
            if axis == "x":               # wall spans X at z=c
                if abs(z - c) < 0.35 and lo - 0.3 <= x <= hi + 0.3:
                    issues.append(f"IN-WALL    {kit} ({ptag}) at {p['at']} inside a wall (z~{c})")
                    break
            else:                          # wall spans Z at x=c
                if abs(x - c) < 0.35 and lo - 0.3 <= z <= hi + 0.3:
                    issues.append(f"IN-WALL    {kit} ({ptag}) at {p['at']} inside a wall (x~{c})")
                    break

    # 2) duplicate/overlapping props of the same kit+tag at ~same spot
    seen = {}
    for p in placed:
        kit = p.get("kit", "")
        if kit in ARCH:
            continue
        at = v3(p["at"]); tag = p.get("tag", "base")
        key = (kit, tag, round(at[0]), round(at[1]), round(at[2]))
        if key in seen:
            if not flags_exclusive(p, seen[key]):
                issues.append(f"DUPLICATE  {kit} ({tag}) near {p['at']}")
        seen[key] = p

    # 2b) distinct co-present props merged into one another (asset collision)
    DECAL = {"mosaic_medallion", "carpet_runner_8m", "rubble_s", "ivy_sheet_a", "ivy_sheet_b",
             "cobweb", "shroud_dead", "bone_pile", "rubble_m", "rubble_l", "ash_drift",
             "root_tangle", "duckboard_4m", "reed_clump"}
    manifest = json.load(open("assets/kit/manifest.json")) if os.path.exists("assets/kit/manifest.json") else {}
    ground = [p for p in placed if p.get("kit", "") not in ARCH
              and p.get("kit", "") not in MOUNTED and p.get("kit", "") not in DECAL
              and not p.get("on")]      # (set down on or in another thing on purpose: oars in a boat)
    for i in range(len(ground)):
        ka = ground[i].get("kit", ""); ta = ground[i].get("tag", "base"); pa = v3(ground[i]["at"])
        for j in range(i + 1, len(ground)):
            kb = ground[j].get("kit", ""); tb = ground[j].get("tag", "base")
            if ka == kb or opposite_state(ta, tb) \
                    or flags_exclusive(ground[i], ground[j]):   # story swaps never co-present
                continue
            pb = v3(ground[j]["at"])
            if abs(pa[1] - pb[1]) >= 1.2:
                continue
            if math.hypot(pa[0] - pb[0], pa[2] - pb[2]) < 0.5:
                issues.append(f"OVERLAP    {ka} ({ta}) into {kb} ({tb}) at {ground[i]['at']}")
                continue
            # Also check if an entity (spawner/npc/pickup/hearth/plaque) sits inside an elongated prop's rotated box
            for prop_p, ent_p in ((ground[i], ground[j]), (ground[j], ground[i])):
                pk = prop_p.get("kit", ""); ek = ent_p.get("kit", "")
                if not ek.startswith("(") or pk not in manifest:
                    continue
                sz = manifest[pk].get("size", [0, 0, 0])
                if sz[2] < 0.35:
                    continue
                p_at = v3(prop_p["at"]); e_at = v3(ent_p["at"])
                rot = math.radians(float(prop_p.get("rot", 0)))
                dx, dz = e_at[0] - p_at[0], e_at[2] - p_at[2]
                lx = dx * math.cos(rot) - dz * math.sin(rot)
                lz = dx * math.sin(rot) + dz * math.cos(rot)
                if abs(lx) < sz[0] * 0.5 - 0.05 and abs(lz) < sz[1] * 0.5 - 0.05:
                    issues.append(f"OVERLAP    {ek} ({ent_p.get('tag','base')}) inside {pk} footprint at {ent_p['at']}")
                    break

    # 2c) unbacked outdoor terraces: an open-air floor slab is a thin 0.25 m tile;
    #     if the area offers a LOWER vantage (another fill level below it), the
    #     slab's underside and the void beneath are visible from there — the exact
    #     porch-terrace defect. Such fills must be backed by substructure: a
    #     `boxes` entry (or another fill) directly beneath their footprint.
    #     (Limit: the LOWEST outdoor slab's own edge-drop is not modelled here —
    #     that seam is covered by the perimeter audit + photo sweeps.)
    boxes_below = d.get("boxes", [])
    def backed(cx, cz, top):
        for b in boxes_below:
            mn, mx = v3(b["min"]), v3(b["max"])
            if mn[0] - 0.05 <= cx <= mx[0] + 0.05 and mn[2] - 0.05 <= cz <= mx[2] + 0.05 \
               and mx[1] >= top - 0.35 and mn[1] <= top - 2.0:
                return True
        for f in fills:
            mn, mx = v3(f["min"]), v3(f["max"])
            if mn[0] - 0.05 <= cx <= mx[0] + 0.05 and mn[2] - 0.05 <= cz <= mx[2] + 0.05 \
               and mx[1] < top - 0.3:      # a room below: underside is its ceiling
                return True
        return False
    tops = sorted({v3(f["min"])[1] for f in fills})
    if len(tops) > 1:
        for f in fills:
            top = v3(f["min"])[1]
            if top <= tops[0] + 0.3:
                continue                    # lowest level: no vantage below it
            mn, mx = v3(f["min"]), v3(f["max"])
            x = mn[0] + 2.0
            while x < mx[0] - 0.01:
                z = mn[2] + 2.0
                flagged = False
                while z < mx[2] - 0.01:
                    if (round(x), round(z)) in open_air and not backed(x, z, top):
                        issues.append(f"UNBACKED   outdoor floor at y={top} cell ~({round(x)},{round(z)}) "
                                      f"has void below (visible from the lower level)")
                        flagged = True
                        break
                    z += 4.0
                if flagged:
                    break
                x += 4.0

    # 3) interior holes: floor cells missing where surrounded by floor
    if fills:
        cells = set()
        for f in fills:
            mn, mx = v3(f["min"]), v3(f["max"])
            x = mn[0]
            while x < mx[0] - 0.01:
                z = mn[2]
                while z < mx[2] - 0.01:
                    cells.add((round(x + 2), round(z + 2)))
                    z += 4
                x += 4
        for (cx, cz) in list(cells):
            if (cx, cz) in cells:
                continue
        # a hole = empty cell with floor on all 4 sides
        xs = [c[0] for c in cells]; zs = [c[1] for c in cells]
        for cx in range(min(xs), max(xs) + 1, 4):
            for cz in range(min(zs), max(zs) + 1, 4):
                if (cx, cz) not in cells:
                    nb = sum((cx + dx, cz + dz) in cells for dx, dz in [(4, 0), (-4, 0), (0, 4), (0, -4)])
                    if nb >= 4:
                        issues.append(f"FLOOR-HOLE interior gap at cell ~({cx},{cz})")

    return issues


def audit_links(ids):
    """Cross-area transition check: a portal's spawn must land AT the reciprocal
    doorway in the target area (within 5 m), never in the middle of the room —
    walking through a door and materialising at the far wall breaks the fiction
    that the world is one connected place."""
    issues = []
    defs = {aid: json.load(open(f"data/areas/{aid}.json")) for aid in ids}
    for aid, d in defs.items():
        for p in d.get("portals", []):
            to = p.get("to", "")
            if to not in defs:
                continue
            back = [q for q in defs[to].get("portals", []) if q.get("to") == aid]
            if not back:
                continue
            sx, sy, sz = v3(p.get("spawn", [0, 0, 0]))
            near = min(math.hypot(sx - v3(q["at"])[0], sz - v3(q["at"])[2]) for q in back)
            if near > 5.0:
                issues.append(f"FAR-SPAWN  {aid} -> {to}: spawn {p['spawn']} lands "
                              f"{near:.1f} m from the reciprocal doorway")
    return issues


def main():
    ids = [sys.argv[1]] if len(sys.argv) > 1 else \
        [os.path.basename(p)[:-5] for p in sorted(glob.glob("data/areas/*.json"))
         if os.path.basename(p) != "index.json"]
    total = 0
    for aid in ids:
        iss = audit(aid)
        if iss:
            print(f"[{aid}] {len(iss)} anomalies:")
            for s in iss:
                print("   " + s)
            total += len(iss)
        else:
            print(f"[{aid}] clean")
    if len(ids) > 1:
        link_issues = audit_links(ids)
        for s in link_issues:
            print("   " + s)
        total += len(link_issues)
        if not link_issues:
            print("[transitions] clean")
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
