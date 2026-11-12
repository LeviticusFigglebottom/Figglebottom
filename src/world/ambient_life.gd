class_name AmbientLife
extends Node3D
## The world breathing: cheap ambient dressing that makes the thaw feel
## inhabited and the rime feel abandoned — which is the whole juxtaposition.
##   kind "motes_gold" — sunlit dust rising slowly through the air (thaw)
##   kind "motes_ash"  — snow crystals sifting downward (rime; id kept for data)
##   kind "birds"      — a few ground birds pecking; they burst up and away
##                       when the wayfarer comes near
##   {"script": ".../ambient_life.gd", "at": [cx, y, cz], "tag": "thaw",
##    "params": {"kind": "motes_gold", "extent": [20, 6, 20], "count": 26}}

var kind := "motes_gold"
var extent: Array = [20, 6, 20]
var count := 26

var _birds: Array = []   # [{root, wings: [l, r], home: Vector3, fled: bool}]
static var _mote_tex: GradientTexture2D = null

static func _get_mote_tex() -> GradientTexture2D:
	if _mote_tex != null:
		return _mote_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.70, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 0.96, 0.88, 0.55),
		Color(1.0, 0.92, 0.80, 0.12),
		Color(1.0, 0.92, 0.80, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 32
	gt.height = 32
	_mote_tex = gt
	return _mote_tex

func _ready() -> void:
	match kind:
		"motes_gold", "motes_ash":
			_build_motes(kind == "motes_ash")
		"birds":
			_build_birds()

func _build_motes(ash: bool) -> void:
	var p := CPUParticles3D.new()
	p.amount = count * 2
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(extent[0] * 0.5, extent[1] * 0.5, extent[2] * 0.5)
	p.direction = Vector3(0.08, -1, 0.04) if ash else Vector3(0.05, 1, 0.05)
	p.spread = 28.0
	p.gravity = Vector3(0, -0.05, 0) if ash else Vector3(0, 0.018, 0)
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.15
	p.scale_amount_min = 0.45
	p.scale_amount_max = 1.15 if ash else 0.95
	var m := QuadMesh.new()
	m.size = Vector2(0.055, 0.055)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _get_mote_tex()
	if ash:   # the rime's air carries snow crystals, not ash
		mat.albedo_texture = FrostFX.crystal_tex()
		mat.albedo_color = Color(0.88, 0.93, 1.0, 0.7)
		p.angle_max = 360.0
		m.size = Vector2(0.09, 0.09)
	else:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.88, 0.56, 0.52)
	m.material = mat
	p.mesh = m
	p.position.y = extent[1] * 0.5
	add_child(p)
	p.emitting = true

func _build_birds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13 + global_position.z * 7)
	var mat_a := StandardMaterial3D.new()
	mat_a.albedo_color = Color(0.28, 0.25, 0.22)
	mat_a.roughness = 0.88
	var mat_b := StandardMaterial3D.new()
	mat_b.albedo_color = Color(0.38, 0.34, 0.29)
	mat_b.roughness = 0.88
	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = Color(0.76, 0.62, 0.28)
	beak_mat.roughness = 0.55
	var bkm := CylinderMesh.new()
	bkm.top_radius = 0.001
	bkm.bottom_radius = 0.007
	bkm.height = 0.022
	bkm.radial_segments = 6
	bkm.material = beak_mat
	for i in count:
		var home := Vector3(rng.randf_range(-extent[0] * 0.5, extent[0] * 0.5), 0.05,
				rng.randf_range(-extent[2] * 0.5, extent[2] * 0.5))
		var bird := Node3D.new()
		add_child(bird)
		bird.position = home
		bird.rotation.y = rng.randf_range(0, TAU)
		var mat := mat_a if rng.randf() < 0.5 else mat_b

		# Plump ovoid songbird body + head + beak + fan tail
		var body_root := Node3D.new()
		body_root.position.y = 0.055
		bird.add_child(body_root)

		var body := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.036
		bm.height = 0.11
		bm.radial_segments = 10
		bm.rings = 6
		bm.material = mat
		body.mesh = bm
		body.rotation.x = deg_to_rad(72)
		body.scale = Vector3(0.88, 1.0, 0.78)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body_root.add_child(body)

		var head := MeshInstance3D.new()
		var hm := SphereMesh.new()
		hm.radius = 0.024
		hm.height = 0.048
		hm.radial_segments = 8
		hm.rings = 5
		hm.material = mat
		head.mesh = hm
		head.position = Vector3(0, 0.032, -0.046)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body_root.add_child(head)

		var beak := MeshInstance3D.new()
		beak.mesh = bkm
		beak.position = Vector3(0, 0.030, -0.074)
		beak.rotation.x = deg_to_rad(-84)
		beak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body_root.add_child(beak)

		var tail := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.032, 0.008, 0.055)
		tm.material = mat
		tail.mesh = tm
		tail.position = Vector3(0, 0.012, 0.064)
		tail.rotation.x = deg_to_rad(22)
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body_root.add_child(tail)

		var wings: Array = []
		for sd in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(sd * 0.028, 0.062, -0.005)
			# Tucked while foraging on the flagstones; spreads on takeoff
			pivot.scale = Vector3(0.18, 1.0, 0.65)
			bird.add_child(pivot)
			var wing := MeshInstance3D.new()
			var wm := SphereMesh.new()
			wm.radius = 0.065
			wm.height = 0.014
			wm.radial_segments = 8
			wm.rings = 4
			wm.material = mat
			wing.mesh = wm
			wing.scale = Vector3(1.15, 1.0, 0.48)
			wing.position = Vector3(sd * 0.068, 0, 0.008)
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pivot.add_child(wing)
			wings.append(pivot)
		# the peck: a little bow, now and then
		var tw := bird.create_tween()
		tw.set_loops(0)
		tw.tween_interval(rng.randf_range(0.8, 2.2))
		tw.tween_property(body_root, "rotation:x", -0.45, 0.16)
		tw.tween_property(body_root, "rotation:x", 0.0, 0.2)
		_birds.append({"root": bird, "wings": wings, "fled": false})

func _physics_process(_dt: float) -> void:
	if kind != "birds":
		set_physics_process(false)
		return
	if not is_visible_in_tree():
		return
	var p = Game.player
	if p == null:
		return
	var all_fled := true
	for b in _birds:
		if b["fled"]:
			continue
		all_fled = false
		var root: Node3D = b["root"]
		if root.global_position.distance_to(p.global_position) < 3.4:
			b["fled"] = true
			_fly_off(root, b["wings"])
	if all_fled:
		set_physics_process(false)

func _fly_off(bird: Node3D, wings: Array) -> void:
	AudioDirector.play("world/bird_flush", bird.global_position)
	for wi in wings.size():
		var sd := -1.0 if wi == 0 else 1.0
		(wings[wi] as Node3D).scale = Vector3.ONE
		var wtw := (wings[wi] as Node3D).create_tween()
		wtw.set_loops(12)
		wtw.tween_property(wings[wi], "rotation:z", sd * 0.9, 0.08)
		wtw.tween_property(wings[wi], "rotation:z", sd * -0.45, 0.08)
	var away := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var to := bird.global_position + away * 9.0 + Vector3(0, 8.0, 0)
	bird.look_at(bird.global_position + away, Vector3.UP)
	var tw := bird.create_tween()
	tw.tween_property(bird, "global_position", to, 2.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(bird.queue_free)
