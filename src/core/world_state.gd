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
	return _area(id)["state"] as RH.WState

func set_area_state(id: String, s: RH.WState) -> void:
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
const SAVE_VERSION := 2

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
	data["save_version"] = maxi(v, int(data.get("save_version", 0)))
	return data

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
		"meta": {
			"level": int(player_data.get("level", 1)),
			"area": last_hearth.get("area", ""),
			"difficulty": str(flag_val("difficulty", "long")),
			"saved_at": Time.get_unix_time_from_system(),
			"play_s": play_s,
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
	return true

func reset() -> void:
	play_s = 0.0
	areas = {}
	flags = {}
	breathmark = null
	last_hearth = {"area": "", "hearth": ""}
	player_data = {}
