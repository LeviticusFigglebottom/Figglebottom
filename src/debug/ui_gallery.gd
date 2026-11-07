extends Node3D
## UI gallery: the boot-time screens on their own, for screenshots.
##   tools/shot.sh docs/screens/ui_housecard.png --sandbox=ui_gallery --ui=housecard --shot-frames=90
##   tools/shot.sh docs/screens/ui_title.png --sandbox=ui_gallery --ui=title --shot-frames=120
##   tools/shot.sh docs/wip/knots.png --sandbox=ui_gallery --ui=difficulty

func _ready() -> void:
	var which := "housecard"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui="):
			which = arg.get_slice("=", 1)
	match which:
		"housecard":
			var card := HouseCard.new()
			card.hold_forever = true
			add_child(card)
		"title":
			var t: Node = load("res://src/ui/title_screen.gd").new()
			t.has_save = true
			add_child(t)
		"difficulty":
			add_child(DifficultyUI.new())
