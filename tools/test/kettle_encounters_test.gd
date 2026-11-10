extends TestBase
## Kettle Fjord's encounters (KETTLE.md 5-9). In the arena sandbox: the
## Ice-fisher's kneel, rise and Cut a hole (runtime thin ice that takes the
## Bearer); the Sealer's Hook (caught and dragged in, then a Club); the
## Sledge-dogs on their QuadRig, the snap and the run down; the Ice-Cutter's
## intro, three phases (and the moves each unlocks), drilled holes, the trace
## that drags to the hole, the ring band, the ring cut, the dog team, the
## guard of the hole and Cut it fresh. In the fjord itself: Ivo on his model,
## Halla and Sten, both Keepsakes threads end to end, and the release (flag,
## card, the hole sealed now and on rebuild, the mitten in the new ice).

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

func _open_ice() -> Array:
	return get_tree().get_nodes_in_group("broken_ice").filter(func(b): return (b as BrokenIce).is_open())

func _close_all_ice() -> void:
	for b in _open_ice():
		(b as BrokenIce).close()
	await ticks(3)

func _revive() -> void:
	if player.dead:
		player.revive_at(Vector3(0, 0.1, 8))
	player.hp = player.max_hp
	await _secs(1.5)   # past the revival's grace

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
	await _fisher()
	await _sealer()
	await _dogs()
	await _ice_cutter()
	arena.queue_free()
	await ticks(5)
	await _fjord()
	finish()

# ------------------------------------------------------------------ Ice-fisher
func _fisher() -> void:
	print("== the Ice-fisher: kneeling at a hole that is not there")
	player.global_position = Vector3(0, 0.1, 14)
	var f := _spawn("ice_fisher", Vector3(0, 0.1, 0), 180.0, "kneel_fish")
	await ticks(10)
	check(f.vis.is_humanoid() and f.vis.model_id == "ice_fisher", "the ice_fisher.glb body")
	check(f.state == Enemy.ES.IDLE and f.vis.current_clip() == "kneel_fish", "kneeling, jigging a line (%s)" % f.vis.current_clip())
	player.global_position = Vector3(0, 0.1, 6)
	_face_player(f.global_position)
	await ticks(6)
	check(f.state == Enemy.ES.ALERT, "it sees the Bearer and rises")
	await _secs(2.0)

	print("== Cut a hole: the ice under the Bearer breaks to black water")
	f.vis.rotation.y = 0.0
	var fwd := -f.vis.global_transform.basis.z
	player.global_position = f.global_position + fwd * 4.0
	player.hp = player.max_hp
	_face_player(f.global_position)
	f.target = player
	f._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var a := f.attack_by_id("cut_hole")
	f._begin_attack(a)
	await _secs(float(a["windup"]) * 0.8)
	check(arena.find_children("*", "FloorTelegraph", true, false).size() > 0, "a circle glows where the Bearer stands")
	await _secs(float(a["windup"]) * 0.2 + 0.1)
	var ice := _open_ice()
	check(ice.size() == 1 and (ice[0] as BrokenIce).covers(player.global_position), "the ice breaks open under him")
	await ticks(12)
	var tells := arena.find_children("*", "FloorTelegraph", true, false).filter(func(t): return not t.is_queued_for_deletion())
	check(tells.is_empty(), "the glow gives way to the black water (%d tells left)" % tells.size())
	check(ice.size() == 1 and (ice[0] as BrokenIce).volumes.size() > 0
			and ((ice[0] as BrokenIce).volumes[0] as HazardVolume).kind == "thin", "a thin-ice hazard volume")
	await _secs(1.4)
	check(player.dead, "he stayed on it: the black water takes him")
	await _revive()
	await _close_all_ice()

	print("== a step off in time")
	f._cooldowns.clear()
	f._set_state(Enemy.ES.COMBAT)
	f.vis.rotation.y = 0.0
	player.global_position = f.global_position + fwd * 4.0
	await ticks(2)
	f._begin_attack(a)
	await _secs(float(a["windup"]) + 0.1)
	player.global_position += fwd.cross(Vector3.UP) * 3.5
	await _secs(1.6)
	check(not player.dead, "off it inside a second, he lives")
	await _secs(5.0)
	check(_open_ice().is_empty(), "the hole freezes over again")

	print("== Pick, then Left pick")
	player.invulnerable = true
	f._cooldowns.clear()
	var pk := f.attack_by_id("pick").duplicate()
	pk["chain_chance"] = 1.0
	f._set_state(Enemy.ES.COMBAT)
	f._begin_attack(pk)
	var chained := false
	for i in 120:
		await ticks(1)
		chained = chained or String(f._atk.get("id", "")) == "pick_left"
	check(chained, "a Pick chains into a Left pick")
	player.invulnerable = false
	f.free()
	await ticks(2)

# ------------------------------------------------------------------ Sealer
func _sealer() -> void:
	print("== the Sealer: the hook drags the Bearer in")
	player.global_position = Vector3(0, 0.1, 8)
	player.hp = player.max_hp
	var s := _spawn("sealer", Vector3(0, 0.1, 0), 0.0)
	await ticks(8)
	check(s.vis.is_humanoid() and s.vis.model_id == "sealer", "the sealer.glb body")
	s.vis.rotation.y = 0.0
	var fwd := -s.vis.global_transform.basis.z
	player.global_position = s.global_position + fwd * 4.2
	_face_player(s.global_position)
	s.target = player
	s._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var a := s.attack_by_id("hook")
	s._begin_attack(a)
	await _secs(float(a["windup"]) + 0.15)
	check(s.hook_hold != null and not player.input_enabled, "caught on the hook: held")
	await _secs(float(a["snare"]) + 0.8)
	var d := Vector2(player.global_position.x - s.global_position.x, player.global_position.z - s.global_position.z).length()
	check(player.input_enabled and d < 2.4, "dragged in to the club (%.1f m)" % d)
	var clubbed := false
	for i in 120:
		await ticks(1)
		clubbed = clubbed or (s.state == Enemy.ES.ATTACK and String(s._atk.get("id", "")) == "club")
	check(clubbed, "and the club follows")
	await _secs(1.6)

	print("== mashing breaks the hook")
	s._cooldowns.clear()
	s._set_state(Enemy.ES.COMBAT)
	s.vis.rotation.y = 0.0
	player.global_position = s.global_position + fwd * 4.2
	await ticks(2)
	s._begin_attack(a)
	await _secs(float(a["windup"]) + 0.15)
	if s.hook_hold != null:
		for i in int(a["mash"]):
			s.hook_hold.mash()
	await _secs(0.8)
	d = Vector2(player.global_position.x - s.global_position.x, player.global_position.z - s.global_position.z).length()
	check(player.input_enabled and d > 3.5, "broken free, he stays where he was (%.1f m)" % d)
	s.free()
	await ticks(2)

# ------------------------------------------------------------------ Sledge-dogs
func _dogs() -> void:
	print("== the Sledge-dogs: a pair on QuadRig poses")
	player.global_position = Vector3(0, 0.1, 9)
	player.hp = player.max_hp
	var a := _spawn("sledge_dog", Vector3(-1.2, 0.1, 0), 0.0)
	var b := _spawn("sledge_dog", Vector3(1.2, 0.1, 0), 0.0)
	await ticks(8)
	check(a.vis.is_quadruped() and a.vis.model_id == "sledge_dog", "the sledge_dog.glb quadruped")
	check(bool(a.cfg.get("flank", false)), "a pair works from opposite sides (flank)")
	b.free()
	a.vis.rotation.y = 0.0
	var fwd := -a.vis.global_transform.basis.z
	player.global_position = a.global_position + fwd * 6.0
	_face_player(a.global_position)
	a.target = player
	a._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var run := a.attack_by_id("run_down")
	var hp0 := player.hp
	var start := a.global_position
	a._begin_attack(run)
	await _secs(float(run["windup"]) * 0.5)
	check(a.vis.quad.weight("crouch") > 0.3, "it drops low on the tell")
	await _secs(float(run["windup"]) * 0.5 + float(run["active"]))
	check(player.hp < hp0, "it runs him down (hp %.0f -> %.0f)" % [hp0, player.hp])
	check(a.global_position.distance_to(start) > 4.0, "flat out along the strip (%.1f m)" % a.global_position.distance_to(start))
	a.free()
	await ticks(2)

# ------------------------------------------------------------------ the Ice-Cutter
func _ice_cutter() -> void:
	print("== the Ice-Cutter: kneeling at the rim, drilling")
	player.global_position = Vector3(0, 0.1, 10)
	player.hp = player.max_hp
	var ic: IceCutter = _spawn("ice_cutter", Vector3(0, 0.1, -6), 180.0)   # facing +z: the hole, then the way in
	await ticks(20)
	check(ic.vis.is_humanoid() and ic.vis.model_id == "ice_cutter", "the ice_cutter.glb body")
	check(ic.state == Enemy.ES.IDLE and not ic.stood and ic.vis.current_clip() == "kneel_drill", "kneeling, drilling")
	check(ic.hole_point().distance_to(Vector3(0, 0.1, -3.36)) < 0.1, "the hole is 2.64 m ahead of him")
	var hud: HUD = arena.find_children("*", "HUD", true, false)[0]
	check(not hud.boss_root.visible, "no bar yet")
	player.global_position = ic.global_position + Vector3(4.5, 0, 2.0)
	player.invulnerable = true
	await ticks(6)
	check(ic.state == Enemy.ES.TRANSITION, "within 6 m he pulls the auger out")
	await _secs(2.8)
	check(ic.stood and hud.boss_root.visible and hud.boss_name.text == "THE ICE-CUTTER", "the bar: THE ICE-CUTTER")

	print("== phase one: the hole")
	var p1 := ic.repertoire()
	check("auger_thrust" in p1 and "drill_down" in p1 and "trace" in p1 and not ("ring_cut" in p1)
		and not ("cut_fresh" in p1), "auger thrust, drill down, trace")
	player.invulnerable = false
	ic.target = player
	ic.vis.rotation.y = PI
	player.global_position = ic.global_position + Vector3(0, 0, 8.0)
	player.hp = player.max_hp
	ic._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var dd := ic.attack_by_id("drill_down")
	ic._begin_attack(dd)
	await _secs(float(dd["windup"]) + 0.1)
	check(ic.open_holes() == 1 and (ic.holes[0] as BrokenIce).covers(player.global_position), "he drills a hole under the Bearer")
	await _secs(1.4)
	check(player.dead, "and the fjord takes him")
	await _revive()
	await _close_all_ice()

	print("== the trace drags the Bearer to the hole, not to him")
	ic.target = player
	ic._cooldowns.clear()
	ic._set_state(Enemy.ES.COMBAT)
	ic.vis.rotation.y = PI
	player.global_position = ic.global_position + Vector3(0, 0, 8.0)
	player.invulnerable = false
	await ticks(2)
	var tr := ic.attack_by_id("trace")
	ic._begin_attack(tr)
	await _secs(float(tr["windup"]) + 0.15)
	check(ic.hook_hold != null, "the frozen trace catches him")
	player.invulnerable = true   # (the rim is not the hole; keep him to measure)
	await _secs(float(tr["snare"]) + 1.0)
	var to_hole := Vector2(player.global_position.x - ic.hole_point().x, player.global_position.z - ic.hole_point().z).length()
	check(to_hole < 3.4, "hauled to the hole's rim (%.1f m from its centre)" % to_hole)
	await _secs(2.0)

	print("== phase two at 60%: the rings")
	ic._set_state(Enemy.ES.COMBAT)
	ic.take_hit(DamagePacket.new(ic.max_hp * 0.39, 0, player))
	await ticks(2)
	check(ic.phase == 1, "at 61% the hole is all")
	ic.take_hit(DamagePacket.new(ic.max_hp * 0.02, 0, player))
	await ticks(2)
	check(ic.phase == 2 and ic.state == Enemy.ES.TRANSITION, "at 59% he turns the auger once")
	var hp_t := ic.hp
	ic.take_hit(DamagePacket.new(100, 0, player))
	check(ic.hp == hp_t, "he cannot be hurt while he cuts the ring")
	await _secs(2.8)
	check(ic.band != null and ic.band.is_open() and ic.band.shape == "ring"
			and absf(ic.band.inner - 9.0) < 0.01 and absf(ic.band.radius - 10.5) < 0.01,
		"a band of open water from 9 to 10.5 m round the hole")
	var p2 := ic.repertoire()
	check("ring_cut" in p2 and "dog_team" in p2 and "drill_down" in p2 and not ("cut_fresh" in p2),
		"phase two adds ring cut and the team")
	ic._set_state(Enemy.ES.COMBAT)
	ic._begin_attack(ic.attack_by_id("drill_down"))
	check(float((ic._atk["ice"] as Dictionary).get("lead", 0.0)) > 0.0, "drill down opens a second hole ahead of him")
	ic._set_state(Enemy.ES.COMBAT)   # (not here: the fjord does not care for i-frames)
	await _close_all_ice()
	await _revive()

	print("== ring cut: a ring round him drops away")
	await _close_all_ice()   # (nothing left open from the moves before)
	ic.target = player
	for a2 in ic.cfg.get("attacks", []):   # (and he picks nothing else meanwhile)
		ic._cooldowns[String(a2["id"])] = 99.0
	ic._set_state(Enemy.ES.COMBAT)
	player.invulnerable = false
	player.hp = player.max_hp
	player.global_position = ic.global_position + Vector3(3.6, 0, 0)
	await ticks(2)
	var rc := ic.attack_by_id("ring_cut")
	var n0 := ic.open_holes()
	ic._begin_attack(rc)
	# (wait on the ring itself, not the clock: a loaded machine runs several
	# physics steps a frame, and a fixed wait could leave him on it past the sink)
	var waited := 0
	while ic.open_holes() <= n0 and waited < 240:
		await ticks(1)
		waited += 1
	var ring: BrokenIce = ic.holes[ic.holes.size() - 1]
	check(ic.open_holes() == n0 + 1 and ring.shape == "ring" and ring.covers(player.global_position)
			and not ring.covers(ic.global_position), "a ring from 2.5 to 5 m: the Bearer at 3.6 m is on it, he is not")
	player.global_position = ic.global_position + Vector3(1.2, 0, 0)
	await _secs(1.2)
	check(not player.dead, "stepped in close, he stands on whole ice")
	ring.close()
	await _secs(1.4)

	print("== the team runs down the ice")
	ic._cooldowns.clear()
	ic._set_state(Enemy.ES.COMBAT)
	ic.vis.rotation.y = PI
	player.global_position = ic.global_position + Vector3(0, 0, 7.0)
	player.hp = player.max_hp
	await ticks(2)
	var dt := ic.attack_by_id("dog_team")
	var hp0 := player.hp
	ic._begin_attack(dt)
	await _secs(float(dt["windup"]) / ic._speed_mult() + 0.1)
	check(player.hp < hp0, "standing in the strip, he is run down (hp %.0f -> %.0f)" % [hp0, player.hp])
	var dogs := arena.find_children("*", "Enemy", true, false).filter(func(e): return (e as Enemy).id == "sledge_dog")
	check(dogs.size() == int(dt["dogs"]), "the dead team: %d dogs on the ice" % dogs.size())
	await _secs(1.6)
	dogs = arena.find_children("*", "Enemy", true, false).filter(func(e): return is_instance_valid(e) and (e as Enemy).id == "sledge_dog")
	check(dogs.is_empty(), "and gone")

	print("== phase three at 25%: the hour")
	player.invulnerable = true
	ic._set_state(Enemy.ES.COMBAT)
	ic.take_hit(DamagePacket.new(ic.hp - ic.max_hp * 0.24, 0, player))
	await ticks(2)
	check(ic.phase == 3 and ic.state == Enemy.ES.TRANSITION, "at 24% he stops")
	await _secs(3.0)
	check(ic.band == null or not is_instance_valid(ic.band) or not ic.band.is_open(), "the band closes over")
	var to_h := Vector2(ic.global_position.x - ic.hole_point().x, ic.global_position.z - ic.hole_point().z).length()
	check(to_h < 3.5, "he is back at the hole (%.1f m)" % to_h)
	check(ic._speed_mult() < 1.0, "and slower (%.2f)" % ic._speed_mult())
	var p3 := ic.repertoire()
	check("auger_thrust" in p3 and "trace" in p3 and "cut_fresh" in p3 and not ("drill_down" in p3)
		and not ("ring_cut" in p3), "phase three: auger thrust, trace, cut it fresh")

	print("== he keeps to the hole")
	ic._cooldowns["cut_fresh"] = 99.0
	ic.global_position = ic.hole_point() + Vector3(-7.0, 0, 6.0)
	player.global_position = ic.global_position + Vector3(-1.5, 0, 2.5)
	ic._set_state(Enemy.ES.COMBAT)
	var d0 := Vector2(ic.global_position.x - ic.hole_point().x, ic.global_position.z - ic.hole_point().z).length()
	await _secs(3.0)
	var d1 := Vector2(ic.global_position.x - ic.hole_point().x, ic.global_position.z - ic.hole_point().z).length()
	check(d1 < d0 - 3.0, "drawn off, he goes back to it (%.1f m -> %.1f m)" % [d0, d1])

	print("== cut it fresh: he kneels at the rim and drills, open")
	ic.global_position = ic.hole_point() + Vector3(0, 0, 3.0)
	player.global_position = ic.global_position + Vector3(0, 0, 7.0)
	ic._cooldowns.clear()
	ic._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	var cf := ic.attack_by_id("cut_fresh")
	ic._begin_attack(cf)
	await _secs(float(cf["windup"]) / ic._speed_mult() + 0.3)
	check(ic.state == Enemy.ES.HOLD, "he drills at the rim")
	var to := ic.hole_point() - ic.global_position
	to.y = 0
	check((-ic.vis.global_transform.basis.z).dot(to.normalized()) > 0.8, "facing the hole, his back to the Bearer")
	var hp_h := ic.hp
	ic.take_hit(DamagePacket.new(10, 999, player))
	check(ic.hp < hp_h and ic.state == Enemy.ES.HOLD, "struck, he keeps drilling")
	await _secs(5.3)
	check(ic.state != Enemy.ES.HOLD, "five quiet seconds: he stands")
	ic.free()
	await _close_all_ice()

# ------------------------------------------------------------------ the fjord
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

func _hole_hazards(at: Vector3) -> int:
	var n := 0
	for h in area.find_children("*", "HazardVolume", true, false):
		var hv := h as HazardVolume
		if hv.kind == "thin" and not hv.is_queued_for_deletion() \
				and Vector2(hv.global_position.x - at.x, hv.global_position.z - at.z).length() < 2.0:
			n += 1
	return n

func _build(state: RH.WState) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	World.set_area_state("kettle_fjord", state)
	area = AreaBuilder.build("kettle_fjord")
	add_child(area)
	Game.register_area(area, "kettle_fjord")
	StateDirector.snap(area, state)
	await ticks(10)

func _fjord() -> void:
	World._save_dir = "user://test_kettle_enc"
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

	print("== Ivo, Halla and Sten keep the thaw")
	var ids_seen := {}
	for c in area.find_children("*", "NPC", true, false):
		ids_seen[(c as NPC).npc_id] = c
	check(ids_seen.has("ivo") and ids_seen.has("halla") and ids_seen.has("sten"), "all three stand in the thaw")
	var ivo: NPC = ids_seen.get("ivo")
	check(ivo != null and ivo._vis.is_humanoid() and ivo._vis.model_id == "ivo", "Ivo stands as ivo.glb")

	print("== the first meetings")
	var ui := _talk("ivo")
	await ticks(2)
	check(ui.text_label.text == "Hold that one. Not by the collar, she bites.", "Ivo opens with his own line")
	check(_lines_of("ivo_mitten") == _expected("ivo_mitten", 1), "his thread starts")
	await _close(ui)
	ui = _talk("halla")
	await ticks(2)
	check(_lines_of("halla_cord") == _expected("halla_cord", 1), "Halla's thread starts")
	var ids := _service_ids(ui)
	check(ids.has("buy_bog_iron") and ids.has("buy_harpoon") and ids.has("buy_flask"), "she sells iron, a harpoon and a flask")
	await _close(ui)
	ui = _talk("sten")
	await ticks(2)
	check(ui.text_label.text.begins_with("Sorry."), "Sten apologises")
	ids = _service_ids(ui)
	check(ids.has("give_icefur"), "and offers his coat")
	ui.choose(ids.find("give_icefur"))
	check(int(player.inventory.get("armour_icefur", 0)) == 1, "the Bearer takes Sten's coat")
	await _close(ui)

	print("== the rime: the ladle in the pot, the cord on the post")
	await _build(RH.WState.RIME)
	var ladle := _pickup("kettle_ladle")
	var cord := _pickup("halla_cord")
	check(ladle != null and cord != null and _pickup("ice_auger") != null and _pickup("sealer_harpoon") != null,
		"the ladle, the cord, the auger and the harpoon are placed")
	if ladle != null:
		ladle._on_take(player)
	if cord != null:
		cord._on_take(player)
	check(_lines_of("ivo_mitten") == _expected("ivo_mitten", 2) and _lines_of("halla_cord") == _expected("halla_cord", 2),
		"both finds are remembered")
	var foes := get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead)
	var kinds := {}
	for e in foes:
		kinds[(e as Enemy).id] = true
	check(kinds.has("ice_fisher") and kinds.has("sledge_dog") and kinds.has("sealer") and kinds.has("ice_cutter")
		and not kinds.has("rimewalker") and not kinds.has("oarsman") and not kinds.has("hearthhound"),
		"the fjord's own foes, no stand-ins (%s)" % str(kinds.keys()))

	print("== back in the thaw, carrying the cord")
	await _build(RH.WState.THAW)
	ui = _talk("halla")
	await ticks(2)
	check(World.flag("ks_halla_cord") and int(player.inventory.get("item_halla_cord", 0)) == 0, "Halla takes the cord")
	check(ui.text_label.text.begins_with("That's not my knot."), "and reads the last knot")
	await _close(ui)
	ui = _talk("ivo")
	await ticks(2)
	check(ui.text_label.text.begins_with("Fish again."), "Ivo grumbles about his supper")
	await _close(ui)

	print("== the release")
	await _build(RH.WState.RIME)
	var ic: IceCutter = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is IceCutter and e.can_process():
			ic = e
	check(ic != null, "the Ice-Cutter kneels at the Breathing Hole")
	var hole := ic.hole_point() if ic != null else Vector3.ZERO
	check(_hole_hazards(hole) >= 1, "the hole is open: its thin ice takes whoever steps on it")
	var cards := []
	var on_card := func(t: String, _h: float): cards.append(t)
	Game.title_card.connect(on_card)
	player.invulnerable = true
	player.global_position = ic.global_position + Vector3(4.5, 0.3, 0.0)
	await ticks(4)
	ic.take_hit(DamagePacket.new(10, 0, player))
	await _secs(2.8)
	while ic != null and not ic.dead:
		ic.take_hit(DamagePacket.new(300, 0, player))
		await _secs(3.0 if ic.state == Enemy.ES.TRANSITION else 0.05)
	await ticks(20)
	Game.title_card.disconnect(on_card)
	check(ic.released and World.flag("ks_ice_cutter_released"), "he is released (ks_ice_cutter_released)")
	check("THE ICE-CUTTER — RELEASED" in cards, "the quiet card")
	check(_hole_hazards(hole) == 0, "the hole skins over: no thin ice left under it")
	var wet := []
	for m in area.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.is_visible_in_tree() and mi.mesh is CylinderMesh and mi.global_position.y < 0.25 \
				and Vector2(mi.global_position.x - hole.x, mi.global_position.z - hole.z).length() < 1.0:
			wet.append("%s %s %s" % [mi.name, mi.mesh, mi.global_position])
	check(wet.is_empty(), "no open water shows where the hole was %s" % str(wet))
	check(ic.open_holes() == 0 and get_tree().get_nodes_in_group("broken_ice").filter(
		func(b): return (b as BrokenIce).is_open()).is_empty(), "every hole he broke closes")
	var mitten := _pickup("ivo_mitten")
	check(mitten != null and Vector2(mitten.global_position.x - hole.x, mitten.global_position.z - hole.z).length() < 0.3,
		"the mitten lies in the new ice where the hole was")
	if mitten != null:
		mitten._on_take(player)
	check(int(player.inventory.get("item_ivo_mitten", 0)) == 1 and World.flag("ks_ivo_mitten_found"),
		"the Bearer chips the mitten free")
	await _build(RH.WState.RIME)
	await ticks(10)
	check(_hole_hazards(hole) == 0, "the hole stays closed in a rebuilt fjord")
	var wet2 := area.find_children("*", "MeshInstance3D", true, false).filter(func(m):
		return (m as MeshInstance3D).is_visible_in_tree() and (m as MeshInstance3D).mesh is CylinderMesh \
			and (m as MeshInstance3D).global_position.y < 0.25 \
			and Vector2((m as Node3D).global_position.x - hole.x, (m as Node3D).global_position.z - hole.z).length() < 1.0)
	check(wet2.is_empty(), "and no water shows there")

	print("== after the release, both threads close")
	await _build(RH.WState.THAW)
	ui = _talk("ivo")
	await ticks(2)
	check(World.flag("ks_ivo_mitten") and ui.text_label.text == "That's mine. Where was it? I had it this morning.",
		"Ivo takes his mitten")
	await _close(ui)
	ui = _talk("halla")
	await ticks(2)
	check(ui.text_label.text.begins_with("I've put him in the end house"), "Halla has put Sten by the fire")
	await _close(ui)
	check(_lines_of("ivo_mitten") == _expected("ivo_mitten", 4), "Ivo's mitten: four lines, in order")
	check(_lines_of("halla_cord") == _expected("halla_cord", 4), "Halla's cord: four lines, in order")
