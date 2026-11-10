extends FullgameBase
## The Lowe, end to end, from the save the slice walk ends on.

func _init() -> void:
	region = "lowe"
	aid = "lowe_barrows"
	start_fixture = "fullgame_after_saltfell"

func _region() -> void:
	print("== the pass: Saltfell to the Lowe")
	check(Game.current_area_id == "saltfell_steading", "the walk starts in Saltfell")
	var seam := _portal_to("lowe_barrows", Vector3(-89, 23, -85))
	check(seam != null, "the pass seam stands")
	var crossed := await _cross("lowe_barrows", seam.global_position + Vector3(0, 0, -1.0))
	check(crossed, "the Bearer walks over the pass into the Lowe (%s)" % str(player.global_position.snapped(Vector3.ONE)))
