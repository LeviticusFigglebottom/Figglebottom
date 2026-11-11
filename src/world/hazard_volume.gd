class_name HazardVolume
extends Area3D
## Diegetic stakes at the edges of the land (ADR 0003 §2):
##   "drown" — deep water: the Bearer is taken at once
##   "kill"  — a fall into a ravine: the same
##   "fall"  — below cliffs: a hard landing hurts by impact speed; walking
##             in on your feet does nothing
##   "bog"   — black peat water: it drags at the legs, and a Bearer who
##             stays in it past hazard/bog_seconds goes under
##   "thin"  — thin ice over a crevasse or a cut hole: stand on it and it
##             gives (hazard/thin_ice_seconds, or the spec's "seconds")
## Numbers live in data/game.json "hazard".

var kind := "fall"
var size := Vector3.ONE
var _falling: Dictionary = {}    # body id -> worst downward speed this fall
var _sunk: Dictionary = {}       # body id -> seconds in the bog / on thin ice
var seconds := -1.0              # override for "thin"
## A round pool in a square box ("bog"): beyond this many metres from the
## box's middle the ground is dry. The Lowe's bog box took the Bearer on the
## road past its corner, where the heather dips below the water's height.
var radius := -1.0

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
	if (kind == "drown" or kind == "kill") and _inside(b):
		_take(b as Player, 99999.0)

## A volume built on the frame the Bearer is carried away (waking at a hearth
## in another region, crossing a seam) can report him from where he lay
## before the move: fallen in Saltfell's ravine, he woke at the Barrow Road
## and the Lowe's ravine took him again at once. Only a body really in the
## box is taken.
func _inside(b: Node3D) -> bool:
	var p := to_local(b.global_position)
	return absf(p.x) <= size.x * 0.5 + 0.8 and absf(p.z) <= size.z * 0.5 + 0.8 \
			and p.y >= -size.y * 0.5 - 2.5 and p.y <= size.y * 0.5 + 0.8

func _physics_process(_dt: float) -> void:
	if kind == "bog" or kind == "thin":
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
		if radius > 0.0:
			var off := to_local(p.global_position)
			if Vector2(off.x, off.z).length() > radius:
				continue
		var key := p.get_instance_id()
		inside[key] = true
		var limit := float(DB.tuning("hazard/bog_seconds", 3.0))
		if kind == "bog":
			var drag := float(DB.tuning("hazard/bog_drag", 0.55))
			p.velocity.x *= drag
			p.velocity.z *= drag
		else:
			limit = seconds if seconds >= 0.0 else float(DB.tuning("hazard/thin_ice_seconds", 0.7))
			# "Off it in a second or go under" (KETTLE.md 5, 6): the second
			# is his to move in. The break that opens a hole can stagger him
			# for most of it (the Ice-Cutter's Drill down broke base poise
			# outright: 0.7 s held of a 1.0 s sink was certain death), so
			# the ice does not give while he is still reeling on it.
			if p.state == Player.S.STAGGER:
				continue
		_sunk[key] = float(_sunk.get(key, 0.0)) + dt
		if _sunk[key] > limit:
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
