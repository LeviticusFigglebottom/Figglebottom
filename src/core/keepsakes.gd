class_name Keepsakes
extends RefCounted
## The Keepsakes journal as data (data/keepsakes.json): questlines are
## ordered steps, each a world flag and one line of text. Nothing here is
## stored: the journal is read straight off World.flags, so it survives a
## save and load exactly as the flags do. No markers, no objectives.

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
	for t in threads_def():
		for s in t.get("steps", []):
			if String(s.get("flag", "")) == flag:
				return true
	return false

static func line_count() -> int:
	var n := 0
	for t in journal():
		n += (t["lines"] as Array).size()
	return n

static func toast_text() -> String:
	return String(DB.table("keepsakes").get("toast", "A keepsake is remembered."))
