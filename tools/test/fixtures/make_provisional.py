#!/usr/bin/env python3
"""Provisional starting saves for the full-game region walks.

Each region's walk (tools/test/fullgame_<region>_test.gd) starts from the
save the previous region's walk ends on (fullgame_after_<previous>.json).
Until those exist, this writes a stand-in: the save the slice walk ends on
(fullgame_after_saltfell.json; for the Coldwell, the save the Thornwold
walk ends on) with the regions between played forward on paper, straight from the data files (hearths lit, Holdfasts released, the
Keepsakes threads closed, what was picked up taken, a few levels bought).

    python3 tools/test/fixtures/make_provisional.py thornwold

writes tools/test/fixtures/fullgame_start_<region>_provisional.json.
One function per region, keyed by the argument."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))


def data(rel):
    return json.load(open(os.path.join(ROOT, "data", rel)))


def base_save():
    return json.load(open(os.path.join(HERE, "fullgame_after_saltfell.json")))


# Which Keepsakes threads belong to which region (data/keepsakes.json ids).
THREADS = {
    "lowe_barrows": ["hesk_tongs", "aud_cord"],
    "kettle_fjord": ["ivo_mitten", "halla_cord"],
    "tarnhall": ["guest_tally", "ottar_stick"],
    "shepherds_reach": ["calder_boots"],
}
# The souls a player speaks with on the way through (met_<id>).
MET = {
    "lowe_barrows": ["aud", "hesk"],
    "kettle_fjord": ["ivo", "halla", "sten"],
    "tarnhall": ["lusse", "ottar"],
    "shepherds_reach": ["old_calder", "sigga"],
}
# What stays in the Pack once the threads are closed: the Holdfast's drop
# (unless a thread hands it on) and the gifts the threads give.
KEPT = {
    "lowe_barrows": {"item_tally_stick": 1},
    "kettle_fjord": {},                      # Ivo takes the mitten back
    "tarnhall": {"item_host_cup": 1, "goat_song": 1},
    # Calder is shown his boots and does not take them; the fold-tally is the
    # Fellcaller's drop; the whistle hangs on its nail in either memory
    "shepherds_reach": {"item_calder_boots": 1, "item_fold_tally": 1, "item_shepherd_whistle": 1},
}


def play_region(save, aid):
    """Mark one region as played through: cleared, in THAW, every hearth lit,
    its Holdfast released, its threads closed, its thread pickups taken."""
    area = data("areas/%s.json" % aid)
    enemies = data("combat/enemies.json")
    keepsakes = data("keepsakes.json")
    flags = {}
    for h in area.get("hearths", []):
        flags["lit_" + h["id"]] = True
    for g in area.get("gates") or []:
        flags["gate_" + g["id"]] = True
    thread_flags = set()
    for t in keepsakes["threads"]:
        if t["id"] in THREADS[aid]:
            for s in t["steps"]:
                thread_flags.add(s["flag"])
                save["flags"][s["flag"]] = True
    for p in area.get("pickups", []):
        if p.get("set_flag") in thread_flags:
            flags["took_" + p["id"]] = True
    for sp in area.get("spawners", []):
        cfg = enemies.get(sp["enemy"], {})
        if not cfg.get("is_boss"):
            continue
        flags["slain_" + sp["id"]] = True
        if cfg.get("release_flag"):
            save["flags"][cfg["release_flag"]] = True
        drop = cfg.get("release_drop", {})
        if drop:
            flags["took_" + drop.get("pickup_id", "release_drop")] = True
            if drop.get("set_flag"):
                save["flags"][drop["set_flag"]] = True
    for n in MET[aid]:
        save["flags"]["met_" + n] = True
    save["areas"][aid] = {"cleared": True, "flags": flags, "state": 0}
    inv = save["player"]["inventory"]
    for k, v in KEPT[aid].items():
        inv[k] = inv.get(k, 0) + v


def grow(save, levels, order=("heart", "might", "wind")):
    """Buy levels the way the hearth does: one attribute point each."""
    pl = save["player"]
    for i in range(levels):
        pl["attributes"][order[i % len(order)]] += 1
        pl["level"] += 1
    save["meta"]["level"] = pl["level"]


def rest_at(save, aid, hearth):
    area = data("areas/%s.json" % aid)
    h = [x for x in area["hearths"] if x["id"] == hearth][0]
    save["last_hearth"] = {"area": aid, "hearth": hearth}
    save["meta"]["area"] = aid
    save["player"]["pos"] = [h["at"][0], h["at"][1] + 0.2, h["at"][2]]


def lowe():
    """Before the Lowe: the slice's own ending."""
    return base_save()


def kettle():
    s = base_save()
    play_region(s, "lowe_barrows")
    grow(s, 2)
    rest_at(s, "lowe_barrows", "hs_open_barrow")
    return s


def tarnhall():
    s = base_save()
    for aid in ("lowe_barrows", "kettle_fjord"):
        play_region(s, aid)
    grow(s, 5)
    rest_at(s, "kettle_fjord", "hs_fish_houses")
    return s


def thornwold():
    """After the Lowe, Kettle Fjord and Tarnhall: at the Byres, the hearth
    nearest the drove-road out to Thornwold."""
    s = base_save()
    for aid in ("lowe_barrows", "kettle_fjord", "tarnhall"):
        play_region(s, aid)
    grow(s, 7)
    s["player"]["warmth"] = 600
    s["player"]["attuned_song"] = "goat_song"
    rest_at(s, "tarnhall", "hs_byres")
    return s


def coldwell():
    """After Shepherd's Reach, from the save the Thornwold walk really ends
    on (fullgame_after_thornwold.json): the Reach played forward on paper.
    At the High Fold, the hearth the Fellcaller's release wakes and the
    nearest to the Coldwell seam. Nothing is added that a walk of regions
    1-6 would not carry: the four knucklebones and the small mask at
    Saltfell are NOT here, because the slice walk does not pick them up."""
    s = json.load(open(os.path.join(HERE, "fullgame_after_thornwold.json")))
    play_region(s, "shepherds_reach")
    # Old Calder's second audience (REACH.md 7: he hums three notes), and
    # the whistle taken off its nail at the lower sheiling
    s["flags"]["ks_calder_hum"] = True
    s["flags"]["chapter_old_calder"] = 2
    s["areas"]["shepherds_reach"]["flags"]["took_shepherds_whistle"] = True
    grow(s, 2)
    rest_at(s, "shepherds_reach", "hs_high_fold")
    return s


REGIONS = {"lowe": lowe, "kettle": kettle, "tarnhall": tarnhall, "thornwold": thornwold, "coldwell": coldwell}

if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in REGIONS:
        sys.exit("usage: make_provisional.py <%s>" % "|".join(REGIONS))
    out = os.path.join(HERE, "fullgame_start_%s_provisional.json" % sys.argv[1])
    json.dump(REGIONS[sys.argv[1]](), open(out, "w"), indent="\t", sort_keys=True)
    open(out, "a").write("\n")
    print("wrote", out)
