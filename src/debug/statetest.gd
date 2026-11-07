extends Node3D
## State-system sandbox: a hand-built courtyard Area with real thaw/rime
## layers, a hearth, and self-capturing transformation screenshots.
##   --state=thaw|rime                  snap to state
##   --wave=still|warm --wave-shots=docs/wave   capture the transformation

var area: Area
var cam: Camera3D

func _ready() -> void:
	area = Area.new()
	area.area_id = "statetest"
	add_child(area)
	Game.register_area(area, "statetest")
	_build()
	area.bake_navmeshes()

	cam = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(10.5, 7.5, 13.5)
	cam.rotation_degrees = Vector3(-24, 33, 0)
	cam.fov = 58
	cam.current = true

	var forced := ""
	var wave := ""
	var wave_prefix := "docs/wave"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--state="):
			forced = arg.get_slice("=", 1)
		elif arg.begins_with("--wave="):
			wave = arg.get_slice("=", 1)
		elif arg.begins_with("--wave-shots="):
			wave_prefix = arg.get_slice("=", 1)

	var start := RH.WState.RIME if (forced == "rime" or wave == "warm") else RH.WState.THAW
	World.set_area_state("statetest", start)
	StateDirector.snap(area, start)

	if wave != "":
		_run_wave.call_deferred(wave, wave_prefix)

func _run_wave(wave: String, prefix: String) -> void:
	await _ticks(30)
	var to := RH.WState.RIME if wave == "still" else RH.WState.THAW
	var hearth_pos := Vector3(0, 0, 0)
	StateDirector.transition(area, to, hearth_pos)
	# capture during the sweep
	var marks := [0.12, 0.35, 0.62, 1.15]
	var dur := float(DB.tuning("transition/duration", 6.0))
	var t := 0.0
	var i := 0
	while i < marks.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= marks[i] * dur:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var path := "%s_%d.png" % [prefix, i]
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			img.save_png(path)
			print("[wave] saved ", path)
			i += 1
	await _ticks(10)
	get_tree().quit()

func _ticks(n: int):
	for i in n:
		await get_tree().physics_frame

func _kit(id: String, pos: Vector3, roty := 0.0, tag := "base", collide := true) -> Node3D:
	var piece := KitLib.instance(id, 1 if tag == "thaw" else (2 if tag == "rime" else 0))
	piece.position = pos
	piece.rotation.y = roty
	if collide:
		var bit := RH.L_WORLD_THAW if tag == "thaw" else (RH.L_WORLD_RIME if tag == "rime" else RH.L_WORLD_BASE)
		KitLib.add_collision(piece, bit)
	if id.contains("brazier") or id.contains("brazier") or id.contains("hearth"):
		KitLib.add_flame_lights(piece)
	area.attach(piece, tag)
	return piece

func _build() -> void:
	# courtyard floor 5x5 tiles (20x20)
	for i in range(5):
		for j in range(5):
			_kit("floor_4x4", Vector3(i * 4 - 8, 0, j * 4 - 8))
	# north arcade (faces courtyard)
	for i in range(5):
		_kit("arch_4m", Vector3(i * 4 - 8, 0, -10), 0.0)
	# east wall: wall, window, window, wall
	_kit("wall_4x4", Vector3(10, 0, -8), -PI / 2)
	_kit("wall_low_4m", Vector3(10, 0, -4), -PI / 2)
	_kit("wall_low_4m", Vector3(10, 0, 0), -PI / 2)
	_kit("wall_4x4", Vector3(10, 0, 4), -PI / 2)
	_kit("wall_4x4", Vector3(10, 0, 8), -PI / 2)
	# south: portal flanked by walls
	_kit("wall_4x4", Vector3(-8, 0, 10), PI)
	_kit("wall_4x4", Vector3(-4, 0, 10), PI)
	_kit("portal_4m", Vector3(0, 0, 10), PI)
	_kit("wall_4x4", Vector3(4, 0, 10), PI)
	_kit("wall_4x4", Vector3(8, 0, 10), PI)
	# west: low parapet (vista)
	for j in range(5):
		_kit("wall_low_4m", Vector3(-10, 0, j * 4 - 8), PI / 2)
	# corner piers: NE corner intact in thaw, broken in rime (state delta)
	_kit("column_4m", Vector3(-9.4, 0, -9.4))
	_kit("column_4m", Vector3(9.4, 0, -9.4), 0.0, "thaw")
	_kit("rime_spike", Vector3(9.4, 0, -9.4), 0.6, "rime")
	# thaw furniture
	_kit("barrel", Vector3(8.6, 0, -6.2), -PI / 2, "thaw", false)
	_kit("crate", Vector3(8.6, 0, 2.2), -PI / 2, "thaw", false)
	_kit("brazier", Vector3(2.2, 0, -7.4), 0.0, "thaw", false)
	_kit("brazier", Vector3(-3.0, 0, -7.4), 0.0, "thaw", false)
	_kit("pillar", Vector3(-8.6, 0, -8.6), PI / 4, "thaw")
	_kit("brazier", Vector3(6.5, 0, 6.5), 0.0, "thaw", false)
	# rime dressing
	_kit("crate", Vector3(0.2, 0, 9.0), 0.3, "rime")
	_kit("rime_spike", Vector3(8.6, 0, -8.0), 1.1, "rime")
	_kit("rime_spike", Vector3(-4.0, 0, -8.6), 2.0, "rime", false)
	_kit("brazier", Vector3(6.5, 0, 6.5), 0.0, "rime", false)
	_kit("woodpile", Vector3(-6.0, 0, 3.0), 0.2, "rime")
	# the hearth at the heart
	var hearth := Hearthstone.new()
	hearth.hearth_id = "test"
	hearth.area = area
	hearth.position = Vector3(0, 0, 0)
	area.base.add_child(hearth)
