class_name Projectile
extends Area3D
## A sung versicle / censer ember: slow, readable, dodgeable. Travels flat,
## hits the first opposing hurtbox, dies on world geometry or timeout.
## Blockable, never parryable.

var packet: DamagePacket
var velocity := Vector3.ZERO
var team := "enemy"
var _ttl := 6.0
var _tint := Color(0.62, 0.75, 1.0)

static func launch(parent: Node, from: Vector3, dir: Vector3, speed: float,
		pk: DamagePacket, color := Color(0.62, 0.75, 1.0)) -> Projectile:
	var p := Projectile.new()
	p.packet = pk
	p.velocity = dir.normalized() * speed
	parent.add_child(p)
	p.global_position = from
	p._dress(color)
	return p

## A loosed shaft: same flight and rules, but it LOOKS like an arrow —
## wood, steel and fletching along the line of flight, no glowing orb.
static func launch_arrow(parent: Node, from: Vector3, dir: Vector3, speed: float,
		pk: DamagePacket) -> Projectile:
	var p := Projectile.new()
	p.packet = pk
	p.velocity = dir.normalized() * speed
	parent.add_child(p)
	p.global_position = from
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	p.global_transform.basis = Basis.looking_at(d, up)
	p.add_child(make_arrow())
	return p

## The arrow model, -Z forward from the nock: ash shaft, steel head, a
## goose-feather hint at the tail. Shared by the nocked visual and the shot.
static func make_arrow() -> Node3D:
	var root := Node3D.new()
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.011
	cm.bottom_radius = 0.011
	cm.height = 0.56
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.33, 0.22)
	cm.material = wood
	shaft.mesh = cm
	shaft.rotation_degrees = Vector3(90, 0, 0)   # cylinder Y -> -Z flight line
	shaft.position = Vector3(0, 0, -0.06)
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.0
	hm.bottom_radius = 0.026
	hm.height = 0.07
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.6, 0.62, 0.66)
	steel.metallic = 0.7
	steel.roughness = 0.35
	hm.material = steel
	head.mesh = hm
	head.rotation_degrees = Vector3(-90, 0, 0)
	head.position = Vector3(0, 0, -0.37)
	root.add_child(head)
	var fletch := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.004, 0.05, 0.09)
	var feather := StandardMaterial3D.new()
	feather.albedo_color = Color(0.75, 0.7, 0.58)
	fm.material = feather
	fletch.mesh = fm
	fletch.position = Vector3(0, 0, 0.2)
	root.add_child(fletch)
	var fletch2 := fletch.duplicate()
	fletch2.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(fletch2)
	return root

func _init() -> void:
	collision_layer = 0
	collision_mask = 1 << (RH.L_HURTBOX - 1)
	monitorable = false
	area_entered.connect(_on_area)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.22
	cs.shape = sph
	add_child(cs)

func _dress(color: Color) -> void:
	_tint = color
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.11
	m.height = 0.22
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lerp(Color.WHITE, 0.45)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.6
	m.material = mat
	mi.mesh = m
	add_child(mi)
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(0.54, 0.54)
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hmat.albedo_color = Color(color.r, color.g, color.b, 0.72)
	hmat.albedo_texture = AreaPortal._radial_tex()
	hq.material = hmat
	halo.mesh = hq
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.4
	l.omni_range = 3.5
	l.shadow_enabled = false
	add_child(l)
	var tr := CPUParticles3D.new()
	tr.amount = 26
	tr.lifetime = 0.5
	tr.local_coords = false
	tr.direction = Vector3.ZERO
	tr.spread = 180.0
	tr.gravity = Vector3.ZERO
	tr.initial_velocity_min = 0.05
	tr.initial_velocity_max = 0.3
	tr.scale_amount_min = 0.02
	tr.scale_amount_max = 0.05
	tr.color = Color(color.r, color.g, color.b, 0.65)
	tr.mesh = AreaPortal.make_mote_quad(1.8)
	add_child(tr)

func _physics_process(dt: float) -> void:
	_ttl -= dt
	if _ttl <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * dt
	# die on world geometry
	var ray := PhysicsRayQueryParameters3D.create(from, to, RH.M_WORLD_ALL)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		_poof(hit["position"])
		return
	global_position = to

func _on_area(a: Area3D) -> void:
	if packet == null or not (a is Hurtbox):
		return
	if (a as Hurtbox).team == team:
		return
	packet.origin = global_position - velocity   # block test faces the flight
	var result := (a as Hurtbox).receive(packet)
	if result != "immune":
		_poof(global_position)

## Whoever sang it is gone: it goes out where it is.
func dispel() -> void:
	if not is_queued_for_deletion():
		_poof(global_position)

func _poof(at: Vector3) -> void:
	set_deferred("monitoring", false)
	packet = null
	velocity = Vector3.ZERO
	var burst := CPUParticles3D.new()
	burst.amount = 30
	burst.lifetime = 0.4
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.6
	burst.gravity = Vector3.ZERO
	burst.scale_amount_min = 0.02
	burst.scale_amount_max = 0.06
	burst.color = Color(_tint.r, _tint.g, _tint.b, 0.82)
	burst.mesh = AreaPortal.make_mote_quad(1.8)
	get_parent().add_child(burst)
	burst.global_position = at
	burst.emitting = true
	var btw := burst.create_tween()
	btw.tween_interval(1.0)
	btw.tween_callback(burst.queue_free)
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", at, -14.0, 1.6)
	queue_free()
