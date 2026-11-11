class_name TideWall
extends Node3D
## The tide froze mid-surge (SLICE.md 2, RIME): a glass wall about three
## metres high along the old waterline, its crest curling landward, with
## the things the wave was carrying stopped inside it (kelp, an oar).
## A scripted area entity, tag rime; built from a polyline of [x, z] world
## points. Segments whose middle falls inside a "gaps" [x0, x1] range are
## left open (the frozen channel to the sea stack runs through one).

var points: Array = []          # [[x, z], ...] along the waterline, west to east
var height := 3.0               # crest height over the base, metres
var base_y := -0.9              # the wall's foot, under the shingle
var thick := 1.1
var curl := 0.7                 # how far the crest leans toward the land
var gaps: Array = []            # [[x0, x1], ...]
var landward := Vector3(0, 0, -1)   # the beach side

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 7707
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (RH.L_WORLD_RIME - 1)
	body.collision_mask = 0
	Surfaces.stamp_kind(body, "tide_wall")
	add_child(body)
	for i in range(points.size() - 1):
		var a := Vector3(float(points[i][0]), 0.0, float(points[i][1]))
		var b := Vector3(float(points[i + 1][0]), 0.0, float(points[i + 1][1]))
		var mid := (a + b) * 0.5
		if _in_gap(mid.x):
			continue
		_segment(st, a, b)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var seg := b - a
		box.size = Vector3(seg.length() + 0.2, height + 0.5, thick)
		cs.shape = box
		cs.position = mid + Vector3(0, base_y + (height + 0.5) * 0.5, 0) - global_position
		cs.rotation.y = atan2(-seg.z, seg.x)
		body.add_child(cs)
		_frozen_in(mid, seg)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = MaterialLib.get_mat("M_ice", 2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)

func _in_gap(x: float) -> bool:
	for g in gaps:
		if x >= float(g[0]) and x <= float(g[1]):
			return true
	return false

## One length of wave: a sea face, a land face, a curling crest. The crest
## height wanders so the line reads as a frozen surge, not a dyke.
func _segment(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var steps := maxi(2, int((b - a).length() / 1.5))
	var dir := (b - a).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	if side.dot(landward) < 0.0:
		side = -side          # side points at the beach
	var prev := []
	for k in steps + 1:
		var t := float(k) / float(steps)
		var p := a.lerp(b, t) - global_position
		var crest := height * (0.82 + 0.18 * sin(p.x * 0.37) + 0.08 * sin(p.x * 1.3 + 2.0))
		var lip := curl * (0.6 + 0.4 * sin(p.x * 0.53 + 1.0))
		var sea_lo := p - side * thick * 0.5 + Vector3(0, base_y, 0)
		var land_lo := p + side * thick * 0.5 + Vector3(0, base_y, 0)
		var sea_hi := p - side * thick * 0.2 + Vector3(0, base_y + crest, 0)
		var land_hi := p + side * (thick * 0.3 + lip) + Vector3(0, base_y + crest * 0.93, 0)
		var cur := [sea_lo, sea_hi, land_hi, land_lo]
		if not prev.is_empty():
			for f in 3:
				_quad(st, prev[f], cur[f], cur[f + 1], prev[f + 1])
		prev = cur

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)
	for v in [a, c, b, a, d, c]:   # both faces: the wall is seen from the beach and the ice
		st.add_vertex(v)

## What the wave was carrying, stopped in it: kelp ribbons, now and then an
## oar, standing out of the land face.
func _frozen_in(mid: Vector3, seg: Vector3) -> void:
	var dir := seg.normalized()
	var n := int(seg.length() / 5.0)
	for k in n:
		var p := mid - global_position + dir * _rng.randf_range(-seg.length() * 0.45, seg.length() * 0.45)
		var kelp := MeshInstance3D.new()
		var km := BoxMesh.new()
		km.size = Vector3(0.12, _rng.randf_range(0.8, 1.6), 0.03)
		kelp.mesh = km
		kelp.material_override = MaterialLib.get_mat("M_peat", 2)
		kelp.position = p + landward * (thick * 0.5) + Vector3(0, _rng.randf_range(0.6, 2.2), 0)
		kelp.rotation = Vector3(_rng.randf_range(-0.4, 0.4), atan2(-dir.z, dir.x), _rng.randf_range(-0.7, 0.7))
		kelp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		kelp.visibility_range_end = 60.0
		add_child(kelp)
	if seg.length() > 6.0 and _rng.randf() < 0.35:
		var oar := MeshInstance3D.new()
		var om := BoxMesh.new()
		om.size = Vector3(2.6, 0.07, 0.12)
		oar.mesh = om
		oar.material_override = MaterialLib.get_mat("M_drift", 2)
		oar.position = mid - global_position + landward * (thick * 0.45) + Vector3(0, 1.4, 0)
		oar.rotation = Vector3(0, atan2(-dir.z, dir.x) + 0.3, 0.5)
		add_child(oar)
