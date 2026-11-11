extends Node
## World — persistent world model: per-area thaw/rime state, flags, the
## pending Breathmark, last hearth, and save/load. Pure data; no scene logic.

signal area_state_changed(area_id: String, state: RH.WState)
## A global flag turned true for the first time (the Keepsakes toast listens).
signal flag_raised(name: String)

var areas: Dictionary = {}        # id -> {state:int, cleared:bool, flags:{}}
var flags: Dictionary = {}        # global story/npc flags
var breathmark = null            # {area:String, pos:Array[3], amount:int} or null
var last_hearth := {"area": "", "hearth": ""}
var player_data: Dictionary = {}  # written by Game on save
## The Journal's two settings: which thread is pinned, and whether the HUD
## shows its objective (src/core/journal.gd).
var journal: Dictionary = {"pin": "outsong", "tracker": true}
## What the Bearer has seen, for the Map (src/core/map_state.gd): regions
## walked into, Hearthstones come upon ("area/hearth_id"), frost veils seen
## (by area) and places found ("area/poi_id").
var map: Dictionary = {"regions": {}, "hearths": {}, "veils": {}, "places": {}}

var _save_dir := "user://saves"

func _enter_tree() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-dir="):
			_save_dir = arg.get_slice("=", 1)

func _area(id: String) -> Dictionary:
	if not areas.has(id):
		areas[id] = {"state": RH.WState.THAW, "cleared": false, "flags": {}}
	return areas[id]

func get_area_state(id: String) -> RH.WState:
	var e := ended()
	if e == "outsong":
		return RH.WState.THAW    # open water, bare ground; nobody in it (see spring())
	if e == "hearth_kept":
		return RH.WState.THAW if id == KEPT_AREA else RH.WState.RIME
	return _area(id)["state"] as RH.WState

# ---------------- the endings (COLDWELL.md 10, ADR 0013) ----------------
## Where the Bearer sits if the coal is kept.
const KEPT_AREA := "coldwell"

## "" while the winter lasts, else "outsong" or "hearth_kept". One flag each
## (set by the choice at the wellhead), so a save carries it as it carries
## every other flag.
func ended() -> String:
	if flag("ending_outsong"):
		return "outsong"
	if flag("ending_hearth_kept"):
		return "hearth_kept"
	return ""

## After the Outsong: true spring. Every area is its unfrozen ground under a
## grey sky (the "spring" light profile), with nobody remembered in it, no
## frost-taken, and hearths that cannot be warmed. The remembered evening is
## closed for good: there is no state left to turn to.
func spring() -> bool:
	return flag("ending_outsong")

## The coal kept: the Bearer sits at the spring in the remembered Melt, and
## everywhere else stays frozen.
func kept() -> bool:
	return flag("ending_hearth_kept")

func set_area_state(id: String, s: RH.WState) -> void:
	if ended() != "":
		return   # nothing turns any more
	var a := _area(id)
	if a["state"] == s:
		return
	a["state"] = s
	area_state_changed.emit(id, s)

func is_cleared(id: String) -> bool:
	return _area(id)["cleared"]

func set_cleared(id: String, v := true) -> void:
	_area(id)["cleared"] = v

func area_flag(id: String, flag: String) -> bool:
	return _area(id)["flags"].get(flag, false)

func set_area_flag(id: String, flag: String, v := true) -> void:
	_area(id)["flags"][flag] = v

func flag(name: String) -> bool:
	return flags.get(name, false)

func flag_val(name: String, def = null):
	return flags.get(name, def)

func set_flag(name: String, v = true) -> void:
	var was = flags.get(name, false)
	flags[name] = v
	if not was and v is bool and v:
		flag_raised.emit(name)

func set_breathmark(area: String, pos: Vector3, amount: int) -> void:
	breathmark = {"area": area, "pos": [pos.x, pos.y, pos.z], "amount": amount}

func clear_breathmark() -> void:
	breathmark = null

func breathmark_pos() -> Vector3:
	if breathmark == null:
		return Vector3.ZERO
	var p = breathmark["pos"]
	return Vector3(p[0], p[1], p[2])

# ---------------- persistence ----------------

## Three hearths may be kept at once. Each slot file carries a small meta
## ledger (level, quarter, difficulty, hours walked) for the title's picker.
const SLOTS := 3
var active_slot := 1
var play_s := 0.0   # real seconds walked this playthrough (Game accumulates)

## The save format's version. Bump it with a step in migrate() whenever a
## save's shape changes; old slots are upgraded as they load.
##   1: the first format (written as "version": 1, before save_version)
##   2: save_version; the player wears armour (player.armour, slot -> id)
##   3: meta.ending ("" | "outsong" | "hearth_kept") for the title's slot
##      ledger; the endings themselves are flags, so nothing else moved
##   4: the Journal's pin and tracker switch ("journal") and the Map's
##      discovery ("map"). An older save's map is rebuilt from what it does
##      hold: areas it has entered, Hearthstones rested at, veils parted.
const SAVE_VERSION := 4

## Upgrade a parsed save of any older version to SAVE_VERSION, one step at a
## time. Returns the same Dictionary, upgraded in place; a newer save than
## this build knows is passed through untouched.
func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", data.get("version", 1)))
	if v < 2:
		# v1 -> v2: the Bearer had no armour slots; dress them in the
		# starting coat they would have begun with
		var pd: Dictionary = data.get("player", {})
		if not pd.is_empty() and not pd.has("armour"):
			pd["armour"] = Player.starting_armour()
		data["player"] = pd
		data.erase("version")
		v = 2
	if v < 3:
		var m: Dictionary = data.get("meta", {})
		m["ending"] = ""
		data["meta"] = m
		v = 3
	if v < 4:
		if not data.has("journal"):
			data["journal"] = {"pin": "outsong", "tracker": true}
		if not data.has("map"):
			data["map"] = _map_from_old(data)
		v = 4
	data["save_version"] = maxi(v, int(data.get("save_version", 0)))
	return data

## v3 -> v4: an old save never recorded what was seen, but it implies a good
## deal. Every area it has an entry for was walked into; a Hearthstone with
## a lit_ flag was rested at; a cleared area's veil was seen, and so was the
## veil of any area whose Holdfast was fought (its spawn flag is kept).
func _map_from_old(data: Dictionary) -> Dictionary:
	var m := {"regions": {}, "hearths": {}, "veils": {}, "places": {}}
	var old_areas: Dictionary = data.get("areas", {})
	for id in old_areas:
		var a: Dictionary = old_areas[id]
		var af: Dictionary = a.get("flags", {})
		var touched := bool(a.get("cleared", false)) or not af.is_empty() or int(a.get("state", 0)) != 0
		for f in af:
			if String(f).begins_with("lit_") and bool(af[f]):
				m["hearths"]["%s/%s" % [id, String(f).trim_prefix("lit_")]] = true
		if touched:
			m["regions"][id] = true
		if bool(a.get("cleared", false)):
			m["veils"][id] = true
	var lh: Dictionary = data.get("last_hearth", {}) if data.get("last_hearth", null) is Dictionary else {}
	if String(lh.get("area", "")) != "":
		m["regions"][String(lh["area"])] = true
		if String(lh.get("hearth", "")) != "":
			m["hearths"]["%s/%s" % [lh["area"], lh["hearth"]]] = true
	return m

func save_path() -> String:
	return _save_dir.path_join("slot_%d.json" % active_slot)

## The single-file era becomes slot 1.
func migrate_legacy_save() -> void:
	var legacy := _save_dir.path_join("hearth.json")
	var s1 := _save_dir.path_join("slot_1.json")
	if FileAccess.file_exists(legacy) and not FileAccess.file_exists(s1):
		DirAccess.rename_absolute(legacy, s1)

func any_slot() -> bool:
	for i in range(1, SLOTS + 1):
		if FileAccess.file_exists(_save_dir.path_join("slot_%d.json" % i)):
			return true
	return false

## null for an empty slot, else {slot, level, area, difficulty, play_s}.
func slot_summary(i: int):
	var path := _save_dir.path_join("slot_%d.json" % i)
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	if not (parsed is Dictionary):
		return null
	var m: Dictionary = parsed.get("meta", {})
	return {
		"slot": i,
		"level": int(m.get("level", parsed.get("player", {}).get("level", 1))),
		"area": String(m.get("area", parsed.get("last_hearth", {}).get("area", ""))),
		"difficulty": String(m.get("difficulty", parsed.get("flags", {}).get("difficulty", "long"))),
		"play_s": float(m.get("play_s", 0.0)),
		"ending": String(m.get("ending", "")),
	}

func delete_slot(i: int) -> void:
	var path := _save_dir.path_join("slot_%d.json" % i)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func save_game() -> void:
	# a save is the whole truth: refresh the wayfarer's ledger before writing.
	# Without this, a pickup-triggered save pairs its new world flags
	# (took_...) with a player snapshotted at some earlier rest — quit and
	# continue would then find the cache consumed AND the item gone.
	if Game.player != null and is_instance_valid(Game.player):
		Game.snapshot_player()
	DirAccess.make_dir_recursive_absolute(_save_dir)
	var data := {
		"save_version": SAVE_VERSION,
		"areas": areas,
		"flags": flags,
		"breathmark": breathmark,
		"last_hearth": last_hearth,
		"player": player_data,
		"play_s": play_s,
		"journal": journal,
		"map": map,
		"meta": {
			"level": int(player_data.get("level", 1)),
			"area": last_hearth.get("area", ""),
			"difficulty": str(flag_val("difficulty", "long")),
			"saved_at": Time.get_unix_time_from_system(),
			"play_s": play_s,
			"ending": ended(),
		},
	}
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))

func has_save() -> bool:
	return FileAccess.file_exists(save_path())

func load_game() -> bool:
	if not has_save():
		return false
	var parsed = JSON.parse_string(FileAccess.open(save_path(), FileAccess.READ).get_as_text())
	if not (parsed is Dictionary):
		return false
	parsed = migrate(parsed)
	areas = {}
	# JSON round-trips ints as floats; normalize.
	for id in parsed.get("areas", {}):
		var a = parsed["areas"][id]
		areas[id] = {"state": int(a.get("state", 0)), "cleared": bool(a.get("cleared", false)), "flags": a.get("flags", {})}
	flags = parsed.get("flags", {})
	breathmark = parsed.get("breathmark", null)
	if breathmark != null:
		breathmark["amount"] = int(breathmark.get("amount", 0))
	last_hearth = parsed.get("last_hearth", {"area": "", "hearth": ""})
	player_data = parsed.get("player", {})
	play_s = float(parsed.get("play_s", 0.0))
	journal = {"pin": "outsong", "tracker": true}
	journal.merge(parsed.get("journal", {}), true)
	map = {"regions": {}, "hearths": {}, "veils": {}, "places": {}}
	var pm: Dictionary = parsed.get("map", {})
	for k in map:
		if pm.get(k, null) is Dictionary:
			map[k] = pm[k]
	return true

func reset() -> void:
	play_s = 0.0
	areas = {}
	flags = {}
	breathmark = null
	last_hearth = {"area": "", "hearth": ""}
	player_data = {}
	journal = {"pin": "outsong", "tracker": true}
	map = {"regions": {}, "hearths": {}, "veils": {}, "places": {}}
