extends Node
## Shot — headless screenshot + scripted-run harness.
## User args (after `--` on the command line):
##   --shot=PATH            capture viewport to PATH then quit
##   --shot-frames=N        frames to wait before capture (default 30)
##   --shot-cam=x,y,z,yaw_deg,pitch_deg[,fov]   spawn a free camera for the shot
##   --shot-settle=N        spawn that camera N frames before capture (default 10);
##                          real GPUs need longer for SDFGI / volumetric fog to settle
##   --shot-quality=0|1|2   force the graphics tier (default: auto, 2 on a GPU, 1 on lavapipe)
##   --state=thaw|rime     force initial world state for the loaded area
##   --shot-pack         populate sample gear/relics and open InventoryUI
##   --quit-after=N         quit after N frames (no capture)
##   --hearth-frame=N       rest at the first hearth on frame N; with
##   --shot-seq=s1,s2,...   captures PATH_0.png.. that many seconds after it
##   --hearth-toggle        make that rest turn the world (THAW <-> RIME)

var _shot_path := ""
var _frames_left := -1
var _quit_after := -1
var _cam_spec := ""
var _settle := 10         # frames between spawning the shot camera and capture
var _open_pack := false
var _trigger_gourd := false
var _stage := ""          # "combat" | "death" | "rest" | "swing" | "foe_death" | "boss"
var _stage_frame := 0
var _frames_total := 0
var _foe: Node3D = null
var forced_state := ""   # read by boot/world setup
var forced_flags: Array = []   # world flags applied before the area builds
var _hearth_frame := -1
var _hearth_choice := "auto"   # --hearth-toggle: turn the world even if uncleared (wave shots)
var _seq: Array = []      # seconds after the hearth trigger
var _seq_t := -1.0
var _seq_i := 0
var _multi: Array = []    # Array of [path, cam_spec]
var _multi_i := 0
var _multi_step := 0
var _enc: EncShots = null   # staged encounter shots (src/debug/enc_shots.gd)

func _ready() -> void:
	# the shot harness must keep ticking while the tree is paused (e.g. to
	# photograph the pause menu itself)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--shot-frames="):
			_frames_left = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shot-quality="):
			# set before the world builds its EnvRig, which reads the static tier
			EnvRig.set_graphics_quality(int(arg.get_slice("=", 1)))
		elif arg.begins_with("--shot-settle="):
			_settle = maxi(int(arg.get_slice("=", 1)), 3)
		elif arg.begins_with("--shot-cam="):
			_cam_spec = arg.get_slice("=", 1)
		elif arg == "--shot-pack":
			_open_pack = true
		elif arg == "--shot-gourd":
			_trigger_gourd = true
		elif arg.begins_with("--shot-stage="):
			_stage = arg.get_slice("=", 1)
		elif arg.begins_with("--enc-shot="):
			_enc = EncShots.new()
			_enc.stage = arg.get_slice("=", 1)
		elif arg.begins_with("--state="):
			forced_state = arg.get_slice("=", 1)
		elif arg.begins_with("--flag="):
			forced_flags.append(arg.get_slice("=", 1))
		elif arg.begins_with("--quit-after="):
			_quit_after = int(arg.get_slice("=", 1))
		elif arg.begins_with("--hearth-frame="):
			_hearth_frame = int(arg.get_slice("=", 1))
		elif arg == "--hearth-toggle":
			_hearth_choice = "toggle"
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
	if _enc != null:
		_enc.path = _shot_path
		add_child(_enc)
		_shot_path = ""   # the encounter stage saves on its own beat
		return
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
	if _frames_left == _settle and _cam_spec != "":
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
	if _cam_spec != "":
		_spawn_cam()
	Game.hearth_flow(hearth, Game.player, _hearth_choice)
	_seq_t = 0.0

func _first_hearth() -> Hearthstone:
	var hs := get_tree().get_nodes_in_group("hearths")
	return hs[0] if not hs.is_empty() else null

## Staged scenes for the screenshot set, counted in frames from boot.
##   combat: a rimewalker squares up to the Bearer mid-swing
##   death:  the Bearer falls; the capture lands on the death splash
##   rest:   the hearthstone menu opens on the levelling page
##   dialogue_ingra: Ingra's audience, framed over the Bearer's shoulder
##   keepsakes: the Pack opened at the Keepsakes leaf, two threads begun
##   swing / foe_death / boss: character close-ups (ADR 0004), see _char_stage
func _stage_tick() -> void:
	_stage_frame += 1
	var p: Player = Game.player
	if _stage in ["swing", "foe_death", "boss"]:
		_char_stage(p)
		return
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
			# freeze on the full splash: headless frames are slower than the
			# respawn timer, so a frame count alone lands after the rise
			if _stage_frame > 8 and not get_tree().paused:
				var hud := get_tree().get_first_node_in_group("hud")
				if hud != null and hud.splash.modulate.a >= 0.99:
					get_tree().paused = true
					_frames_left = mini(_frames_left, 4)
		"dialogue_ingra":
			# Ingra at her tally in the yard, mid-errand: her fourth line
			if _stage_frame == 8:
				for n in get_tree().current_scene.find_children("*", "NPC", true, false):
					if (n as NPC).npc_id == "steward_ingra":
						var npc := n as NPC
						var fwd := -npc.global_transform.basis.z
						fwd.y = 0.0
						p.global_position = npc.global_position + fwd.normalized() * 2.2
						p.velocity = Vector3.ZERO
						npc._on_talk(p)
						var side := fwd.normalized().cross(Vector3.UP)
						var cam := Camera3D.new()
						cam.name = "ShotCam"
						get_tree().current_scene.add_child(cam)
						var mid := (p.global_position + npc.global_position) * 0.5
						cam.global_position = mid + side * 3.4 + fwd.normalized() * 0.6 + Vector3.UP * 1.9
						cam.look_at(mid + Vector3.UP * 1.1, Vector3.UP)
						cam.fov = 50.0
						cam.current = true
			if _stage_frame == 12:
				for c in get_tree().root.get_children():
					if c is DialogueUI:
						for k in 3:
							(c as DialogueUI).advance()
		"hud":
			# the HUD at rest, with an area card held up for the photograph
			if _stage_frame == 8:
				Game.title_card.emit("THE STRAND", 120.0)
		"keepsakes":
			# a journey part-way along: both threads started, one further on
			if _stage_frame == 8:
				for f in ["ks_ingra_met", "ks_ingra_rye_found", "ks_ingra_rye", "ks_brede_met", "ks_brede_float_found"]:
					World.set_flag(f)
				InventoryUI.open_for(p, "keepsakes")
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

## Character close-ups, side-on, captured on a gameplay beat rather than a
## frame count:
##   swing:     a rimewalker faces the Bearer and attacks; the capture is the
##              frame its data windup ends (the clip's contact frame)
##   foe_death: the same foe dies; capture once the death clip has played
##   boss:      the first boss, framed in its arena
func _char_stage(p: Player) -> void:
	if _stage_frame == 6:
		for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
			var en := e as Enemy
			if en == null or en.dead or not en.can_process():
				continue
			if bool(en.cfg.get("is_boss", false)) == (_stage == "boss"):
				_foe = en
				break
		if _foe == null:
			push_warning("Shot: no foe for stage %s" % _stage)
			_frames_left = 1
			return
		p.invulnerable = true
		p.velocity = Vector3.ZERO
		if _stage != "boss":
			var fwd := -(_foe as Enemy).vis.global_transform.basis.z
			fwd.y = 0.0
			p.global_position = _foe.global_position + fwd.normalized() * 1.9 + Vector3.UP * 0.1
		_frames_total = _frames_left
	if _foe == null or not is_instance_valid(_foe):
		return
	var foe := _foe as Enemy
	if _stage != "boss":
		var d := foe.global_position - p.global_position
		p.vis.rotation.y = atan2(-d.x, -d.z)
		foe.vis.rotation.y = atan2(d.x, d.z)
		foe.target = p
	if _stage_frame == 30:
		match _stage:
			"swing":
				foe._begin_attack((foe.cfg["attacks"] as Array)[0])
			"foe_death":
				foe._die()
		_frame_char_cam(p, foe)
	if _stage_frame > 30:
		_frame_char_cam(p, foe)
		var ready := false
		match _stage:
			"swing":
				ready = foe.state == Enemy.ES.ATTACK and foe.state_t >= float(foe._atk["windup"])
			"foe_death":
				# on the clip's own clock (frames render slower than game time)
				ready = foe.dead and (foe.vis.rig == null or foe.vis.rig.action_time() >= 1.45)
			"boss":
				ready = _stage_frame > 60
		if ready and not get_tree().paused:
			# freeze on the beat: headless frames render slower than physics
			# ticks, so grab only once the paused pose has been drawn
			get_tree().paused = true
			_frames_left = mini(_frames_left, 4)

func _frame_char_cam(p: Player, foe: Enemy) -> void:
	var cam := get_tree().current_scene.find_child("ShotCam", false, false) as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "ShotCam"
		get_tree().current_scene.add_child(cam)
		cam.current = true
	var h := maxf(float(foe.cfg.get("hurt_h", 1.6)), 1.2)
	if _stage == "boss":
		var fwd := -foe.vis.global_transform.basis.z
		fwd.y = 0.0
		var side := fwd.normalized().cross(Vector3.UP)
		var tgt := foe.global_position + Vector3.UP * h * 0.6
		cam.global_position = tgt + fwd.normalized() * h * 2.4 + side * h * 1.0 + Vector3.UP * h * 0.15
		cam.look_at(tgt, Vector3.UP)
		cam.fov = 55.0
		return
	var mid := (p.global_position + foe.global_position) * 0.5
	var axis := foe.global_position - p.global_position
	axis.y = 0.0
	var side := axis.normalized().cross(Vector3.UP)
	var tgt := mid + Vector3.UP * 0.95
	cam.global_position = tgt + side * 3.6 + Vector3.UP * 0.35
	cam.look_at(tgt, Vector3.UP)
	cam.fov = 48.0

func _exit_tree() -> void:
	AmbientLife._mote_tex = null
	FrostFX.clear_cache()
	EnvRig.active_instance = null
