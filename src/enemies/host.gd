class_name Host
extends Enemy
## The Holdfast of Tarnhall (TARNHALL.md 6): Gaute Haug, who barred the hall
## doors when his guests began coughing and could not open them again, and
## kept filling their cups. Three phases by HP (data "phase_at"), each with
## its own repertoire (attack "phases"); every timing in enemies.json; every
## move that covers ground behind a floor telegraph.
##
##   intro      he walks the table filling horns; wakes when the Bearer is
##              within wake_dist or strikes him: sets the horn down, turns.
##   phase 1    Horn fist, Table sweep (the table on his back comes round:
##              a fan; whoever is in it is slid outward and pinned against
##              a wall or bench), Bench throw (lands on a circle).
##   -> 2       raise_guests: two white guests stand up out of their seats
##              (the seated stills in the hall), and the horns in front of
##              empty places fill again.
##   phase 2    Raise the guests (more stand, capped), Tip the horn (a pool
##              of frost spreads across the floor), two benches at a time.
##   -> 3       his pools grey out; he goes back to the table and keeps to it.
##   phase 3    the sweep turns right round; Pour (he fills the horns along
##              the table, his back to the Bearer: open; mends the guests;
##              left alone, a guest stands and he turns back).
##   release    he sets the horn down and sits; the guests sit; the bar on
##              the front doors lifts (release_gates) and the doors open;
##              his cup is left beside him (release_drop); card and hearth
##              through Game.on_boss_slain.

signal phase_changed(new_phase: int)
signal released_boss
signal guests_raised(n: int)

var stood := false
var released := false
var guests: Array = []         # the guests he has raised this fight
var pools: Array = []          # the frost he has poured
var filled: Array = []         # the horns he has filled again (dark skins)
var _trans := ""
var _trans_events: Array = []
var _hold_quiet := 0.0
var _engaged_by_veil := false

func _ready() -> void:
	super._ready()
	vis.play("pour_horn", 0.0)

func _d(key: String, def = null):
	return cfg.get(key, def)

func phase_at() -> Array:
	return cfg.get("phase_at", [0.6, 0.25])

func repertoire() -> Array:
	var out := []
	for a in cfg.get("attacks", []):
		if not a.has("phases") or phase in a["phases"] or float(phase) in a["phases"]:
			out.append(String(a["id"]))
	return out

func standing_guests() -> Array:
	guests = guests.filter(func(g): return is_instance_valid(g) and not g.dead)
	return guests

func _on_pool(fp: FrostPool) -> void:
	pools.append(fp)

func open_pools() -> int:
	pools = pools.filter(func(p): return is_instance_valid(p) and (p as FrostPool).is_open())
	return pools.size()

# ---------------------------------------------------------------- the seats
## The guests still in their places: the seated feast-guests the area spawns
## along the benches in RIME (enemies data "seated", pose sit_feast), or a
## white still of the feast-guest model.
func seated() -> Array:
	var out: Array = []
	for n3 in _places():
		if n3.has_meta("risen"):
			continue
		if n3 is Enemy:
			if not (n3 as Enemy).dead and (n3 as Enemy).state == ES.IDLE:
				out.append(n3)
		elif n3.is_visible_in_tree():
			out.append(n3)
	out.sort_custom(func(a, b): return _seat_cost(a) < _seat_cost(b))
	return out

## Seats on his side of the table first (their backs to the floor he stands
## on), then the nearest.
func _seat_cost(seat: Node3D) -> float:
	var to_home := home - seat.global_position
	to_home.y = 0.0
	var behind := _seat_faces(seat).dot(to_home) > 0.0   # the table is between them
	return seat.global_position.distance_squared_to(home) + (400.0 if behind else 0.0)

## Up to `n` guests stand out of their seats (never more than max_alive up).
## Each rises where it sat, stepped out from the bench toward the floor.
func raise_guests(n: int) -> int:
	var cap := int(attack_by_id("raise_guests").get("max_alive", 3))
	var placed := 0
	for seat in seated():
		if placed >= n or standing_guests().size() >= cap:
			break
		var s3 := seat as Node3D
		if s3 is Enemy:
			# a seated guest stands up out of its place
			var sg := s3 as Enemy
			sg.set_meta("risen", true)
			sg.target = target if target != null else _player()
			if sg.target != null:
				sg._set_state(ES.ALERT)
			guests.append(sg)
			_fill_horn(sg)
			placed += 1
			continue
		var g := Enemy.new()
		g.setup(String(_d("guest", "feast_guest")))
		g.idle_pose = "sit_feast"
		get_parent().add_child(g)
		# out from the bench, away from the table it faces
		var faces := _seat_faces(s3)
		g.global_position = s3.global_position - faces * float(_d("seat_step", 0.55)) + Vector3.UP * 0.1
		g.vis.rotation.y = atan2(-faces.x, -faces.z)
		g.home = g.global_position
		g.target = target if target != null else _player()
		if g.target != null:
			g._set_state(ES.ALERT)
		s3.visible = false
		s3.set_meta("risen", true)
		guests.append(g)
		_fill_horn(s3)
		placed += 1
	if placed > 0:
		guests_raised.emit(placed)
		AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, -6.0, 1.3)
	return placed

## Every place at the table: the feast-guest stills, risen or not (not the
## bodies of guests that are up: those are the same model, inside an Enemy).
var _places_cache: Array = []

func _places() -> Array:
	_places_cache = _places_cache.filter(func(n): return is_instance_valid(n))
	if not _places_cache.is_empty():
		return _places_cache
	var area: Node = Game.current_area if Game.current_area != null else get_parent()
	var out: Array = []
	for n in area.find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if not n3.scene_file_path.ends_with("feast_guest.glb"):
			continue
		var up := n3.get_parent()
		var in_body := false
		while up != null and up != area:
			if up is Enemy:
				in_body = true
				break
			up = up.get_parent()
		if not in_body:
			out.append(n3)
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Enemy and (e as Enemy).cfg.get("seated", false) and (e as Enemy).can_process():
			out.append(e)
	_places_cache = out
	return out

## Which way a seated still faces (a raw glb: its front is +Z), on the floor.
static func _seat_faces(seat: Node3D) -> Vector3:
	var f := seat.global_transform.basis.z
	if seat is Enemy:
		f = -(seat as Enemy).vis.global_transform.basis.z   # (an Enemy faces -Z)
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

## The horn in front of a place fills again, dark, and skins over.
func _fill_horn(seat: Node3D) -> void:
	var at := seat.global_position + _seat_faces(seat) * float(_d("horn_ahead", 1.53)) \
			+ Vector3.UP * float(_d("horn_h", 1.17))
	var skin := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.08
	cm.height = 0.02
	skin.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.12, 0.2)
	m.roughness = 0.15
	skin.material_override = m
	get_parent().add_child(skin)
	skin.global_position = at
	filled.append(skin)
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.7
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.06
	p.color = Color(0.5, 0.62, 0.9, 0.8)
	p.mesh = AreaPortal.make_mote_quad(1.0)
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	RH.free_after(p, 1.0)

## Every horn: the ones in front of empty places (Pour, the second sitting).
func fill_empty_places() -> void:
	for n3 in _places():
		if n3.has_meta("risen") and not n3.has_meta("refilled"):
			n3.set_meta("refilled", true)
			_fill_horn(n3)

# ---------------------------------------------------------------- intro
func engage_from_veil(p: Node3D) -> void:
	target = p
	_engaged_by_veil = true

func _st_idle(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 8 * dt)
	velocity.z = move_toward(velocity.z, 0, 8 * dt)
	var p := _player()
	if p == null or p.get("dead"):
		return
	if global_position.distance_to(p.global_position) <= float(_d("wake_dist", 7.0)):
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
		_hold_quiet = 0.0   # he keeps pouring while the Bearer keeps at it
	var was_up := stood
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
		hp = maxf(hp, max_hp * float(at[1]) + 1.0)   # one blow cannot skip the second sitting
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
		AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 1.0, 0.6)

func _transition_time() -> float:
	return float(((cfg.get("transitions", {}) as Dictionary).get(_trans, {}) as Dictionary).get("time", 2.0))

func _st_transition(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 12 * dt)
	velocity.z = move_toward(velocity.z, 0, 12 * dt)
	while not _trans_events.is_empty() and state_t >= float(_trans_events[0][0]):
		var ev: Array = _trans_events.pop_front()
		_transition_event(String(ev[1]))
	var tt := _transition_time()
	if _trans == "p3" and state_t < tt * 0.7:
		# back to the table, to keep to it
		var to := home - global_position
		to.y = 0
		if to.length() > 0.6:
			var v := to.normalized() * minf(float(cfg.get("speed", 1.8)), to.length() / 0.4)
			velocity.x = v.x
			velocity.z = v.z
			_face(to, dt, 2.0)
	elif target != null and is_instance_valid(target) and (_trans != "wake" or state_t > tt * 0.45):
		_face(target.global_position - global_position, dt, 1.2)
	if state_t >= tt:
		if _trans == "wake":
			_stand_done()
		_set_state(ES.COMBAT)
		vis.idle(0.3)

func _transition_event(ev: String) -> void:
	match ev:
		"set_down":   # the horn set down on the table in front of a guest
			AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -10.0, 0.7)
		"raise":
			raise_guests(int(_d("raise_count", 2)))
		"refill":
			fill_empty_places()
		"pools_grey":
			for fp in pools:
				if is_instance_valid(fp):
					(fp as FrostPool).close()
			pools.clear()

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
		# he keeps to the table, facing the Bearer
		var from_home := global_position - home
		from_home.y = 0
		if from_home.length() > float(_d("guard_r", 6.0)):
			_face(target.global_position - global_position, dt, 2.0)
			var back := -from_home.normalized() * float(cfg.get("speed", 1.8))
			velocity.x = move_toward(velocity.x, back.x, 8 * dt)
			velocity.z = move_toward(velocity.z, back.z, 8 * dt)
			for k in _cooldowns:
				_cooldowns[k] = maxf(0.0, _cooldowns[k] - dt)
			return
	super._st_combat(dt)

## Raise the guests only while fewer than two stand; Pour only at the table.
func _attack_usable(a: Dictionary) -> bool:
	match String(a.get("id", "")):
		"raise_guests":
			return standing_guests().size() < int(a.get("below", 2)) and not seated().is_empty()
		"pour":
			var d := global_position - home
			d.y = 0
			return d.length() <= float(_d("guard_r", 6.0)) + 0.5
	return true

func _strike() -> void:
	match String(_atk.get("type", "melee")):
		"hold": _enter_hold()
		"summon": raise_guests(int(_atk.get("count", 2)))
		_: super._strike()

func _st_attack(dt: float) -> void:
	if String(_atk.get("type", "")) == "hold":
		# he turns his back on the Bearer, to the table, and lifts a horn
		velocity.x = move_toward(velocity.x, 0, 12 * dt)
		velocity.z = move_toward(velocity.z, 0, 12 * dt)
		_face(_table_dir(), dt, 1.5)
		if state_t >= float(_atk.get("windup", 1.6)) / _speed_mult():
			_strike()
		return
	super._st_attack(dt)

## Toward the nearest place at the table (a seat still, risen or not).
func _table_dir() -> Vector3:
	var best := Vector3.ZERO
	var bd := 1e9
	for n3 in _places():
		var d := (n3 as Node3D).global_position.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = _seat_faces(n3)   # the way the nearest place faces: across the table
			if best.dot((n3 as Node3D).global_position - global_position) < 0.0:
				best = (n3 as Node3D).global_position - global_position   # (a place across the table from him)
	if best == Vector3.ZERO:
		best = -vis.global_transform.basis.z
	best.y = 0
	return best

func _enter_hold() -> void:
	_hold_quiet = 0.0
	_set_state(ES.HOLD)
	vis.play("pour_horn", 0.3)
	for g in standing_guests():
		g.hp = g.max_hp   # every guest still up is mended
	fill_empty_places()

func _st_hold(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_hold_quiet += dt
	_face(_table_dir(), dt, 1.0)
	if fmod(state_t, 1.2) < dt:
		AudioDirector.sfx_at("res://assets/audio/whoosh_l.wav", global_position, -16.0, 0.4)
	if _hold_quiet >= float(attack_by_id("pour").get("quiet", 5.0)):
		raise_guests(1)
		_set_state(ES.COMBAT)
		vis.idle(0.6)

## A horn fist is parryable; everything else he shrugs.
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
	_fight_over()
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	var to := _table_dir()
	vis.rotation.y = atan2(to.x, to.z)   # his back to the table, sitting at it
	vis.play(String(_d("release_anim", "host_sit")), 0.5)   # he sets the horn down and sinks onto the bench end
	Game.add_warmth(int(cfg.get("warmth", 10)))
	for fp in pools:
		if is_instance_valid(fp):
			(fp as FrostPool).close()
	pools.clear()
	for g in standing_guests():
		_sit_guest(g)
	for n in _places():   # and those still in their places stay there
		if n is Enemy and not (n as Enemy).dead and not guests.has(n):
			_sit_guest(n)
	died.emit(self)
	_release_flow.call_deferred()

## A guest still standing sits down where it is.
func _sit_guest(g: Enemy) -> void:
	g.set_physics_process(false)
	g.remove_from_group(RH.GROUP_ENEMIES)
	g.hurtbox.set_deferred("monitorable", false)
	g.collision_layer = 0
	g._end_all_swings()
	g.vis.play("sit_feast", 0.5)
	if g.hpbar != null:
		g.hpbar.dismiss()

func _release_flow() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("hide_boss"):
			hud.hide_boss()
	if not _engaged_by_veil:
		Game.on_boss_slain(Game.current_area_id, self)
	released_boss.emit()

## He stays where he sat; no dissolve.
func _fade_out() -> void:
	pass

## Raised guests outlive the fight only as seated stills: on leaving, free
## them with him (the area rebuild lays the stills again).
func _exit_tree() -> void:
	for g in guests:
		if is_instance_valid(g) and not (g as Enemy).cfg.get("seated", false):
			g.queue_free()   # (a seated guest belongs to its spawner)
	guests.clear()
	for s in filled:
		if is_instance_valid(s):
			s.queue_free()
	filled.clear()
	# and a fight reset before his release seats them again: the stills that
	# stood up are back in their places (they stayed gone, the bench empty,
	# with nobody left for the next Host to raise)
	if not released:
		for n in _places_cache:
			if is_instance_valid(n) and not (n is Enemy) and n.has_meta("risen"):
				(n as Node3D).visible = true
				n.remove_meta("risen")
				n.remove_meta("refilled")
	super._exit_tree()
