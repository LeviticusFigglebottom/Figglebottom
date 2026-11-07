class_name HazardVolume
extends Area3D
## Diegetic stakes at the edges of the land (ADR 0003 §2):
##   "drown" — deep water: the Bearer is taken at once
##   "kill"  — a fall into a ravine: the same
##   "fall"  — below cliffs: a hard landing hurts by impact speed; walking
##             in on your feet does nothing
##   "bog"   — black peat water: it drags at the legs, and a Bearer who
##             stays in it past hazard/bog_seconds goes under
## Numbers live in data/game.json "hazard".

var kind := "fall"
var size := Vector3.ONE
var _falling: Dictionary = {}    # body id -> worst downward speed this fall
var _sunk: Dictionary = {}       # body id -> seconds in the bog

func _ready() -> void:
	add_to_group("hazards")
	collision_layer = 0
	collision_mask = 1 << (RH.L_PLAYER - 1)
	monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	add_child(cs)
	body_entered.connect(_on_enter)

func _on_enter(b: Node3D) -> void:
	if not (b is Player) or (b as Player).dead:
		return
	if kind == "drown" or kind == "kill":
		_take(b as Player, 99999.0)

func _physics_process(_dt: float) -> void:
	if kind == "bog":
		_bog(_dt)
		return
	if kind != "fall":
		return
	for b in get_overlapping_bodies():
		if not (b is Player):
			continue
		var p := b as Player
		var key := p.get_instance_id()
		if not p.is_on_floor():
			_falling[key] = minf(float(_falling.get(key, 0.0)), p.velocity.y)
		elif _falling.has(key):
			var v := -float(_falling[key])
			_falling.erase(key)
			var safe := float(DB.tuning("hazard/fall_safe_speed", 13.0))
			var lethal := float(DB.tuning("hazard/fall_lethal_speed", 24.0))
			if v > safe and not p.dead:
				var t := clampf((v - safe) / maxf(lethal - safe, 0.1), 0.0, 1.0)
				_take(p, 99999.0 if t >= 1.0 else t * p.max_hp)

func _bog(dt: float) -> void:
	var inside := {}
	for b in get_overlapping_bodies():
		if not (b is Player) or (b as Player).dead:
			continue
		var p := b as Player
		var key := p.get_instance_id()
		inside[key] = true
		var drag := float(DB.tuning("hazard/bog_drag", 0.55))
		p.velocity.x *= drag
		p.velocity.z *= drag
		_sunk[key] = float(_sunk.get(key, 0.0)) + dt
		if _sunk[key] > float(DB.tuning("hazard/bog_seconds", 3.0)):
			_sunk.erase(key)
			_take(p, 99999.0)
	for k in _sunk.keys():
		if not inside.has(k):
			_sunk.erase(k)

func _take(p: Player, dmg: float) -> void:
	# the land does not care for i-frames
	var was := p.invulnerable
	p.invulnerable = false
	var pk := DamagePacket.new(dmg, 0, null)
	pk.kind = "hazard"   # no absorption: a coat does not soften a fall
	p.take_hit(pk)
	p.invulnerable = was
