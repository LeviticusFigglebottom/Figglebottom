class_name BrokenIce
extends Node3D
## Ice broken open at runtime (KETTLE.md 5, 6): a disc or a ring of black
## water that takes the Bearer if he stays on it (HazardVolume kind "thin",
## `sink` seconds), shown for `life` seconds and then frozen over again. The
## Ice-fisher's Cut a hole, the Ice-Cutter's Drill down and Ring cut, and his
## phase-two ring round the arena. A disc is one thin volume; a ring is a
## band of them round the circle. close() freezes it early.

signal closed_over(ice)

var shape := "disc"
var radius := 2.0
var inner := 0.0
var life := 6.0
var sink := 1.0
var _t := 0.0
var _closing := false
var _water: MeshInstance3D
var _mat: StandardMaterial3D
var volumes: Array = []

static func open(parent: Node, at: Vector3, p_shape: String, p_radius: float, p_inner: float,
		p_life: float, p_sink: float) -> BrokenIce:
	var b := BrokenIce.new()
	b.shape = p_shape
	b.radius = p_radius
	b.inner = p_inner
	b.life = p_life
	b.sink = p_sink
	parent.add_child(b)
	b.global_position = at
	return b

func _ready() -> void:
	add_to_group("broken_ice")
	_build_volumes()
	_water = MeshInstance3D.new()
	_water.mesh = FloorTelegraph._shape_mesh("annulus" if shape == "ring" else "ring",
			[inner, radius] if shape == "ring" else [radius])
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(0.03, 0.06, 0.1, 0.0)
	_water.material_override = _mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.position.y = 0.09
	add_child(_water)
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color:a", 0.92, 0.18)
	_shards()
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -2.0, 0.55)

## The thin volumes: one square inside a disc, or boxes round a ring.
func _build_volumes() -> void:
	if shape == "ring":
		var mid := (radius + inner) * 0.5
		var band := maxf(radius - inner, 0.4)
		var n := maxi(int(TAU * mid / band), 8)
		for i in n:
			var a := TAU * (float(i) + 0.5) / n
			var seg := TAU * mid / n
			_volume(Vector3(cos(a), 0, sin(a)) * mid, Vector3(band, 1.6, seg * 1.05), -a)
	else:
		var side := radius * 1.6   # inside the circle, nearly to its rim
		_volume(Vector3.ZERO, Vector3(side, 1.6, side), 0.0)

func _volume(pos: Vector3, size: Vector3, yaw: float) -> void:
	var h := HazardVolume.new()
	h.kind = "thin"
	h.seconds = sink
	h.size = size
	add_child(h)
	h.position = pos + Vector3.UP * 0.1
	h.rotation.y = yaw
	volumes.append(h)

func _shards() -> void:
	var p := CPUParticles3D.new()
	p.amount = int(clampf(radius * 30.0, 30, 160))
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING if shape == "ring" else CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = inner
	p.emission_ring_height = 0.1
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.8
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	p.color = Color(0.85, 0.92, 1.0, 0.9)
	p.mesh = AreaPortal.make_mote_quad(1.4)
	add_child(p)
	p.position.y = 0.15
	p.emitting = true

func _physics_process(dt: float) -> void:
	_t += dt
	if not _closing and _t >= life:
		close()

## Freeze over: the volumes go at once, the water greys to white.
func close() -> void:
	if _closing:
		return
	_closing = true
	for v in volumes:
		if is_instance_valid(v):
			v.queue_free()
	volumes.clear()
	closed_over.emit(self)
	var tw := create_tween()
	tw.tween_property(_mat, "albedo_color", Color(0.82, 0.88, 0.94, 0.0), 1.2)
	tw.tween_callback(queue_free)

func is_open() -> bool:
	return not _closing

## Whether a point on the ice is over this open water.
func covers(p: Vector3) -> bool:
	if _closing:
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	return d <= radius and d >= inner

## Close the area's own hole for good (a released Holdfast; KETTLE.md 9):
## the thin volumes and water within `r` of `at` go, and new ice lies over.
static func seal_at(area: Node, at: Vector3, r: float) -> void:
	if area == null:
		return
	for h in area.find_children("*", "HazardVolume", true, false):
		var hv := h as HazardVolume
		if hv.kind == "thin" and Vector2(hv.global_position.x - at.x, hv.global_position.z - at.z).length() <= r:
			hv.queue_free()
	for w in area.find_children("*", "MeshInstance3D", true, false):
		var mi := w as MeshInstance3D
		if String(mi.name).contains("Water") and Vector2(mi.global_position.x - at.x, mi.global_position.z - at.z).length() <= 0.6:
			mi.visible = false
			mi.set_meta("sealed", true)
	for old in area.get_tree().get_nodes_in_group("sealed_ice") if area.is_inside_tree() else []:
		if (old as Node3D).global_position.distance_to(at) < r:
			return   # already closed over
	var skin := MeshInstance3D.new()
	skin.name = "SealedIce"
	skin.mesh = FloorTelegraph._shape_mesh("ring", [r * 0.9])
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.85, 0.92)
	m.roughness = 0.2
	m.metallic_specular = 0.8
	skin.material_override = m
	area.add_child(skin)
	skin.global_position = Vector3(at.x, at.y + 0.1, at.z)
	skin.add_to_group("sealed_ice")
