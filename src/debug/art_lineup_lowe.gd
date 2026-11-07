extends Node3D
## Lowe art lineup: every Lowe-region Tripo hero (the Turfwright, the three Lowe frost-taken,
## Hesk, Aud, the Bearer in Barrow-wool, the region weapons and landmarks) at true scale.
## Run: godot --path . res://scenes/sandbox/art_lineup_lowe.tscn -- --shots
## With --shots it renders every camera in SHOTS twice, once under the THAW sun and once under
## the cold blue RIME light, to docs/screens/art_lowe_<shot>_<state>.png, then quits.
## Pass --rime to open it in RIME when looking interactively.
## Standalone on purpose (like art_lineup): no game systems, so the art can be judged alone.

const M := "res://assets/models/"
const MAUL := M + "weapons/post_maul.glb"
const SPADE := M + "weapons/turf_spade.glb"

## path, design height (m, drawn as a pole), clip, x position in the row, weapon for the right hand
const CHARACTERS := [
	[M + "characters/bearer_barrow.glb", 1.8, "walk", -5.6, MAUL],
	[M + "npcs/aud.glb", 1.6, "idle", -4.2, ""],
	[M + "npcs/hesk.glb", 1.8, "idle", -2.9, ""],
	[M + "enemies/barrow_sleeper.glb", 1.9, "walk", -1.4, ""],
	[M + "enemies/keener.glb", 1.75, "idle", 0.0, ""],
	[M + "enemies/cairn_carrier.glb", 2.2, "idle", 1.6, ""],
	[M + "bosses/turfwright.glb", 3.4, "idle", 4.6, ""],
]

## the Turfwright's text-prompt clips, each frozen part-way through: clip, x, fraction of the clip
const BOSS_CLIPS := [["ground_cut", 15.0, 0.45], ["stack_sod", 19.0, 0.5], ["back_drop", 23.0, 0.45]]

## path, position, yaw: a short barrow road behind the row
const LANDMARKS := [
	[M + "landmarks/lm_barrow_door.glb", Vector3(-3.0, 0, -9.0), 10.0],
	[M + "landmarks/lm_barrow_door.glb", Vector3(4.5, 0, -10.5), -12.0],
	[M + "landmarks/lm_standing_stone.glb", Vector3(-8.5, 0, -7.0), 20.0],
	[M + "landmarks/lm_standing_stone.glb", Vector3(9.5, 0, -6.0), -40.0],
	[M + "landmarks/lm_standing_stone.glb", Vector3(0.8, 0, -15.0), 75.0],
]

## carried items on a bench to the right of the row: path, position, rotation (deg)
const ITEMS := [
	[SPADE, Vector3(9.4, 0.72, 0.6), Vector3(0, 0, -90)],
	[MAUL, Vector3(9.4, 0.72, 1.25), Vector3(0, 0, -90)],
]

## name, camera position, look-at target, fov
const SHOTS := [
	["row", Vector3(0.0, 1.8, 9.0), Vector3(0.0, 1.3, 0.0), 58.0],
	["boss", Vector3(3.4, 2.0, 5.2), Vector3(4.6, 1.7, 0.0), 55.0],
	["boss_back", Vector3(7.0, 2.4, -3.6), Vector3(4.6, 1.8, 0.0), 55.0],
	["enemies", Vector3(0.1, 1.5, 4.6), Vector3(0.1, 1.1, 0.0), 52.0],
	["npcs", Vector3(-4.2, 1.4, 3.6), Vector3(-4.2, 1.0, 0.0), 50.0],
	["landmarks", Vector3(0.5, 2.6, -3.2), Vector3(0.5, 1.0, -10.5), 62.0],
	["items", Vector3(9.4, 2.3, 3.0), Vector3(9.4, 0.75, 0.95), 45.0],
	["boss_clips", Vector3(19.0, 2.4, 8.5), Vector3(19.0, 1.4, 0.0), 55.0],
]

const THAW := {
	"sky_top": Color(0.36, 0.42, 0.55), "sky_horizon": Color(0.86, 0.66, 0.46),
	"sun": Color(1.0, 0.78, 0.52), "sun_energy": 2.0, "sun_rot": Vector3(-16.0, -35.0, 0.0),
	"fog": Color(0.7, 0.58, 0.46), "fog_density": 0.003, "vfog_albedo": Color(1.0, 0.85, 0.65),
	"vfog_density": 0.003, "ambient": 0.45, "ground_a": Color(0.30, 0.17, 0.12), "ground_b": Color(0.45, 0.33, 0.22),
}
## STYLE.md RIME: blue-white sun (.74, .84, 1.0), denser cold fog, desaturated
const RIME := {
	"sky_top": Color(0.42, 0.48, 0.58), "sky_horizon": Color(0.70, 0.76, 0.84),
	"sun": Color(0.74, 0.84, 1.0), "sun_energy": 1.3, "sun_rot": Vector3(-28.0, -35.0, 0.0),
	"fog": Color(0.62, 0.70, 0.80), "fog_density": 0.012, "vfog_albedo": Color(0.85, 0.9, 1.0),
	"vfog_density": 0.012, "ambient": 0.6, "ground_a": Color(0.52, 0.55, 0.60), "ground_b": Color(0.74, 0.77, 0.82),
}

var _cam: Camera3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _ground_grad: Gradient


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_characters()
	_build_landmarks()
	_build_items()
	_build_boss_clips()
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_set_shot(SHOTS[0])
	var args := OS.get_cmdline_user_args()
	_apply_state(RIME if "--rime" in args else THAW)
	if "--shots" in args:
		_capture_all.call_deferred()


func _set_shot(s: Array) -> void:
	_cam.fov = s[3]
	_cam.position = s[1]
	_cam.look_at(s[2], Vector3.UP)


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screens"))
	for i in 50:
		await get_tree().process_frame
	for state in [["thaw", THAW], ["rime", RIME]]:
		_apply_state(state[1])
		for s in SHOTS:
			_set_shot(s)
			for i in 14:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			var path := "res://docs/screens/art_lowe_%s_%s.png" % [s[0], state[0]]
			img.save_png(ProjectSettings.globalize_path(path))
			print("[shot] ", path)
	get_tree().quit()


func _apply_state(st: Dictionary) -> void:
	_sky.sky_top_color = st["sky_top"]
	_sky.sky_horizon_color = st["sky_horizon"]
	_sun.light_color = st["sun"]
	_sun.light_energy = st["sun_energy"]
	_sun.rotation_degrees = st["sun_rot"]
	_env.fog_light_color = st["fog"]
	_env.fog_density = st["fog_density"]
	_env.volumetric_fog_albedo = st["vfog_albedo"]
	_env.volumetric_fog_density = st["vfog_density"]
	_env.ambient_light_energy = st["ambient"]
	_ground_grad.set_color(0, st["ground_a"])
	_ground_grad.set_color(1, st["ground_b"])


func _build_environment() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	_sky = ProceduralSkyMaterial.new()
	_sky.ground_horizon_color = Color(0.45, 0.4, 0.33)
	_sky.ground_bottom_color = Color(0.2, 0.18, 0.15)
	_sky.sun_angle_max = 8.0
	sky.sky_material = _sky
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 0.95
	_env.tonemap_white = 6.0
	_env.fog_enabled = true
	_env.fog_sky_affect = 0.15
	_env.fog_sun_scatter = 0.25
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_length = 40.0
	_env.ssao_enabled = true
	_env.ssao_radius = 1.2
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 50.0
	_sun.light_volumetric_fog_energy = 0.6
	add_child(_sun)


## heather-brown moor in THAW, hoar-grey in RIME
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
	_ground_grad = Gradient.new()
	nt.color_ramp = _ground_grad
	mat.albedo_texture = nt
	mat.uv1_scale = Vector3(14, 14, 1)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


func _place(path: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("art_lineup_lowe: missing " + path)
		return null
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	return node


func _build_characters() -> void:
	for c in CHARACTERS:
		var root := _place(c[0], Vector3(c[3], 0, 0))
		_height_tick(Vector3(c[3] + (1.1 if c[1] > 2.5 else 0.55), 0, 0), c[1])
		if root == null:
			continue
		_play(root, c[2])
		if c[4] != "":
			_attach(root, "RightHand", c[4])


func _build_boss_clips() -> void:
	for c in BOSS_CLIPS:
		var root := _place(M + "bosses/turfwright.glb", Vector3(c[1], 0, 0), 30.0)
		if root == null:
			continue
		var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null or not ap.has_animation(c[0]):
			push_warning("art_lineup_lowe: turfwright has no clip " + c[0])
			continue
		ap.play(c[0])
		ap.seek(ap.get_animation(c[0]).length * c[2], true)
		ap.pause()


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
	bm.size = Vector3(2.0, 0.7, 1.6)
	bench.mesh = bm
	bench.position = Vector3(9.4, 0.35, 0.9)
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


## Same grip convention as art_lineup._attach(): grip at origin, head/blade +Y.
func _attach(root: Node3D, bone_suffix: String, path: String) -> void:
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
		if skel.get_bone_name(i).ends_with(suffix):
			return i
	return -1


func _local(skel: Skeleton3D, rest: Transform3D, suffix: String) -> Vector3:
	var i := _bone(skel, suffix)
	if i < 0:
		return Vector3(0, 0.08, 0)
	return rest.affine_inverse() * skel.get_bone_global_rest(i).origin
