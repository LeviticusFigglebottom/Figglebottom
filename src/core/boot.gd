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
		elif arg.begins_with("--test-seed="):
			seed_arg = int(arg.get_slice("=", 1))
		elif arg.begins_with("--scene="):
			target = arg.get_slice("=", 1)
	if test_seed != -1:
		seed(seed_arg if seed_arg != -1 else test_seed)
	if not ResourceLoader.exists(target):
		push_warning("Boot: scene %s missing; staying on boot screen" % target)
		return
	get_tree().change_scene_to_file.call_deferred(target)
