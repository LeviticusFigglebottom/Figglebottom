extends TestBase
## The Journal and the Map (ADR 0014): objectives advance with the flags,
## optional steps wait for their item, finished threads move to Done, the
## pin drives the HUD tracker and the Map's objective mark, discovery is
## marked as the Bearer walks (regions, Hearthstones, the frost veil,
## places), markers come from the save, and all of it survives a save, a
## load and the migration of an older save.

var area: Area
var player: Player
var hud: HUD

func _ready() -> void:
	_run.call_deferred()

func _thread(id: String) -> Dictionary:
	return Journal.view_of(Journal.thread_def(id))

func _markers(kind: String, only := "") -> Array:
	return MapState.markers(only).filter(func(m): return m["kind"] == kind)

func _stand(at: Vector2) -> void:
	player.global_position = Vector3(at.x, player.global_position.y, at.y)
	MapState.scout(Game.current_area_id, player.global_position)

func _board(a: String, place_name: String) -> Dictionary:
	for pl in MapState.places_def(a):
		if pl["zone"] == null and pl["name"] == place_name:
			return pl
	return {}

func _run() -> void:
	World._save_dir = "user://test_journal_map"
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	hud = HUD.new()
	add_child(hud)
	await ticks(10)

	print("== the data")
	var ok_steps := true
	var all: Array = Keepsakes.threads_def().duplicate()
	all.append(Journal.main_def())
	for t in all:
		ok_steps = ok_steps and String(t.get("title", "")) != ""
		for s in (t.get("steps", []) as Array) + (t.get("optional", []) as Array):
			ok_steps = ok_steps and String(s.get("objective", "")) != "" and String(s.get("line", "")) != "" \
				and (s.has("flag") or s.has("area_flag"))
			# an objective names a place the data can find
			if s.has("at") and s["at"] is String:
				ok_steps = ok_steps and Journal.resolve_at(String(s.get("area", t.get("area", ""))), s["at"]) != null
	check(ok_steps, "every thread has a title; every step a flag, an objective, a line, and a place that resolves")
	check(Journal.main_def().get("title", "") == "The Outsong" and (Journal.main_def()["steps"] as Array).size() == 9,
		"the journey is its own thread: The Outsong, one step a region and the choice")
	check(not Journal.thread_def("smudge").is_empty() and not Journal.thread_def("melt_flowers").is_empty(),
		"the POI threads are written and waiting for their flags")

	print("== objectives advance with flags")
	var v := Journal.view()
	check((v["active"] as Array).is_empty() and (v["done"] as Array).is_empty(), "a new journey has no side threads")
	check(String(v["main"]["objective"]).begins_with("Rest at a Hearthstone."), "the journey opens with the first rest")
	World.set_flag("ks_ingra_met")
	var t := _thread("ingra_rye")
	check(t["started"] and not t["complete"] and String(t["objective"]).begins_with("Find Ingra's missing sack of rye."),
		"meeting Ingra: the objective is to find the rye")
	check(String(t["objective"]).contains("byre") and String(t["objective"]).contains("RIME"), "it says where, and in which state")
	check(t["done"] == ["Met Ingra, the steward, in Saltfell yard. She is a sack of rye short and blames a dog."], "the met step is listed as done")
	World.set_flag("ks_ingra_rye_found")
	t = _thread("ingra_rye")
	check(String(t["objective"]).begins_with("Take the rye sack back to Ingra") and (t["done"] as Array).size() == 2, "finding it moves the objective on")
	check((t["extras"] as Array).is_empty(), "an optional step is silent until its item is carried")
	player.inventory["item_three_bowls"] = 1
	t = _thread("ingra_rye")
	check(t["extras"] == ["Show Ingra the three bowls from the Lookout Stone, in THAW."], "carrying the bowls offers the optional step")
	World.set_flag("ks_ingra_bowls")
	World.set_flag("ks_ingra_rye")
	t = _thread("ingra_rye")
	check((t["extras"] as Array).is_empty() and (t["done"] as Array).size() == 4 and String(t["done"][3]).begins_with("Showed Ingra the three bowls"),
		"done, the optional step is one more plain line, after the step it follows")
	check(not t["complete"], "an optional step never finishes a thread")
	World.set_flag("ks_ingra_count")
	t = _thread("ingra_rye")
	check(t["complete"] and String(t["objective"]) == "", "the last flag finishes the thread")
	v = Journal.view()
	check((v["done"] as Array).map(func(x): return x["id"]) == ["ingra_rye"] and (v["active"] as Array).is_empty(), "a finished thread moves to Done")
	check(Keepsakes.journal()[0]["lines"] == _thread("ingra_rye")["done"].filter(func(l): return not String(l).begins_with("Showed Ingra the three")),
		"Keepsakes.journal() still reads the same steps")
	# an objective that changes with what is carried
	World.set_flag("ks_linnet_met")
	check(String(_thread("song_cord")["objective"]).begins_with("Search the ash"), "Linnet's ring: first, search")
	player.inventory["item_birch_ring"] = 1
	check(String(_thread("song_cord")["objective"]).begins_with("Take the ring of plaited birch to Linnet"), "then, carrying it, take it to her")
	# the journey: sequential, by region
	World.set_area_flag("saltfell_steading", "lit_hs_boat_shed")
	check(String(Journal.view()["main"]["objective"]).begins_with("Release the Holdfast of Saltfell."), "after the first rest: release Saltfell's Holdfast")
	World.set_flag("ks_netmender_released")
	var mv: Dictionary = Journal.view()["main"]
	check(String(mv["objective"]).begins_with("Go up the water to the Lowe.") and mv["area"] == "lowe_barrows" and (mv["done"] as Array).size() == 2,
		"released: the next region's goal, and where to go")
	World.flags.erase("ks_netmender_released")
	World.set_flag("ks_turfwright_released")
	check((Journal.view()["main"]["done"] as Array).size() == 3, "the journey only goes one way: a later release implies the earlier")
	World.flags.erase("ks_turfwright_released")

	print("== the pinned tracker")
	check(Journal.pin_id() == "outsong" and Journal.tracker_on(), "a new journey pins the Outsong, tracker on")
	hud.refresh_tracker()
	check(hud._tracker_box.visible and hud._tracker_title.text == "The Outsong"
		and hud._tracker_text.text == "Release the Holdfast of Saltfell.", "the HUD shows the pinned thread and its objective's first sentence")
	World.set_flag("ks_brede_met")
	Journal.set_pin("brede_float")
	hud.refresh_tracker()
	check(hud._tracker_title.text == "Brede's lost net-float" and hud._tracker_text.text == "Find Brede's cork net-float.", "pinning another thread changes the line")
	World.set_flag("ks_brede_float_found")
	hud.refresh_tracker()
	check(hud._tracker_text.text.begins_with("Take the float back to Brede"), "and it follows the thread's flags")
	Journal.set_tracker(false)
	hud.refresh_tracker()
	check(not hud._tracker_box.visible and Journal.tracker().is_empty(), "the tracker can be switched off")
	Journal.set_tracker(true)
	Journal.set_pin("ingra_rye")
	check(Journal.pinned()["id"] == "outsong", "a finished thread hands the pin back to the journey")
	# the leaf: pin by Enter, switch by the first row
	Journal.set_pin("outsong")
	InventoryUI.open_for(player, "journal")
	await ticks(3)
	var inv: InventoryUI = get_tree().get_first_node_in_group("inventory_ui")
	check(inv != null and inv._tab == "journal", "the Journal leaf opens")
	if inv != null:
		var kinds: Array = inv._rows.map(func(r): return "%s:%s" % [r["kind"], r["id"]])
		check(kinds.slice(0, 2) == ["tracker:tracker", "thread:outsong"] and kinds.has("thread:brede_float") and kinds.has("done:ingra_rye"),
			"rows: the switch, the journey, threads in hand, then Done (%s)" % str(kinds))
		inv._sel = kinds.find("thread:brede_float")
		inv._act_selected()
		check(Journal.pin_id() == "brede_float", "Enter on a thread pins it")
		inv._sel = 0
		inv._act_selected()
		check(not Journal.tracker_on(), "Enter on the first row switches the HUD line")
		Journal.set_tracker(true)
		var texts: Array = inv._list.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
		check(texts.has("Current objective") and texts.has("Done") and not texts.has(_thread("ingra_rye")["done"][0]),
			"objectives are labelled; a finished thread is folded")
		inv.close()
	await ticks(3)

	print("== map discovery")
	World.map = {"regions": {}, "hearths": {}, "veils": {}, "places": {}}
	World.areas.clear()        # no Hearthstone rested at yet
	var meta := MapState.meta()
	check(MapState.regions().size() == 7 and meta["regions"].size() == 7, "the map is baked for all seven regions")
	var baked := true
	for r in MapState.regions():
		baked = baked and ResourceLoader.exists(String(MapState.region(r)["image"]))
		var rd: Dictionary = DB.area_def(r)["terrain"]
		baked = baked and MapState.region(r)["origin"] == rd["origin"]
	check(baked and ResourceLoader.exists(String(meta["world"]["image"])), "every sheet is on disk and sits at its terrain's origin")
	check(not MapState.region_seen("saltfell_steading") and MapState.markers().filter(func(m): return m["kind"] != "bearer" and m["kind"] != "pin").is_empty(),
		"nothing is on the map before it is walked")
	var start := Vector2(player.global_position.x, player.global_position.z)
	_stand(start)
	check(MapState.region_seen("saltfell_steading") and not MapState.region_seen("lowe_barrows"), "walking in a region discovers it, and only it")
	check(_markers("place").any(func(m): return m["name"] == "The Strand"), "the zone walked into is a found place")
	check(_markers("hearth").is_empty(), "a Hearthstone out of sight is not marked")
	_stand(Vector2(23.0, 50.0))
	var hs := _markers("hearth")
	check(hs.size() == 1 and hs[0]["id"] == "hs_boat_shed" and not hs[0]["rested"] and not hs[0]["last"], "come upon: marked, not yet rested at")
	World.map["hearths"].clear()
	World.areas.clear()
	World.last_hearth = {"area": "saltfell_steading", "hearth": "hs_boat_shed"}
	World.set_area_flag("saltfell_steading", "lit_hs_boat_shed")
	hs = _markers("hearth")
	check(hs.size() == 1 and hs[0]["rested"] and hs[0]["last"], "rested at: marked as rested, and as the last rest")
	World.set_area_flag("saltfell_steading", "lit_hs_salt_house")
	World.last_hearth = {"area": "saltfell_steading", "hearth": "hs_salt_house"}
	hs = _markers("hearth")
	check(hs.size() == 2 and hs.filter(func(m): return m["last"]).map(func(m): return m["id"]) == ["hs_salt_house"], "only the last-rested Hearthstone is picked out")
	check(not hs.any(func(m): return m["id"] == "hs_long_hearth"), "a Hearthstone that wakes on release is not there before it")
	# the Bearer
	player.vis.rotation.y = 0.75
	var me := _markers("bearer")
	check(me.size() == 1 and (me[0]["pos"] as Vector2).is_equal_approx(Vector2(23.0, 50.0)) and is_equal_approx(me[0]["yaw"], 0.75),
		"the Bearer's mark: where they stand, and their facing")
	# the frost veil: seen only in RIME, near
	var veil_at := Vector2(0.0, -14.0)
	_stand(veil_at)
	check(_markers("veil").is_empty(), "in THAW there is no veil to see")
	World.set_area_state("saltfell_steading", RH.WState.RIME)
	_stand(veil_at)
	var vs := _markers("veil")
	check(vs.size() == 1 and not vs[0]["released"] and (vs[0]["pos"] as Vector2).is_equal_approx(Vector2(0.0, -20.0)), "in RIME, near it: the unreleased Holdfast's veil is marked")
	World.set_cleared("saltfell_steading")
	World.set_flag("ks_netmender_released")
	check(_markers("veil")[0]["released"], "released: the mark says so")
	check(_markers("hearth").any(func(m): return m["id"] == "hs_long_hearth") == MapState.hearth_seen("saltfell_steading", "hs_long_hearth"),
		"the Long Hearth is marked only once come upon")
	# seams
	var seams := _markers("seam")
	check(seams.size() == 2 and seams.all(func(m): return m["to"] == "lowe_barrows" and not m["known"])
		and seams.map(func(m): return m["label"]) == ["the cliff-top pass", "the drawbridge"], "both ways to the Lowe are marked, named, their far end unwalked")
	MapState.scout("lowe_barrows", Vector3(-89, 24, -95))
	check(_markers("seam", "saltfell_steading").all(func(m): return m["known"]) and MapState.region_seen("lowe_barrows"), "walked through: the far end is known")
	check(_markers("seam", "lowe_barrows").size() == 3, "the Lowe shows its own ways on")
	# wayside boards: a place is found at a board that stands in the state walked in
	var graves := _board("saltfell_steading", "The Cliff Graves")
	var mound := _board("lowe_barrows", "The Last Mound")
	check(not graves.is_empty() and (graves["tags"] as Array).has("thaw") and (graves["tags"] as Array).has("rime"),
		"a board with a THAW text and a RIME text is one place")
	check(not mound.is_empty() and mound["tags"] == ["rime"], "the Last Mound's board stands only in RIME")
	if not graves.is_empty() and not mound.is_empty():
		var mound_at := Vector3(mound["pos"].x, 0.0, mound["pos"].y)
		World.set_area_state("lowe_barrows", RH.WState.THAW)
		MapState.scout("lowe_barrows", mound_at)
		check(not MapState.place_seen("lowe_barrows", mound["id"]), "in THAW its board is not there to find")
		World.set_area_state("lowe_barrows", RH.WState.RIME)
		MapState.scout("lowe_barrows", mound_at)
		check(MapState.place_seen("lowe_barrows", mound["id"]), "in RIME, come up to: the place is found")
		World.set_area_state("lowe_barrows", RH.WState.THAW)
		check(_markers("place", "lowe_barrows").any(func(m): return m["name"] == "The Last Mound"), "a found place stays on the map when the world turns")
		MapState.scout("saltfell_steading", Vector3(graves["pos"].x, 0.0, graves["pos"].y))
		check(MapState.place_seen("saltfell_steading", graves["id"]), "a board with a text for each state is found in either")
	# the pinned objective's place
	World.flags.erase("ks_ingra_rye_found"); World.flags.erase("ks_ingra_rye"); World.flags.erase("ks_ingra_count")
	Journal.set_pin("ingra_rye")
	var pins := _markers("pin")
	check(pins.size() == 1 and (pins[0]["pos"] as Vector2).is_equal_approx(Vector2(-27, -14)) and pins[0]["title"] == "Ingra's missing rye",
		"the pinned objective is marked where Ingra said to look")
	Journal.set_pin("brede_float")
	World.flags.erase("ks_brede_float_found")
	check(_markers("pin").is_empty() and Journal.pin_place()["area"] == "saltfell_steading", "an objective with no known place has a region and no mark")
	# the view
	InventoryUI.open_for(player, "map")
	await ticks(3)
	inv = get_tree().get_first_node_in_group("inventory_ui")
	var view: MapView = inv.get_meta("map_view", null) if inv != null else null
	check(view != null and view.mode == "overview" and view.seen_regions() == ["saltfell_steading", "lowe_barrows"], "the Map leaf opens on the highland, two regions walked")
	if view != null:
		view.show_region("coldwell")
		check(view.mode == "overview", "a region not walked cannot be opened")
		view.toggle()
		check(view.mode == "region" and view.area == "saltfell_steading", "Enter goes into the region the Bearer is in")
		var at := view.to_view(Vector2(23.0, 55.5))
		check(Rect2(Vector2.ZERO, view.size).has_point(at) and view._world_at(at).is_equal_approx(Vector2(23.0, 55.5)), "world and sheet agree")
		view.step(1)
		check(view.area == "lowe_barrows", "W/S steps to the next walked region")
		view.toggle()
		check(view.mode == "overview" and view.region_at(view.to_view(Vector2(0.0, 60.0))) == "saltfell_steading", "and back; a click on a region finds it")
		inv.close()
	await ticks(3)

	print("== save, load, migrate")
	Journal.set_pin("brede_float")
	Journal.set_tracker(false)
	var map_before := World.map.duplicate(true)
	World.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.open(World.save_path(), FileAccess.READ).get_as_text())
	check(int(saved["save_version"]) == World.SAVE_VERSION and World.SAVE_VERSION == 4 and saved.has("map") and saved.has("journal"), "saves are version 4 and carry the map and the journal")
	World.reset()
	check(World.map["regions"].is_empty() and Journal.pin_id() == "outsong" and Journal.tracker_on(), "a reset world has seen nothing")
	check(World.load_game(), "the save loads")
	check(World.map == map_before and Journal.pin_id() == "brede_float" and not Journal.tracker_on(), "discovery, the pin and the switch come back")
	check(MapState.region_seen("lowe_barrows") and _markers("veil", "saltfell_steading").size() == 1, "and so do the markers")
	# a version-3 save: no map, no journal
	var v3 := saved.duplicate(true)
	v3["save_version"] = 3
	v3.erase("map")
	v3.erase("journal")
	v3["areas"] = {
		"saltfell_steading": {"state": 1, "cleared": true, "flags": {"lit_hs_boat_shed": true, "took_rye_sack": true}},
		"lowe_barrows": {"state": 0, "cleared": false, "flags": {"lit_hs_barrow_road": true}},
		"coldwell": {"state": 0, "cleared": false, "flags": {}},
	}
	v3["last_hearth"] = {"area": "lowe_barrows", "hearth": "hs_barrow_road"}
	var up := World.migrate(v3.duplicate(true))
	check(int(up["save_version"]) == 4 and up["journal"] == {"pin": "outsong", "tracker": true}, "v3 becomes v4: the Outsong pinned, tracker on")
	check(up["map"]["regions"].keys() == ["saltfell_steading", "lowe_barrows"], "regions it had entered are discovered; an untouched one is not")
	check(up["map"]["hearths"].has("saltfell_steading/hs_boat_shed") and up["map"]["hearths"].has("lowe_barrows/hs_barrow_road")
		and up["map"]["veils"] == {"saltfell_steading": true}, "Hearthstones rested at and a released Holdfast's veil are marked")
	check(World.migrate(up.duplicate(true)) == up, "migrating a current save changes nothing")
	var f := FileAccess.open(World.save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(v3))
	f.close()
	World.reset()
	check(World.load_game() and MapState.region_seen("lowe_barrows") and not MapState.region_seen("coldwell")
		and _markers("hearth", "lowe_barrows").size() == 1 and _markers("hearth", "lowe_barrows")[0]["last"], "the old save loads with its map rebuilt")

	DirAccess.remove_absolute(World.save_path())
	finish()
