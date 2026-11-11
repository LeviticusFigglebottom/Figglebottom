class_name Keepsakes
extends RefCounted
## The side threads as data (data/keepsakes.json): ordered steps, each a
## world flag, an objective and one plain line for when it is done. Nothing
## here is stored: it is read straight off World.flags, so it survives a
## save and load exactly as the flags do. The Journal (src/core/journal.gd)
## builds the quest log on top: objectives, optional steps, the main thread.

static func threads_def() -> Array:
	return DB.table("keepsakes").get("threads", [])

## Every thread the Bearer has started, in data order, each with its
## revealed lines in step order: [{id, title, lines: [String]}].
static func journal() -> Array:
	var out := []
	for t in threads_def():
		var lines := []
		for s in t.get("steps", []):
			if World.flag(String(s.get("flag", ""))):
				lines.append(String(s.get("line", "")))
		if not lines.is_empty():
			out.append({"id": t.get("id", ""), "title": t.get("title", ""), "lines": lines})
	return out

static func is_step_flag(flag: String) -> bool:
	var all: Array = threads_def().duplicate()
	all.append(DB.table("keepsakes").get("main", {}))
	for t in all:
		for s in (t.get("steps", []) as Array) + (t.get("optional", []) as Array):
			var f: Variant = s.get("flag", "")
			if (f is Array and (f as Array).has(flag)) or (f is String and f == flag):
				return true
	return false

static func line_count() -> int:
	var n := 0
	for t in journal():
		n += (t["lines"] as Array).size()
	return n

static func toast_text() -> String:
	return String(DB.table("keepsakes").get("toast", "Journal updated."))
