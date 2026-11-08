class_name IceRidge
extends StaticBody3D
## A frozen ridge of net-knots thrown up along the floor (the Netmender's
## Knot). It blocks movement for `life` seconds, can be re-frozen (Mend the
## floor) and broken by `breaks_after` heavy hits. Collides on the base layer
## so it cuts the arena in either state.

signal broken(ridge)

var length := 10.0
var life := 10.0
var breaks_after := 2
var heavy_hits := 0
var _t := 0.0
var _mesh: MeshInstance3D
var hurtbox: Hurtbox

func setup(p_length: float, p_life: float, p_breaks := 2) -> void:
	length = p_length
	life = p_life
	breaks_after = p_breaks

func _ready() -> void:
	add_to_group("ice_ridges")
	collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.3, length)
	cs.shape = box
	cs.position = Vector3(0, 0.65, -length * 0.5)
	add_child(cs)
	hurtbox = Hurtbox.new()
	hurtbox.team = "neutral"
	var hcs := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(1.1, 1.4, length)
	hcs.shape = hb
	hcs.position = cs.position
	hurtbox.add_child(hcs)
	add_child(hurtbox)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _spikes()
	add_child(_mesh)
	scale = Vector3(1, 0.05, 1)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A row of knotted ice: lumpy cones along the strip, alternating heights.
func _spikes() -> Mesh:
	var am := ArrayMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.88, 0.98, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic_specular = 0.8
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.55, 0.9)
	mat.emission_energy_multiplier = 0.35
	mat.rim_enabled = true
	mat.rim = 0.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(int(length / 0.55), 2)
	for i in n:
		var z := -length * (float(i) + 0.5) / n
		var h := 0.75 + 0.55 * absf(sin(i * 2.1))
		var r := 0.32 + 0.12 * absf(cos(i * 1.3))
		var x := 0.12 * sin(i * 3.7)
		_cone(st, Vector3(x, 0, z), r, h, 7)
	st.generate_normals()
	st.set_material(mat)
	return st.commit()

static func _cone(st: SurfaceTool, base: Vector3, r: float, h: float, segs: int) -> void:
	var tip := base + Vector3(0, h, 0)
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		st.add_vertex(base + Vector3(cos(a0) * r, 0, sin(a0) * r))
		st.add_vertex(tip)
		st.add_vertex(base + Vector3(cos(a1) * r, 0, sin(a1) * r))

## Mend the floor: the ridge is frozen anew and stands `extra` seconds longer.
func refreeze(extra: float) -> void:
	life = maxf(life - _t, 0.0) + extra
	_t = 0.0
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1.15, 1.2, 1.0), 0.12)
	tw.tween_property(_mesh, "scale", Vector3.ONE, 0.25)

func remaining() -> float:
	return life - _t

func _physics_process(dt: float) -> void:
	_t += dt
	if _t >= life:
		shatter()

## Only heavy blows break it (SLICE.md 6: two heavy hits).
func take_hit(packet: DamagePacket) -> void:
	var heavy := packet.source != null and bool(packet.source.get("_atk_is_heavy"))
	if not heavy:
		return
	heavy_hits += 1
	Juice.shake(0.2, 0.15)
	if heavy_hits >= breaks_after:
		shatter()

func shatter() -> void:
	if is_queued_for_deletion():
		return
	collision_layer = 0
	broken.emit(self)
	FrostDissolve.shards(get_parent(), global_position - global_transform.basis.z * length * 0.5, 1.0)
	queue_free()
