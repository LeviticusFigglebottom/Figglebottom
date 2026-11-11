class_name IceCrack
extends MeshInstance3D
## The warning before ice breaks (KETTLE.md 5, 6; lead feedback): dark
## cracks run out across the white from where it will open, spreading over
## the last second of the windup, so the floor itself says where to stop
## standing. A disc cracks outward from its centre; a ring cracks round its
## band. The hole's black water replaces it when the strike lands.

var life := 1.0
var shape := "disc"
var radius := 2.0
var inner := 0.0
var _t := 0.0
var _mat: StandardMaterial3D

static func spawn(parent: Node, at: Vector3, p_shape: String, p_radius: float, p_inner: float,
		secs: float) -> IceCrack:
	var c := IceCrack.new()
	c.shape = p_shape
	c.radius = p_radius
	c.inner = p_inner
	c.life = maxf(secs, 0.1)
	c.mesh = c._crack_mesh()
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(c)
	c.global_position = at + Vector3.UP * 0.12
	return c

## Jagged lines: from the centre out to the rim (disc), or zig-zagging round
## the band (ring), each a thin flat quad. Seeded from the size so a test can
## count them and a shot looks the same twice.
func _crack_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(radius * 1000.0 + inner * 77.0)
	if shape == "ring":
		var mid := (radius + inner) * 0.5
		var band := maxf(radius - inner, 0.4)
		var n := maxi(int(TAU * mid / 0.7), 12)
		var prev := Vector3(mid, 0, 0)
		for i in range(1, n + 1):
			var a := TAU * float(i) / n
			var r := mid + rng.randf_range(-0.4, 0.4) * band
			var p := Vector3(cos(a), 0, sin(a)) * r
			_seg(st, prev, p, 0.07)
			if i % 3 == 0:   # spurs across the band
				var sp := Vector3(cos(a), 0, sin(a)) * (inner if rng.randf() < 0.5 else radius)
				_seg(st, p, p.lerp(sp, 0.8), 0.04)
			prev = p
	else:
		var arms := 7
		for k in arms:
			var a := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / arms
			var p := Vector3.ZERO
			var steps := 4
			for j in steps:
				var rr := radius * float(j + 1) / steps
				var aj := a + rng.randf_range(-0.35, 0.35)
				var q := Vector3(cos(aj), 0, sin(aj)) * rr
				_seg(st, p, q, 0.08 - 0.012 * j)
				if j == 1:   # a branch
					var ab := aj + rng.randf_range(0.5, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
					_seg(st, q, q + Vector3(cos(ab), 0, sin(ab)) * radius * 0.35, 0.04)
				p = q
		# the rim it will break along
		var rim := 24
		for i in rim:
			if i % 2 == 1:
				continue
			var a0 := TAU * float(i) / rim
			var a1 := TAU * float(i + 1) / rim
			_seg(st, Vector3(cos(a0), 0, sin(a0)) * radius, Vector3(cos(a1), 0, sin(a1)) * radius, 0.05)
	return st.commit()

static func _seg(st: SurfaceTool, a: Vector3, b: Vector3, w: float) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var side := d.normalized().cross(Vector3.UP) * w * 0.5
	for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
		st.add_vertex(v)

func _ready() -> void:
	add_to_group("ice_cracks")
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(0.04, 0.08, 0.14, 0.0)
	material_override = _mat
	if shape != "ring":
		scale = Vector3(0.15, 1.0, 0.15)
	AudioDirector.play("world/ice_break", global_position, -8.0)

func _process(dt: float) -> void:
	_t += dt
	var k := clampf(_t / life, 0.0, 1.0)
	# the cracks run out to the rim, darkening as they go
	if shape != "ring":
		var s := lerpf(0.15, 1.0, 1.0 - pow(1.0 - k, 2.0))
		scale = Vector3(s, 1.0, s)
	_mat.albedo_color.a = lerpf(0.35, 0.95, k)
	if _t >= life + 0.25:
		queue_free()

## Follow a moving aim until it commits (the strike lands where it stops).
func follow(at: Vector3) -> void:
	global_position = at + Vector3.UP * 0.12
