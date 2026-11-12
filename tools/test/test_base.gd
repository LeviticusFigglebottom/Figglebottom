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

## A gate opened or the bridge lowered: the navmesh is baked again in the
## background (Area.rebake_navmeshes) and the old one answers until then.
## Wait for the new routes before asking for a path through the opening.
func nav_wait(a: Area = null, max_s := 30.0) -> void:
	if a == null:
		a = Game.current_area
	var t0 := Time.get_ticks_msec()
	while a != null and is_instance_valid(a) and a.nav_pending and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().physics_frame

func finish() -> void:
	if Game.stream != null:
		Game.stream.reset()    # no worker build outlives the test
	AudioDirector.shutdown()
	print("")
	print("RESULT: %d checks, %d failures" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)

func _exit_tree() -> void:
	if Game.stream != null:
		Game.stream.reset()
	AudioDirector.shutdown()
	KitLib._scene_cache.clear()
	KitLib._shape_cache.clear()
	AreaBuilder._box_mesh_cache.clear()
	MaterialLib._cache.clear()
	MaterialLib._tex_cache.clear()
	AmbientLife._mote_tex = null
	FrostFX.clear_cache()
	FrostDissolve.clear_cache()
	EnvRig.active_instance = null
