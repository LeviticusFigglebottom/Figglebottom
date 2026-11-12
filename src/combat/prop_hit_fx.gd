class_name PropHitFX
## The burst a blade raises from the world: chips, dust, sparks, shards,
## fibres, clods or a puff of snow, with its sound and (if the data says)
## a breath of camera shake. Every number is data (data/surfaces.json fx);
## one burst is a handful of one-shot CPU emitters under one node, freed
## when the longest of them has lived.

const GROUP := &"prop_bursts"

static var _meshes: Dictionary = {}     # layer look -> Mesh, shared by every burst

static func clear_cache() -> void:
	_meshes.clear()

## Raise one burst of `surface` at `pos`, thrown off `normal` and carried
## along `along` (the blade's direction of travel). Returns its root, or
## null when the surface takes a blow in silence.
static func burst(host: Node, pos: Vector3, normal: Vector3, surface: String,
		along := Vector3.ZERO, heavy := false) -> Node3D:
	var fx: Dictionary = (Surfaces.table().get("fx", {}) as Dictionary).get(surface, {})
	if fx.is_empty() or host == null or not host.is_inside_tree():
		return null
	var parent: Node = host.get_tree().current_scene
	if parent == null:
		parent = host.get_tree().root
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var might := float(DB.tuning("prop_hit/heavy_scale", 1.5)) if heavy else 1.0
	# off the face, carried a little with the blade, lifted a little
	var slide := along - n * along.dot(n)
	var dir := n + slide.limit_length(1.0) * float(DB.tuning("prop_hit/carry", 0.55)) \
			+ Vector3.UP * float(DB.tuning("prop_hit/up", 0.3))
	dir = dir.normalized() if dir.length_squared() > 0.0001 else n

	var root := Node3D.new()
	root.name = "PropBurst_" + surface
	root.add_to_group(GROUP)
	root.set_meta("surface", surface)
	parent.add_child(root)
	root.global_position = pos + n * float(DB.tuning("prop_hit/lift", 0.04))
	var life := 0.0
	for l in fx.get("layers", []):
		var p := _emitter(l, dir, might)
		root.add_child(p)
		p.emitting = true
		life = maxf(life, p.lifetime)
	if fx.has("light"):
		_flash(root, fx["light"])
	RH.free_after(root, life + 0.15)   # the last particle has gone out

	# the recorded strike for this surface (audio.json "impacts"); the takes'
	# own level and pitch spread are the registry's
	root.set_meta("sound", AudioDirector.impact_key(surface))
	AudioDirector.impact(surface, pos, 0.0, float(DB.tuning("prop_hit/heavy_pitch", 0.88)) if heavy else 1.0)
	var sh: Array = fx.get("shake", [])
	if sh.size() == 2 and float(sh[0]) > 0.0:
		Juice.shake(float(sh[0]) * might, float(sh[1]))
	return root

static func _emitter(l: Dictionary, dir: Vector3, might: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = maxi(1, int(round(float(l.get("amount", 8)) * might)))
	p.lifetime = float(l.get("life", 0.5))
	p.explosiveness = float(l.get("explosiveness", 0.95))
	p.direction = dir
	p.spread = float(l.get("spread", 45.0))
	var sp: Array = l.get("speed", [1.0, 3.0])
	p.initial_velocity_min = float(sp[0])
	p.initial_velocity_max = float(sp[1])
	p.gravity = Vector3(0, -float(l.get("gravity", 9.8)), 0)
	var dm := float(l.get("damping", 0.0))
	p.damping_min = dm
	p.damping_max = dm
	var sz: Array = l.get("size", [0.05, 0.1])
	p.scale_amount_min = float(sz[0])
	p.scale_amount_max = float(sz[1])
	var c: Array = l.get("color", [1, 1, 1, 1])
	var col := Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]) if c.size() > 3 else 1.0)
	p.color = col
	var kind := String(l.get("mesh", "quad"))
	if kind == "quad":
		# a puff swells and thins; a glint just goes out
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
		p.color_ramp = ramp
		if l.has("grow"):
			var cv := Curve.new()
			cv.add_point(Vector2(0.0, 1.0 / float(l["grow"])))
			cv.add_point(Vector2(1.0, 1.0))
			p.scale_amount_curve = cv
			p.scale_amount_min *= float(l["grow"])
			p.scale_amount_max *= float(l["grow"])
		p.angle_min = 0.0
		p.angle_max = 360.0
	else:
		# solid bits fly end-on along their path and shrink away at the last
		p.particle_flag_align_y = true
		var cv2 := Curve.new()
		cv2.add_point(Vector2(0.0, 1.0))
		cv2.add_point(Vector2(0.75, 1.0))
		cv2.add_point(Vector2(1.0, 0.0))
		p.scale_amount_curve = cv2
	p.mesh = _mesh(l, kind)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

## The unit mesh a layer scales (its `size` is metres): a camera-facing
## quad with one of FrostFX's drawn textures, a sliver (a chip, a spark, a
## fibre: long on Y, which rides the velocity) or a chunk (a clod, a flake).
static func _mesh(l: Dictionary, kind: String) -> Mesh:
	var additive := bool(l.get("additive", false))
	var lit := bool(l.get("lit", false))
	var tex := String(l.get("tex", "soft"))
	var thin := float(l.get("thin", 0.22))
	var hot := float(l.get("hot", 1.0))     # over 1: bright enough to bloom
	var key := "%s|%s|%s|%s|%.2f|%.2f" % [kind, tex, additive, lit, thin, hot]
	if _meshes.has(key):
		return _meshes[key]
	var mesh: Mesh
	if kind == "quad":
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE
		var t: Texture2D = FrostFX.crystal_tex() if tex == "crystal" else (FrostFX.drip_tex() if tex == "drip" else FrostFX.soft_tex())
		var qmat := FrostFX.material(t, Color(hot, hot, hot), additive)
		qmat.vertex_color_is_srgb = true   # the data's colours are as a painter reads them
		qm.material = qmat
		mesh = qm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(thin, 1.0, thin * 0.6) if kind == "sliver" else Vector3(0.8, 1.0, 0.65)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true      # (left linear, tan chips and orange sparks wash out to cream)
		m.albedo_color = Color(hot, hot, hot)
		m.roughness = 0.9
		if additive:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.material = m
		mesh = bm
	_meshes[key] = mesh
	return mesh

static func _flash(root: Node3D, cfg: Dictionary) -> void:
	var l := OmniLight3D.new()
	var c: Array = cfg.get("color", [1, 0.8, 0.4])
	l.light_color = Color(float(c[0]), float(c[1]), float(c[2]))
	l.light_energy = float(cfg.get("energy", 1.5))
	l.omni_range = float(cfg.get("range", 2.8))
	l.shadow_enabled = false
	root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, float(cfg.get("fade", 0.14)))
	tw.tween_callback(l.queue_free)
