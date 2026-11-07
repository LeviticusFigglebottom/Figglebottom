extends TestBase
## Smoke: every script compiles under the live autoloads, every data table
## parses, the starting area builds.

func _ready() -> void:
	_run.call_deferred()

func _scripts(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_scripts(dir.path_join(sub), out)

func _run() -> void:
	print("== scripts compile")
	var all: Array = []
	_scripts("res://src", all)
	var bad := 0
	for p in all:
		var sc = load(p)
		if sc == null or not (sc as GDScript).can_instantiate():
			bad += 1
			print("    broken: ", p)
	check(bad == 0, "%d scripts load (%d broken)" % [all.size(), bad])
	print("== data tables")
	for t in ["game", "weapons", "movesets", "songs", "enemies", "items", "npcs", "areas"]:
		check(not DB.table(t).is_empty(), "table '%s' parsed" % t)
	print("== starting area builds")
	var area := AreaBuilder.build("saltfell_steading")
	check(area != null, "saltfell_steading builds")
	if area != null:
		add_child(area)
		await ticks(5)
		check(area.base.get_child_count() > 40, "base geometry present (%d)" % area.base.get_child_count())
	finish()
