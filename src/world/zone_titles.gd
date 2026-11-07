class_name ZoneTitles
extends Node
## Named places inside one continuous area (ADR 0005): walking from the
## Strand up to the yard shows SALTFELL the first time, as a portal would.
## zones: [{"name", "min": [x, z], "max": [x, z]}], innermost listed last.

var zones: Array = []
var _current := ""
var _seen: Dictionary = {}
var _t := 0.0

func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	var p := Game.player as Node3D
	if p == null or not is_instance_valid(p):
		return
	var here := ""
	for z in zones:
		var mn: Array = z["min"]
		var mx: Array = z["max"]
		var pos: Vector3 = p.global_position
		if pos.x >= float(mn[0]) and pos.x <= float(mx[0]) and pos.z >= float(mn[1]) and pos.z <= float(mx[1]):
			here = String(z["name"])
	if here != _current:
		_current = here
		if here != "" and not _seen.has(here):
			_seen[here] = true
			if _seen.size() > 1:      # the arrival card already named the first
				Game.area_title.emit(here)
