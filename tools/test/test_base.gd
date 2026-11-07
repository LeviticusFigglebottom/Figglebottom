class_name TestBase
extends Node
## Base for in-game headless tests (run via `--test=<name>`; boot.gd routes
## to tools/test/<name>_test.tscn). Autoloads are live — this IS the game.

var fails := 0
var checks := 0

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  ok  - ", label)
	else:
		fails += 1
		print("  FAIL - ", label)

func ticks(n: int):
	for i in n:
		await get_tree().physics_frame

func finish() -> void:
	AudioDirector.shutdown()
	print("")
	print("RESULT: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _exit_tree() -> void:
	AudioDirector.shutdown()
	KitLib._scene_cache.clear()
	KitLib._shape_cache.clear()
	AreaBuilder._box_mesh_cache.clear()
	MaterialLib._cache.clear()
	MaterialLib._tex_cache.clear()
	AmbientLife._mote_tex = null
	EnvRig.active_instance = null
