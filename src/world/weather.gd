class_name Weather
extends Node3D
## Air for terrain areas. THAW: gulls wheeling over the water, pollen near the
## ground (with the area's gold motes). RIME: snow falling round the camera,
## ice glitter in the air, and spindrift smoking off the cliff lips.
## The camera-following emitters keep particle counts small on lavapipe.

var follow := false

static func build(area: Area, terrain: Terrain, def: Dictionary) -> void:
	var nb: Array = def.get("nav_bounds", [-60, 0, -60, 60, 40, 60])
	var c := Vector3((float(nb[0]) + float(nb[3])) * 0.5, 0, (float(nb[2]) + float(nb[5])) * 0.5)
	var size := Vector3(float(nb[3]) - float(nb[0]), 0, float(nb[5]) - float(nb[2]))
	var wcfg: Dictionary = def.get("weather", {})
	# THAW: gulls over the sea and the cliff tops
	if wcfg.get("gulls", true):
		var gulls := _emitter(36, 14.0, Vector3(size.x * 0.6, 8.0, size.z * 0.6), _quad(0.55, Color(0.94, 0.92, 0.86, 0.95), false))
		gulls.position = c + Vector3(0, float(wcfg.get("gull_y", 34.0)), float(wcfg.get("gull_dz", 40.0)))
		gulls.direction = Vector3(1, 0.05, 0.3)
		gulls.spread = 70.0
		gulls.initial_velocity_min = 2.5
		gulls.initial_velocity_max = 5.0
		gulls.angular_velocity_min = -20
		gulls.angular_velocity_max = 20
		area.thaw_layer.add_child(gulls)
	var pollen := Weather.new()
	pollen.follow = true
	pollen.add_child(_falling(140, Vector3(18, 2.0, 18), Vector3(0.3, 0.05, 0.1), 0.06, Color(1.0, 0.9, 0.55, 0.5), true))
	area.thaw_layer.add_child(pollen)
	# RIME: snow and glitter that travel with the camera
	var snow := Weather.new()
	snow.follow = true
	snow.add_child(_falling(900, Vector3(26, 12, 26), Vector3(0.9, -1.6, 0.4), 0.11, Color(0.95, 0.97, 1.0, 0.85), false))
	snow.add_child(_falling(160, Vector3(14, 3, 14), Vector3(0.1, -0.1, 0.05), 0.05, Color(0.8, 0.9, 1.0, 0.9), true))
	area.rime_layer.add_child(snow)
	# spindrift: snow smoke peeling off a few cliff lips into the wind
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var made := 0
	var tries := 0
	while made < int(wcfg.get("spindrift", 14)) and tries < 4000:
		tries += 1
		var x := rng.randf_range(float(nb[0]), float(nb[3]))
		var z := rng.randf_range(float(nb[2]), float(nb[5]))
		if not terrain.contains(x, z) or terrain.drop_at(x, z, 4.0) < 8.0:
			continue
		var y := terrain.height_at(x, z)
		var sd := _emitter(70, 2.6, Vector3(3.0, 0.4, 3.0), _quad(0.9, Color(0.92, 0.95, 1.0, 0.22), false))
		sd.position = Vector3(x, y + 0.4, z)
		sd.direction = Vector3(0.9, 0.25, -0.5)
		sd.spread = 25.0
		sd.initial_velocity_min = 2.0
		sd.initial_velocity_max = 4.5
		sd.gravity = Vector3(0, -0.6, 0)
		sd.scale_amount_min = 0.8
		sd.scale_amount_max = 2.2
		sd.visibility_range_end = 120.0
		area.rime_layer.add_child(sd)
		made += 1

func _process(_dt: float) -> void:
	if not follow:
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_position = cam.global_position

static func _emitter(amount: int, lifetime: float, box: Vector3, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.gravity = Vector3.ZERO
	p.mesh = mesh
	return p

static func _falling(amount: int, box: Vector3, drift: Vector3, size: float, col: Color, glitter: bool) -> CPUParticles3D:
	var p := _emitter(amount, 7.0, box, _quad(size, col, glitter))
	p.local_coords = false
	p.direction = drift.normalized()
	p.spread = 20.0
	p.initial_velocity_min = drift.length() * 0.6
	p.initial_velocity_max = drift.length() * 1.3
	p.gravity = Vector3(0, drift.y * 0.2, 0)
	p.position = Vector3(0, box.y * 0.6, 0)
	if glitter:
		p.position.y = 0.5
	return p

static func _quad(sz: float, col: Color, additive: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(sz, sz * (0.45 if sz > 0.5 and not additive and col.a > 0.9 else 1.0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = false
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 16
	gt.height = 16
	m.albedo_texture = gt
	q.material = m
	return q
