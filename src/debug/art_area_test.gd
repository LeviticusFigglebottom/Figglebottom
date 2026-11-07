extends Node3D
## Area-chunk experiment: is a Tripo "diorama" usable as playable space?
## Loads two variants of the same generated yard, (a) the Tripo quad remesh and (b) the raw
## mesh decimated in Blender, both scaled to 30 m. It raycasts their imported trimesh
## collision to find walkable ground, then shoots an overview and a 1.6 m eye-height view
## of each, with a 1.8 m rimewalker for scale.
## Run: godot --path . res://scenes/sandbox/art_area_test.tscn -- --shots

const VARIANTS := {
	"remesh": "res://assets/models/areas/experiment/area_saltfell_yard_remesh.glb",
	"decim": "res://assets/models/areas/experiment/area_saltfell_yard_decim.glb",
}
const SPACING := 80.0
const RIMEWALKER := "res://assets/models/enemies/rimewalker.glb"

var _cam: Camera3D
var _origins := {}


func _ready() -> void:
	_build_env()
	var i := 0
	for key: String in VARIANTS:
		var path: String = VARIANTS[key]
		var o := Vector3(SPACING * i, 0, 0)
		_origins[key] = o
		i += 1
		if not ResourceLoader.exists(path):
			push_warning("art_area_test: missing " + path)
			continue
		var n: Node3D = (load(path) as PackedScene).instantiate()
		n.position = o
		add_child(n)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	if "--shots" in OS.get_cmdline_user_args():
		_run.call_deferred()


func _ray_down(x: float, z: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -10, z))
	return get_world_3d().direct_space_state.intersect_ray(q)


func _run() -> void:
	for f in 4:
		await get_tree().physics_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screens"))
	for key: String in _origins:
		var o: Vector3 = _origins[key]
		# sample a grid over the footprint: report collision coverage and height spread
		var hits := 0
		var heights: Array[float] = []
		for gx in range(-12, 13, 3):
			for gz in range(-12, 13, 3):
				var h := _ray_down(o.x + gx, o.z + gz)
				if h:
					hits += 1
					heights.append((h.position as Vector3).y)
		heights.sort()
		var med: float = heights[heights.size() / 2] if heights.size() > 0 else 0.0
		print("[area] %s: collision hits %d/81, ground heights min %.2f median %.2f max %.2f" % [
			key, hits, heights.front() if heights.size() else 0.0, med, heights.back() if heights.size() else 0.0])
		# find an open spot near the median height in front of the building for the eye view
		var eye := Vector3(o.x, med, o.z + 6)
		for dz in [8, 6, 10, 4, 12]:
			var h2 := _ray_down(o.x + 2, o.z + dz)
			if h2 and absf((h2.position as Vector3).y - med) < 0.6:
				eye = h2.position
				break
		var rw: Node3D = (load(RIMEWALKER) as PackedScene).instantiate()
		rw.position = eye + Vector3(-1.2, 0, -3.0)
		add_child(rw)
		print("[area] %s: eye ground at %s" % [key, eye])
		_shot("art_area_%s_overview" % key, o + Vector3(26, 24, 30), o + Vector3(0, 3, 0), 50.0)
		await _settle()
		_save("art_area_%s_overview" % key)
		_shot("art_area_%s_eye" % key, eye + Vector3(0, 1.6, 0), eye + Vector3(-2, 1.8, -10), 65.0)
		await _settle()
		_save("art_area_%s_eye" % key)
	get_tree().quit()


func _shot(_name: String, pos: Vector3, at: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.position = pos
	_cam.look_at(at, Vector3.UP)


func _settle() -> void:
	for i in 12:
		await get_tree().process_frame


func _save(n: String) -> void:
	var p := "res://docs/screens/%s.png" % n
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("[shot] ", p)


func _build_env() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.36, 0.42, 0.55)
	sm.sky_horizon_color = Color(0.86, 0.66, 0.46)
	sm.ground_horizon_color = Color(0.45, 0.4, 0.33)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.58, 0.46)
	env.fog_density = 0.003
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.78, 0.52)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-24.0, 50.0, 0.0)
	add_child(sun)
