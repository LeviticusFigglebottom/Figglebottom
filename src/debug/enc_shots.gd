class_name EncShots
extends Node
## Staged encounter screenshots (docs/screens/enc_*.png). Shot adds this node
## when the command line carries --enc-shot=<stage>; it stages the beat in the
## live area, frames a camera, freezes the tree on the beat and saves.
##   tools/shot.sh docs/screens/enc_bearer_idle.png --area=saltfell_steading \
##       --state=thaw --enc-shot=bearer_idle
## Stages: bearer_idle, bearer_roll, bearer_drink, oarsman_stroke, hound_lunge,
## netmender_p1, netmender_p2, netmender_p3, ingra_thaw, release.
## The Lowe (lowe_barrows; docs/screens/lowe_enc_*.png): lowe_sleeper, lowe_keener,
## lowe_carrier, turfwright_p1, turfwright_p2, turfwright_p3, lowe_release (RIME);
## lowe_hesk, lowe_aud (THAW).

var stage := ""
var path := ""
var _f := 0
var _foe: Node3D = null
var _cam: Camera3D
var _done := false
var _hold := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

var _clock := 0.0   # game seconds since boot (headless frames run slow)

func _process(dt: float) -> void:
	if _done:
		return
	if Engine.time_scale > 0.0:
		_clock += dt
	if _hold >= 0:
		_hold -= 1
		if _hold == 0:
			_save()
		return
	var p: Player = Game.player
	if p == null:
		return
	_f += 1
	if _f == 1:
		p.invulnerable = true
		p.sim_active = true
		p.hurtbox.monitorable = false
		_cam = Camera3D.new()
		_cam.name = "EncCam"
		get_tree().current_scene.add_child(_cam)
	if _f > 1:
		_cam.current = true
	call("_st_" + stage, p)

## Stop game time on the beat. time_scale 0 rather than a pause: paused
## skeletons stop publishing their pose to the renderer, so the photo would
## show a frame from before the beat.
func _freeze(frames := 6) -> void:
	Engine.time_scale = 0.0
	_hold = frames
	if _foe != null and is_instance_valid(_foe) and _foe is Enemy:
		var e := _foe as Enemy
		print("[shot] freeze: %s state %d atk %s t %.2f clip %s tells %d" % [e.id, e.state, e._atk.get("id", "-"),
				e.state_t, e.vis.current_clip(), get_tree().current_scene.find_children("*", "FloorTelegraph", true, false).size()])

func _save() -> void:
	_done = true
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("[shot] saved ", path)
	AudioDirector.shutdown()
	get_tree().quit()

## Camera at `eye` offset from `at` in the frame of `yaw_node` (x right, y up,
## z toward the node's face), looking at `at` + look_up.
func _frame(at: Vector3, basis_from: Node3D, eye: Vector3, look_up := 0.9, fov := 45.0) -> void:
	var b := basis_from.global_transform.basis.orthonormalized()
	var fwd := -b.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var tgt := at + Vector3.UP * look_up
	_cam.global_position = tgt + right * eye.x + Vector3.UP * eye.y + fwd * eye.z
	_cam.look_at(tgt, Vector3.UP)
	_cam.fov = fov

func _place_player(p: Player, pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.vis.rotation.y = yaw
	p.cam.yaw = yaw

func _ground(x: float, z: float, from_y := 120.0) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y, z), Vector3(x, -50, z), RH.M_WORLD_ALL)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else Vector3(x, 0, z)

# ------------------------------------------------------------------ the Bearer
func _bearer_spot(p: Player) -> void:
	if _f == 2:
		# the Strand below the boat-shed (or the arena sandbox floor)
		var at := _ground(-6.0, 57.0) if Game.current_area != null else Vector3(0, 0, 4)
		_place_player(p, at + Vector3.UP * 0.1, deg_to_rad(200))

func _st_bearer_idle(p: Player) -> void:
	_bearer_spot(p)
	if _f > 2:
		_frame(p.global_position, p.vis, Vector3(-1.0, 0.25, 2.6), 0.95, 42.0)
	if _f == 70:
		_freeze()

func _st_bearer_roll(p: Player) -> void:
	_bearer_spot(p)
	if _f > 2:
		_frame(p.global_position, p.vis, Vector3(-3.2, 0.3, 0.6), 0.6, 45.0)
	if _f == 60:
		p.stamina = p.max_stamina
		p._try_roll(-p.vis.global_transform.basis.z)
	if _f > 60 and p.state == Player.S.ROLL and p.state_t >= 0.2:
		_freeze()

func _st_bearer_drink(p: Player) -> void:
	_bearer_spot(p)
	if _f > 2:
		_frame(p.global_position, p.vis, Vector3(-1.3, 0.2, 2.4), 1.2, 40.0)
	if _f == 60:
		p.hp = p.max_hp * 0.5
		p.try_gourd()
	if _f > 60 and p.state == Player.S.GOURD and p.state_t >= 0.62:
		_freeze()

# ------------------------------------------------------------------ villagers
func _find_npc(id: String) -> NPC:
	for n in get_tree().current_scene.find_children("*", "NPC", true, false):
		if (n as NPC).npc_id == id and (n as NPC).is_visible_in_tree():
			return n
	return null

func _st_ingra_thaw(p: Player) -> void:
	var ing := _find_npc("steward_ingra")
	if ing == null:
		return
	var fwd := -ing.global_transform.basis.z
	if _f == 3:
		_place_player(p, ing.global_position + fwd * 2.6 + Vector3.UP * 0.2, atan2(fwd.x, fwd.z))
	if _f > 3:
		_frame(ing.global_position, ing, Vector3(1.6, 0.25, 3.2), 0.95, 40.0)
	if _f == 50:
		ing._vis.play("greet", 0.3)
	if _f > 50 and ing._vis.rig != null and ing._vis.rig.action_time() >= 1.4:
		_freeze()

# ------------------------------------------------------------------ death
## A slain Tripo foe frosts over and shatters (FrostDissolve), captured mid-way.
var _t0 := 0.0

func _first_foe(id: String) -> Enemy:
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Enemy and (e as Enemy).id == id and not (e as Enemy).dead and (e as Enemy).can_process():
			return e
	return null

func _st_foe_dissolve(p: Player) -> void:
	if _f == 10:
		_foe = _first_foe("rimewalker")
		(_foe as Enemy)._die()
		_t0 = _clock
	if _foe != null and is_instance_valid(_foe):
		_frame(_foe.global_position, _foe, Vector3(1.6, 0.8, -3.4), 0.4, 42.0)
		if _diss_of(_foe) >= 0.45:
			_freeze()

func _diss_of(n: Node) -> float:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m = (mi as MeshInstance3D).get_surface_override_material(0)
		if m is ShaderMaterial and m.get_shader_parameter("death_diss") != null:
			return float(m.get_shader_parameter("death_diss"))
	return 0.0

# ------------------------------------------------------------------ foes
func _spawn_foe(id: String, pos: Vector3) -> Enemy:
	var ecfg: Dictionary = DB.table("enemies").get(id, {})
	var e: Enemy = load(ecfg["class"]).new() if ecfg.has("class") else Enemy.new()
	e.setup(id)
	get_tree().current_scene.add_child(e)
	e.global_position = pos
	return e

## Face-off: the foe found in the area (or spawned in the sandbox) squares up
## to the Bearer `gap` metres away; returns it once placed.
var near_hint := Vector3.INF   # pick the foe of that kind nearest this point

func _foe_near(id: String, at: Vector3) -> Enemy:
	var best: Enemy = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		var en := e as Enemy
		if en == null or en.id != id or en.dead or not en.can_process():
			continue
		if best == null or en.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = en
	return best

func _face_off(p: Player, id: String, gap: float) -> Enemy:
	if _f == 3:
		var e: Enemy = null
		if Game.current_area != null:
			e = _foe_near(id, near_hint) if near_hint != Vector3.INF else _first_foe(id)
		if e == null:
			e = _spawn_foe(id, p.global_position + Vector3(0, 0.1, -gap))
		_foe = e
	if _foe == null or not is_instance_valid(_foe):
		return null
	var e2 := _foe as Enemy
	if _f == 6:
		var fwd := -e2.vis.global_transform.basis.z
		fwd.y = 0
		_place_player(p, e2.global_position + fwd.normalized() * gap + Vector3.UP * 0.1, 0.0)
	if _f >= 6:
		var d := e2.global_position - p.global_position
		d.y = 0
		p.vis.rotation.y = atan2(-d.x, -d.z)
		if e2.state != Enemy.ES.ATTACK:
			e2.vis.rotation.y = atan2(d.x, d.z)
			e2.velocity = Vector3.ZERO
		e2.target = p
	return e2

func _side_cam(p: Player, e: Node3D, dist := 4.4, h := 0.5, look := 1.0, fov := 46.0) -> void:
	var mid := (p.global_position + e.global_position) * 0.5
	var axis := e.global_position - p.global_position
	axis.y = 0
	var side := axis.normalized().cross(Vector3.UP)
	var tgt := mid + Vector3.UP * look
	_cam.global_position = tgt + side * dist + Vector3.UP * h - axis.normalized() * 0.8
	_cam.look_at(tgt, Vector3.UP)
	_cam.fov = fov

func _st_oarsman_stroke(p: Player) -> void:
	near_hint = Vector3(9.0, 0, 76.5)   # the waterline, facing the sea
	var e := _face_off(p, "oarsman", 3.2)
	if e == null:
		return
	if _f >= 6:
		_side_cam(p, e)
	if _f == 50:
		e._begin_attack(e.attack_by_id(OS.get_environment("ENC_ATK") if OS.get_environment("ENC_ATK") != "" else "stroke"))
	if _f > 50 and e.state == Enemy.ES.ATTACK and e.state_t >= float(e._atk["windup"]) + float(OS.get_environment("ENC_DT") if OS.get_environment("ENC_DT") != "" else "0.06"):
		_freeze()

func _st_hound_lunge(p: Player) -> void:
	near_hint = Vector3(0.0, 0, -16.6)   # across the Longhouse threshold
	var e := _face_off(p, "hearthhound", 3.0)
	if e == null:
		return
	if _f == 4:
		e.set("barked", true)
	if _f >= 6:
		_side_cam(p, e, 3.6, 0.2, 0.6, 46.0)
	if _f == 50:
		e._begin_attack(e.attack_by_id(OS.get_environment("ENC_ATK") if OS.get_environment("ENC_ATK") != "" else "lunge_bite"))
	if _f > 50 and e.state == Enemy.ES.ATTACK and e.state_t >= float(e._atk["windup"]) + float(OS.get_environment("ENC_DT") if OS.get_environment("ENC_DT") != "" else "0.1"):
		_freeze()

func _st_hound_lie(p: Player) -> void:
	if _f == 3:
		_foe = _first_foe("hearthhound") if Game.current_area != null else _spawn_foe("hearthhound", p.global_position + Vector3(0, 0.1, -5.0))
		_place_player(p, p.global_position + Vector3(8, 0, 6), 0.0)   # out of its sight
	if _foe != null and _f >= 4:
		_frame(_foe.global_position, _foe.vis, Vector3(2.2, 0.6, 2.2), 0.3, 40.0)
	if _f == 60:
		_freeze()

# ------------------------------------------------------------------ the Netmender
## Wake her (the Bearer walks up behind her), set the phase, face her from
## `gap` metres, start `atk` and freeze `frac` of the way through its windup.
var _nm_phase_set := false
var _started := false

func _netmender_stage(p: Player, ph: int, atk: String, frac: float, gap := 7.0) -> void:
	if _f == 3:
		_foe = _foe_near("netmender", Vector3(0, 0, -46))
		if _foe == null:
			return
		_place_player(p, _foe.global_position + Vector3(0, 0.1, 3.4), PI)
	var nm := _foe as Netmender
	if nm == null:
		return
	if not nm.stood:
		_frame(nm.global_position, p.vis, Vector3(1.6, 1.6, -3.0), 1.6, 50.0)
		return
	if not _nm_phase_set:
		_nm_phase_set = true
		_t0 = _clock
		nm.phase = ph
		if ph >= 2:
			nm.hp = nm.max_hp * 0.5
			nm._haul_floor(2.0)
			nm._slam_furniture()
		if ph >= 3:
			nm.hp = nm.max_hp * 0.2
			nm.vis.rig.set_carry("left_behind", ["mixamorig_LeftShoulder", "mixamorig_LeftArm",
					"mixamorig_LeftForeArm", "mixamorig_LeftHand"], true)
		nm.vis.rotation.y = PI   # turned to face the door, and the Bearer
		var fwd := -nm.vis.global_transform.basis.z
		_place_player(p, nm.global_position + fwd * gap + Vector3.UP * 0.1, 0.0)
	var to := nm.global_position - p.global_position
	p.vis.rotation.y = atan2(-to.x, -to.z)
	var back := -to
	back.y = 0
	back = back.normalized()
	var right := back.cross(Vector3.UP)
	_cam.global_position = p.global_position + back * 3.4 - right * 1.5 + Vector3.UP * 2.3
	_cam.look_at(nm.global_position + Vector3.UP * 1.7, Vector3.UP)
	_cam.fov = 52.0
	if not _started and _clock - _t0 > 0.6:
		_started = true
		nm._cooldowns.clear()
		nm._begin_attack(nm.attack_by_id(atk))
	if _started and nm.state == Enemy.ES.ATTACK and String(nm._atk.get("id", "")) == atk \
			and nm.state_t >= float(nm._atk["windup"]) / nm._speed_mult() * frac:
		_freeze()

func _st_netmender_p1(p: Player) -> void:
	_netmender_stage(p, 1, "knot", 0.85, 7.0)

func _st_netmender_p2(p: Player) -> void:
	_netmender_stage(p, 2, "sea_weight", 0.8, 7.5)

func _st_netmender_p3(p: Player) -> void:
	_netmender_stage(p, 3, "last_cast", 0.85, 6.5)

## Release: she sits back down; the card, the needle where she sat.
func _st_release(p: Player) -> void:
	if _f == 3:
		_foe = _foe_near("netmender", Vector3(0, 0, -46))
		if _foe == null:
			return
		_place_player(p, _foe.global_position + Vector3(0, 0.1, 3.4), PI)
	var nm := _foe as Netmender
	if nm == null:
		return
	if not nm.stood:
		return
	if not nm.released:
		nm.vis.rotation.y = PI   # turned to face the door, and the Bearer
		var fwd := -nm.vis.global_transform.basis.z
		_place_player(p, nm.global_position + fwd * 5.0 + Vector3.UP * 0.1, 0.0)
		nm._die()
		_t0 = _clock
	var to := nm.global_position - p.global_position
	p.vis.rotation.y = atan2(-to.x, -to.z)
	var back := -to
	back.y = 0
	back = back.normalized()
	var right := back.cross(Vector3.UP)
	_cam.global_position = p.global_position + back * 2.8 - right * 1.6 + Vector3.UP * 2.0
	_cam.look_at(nm.global_position + Vector3.UP * 1.0 - back * -1.0, Vector3.UP)
	_cam.fov = 52.0
	if _clock - _t0 > 2.4:
		_freeze()

# ------------------------------------------------------------------ the Lowe
## The Lowe's foes (LOWE.md 5): squared up to the Bearer, the signature move
## frozen `frac` of the way through its windup so its tell (body and floor)
## shows. Run in lowe_barrows, RIME.
func _lowe_foe_stage(p: Player, id: String, hint: Vector3, atk: String, frac: float, gap: float,
		cam_dist := 5.2, cam_h := 1.0, look := 1.0, move_to := Vector3.INF) -> void:
	near_hint = hint
	if _f == 2:
		_quiet_titles()
	var e := _face_off(p, id, gap)
	if e == null:
		return
	if _f == 4 and move_to != Vector3.INF:
		# stage it on open ground, clear of decks and walls the camera would hit
		e.global_position = move_to
		e.home = move_to
		e.idle_pose = ""
		e._risen = true
		e.vis.idle(0.0)
	if _f >= 6:
		_side_cam(p, e, cam_dist, cam_h, look, 50.0)
		_quiet_card()
	if _f < 50:
		# nothing before the beat: a hole cut under the staged Bearer would
		# take him (the fjord does not care for i-frames) and the shot with him
		for a in e.cfg.get("attacks", []):
			e._cooldowns[String(a["id"])] = 99.0
	if _f == 50:
		e._cooldowns.clear()
		e._begin_attack(e.attack_by_id(atk))
	if _f > 50 and e.state == Enemy.ES.ATTACK and String(e._atk.get("id", "")) == atk \
			and e.state_t >= float(e._atk["windup"]) * frac:
		_freeze()

func _st_lowe_sleeper(p: Player) -> void:
	_lowe_foe_stage(p, "barrow_sleeper", Vector3(-57.9, 0, -118.8), "door_fall", 0.8, 2.4, 4.4, 1.0, 1.0)

func _st_lowe_keener(p: Player) -> void:
	_lowe_foe_stage(p, "keener", Vector3(-30, 0, -128), "keen", 1.12, 5.0, 4.6, 0.8, 1.2)

func _st_lowe_carrier(p: Player) -> void:
	_lowe_foe_stage(p, "cairn_carrier", Vector3(22, 0, -158), "set_stone", 0.8, 3.0, 5.6, 1.2, 1.2)

## The Turfwright: wake him, set the phase, face him from `gap` metres,
## start `atk` and freeze `frac` of the way through it (or into a hold).
var _tw_set := false

func _turfwright_stage(p: Player, ph: int, atk: String, frac: float, gap: float,
		cam_back := 4.6, cam_up := 3.2) -> void:
	if _f == 3:
		_foe = _foe_near("turfwright", Vector3(46, 0, -205))
		if _foe == null:
			return
		_place_player(p, _foe.global_position + Vector3(0, 0.1, 4.5), PI)
	var tw := _foe as Turfwright
	if tw == null:
		return
	if not tw.stood:
		_frame(tw.global_position, p.vis, Vector3(2.0, 2.4, -4.0), 2.0, 55.0)
		return
	if not _tw_set:
		_tw_set = true
		_t0 = _clock
		tw.phase = ph
		if ph >= 2:
			tw.hp = tw.max_hp * 0.5
			tw._raise_walls()
		if ph >= 3:
			tw.hp = tw.max_hp * 0.2
			for w in tw.walls:
				(w as IceRidge).queue_free()
			tw.walls.clear()
			tw.sod_at = "chest"
			tw.vis.rig.set_carry("turf_carry", ["mixamorig_LeftShoulder", "mixamorig_LeftArm",
					"mixamorig_LeftForeArm", "mixamorig_LeftHand"], true)
		tw.vis.rotation.y = PI   # turned to the way in, and the Bearer
		var fwd := -tw.vis.global_transform.basis.z
		_place_player(p, tw.global_position + fwd * gap + Vector3.UP * 0.1, 0.0)
	var to := tw.global_position - p.global_position
	p.vis.rotation.y = atan2(-to.x, -to.z)
	var back := -to
	back.y = 0
	back = back.normalized()
	var right := back.cross(Vector3.UP)
	_cam.global_position = p.global_position + back * cam_back - right * 2.2 + Vector3.UP * cam_up
	_cam.look_at(tw.global_position + Vector3.UP * 1.6 - back * 1.5, Vector3.UP)
	_cam.fov = 56.0
	if not _started and _clock - _t0 > 0.6:
		_started = true
		tw._cooldowns.clear()
		tw._begin_attack(tw.attack_by_id(atk))
	if _started and tw.state == Enemy.ES.HOLD and tw.state_t >= 0.8:
		_freeze()
	elif _started and tw.state == Enemy.ES.ATTACK and String(tw._atk.get("id", "")) == atk \
			and String(tw._atk.get("type", "")) != "hold" \
			and tw.state_t >= float(tw._atk["windup"]) / tw._speed_mult() * frac:
		_freeze()

func _st_turfwright_p1(p: Player) -> void:
	_turfwright_stage(p, 1, "ground_cut", 0.85, 8.0)

func _st_turfwright_p2(p: Player) -> void:
	_turfwright_stage(p, 2, "stack_sod", 0.85, 8.0, 7.0, 5.0)

func _st_turfwright_p3(p: Player) -> void:
	_turfwright_stage(p, 3, "last_turf", 1.0, 9.0)

## Release: he kneels and lays the sod in the doorway; the card; the stick.
func _st_lowe_release(p: Player) -> void:
	if _f == 3:
		_foe = _foe_near("turfwright", Vector3(46, 0, -205))
		if _foe == null:
			return
		_place_player(p, _foe.global_position + Vector3(0, 0.1, 4.5), PI)
	var tw := _foe as Turfwright
	if tw == null or not tw.stood:
		return
	if not tw.released:
		tw.vis.rotation.y = PI
		var fwd := -tw.vis.global_transform.basis.z
		_place_player(p, tw.global_position + fwd * 6.0 + Vector3.UP * 0.1, 0.0)
		tw._die()
		_t0 = _clock
	var to := tw.global_position - p.global_position
	p.vis.rotation.y = atan2(-to.x, -to.z)
	var back := -to
	back.y = 0
	back = back.normalized()
	var right := back.cross(Vector3.UP)
	_cam.global_position = p.global_position + back * 3.0 - right * 2.4 + Vector3.UP * 2.4
	_cam.look_at(tw.global_position + Vector3.UP * 1.2, Vector3.UP)
	_cam.fov = 54.0
	if _clock - _t0 > 2.8:
		_freeze()

## Hesk and Aud in THAW, mid-conversation: the dialogue panel up on a line.
func _npc_talk_stage(p: Player, id: String, line := 0, eye := Vector3(-1.3, 0.5, 3.1)) -> void:
	var n := _find_npc(id)
	if n == null:
		return
	var fwd := -n.global_transform.basis.z
	if _f == 3:
		_place_player(p, n.global_position + fwd * 2.2 + Vector3.UP * 0.2, atan2(fwd.x, fwd.z))
	if _f > 3:
		_frame(n.global_position, n, eye, 1.0, 40.0)
	if _f == 40:
		n._on_talk(p)
	if _f == 46:
		for ui in get_tree().root.find_children("*", "DialogueUI", true, false):
			for i in line:
				(ui as DialogueUI).advance()
	if _f > 46 and ((n._vis.rig != null and n._vis.rig.action_time() >= 1.2) or (n._vis.rig == null and _f > 80)):
		_freeze()   # (a mannequin stand-in has no greet clip to wait on)

func _st_lowe_hesk(p: Player) -> void:
	_npc_talk_stage(p, "hesk", 3)

func _st_lowe_aud(p: Player) -> void:
	_npc_talk_stage(p, "aud", 3)

# ------------------------------------------------------------------ Kettle Fjord
## (kettle_fjord; docs/screens/kettle_enc_*.png): kettle_fisher, kettle_sealer,
## kettle_dogs, ice_cutter_p1, ice_cutter_p2, ice_cutter_p3, kettle_release
## (RIME); kettle_ivo, kettle_halla, kettle_sten (THAW).
func _st_kettle_fisher(p: Player) -> void:
	_lowe_foe_stage(p, "ice_fisher", Vector3(-33, 0, -328.8), "cut_hole", 0.85, 3.5, 5.0, 1.4, 0.9,
			Vector3(-40, 0.15, -338))

func _st_kettle_sealer(p: Player) -> void:
	_lowe_foe_stage(p, "sealer", Vector3(-12, 0, -303.7), "hook", 0.85, 4.0, 5.0, 1.0, 1.1,
			Vector3(-8, 0.15, -330))

func _st_kettle_dogs(p: Player) -> void:
	_lowe_foe_stage(p, "sledge_dog", Vector3(-58, 0, -323.8), "run_down", 0.8, 6.0, 5.0, 1.6, 0.4,
			Vector3(-46, 0.15, -340))

## The Ice-Cutter: wake him, set the phase, face him across the ice from
## `gap` metres, start `atk` and freeze `frac` of the way through it (or a
## moment into a hold, or `after` seconds past the strike when the broken ice
## is the thing to see).
var _ic_set := false

func _ice_cutter_stage(p: Player, ph: int, atk: String, frac: float, gap: float, after := -1.0,
		cam_back := 5.0, cam_up := 3.6, step_off := false) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("ice_cutter", Vector3(22, 0, -320))
		if _foe == null:
			return
		_place_player(p, _foe.global_position + Vector3(4.5, 0.1, 1.0), PI)
	var ic := _foe as IceCutter
	if ic == null:
		return
	if not ic.stood:
		_frame(ic.global_position, p.vis, Vector3(2.0, 2.4, -4.0), 1.6, 55.0)
		return
	if not _ic_set:
		_ic_set = true
		_t0 = _clock
		ic.phase = ph
		if ph >= 2:
			ic.hp = ic.max_hp * 0.5
			ic._transition_event("ring_band")
		if ph >= 3:
			ic.hp = ic.max_hp * 0.2
			ic._transition_event("band_close")
		ic.vis.rotation.y = 0.0 if ph < 3 else PI
		var fwd := -ic.vis.global_transform.basis.z
		var at := ic.global_position + fwd * gap
		if ph < 3:
			# beyond the hole, toward the far shore, so the hole lies between them
			at = ic.global_position - Vector3(0, 0, gap)
			ic.vis.rotation.y = 0.0
		_place_player(p, Vector3(at.x, 0.15, at.z), 0.0)
	var to := ic.global_position - p.global_position
	p.vis.rotation.y = atan2(-to.x, -to.z)
	var back := -to
	back.y = 0
	back = back.normalized()
	var right := back.cross(Vector3.UP)
	_cam.global_position = p.global_position + back * cam_back - right * 2.4 + Vector3.UP * cam_up
	_cam.look_at(ic.global_position + Vector3.UP * 1.2 - back * 1.5, Vector3.UP)
	_cam.fov = 58.0
	if not _started and _clock - _t0 > 0.6:
		_started = true
		ic._cooldowns.clear()
		ic.target = p
		ic._begin_attack(ic.attack_by_id(atk))
		_t1 = _clock
	if not _started:
		return
	if ic.state == Enemy.ES.HOLD and ic.state_t >= 0.8:
		_freeze()
	elif after >= 0.0:
		var w := float(ic.attack_by_id(atk)["windup"]) / ic._speed_mult()
		if step_off and not _stepped and _clock - _t1 >= w + 0.05:
			# he steps off the broken ice in time: show the hole beside him
			_stepped = true
			_place_player(p, p.global_position + Vector3(3.4, 0, 0), 0.0)
		if _clock - _t1 >= w + after:
			_freeze()
	elif ic.state == Enemy.ES.ATTACK and String(ic._atk.get("id", "")) == atk \
			and String(ic._atk.get("type", "")) != "hold" \
			and ic.state_t >= float(ic._atk["windup"]) / ic._speed_mult() * frac:
		_freeze()

var _t1 := 0.0
var _stepped := false

func _st_ice_cutter_p1(p: Player) -> void:
	_ice_cutter_stage(p, 1, "drill_down", 0.0, 8.0, 1.2, 5.0, 3.6, true)

func _st_ice_cutter_p2(p: Player) -> void:
	_ice_cutter_stage(p, 2, "ring_cut", 0.0, 5.6, 1.0, 7.0, 6.0)   # inside the band

func _st_ice_cutter_p3(p: Player) -> void:
	_ice_cutter_stage(p, 3, "cut_fresh", 1.0, 8.0)

## Release: he kneels at the rim; the hole skins over; the mitten; the card.
func _st_kettle_release(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("ice_cutter", Vector3(22, 0, -320))
		if _foe == null:
			return
		_place_player(p, _foe.global_position + Vector3(4.5, 0.1, 1.0), PI)
	var ic := _foe as IceCutter
	if ic == null or not ic.stood:
		return
	if not ic.released:
		var hole := ic.hole_point()
		_place_player(p, Vector3(hole.x + 1.0, 0.15, hole.z + 4.5), 0.0)
		ic._die()
		_t0 = _clock
	var hole2 := ic.hole_point()
	_cam.global_position = hole2 + Vector3(3.2, 3.0, 6.0)
	_cam.look_at(hole2 + Vector3(0, 0.4, -0.8), Vector3.UP)
	_cam.fov = 54.0
	if _clock - _t0 > 2.8:
		_freeze()

func _st_kettle_ivo(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_npc_talk_stage(p, "ivo", 3)

func _st_kettle_halla(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_npc_talk_stage(p, "halla", 2)

func _st_kettle_sten(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_npc_talk_stage(p, "sten", 0)

## Zone title cards fire as the staged Bearer is set down in a new zone; they
## are not the beat being shown.
func _quiet_titles() -> void:
	for z in get_tree().current_scene.find_children("*", "ZoneTitles", true, false):
		z.queue_free()

## The region's own arrival card (not the release card) is not the beat either.
func _quiet_card() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		var tl = hud.get("_title_layer")
		if tl != null and is_instance_valid(tl):
			tl.queue_free()

# ------------------------------------------------------------------ Tarnhall
## (tarnhall; docs/screens/tarnhall_enc_*.png): tarnhall_guest, tarnhall_cupbearer,
## tarnhall_champion, host_p1, host_p1b, host_p2, host_p2b, host_p3,
## tarnhall_release, tarnhall_doors (RIME); tarnhall_lusse, tarnhall_ottar
## (THAW). And kettle_crack (kettle_fjord, RIME): the ice cracking first.
const HALL_FLOOR := Vector3(200.0, 24.4, -326.5)   # the open floor south of the table

func _st_tarnhall_guest(p: Player) -> void:
	_lowe_foe_stage(p, "feast_guest", Vector3(202, 0, -320), "toast", 0.8, 1.9, 4.6, 1.2, 1.0)

func _st_tarnhall_cupbearer(p: Player) -> void:
	_lowe_foe_stage(p, "cupbearer", Vector3(220, 0, -328.5), "going_round", 0.8, 2.2, 4.4, 1.4, 1.0,
			Vector3(208.0, 24.55, -319.0))

func _st_tarnhall_champion(p: Player) -> void:
	# (the camera on its shield side: the board grown into the left forearm)
	_lowe_foe_stage(p, "hall_champion", Vector3(222.6, 0, -323.2), "shield_rush", 0.8, 6.0, -6.0, 1.8, 1.0,
			Vector3(204.0, 24.55, -321.0))

func _st_kettle_crack(p: Player) -> void:
	# the cracks spread a second before the ice opens: frozen half a second out
	_lowe_foe_stage(p, "ice_fisher", Vector3(-33, 0, -328.8), "cut_hole", 0.62, 3.5, 4.6, 2.2, 0.4,
			Vector3(-40, 0.15, -338))

## The Host: woken at the table, the phase set, the Bearer on the hall floor
## `gap` metres off; `atk` started and frozen `frac` of the way through its
## windup (or `after` seconds past the strike), or a transition frozen at
## `trans_t` seconds. The camera stands behind the Bearer's right shoulder,
## under the roof.
var _host_set := false

func _host_stage(p: Player, ph: int, atk: String, frac: float, gap: float, after := -1.0,
		trans := "", trans_t := 0.0, cam_back := 4.6, cam_up := 2.6, side := 2.6) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("host", Vector3(200, 0, -330))
		if _foe == null:
			return
	var h := _foe as Host
	if h == null:
		return
	if not _host_set:
		_host_set = true
		_t0 = _clock
		h.target = p
		h._stand_done()
		h._set_state(Enemy.ES.COMBAT)
		h.vis.idle(0.0)
		h.phase = ph
		if ph >= 2:
			h.hp = h.max_hp * 0.5
		if ph >= 3:
			h.hp = h.max_hp * 0.2
		h.vis.rotation.y = PI   # facing the hall floor (+z)
		for a in h.cfg.get("attacks", []):
			h._cooldowns[String(a["id"])] = 99.0
		_place_player(p, h.global_position + Vector3(0.6, 0.1, gap), 0.0)
	var to := h.global_position - p.global_position
	to.y = 0
	p.vis.rotation.y = atan2(-to.x, -to.z)
	# from the east end of the open floor, looking along the hall across the
	# pair (a camera behind the Bearer would stand in the south wall)
	var mid := h.global_position.lerp(p.global_position, 0.45)
	_cam.global_position = mid + Vector3(side, cam_up, cam_back)
	_cam.look_at(mid + Vector3.UP * 1.4, Vector3.UP)
	if _cam_fix.size() == 2:   # a beat at the bench, not between the two of them
		_cam.global_position = h.global_position + (_cam_fix[0] as Vector3)
		_cam.look_at(h.global_position + (_cam_fix[1] as Vector3), Vector3.UP)
	_cam.fov = 60.0
	_quiet_card()
	if _clock - _t0 < 0.8:
		return
	if not _started:
		_started = true
		_t1 = _clock
		if trans != "":
			h._begin_transition(trans)
		else:
			h._cooldowns.clear()
			h._begin_attack(h.attack_by_id(atk))
		return
	if trans != "":
		if h.state == Enemy.ES.TRANSITION and h.state_t >= trans_t:
			_freeze()
		return
	if h.state == Enemy.ES.HOLD and h.state_t >= 1.2:
		_freeze()
	elif after >= 0.0:
		var w := float(h.attack_by_id(atk)["windup"]) / h._speed_mult()
		if _clock - _t1 >= w + after:
			_freeze()
	elif h.state == Enemy.ES.ATTACK and String(h._atk.get("id", "")) == atk \
			and h.state_t >= float(h._atk["windup"]) / h._speed_mult() * frac:
		_freeze()

func _st_host_p1(p: Player) -> void:
	_host_stage(p, 1, "table_sweep", 0.85, 4.2, -1.0, "", 0.0, 1.6, 3.6, 8.0)

func _st_host_p1b(p: Player) -> void:
	_host_stage(p, 1, "bench_throw", 0.0, 7.0, 0.22, "", 0.0, 1.4, 3.2, 8.5)

var _cam_fix: Array = []

func _st_host_p2(p: Player) -> void:
	# the guests standing up out of their places beside him
	_cam_fix = [Vector3(-4.5, 3.0, 4.0), Vector3(3.0, 1.4, -1.0)]
	_host_stage(p, 2, "", 0.0, 6.0, -1.0, "p2", 2.0, 1.0, 3.0, 8.0)

func _st_host_p2b(p: Player) -> void:
	_host_stage(p, 2, "tip_horn", 0.0, 7.5, 1.8, "", 0.0, 1.4, 4.0, 8.5)

func _st_host_p3(p: Player) -> void:
	_host_stage(p, 3, "pour", 1.0, 7.0, -1.0, "", 0.0, 1.2, 2.8, 7.0)

## Release: he sits down at the table; the guests sit; the cup beside him.
func _st_tarnhall_release(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("host", Vector3(200, 0, -330))
	var h := _foe as Host
	if h == null:
		return
	if not h.released:
		h.target = p
		h._stand_done()
		h.raise_guests(2)
		_place_player(p, h.global_position + Vector3(1.2, 0.1, 5.0), 0.0)
		h._die()
		_t0 = _clock
	_cam.global_position = h.global_position + Vector3(4.6, 2.6, 6.4)
	_cam.look_at(h.global_position + Vector3(-0.6, 1.4, 0.4), Vector3.UP)
	_cam.fov = 58.0
	if _clock - _t0 > 3.2:
		_freeze()

## The doors: the bar lifted, the leaves open on the tarn; the tally on the post.
func _st_tarnhall_doors(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("host", Vector3(200, 0, -330))
	var h := _foe as Host
	if h == null:
		return
	if not h.released:
		h.target = p
		h._stand_done()
		_place_player(p, Vector3(191.5, 24.5, -326.0), -PI / 2)   # behind the camera
		h._die()
		_t0 = _clock
	_cam.global_position = Vector3(188.5, 26.6, -325.4)
	_cam.look_at(Vector3(180.0, 25.4, -328.6), Vector3.UP)
	_cam.fov = 62.0
	if _clock - _t0 > 2.6:
		_freeze()

func _st_tarnhall_lusse(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_npc_talk_stage(p, "lusse", 1)

func _st_tarnhall_ottar(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_npc_talk_stage(p, "ottar", 2)

# ------------------------------------------------------------------ release scenes
## The post-release THAW scenes (docs/screens/release_*.png; run with
## --state=thaw and --flag=<the release flag>): release_lowe (Arne and the
## twins outside their barrow), release_kettle (Pell and Ivo at the kettle).
## The camera faces the group; the Bearer stands just behind it, in earshot,
## and the beat is a line of their talk overheard.
func _release_stage(p: Player, id: String, eye: Vector3, look_up: float, line := 1) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	var n := _find_npc(id)
	if n == null:
		return
	var fwd := -n.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var cam := n.global_position + fwd * eye.z + right * eye.x + Vector3.UP * eye.y
	if _f == 3:
		_place_player(p, n.global_position + fwd * (eye.z + 1.2) + Vector3.UP * 0.3, atan2(fwd.x, fwd.z))
		_t0 = _clock
		n.overheard.connect(func(_w, _l): _heard += 1)
	_cam.global_position = cam
	_cam.look_at(n.global_position + Vector3.UP * look_up - right * eye.x * 0.3, Vector3.UP)
	_cam.fov = 50.0
	if _heard >= line and _clock - _t0 > 1.0:
		_hold_clock += get_process_delta_time()
		if _hold_clock > 1.0:
			_freeze()

var _heard := 0
var _hold_clock := 0.0

func _st_release_lowe(p: Player) -> void:
	_release_stage(p, "arne", Vector3(0.6, 1.5, 4.6), 0.7, 3)

## Pell and Ivo across the kettle: from the side, so the kettle sits between
## them and not between them and the camera.
func _st_release_kettle(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	var pell := _find_npc("pell")
	var ivo := _find_npc("ivo")
	if pell == null or ivo == null:
		return
	var mid := (pell.global_position + ivo.global_position) * 0.5
	var axis := ivo.global_position - pell.global_position
	axis.y = 0
	var side := axis.normalized().cross(Vector3.UP) * _kettle_side
	var cam := mid + side * 5.2 + Vector3.UP * 1.9
	if _f == 3:
		_place_player(p, mid + side * 6.6 + Vector3.UP * 0.3, atan2(side.x, side.z))
		_t0 = _clock
		pell.overheard.connect(func(_w, _l): _heard += 1)
	_cam.global_position = cam
	_cam.look_at(mid + Vector3.UP * 0.8, Vector3.UP)
	_cam.fov = 50.0
	if _heard >= 2 and _clock - _t0 > 1.0:
		_hold_clock += get_process_delta_time()
		if _hold_clock > 1.0:
			_freeze()

var _kettle_side := -1.0   # (the shelf side, not the cliff)

# ------------------------------------------------------------------ Thornwold
## (thornwold; docs/screens/thornwold_enc_*.png): thorn_collier, thorn_stag,
## hedgelayer_p1, hedgelayer_p2, hedgelayer_p3, thorn_release (RIME);
## thorn_argument (THAW), thorn_after (THAW, --flag=ks_hedgelayer_released).
func _st_thorn_collier(p: Player) -> void:
	# on the clearing's open floor (on the road the camera would stand in the thorn)
	_lowe_foe_stage(p, "collier", Vector3(380, 0, -312), "rake", 0.8, 2.0, 4.4, 1.3, 1.0,
			Vector3(343.0, 34.5, -303.0))

func _st_thorn_stag(p: Player) -> void:
	_lowe_foe_stage(p, "rime_stag", Vector3(400, 0, -300), "bound", 0.7, 7.0, 7.0, 2.4, 1.2,
			Vector3(348.0, 34.5, -300.0))

## The Hedgelayer: woken, the phase set (with its ring), the Bearer `gap`
## metres off toward the middle of the grave's clearing; `atk` started and
## frozen `frac` of the way through its windup, or `after` seconds past it.
var _hl_set := false
var _hl_cam_grave := false
var _hl_dir := Vector2(0.85, 0.3)   # where the Bearer stands: round the ring, and in

func _hl_stage(p: Player, ph: int, atk: String, frac: float, gap: float, after := -1.0,
		cam := Vector3(5.0, 3.6, 6.0), hold_t := 0.0) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	if _f == 3:
		_foe = _foe_near("hedgelayer", Vector3(448, 0, -321))
	var h := _foe as Hedgelayer
	if h == null:
		return
	if not _hl_set:
		_hl_set = true
		_t0 = _clock
		h.target = p
		h._stand_done()
		h.vis.idle(0.0)
		h.phase = ph
		if ph >= 2:
			h.hp = h.max_hp * 0.5
			h._raise_ring(h.cfg["ring2"])
		if ph >= 3:
			h.hp = h.max_hp * 0.2
			h._raise_ring(h.cfg["ring3"])
		h._set_state(Enemy.ES.COMBAT)
		for a in h.cfg.get("attacks", []):
			h._cooldowns[String(a["id"])] = 99.0
		# round the ring from him (not toward the grave: the pine and the turf
		# are there), so what he raises lands on open floor
		var to_g := h.grave_point() - h.global_position
		to_g.y = 0
		var tang := to_g.normalized().cross(Vector3.UP)
		var at := h.global_position + (tang * _hl_dir.x + to_g.normalized() * _hl_dir.y).normalized() * gap
		_place_player(p, Vector3(at.x, h.global_position.y + 0.3, at.z), 0.0)
	var mid := h.global_position.lerp(p.global_position, 0.5)
	var axis := p.global_position - h.global_position
	axis.y = 0
	var side := axis.normalized().cross(Vector3.UP)
	if _hl_cam_grave:
		# up over the grave, looking out at the Bearer and the hedge beside him
		var g := h.grave_point()
		var out := p.global_position - g
		out.y = 0
		_cam.global_position = g - out.normalized() * 1.5 + Vector3.UP * 6.5
		_cam.look_at(p.global_position + Vector3.UP * 0.5, Vector3.UP)
	elif cam.y < 0.0:
		# behind the Bearer, looking at him
		_cam.global_position = p.global_position + axis.normalized() * absf(cam.z) + side * cam.x + Vector3.UP * absf(cam.y)
		_cam.look_at(h.global_position + Vector3.UP * 1.8, Vector3.UP)
	elif cam.z < 0.0:
		# over his shoulder: past him to the Bearer and what rises behind
		_cam.global_position = h.global_position + side * cam.x + Vector3.UP * cam.y + axis.normalized() * cam.z
		_cam.look_at(p.global_position + axis.normalized() * 1.5 + Vector3.UP * 1.0, Vector3.UP)
	else:
		_cam.global_position = mid + side * cam.x + Vector3.UP * cam.y + axis.normalized() * cam.z
		_cam.look_at(mid + Vector3.UP * 1.2, Vector3.UP)
	_cam.fov = 58.0
	if _clock - _t0 < 0.8:
		return
	if not _started:
		_started = true
		_t1 = _clock
		h._cooldowns.clear()
		h.target = p
		h._begin_attack(h.attack_by_id(atk))
		return
	if h.state == Enemy.ES.HOLD and h._hold_kind == "measure" and h.state_t >= 1.2:
		_freeze()
	elif after >= 0.0:
		var w := float(h.attack_by_id(atk)["windup"]) / h._speed_mult()
		if _clock - _t1 >= w + after:
			_freeze()
	elif h.state == Enemy.ES.ATTACK and String(h._atk.get("id", "")) == atk \
			and h.state_t >= float(h._atk["windup"]) / h._speed_mult() * frac:
		_freeze()

func _st_hedgelayer_p1(p: Player) -> void:
	_hl_dir = Vector2(0.6, 0.8)   # (so the wall rises on open floor, short of the ring)
	_hl_stage(p, 1, "raise_wall", 0.0, 5.0, 0.5, Vector3(2.2, 3.6, -4.5))

func _st_hedgelayer_p2(p: Player) -> void:
	# in the hedge: the circle glowing where he will step out
	_hl_cam_grave = true
	_hl_stage(p, 2, "step_into", 0.0, 5.0, 1.2 + 0.4, Vector3(2.5, 4.4, -4.0))

func _st_hedgelayer_p3(p: Player) -> void:
	_hl_dir = Vector2(0.0, 1.0)   # (straight in toward the grave: he is in the ring's gap)
	_hl_stage(p, 3, "where_it_goes", 1.0, 4.0, -1.0, Vector3(1.4, -2.6, 3.4))

## Release: he kneels at the gap; the ring unlays; the gate lies down; the cord.
func _st_thorn_release(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("hedgelayer", Vector3(448, 0, -321))
	var h := _foe as Hedgelayer
	if h == null:
		return
	if not h.released:
		h.target = p
		h._stand_done()
		h.phase = 2
		h._raise_ring(h.cfg["ring2"])
		var g := h.grave_point()
		_place_player(p, g + Vector3(-6.0, 0.3, 4.0), 0.0)
		h._die()
		_t0 = _clock
	var g2 := h.grave_point()
	for v in get_tree().current_scene.find_children("*", "FrostVeil", true, false):
		(v as Node3D).visible = false   # (it falls as meltwater; the beat is the gate)
	# from the road side of the gap, outside the ring: the gate laid down in it
	_cam.global_position = g2 + Vector3(-17.0, 3.4, 3.2)
	_cam.look_at(g2 + Vector3(-11.0, 0.2, 0.0), Vector3.UP)
	_cam.fov = 58.0
	if _clock - _t0 > 3.0:
		_freeze()

func _st_thorn_argument(p: Player) -> void:
	_release_stage(p, "eyvind", Vector3(1.6, 1.6, 5.0), 0.9, 2)

## After: the two of them either side of the gap, the gate lying flat
## across it between them; from the road side, outside the rings.
func _st_thorn_after(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	var e := _find_npc("eyvind_gate")
	var l := _find_npc("linnet")
	if e == null or l == null:
		return
	var mid := (e.global_position + l.global_position) * 0.5
	var out := Vector3(-1, 0, 0)   # the rings' gap faces west, to the road
	if _f == 3:
		_place_player(p, mid + out * 7.4 + Vector3.UP * 0.3, atan2(-out.x, -out.z) + PI)
		_t0 = _clock
		e.overheard.connect(func(_w, _l): _heard += 1)
	_cam.global_position = mid + out * 6.2 + Vector3(0, 2.2, 1.2)
	_cam.look_at(mid + Vector3(1.2, 0.7, 0), Vector3.UP)
	_cam.fov = 52.0
	if _heard >= 4 and _clock - _t0 > 1.0:
		_hold_clock += get_process_delta_time()
		if _hold_clock > 1.0:
			_freeze()

# ------------------------------------------------------------------ Shepherd's Reach
## (shepherds_reach; docs/screens/reach_enc_*.png): reach_drover, reach_ram,
## fellcaller_p1, fellcaller_p2, fellcaller_p3, reach_release (RIME);
## reach_calder, reach_sigga (THAW), reach_after (THAW,
## --flag=ks_fellcaller_released).
func _st_reach_drover(p: Player) -> void:
	_lowe_foe_stage(p, "drover", Vector3(626, 0, -292), "leg_hook", 0.92, 4.2, 5.4, 1.2, 1.0)

func _st_reach_ram(p: Player) -> void:
	_lowe_foe_stage(p, "frost_ram", Vector3(660, 0, -300), "charge", 0.9, 7.0, 6.4, 1.6, 0.8)

## A Holdfast of the high country, woken and set in a phase; the Bearer `gap`
## metres off in `dir` (x across, z out from the boss toward the arena's
## middle); `atk` started and frozen `frac` of the way through its windup, or
## `after` seconds past it. cam: metres to the side, up, and back along the axis.
var _hc_set := false

func _high_stage(p: Player, id: String, centre: Vector3, ph: int, atk: String, frac: float, gap: float,
		after := -1.0, cam := Vector3(5.0, 3.2, 2.0), dir := Vector2(0.4, 1.0), fov := 58.0) -> Enemy:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	if _f == 3:
		_foe = _foe_near(id, centre)
	var e := _foe as Enemy
	if e == null:
		return null
	if not _hc_set:
		_hc_set = true
		_t0 = _clock
		e.target = p
		e.call("_stand_done")
		e.phase = ph
		for a in e.cfg.get("attacks", []):
			e._cooldowns[String(a["id"])] = 99.0
		var to_c := centre - e.global_position
		to_c.y = 0
		var out := to_c.normalized() if to_c.length() > 0.5 else Vector3(-1, 0, 0)
		var at := e.global_position + (out.cross(Vector3.UP) * dir.x + out * dir.y).normalized() * gap
		_place_player(p, Vector3(at.x, e.global_position.y + 0.3, at.z), 0.0)
		e._set_state(Enemy.ES.COMBAT)
	var mid := e.global_position.lerp(p.global_position, 0.5)
	var axis := p.global_position - e.global_position
	axis.y = 0
	var side := axis.normalized().cross(Vector3.UP)
	_cam.global_position = mid + side * cam.x + Vector3.UP * cam.y + axis.normalized() * cam.z
	_cam.look_at(mid + Vector3.UP * 1.3, Vector3.UP)
	_cam.fov = fov
	var d := e.global_position - p.global_position
	p.vis.rotation.y = atan2(-d.x, -d.z)
	if _clock - _t0 < 0.8:
		return e
	if atk == "":
		return e
	if not _started:
		_started = true
		_t1 = _clock
		e._cooldowns.clear()
		e.target = p
		e.vis.rotation.y = atan2(d.x, d.z)
		e._begin_attack(e.attack_by_id(atk))
		return e
	if e.state == Enemy.ES.HOLD and e.state_t >= 1.2:
		_freeze()
	elif after >= 0.0:
		var w := float(e.attack_by_id(atk)["windup"]) / e._speed_mult()
		if _clock - _t1 >= w + after:
			_freeze()
	elif e.state == Enemy.ES.ATTACK and String(e._atk.get("id", "")) == atk \
			and e.state_t >= float(e._atk["windup"]) / e._speed_mult() * frac:
		_freeze()
	return e

const FOLD := Vector3(660.0, 0, -372.0)

func _st_fellcaller_p1(p: Player) -> void:
	_high_stage(p, "fellcaller", FOLD, 1, "rising_cry", 0.9, 5.0, -1.0, Vector3(6.0, 3.4, 1.5))

func _st_fellcaller_p2(p: Player) -> void:
	# the flock half-way down the strip
	_high_stage(p, "fellcaller", FOLD, 2, "call_them_in", 0.0, 7.0, 0.42, Vector3(6.5, 5.0, 3.5))

func _st_fellcaller_p3(p: Player) -> void:
	var e := _high_stage(p, "fellcaller", FOLD, 3, "count_them", 1.0, 7.0, -1.0, Vector3(6.0, 3.0, 0.5), Vector2(0.9, 0.5))
	if e != null and _f == 5:
		e.global_position = (e as Fellcaller).stand_over_point()

## Release: one soft call; the slope lies down. From above the fold wall,
## looking down the trod at the flock.
func _st_reach_release(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("fellcaller", FOLD)
	var f := _foe as Fellcaller
	if f == null:
		return
	if not f.released:
		f.target = p
		f._stand_done()
		_place_player(p, f.global_position + Vector3(-3.0, 0.3, 3.0), 0.0)
		f._die()
		_t0 = _clock
	for v in get_tree().current_scene.find_children("*", "FrostVeil", true, false):
		(v as Node3D).visible = false
	# from the open floor: her knelt by him, the cairn behind them
	_cam.global_position = f.father_point() + Vector3(-5.6, 2.4, 4.2)
	_cam.look_at(f.father_point() + Vector3(-0.4, 0.8, 0.0), Vector3.UP)
	_cam.fov = 56.0
	if _clock - _t0 > 4.2:
		_freeze()

## The slope after: seventy sheep lying down (RIME, --flag=ks_fellcaller_released).
func _st_reach_flock(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	if _f == 3:
		_place_player(p, _ground(636.0, -356.0) + Vector3.UP * 0.3, deg_to_rad(250))
		_t0 = _clock
	if _f > 3:
		_cam.global_position = p.global_position + Vector3(-5.0, 3.4, 4.0)
		_cam.look_at(Vector3(656, p.global_position.y + 1.0, -374), Vector3.UP)
		_cam.fov = 62.0
	if _f > 60:
		_freeze()

func _st_reach_calder(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	_npc_talk_stage(p, "old_calder", 3)

func _st_reach_sigga(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	_npc_talk_stage(p, "sigga", 0)

func _st_reach_after(p: Player) -> void:
	_release_stage(p, "sigga_fold", Vector3(2.4, 1.7, 5.6), 0.9, 3)

## Old Calder laid at the cairn, RIME, and her beside him calling.
func _st_reach_cairn(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	if _f == 3:
		_foe = _foe_near("fellcaller", FOLD)
	var f := _foe as Fellcaller
	if f == null:
		return
	f.set_physics_process(false)   # (she goes on calling: the Bearer has not come near)
	if _f == 4:
		_place_player(p, f.father_point() + Vector3(-9.0, 0.3, 6.0), 0.0)
	for v in get_tree().current_scene.find_children("*", "FrostVeil", true, false):
		(v as Node3D).visible = false
	# from the open side of the fold: him against the cairn, her beside him
	_cam.global_position = f.father_point() + Vector3(-6.4, 2.0, -2.4)
	_cam.look_at(f.father_point() + Vector3(-0.6, 1.0, 0.3), Vector3.UP)
	_cam.fov = 60.0
	if _f > 70:
		_freeze()

# ------------------------------------------------------------------ the Coldwell
## (coldwell; docs/screens/coldwell_enc_*.png): cold_upwalker, cold_unsung,
## leadvoice_sat, leadvoice_p1, leadvoice_p2, leadvoice_p3, cold_release
## (RIME); cold_melt (THAW).
const WELL := Vector3(922.0, 0, -478.0)

func _st_cold_upwalker(p: Player) -> void:
	_lowe_foe_stage(p, "upwalker", Vector3(790, 0, -430), "fall_forward", 0.9, 2.8, 5.0, 1.2, 1.0)

func _st_cold_unsung(p: Player) -> void:
	_lowe_foe_stage(p, "unsung", Vector3(906, 0, -484), "breath_in", 0.9, 2.0, 4.6, 1.0, 1.0)

## Where the Bearer stands for her shots: south of her, clear of the well-housing.
func _lv(p: Player, ph: int, atk: String, frac: float, gap: float, after := -1.0,
		cam := Vector3(5.0, 3.0, 2.0), dir := Vector2(1.0, 0.25)) -> Leadvoice:
	var l := _high_stage(p, "leadvoice", WELL, ph, atk, frac, gap, after, cam, dir, 56.0) as Leadvoice
	return l

func _st_leadvoice_sat(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	if _f == 3:
		_foe = _foe_near("leadvoice", WELL)
	var l := _foe as Leadvoice
	if l == null:
		return
	l.set_physics_process(false)
	if _f == 4:
		_place_player(p, l.global_position + Vector3(4.0, 0.3, 7.5), 0.0)   # (out of frame)
	for v in get_tree().current_scene.find_children("*", "FrostVeil", true, false):
		(v as Node3D).visible = false
	# from the south, outside the well's own stones: her side, the spring beyond her knees
	_cam.global_position = l.global_position + Vector3(0.6, 1.5, 5.2)
	_cam.look_at(l.global_position + Vector3(-0.8, 1.2, 0), Vector3.UP)
	_cam.fov = 52.0
	var d := l.global_position - p.global_position
	p.vis.rotation.y = atan2(-d.x, -d.z)
	if _f > 80:
		_freeze()

func _st_leadvoice_p1(p: Player) -> void:
	# the note gone by: the wall of rime standing between them
	_lv(p, 1, "held_note", 0.0, 6.5, 0.5, Vector3(7.0, 3.4, 0.0))

func _st_leadvoice_p2(p: Player) -> void:
	# the band lit all the way round, the Bearer stood inside it, close to her
	_lv(p, 2, "long_note", 0.92, 3.8, -1.0, Vector3(7.0, 7.5, 3.0))

var _lv_sing := false

func _st_leadvoice_p3(p: Player) -> void:
	var l := _lv(p, 3, "", 0.0, 3.9, -1.0, Vector3(4.2, 1.9, 2.4))
	if l == null:
		return
	if not _lv_sing and _clock - _t0 > 0.3:
		_lv_sing = true
		l.hp = l.max_hp * 0.25
		l._p3_hp = l.hp
		l.standing = true
		l.vis.idle(0.0)
		l.sing_zone.enabled = true
		_t1 = _clock
	# on her feet; the Bearer within reach of her voice; one word on the plate
	if _lv_sing and _clock - _t1 > 1.6:
		_freeze()

func _st_cold_release(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	if _f == 3:
		_foe = _foe_near("leadvoice", WELL)
	var l := _foe as Leadvoice
	if l == null:
		return
	if not l.released:
		l.target = p
		l._stand_done()
		_place_player(p, l.global_position + Vector3(-1.5, 0.3, 5.0), 0.0)
		l.phase = 3
		l.verses_sung = 3
		l._release()
		_t0 = _clock
	for v in get_tree().current_scene.find_children("*", "FrostVeil", true, false):
		(v as Node3D).visible = false
	var d := l.global_position - p.global_position
	p.vis.rotation.y = atan2(-d.x, -d.z)
	_cam.global_position = p.global_position + Vector3(-2.6, 1.9, 2.6)
	_cam.look_at(l.global_position.lerp(p.global_position, 0.45) + Vector3.UP * 0.9, Vector3.UP)
	_cam.fov = 54.0
	if _clock - _t0 > 4.0:
		_freeze()

func _st_cold_melt(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	_npc_talk_stage(p, "maren", 1, Vector3(-1.9, 0.6, 3.6))

# ------------------------------------------------------------------ the endings
## (coldwell, RIME, --flag=ks_leadvoice_released; docs/screens/ending_*.png):
## ending_choice, ending_outsong_sing, ending_outsong_coal, ending_outsong_spring,
## ending_kept, ending_kept_credits. And ending_credits (any area).
func _ending_begin(p: Player, which: String) -> EndingDirector:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	var ec: Node = null
	for c in get_tree().get_nodes_in_group("ending_choice"):
		ec = c
	if ec == null:
		return null
	if _f == 4:
		for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
			if e is Leadvoice:
				# as she is after the third verse
				(e as Leadvoice).released = true
				(e as Leadvoice).dead = true
				(e as Leadvoice).set_physics_process(false)
			elif e is Enemy and (e as Enemy).global_position.distance_to(ec.global_position) < 40.0:
				(e as Enemy).queue_free()
		for v in get_tree().current_scene.find_children("*", "FrostVeil", true, false):
			(v as Node3D).visible = false
		var spot: Vector3 = ec.to_global(Vector3(-ec.spread * 0.5 if which != "hearth_kept" else ec.spread * 0.5, 0.3, 0))
		var to: Vector3 = ec.spring_point() - spot
		_place_player(p, spot, atan2(-to.x, -to.z))
	if _f == 30 and which != "":
		ec.choose(which)
		_t0 = _clock
	var own_cam: bool = ec.director == null or not is_instance_valid(ec.director) or ec.director.cam == null
	_cam.current = own_cam
	if not own_cam:
		ec.director.cam.current = true   # (this harness takes the view every frame: hand it back)
	if own_cam and _f > 30:
		# the ending has given the camera back: the same view as ending_choice
		_cam.global_position = ec.to_global(Vector3(-2.8, 2.1, 2.9))
		_cam.look_at(ec.spring_point() + Vector3.UP * 0.9, Vector3.UP)
		_cam.fov = 60.0
	return ec.director if _f > 30 else null

## The two places to stand, and her sat across the spring.
func _st_ending_choice(p: Player) -> void:
	_ending_begin(p, "")
	var ec: Node = get_tree().get_first_node_in_group("ending_choice")
	if ec == null or _f < 5:
		return
	_cam.global_position = ec.to_global(Vector3(-2.8, 2.1, 2.9))   # (inside the ring of stones)
	_cam.look_at(ec.spring_point() + Vector3.UP * 0.9, Vector3.UP)
	_cam.fov = 60.0
	if _f > 70:
		_freeze()

func _ending_at(p: Player, which: String, beat: String, plus: float) -> void:
	var d := _ending_begin(p, which)
	if d == null:
		return
	if not (beat in d.beats) and not StateDirector.transitioning:
		d._t += 0.35   # (the harness has not got all day: wind on to the beat)
	if beat in d.beats:
		if _t1 == 0.0:
			_t1 = _clock
		if _clock - _t1 >= plus:
			_freeze()

func _st_ending_outsong_sing(p: Player) -> void:
	_ending_at(p, "outsong", "sing", 6.0)

func _st_ending_outsong_coal(p: Player) -> void:
	_ending_at(p, "outsong", "coal", 0.9)

func _st_ending_outsong_wave(p: Player) -> void:
	_ending_at(p, "outsong", "coal", 4.6)

func _st_ending_outsong_spring(p: Player) -> void:
	_ending_at(p, "outsong", "walk", 1.5)

func _st_ending_kept(p: Player) -> void:
	_ending_at(p, "hearth_kept", "sit", 3.5)

func _st_ending_kept_credits(p: Player) -> void:
	var d := _ending_begin(p, "hearth_kept")
	if d != null and not ("credits" in d.beats) and not StateDirector.transitioning:
		d._t += 0.35
	if d != null and d.credits != null and is_instance_valid(d.credits):
		if _t1 == 0.0:
			_t1 = _clock
			d.credits.show_at(13.0)
			d._cam_t = d._cam_time * 0.8   # (and the camera most of the way back)
		if _clock - _t1 > 1.5:
			_freeze()

## The Strand at Saltfell in spring (saltfell_steading, --flag=ending_outsong).
func _st_ending_strand(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	if _f == 3:
		_place_player(p, _ground(-6.0, 57.0) + Vector3.UP * 0.1, deg_to_rad(200))
	if _f > 3:
		for hud in get_tree().get_nodes_in_group("hud"):
			(hud as CanvasLayer).visible = false
		_frame(p.global_position, p.vis, Vector3(-2.4, 1.5, -6.4), 1.2, 56.0)
	if _f > 70:
		_freeze()

## Two masks on the low pegs (saltfell_steading, --flag=ending_outsong).
func _st_ending_pegs(p: Player) -> void:
	if _f == 2:
		_quiet_titles()
	_quiet_card()
	if _f == 3:
		_place_player(p, Vector3(1.6, _ground(1.6, -23.6, 30.0).y + 0.2, -23.6), PI)
	if _f > 3:
		for hud in get_tree().get_nodes_in_group("hud"):
			(hud as CanvasLayer).visible = false
		_cam.global_position = Vector3(2.4, p.global_position.y + 1.25, -22.6)
		_cam.look_at(Vector3(2.9, p.global_position.y + 1.05, -20.75), Vector3.UP)
		_cam.fov = 50.0
	if _f > 70:
		_freeze()

func _st_ending_credits(_p: Player) -> void:
	if _f == 3:
		var c := CreditsUI.new()
		c.over_world = false
		c.name = "ShotCredits"
		get_tree().root.add_child(c)
	if _f == 8:
		(get_tree().root.get_node("ShotCredits") as CreditsUI).show_at(12.5)
	if _f > 20:
		_freeze()

