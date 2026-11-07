extends Node
## StateDirector — owns the thaw↔rime transformation: the expanding wave
## (global shader uniforms), the environment/light lerp, layer + navmesh
## swaps, particles and the audio swell. Everyone else calls transition()
## or snap(); the seam stays here. (DECISIONS D-002/D-003)

signal transition_started(area_id: String, to_state: RH.WState)
signal transition_finished(area_id: String, to_state: RH.WState)

## The wave's light: a pale blue-white frost rim going to RIME, a low warm
## bloom on the melt line going to THAW (shaders/wavefront.gdshaderinc).
const FROST_RIM := Color(0.70, 0.85, 1.0)
const MELT_GLOW := Color(1.0, 0.66, 0.36)

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
	AudioDirector.play_state(area.env, to_state, 0.35)

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
	_set_g("rh_wave_color", Vector3(FROST_RIM.r, FROST_RIM.g, FROST_RIM.b) if to_rime
			else Vector3(MELT_GLOW.r, MELT_GLOW.g, MELT_GLOW.b))
	_set_g("rh_wave_r", 0.0)

	area.pre_transition(to_state)
	_spawn_wave_particles(area, origin, duration, max_r, to_rime)
	# the world draws a breath in and holds it (RIME), or lets it go (THAW);
	# ice cracks ride the frost line out, or give as it melts
	var wave_cfg: Dictionary = AudioDirector.cfg("wave", {})
	AudioDirector.sfx(String(wave_cfg.get("to_rime" if to_rime else "to_thaw", "")), 0.0)
	AudioDirector.play_music("", float(wave_cfg.get("music_out_fade", 2.5)))   # music dies during the wave
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
	AudioDirector.play_state(area.env, to_state)
	transitioning = false
	transition_finished.emit(area.area_id, to_state)

## Particles ride the wavefront out. To RIME: snow crystals lifted off the
## frost line and a glitter of ice. To THAW: pollen and warm dust rising,
## steam off the wet ground, meltwater dripping from everything above.
func _spawn_wave_particles(area: Area, origin: Vector3, duration: float, max_r: float, to_rime: bool) -> void:
	var sets: Array = []
	if to_rime:
		sets.append(_ring_emitter(700, 2.4, 0.3, Vector3(0, -0.35, 0), 0.6, 2.0, 0.16, 0.5, 1.3,
				FrostFX.material(FrostFX.crystal_tex(), Color(0.86, 0.93, 1.0, 0.95)), true))
		sets.append(_ring_emitter(260, 0.9, 0.2, Vector3(0, -0.1, 0), 0.4, 1.6, 0.05, 0.4, 1.0,
				FrostFX.material(FrostFX.soft_tex(), Color(0.75, 0.88, 1.0, 0.85), true)))
	else:
		sets.append(_ring_emitter(520, 3.2, 0.2, Vector3(0, 0.18, 0), 0.25, 0.9, 0.07, 0.5, 1.2,
				FrostFX.material(FrostFX.soft_tex(), Color(1.0, 0.84, 0.52, 0.75), true)))
		sets.append(_ring_emitter(90, 2.6, 0.1, Vector3(0, 0.5, 0), 0.2, 0.6, 0.7, 0.6, 1.6,
				FrostFX.material(FrostFX.soft_tex(), Color(0.95, 0.95, 0.92, 0.16))))
		var drips := _ring_emitter(240, 0.7, 2.6, Vector3(0, -9.0, 0), 0.0, 0.2, 0.09, 0.7, 1.0,
				FrostFX.material(FrostFX.drip_tex(), Color(0.80, 0.90, 1.0, 0.75), false, true))
		drips.emission_ring_height = 1.6
		drips.direction = Vector3.DOWN
		sets.append(drips)
	for p in sets:
		var cp := p as CPUParticles3D
		cp.position = origin + Vector3(0, cp.position.y, 0)
		area.add_child(cp)
		cp.emitting = true
		var tw := cp.create_tween()
		tw.tween_method(func(r: float):
				cp.emission_ring_radius = maxf(r, 0.4)
				cp.emission_ring_inner_radius = maxf(r - 1.5, 0.1),
				0.0, max_r, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): cp.emitting = false)
		tw.tween_interval(cp.lifetime + 0.5)
		tw.tween_callback(cp.queue_free)

func _ring_emitter(amount: int, life: float, height: float, gravity: Vector3, v_min: float, v_max: float,
		size: float, s_min: float, s_max: float, mat: Material, spin := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_height = 0.5
	p.emission_ring_inner_radius = 0.1
	p.emission_ring_radius = 0.4
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.damping_min = 0.2
	p.damping_max = 0.8
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	if spin:
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -90.0
		p.angular_velocity_max = 90.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * (3.0 if mat is StandardMaterial3D and (mat as StandardMaterial3D).billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y else 1.0))
	quad.material = mat
	p.mesh = quad
	p.position = Vector3(0, height + 0.4, 0)
	return p
