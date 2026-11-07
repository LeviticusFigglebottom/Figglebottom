class_name CameraRig
extends Node3D
## Third-person orbit + soulslike lock-on. Lives on the player root.
## Chain: self (yaw, at neck height) -> Pitch -> SpringArm3D -> Camera3D.

var pitch_node: Node3D
var spring: SpringArm3D
var cam: Camera3D

var yaw := 0.0
var pitch := -0.22
var locked_target: Node3D = null
var sensitivity := 0.0035

var _shake_t := 0.0
var _shake_strength := 0.0
var _shake_clock := 0.0
var _fov_base := 62.0
var _fov_punch := 0.0
var _lock_reticle: MeshInstance3D = null

const LOCK_RETICLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float pulse = 0.92 + 0.08 * sin(TIME * 5.5);
	float core = exp(-r * r * 22.0) * 1.15;
	float ring = exp(-pow((r - 0.52 * pulse) * 9.5, 2.0)) * 0.85;
	float diamond = exp(-((abs(p.x) + abs(p.y)) * 4.2)) * 0.45;
	float a = clamp(core + ring + diamond, 0.0, 1.0) * smoothstep(1.0, 0.72, r);
	vec3 col = mix(vec3(1.0, 0.82, 0.42), vec3(1.0, 0.97, 0.86), clamp(core, 0.0, 1.0));
	ALBEDO = col * a;
	ALPHA = a;
}
"""

func _ready() -> void:
	position = Vector3(0, 1.55, 0)
	pitch_node = Node3D.new(); pitch_node.name = "Pitch"; add_child(pitch_node)
	spring = SpringArm3D.new()
	spring.spring_length = float(DB.tuning("camera/distance", 3.6))
	# Sweep a sphere, not a ray: the camera rides 0.35 m off the arm's axis
	# (over-the-shoulder), so a bare ray let that offset poke through walls
	# and reveal the exterior. The sphere envelope contains the offset camera.
	spring.margin = 0.05
	var swept := SphereShape3D.new()
	swept.radius = 0.45
	spring.shape = swept
	spring.collision_mask = RH.M_WORLD_ALL
	pitch_node.add_child(spring)
	cam = Camera3D.new()
	_fov_base = float(DB.tuning("camera/fov", 62))
	cam.fov = _fov_base
	cam.near = 0.1
	cam.far = 300.0
	spring.add_child(cam)
	cam.position = Vector3(0.35, 0.25, 0)   # over-the-shoulder bias
	cam.current = true
	sensitivity = float(DB.tuning("camera/sensitivity", 0.0035))
	Juice.shake_requested.connect(_on_shake)
	set_as_top_level(false)
	_build_lock_reticle()

func _build_lock_reticle() -> void:
	_lock_reticle = MeshInstance3D.new()
	_lock_reticle.name = "LockReticle"
	_lock_reticle.top_level = true
	_lock_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var qm := QuadMesh.new()
	qm.size = Vector2(0.42, 0.42)
	var sh := Shader.new()
	sh.code = LOCK_RETICLE_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	qm.material = sm
	_lock_reticle.mesh = qm
	_lock_reticle.visible = false
	add_child(_lock_reticle)

func _on_shake(might: float, time: float) -> void:
	_shake_strength = maxf(_shake_strength, might)
	_shake_t = maxf(_shake_t, time)
	_fov_punch = maxf(_fov_punch, might * 3.8)

## Settings-menu seams (PauseUI persists these across runs).
func set_sensitivity(v: float) -> void:
	sensitivity = v

func set_base_fov(f: float) -> void:
	_fov_base = f
	if cam != null:
		cam.fov = f

func mouse_look(rel: Vector2) -> void:
	if locked_target != null and (not is_instance_valid(locked_target) or locked_target.get("dead") == true):
		locked_target = null
	if locked_target != null:
		# a hard flick breaks the lock so the camera can never feel "stuck"
		if absf(rel.x) > 60.0:
			locked_target = null
		return
	yaw -= rel.x * sensitivity
	pitch = clampf(pitch - rel.y * sensitivity, -1.15, 0.55)

func stick_look(v: Vector2, dt: float) -> void:
	if locked_target != null or v.length_squared() < 0.02:
		return
	yaw -= v.x * 2.6 * dt
	pitch = clampf(pitch - v.y * 1.8 * dt, -1.15, 0.55)

func try_lock(candidates: Array) -> void:
	if locked_target != null:
		locked_target = null
		return
	var best: Node3D = null
	var best_score := INF
	var fwd := -global_transform.basis.z
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var to: Vector3 = c.global_position - global_position
		var d := to.length()
		if d > 16.0:
			continue
		var ang := fwd.angle_to(to.normalized())
		if ang > 1.1:
			continue
		if not _has_los(c):
			continue                      # never lock through a wall
		var score := d + ang * 6.0
		if score < best_score:
			best_score = score
			best = c
	locked_target = best

## True when nothing world-solid stands between the camera and the target's
## chest. Ray runs from the CAMERA (not the player) so a foe peeking past a
## pillar you can actually see is still lockable.
func _has_los(c: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position if cam != null else global_position
	var to := c.global_position + Vector3.UP * 1.1
	var q := PhysicsRayQueryParameters3D.create(from, to, RH.M_WORLD_ALL)
	q.exclude = [get_parent()]
	return space.intersect_ray(q).is_empty()

func _physics_process(dt: float) -> void:
	if locked_target != null and (not is_instance_valid(locked_target) or locked_target.get("dead") == true):
		locked_target = null
	if locked_target != null:
		var to: Vector3 = locked_target.global_position - global_position
		var flat := Vector2(to.x, to.z)
		var target_yaw := atan2(-flat.x, -flat.y)
		yaw = lerp_angle(yaw, target_yaw, 1.0 - exp(-8.0 * dt))
		# aim at the target's CHEST from a comfortable over-shoulder line
		var target_pitch := clampf(atan2(to.y + 1.1, maxf(flat.length(), 2.6)) - 0.14, -0.42, 0.22)
		pitch = lerpf(pitch, target_pitch, 1.0 - exp(-6.0 * dt))
		if _lock_reticle != null:
			_lock_reticle.visible = true
			_lock_reticle.global_position = locked_target.global_position + Vector3(0, 1.18, 0)
	elif _lock_reticle != null:
		_lock_reticle.visible = false

	rotation.y = yaw
	pitch_node.rotation.x = pitch
	_fov_punch = move_toward(_fov_punch, 0.0, dt * 16.0)
	# 3-axis rotational trauma + positional micro-shake
	if _shake_t > 0.0:
		_shake_t -= dt
		_shake_clock += dt * 42.0
		var s := _shake_strength * minf(_shake_t * 3.0, 1.0)
		var s2 := s * s
		cam.h_offset = (randf() - 0.5) * s * 0.24
		cam.v_offset = (randf() - 0.5) * s * 0.24
		cam.rotation = Vector3(
			sin(_shake_clock * 1.3) * s2 * 0.065,
			cos(_shake_clock * 0.9) * s2 * 0.055,
			sin(_shake_clock * 1.7 + 1.1) * s2 * 0.095
		)
		if _shake_t <= 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			cam.rotation = Vector3.ZERO
			_shake_strength = 0.0

## Bow sight: RMB narrows the eye while the bow is in hand.
var zoomed := false

func set_sprinting(on: bool, dt: float) -> void:
	var target := _fov_base + (6.0 if on else 0.0) - (26.0 if zoomed else 0.0) - _fov_punch
	cam.fov = lerpf(cam.fov, target, 1.0 - exp(-(9.0 if zoomed else 6.0) * dt))

## Camera-relative movement basis on the ground plane.
func move_basis() -> Basis:
	return Basis(Vector3.UP, yaw)
