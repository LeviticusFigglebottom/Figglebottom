extends Node3D
## Combat sandbox: kit-floor arena, walls, columns, training pells, player.
## Run: godot --path . -- --sandbox=arena

func _ready() -> void:
	# floor 6x6 tiles (24x24 m)
	for i in range(6):
		for j in range(6):
			var f := KitLib.instance("floor_4x4")
			f.position = Vector3(i * 4 - 10, 0, j * 4 - 10)
			KitLib.add_collision(f, RH.L_WORLD_BASE)
			add_child(f)
	# perimeter walls
	for i in range(6):
		for spec in [
			[0.0, Vector3(i * 4 - 10, 0, -12)],
			[PI, Vector3(i * 4 - 10, 0, 12)],
			[PI / 2, Vector3(-12, 0, i * 4 - 10)],
			[-PI / 2, Vector3(12, 0, i * 4 - 10)],
		]:
			var w := KitLib.instance("wall_4x4")
			w.position = spec[1]
			w.rotation.y = spec[0]
			KitLib.add_collision(w, RH.L_WORLD_BASE)
			add_child(w)
	for corner in [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(-12, 0, 12), Vector3(12, 0, 12)]:
		var c := KitLib.instance("column_4m")
		c.position = corner
		KitLib.add_collision(c, RH.L_WORLD_BASE)
		add_child(c)

	var dummy := TrainingDummy.new()
	dummy.name = "Dummy"
	dummy.position = Vector3(0, 0, -4)
	add_child(dummy)
	var dummy2 := TrainingDummy.new()
	dummy2.name = "Dummy2"
	dummy2.position = Vector3(5, 0, -7)
	dummy2.rotation.y = 0.8
	add_child(dummy2)

	var player := Player.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector3(0, 0.1, 4)

	# live foes (idle until approached) + a hearth + HUD for playtesting
	var pen := Spawner.new()
	pen.name = "PenSpawner"
	pen.enemy_id = "rimewalker"
	pen.position = Vector3(-6, 0, -8)
	add_child(pen)
	var ward := Spawner.new()
	ward.name = "WardSpawner"
	ward.enemy_id = "ward"
	ward.position = Vector3(7, 0, -9)
	ward.face_deg = 180.0
	add_child(ward)
	var hearth := Hearthstone.new()
	hearth.hearth_id = "arena"
	hearth.position = Vector3(9, 0, 9)
	add_child(hearth)
	add_child(HUD.new())

	# warm look
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -120, 0)
	sun.light_color = Color(1.0, 0.85, 0.62)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.45, 0.38)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.48)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
