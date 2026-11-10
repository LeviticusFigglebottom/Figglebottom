class_name ThornWall
extends Node3D
## A wall of frozen thorn raised at runtime (THORNWOLD.md 6: the Hedgelayer
## lays hedge in the fight): a straight run `length` long, or a ring of
## `radius` with one gap, `height` high. It rises out of the ground, blocks
## like the wood's own hedges (box colliders segment by segment), and sinks
## back stem by stem when it is done (`life`, or sink()). Built from the
## wood's own thorn meshes (Forest), so it looks like the rings round it.

signal sunk(wall)

var shape := "line"          # "line" | "ring"
var length := 9.0
var radius := 8.0
var gap_deg := 0.0           # ring: the bearing of its gap (degrees, from +X toward +Z)
var gap_m := 3.4
var height := 3.0
var width := 1.3
var life := 14.0
var _t := 0.0
var _sinking := false
var _vis: Node3D
var bodies: Array = []
## The run's points on the ground (local x, z): the Hedgelayer steps out of them.
var points: Array = []

static func raise(parent: Node, at: Vector3, yaw: float, p_length: float, p_height: float, p_life: float) -> ThornWall:
	var w := ThornWall.new()
	w.shape = "line"
	w.length = p_length
	w.height = p_height
	w.life = p_life
	parent.add_child(w)
	w.global_position = at
	w.rotation.y = yaw
	return w

static func raise_ring(parent: Node, centre: Vector3, p_radius: float, p_gap_deg: float, p_height: float,
		p_life: float) -> ThornWall:
	var w := ThornWall.new()
	w.shape = "ring"
	w.radius = p_radius
	w.gap_deg = p_gap_deg
	w.height = p_height
	w.life = p_life
	parent.add_child(w)
	w.global_position = centre
	return w

func _ready() -> void:
	add_to_group("thorn_walls")
	_vis = Node3D.new()
	add_child(_vis)
	var runs: Array = []
	if shape == "ring":
		var half := gap_m / 2.0 / radius
		var a0 := deg_to_rad(gap_deg) + half
		var a1 := deg_to_rad(gap_deg) + TAU - half
		var n := maxi(8, int((a1 - a0) * radius / 1.5))
		var run: Array = []
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			run.append(Vector2(cos(a), sin(a)) * radius)
		runs.append(run)
	else:
		var run2: Array = []
		var n2 := maxi(2, int(length / 1.5))
		for i in n2 + 1:
			run2.append(Vector2(lerpf(-length * 0.5, length * 0.5, float(i) / n2), 0.0))
		runs.append(run2)
	for run in runs:
		for p in run:
			points.append(p)
		_build_run(run)
	# up out of the ground
	_vis.scale = Vector3(1, 0.05, 1)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_burst(0.9)
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -4.0, 0.5)

## Stems leaning and crossing, a dense core, a box collider per segment.
func _build_run(run: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(global_position.x * 13.0 + global_position.z * 7.0)) + run.size()
	var stems: Array = []
	var cores: Array = []
	for k in run.size() - 1:
		var a: Vector2 = run[k]
		var b: Vector2 = run[k + 1]
		var d := b - a
		var L := d.length()
		if L < 0.05:
			continue
		var dir := d / L
		var yaw := atan2(-dir.y, dir.x)
		var t := 0.0
		while t < L:
			var p := a + dir * t
			for i in 8:
				var off := (rng.randf() - 0.5) * width
				var q := p + Vector2(-dir.y, dir.x) * off
				var lean := 0.35 * (1.0 if i % 2 == 0 else -1.0) + rng.randf_range(-0.3, 0.3)
				var ln := height * rng.randf_range(0.9, 1.4)
				var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, lean) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
				stems.append(Transform3D(bs.scaled_local(Vector3(1, ln, 1)), Vector3(q.x, -0.1, q.y) + bs * Vector3(0, ln * 0.5, 0)))
			t += 0.45
		var mid := (a + b) * 0.5
		var cb := Basis(Vector3.UP, yaw)
		cores.append(Transform3D(cb.scaled_local(Vector3(L * 1.02, height * 0.6, width * 0.6)), Vector3(mid.x, height * 0.3 - 0.05, mid.y)))
		var body := StaticBody3D.new()
		body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(L + 0.2, height + 0.4, maxf(width, 0.8))
		cs.shape = bx
		body.add_child(cs)
		body.transform = Transform3D(cb, Vector3(mid.x, height * 0.5, mid.y))
		add_child(body)
		bodies.append(body)
	_multi("stem|thorn", stems)
	_multi("core|thorn", cores)

func _multi(key: String, xfs: Array) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Forest._mesh(key, 2)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	_vis.add_child(mmi)

func _burst(amount_k: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(clampf(points.size() * 10.0 * amount_k, 24, 220))
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	var pts := PackedVector3Array()
	for q in points:
		pts.append(Vector3((q as Vector2).x, 0.2, (q as Vector2).y))
	p.emission_points = pts
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.4
	p.gravity = Vector3(0, -8.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.color = Color(0.82, 0.9, 1.0, 0.9)
	p.mesh = AreaPortal.make_mote_quad(1.2)
	add_child(p)
	p.emitting = true

func _physics_process(dt: float) -> void:
	_t += dt
	if not _sinking and life > 0.0 and _t >= life:
		sink()

func is_standing() -> bool:
	return not _sinking

## Unlay: the colliders go at once; the stems sink back into the ground.
func sink(secs := 0.9) -> void:
	if _sinking:
		return
	_sinking = true
	for b in bodies:
		if is_instance_valid(b):
			(b as StaticBody3D).collision_layer = 0
	_burst(0.5)
	sunk.emit(self)
	var tw := create_tween()
	tw.tween_property(_vis, "scale", Vector3(1, 0.02, 1), secs).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

## Ground-plane distance from `p` to the wall (to its run of points).
func distance_to(p: Vector3) -> float:
	var best := 1e9
	for q in points:
		var w := global_transform * Vector3((q as Vector2).x, 0, (q as Vector2).y)
		best = minf(best, Vector2(w.x - p.x, w.z - p.z).length())
	return best

## The point of the wall nearest `p`, on the ground (world).
func nearest_point(p: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := 1e9
	for q in points:
		var w := global_transform * Vector3((q as Vector2).x, 0, (q as Vector2).y)
		var d := Vector2(w.x - p.x, w.z - p.z).length()
		if d < bd:
			bd = d
			best = w
	return best
