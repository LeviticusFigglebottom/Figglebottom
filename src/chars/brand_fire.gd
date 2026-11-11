class_name BrandFire
extends Node3D
## The fire on a carried brand (the torch): flame cards on the head, embers,
## smoke, and the light that is the torch's whole use. Sits at the head of the
## weapon model, so it rides the hand.
##
## The flame always burns upward, whatever way the haft points, and is
## dragged behind the head when it moves: a swung brand trails its fire.
## Wind worries it in gusts, harder under RIME snowfall, and under a roof
## hardly at all. All of that is looks; the light's reach is data
## (weapons.json <id>.fire) and does not gutter below `light_floor`.

var cfg := {}
## 0 = out (a dull coal), 1 = burning. Eased toward `_lit_to`.
var lit := 0.0
var _lit_to := 1.0
var _flames: Array[MeshInstance3D] = []
var _embers: CPUParticles3D
var _smoke: CPUParticles3D
var _light: OmniLight3D
var _coal: MeshInstance3D
var _prev := Vector3.ZERO
var _has_prev := false
var _vel := Vector3.ZERO
var _lean := Vector3.ZERO          # world-space push on the flame (m/s-ish)
var _phase := 0.0
var _shelter := 0.0                # 1 under a roof
var _shelter_t := 0.0
var _flare := 0.0                  # the catch when it is lit, a struck blow
var _gutter := 0.0                 # 0 steady .. 1 nearly blown out

## The wind the RIME snow falls on (area.gd drifts it the same way).
const WIND_DIR := Vector3(0.93, 0.0, 0.37)

static var _smoke_mat: StandardMaterial3D = null
static var _spark_mat: StandardMaterial3D = null

func setup(fire: Dictionary) -> void:
	cfg = fire
	_phase = randf() * 40.0
	var h := float(cfg.get("flame_h", 0.34))
	var r := float(cfg.get("flame_r", 0.085))
	# a tall tongue and a low fat one, so the fire has a body from any side
	for row in [[h, r, 0.0], [h * 0.62, r * 1.25, 1.7]]:
		var f := KitLib._flame(self, Vector3.ZERO, float(row[0]), float(row[1]), "flame")
		f.set_surface_override_material(0, MaterialLib.get_mat("M_flame", 0))
		f.set_instance_shader_parameter("keep_in_rime", 1.0)   # a carried fire burns in both states
		f.set_instance_shader_parameter("flame_tint", Vector3(1.0, 0.6, 0.2))
		f.set_instance_shader_parameter("flame_energy", 1.0)
		f.rotation.y = float(row[2])
		f.top_level = true   # upright in the world, not along the haft
		_flames.append(f)
	# the head itself glows: with the flame out this is all that is left
	_coal = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 0.9
	sm.height = r * 2.2
	sm.radial_segments = 10
	sm.rings = 5
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.albedo_color = Color(1.0, 0.32, 0.06)
	sm.material = cm
	_coal.mesh = sm
	_coal.position.y = -r * 0.6
	_coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_coal)
	_embers = _make_sparks(14, 1.3)
	_embers.emitting = true
	add_child(_embers)
	_smoke = _make_smoke()
	add_child(_smoke)
	_light = OmniLight3D.new()
	var lc: Array = cfg.get("light_color", [1.0, 0.72, 0.38])
	_light.light_color = Color(lc[0], lc[1], lc[2])
	_light.omni_range = float(cfg.get("light_range", 8.0))
	_light.omni_attenuation = float(cfg.get("light_attenuation", 1.0))
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	# over the flame, clear of the haft and the fist, so the hand is lit, not burnt out
	_light.position.y = h * 0.8
	add_child(_light)
	set_process(true)

static func _make_sparks(amount: int, life: float) -> CPUParticles3D:
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_mat.vertex_color_use_as_albedo = true
	var p := CPUParticles3D.new()
	p.name = "embers"
	p.amount = amount
	p.lifetime = life
	p.local_coords = false   # sparks are left behind in the air
	p.randomness = 0.6
	p.lifetime_randomness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0.25, 0.5, 0.1)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1.7, 1.05, 0.45, 1.0))
	fade.set_color(1, Color(0.9, 0.15, 0.02, 0.0))
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.014, 0.014)
	q.material = _spark_mat
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func _make_smoke() -> CPUParticles3D:
	if _smoke_mat == null:
		_smoke_mat = StandardMaterial3D.new()
		_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_smoke_mat.vertex_color_use_as_albedo = true
		_smoke_mat.albedo_texture = _puff_tex()
		_smoke_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var p := CPUParticles3D.new()
	p.name = "smoke"
	p.amount = 12
	p.lifetime = 2.2
	p.local_coords = false
	p.randomness = 0.5
	p.lifetime_randomness = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.03
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.3, 0.25, 0.12)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.8
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.16, 0.13, 0.11, 0.0))
	fade.set_color(1, Color(0.45, 0.45, 0.46, 0.0))
	fade.add_point(0.15, Color(0.16, 0.14, 0.12, 0.3))
	fade.add_point(0.6, Color(0.3, 0.29, 0.28, 0.14))
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	q.material = _smoke_mat
	p.mesh = q
	p.position.y = float(cfg.get("flame_h", 0.34)) * 0.9
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

static var _puff: GradientTexture2D = null

static func _puff_tex() -> Texture2D:
	if _puff == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.45))
		_puff = GradientTexture2D.new()
		_puff.gradient = g
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
		_puff.width = 48
		_puff.height = 48
	return _puff

## Light it (drawn) or let it die to a coal (stowed). `now` skips the ease.
func set_lit(on: bool, now := false) -> void:
	if on and _lit_to < 0.5 and not now:
		_flare = 1.0   # it catches with a flare and a spit of sparks
		burst(10, 1.6)
	_lit_to = 1.0 if on else 0.0
	if now:
		lit = _lit_to
		_apply(0.0)

func is_lit() -> bool:
	return _lit_to > 0.5

## A blow landed with the head: sparks thrown off it, and the fire flares.
func burst(amount := 26, speed := 3.2) -> void:
	if not is_inside_tree():
		return
	var p := _make_sparks(amount, 0.9)
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.2, -3.2, 0.1)
	p.emitting = true
	p.finished.connect(p.queue_free)
	add_child(p)
	_flare = maxf(_flare, 0.8)

## World position of the flame's root (the head of the brand).
func head_pos() -> Vector3:
	return global_position

func _gust(t: float) -> float:
	# slow swell with a sharper lick on top: 0 calm .. 1 a hard gust
	var a := sin(t * 0.63 + _phase) * 0.5 + sin(t * 1.71 + _phase * 1.9) * 0.3 + sin(t * 4.3 + _phase * 0.7) * 0.2
	return clampf(a * 0.5 + 0.5, 0.0, 1.0)

func _process(dt: float) -> void:
	if dt <= 0.0:
		return
	lit = move_toward(lit, _lit_to, dt * (2.4 if _lit_to > lit else 3.5))
	_flare = move_toward(_flare, 0.0, dt * 2.6)
	_apply(dt)

func _apply(dt: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var head := global_position
	if dt > 0.0:
		if _has_prev:
			_vel = _vel.lerp((head - _prev) / dt, 1.0 - exp(-18.0 * dt))
		_prev = head
		_has_prev = true
		_shelter_t -= dt
		if _shelter_t <= 0.0:
			_shelter_t = 0.5
			var area: Node = Game.current_area
			var inside := area != null and is_instance_valid(area) and AudioDirector._indoors(area, head)
			_shelter = 1.0 if inside else 0.0
	var rime := clampf(StateDirector.state_blend, 0.0, 1.0)
	var open := 1.0 - _shelter * 0.85
	# THAW: a light evening air. RIME: the wind the snow comes down on.
	var gust := _gust(t)
	var wind := (0.25 + 0.35 * gust + rime * (0.5 + 1.3 * gust * gust)) * open
	# snow hissing into it: short dips, only out under the RIME sky
	var hiss := maxf(0.0, sin(t * 7.3 + _phase) * sin(t * 2.9 + _phase * 1.3) - 0.55) * 2.2 * rime * open
	var gutter_to := clampf((wind - 0.9) * 0.55 + hiss + _vel.length() * 0.05, 0.0, 0.8)
	_gutter = lerpf(_gutter, gutter_to, 1.0 - exp(-9.0 * maxf(dt, 0.016)))
	# the flame is pushed downwind and dragged behind the moving head
	var push := WIND_DIR * wind * 0.9 - _vel * 0.3
	push.y = 0.0
	_lean = _lean.lerp(push, 1.0 - exp(-10.0 * maxf(dt, 0.016)))
	var lean_amt := minf(_lean.length(), 1.6)
	var up := Vector3.UP
	if lean_amt > 0.01:
		up = (Vector3.UP + _lean.normalized() * minf(lean_amt * 0.55, 1.1)).normalized()
	var size := lit * (1.0 - 0.45 * _gutter + 0.35 * _flare)
	var i := 0
	for f in _flames:
		var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		var b := Basis(x, up, x.cross(up)).rotated(up, float(i) * 1.7)
		# stretched along the lean, thinned by it: a streaming flame
		b = b.scaled(Vector3(maxf(size, 0.001), maxf(size * (1.0 + lean_amt * 0.25), 0.001), maxf(size, 0.001)))
		f.global_transform = Transform3D(b, head)
		f.visible = lit > 0.03
		f.set_instance_shader_parameter("flame_energy", 0.85 + 0.5 * _flare - 0.25 * _gutter)
		i += 1
	_coal.scale = Vector3.ONE * (0.55 + 0.45 * lit)
	(_coal.mesh as SphereMesh).material.albedo_color = Color(1.0, 0.32, 0.06) * (0.25 + 0.75 * lit)
	_embers.emitting = lit > 0.5
	_embers.gravity = Vector3(0.25 + _lean.x * 0.8, 0.5, 0.1 + _lean.z * 0.8)
	_smoke.emitting = lit > 0.15
	_smoke.gravity = Vector3(_lean.x * 0.9, 0.3, _lean.z * 0.9)
	# the light: a breathing flicker; a gust dips it but never below the floor
	var flick := sin(t * 9.1 + _phase) * 0.06 + sin(t * 23.0 + _phase * 2.1) * 0.035
	var floor_k := float(cfg.get("light_floor", 0.72))
	var k := maxf(1.0 + flick - 0.38 * _gutter, floor_k) + 0.6 * _flare
	_light.light_energy = float(cfg.get("light_energy", 1.8)) * lit * k
	_light.visible = lit > 0.01
	_light.position = Vector3(0, float(cfg.get("flame_h", 0.34)) * 0.8, 0)
	_light.global_position = head + up * float(cfg.get("flame_h", 0.34)) * 0.8

## Wind and snow on the flame right now, 0 steady .. 0.8 (tests read it).
func gutter() -> float:
	return _gutter

func light() -> OmniLight3D:
	return _light
