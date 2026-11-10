extends TestBase
## The slice encounters (SLICE.md 5, 6): the Bearer's Tripo body and gear,
## the Hearthhound's leash, bark and grab, the Oarsman's ship-oars shockwave
## and oar, and the Netmender's intro, phases (and the moves each unlocks),
## ridges, net and release with the Mending Needle. Runs in the arena sandbox.

var arena: Node
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _spawn(id: String, pos: Vector3, face_deg := 0.0) -> Enemy:
	var ecfg: Dictionary = DB.table("enemies").get(id, {})
	var e: Enemy = load(ecfg["class"]).new() if ecfg.has("class") else Enemy.new()
	e.setup(id)
	arena.add_child(e)
	e.global_position = pos
	e.home = pos
	e.vis.rotation.y = deg_to_rad(face_deg)
	return e

func _face_player(yaw_toward: Vector3) -> void:
	var d := yaw_toward - player.global_position
	player.vis.rotation.y = atan2(-d.x, -d.z)

func _secs(s: float):
	await ticks(int(ceil(s * 60.0)))

func _run() -> void:
	arena = (load("res://scenes/sandbox/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await ticks(5)
	for sp in ["PenSpawner", "WardSpawner"]:   # a quiet arena
		var n := arena.get_node_or_null(sp)
		if n != null:
			n.free()
	player = arena.get_node("Player")
	player.sim_active = true
	await ticks(3)
	await _bearer()
	await _hound()
	await _oarsman()
	await _netmender()
	finish()

# ------------------------------------------------------------------ the Bearer
func _bearer() -> void:
	print("== the Bearer: Tripo body, hewing blade and board shield")
	var v: PlayerVisual = player.vis
	check(v.is_humanoid() and v.model_id == "bearer_traveller", "the Bearer is bearer_traveller (%s)" % v.model_id)
	var watt := v.weapon_mount.get_parent() as BoneAttachment3D
	var satt := v.shield_mount.get_parent() as BoneAttachment3D
	check(watt != null and watt.bone_name == "mixamorig_RightHand", "the blade rides the right hand")
	check(satt != null and satt.bone_name == "mixamorig_LeftForeArm", "the shield rides the left forearm")
	var blade: Node = v.weapon_mount.get_child(0) if v.weapon_mount.get_child_count() > 0 else null
	var board: Node = v.shield_mount.get_child(0) if v.shield_mount.get_child_count() > 0 else null
	check(blade != null and blade.scene_file_path.ends_with("hewing_blade.glb"), "the hewing blade glb is mounted")
	check(board != null and board.scene_file_path.ends_with("saltfell_shield.glb"), "the Saltfell board shield glb is mounted")
	var hand := v.bone_xform("mixamorig_RightHand").origin
	check(v.weapon_xform().origin.distance_to(hand) < 0.2, "the grip sits in the fist")
	# the Bearer's own Tripo drink and kneel stay; roll and parry come from the
	# combat library's one-handed set (ADR 0011)
	check(v.rig.qualified("roll") == "dive_roll" and v.rig.qualified("gourd") == "own/drink"
			and v.rig.qualified("kneel") == "own/rest" and v.rig.qualified("parry") == "guard_parry",
		"real clips: roll, drink, kneel and parry (%s, %s, %s, %s)" % [v.rig.qualified("roll"),
			v.rig.qualified("gourd"), v.rig.qualified("kneel"), v.rig.qualified("parry")])
	check(not HumanoidLib.is_procedural(v.rig.clip_anim("block")) and v.rig.qualified("stagger") == "react_front",
		"block and stagger are library clips, no longer overlays (%s, %s)" % [v.rig.qualified("block"), v.rig.qualified("stagger")])
	print("== the gourd in hand while drinking")
	player.hp = player.max_hp * 0.5
	check(player.try_gourd(), "he drinks")
	await ticks(10)
	var g: Node3D = player.get("_gourd_mount")
	var gm: Node = g.get_child(0) if g != null and g.get_child_count() > 0 else null
	check(gm != null and gm.scene_file_path.ends_with("gourd.glb") and g.is_visible_in_tree(), "the Tripo gourd is in his hand")
	check(not v.weapon_mount.visible, "the blade is put away while the drinking hand holds the gourd")
	await _secs(1.3)
	check(player.get("_gourd_mount") == null and v.weapon_mount.visible, "the gourd goes back, the blade comes out")

# ------------------------------------------------------------------ the Hearthhound
func _hound() -> void:
	print("== the Hearthhound: lies across its threshold")
	var home := Vector3(-6, 0.1, -6)
	player.global_position = Vector3(8, 0.1, 9)
	var h: Hearthhound = _spawn("hearthhound", home, 180.0)
	await ticks(20)
	check(h.vis.is_quadruped() and h.state == Enemy.ES.IDLE, "a quadruped, idle")
	check(h.vis.quad.weight("lie") > 0.9, "lying down (lie %.2f)" % h.vis.quad.weight("lie"))

	print("== the guard bark wakes the frost-taken within 15 m")
	var rw := _spawn("rimewalker", Vector3(6, 0.1, -10), 90.0)   # 12.6 m off, facing away
	await ticks(5)
	player.global_position = Vector3(-6, 0.1, 0.5)
	_face_player(home)
	var barked := false
	var rw_idle_before := true
	for i in 120:
		await ticks(1)
		if h.state == Enemy.ES.ATTACK and String(h._atk.get("id", "")) == "guard_bark" and h.state_t < 0.5:
			rw_idle_before = rw_idle_before and rw.state == Enemy.ES.IDLE
		if h.barked and h.state != Enemy.ES.ATTACK:
			barked = true
			break
	check(h.barked, "it sat up and barked")
	check(rw_idle_before and rw.state != Enemy.ES.IDLE and rw.target == player,
		"the rimewalker 12.6 m away, which could not see him, comes (state %d)" % rw.state)
	rw.free()

	print("== the leash: 8 m from the threshold, no further")
	player.global_position = home + Vector3(0, 0, 14)
	await ticks(4)
	h._set_state(Enemy.ES.COMBAT)
	h.target = player
	await ticks(3)
	check(h.target == null and h.state in [Enemy.ES.RETURN, Enemy.ES.IDLE],
		"the Bearer stands past its leash: it will not follow (state %d)" % h.state)
	h.global_position = home + Vector3(5.5, 0, 6.5)   # dragged 8.5 m out
	h._set_state(Enemy.ES.COMBAT)
	h.target = player
	await ticks(3)
	check(h.state == Enemy.ES.RETURN, "pulled 8.5 m from home, it goes back")
	var back := false
	for i in 600:
		await ticks(1)
		if h.state == Enemy.ES.IDLE:
			back = true
			break
	check(back and h.away_from_home() < 0.8, "back on its threshold (%.2f m off)" % h.away_from_home())
	await _secs(1.0)
	check(h.vis.quad.weight("lie") > 0.8, "and lies down again")

	print("== the grab-shake: a lunge from behind holds and shakes")
	h.barked = true
	h._set_state(Enemy.ES.COMBAT)
	h.target = player
	h.vis.rotation.y = 0.0
	var fwd := -h.vis.global_transform.basis.z
	player.global_position = h.global_position + fwd * 1.7
	_face_player(player.global_position + fwd)       # his back to the hound
	player.invulnerable = false
	await ticks(2)
	check(h.from_behind(player), "the hound is behind him")
	var hp0 := player.hp
	h._begin_attack(h.attack_by_id("lunge_bite"))
	var grabbed := false
	for i in 90:
		await ticks(1)
		if h.state == Enemy.ES.GRAB:
			grabbed = true
			break
	check(grabbed, "the bite lands from behind and becomes a grab")
	check(grabbed and not player.input_enabled, "he is held: no control")
	await _secs(0.9)
	check(player.hp < hp0, "it shakes him (hp %.0f -> %.0f)" % [hp0, player.hp])
	if h.grab != null:
		for i in int(h.cfg["grab"]["mash"]):
			h.grab.mash()
	await ticks(3)
	check(player.input_enabled and h.state == Enemy.ES.STAGGER, "mashing breaks the hold; the hound reels")

	print("== from the front a bite is only a bite")
	await _secs(1.4)
	h._set_state(Enemy.ES.COMBAT)
	h.vis.rotation.y = 0.0
	player.global_position = h.global_position + fwd * 1.7
	_face_player(h.global_position)
	player.hp = player.max_hp
	await ticks(2)
	h._begin_attack(h.attack_by_id("lunge_bite"))
	var any_grab := false
	for i in 80:
		await ticks(1)
		any_grab = any_grab or h.state == Enemy.ES.GRAB
	check(not any_grab and player.input_enabled, "facing it, no grab")
	h.free()
	await ticks(2)

# ------------------------------------------------------------------ the Oarsman
func _oarsman() -> void:
	print("== the Oarsman: an ice oar across both hands")
	player.global_position = Vector3(0, 0.1, 6)
	player.hp = player.max_hp
	var o: Oarsman = _spawn("oarsman", Vector3(0, 0.1, -2), 0.0)
	await ticks(10)
	check(o.vis.is_humanoid() and o.vis.model_id == "oarsman", "the oarsman.glb body")
	var x := o.oar_xform()
	var l := o.vis.bone_xform("mixamorig_LeftHand").origin
	var r := o.vis.bone_xform("mixamorig_RightHand").origin
	var off := (r - x.origin) - x.basis.y * (r - x.origin).dot(x.basis.y)
	check(x.origin.distance_to(l) < 0.01 and off.length() < 0.02, "the oar runs from the left hand through the right")
	check(o.blade_hitbox.global_transform.origin.distance_to(x.origin) < 0.01, "its hit volume rides the oar")
	check(o.oar.material_override is ShaderMaterial, "a translucent ice shader")

	print("== ship oars: the slam sends an ice line 4 m forward")
	var fwd := -o.vis.global_transform.basis.z
	player.global_position = o.global_position + fwd * 2.6
	_face_player(o.global_position)
	o.target = player
	o._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var a := o.attack_by_id("ship_oars")
	var hp0 := player.hp
	o._begin_attack(a)
	await _secs(float(a["windup"]) + 0.15)
	check(player.hp < hp0, "standing in the line, he is struck (hp %.0f -> %.0f)" % [hp0, player.hp])
	check(o.state == Enemy.ES.ATTACK, "then the long recovery: still dragging the oar up")
	await _secs(float(a["recover"]) - 0.3)
	check(o.state == Enemy.ES.ATTACK, "the 1.4 s window holds")
	await _secs(0.6)
	check(not (o.state == Enemy.ES.ATTACK and String(o._atk.get("id", "")) == "ship_oars"), "and ends")

	print("== a sidestep after the aim commits clears the line")
	o._cooldowns.clear()
	o.vis.rotation.y = 0.0
	fwd = -o.vis.global_transform.basis.z
	player.global_position = o.global_position + fwd * 2.6
	player.hp = player.max_hp
	await ticks(2)
	o._begin_attack(a)
	await _secs(float(a["windup"]) * 0.8)
	player.global_position += fwd.cross(Vector3.UP) * 2.4
	hp0 = player.hp
	await _secs(float(a["windup"]) * 0.2 + 0.2)
	check(player.hp >= hp0, "two metres aside, untouched")

	print("== the stroke flows into the back-stroke")
	await _secs(1.6)
	o._cooldowns.clear()
	var st := o.attack_by_id("stroke").duplicate()
	st["chain_chance"] = 1.0
	player.invulnerable = true
	o._begin_attack(st)
	var chained := false
	for i in 150:
		await ticks(1)
		chained = chained or String(o._atk.get("id", "")) == "back_stroke"
	check(chained, "a Stroke chains into a Back-stroke")
	check(not o.attack_by_id("back_stroke").get("pick", true) or o.attack_by_id("back_stroke").get("chain_only", false),
		"the Back-stroke comes only after a Stroke")
	player.invulnerable = false
	o.free()
	await ticks(2)

# ------------------------------------------------------------------ the Netmender
func _netmender() -> void:
	print("== the Netmender: she mends until he comes close")
	player.global_position = Vector3(0, 0.1, 6)
	player.hp = player.max_hp
	var nm: Netmender = _spawn("netmender", Vector3(0, 0.1, -6), 180.0)
	await ticks(20)
	check(nm.state == Enemy.ES.IDLE and not nm.stood and nm.vis.current_clip() == "sit_mend", "sitting, mending")
	var hud: HUD = arena.find_children("*", "HUD", true, false)[0]
	check(not hud.boss_root.visible, "no bar yet")
	player.global_position = nm.global_position + Vector3(0, 0, 3.6)
	player.invulnerable = true
	await ticks(6)
	check(nm.state == Enemy.ES.TRANSITION, "within 4 m she stops and stands")
	await _secs(2.2)
	check(nm.stood and hud.boss_root.visible and hud.boss_name.text == "THE NETMENDER", "the bar: THE NETMENDER")

	print("== phase thresholds at 60% and 25%, each with its moves")
	var p1 := nm.repertoire()
	check("needle_stitch" in p1 and "cast" in p1 and "turn_away" in p1 and "knot" in p1
		and not ("haul" in p1) and not ("sea_weight" in p1) and not ("hold" in p1), "phase 1: stitch, cast, turn away, knot")
	nm.take_hit(DamagePacket.new(nm.max_hp * 0.39, 0, player))
	await ticks(2)
	check(nm.phase == 1, "at 61% she is still mending the first net")
	nm.take_hit(DamagePacket.new(nm.max_hp * 0.02, 0, player))
	await ticks(2)
	check(nm.phase == 2 and nm.state == Enemy.ES.TRANSITION, "at 59% the hauling begins")
	var hp_t := nm.hp
	nm.take_hit(DamagePacket.new(100, 0, player))
	check(nm.hp == hp_t, "she cannot be hurt while she hauls the floor")
	await _secs(2.8)
	check(nm.state != Enemy.ES.TRANSITION, "the transition ends")
	var p2 := nm.repertoire()
	check("haul" in p2 and "sea_weight" in p2 and "mend_floor" in p2 and "needle_stitch" in p2 and "cast" in p2
		and not ("hold" in p2), "phase 2 adds haul, sea-weight, mend the floor")
	nm._begin_attack(nm.attack_by_id("needle_stitch"))
	check((nm._atk["hits"] as Array).size() == 4, "the stitch gains a fourth stab")
	await _secs(2.6)

	print("== knot ridges: raised, mended, broken by two heavy blows")
	nm._set_state(Enemy.ES.COMBAT)
	nm._begin_attack(nm.attack_by_id("knot"))
	await _secs(1.6)
	check(nm._live_ridges() == 1, "a ridge of ice-knots stands")
	var ridge: IceRidge = nm.ridges[0]
	var left := ridge.remaining()
	nm._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	nm._begin_attack(nm.attack_by_id("mend_floor"))
	await _secs(1.0)
	check(ridge.remaining() > left + 4.0, "mend the floor re-freezes it (%.1f s -> %.1f s)" % [left, ridge.remaining()])
	player.set("_atk_is_heavy", false)
	ridge.take_hit(DamagePacket.new(30, 10, player))
	check(is_instance_valid(ridge) and ridge.heavy_hits == 0, "a light blow does nothing")
	player.set("_atk_is_heavy", true)
	ridge.take_hit(DamagePacket.new(30, 10, player))
	ridge.take_hit(DamagePacket.new(30, 10, player))
	player.set("_atk_is_heavy", false)
	await ticks(2)
	check(nm._live_ridges() == 0, "two heavy blows break it")

	print("== the cast snares; unbroken, she hauls him in")
	await _secs(1.0)
	nm._set_state(Enemy.ES.COMBAT)
	nm.vis.rotation.y = deg_to_rad(180.0)
	player.global_position = nm.global_position + Vector3(0, 0, 6.0)
	player.invulnerable = false
	await ticks(2)
	nm._begin_attack(nm.attack_by_id("cast"))
	await _secs(1.25)
	check(nm.snare != null and not player.input_enabled, "caught in the net: rooted")
	await _secs(2.0)
	var d := Vector2(player.global_position.x - nm.global_position.x, player.global_position.z - nm.global_position.z).length()
	check(player.input_enabled and d < 3.0, "the net let go and she hauled him in (%.1f m)" % d)
	player.invulnerable = true

	print("== the hole: phase three below 25%")
	await _secs(2.0)
	nm.take_hit(DamagePacket.new(nm.hp - nm.max_hp * 0.24, 0, player))
	await ticks(2)
	check(nm.phase == 3 and nm.state == Enemy.ES.TRANSITION, "at 24% she reaches back through the net")
	await _secs(2.6)
	var p3 := nm.repertoire()
	check("one_hand_stitch" in p3 and "last_cast" in p3 and "hold" in p3 and not ("turn_away" in p3)
		and not ("needle_stitch" in p3) and not ("sea_weight" in p3), "phase 3: one-hand stitch, last cast, hold")
	check(nm.vis.rig._carry == "left_behind", "her left hand stays behind her, holding his")
	check(nm._speed_mult() < 1.0, "and she is slower (%.2f)" % nm._speed_mult())

	print("== hold: open, and if he does nothing she stands again")
	nm._set_state(Enemy.ES.COMBAT)
	nm._begin_attack(nm.attack_by_id("hold"))
	await _secs(float(nm.attack_by_id("hold")["windup"]) / nm._speed_mult() + 0.2)
	check(nm.state == Enemy.ES.HOLD, "she curls around him")
	var hp_h := nm.hp
	nm.take_hit(DamagePacket.new(10, 999, player))
	check(nm.hp < hp_h and nm.state == Enemy.ES.HOLD, "she takes the blow and stays curled")
	await _secs(6.3)
	check(nm.state != Enemy.ES.HOLD, "six quiet seconds: she stands and resumes")

	print("== release: the needle where she sat")
	while not nm.dead:
		nm.take_hit(DamagePacket.new(200, 0, player))
		await ticks(2)
	await ticks(10)
	check(nm.released and World.flag("ks_netmender_released"), "she is released")
	check(nm.vis.current_clip() == "sit_still" or nm.vis.rig.action_clip() == "sit_still", "she sits back down")
	var needle: Pickup = null
	for pk in arena.find_children("*", "Pickup", true, false):
		if (pk as Pickup).item_id == "item_mending_needle":
			needle = pk
	check(needle != null and needle.global_position.distance_to(nm.global_position) < 2.5,
		"the Mending Needle lies where she sat")
	check(not hud.boss_root.visible, "the bar is gone")
	if needle != null:
		needle._on_take(player)
	check(int(player.inventory.get("item_mending_needle", 0)) == 1, "the Bearer takes the needle")
