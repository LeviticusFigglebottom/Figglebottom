class_name ArtLineupRegion
extends Node3D
## Shared base for the per-region art lineups (art_lineup_<region>.gd). Same look and capture flow
## as art_lineup_lowe.gd, but data-driven so each region script only lists its assets and cameras.
## Run: godot --path . res://scenes/sandbox/art_lineup_<region>.tscn -- --shots
## With --shots it renders every camera twice, THAW then RIME, to
## docs/screens/art_<region>_<shot>_<state>.png, then quits. Pass --rime to open it in RIME.
## Standalone on purpose: no game systems, so the art is judged alone.

const M := "res://assets/models/"

## Filled in by the region script's _config().
var region := ""
## [path, design height (m, drawn as a pole), clip, x, weapon path for the right hand or ""]
var characters: Array = []
## [boss path, clip, x, fraction of the clip]: a boss frozen part-way through a signature clip
var boss_clips: Array = []
## [path, position, yaw]
var landmarks: Array = []
## [path, position, rotation (deg)] laid on a bench at bench_pos
var items: Array = []
var bench_pos := Vector3(12.0, 0.35, 0.9)
var bench_size := Vector3(2.4, 0.7, 2.0)
## [name, camera position, look-at, fov]
var shots: Array = []
## ground tint in THAW (RIME is always hoar-grey)
var ground_thaw := [Color(0.30, 0.22, 0.14), Color(0.42, 0.36, 0.24)]

const THAW := {
	"sky_top": Color(0.36, 0.42, 0.55), "sky_horizon": Color(0.86, 0.66, 0.46),
	"sun": Color(1.0, 0.78, 0.52), "sun_energy": 2.0, "sun_rot": Vector3(-16.0, -35.0, 0.0),
	"fog": Color(0.7, 0.58, 0.46), "fog_density": 0.003, "vfog_albedo": Color(1.0, 0.85, 0.65),
	"vfog_density": 0.003, "ambient": 0.45,
}
## STYLE.md RIME: blue-white sun (.74, .84, 1.0), denser cold fog, desaturated
const RIME := {
	"sky_top": Color(0.42, 0.48, 0.58), "sky_horizon": Color(0.70, 0.76, 0.84),
	"sun": Color(0.74, 0.84, 1.0), "sun_energy": 1.3, "sun_rot": Vector3(-28.0, -35.0, 0.0),
	"fog": Color(0.62, 0.70, 0.80), "fog_density": 0.012, "vfog_albedo": Color(0.85, 0.9, 1.0),
	"vfog_density": 0.012, "ambient": 0.6,
}
const RIME_GROUND := [Color(0.52, 0.55, 0.60), Color(0.74, 0.77, 0.82)]

var _cam: Camera3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _ground_grad: Gradient


## Region scripts override this to fill the vars above.
func _config() -> void:
	pass


func _ready() -> void:
	_config()
	_build_environment()
	_build_ground()
	for c in characters:
		_build_character(c)
	for b in boss_clips:
		_build_boss_clip(b)
	for l in landmarks:
		_place(l[0], l[1], l[2])
	if not items.is_empty():
		_build_items()
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_set_shot(shots[0])
	var args := OS.get_cmdline_user_args()
	_apply_state("--rime" in args)
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
	for state in ["thaw", "rime"]:
		_apply_state(state == "rime")
		for s in shots:
			_set_shot(s)
			for i in 14:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			var path := "res://docs/screens/art_%s_%s_%s.png" % [region, s[0], state]
			img.save_png(ProjectSettings.globalize_path(path))
			print("[shot] ", path)
	get_tree().quit()


func _apply_state(rime: bool) -> void:
	var st: Dictionary = RIME if rime else THAW
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
	var g: Array = RIME_GROUND if rime else ground_thaw
	_ground_grad.set_color(0, g[0])
	_ground_grad.set_color(1, g[1])


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
	_sun.directional_shadow_max_distance = 60.0
	_sun.light_volumetric_fog_energy = 0.6
	add_child(_sun)


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(160, 160)
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
	mat.uv1_scale = Vector3(18, 18, 1)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


func _place(path: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("art_lineup_%s: missing %s" % [region, path])
		return null
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw_deg
	add_child(node)
	return node


func _build_character(c: Array) -> void:
	var root := _place(c[0], Vector3(c[3], 0, 0))
	_height_tick(Vector3(c[3] + (1.3 if c[1] > 2.5 else 0.55), 0, 0), c[1])
	if root == null:
		return
	_play(root, c[2])
	if c[4] != "":
		_attach(root, "RightHand", c[4])


func _build_boss_clip(b: Array) -> void:
	var root := _place(b[0], Vector3(b[2], 0, 0), 30.0)
	if root == null:
		return
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null or not ap.has_animation(b[1]):
		push_warning("art_lineup_%s: %s has no clip %s" % [region, b[0], b[1]])
		return
	ap.play(b[1])
	ap.seek(ap.get_animation(b[1]).length * b[3], true)
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


func _build_items() -> void:
	var bench := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bench_size
	bench.mesh = bm
	bench.position = bench_pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.27, 0.2)
	mat.roughness = 0.9
	bench.material_override = mat
	add_child(bench)
	for it in items:
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
