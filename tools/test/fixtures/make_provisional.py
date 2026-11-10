#!/usr/bin/env python3
"""Provisional starting saves for the full-game region walks.

The real chain: each region's walk (tools/test/fullgame_<region>_test.gd)
starts from the save the previous region's walk ends on
(fullgame_after_<previous>.json). Until the previous walk exists, this writes
the save a player would plausibly hold on reaching a region:
fullgame_start_<region>_provisional.json, built from fullgame_after_saltfell
and the data files. One function per region, keyed by the argument.

Run: python3 tools/test/fixtures/make_provisional.py kettle"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
THAW = 0   # RH.WState.THAW


def data(rel):
    return json.load(open(os.path.join(ROOT, "data", rel)))


def base_save():
    return json.load(open(os.path.join(HERE, "fullgame_after_saltfell.json")))


def write(region, save):
    out = os.path.join(HERE, "fullgame_start_%s_provisional.json" % region)
    json.dump(save, open(out, "w"), indent=1, sort_keys=True)
    print("wrote", out)


def level_up(save, **points):
    """Spend levels: a level is one point in one attribute (Player.level)."""
    p = save["player"]
    for stat, n in points.items():
        p["attributes"][stat] += n
        p["level"] += n
    save["meta"]["level"] = p["level"]


def region_threads(area, npcs):
    """Keepsakes threads that belong to an area: any step flag raised by one
    of its NPCs or pickups, or by its Holdfast's release."""
    raised = set()
    for n in area.get("npcs", []):
        cfg = npcs.get(n["id"], {})
        raised.update(cfg.get("first_flags", []))
        for rule in cfg.get("on_talk", []) + cfg.get("lines_when", []):
            if rule.get("set_flag"):
                raised.add(rule["set_flag"])
    for pk in area.get("pickups", []):
        if pk.get("set_flag"):
            raised.add(pk["set_flag"])
    out = []
    for t in data("keepsakes.json")["threads"]:
        if any(s["flag"] in raised for s in t["steps"]):
            out.append(t)
    return out


def finish_region(save, aid, last_hearth_near=None, extra_took=()):
    """Mark an area as a player leaves it done: cleared, in THAW, every
    hearth lit, the Holdfast released and its drop taken, both Keepsakes
    threads whole (the items found, handed over and gone from the Pack),
    everyone met. Returns the area def."""
    area = data("areas/%s.json" % aid)
    npcs = data("npcs.json")
    enemies = data("combat/enemies.json")
    inv = save["player"]["inventory"]
    flags = save["flags"]
    af = {}
    for h in area.get("hearths", []):
        af["lit_" + h["id"]] = True
    for sp in area.get("spawners", []):
        cfg = enemies.get(sp["enemy"], {})
        if not cfg.get("is_boss"):
            continue
        af["slain_" + sp.get("id", sp["enemy"])] = True
        if cfg.get("release_flag"):
            flags[cfg["release_flag"]] = True
        drop = cfg.get("release_drop", {})
        if drop.get("item"):
            af["took_" + drop.get("pickup_id", "release_drop")] = True
            inv[drop["item"]] = inv.get(drop["item"], 0) + 1
            if drop.get("set_flag"):
                flags[drop["set_flag"]] = True
        for gid in cfg.get("release_gates", []):
            af["gate_" + gid] = True
    for n in area.get("npcs", []):
        cfg = npcs.get(n["id"], {})
        if not cfg.get("mute") and cfg.get("lines_first"):
            flags["met_" + n["id"]] = True
    thread_flags = set()
    for t in region_threads(area, npcs):
        for s in t["steps"]:
            flags[s["flag"]] = True
            thread_flags.add(s["flag"])
    # the thread items: found (took_), then handed over (on_talk take_item)
    handed = set()
    for n in area.get("npcs", []):
        for rule in npcs.get(n["id"], {}).get("on_talk", []):
            if rule.get("take_item") and rule.get("needs_item"):
                handed.add(rule["needs_item"])
                if rule.get("reward_item"):
                    inv[rule["reward_item"]] = inv.get(rule["reward_item"], 0) + int(rule.get("reward_count", 1))
    for pk in area.get("pickups", []):
        mine = pk.get("set_flag") in thread_flags or pk.get("item") in handed or pk["id"] in extra_took
        if not mine:
            continue
        af["took_" + pk["id"]] = True
        if pk.get("set_flag"):
            flags[pk["set_flag"]] = True
        item = pk.get("item", "")
        if item and item not in handed:
            inv[item] = inv.get(item, 0) + int(pk.get("count", 1))
    save["areas"][aid] = {"cleared": True, "state": THAW, "flags": af}
    if last_hearth_near is not None:
        best = min(area["hearths"], key=lambda h: math.hypot(h["at"][0] - last_hearth_near[0], h["at"][2] - last_hearth_near[1]))
        save["last_hearth"] = {"area": aid, "hearth": best["id"]}
        save["player"]["pos"] = [best["at"][0], best["at"][1] + 0.3, best["at"][2]]
        save["meta"]["area"] = aid
    return area


def after_lowe(save):
    """The Lowe done (LOWE.md): the Turfwright released, the tally-stick and
    the spindles in the Pack, Hesk's tongs and Orm's cord home, the bridge
    down, two more levels. `near` picks the hearth to wake at."""
    save["flags"]["lowe_bridge_down"] = True   # drawbridge.gd: a world flag
    level_up(save, heart=1, might=1)
    save["player"]["warmth"] = 1200
    return save


def kettle():
    """Kettle Fjord starts from the Lowe done, at the Lowe hearth nearest
    the Kettle Road seam."""
    save = after_lowe(base_save())
    lowe = data("areas/lowe_barrows.json")
    seam = [p for p in lowe["portals"] if p["to"] == "kettle_fjord"][0]["at"]
    finish_region(save, "lowe_barrows", last_hearth_near=(seam[0], seam[2]), extra_took=("twin_spindles",))
    return save


REGIONS = {"kettle": kettle}

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in REGIONS:
        sys.exit("usage: make_provisional.py {%s}" % "|".join(sorted(REGIONS)))
    write(sys.argv[1], REGIONS[sys.argv[1]]())
