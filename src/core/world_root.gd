extends Node3D
## The game proper: loads the save (or begins a journey), shows the title,
## builds the chosen area, places the Bearer, raises the HUD.

const TITLE := preload("res://src/ui/title_screen.gd")
const START_AREA := "saltfell_steading"

func _ready() -> void:
	Game.world_root = self
	var fresh := true
	var area_id := START_AREA
	var harnessed := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--area="):
			area_id = arg.get_slice("=", 1)
			harnessed = true

	var interactive := not harnessed and Shot.forced_state == "" \
			and not DisplayServer.get_name().contains("headless")

	# harness/headless runs keep the single-load behaviour (slot 1)
	if not interactive:
		if not harnessed:
			fresh = not World.load_game()
			if not fresh and World.last_hearth.get("area", "") != "":
				area_id = World.last_hearth["area"]
		Game.set_difficulty(str(World.flag_val("difficulty", "long")))

	if interactive:
		var card := HouseCard.new()
		add_child(card)
		await card.finished
		var preweighed := not World.any_slot()
		if preweighed:
			var sel := DifficultyUI.new()
			add_child(sel)
			Game.set_difficulty(await sel.chosen)
		var picked := false
		while not picked:
			var title := TITLE.new()
			title.has_save = World.any_slot()
			add_child(title)
			var pick = await title.done   # [choice, slot]
			title.queue_free()
			var choice: String = pick[0]
			var slot: int = pick[1]
			if choice == "resume":
				World.active_slot = slot
				if World.load_game():
					fresh = false
					if World.last_hearth.get("area", "") != "":
						area_id = World.last_hearth["area"]
					Game.set_difficulty(str(World.flag_val("difficulty", "long")))
				picked = true
			else:
				var diff := str(World.flag_val("difficulty", "long"))
				if not preweighed:
					var sel2 := DifficultyUI.new()
					sel2.cancellable = true
					add_child(sel2)
					diff = await sel2.chosen
					if diff == "":
						continue   # Esc: back to the title, nothing lost
				World.active_slot = slot
				World.reset()
				World.delete_slot(slot)
				Game.set_warmth(0)
				Game.set_difficulty(diff)
				fresh = true
				area_id = START_AREA
				picked = true

	for f in Shot.forced_flags:
		World.set_flag(String(f))   # shot harness: flag-conditional geometry
	var area := AreaBuilder.build(area_id)
	add_child(area)
	Game.register_area(area, area_id)

	# state: saved state, or forced by the shot harness
	if Shot.forced_state != "":
		World.set_area_state(area_id, RH.state_from_name(Shot.forced_state))
	StateDirector.snap(area, World.get_area_state(area_id))

	var player := Player.new()
	player.name = "Player"
	add_child(player)
	if not fresh:
		player.from_save(World.player_data)
		Game.set_warmth(int(World.player_data.get("warmth", 0)))
	var def: Dictionary = area.get_meta("def")
	var spawn: Vector3 = AreaBuilder._v3(def.get("start", {}).get("pos", [0, 0.2, 0]))
	var hearth := Game.find_hearth(World.last_hearth.get("hearth", ""))
	if not fresh and hearth != null:
		spawn = hearth.respawn_point()
	player.global_position = spawn
	player.cam.yaw = deg_to_rad(float(def.get("start", {}).get("yaw", 0)))

	add_child(HUD.new())
	Game.refresh_breathmark()
	Game.area_title.emit(area.display_name)
