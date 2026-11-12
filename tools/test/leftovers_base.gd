class_name LeftoversBase
extends TestBase
## Shared by the leftovers suites (leftovers_test.gd, leftovers_longhouse_test.gd):
## the count (every node in the scene that was not there before and is not on
## its way out) and the forced fight (each move of a foe skipped to its
## strike, so that whatever the move raises, throws, pours or summons is
## standing; a Holdfast taken through its phases and released).

const SPEED := 3.0          # game seconds per real second (the suites are long)

var player: Player
var hud: HUD
## Where the Bearer waits between moves, from the foe's home: off whatever
## the move opened under him.
var park_off := Vector3(0, 0.1, 17.0)

func _t(n: int):
	for i in n:
		Engine.time_scale = SPEED   # (a hit-stop puts it back to 1)
		await get_tree().physics_frame

func _secs(s: float):
	await _t(int(ceil(s * 60.0)))

# ------------------------------------------------------------------ the count
func _skip(n: Node) -> bool:
	return n == player or n == hud

func _snapshot() -> Dictionary:
	var out := {}
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out[n.get_instance_id()] = true
		for c in n.get_children(true):
			if not _skip(c):
				stack.append(c)
	return out

## The topmost nodes that were not there at `before` and are not on their way
## out. A burst of particles that only plays once is on its way out.
func _new_roots(before: Dictionary) -> Array:
	var out: Array = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(true):
			if _skip(c) or c.is_queued_for_deletion():
				continue
			if before.has(c.get_instance_id()):
				stack.append(c)
			elif not (c is CPUParticles3D and (c as CPUParticles3D).one_shot):
				out.append(c)
	return out

func _kind(n: Node) -> String:
	var s: Script = n.get_script()
	var g := String(s.get_global_name()) if s != null else ""
	return "%s '%s'" % [g if g != "" else n.get_class(), n.name]

func _pen_of(n: Node) -> Spawner:
	var up := n
	while up != null and not (up is Spawner):
		up = up.get_parent()
	return up as Spawner

func _list(nodes: Array) -> String:
	var names: Array = []
	for n in nodes:
		names.append(_kind(n))
	return ", ".join(names) if not names.is_empty() else "nothing"

# ------------------------------------------------------------------ the fight
func _stand_before(e: Enemy, dist := 2.2) -> void:
	var fwd := -e.vis.global_transform.basis.z
	fwd.y = 0.0
	player.global_position = e.global_position + fwd.normalized() * dist + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	player.hp = player.max_hp

## One move, skipped to its strike (or left `part` of the way through its
## windup: the tell is on the floor and nothing has landed).
func _use(e: Enemy, a: Dictionary, part := 1.0) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	if e.get("hidden") == true:
		e.call("_emerge", e.global_position, false)
	# he struggles out of the last move's hold (unbroken, a hook hauls him
	# onto whatever hole is open); the hold of the last move of all stays on
	for g in e.get_children():
		if g is GrabHold and not (g as GrabHold).is_over():
			(g as GrabHold).presses = 999
			await _t(2)
	_stand_before(e, clampf(float(a.get("range", 2.2)) * 0.6, 1.6, 4.0))
	e.target = player
	e._set_state(Enemy.ES.COMBAT)
	e._begin_attack(a)
	await _t(2)
	if e.state != Enemy.ES.ATTACK:
		return
	var w := float(e._atk.get("windup", 0.5)) / e._speed_mult()
	e.state_t = w * part - (0.02 if part >= 1.0 else 0.0)
	await _t(6 if part >= 1.0 else 3)
	_park(e)
	await _t(2)   # (seen to be off it: thin ice counts up while he stands on it)

func _park(e: Enemy) -> void:
	player.global_position = e.home + park_off
	player.velocity = Vector3.ZERO

func _in_phase(a: Dictionary, ph: int) -> bool:
	if a.has("phases"):
		return ph in a["phases"] or float(ph) in a["phases"]
	return ph == 1

## The telegraphed move with the longest windup: the one to be caught in.
func _long_tell(e: Enemy, ph: int) -> Dictionary:
	var best := {}
	for a in e.cfg.get("attacks", []):
		if not a.has("telegraph") or (ph > 0 and not _in_phase(a, ph)):
			continue
		if best.is_empty() or float(a.get("windup", 0.0)) > float(best.get("windup", 0.0)):
			best = a
	return best

func _fight(e: Enemy) -> void:
	e.set_physics_process(true)
	for a in e.cfg.get("attacks", []):
		await _use(e, a)
	var tell := _long_tell(e, 0)
	if not tell.is_empty():
		await _use(e, tell, 0.8)

## A Holdfast's fight up to `upto`: each phase's moves, and each phase change
## struck out of a half-wound telegraphed move (her Sea-weight, his Ground
## cut), the turn itself hurried through with every one of its events.
func _fight_boss(b: Enemy, upto: int) -> void:
	b.set_physics_process(true)
	b.set("stood", true)
	b.target = player
	b._set_state(Enemy.ES.COMBAT)
	for ph in range(1, upto + 1):
		if ph > 1:
			var at: Array = b.cfg.get("phase_at", [0.6, 0.25])
			var tell := _long_tell(b, ph - 1)
			if not tell.is_empty():
				await _use(b, tell, 0.8)
			b.hp = b.max_hp * float(at[ph - 2]) + 1.0
			b.take_hit(DamagePacket.new(3.0, 0, player))
			await _t(1)
			var guard := 0
			while b.state == Enemy.ES.TRANSITION and guard < 20:
				b.state_t = 99.0
				guard += 1
				await _t(1)
			if b.phase != ph:
				check(false, "%s reached phase %d (at %d)" % [b.id, ph, b.phase])
		for a in b.cfg.get("attacks", []):
			if _in_phase(a, ph):
				await _use(b, a)
	var last := _long_tell(b, upto)
	if not last.is_empty():
		await _use(b, last, 0.8)

func _release(b: Enemy) -> void:
	if b is Leadvoice:
		var lv := b as Leadvoice
		lv.standing = true
		for i in int(lv.cfg.get("verses", 3)):
			if lv.released:
				break
			lv._set_state(Enemy.ES.COMBAT)
			_stand_before(lv, 2.5)
			lv.begin_verse(player)
			await _t(2)
			lv.set("_verse_t", 99.0)
			await _t(3)
			lv.set("_bow_t", 99.0)
			await _t(3)
		return
	var guard := 0
	while not b.dead and guard < 200:
		guard += 1
		if b.state == Enemy.ES.TRANSITION:
			b.state_t = 99.0
		else:
			b.take_hit(DamagePacket.new(b.max_hp * 0.3, 0, player))
		await _t(1)
