class_name CharVisual
extends Node3D
## Shared skeletal visual driver for player, enemies and NPCs. Instances a
## skel_* glb (armature + skinned mesh), builds the SkelAnim clip library
## against its rest pose, cross-fades locomotion cycles to actual ground
## speed, and mounts gear on bones via BoneAttachment3D.

var body: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var trail: MeshInstance3D
var weapon_mount: Node3D
var shield_mount: Node3D
var head_mount: Node3D
var weapon_kit := ""

## How each weapon kit rides the fist outside active attack swings.
## In relaxed stances (idle/walk/run), hand_r's +Y points ~36 deg forward of
## straight down (-Y world) at y ~ 0.87 m. Rotating +X on weapon_mount pitches
## the blade/shaft upward so weapons never stab into the floor at rest.
const CARRY_POSE := {
	"hewing_blade": Vector3(78, 10, -8),
	"maul": Vector3(102, 24, -18),
	"spear": Vector3(104, 14, -8),
	"greatblade": Vector3(76, 16, -10),
	"torch": Vector3(135, 0, 0),
}

const TRAIL_EXTENTS := {
	"hewing_blade": Vector2(0.12, 1.08),
	"greatblade": Vector2(0.22, 1.54),
	"maul": Vector2(0.45, 1.18),
	"spear": Vector2(1.10, 2.30),
}

## Clips authored with the blade extending straight along hand_r +Y.
const ZERO_MOUNT_CLIPS := [
	"attack_l1", "attack_l2", "attack_h", "riposte",
	"atk_r", "atk_double", "atk_thrust", "atk_over", "atk_back", "atk_spin",
	"atk_2h_cleave", "atk_2h_sweep", "atk_2h_thrust",
	"twohand_idle", "twohand_walk", "kneel", "seppuku",
]

## ground speed (m/s) at which the walk / run cycles play at 1x
var stride := 2.6
var run_stride := 5.2
var footsteps := false
var step_volume := -14.0

var _step_i := 0
var _lean := Vector2.ZERO
var _flinch_amp := 0.0
var _flinch_phase := 0.0
var _flinch_axis := Vector3(1, 0, 0)

## Locomotion clip substitutions (e.g. a two-handed carry:
## {"idle": "twohand_idle", "walk": "twohand_walk", "run": "twohand_walk"}).
## Pacing still follows the base gait; only the clip swaps.
var loco_override := {}

const LOCO := ["idle", "walk", "run", "twohand_idle", "twohand_walk", ""]

func build_body(skel_id: String, amp := 1.0, sway := 1.0, vis_scale := 1.0) -> void:
	body = KitLib.instance(skel_id)
	body.name = "Body"
	if vis_scale != 1.0:
		body.scale = Vector3.ONE * vis_scale
	add_child(body)
	skel = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		push_error("CharVisual: '%s' has no Skeleton3D" % skel_id)
		return
	anim = AnimationPlayer.new()
	anim.name = "Anim"
	add_child(anim)
	anim.root_node = anim.get_path_to(self)
	anim.add_animation_library("", SkelAnim.build_library(skel, get_path_to(skel), amp, sway))
	anim.play("idle")
	anim.advance(randf() * 1.7)   # desync crowds

## Upper-body / rig hit-flinch impulse on melee impact or block.
func flinch(world_dir: Vector3, might := 1.0) -> void:
	var local_dir := global_transform.basis.inverse() * world_dir
	local_dir.y = 0.0
	if local_dir.length_squared() < 0.001:
		local_dir = Vector3(0, 0, 1)
	else:
		local_dir = local_dir.normalized()
	_flinch_axis = Vector3(local_dir.z, 0.22 * signf(local_dir.x), -local_dir.x).normalized()
	_flinch_amp = clampf(_flinch_amp + 0.24 * might, 0.0, 0.38)
	_flinch_phase = 0.0

func _process(dt: float) -> void:
	if body == null:
		return
	if _flinch_amp > 0.0005:
		_flinch_phase += dt * 24.0
		_flinch_amp = move_toward(_flinch_amp, 0.0, dt * 1.35)
		var wave := sin(_flinch_phase) * _flinch_amp
		body.rotation = _flinch_axis * wave
	elif body.rotation != Vector3.ZERO:
		body.rotation = Vector3.ZERO

## A gear mount that rides a bone. Returned node is a child of the
## BoneAttachment3D; offset/orient it freely, then parent kit pieces to it.
func mount(bone: String) -> Node3D:
	var att := BoneAttachment3D.new()
	att.name = "Att_" + bone
	skel.add_child(att)
	att.bone_name = bone
	var m := Node3D.new()
	m.name = "Mount"
	att.add_child(m)
	return m

## Standard right-hand weapon grip. Kit weapons extend blade +Y from the
## grip origin, and the hand bone's +Y runs past the fingers — so an
## identity mount carries the blade beyond the fist (down when relaxed).
func mount_weapon_hand() -> Node3D:
	weapon_mount = mount("hand_r")
	weapon_mount.position = Vector3(0, 0.05, 0)
	return weapon_mount

func set_weapon(kit_id: String) -> void:
	if weapon_mount == null:
		mount_weapon_hand()
	for c in weapon_mount.get_children():
		c.queue_free()
	weapon_kit = kit_id
	if kit_id != "":
		weapon_mount.add_child(KitLib.instance(kit_id))
	if trail != null:
		var ext: Vector2 = TRAIL_EXTENTS.get(weapon_kit, Vector2(0.12, 1.08))
		trail.set("base_up", ext.x)
		trail.set("tip_up", ext.y)
	var cur: String = anim.current_animation if anim != null else "idle"
	apply_carry_pose(cur)

func apply_carry_pose(clip := "") -> void:
	if weapon_mount == null:
		return
	var c: String = clip
	if c == "" and anim != null:
		c = anim.current_animation
	if c in ZERO_MOUNT_CLIPS:
		weapon_mount.rotation_degrees = Vector3.ZERO
	else:
		weapon_mount.rotation_degrees = Vector3(CARRY_POSE.get(weapon_kit, Vector3.ZERO))

const _SWING_TRAIL := preload("res://src/chars/swing_trail.gd")

func add_trail() -> void:
	var st: MeshInstance3D = _SWING_TRAIL.new()
	st.name = "Trail"
	st.set("target", weapon_mount)
	var ext: Vector2 = TRAIL_EXTENTS.get(weapon_kit, Vector2(0.12, 1.08))
	st.set("base_up", ext.x)
	st.set("tip_up", ext.y)
	trail = st
	# sibling of the weapon so set_weapon() never frees it
	weapon_mount.get_parent().add_child(trail)

func play(clip: String, blend := 0.12, speed := 1.0) -> void:
	if anim == null:
		return
	anim.speed_scale = 1.0
	if anim.has_animation(clip):
		anim.play(clip, blend, speed)
	apply_carry_pose(clip)

func back_to_idle(blend := 0.2) -> void:
	if anim == null:
		return
	anim.speed_scale = 1.0
	var clip := String(loco_override.get("idle", "idle"))
	anim.play(clip, blend)
	apply_carry_pose(clip)

func idle(blend := 0.25) -> void:
	back_to_idle(blend)

## Locomotion: cross-fade idle/walk/run by ground speed and time the cycle
## to the actual stride so feet stop skating. Only touches the animation
## while a locomotion clip owns it — action clips play out untouched.
func locomotion(dt: float, ground_speed: float, accel_lean := Vector2.ZERO, grounded := true) -> void:
	if anim == null:
		return
	var cur := anim.current_animation
	if not (cur in LOCO):
		return
	var base := "idle"
	if grounded and ground_speed > 0.55:
		base = "run" if ground_speed > stride * 1.5 else "walk"
	var want := String(loco_override.get(base, base))
	if want != cur:
		anim.play(want, 0.3)
		apply_carry_pose(want)
	match base:
		"walk":
			anim.speed_scale = clampf(ground_speed / stride, 0.55, 1.75)
		"run":
			anim.speed_scale = clampf(ground_speed / run_stride, 0.7, 1.5)
		_:
			anim.speed_scale = 1.0
	# lean into acceleration (whole-rig, subtle)
	_lean = _lean.lerp(accel_lean if base != "idle" else Vector2.ZERO, 1.0 - exp(-7.0 * dt))
	rotation.x = clampf(-_lean.y * 0.05, -0.1, 0.1)
	rotation.z = clampf(_lean.x * 0.04, -0.09, 0.09)
	# footfalls at each half-cycle
	if footsteps and want != "idle" and grounded:
		var half: float = maxf(anim.current_animation_length * 0.5, 0.01)
		var idx := int(anim.current_animation_position / half)
		if idx != _step_i:
			_step_i = idx
			AudioDirector.sfx_at("res://assets/audio/step%d.wav" % ((idx % 2) + 1),
					global_position, step_volume, randf_range(0.9, 1.1))
