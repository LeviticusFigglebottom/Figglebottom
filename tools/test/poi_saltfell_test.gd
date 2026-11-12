extends PoiBase
## Saltfell's points of interest (docs/lore/POI.md 2): the Drag-Mark, the
## Salt House, the Cliff Graves and the Lookout Stone. Each is walked to on
## the navmesh and used: the pickup can be taken, the plaque reads, the
## overheard exchange plays in order, the thread step sets.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await setup("saltfell_steading")
	var def: Dictionary = area.get_meta("def")
	var strand := ground(-4, 62)
	var yard := ground(-10, 10)

	print("== THAW: what stands there")
	check(prop("sf_roller_run") != null and prop("boat", "thaw") != null, "Brede's boat on its rollers, a second run beside it")
	check(area.find_children("*", "DragFurrow", true, false).size() == 1
		and not (area.find_children("*", "DragFurrow", true, false)[0] as Node3D).is_visible_in_tree(), "no furrow in THAW")
	check(prop("salt_pan", "thaw") != null and prop("sf_salt_pan_split") == null, "the pan by the salt house is whole")
	check(prop("sf_small_grave") != null and prop("sf_small_grave_open") == null and prop("lw_sod_row") == null,
		"the small grave is closed, thrift on it")
	check(prop("sf_lookout_stone") != null and prop("sf_needle_case") != null, "a net-needle case on the Lookout Stone")
	check(pickup("thole_pin") == null and pickup("pan_salt") == null and pickup("three_bowls") == null, "nothing to pick up yet")
	for kit in ["sf_capstan", "sf_salt_basket", "sf_gutting_bench", "sf_tar_pot", "sf_brine_trough", "sf_oar_rack", "sf_net_sinkers", "sf_kelp_rick"]:
		check(prop(kit) != null and prop(kit).find_children("*", "MeshInstance3D", true, false).size() > 0, "%s is out, modelled" % kit)
	check(reaches(strand, yard), "the cliff path still joins the Strand and the yard")

	print("== the Salt House, THAW: two voices inside")
	var boilers := npc("salt_boilers")
	check(boilers != null and boilers.find_children("*", "CollisionObject3D", true, false).is_empty()
		and boilers.find_children("*", "Interactable", true, false).is_empty(), "the salt-boilers are voices: no body, no prompt")
	var house: Dictionary = (def["houses"] as Array).filter(func(h): return h["id"] == "salthouse")[0]
	await stand(ground(-26.0, 21.0))       # the Salt House hearth
	var door := ground(-33.6, 21.9)
	check(await walk_path(door), "from the hearth to the salt-house door")
	check(player.global_position.distance_to(boilers.global_position) < 7.0, "within 7 m of them at the door (%.1f)" % player.global_position.distance_to(boilers.global_position))
	var heard: Array = await overhear(boilers, 62.0)
	var want: Array = (DB.npc("salt_boilers")["overhear"] as Array).map(func(e): return String(e[1]))
	check(heard_in_order(heard, want), "the exchange is overheard, five lines in order (%d heard)" % heard.size())
	check(hud.overheard_label.text != "" and not hud.overheard_label.text.contains(": "), "shown with no name: nobody saw who said it")
	check(house["doors"].size() == 1 and reaches(door, yard), "the house has its door, and the yard is still open round it")
	check(not bool(def.get("wayside", true)) and area.find_children("*", "Node3D", true, false).filter(
		func(n): return String(n.get_meta("kit_id", "")) == "drying_rack").size() <= 9, "racks stand in rows, set by hand; nothing strewn")

	await stand(ground(10.0, -2.0))
	check((await talk("steward_ingra")).size() > 0 and World.flag("ks_ingra_met"), "Ingra is met")
	await stand(ground(-4.0, 66.0))
	check((await talk("brede")).size() > 0 and World.flag("ks_brede_met"), "Brede is met")

	print("== the Cliff Graves, THAW")
	var txt: String = await read(plaque("THE CLIFF GRAVES"))
	check(txt.contains("The thrift on it was picked today."), "the THAW plaque reads")

	print("== collision: the hero props are solid")
	for kit in ["sf_capstan", "sf_salt_basket", "sf_gutting_bench", "sf_tar_pot", "sf_brine_trough", "sf_oar_rack", "sf_net_sinkers",
			"sf_kelp_rick", "drying_rack", "boat", "boat_upturned", "sf_rack_tall", "sf_rack_low", "sf_net_pile", "sf_fish_barrels",
			"sf_salt_sacks", "sf_mooring_post", "sf_boat_half"]:
		check(await solid(prop(kit)), "%s stops the Bearer" % kit)
	# (a MultiMesh cannot be read back under the headless renderer: measure what it is built from)
	var logs := area.find_children("Scatter_driftwood*", "MultiMeshInstance3D", true, false)
	var rule: Dictionary = (def["scatter"]["rules"] as Array).filter(func(r): return r["kind"] == "driftwood")[0]
	var longest := 0.0
	var kinds := 0
	for hv in Scatter.HERO["driftwood"]:
		var m := Scatter._hero_mesh(String(hv[0]), String(hv[1]), 0)
		if m != null:
			kinds += 1
			longest = maxf(longest, m.get_aabb().size.x * float(hv[2]) * float(rule["scale"][1]))
	check(kinds >= 4 and logs.size() >= kinds and longest <= 2.5, "driftwood: %d kinds, none over 2.5 m (longest %.2f m)" % [kinds, longest])
	check(int(rule["count"]) <= 16 and float(rule["h"][1]) <= 1.6, "sparse, and only along the wrack line")

	print("== RIME")
	await turn(RH.WState.RIME)
	check(prop("boat", "thaw") == null and (area.find_children("*", "DragFurrow", true, false)[0] as Node3D).is_visible_in_tree(),
		"the boat is gone; one furrow goes up the beach")
	var fur := area.find_children("*", "DragFurrow", true, false)[0] as Node3D
	check(fur.find_children("*", "MeshInstance3D", true, false).size() == 2 and fur.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the furrow is a mark: drawn, not solid")
	await stand(strand)
	txt = await read(plaque("THE STRAND\n\nOne boat"))
	check(txt.contains("The rollers were lying beside it the whole way."), "the Drag-Mark plaque reads")
	check(await take("thole_pin"), "the thole pin is picked up out of the furrow")
	check(int(player.inventory.get("item_thole_pin", 0)) == 1, "Thole Pin in the Pack")
	check(reaches(player.global_position, yard), "the furrow blocks nothing: the cliff path is open from it")

	await stand(ground(-26.0, 21.0))
	check(prop("sf_salt_pan_split") != null and prop("salt_pan", "thaw") == null, "the pan has boiled dry and split")
	check(await take("pan_salt"), "the cake of salt is lifted out of the split pan")
	check(int(player.inventory.get("item_pan_salt", 0)) == 1, "Cake of Pan Salt in the Pack")

	await stand(ground(36.0, 10.0))
	check(prop("sf_small_grave_open") != null and prop("lw_sod_row") != null and prop("sf_turf_spade") != null,
		"the small grave is open, the turf laid to one side, the spade standing")
	txt = await read(plaque("THE CLIFF GRAVES"))
	check(txt.contains("in the order it came off."), "the RIME plaque reads, on the same board")
	check(pickup("knucklebones") != null and pickup("knucklebones").global_position.distance_to(prop("sf_small_grave_open").global_position) < 4.0,
		"the knucklebones still lie beside it")

	await stand(ground(-84.0, -4.0))
	check(prop("sf_needle_case") == null, "the needle case is not there in RIME")
	check(await take("three_bowls"), "the three bowls are taken off the Lookout Stone")
	check(int(player.inventory.get("item_three_bowls", 0)) == 1, "Three Bowls in the Pack")
	check(reaches(player.global_position, yard), "back from the headland to the yard")

	print("== THAW again: who they belonged to")
	await turn(RH.WState.THAW)
	await stand(ground(10.0, -2.0))
	var w0: int = Game.warmth
	var lines: Array = await talk("steward_ingra")
	check(World.flag("ks_ingra_bowls") and int(player.inventory.get("item_three_bowls", 0)) == 0, "Ingra takes her bowls: the thread step sets")
	check(lines.has("Three short. I knew I was three short. Put them on the end, I'll wash them."), "she says she knew (%s)" % str(lines.slice(0, 1)))
	check(journal("ingra_rye").has("Ingra was three bowls short. She had known she was three short."), "the journal has the line")
	check(World.flag("ingra_salt_shown") and Game.warmth - w0 == 60 and int(player.inventory.get("item_pan_salt", 0)) == 0,
		"the burnt salt is worth 60 warmth to her (%d)" % (Game.warmth - w0))
	check(lines.has("That's burnt. Who burns salt?"), "and asks who burns salt")
	lines = await talk("steward_ingra")
	check(not lines.has("Those are mine. Who's had those out on the head?"), "said once: she is back to her own talk")
	await stand(ground(-4.0, 66.0))
	lines = await talk("brede")
	check(lines.has("That's off mine. They don't come out. You'd have to pull her over sideways to get that out."), "Brede knows his thole pin (%s)" % str(lines.slice(0, 1)))
	check(int(player.inventory.get("item_thole_pin", 0)) == 1, "he does not take it")
	finish()
