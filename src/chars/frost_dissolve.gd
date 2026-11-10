class_name FrostDissolve
## Tripo characters import with StandardMaterial3D, which the shared death
## dissolve (a `death_diss` uniform on ShaderMaterials, RH.set_dissolve) never
## reached, so the dead simply vanished. apply() swaps each surface for a
## frost_dissolve.gdshader copy carrying the same textures; RH.set_dissolve
## then frosts the body over and shatters it away.

const SHADER := preload("res://shaders/frost_dissolve.gdshader")

## One frost material per source material, shared by every body of that
## kind (all the Rimewalkers shatter from the same one); RH.set_dissolve
## clones it per body only when that body starts to go.
static var _cache: Dictionary = {}

static func _shared(src: Material) -> ShaderMaterial:
	var key = src if src != null else "none"
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var std := src as BaseMaterial3D
	if std != null:
		m.set_shader_parameter("albedo_tex", std.albedo_texture)
		m.set_shader_parameter("albedo_color", std.albedo_color)
		m.set_shader_parameter("roughness", std.roughness)
		if std.normal_enabled and std.normal_texture != null:
			m.set_shader_parameter("normal_tex", std.normal_texture)
			m.set_shader_parameter("normal_scale", std.normal_scale)
			m.set_shader_parameter("has_normal", true)
	_cache[key] = m
	return m

static func clear_cache() -> void:
	_cache.clear()

static func apply(root: Node) -> int:
	var n := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.has_meta("_frost_diss"):
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.get_surface_override_material(s)
			if src == null:
				src = mi.mesh.surface_get_material(s)
			if src is ShaderMaterial:
				continue   # already dissolvable (hall.gdshader greybox)
			mi.set_surface_override_material(s, _shared(src))
			n += 1
		mi.set_meta("_frost_diss", true)
	return n

## A burst of ice flakes where a body shatters (the end of the dissolve).
static func shards(parent: Node, at: Vector3, height := 1.6) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.75
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35, height * 0.5, 0.35)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.08
	p.color = Color(0.8, 0.9, 1.0, 0.9)
	p.mesh = AreaPortal.make_mote_quad(1.2)
	parent.add_child(p)
	p.global_position = at + Vector3.UP * height * 0.5
	p.emitting = true
	RH.free_after(p, 1.6)
