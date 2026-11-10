extends Node3D
## The game proper: loads the save (or begins a journey), shows the title,
## builds the chosen area, places the Bearer, raises the HUD.

const TITLE := preload("res://src/ui/title_screen.gd")
const START_AREA := "saltfell_steading"

## The Bearer, the HUD and the area the front door last raised; the
## title return tears exactly these down.
var _player: Node = null
var _hud: Node = null
var _area: Node = null

func _ready() -> void:
	Game.world_root = self
	_front_door(false)

## Back to the title from the pause sheet: the hearth is kept first (saved
## where the Bearer stands), the world is torn down, and the front door runs
## again without the house card. Resume finds the save just written.
func return_to_title() -> void:
	if Game.player != null and is_instance_valid(Game.player):
		Game.snapshot_player()
		World.save_game()
	Game.arena_locked = false
	get_tree().paused = false
	for n in [_hud, _player, _area]:
		if n != null and is_instance_valid(n):
			remove_child(n)
			n.queue_free()
	_hud = null
	_player = null
	_area = null
	for b in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if is_instance_valid(b) and is_ancestor_of(b):
			b.queue_free()
	Game.player = null
	Game.current_area = null
	Game.current_area_id = ""
	AudioDirector.end_boss_theme("", 0.5)
	await get_tree().process_frame
	_front_door(true)

func _front_door(returning: bool) -> void:
	var fresh := true
	var area_id := START_AREA
	var harnessed := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--area="):
			area_id = arg.get_slice("=", 1)
			harnessed = true

	# Game.front_door lets a headless test walk the real boot path
	var interactive := Game.front_door or (not harnessed and Shot.forced_state == "" \
			and not DisplayServer.get_name().contains("headless"))

	# harness/headless runs keep the single-load behaviour (slot 1)
	if not interactive:
		if not harnessed:
			fresh = not World.load_game()
			if not fresh and World.last_hearth.get("area", "") != "":
				area_id = World.last_hearth["area"]
		Game.set_difficulty(str(World.flag_val("difficulty", "long")))

	if interactive and not returning:
		var card := HouseCard.new()
		add_child(card)
		await card.finished
	if interactive:
		# the winter is weighed after New journey is chosen (title -> new ->
		# difficulty), never before the title: Esc there returns to it
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
				var sel2 := DifficultyUI.new()
				sel2.cancellable = true
				add_child(sel2)
				var diff: String = await sel2.chosen
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

	# a kept save opens where the Bearer sat down (COLDWELL.md 10)
	if World.kept() and not harnessed:
		area_id = World.KEPT_AREA
	for f in Shot.forced_flags:
		World.set_flag(String(f))   # shot harness: flag-conditional geometry
	var area := AreaBuilder.build(area_id)
	add_child(area)
	_area = area
	Game.register_area(area, area_id)

	# state: saved state, or forced by the shot harness
	if Shot.forced_state != "":
		World.set_area_state(area_id, RH.state_from_name(Shot.forced_state))
	StateDirector.snap(area, World.get_area_state(area_id))

	var player := Player.new()
	player.name = "Player"
	add_child(player)
	_player = player
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
	if hearth != null and not fresh:
		player.cam.yaw = hearth.global_rotation.y + PI   # wake facing out from the hearth
	# the Bearer faces where the camera looks: a new journey opened on him
	# staring back into the lens
	if player.get("vis") != null:
		player.vis.rotation.y = player.cam.yaw

	_hud = HUD.new()
	add_child(_hud)
	if World.kept() and area_id == World.KEPT_AREA:
		EndingDirector.resume_kept(player, area)
	Game.refresh_breathmark()
	Game.area_title.emit(area.arrival_title(spawn))
