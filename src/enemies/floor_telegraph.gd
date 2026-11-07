class_name FloorTelegraph
extends MeshInstance3D
## A tell drawn on the floor during a windup: a faint cold glow over the exact
## ground an attack will cover (a strip, a rectangle, a fan or a ring), rising
## to full strength as the windup ends. The shape is the hit area, so the fight
## can be learned: what glows is what lands.

var life := 1.0
var _t := 0.0
var _mat: StandardMaterial3D
var color := Color(0.55, 0.8, 1.0)

## shape: "rect" (size = [width, length], from the origin forward along -Z),
## "fan" (size = [range, degrees]), "ring" (size = [radius]).
static func spawn(parent: Node, xform: Transform3D, shape: String, size: Array, duration: float,
		tint := Color(0.55, 0.8, 1.0)) -> FloorTelegraph:
	var t := FloorTelegraph.new()
	t.life = maxf(duration, 0.05)
	t.color = tint
	t.mesh = _shape_mesh(shape, size)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(t)
	t.global_transform = Transform3D(xform.basis.orthonormalized(), xform.origin + Vector3.UP * 0.04)
	return t

static func _shape_mesh(shape: String, size: Array) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match shape:
		"rect":
			var w := float(size[0]) * 0.5
			var l := float(size[1])
			var steps := maxi(int(l / 0.5), 1)
			for i in steps:   # strips so the glow can sweep forward
				var z0 := -l * float(i) / steps
				var z1 := -l * float(i + 1) / steps
				var u0 := float(i) / steps
				var u1 := float(i + 1) / steps
				_quad(st, Vector3(-w, 0, z0), Vector3(w, 0, z0), Vector3(w, 0, z1), Vector3(-w, 0, z1), u0, u1)
		"fan":
			var r := float(size[0])
			var half := deg_to_rad(float(size[1]) * 0.5)
			var segs := 18
			for i in segs:
				var a0 := lerpf(-half, half, float(i) / segs)
				var a1 := lerpf(-half, half, float(i + 1) / segs)
				var p0 := Vector3(sin(a0), 0, -cos(a0)) * r
				var p1 := Vector3(sin(a1), 0, -cos(a1)) * r
				st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3.ZERO)
				st.set_uv(Vector2(1, 1)); st.add_vertex(p1)
				st.set_uv(Vector2(1, 1)); st.add_vertex(p0)
		_:   # ring disc
			var rr := float(size[0])
			var segs2 := 32
			for i in segs2:
				var b0 := TAU * float(i) / segs2
				var b1 := TAU * float(i + 1) / segs2
				st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3.ZERO)
				st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(cos(b1), 0, sin(b1)) * rr)
				st.set_uv(Vector2(1, 1)); st.add_vertex(Vector3(cos(b0), 0, sin(b0)) * rr)
	return st.commit()

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, u0: float, u1: float) -> void:
	for v in [[a, u0], [b, u0], [c, u1], [a, u0], [c, u1], [d, u1]]:
		st.set_uv(Vector2(v[1], v[1]))
		st.add_vertex(v[0])

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.no_depth_test = false
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.0)
	material_override = _mat

func _process(dt: float) -> void:
	_t += dt
	var k := clampf(_t / life, 0.0, 1.0)
	# faint at once (you can always see it), full at the strike; a pulse
	# quickens toward the end so the beat itself is readable
	var pulse := 0.5 + 0.5 * sin(_t * lerpf(6.0, 22.0, k))
	_mat.albedo_color.a = lerpf(0.12, 0.55, k * k) + 0.08 * pulse
	if _t >= life:
		queue_free()
