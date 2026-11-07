extends Node
## DB — loads all data tables (the game-as-data layer). Read-only at runtime.

var tables: Dictionary = {}

func _enter_tree() -> void:
	_load_table("game", "res://data/game.json")
	_load_table("weapons", "res://data/combat/weapons.json")
	_load_table("movesets", "res://data/combat/movesets.json")
	_load_table("songs", "res://data/combat/songs.json")
	_load_table("enemies", "res://data/combat/enemies.json")
	_load_table("items", "res://data/items.json")
	_load_table("npcs", "res://data/npcs.json")
	_load_table("keepsakes", "res://data/keepsakes.json")
	_load_table("areas", "res://data/areas/index.json")

func _load_table(key: String, path: String) -> void:
	if not FileAccess.file_exists(path):
		tables[key] = {}
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("DB: failed to parse %s" % path)
		tables[key] = {}
	else:
		tables[key] = parsed

func table(name: String) -> Dictionary:
	return tables.get(name, {})

func song(id: String) -> Dictionary:
	return table("songs").get(id, {})

func weapon(id: String) -> Dictionary:
	return table("weapons").get(id, {})

func moveset(id: String) -> Dictionary:
	return table("movesets").get(id, {})

func enemy(id: String) -> Dictionary:
	return table("enemies").get(id, {})

func item(id: String) -> Dictionary:
	return table("items").get(id, {})

func npc(id: String) -> Dictionary:
	return table("npcs").get(id, {})

func area_def(id: String) -> Dictionary:
	var path := "res://data/areas/%s.json" % id
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	return parsed if parsed is Dictionary else {}

## Dotted-path tuning accessor into game.json, e.g. tuning("player/stamina/regen", 28.0)
func tuning(path: String, def = null):
	var cur = table("game")
	for part in path.split("/"):
		if cur is Dictionary and cur.has(part):
			cur = cur[part]
		else:
			return def
	return cur
