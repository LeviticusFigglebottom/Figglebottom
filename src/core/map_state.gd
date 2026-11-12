class_name MapState
extends RefCounted
## What the Map knows. The base images are baked from the terrain
## (tools/ui/build_map.py -> data/map.json); everything on top of them is
## worked out here from the area data and the save: which regions have been
## walked into, which Hearthstones come upon, which frost veils seen, which
## places found (World.map), and so which markers the Map may draw.

const HEARTH_SIGHT := 18.0   # metres: a Hearthstone is marked once this near
const VEIL_SIGHT := 30.0
const PLACE_SIGHT := 8.0     # a wayside board

static var _meta: Dictionary = {}

static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists("res://data/map.json"):
		var parsed = JSON.parse_string(FileAccess.open("res://data/map.json", FileAccess.READ).get_as_text())
		if parsed is Dictionary:
			_meta = parsed
	return _meta

static func regions() -> Array:
	return meta().get("order", [])

static func region(id: String) -> Dictionary:
	return (meta().get("regions", {}) as Dictionary).get(id, {})

# ---------------------------------------------------------------- discovery

static func _mark(group: String, key: String) -> bool:
	if not World.map.has(group):
		World.map[group] = {}
	if World.map[group].has(key):
		return false
	World.map[group][key] = true
	return true

static func region_seen(id: String) -> bool:
	return bool((World.map.get("regions", {}) as Dictionary).get(id, false))

static func hearth_seen(area: String, hearth: String) -> bool:
	return bool((World.map.get("hearths", {}) as Dictionary).get("%s/%s" % [area, hearth], false)) \
		or World.area_flag(area, "lit_" + hearth)

static func veil_seen(area: String) -> bool:
	return bool((World.map.get("veils", {}) as Dictionary).get(area, false)) or World.is_cleared(area)

static func place_seen(area: String, id: String) -> bool:
	return bool((World.map.get("places", {}) as Dictionary).get("%s/%s" % [area, id], false))

static func _ok(spec: Dictionary) -> bool:
	if String(spec.get("require_flag", "")) != "" and not World.flag(String(spec["require_flag"])):
		return false
	if String(spec.get("absent_flag", "")) != "" and World.flag(String(spec["absent_flag"])):
		return false
	return true

## The named places of an area: its zones (found by walking into them) and
## its wayside boards (found by coming up to them; a board is named by its
## first line). [{id, name, pos (Vector2), zone: {min, max} or null}]; a
## board also has `tags`, the states its texts are tagged for.
static var _places := {}

static func places_def(area: String) -> Array:
	if not _places.has(area):
		_places[area] = _build_places(area)
	return _places[area]

static func _build_places(area: String) -> Array:
	var def := DB.area_def_ro(area)
	var out := []
	var names := {}
	for z in def.get("zones", []):
		var mn: Array = z["min"]
		var mx: Array = z["max"]
		var nm := HUD._caps_case(String(z.get("name", "")))
		names[nm.to_lower()] = true
		out.append({"id": "zone:" + String(z.get("name", "")), "name": nm,
			"pos": Vector2((float(mn[0]) + float(mx[0])) * 0.5, (float(mn[1]) + float(mx[1])) * 0.5),
			"zone": {"min": Vector2(float(mn[0]), float(mn[1])), "max": Vector2(float(mx[0]), float(mx[1]))}})
	var region_name := String(def.get("name", "")).to_lower()
	# (a Hearthstone's mark carries its name already: a board beside it with
	# the same name would write it on the sheet twice)
	for h in def.get("hearths", []):
		names[HUD._caps_case(String(h.get("name", "")).to_upper()).to_lower()] = true
	var boards := {}     # name -> its place: one board may carry a THAW text and a RIME text
	for pl in def.get("plaques", []):
		var first := String(pl.get("text", "")).get_slice("\n", 0).strip_edges()
		var nm := HUD._caps_case(first)
		var tag := String(pl.get("tag", "base"))
		if boards.has(nm.to_lower()):
			(boards[nm.to_lower()]["tags"] as Array).append(tag)
			continue
		# a board that only names the region, a zone or a Hearthstone adds no place of its own
		if first == "" or names.has(nm.to_lower()) or nm.to_lower() == region_name:
			continue
		names[nm.to_lower()] = true
		var at: Array = pl.get("at", [0, 0, 0])
		var place := {"id": "board:" + first, "name": nm, "pos": Vector2(float(at[0]), float(at[2])), "zone": null, "tags": [tag]}
		boards[nm.to_lower()] = place
		out.append(place)
	return out

## Whether a board stands to be read in the area's state now: one tagged
## `rime` is not there in THAW, and a place cannot be found by a board that
## is not there.
static func _board_stands(area: String, pl: Dictionary) -> bool:
	var now := "rime" if World.get_area_state(area) == RH.WState.RIME else "thaw"
	var tags: Array = pl.get("tags", ["base"])
	return tags.has("base") or tags.has(now)

## Called as the Bearer walks (HUD, twice a second): marks what is now
## within sight. Returns true when something new was found.
static func scout(area: String, pos: Vector3) -> bool:
	if area == "" or DB.area_def_ro(area).is_empty():
		return false
	var found := _mark("regions", area)
	var def := DB.area_def_ro(area)
	var here := Vector2(pos.x, pos.z)
	for h in def.get("hearths", []):
		var at: Array = h.get("at", [0, 0, 0])
		if _ok(h) and here.distance_to(Vector2(float(at[0]), float(at[2]))) <= HEARTH_SIGHT:
			found = _mark("hearths", "%s/%s" % [area, String(h.get("id", ""))]) or found
	# a frost veil only stands in RIME
	if World.get_area_state(area) == RH.WState.RIME:
		for v in def.get("frost_veils", []):
			var at: Array = v.get("at", [0, 0, 0])
			if here.distance_to(Vector2(float(at[0]), float(at[2]))) <= VEIL_SIGHT:
				found = _mark("veils", area) or found
	for pl in places_def(area):
		var hit := false
		if pl["zone"] != null:
			var z: Dictionary = pl["zone"]
			hit = here.x >= z["min"].x and here.x <= z["max"].x and here.y >= z["min"].y and here.y <= z["max"].y
		else:
			hit = here.distance_to(pl["pos"]) <= PLACE_SIGHT and _board_stands(area, pl)
		if hit:
			found = _mark("places", "%s/%s" % [area, pl["id"]]) or found
	return found

# ---------------------------------------------------------------- markers

## Every marker the Map may show now, for one area ("" = all discovered
## areas). Each is {kind, area, pos (Vector2 world x,z), ...}:
##   hearth  {id, name, rested, last}     come upon; rested at; the last one
##   veil    {released}                   the frost veil, once seen
##   seam    {to, to_name, label, known}  a way to the next region
##   place   {name}                       a found place
##   bearer  {yaw}                        where the Bearer stands, and facing
##   pin     {title}                      the pinned objective, when its place is known
static func markers(only_area := "") -> Array:
	var out := []
	for area in regions():
		if (only_area != "" and area != only_area) or not region_seen(area):
			continue
		var def := DB.area_def_ro(area)
		for h in def.get("hearths", []):
			var hid := String(h.get("id", ""))
			if not _ok(h) or not hearth_seen(area, hid):
				continue
			var at: Array = h.get("at", [0, 0, 0])
			out.append({"kind": "hearth", "area": area, "id": hid, "name": String(h.get("name", "")),
				"pos": Vector2(float(at[0]), float(at[2])),
				"rested": World.area_flag(area, "lit_" + hid),
				"last": String(World.last_hearth.get("area", "")) == area and String(World.last_hearth.get("hearth", "")) == hid})
		if veil_seen(area):
			for v in def.get("frost_veils", []):
				var at: Array = v.get("at", [0, 0, 0])
				out.append({"kind": "veil", "area": area, "pos": Vector2(float(at[0]), float(at[2])),
					"released": World.is_cleared(area)})
		var seen_to := {}
		for p in def.get("portals", []):
			var to := String(p.get("to", ""))
			var at: Array = p.get("at", [0, 0, 0])
			var labels: PackedStringArray = String((meta().get("graph", {}) as Dictionary).get(area, {}).get(to, "")).split("; ")
			var n := int(seen_to.get(to, 0))
			seen_to[to] = n + 1
			out.append({"kind": "seam", "area": area, "to": to, "pos": Vector2(float(at[0]), float(at[2])),
				"to_name": String(region(to).get("name", to)), "known": region_seen(to),
				"label": labels[mini(n, labels.size() - 1)] if labels.size() > 0 else ""})
		for pl in places_def(area):
			if place_seen(area, pl["id"]):
				out.append({"kind": "place", "area": area, "name": pl["name"], "pos": pl["pos"],
					"zone": pl["zone"] != null})
	var pin := Journal.pin_place()
	if not pin.is_empty() and pin.get("pos", null) != null and region_seen(String(pin["area"])) \
			and (only_area == "" or only_area == String(pin["area"])):
		out.append({"kind": "pin", "area": String(pin["area"]), "pos": pin["pos"], "title": String(pin["title"])})
	var p = Game.player
	if p != null and is_instance_valid(p) and Game.current_area_id != "" \
			and (only_area == "" or only_area == Game.current_area_id):
		var yaw: float = p.vis.rotation.y if p.get("vis") != null else p.rotation.y
		out.append({"kind": "bearer", "area": Game.current_area_id,
			"pos": Vector2(p.global_position.x, p.global_position.z), "yaw": yaw})
	return out
