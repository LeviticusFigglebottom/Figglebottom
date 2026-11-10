class_name CharVisual
extends Node3D
## Shared skeletal visual driver for player, enemies and NPCs. Two bodies:
##   mannequin (build_body): the 17-bone greybox, SkelAnim clips on an
##     AnimationPlayer, cross-faded locomotion.
##   humanoid (build_model): a Mixamo-rigged Tripo model driven by a
##     HumanoidRig AnimationTree over the shared HumanoidLib (ADR 0004).
## Either way it times locomotion to ground speed, rate-scales action clips
## so contact lands on data, and mounts gear on bones via BoneAttachment3D.

var body: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var trail: MeshInstance3D
var weapon_mount: Node3D
var shield_mount: Node3D
var head_mount: Node3D
var weapon_kit := ""
## Humanoid mode: the AnimationTree driver (null for mannequins).
var rig: HumanoidRig = null
## Quadruped mode (clip_meta.json models.<id>.rig == "quadruped"): one real
## walk clip plus weighted procedural poses (QuadRig).
var quad: QuadRig = null
var _quad_clip := ""
var model_id := ""

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
	"attack_l1", "attack_l2", "attack_h", "attack_sprint", "riposte",
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
var _antic_t := 0.0
var _antic_dur := 0.0
var _antic_deg := 0.0
var _dig := 0.0
var _dig_rate := 1.0

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

## Humanoid body from clip_meta.json "models". Returns false (nothing built)
## when the model is unknown, so callers fall back to a mannequin.
func build_model(id: String) -> bool:
	if String(HumanoidLib.model_cfg(id).get("rig", "")) == "quadruped":
		return false   # build_quadruped's
	if not HumanoidLib.has_model(id):
		push_warning("CharVisual: no humanoid model '%s'; using a mannequin" % id)
		return false
	var cfg := HumanoidLib.model_cfg(id)
	body = Node3D.new()
	body.name = "Body"   # flinch target: its rotation is reset every frame
	add_child(body)
	var holder := Node3D.new()
	holder.name = "Model"
	# Tripo meshes face +Z; Godot characters face -Z
	holder.rotation_degrees.y = float(cfg.get("yaw_deg", 180.0))
	holder.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	body.add_child(holder)
	var inst := HumanoidLib.instance_model(id)
	holder.add_child(inst)
	skel = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		ap.free()   # the shared library drives this rig, not the glb's own player
	model_id = id
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(id, skel)
	return true

## A Tripo quadruped from clip_meta.json: its glb's walk plays by ground
## speed, everything else is a QuadRig pose. False when not a quadruped.
func build_quadruped(id: String) -> bool:
	var cfg := HumanoidLib.model_cfg(id)
	if String(cfg.get("rig", "")) != "quadruped" or not ResourceLoader.exists(String(cfg.get("scene", ""))):
		return false
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	var holder := Node3D.new()
	holder.name = "Model"
	holder.rotation_degrees.y = float(cfg.get("yaw_deg", 180.0))
	holder.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	body.add_child(holder)
	var inst := HumanoidLib.instance_model(id)
	holder.add_child(inst)
	skel = inst.find_child("Skeleton3D", true, false) as Skeleton3D
	model_id = id
	quad = QuadRig.new()
	quad.name = "Quad"
	add_child(quad)
	quad.setup(skel, inst.find_child("AnimationPlayer", true, false) as AnimationPlayer, cfg.get("poses", {}))
	quad.stride = float(cfg.get("stride", 1.4))
	return true

func is_humanoid() -> bool:
	return rig != null

func is_quadruped() -> bool:
	return quad != null

## The clip that owns the rig ("" once a one-shot has finished).
func current_clip() -> String:
	if rig != null:
		return rig.current_clip()
	if quad != null:
		return _quad_clip
	return String(anim.current_animation) if anim != null else ""

## Length (s at 1x) of a clip as it plays: the section for humanoids.
func clip_length(clip: String) -> float:
	if rig != null:
		return rig.clip_length(clip)
	if quad != null:
		return 1.0
	if anim != null and anim.has_animation(clip):
		return anim.get_animation(clip).length
	return 1.0

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
	# strike polish, added on top of the clip: a lean away through the
	# wind-up that is spent by the contact frame, and a short dig forward on
	# a landed hit. Both run on scaled time, so Juice's hit-stop freezes the
	# dig (and the clip) on the impact pose.
	if _antic_dur > 0.0:
		_antic_t += dt
		var u := _antic_t / _antic_dur
		if u >= 1.0:
			_antic_dur = 0.0
		else:
			body.rotation.x += deg_to_rad(_antic_deg) * sin(PI * u) * (1.0 - u)
	if _dig > 0.0005:
		body.rotation.x -= deg_to_rad(_dig)
		_dig = move_toward(_dig, 0.0, dt * _dig_rate)

## Lean away from the strike while it winds up (`windup` seconds to contact).
func anticipate(windup: float) -> void:
	var pol: Dictionary = HumanoidLib.meta().get("polish", {})
	_antic_deg = float(pol.get("antic_lean_deg", 0.0))
	_antic_dur = maxf(windup, 0.0) if rig != null and _antic_deg != 0.0 else 0.0
	_antic_t = 0.0

func cancel_anticipation() -> void:
	_antic_dur = 0.0

## A landed blow: the body digs in behind the weapon and eases back out.
func impact_dig(might := 1.0) -> void:
	if rig == null:
		return
	var pol: Dictionary = HumanoidLib.meta().get("polish", {})
	_dig = float(pol.get("impact_dig_deg", 0.0)) * might
	_dig_rate = _dig / maxf(float(pol.get("impact_dig_ease", 0.2)), 0.01)

## Whether a clip resolves on this rig (humanoid: through sets and aliases).
func has_clip(clip: String) -> bool:
	if rig != null:
		return rig.has_clip(clip)
	return anim != null and anim.has_animation(clip)

## A one-shot action has played out (a humanoid holds its last frame).
func action_done() -> bool:
	if rig != null:
		return not rig.action_active()
	return anim == null or not anim.is_playing()

## A gear mount that rides a bone. Returned node is a child of the
## BoneAttachment3D; offset/orient it freely, then parent kit pieces to it.
func mount(bone: String) -> Node3D:
	if rig != null:
		bone = HumanoidLib.bone(bone)   # mannequin names keep working
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
	if rig != null:
		weapon_mount = mount_slot("weapon")
		return weapon_mount
	weapon_mount = mount("hand_r")
	weapon_mount.position = Vector3(0, 0.05, 0)
	return weapon_mount

## Humanoid gear slot from clip_meta.json "mounts": bone + grip offset.
func mount_slot(slot: String) -> Node3D:
	var c := HumanoidLib.mount_cfg(slot)
	var m := mount(String(c.get("bone", "mixamorig_RightHand")))
	m.set_meta("slot", slot)
	_apply_slot(m)
	return m

func _apply_slot(m: Node3D) -> void:
	# a weapon class may grip differently (mounts "weapon@twohand")
	var c := HumanoidLib.class_mount_cfg(String(m.get_meta("slot", "weapon")), rig.clip_set if rig != null else "")
	var p: Array = c.get("pos", [0, 0, 0])
	var r: Array = c.get("rot", [0, 0, 0])
	m.position = Vector3(p[0], p[1], p[2])
	m.rotation_degrees = Vector3(r[0], r[1], r[2])

## The weapon mount's world transform read straight from the skeleton's
## current pose. A BoneAttachment3D only catches up when the skeleton next
## publishes its pose; hit volumes need this tick's blade, not last frame's.
func weapon_xform() -> Transform3D:
	if weapon_mount == null:
		return global_transform
	var att := weapon_mount.get_parent() as BoneAttachment3D
	var bi := skel.find_bone(att.bone_name) if att != null and skel != null else -1
	if bi < 0:
		return weapon_mount.global_transform
	return skel.global_transform * skel.get_bone_global_pose(bi) * weapon_mount.transform

## A bone's world transform from the skeleton's current pose (see weapon_xform).
func bone_xform(bone: String) -> Transform3D:
	var bi := skel.find_bone(bone) if skel != null else -1
	if bi < 0:
		return global_transform
	return skel.global_transform * skel.get_bone_global_pose(bi)

func _trail_extents() -> Vector2:
	if rig != null:
		var t: Array = HumanoidLib.weapon_cfg(weapon_kit).get("trail", [])
		if t.size() == 2:
			return Vector2(t[0], t[1])
	return TRAIL_EXTENTS.get(weapon_kit, Vector2(0.12, 1.08))

func set_weapon(kit_id: String) -> void:
	if weapon_mount == null:
		mount_weapon_hand()
	for c in weapon_mount.get_children():
		c.queue_free()
	weapon_kit = kit_id
	if rig != null and bool(HumanoidLib.model_cfg(model_id).get("clip_sets", false)):
		# the weapon's class picks the clips that answer attack_l1, block, ...
		rig.clip_set = HumanoidLib.weapon_class(kit_id)
	if kit_id != "":
		var w: Node3D = HumanoidLib.weapon_instance(kit_id) if rig != null else null
		weapon_mount.add_child(w if w != null else KitLib.instance(kit_id))
	if trail != null:
		var ext := _trail_extents()
		trail.set("base_up", ext.x)
		trail.set("tip_up", ext.y)
	apply_carry_pose(current_clip())

func apply_carry_pose(clip := "") -> void:
	if weapon_mount == null:
		return
	if rig != null:
		_apply_slot(weapon_mount)   # the grip is data; humanoid clips carry the blade
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
	var ext := _trail_extents()
	st.set("base_up", ext.x)
	st.set("tip_up", ext.y)
	trail = st
	# sibling of the weapon so set_weapon() never frees it
	weapon_mount.get_parent().add_child(trail)

func play(clip: String, blend := 0.12, speed := 1.0) -> void:
	if rig != null:
		rig.play(clip, blend, speed)
		return
	if quad != null:
		_quad_play(clip, blend / maxf(speed, 0.05))
		return
	if anim == null:
		return
	anim.speed_scale = 1.0
	if anim.has_animation(clip):
		anim.play(clip, blend, speed)
	apply_carry_pose(clip)

## Play an action so its contact frame lands `contact_at` seconds from now
## (an attack's data windup). Contact points are data: clip_meta.json.
## lo/hi bound the rate (the player keeps the source's 0.55-1.85 clamp).
func play_timed(clip: String, contact_at: float, blend := 0.08, lo := 0.0, hi := INF) -> float:
	if rig != null:
		return rig.play_timed(clip, contact_at, blend, lo, hi)
	if quad != null:
		_quad_play(clip, contact_at)   # a pose eases in over the windup
		return 1.0
	var rate := clampf(HumanoidLib.mannequin_contact(clip) / maxf(contact_at, 0.02), lo, hi)
	play(clip, blend, rate)
	return rate

func back_to_idle(blend := 0.2) -> void:
	if rig != null:
		rig.stop_action(blend)
		return
	if quad != null:
		_quad_play("", blend)
		return
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
	if rig != null:
		_humanoid_locomotion(dt, ground_speed, accel_lean, grounded)
		return
	if quad != null:
		quad.gait(dt, ground_speed if grounded else 0.0)
		return
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
			AudioDirector.footstep(global_position, idx, step_volume)

func _humanoid_locomotion(dt: float, ground_speed: float, accel_lean: Vector2, grounded: bool) -> void:
	var gait := rig.locomotion(dt, ground_speed, stride, run_stride, grounded)
	if gait == "":
		return   # an action owns the rig
	_lean = _lean.lerp(accel_lean if gait != "idle" else Vector2.ZERO, 1.0 - exp(-7.0 * dt))
	rotation.x = clampf(-_lean.y * 0.05, -0.1, 0.1)
	rotation.z = clampf(_lean.x * 0.04, -0.09, 0.09)
	if footsteps and gait != "idle" and grounded:
		var cyc := rig.loco_cycle()
		var idx := int(cyc.x / maxf(cyc.y * 0.5, 0.01))
		if idx != _step_i:
			_step_i = idx
			AudioDirector.footstep(global_position, idx, step_volume)

## Quadruped clip vocabulary -> poses ("death" lies it on its side; an
## unknown clip, or "", releases every pose back to the stand).
func _quad_play(clip: String, blend: float) -> void:
	var pose := String((HumanoidLib.model_cfg(model_id).get("pose_alias", {}) as Dictionary).get(clip, clip))
	_quad_clip = clip
	if quad.poses.has(pose):
		quad.only(pose, blend)
	else:
		quad.only("", blend)
