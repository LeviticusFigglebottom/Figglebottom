extends SceneTree
## Writes the project Theme resource from UITheme.build_theme(), so the
## .tres and the code can never disagree. Run after changing ui_theme.gd:
##   godot --headless --path . --script tools/ui/gen_theme.gd

func _init() -> void:
	var t: Theme = load("res://src/ui/ui_theme.gd").build_theme()
	var err := ResourceSaver.save(t, "res://assets/ui/rimeholt_theme.tres")
	print("[theme] wrote assets/ui/rimeholt_theme.tres: ", error_string(err))
	quit(0 if err == OK else 1)
