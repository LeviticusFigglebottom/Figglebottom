class_name QuadRig
extends Node
## Driver for a Tripo quadruped (the Hearthhound): one real clip (walk), the
## rest procedural. Tripo's quadruped rig has no retarget profile, so poses
## are authored as skeleton-space Euler offsets (degrees; the rig faces -Z in
## skeleton space: +X pitches a leg's tip forward and lifts a nose, Y turns,
## Z rolls) composed onto each bone at its pivot, plus a root lift in metres
## of skeleton space. Poses blend by weight, so "lie" eases into "crouch".
## Timing stays with the caller (enemy data); poses are flavour.

var skel: Skeleton3D
var ap: AnimationPlayer
var poses: Dictionary = {}          # name -> {bone: [x, y, z], "_root": [x, y, z]}
var _w: Dictionary = {}             # pose name -> current weight
var _w_to: Dictionary = {}          # pose name -> target weight
var _w_speed: Dictionary = {}
var _walk_t := 0.0
var _walk_w := 0.0
var _walk_len := 1.0
var _rest_q: Dictionary = {}        # bone index -> rest local rotation
var _glob_q: Dictionary = {}        # bone index -> rest global rotation (skeleton space)
var _root := -1
var _root_rest := Vector3.ZERO
var _anim_bones: Array = []         # bone indices the walk clip keys
var shake := 0.0                    # 0..1: the grab shake (head and neck whip)
var _shake_t := 0.0
var stride := 1.4

func setup(p_skel: Skeleton3D, p_ap: AnimationPlayer, p_poses: Dictionary) -> void:
	skel = p_skel
	ap = p_ap
	poses = p_poses
	for i in skel.get_bone_count():
		_rest_q[i] = skel.get_bone_rest(i).basis.get_rotation_quaternion()
		_glob_q[i] = skel.get_bone_global_rest(i).basis.get_rotation_quaternion()
	_root = skel.find_bone("tripo__Root")
	if _root >= 0:
		_root_rest = skel.get_bone_rest(_root).origin
	if ap != null and ap.has_animation("walk"):
		ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var a := ap.get_animation("walk")
		a.loop_mode = Animation.LOOP_LINEAR
		_walk_len = a.length
		ap.play("walk")
		for t in a.get_track_count():
			var bn := String(a.track_get_path(t).get_concatenated_subnames())
			var bi := skel.find_bone(bn)
			if bi >= 0 and not bi in _anim_bones:
				_anim_bones.append(bi)
	for n in poses:
		_w[n] = 0.0
		_w_to[n] = 0.0
		_w_speed[n] = 4.0
	process_physics_priority = -10   # pose before the owner's state machine reads it

## Ease a pose to `weight` over `blend` seconds (0 releases it).
func set_pose(name: String, weight := 1.0, blend := 0.2) -> void:
	if not poses.has(name):
		return
	_w_to[name] = weight
	_w_speed[name] = 1.0 / maxf(blend, 0.01)

## pose -> [next pose, seconds before it, blend] (clip_meta pose_seq): an
## extension pose hands over to its landing on a timer.
var pose_seq: Dictionary = {}
var _seq_next := ""
var _seq_t := 0.0
var _seq_blend := 0.1

## Release every pose except `keep`.
func only(keep: String, blend := 0.2) -> void:
	for n in poses:
		set_pose(n, 1.0 if n == keep else 0.0, blend)
	_seq_next = ""
	var sq = pose_seq.get(keep)
	if sq is Array and (sq as Array).size() >= 3 and poses.has(String(sq[0])):
		_seq_next = String(sq[0])
		_seq_t = float(sq[1])
		_seq_blend = float(sq[2])

func weight(name: String) -> float:
	return float(_w.get(name, 0.0))

func gait(dt: float, ground_speed: float) -> void:
	var want := clampf(ground_speed / 0.6, 0.0, 1.0)
	_walk_w = move_toward(_walk_w, want, dt * 5.0)
	if ground_speed > 0.05:
		_walk_t = fposmod(_walk_t + dt * clampf(ground_speed / stride, 0.5, 2.6), _walk_len)

func _physics_process(dt: float) -> void:
	if skel == null:
		return
	if _seq_next != "":
		_seq_t -= dt
		if _seq_t <= 0.0:
			var nx := _seq_next
			only(nx, _seq_blend)
	for n in _w:
		_w[n] = move_toward(_w[n], _w_to[n], dt * _w_speed[n])
	_shake_t += dt
	skel.reset_bone_poses()
	if ap != null and _walk_w > 0.001:
		ap.seek(_walk_t, true)
		ap.advance(0.0)
		if _walk_w < 0.999:
			for bi in _anim_bones:
				skel.set_bone_pose_rotation(bi, _rest_q[bi].slerp(skel.get_bone_pose_rotation(bi), _walk_w))
				if bi == _root:
					skel.set_bone_pose_position(bi, _root_rest.lerp(skel.get_bone_pose_position(bi), _walk_w))
	# procedural offsets, weighted, composed in skeleton space at each pivot
	var acc: Dictionary = {}
	var lift := Vector3.ZERO
	for n in poses:
		var w: float = _w[n]
		if w <= 0.001:
			continue
		var p: Dictionary = poses[n]
		for bn in p:
			if bn == "_root":
				var r: Array = p[bn]
				lift += Vector3(r[0], r[1], r[2]) * w
				continue
			var e: Array = p[bn]
			var prev: Vector3 = acc.get(bn, Vector3.ZERO)
			acc[bn] = prev + Vector3(e[0], e[1], e[2]) * w
	if shake > 0.001:
		var s := sin(_shake_t * 26.0) * 34.0 * shake
		for bn in ["tripo__Head_1", "tripo__Head_2"]:
			var prev2: Vector3 = acc.get(bn, Vector3.ZERO)
			acc[bn] = prev2 + Vector3(0, s, s * 0.4)
	for bn in acc:
		var bi := skel.find_bone(bn)
		if bi < 0:
			continue
		var d: Vector3 = acc[bn]
		var r2 := Quaternion.from_euler(Vector3(deg_to_rad(d.x), deg_to_rad(d.y), deg_to_rad(d.z)))
		var g: Quaternion = _glob_q[bi]
		skel.set_bone_pose_rotation(bi, skel.get_bone_pose_rotation(bi) * (g.inverse() * r2 * g))
	if _root >= 0 and lift != Vector3.ZERO:
		skel.set_bone_pose_position(_root, skel.get_bone_pose_position(_root) + lift)
