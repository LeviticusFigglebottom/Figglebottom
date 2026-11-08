class_name IceRidge
extends StaticBody3D
## A frozen ridge of net-knots thrown up along the floor (the Netmender's
## Knot). It blocks movement for `life` seconds, can be re-frozen (Mend the
## floor) and broken by `breaks_after` heavy hits. Collides on the base layer
## so it cuts the arena in either state. `style` dresses it: "ice" (knots),
## "sod" (frozen turf laid in courses: the Turfwright's cuts and walls),
## "stone" (a cairn: the Cairn-carrier's set stone).

signal broken(ridge)

var length := 10.0
var life := 10.0
var breaks_after := 2
var heavy_hits := 0
var style := "ice"
var height := 1.3
var _t := 0.0
var _mesh: MeshInstance3D
var hurtbox: Hurtbox

func setup(p_length: float, p_life: float, p_breaks := 2, p_style := "ice") -> void:
	length = p_length
	life = p_life
	breaks_after = p_breaks
	style = p_style

func _ready() -> void:
	add_to_group("ice_ridges")
	collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, height, length)
	cs.shape = box
	cs.position = Vector3(0, height * 0.5, -length * 0.5)
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
	_mesh.mesh = _sods() if style == "sod" else (_stones() if style == "stone" else _spikes())
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

## Cut turf laid in courses, like a sod wall: dark peat sides, a frosted top.
func _sods() -> Mesh:
	var side_mat := StandardMaterial3D.new()
	side_mat.albedo_color = Color(0.3, 0.22, 0.15)
	side_mat.roughness = 0.95
	side_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var top_mat := StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.78, 0.82, 0.88)
	top_mat.roughness = 0.9
	top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tops := SurfaceTool.new()
	tops.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(int(length / 0.62), 1)
	var courses := 3
	for c in courses:
		var y0 := c * height / courses
		var y1 := (c + 1) * height / courses - 0.04
		var shift := 0.31 if c % 2 == 1 else 0.0
		for i in n + 1:
			var z0 := -clampf(i * length / n - shift, 0.0, length)
			var z1 := -clampf((i + 1) * length / n - shift - 0.05, 0.0, length)
			if z0 - z1 < 0.1:
				continue
			var w := 0.42 + 0.05 * sin(i * 2.7 + c)
			_block(sides, tops if c == courses - 1 else sides, Vector3(-w, y0, z1), Vector3(w, y1, z0))
	sides.generate_normals()
	sides.set_material(side_mat)
	var am := sides.commit()
	tops.generate_normals()
	tops.set_material(top_mat)
	return tops.commit(am)

## A cairn of frozen schist: rough rounded stones heaped along the strip.
func _stones() -> Mesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.5, 0.48)
	mat.roughness = 0.85
	mat.rim_enabled = true
	mat.rim = 0.35
	var rock := SphereMesh.new()
	rock.radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 7
	rock.rings = 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := maxi(int(length / 0.55), 2)
	for i in n:
		var z := -length * (float(i) + 0.5) / n
		for k in 3:
			var r := 0.3 + 0.1 * absf(sin(i * 1.9 + k))
			var y := 0.22 + k * 0.38
			var x := 0.18 * sin(i * 3.1 + k * 1.7)
			var b := Basis(Vector3.UP, i * 1.3 + k).scaled(Vector3(r * 1.15, r * 0.75, r))
			st.append_from(rock, 0, Transform3D(b, Vector3(x, y, z)))
	st.generate_normals()
	st.set_material(mat)
	return st.commit()

## An axis-aligned block: its upper face goes to `top` (the frosted course).
static func _block(st: SurfaceTool, top: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var p := [Vector3(a.x, a.y, a.z), Vector3(b.x, a.y, a.z), Vector3(b.x, a.y, b.z), Vector3(a.x, a.y, b.z),
		Vector3(a.x, b.y, a.z), Vector3(b.x, b.y, a.z), Vector3(b.x, b.y, b.z), Vector3(a.x, b.y, b.z)]
	var faces := [[4, 7, 6, 5], [0, 1, 2, 3], [0, 4, 5, 1], [2, 6, 7, 3], [1, 5, 6, 2], [3, 7, 4, 0]]
	for fi in faces.size():
		var f: Array = faces[fi]
		var to := top if fi == 0 else st
		for idx in [f[0], f[1], f[2], f[0], f[2], f[3]]:
			to.add_vertex(p[idx])

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
