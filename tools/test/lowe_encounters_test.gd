extends TestBase
## The Lowe's encounters (LOWE.md 5-8). In the arena sandbox: the
## Barrow-sleeper's sit, rise and Door-fall; the Keener's notes, keen, hush and
## rouse; the Cairn-carrier's set stone; the Turfwright's intro, three phases
## (and the moves each unlocks), cuts, back-drop, walls, guard and last turf.
## In the Lowe itself: Hesk and Aud on their own models, both Keepsakes
## threads from first meeting to last line through the real pickups and
## dialogue, and the release (flag, card, tally-stick, hearth, spindles).

var arena: Node
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _secs(s: float):
	await ticks(int(ceil(s * 60.0)))

func _spawn(id: String, pos: Vector3, face_deg := 0.0, pose := "") -> Enemy:
	var ecfg: Dictionary = DB.table("enemies").get(id, {})
	var e: Enemy = load(ecfg["class"]).new() if ecfg.has("class") else Enemy.new()
	e.setup(id)
	e.idle_pose = pose
	arena.add_child(e)
	e.global_position = pos
	e.home = pos
	e.vis.rotation.y = deg_to_rad(face_deg)
	return e

func _face_player(toward: Vector3) -> void:
	var d := toward - player.global_position
	player.vis.rotation.y = atan2(-d.x, -d.z)

func _ridges() -> Array:
	return get_tree().get_nodes_in_group("ice_ridges").filter(func(r): return not r.is_queued_for_deletion())

func _projectiles() -> int:
	return arena.find_children("*", "Projectile", true, false).size()

func _run() -> void:
	World.reset()
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
	await _sleeper()
	await _keener()
	await _carrier()
	await _turfwright()
	arena.queue_free()
	await ticks(5)
	await _lowe()
	finish()

# ------------------------------------------------------------------ Barrow-sleeper
func _sleeper() -> void:
	print("== the Barrow-sleeper: sat up in the barrow mouth")
	player.global_position = Vector3(0, 0.1, 14)
	var s := _spawn("barrow_sleeper", Vector3(0, 0.1, 0), 180.0, "sit_up")
	await ticks(10)
	check(s.vis.is_humanoid() and s.vis.model_id == "barrow_sleeper", "the barrow_sleeper.glb body")
	check(s.state == Enemy.ES.IDLE and s.vis.current_clip() == "sit_up", "sitting up, facing the road (%s)" % s.vis.current_clip())
	player.global_position = Vector3(0, 0.1, 6)
	_face_player(s.global_position)
	await ticks(6)
	check(s.state == Enemy.ES.ALERT, "it sees the Bearer and begins to rise")
	await _secs(1.6)
	check(s.state == Enemy.ES.ALERT, "slowly: still rising after 1.6 s")
	await _secs(1.2)
	check(s.state != Enemy.ES.ALERT and s.state != Enemy.ES.IDLE, "up after its 2.4 s rise")

	print("== Door-fall: it comes down full length over the strip")
	player.invulnerable = false
	player.hp = player.max_hp
	s.vis.rotation.y = 0.0
	var fwd := -s.vis.global_transform.basis.z
	player.global_position = s.global_position + fwd * 2.2
	_face_player(s.global_position)
	s.target = player
	s._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var a := s.attack_by_id("door_fall")
	check(not bool(a.get("blockable", true)) and a.has("telegraph"), "not blockable; its strip glows on the floor")
	var hp0 := player.hp
	s._begin_attack(a)
	await _secs(float(a["windup"]) * 0.8)
	check(arena.find_children("*", "FloorTelegraph", true, false).size() > 0, "the floor tell shows during the windup")
	await _secs(float(a["windup"]) * 0.2 + 0.15)
	check(player.hp < hp0, "standing in the strip, he is struck (hp %.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.5)
	check(s.state == Enemy.ES.ATTACK, "then it lies there: the punish window")
	await _secs(0.8)
	check(s.state != Enemy.ES.ATTACK or String(s._atk.get("id", "")) != "door_fall", "and gets up")

	print("== Hammer-fist leads into a Back-fist")
	player.invulnerable = true
	s._cooldowns.clear()
	var hf := s.attack_by_id("hammer_fist").duplicate()
	hf["chain_chance"] = 1.0
	s._begin_attack(hf)
	var chained := false
	for i in 140:
		await ticks(1)
		chained = chained or String(s._atk.get("id", "")) == "back_fist"
	check(chained, "a Hammer-fist chains into a Back-fist")
	check(s.attack_by_id("back_fist").get("chain_only", false), "the Back-fist only ever follows")
	player.invulnerable = false
	s.free()
	await ticks(2)

# ------------------------------------------------------------------ Keener
func _keener() -> void:
	print("== the Keener: keeps its distance and breathes the tune")
	player.global_position = Vector3(0, 0.1, 9)
	player.hp = player.max_hp
	var k := _spawn("keener", Vector3(0, 0.1, 0), 180.0)
	await ticks(6)
	check(k.vis.is_humanoid() and k.vis.model_id == "keener", "the keener.glb body")
	check(float(k.cfg.get("keep_range", 0.0)) >= 6.0, "it keeps its distance (keep_range %.0f)" % float(k.cfg.get("keep_range", 0.0)))
	k.target = player
	k._set_state(Enemy.ES.COMBAT)
	var p0 := _projectiles()
	k._begin_attack(k.attack_by_id("breath_note"))
	await _secs(float(k.attack_by_id("breath_note")["windup"]) + 0.05)
	check(_projectiles() == p0 + 1, "a breathed note: one slow note of frost")
	await _secs(1.2)
	k._set_state(Enemy.ES.COMBAT)
	p0 = _projectiles()
	k._begin_attack(k.attack_by_id("keen"))
	await _secs(float(k.attack_by_id("keen")["windup"]) + 0.05)
	check(_projectiles() >= p0 + 3, "the keen: three notes in a fan")
	await _secs(1.5)

	print("== Hush: it breathes out on whoever comes close")
	k._set_state(Enemy.ES.COMBAT)
	player.global_position = k.global_position + Vector3(0, 0, 1.8)
	player.hp = player.max_hp
	await ticks(2)
	var hp0 := player.hp
	k._begin_attack(k.attack_by_id("hush"))
	await _secs(float(k.attack_by_id("hush")["windup"]) + 0.1)
	check(player.hp < hp0, "close in, he takes the hush (hp %.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.2)

	print("== Rouse: the idle dead within 16 m turn and come")
	var s := _spawn("barrow_sleeper", Vector3(12, 0.1, -6), 90.0)   # 13.4 m off, facing away
	await ticks(4)
	player.global_position = Vector3(-3, 0.1, 4)
	check(s.state == Enemy.ES.IDLE, "a sleeper sits idle, unaware")
	k._set_state(Enemy.ES.COMBAT)
	k._begin_attack(k.attack_by_id("rouse"))
	await _secs(float(k.attack_by_id("rouse")["windup"]) + 0.1)
	check(s.state != Enemy.ES.IDLE and s.target == player, "roused, it turns to the Bearer (state %d)" % s.state)
	s.free()
	k.free()
	for pr in arena.find_children("*", "Projectile", true, false):
		pr.queue_free()
	await ticks(2)

# ------------------------------------------------------------------ Cairn-carrier
func _carrier() -> void:
	print("== the Cairn-carrier: sets a stone down as a cairn")
	player.global_position = Vector3(0, 0.1, 6)
	player.hp = player.max_hp
	var c := _spawn("cairn_carrier", Vector3(0, 0.1, 0), 0.0)
	await ticks(6)
	check(c.vis.is_humanoid() and c.vis.model_id == "cairn_carrier", "the cairn_carrier.glb body")
	c.vis.rotation.y = 0.0
	var fwd := -c.vis.global_transform.basis.z
	player.global_position = c.global_position + fwd * 1.9
	_face_player(c.global_position)
	c.target = player
	c._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var a := c.attack_by_id("set_stone")
	var hp0 := player.hp
	var r0 := _ridges().size()
	c._begin_attack(a)
	await _secs(float(a["windup"]) + 0.15)
	check(player.hp < hp0, "under the stone, he is struck (hp %.0f -> %.0f)" % [hp0, player.hp])
	var rs := _ridges()
	check(rs.size() == r0 + 1 and (rs[rs.size() - 1] as IceRidge).style == "stone", "the stone stays: a cairn")
	var cairn: IceRidge = rs[rs.size() - 1]
	check(absf(cairn.life - 14.0) < 0.01, "for 14 s")
	player.set("_atk_is_heavy", true)
	cairn.take_hit(DamagePacket.new(30, 10, player))
	cairn.take_hit(DamagePacket.new(30, 10, player))
	player.set("_atk_is_heavy", false)
	await ticks(2)
	check(not is_instance_valid(cairn) or cairn.is_queued_for_deletion(), "two heavy blows knock it down")
	check(c.attack_by_id("stone_toss").get("min_range", 0.0) >= 6.0, "the stone toss is for a Bearer kept off")
	c.free()
	await ticks(2)

# ------------------------------------------------------------------ the Turfwright
func _turfwright() -> void:
	print("== the Turfwright: holds the last sod up to the door")
	player.global_position = Vector3(0, 0.1, 12)
	player.hp = player.max_hp
	var tw: Turfwright = _spawn("turfwright", Vector3(0, 0.1, -4), 0.0)   # facing -z, the door
	await ticks(20)
	check(tw.vis.is_humanoid() and tw.vis.model_id == "turfwright", "the turfwright.glb body")
	check(tw.state == Enemy.ES.IDLE and not tw.stood and tw.vis.current_clip() == "turf_raise", "standing at the door, the sod held up")
	check(tw.sod_at == "spade" and tw.sod.global_position.distance_to(tw.vis.bone_xform("mixamorig_RightHand").origin) < 1.2,
		"the sod is on his spade")
	check(tw.door_point().distance_to(Vector3(0, 0.1, -13)) < 0.2, "the doorway is 9 m ahead of him")
	var hud: HUD = arena.find_children("*", "HUD", true, false)[0]
	check(not hud.boss_root.visible, "no bar yet")
	player.global_position = tw.global_position + Vector3(0, 0, 5.4)
	player.invulnerable = true
	await ticks(6)
	check(tw.state == Enemy.ES.TRANSITION, "within 6 m he sets the sod down")
	await _secs(2.8)
	check(tw.stood and hud.boss_root.visible and hud.boss_name.text == "THE TURFWRIGHT", "the bar: THE TURFWRIGHT")
	check(tw.sod_at == "threshold" and tw.sod.global_position.distance_to(tw.door_point()) < 5.5, "the sod lies on the threshold")
	var to_p := player.global_position - tw.global_position
	check((-tw.vis.global_transform.basis.z).dot(to_p.normalized()) > 0.7, "and he has turned round")

	print("== phase one: the cutting")
	var p1 := tw.repertoire()
	check("spade_chop" in p1 and "ground_cut" in p1 and "back_drop" in p1 and not ("stack_sod" in p1)
		and not ("last_turf" in p1), "spade chop, ground cut, back-drop")
	tw.target = player
	tw._set_state(Enemy.ES.COMBAT)
	tw.vis.rotation.y = PI
	player.global_position = tw.global_position + Vector3(0, 0, 6.0)
	player.invulnerable = false
	player.hp = player.max_hp
	await ticks(2)
	var hp0 := player.hp
	var gc := tw.attack_by_id("ground_cut").duplicate()
	gc["chain_chance"] = 0.0
	tw._begin_attack(gc)
	await _secs(float(gc["windup"]) + 0.15)
	check(player.hp < hp0, "the ground cut runs under him (hp %.0f -> %.0f)" % [hp0, player.hp])
	check(tw.live_ridges() == 1 and (tw.ridges[0] as IceRidge).style == "sod", "the lifted sod stands as a low wall")
	await _secs(1.4)

	print("== back-drop: the Bearer behind him too long")
	for r in tw.ridges:
		if is_instance_valid(r):
			(r as IceRidge).shatter()   # the cut would stand between them
	tw._cooldowns.clear()
	for a in ["spade_chop", "ground_cut"]:
		tw._cooldowns[a] = 99.0   # nothing else ready: only the lid answers
	tw._set_state(Enemy.ES.COMBAT)
	tw.vis.rotation.y = 0.0
	var fwd := -tw.vis.global_transform.basis.z
	player.global_position = tw.global_position - fwd * 2.6
	player.hp = player.max_hp
	hp0 = player.hp
	var dropped := false
	for i in 150:
		tw.vis.rotation.y = 0.0   # he will not get to turn: the lid is the answer
		player.global_position = tw.global_position - fwd * 2.6
		await ticks(1)
		if tw.state == Enemy.ES.ATTACK and String(tw._atk.get("id", "")) == "back_drop":
			dropped = true
			break
	check(dropped, "after 1.2 s at his back, he drops the door")
	check(tw._atk_dir.dot(fwd) < -0.9, "behind him")
	await _secs(float(tw.attack_by_id("back_drop")["windup"]) + 0.2)
	check(player.hp < hp0, "and it lands on the Bearer (hp %.0f -> %.0f)" % [hp0, player.hp])
	await _secs(2.0)

	print("== phase two at 60%: the stacking")
	player.invulnerable = true
	tw.take_hit(DamagePacket.new(tw.max_hp * 0.39, 0, player))
	await ticks(2)
	check(tw.phase == 1, "at 61% he is still cutting")
	tw.take_hit(DamagePacket.new(tw.max_hp * 0.02, 0, player))
	await ticks(2)
	check(tw.phase == 2 and tw.state == Enemy.ES.TRANSITION, "at 59% he drives the spade in")
	var hp_t := tw.hp
	tw.take_hit(DamagePacket.new(100, 0, player))
	check(tw.hp == hp_t, "he cannot be hurt while the walls come up")
	await _secs(2.8)
	check(tw.state != Enemy.ES.TRANSITION and tw.live_walls() == 4, "four sod walls cut the hollow into bays (%d)" % tw.live_walls())
	var p2 := tw.repertoire()
	check("stack_sod" in p2 and "sod_throw" in p2 and "drag_swing" in p2 and "ground_cut" in p2
		and not ("last_turf" in p2), "phase two adds stack a sod, sod throw, drag swing")
	tw._set_state(Enemy.ES.COMBAT)
	tw._begin_attack(tw.attack_by_id("ground_cut"))
	check(float(tw._atk.get("chain_chance", 0.0)) >= 1.0, "the ground cut always crosses now")
	await _secs(3.6)

	print("== stack a sod: a wall laid where the Bearer stands")
	tw._cooldowns.clear()
	tw._set_state(Enemy.ES.COMBAT)
	tw.vis.rotation.y = PI
	player.global_position = tw.global_position + Vector3(2.0, 0, 7.5)
	player.invulnerable = false
	player.hp = player.max_hp
	hp0 = player.hp
	await ticks(2)
	var ss := tw.attack_by_id("stack_sod")
	var n0 := tw.live_ridges()
	tw._begin_attack(ss)
	await _secs(float(ss["windup"]) / tw._speed_mult() + 0.15)
	check(player.hp < hp0, "the sod comes down on him (hp %.0f -> %.0f)" % [hp0, player.hp])
	var laid: IceRidge = tw.ridges[tw.ridges.size() - 1] if tw.live_ridges() > n0 else null
	var mid := laid.global_position - laid.global_transform.basis.z * laid.length * 0.5 if laid != null else Vector3.INF
	check(laid != null and Vector2(mid.x - player.global_position.x, mid.z - player.global_position.z).length() < 1.2,
		"and stays there, a wall where he stood")
	await _secs(1.4)

	print("== phase three at 25%: the last turf")
	player.invulnerable = true
	tw._set_state(Enemy.ES.COMBAT)
	tw.take_hit(DamagePacket.new(tw.hp - tw.max_hp * 0.24, 0, player))
	await ticks(2)
	check(tw.phase == 3 and tw.state == Enemy.ES.TRANSITION, "at 24% he stops")
	await _secs(3.0)
	check(tw.live_walls() == 0, "the bay walls slump")
	check(tw.sod_at == "chest" and tw.vis.rig._carry == "turf_carry", "he holds the sod to his chest")
	check(tw._speed_mult() < 1.0, "and he is slower (%.2f)" % tw._speed_mult())
	var p3 := tw.repertoire()
	check("one_hand_chop" in p3 and "ground_cut" in p3 and "last_turf" in p3 and not ("back_drop" in p3)
		and not ("spade_chop" in p3) and not ("stack_sod" in p3), "phase three: one-hand chop, ground cut, the last turf")

	print("== he keeps to the door")
	tw._cooldowns["last_turf"] = 99.0
	tw.global_position = tw.door_point() + Vector3(-6.0, 0, 11.0)   # clear of the sandbox dummy
	tw.target = player
	player.global_position = tw.global_position + Vector3(0, 0, 3.0)
	tw._set_state(Enemy.ES.COMBAT)
	for r in tw.ridges:
		if is_instance_valid(r):
			(r as IceRidge).shatter()
	var d0 := tw.global_position.distance_to(tw.door_point())
	await _secs(3.0)
	var d1 := Vector2(tw.global_position.x - tw.door_point().x, tw.global_position.z - tw.door_point().z).length()
	check(d1 < d0 - 3.0, "drawn off, he backs up to it (%.1f m -> %.1f m)" % [d0, d1])

	print("== the last turf: kneels at the door, lifts it, and holds it there")
	tw.global_position = tw.door_point() + Vector3(0, 0, 6.0)
	player.global_position = tw.global_position + Vector3(0, 0, 9.0)
	tw._cooldowns.clear()
	tw._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var lt := tw.attack_by_id("last_turf")
	tw._begin_attack(lt)
	await _secs(float(lt["windup"]) / tw._speed_mult() + 0.3)
	check(tw.state == Enemy.ES.HOLD, "he holds the sod to the gap")
	var to_door := tw.door_point() - tw.global_position
	to_door.y = 0
	check((-tw.vis.global_transform.basis.z).dot(to_door.normalized()) > 0.8, "facing the door, his back to the Bearer")
	var hp_h := tw.hp
	tw.take_hit(DamagePacket.new(10, 999, player))
	check(tw.hp < hp_h and tw.state == Enemy.ES.HOLD, "struck, he keeps holding it")
	await _secs(5.3)
	check(tw.state != Enemy.ES.HOLD and tw.sod_at == "chest", "five quiet seconds: he lowers it and stands")
	tw.free()
	await ticks(2)

# ------------------------------------------------------------------ the Lowe
var area: Area

func _talk(npc_id: String) -> DialogueUI:
	var cfg := DB.npc(npc_id)
	cfg["id"] = npc_id
	var ui := DialogueUI.new(cfg, null)
	get_tree().root.add_child(ui)
	return ui

func _service_ids(ui: DialogueUI) -> Array:
	while ui._phase == "lines":
		ui.advance()
	return ui._options.map(func(o): return String(o.get("id", "")))

func _close(ui: DialogueUI) -> void:
	if is_instance_valid(ui):
		ui.close()
	await ticks(3)

func _lines_of(thread_id: String) -> Array:
	for t in Keepsakes.journal():
		if t["id"] == thread_id:
			return t["lines"]
	return []

func _expected(thread_id: String, n: int) -> Array:
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			return (t["steps"] as Array).slice(0, n).map(func(s): return String(s["line"]))
	return []

func _pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id and not p.is_queued_for_deletion():
			return p
	return null

func _build(state: RH.WState) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	World.set_area_state("lowe_barrows", state)
	area = AreaBuilder.build("lowe_barrows")
	add_child(area)
	Game.register_area(area, "lowe_barrows")
	StateDirector.snap(area, state)
	await ticks(10)

func _lowe() -> void:
	World._save_dir = "user://test_lowe_enc"
	World.reset()
	Game.set_warmth(0)
	await _build(RH.WState.THAW)
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	var hud := HUD.new()
	add_child(hud)
	await ticks(10)

	print("== Hesk and Aud keep the thaw, each on their own model")
	for id in ["hesk", "aud"]:
		var n: NPC = null
		for c in area.find_children("*", "NPC", true, false):
			if (c as NPC).npc_id == id:
				n = c
		check(n != null and n._vis.is_humanoid() and n._vis.model_id == id, "%s stands in the thaw as %s.glb" % [id, id])
		check(n != null and n.get_meta("state_tag", "") == "thaw", "%s is THAW only" % id)

	print("== Hesk: the first meeting")
	var ui := _talk("hesk")
	await ticks(2)
	check(ui.text_label.text == "Don't stand there, you're in my draught. There. No. There.", "Hesk opens with his own line")
	check(_lines_of("hesk_tongs") == _expected("hesk_tongs", 1), "his thread starts")
	var ids := _service_ids(ui)
	check(ids.has("fold_iron") and ids.has("buy_bog_iron") and ids.has("buy_maul") and not ids.has("fold_iron_kin"),
		"he folds iron, sells bog-iron and the post maul")
	await _close(ui)

	print("== Aud: the first meeting")
	ui = _talk("aud")
	await ticks(2)
	check(ui.text_label.text.begins_with("Keep to the road, love."), "Aud opens with her own line")
	check(_lines_of("aud_cord") == _expected("aud_cord", 1), "her thread starts")
	ids = _service_ids(ui)
	check(ids.has("buy_turf_song") and ids.has("rest_level") and not ids.has("give_barrow_cloak"),
		"she teaches the Turf-Laying Song and sits you down; no cloak yet")
	await _close(ui)

	print("== the rime: the cord in the first barrow, the tongs in the bog ice")
	await _build(RH.WState.RIME)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	var cord := _pickup("orm_cord")
	var tongs := _pickup("hesk_tongs")
	check(cord != null and tongs != null and _pickup("turf_spade") != null and _pickup("woad_thread") != null,
		"the cord, the tongs, the spade and the thread are placed")
	check(_pickup("twin_spindles") == null, "no spindles before the release")
	if cord != null:
		cord._on_take(player)
	if tongs != null:
		tongs._on_take(player)
	check(_lines_of("aud_cord") == _expected("aud_cord", 2) and _lines_of("hesk_tongs") == _expected("hesk_tongs", 2),
		"both finds are remembered")
	var foes := get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead)
	var kinds := {}
	for e in foes:
		kinds[(e as Enemy).id] = true
	check(kinds.has("barrow_sleeper") and kinds.has("keener") and kinds.has("cairn_carrier") and kinds.has("turfwright")
		and not kinds.has("rimewalker") and not kinds.has("oarsman"), "the Lowe's own foes, no stand-ins (%s)" % str(kinds.keys()))
	var sitters := foes.filter(func(e): return (e as Enemy).idle_pose == "sit_up")
	check(sitters.size() == 3, "three of the dead sit up in the barrow mouths")

	print("== back in the thaw, carrying them")
	await _build(RH.WState.THAW)
	var iron0 := int(player.inventory.get("bog_iron", 0))
	ui = _talk("hesk")
	await ticks(2)
	check(World.flag("ks_hesk_tongs") and int(player.inventory.get("item_hesk_tongs", 0)) == 0, "Hesk takes the tongs")
	check(int(player.inventory.get("bog_iron", 0)) == iron0 + 1, "and gives a lump of bog-iron for them")
	ids = _service_ids(ui)
	check(ids.has("fold_iron_kin") and not ids.has("fold_iron"), "and folds iron for less")
	await _close(ui)
	ui = _talk("aud")
	await ticks(2)
	check(World.flag("ks_aud_cord") and int(player.inventory.get("item_orm_cord", 0)) == 0, "Aud takes the cord")
	check(ui.text_label.text.begins_with("That's Orm's cord."), "and will not be told")
	ids = _service_ids(ui)
	check(ids.has("give_barrow_cloak"), "Orm's working cloak is offered")
	ui.choose(ids.find("give_barrow_cloak"))
	check(int(player.inventory.get("armour_barrow_cloak", 0)) == 1, "the Bearer takes the cloak")
	await _close(ui)
	check(_lines_of("aud_cord") == _expected("aud_cord", 3) and _lines_of("hesk_tongs") == _expected("hesk_tongs", 3),
		"three lines each")

	print("== the release")
	await _build(RH.WState.RIME)
	var tw: Turfwright = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Turfwright and e.can_process():
			tw = e
	check(tw != null, "the Turfwright stands at the twins' barrow")
	check(Game.find_hearth("hs_open_barrow") == null, "the Open Barrow hearth is cold")
	var cards := []
	var on_card := func(t: String, _h: float): cards.append(t)
	Game.title_card.connect(on_card)
	player.invulnerable = true
	player.global_position = tw.global_position + Vector3(0, 0.3, 5.0)
	await ticks(4)
	tw.take_hit(DamagePacket.new(10, 0, player))   # wake him
	await _secs(2.8)
	while tw != null and not tw.dead:
		tw.take_hit(DamagePacket.new(300, 0, player))
		await _secs(3.0 if tw.state == Enemy.ES.TRANSITION else 0.05)
	await ticks(20)
	Game.title_card.disconnect(on_card)
	check(tw.released and World.flag("ks_turfwright_released"), "he is released (ks_turfwright_released)")
	check("THE TURFWRIGHT — RELEASED" in cards, "the quiet card")
	check(tw.sod_at == "door" and tw.vis.current_clip() in ["lay_turf", ""], "he lays the sod in the doorway")
	var stick := _pickup("tally_stick")
	check(stick != null and stick.item_id == "item_tally_stick" and stick.global_position.distance_to(tw.global_position) < 3.0,
		"the tally-stick lies in front of where he knelt")
	check(Game.find_hearth("hs_open_barrow") != null, "the Open Barrow becomes a Hearthstone")
	check(tw.live_ridges() == 0 and tw.live_walls() == 0, "the cuts and walls sink")
	if stick != null:
		stick._on_take(player)
	check(int(player.inventory.get("item_tally_stick", 0)) == 1, "the Bearer takes the tally-stick")
	await _build(RH.WState.RIME)
	check(_pickup("twin_spindles") != null, "the twins' spindles are on the threshold stone")
	check(Game.find_hearth("hs_open_barrow") != null, "the hearth stays lit in a rebuilt Lowe")

	print("== after the release, both threads close")
	await _build(RH.WState.THAW)
	ui = _talk("hesk")
	await ticks(2)
	check(ui.text_label.text == "Wind's come right. First time all summer. I don't trust it.", "Hesk: the wind has come right")
	await _close(ui)
	ui = _talk("aud")
	await ticks(2)
	check(ui.text_label.text.begins_with("I've moved the heather."), "Aud: she has moved the heather")
	await _close(ui)
	check(_lines_of("hesk_tongs") == _expected("hesk_tongs", 4), "Hesk's tongs: four lines, in order")
	check(_lines_of("aud_cord") == _expected("aud_cord", 4), "Orm's cord: four lines, in order")
