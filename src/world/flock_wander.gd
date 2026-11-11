class_name FlockWander
extends Node3D
## The Reach's living flock at pasture (THAW). The ewes are unrigged props,
## so this walks them the way sheep actually move when nothing is driving
## them: stand and crop for a long while, then a few slow steps to the next
## patch, never far from where they were put. The head and ears are moved by
## the hall shader (graze_* uniforms); this only shifts and turns the body.
## No collision, no navigation: each stays inside a short tether on ground
## as level as where she started.

const TETHER := 2.6          # metres from where the generator set her
const PACE := 0.24           # metres a second: an amble
const TURN := 1.1            # radians a second
const ACTIVE_RANGE := 110.0  # nobody sees a ewe shuffle beyond this

var area: Area = null
var ewes: Array = []         # the sheep pieces (Node3D)
var _st: Array = []          # per ewe: {home, target, wait}

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for e in ewes:
		var n := e as Node3D
		_st.append({"home": n.position, "target": n.position, "wait": rng.randf_range(2.0, 30.0)})

func _process(dt: float) -> void:
	if not is_visible_in_tree() or area == null or area.terrain == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	for i in ewes.size():
		var n := ewes[i] as Node3D
		if not is_instance_valid(n):
			continue
		var s: Dictionary = _st[i]
		if s["wait"] > 0.0:
			s["wait"] -= dt
			if s["wait"] <= 0.0:
				_pick(n, s)
			continue
		if n.global_position.distance_squared_to(eye) > ACTIVE_RANGE * ACTIVE_RANGE:
			s["wait"] = 5.0
			continue
		var to: Vector3 = s["target"] - n.position
		to.y = 0.0
		var dist := to.length()
		if dist < 0.08:
			# there: head down for a good while (most of a ewe's day)
			s["wait"] = 8.0 + fmod(float(i) * 7.3 + n.position.x, 26.0)
			continue
		# her face is local -Z: turn it to the way she is going, then go
		var want := atan2(-to.x, -to.z)
		var diff := wrapf(want - n.rotation.y, -PI, PI)
		n.rotation.y += clampf(diff, -TURN * dt, TURN * dt)
		if absf(diff) < 0.5:
			var step := to / dist * minf(PACE * dt, dist)
			var p := n.position + step
			p.y = area.terrain.height_at(p.x, p.z)
			n.position = p

## The next patch: a metre or two off, inside the tether, on ground she
## could stand on (no steeper or higher than a step from home).
func _pick(n: Node3D, s: Dictionary) -> void:
	var home: Vector3 = s["home"]
	for attempt in 4:
		var a := randf() * TAU
		var q := n.position + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, 2.2)
		if Vector2(q.x - home.x, q.z - home.z).length() > TETHER:
			continue
		if not area.terrain.contains(q.x, q.z) or area.terrain.normal_at(q.x, q.z).y < 0.9:
			continue
		if absf(area.terrain.height_at(q.x, q.z) - home.y) > 0.7:
			continue
		s["target"] = q
		return
	s["wait"] = 6.0
