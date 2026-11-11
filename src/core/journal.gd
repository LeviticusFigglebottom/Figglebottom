class_name Journal
extends RefCounted
## The Journal: the quest log read off data/keepsakes.json and World.flags.
## Nothing here is stored except the pin and the tracker switch
## (World.journal); a thread's state is always worked out from the flags, so
## it survives a save and load exactly as they do.
##
## A thread view is {id, title, area, started, complete, objective, extras,
## done, step}: `objective` is the plain instruction for the next step (""
## when complete), `extras` the optional things that can be done now, `done`
## the finished steps as plain statements, `step` the next step's data.

const MAIN_ID := "outsong"

static func main_def() -> Dictionary:
	return DB.table("keepsakes").get("main", {})

static func thread_def(id: String) -> Dictionary:
	if id == String(main_def().get("id", MAIN_ID)):
		return main_def()
	for t in Keepsakes.threads_def():
		if String(t.get("id", "")) == id:
			return t
	return {}

## A step is done when its flag is set. `flag` may be a list (any of them);
## `area_flag` is "area/flag" (or a list), for things the areas remember,
## such as a Hearthstone rested at.
static func step_done(s: Dictionary) -> bool:
	var f: Variant = s.get("flag", "")
	for name in (f if f is Array else [f]):
		if String(name) != "" and World.flag(String(name)):
			return true
	var af: Variant = s.get("area_flag", "")
	for name in (af if af is Array else [af]):
		var parts := String(name).split("/")
		if parts.size() == 2 and World.area_flag(parts[0], parts[1]):
			return true
	return false

static func _carries(item: String) -> bool:
	var p = Game.player
	if p != null and is_instance_valid(p):
		return int(p.inventory.get(item, 0)) > 0
	return int((World.player_data.get("inventory", {}) as Dictionary).get(item, 0)) > 0

static func _objective_of(s: Dictionary) -> String:
	for w in s.get("objective_when", []):
		if (String(w.get("flag", "")) != "" and World.flag(String(w["flag"]))) \
				or (String(w.get("item", "")) != "" and _carries(String(w["item"]))):
			return String(w.get("objective", ""))
	return String(s.get("objective", ""))

static func view_of(t: Dictionary) -> Dictionary:
	var steps: Array = t.get("steps", [])
	var flags := []
	for s in steps:
		flags.append(step_done(s))
	if bool(t.get("sequential", false)):
		# the journey only goes one way: a later step done means the earlier are
		var later := false
		for i in range(flags.size() - 1, -1, -1):
			later = later or flags[i]
			flags[i] = later
	var done := []
	var next: Dictionary = {}
	for i in steps.size():
		if flags[i]:
			done.append(String(steps[i].get("line", "")))
		elif next.is_empty():
			next = steps[i]
	var is_main := String(t.get("id", "")) == String(main_def().get("id", MAIN_ID))
	var started: bool = is_main or (not flags.is_empty() and flags[0]) or not done.is_empty()
	var extras := []
	for o in t.get("optional", []):
		if step_done(o):
			# an optional step's line sits after the step it belongs to
			var at := done.size()
			var after := String(o.get("after", ""))
			for i in steps.size():
				if String(steps[i].get("flag", "")) == after and flags[i]:
					at = mini(done.size(), flags.slice(0, i + 1).count(true))
			done.insert(at, String(o.get("line", "")))
		elif started and (String(o.get("needs_item", "")) == "" or _carries(String(o["needs_item"]))):
			extras.append(_objective_of(o))
	return {
		"id": String(t.get("id", "")), "title": String(t.get("title", "")),
		"about": String(t.get("about", "")),
		"area": String(next.get("area", t.get("area", ""))),
		"started": started, "complete": started and next.is_empty(),
		"objective": _objective_of(next) if (started and not next.is_empty()) else "",
		"extras": extras, "done": done, "step": next,
	}

## The whole log: {main, active: [...], done: [...]} in data order.
static func view() -> Dictionary:
	var active := []
	var finished := []
	for t in Keepsakes.threads_def():
		var v := view_of(t)
		if not v["started"]:
			continue
		if v["complete"]:
			finished.append(v)
		else:
			active.append(v)
	return {"main": view_of(main_def()), "active": active, "done": finished}

# ---------------------------------------------------------------- the pin

static func pin_id() -> String:
	return String(World.journal.get("pin", MAIN_ID))

static func set_pin(id: String) -> void:
	World.journal["pin"] = id

static func tracker_on() -> bool:
	return bool(World.journal.get("tracker", true))

static func set_tracker(on: bool) -> void:
	World.journal["tracker"] = on

## The pinned thread's view. A pinned thread that is finished (or was never
## started) hands the pin back to the journey.
static func pinned() -> Dictionary:
	var t := thread_def(pin_id())
	var v := view_of(t) if not t.is_empty() else {}
	if v.is_empty() or not v["started"] or v["complete"]:
		v = view_of(main_def())
	return v

## The HUD tracker's two lines, or {} when it is off or there is nothing to do.
static func tracker() -> Dictionary:
	if not tracker_on() or main_def().is_empty():
		return {}
	var v := pinned()
	if String(v.get("objective", "")) == "":
		return {}
	return {"title": v["title"], "objective": v["objective"]}

## Where the pinned objective is, for the map: {area, pos (Vector2 x,z) or
## null, title}. `pos` is only set when the step's data gives a place, which
## it does only when the Bearer has been told where to go.
static func pin_place() -> Dictionary:
	var v := pinned()
	var s: Dictionary = v.get("step", {})
	if s.is_empty():
		return {}
	var area := String(s.get("area", v.get("area", "")))
	return {"area": area, "pos": resolve_at(area, s.get("at", null)), "title": v["title"]}

## "npc:<id>" | "pickup:<id>" | "hearth:<id>" | "veil" | [x, z] -> Vector2(x, z)
static func resolve_at(area: String, at: Variant) -> Variant:
	if at is Array and (at as Array).size() >= 2:
		return Vector2(float(at[0]), float(at[1]))
	if not (at is String) or area == "":
		return null
	var def := DB.area_def(area)
	var kind := String(at).get_slice(":", 0)
	var id := String(at).get_slice(":", 1)
	var list := {"npc": "npcs", "pickup": "pickups", "hearth": "hearths", "veil": "frost_veils"}
	var rows: Array = def.get(String(list.get(kind, "")), [])
	for r in rows:
		if kind == "veil" or String(r.get("id", "")) == id:
			var p: Array = r.get("at", [0, 0, 0])
			return Vector2(float(p[0]), float(p[2]))
	return null
