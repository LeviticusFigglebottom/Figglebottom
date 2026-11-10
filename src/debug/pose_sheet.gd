extends Node3D
## Pose sheet: one model repeated in a row, each copy frozen at a different
## time of one of its glb clips, so a text-prompt clip can be judged (and its
## start/contact/end sections read off) from a single image.
## Run: tools/shot.sh docs/screens/x.png --sandbox=pose_sheet --pose-model=res://...glb
##        --pose-clip=dodge_roll --pose-times=0,0.5,1,1.5 [--pose-yaw=90]

## Rig mode (the combat clips, tools/anim/sheets.sh): the Bearer as the game
## builds him (PlayerVisual: weapon, shield, clip set), frozen at 8 beats of a
## game clip's section: start, wind-up, contact, follow-through, end. The
## ribbon behind each blade is the sweep since the previous frame.
##   --pose-rig=bearer_traveller --pose-batch=attack_l1@hewing_blade,attack_h@greatblade
##   [--pose-yaw=150] [--pose-out=docs/screens] [--pose-whole]  (whole clip, evenly)
##   [--pose-zoom=5]  (that one beat, full frame)   clip@bare: empty hands
var _rig_model := ""
var _batch: Array = []
var _out_dir := "docs/screens"
var _whole := false
var _yaw := 150.0
var _stage: Node3D = null
var _item_yaw := 150.0
var _zoom := -1                # --pose-zoom=<cell 1..8>: that one beat, full frame

func _rig_args() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pose-rig="):
			_rig_model = a.get_slice("=", 1)
		elif a.begins_with("--pose-batch="):
			_batch = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--pose-out="):
			_out_dir = a.get_slice("=", 1)
		elif a == "--pose-whole":
			_whole = true
		elif a.begins_with("--pose-yaw="):
			_yaw = float(a.get_slice("=", 1))
		elif a.begins_with("--pose-zoom="):
			_zoom = int(a.get_slice("=", 1)) - 1
	return _rig_model != ""

func _rig_sheets() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.32, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -25, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.3
	cam.position = Vector3(0, 0.0, 12.0)
	if _zoom >= 0:   # the cell grid is 4 x 2, 2.35 m apart, rows at 0.25 and -2.45
		cam.size = 2.6
		cam.position = Vector3((_zoom % 4 - 1.5) * 2.35, (0.25 if _zoom < 4 else -2.45) + 1.05, 12.0)
	for item in _batch:
		# clip[@kit[@yaw]]
		var clip := String(item).get_slice("@", 0)
		var kit := String(item).get_slice("@", 1) if String(item).contains("@") else "hewing_blade"
		_item_yaw = float(String(item).get_slice("@", 2)) if String(item).count("@") >= 2 else _yaw
		if _stage != null:
			_stage.queue_free()
		_stage = Node3D.new()
		add_child(_stage)
		var tag := _foe_sheet(clip, kit) if _rig_model == "foe" else _rig_sheet(clip, kit)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/anim_%s_%s.png" % [_out_dir, tag, "sheet" if _zoom < 0 else "beat%d" % (_zoom + 1)]
		get_viewport().get_texture().get_image().save_png(path)
		print("[shot] ", path)
	get_tree().quit()

func _rig_sheet(clip: String, kit: String) -> String:
	var cols := 4
	var times: Array = []
	var tag := clip
	var info := ""
	for i in 8:
		var vis := PlayerVisual.new()
		_stage.add_child(vis)
		var bare := kit == "bare"
		if bare:
			kit = "hewing_blade"
		vis.build(kit, _rig_model)
		var w := {}
		for wid in DB.table("weapons"):
			var row = DB.table("weapons")[wid]
			if row is Dictionary and String(row.get("kit", "")) == kit:
				w = row
				break
		vis.apply_loadout(kit, not bool(w.get("two_handed", false)))
		if bare:   # clip@bare: empty hands (the ending beats)
			for m in [vis.weapon_mount, vis.shield_mount, vis.trail]:
				if m != null:
					(m as Node3D).visible = false
			kit = "bare"
		vis.set_physics_process(false)
		vis.rig.set_physics_process(false)
		vis.position = Vector3((i % cols - (cols - 1) * 0.5) * 2.35, 0.25 if i < cols else -2.45, 0)
		vis.rotation_degrees.y = _item_yaw
		if times.is_empty():
			var sec: Vector3 = vis.rig._section(clip)
			var s := sec.x
			var c := sec.y if sec.y > sec.x else lerpf(sec.x, sec.z, 0.5)
			var e := sec.z
			if _whole or sec.y <= sec.x:
				for k in 8:
					times.append(lerpf(s, e, k / 7.0))
			else:
				times = [s, lerpf(s, c, 0.4), lerpf(s, c, 0.75), c - 0.04, c, c + 0.05, c + 0.14, lerpf(c, e, 0.6)]
			var set_tag := vis.rig.clip_set
			tag = "%s_%s" % [kit, clip]   # one sheet per weapon, even where two share a class
			if set_tag == "":
				tag = clip
			if absf(_item_yaw - _yaw) > 1.0:
				tag += "_side"
			if _rig_model != "bearer_traveller":   # an outfit's own sheet (POSE_RIG=bearer_fleece tools/anim/sheets.sh ...)
				tag = "%s_%s" % [_rig_model.trim_prefix("bearer_"), tag]
			info = "%s%s  [%s]  ->  %s   start %.2f  contact %.2f  end %.2f" % ["" if _rig_model == "bearer_traveller" else _rig_model + "  ",
					clip, kit, vis.rig.qualified(clip), sec.x, sec.y, sec.z]
		# the blade's sweep since the previous frame
		var ext := vis._trail_extents()
		if i > 0:
			var im := ImmediateMesh.new()
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
			for k in 9:
				vis.rig.freeze_at(clip, lerpf(float(times[i - 1]), float(times[i]), k / 8.0))
				var xf := vis.weapon_xform()
				im.surface_add_vertex(xf * Vector3(0, ext.x, 0))
				im.surface_add_vertex(xf * Vector3(0, ext.y, 0))
			im.surface_end()
			var mi := MeshInstance3D.new()
			mi.mesh = im
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = Color(1.0, 0.85, 0.35, 0.33)
			mi.material_override = mat
			_stage.add_child(mi)
		vis.rig.freeze_at(clip, float(times[i]))
		if clip in ["idle", "walk", "run"] and vis.rig._carry != "":
			vis.rig._carry_always = true   # locomotion: the arms-only carry layer shows
			vis.rig._push()
			vis.rig.advance(0.0)
		if clip in ["idle", "walk", "run"] and vis._has_carry:
			vis.set_process(false)   # locomotion: show the carry grip, not the fighting one
			vis.weapon_mount.transform = vis._grip_carry
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.95
		cm.bottom_radius = 0.95
		cm.height = 0.02
		disc.mesh = cm
		disc.position = vis.position - Vector3(0, 0.01, 0)
		_stage.add_child(disc)
		var lbl := Label3D.new()
		lbl.text = "%d  t=%.2f%s" % [i + 1, float(times[i]), "  CONTACT" if i == 4 and not _whole else ""]
		lbl.pixel_size = 0.0035
		lbl.position = vis.position + Vector3(-0.75, 2.2, 0.5)
		_stage.add_child(lbl)
	var head := Label3D.new()
	head.text = info
	head.pixel_size = 0.0035
	head.position = Vector3(0, -0.02, 1.0)
	_stage.add_child(head)
	return tag

## Foe mode (--pose-rig=foe --pose-batch=rimewalker@swipe,...): the foe as
## EnemyVisual builds it, at 8 beats of one attack's clip: start, risen,
## mid-hold, just before, CONTACT (the data windup), overshoot, follow, late.
## Writes anim_foe_<id>_<attack>_sheet.png.
func _foe_sheet(foe: String, attack: String) -> String:
	var cfg: Dictionary = DB.enemy(foe)
	var atk := {}
	for a in cfg.get("attacks", []):
		if String(a.get("id", "")) == attack:
			atk = a
	var times: Array = []
	var clip := String(atk.get("anim", attack))
	var info := ""
	for i in 8:
		var vis := EnemyVisual.new()
		_stage.add_child(vis)
		vis.build(cfg)
		vis.set_physics_process(false)
		if vis.quad != null:
			# quadrupeds: one cell per pose (the attack id is ignored)
			var names: Array = [""]
			var listed: Array = ["crouch", "launch", "lunge", "bite", "land", "recover", "bark", "hold", "flinch", "dead"]
			if vis.quad.poses.has("gore"):
				listed = ["lower", "drive", "gore", "rear", "launch", "leap", "land", "recover"]
			elif vis.quad.poses.has("paw_up"):   # the ram: butt, then (frost_ram@more) charge and kick
				listed = ["tuck", "drive", "butt", "land", "lower", "paw_up", "paw_back",
						"run", "skid", "shake_l", "kick_load", "kick", "flinch", "dead"]
			for pn0 in listed:
				if vis.quad.poses.has(pn0):
					names.append(pn0)
			vis.quad.pose_seq = {}
			vis.quad.set_physics_process(false)
			vis.position = Vector3((i % 4 - 1.5) * 2.35, 0.25 if i < 4 else -2.45, 0)
			vis.rotation_degrees.y = 100.0
			vis.scale = Vector3.ONE * minf(1.0, 1.1 / maxf(float(cfg.get("hurt_h", 1.0)), 0.5))
			if attack == "more":   # the poses past the first eight cells
				names = names.slice(7)
			var pn := String(names[i]) if i < names.size() else ""
			vis.quad.only(pn, 0.0)
			vis.quad._physics_process(1.0)
			var ql := Label3D.new()
			ql.text = pn if pn != "" else "stand"
			ql.pixel_size = 0.0035
			ql.position = vis.position + Vector3(-0.75, 2.2, 0.5)
			_stage.add_child(ql)
			continue
		if vis.rig == null:
			continue
		vis.rig.set_physics_process(false)
		# big bodies fit their cell (clip_meta models.<id>.sheet_h where the body is taller than its hurtbox)
		var sc: float = 1.8 / maxf(float(HumanoidLib.model_cfg(String(cfg.get("model", ""))).get("sheet_h", cfg.get("hurt_h", 1.8))), 1.8)
		vis.scale = Vector3.ONE * sc
		vis.position = Vector3((i % 4 - 1.5) * 2.35, 0.25 if i < 4 else -2.45, 0)
		vis.rotation_degrees.y = _item_yaw
		var alt := "@" + attack
		vis.rig.remap = {clip: alt} if vis.rig.has_clip(alt) else {}
		if times.is_empty():
			var sec: Vector3 = vis.rig._section(clip)
			var s := sec.x
			var c := sec.y
			var e := sec.z
			if c <= s:
				for k in 8:
					times.append(lerpf(s, e, k / 7.0))
			else:
				times = [s, s + minf(0.24, (c - s) * 0.5), lerpf(s, c, 0.6), c - 0.09, c, c + 0.07, c + 0.3, lerpf(c, e, 0.75)]
			info = "%s  %s  (%s)  ->  %s   windup %.2f  contact %.2f  end %.2f" % [foe, attack, clip,
					vis.rig.qualified(clip), float(atk.get("windup", 0.0)), c - s, e]
		vis.rig.freeze_at(clip, float(times[i]))
		if foe == "oarsman":   # the oar is the fight scene's; a stand-in shows its line
			var l := vis.bone_xform("mixamorig_LeftHand").origin
			var r := vis.bone_xform("mixamorig_RightHand").origin
			var im := ImmediateMesh.new()
			im.surface_begin(Mesh.PRIMITIVE_LINES)
			im.surface_add_vertex(l - (r - l).normalized() * 0.3)
			im.surface_add_vertex(r + (r - l).normalized() * 1.5)
			im.surface_end()
			var mi := MeshInstance3D.new()
			mi.mesh = im
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(0.7, 0.9, 1.0)
			mi.material_override = mat
			_stage.add_child(mi)
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.95
		cm.bottom_radius = 0.95
		cm.height = 0.02
		disc.mesh = cm
		disc.position = vis.position - Vector3(0, 0.01, 0)
		_stage.add_child(disc)
		var lbl := Label3D.new()
		lbl.text = "%d  t=%.2f%s" % [i + 1, float(times[i]), "  CONTACT" if i == 4 else ""]
		lbl.pixel_size = 0.0035
		lbl.position = vis.position + Vector3(-0.75, 2.2, 0.5)
		_stage.add_child(lbl)
	var head := Label3D.new()
	head.text = info
	head.pixel_size = 0.0035
	head.position = Vector3(0, -0.02, 1.0)
	_stage.add_child(head)
	return "foe_%s_%s" % [foe, attack]

func _ready() -> void:
	if _rig_args():
		_rig_sheets()
		return
	var model := ""
	var clip := "idle"
	var times: Array = [0.0]
	var yaw := 90.0
	var diss: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pose-model="):
			model = a.get_slice("=", 1)
		elif a.begins_with("--pose-clip="):
			clip = a.get_slice("=", 1)
		elif a.begins_with("--pose-times="):
			times = Array(a.get_slice("=", 1).split(",")).map(func(x): return float(x))
		elif a.begins_with("--pose-diss="):
			diss = Array(a.get_slice("=", 1).split(",")).map(func(x): return float(x))
		elif a.begins_with("--pose-yaw="):
			yaw = float(a.get_slice("=", 1))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.34, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.6
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 20)
	floor_mi.mesh = pm
	add_child(floor_mi)
	var n := times.size()
	var spacing := 1.5
	for i in n:
		var inst := (load(model) as PackedScene).instantiate() as Node3D
		add_child(inst)
		inst.position = Vector3((i - (n - 1) * 0.5) * spacing, 0, 0)
		inst.rotation_degrees.y = yaw
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap != null and ap.has_animation(clip):
			ap.play(clip)
			ap.seek(float(times[i]), true)
			ap.pause()
		if i < diss.size():   # preview the frost dissolve at this value
			FrostDissolve.apply(inst)
			RH.set_dissolve(inst, float(diss[i]))
		var lbl := Label3D.new()
		lbl.text = "%s %.2f" % [clip, float(times[i])]
		lbl.pixel_size = 0.004
		lbl.position = Vector3(0, 2.15, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lbl)
		lbl.global_position = inst.global_position + Vector3(0, 2.1, 0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	var w := n * spacing
	cam.position = Vector3(0, 1.1, maxf(w * 0.62, 3.5))
	cam.look_at(Vector3(0, 0.9, 0))
	cam.fov = 60.0
