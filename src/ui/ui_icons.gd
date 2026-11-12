class_name UIIcons
extends RefCounted
## Where every screen finds an icon. The set is painted, cut to 256 px by
## tools/ui/build_icons.py into assets/ui/icons/. An id resolves, in order:
## an "icon" field on its data row (items, weapons or songs), the table
## below, a file named for the id, a file named for the id without its
## item_/ks_ prefix, then the plain bundle. So a new item needs no code:
## name its icon file after it, or give its row an "icon".

const DIR := "res://assets/ui/icons/"
const FALLBACK := "relic"

const BY := {
	"sealer_harpoon": "harpoon", "feast_cleaver": "cleaver", "hedging_bill": "bill",
	"saltfell_shield": "shield",
	"mend": "song_mend", "ember_throw": "song_ember_throw", "hearth_shout": "song_hearth_shout",
	"long_note": "song_long_note", "warding_hum": "song_warding_hum",
	"turf_song": "song_turf", "goat_song": "song_goat",
	"item_mending_needle": "needle", "ks_child_mask": "mask",
	"armour_traveller_coat": "armour_coat", "armour_saltfell_oilskins": "armour_oilskins",
	"armour_barrow_cloak": "armour_cloak",
	"item_tally_stick": "tally", "item_twin_spindles": "spindles", "item_orm_cord": "knot_cord",
	"item_hesk_tongs": "tongs", "item_kettle_ladle": "ladle", "item_ottar_staff": "stick",
	"item_calder_boots": "boots", "item_shepherd_whistle": "whistle",
	"item_wren_band": "woad_band", "item_maren_mask": "bare_mask",
}

static func path_for(id: String) -> String:
	var named := ""
	for table in ["items", "weapons", "songs"]:
		var row: Variant = DB.table(table).get(id, null)
		if row is Dictionary and String(row.get("icon", "")) != "":
			named = String(row["icon"])
	for c in [named, String(BY.get(id, "")), id, id.trim_prefix("item_").trim_prefix("ks_")]:
		if c != "" and ResourceLoader.exists(DIR + c + ".png"):
			return DIR + c + ".png"
	if not DB.song(id).is_empty():
		return DIR + "song.png"
	return DIR + FALLBACK + ".png"

static func tex(id: String) -> Texture2D:
	return load(path_for(id)) as Texture2D

## A named icon that is not an item (crest, warmth, stat_heart, slot_head).
static func named(icon: String) -> Texture2D:
	var p := DIR + icon + ".png"
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
