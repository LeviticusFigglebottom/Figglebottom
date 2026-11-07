extends Node3D
## Art pilot sandbox: shows the pilot assets in a lit corner of a steading.
## Run: godot --path . res://scenes/sandbox/art_pilot.tscn -- --shots
## With --shots it renders every camera in SHOTS to docs/screens/art_pilot_<name>.png and quits.
## Standalone on purpose: it touches no game systems, so the art pipeline can be judged alone.

const KIT := "res://assets/models/kit/"
const RIMEWALKER := "res://assets/models/enemies/rimewalker.glb"
const NETMENDER := "res://assets/models/bosses/netmender.glb"
const BLADE := "res://assets/models/weapons/hewing_blade.glb"

## name, camera position, look-at target, fov
const SHOTS := [
	["overview", Vector3(9.5, 4.2, 10.5), Vector3(-0.5, 1.0, -1.0), 50.0],
	["yard_eye", Vector3(4.5, 1.6, 6.5), Vector3(-1.5, 1.3, -2.0), 55.0],
	["hearthstone", Vector3(-1.4, 1.5, 2.7), Vector3(0.0, 0.5, 0.0), 40.0],
	["rimewalker", Vector3(-0.2, 1.35, 2.9), Vector3(2.2, 0.95, 1.5), 40.0],
	["blade", Vector3(2.0, 1.3, -2.3), Vector3(3.45, 0.95, -2.45), 35.0],
	["netmender", Vector3(-0.2, 2.2, 3.6), Vector3(-3.0, 1.6, -0.6), 45.0],
	["kit", Vector3(1.5, 2.0, 9.0), Vector3(-5.5, 0.9, 1.5), 50.0],
]

var _cam: Camera3D
var _sun: DirectionalLight3D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_kit()
	_build_characters()
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_set_shot(SHOTS[0])
	if "--shots" in OS.get_cmdline_user_args():
		_capture_all.call_deferred()


func _set_shot(s: Array) -> void:
	_cam.fov = s[3]
	_cam.position = s[1]
	_cam.look_at(s[2], Vector3.UP)


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screens"))
	# let animations advance into a readable pose and the fog/shadows settle
	for i in 45:
		await get_tree().process_frame
	for s in SHOTS:
		_set_shot(s)
		for i in 12:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "res://docs/screens/art_pilot_%s.png" % s[0]
		img.save_png(ProjectSettings.globalize_path(path))
		print("[shot] ", path)
	get_tree().quit()


func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.42, 0.55)
	sm.sky_horizon_color = Color(0.86, 0.66, 0.46)
	sm.ground_horizon_color = Color(0.45, 0.4, 0.33)
	sm.ground_bottom_color = Color(0.2, 0.18, 0.15)
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.58, 0.46)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.15
	env.fog_sun_scatter = 0.25
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0035
	env.volumetric_fog_albedo = Color(1.0, 0.85, 0.65)
	env.volumetric_fog_length = 40.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.78, 0.52)
	_sun.light_energy = 2.0
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 40.0
	_sun.light_volumetric_fog_energy = 0.6
	# low evening sun from the side so silhouettes and adze marks read
	_sun.rotation_degrees = Vector3(-14.0, 62.0, 0.0)
	add_child(_sun)


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	pm.subdivide_width = 1
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 512
	nt.height = 512
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	nt.noise = n
	var grad := Gradient.new()
	grad.set_color(0, Color(0.24, 0.24, 0.15))
	grad.set_color(1, Color(0.42, 0.38, 0.25))
	nt.color_ramp = grad
	mat.albedo_texture = nt
	mat.uv1_scale = Vector3(10, 10, 1)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)


func _place(path: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("art_pilot: missing " + path)
		return null
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)
	return n


func _build_kit() -> void:
	# a corner of a steading: longhouse side wall (3 bays) on the north, dry-stone yard
	# wall on the west, hearthstone in the yard, a fish rack by the wall
	for i in 3:
		_place(KIT + "kit_longhouse_wall_4m.glb", Vector3(-4.0 + 4.0 * i, 0, -4.0))
	for i in 3:
		_place(KIT + "kit_drystone_wall_4m.glb", Vector3(-6.4, 0, -1.6 + 4.0 * i), 90.0)
	_place(KIT + "kit_drystone_wall_4m.glb", Vector3(-4.4, 0, 10.0), 0.0)
	_place(KIT + "kit_hearthstone.glb", Vector3(0, 0, 0), 15.0)
	_place(KIT + "kit_drying_rack.glb", Vector3(-4.2, 0, 3.8), 90.0)
	_place(KIT + "kit_drying_rack.glb", Vector3(5.0, 0, -2.0), 10.0)


func _build_characters() -> void:
	var rw := _place(RIMEWALKER, Vector3(2.2, 0, 1.5), -35.0)
	if rw:
		_play(rw, "walk")
		_attach_blade(rw)
	var rw2 := _place(RIMEWALKER, Vector3(3.6, 0, -2.2), -70.0)
	if rw2:
		_play(rw2, "idle")
		_attach_blade(rw2)
	var nm := _place(NETMENDER, Vector3(-3.0, 0, -0.6), 35.0)
	if nm:
		_play(nm, "idle")


func _play(root: Node, clip: String) -> void:
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(clip):
		return
	var anim := ap.get_animation(clip)
	anim.loop_mode = Animation.LOOP_LINEAR
	ap.play(clip)


func _attach_blade(root: Node3D) -> void:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var bone := -1
	for i in skel.get_bone_count():
		# Godot sanitises "mixamorig:RightHand" to "mixamorig_RightHand"; match the suffix
		if skel.get_bone_name(i).ends_with("RightHand"):
			bone = i
	if bone < 0:
		push_warning("art_pilot: no RightHand bone")
		return
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(bone)
	skel.add_child(att)
	# Grip convention (docs/art/design/pilot.md): grip centre at origin, blade +Y, edge +Z.
	# Build the grip frame from the rest pose instead of magic angles, so it works on any
	# Tripo mixamo rig: fingers run hand->middle1, the blade leaves the fist on the thumb
	# side, and the edge faces the knuckles (finger direction).
	var hand_rest := skel.get_bone_global_rest(bone)
	var mid := _bone_local(skel, hand_rest, "RightHandMiddle1")
	var thumb := _bone_local(skel, hand_rest, "RightHandThumb1")
	var fingers := mid.normalized()
	var up := (thumb - fingers * thumb.dot(fingers)).normalized()
	var side := up.cross(fingers)
	var holder := Node3D.new()
	var s := skel.global_basis.get_scale().x / root.global_basis.get_scale().x
	holder.transform = Transform3D(Basis(side, up, fingers).scaled(Vector3.ONE / s), mid * 0.55)
	att.add_child(holder)
	var blade := load(BLADE) as PackedScene
	if blade:
		holder.add_child(blade.instantiate())


func _bone_local(skel: Skeleton3D, hand_rest: Transform3D, suffix: String) -> Vector3:
	for i in skel.get_bone_count():
		if skel.get_bone_name(i).ends_with(suffix):
			return hand_rest.affine_inverse() * skel.get_bone_global_rest(i).origin
	return Vector3(0, 0.08, 0)
