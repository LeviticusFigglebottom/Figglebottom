class_name EncShots
extends Node
## Staged encounter screenshots (docs/screens/enc_*.png). Shot adds this node
## when the command line carries --enc-shot=<stage>; it stages the beat in the
## live area, frames a camera, freezes the tree on the beat and saves.
##   tools/shot.sh docs/screens/enc_bearer_idle.png --area=saltfell_steading \
##       --state=thaw --enc-shot=bearer_idle
## Stages: bearer_idle, bearer_roll, bearer_drink, oarsman_stroke, hound_lunge,
## netmender_p1, netmender_p2, netmender_p3, ingra_thaw, release.

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
	if not get_tree().paused:
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

func _freeze(frames := 5) -> void:
	get_tree().paused = true
	_hold = frames

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
func _face_off(p: Player, id: String, gap: float) -> Enemy:
	if _f == 3:
		var e := _first_foe(id) if Game.current_area != null else null
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
