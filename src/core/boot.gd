extends Node
## Boot — routes startup: sandbox scenes for tooling, else the game world.

func _ready() -> void:
	var target := "res://scenes/world.tscn"
	var test_seed := -1
	var seed_arg := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sandbox="):
			target = "res://scenes/sandbox/%s.tscn" % arg.get_slice("=", 1)
		elif arg.begins_with("--test="):
			target = "res://tools/test/%s_test.tscn" % arg.get_slice("=", 1)
			# a test draws the same fight every run: foes choose with the global
			# RNG (randf in enemy.gd), unseeded, so a walk met a different
			# fight each time and passed or failed by luck. --test-seed=N to vary.
			test_seed = hash(arg.get_slice("=", 1))
		elif arg == "--deterministic":
			# test walks: no streamer (synchronous builds and bakes) and the nav map and regions
			# updated in step, so nothing a worker thread finishes "some frames later" can change
			# a seeded run (a foe's path query read the old map or the new one by thread timing)
			Engine.set_meta("deterministic", true)
			ProjectSettings.set_setting("navigation/world/region_use_async_iterations", false)
			ProjectSettings.set_setting("navigation/world/map_use_async_iterations", false)
			NavigationServer3D.map_set_use_async_iterations(get_viewport().world_3d.navigation_map, false)
		elif arg.begins_with("--test-seed="):
			seed_arg = int(arg.get_slice("=", 1))
		elif arg.begins_with("--scene="):
			target = arg.get_slice("=", 1)
	if test_seed != -1:
		var used := seed_arg if seed_arg != -1 else test_seed
		seed(used)
		Engine.set_meta("test_seed", used)   # printed in the RESULT line, to replay a run
	if not ResourceLoader.exists(target):
		push_warning("Boot: scene %s missing; staying on boot screen" % target)
		return
	get_tree().change_scene_to_file.call_deferred(target)
