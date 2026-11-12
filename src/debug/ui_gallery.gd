extends Node3D
## UI gallery: the boot-time screens on their own, for screenshots.
##   tools/shot.sh docs/screens/ui_housecard.png --sandbox=ui_gallery --ui=housecard --shot-frames=90
##   tools/shot.sh docs/screens/ui_title.png --sandbox=ui_gallery --ui=title --shot-frames=120
##   tools/shot.sh docs/wip/knots.png --sandbox=ui_gallery --ui=difficulty
##   tools/shot.sh docs/wip/map_lowe.png --sandbox=ui_gallery --ui=map --map-area=lowe_barrows
##     the Map alone, full screen, with no world built (seconds, where the
##     in-game `--shot-stage=map_zoom` builds a whole area): one region's
##     sheet with every marker it can ever carry, as if all seven regions
##     had been walked end to end. No --map-area: the whole highland.
##     Add --state=rime for the region's RIME boards and its veil standing.

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
		"map":
			_map()

## Every region walked, every Hearthstone, place and veil found: what a
## sheet has to line up with after tools/ui/build_map.py is re-run.
func _map() -> void:
	var area := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map-area="):
			area = arg.get_slice("=", 1)
	World.map = {"regions": {}, "hearths": {}, "veils": {}, "places": {}}
	for a in MapState.regions():
		MapState._mark("regions", a)
		MapState._mark("veils", a)
		if Shot.forced_state == "rime":
			World.set_area_state(a, RH.WState.RIME)
		for h in DB.area_def(a).get("hearths", []):
			MapState._mark("hearths", "%s/%s" % [a, h["id"]])
		for pl in MapState.places_def(a):
			MapState._mark("places", "%s/%s" % [a, pl["id"]])
	var layer := CanvasLayer.new()
	add_child(layer)
	var view := MapView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(view)
	if area != "":
		view.show_region(area)
