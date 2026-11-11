class_name Hedgelayer
extends Enemy
## The Holdfast of Thornwold (THORNWOLD.md 6): Eyvind Brask, who hedged in
## his betrothed's grave so nobody could come and sing her out, ring after
## ring, and never decided where the gate went. Three phases by HP (data
## "phase_at"), each with its own repertoire (attack "phases"); every timing
## in enemies.json; every move that covers ground behind a floor telegraph.
##
##   intro      at the hedge with his back to the gap, laying a stem that is
##              already laid; wakes when the Bearer is within wake_dist or
##              strikes him.
##   phase 1    Bill, Thorn lash (catches and drags the Bearer in, then a
##              Bill), Raise a wall (a wall of thorn rises across the floor
##              behind the Bearer: ThornWall).
##   -> 2       a ring of thorn rises round the grave (data "ring2") with one
##              gap, where he stands; it stays for the phase.
##   phase 2    Into the hedge (he backs into the nearest thorn and comes out
##              of another place on it, by the Bearer, with a Bill across a
##              glowing circle); two walls at a time, a lane.
##   -> 3       the ring closes in ("ring3"); he stands in its gap.
##   phase 3    Thorn lash twice, Where it goes (he measures the gap, his back
##              to the Bearer: open; resumes after 5 quiet seconds).
##   release    he kneels at the gap; every wall he raised unlays itself; the
##              gate he never hung lies down flat across the gap
##              (release_gate_laid); the song-cord on the grave (release_drop
##              at_point); card and hearth through Game.on_boss_slain.

signal phase_changed(new_phase: int)
signal released_boss
signal stepped_out(at: Vector3)

var stood := false
var released := false
var walls: Array = []          # the thorn he has raised this fight
var ring: ThornWall = null     # the phase ring round the grave
var hidden := false            # inside the hedge (Into the hedge)
var laid_gate: Node3D = null
var _trans := ""
var _trans_events: Array = []
var _hold_quiet := 0.0
var _hold_kind := ""
var _exit := Vector3.INF
var _exit_tele: Node = null
var _engaged_by_veil := false

func _ready() -> void:
	super._ready()
	vis.play("lay_stem", 0.0)

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

## The grave under the pine: data "grave_off" [dx, dz] from where he stands.
func grave_point() -> Vector3:
	var o: Array = _d("grave_off", [0.0, 0.0])
	return home + Vector3(float(o[0]), 0.0, float(o[1]))

## Linnet's song-cord is set on the grave (release_drop at_point).
func drop_point() -> Vector3:
	return grave_point() + Vector3(1.4, 0.4, 0.0)

func standing_walls() -> Array:
	walls = walls.filter(func(w): return is_instance_valid(w) and (w as ThornWall).is_standing())
	return walls

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
	if state == ES.HOLD and _hold_kind == "measure":
		_hold_quiet = 0.0   # he keeps measuring while the Bearer keeps at it
	var was_up := stood
	if packet.source != null and packet.source.is_in_group("player"):
		packet.amount *= Game.test_boss_dmg_mult   # 1.0 outside the full-game walk
	super.take_hit(packet)
	if not was_up and not dead and state != ES.TRANSITION:
		if packet.source != null and packet.source.is_in_group("player"):
			target = packet.source
		_wake()

func is_invulnerable() -> bool:
	return dead or released or hidden or state == ES.TRANSITION

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
	if hidden:
		_emerge(global_position, false)
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
	if (_trans == "p2" or _trans == "p3") and state_t < tt * 0.45:
		# to where the ring's gap will be: on its line, on his side of the grave
		var rr := float((_d("ring2" if _trans == "p2" else "ring3", {}) as Dictionary).get("radius", 8.0))
		var from_g := global_position - grave_point()
		from_g.y = 0
		var want := grave_point() + (from_g.normalized() if from_g.length() > 0.2 else Vector3.LEFT) * rr
		var to := want - global_position
		to.y = 0
		if to.length() > 0.3:
			var v := to.normalized() * minf(float(cfg.get("speed", 2.2)) * 1.6, to.length() / 0.3)
			velocity.x = v.x
			velocity.z = v.z
			_face(to, dt, 2.0)
	elif target != null and is_instance_valid(target) and (_trans != "wake" or state_t > tt * 0.4):
		_face(target.global_position - global_position, dt, 1.2)
	if state_t >= tt:
		if _trans == "wake":
			_stand_done()
		_set_state(ES.COMBAT)
		vis.idle(0.3)

func _transition_event(ev: String) -> void:
	match ev:
		"turn":
			AudioDirector.play("boss/thorn_growth", global_position, -6.0)
		"ring":
			_raise_ring(_d("ring2", {}))
		"ring_close":
			_raise_ring(_d("ring3", {}))

## A ring of thorn round the grave, its gap where he stands (he is in it).
func _raise_ring(rc: Dictionary) -> void:
	if ring != null and is_instance_valid(ring):
		ring.sink(0.6)
	var c := grave_point()
	var to := global_position - c
	var gap := rad_to_deg(atan2(to.z, to.x))
	ring = ThornWall.raise_ring(get_parent(), Vector3(c.x, global_position.y - 0.1, c.z), float(rc.get("radius", 8.0)),
			gap, float(rc.get("height", 3.0)), 9999.0)
	walls.append(ring)
	# whoever stands in the hedge's line is put out of it, inward
	var p := _player()
	if p != null and not p.get("dead"):
		var d := Vector2(p.global_position.x - c.x, p.global_position.z - c.z)
		if absf(d.length() - ring.radius) < 1.0 and ring.distance_to(p.global_position) < 1.0:
			var inward := -d.normalized() * 1.4
			p.global_position += Vector3(inward.x, 0, inward.y)

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

func _attack_usable(a: Dictionary) -> bool:
	match String(a.get("type", "")):
		"step":
			return not standing_walls().is_empty()
		"hold":
			return ring != null and is_instance_valid(ring) and ring.distance_to(global_position) < 3.0
	return true

func _strike() -> void:
	match String(_atk.get("type", "melee")):
		"wall": _raise_walls()
		"step": _go_in()
		"hold": _enter_measure()
		_: super._strike()

func _st_attack(dt: float) -> void:
	if String(_atk.get("type", "")) == "hold":
		velocity.x = move_toward(velocity.x, 0, 12 * dt)
		velocity.z = move_toward(velocity.z, 0, 12 * dt)
		_face(_gap_dir(), dt, 1.5)
		if state_t >= float(_atk.get("windup", 1.6)) / _speed_mult():
			_strike()
		return
	super._st_attack(dt)

## Where the walls go: across the aim behind the Bearer (one), or either
## side of him along it (two: a lane). Ground-plane [centre, yaw] pairs.
func wall_plan() -> Array:
	var wd: Dictionary = _atk.get("wall", {})
	var f := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var tp: Vector3 = target.global_position if _target_valid() else global_position + f * 4.0
	var side := f.cross(Vector3.UP)
	var out := []
	if int(wd.get("count", 1)) >= 2:
		var lane := float(wd.get("lane", 2.4))
		for s in [-1.0, 1.0]:
			out.append([tp + side * lane * s, atan2(-f.z, f.x)])   # along the aim
	else:
		out.append([tp + f * float(wd.get("behind", 2.6)), atan2(-side.z, side.x)])   # across it
	return out

func _spawn_telegraph(remaining: float) -> Node:
	if String(_atk.get("type", "")) != "wall":
		return super._spawn_telegraph(remaining)
	var wd: Dictionary = _atk.get("wall", {})
	var tint: Array = (_atk.get("telegraph", {}) as Dictionary).get("color", [0.3, 0.58, 1.0])
	var last: Node = null
	for pl in wall_plan():
		var c: Vector3 = pl[0]
		var yaw: float = pl[1]
		# a rect runs forward (-Z) from its origin: start it at one end of the wall
		var along := Vector3(cos(yaw), 0, -sin(yaw))
		var start := c - along * float(wd.get("length", 9.0)) * 0.5
		var b := Basis.looking_at(along, Vector3.UP)
		last = FloorTelegraph.spawn(get_parent(), Transform3D(b, Vector3(start.x, global_position.y, start.z)), "rect",
				[float(wd.get("width", 1.4)), float(wd.get("length", 9.0))], maxf(remaining, 0.1), Color(tint[0], tint[1], tint[2]))
	return last

func _raise_walls() -> void:
	var wd: Dictionary = _atk.get("wall", {})
	var p := _player()
	for pl in wall_plan():
		var c: Vector3 = pl[0]
		var w := ThornWall.raise(get_parent(), Vector3(c.x, global_position.y - 0.1, c.z), float(pl[1]),
				float(wd.get("length", 9.0)), float(wd.get("height", 3.0)), float(wd.get("life", 14.0)))
		walls.append(w)
		if p != null and not p.get("dead") and w.distance_to(p.global_position) <= float(wd.get("width", 1.4)) * 0.5 + 0.2:
			_hit_player(p, float(_atk.get("dmg", 18)), float(_atk.get("poise_dmg", 30)), "physical", false)
	Juice.shake(0.35, 0.3)

# ---------------------------------------------------------------- into the hedge
## He backs into the nearest thorn and is gone.
func _go_in() -> void:
	hidden = true
	vis.visible = false
	collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	_exit = Vector3.INF
	_hold_kind = "hidden"
	_set_state(ES.HOLD)
	AudioDirector.play("boss/thorn_growth", global_position, -2.0)

## Where he will come out: the place on a standing wall nearest the Bearer,
## a step out from it toward him.
func exit_point() -> Vector3:
	var p: Node3D = target if _target_valid() else _player()
	var best := Vector3.INF
	var bd := 1e9
	for w in standing_walls():
		var q := (w as ThornWall).nearest_point(p.global_position)
		var d := q.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = q
	if best == Vector3.INF:
		return p.global_position + Vector3(3, 0, 0)
	var out := p.global_position - best
	out.y = 0
	return best + out.normalized() * 1.0 + Vector3(0, global_position.y - best.y, 0)

func _st_hidden(dt: float) -> void:
	velocity = Vector3.ZERO
	var st: Dictionary = attack_by_id("step_into")
	var gone := float(st.get("gone", 1.2))
	var tell := float(st.get("out_tell", 0.8))
	if _exit == Vector3.INF and state_t >= gone:
		_exit = exit_point()
		global_position = Vector3(_exit.x, global_position.y, _exit.z)
		var tg: Dictionary = st.get("exit_tele", {})
		var tint: Array = tg.get("color", [0.3, 0.58, 1.0])
		_exit_tele = FloorTelegraph.spawn(get_parent(), Transform3D(Basis(), global_position), "ring",
				[float((st.get("sweep", {}) as Dictionary).get("radius", 3.0))], tell, Color(tint[0], tint[1], tint[2]))
		AudioDirector.play("boss/thorn_growth", global_position, -5.0)
	if _exit != Vector3.INF and state_t >= gone + tell:
		_emerge(_exit, true)

## Out of the hedge, with a Bill across the circle.
func _emerge(at: Vector3, strike: bool) -> void:
	hidden = false
	vis.visible = true
	collision_layer = 1 << (RH.L_ENEMY - 1)
	hurtbox.set_deferred("monitorable", true)
	_hold_kind = ""
	stepped_out.emit(at)
	if not strike:
		return
	if _target_valid():
		var to := target.global_position - global_position
		vis.rotation.y = atan2(-to.x, -to.z)
		_atk_dir = Vector3(-sin(vis.rotation.y), 0, -cos(vis.rotation.y))
	_atk = attack_by_id("step_into")
	_atk_off = 0.0
	_sweep_strike()
	vis.play("slash", 0.05)
	_set_state(ES.COMBAT)

# ---------------------------------------------------------------- where it goes
## The gap in his ring, from where he stands.
func _gap_dir() -> Vector3:
	var to := grave_point() - global_position
	to.y = 0
	return -to if to.length() > 0.1 else -vis.global_transform.basis.z

func _enter_measure() -> void:
	_hold_quiet = 0.0
	_hold_kind = "measure"
	_set_state(ES.HOLD)
	vis.play("measure_gap", 0.3)

func _st_hold(dt: float) -> void:
	if _hold_kind == "hidden":
		_st_hidden(dt)
		return
	velocity.x = 0
	velocity.z = 0
	_hold_quiet += dt
	_face(_gap_dir(), dt, 1.0)
	if _hold_quiet >= float(attack_by_id("where_it_goes").get("quiet", 5.0)):
		_hold_kind = ""
		_set_state(ES.COMBAT)
		vis.idle(0.6)

## A Bill is parryable; everything else he shrugs.
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
	if hidden:
		_emerge(global_position, false)
	_set_state(ES.DEAD)
	_end_all_swings()
	if hook_hold != null:
		hook_hold.end(false)
	_pull_t = 0.0
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	vis.play(String(_d("release_anim", "kneel_hands")), 0.5)   # he kneels and puts his hands on the ground
	Game.add_warmth(int(cfg.get("warmth", 10)))
	_unlay()
	_lay_gate_down()
	died.emit(self)
	_release_flow.call_deferred()

## The hedge unlays itself stem by stem: the ring first, then the walls.
func _unlay() -> void:
	var order: Array = []
	if ring != null and is_instance_valid(ring):
		order.append(ring)
	for w in standing_walls():
		if w != ring:
			order.append(w)
	var t := 0.0
	for w in order:
		var ww: ThornWall = w
		get_tree().create_timer(t, false).timeout.connect(func():
			if is_instance_valid(ww):
				ww.sink(1.4))
		t += 0.35
	ring = null

## The gate he never hung lies down flat across the gap (data
## "release_gate_laid": {scene, off [dx, dz] from the grave, rot}); the one
## leaning on the hedge is gone. The area lays it again on every rebuild.
func _lay_gate_down() -> void:
	var gd: Dictionary = _d("release_gate_laid", {})
	if gd.is_empty():
		return
	var area: Node = Game.current_area if Game.current_area != null else get_parent()
	var scene := String(gd.get("scene", ""))
	for n in area.find_children("*", "Node3D", true, false):
		if (n as Node3D).scene_file_path == scene and not (n as Node3D).has_meta("laid"):
			(n as Node3D).visible = false
	if not ResourceLoader.exists(scene):
		return
	laid_gate = (load(scene) as PackedScene).instantiate()
	laid_gate.set_meta("laid", true)
	# on the ground of both memories: under the RIME layer it went out of
	# sight when the wood was warmed, with Linnet standing there saying it
	# lay across the gap
	var holder: Node = (area as Area).base if area is Area else get_parent()
	holder.add_child(laid_gate)
	var off: Array = gd.get("off", [0.0, 0.0])
	var at := grave_point() + Vector3(float(off[0]), 0.0, float(off[1]))
	var gy := global_position.y
	var from := Vector3(at.x, global_position.y + 1.2, at.z)   # (under the hedge tops and the pine)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, RH.M_WORLD_ALL)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		gy = (hit["position"] as Vector3).y   # on the ground in the gap, not where he stood
	laid_gate.global_position = Vector3(at.x, gy + 0.04, at.z)
	laid_gate.rotation_degrees = Vector3(float(gd.get("tilt", -90.0)), float(gd.get("rot", 0.0)), 0.0)
	laid_gate.scale = Vector3.ONE * float(gd.get("scale", 0.8))
	AudioDirector.play("world/bar_drop", laid_gate.global_position)

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

func _exit_tree() -> void:
	for w in walls:
		if is_instance_valid(w):
			(w as Node).queue_free()
	walls.clear()
	super._exit_tree()
