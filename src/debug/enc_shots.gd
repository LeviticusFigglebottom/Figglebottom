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

func _process(_dt: float) -> void:
	if _done:
		return
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
