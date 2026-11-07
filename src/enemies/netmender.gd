class_name Netmender
extends Enemy
## The Holdfast of Saltfell (SLICE.md 6): Gunna, mending, with Brede bound in
## the net on her back. Three phases by HP (data "phase_at": 100-60, 60-25,
## 25-0), each with its own repertoire (attack "phases"), every timing in
## enemies.json, every move behind a body tell and, where it covers ground, a
## floor telegraph over the exact area it hits.
##
##   intro      sits mending; wakes when the Bearer is within wake_dist or
##              strikes her: ties off the knot, bites the twine, stands; the
##              bar appears.
##   phase 1    Needle stitch (3 stabs, parryable), Cast (net fan: snare and
##              haul into a stitch), Turn away (Bearer behind her too long:
##              a 360 sweep), Knot (a line of ice-knots that leaves a ridge).
##   -> 2       she hauls the floor-net: the floor slides 2 m toward her, the
##              tables and benches at the walls slam over.
##   phase 2    Haul, Sea-weight (10 x 4 m), Mend the floor; the stitch gains
##              a fourth stab.
##   -> 3       her hand goes through the net at her back to hold his; she
##              fights one-handed, slower, and never turns her back.
##   phase 3    One-hand stitch, Last cast (10 m, over the shoulder), Hold
##              (open; resumes after 6 quiet seconds).
##   release    she sits back down; the veil falls as meltwater; the title
##              card; the Long Hearth becomes a Hearthstone; the Mending
##              Needle lies where she sat.

signal phase_changed(new_phase: int)
signal released_boss

var stood := false
var released := false
var ridges: Array = []
var net_floor: NetFloor = null
var snare: GrabHold = null
var _behind_t := 0.0
var _queued := ""
var _trans := ""
var _trans_events: Array = []
var _hold_quiet := 0.0
var _haul_t := -1.0
var _haul_dir := Vector3.ZERO
var _haul_speed := 0.0
var _haul_target: Node3D = null
var _spin_from := 0.0
var _sheet: MeshInstance3D = null
var _engaged_by_veil := false

func _ready() -> void:
	super._ready()
	vis.play("sit_mend", 0.0)
	_find_floor.call_deferred()

func _find_floor() -> void:
	for n in get_tree().get_nodes_in_group("net_floor"):
		net_floor = n
		return

# ---------------------------------------------------------------- data
func phase_at() -> Array:
	return cfg.get("phase_at", [0.6, 0.25])

func _d(key: String, def = null):
	return cfg.get(key, def)

## Which attacks this phase may use (by id), for tests and the HUD.
func repertoire() -> Array:
	var out := []
	for a in cfg.get("attacks", []):
		if not a.has("phases") or phase in a["phases"] or float(phase) in a["phases"]:
			out.append(String(a["id"]))
	return out

# ---------------------------------------------------------------- intro
## The frost veil was parted: she knows the Bearer is there and keeps mending.
func engage_from_veil(p: Node3D) -> void:
	target = p
	_engaged_by_veil = true

func _st_idle(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 8 * dt)
	velocity.z = move_toward(velocity.z, 0, 8 * dt)
	var p := _player()
	if p == null or p.get("dead"):
		return
	if global_position.distance_to(p.global_position) <= float(_d("wake_dist", 4.0)):
		target = p
		_wake()

func _wake() -> void:
	if stood or state == ES.TRANSITION:
		return
	_begin_transition("wake")

func take_hit(packet: DamagePacket) -> void:
	if is_invulnerable():
		return   # (scripted damage too, not only the hurtbox path)
	if state == ES.HOLD:
		_hold_quiet = 0.0   # she stays curled while the Bearer keeps at it
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
		# a single blow cannot skip the hauling: phase 3 waits its turn
		hp = maxf(hp, max_hp * float(at[1]) + 1.0)
		_begin_transition("p2")
	elif phase == 2 and f <= float(at[1]):
		phase = 3
		_begin_transition("p3")

## Poise breaks do not interrupt a phase change or the hold.
func _stagger(mult := 1.0) -> void:
	if state == ES.TRANSITION or state == ES.HOLD or not stood:
		poise = float(cfg.get("poise", 30))
		return
	super._stagger(mult)

# ---------------------------------------------------------------- transitions
func _begin_transition(kind: String) -> void:
	_end_all_swings()
	if snare != null:
		snare.end(false)
	_queued = ""
	_haul_t = -1.0
	_trans = kind
	var tc: Dictionary = (cfg.get("transitions", {}) as Dictionary).get(kind, {})
	_trans_events = (tc.get("events", []) as Array).duplicate()
	_set_state(ES.TRANSITION)
	vis.play(String(tc.get("anim", "idle")), 0.25)
	if kind != "wake":
		phase_changed.emit(phase)
		Juice.shake(0.5, 0.5)
		AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 1.0, 0.8)
		if net_floor != null:
			net_floor.pulse(1.0, 1.6)

func _transition_time() -> float:
	return float(((cfg.get("transitions", {}) as Dictionary).get(_trans, {}) as Dictionary).get("time", 2.0))

func _st_transition(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 12 * dt)
	velocity.z = move_toward(velocity.z, 0, 12 * dt)
	while not _trans_events.is_empty() and state_t >= float(_trans_events[0][0]):
		var ev: Array = _trans_events.pop_front()
		_transition_event(String(ev[1]))
	if state_t >= _transition_time():
		if _trans == "wake":
			_stand_done()
		_set_state(ES.COMBAT)
		vis.idle(0.3)

func _transition_event(ev: String) -> void:
	match ev:
		"bite":   # ties off the knot, cuts it with her teeth: heard, not seen
			AudioDirector.sfx_at("res://assets/audio/parry.wav", global_position, -10.0, 0.45)
		"haul_floor":
			_haul_floor(float(_d("floor_slide", 2.0)))
		"slam_tables":
			_slam_furniture()
		"hold_hand":
			if vis.rig != null:
				vis.rig.set_carry("left_behind", ["mixamorig_LeftShoulder", "mixamorig_LeftArm",
						"mixamorig_LeftForeArm", "mixamorig_LeftHand"], true)
			breath_puff("held", 1.6)

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

## Phase two begins: the whole floor-net is dragged toward her, and the
## Bearer with it (if he stands on it).
func _haul_floor(dist: float) -> void:
	var p := _player()
	var dir := Vector3(0, 0, 1)
	if p != null:
		dir = global_position - p.global_position
		dir.y = 0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	if net_floor != null:
		var axis := net_floor.global_transform.basis.z
		axis = axis if axis.dot(dir) > 0 else -axis
		net_floor.slide(axis, dist, 0.6)
		dir = axis
	if p != null and (net_floor == null or net_floor.covers(p.global_position)):
		_start_pull(p, dir, dist, 0.6)
	Juice.shake(0.6, 0.6)

## The tables and benches dragged to the walls slam over.
func _slam_furniture() -> void:
	var area: Node = Game.current_area if Game.current_area != null else get_parent()
	for n in area.find_children("*", "Node3D", true, false):
		var k := String(n.get_meta("kit_id", ""))
		if not (k in ["table_3m", "bench_3m"]):
			continue
		var nd := n as Node3D
		if not nd.is_visible_in_tree():
			continue
		if net_floor != null and not net_floor.covers(nd.global_position + Vector3.UP * 0.2):
			continue
		var tw := nd.create_tween()
		tw.tween_property(nd, "rotation:z", nd.rotation.z + deg_to_rad(88.0 * (1.0 if randf() < 0.5 else -1.0)), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, 0.0, 0.6)

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
		_face(to, dt, 2.6)   # she will not turn her back at all
	elif stood:
		var fwd := -vis.global_transform.basis.z
		fwd.y = 0
		var deg := rad_to_deg(fwd.normalized().angle_to(to.normalized())) if to.length() > 0.1 else 0.0
		var ta := attack_by_id("turn_away")
		if deg > float(ta.get("behind_deg", 110.0)):
			_behind_t += dt
		else:
			_behind_t = maxf(0.0, _behind_t - dt * 2.0)
		if _behind_t >= float(ta.get("behind_time", 1.5)) and _cooldowns.get("turn_away", 0.0) <= 0.0 \
				and not ta.is_empty() and _attack_allowed_ignoring_pick(ta):
			_behind_t = 0.0
			_spin_from = vis.rotation.y
			_begin_attack(ta)
			return
	if _queued != "":
		var q := attack_by_id(_queued)
		_queued = ""
		if not q.is_empty() and to.length() <= float(q.get("range", 3.0)) + 0.6:
			_begin_attack(q)
			return
	super._st_combat(dt)

func _attack_allowed_ignoring_pick(a: Dictionary) -> bool:
	return not a.has("phases") or phase in a["phases"] or float(phase) in a["phases"]

func _attack_usable(a: Dictionary) -> bool:
	if String(a.get("type", "")) == "mend":
		return _live_ridges() > 0
	return true

func _live_ridges() -> int:
	ridges = ridges.filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())
	return ridges.size()

func _on_ridge(r: IceRidge) -> void:
	ridges.append(r)

func _begin_attack(a: Dictionary) -> void:
	super._begin_attack(a)
	if String(a.get("id", "")) == "turn_away":
		_spin_from = vis.rotation.y
	if String(a.get("id", "")) == "sea_weight":
		_raise_sheet()

func _st_attack(dt: float) -> void:
	super._st_attack(dt)
	if state != ES.ATTACK:
		return
	var w := float(_atk.get("windup", 0.5)) / _speed_mult()
	var act := float(_atk.get("active", 0.2)) / _speed_mult()
	match String(_atk.get("id", "")):
		"turn_away":
			# she turns her back (Brede's mask swings into view), then spins
			var t := state_t
			if t < w:
				vis.rotation.y = _spin_from + PI * smoothstep(0.0, 1.0, t / w)
			elif t < w + act:
				vis.rotation.y = _spin_from + PI + TAU * (t - w) / act
			else:
				vis.rotation.y = _spin_from + PI + TAU
		"sea_weight":
			_track_sheet()

func _strike() -> void:
	match String(_atk.get("type", "melee")):
		"mend": _mend_floor()
		"hold": _enter_hold()
		_: super._strike()
	if String(_atk.get("id", "")) == "sea_weight":
		_drop_sheet()

func _attack_finished() -> void:
	if String(_atk.get("id", "")) == "turn_away":
		vis.rotation.y = _spin_from   # she faces as she did before the spin
	super._attack_finished()

## A stitch is parryable (SLICE.md 6): the parry opens her up as it would a
## lesser foe; everything else she shrugs off like any holdfast.
func on_parried(host) -> void:
	if state == ES.ATTACK and _atk.get("parry_stagger", false):
		_end_all_swings()
		var p := _player()
		if p != null and p.has_method("on_parry_success"):
			p.on_parry_success(self)
		_stagger(float(_d("parry_stagger_mult", 1.8)))
		return
	super.on_parried(host)

# ---------------------------------------------------------------- the net
## Cast / Last cast: the net flies in a fan. Rolling sideways out of the fan
## (or through it, i-frames) escapes; a catch snares the Bearer (rooted, mash
## to break), and if he does not break it she hauls him in to stitch range.
func _net_cast() -> void:
	var rng := float(_atk.get("net_range", _atk.get("range", 8.0)))
	var fan := float(_atk.get("fan_deg", 60.0))
	_net_vfx(rng, fan)
	var p := _player()
	if p == null or p.get("dead"):
		return
	var to := p.global_position - global_position
	to.y = 0
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	if to.length() > rng or rad_to_deg(fwd.angle_to(to.normalized())) > fan * 0.5:
		return
	if p.has_method("is_invulnerable") and p.is_invulnerable():
		return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0,
			p.global_position + Vector3.UP * 1.0, RH.M_WORLD_ALL)
	q.exclude = [self]
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	snare = GrabHold.start(self, p, float(_atk.get("snare", 1.5)), int(_atk.get("mash", 5)))
	snare.released.connect(_on_snare_released.bind(p, float(_atk.get("haul_to", 2.2)), String(_atk.get("then", ""))))
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", p.global_position, -4.0, 0.7)

func _on_snare_released(broken: bool, p: Node3D, haul_to: float, then: String) -> void:
	snare = null
	if broken or dead or released or not is_instance_valid(p) or p.get("dead"):
		return
	var to := global_position - p.global_position
	to.y = 0
	var d := to.length() - haul_to
	if d > 0.1:
		_start_pull(p, to.normalized(), d, 0.45)
	_queued = then

## Pull the Bearer `dist` along `dir` over `secs` (a body pushed through the
## world: walls and ridges still stop him).
func _start_pull(p: Node3D, dir: Vector3, dist: float, secs: float) -> void:
	_haul_target = p
	_haul_dir = dir
	_haul_speed = dist / maxf(secs, 0.05)
	_haul_t = secs

## Haul: the floor-net drags everything toward her (3 m over the active
## window). The Bearer can sprint against it to hold his ground.
func _haul() -> void:
	var p := _player()
	if p == null:
		return
	var dir := global_position - p.global_position
	dir.y = 0
	dir = dir.normalized()
	var dist := float(_atk.get("pull", 3.0))
	var secs := float(_atk.get("pull_time", 0.8))
	if net_floor != null:
		net_floor.slide(dir, dist, secs)
	if net_floor == null or net_floor.covers(p.global_position):
		_start_pull(p, dir, dist, secs)
	AudioDirector.sfx_at("res://assets/audio/whoosh_l.wav", global_position, -2.0, 0.5)
	_queued = String(_atk.get("then", ""))

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	if _haul_t > 0.0 and _haul_target != null and is_instance_valid(_haul_target):
		_haul_t -= dt
		var body := _haul_target as CharacterBody3D
		if body != null:
			body.move_and_collide(_haul_dir * _haul_speed * dt)
		if _haul_t <= 0.0:
			_haul_target = null

func _net_vfx(rng: float, fan: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = FloorTelegraph._shape_mesh("fan", [rng, fan])
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/net_floor.gdshader")
	m.set_shader_parameter("rope", 0.05)
	m.set_shader_parameter("cell", 0.5)
	m.set_shader_parameter("pulse", 0.6)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	mi.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), global_position + Vector3.UP * 0.35)
	mi.scale = Vector3(0.1, 1, 0.1)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position:y", mi.position.y - 0.3, 0.6)
	tw.tween_callback(mi.queue_free)

# ---------------------------------------------------------------- sea-weight
## The net train lifted over her head like a sail (Brede's figure shows as
## she rises to full height), then brought down over the 10 x 4 m rectangle.
func _raise_sheet() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4.0, 3.2)
	pm.orientation = PlaneMesh.FACE_Z
	_sheet.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/net_floor.gdshader")
	m.set_shader_parameter("cell", 0.4)
	m.set_shader_parameter("rope", 0.045)
	_sheet.material_override = m
	_sheet.top_level = true
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	vis.add_child(_sheet)
	_sheet.scale = Vector3(0.2, 0.2, 0.2)
	_track_sheet()

func _track_sheet() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		return
	var w := float(_atk.get("windup", 1.6)) / _speed_mult()
	var k := clampf(state_t / maxf(w * 0.7, 0.01), 0.0, 1.0)
	var mid := (vis.bone_xform("mixamorig_LeftHand").origin + vis.bone_xform("mixamorig_RightHand").origin) * 0.5
	var fwd := -vis.global_transform.basis.z
	fwd.y = 0
	_sheet.global_transform = Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP).scaled(Vector3.ONE * lerpf(0.2, 1.0, k)),
			mid + Vector3.UP * 1.0 * k - fwd.normalized() * 0.3)

func _drop_sheet() -> void:
	if _sheet == null or not is_instance_valid(_sheet):
		return
	var s := _sheet
	_sheet = null
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var length := float(_atk.get("length", 10.0))
	var land := Transform3D(Basis.looking_at(Vector3.DOWN, fwd).scaled(Vector3(1.0, length / 3.2, 1.0)),
			global_position + fwd * (float(_atk.get("offset", 0.5)) + length * 0.5) + Vector3.UP * 0.12)
	var tw := s.create_tween()
	tw.tween_property(s, "global_transform", land, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(float(_atk.get("recover", 2.0)) * 0.6)
	tw.tween_callback(s.queue_free)

# ---------------------------------------------------------------- mend / hold
func _mend_floor() -> void:
	var ext := float(_atk.get("extend", 8.0))
	for r in ridges:
		if is_instance_valid(r):
			(r as IceRidge).refreeze(ext)
	if net_floor != null:
		net_floor.pulse(0.6, 0.8)
	AudioDirector.sfx_at("res://assets/audio/horn_low.wav", global_position, -6.0, 1.8)

## Hold: she curls around him and does not fight. She is open. If the Bearer
## does nothing for hold_quiet seconds she stands and goes on.
func _enter_hold() -> void:
	_hold_quiet = 0.0
	_set_state(ES.HOLD)

func _st_hold(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	_hold_quiet += dt
	if fmod(state_t, 2.2) < dt:
		breath_puff("held", 2.0)   # the breath slows
	if _hold_quiet >= float(attack_by_id("hold").get("quiet", 6.0)):
		_set_state(ES.COMBAT)
		vis.idle(0.6)

# ---------------------------------------------------------------- release
func _die() -> void:
	if released:
		return
	released = true
	dead = true
	_set_state(ES.DEAD)
	_end_all_swings()
	if snare != null:
		snare.end(false)
	_haul_t = -1.0
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	if vis.rig != null:
		vis.rig.set_carry("")
	vis.play("sit_still", 0.5)   # she sits back down
	Game.add_warmth(int(cfg.get("warmth", 10)))
	for ridge in ridges:
		if is_instance_valid(ridge):
			(ridge as IceRidge).shatter()
	died.emit(self)
	_release_flow.call_deferred()

func _release_flow() -> void:
	var rel: Dictionary = cfg.get("release", {})
	World.set_flag(String(rel.get("flag", "ks_netmender_released")))
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("hide_boss"):
			hud.hide_boss()
		if hud.has_method("show_area_title"):
			hud.show_area_title(String(rel.get("title", "THE NETMENDER — RELEASED")), "release")
	if net_floor != null:
		net_floor.pulse(0.8, 3.0)
	_drop_needle(rel)
	_light_long_hearth(rel)
	released_boss.emit()

## The Mending Needle lies where she sat.
func _drop_needle(rel: Dictionary) -> void:
	var k := Pickup.new()
	k.pickup_id = String(rel.get("pickup_id", "mending_needle"))
	k.area_id = Game.current_area_id
	k.item_id = String(rel.get("drop", "item_mending_needle"))
	k.item_count = 1
	k.label = String(rel.get("drop_label", "Take the mending needle"))
	k.display_scene = String(rel.get("drop_scene", ""))
	var home_node: Node = Game.current_area.base if Game.current_area != null else get_parent()
	home_node.add_child(k)
	var fwd := -vis.global_transform.basis.z
	fwd.y = 0
	k.global_position = global_position + fwd.normalized() * float(rel.get("drop_ahead", 1.2))

## The long hearth catches from the Bearer's horn: it is a Hearthstone now.
## The spec is the area's own (hearths entry with require_flag), so a rebuilt
## area keeps it.
func _light_long_hearth(rel: Dictionary) -> void:
	var hid := String(rel.get("hearth", ""))
	if hid == "" or Game.current_area == null or Game.find_hearth(hid) != null:
		return
	var def: Dictionary = Game.current_area.get_meta("def", {})
	for spec in def.get("hearths", []):
		if String(spec.get("id", "")) != hid:
			continue
		var h := Hearthstone.new()
		h.hearth_id = hid
		h.display_name = String(spec.get("name", "Hearthstone"))
		h.area = Game.current_area
		Game.current_area.base.add_child(h)
		h.position = Vector3(spec["at"][0], spec["at"][1], spec["at"][2])
		h.rotation.y = deg_to_rad(float(spec.get("rot", 0)))
		AudioDirector.sfx_at("res://assets/audio/swell_warm.wav", h.global_position, -2.0)

## She stays where she sat; no dissolve.
func _fade_out() -> void:
	pass
