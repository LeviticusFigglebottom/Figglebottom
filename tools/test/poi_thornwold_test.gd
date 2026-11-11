extends TestBase
## Thornwold's points of interest (docs/lore/POI.md 6): the Notch's board, a
## caption for each state; Linnet's hut and the ends she cut off; the Field
## They Haven't Got, its gateposts and the latch; the Layer's Stiles, grown
## over in RIME and broken open from inside. Also the region's own prop set
## and plants (BIOMES.md).

const GRAVE := Vector2(452.0, -325.0)
const R1 := 12.0
const R2 := 19.0
const R3 := 26.0
const STILE_A := 125.0

var area: Area
var player: Player
var _panel := ""

func _ready() -> void:
	_run.call_deferred()

func _ring(r: float, a_deg: float) -> Vector3:
	var x := GRAVE.x + r * cos(deg_to_rad(a_deg))
	var z := GRAVE.y + r * sin(deg_to_rad(a_deg))
	return Vector3(x, area.terrain.height_at(x, z), z)

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := area.get_world_3d().navigation_map
	var q := NavigationPathQueryParameters3D.new()
	q.map = map
	q.start_position = NavigationServer3D.map_get_closest_point(map, from)
	q.target_position = NavigationServer3D.map_get_closest_point(map, to)
	q.path_search_max_polygons = 200000
	var r := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(q, r)
	return r.path

func _len(p: PackedVector3Array) -> float:
	var t := 0.0
	for i in range(1, p.size()):
		t += p[i].distance_to(p[i - 1])
	return t

func _reaches(p: PackedVector3Array, to: Vector3, tol := 2.5) -> bool:
	return p.size() > 1 and p[p.size() - 1].distance_to(to) < tol

func _rest(id: String) -> void:
	var hearth := Game.find_hearth(id)
	player.global_position = hearth.respawn_point()
	await ticks(4)
	Game.hearth_flow(hearth, player)
	var w := 0
	while not StateDirector.transitioning and w < 300:
		w += 5
		await ticks(5)
	w = 0
	while StateDirector.transitioning and w < 1200:
		w += 10
		await ticks(10)

func _pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id and not p.is_queued_for_deletion():
			return p
	return null

func _plaques(layer: Node, head: String) -> Array:
	return layer.find_children("*", "LorePlaque", true, false).filter(func(p): return String(p.text).begins_with(head))

func _read(pl: LorePlaque) -> String:
	_panel = ""
	for z in pl.find_children("*", "Interactable", true, false):
		(z as Interactable).activate(player)
	return _panel

func _kits(id: String, layer: Node = null) -> Array:
	return (layer if layer != null else area).find_children("*", "Node3D", true, false).filter(
		func(n): return String(n.get_meta("kit_id", "")) == id)

func _gate(id: String) -> ShortcutGate:
	for g in area.find_children("*", "ShortcutGate", true, false):
		if (g as ShortcutGate).gate_id == id:
			return g
	return null

func _talk(npc_id: String) -> DialogueUI:
	var cfg := DB.npc(npc_id)
	cfg["id"] = npc_id
	var ui := DialogueUI.new(cfg, null)
	get_tree().root.add_child(ui)
	return ui

func _lines_of(thread_id: String) -> Array:
	for t in Keepsakes.journal():
		if t["id"] == thread_id:
			return t["lines"]
	return []

func _veg(kind: String, layer: Node = null) -> int:
	var n := 0
	for m in (layer if layer != null else area).find_children("Veg_%s_*" % kind, "MultiMeshInstance3D", true, false):
		n += (m as MultiMeshInstance3D).multimesh.instance_count
	return n

## Walk straight at a point for a while (no path: the test is what stops him).
func _push_at(to: Vector3, max_ticks := 260) -> void:
	var waited := 0
	while waited < max_ticks:
		var d := to - player.global_position
		d.y = 0
		if d.length() < 0.15:
			break
		player.cam.yaw = atan2(-d.x, -d.z)
		player.sim_move = Vector3(0, 0, -1)
		await ticks(2)
		waited += 2
	player.sim_move = Vector3.ZERO
	await ticks(2)

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("thornwold")
	add_child(area)
	Game.register_area(area, "thornwold")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	player.invulnerable = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("thornwold"))
	World.last_hearth = {"area": "thornwold", "hearth": "hs_colliers_clearing"}
	Game.lore_panel.connect(func(t): _panel = t)
	await ticks(20)

	print("== the region's own prop set (BIOMES.md)")
	var own := ["tw_clamp_a", "tw_clamp_b", "tw_clamp_c", "tw_cordwood", "tw_hurdle", "tw_stake_bundle", "tw_stile",
		"tw_charcoal_sacks", "tw_gatepost", "tw_collier_hut", "tw_shaving_horse", "tw_riddle_stand", "tw_sledge", "tw_hedging_tools",
		"tw_wood_shelter"]
	var placed := own.filter(func(k): return not _kits(k).is_empty())
	check(placed.size() == own.size(), "all fifteen of Thornwold's own pieces stand in the wood (%d)" % placed.size())
	var meshed := own.filter(func(k): return ResourceLoader.exists(String(KitLib.HERO_PIECES[k]["glb"])))
	check(meshed.size() == own.size(), "each has its model")
	check(_kits("tw_clamp_b", area.thaw_layer).size() + _kits("tw_clamp_b", area.base).size() == 4, "THAW: four clamps turfed and lit")
	check(_kits("tw_clamp_c", area.rime_layer).size() == 2, "RIME: the two that kept something are opened and raked out")
	var ranged := true
	for k in own:
		for n in _kits(k):
			for g in (n as Node3D).find_children("*", "GeometryInstance3D", true, false):
				if (g as GeometryInstance3D).visibility_range_end <= 0.0:
					ranged = false
	check(ranged, "every piece of the set drops out with distance")

	print("== every solid piece stops the Bearer at its own shape")
	# (the owner's playtest: a prop you can walk through, or one that stops
	# you a stride short of itself, is worse than no prop)
	var solid := {"tw_clamp_a": 1.2, "tw_clamp_b": 1.25, "tw_cordwood": 0.3, "tw_hurdle": 0.0, "tw_charcoal_sacks": 0.25,
		"tw_gatepost": 0.0, "tw_collier_hut": 1.2, "tw_shaving_horse": 0.1, "tw_riddle_stand": 0.3, "tw_sledge": 0.15,
		"tw_hedging_tools": 0.2, "tw_wood_shelter": 0.6}
	for k in solid:
		var inst := _kits(k).filter(func(n): return not (n as Node3D).find_children("*", "CollisionShape3D", true, false).is_empty())
		check(not inst.is_empty(), "%s has a collider" % k)
		if inst.is_empty():
			continue
		var prop: Node3D = inst[0]
		var c := prop.global_position
		var sz: Array = KitLib.PIECES[k]["size"]
		var reach := maxf(float(sz[0]), float(sz[1])) * 0.5 + 1.6
		var closest := INF
		for a in [0.0, 90.0, 180.0, 270.0]:
			var from := c + Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * reach
			from.y = area.terrain.height_at(from.x, from.z) + 0.3
			player.global_position = from
			player.velocity = Vector3.ZERO
			await ticks(6)
			if Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length() > 0.6:
				continue      # (something else stands there: not this prop's side to test)
			await _push_at(c)
			var d := Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length()
			closest = minf(closest, d)
		check(closest > float(solid[k]), "%s cannot be walked into (stopped %.2f m from its middle)" % [k, closest])
		# (from its clearest side: the others may have a neighbour in the way)
		check(closest < maxf(float(sz[0]), float(sz[1])) * 0.5 + 0.75,
			"%s stops him at itself, not short of it (%.2f m)" % [k, closest])
	player.global_position = AreaBuilder._v3(def["start"]["pos"]) + Vector3(0, 0.3, 0)
	await ticks(6)

	print("== the region's own plants (BIOMES.md, data/veg/thornwold.json)")
	check(_veg("grass") == 0 and _veg("sward") == 0 and _veg("heather") == 0, "no grass cards under the canopy, and no heather")
	check(_veg("bracken") > 200 and _veg("bilberry") > 200, "bracken and bilberry on the needle floor (%d, %d)" % [_veg("bracken"), _veg("bilberry")])
	check(_veg("moss_cushion", area.thaw_layer) > 40 and _veg("hazel_stool", area.thaw_layer) > 10 and _veg("birch_sapling", area.thaw_layer) > 10,
		"moss cushions, hazel stools and birch saplings (%d, %d, %d)" % [_veg("moss_cushion", area.thaw_layer),
		_veg("hazel_stool", area.thaw_layer), _veg("birch_sapling", area.thaw_layer)])
	check(_veg("moss_cushion", area.rime_layer) > 0 and _veg("moss_cushion", area.rime_layer) < _veg("moss_cushion", area.thaw_layer),
		"RIME keeps some of the cushions, sunk in the snow")
	check(_veg("hazel_stool", area.rime_layer) == _veg("hazel_stool", area.thaw_layer), "and every stool, bare")

	print("== 6.1 the Notch")
	var thaw_board := _plaques(area.thaw_layer, "THE NOTCH")
	var rime_board := _plaques(area.rime_layer, "THE NOTCH")
	check(thaw_board.size() == 1 and rime_board.size() == 1, "one board, a caption for each state")
	if thaw_board.size() == 1 and rime_board.size() == 1:
		check((thaw_board[0] as Node3D).global_position.distance_to((rime_board[0] as Node3D).global_position) < 0.1, "both on the same board")
		player.global_position = (thaw_board[0] as Node3D).global_position + Vector3(0.8, 0.3, -0.8)
		await ticks(6)
		check(_read(thaw_board[0]) == "THE NOTCH\n\nFour clamps are lit. Blue smoke means burning and white means cooking.\nAll four are white.",
			"THAW: it counts the clamps")
	var bay := Vector3(306.5, area.terrain.height_at(306.5, -316.0), -316.0)
	check(_reaches(_path(AreaBuilder._v3(def["start"]["pos"]), bay), bay), "the bay is reached from the road")
	check(_kits("tw_hurdle").size() >= 3, "a hurdle rail at its edge")
	var most := 0
	for k in own:
		most = maxi(most, _kits(k, area.thaw_layer).size() + _kits(k, area.base).size())
	check(most <= 5, "no piece of the set is repeated more than five times (%d)" % most)
	var bay_trees := 0
	for m in area.find_children("Forest_tree_*", "MultiMeshInstance3D", true, false):
		var mm := (m as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var o: Vector3 = (m as Node3D).global_transform * mm.get_instance_transform(i).origin
			if Vector2(o.x - bay.x, o.z - bay.z).length() < 4.0:
				bay_trees += 1
	check(bay_trees == 0, "no tree stands in the bay")

	print("== 6.2 Linnet's hut (THAW)")
	var hut := _kits("tw_collier_hut")
	check(hut.size() == 1 and _kits("tw_hut_thaw", area.thaw_layer).size() == 1 and _kits("tw_hut_rime", area.rime_layer).size() == 1,
		"the hut, with its inside made up in THAW and left as it was in RIME")
	var ends := _pickup("wool_ends")
	check(ends != null and ends.get_parent() == area.rime_layer or (ends != null and area.rime_layer.is_ancestor_of(ends)),
		"the ends of wool lie there in RIME only")

	print("== 6.3 the Field They Haven't Got (THAW)")
	check(_kits("tw_gatepost").size() == 4, "a pair of gateposts in the east side and a pair in the west")
	var field := Vector3(372.0, area.terrain.height_at(372.0, -302.0), -302.0)
	var clearing := Game.find_hearth("hs_colliers_clearing").respawn_point()
	var to_field := _path(clearing, field)
	check(_reaches(to_field, field), "the field is reached from the clearing")
	var east_out := Vector3(382.5, area.terrain.height_at(382.5, -302.0), -302.0)
	check(_len(_path(field, east_out)) < 14.0, "and there is no gate in the east gateway: walk through")

	print("== 6.4 the Layer's Stiles (THAW): nobody needs them")
	check(_kits("tw_stile").size() == 2, "two plank stiles on one bearing")
	var out3 := _ring(R3 + 3.0, STILE_A)
	var mid := _ring((R2 + R3) * 0.5, STILE_A)
	var in2 := _ring((R1 + R2) * 0.5, STILE_A)
	check(_len(_path(out3, mid)) < 9.0 and _len(_path(mid, in2)) < 10.0, "each is a way through its ring")
	check(_gate("stile_outer") != null and area.rime_layer.is_ancestor_of(_gate("stile_outer")), "the thorn over them is RIME's")

	print("== RIME")
	await _rest("hs_colliers_clearing")
	check(World.get_area_state("thornwold") == RH.WState.RIME, "Thornwold is rime")
	await ticks(30)
	if rime_board.size() == 1:
		check(_read(rime_board[0]) == "THE NOTCH\n\nThree rings of hedge round one pine.\nA hedge keeps stock in. There is no stock in there.",
			"the Notch's board reads the rings now")

	print("== 6.2 the ends she cut off")
	ends = _pickup("wool_ends")
	check(ends != null and ends.is_visible_in_tree(), "the ends lie in the swept corner by the door")
	if ends != null:
		var hut_at: Vector3 = (hut[0] as Node3D).global_position
		check(Vector2(ends.global_position.x - hut_at.x, ends.global_position.z - hut_at.z).length() < 2.4, "inside the door")
		var stand := ends.global_position + (ends.global_position - hut_at).normalized() * 1.1
		check(_reaches(_path(clearing, stand), stand, 1.6), "and can be reached from the clearing")
		player.global_position = stand + Vector3(0, 0.3, 0)
		await ticks(8)
		check(ends._zone.prompt == "Gather the ends", "the prompt: Gather the ends")
		ends._zone.activate(player)
		await ticks(4)
		check(int(player.inventory.get("item_wool_ends", 0)) == 1 and World.flag("ks_wool_ends_found"), "the Bearer gathers them")
	check(String(DB.item("item_wool_ends").get("name", "")) == "Ends of Wool", "Ends of Wool, in the items")

	print("== 6.3 the field in RIME: thorn on three sides, a stag, a collier, a latch")
	var foes := {}
	for sp in area.rime_layer.find_children("*", "Spawner", true, false):
		foes[String((sp as Spawner).spawn_flag)] = (sp as Spawner).global_position
	check(foes.has("slain_stag_field") and Vector2(foes["slain_stag_field"].x - 372.0, foes["slain_stag_field"].z + 302.0).length() < 6.0,
		"a Rime-stag stands inside the square")
	check(foes.has("slain_collier_road") and absf(foes["slain_collier_road"].z + 310.2) < 1.5 and absf(foes["slain_collier_road"].x - 372.0) < 4.0,
		"the Collier stands in its open side")
	var open_side := Vector3(372.0, area.terrain.height_at(372.0, -311.5), -311.5)
	check(_len(_path(open_side, field)) < 13.0, "the fourth side is still open")
	var behind := Vector3(372.0, area.terrain.height_at(372.0, -291.5), -291.5)
	check(_len(_path(field, behind)) > 18.0, "the far side is a wall of thorn")
	var latch := _pickup("gate_latch")
	check(latch != null and latch.display_lift > 1.2, "the latch is on top of the east post")
	if latch != null:
		for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
			e.set_physics_process(false)      # (the stag and the collier are not this test)
		player.global_position = latch.global_position + Vector3(-0.6, 0.3, 0.0)
		await ticks(8)
		check(latch._zone.prompt == "Take the latch", "the prompt: Take the latch")
		latch._zone.activate(player)
		await ticks(4)
		check(int(player.inventory.get("item_gate_latch", 0)) == 1 and World.flag("ks_gate_latch_found"), "the Bearer takes it")

	print("== 6.4 the stiles in RIME: grown over, broken off from inside")
	var hearth := Game.find_hearth("hs_outer_ring").respawn_point()
	var veil_mouth := _ring(R1 + 2.5, 180.0)
	var long_way := _len(_path(hearth, veil_mouth))
	check(_len(_path(out3, mid)) > 30.0, "the outer stile is shut: the way in is the gap")
	check(long_way > 90.0, "from the Outer Ring hearth to the veil is the long way round (%.0f m)" % long_way)
	for step in [["stile_outer", out3, mid], ["stile_inner", mid, in2]]:
		var g := _gate(String(step[0]))
		check(g != null, "%s stands" % step[0])
		if g == null:
			continue
		check(g._front.prompt == "Grown over" and g._back.prompt == "Break the thorn off the stile", "its two prompts")
		check(g.find_children("gate_leaf_*", "Node3D", true, false).is_empty(), "no door leaves: the thorn is the bar")
		var outside: Vector3 = step[1]
		var inside: Vector3 = step[2]
		check(g.to_local(outside).z > 0.0 and g.to_local(inside).z < 0.0, "barred face outward, the breaking side toward the pine")
		player.global_position = g.global_position + g.global_transform.basis.z * 1.3 + Vector3(0, 0.3, 0)
		await ticks(6)
		g._front.activate(player)
		await ticks(2)
		check(not World.area_flag("thornwold", "gate_" + String(step[0])), "from outside it only says so")
		player.global_position = g.global_position - g.global_transform.basis.z * 1.3 + Vector3(0, 0.3, 0)
		await ticks(6)
		g._back.activate(player)
		await ticks(90)
		check(World.area_flag("thornwold", "gate_" + String(step[0])), "from inside the thorn breaks off")
		var dressing := g.get_children().filter(func(c): return c.has_meta("gate_dressing"))
		check(dressing.size() == 1 and not (dressing[0] as Node3D).visible, "and is gone from the stile")
		check(_len(_path(outside, inside)) < 10.0, "the stile is a way through now")
	var short_way := _len(_path(hearth, veil_mouth))
	check(short_way < long_way * 0.5 and short_way < 60.0, "both open: hearth to veil by two stiles (%.0f m, was %.0f)" % [short_way, long_way])
	var hedge_board := _plaques(area.rime_layer, "THE HEDGE")
	check(hedge_board.size() == 1, "a board at the outer stile, inside")
	if hedge_board.size() == 1:
		var hb: Node3D = hedge_board[0]
		var rr := Vector2(hb.global_position.x - GRAVE.x, hb.global_position.z - GRAVE.y).length()
		check(rr < R3 and rr > R2, "between the outer and the middle ring")
		check(_read(hedge_board[0]) == "THE HEDGE\n\nThere is a stile in every ring, built the proper way.\nThen he let the thorn grow over them.",
			"it reads as planned")

	print("== the thread: Linnet's song-cord")
	World.set_flag("met_linnet")             # (they have met: this is not her first word to him)
	World.set_flag("ks_linnet_met")
	var before := _lines_of("song_cord").size()
	var ui := _talk("linnet")
	await ticks(2)
	check(World.flag("ks_gate_latch") and _lines_of("song_cord").size() == before + 1, "Linnet, shown the latch: a step is remembered")
	var said := []
	for i in 8:
		if ui._phase != "lines":
			break
		said.append(ui.text_label.text)
		ui.advance()
	check(said.has("He's made that for both. Look at it. It won't fit either."), "her line about it (%s)" % str(said))
	ui.close()
	ui = _talk("lusse")
	await ticks(2)
	check(not World.flag("ks_wool_ends"), "Lusse does not count the ends before she has read the cord")
	ui.close()
	World.set_flag("ks_song_cord_read")
	ui = _talk("lusse")
	await ticks(2)
	check(World.flag("ks_wool_ends"), "after it she does")
	said = []
	for i in 8:
		if ui._phase != "lines":
			break
		said.append(ui.text_label.text)
		ui.advance()
	check(said.has("She's cut and started again, look. Six times. Seven. It's hard, saying it about yourself."), "her line (%s)" % str(said))
	ui.close()
	check(int(player.inventory.get("item_wool_ends", 0)) == 1 and int(player.inventory.get("item_gate_latch", 0)) == 1, "both are kept")
	finish()
