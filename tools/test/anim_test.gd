extends TestBase
## Humanoid animation layer (ADR 0004): Tripo models load retargeted, keep
## their Mixamo bones, share one library, land attack contact on the data
## windup, strike with ice-club hands (or a blade in the right hand when
## armed), and fall on death. Runs in the
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

	print("== unarmed: the ice-club hands are the weapon")
	check(rw.vis.weapon_mount == null and rw.blade_hitbox == null, "no weapon mesh or blade box on the rimewalker")
	check(rw.fist_hitbox != null and rw._fists.has("right") and rw._fists.has("left"), "a fist volume on each hand")
	var fr: Dictionary = rw._fists["right"]
	var want_r: Vector3 = rw.vis.bone_xform("mixamorig_RightHand") * (fr["offset"] as Vector3)
	check(fr["bone"] == "mixamorig_RightHand" and rw.fist_position("right").distance_to(want_r) < 0.06,
		"right fist rides mixamorig_RightHand at its data offset (%.3f m off)" % rw.fist_position("right").distance_to(want_r))

	print("== attack contact lands on the data windup")
	rw.target = player
	var atk: Dictionary = (rw.cfg["attacks"] as Array)[0]
	rw._begin_attack(atk)
	var windup := float(atk["windup"])
	var guard := 0
	while rw.state == Enemy.ES.ATTACK and rw.state_t < windup and guard < 300:
		guard += 1
		await ticks(1)
	# the foe's own clip for this attack ("@swipe", cut to its windup) answers atk_r
	var asec: Vector3 = rw.vis.rig._section("atk_r")
	var rate := (asec.y - rw.vis.rig.action_started_at()) / windup
	var anim_t := rw.vis.rig.action_time()
	var frame := 1.0 / float(Engine.physics_ticks_per_second)
	var err := absf(anim_t - asec.y) / rate
	check(err <= frame + 1e-4, "contact frame at windup: clip %.3f vs contact %.3f (%.4f s off, 1 frame = %.4f)"
		% [anim_t, asec.y, err, frame])
	check(rw.vis.rig.qualified("atk_r") == "f_rimewalker_swipe" and absf(rate - 1.0) < 0.02,
		"the rimewalker's swipe is its own clip, played at 1x (%s, rate %.2f)" % [rw.vis.rig.qualified("atk_r"), rate])
	check(rw.vis.current_clip() == "atk_r", "the attack clip owns the rig")
	var f0 := rw.fist_position("right")
	await ticks(2)
	var f1 := rw.fist_position("right")
	var want := rw.vis.bone_xform("mixamorig_RightHand") * (fr["offset"] as Vector3)
	# synced before move_and_slide: the lunge (1.5 m/s) may add one tick of drift
	check(rw.fist_hitbox.monitoring and not (fr["shape"] as CollisionShape3D).disabled
		and (rw._fists["left"]["shape"] as CollisionShape3D).disabled,
		"a one-handed swing opens the right fist only")
	check(f1.distance_to(want) < 0.06 and f0.distance_to(f1) > 0.01,
		"the fist volume follows the hand through the swing (moved %.2f m, off %.3f m)" % [f0.distance_to(f1), f1.distance_to(want)])

	print("== death plays the death clip")
	var hips0 := _bone_pos(rw.vis, "mixamorig_Hips").y - rw.global_position.y
	rw.take_hit(DamagePacket.new(99999, 0, player))
	await ticks(2)
	check(rw.dead and rw.vis.current_clip() == "death", "dies into 'death' (%s)" % rw.vis.current_clip())
	check(rw.vis.rig.qualified("death") == "fall_back" and not HumanoidLib.is_procedural(rw.vis.rig.clip_anim("death")),
		"death is the library's real fall")
	await ticks(110)
	var hips1 := _bone_pos(rw.vis, "mixamorig_Hips").y - rw.global_position.y
	check(hips1 < hips0 * 0.35, "the body falls (hips %.2f -> %.2f m)" % [hips0, hips1])

	print("== the double fall strikes with both hands")
	var rw2 := _spawn("rimewalker", player.global_position + Vector3(-2.5, 0.1, -2.2))
	await ticks(6)
	rw2.target = player
	var flail: Dictionary = (rw2.cfg["attacks"] as Array)[1]
	rw2._begin_attack(flail)
	while rw2.state == Enemy.ES.ATTACK and rw2.state_t < float(flail["windup"]) + 0.02:
		await ticks(1)
	check(rw2.fist_hitbox.monitoring and not (rw2._fists["right"]["shape"] as CollisionShape3D).disabled
		and not (rw2._fists["left"]["shape"] as CollisionShape3D).disabled, "both fists open for the double fall")
	rw2.queue_free()

	print("== an armed humanoid keeps the blade path")
	var rwcfg: Dictionary = HumanoidLib.model_cfg("rimewalker")
	rwcfg["bare_hands"] = false   # stand-in for an armed model (the Bearer, later)
	var armed := Enemy.new()
	armed.setup("rimewalker")
	armed.cfg = armed.cfg.duplicate()
	armed.cfg["weapon"] = "hewing_blade"
	arena.add_child(armed)
	armed.global_position = player.global_position + Vector3(2.5, 0.1, -2.2)
	rwcfg["bare_hands"] = true
	await ticks(6)
	var att := armed.vis.weapon_mount.get_parent() as BoneAttachment3D if armed.vis.weapon_mount != null else null
	check(att != null and att.bone_name == "mixamorig_RightHand", "weapon rides a BoneAttachment3D on mixamorig_RightHand")
	var grip := armed.vis.weapon_mount.global_position
	var hand := _bone_pos(armed.vis, "mixamorig_RightHand")
	check(grip.distance_to(hand) < 0.15, "grip sits in the fist (%.3f m from the hand bone)" % grip.distance_to(hand))
	check(not armed.vis.weapon_mount.find_children("*", "MeshInstance3D", true, false).is_empty(), "the hewing blade glb is mounted")
	check(armed.blade_hitbox != null and armed.fist_hitbox == null, "armed: the blade box, not fists")
	armed.target = player
	armed._begin_attack((armed.cfg["attacks"] as Array)[0])
	while armed.state == Enemy.ES.ATTACK and armed.state_t < float((armed.cfg["attacks"] as Array)[0]["windup"]):
		await ticks(1)
	var g0 := armed.vis.weapon_xform().origin
	await ticks(2)
	var g1 := armed.vis.weapon_xform().origin
	check(armed.blade_hitbox.monitoring and armed.blade_hitbox.global_position.distance_to(g1) < 0.06 and g0.distance_to(g1) > 0.01,
		"blade hitbox rides the weapon mesh through the swing (moved %.2f m, off %.3f m)"
		% [g0.distance_to(g1), armed.blade_hitbox.global_position.distance_to(g1)])
	await ticks(3)
	check(armed.vis.weapon_mount.global_position.distance_to(armed.vis.weapon_xform().origin) < 0.05,
		"the BoneAttachment3D agrees with the pose read")
	armed.queue_free()

	print("== the netmender: own clips, borrowed run")
	var nm := _spawn("netmender", player.global_position + Vector3(4, 0.1, -4))
	await ticks(5)
	check(nm.vis.is_humanoid() and nm.vis.model_id == "netmender", "the Saltfell holdfast wears netmender.glb")
	check(nm.vis.rig.qualified("idle") == "own/idle" and nm.vis.rig.qualified("run") == "run",
		"own idle shadows the shared one; run is borrowed (%s, %s)" % [nm.vis.rig.qualified("idle"), nm.vis.rig.qualified("run")])
	check(nm.vis.rig.qualified("roll") == "dodge_roll" and HumanoidLib.is_procedural(nm.vis.rig.clip_anim("block")),
		"a real aliased clip beats her overlay (roll -> %s); block stays the overlay" % nm.vis.rig.qualified("roll"))

	print("== a real clip drops in over a fallback, by name alone")
	var fake_roll := Animation.new()
	fake_roll.length = 1.5
	var fake_stagger := Animation.new()
	fake_stagger.length = 0.9
	shared.add_animation("roll", fake_roll)            # replaces the shared overlay
	shared.add_animation("stagger", fake_stagger)      # outranks the "hit" alias
	check(nm.vis.rig.qualified("roll") == "roll", "a real shared roll outranks her own overlay (%s)" % nm.vis.rig.qualified("roll"))
	check(nm.vis.rig.qualified("stagger") == "f_netmender_stagger", "her own stagger clip (clip set) answers first (%s)" % nm.vis.rig.qualified("stagger"))
	var nm_set: String = nm.vis.rig.clip_set
	nm.vis.rig.clip_set = ""   # the plain alias chain, as a model without a clip set resolves it
	check(nm.vis.rig.qualified("stagger") == "stagger", "a real stagger outranks the hit fallback")
	check(absf(nm.vis.rig.clip_length("roll") - 1.5) < 0.01, "with no metadata it plays whole (%.2f s), not the overlay's 1.0 s"
		% nm.vis.rig.clip_length("roll"))
	shared.remove_animation("stagger")
	shared.add_animation("roll", HumanoidOverlays.build(rw.vis.skel, shared.get_animation("idle"))["roll"])
	check(nm.vis.rig.qualified("stagger") == "own/hit", "and without it stagger falls back to hit")
	nm.vis.rig.clip_set = nm_set
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
	check(player.vis.is_humanoid() and player.vis.model_id == "bearer_traveller",
		"the Bearer wears bearer_traveller (game.json player.model)")
	var pv := PlayerVisual.new()
	add_child(pv)
	pv.build("hewing_blade", "rimewalker")
	check(pv.is_humanoid() and pv.shield_mount != null and pv.weapon_mount != null,
		"the player visual accepts a model key")
	var rsec := HumanoidLib.clip_info("dodge_roll", false, "rimewalker")
	check(absf(pv.clip_length("roll") - (float(rsec["end"]) - float(rsec["start"]))) < 0.01,
		"player roll timing reads the humanoid section (%.2f s)" % pv.clip_length("roll"))
	pv.play_timed("attack_l1", 0.36, 0.05, 0.55, 1.85)
	await ticks(1)
	check(pv.current_clip() == "attack_l1", "player attacks play on the humanoid")
	pv.queue_free()

	print("== foe attack clips are cut to their data windups")
	var fsets: Dictionary = HumanoidLib.meta().get("clip_sets", {})
	var fclips: Dictionary = HumanoidLib.meta().get("clips", {})
	var fn := 0
	var fbad := []
	for sid in fsets:
		if not String(sid).begins_with("foe_"):
			continue
		var foe_id := String(sid).trim_prefix("foe_")
		var fcfg: Dictionary = DB.enemy(foe_id)
		if String(HumanoidLib.model_cfg(String(fcfg.get("model", ""))).get("clip_set", "")) != String(sid):
			fbad.append("%s: model has no clip_set" % foe_id)
		for fa in fcfg.get("attacks", []):
			var key := "@" + String(fa["id"])
			if not (fsets[sid] as Dictionary).has(key):
				continue
			var cname := String(((fsets[sid] as Dictionary)[key] as Array)[0])
			var frow: Dictionary = fclips.get(cname, {})
			var fanim := HumanoidLib.shared_library().get_animation(cname) if HumanoidLib.shared_library().has_animation(cname) else null
			fn += 1
			# the clip's contact IS the windup: it plays at 1x, the strike lands on the tick
			if fanim == null or absf(float(frow.get("contact", -1.0)) - float(fa["windup"])) > 1.0 / 60.0 \
					or fanim.length + 0.02 < float(frow.get("end", 0.0)):
				fbad.append("%s %s" % [foe_id, fa["id"]])
	check(fn >= 30 and fbad.is_empty(), "%d foe attacks have a clip whose contact is the data windup %s" % [fn, str(fbad)])

	print("== the combat library: weapon-class clip sets on the Bearer")
	check(HumanoidLib.shared_library().has_animation("sw_light_a")
			and not HumanoidLib.is_procedural(HumanoidLib.shared_library().get_animation("sw_light_a")),
		"the combat library's clips are real clips in the shared library")
	var pv3 := PlayerVisual.new()
	add_child(pv3)
	pv3.build("hewing_blade", "rimewalker")
	check(pv3.rig.clip_set != "onehand" and pv3.rig.qualified("attack_l1") == "slash",
		"models without clip_sets keep their own attack clips")
	pv3.queue_free()
	var dtick := 1.0 / float(Engine.physics_ticks_per_second)
	var cseen := {}
	for wid in ["hewing_blade", "greatblade", "maul", "turf_spade", "spear"]:
		var cw: Dictionary = DB.weapon(wid)
		player.inventory[wid] = 1
		player._set_state(Player.S.MOVE)
		player.equip_weapon(wid)
		await ticks(2)
		var prig: HumanoidRig = player.vis.rig
		var ccls := HumanoidLib.weapon_class(String(cw.get("kit", wid)))
		check(prig.clip_set == ccls and ccls != "", "%s fights with the '%s' clip set" % [wid, ccls])
		var cmc := HumanoidLib.class_mount_cfg("weapon", ccls)
		player.vis.play("block", 0.01)
		await ticks(30)
		check(player.vis.weapon_mount.rotation_degrees.distance_to(
				Vector3(cmc["rot"][0], cmc["rot"][1], cmc["rot"][2])) < 0.5, "%s turns into the %s grip for an action" % [wid, ccls])
		player.vis.back_to_idle(0.01)
		await ticks(3)
		var cms: Dictionary = DB.moveset(String(cw.get("moveset", "longsword")))
		var cmoves: Array = (cms["lights"] as Array).duplicate()
		cmoves.append(cms["heavy"])
		if cms.has("sprint"):
			cmoves.append(cms["sprint"])
		for cm in cmoves:
			var can := String(cm["anim"])
			var cq := prig.qualified(can)
			var is_lib := cq != "" and not cq.begins_with("own/") and not HumanoidLib.is_procedural(prig.get_animation(cq))
			var cstrike := maxf(float(cm["windup"]) + float(cm["active"]) * 0.45, 0.12)
			var csec: Vector3 = prig._section(can)
			var crate := player.vis.play_timed(can, cstrike, 0.07, 0.55, 1.85)
			var cn := int(round(cstrike / dtick))
			await ticks(cn)
			var coff := absf(prig.action_time() - csec.y)
			# one physics frame of clip time, plus the rounding of the windup to ticks
			var ctol := crate * dtick * 1.5
			check(is_lib and csec.y > csec.x and coff <= ctol,
				"%s %s -> %s: contact on the data windup (%.3f s, off %.3f s of clip, rate %.2f)" % [wid, can, cq, cstrike, coff, crate])
			check(is_equal_approx(prig.action_started_at(), csec.x) and crate >= 0.55 and crate <= 1.85,
				"%s %s plays its whole wind-up, unclamped (rate %.2f)" % [wid, can, crate])
			cseen[cq] = true
			player.vis.back_to_idle(0.01)
			await ticks(3)
		for can in ["riposte", "block", "block_hit", "parry", "stagger", "stagger_back", "death", "roll", "backstep"]:
			var cq := prig.qualified(can)
			check(cq != "" and not cq.begins_with("own/") and not HumanoidLib.is_procedural(prig.get_animation(cq)),
				"%s %s resolves to a library clip (%s)" % [wid, can, cq])
	check(cseen.size() >= 12, "the classes swing different clips (%d distinct attack clips)" % cseen.size())
	# riposte, parry and roll have fixed gameplay beats: the clips are cut to them
	player.equip_weapon("hewing_blade")
	await ticks(2)
	var prig2: HumanoidRig = player.vis.rig
	check(absf(prig2.contact_time("riposte") - 0.34) <= dtick * 1.01,
		"the riposte's point lands on the 0.34 s damage beat (%.2f s)" % prig2.contact_time("riposte"))
	var cpr: Dictionary = DB.tuning("player/parry", {})
	if cpr.is_empty():
		cpr = (DB.table("game").get("player", {}) as Dictionary).get("parry", {})
	var cpc := prig2.contact_time("parry")
	check(cpc >= float(cpr.get("windup", 0.08)) and cpc <= float(cpr.get("windup", 0.08)) + float(cpr.get("window", 0.16)),
		"the parry sweep peaks inside the parry window (%.2f s)" % cpc)
	# the swing ribbon samples the pose on the physics tick, so it has an arc
	# to draw however few frames get rendered
	player.vis.play_timed("attack_l1", 0.3, 0.07, 0.55, 1.85)
	await ticks(12)
	player.vis.trail.visible = true
	await ticks(8)
	var tpts: Array = player.vis.trail.get("_pts")
	var sweep := 0.0
	for ti in range(1, tpts.size()):
		sweep += (tpts[ti]["t"] as Vector3).distance_to(tpts[ti - 1]["t"])
	check(tpts.size() >= 6 and sweep > 1.0, "the swing trail records the arc per physics tick (%d samples, %.2f m)" % [tpts.size(), sweep])
	player.vis.trail.visible = false
	player.vis.back_to_idle(0.01)
	await ticks(3)
	# a stagger from behind picks the forward lurch
	player.invulnerable = false
	player.poise = 0.01
	player.hp = player.max_hp
	var cbehind := DamagePacket.new(1, 50, null)
	cbehind.origin = player.global_position + player.vis.global_transform.basis.z * 1.5
	player.take_hit(cbehind)
	await ticks(1)
	check(player.state == Player.S.STAGGER and prig2.qualified(prig2.action_clip()) == "react_back",
		"a blow from behind staggers forward (%s)" % prig2.action_clip())
	player.invulnerable = true
	await ticks(60)
	player.inventory["bow"] = 1
	player._set_state(Player.S.MOVE)
	player.equip_weapon("bow")
	await ticks(2)
	check(player.vis.rig.clip_set == "bow" and player.vis.rig.qualified("bow_draw") == "bow_pull",
		"the bow draws with its own clip")
	check(player.vis.rig.qualified("bow_loose") == "bow_loose", "and looses with one")
	player.equip_weapon("hewing_blade")
	finish()
