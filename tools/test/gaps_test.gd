extends TestBase
## Pinch gaps (fix/table-column-gap). In the Longhouse in RIME the tables are dragged to the west wall beside
## the column row; a roll into the table at z -40 left the Bearer wedged off the floor (fullslice seed 5 on
## gpu/walk-ticks: he hung 330 frames, then fell through). Roll into it from a fan of starts and angles: after
## each he must stand on the floor, not hang, and walk back out.

const SH := 21.976
var area: Area
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	World.reset()
	World._save_dir = "user://test_gaps"
	World.set_area_state("saltfell_steading", RH.WState.RIME)
	area = AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	player = Player.new()
	add_child(player)
	player.global_position = Vector3(-2.8, SH + 0.3, -41.05)
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, RH.WState.RIME)
	await ticks(30)
	# the geometry alone: the Netmender wakes within 4 m and her body would part him into the corner
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		e.queue_free()
	for sp in area.find_children("*", "Spawner", true, false):
		sp.process_mode = Node.PROCESS_MODE_DISABLED
	await ticks(5)

	print("== roll into the rime table by the column (z -40)")
	var wedged := 0
	var stuck := 0
	var tries := 0
	for z in [-40.4, -40.8, -41.05, -41.3, -41.6]:
		for ang in [-25.0, -12.0, 0.0, 12.0, 25.0]:
			tries += 1
			player.velocity = Vector3.ZERO
			player.global_position = Vector3(-2.7, SH + 0.05, z)
			player.sim_move = Vector3.ZERO
			await ticks(12)
			var dir := Vector3(-1, 0, 0).rotated(Vector3.UP, deg_to_rad(ang))
			player.cam.yaw = atan2(-dir.x, -dir.z)
			player.stamina = player.max_stamina
			player.sim_move = Vector3(0, 0, -1)
			player.try_roll()
			# keep pushing in, as a player holding the stick does
			await ticks(40)
			player.sim_move = Vector3.ZERO
			await ticks(30)
			var hang := not player.is_on_floor() and absf(player.get_real_velocity().y) < 0.05 \
					and player.global_position.y > SH + 0.005
			if hang or player.global_position.y < SH - 0.3:
				wedged += 1
				print("   wedged: start z %.2f, %+.0f deg -> %s floor=%s" % [z, ang, str(player.global_position), str(player.is_on_floor())])
			# and out again: east, back the way he came, else along the wall north or south
			var p0 := player.global_position
			var out := false
			for yaw in [atan2(-1.0, 0.0), atan2(0.0, 1.0), atan2(0.0, -1.0)]:
				player.cam.yaw = yaw
				player.sim_move = Vector3(0, 0, -1)
				await ticks(60)
				player.sim_move = Vector3.ZERO
				if Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length() >= 0.8:
					out = true
					break
			if not out:
				stuck += 1
				print("   cannot get out: start z %.2f, %+.0f deg (at %s; state %d, input %s, v %s, real %s, floor %s)" % [z, ang, str(player.global_position), player.state, str(player.input_enabled), str(player.velocity), str(player.get_real_velocity()), str(player.is_on_floor())])
	check(wedged == 0, "no roll leaves him hung off the floor (%d of %d)" % [wedged, tries])
	check(stuck == 0, "he walks back out every time (%d of %d stuck)" % [stuck, tries])
	finish()
