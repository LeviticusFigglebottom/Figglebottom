#!/usr/bin/env python3
"""Progression gates (ADR 0015), shared by the area generators.

Each region's way on is shut by the thing its Holdfast keeps (Gunna's net,
Arne's stacked sods, the Host's bar ...) until that Holdfast is released. The
gate is a ShortcutGate (src/world/shortcut_gate.gd): real collision in both
states, opened by the release's world flag, and it can always be undone from
the far side, so nobody arriving from the next region is ever shut out of the
one behind.

`gate()` seats one across a neck of walkable land: it measures how far the
ground can be walked to either side of the road and closes that with the
region's own fabric (a dry-stone dyke, a row of peat stacks, boulders), so
nothing is an invisible wall. It also returns the `way_on` block the journal
and the map read (where the way on is, what opens it, what to call it).

Usage in a generator, inside its `# --- progression gates` block:

    G = PG.gate("saltfell_steading", "pass_net", T.sample, at=(-89.0, -75.5), toward=(0, -1), ...)
    D["gates"].append(G["gate"]); scatter["fences"] += G["fences"]; ...
"""
import math


def r2(v):
    return round(v, 2)


def install(D, G):
    """Put a gate() result into an area def: the gate, its flanks, the scatter
    kept clear of the opening, and the way_on block."""
    D.setdefault("gates", []).append(G["gate"])
    D.setdefault("way_on", []).append(G["way_on"])
    sc = D.setdefault("scatter", {})
    sc.setdefault("fences", []).extend(G["fences"])
    sc.setdefault("place", []).extend(G["place"])
    sc.setdefault("clear", []).extend(G["clear"])
    D.setdefault("blockers", []).extend(G.get("cores", []))


def _walkable(sample, x, z, floor=-0.9):
    h = sample(x, z)
    if h < floor:
        return False
    return max(abs(sample(x + a, z + b) - h) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))) <= 1.0


def span(sample, cx, cz, nx, nz, reach=30.0, step=0.5, blocked=None, floor=-0.9):
    """How far the land can be walked to either side of (cx, cz) along the
    line (nx, nz): (lo, hi), lo <= 0 <= hi. `blocked(x, z)` adds what the
    heightmap does not know (a thicket, a house wall)."""
    def ok(t):
        x, z = cx + nx * t, cz + nz * t
        return _walkable(sample, x, z, floor) and not (blocked is not None and blocked(x, z))
    lo = 0.0
    while lo > -reach and ok(lo - step):
        lo -= step
    hi = 0.0
    while hi < reach and ok(hi + step):
        hi += step
    return lo, hi


def gate(area_id, gate_id, sample, at, toward, flag, name, to, seam_at, width=3.6, height=2.5, depth=0.14,
         flank="drystone", flank_tag="base", dressing=(), leaves=False, locked_prompt="Tied from the other side",
         unbar_prompt="Untie it", open_toast="The way stands open.", ext=2.5, max_span=22.0, blocked=None,
         flank_scale=1.0, hint="", posts=None, post_scale=1.0, floor=-0.9):
    """One progression gate.

    at       (x, z) on the road, where the opening is
    toward   (dx, dz) along the road toward the seam (the far side)
    flank    "drystone" | "wattle" | "peat_stack" | "boulder" | None: what
             closes the walkable ground either side of the opening
    dressing pieces as ShortcutGate.dress reads them, but with "along" (m
             along the gate line) and "out" (m toward the near side) in place
             of "offset": each is seated on the ground where it stands
    Returns {"gate", "fences", "place", "clear", "way_on", "span"}."""
    cx, cz = at
    ln = math.hypot(*toward)
    ux, uz = toward[0] / ln, toward[1] / ln
    rot = math.degrees(math.atan2(-ux, -uz))       # local -z looks at the far side
    a = math.radians(rot)
    lx, lz = math.cos(a), -math.sin(a)             # the gate's local +x in the world
    y0 = sample(cx, cz)
    half = width * 0.5
    lo, hi = span(sample, cx, cz, lx, lz, blocked=blocked, floor=floor)
    assert hi - lo <= max_span, f"{gate_id}: the neck is {hi - lo:.1f} m wide here; pick a narrower place"

    fences, place, cores = [], [], []
    for sgn, end in ((-1, lo), (1, hi)):
        t0, t1 = half + (0.9 if posts else 0.1), abs(end) + ext
        if flank is None or t1 - t0 < 0.4:
            continue
        if flank in ("drystone", "wattle"):
            n = max(1, int(math.ceil((t1 - t0) / 2.0)))
            pts = [[r2(cx + lx * sgn * (t0 + (t1 - t0) * k / n)), r2(cz + lz * sgn * (t0 + (t1 - t0) * k / n))]
                   for k in range(n + 1)]
            f = {"kind": flank, "points": pts}
            if flank_tag != "base":
                f["tag"] = flank_tag
            fences.append(f)
        else:
            pitch = {"peat_stack": 1.4, "boulder": 1.5}[flank] * flank_scale
            t = t0 + pitch * 0.45
            k = 0
            while t < t1 + pitch * 0.5:
                jz = 0.25 * math.sin(k * 2.3 + sgn)
                p = {"kind": flank, "at": [r2(cx + lx * sgn * t - ux * jz), r2(cz + lz * sgn * t - uz * jz)],
                     "rot": r2(rot + (7 * math.sin(k * 1.9 + sgn) if flank == "peat_stack" else k * 67 % 360)),
                     "scale": r2(flank_scale * (1.0 + (0.12 * math.sin(k * 3.1) if flank == "boulder" else 0.0)))}
                if flank_tag != "base":
                    p["tag"] = flank_tag
                place.append(p)
                if flank == "boulder":
                    # a boulder's collider is the hull of its rounded mesh: low
                    # enough that the navmesh baked a step over its top though
                    # nobody can climb it (Kettle, after the landing was widened).
                    # A tall core inside it keeps the routes where the feet are.
                    bx, bz = p["at"]
                    core = {"at": [bx, r2(sample(bx, bz) + 2.0), bz], "radius": r2(0.42 * p["scale"]), "height": 4.0}
                    if flank_tag != "base":
                        core["tag"] = flank_tag
                    cores.append(core)
                t += pitch
                k += 1

    for sgn in ((-1, 1) if posts else ()):
        place.append({"kind": posts, "at": [r2(cx + lx * sgn * (half + 0.45)), r2(cz + lz * sgn * (half + 0.45))],
                      "rot": r2(rot + 90 + sgn * 8), "scale": post_scale})

    dress = []
    for d in dressing:
        d = dict(d)
        al, out = d.pop("along", 0.0), d.pop("out", 0.0)
        wx, wz = cx + lx * al - ux * out, cz + lz * al - uz * out
        d["offset"] = [r2(al), r2(sample(wx, wz) - y0 + d.pop("lift", 0.0)), r2(out)]
        dress.append(d)

    g = {"id": gate_id, "at": [r2(cx), r2(y0), r2(cz)], "rot": r2(rot), "width": width, "height": height,
         "depth": depth, "leaves": leaves, "open_flag": flag, "locked_prompt": locked_prompt,
         "unbar_prompt": unbar_prompt, "open_toast": open_toast, "dressing": dress,
         # the walkable ground along the gate line, for tools/test/gates_test.gd
         "span": [r2(lo), r2(hi)]}
    way_on = {"id": gate_id, "name": name, "to": to, "at": [r2(cx), r2(y0), r2(cz)],
              "seam": [r2(v) for v in seam_at], "open_flag": flag, "gate": gate_id}
    if hint:
        way_on["hint"] = hint
    return {"gate": g, "fences": fences, "place": place, "cores": cores, "clear": [[r2(cx), r2(cz), r2(half + 1.6)]],
            "way_on": way_on, "span": (lo, hi), "rot": rot, "line": (lx, lz)}
