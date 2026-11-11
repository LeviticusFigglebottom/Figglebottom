class_name Turfwright
extends Enemy
## The Holdfast of the Lowe (LOWE.md 6): Arne Holm, who will not lay the last
## turf on his twin daughters' barrow. His back is the barrow's turf door,
## propped open. Three phases by HP (data "phase_at"), each with its own
## repertoire (attack "phases"), every timing in enemies.json, every move
## that covers ground behind a floor telegraph.
##
##   intro      stands at the twins' door holding one sod up on the spade;
##              wakes when the Bearer is within wake_dist or strikes him: sets
##              the sod down on the threshold, square, and turns round.
##   phase 1    Spade chop, Ground cut (a 12 m cut that leaves a low sod
##              wall; may chain a Cross cut), Back-drop (the Bearer behind
##              him too long: the door on his back dropped like a lid).
##   -> 2       he drives the spade in and pulls: four sod walls rise in a
##              cross (data "arena_walls"), cutting the hollow into bays.
##   phase 2    Stack a sod (a wall laid where the Bearer stands), Sod throw,
##              Drag swing; the Ground cut always crosses.
##   -> 3       he takes up the sod from the threshold and holds it to his
##              chest; the bay walls slump. One-handed, slower, and he keeps
##              within guard_r of the door, backing up to it.
##   phase 3    One-hand chop, Ground cut, The last turf (kneels at the door
##              and lifts the sod to the gap: open; resumes after 5 quiet s).
##   release    he lays the sod in the doorway; the door on his back comes
##              down; the walls and cuts sink; card, hearth and tally-stick
##              from his data through Game.on_boss_slain.

signal phase_changed(new_phase: int)
signal released_boss

var stood := false
var released := false
var ridges: Array = []        # the cuts and laid sods
var walls: Array = []         # the bay walls of phase two
var sod: MeshInstance3D = null
var sod_at := "spade"         # spade | threshold | chest | door
var _door := Vector3.INF
var _behind_t := 0.0
var _trans := ""
var _trans_events: Array = []
var _hold_quiet := 0.0
var _engaged_by_veil := false
var _turn_from := 0.0

func _ready() -> void:
	super._ready()
	vis.play("turf_raise", 0.0)
	_build_sod()

func _d(key: String, def = null):
	return cfg.get(key, def)

func phase_at() -> Array:
	return cfg.get("phase_at", [0.6, 0.25])

## Which attacks this phase may use (by id), for tests and the HUD.
func repertoire() -> Array:
	var out := []
	for a in cfg.get("attacks", []):
		if not a.has("phases") or phase in a["phases"] or float(phase) in a["phases"]:
			out.append(String(a["id"]))
	return out

## The twins' doorway: door_ahead metres along the way he first faces.
func door_point() -> Vector3:
	if _door == Vector3.INF:
		var f := -vis.global_transform.basis.z
		f.y = 0
		_door = home + f.normalized() * float(_d("door_ahead", 8.0))
	return _door

func _threshold() -> Vector3:
	var to := home - door_point()
	to.y = 0
	return door_point() + to.normalized() * float(_d("threshold_out", 3.2))

# ---------------------------------------------------------------- the sod
func _build_sod() -> void:
	sod = MeshInstance3D.new()
	sod.name = "LastTurf"
	var bm := BoxMesh.new()
	var sz: Array = _d("sod_size", [0.75, 0.2, 0.5])
	bm.size = Vector3(sz[0], sz[1], sz[2])
	sod.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.23, 0.15)
	m.roughness = 0.95
	sod.material_override = m
	var top := MeshInstance3D.new()   # the frosted heather side, up
	var tm := BoxMesh.new()
	tm.size = Vector3(sz[0] * 1.02, 0.04, sz[2] * 1.02)
	top.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.72, 0.74, 0.76)
	tmat.roughness = 0.9
	top.material_override = tmat
	top.position.y = sz[1] * 0.5
	sod.add_child(top)
	sod.top_level = true
	vis.add_child(sod)

func _sync_sod() -> void:
	if sod == null:
		return
	match sod_at:
		"spade":   # level on the blade grown from his right forearm
			var x := vis.bone_xform("mixamorig_RightHand")
			var b := x.basis.orthonormalized()
			var fwd := -vis.global_transform.basis.z
			fwd.y = 0
			sod.global_transform = Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP),
					x.origin + b.y * float(_d("spade_reach", 0.55)) + Vector3.UP * 0.12)
		"chest":
			var l := vis.bone_xform("mixamorig_LeftHand").origin
			var c := vis.bone_xform("mixamorig_Spine2").origin
			var fwd2 := -vis.global_transform.basis.z
			fwd2.y = 0
			sod.global_transform = Transform3D(Basis.looking_at(fwd2.normalized(), Vector3.UP)
					* Basis(Vector3.RIGHT, PI * 0.5), l.lerp(c, 0.35) + fwd2.normalized() * 0.25)
		_:
			pass   # set down: it stays where it was put

func _set_sod_down(at: Vector3, face: Vector3, on_ground := true) -> void:
	face.y = 0
	if on_ground:
		at.y = _ground_y(at) + float((_d("sod_size", [0.75, 0.2, 0.5]) as Array)[1]) * 0.5
	sod.global_transform = Transform3D(Basis.looking_at(face.normalized(), Vector3.UP), at)

## The ground under `p` (the threshold is on the barrow's rising apron).
func _ground_y(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 6.0, RH.M_WORLD_ALL)
	q.exclude = [self]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else p.y

# ---------------------------------------------------------------- intro
func engage_from_veil(p: Node3D) -> void:
	target = p
	_engaged_by_veil = true

func _st_idle(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 8 * dt)
	velocity.z = move_toward(velocity.z, 0, 8 * dt)
	door_point()
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
		_hold_quiet = 0.0   # he stays at the door while the Bearer keeps at it
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
		hp = maxf(hp, max_hp * float(at[1]) + 1.0)   # one blow cannot skip the stacking
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
	_trans = kind
	var tc: Dictionary = (cfg.get("transitions", {}) as Dictionary).get(kind, {})
	_trans_events = (tc.get("events", []) as Array).duplicate()
	_turn_from = vis.rotation.y
	_set_state(ES.TRANSITION)
	vis.play(String(tc.get("anim", "idle")), 0.25)
	if kind != "wake":
		phase_changed.emit(phase)
		Juice.shake(0.5, 0.5)
		AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 1.0, 0.75)

func _transition_time() -> float:
	return float(((cfg.get("transitions", {}) as Dictionary).get(_trans, {}) as Dictionary).get("time", 2.0))

func _st_transition(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 12 * dt)
	velocity.z = move_toward(velocity.z, 0, 12 * dt)
	while not _trans_events.is_empty() and state_t >= float(_trans_events[0][0]):
		var ev: Array = _trans_events.pop_front()
		_transition_event(String(ev[1]))
	var tt := _transition_time()
	# the wake ends with him turning round to the Bearer; the third phase
	# with him turned from the door to the Bearer, the sod held to his chest
	if _trans in ["wake", "p3"] and state_t > tt * 0.6 and target != null and is_instance_valid(target):
		_face(target.global_position - global_position, dt, 1.4)
	if state_t >= tt:
		if _trans == "wake":
			_stand_done()
		_set_state(ES.COMBAT)
		vis.idle(0.3)

func _transition_event(ev: String) -> void:
	match ev:
		"set_down":
			sod_at = "threshold"
			_set_sod_down(_threshold(), door_point() - home)
			AudioDirector.play("boss/sod_thud", global_position, -6.0)
		"raise_walls":
			_raise_walls()
		"take_turf":
			sod_at = "chest"
			if vis.rig != null:
				vis.rig.set_carry("turf_carry", ["mixamorig_LeftShoulder", "mixamorig_LeftArm",
						"mixamorig_LeftForeArm", "mixamorig_LeftHand"], true)
		"walls_slump":
			for w in walls:
				if is_instance_valid(w):
					(w as IceRidge).shatter()
			walls.clear()

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

## Phase two: four walls of stacked sod rise out of the floor. Each wall is
## {"from": [dx, dz], "to": [dx, dz]} in metres from where he first stood,
## turned with him (x his right, z toward the Bearer's way in).
func _raise_walls() -> void:
	var f := -(door_point() - home)
	f.y = 0
	f = f.normalized()
	var r := f.cross(Vector3.UP) * -1.0
	for spec in cfg.get("arena_walls", []):
		var a: Array = spec.get("from", [0, 0])
		var b: Array = spec.get("to", [0, 4])
		var pa := home + r * float(a[0]) + f * float(a[1])
		var pb := home + r * float(b[0]) + f * float(b[1])
		var along := pb - pa
		along.y = 0
		var w := IceRidge.new()
		w.height = float(spec.get("height", 1.6))
		w.setup(along.length(), float(spec.get("life", 9999.0)), int(spec.get("breaks", 3)), "sod")
		get_parent().add_child(w)
		pa.y = global_position.y
		w.global_transform = Transform3D(Basis.looking_at(along.normalized(), Vector3.UP), pa)
		walls.append(w)
	Juice.shake(0.6, 0.6)
	AudioDirector.play("boss/sod_thud", global_position)

## The middle of the cross, where every bay opens (the mean of the walls'
## inner ends, in the same frame as _raise_walls).
func _cross_mid() -> Vector3:
	var f := -(door_point() - home)
	f.y = 0
	f = f.normalized()
	var r := f.cross(Vector3.UP) * -1.0
	var specs: Array = cfg.get("arena_walls", [])
	var m := Vector2.ZERO
	for spec in specs:
		m += Vector2(float(spec["from"][0]), float(spec["from"][1])) / maxf(specs.size(), 1.0)
	return home + r * m.x + f * m.y

## His bay walls are not on the navmesh: with one between him and the Bearer
## the path ran straight into it, and he stood at the wall for as long as
## the Bearer stood behind it. He goes round by the middle of the cross.
func _st_approach(dt: float) -> void:
	if phase == 2 and live_walls() > 0 and target != null and is_instance_valid(target) and not _los_clear():
		var to := _cross_mid() - global_position
		to.y = 0
		if to.length() > 1.0:
			var sp := float(cfg.get("speed", 2.5))
			var dir := to.normalized()
			velocity.x = move_toward(velocity.x, dir.x * sp, 10 * dt * sp)
			velocity.z = move_toward(velocity.z, dir.z * sp, 10 * dt * sp)
			_face(dir, dt)
			return
	super._st_approach(dt)

func live_walls() -> int:
	walls = walls.filter(func(w): return is_instance_valid(w) and not w.is_queued_for_deletion())
	return walls.size()

func live_ridges() -> int:
	ridges = ridges.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())
	return ridges.size()

func _on_ridge(r: IceRidge) -> void:
	ridges.append(r)

# ---------------------------------------------------------------- combat
func _st_extra(dt: float) -> void:
	match state:
		ES.TRANSITION: _st_transition(dt)
		ES.HOLD: _st_hold(dt)
		_: super._st_extra(dt)

func _st_combat(dt: float) -> void:
	if not _target_valid():
		return
	var to := target.global_position - global_position
	to.y = 0
	if phase >= 3:
		# he keeps to the door, backing up to it, facing the Bearer
		var from_door := global_position - door_point()
		from_door.y = 0
		if from_door.length() > float(_d("guard_r", 7.0)):
			_face(to, dt, 2.0)
			var back := -from_door.normalized() * float(cfg.get("speed", 2.3))
			velocity.x = move_toward(velocity.x, back.x, 8 * dt)
			velocity.z = move_toward(velocity.z, back.z, 8 * dt)
			for k in _cooldowns:
				_cooldowns[k] = maxf(0.0, _cooldowns[k] - dt)
			return
	elif stood:
		# the Bearer behind him: the door on his back comes down like a lid
		var fwd := -vis.global_transform.basis.z
		fwd.y = 0
		var deg := rad_to_deg(fwd.normalized().angle_to(to.normalized())) if to.length() > 0.1 else 0.0
		var bd := attack_by_id("back_drop")
		if deg > float(bd.get("behind_deg", 110.0)) and to.length() < float(bd.get("range", 5.0)):
			_behind_t += dt
		else:
			_behind_t = maxf(0.0, _behind_t - dt * 2.0)
		if not bd.is_empty() and _behind_t >= float(bd.get("behind_time", 1.2)) \
				and _cooldowns.get("back_drop", 0.0) <= 0.0 and _in_phase(bd):
			_behind_t = 0.0
			_begin_attack(bd)
			return
	super._st_combat(dt)

func _in_phase(a: Dictionary) -> bool:
	return not a.has("phases") or phase in a["phases"] or float(phase) in a["phases"]

## The last turf is for when the Bearer stands off, and only near the door.
func _attack_usable(a: Dictionary) -> bool:
	if String(a.get("type", "")) == "hold":
		var d := global_position - door_point()
		d.y = 0
		return d.length() <= float(_d("guard_r", 7.0)) + 0.5
	return true

func _begin_attack(a: Dictionary) -> void:
	super._begin_attack(a)
	if String(a.get("type", "")) == "hold":
		_turn_from = vis.rotation.y

func _st_attack(dt: float) -> void:
	if String(_atk.get("type", "")) == "hold":
		# he turns his back on the Bearer, to the door, and kneels
		velocity.x = move_toward(velocity.x, 0, 12 * dt)
		velocity.z = move_toward(velocity.z, 0, 12 * dt)
		_face(door_point() - global_position, dt, 1.5)
		var w := float(_atk.get("windup", 2.0)) / _speed_mult()
		if state_t >= w:
			_strike()
		return
	super._st_attack(dt)

func _strike() -> void:
	match String(_atk.get("type", "melee")):
		"hold": _enter_hold()
		_: super._strike()

## The sod is lifted to the gap and held there. He is open. If the Bearer does
## nothing for `quiet` seconds he lowers it to his chest and stands.
func _enter_hold() -> void:
	_hold_quiet = 0.0
	_set_state(ES.HOLD)
	vis.play("last_turf_hold", 0.3)
	sod_at = "held"
	var l := vis.bone_xform("mixamorig_LeftHand").origin
	var r := vis.bone_xform("mixamorig_RightHand").origin
	_set_sod_down((l + r) * 0.5 + Vector3.UP * 0.15, door_point() - global_position, false)

func _st_hold(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_hold_quiet += dt
	if fmod(state_t, 2.0) < dt:
		breath_puff("held", 1.8)
	if _hold_quiet >= float(attack_by_id("last_turf").get("quiet", 5.0)):
		sod_at = "chest"
		_set_state(ES.COMBAT)
		vis.idle(0.6)

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	if not released:
		_sync_sod()

## A chop is parryable on the blade (LOWE.md 6): the parry opens him up as
## it would a lesser foe; everything else he shrugs off like any holdfast.
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
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	if vis.rig != null:
		vis.rig.set_carry("")
	# he kneels at the door and lays the sod in the doorway
	vis.rotation.y = atan2(-(door_point() - global_position).x, -(door_point() - global_position).z)
	vis.play("lay_turf", 0.5)
	sod_at = "door"
	var tw := create_tween()
	var lay := door_point().lerp(global_position, 0.25)
	lay.y = _ground_y(lay) + float(_d("door_sill", 0.4))
	tw.tween_interval(1.0)
	tw.tween_property(sod, "global_position", lay, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Game.add_warmth(int(cfg.get("warmth", 10)))
	for r in ridges + walls:
		if is_instance_valid(r):
			(r as IceRidge).shatter()
	ridges.clear()
	walls.clear()
	died.emit(self)
	_release_flow.call_deferred()

## Flag, card, the tally-stick and the Open Barrow hearth are
## Game.on_boss_slain's, from his data; the frost veil calls it. With no
## veil to call it (a sandbox), he does.
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
