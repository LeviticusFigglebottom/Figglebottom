extends Node3D
## Pose sheet: one model repeated in a row, each copy frozen at a different
## time of one of its glb clips, so a text-prompt clip can be judged (and its
## start/contact/end sections read off) from a single image.
## Run: tools/shot.sh docs/screens/x.png --sandbox=pose_sheet --pose-model=res://...glb
##        --pose-clip=dodge_roll --pose-times=0,0.5,1,1.5 [--pose-yaw=90]

func _ready() -> void:
	var model := ""
	var clip := "idle"
	var times: Array = [0.0]
	var yaw := 90.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pose-model="):
			model = a.get_slice("=", 1)
		elif a.begins_with("--pose-clip="):
			clip = a.get_slice("=", 1)
		elif a.begins_with("--pose-times="):
			times = Array(a.get_slice("=", 1).split(",")).map(func(x): return float(x))
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
