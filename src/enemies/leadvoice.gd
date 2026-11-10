class_name Leadvoice
extends Enemy
## The last Holdfast (COLDWELL.md 6): Maren of Saltfell, the Leadvoice, sat
## at the wellhead with Wren against her chest. She has no strike. Nothing in
## this script or its data opens a hand volume: she holds notes that freeze
## the air, she folds down over the child when the Bearer comes too near, and
## the unsung dead stand up between them. Three phases by HP (data
## "phase_at"); every timing in enemies.json; every move that covers ground
## behind a floor telegraph.
##
##   intro      sat, bent over the child; lifts her head when the Bearer is
##              within wake_dist or strikes her.
##   phase 1    Held note (a strip of air freezes and stands: IceRidge),
##              Shelter (the cold off her back puts the Bearer out of reach),
##              Not yet (she breathes in to begin and does not: two Unsung).
##   -> 2       her head comes right up.
##   phase 2    Long note (a band all the way round; close to her there is
##              nothing), Come up (an Upwalker in through the gap).
##   -> 3       she stands up, for the first time.
##   phase 3    a blade no longer counts (p3_blade). Within sing_r the Bearer
##              may sing (an Interactable on her, "Sing"): verse_time seconds
##              open, broken by any blow. Each verse takes a third of what is
##              left, breaks the Unsung near, and she bows her head a moment.
##   release    after the last verse she sits down again. The band and the
##              mask are set down in front of her (release_drop,
##              release_drop2). No Outsong plays here (release_outsong
##              false): that one is the Bearer's to sing, or not.

signal phase_changed(new_phase: int)
signal released_boss
signal verse_begun
signal verse_sung(n: int)
signal verse_broken

var stood := false             # woken (the bar is up)
var standing := false          # on her feet (phase 3)
var released := false
var verses_sung := 0
var singing := false
var sing_zone: Interactable
var _trans := ""
var _trans_events: Array = []
var _engaged_by_veil := false
var _verse_t := 0.0
var _verse_hp := 0.0
var _singer: Node = null
var _p3_hp := 0.0
var _bow_t := 0.0

func _ready() -> void:
	super._ready()
	_sit(0.0)
	sing_zone = Interactable.new()
	sing_zone.prompt = "Sing"
	sing_zone.setup_zone(float(_d("sing_r", 4.4)), 2.4)
	sing_zone.enabled = false
	sing_zone.activated.connect(begin_verse)
	add_child(sing_zone)

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

## Sat: her own rising clip held at its first frame.
func _sit(blend := 0.6) -> void:
	_sat_note = ""
	vis.play(String(_d("seat_clip", "rise")), blend, 0.0)

func is_seated_pose() -> bool:
	return not standing and (vis.current_clip() == String(_d("seat_clip", "rise")) or _sat_note != "" and vis.current_clip() == _sat_note)

## The clip of the note she is holding sat down ("" between notes): her
## seated beats (clip set "@sit_<attack>", keyed on her seated stance).
var _sat_note := ""

## A voice does not need to see who it is for.
func _los_clear() -> bool:
	return true

# ---------------------------------------------------------------- intro
func engage_from_veil(p: Node3D) -> void:
	target = p
	_engaged_by_veil = true

func _st_idle(_dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	var p := _player()
	if p == null or p.get("dead"):
		return
	if global_position.distance_to(p.global_position) <= float(_d("wake_dist", 10.0)):
		target = p
		_wake()

func _wake() -> void:
	if stood or state == ES.TRANSITION:
		return
	_begin_transition("wake")

func is_invulnerable() -> bool:
	return dead or released or state == ES.TRANSITION

func take_hit(packet: DamagePacket) -> void:
	if is_invulnerable():
		return
	var was_up := stood
	if phase == 3:
		# on her feet, a blade is nothing to her: only the verses count
		var keep := hp
		packet.amount *= float(_d("p3_blade", 0.0))
		super.take_hit(packet)
		if not dead:
			hp = maxf(minf(hp, keep), 1.0)
		return
	super.take_hit(packet)
	if not was_up and not dead and state != ES.TRANSITION:
		if packet.source != null and packet.source.is_in_group("player"):
			target = packet.source
		_wake()

func _check_phase() -> void:
	if dead:
		return
	var f := hp / max_hp
	var at := phase_at()
	if phase == 1 and f <= float(at[0]):
		phase = 2
		hp = maxf(hp, max_hp * float(at[1]) + 1.0)
		_begin_transition("p2")
	elif phase == 2 and f <= float(at[1]):
		phase = 3
		hp = max_hp * float(at[1])   # what is left is sung, in thirds
		_p3_hp = hp
		_begin_transition("p3")

## Nothing staggers her; she is not fighting.
func _stagger(_mult := 1.0) -> void:
	poise = float(cfg.get("poise", 9999))

## The last of her is not struck off: in phase 3 only a verse can end it.
func _die() -> void:
	if phase < 3 or verses_sung < int(_d("verses", 3)):
		hp = 1.0
		_check_phase()
		return
	_release()

# ---------------------------------------------------------------- transitions
func _begin_transition(kind: String) -> void:
	_end_all_swings()
	_then_atk = ""
	_trans = kind
	var tc: Dictionary = (cfg.get("transitions", {}) as Dictionary).get(kind, {})
	_trans_events = (tc.get("events", []) as Array).duplicate()
	_set_state(ES.TRANSITION)
	var an := String(tc.get("anim", ""))
	if an != "":
		# (her rising clip, played through once over the length of the turn)
		vis.play_timed(an, float(tc.get("time", 4.0)) * 0.65, 0.3)
	else:
		vis.play(String(_d("seat_clip", "rise")), 0.6, float(_d("seat_lift", 0.1)))
	if kind != "wake":
		phase_changed.emit(phase)

func _transition_time() -> float:
	return float(((cfg.get("transitions", {}) as Dictionary).get(_trans, {}) as Dictionary).get("time", 2.0))

func _st_transition(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	while not _trans_events.is_empty() and state_t >= float(_trans_events[0][0]):
		var ev: Array = _trans_events.pop_front()
		_transition_event(String(ev[1]))
	if target != null and is_instance_valid(target):
		_face(target.global_position - global_position, dt, 0.6)
	if state_t >= _transition_time():
		if _trans == "wake":
			_stand_done()
		_set_state(ES.COMBAT)
		if standing:
			vis.idle(0.4)
		else:
			_sit()

func _transition_event(ev: String) -> void:
	match ev:
		"unsung":
			raise_dead("unsung", 2, 3, false)
		"stood":
			standing = true
			sing_zone.enabled = true
			Juice.shake(0.3, 0.5)

func _stand_done() -> void:
	stood = true
	var p := _player()
	if target == null and p != null:
		target = p
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("show_boss"):
			hud.show_boss(self)
	if bool(_d("boss_music", true)):
		AudioDirector.boss_theme(id, 2.5)
	else:
		AudioDirector.play_music("", 3.0)   # nothing plays: nobody has started

# ---------------------------------------------------------------- the dead
func dead_up(enemy_id := "") -> Array:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	return _minions.filter(func(m): return enemy_id == "" or (m as Enemy).id == enemy_id)

## The gap in the stones, from where she sits: the way she faces at rest.
func gap_dir() -> Vector3:
	var a := deg_to_rad(float(_d("gap_face_deg", rad_to_deg(_home_yaw))))
	return Vector3(-sin(a), 0, -cos(a))

var _home_yaw := 0.0

## They stand up between her and the Bearer (or come in through the gap),
## already turned to him: in the way.
func raise_dead(enemy_id: String, n: int, cap: int, from_gap: bool) -> int:
	var placed := 0
	var tp: Vector3 = target.global_position if _target_valid() else global_position + gap_dir() * 8.0
	var to := tp - global_position
	to.y = 0.0
	var d := to.length()
	var dir := to.normalized() if d > 0.2 else gap_dir()
	var side := dir.cross(Vector3.UP)
	for i in n:
		if dead_up(enemy_id).size() >= cap:
			break
		var e := Enemy.new()
		e.setup(enemy_id)
		get_parent().add_child(e)
		var at: Vector3
		if from_gap:
			at = global_position + gap_dir() * (float(_d("summon_ring", 6.5)) + 6.0)
		else:
			var mid := clampf(d * 0.5, 3.0, float(_d("summon_ring", 6.5)))
			at = global_position + dir * mid + side * (float(i) - float(n - 1) * 0.5) * 2.2
		at = _open_ground(at, side)
		e.global_position = Vector3(at.x, global_position.y + 0.3, at.z)
		e.home = e.global_position
		e.vis.rotation.y = atan2(-dir.x, -dir.z)
		e.target = target
		e._set_state(ES.ALERT)
		_minions.append(e)
		placed += 1
		FrostDissolve.shards(get_parent(), e.global_position, 1.2)
	return placed

## Nobody stands up inside the well-housing or a stone: try the place, then
## either side of it, wider each time.
func _open_ground(at: Vector3, side: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var probe := SphereShape3D.new()
	probe.radius = 0.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = probe
	q.collision_mask = RH.M_WORLD_ALL
	for off in [0.0, 2.6, -2.6, 4.4, -4.4, 6.0, -6.0]:
		var c: Vector3 = at + side * float(off)
		q.transform = Transform3D(Basis(), Vector3(c.x, global_position.y + 1.1, c.z))
		if space.intersect_shape(q, 1).is_empty():
			return c
	return at

# ---------------------------------------------------------------- combat
func _st_extra(dt: float) -> void:
	match state:
		ES.TRANSITION: _st_transition(dt)
		ES.HOLD: _st_bow(dt)
		_: super._st_extra(dt)

func _physics_process(dt: float) -> void:
	if _home_yaw == 0.0 and state == ES.IDLE:
		_home_yaw = vis.rotation.y
	super._physics_process(dt)
	if dead and not released:
		return
	velocity.x = 0
	velocity.z = 0
	# she stays sat between notes (the base rig would stand her up to idle)
	if not standing and (state == ES.IDLE or state == ES.COMBAT or state == ES.APPROACH or state == ES.ALERT) \
			and vis.current_clip() != String(_d("seat_clip", "rise")):
		_sit()
	if singing:
		_tick_verse(dt)

func _attack_usable(a: Dictionary) -> bool:
	if singing:
		return false   # she listens
	if String(a.get("type", "")) == "summon":
		return dead_up(String(a.get("enemy", "unsung"))).size() < int(a.get("below", a.get("max_alive", 2)))
	return true

func _begin_attack(a: Dictionary) -> void:
	super._begin_attack(a)
	_sat_note = ""
	if not standing:
		# sat: only her head and shoulders come up for it. Her own seated
		# beat for this note where the library has one, landing on the
		# windup; else the seat clip, lifted a little.
		var beat := "@sit_" + String(a.get("id", ""))
		if vis.rig != null and vis.rig.has_clip(beat):
			_sat_note = String(a.get("anim", "hold_note"))
			vis.play_timed(_sat_note, maxf(float(a.get("windup", 0.5)) / _speed_mult(), 0.05), 0.4, 0.0, INF, beat)
		else:
			vis.play(String(_d("seat_clip", "rise")), 0.4, float(_d("seat_lift", 0.1)))

func _strike() -> void:
	match String(_atk.get("type", "melee")):
		"summon":
			raise_dead(String(_atk.get("enemy", "unsung")), int(_atk.get("count", 2)), int(_atk.get("max_alive", 3)),
					bool(_atk.get("from_gap", false)))
		"line", "sweep":
			super._strike()
		_:
			pass   # she has no strike

func _attack_finished() -> void:
	_set_state(ES.COMBAT)
	if standing:
		vis.idle()
	else:
		_sit()

func on_parried(_host) -> void:
	pass

# ---------------------------------------------------------------- the verses
## The Bearer, within sing_r of her and on his feet, sings: verse_time
## seconds with his hands down. A blow breaks it.
func begin_verse(p) -> void:
	if not standing or singing or released or dead or p == null:
		return
	singing = true
	_singer = p
	_verse_t = 0.0
	_verse_hp = float(p.get("hp")) if p.get("hp") != null else 0.0
	if p.has_method("lock_control"):
		p.lock_control(true)
	if p.get("vis") != null:
		var to: Vector3 = global_position - (p as Node3D).global_position
		p.vis.rotation.y = atan2(-to.x, -to.z)
		p.vis.play("cast_self", 0.2)
	sing_zone.enabled = false
	AudioDirector.sfx(String(_d("sfx_verse", "")), -3.0, 1.0)
	verse_begun.emit()

func _tick_verse(dt: float) -> void:
	_verse_t += dt
	var p := _singer
	if p == null or not is_instance_valid(p) or p.get("dead"):
		_end_verse(false)
		return
	if float(p.get("hp")) < _verse_hp - 0.01:
		_end_verse(false)   # struck: the breath goes out of it
		return
	if _verse_t >= float(_d("verse_time", 2.4)):
		_end_verse(true)

func _end_verse(whole: bool) -> void:
	singing = false
	var p := _singer
	_singer = null
	if p != null and is_instance_valid(p) and p.has_method("lock_control") and not p.get("dead"):
		p.lock_control(false)
	if not whole:
		sing_zone.enabled = standing and not released
		verse_broken.emit()
		return
	verses_sung += 1
	var total := int(_d("verses", 3))
	hp = maxf(_p3_hp * (1.0 - float(verses_sung) / float(total)), 0.0)
	# whoever nobody sang for, and stood near enough to hear, is sung now
	var r := float(_d("verse_breaks_r", 9.0))
	for m in dead_up():
		var e := m as Enemy
		if e.id == "unsung" and e.global_position.distance_to(global_position) <= r + 6.0:
			e._die()
	verse_sung.emit(verses_sung)
	if verses_sung >= total:
		_release()
		return
	_end_all_swings()
	_bow_t = 0.0
	_set_state(ES.HOLD)
	vis.play("shelter", 0.6, 0.5)
	sing_zone.enabled = false

## After a verse she bows her head over the child and is still.
func _st_bow(dt: float) -> void:
	_bow_t += dt
	if _bow_t >= float(_d("verse_bow", 2.0)):
		_set_state(ES.COMBAT)
		vis.idle(0.6)
		sing_zone.enabled = true
		_cooldowns["shelter"] = 0.0   # and then she wants the Bearer further off

# ---------------------------------------------------------------- release
func _release() -> void:
	if released:
		return
	released = true
	dead = true
	singing = false
	standing = false
	hp = 0.0
	_set_state(ES.DEAD)
	_end_all_swings()
	sing_zone.enabled = false
	hurtbox.set_deferred("monitorable", false)
	for m in dead_up():
		(m as Enemy)._die()
	for r in get_tree().get_nodes_in_group("ice_ridges"):
		if r.has_method("shatter"):
			r.shatter()
	_sit(2.4)   # she sits down again
	died.emit(self)
	_release_flow.call_deferred()

func _release_flow() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("hide_boss"):
			hud.hide_boss()
	if not _engaged_by_veil:
		Game.on_boss_slain(Game.current_area_id, self)
	_second_drop()
	released_boss.emit()

## The mask beside the band (data "release_drop2": side metres to the right
## of the first, as the Bearer sees them).
func _second_drop() -> void:
	var drop: Dictionary = _d("release_drop2", {})
	if drop.is_empty() or not is_inside_tree():
		return
	var k := Pickup.new()
	k.pickup_id = String(drop.get("pickup_id", "release_drop2"))
	k.area_id = Game.current_area_id
	k.item_id = String(drop.get("item", ""))
	k.label = String(drop.get("label", "Take"))
	k.display_scene = String(drop.get("scene", ""))
	k.set_flag = String(drop.get("set_flag", ""))
	var holder: Node = Game.current_area.base if Game.current_area != null else get_parent()
	holder.add_child(k)
	var p := _player()
	var toward := (p.global_position - global_position) if p != null else gap_dir()
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.1 else gap_dir()
	k.global_position = global_position + toward * float(drop.get("ahead", 2.0)) \
			+ toward.cross(Vector3.UP) * float(drop.get("side", 1.3)) + Vector3.UP * 0.02

## She stays where she sat; no dissolve.
func _fade_out() -> void:
	pass
