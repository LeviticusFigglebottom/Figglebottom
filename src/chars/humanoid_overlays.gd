class_name HumanoidOverlays
## Procedural clips for states no Tripo preset covers (roll, block, parry,
## drink, rest, cast, the death fall). SkelAnim's idea on the Mixamo rig:
## eased Euler deltas (degrees) composed onto a base pose, here the first
## frame of the model's idle, so a hunched body stays hunched.
##
## Deltas are in BODY space, not bone-local, so the tables never depend on a
## rig's bone rolls: X = the character's left, Y = up, Z = forward (the
## retargeted skeleton faces +Z). Right-handed, about the bone's own pivot:
##   upward bones (Hips as root, Spine*, Neck, Head):
##     +X bows forward, +Y turns left, +Z leans right.
##   downward bones (UpLeg, Leg, hanging Arm and ForeArm):
##     -X swings the tip forward, +X back; outward is -Z on the right
##     limb and +Z on the left. Knees flex +X, elbows flex -X.
##   Foot (points forward): -X lifts the toes.
## Hips offsets are skeleton-space [left, up, forward] in hips-heights.

const P := "mixamorig_"

## clip -> {len, loop, rot: {bone: [[t, x, y, z]...]}, pos: {Hips: [[t, dx, dy, dz]...]}}
static func tables() -> Dictionary:
	return {
		"death": {"len": 1.6, "rot": {
			"Hips": [[0.0, 0, 0, 0], [0.35, 8, 0, 0], [0.75, 55, 0, -6], [1.05, 86, 0, -4], [1.6, 90, 0, -4]],
			"Spine": [[0.0, 0, 0, 0], [0.35, 14, 0, 0], [0.75, 16, 0, 0], [1.05, 0, 0, 0], [1.6, -4, 0, 0]],
			"Spine2": [[0.0, 0, 0, 0], [0.35, 8, 0, 0], [0.75, 6, 0, 0], [1.05, 0, 0, 0]],
			"Neck": [[0.0, 0, 0, 0], [0.35, 10, 0, 0], [1.05, -15, 25, 0], [1.6, -18, 30, 0]],
			"Head": [[0.0, 0, 0, 0], [0.35, 12, 0, 0], [1.05, -15, 35, 0], [1.6, -18, 40, 0]],
			"LeftUpLeg": [[0.0, 0, 0, 0], [0.35, -12, 0, 4], [0.75, -45, 0, 6], [1.05, -6, 0, 8], [1.6, -2, 0, 8]],
			"RightUpLeg": [[0.0, 0, 0, 0], [0.35, -12, 0, -4], [0.75, -45, 0, -6], [1.05, -6, 0, -8], [1.6, -2, 0, -8]],
			"LeftLeg": [[0.0, 0, 0, 0], [0.35, 95, 0, 0], [0.75, 85, 0, 0], [1.05, 18, 0, 0], [1.6, 12, 0, 0]],
			"RightLeg": [[0.0, 0, 0, 0], [0.35, 95, 0, 0], [0.75, 85, 0, 0], [1.05, 18, 0, 0], [1.6, 12, 0, 0]],
			"LeftArm": [[0.0, 0, 0, 0], [0.35, -15, 0, 8], [0.75, -70, 0, 12], [1.05, -30, 0, 30], [1.6, -25, 0, 32]],
			"RightArm": [[0.0, 0, 0, 0], [0.35, -15, 0, -8], [0.75, -70, 0, -12], [1.05, -30, 0, -30], [1.6, -25, 0, -32]],
			"LeftForeArm": [[0.0, 0, 0, 0], [0.75, -35, 0, 0], [1.05, -15, 0, 0], [1.6, -12, 0, 0]],
			"RightForeArm": [[0.0, 0, 0, 0], [0.75, -35, 0, 0], [1.05, -15, 0, 0], [1.6, -12, 0, 0]],
		}, "pos": {"Hips": [[0.0, 0, 0, 0], [0.35, 0, -0.42, 0.04], [0.75, 0, -0.62, 0.28],
			[1.05, 0, -0.86, 0.5], [1.6, 0, -0.87, 0.52]]}},

		"roll": {"len": 1.0, "rot": {
			"Hips": [[0.0, 0, 0, 0], [0.07, 14, 0, 0], [0.2, 70, 0, 0], [0.4, 170, 0, 0], [0.6, 260, 0, 0],
				[0.8, 330, 0, 0], [1.0, 360, 0, 0]],
			"Spine": [[0.0, 0, 0, 0], [0.25, 30, 0, 0], [0.75, 30, 0, 0], [1.0, 0, 0, 0]],
			"Spine2": [[0.0, 0, 0, 0], [0.25, 15, 0, 0], [0.75, 15, 0, 0], [1.0, 0, 0, 0]],
			"Head": [[0.0, 0, 0, 0], [0.25, 25, 0, 0], [0.75, 25, 0, 0], [1.0, 0, 0, 0]],
			"LeftUpLeg": [[0.0, 0, 0, 0], [0.25, -95, 0, 0], [0.75, -95, 0, 0], [1.0, 0, 0, 0]],
			"RightUpLeg": [[0.0, 0, 0, 0], [0.25, -95, 0, 0], [0.75, -95, 0, 0], [1.0, 0, 0, 0]],
			"LeftLeg": [[0.0, 0, 0, 0], [0.25, 110, 0, 0], [0.75, 110, 0, 0], [1.0, 0, 0, 0]],
			"RightLeg": [[0.0, 0, 0, 0], [0.25, 110, 0, 0], [0.75, 110, 0, 0], [1.0, 0, 0, 0]],
			"LeftArm": [[0.0, 0, 0, 0], [0.25, -50, 0, 10], [0.75, -50, 0, 10], [1.0, 0, 0, 0]],
			"RightArm": [[0.0, 0, 0, 0], [0.25, -50, 0, -10], [0.75, -50, 0, -10], [1.0, 0, 0, 0]],
			"LeftForeArm": [[0.0, 0, 0, 0], [0.25, -80, 0, 0], [0.75, -80, 0, 0], [1.0, 0, 0, 0]],
			"RightForeArm": [[0.0, 0, 0, 0], [0.25, -80, 0, 0], [0.75, -80, 0, 0], [1.0, 0, 0, 0]],
		}, "pos": {"Hips": [[0.0, 0, 0, 0], [0.07, 0, -0.1, 0], [0.3, 0, -0.55, 0], [0.7, 0, -0.55, 0], [1.0, 0, 0, 0]]}},

		"backstep": {"len": 0.32, "rot": {
			"Spine": [[0.0, 0, 0, 0], [0.14, -8, 0, 0], [0.32, 0, 0, 0]],
			"LeftUpLeg": [[0.0, 0, 0, 0], [0.14, -20, 0, 3], [0.32, 0, 0, 0]],
			"LeftLeg": [[0.0, 0, 0, 0], [0.14, 30, 0, 0], [0.32, 0, 0, 0]],
			"RightUpLeg": [[0.0, 0, 0, 0], [0.14, 15, 0, -3], [0.32, 0, 0, 0]],
			"RightLeg": [[0.0, 0, 0, 0], [0.14, 25, 0, 0], [0.32, 0, 0, 0]],
			"LeftArm": [[0.0, 0, 0, 0], [0.14, -15, 0, 10], [0.32, 0, 0, 0]],
			"RightArm": [[0.0, 0, 0, 0], [0.14, -15, 0, -10], [0.32, 0, 0, 0]],
		}, "pos": {"Hips": [[0.0, 0, 0, 0], [0.14, 0, -0.08, -0.04], [0.32, 0, 0, 0]]}},

		"block": {"len": 2.2, "loop": true, "rot": {
			"Spine": [[0.0, 6, 0, 0], [1.1, 7.5, 0, 0], [2.2, 6, 0, 0]],
			"Spine2": [[0.0, 3, 8, 0], [1.1, 4, 8, 0], [2.2, 3, 8, 0]],
			"Head": [[0.0, 4, -6, 0], [2.2, 4, -6, 0]],
			"LeftArm": [[0.0, -62, 0, -25], [1.1, -64, 0, -25], [2.2, -62, 0, -25]],
			"LeftForeArm": [[0.0, -75, 0, 0], [2.2, -75, 0, 0]],
			"RightArm": [[0.0, -25, 0, -12], [1.1, -27, 0, -12], [2.2, -25, 0, -12]],
			"RightForeArm": [[0.0, -55, 0, 0], [2.2, -55, 0, 0]],
			"LeftUpLeg": [[0.0, -14, 0, 6], [2.2, -14, 0, 6]],
			"RightUpLeg": [[0.0, -10, 0, -6], [2.2, -10, 0, -6]],
			"LeftLeg": [[0.0, 22, 0, 0], [2.2, 22, 0, 0]],
			"RightLeg": [[0.0, 18, 0, 0], [2.2, 18, 0, 0]],
		}, "pos": {"Hips": [[0.0, 0, -0.05, 0], [1.1, 0, -0.06, 0], [2.2, 0, -0.05, 0]]}},

		"parry": {"len": 0.6, "rot": {
			"Spine2": [[0.0, 0, 0, 0], [0.08, 0, -15, 0], [0.18, 4, 18, 0], [0.6, 0, 0, 0]],
			"LeftArm": [[0.0, 0, 0, 0], [0.08, -75, 0, -30], [0.18, -70, 0, 35], [0.35, -40, 0, 20], [0.6, 0, 0, 0]],
			"LeftForeArm": [[0.0, 0, 0, 0], [0.08, -80, 0, 0], [0.18, -30, 0, 0], [0.6, 0, 0, 0]],
			"RightArm": [[0.0, 0, 0, 0], [0.18, -20, 0, -10], [0.6, 0, 0, 0]],
			"LeftUpLeg": [[0.0, 0, 0, 0], [0.12, -12, 0, 4], [0.6, 0, 0, 0]],
			"LeftLeg": [[0.0, 0, 0, 0], [0.12, 16, 0, 0], [0.6, 0, 0, 0]],
		}, "pos": {"Hips": [[0.0, 0, 0, 0], [0.12, 0, -0.04, 0], [0.6, 0, 0, 0]]}},

		"drink": {"len": 1.1, "rot": {
			"LeftArm": [[0.0, 0, 0, 0], [0.3, -75, 0, -25], [0.45, -80, 0, -30], [0.85, -80, 0, -30], [1.1, 0, 0, 0]],
			"LeftForeArm": [[0.0, 0, 0, 0], [0.3, -120, 0, 0], [0.45, -135, 0, 0], [0.85, -135, 0, 0], [1.1, 0, 0, 0]],
			"Spine2": [[0.0, 0, 0, 0], [0.45, -6, 0, 0], [0.85, -6, 0, 0], [1.1, 0, 0, 0]],
			"Neck": [[0.0, 0, 0, 0], [0.45, -10, 0, 0], [0.85, -12, 0, 0], [1.1, 0, 0, 0]],
			"Head": [[0.0, 0, 0, 0], [0.45, -14, 0, 0], [0.85, -16, 0, 0], [1.1, 0, 0, 0]],
			"RightArm": [[0.0, 0, 0, 0], [0.45, -8, 0, -6], [1.1, 0, 0, 0]],
		}},

		"rest": {"len": 1.2, "rot": {
			"Spine": [[0.0, 0, 0, 0], [0.5, 12, 0, 0], [1.2, 14, 0, 0]],
			"Head": [[0.0, 0, 0, 0], [0.5, 10, 0, 0], [1.2, 18, 0, 0]],
			"LeftUpLeg": [[0.0, 0, 0, 0], [0.5, -85, 0, 6], [1.2, -88, 0, 6]],
			"LeftLeg": [[0.0, 0, 0, 0], [0.5, 85, 0, 0], [1.2, 88, 0, 0]],
			"RightUpLeg": [[0.0, 0, 0, 0], [0.5, -5, 0, -6], [1.2, 0, 0, -6]],
			"RightLeg": [[0.0, 0, 0, 0], [0.5, 90, 0, 0], [1.2, 95, 0, 0]],
			"LeftArm": [[0.0, 0, 0, 0], [0.5, -30, 0, -5], [1.2, -35, 0, -5]],
			"LeftForeArm": [[0.0, 0, 0, 0], [1.2, -30, 0, 0]],
			"RightArm": [[0.0, 0, 0, 0], [1.2, -10, 0, -8]],
		}, "pos": {"Hips": [[0.0, 0, 0, 0], [0.5, 0, -0.4, 0], [1.2, 0, -0.45, 0]]}},

		"cast": {"len": 0.8, "rot": {
			"RightArm": [[0.0, 0, 0, 0], [0.2, -40, 0, -10], [0.32, -88, 0, 5], [0.55, -85, 0, 5], [0.8, 0, 0, 0]],
			"RightForeArm": [[0.0, 0, 0, 0], [0.2, -60, 0, 0], [0.32, -5, 0, 0], [0.55, -5, 0, 0], [0.8, 0, 0, 0]],
			"Spine2": [[0.0, 0, 0, 0], [0.2, -4, 10, 0], [0.32, 8, -10, 0], [0.8, 0, 0, 0]],
			"Head": [[0.0, 0, 0, 0], [0.32, 6, 0, 0], [0.8, 0, 0, 0]],
		}},
	}

## Build every overlay clip for `skel` on the first frame of `idle` (whose
## tracks are already normalised: "Skeleton3D:<bone>", hips in hips-heights).
static func build(skel: Skeleton3D, idle: Animation) -> Dictionary:
	var n := skel.get_bone_count()
	var base_q: Array[Quaternion] = []
	var glob_q: Array[Quaternion] = []
	base_q.resize(n)
	glob_q.resize(n)
	for i in n:
		var bn := skel.get_bone_name(i)
		var t := idle.find_track(NodePath("Skeleton3D:" + bn), Animation.TYPE_ROTATION_3D)
		base_q[i] = idle.rotation_track_interpolate(t, 0.0) if t >= 0 \
				else skel.get_bone_rest(i).basis.get_rotation_quaternion()
	# FK over rotations only: parents always precede children in a glTF skeleton
	for i in n:
		var par := skel.get_bone_parent(i)
		glob_q[i] = (glob_q[par] * base_q[i]) if par >= 0 else base_q[i]
	var hips_t := idle.find_track(NodePath("Skeleton3D:" + P + "Hips"), Animation.TYPE_POSITION_3D)
	var hips_base: Vector3 = idle.position_track_interpolate(hips_t, 0.0) if hips_t >= 0 else Vector3.ZERO
	var out := {}
	var tabs := tables()
	for clip in tabs:
		var c: Dictionary = tabs[clip]
		var a := Animation.new()
		a.length = float(c["len"])
		a.loop_mode = Animation.LOOP_LINEAR if c.get("loop", false) else Animation.LOOP_NONE
		var rot: Dictionary = c.get("rot", {})
		for i in n:
			var bn := skel.get_bone_name(i)
			var short := bn.trim_prefix(P)
			var tr := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(tr, NodePath("Skeleton3D:" + bn))
			a.track_set_interpolation_type(tr, Animation.INTERPOLATION_CUBIC)
			if rot.has(short):
				var g := glob_q[i]
				for k in rot[short]:
					var r := Quaternion.from_euler(Vector3(deg_to_rad(k[1]), deg_to_rad(k[2]), deg_to_rad(k[3])))
					# body-space rotation at the pivot, expressed in the bone's local frame
					a.rotation_track_insert_key(tr, k[0], base_q[i] * (g.inverse() * r * g))
			else:
				a.rotation_track_insert_key(tr, 0.0, base_q[i])
		var pt := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(pt, NodePath("Skeleton3D:" + P + "Hips"))
		a.track_set_interpolation_type(pt, Animation.INTERPOLATION_CUBIC)
		var pos: Array = (c.get("pos", {}) as Dictionary).get("Hips", [])
		if pos.is_empty():
			a.position_track_insert_key(pt, 0.0, hips_base)
		for k in pos:
			a.position_track_insert_key(pt, k[0], hips_base + Vector3(k[1], k[2], k[3]))
		a.set_meta("procedural", true)   # a real clip of the same name outranks it
		out[clip] = a
	return out
