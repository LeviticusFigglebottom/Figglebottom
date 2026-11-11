class_name Fellcaller
extends Enemy
## The Holdfast of Shepherd's Reach (REACH.md 6): Sigga Calder, whose calls
## carried three valleys. Her father walked up to the high fold in the night
## so she would not catch his cough; she has been calling the flock in to him
## ever since. Three phases by HP (data "phase_at"), each with its own
## repertoire (attack "phases"); every timing in enemies.json; every move
## that covers ground behind a floor telegraph.
##
##   intro      beside her father at the cairn, calling out over the fold
##              wall; wakes when the Bearer is within wake_dist or strikes her.
##   phase 1    Horn swing, Rising cry (a ring that staggers), Head down (a
##              charge the length of a strip; she overruns).
##   -> 2       a call that does not rise: two Frost-rams come over the wall.
##   phase 2    Call them in (the flock down a strip through where the Bearer
##              stands: HerdRun), Bring tups (one more ram, at most two).
##   -> 3       she goes back and stands over her father.
##   phase 3    she keeps within guard_r of him; the cry twice; the flock in
##              two strips, a cross; Count them (she crouches to him and
##              calls low, her back to the Bearer: open; resumes after 5
##              quiet seconds).
##   release    she kneels beside him; one soft call; every sheep on the
##              slope lies down (release_flock); the fold-tally by his hand
##              (release_drop at_point); card and hearth through
##              Game.on_boss_slain.

signal phase_changed(new_phase: int)
signal released_boss
signal herd_called(runs: Array)

var stood := false
var released := false
var herds: Array = []
var _trans := ""
var _trans_events: Array = []
var _hold_quiet := 0.0
var _herd_plan: Array = []     # [[from, dir]] committed with the floor tell
var _engaged_by_veil := false

func _ready() -> void:
	super._ready()
	vis.play("call", 0.0, 0.5)   # the long call, over and over

func _d(key: String, def = null):
	return cfg.get(key, def)

func phase_at() -> Array:
	return cfg.get("phase_at", [0.65, 0.3])

func repertoire() -> Array:
	var out := []
	for a in cfg.get("attacks", []):
		if not a.has("phases") or phase in a["phases"] or float(phase) in a["phases"]:
			out.append(String(a["id"]))
	return out

## Where Old Calder lies: data "father_off" [dx, dz] from where she stands.
func father_point() -> Vector3:
	var o: Array = _d("father_off", [0.0, 0.0])
	return home + Vector3(float(o[0]), 0.0, float(o[1]))

## The fold-tally is by his hand, on the side the Bearer comes from.
func drop_point() -> Vector3:
	var out := home - father_point()
	out.y = 0.0
	return father_point() + (out.normalized() if out.length() > 0.1 else Vector3.BACK) * 1.1 + Vector3.UP * 0.05

# ---------------------------------------------------------------- intro
func engage_from_veil(p: Node3D) -> void:
	target = p
	_engaged_by_veil = true

func _st_idle(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 8 * dt)
	velocity.z = move_toward(velocity.z, 0, 8 * dt)
	# the call is a one-shot clip: she makes it over and over (REACH.md 6),
	# not once and then stands idle until the Bearer comes
	if not stood and vis.current_clip() != "call":
		vis.play("call", 0.3, 0.5)
	var p := _player()
	if p == null or p.get("dead"):
		return
	if global_position.distance_to(p.global_position) <= float(_d("wake_dist", 8.0)):
		target = p
		_wake()

func _wake() -> void:
	if stood or state == ES.TRANSITION:
		return
	_begin_transition("wake")

func take_hit(packet: DamagePacket) -> void:
	if is_invulnerable():
		return
	if state == ES.HOLD:
		_hold_quiet = 0.0   # she keeps calling to him while the Bearer keeps at it
	var was_up := stood
	if packet.source != null and packet.source.is_in_group("player"):
		packet.amount *= Game.test_boss_dmg_mult   # 1.0 outside the full-game walk
	super.take_hit(packet)
	if not was_up and not dead and state != ES.TRANSITION:
		if packet.source != null and packet.source.is_in_group("player"):
			target = packet.source
		_wake()

func is_invulnerable() -> bool:
	return dead or released or state == ES.TRANSITION

func _check_phase() -> void:
	if dead:
		return
	var f := hp / max_hp
	var at := phase_at()
	if phase == 1 and f <= float(at[0]):
		phase = 2
		hp = maxf(hp, max_hp * float(at[1]) + 1.0)   # one blow cannot skip the flock
		_begin_transition("p2")
	elif phase == 2 and f <= float(at[1]):
		phase = 3
		_begin_transition("p3")

func _stagger(mult := 1.0) -> void:
	if state == ES.TRANSITION or state == ES.HOLD or not stood:
		poise = float(cfg.get("poise", 30))
		return
	super._stagger(mult)

# ---------------------------------------------------------------- transitions
func _begin_transition(kind: String) -> void:
	_end_all_swings()
	_then_atk = ""
	_trans = kind
	var tc: Dictionary = (cfg.get("transitions", {}) as Dictionary).get(kind, {})
	_trans_events = (tc.get("events", []) as Array).duplicate()
	_set_state(ES.TRANSITION)
	vis.play(String(tc.get("anim", "idle")), 0.25)
	if kind != "wake":
		phase_changed.emit(phase)
		Juice.shake(0.4, 0.4)
		AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 1.0, 0.8)

func _transition_time() -> float:
	return float(((cfg.get("transitions", {}) as Dictionary).get(_trans, {}) as Dictionary).get("time", 2.0))

## Where she stands in phase 3: over him, on the Bearer's side.
func stand_over_point() -> Vector3:
	var fp := father_point()
	var out := (target.global_position if target != null and is_instance_valid(target) else home) - fp
	out.y = 0.0
	return fp + (out.normalized() if out.length() > 0.1 else Vector3.BACK) * 1.8

func _st_transition(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 12 * dt)
	velocity.z = move_toward(velocity.z, 0, 12 * dt)
	while not _trans_events.is_empty() and state_t >= float(_trans_events[0][0]):
		var ev: Array = _trans_events.pop_front()
		_transition_event(String(ev[1]))
	var tt := _transition_time()
	if _trans == "p3" and not _trans_events.is_empty():
		# back to him, however far the fight has gone
		var to := stand_over_point() - global_position
		to.y = 0
		if to.length() > 0.4:
			var v := to.normalized() * maxf(float(cfg.get("speed", 2.6)) * 1.5, to.length() / maxf(tt * 0.7 - state_t, 0.2))
			velocity.x = v.x
			velocity.z = v.z
			_face(to, dt, 2.0)
			vis.locomotion(dt, Vector2(v.x, v.z).length())
	elif target != null and is_instance_valid(target) and (_trans != "wake" or state_t > tt * 0.35):
		_face(target.global_position - global_position, dt, 1.4)
	if state_t >= tt:
		if _trans == "wake":
			_stand_done()
		_set_state(ES.COMBAT)
		vis.idle(0.3)

func _transition_event(ev: String) -> void:
	match ev:
		"turn":
			AudioDirector.sfx_at("res://assets/audio/whoosh_l.wav", global_position, -10.0, 0.6)
		"rams":
			bring_rams(int(_d("p2_rams", 2)), 2)
		"stand_over":
			vis.idle(0.3)

func _stand_done() -> void:
	stood = true
	var p := _player()
	if target == null and p != null:
		target = p
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("show_boss"):
			hud.show_boss(self)
	AudioDirector.boss_theme(id, 1.5)
	AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 2.0)

# ---------------------------------------------------------------- the rams
func rams_up() -> Array:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	return _minions

## Frost-rams over the fold wall: they land on the ring's edge, opposite
## ways round from the Bearer, already running.
func bring_rams(n: int, cap: int) -> int:
	var placed := 0
	var c := father_point()
	var ring := maxf(float(_d("guard_r", 7.0)) + 3.0, 8.0)
	for i in n:
		if rams_up().size() >= cap:
			break
		var e := Enemy.new()
		e.setup("frost_ram")
		get_parent().add_child(e)
		var from_p := (target.global_position if _target_valid() else global_position) - c
		var a := atan2(from_p.z, from_p.x) + PI + (float(i) - float(n - 1) * 0.5) * 1.1
		e.global_position = Vector3(c.x + cos(a) * ring, global_position.y + 0.2, c.z + sin(a) * ring)
		e.home = e.global_position
		e.target = target
		e._set_state(ES.ALERT)
		_minions.append(e)
		_own(e)
		placed += 1
	if placed > 0:
		Juice.shake(0.3, 0.3)
	return placed

# ---------------------------------------------------------------- combat
func _st_extra(dt: float) -> void:
	match state:
		ES.TRANSITION: _st_transition(dt)
		ES.HOLD: _st_hold(dt)
		_: super._st_extra(dt)

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	# phase 3: she will not be drawn off him
	if phase == 3 and not dead and (state == ES.COMBAT or state == ES.APPROACH):
		var from_f := global_position - father_point()
		from_f.y = 0
		var gr := float(_d("guard_r", 7.0))
		if from_f.length() > gr:
			var back := -from_f.normalized() * float(cfg.get("speed", 2.6))
			velocity.x = back.x
			velocity.z = back.z

func _attack_usable(a: Dictionary) -> bool:
	match String(a.get("type", "")):
		"summon":
			return rams_up().size() < int(a.get("max_alive", 2))
		"hold":
			return global_position.distance_to(father_point()) < float(_d("guard_r", 7.0)) + 1.0
	return true

func _strike() -> void:
	match String(_atk.get("type", "melee")):
		"herd": _call_herd()
		"hold": _enter_count()
		"summon": bring_rams(int(_atk.get("count", 1)), int(_atk.get("max_alive", 2)))
		_: super._strike()

func _st_attack(dt: float) -> void:
	if String(_atk.get("type", "")) == "hold":
		velocity.x = move_toward(velocity.x, 0, 12 * dt)
		velocity.z = move_toward(velocity.z, 0, 12 * dt)
		_face(father_point() - global_position, dt, 1.5)
		if state_t >= float(_atk.get("windup", 1.6)) / _speed_mult():
			_strike()
		return
	super._st_attack(dt)

## Where the flock runs: a strip across her aim through where the Bearer
## stands (they come from the side, over the wall), and with "cross" a second
## along the aim. [[from, dir]] on the ground plane.
func herd_plan() -> Array:
	var hd: Dictionary = _atk.get("herd", {})
	var f := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var tp: Vector3 = target.global_position if _target_valid() else global_position + f * 5.0
	var side := f.cross(Vector3.UP)
	var half := float(hd.get("length", 20.0)) * 0.5
	var out := [[Vector3(tp.x, global_position.y, tp.z) - side * half, side]]
	if bool(hd.get("cross", false)):
		out.append([Vector3(tp.x, global_position.y, tp.z) + f * half, -f])
	return out

func _spawn_telegraph(remaining: float) -> Node:
	if String(_atk.get("type", "")) != "herd":
		return super._spawn_telegraph(remaining)
	var hd: Dictionary = _atk.get("herd", {})
	var tint: Array = (_atk.get("telegraph", {}) as Dictionary).get("color", [0.3, 0.58, 1.0])
	_herd_plan = herd_plan()
	var last: Node = null
	var k := 0
	for pl in _herd_plan:
		var b := Basis.looking_at(pl[1], Vector3.UP)
		# the second strip glows on until its own flock comes
		var extra := float(hd.get("cross_delay", 0.7)) * float(k) + float(hd.get("run", 1.3)) * 0.5
		last = _own(FloorTelegraph.spawn(get_parent(), Transform3D(b, pl[0]), "rect",
				[float(hd.get("width", 3.2)), float(hd.get("length", 20.0))], maxf(remaining, 0.1) + extra,
				Color(tint[0], tint[1], tint[2])))
		k += 1
	return last

func _call_herd() -> void:
	var hd: Dictionary = _atk.get("herd", {})
	if _herd_plan.is_empty():
		_herd_plan = herd_plan()
	var dmg := float(_atk.get("dmg", 24))
	var pd := float(_atk.get("poise_dmg", 70))
	var runs := []
	var k := 0
	for pl in _herd_plan:
		var from: Vector3 = pl[0]
		var along: Vector3 = pl[1]
		var go := func():
			if not is_instance_valid(self) or dead:
				return
			var h := HerdRun.start(get_parent(), from, along, float(hd.get("length", 20.0)), float(hd.get("width", 3.2)),
					float(hd.get("run", 1.3)), int(hd.get("count", 9)), String(_d("herd_kit", "sheep")), _d("herd_remap", {}),
					func(p): _hit_player(p, dmg, pd, "physical", false))
			herds.append(h)
		if k == 0:
			go.call()
		else:
			get_tree().create_timer(float(hd.get("cross_delay", 0.7)) * k, false).timeout.connect(go)
		runs.append([from, along])
		k += 1
	_herd_plan = []
	herd_called.emit(runs)
	Juice.shake(0.3, 0.6)
	AudioDirector.sfx_at("res://assets/audio/roll.wav", global_position, 0.0, 0.6)

# ---------------------------------------------------------------- count them
func _enter_count() -> void:
	_hold_quiet = 0.0
	_set_state(ES.HOLD)
	vis.play(String(_atk.get("hold_anim", "kneel_down")), 0.4)
	AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, -8.0, 0.7)

func _st_hold(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_hold_quiet += dt
	_face(father_point() - global_position, dt, 1.0)
	if _hold_quiet >= float(attack_by_id("count_them").get("quiet", 5.0)):
		_set_state(ES.COMBAT)
		vis.idle(0.6)

## A Horn swing is parryable; everything else she shrugs.
func on_parried(host) -> void:
	if state == ES.ATTACK and _atk.get("parry_stagger", false):
		_end_all_swings()
		var p := _player()
		if p != null and p.has_method("on_parry_success"):
			p.on_parry_success(self)
		_stagger(float(_d("parry_stagger_mult", 1.5)))
		return
	super.on_parried(host)

# ---------------------------------------------------------------- release
func _die() -> void:
	if released:
		return
	released = true
	dead = true
	_set_state(ES.DEAD)
	_end_all_swings()
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	Game.add_warmth(int(cfg.get("warmth", 10)))
	for m in rams_up():
		(m as Enemy)._die()   # the tups go down with the call
	_fight_over()
	for h in herds:
		if is_instance_valid(h):
			(h as Node).queue_free()
	herds.clear()
	# one soft call, and then she kneels by him
	vis.play("call", 0.5, 0.6)
	AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, -10.0, 0.62)
	get_tree().create_timer(1.6, false).timeout.connect(func():
		if is_instance_valid(self):
			_face_now(father_point() - global_position)
			vis.play(String(_d("release_anim", "kneel_down")), 0.8))
	lie_flock_down()
	died.emit(self)
	_release_flow.call_deferred()

func _face_now(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.05:
		vis.rotation.y = atan2(-dir.x, -dir.z)

## The whole slope of sheep lies down at once (data "release_flock": the
## group the area's frozen flock is in, how low, over how long). A rebuilt
## Reach lays them lying (the area's own flagged props).
func lie_flock_down() -> int:
	var rf: Dictionary = _d("release_flock", {})
	var n := 0
	for s in get_tree().get_nodes_in_group(String(rf.get("group", "flock_rime"))):
		var sheep := s as Node3D
		if sheep == null or sheep.has_meta("lying"):
			continue
		sheep.set_meta("lying", true)
		var tw := sheep.create_tween()
		tw.tween_property(sheep, "scale:y", sheep.scale.y * float(rf.get("lie", 0.58)), float(rf.get("over", 1.1))) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		n += 1
	return n

func _release_flow() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("hide_boss"):
			hud.hide_boss()
	if not _engaged_by_veil:
		Game.on_boss_slain(Game.current_area_id, self)
	released_boss.emit()

## She stays where she knelt; no dissolve.
func _fade_out() -> void:
	pass

func _exit_tree() -> void:
	for h in herds:
		if is_instance_valid(h):
			(h as Node).queue_free()
	herds.clear()
	super._exit_tree()
