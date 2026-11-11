class_name BowRig
extends Node3D
## The string and the nocked arrow of a held bow. The stave is a model (grip
## at the origin, tips toward -Z); the string cannot be, because it has to
## follow the drawing hand: two straight runs from the nocks to the nocking
## point, which rests midway between them and is pulled to the string hand
## while an arrow is nocked. The arrow lies from that point across the grip.
## On the loose the string snaps back past its rest and rings down.
## Child of the bow model, so everything here is in the bow's own space.

var nock := Vector3(0, 0.702, -0.159)     # upper nock; the lower mirrors it in Y
var rest_at := Vector3(0.012, 0.035, 0.0)  # where the shaft crosses the grip
## Returns the string hand's world position while drawing (the fingers).
var hand := Callable()

var _string: MeshInstance3D
var _arrow: Node3D
var _nocked := false
var _pull := 0.0          # 0 string at rest .. 1 on the hand
var _ring := 0.0          # after a loose: the string's overshoot, decaying
var _ring_t := 0.0
var _mat: StandardMaterial3D

func setup(cfg: Dictionary) -> void:
	var n: Array = cfg.get("nock", [nock.x, nock.y, nock.z])
	nock = Vector3(n[0], n[1], n[2])
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.72, 0.66, 0.52)   # twisted flax
	_mat.roughness = 0.9
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_string = MeshInstance3D.new()
	_string.mesh = ImmediateMesh.new()
	_string.material_override = _mat
	_string.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_string)
	_arrow = HumanoidLib.weapon_instance("arrow")
	if _arrow == null:
		_arrow = Node3D.new()
	_arrow.visible = false
	add_child(_arrow)
	_draw(Vector3(0, 0, nock.z))

## An arrow goes on the string (the draw begins) or comes off unshot.
func set_nocked(on: bool) -> void:
	_nocked = on
	_arrow.visible = on

func is_nocked() -> bool:
	return _nocked

## The fingers open: the arrow is gone and the string leaps forward.
func loose() -> void:
	_ring = _pull
	_ring_t = 0.0
	_nocked = false
	_arrow.visible = false
	_pull = 0.0

func _process(dt: float) -> void:
	var rest := Vector3(0, 0, nock.z)
	var at := rest
	if _nocked and hand.is_valid():
		# the hand comes to the string over the first beat of the draw, then holds it
		_pull = move_toward(_pull, 1.0, dt * 5.0)
		var h: Vector3 = to_local(hand.call())
		# the string only ever comes back from its rest, never forward of it
		h.z = minf(h.z, rest.z)
		h.x = clampf(h.x, -0.05, 0.05)
		h.y = clampf(h.y, -0.12, 0.12)
		at = rest.lerp(h, smoothstep(0.0, 1.0, _pull))
	elif _ring > 0.001:
		_ring_t += dt
		_ring *= exp(-14.0 * dt)
		at = rest + Vector3(0, 0, 0.09 * _ring * cos(_ring_t * 70.0))
	_draw(at)
	if _nocked:
		var dir := (rest_at - at).normalized()
		var side := dir.cross(Vector3.UP).normalized()
		_arrow.transform = Transform3D(Basis(side, dir, side.cross(dir)), at)

func _draw(at: Vector3) -> void:
	var im := _string.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for end in [nock, Vector3(nock.x, -nock.y, nock.z)]:
		_run(im, end, at)
	im.surface_end()

## A thin three-sided strand between two points.
func _run(im: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.RIGHT).normalized()
	var v := d.cross(u)
	var r := 0.0022
	var ring: Array = []
	for k in 3:
		var ang := TAU * k / 3.0
		ring.append((u * cos(ang) + v * sin(ang)) * r)
	for k in 3:
		var o0: Vector3 = ring[k]
		var o1: Vector3 = ring[(k + 1) % 3]
		for p in [a + o0, a + o1, b + o1, a + o0, b + o1, b + o0]:
			im.surface_set_normal((o0 + o1).normalized())
			im.surface_add_vertex(p)

## A frozen pose (the pose sheet): the string is already on the hand.
func snap() -> void:
	_pull = 1.0

## Where the nocking point is now, in world space (tests, the pose sheet).
func string_at() -> Vector3:
	return _arrow.global_position if _nocked else to_global(Vector3(0, 0, nock.z))
