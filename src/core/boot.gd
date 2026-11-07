extends Node
## Boot — routes startup: sandbox scenes for tooling, else the game world.

func _ready() -> void:
	var target := "res://scenes/world.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sandbox="):
			target = "res://scenes/sandbox/%s.tscn" % arg.get_slice("=", 1)
		elif arg.begins_with("--test="):
			target = "res://tools/test/%s_test.tscn" % arg.get_slice("=", 1)
		elif arg.begins_with("--scene="):
			target = arg.get_slice("=", 1)
	if not ResourceLoader.exists(target):
		push_warning("Boot: scene %s missing; staying on boot screen" % target)
		return
	get_tree().change_scene_to_file.call_deferred(target)
