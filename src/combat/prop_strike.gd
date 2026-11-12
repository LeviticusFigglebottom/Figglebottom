class_name PropStrike
extends RefCounted
## A blade against the world. While a swing is live its edge is traced each
## physics tick against the world layers (rays only: the weapon carries no
## body). The first prop, wall or stretch of ground it meets takes ONE burst
## of its surface (PropHitFX); the blow does no damage and stops no clock,
## so it still reads as a miss on a wall. Tuning: game.json prop_hit.

## (collider, point, normal, surface, burst root or null)
signal struck(collider: Object, pos: Vector3, normal: Vector3, surface: String, burst: Node3D)

const META_GROUP := &"strike_group"   # colliders of one piece answer as one
const WORLD_MASK := RH.M_WORLD_ALL | (1 << (RH.L_WORLD_LOW - 1))

var wielder: CollisionObject3D = null

var _query := PhysicsRayQueryParameters3D.new()   # one, reused: no garbage per tick
var _base_exclude: Array[RID] = []
var _struck := {}            # strike group -> true, this swing
var _cool := {}              # strike group -> physics frame it may burst again
var _prev := PackedVector3Array()
var _has_prev := false
var _live := false
var _heavy := false
var _bursts := 0
# the tuning, read once per swing
var _max := 2
var _cool_frames := 18
var _pad := 0.12
var _samples: Array = [0.5, 1.0]

func _init(p_wielder: CollisionObject3D = null) -> void:
	wielder = p_wielder
	_query.collision_mask = WORLD_MASK
	_query.collide_with_areas = false
	_query.hit_from_inside = false

func live() -> bool:
	return _live

## A swing opens: nothing struck yet, no path behind the blade.
func begin(heavy := false) -> void:
	_live = bool(DB.tuning("prop_hit/enabled", true))
	_heavy = heavy
	_bursts = 0
	_has_prev = false
	_struck.clear()
	_max = int(DB.tuning("prop_hit/max_per_swing", 2))
	_cool_frames = int(round(float(DB.tuning("prop_hit/cooldown", 0.3)) * Engine.physics_ticks_per_second))
	_pad = float(DB.tuning("prop_hit/tip_pad", 0.12))
	_samples = DB.tuning("prop_hit/samples", [0.5, 1.0])
	_prev.resize(_samples.size())
	_base_exclude.clear()
	if wielder != null and is_instance_valid(wielder):
		_base_exclude.append(wielder.get_rid())
	_query.exclude = _base_exclude
	var now := Engine.get_physics_frames()
	for k in _cool.keys():
		if int(_cool[k]) <= now:
			_cool.erase(k)

func end() -> void:
	_live = false
	_has_prev = false

## One physics tick of a live swing: the edge as it lies (grip to tip, a
## little past it), then the path each sample point swept since last tick.
func sweep(space: PhysicsDirectSpaceState3D, grip: Vector3, tip: Vector3) -> void:
	if not _live or space == null:
		return
	var edge := tip - grip
	var travel := (tip - _prev[_samples.size() - 1]) if _has_prev else edge
	_trace(space, grip, tip + edge.normalized() * _pad, travel)
	for i in _samples.size():
		var pt := grip.lerp(tip, float(_samples[i]))
		if _has_prev:
			_trace(space, _prev[i], pt, travel)
		_prev[i] = pt
	_has_prev = true

func _trace(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, travel: Vector3) -> void:
	if _bursts >= _max or from.distance_squared_to(to) < 0.000001:
		return
	_query.from = from
	_query.to = to
	var hit := space.intersect_ray(_query)
	if hit.is_empty():
		return
	var col: Object = hit["collider"]
	# seen once, seen through: later traces this swing reach what lies behind
	var ex := _query.exclude
	ex.append(hit["rid"])
	_query.exclude = ex
	var key = col.get_meta(META_GROUP, col.get_instance_id())
	if _struck.has(key):
		return
	_struck[key] = true
	if int(_cool.get(key, 0)) > Engine.get_physics_frames():
		return
	var pos: Vector3 = hit["position"]
	var surface := Surfaces.of(col, pos)
	if surface == Surfaces.NONE:
		return
	_cool[key] = Engine.get_physics_frames() + _cool_frames
	_bursts += 1
	var normal: Vector3 = hit["normal"]
	var burst := PropHitFX.burst(wielder, pos, normal, surface, travel.normalized(), _heavy)
	struck.emit(col, pos, normal, surface, burst)
