extends Node3D
## Art lineup sandbox: every slice-tier Tripo hero side by side at true scale, animated,
## under the warm low THAW sun, plus a landmark yard and a carried-items table.
## Run: godot --path . res://scenes/sandbox/art_lineup.tscn -- --shots
## With --shots it renders every camera in SHOTS to docs/screens/art_lineup_<name>.png and quits.
## Standalone on purpose (like art_pilot): no game systems, so the art can be judged alone.

const M := "res://assets/models/"
const BLADE := M + "weapons/hewing_blade.glb"
const SHIELD := M + "weapons/saltfell_shield.glb"

## path, design height (m, for the ground tick), clip, x position in the row.
## The GLBs are already scaled to their design size; the height is only drawn as a marker.
const CHARACTERS := [
	[M + "characters/bearer_traveller.glb", 1.8, "walk", -5.4, true],
	[M + "characters/bearer_oilskins.glb", 1.8, "idle", -4.2, true],
	[M + "npcs/ingra.glb", 1.7, "idle", -3.0, false],
	[M + "npcs/brede.glb", 1.8, "walk", -1.8, false],
	[M + "enemies/rimewalker.glb", 1.8, "walk", -0.4, false],
	[M + "enemies/oarsman.glb", 1.9, "idle", 1.0, false],
	[M + "enemies/hearthhound.glb", 0.8, "walk", 2.6, false],
	[M + "bosses/netmender.glb", 3.2, "idle", 5.2, false],
]

## path, position, yaw (landmark yard, behind the row at z < -4)
const LANDMARKS := [
	[M + "landmarks/lm_doorpost.glb", Vector3(-9.5, 0, -10.0), 15.0],
	[M + "landmarks/lm_long_hearth.glb", Vector3(-1.0, 0, -11.0), 90.0],
	[M + "landmarks/lm_brede_boat.glb", Vector3(9.5, 0, -10.5), -25.0],
	[M + "landmarks/lm_frost_veil_net.glb", Vector3(-5.5, 0, -16.5), 0.0],
	[M + "landmarks/lm_tide_wall.glb", Vector3(6.0, 0, -19.0), 90.0],
	[M + "landmarks/lm_standing_stone.glb", Vector3(-12.5, 0, -15.5), 10.0],
	[M + "kit/kit_longhouse_wall_4m.glb", Vector3(0.5, 0, -17.3), 0.0],
	[M + "landmarks/lm_mask_pegs.glb", Vector3(0.5, 0.9, -17.05), 0.0],
	[M + "kit/kit_hearthstone.glb", Vector3(-6.0, 0, -7.0), 15.0],
]

## carried items laid on a bench to the right of the row: path, position, rotation (deg)
const ITEMS := [
	[BLADE, Vector3(9.0, 0.72, 1.0), Vector3(0, 0, -90)],
	[SHIELD, Vector3(10.0, 0.72, 0.9), Vector3(-90, 0, 0)],
	[M + "weapons/mending_needle.glb", Vector3(9.0, 0.72, 1.35), Vector3(0, 0, -90)],
	[M + "props/fostering_horn.glb", Vector3(9.0, 0.72, 0.55), Vector3.ZERO],
	[M + "props/gourd.glb", Vector3(9.5, 0.72, 0.5), Vector3.ZERO],
]

## name, camera position, look-at target, fov
const SHOTS := [
	["characters", Vector3(0.0, 1.6, 8.6), Vector3(0.0, 1.15, 0.0), 58.0],
	["characters_34", Vector3(-8.5, 1.6, 6.0), Vector3(0.5, 1.0, 0.0), 50.0],
	["heroes_close", Vector3(-3.6, 1.45, 3.4), Vector3(-3.6, 1.0, 0.0), 50.0],
	["enemies_close", Vector3(2.6, 1.7, 5.2), Vector3(2.6, 1.2, 0.0), 55.0],
	["landmarks", Vector3(-1.5, 6.5, -1.5), Vector3(-1.0, 1.0, -13.0), 62.0],
	["landmarks_eye", Vector3(7.0, 1.7, -4.5), Vector3(-3.0, 1.6, -14.0), 60.0],
	["mask_pegs", Vector3(0.5, 1.6, -13.8), Vector3(0.5, 1.4, -17.0), 50.0],
	["items", Vector3(9.6, 1.45, 2.3), Vector3(9.5, 0.75, 0.9), 40.0],
]

var _cam: Camera3D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_characters()
	_build_landmarks()
	_build_items()
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
	# let clips advance into a readable pose and the fog/shadows settle
	for i in 50:
		await get_tree().process_frame
	for s in SHOTS:
		_set_shot(s)
		for i in 12:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "res://docs/screens/art_lineup_%s.png" % s[0]
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
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.58, 0.46)
	env.fog_density = 0.003
	env.fog_sky_affect = 0.15
	env.fog_sun_scatter = 0.25
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.003
	env.volumetric_fog_albedo = Color(1.0, 0.85, 0.65)
	env.volumetric_fog_length = 40.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	# STYLE.md THAW sun: low amber (1.0, .78, .52), long shadows
	sun.light_color = Color(1.0, 0.78, 0.52)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	sun.light_volumetric_fog_energy = 0.6
	# low and from the front-left so masks and garments read in the row shot
	sun.rotation_degrees = Vector3(-16.0, -35.0, 0.0)
	add_child(sun)


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	nt.noise = n
	var grad := Gradient.new()
	grad.set_color(0, Color(0.24, 0.24, 0.15))
	grad.set_color(1, Color(0.42, 0.38, 0.25))
	nt.color_ramp = grad
	mat.albedo_texture = nt
	mat.uv1_scale = Vector3(14, 14, 1)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


func _place(path: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("art_lineup: missing " + path)
		return null
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	return node


func _build_characters() -> void:
	for c in CHARACTERS:
		var root := _place(c[0], Vector3(c[3], 0, 0))
		_height_tick(Vector3(c[3] + (1.0 if c[1] > 2.5 else 0.5), 0, 0), c[1])
		if root == null:
			continue
		_play(root, c[2])
		if c[4]:
			_attach(root, "RightHand", BLADE, false)
			_attach(root, "LeftForeArm", SHIELD, true)


## a thin pole at the design height beside each character, so true scale is checkable by eye
func _height_tick(pos: Vector3, h: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, h, 0.03)
	mi.mesh = bm
	mi.position = pos + Vector3(0, h * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.86, 0.78)
	mi.material_override = mat
	add_child(mi)


func _build_landmarks() -> void:
	for l in LANDMARKS:
		_place(l[0], l[1], l[2])


func _build_items() -> void:
	var bench := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.7, 1.4)
	bench.mesh = bm
	bench.position = Vector3(9.5, 0.35, 0.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.27, 0.2)
	mat.roughness = 0.9
	bench.material_override = mat
	add_child(bench)
	for it in ITEMS:
		var node := _place(it[0], it[1])
		if node:
			node.rotation_degrees = it[2]


func _play(root: Node, clip: String) -> void:
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	if not ap.has_animation(clip):
		clip = "idle" if ap.has_animation("idle") else ap.get_animation_list()[0]
	ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	ap.play(clip)


## Bone attachment, same grip convention as art_pilot._attach_blade(): grip at origin,
## blade +Y, edge +Z; the frame is built from the rest pose (hand->Middle1 = fingers).
## A shield goes on the forearm, face out (+Z of the shield GLB faces away from the arm).
func _attach(root: Node3D, bone_suffix: String, path: String, is_shield: bool) -> void:
	var skel := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or not ResourceLoader.exists(path):
		return
	var bone := _bone(skel, bone_suffix)
	if bone < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(bone)
	skel.add_child(att)
	var s := skel.global_basis.get_scale().x / root.global_basis.get_scale().x
	var holder := Node3D.new()
	var rest := skel.get_bone_global_rest(bone)
	if is_shield:
		# forearm bone runs elbow->wrist along +Y; strap the board to the outside of the arm
		var hand := _local(skel, rest, "LeftHand")
		var along := hand.normalized()
		var out := (rest.basis.inverse() * Vector3(-1, 0, 0)).normalized()
		out = (out - along * out.dot(along)).normalized()
		var up := out.cross(along).normalized()
		holder.transform = Transform3D(Basis(along, up, out).scaled(Vector3.ONE / s), hand * 0.55 + out * 0.06 * s)
	else:
		# Tripo's T-pose rigs rest palms-forward, so the thumb axis points up, not forward.
		# Point the blade along the character's forward axis instead (made perpendicular
		# to the fingers), which stays forward when the arm hangs in idle and walk.
		var mid := _local(skel, rest, "RightHandMiddle1")
		var fingers := mid.normalized()
		var fwd_skel := skel.global_basis.inverse() * root.global_basis.z
		var fwd := (rest.basis.inverse() * fwd_skel).normalized()
		var up2 := (fwd - fingers * fwd.dot(fingers)).normalized()
		holder.transform = Transform3D(Basis(up2.cross(fingers), up2, fingers).scaled(Vector3.ONE / s), mid * 0.55)
	att.add_child(holder)
	holder.add_child((load(path) as PackedScene).instantiate())


func _bone(skel: Skeleton3D, suffix: String) -> int:
	for i in skel.get_bone_count():
		# Godot sanitises "mixamorig:RightHand" to "mixamorig_RightHand"; match the suffix
		if skel.get_bone_name(i).ends_with(suffix):
			return i
	return -1


func _local(skel: Skeleton3D, rest: Transform3D, suffix: String) -> Vector3:
	var i := _bone(skel, suffix)
	if i < 0:
		return Vector3(0, 0.08, 0)
	return rest.affine_inverse() * skel.get_bone_global_rest(i).origin
