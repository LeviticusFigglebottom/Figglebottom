class_name TrapWarden
extends Node
## No ditch keeps the Bearer. tools/audit_edges.py finds ground he can drop
## or slide onto and cannot walk back out of; tools/fix_traps.py writes those
## cells per world state to data/terrain/traps/<area>.json. This watches the
## Bearer: while he stands on safe ground it remembers the spot, and when he
## has stood in a trap for hazard/strand_seconds it sets him back there, at a
## cost of hazard/strand_damage of his health (never the last of it).
## Falling through a trap, rolling across one or fighting on its lip does
## nothing: only standing stranded does.

var area: Area
var _cells := {}            # state name -> { Vector2i(x, z): true }
var _safe := Vector3.INF
var _safe_age := 0.0
var _stuck := 0.0

static func mask_path(area_id: String) -> String:
	return "res://data/terrain/traps/%s.json" % area_id

## Attach a warden to `a` if the area has a trap mask.
static func build(a: Area) -> TrapWarden:
	var p := mask_path(a.area_id)
	if not FileAccess.file_exists(p):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary):
		return null
	var w := TrapWarden.new()
	w.name = "TrapWarden"
	w.area = a
	for st in d:
		var cells := {}
		for run in d[st]:
			for x in range(int(run[1]), int(run[2]) + 1):
				cells[Vector2i(x, int(run[0]))] = true
		w._cells[String(st)] = cells
	a.add_child(w)
	return w

func is_trap(pos: Vector3, state_name: String) -> bool:
	var cells: Dictionary = _cells.get(state_name, {})
	return cells.has(Vector2i(int(round(pos.x)), int(round(pos.z))))

## One tick of the watch. Returns where to set the Bearer back to, or
## Vector3.INF when he stays where he is. (Pure, so a test can drive it.)
func step(pos: Vector3, on_floor: bool, state_name: String, dt: float) -> Vector3:
	if not on_floor:
		return Vector3.INF
	if not is_trap(pos, state_name):
		_stuck = 0.0
		# a spot he has held for a moment, not the lip he is sliding off
		_safe_age += dt
		if _safe_age > 0.4:
			_safe = pos
			_safe_age = 0.0
		return Vector3.INF
	_safe_age = 0.0
	_stuck += dt
	if _stuck < float(DB.tuning("hazard/strand_seconds", 2.2)) or _safe == Vector3.INF:
		return Vector3.INF
	_stuck = 0.0
	return _safe

func _physics_process(dt: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.dead or area == null:
		return
	var st := "rime" if area.state() == RH.WState.RIME else "thaw"
	var back := step(p.global_position, p.is_on_floor(), st, dt)
	if back == Vector3.INF:
		return
	p.global_position = back + Vector3.UP * 0.3
	p.velocity = Vector3.ZERO
	# the climb back costs him, but the land does not finish him this way
	var dmg := minf(p.max_hp * float(DB.tuning("hazard/strand_damage", 0.12)), maxf(p.hp - 1.0, 0.0))
	if dmg > 0.0:
		var was: bool = p.invulnerable
		p.invulnerable = false
		var pk := DamagePacket.new(dmg, 0, null)
		pk.kind = "hazard"
		p.take_hit(pk)
		p.invulnerable = was
