extends Node
## Shot — headless screenshot + scripted-run harness.
## User args (after `--` on the command line):
##   --shot=PATH            capture viewport to PATH then quit
##   --shot-frames=N        frames to wait before capture (default 30)
##   --shot-cam=x,y,z,yaw_deg,pitch_deg[,fov]   spawn a free camera for the shot
##   --state=thaw|rime     force initial world state for the loaded area
##   --shot-pack         populate sample gear/relics and open InventoryUI
##   --quit-after=N         quit after N frames (no capture)

var _shot_path := ""
var _frames_left := -1
var _quit_after := -1
var _cam_spec := ""
var _open_pack := false
var _trigger_gourd := false
var _stage := ""          # "combat" | "death" | "rest": staged scenes
var _stage_frame := 0
var _frames_total := 0
var _foe: Node3D = null
var forced_state := ""   # read by boot/world setup
var forced_flags: Array = []   # world flags applied before the area builds
var _hearth_frame := -1
var _seq: Array = []      # seconds after the hearth trigger
var _seq_t := -1.0
var _seq_i := 0
var _multi: Array = []    # Array of [path, cam_spec]
var _multi_i := 0
var _multi_step := 0

func _ready() -> void:
	# the shot harness must keep ticking while the tree is paused (e.g. to
	# photograph the pause menu itself)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-frames="):
			_frames_left = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-cam="):
			_cam_spec = arg.get_slice("=", 1)
		elif arg == "--shot-pack":
			_open_pack = true
		elif arg == "--shot-gourd":
			_trigger_gourd = true
		elif arg.begins_with("--shot-stage="):
			_stage = arg.get_slice("=", 1)
		elif arg.begins_with("--state="):
			forced_state = arg.get_slice("=", 1)
		elif arg.begins_with("--flag="):
			forced_flags.append(arg.get_slice("=", 1))
		elif arg.begins_with("--quit-after="):
			_quit_after = int(arg.get_slice("=", 1))
		elif arg.begins_with("--hearth-frame="):
			_hearth_frame = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-seq="):
			for part in arg.get_slice("=", 1).split(","):
				_seq.append(float(part))
		elif arg == "--shot-seq-now":
			_seq_t = 0.0   # sequence clock runs from boot (filming the intro)
		elif arg.begins_with("--shot-multi="):
			for entry in arg.get_slice("=", 1).replace("+", ";").split(";"):
				if entry.contains("@"):
					_multi.append([entry.get_slice("@", 0), entry.get_slice("@", 1)])
			if not _multi.is_empty() and _shot_path == "":
				_shot_path = String(_multi[0][0])
				_cam_spec = String(_multi[0][1])
	if _shot_path != "" and _frames_left < 0:
		_frames_left = 30
	_frames_total = _frames_left

func _process(_d: float) -> void:
	if _quit_after > 0:
		if _quit_after == 2:
			AudioDirector.shutdown()
		_quit_after -= 1
		if _quit_after == 0:
			get_tree().quit()
	if _hearth_frame > 0:
		_hearth_frame -= 1
		if _hearth_frame == 0:
			_trigger_hearth()
	if _seq_t >= 0.0 and _seq_i < _seq.size():
		_seq_t += get_process_delta_time()
		if _seq_t >= float(_seq[_seq_i]):
			var img := get_viewport().get_texture().get_image()
			var p := _shot_path.get_basename() + "_%d.png" % _seq_i
			DirAccess.make_dir_recursive_absolute(p.get_base_dir())
			img.save_png(p)
			print("[shot] saved ", p)
			_seq_i += 1
			if _seq_i >= _seq.size():
				get_tree().quit()
	if _shot_path == "" or _frames_left < 0 or not _seq.is_empty():
		return
	if _cam_spec != "" and not _trigger_gourd and Game.player != null and Game.player.hurtbox != null:
		Game.player.hurtbox.monitorable = false
		Game.player.hurtbox.monitoring = false
	if _stage != "" and Game.player != null:
		_stage_tick()
	if _frames_left == 12 and _open_pack and Game.player != null:
		for wid in ["spear", "greatblade", "maul", "bow"]:
			Game.player.give_item(wid, 1)
		Game.player.inventory["bog_iron"] = 2
		Game.player.inventory["arrows"] = 12
		Game.player.set_hotbar_slot(1, "maul")
		Game.player.set_hotbar_slot(2, "spear")
		Game.player.set_hotbar_slot(3, "greatblade")
		InventoryUI.open_for(Game.player)
	if _frames_left == 120 and _trigger_gourd and Game.player != null:
		Game.player.global_position = Vector3(0.0, 0.2, 3.2)
		Game.player.velocity = Vector3.ZERO
		Game.player.hp = Game.player.max_hp * 0.55
		Game.player.health_changed.emit(Game.player.hp, Game.player.max_hp)
		Game.player.vis.rotation.y = PI
		Game.player.try_gourd()
		if _cam_spec == "":
			var ppos: Vector3 = Game.player.global_position
			_cam_spec = "%.2f,%.2f,%.2f,-8,-6,42" % [ppos.x - 0.28, ppos.y + 1.38, ppos.z + 2.25]
			_spawn_cam()
	if _trigger_gourd and Game.player != null and Game.player.state == Player.S.GOURD and Game.player.state_t >= 0.76:
		_frames_left = min(_frames_left, 2)
	if _frames_left == 10 and _cam_spec != "":
		_spawn_cam()
	if not _multi.is_empty() and _frames_left <= 8:
		if _multi_step == 0:
			_cam_spec = String(_multi[_multi_i][1])
			_spawn_cam()
			_multi_step = 1
			return
		elif _multi_step == 1:
			_multi_step = 2
			return
		else:
			var mpath := String(_multi[_multi_i][0])
			var mimg := get_viewport().get_texture().get_image()
			var mdir := mpath.get_base_dir()
			if mdir != "" and not DirAccess.dir_exists_absolute(mdir):
				DirAccess.make_dir_recursive_absolute(mdir)
			mimg.save_png(mpath)
			print("[shot] saved ", mpath)
			_multi_i += 1
			_multi_step = 0
			if _multi_i >= _multi.size():
				AudioDirector.shutdown()
				get_tree().quit()
			return
	if _frames_left == 2:
		AudioDirector.shutdown()
	_frames_left -= 1
	if _frames_left == 0:
		var img := get_viewport().get_texture().get_image()
		var dir := _shot_path.get_base_dir()
		if dir != "" and not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(_shot_path)
		print("[shot] saved ", _shot_path)
		get_tree().quit()

func _spawn_cam() -> void:
	var parts := _cam_spec.split(",")
	if parts.size() < 5:
		return
	var cam := get_tree().current_scene.find_child("ShotCam", false, false) as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ShotCam"
		get_tree().current_scene.add_child(cam)
	cam.global_position = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	cam.rotation_degrees = Vector3(float(parts[4]), float(parts[3]), 0.0)
	if parts.size() >= 6:
		cam.fov = float(parts[5])
	cam.current = true

func _trigger_hearth() -> void:
	var hearth = _first_hearth()
	if hearth == null or Game.player == null:
		push_warning("Shot: no hearth/player for hearth capture")
		return
	Game.player.global_position = hearth.respawn_point()
	Game.player.vis.rotation.y = PI
	Game.hearth_flow(hearth, Game.player)
	_seq_t = 0.0

func _first_hearth() -> Hearthstone:
	var hs := get_tree().get_nodes_in_group("hearths")
	return hs[0] if not hs.is_empty() else null

## Staged scenes for the screenshot set, counted in frames from boot.
##   combat: a rimewalker squares up to the Bearer mid-swing
##   death:  the Bearer falls; the capture lands on the death splash
##   rest:   the hearthstone menu opens on the levelling page
func _stage_tick() -> void:
	_stage_frame += 1
	var p: Player = Game.player
	match _stage:
		"combat":
			if _stage_frame == 6:
				var foe: Enemy = null
				for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
					if e is Enemy and not (e as Enemy).dead and (e as Enemy).can_process():
						foe = e
						break
				if foe != null:
					_foe = foe
					p.global_position = foe.global_position + Vector3(0.6, 0.1, 2.4)
					p.velocity = Vector3.ZERO
					foe.target = p
					foe._set_state(Enemy.ES.ALERT)
					p.invulnerable = true   # the photo needs the Bearer standing
			if _foe != null and is_instance_valid(_foe):
				var d: Vector3 = _foe.global_position - p.global_position
				var yaw := atan2(-d.x, -d.z)
				p.vis.rotation.y = yaw
				p.cam.yaw = yaw
			if _stage_frame == _frames_total - 26:
				p.sim_active = true
				p.try_attack(false)
		"death":
			if _stage_frame == 8:
				Game.set_warmth(57)
				p.take_hit(DamagePacket.new(99999, 0, null))
		"rest":
			if _stage_frame == 8:
				var h := _first_hearth()
				if h != null:
					p.global_position = h.respawn_point()
					p.velocity = Vector3.ZERO
					Game.set_warmth(140)
					h.zone.activated.emit(p)
			if _stage_frame == 14:
				for c in get_tree().root.get_children():
					if c is RestUI:
						(c as RestUI).choose(1)   # the levelling page

func _exit_tree() -> void:
	AmbientLife._mote_tex = null
	EnvRig.active_instance = null
