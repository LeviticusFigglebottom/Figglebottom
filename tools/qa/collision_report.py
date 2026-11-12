#!/usr/bin/env python3
"""Markdown tables for docs/qa/COLLISION_AUDIT.md from the collision audit's
JSON (tools/audit_collision.sh --collision-out=/abs/out.json).

Usage: python3 tools/qa/collision_report.py out.json > tables.md"""
import collections
import json
import sys

ORDER = ["walk_through", "partial", "invisible", "floating", "unbacked_floor", "void", "terrain_collider",
         "terrain_edge", "seam", "spawn", "threshold"]


def vol(o):
    s = o["size"]
    return s[0] * s[1] * s[2]


def main():
    d = json.load(open(sys.argv[1]))
    print("### Counts per area and pass\n")
    print("| area | pass | " + " | ".join(ORDER) + " |")
    print("|---|---|" + "---:|" * len(ORDER))
    for area, passes in d["counts"].items():
        for pn, c in passes.items():
            print("| %s | %s | %s |" % (area, pn, " | ".join(str(c.get(k, "")) for k in ORDER)))
    groups = collections.OrderedDict()
    for o in d["offenders"]:
        groups.setdefault((o["area"], o["check"], o["id"], o["owner"], o["fix"]), []).append(o)
    print("\n### Offenders (grouped: one row per area, kind and thing)\n")
    print("| area | kind | what | n | passes | largest (m) | where (x, y, z) | probable fix | owner |")
    print("|---|---|---|---:|---|---|---|---|---|")
    for (area, chk, ident, owner, fix), items in groups.items():
        items.sort(key=vol, reverse=True)
        passes = sorted({p for o in items for p in o["passes"]})
        where = "; ".join("%.0f, %.0f, %.0f" % tuple(o["pos"]) for o in items[:6]) + (" ..." if len(items) > 6 else "")
        big = items[0]["size"]
        print("| %s | %s | `%s` | %d | %s | %.1f x %.1f x %.1f | %s | %s | %s |" % (
            area, chk, ident, len(items), ", ".join(passes), big[0], big[1], big[2], where, fix, owner))
    print("\n### Every offender\n")
    print("| area | kind | what | x, y, z | size (m) | passes | finding |")
    print("|---|---|---|---|---|---|---|")
    for o in d["offenders"]:
        print("| %s | %s | `%s` | %.1f, %.1f, %.1f | %.1f x %.1f x %.1f | %s | %s |" % (
            o["area"], o["check"], o["id"], o["pos"][0], o["pos"][1], o["pos"][2], o["size"][0], o["size"][1], o["size"][2],
            ", ".join(o["passes"]), o["detail"]))


if __name__ == "__main__":
    main()
