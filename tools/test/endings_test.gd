extends TestBase
## The two endings (COLDWELL.md 10, ADR 0011), through the `ending_choice`
## hook at the spring. Both are reachable once the Leadvoice is released,
## and only one of them, once. The Outsong: its beats in order, the flag, the
## robes and the mask, true spring in every area (open ground, the grey
## light, nobody remembered, no frost-taken), hearths that will not warm,
## the horn empty, two masks on the peg at Saltfell; then saved, loaded and
## still so. The Hearth Kept: its beats, the flag, the remembered Melt at the
## Coldwell and the frost everywhere else, the Bearer sat and held, the frost
## on him; saved, loaded, and resumed where he sat. The credits. The seven
## pieces of WORLD.md 4, each placed where it can be found. A save from
## before the endings loads as one that has not ended.

var area: Area
var player: Player
var hud: HUD

func _ready() -> void:
	_run.call_deferred()

func _secs(s: float):
	await ticks(int(ceil(s * 60.0)))

func _build(id: String) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	StateDirector.snap(area, World.get_area_state(id))
	await ticks(10)

func _fresh(slot_dir: String) -> void:
	for d in get_tree().root.find_children("*", "EndingDirector", true, false):
		d.free()
	if player != null and is_instance_valid(player):
		player.free()
	Game.player = null
	if hud != null and is_instance_valid(hud):
		hud.free()
	World._save_dir = slot_dir
	World.reset()
	World.delete_slot(World.active_slot)
	Game.set_warmth(0)
	# the road so far: every Holdfast released, the Coldwell stilled
	for a in ["saltfell_steading", "lowe_barrows", "kettle_fjord", "tarnhall", "thornwold", "shepherds_reach", "coldwell"]:
		World.set_cleared(a)
		World.set_area_state(a, RH.WState.RIME)
	World.set_area_flag("coldwell", "slain_leadvoice")
	await _build("coldwell")
	player = Player.new()
	add_child(player)
	hud = HUD.new()
	add_child(hud)
	player.sim_active = true
	await ticks(6)

func _choice() -> Node:
	for c in get_tree().get_nodes_in_group("ending_choice"):
		if area.is_ancestor_of(c):
			return c
	return null

func _npcs_seen() -> Array:
	return area.find_children("*", "NPC", true, false).filter(func(n): return (n as NPC).is_visible_in_tree() and not n.is_queued_for_deletion())

func _foes_live() -> Array:
	return get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e):
		return is_instance_valid(e) and area.is_ancestor_of(e) and e.can_process() and not e.dead and not e.is_queued_for_deletion())

func _run() -> void:
	await _pieces()
	await _credits()
	await _outsong()
	await _hearth_kept()
	_old_save()
	finish()

# ------------------------------------------------------------------ the seven pieces
func _has_pickup(area_id: String, item: String) -> bool:
	return DB.area_def(area_id).get("pickups", []).any(func(p): return String(p.get("item", "")) == item)

func _pieces() -> void:
	print("== the Bearer's own grief, in seven pieces, each where it can be found")
	check(_has_pickup("saltfell_steading", "ks_child_mask"), "1 Saltfell: the small mask on the peg")
	check(not ("Wren" in String(DB.item("ks_child_mask")["desc"])), "  whose it is, its text does not say")
	check(_has_pickup("lowe_barrows", "ks_woad_thread"), "2 the Lowe: the woad thread on the closed barrow")
	var tracks: Array = DB.area_def("kettle_fjord").get("pickups", []).filter(func(p): return String(p.get("id", "")) == "ice_tracks")
	check(tracks.size() == 1 and String(tracks[0].get("look", "")).contains("The left stride is longer"), "3 Kettle Fjord: one set of footprints, the left stride longer")
	check(_has_pickup("tarnhall", "item_latch_wool"), "4 Tarnhall: woad wool on the latch, outside")
	check(_has_pickup("thornwold", "item_knucklebone"), "5 Thornwold: the fifth knucklebone on the drove-road")
	var calder: Dictionary = DB.npc("old_calder")
	check((calder.get("chapters", []) as Array).size() == 2 and (calder.get("line_sfx", {}) as Dictionary).values()[0][0] == AudioDirector.cfg("hum", ""),
		"6 the Reach: Old Calder hums it, the hum the Bearer rests to")
	check((DB.table("items")["fostering_horn"].get("desc_when", []) as Array).any(func(w): return w["flag"] == "ks_horn_wellhead")
		and DB.area_def("coldwell")["zones"].any(func(z): return String(z.get("set_flag", "")) == "ks_horn_wellhead"),
		"7 the Coldwell: the horn reads differently at the wellhead")
	var said := JSON.stringify(DB.table("npcs")) + JSON.stringify(DB.table("keepsakes"))
	check(not said.contains("your mother") and not said.contains("your sister") and not said.contains("the Bearer's"), "nobody says what they add up to")
	World.reset()
	World._save_dir = "user://test_endings_look"
	area = null
	World.set_area_state("kettle_fjord", RH.WState.RIME)
	await _build("kettle_fjord")
	var tr: Pickup = null
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == "ice_tracks":
			tr = p
	check(tr != null and tr.look_text != "", "the tracks are a thing to look at")
	if tr != null:
		var read := []
		var on := func(t): read.append(t)
		Game.lore_panel.connect(on)
		tr._on_take(null)
		Game.lore_panel.disconnect(on)
		check(read.size() == 1 and World.flag("ks_ice_tracks_seen") and is_instance_valid(tr) and not tr.is_queued_for_deletion(),
			"looked at, they stay where they are")
	area.free()
	area = null
	await ticks(3)

# ------------------------------------------------------------------ credits
func _credits() -> void:
	print("== the credits")
	var c := CreditsUI.new()
	add_child(c)
	await ticks(4)
	var texts: Array = c.lines.map(func(e): return String(e[1]))
	check("RIMEHOLT" in texts and "Figglebottom Productions" in texts, "the game and the house")
	check(c.lines.any(func(e): return e[0] == "knot") and c.duration() > 20.0, "one slow column, a knot at the foot (%.0f s)" % c.duration())
	var done := [false]
	c.finished.connect(func(): done[0] = true)
	c.skip()
	await ticks(2)
	check(done[0] and not is_instance_valid(c), "and they end")

# ------------------------------------------------------------------ the Outsong
func _outsong() -> void:
	print("== the choice at the spring")
	await _fresh("user://test_endings_outsong")
	var ec := _choice()
	check(ec != null and not ec.is_open() and World.ended() == "", "nothing is offered while she sits there")
	World.set_flag("ks_leadvoice_released")
	await ticks(3)
	check(ec.is_open(), "released: both are offered")
	check(Game.toggle_free("coldwell") and Game.toggle_free("saltfell_steading"), "(before: the cleared hearths turn freely)")
	player.global_position = ec.to_global(Vector3(-ec.spread * 0.5, 0.3, 0))
	await ticks(4)

	print("== the Outsong")
	ec.set_meta("fast", true)
	ec._outsong.activate(player)
	check(World.flag("ending_outsong") and World.ended() == "outsong" and World.spring(), "ending_outsong")
	check(not ec.is_open(), "the other is no longer offered")
	ec.choose("hearth_kept")
	check(not World.flag("ending_hearth_kept"), "and cannot be taken after")
	var d: EndingDirector = ec.director
	check(d != null and EndingDirector.active == d, "the ending is running")
	var guard := 0
	while is_instance_valid(d) and not d.done and guard < 600:
		guard += 1
		await ticks(1)
	var beats: Array = d.beats if is_instance_valid(d) else []
	await ticks(4)
	check(beats == ["begin", "mask", "sing", "kneel", "coal", "spring", "walk", "credits", "end"], "its beats, in order: %s" % str(beats))
	check(player.vis.model_id == "bearer_outsong", "the Bearer is in the robes and the mask (%s)" % player.vis.model_id)
	check(player.input_enabled, "and has the walk out to himself")
	check(hud.visible, "the HUD is back after the credits")
	check(area.thaw_layer.visible and not area.rime_layer.visible, "the Coldwell is open ground and running water")
	check(_npcs_seen().is_empty(), "nobody is remembered at the spring")
	check(_foes_live().is_empty(), "and nobody is kept there")
	var spring_sun: Array = area.env.profiles["spring"]["sun_color"]
	check(area.env.sun.light_color.is_equal_approx(Color(spring_sun[0], spring_sun[1], spring_sun[2])), "the light is the grey of a real spring")
	check(area.env.music_for(RH.WState.THAW) == "", "no music is laid over it")

	print("== after: every hearth, every area")
	for a in ["saltfell_steading", "lowe_barrows", "kettle_fjord", "tarnhall", "thornwold", "shepherds_reach", "coldwell"]:
		check(World.get_area_state(a) == RH.WState.THAW and not Game.toggle_free(a), "%s: thawed for good, and the hearth will not turn" % a)
	World.set_area_state("tarnhall", RH.WState.RIME)
	check(World.get_area_state("tarnhall") == RH.WState.THAW, "nothing stills it again")
	check(String(DB.item("fostering_horn")["desc"]).contains("It is empty."), "the horn is empty")
	var h: Hearthstone = get_tree().get_nodes_in_group("hearths").filter(func(x): return area.is_ancestor_of(x))[0]
	var started := [0]
	var on_t := func(_a, _s): started[0] += 1
	StateDirector.transition_started.connect(on_t)
	await Game.hearth_flow(h, player, "toggle")
	StateDirector.transition_started.disconnect(on_t)
	check(started[0] == 0 and area.thaw_layer.visible, "resting turns nothing")
	var rest := RestUI.new(h, player)
	get_tree().root.add_child(rest)
	await ticks(3)
	var ids: Array = rest._options.map(func(o): return String(o["id"]))
	check("cold" in ids and not ("toggle" in ids), "the stone can be asked")
	rest.choose(ids.find("cold"))
	check(rest.info_label.text == "The horn is empty.", "and answers: %s" % rest.info_label.text)
	rest.close()
	await ticks(3)
	player.lock_control(false)

	print("== Saltfell, in spring")
	await _build("saltfell_steading")
	check(area.thaw_layer.visible and _npcs_seen().is_empty() and _foes_live().is_empty(), "the yard is empty: no Ingra, no Brede, no frost-taken")
	var masks := area.find_children("*", "Node3D", true, false).filter(func(n):
		return String((n as Node3D).scene_file_path).ends_with("child_mask.tscn") or String((n as Node3D).scene_file_path).ends_with("mourning_mask.tscn"))
	check(masks.size() == 2, "two masks on the pegs by the Longhouse door (%d)" % masks.size())
	check(not area.find_children("*", "Hearthstone", true, false).is_empty(), "the hearthstones are still there to rest at")

	print("== saved, and loaded")
	Game.snapshot_player()
	World.save_game()
	check(World.slot_summary(World.active_slot)["ending"] == "outsong", "the slot knows how it ended")
	World.reset()
	check(World.ended() == "", "(a clean world has not ended)")
	check(World.load_game() and World.ended() == "outsong" and World.spring(), "loaded: still spring")
	check(World.get_area_state("kettle_fjord") == RH.WState.THAW and not Game.toggle_free("kettle_fjord"), "and still nothing to turn")
	var p2 := Player.new()
	add_child(p2)
	p2.from_save(World.player_data)
	await ticks(4)
	check(p2.vis.model_id == "bearer_outsong", "the Bearer loads in the robes")
	p2.free()
	await _build("coldwell")
	var ec2 := _choice()
	World.set_flag("ks_leadvoice_released")
	await ticks(3)
	check(ec2 != null and not ec2.is_open(), "the spring offers nothing a second time")
	check(_npcs_seen().is_empty(), "and Maren and Wren are not at the water")

# ------------------------------------------------------------------ the Hearth Kept
func _hearth_kept() -> void:
	print("== the Hearth Kept")
	await _fresh("user://test_endings_kept")
	World.set_flag("ks_leadvoice_released")
	await ticks(3)
	var ec := _choice()
	check(ec.is_open(), "both are offered")
	player.global_position = ec.kept_spot() + Vector3.UP * 0.3
	await ticks(4)
	ec.set_meta("fast", true)
	ec._kept.activate(player)
	check(World.flag("ending_hearth_kept") and World.ended() == "hearth_kept" and World.kept() and not World.spring(), "ending_hearth_kept")
	var d: EndingDirector = ec.director
	var guard := 0
	while is_instance_valid(d) and not d.done and guard < 600:
		guard += 1
		await ticks(1)
	await ticks(4)
	check(d.beats == ["begin", "shut", "melt", "sit", "credits", "end"], "its beats, in order: %s" % str(d.beats))
	check(is_instance_valid(d) and EndingDirector.active == d, "it does not end: it stays")
	check(area.thaw_layer.visible and not area.rime_layer.visible, "the Coldwell is the remembered Melt")
	var seen := _npcs_seen().map(func(n): return (n as NPC).npc_id)
	check("maren" in seen and "wren" in seen, "a woman and a child at the water (%s)" % str(seen))
	for a in ["saltfell_steading", "lowe_barrows", "kettle_fjord", "tarnhall", "thornwold", "shepherds_reach"]:
		check(World.get_area_state(a) == RH.WState.RIME and not Game.toggle_free(a), "%s: frozen, and it stays frozen" % a)
	check(World.get_area_state("coldwell") == RH.WState.THAW, "the Coldwell alone is warm")
	check(not player.input_enabled and player.state == Player.S.REST, "the Bearer has sat down and does not get up")
	check(player.vis.current_clip() == String(DB.tuning("endings/hearth_kept/sit_clip", "")), "sat by the spring (%s)" % player.vis.current_clip())
	check(player.global_position.distance_to(ec.kept_spot()) < 1.0, "where he chose")
	var rime = player.vis.get_meta("frost_over", null)
	check(rime is StandardMaterial3D and (rime as StandardMaterial3D).albedo_color.a > 0.4, "the frost has come onto him")
	check(not hud.visible and d.cam != null and d.cam.current, "no HUD; the camera has gone back")
	check(String(DB.item("fostering_horn")["desc"]).begins_with("The horn a child carries") or String(DB.item("fostering_horn")["desc"]).begins_with("A cow's horn"),
		"the horn is shut, and still has its coal")
	check(player.vis.model_id != "bearer_outsong", "nobody put a mask on")

	print("== saved, and loaded")
	World.save_game()
	check(World.slot_summary(World.active_slot)["ending"] == "hearth_kept", "the slot knows how it ended")
	d.free()
	player.free()
	Game.player = null
	hud.free()
	World.reset()
	check(World.load_game() and World.kept(), "loaded: kept")
	await _build(World.KEPT_AREA)
	check(area.thaw_layer.visible, "it opens on the Melt")
	player = Player.new()
	add_child(player)
	player.from_save(World.player_data)
	hud = HUD.new()
	add_child(hud)
	await ticks(4)
	var r := EndingDirector.resume_kept(player, area)
	await ticks(6)
	var ec2 := _choice()
	check(r.beats == ["kept"] and not player.input_enabled, "and on the Bearer, sat, held")
	check(player.global_position.distance_to(ec2.kept_spot()) < 1.0 and player.vis.current_clip() == "sit_still", "at the spring (%s)" % player.vis.current_clip())
	check(not hud.visible and r.cam != null and r.cam.current, "the same view")
	check(not ec2.is_open(), "the spring offers nothing")
	player.lock_control(false)
	check(not Game.toggle_free("coldwell"), "there is no hearth to turn it back")
	r.free()

# ------------------------------------------------------------------ an older save
func _old_save() -> void:
	print("== a save from before")
	var old := {"save_version": 2, "flags": {"met_steward_ingra": true}, "areas": {}, "player": {"level": 3, "armour": {}},
			"meta": {"level": 3, "area": "saltfell_steading"}}
	var up := World.migrate(old)
	check(int(up["save_version"]) == World.SAVE_VERSION and String(up["meta"]["ending"]) == "", "v2 becomes v%d: not ended" % World.SAVE_VERSION)
	World.reset()
	check(World.get_area_state("saltfell_steading") == RH.WState.THAW and World.ended() == "", "a fresh journey begins in the thaw, as it always did")
	World.set_area_state("saltfell_steading", RH.WState.RIME)
	check(World.get_area_state("saltfell_steading") == RH.WState.RIME, "and can be stilled")
