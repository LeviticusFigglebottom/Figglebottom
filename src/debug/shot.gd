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
##   --shot-nohud           hide every CanvasLayer (HUD, zone titles) for art comparisons
##   --gfx=0|1|2            force the graphics tier (lavapipe defaults to 1: no SDFGI/SSIL/SSR)
##   --hearth-frame=N       rest at the first hearth on frame N; with
##   --shot-seq=s1,s2,...   captures PATH_0.png.. that many seconds after it
##   --hearth-toggle        make that rest turn the world (THAW <-> RIME)

var _shot_path := ""
var _frames_left := -1
var _quit_after := -1
var _cam_spec := ""
var _settle := 10         # frames between spawning the shot camera and capture
var _open_pack := false
var _no_hud := false
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
		elif arg == "--shot-nohud":
			_no_hud = true
		elif arg.begins_with("--gfx="):
			EnvRig.graphics_quality = clampi(int(arg.get_slice("=", 1)), 0, 2)
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

## Quit once the renderer has stopped compiling pipelines. Leaving while a
## background compile is still queued deadlocks the engine's shutdown under a
## software driver (lavapipe takes seconds per pipeline), and the wrapper then
## sits out its whole timeout. A few quiet seconds cost nothing.
const QUIET_SECONDS := 4.0
var _leaving := false
var _quiet_t := 0.0
var _pipelines := -1

## What the frame just captured cost (for before/after tables).
func _print_stats(path: String) -> void:
	print("[shot] stats %s draw_calls=%d primitives=%d objects=%d" % [path.get_file(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])

func _leave() -> void:
	_leaving = true
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

func _wait_quiet(dt: float) -> void:
	var n := 0
	for k in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		n += RenderingServer.get_rendering_info(k)
	if n != _pipelines:
		_pipelines = n
		_quiet_t = 0.0
	_quiet_t += dt
	if _quiet_t >= QUIET_SECONDS:
		get_tree().quit()

func _process(_d: float) -> void:
	if _leaving:
		_wait_quiet(_d)
		return
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
				_leave()
	if _shot_path == "" or _frames_left < 0 or not _seq.is_empty():
		return
	if _no_hud:
		for cl in get_tree().root.find_children("*", "CanvasLayer", true, false):
			(cl as CanvasLayer).visible = false
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
			_print_stats(mpath)
			_multi_i += 1
			_multi_step = 0
			if _multi_i >= _multi.size():
				AudioDirector.shutdown()
				_leave()
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
		_print_stats(_shot_path)
		_leave()

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
##   journal: the Pack opened at the Journal, threads begun, one pinned
##   pack / pack_songs / pack_armour: the Pack's other leaves, stocked
##   belt: the HUD with a full belt and the pinned objective
##   map / map_zoom: the Map, the whole highland and one region
##   swing / foe_death / boss: character close-ups (ADR 0004), see _char_stage
func _stage_tick() -> void:
	_stage_frame += 1
	var p: Player = Game.player
	if _stage in ["swing", "foe_death", "boss"] or _stage.begins_with("bearer_"):
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
		"ui_tour":
			# every UI photograph in one boot (the world is slow to build under
			# a software renderer): OUT_belt, _pack, _songs, _armour, _journal,
			# _map, _map_zoom. Run with --shot-frames=90.
			var names := ["belt", "pack", "songs", "armour", "journal", "map", "map_zoom"]
			if _stage_frame == 8:
				_stock_pack(p)
				_walked_world()
				for f in ["ks_ingra_met", "ks_ingra_rye_found", "ks_brede_met", "ks_knucklebones_found", "ks_horn_wellhead"]:
					World.set_flag(f)
				Journal.set_pin("ingra_rye")
			var k := (_stage_frame - 18) / 9
			if _stage_frame >= 18 and (_stage_frame - 18) % 9 == 0 and k < names.size():
				get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_shot_path.get_basename(), names[k]])
				print("[shot] saved %s_%s.png" % [_shot_path.get_basename(), names[k]])
				var inv: InventoryUI = get_tree().get_first_node_in_group("inventory_ui")
				match names[k]:
					"belt": InventoryUI.open_for(p, "pack")
					"pack": inv._show_tab("songs")
					"songs": inv._show_tab("armour")
					"armour": inv._show_tab("journal")
					"journal": inv._show_tab("map")
					"map": (inv.get_meta("map_view") as MapView).show_region(Game.current_area_id)
		"keepsakes", "journal":
			# a journey part-way along: both threads started, one further on,
			# one finished thread folded under Done
			if _stage_frame == 8:
				for f in ["ks_ingra_met", "ks_ingra_rye_found", "ks_brede_met", "ks_knucklebones_found", "ks_horn_wellhead"]:
					World.set_flag(f)
				World.set_area_flag("saltfell_steading", "lit_hs_boat_shed")
				Journal.set_pin("ingra_rye")
				InventoryUI.open_for(p, "journal")
		"pack", "pack_songs", "pack_armour":
			# the Pack with a traveller's worth in it
			if _stage_frame == 8:
				_stock_pack(p)
				InventoryUI.open_for(p, {"pack": "pack", "pack_songs": "songs", "pack_armour": "armour"}[_stage])
		"belt":
			# the HUD with a full belt, a song attuned and a thread pinned
			if _stage_frame == 8:
				_stock_pack(p)
				World.set_flag("ks_ingra_met")
				Journal.set_pin("ingra_rye")
		"map", "map_zoom":
			# the Map after three regions: two released, the third walked into
			if _stage_frame == 8:
				_walked_world()
				World.set_flag("ks_ingra_met")
				Journal.set_pin("ingra_rye")
				InventoryUI.open_for(p, "map")
			if _stage_frame == 12 and _stage == "map_zoom":
				for c in get_tree().get_nodes_in_group("inventory_ui"):
					var mv := c.get_meta("map_view", null) as MapView
					if mv != null:
						mv.show_region(Game.current_area_id)
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

## A journey three regions along, for the Map photographs: Saltfell and the
## Lowe released, Kettle Fjord just walked into.
func _walked_world() -> void:
	for a in ["saltfell_steading", "lowe_barrows", "kettle_fjord"]:
		MapState._mark("regions", a)
		for h in DB.area_def(a).get("hearths", []):
			if a != "kettle_fjord" or String(h["id"]) == "hs_landing_ice":
				MapState._mark("hearths", "%s/%s" % [a, h["id"]])
		for pl in MapState.places_def(a):
			MapState._mark("places", "%s/%s" % [a, pl["id"]])
	# (the flags only: the area on screen is left in the state it was built in)
	for a in ["saltfell_steading", "lowe_barrows"]:
		MapState._mark("veils", a)
		for h in DB.area_def(a).get("hearths", []):
			World.set_area_flag(a, "lit_" + String(h["id"]))
	World.set_area_flag("kettle_fjord", "lit_hs_landing_ice")
	World.last_hearth = {"area": "saltfell_steading", "hearth": "hs_salt_house"}

## A traveller's Pack for the UI photographs: arms on the belt, two songs,
## armour and a handful of goods.
func _stock_pack(p: Player) -> void:
	for id in ["hewing_blade", "spear", "bow", "maul", "turf_spade", "mend", "ember_throw", "long_note",
			"armour_traveller_coat", "armour_saltfell_oilskins", "armour_barrow_cloak",
			"item_net_float", "item_rye_sack", "ks_child_mask", "ks_knucklebones", "item_orm_cord", "fostering_horn"]:
		p.inventory[id] = maxi(int(p.inventory.get(id, 0)), 1)
	p.inventory["arrows"] = 14
	p.inventory["bog_iron"] = 3
	for i in 4:
		p.set_hotbar_slot(i, ["hewing_blade", "spear", "bow", "maul"][i])
	p.set_hotbar_slot(4, "gourd")
	p.attune_song("mend")
	p.inventory_changed.emit()

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
	if _stage.begins_with("bearer_"):
		_bearer_stage(p, foe)
		return
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

## The Bearer's own strikes on a foe (the combat clips, ADR 0011), frozen a
## few ticks into the active window so the trail and the hit both show:
##   bearer_light1 / bearer_light2 / bearer_heavy / bearer_sprint
##   bearer_bow (the full draw, held) / bearer_hold (the weapon carried, no foe)
## --shot-weapon=<id> arms him first; --shot-beat=<s> moves the capture
## (seconds after the windup ends; negative looks at the wind-up).
func _bearer_stage(p: Player, foe: Enemy) -> void:
	foe.set_physics_process(false)   # the foe stands and takes it
	if _stage_frame == 8:
		for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
			if e != foe and e is Node3D:
				(e as Node3D).visible = false   # its packmates would crowd the lens
	var beat := 0.04
	var wpn := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-beat="):
			beat = float(a.get_slice("=", 1))
		elif a.begins_with("--shot-weapon="):
			wpn = a.get_slice("=", 1)
	if _stage_frame == 12 and wpn != "":
		p.inventory[wpn] = 1
		p.equip_weapon(wpn)
	if _stage_frame == 30:
		p.sim_active = true
		match _stage:
			"bearer_light1":
				p._combo_i = 0
				p._chain_attack(false)
			"bearer_light2":
				p._combo_i = 1
				p._chain_attack(false)
			"bearer_heavy":
				p._chain_attack(true)
			"bearer_sprint":
				p._sprint_attack()
			"bearer_bow":
				# the draw, driven by hand (no key is held in a shot): nock,
				# pull, and hold at the cheek
				p.inventory["arrows"] = 12
				p.set_physics_process(false)
				p.vis.play("bow_draw", 0.1)
				p._nock_arrow(true)
			"bearer_hold":
				foe.visible = false   # the weapon carried, nobody to hit
	if _stage == "bearer_bow" or _stage == "bearer_hold":
		_frame_char_cam(p, foe)
		if _stage == "bearer_bow" and _stage_frame > 30 and p.vis.rig.action_time() > 0.74 and p.vis.current_clip() != "bow_hold":
			p.vis.play("bow_hold", 0.08)
		# (software frames in a full area take seconds each: wait on game time, not on many frames)
		var settled := (_stage == "bearer_hold" and p.vis.brand != null and p.vis.brand.lit > 0.98) \
				or (_stage == "bearer_bow" and p.vis.current_clip() == "bow_hold")
		if settled and not get_tree().paused and _stage_frame > 40:
			_hold_frames += 1
			if _hold_frames > 8:   # a few drawn frames so the string, flame and smoke are all up
				get_tree().paused = true
				_frames_left = mini(_frames_left, 4)
		return
	if _stage_frame >= 30:
		_frame_char_cam(p, foe)
		if p.state == Player.S.ATTACK and p.state_t >= float(p._atk["windup"]) + beat and not get_tree().paused:
			get_tree().paused = true
			_frames_left = mini(_frames_left, 4)

var _hold_frames := 0

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
	if _stage.begins_with("bearer_"):   # three-quarter, from behind the Bearer's sword arm
		cam.global_position = tgt + side * 3.3 - axis.normalized() * 1.3 + Vector3.UP * 0.45
	if _stage == "bearer_hold":   # the Bearer alone, from his front quarter, the light in frame
		tgt = p.global_position + Vector3.UP * 1.25
		cam.global_position = tgt + axis.normalized() * 2.9 + side * 2.2 + Vector3.UP * 0.25
	elif _stage == "bearer_bow":  # from ahead on his open side: stave, string, shaft and the drawing hand
		tgt = p.global_position + Vector3.UP * 1.3
		cam.global_position = tgt + side * 3.0 + axis.normalized() * 1.3 + Vector3.UP * 0.15
	cam.look_at(tgt, Vector3.UP)
	cam.fov = 48.0

func _exit_tree() -> void:
	AmbientLife._mote_tex = null
	FrostFX.clear_cache()
	EnvRig.active_instance = null
