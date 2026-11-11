class_name IceCutter
extends Enemy
## The Holdfast of Kettle Fjord (KETTLE.md 6): Old Pell, who has kept a hole
## open in the ice where his grandson's sledge tracks stopped, cutting it
## fresh every hour. Three phases by HP (data "phase_at"), each with its own
## repertoire (attack "phases"); every timing in enemies.json; every move
## that covers ground behind a floor telegraph; the floor itself breaks
## (BrokenIce: runtime thin-ice volumes).
##
##   intro      kneels at the rim drilling; wakes when the Bearer is within
##              wake_dist or strikes him: pulls the auger out, stands.
##   phase 1    Auger thrust, Drill down (a hole under the Bearer), Trace (a
##              frozen trace catches and drags the Bearer to the hole's rim,
##              then a thrust).
##   -> 2       one turn of the auger: a band of the ice round the arena
##              breaks open for the phase (data "ring_band").
##   phase 2    Ring cut (a ring round him drops away), The team (the dead
##              dog team runs down the ice in a line); Drill down opens two.
##   -> 3       the band closes; he kneels at the hole. He keeps within
##              guard_r of it from now on, slower.
##   phase 3    Auger thrust, Trace, Cut it fresh (kneels and drills at the
##              rim: open; resumes after 5 quiet seconds).
##   release    he lets the auger rest; the hole skins over for good
##              (release_seal); the mitten in the new ice (release_drop
##              at_seal); card and hearth through Game.on_boss_slain.

signal phase_changed(new_phase: int)
signal released_boss

var stood := false
var released := false
var holes: Array = []          # the ice he broke this fight
var band: BrokenIce = null     # phase two's ring round the arena
var _hole := Vector3.INF
var _trans := ""
var _trans_events: Array = []
var _hold_quiet := 0.0
var _engaged_by_veil := false

func _ready() -> void:
	super._ready()
	vis.play("kneel_drill", 0.0)

func _d(key: String, def = null):
	return cfg.get(key, def)

func phase_at() -> Array:
	return cfg.get("phase_at", [0.6, 0.25])

func repertoire() -> Array:
	var out := []
	for a in cfg.get("attacks", []):
		if _in_phase(a):
			out.append(String(a["id"]))
	return out

func _in_phase(a: Dictionary) -> bool:
	return not a.has("phases") or phase in a["phases"] or float(phase) in a["phases"]

## The Breathing Hole: hole_ahead metres along the way he first faces.
func hole_point() -> Vector3:
	if _hole == Vector3.INF:
		var f := -vis.global_transform.basis.z
		f.y = 0
		_hole = home + f.normalized() * float(_d("hole_ahead", 2.6))
	return _hole

## Game.on_boss_slain closes this one (release_seal).
func seal_point() -> Vector3:
	return hole_point()

## The trace drags the Bearer to the hole, not to him.
func _hook_anchor() -> Vector3:
	return hole_point()

func _on_broken_ice(b: BrokenIce) -> void:
	holes.append(b)

func open_holes() -> int:
	holes = holes.filter(func(h): return is_instance_valid(h) and (h as BrokenIce).is_open())
	return holes.size()

# ---------------------------------------------------------------- intro
func engage_from_veil(p: Node3D) -> void:
	target = p
	_engaged_by_veil = true

func _st_idle(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 8 * dt)
	velocity.z = move_toward(velocity.z, 0, 8 * dt)
	hole_point()
	var p := _player()
	if p == null or p.get("dead"):
		return
	if global_position.distance_to(p.global_position) <= float(_d("wake_dist", 6.0)):
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
		_hold_quiet = 0.0   # he keeps drilling while the Bearer keeps at it
	var was_up := stood
	if packet.source != null and packet.source.is_in_group("player"):
		packet.amount *= Game.test_boss_dmg_mult   # 1.0 outside the full-game test
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
		hp = maxf(hp, max_hp * float(at[1]) + 1.0)   # one blow cannot skip the rings
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
	if hook_hold != null:
		hook_hold.end(false)
	_then_atk = ""
	_trans = kind
	var tc: Dictionary = (cfg.get("transitions", {}) as Dictionary).get(kind, {})
	_trans_events = (tc.get("events", []) as Array).duplicate()
	_set_state(ES.TRANSITION)
	vis.play(String(tc.get("anim", "idle")), 0.25)
	if kind != "wake":
		phase_changed.emit(phase)
		Juice.shake(0.5, 0.5)
		AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 1.0, 0.7)

func _transition_time() -> float:
	return float(((cfg.get("transitions", {}) as Dictionary).get(_trans, {}) as Dictionary).get("time", 2.0))

func _st_transition(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 12 * dt)
	velocity.z = move_toward(velocity.z, 0, 12 * dt)
	while not _trans_events.is_empty() and state_t >= float(_trans_events[0][0]):
		var ev: Array = _trans_events.pop_front()
		_transition_event(String(ev[1]))
	var tt := _transition_time()
	if _trans == "p3" and state_t < tt * 0.6:
		# back to the hole, to kneel at it
		var to := hole_point() - global_position
		to.y = 0
		var want := to.length() - float(_d("kneel_off", 2.4))
		if want > 0.3:
			var v := to.normalized() * minf(float(cfg.get("speed", 2.0)), want / 0.4)
			velocity.x = v.x
			velocity.z = v.z
			_face(to, dt, 2.0)
	elif state_t > tt * 0.6 and target != null and is_instance_valid(target):
		_face(target.global_position - global_position, dt, 1.4)
	if state_t >= tt:
		if _trans == "wake":
			_stand_done()
		_set_state(ES.COMBAT)
		vis.idle(0.3)

func _transition_event(ev: String) -> void:
	match ev:
		"knock":   # the shavings knocked off the auger against his boot
			AudioDirector.play("world/ice_break", global_position, -6.0)
		"ring_band":
			var rb: Dictionary = _d("ring_band", {})
			band = BrokenIce.open(get_parent(), hole_point(), "ring", float(rb.get("outer", 10.5)),
					float(rb.get("inner", 9.0)), float(rb.get("life", 9999.0)), float(rb.get("sink", 0.7)))
			holes.append(band)
		"band_close":
			if band != null and is_instance_valid(band):
				band.close()
			band = null

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

# ---------------------------------------------------------------- combat
func _st_extra(dt: float) -> void:
	match state:
		ES.TRANSITION: _st_transition(dt)
		ES.HOLD: _st_hold(dt)
		_: super._st_extra(dt)

func _st_combat(dt: float) -> void:
	if not _target_valid():
		return
	if phase >= 3:
		# he keeps to the hole, facing the Bearer
		var from_hole := global_position - hole_point()
		from_hole.y = 0
		if from_hole.length() > float(_d("guard_r", 4.0)):
			var to := target.global_position - global_position
			_face(to, dt, 2.0)
			var back := -from_hole.normalized() * float(cfg.get("speed", 2.0))
			velocity.x = move_toward(velocity.x, back.x, 8 * dt)
			velocity.z = move_toward(velocity.z, back.z, 8 * dt)
			for k in _cooldowns:
				_cooldowns[k] = maxf(0.0, _cooldowns[k] - dt)
			return
	super._st_combat(dt)

func _st_approach(dt: float) -> void:
	if phase >= 3:
		_set_state(ES.COMBAT)   # he does not follow
		return
	super._st_approach(dt)

## Cut it fresh is for when the Bearer stands off, and only at the hole.
func _attack_usable(a: Dictionary) -> bool:
	if String(a.get("type", "")) == "hold":
		var d := global_position - hole_point()
		d.y = 0
		return d.length() <= float(_d("guard_r", 4.0)) + 0.5
	return true

func _strike() -> void:
	match String(_atk.get("type", "melee")):
		"hold": _enter_hold()
		_: super._strike()
	if String(_atk.get("id", "")) == "dog_team":
		_run_team()

func _st_attack(dt: float) -> void:
	if String(_atk.get("type", "")) == "hold":
		# he turns his back on the Bearer, to the hole, and kneels at the rim
		velocity.x = move_toward(velocity.x, 0, 12 * dt)
		velocity.z = move_toward(velocity.z, 0, 12 * dt)
		_face(hole_point() - global_position, dt, 1.5)
		if state_t >= float(_atk.get("windup", 2.0)) / _speed_mult():
			_strike()
		return
	super._st_attack(dt)

func _enter_hold() -> void:
	_hold_quiet = 0.0
	_set_state(ES.HOLD)
	vis.play("kneel_drill", 0.3)

func _st_hold(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_hold_quiet += dt
	if fmod(state_t, 1.1) < dt:
		AudioDirector.play("world/ice_break", global_position, -10.0)
	if _hold_quiet >= float(attack_by_id("cut_fresh").get("quiet", 5.0)):
		_set_state(ES.COMBAT)
		vis.idle(0.6)

## The team: the dead dogs run down the ice behind him and on past the
## Bearer, along the strip the line strike just hit, and are gone.
func _run_team() -> void:
	var n := int(_atk.get("dogs", 4))
	var length := float(_atk.get("length", 18.0))
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var side := fwd.cross(Vector3.UP)
	var start := global_position - fwd * 4.0
	for i in n:
		var dog := Enemy.new()
		dog.setup(String(_atk.get("dog", "sledge_dog")))
		get_parent().add_child(dog)
		dog.set_physics_process(false)
		dog.collision_layer = 0
		dog.hurtbox.monitorable = false
		dog.remove_from_group(RH.GROUP_ENEMIES)
		var lane := (float(i % 2) - 0.5) * 1.0
		var from := start + side * lane - fwd * float(i / 2) * 1.6
		dog.global_position = from
		dog.vis.rotation.y = atan2(-fwd.x, -fwd.z)
		if dog.vis.quad != null:
			dog.vis.quad.only("lunge", 0.05)
		var tw := dog.create_tween()
		tw.tween_property(dog, "global_position", from + fwd * (length + 6.0), 1.1 + i * 0.05)
		tw.tween_callback(dog.queue_free)

## A thrust is parryable on the bit; everything else he shrugs.
func on_parried(host) -> void:
	if state == ES.ATTACK and _atk.get("parry_stagger", false):
		_end_all_swings()
		var p := _player()
		if p != null and p.has_method("on_parry_success"):
			p.on_parry_success(self)
		_stagger(float(_d("parry_stagger_mult", 1.6)))
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
	if hook_hold != null:
		hook_hold.end(false)
	_pull_t = 0.0
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	var to := hole_point() - global_position
	vis.rotation.y = atan2(-to.x, -to.z)
	vis.play("rest_auger", 0.5)   # he kneels at the rim and lets the auger rest
	Game.add_warmth(int(cfg.get("warmth", 10)))
	for h in holes:
		if is_instance_valid(h):
			(h as BrokenIce).close()
	holes.clear()
	band = null
	died.emit(self)
	_release_flow.call_deferred()

func _release_flow() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("hide_boss"):
			hud.hide_boss()
	if not _engaged_by_veil:
		Game.on_boss_slain(Game.current_area_id, self)
	released_boss.emit()

## He stays where he knelt; no dissolve.
func _fade_out() -> void:
	pass
