class_name EnvRig
extends Node3D
## Owns the WorldEnvironment + sun + counter-directional sky fill for an area
## and blends between the thaw and rime lighting profiles (data/state_profiles.json).

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var sky_fill: DirectionalLight3D
var sky_mat: ShaderMaterial

var profiles: Dictionary = {}
## Per-area profile overrides from the area def's "env" block: only the keys
## given are replaced per state, so an area can redden its sun (the Black
## Gate's drowned dusk) without re-authoring the whole global profile.
var overrides: Dictionary = {}

## Graphics Quality tier: 0 = Low, 1 = High (SSAO + ACES + Sky Radiance),
## 2 = Ultra (+ SSIL + SSR + SDFGI). Auto-detected on first boot.
static var graphics_quality: int = -1
static var active_instance: EnvRig = null
static var _cached_profiles: Dictionary = {}

static func get_graphics_quality() -> int:
	if graphics_quality < 0:
		var adapter := RenderingServer.get_video_adapter_name().to_lower()
		if DisplayServer.get_name() == "headless" or adapter.contains("llvmpipe") \
				or adapter.contains("lavapipe") or adapter.contains("swiftshader"):
			graphics_quality = 1
		else:
			graphics_quality = 2
	return graphics_quality

static func set_graphics_quality(tier: int) -> void:
	graphics_quality = clampi(tier, 0, 2)
	if is_instance_valid(active_instance):
		active_instance.apply_quality_tier()

func set_overrides(ov: Dictionary) -> void:
	overrides = ov

func _profile(state_name: String) -> Dictionary:
	# after the Outsong the unfrozen ground is lit by a real spring: grey and
	# green, no amber (the "spring" profile; an area may override it by name)
	if state_name == "thaw" and World.spring() and profiles.has("spring"):
		state_name = "spring"
	var p: Dictionary = profiles[state_name].duplicate()
	for k in overrides.get(state_name, {}):
		p[k] = overrides[state_name][k]
	return p

func _ready() -> void:
	active_instance = self
	if _cached_profiles.is_empty():
		var f := FileAccess.open("res://data/state_profiles.json", FileAccess.READ)
		_cached_profiles = JSON.parse_string(f.get_as_text())
	profiles = _cached_profiles

	world_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/stylized_sky.gdshader")
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.25
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_white = 6.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.07
	e.adjustment_saturation = 1.02
	e.fog_enabled = true
	e.fog_sky_affect = 0.22
	e.volumetric_fog_enabled = true
	e.volumetric_fog_anisotropy = 0.66
	e.volumetric_fog_length = 88.0
	e.volumetric_fog_ambient_inject = 0.32
	e.glow_enabled = true
	e.glow_normalized = true
	e.glow_bloom = 0.14
	e.glow_hdr_threshold = 0.95
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	world_env.environment = e
	apply_quality_tier()
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_bias = 0.022
	sun.shadow_normal_bias = 1.15
	sun.shadow_blur = 1.35
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_max_distance = _shadow_distance()
	add_child(sun)

	# Secondary shadowless zenith/counter-directional sky & moonlight bounce fill
	# Ensures enclosed courtyards and boss arenas retain crisp normal-mapped relief
	# and specular edge readable silhouettes even inside directional wall shadows.
	sky_fill = DirectionalLight3D.new()
	sky_fill.shadow_enabled = false
	sky_fill.rotation_degrees = Vector3(-68.0, 138.0, 0.0)
	add_child(sky_fill)

## Sun shadow reach per quality tier (render/shadow_distance, Low/High/
## Ultra). Past ~100 m the third-person camera sees cliffs, not contact
## shadows; the shorter reach also spends the four splits' texels nearer.
func _shadow_distance() -> float:
	var d: Array = DB.tuning("render/shadow_distance", [70.0, 100.0, 135.0])
	return float(d[clampi(get_graphics_quality(), 0, d.size() - 1)])

func apply_quality_tier() -> void:
	if world_env == null or world_env.environment == null:
		return
	var e := world_env.environment
	var q := get_graphics_quality()
	if sun != null:
		sun.directional_shadow_max_distance = _shadow_distance()
	e.ssao_enabled = (q >= 1)
	if e.ssao_enabled:
		e.ssao_radius = 1.25
		e.ssao_intensity = 1.75
		e.ssao_power = 1.55
		e.ssao_detail = 0.65
		e.ssao_horizon = 0.08
		e.ssao_sharpness = 0.96
		e.ssao_light_affect = 0.52
	e.ssil_enabled = (q >= 2)
	if e.ssil_enabled:
		e.ssil_radius = 4.5
		e.ssil_intensity = 0.85
		e.ssil_sharpness = 0.96
	e.ssr_enabled = (q >= 2)
	if e.ssr_enabled:
		e.ssr_max_steps = 32
		e.ssr_fade_in = 0.15
		e.ssr_fade_out = 2.0
	e.sdfgi_enabled = (q >= 2)
	if e.sdfgi_enabled:
		e.sdfgi_use_occlusion = true
		e.sdfgi_read_sky_light = true
		e.sdfgi_cascades = 4
		e.sdfgi_min_cell_size = 0.4
		e.sdfgi_energy = 0.85
	RenderingServer.global_shader_parameter_set("rh_water_sky_fill", 1.0 if e.sdfgi_enabled else 0.0)

## Sky keys an older or partial profile may not carry ("sky_<key>").
const SKY_DEFAULTS := {
	"thaw": {"mid": [0.62, 0.5, 0.45], "haze": [1.0, 0.76, 0.46], "cloud_lit": [1.0, 0.72, 0.5],
		"cloud_shade": [0.3, 0.27, 0.34], "aurora_color": [0.3, 0.9, 0.62],
		"cloud_cover": 0.45, "sun_disc": 1.0, "aurora": 0.0, "stars": 0.0},
	"rime": {"mid": [0.08, 0.11, 0.18], "haze": [0.2, 0.26, 0.38], "cloud_lit": [0.2, 0.25, 0.36],
		"cloud_shade": [0.035, 0.045, 0.075], "aurora_color": [0.3, 0.9, 0.62],
		"cloud_cover": 0.85, "sun_disc": 0.2, "aurora": 0.35, "stars": 0.6},
}

func _sky(profile: Dictionary, state_name: String, key: String) -> Variant:
	return profile.get("sky_" + key, SKY_DEFAULTS[state_name][key])

func _c(v: Array) -> Color:
	return Color(v[0], v[1], v[2])

## t: 0 = thaw, 1 = rime
func blend(t: float) -> void:
	var a := _profile("thaw")
	var b := _profile("rime")
	var e := world_env.environment
	var sc := _c(a["sun_color"]).lerp(_c(b["sun_color"]), t)
	sun.light_color = sc
	var rime_sun_e := maxf(float(b["sun_energy"]), 0.85)
	sun.light_energy = lerpf(float(a["sun_energy"]), rime_sun_e, t)
	var ra: Array = a["sun_rot"]
	var rb: Array = b["sun_rot"]
	sun.rotation_degrees = Vector3(lerpf(ra[0], rb[0], t), lerpf(ra[1], rb[1], t), 0)
	if sky_fill != null:
		# an area may warm or lift the bounce (a deep fjord at evening)
		var fca: Color = _c(a["fill_color"]) if a.has("fill_color") else Color(0.82, 0.76, 0.68)
		var fcb: Color = _c(b["fill_color"]) if b.has("fill_color") else Color(0.64, 0.72, 0.86)
		sky_fill.light_color = fca.lerp(fcb, t)
		sky_fill.light_energy = lerpf(float(a.get("fill_energy", 0.22)), float(b.get("fill_energy", 0.52)), t)
		var fra: Array = a.get("fill_rot", [-68.0, 138.0])
		var frb: Array = b.get("fill_rot", [-68.0, 138.0])
		sky_fill.rotation_degrees = Vector3(lerpf(fra[0], frb[0], t), lerpf(fra[1], frb[1], t), 0.0)
	e.ambient_light_color = _c(a["ambient"]).lerp(_c(b["ambient"]), t)
	e.ambient_light_energy = lerpf(float(a["ambient_energy"]), float(b["ambient_energy"]), t)
	e.ambient_light_sky_contribution = lerpf(a.get("sky_contribution", 0.20), b.get("sky_contribution", 0.14), t)
	if e.ssao_enabled:
		e.ssao_intensity = lerpf(a.get("ssao_intensity", 1.75), b.get("ssao_intensity", 1.85), t)
	e.fog_light_color = _c(a["fog_color"]).lerp(_c(b["fog_color"]), t)
	e.fog_density = lerpf(a["fog_density"], b["fog_density"], t)
	e.volumetric_fog_density = lerpf(a["vol_density"], b["vol_density"], t)
	e.volumetric_fog_anisotropy = lerpf(a.get("vol_anisotropy", 0.66), b.get("vol_anisotropy", 0.66), t)
	_blend_pockets(t)
	e.volumetric_fog_albedo = _c(a["vol_albedo"]).lerp(_c(b["vol_albedo"]), t)
	e.tonemap_exposure = lerpf(a["exposure"], b["exposure"], t)
	e.adjustment_contrast = lerpf(a.get("contrast", 1.06), b.get("contrast", 1.08), t)
	e.adjustment_saturation = lerpf(a.get("saturation", 1.06), b.get("saturation", 0.96), t)
	e.glow_intensity = lerpf(a["glow"], b["glow"], t)
	# the sky: every stop and amount is profile data (defaults in SKY_DEFAULTS)
	var top := _c(a["bg_top"]).lerp(_c(b["bg_top"]), t)
	var horizon := _c(a["bg_horizon"]).lerp(_c(b["bg_horizon"]), t)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("sun_color", sc)
	sky_mat.set_shader_parameter("ground_color", horizon.darkened(0.65))
	sky_mat.set_shader_parameter("rime", t)
	RenderingServer.global_shader_parameter_set("rh_sky_top", top)
	RenderingServer.global_shader_parameter_set("rh_sky_horizon", horizon)
	for k in ["mid", "haze", "cloud_lit", "cloud_shade", "aurora_color"]:
		sky_mat.set_shader_parameter(k if k.begins_with("cloud") or k == "aurora_color" else k + "_color",
			_c(_sky(a, "thaw", k)).lerp(_c(_sky(b, "rime", k)), t))
	for k in ["cloud_cover", "sun_disc", "aurora", "stars"]:
		sky_mat.set_shader_parameter(k, lerpf(float(_sky(a, "thaw", k)), float(_sky(b, "rime", k)), t))
	# place the sky's sun disc where the directional light streams from
	var sb := Basis.from_euler(Vector3(deg_to_rad(lerpf(ra[0], rb[0], t)),
			deg_to_rad(lerpf(ra[1], rb[1], t)), 0.0))
	sky_mat.set_shader_parameter("sun_dir", sb.z)

## Local volumetric fog for deep gorges, from the area def's "fog_pockets":
## [{"at": [x,y,z], "size": [x,y,z], "density": [thaw, rime], "albedo": [r,g,b]?}]
var _pockets: Array = []

func build_fog_pockets(list: Array) -> void:
	for p in _pockets:
		p["node"].queue_free()
	_pockets.clear()
	for d in list:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		var sz: Array = d["size"]
		fv.size = Vector3(sz[0], sz[1], sz[2])
		var at: Array = d["at"]
		fv.position = Vector3(at[0], at[1], at[2])
		var m := FogMaterial.new()
		m.edge_fade = 0.6
		m.height_falloff = float(d.get("height_falloff", 0.0))
		if d.has("albedo"):
			m.albedo = _c(d["albedo"])
		fv.material = m
		add_child(fv)
		var dens: Array = d["density"]
		m.density = float(dens[0])
		_pockets.append({"node": fv, "mat": m, "a": float(dens[0]), "b": float(dens[1])})

func _blend_pockets(t: float) -> void:
	for p in _pockets:
		p["mat"].density = lerpf(p["a"], p["b"], t)

func snap(state: RH.WState) -> void:
	blend(1.0 if state == RH.WState.RIME else 0.0)

func music_for(state: RH.WState) -> String:
	return _profile(RH.STATE_NAMES[state]).get("music", "")

func ambience_for(state: RH.WState) -> String:
	return _profile(RH.STATE_NAMES[state]).get("ambience", "")

## Music, ambience and their crossfade times for a state (AudioDirector).
func audio_for(state: RH.WState) -> Dictionary:
	var p := _profile(RH.STATE_NAMES[state])
	var out := {}
	for k in ["music", "ambience", "music_fade_in", "ambience_fade"]:
		if p.has(k):
			out[k] = p[k]
	return out
