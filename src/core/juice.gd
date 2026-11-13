extends Node
## Hitstop + camera-shake + directional combat VFX bus. Autoloaded as `Juice`.
##
## `hitstop()` freezes `Engine.time_scale` briefly while an `ALWAYS`-processed
## clock counts unscaled frame time (the frame delta undone of `time_scale`): at
## a fixed timestep that is a fixed number of frames, so a seeded walk repeats. Everything in the scene tree
## that respects `time_scale` pauses on the contact frame — the blade hangs in
## the meat for a beat before the follow-through.

signal shake_requested(trauma: float, duration: float)
signal post_flash_requested(kind: String, might: float)

var _clock := 0.0           # unscaled seconds, advanced in _process
var _hitstop_until := -1.0  # < 0: no hitstop running

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.0001)
	if _hitstop_until >= 0.0 and _clock >= _hitstop_until:
		_hitstop_until = -1.0
		Engine.time_scale = 1.0

## Freeze gameplay briefly. Uses Engine.time_scale; stacked calls extend.
func hitstop(duration := 0.09, scale := 0.05) -> void:
	Engine.time_scale = scale
	_hitstop_until = maxf(_hitstop_until, _clock + duration)

func shake(trauma: float, duration := 0.18) -> void:
	shake_requested.emit(trauma, duration)

func post_flash(kind: String, might := 1.0) -> void:
	post_flash_requested.emit(kind, might)

## Spawns a directional impact burst (`"spark"`, `"blood"`, `"parry"`,
## `"heavy"`) plus a short-lived point-light flash in the active 3D scene.
func spawn_hit_fx(world_pos: Vector3, normal := Vector3.UP, kind := "blood") -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var dir := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP

	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = (dir + Vector3(0, 0.38, 0)).normalized()

	var l := OmniLight3D.new()
	l.shadow_enabled = false

	match kind:
		"spark":
			p.amount = 26
			p.lifetime = 0.34
			p.spread = 48.0
			p.initial_velocity_min = 4.2
			p.initial_velocity_max = 9.0
			p.gravity = Vector3(0, -14.0, 0)
			p.scale_amount_min = 0.025
			p.scale_amount_max = 0.065
			p.color = Color(1.0, 0.78, 0.38)
			l.light_color = Color(1.0, 0.76, 0.36)
			l.light_energy = 1.8
			l.omni_range = 3.2
			post_flash("spark", 0.35)
		"parry":
			p.amount = 48
			p.lifetime = 0.48
			p.spread = 75.0
			p.initial_velocity_min = 5.5
			p.initial_velocity_max = 12.5
			p.gravity = Vector3(0, -11.0, 0)
			p.scale_amount_min = 0.035
			p.scale_amount_max = 0.09
			p.color = Color(1.0, 0.90, 0.55)
			l.light_color = Color(1.0, 0.88, 0.52)
			l.light_energy = 3.4
			l.omni_range = 5.0
			post_flash("parry", 0.85)
		"heavy":
			p.amount = 38
			p.lifetime = 0.45
			p.spread = 62.0
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 9.5
			p.gravity = Vector3(0, -13.0, 0)
			p.scale_amount_min = 0.04
			p.scale_amount_max = 0.095
			p.color = Color(0.68, 0.12, 0.08)
			l.light_color = Color(0.95, 0.38, 0.18)
			l.light_energy = 2.2
			l.omni_range = 3.8
			post_flash("blood", 0.55)
		"ember":   # a burning brand on a frozen body: fire knocked loose, slow to fall
			p.amount = 34
			p.lifetime = 0.7
			p.spread = 70.0
			p.initial_velocity_min = 1.6
			p.initial_velocity_max = 5.5
			p.gravity = Vector3(0.4, -4.0, 0.2)
			p.scale_amount_min = 0.02
			p.scale_amount_max = 0.06
			p.color = Color(1.0, 0.56, 0.16)
			l.light_color = Color(1.0, 0.62, 0.26)
			l.light_energy = 2.6
			l.omni_range = 4.2
			post_flash("spark", 0.3)
		"dust":
			p.amount = 18
			p.lifetime = 0.42
			p.spread = 68.0
			p.initial_velocity_min = 1.4
			p.initial_velocity_max = 3.6
			p.gravity = Vector3(0, -2.5, 0)
			p.scale_amount_min = 0.05
			p.scale_amount_max = 0.12
			p.color = Color(0.58, 0.54, 0.48, 0.55)
			l.light_energy = 0.0
			l.omni_range = 0.5
		_: # "blood" / ichor mist + crimson droplets
			p.amount = 24
			p.lifetime = 0.38
			p.spread = 52.0
			p.initial_velocity_min = 2.8
			p.initial_velocity_max = 6.8
			p.gravity = Vector3(0, -12.5, 0)
			p.scale_amount_min = 0.03
			p.scale_amount_max = 0.075
			p.color = Color(0.56, 0.08, 0.07)
			l.light_color = Color(0.85, 0.22, 0.14)
			l.light_energy = 1.1
			l.omni_range = 2.4
			post_flash("blood", 0.28)

	var qm := QuadMesh.new()
	qm.size = Vector2(0.08, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = AreaPortal._radial_tex()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if kind == "spark" or kind == "parry" or kind == "ember":
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.material = mat
	p.mesh = qm

	root.add_child(p)
	p.global_position = world_pos
	p.emitting = true

	root.add_child(l)
	l.global_position = world_pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.18)
	tw.tween_callback(l.queue_free)
	var ptw := p.create_tween()
	ptw.tween_interval(maxf(0.65, p.lifetime + 0.1))
	ptw.tween_callback(p.queue_free)

func reset() -> void:
	_hitstop_until_ms = 0
	Engine.time_scale = 1.0
