extends TestBase
## The Bearer's controller on uneven ground: step-up onto kerbs, thresholds and
## deck edges up to move/step_height (game.json), no step onto anything
## taller, stair snapping on the way down, and the flat-ground feel numbers
## (run speed) unchanged.

var player: Player
var _stair_frames := 0

func _ready() -> void:
	_run.call_deferred()

func _box(a: Vector3, b2: Vector3) -> void:
	var mn := a.min(b2)
	var mx := a.max(b2)
	var b := StaticBody3D.new()
	b.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = mx - mn
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.global_position = (mn + mx) * 0.5

func _walk(from: Vector3, n: int, watch_floor := false) -> int:
	player.global_position = from
	player.velocity = Vector3.ZERO
	player.cam.yaw = 0.0
	await ticks(4)
	var airborne := 0
	_stair_frames = 0
	player.sim_move = Vector3(0, 0, -1)
	for i in n:
		await ticks(1)
		if _stair_frames == 0 and player.global_position.z < -12.0:
			_stair_frames = i + 1
		if watch_floor and not player.is_on_floor() and player.global_position.z < -8.8:
			airborne += 1
			if OS.has_environment("CTRL_DEBUG"):
				print("    air at ", player.global_position, " v ", player.velocity)
	player.sim_move = Vector3.ZERO
	await ticks(4)
	return airborne

func _run() -> void:
	_box(Vector3(-30, -1, -40), Vector3(30, 0, 10))            # the ground
	# lane A (x 0): a 0.30 m deck edge, 6 m deep
	_box(Vector3(-1.5, 0, -10), Vector3(1.5, 0.30, -4))
	# lane B (x 8): a 0.55 m ledge, too tall to step
	_box(Vector3(6.5, 0, -10), Vector3(9.5, 0.55, -4))
	# lane C (x -8): four 0.25 m stairs up to a 1 m landing, four down again
	for k in 4:
		_box(Vector3(-9.5, 0, -4.0 - k * 0.6), Vector3(-6.5, 0.25 * (k + 1), -4.0 - (k + 1) * 0.6))
	_box(Vector3(-9.5, 0, -8.8), Vector3(-6.5, 1.0, -6.4))
	for k in 4:
		_box(Vector3(-9.5, 0, -8.8 - (k + 1) * 0.6), Vector3(-6.5, 1.0 - 0.25 * (k + 1), -8.8 - k * 0.6))
	player = Player.new()
	add_child(player)
	player.sim_active = true
	player.global_position = Vector3(16, 0.1, 0)
	await ticks(20)

	print("== the controller's numbers live in game.json")
	check(DB.tuning("player/move/step_height") != null and float(DB.tuning("player/move/step_height")) <= 0.35,
		"step_height is data (%.2f m, at most 0.35)" % float(DB.tuning("player/move/step_height", 0.0)))
	check(player.floor_snap_length >= float(DB.tuning("player/move/snap_down", 0.0)) - 0.001, "floor snap follows move/snap_down")

	print("== flat ground feels the same")
	player.global_position = Vector3(16, 0.1, 6)
	player.cam.yaw = 0.0
	await ticks(4)
	player.sim_move = Vector3(0, 0, -1)
	await ticks(40)
	var sp := Vector2(player.velocity.x, player.velocity.z).length()
	player.sim_move = Vector3.ZERO
	check(absf(sp - float(DB.tuning("player/move/run"))) < 0.05, "run speed on the flat is still move/run (%.2f)" % sp)
	await ticks(10)

	print("== a 0.30 m deck edge")
	await _walk(Vector3(0, 0.1, 0), 90)
	check(player.global_position.z < -5.0, "the Bearer walks up onto it (z %.1f)" % player.global_position.z)
	check(absf(player.global_position.y - 0.30) < 0.08, "and stands on top (y %.2f)" % player.global_position.y)

	print("== a 0.55 m ledge")
	await _walk(Vector3(8, 0.1, 0), 90)
	check(player.global_position.z > -4.0, "is too tall to step (z %.1f)" % player.global_position.z)
	check(player.global_position.y < 0.1, "and the Bearer stays on the ground (y %.2f)" % player.global_position.y)

	print("== stairs, up and down")
	var air: int = await _walk(Vector3(-8, 0.1, -1), 150, true)
	check(player.global_position.z < -12.0, "up four 0.25 m stairs and down the other side (z %.1f)" % player.global_position.z)
	check(player.global_position.y < 0.1, "back on the ground at the foot (y %.2f)" % player.global_position.y)
	check(air <= 4, "stair snapping keeps the feet down (%d airborne frames on the way down)" % air)
	check(_stair_frames > 0 and _stair_frames < 150, "and the climb never stalls at a riser (%d frames for 11 m)" % _stair_frames)

	finish()
