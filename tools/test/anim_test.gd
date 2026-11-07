extends TestBase
## Humanoid animation layer (ADR 0004): Tripo models load retargeted, keep
## their Mixamo bones, share one library, land attack contact on the data
## windup, carry the blade in the right hand, and fall on death. Runs in the
## arena sandbox with real Enemy and Player nodes.

const MIXAMO := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
	"LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
	"RightHandThumb1", "RightHandIndex1", "RightHandMiddle1", "RightHandRing1", "RightHandPinky1",
	"LeftHandThumb1", "LeftHandIndex1", "LeftHandMiddle1", "LeftHandRing1", "LeftHandPinky1"]
const STATES := ["idle", "walk", "run", "atk_r", "stagger", "death", "roll", "block", "parry",
	"gourd", "kneel", "backstep", "cast"]

var arena: Node
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _spawn(id: String, pos: Vector3) -> Enemy:
	var e := Enemy.new()
	e.setup(id)
	arena.add_child(e)
	e.global_position = pos
	return e

func _bone_pos(v: CharVisual, bone: String) -> Vector3:
	var i := v.skel.find_bone(bone)
	return (v.skel.global_transform * v.skel.get_bone_global_pose(i)).origin

func _run() -> void:
	arena = (load("res://scenes/sandbox/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await ticks(5)
	player = arena.get_node("Player")
	player.invulnerable = true
	var meta := HumanoidLib.meta()

	print("== data and library")
	check(not meta.is_empty(), "clip_meta.json parses")
	for id in ["rimewalker", "netmender"]:
		check(HumanoidLib.has_model(id), "model '%s' is declared and its glb exists" % id)
	var shared := HumanoidLib.shared_library()
	check(shared != null and shared.get_animation_list().size() >= 13,
		"one shared library (%d clips)" % (shared.get_animation_list().size() if shared else 0))
	var donor_ap := HumanoidLib.instance_model("rimewalker")
	var real_names: Array = (donor_ap.find_child("AnimationPlayer", true, false) as AnimationPlayer).get_animation_list()
	donor_ap.free()
	var tables := HumanoidOverlays.tables()
	var clips: Dictionary = meta["clips"]
	var real: Array = []
	var proc: Array = []
	var neither: Array = []
	for c in ["idle", "walk", "run", "slash", "hit", "death", "roll", "backstep", "block", "parry", "drink", "rest", "cast"]:
		var a := shared.get_animation(c) if shared.has_animation(c) else null
		if a == null:
			neither.append(c)
		elif HumanoidLib.is_procedural(a):
			proc.append(c)
		else:
			real.append(c)
		if a != null and HumanoidLib.is_procedural(a) != (c in tables and not c in real_names):
			neither.append(c + "?")
	print("    real: %s\n    procedural: %s" % [real, proc])
	check(neither.is_empty(), "every state is a real clip or a procedural overlay (bad %s)" % [neither])
	var a_slash := shared.get_animation("slash")
	var sec: Dictionary = clips["slash"]
	check(a_slash != null and float(sec["contact"]) > float(sec["start"]) and float(sec["end"]) <= a_slash.length,
		"slash section start<contact<end fits the clip")

	print("== the rimewalker loads as a humanoid")
	var rw := _spawn("rimewalker", player.global_position + Vector3(0, 0.1, -2.2))
	await ticks(10)
	check(rw.vis.is_humanoid() and rw.vis.anim == null, "rimewalker builds the humanoid rig, not a mannequin")
	var meshes := rw.vis.find_children("*", "MeshInstance3D", true, false)
	check(rw.vis.skel != null and not meshes.is_empty(), "model loads: skeleton + %d meshes" % meshes.size())
	var missing: Array = []
	for b in MIXAMO:
		if rw.vis.skel.find_bone("mixamorig_" + b) < 0:
			missing.append(b)
	check(missing.is_empty(), "skeleton has the Mixamo bones (missing %s)" % [missing])
	check(rw.vis.skel.get_bone_count() >= 52, "%d bones" % rw.vis.skel.get_bone_count())
	var head := _bone_pos(rw.vis, "mixamorig_HeadTop_End")
	var toes := minf(_bone_pos(rw.vis, "mixamorig_LeftToe_End").y, _bone_pos(rw.vis, "mixamorig_RightToe_End").y)
	check(absf(head.y - rw.global_position.y - 1.75) < 0.2, "stands ~1.8 m (head top %.2f)" % (head.y - rw.global_position.y))
	check(absf(toes - rw.global_position.y) < 0.12, "feet on the ground (toes %.3f)" % (toes - rw.global_position.y))
	var face := (_bone_pos(rw.vis, "mixamorig_LeftToe_End") + _bone_pos(rw.vis, "mixamorig_RightToe_End")) * 0.5 \
			- _bone_pos(rw.vis, "mixamorig_Hips")
	var fwd := -rw.vis.global_transform.basis.z
	face.y = 0.0
	check(face.normalized().dot(fwd) > 0.5, "the model faces the visual's forward (-Z) (dot %.2f)" % face.normalized().dot(fwd))

	print("== every state resolves to a clip")
	var unresolved: Array = []
	for s in STATES:
		if not rw.vis.rig.has_clip(s):
			unresolved.append(s)
	check(unresolved.is_empty(), "rimewalker: all states have clips (missing %s)" % [unresolved])

	print("== weapon in the right hand")
	var att := rw.vis.weapon_mount.get_parent() as BoneAttachment3D if rw.vis.weapon_mount != null else null
	check(att != null and att.bone_name == "mixamorig_RightHand", "weapon rides a BoneAttachment3D on mixamorig_RightHand")
	var grip := rw.vis.weapon_mount.global_position
	var hand := _bone_pos(rw.vis, "mixamorig_RightHand")
	check(grip.distance_to(hand) < 0.15, "grip sits in the fist (%.3f m from the hand bone)" % grip.distance_to(hand))
	var wmesh := rw.vis.weapon_mount.find_children("*", "MeshInstance3D", true, false)
	check(not wmesh.is_empty(), "the hewing blade glb is mounted")
	_report_blade(rw, "idle")

	print("== attack contact lands on the data windup")
	rw.target = player
	var atk: Dictionary = (rw.cfg["attacks"] as Array)[0]
	rw._begin_attack(atk)
	var windup := float(atk["windup"])
	var guard := 0
	while rw.state == Enemy.ES.ATTACK and rw.state_t < windup and guard < 300:
		guard += 1
		await ticks(1)
	var rate := (float(sec["contact"]) - rw.vis.rig.action_started_at()) / windup
	var anim_t := rw.vis.rig.action_time()
	var frame := 1.0 / float(Engine.physics_ticks_per_second)
	var err := absf(anim_t - float(sec["contact"])) / rate
	check(err <= frame + 1e-4, "contact frame at windup: clip %.3f vs contact %.3f (%.4f s off, 1 frame = %.4f)"
		% [anim_t, float(sec["contact"]), err, frame])
	check(rw.vis.current_clip() == "atk_r", "the attack clip owns the rig")
	_report_blade(rw, "contact")
	var g0 := rw.vis.weapon_xform().origin
	await ticks(2)
	var g1 := rw.vis.weapon_xform().origin
	# synced before move_and_slide: the lunge (1.5 m/s) may add one tick of drift
	check(rw.blade_hitbox != null and rw.state == Enemy.ES.ATTACK
		and rw.blade_hitbox.global_position.distance_to(g1) < 0.06 and g0.distance_to(g1) > 0.01,
		"blade hitbox rides the weapon mesh through the swing (moved %.2f m, off %.3f m)"
		% [g0.distance_to(g1), rw.blade_hitbox.global_position.distance_to(g1) if rw.blade_hitbox else -1.0])
	await ticks(3)
	var bone_att := rw.vis.weapon_mount.global_position
	check(bone_att.distance_to(rw.vis.weapon_xform().origin) < 0.05, "the BoneAttachment3D agrees with the pose read")

	print("== death plays the death clip")
	var hips0 := _bone_pos(rw.vis, "mixamorig_Hips").y - rw.global_position.y
	rw.take_hit(DamagePacket.new(99999, 0, player))
	await ticks(2)
	check(rw.dead and rw.vis.current_clip() == "death", "dies into 'death' (%s)" % rw.vis.current_clip())
	check(rw.vis.rig.qualified("death") == "death" and HumanoidLib.is_procedural(rw.vis.rig.clip_anim("death")),
		"death is the shared procedural fall")
	await ticks(110)
	var hips1 := _bone_pos(rw.vis, "mixamorig_Hips").y - rw.global_position.y
	check(hips1 < hips0 * 0.35, "the body falls (hips %.2f -> %.2f m)" % [hips0, hips1])

	print("== the netmender: own clips, borrowed run")
	var nm := _spawn("holdfast_of_saltfell", player.global_position + Vector3(4, 0.1, -4))
	await ticks(5)
	check(nm.vis.is_humanoid() and nm.vis.model_id == "netmender", "the Saltfell holdfast wears netmender.glb")
	check(nm.vis.rig.qualified("idle") == "own/idle" and nm.vis.rig.qualified("run") == "run",
		"own idle shadows the shared one; run is borrowed (%s, %s)" % [nm.vis.rig.qualified("idle"), nm.vis.rig.qualified("run")])
	check(HumanoidLib.is_procedural(nm.vis.rig.clip_anim("roll")), "her roll is the overlay on her own idle")

	print("== a real clip drops in over a fallback, by name alone")
	var fake_roll := Animation.new()
	fake_roll.length = 1.5
	var fake_stagger := Animation.new()
	fake_stagger.length = 0.9
	shared.add_animation("roll", fake_roll)            # replaces the shared overlay
	shared.add_animation("stagger", fake_stagger)      # outranks the "hit" alias
	check(nm.vis.rig.qualified("roll") == "roll", "a real shared roll outranks her own overlay (%s)" % nm.vis.rig.qualified("roll"))
	check(nm.vis.rig.qualified("stagger") == "stagger", "a real stagger outranks the hit fallback")
	check(absf(nm.vis.rig.clip_length("roll") - 1.5) < 0.01, "with no metadata it plays whole (%.2f s), not the overlay's 1.0 s"
		% nm.vis.rig.clip_length("roll"))
	shared.remove_animation("stagger")
	shared.add_animation("roll", HumanoidOverlays.build(rw.vis.skel, shared.get_animation("idle"))["roll"])
	check(nm.vis.rig.qualified("stagger") == "own/hit", "and without it stagger falls back to hit")
	var nm_head := _bone_pos(nm.vis, "mixamorig_HeadTop_End").y - nm.global_position.y
	check(nm_head > 2.4, "she stands tall (head top %.2f m)" % nm_head)
	check(nm.vis.weapon_mount == null, "bare-handed: the data maul is not mounted on her")
	nm.queue_free()

	print("== fallbacks and the player path")
	var cfg_missing := DB.enemy("rimewalker").duplicate()
	cfg_missing["model"] = "no_such_model"
	var ev := EnemyVisual.new()
	add_child(ev)
	ev.build(cfg_missing)
	check(not ev.is_humanoid() and ev.anim != null, "unknown model falls back to the mannequin")
	ev.queue_free()
	check(not player.vis.is_humanoid(), "the Bearer is still the mannequin (no player.model)")
	var pv := PlayerVisual.new()
	add_child(pv)
	pv.build("hewing_blade", "rimewalker")
	check(pv.is_humanoid() and pv.shield_mount != null and pv.weapon_mount != null,
		"the player visual accepts a model key")
	check(absf(pv.clip_length("roll") - 1.0) < 0.01, "player roll timing reads the humanoid section")
	pv.play_timed("attack_l1", 0.36, 0.05, 0.55, 1.85)
	await ticks(1)
	check(pv.current_clip() == "attack_l1", "player attacks play on the humanoid")
	pv.queue_free()
	finish()

func _report_blade(e: Enemy, tag: String) -> void:
	var m := e.vis.weapon_mount.global_transform
	var dir := (m.basis.y).normalized()
	var b := e.vis.global_transform.basis
	print("    blade %s: fwd %.2f up %.2f right %.2f | edge fwd %.2f up %.2f right %.2f" % [tag,
		dir.dot(-b.z), dir.dot(b.y), dir.dot(b.x),
		m.basis.z.normalized().dot(-b.z), m.basis.z.normalized().dot(b.y), m.basis.z.normalized().dot(b.x)])
	var sk := e.vis.skel
	var hb := (sk.global_transform.basis * sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand")).basis).orthonormalized()
	for ax in [["x", hb.x], ["y", hb.y], ["z", hb.z]]:
		var v: Vector3 = ax[1]
		print("      hand %s: fwd %.2f up %.2f right %.2f" % [ax[0], v.dot(-b.z), v.dot(b.y), v.dot(b.x)])
