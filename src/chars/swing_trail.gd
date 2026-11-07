class_name SwingTrail
extends MeshInstance3D
## The swoosh: while visible, the blade's base and tip are sampled every
## frame and stitched into a short-lived Catmull-Rom subdivided ribbon —
## the actual arc the swing swept, fading along its length.

const LIFE := 0.15          # seconds of arc kept behind the blade
var base_up := 0.12         # sample points along the blade (+Y from grip)
var tip_up := 1.08
const SUBDIV := 3

var target: Node3D          # the weapon mount; kit blades run +Y from it
var _pts: Array = []        # newest-first: {b: Vector3, t: Vector3, at: float}
var _clock := 0.0
var _was_visible := false

func _init() -> void:
	top_level = true        # ribbon lives in world space, not on the hand
	mesh = ImmediateMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/trail.gdshader")
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false

func _process(dt: float) -> void:
	_clock += dt
	if visible and not _was_visible:
		_pts.clear()        # a fresh swing sweeps a fresh arc
	_was_visible = visible
	if not visible:
		return
	global_transform = Transform3D.IDENTITY
	if target != null and is_instance_valid(target):
		var xf := target.global_transform
		_pts.push_front({"b": xf * Vector3(0, base_up, 0),
				"t": xf * Vector3(0, tip_up, 0), "at": _clock})
	while _pts.size() > 2 and _clock - float(_pts[_pts.size() - 1]["at"]) > LIFE:
		_pts.pop_back()
	_rebuild()

static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _rebuild() -> void:
	var im := mesh as ImmediateMesh
	im.clear_surfaces()
	var n := _pts.size()
	if n < 2:
		return
	var sub_b: Array[Vector3] = []
	var sub_t: Array[Vector3] = []
	for i in range(n - 1):
		var i0 := maxi(i - 1, 0)
		var i1 := i
		var i2 := i + 1
		var i3 := mini(i + 2, n - 1)
		for s in range(SUBDIV):
			var f := float(s) / float(SUBDIV)
			sub_b.append(_catmull_rom(_pts[i0]["b"], _pts[i1]["b"], _pts[i2]["b"], _pts[i3]["b"], f))
			sub_t.append(_catmull_rom(_pts[i0]["t"], _pts[i1]["t"], _pts[i2]["t"], _pts[i3]["t"], f))
	sub_b.append(_pts[n - 1]["b"])
	sub_t.append(_pts[n - 1]["t"])

	var total := sub_b.size()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in total:
		var k := float(i) / float(maxi(total - 1, 1))   # 0 at the blade, 1 at the tail
		im.surface_set_uv(Vector2(k, 0.0))
		im.surface_add_vertex(sub_b[i])
		im.surface_set_uv(Vector2(k, 1.0))
		im.surface_add_vertex(sub_t[i])
	im.surface_end()
