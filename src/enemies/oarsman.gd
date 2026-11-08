class_name Oarsman
extends Enemy
## A rower frozen mid-stroke (SLICE.md 5): the ice oar has grown from both
## hands as one piece. The oar is built here (a translucent ice mesh), runs
## from the left hand through the right and out to the blade, and its outer
## length is the hit volume: what the oar sweeps through is what it hits.
## The moves (Stroke -> Back-stroke, Ship oars and its long recovery) are data
## in enemies.json; the arm poses are HumanoidOverlays oar_*.

var oar: MeshInstance3D
var _oar_len := 3.0
var _oar_grip := 0.45     # shaft behind the left hand (the loom)
var _oar_hit_from := 1.2  # hit volume starts this far out from the left hand

func _ready() -> void:
	super._ready()
	var oc: Dictionary = cfg.get("oar", {})
	_oar_len = float(oc.get("length", 3.0))
	_oar_grip = float(oc.get("grip", 0.45))
	_oar_hit_from = float(oc.get("hit_from", 1.2))
	oar = MeshInstance3D.new()
	oar.name = "IceOar"
	oar.mesh = _build_oar_mesh(_oar_len, float(oc.get("blade_len", 0.85)), float(oc.get("blade_w", 0.28)))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ice.gdshader")
	oar.material_override = mat
	oar.top_level = true
	oar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	vis.add_child(oar)   # under vis: the death dissolve shatters it too
	# the hit volume: a box over the outer shaft and the blade
	blade_hitbox = Hitbox.new()
	blade_hitbox.name = "OarHitbox"
	blade_hitbox.exclude = self
	blade_hitbox.friendly_team = "enemy"
	blade_hitbox.on_contact = _on_hit_contact
	blade_hitbox.top_level = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var reach := _oar_len - _oar_grip - _oar_hit_from
	box.size = Vector3(0.55, reach, 0.55)
	cs.shape = box
	cs.position = Vector3(0, _oar_hit_from + reach * 0.5, 0)
	blade_hitbox.add_child(cs)
	add_child(blade_hitbox)
	_sync_blade()

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	if not dead:
		_sync_blade()

## The oar's frame this tick: origin at the left hand, +Y out through the
## right hand toward the blade.
func oar_xform() -> Transform3D:
	var l := vis.bone_xform("mixamorig_LeftHand").origin
	var r := vis.bone_xform("mixamorig_RightHand").origin
	var dir := r - l
	if dir.length() < 0.08:
		dir = -vis.global_transform.basis.z
	dir = dir.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = vis.global_transform.basis.x
	var z := side.normalized().cross(dir).normalized()
	var b := Basis(dir.cross(z).normalized(), dir, z)
	return Transform3D(b, l)

## The far end of the oar (blade tip) in world space.
func oar_tip() -> Vector3:
	var x := oar_xform()
	return x.origin + x.basis.y * (_oar_len - _oar_grip)

func _sync_blade() -> void:
	if oar == null or vis == null:
		return
	var x := oar_xform()
	oar.global_transform = Transform3D(x.basis, x.origin - x.basis.y * _oar_grip)
	blade_hitbox.global_transform = x

## A loom (shaft) tapering to a flat blade, with a few grown icicle spurs.
static func _build_oar_mesh(length: float, blade_len: float, blade_w: float) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8
	var shaft := length - blade_len
	for i in segs:
		var a0 := TAU * float(i) / segs
		var a1 := TAU * float(i + 1) / segs
		var r0 := 0.055
		var r1 := 0.04
		var p00 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10 := Vector3(cos(a0) * r1, shaft, sin(a0) * r1)
		var p11 := Vector3(cos(a1) * r1, shaft, sin(a1) * r1)
		for v in [p00, p10, p01, p01, p10, p11]:
			st.add_vertex(v)
	# the blade: a flattened lozenge, widest two-thirds out
	var t := 0.05
	var rows := [[shaft, 0.04], [shaft + blade_len * 0.25, blade_w * 0.8], [shaft + blade_len * 0.7, blade_w],
		[length, blade_w * 0.45]]
	for i in rows.size() - 1:
		var y0: float = rows[i][0]
		var w0: float = rows[i][1] * 0.5
		var y1: float = rows[i + 1][0]
		var w1: float = rows[i + 1][1] * 0.5
		for sz in [-1.0, 1.0]:
			var a := Vector3(-w0, y0, sz * t * 0.5)
			var b := Vector3(w0, y0, sz * t * 0.5)
			var c := Vector3(w1, y1, sz * t * 0.5)
			var d := Vector3(-w1, y1, sz * t * 0.5)
			if sz > 0:
				for v in [a, b, c, a, c, d]:
					st.add_vertex(v)
			else:
				for v in [a, c, b, a, d, c]:
					st.add_vertex(v)
		for sx in [-1.0, 1.0]:   # the blade's edges
			var e0 := Vector3(sx * w0, y0, -t * 0.5)
			var e1 := Vector3(sx * w0, y0, t * 0.5)
			var e2 := Vector3(sx * w1, y1, t * 0.5)
			var e3 := Vector3(sx * w1, y1, -t * 0.5)
			if sx > 0:
				for v in [e0, e2, e1, e0, e3, e2]:
					st.add_vertex(v)
			else:
				for v in [e0, e1, e2, e0, e2, e3]:
					st.add_vertex(v)
	# icicle spurs where the hands froze to the loom
	for k in 5:
		var y := 0.25 + k * 0.22
		var ang := k * 2.3
		var base := Vector3(cos(ang) * 0.05, y, sin(ang) * 0.05)
		var tip := base + Vector3(cos(ang) * 0.09, -0.12, sin(ang) * 0.09)
		var s1 := base + Vector3(0, 0.05, 0)
		var s2 := base + Vector3(sin(ang) * 0.03, 0, -cos(ang) * 0.03)
		for v in [s1, s2, tip, s2, base, tip, base, s1, tip]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()
