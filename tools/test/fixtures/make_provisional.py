#!/usr/bin/env python3
"""Provisional starting saves for the full-game region walks.

Each region's walk (tools/test/fullgame_<region>_test.gd) starts from the
save the previous region's walk ends on. Until those exist, this writes a
stand-in from the slice's save and the data files: the state a player is in
who has finished the earlier regions (holdfast released, hearths lit, both
Keepsakes threads closed, the drops in the Pack, a few more levels).

    tools/test/fixtures/make_provisional.py <region>

writes tools/test/fixtures/fullgame_start_<region>_provisional.json.
One function per region below, keyed by the argument.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))


def _data(rel):
    with open(os.path.join(ROOT, "data", rel)) as f:
        return json.load(f)


def _base():
    with open(os.path.join(HERE, "fullgame_after_saltfell.json")) as f:
        return json.load(f)


def _give(save, item, n=1):
    inv = save["player"]["inventory"]
    inv[item] = float(inv.get(item, 0) + n)
    # a newly won arm seats itself in the first open hand-slot (Player.give_item)
    hb = save["player"]["hotbar"]
    if item in _data("combat/weapons.json") and item not in hb and "" in hb:
        hb[hb.index("")] = item


def _take(save, item):
    inv = save["player"]["inventory"]
    if inv.get(item, 0) <= 1:
        inv.pop(item, None)
    else:
        inv[item] -= 1


def _levels(save, stats):
    """One level per stat named (RestUI._buy_stat: +1 attribute, +1 level)."""
    p = save["player"]
    for s in stats:
        p["attributes"][s] += 1
        p["level"] += 1


def finish_region(save, aid, threads, last_hearth, grow):
    """The region `aid` played to its end: every pickup taken, its people
    met and their errands closed, the Holdfast released, left in THAW."""
    area = _data("areas/%s.json" % aid)
    enemies = _data("combat/enemies.json")
    npcs = _data("npcs.json")
    flags = save["flags"]
    aflags = {}
    for h in area.get("hearths", []):
        aflags["lit_" + h["id"]] = True
    for g in area.get("gates") or []:
        aflags["gate_" + g["id"]] = True
    # the Holdfast (the spawner behind the veil) and what it leaves
    for sp in area.get("spawners", []):
        cfg = enemies.get(sp["enemy"], {})
        if not cfg.get("is_boss"):
            continue
        aflags["slain_" + sp.get("id", sp["enemy"])] = True
        flags[cfg["release_flag"]] = True
        for gid in cfg.get("release_gates", []):
            aflags["gate_" + gid] = True
        drop = cfg.get("release_drop", {})
        if drop:
            aflags["took_" + drop.get("pickup_id", "release_drop")] = True
            _give(save, drop["item"])
            if drop.get("set_flag"):
                flags[drop["set_flag"]] = True
    for pk in area.get("pickups", []):
        if aflags.get("took_" + pk["id"]):
            continue   # (the drop, where the area data carries it too)
        aflags["took_" + pk["id"]] = True
        if pk.get("item"):
            _give(save, pk["item"], int(pk.get("count", 1)))
        if pk.get("set_flag"):
            flags[pk["set_flag"]] = True
    # the people: met, first flags, errands closed by talking, free gifts,
    # and the lines the release turns (their Keepsakes steps)
    for spec in area.get("npcs", []):
        nid = spec["id"]
        cfg = npcs[nid]
        if cfg.get("mute"):
            continue
        flags["met_" + nid] = True
        for f in cfg.get("first_flags", []):
            flags[f] = True
        for ex in cfg.get("on_talk", []):
            need = ex.get("needs_item", "")
            if need and save["player"]["inventory"].get(need, 0) < 1:
                continue
            if need and ex.get("take_item"):
                _take(save, need)
            if ex.get("reward_item"):
                _give(save, ex["reward_item"], int(ex.get("reward_count", 1)))
            if ex.get("set_flag"):
                flags[ex["set_flag"]] = True
        for w in cfg.get("lines_when", []):
            if w.get("set_flag") and flags.get(w.get("flag")):
                flags[w["set_flag"]] = True
        for sv in cfg.get("services", []):
            if sv.get("type") == "gift" and flags.get(sv.get("require_flag", "difficulty")):
                flags[sv["once_flag"]] = True
                _give(save, sv["item"])
    # every step of the region's threads must have come out of the above
    for t in _data("keepsakes.json")["threads"]:
        if t["id"] in threads:
            for s in t["steps"]:
                assert flags.get(s["flag"]), "%s: %s not reached" % (aid, s["flag"])
    save["areas"][aid] = {"cleared": True, "flags": dict(sorted(aflags.items())), "state": 0}
    _levels(save, grow)
    hearth = [h for h in area["hearths"] if h["id"] == last_hearth][0]
    save["last_hearth"] = {"area": aid, "hearth": last_hearth}
    save["player"]["pos"] = [float(v) for v in hearth["at"]]
    save["meta"]["area"] = aid
    save["meta"]["level"] = save["player"]["level"]
    save["play_s"] += 1500.0
    save["meta"]["play_s"] = save["play_s"]
    save["flags"] = dict(sorted(flags.items()))
    return save


def _after_lowe(save):
    return finish_region(save, "lowe_barrows", ["hesk_tongs", "aud_cord"], "hs_open_barrow",
                         ["heart", "might", "wind"])


def _after_kettle(save):
    return finish_region(save, "kettle_fjord", ["ivo_mitten", "halla_cord"], "hs_fish_houses",
                         ["heart", "might", "wind"])


def tarnhall():
    """Tarnhall starts after the Lowe and Kettle Fjord, at the Fish-Houses."""
    return _after_kettle(_after_lowe(_base()))


REGIONS = {
    "tarnhall": tarnhall,
}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in REGIONS:
        sys.exit("usage: make_provisional.py <%s>" % "|".join(sorted(REGIONS)))
    region = sys.argv[1]
    out = os.path.join(HERE, "fullgame_start_%s_provisional.json" % region)
    with open(out, "w") as f:
        json.dump(REGIONS[region](), f, indent="\t", sort_keys=True)
        f.write("\n")
    print("wrote", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    main()
