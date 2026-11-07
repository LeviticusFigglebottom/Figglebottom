extends Node
## StateDirector — owns the thaw↔rime transformation: the expanding wave
## (global shader uniforms), the environment/light lerp, layer + navmesh
## swaps, particles and the audio swell. Everyone else calls transition()
## or snap(); the seam stays here. (DECISIONS D-002/D-003)

signal transition_started(area_id: String, to_state: RH.WState)
signal transition_finished(area_id: String, to_state: RH.WState)

const GOLD := Color(1.0, 0.78, 0.42)
const ASHBLUE := Color(0.45, 0.62, 0.95)

var transitioning := false
var state_blend := 0.0
var _wave_r := 0.0

func _set_g(param: String, v) -> void:
	if param == "rh_state_blend":
		state_blend = float(v)
	RenderingServer.global_shader_parameter_set(param, v)

## Instant state application (loads, tools). No spectacle.
func snap(area: Area, to_state: RH.WState) -> void:
	if area == null:
		return
	_set_g("rh_state_blend", 1.0 if to_state == RH.WState.RIME else 0.0)
	_set_g("rh_wave_r", -1000.0)
	area.apply_state(to_state)
	World.set_area_state(area.area_id, to_state)
	AudioDirector.play_music(area.env.music_for(to_state), 1.0)
	AudioDirector.play_ambience(area.env.ambience_for(to_state))

## The spectacle: the world remembers (warm) or forgets (still).
func transition(area: Area, to_state: RH.WState, origin: Vector3) -> void:
	if transitioning or area == null:
		return
	if World.get_area_state(area.area_id) == to_state:
		return
	transitioning = true
	transition_started.emit(area.area_id, to_state)

	var cfg: Dictionary = DB.tuning("transition", {})
	var duration := float(cfg.get("duration", 6.0))
	var max_r := float(cfg.get("max_radius", 90.0))
	var band := float(cfg.get("band", 4.5))
	var to_rime := to_state == RH.WState.RIME

	# wave setup: old state everywhere, target inside the growing radius
	_set_g("rh_wave_origin", origin)
	_set_g("rh_wave_band", band)
	_set_g("rh_wave_dir", 1.0 if to_rime else 0.0)
	_set_g("rh_wave_color", Vector3(ASHBLUE.r, ASHBLUE.g, ASHBLUE.b) if to_rime
			else Vector3(GOLD.r, GOLD.g, GOLD.b))
	_set_g("rh_wave_r", 0.0)

	area.pre_transition(to_state)
	_spawn_wave_particles(area, origin, duration, max_r, to_rime)
	AudioDirector.sfx("res://assets/audio/swell_still.wav" if to_rime else "res://assets/audio/swell_warm.wav", 2.0)
	AudioDirector.sfx_at("res://assets/audio/horn_low.wav", origin, 4.0, 0.8 if to_rime else 1.0)
	AudioDirector.play_music("", 2.5)   # music dies during the wave
	Juice.shake(0.25, 1.2)

	var env_from := 0.0 if to_rime else 1.0
	var env_to := 1.0 if to_rime else 0.0
	var t := 0.0
	while t < duration:
		var dt := get_process_delta_time()
		t += dt
		var k: float = ease(clampf(t / duration, 0.0, 1.0), 0.65)
		_wave_r = k * max_r
		_set_g("rh_wave_r", _wave_r)
		state_blend = lerpf(env_from, env_to, k)
		area.env.blend(state_blend)
		await get_tree().process_frame

	# settle
	_set_g("rh_state_blend", 1.0 if to_rime else 0.0)
	_set_g("rh_wave_r", -1000.0)
	area.apply_state(to_state)
	World.set_area_state(area.area_id, to_state)
	World.save_game()
	AudioDirector.play_music(area.env.music_for(to_state), 3.0)
	AudioDirector.play_ambience(area.env.ambience_for(to_state))
	transitioning = false
	transition_finished.emit(area.area_id, to_state)

func _spawn_wave_particles(area: Area, origin: Vector3, duration: float, max_r: float, to_rime: bool) -> void:
	var p := CPUParticles3D.new()
	p.amount = 900
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.4
	p.emission_ring_inner_radius = 0.1
	p.emission_ring_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -0.4 if to_rime else 0.6, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.10
	p.color = ASHBLUE if to_rime else GOLD
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	mat.albedo_texture = gt
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = mat
	p.mesh = quad
	p.position = origin + Vector3(0, 0.4, 0)
	area.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_method(func(r: float): p.emission_ring_radius = maxf(r, 0.4); p.emission_ring_inner_radius = maxf(r - 1.5, 0.1),
			0.0, max_r, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(2.0)
	tw.tween_callback(p.queue_free)
