class_name HerdRun
extends Node3D
## The flock coming down a strip in a rush (REACH.md 6, Call them in): a
## clump of frozen sheep run from one end of the strip to the other in `run`
## seconds, and whoever the front passes over is struck once. What glowed on
## the floor is the strip; the front is the only thing that hurts.

signal passed

var dir := Vector3.FORWARD
var length := 20.0
var width := 3.2
var run := 1.3
var depth := 2.4               # how deep the clump is, front to back
var on_hit: Callable           # (player) -> void
var _t := 0.0
var _struck := false
var _sheep: Array = []

static func start(parent: Node, from: Vector3, along: Vector3, length_: float, width_: float, run_: float,
		count: int, kit: String, remap: Dictionary, hit: Callable) -> HerdRun:
	var h := HerdRun.new()
	h.dir = Vector3(along.x, 0, along.z).normalized()
	h.length = length_
	h.width = width_
	h.run = maxf(run_, 0.1)
	h.on_hit = hit
	parent.add_child(h)
	h.global_position = from
	h.add_to_group("herd_runs")
	var side := h.dir.cross(Vector3.UP)
	for i in count:
		var s: Node3D = KitLib.instance(kit, 2, remap) if KitLib.has_piece(kit) else Node3D.new()
		h.add_child(s)
		# three abreast, rank behind rank, never quite in line
		var col := float(i % 3) - 1.0
		var rank := float(i / 3)
		s.position = side * col * (width_ * 0.3) + h.dir * (-rank * 1.1 + sin(i * 2.3) * 0.3)
		s.rotation.y = atan2(-h.dir.x, -h.dir.z)
		s.set_meta("phase", float(i) * 1.7)
		h._sheep.append(s)
	return h

## Metres the front has come down the strip.
func front() -> float:
	return clampf(_t / run, 0.0, 1.0) * (length + depth)

func _physics_process(dt: float) -> void:
	_t += dt
	var f := front()
	var side := dir.cross(Vector3.UP)
	for s in _sheep:
		var n := s as Node3D
		var base: Vector3 = n.position - dir * n.position.dot(dir)   # its place across the strip
		var back: float = float(_sheep.find(s) / 3) * 1.1
		n.position = base + dir * (f - back)
		n.position.y = absf(sin(_t * 14.0 + float(n.get_meta("phase", 0.0)))) * 0.22   # the bound of a running ewe
	var p := Game.player as Node3D
	if not _struck and p != null and is_instance_valid(p) and not p.get("dead"):
		var to := p.global_position - global_position
		to.y = 0.0
		var along := to.dot(dir)
		if absf(to.dot(side)) <= width * 0.5 and along <= f and along >= f - depth and along <= length:
			_struck = true
			if on_hit.is_valid():
				on_hit.call(p)
	if _t >= run:
		passed.emit()
		set_physics_process(false)
		# over the far wall and gone
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.25)
		tw.tween_callback(queue_free)
