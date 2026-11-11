extends TestBase
## Area streaming (ADR 0014, src/core/streamer.gd): a seam is crossed with no
## synchronous build on the main thread and no frame over the budget; the
## neighbour is ready before the Bearer arrives; what is made ready ahead is
## inert; the area left is freed; saves made meanwhile are right; a cold or
## corrupt cache only costs time; a rest and a death stay inside the budget.
##
## Timing asserts read BuildProf (main-thread milliseconds of streaming work
## per frame), never the frame rate: this runs headless on slow, shared
## boxes. The cache is a scratch directory, emptied first, so every run starts
## cold and nothing here reads another run's entries.

const SCRATCH := "user://test_streaming"

var root3d: Node3D
var player: Player
var hitch_ms := 30.0
var max_alive := 0

func _ready() -> void:
	_run.call_deferred()

func _process(_dt: float) -> void:
	if Game.stream != null:
		max_alive = maxi(max_alive, Game.stream.areas_alive())

func _until(cond: Callable, max_s := 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await ticks(2)
	return cond.call()

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c

func _under(area: Node, group: String) -> int:
	var k := 0
	for n in get_tree().get_nodes_in_group(group):
		if area.is_ancestor_of(n):
			k += 1
	return k

func _portal(to: String) -> AreaPortal:
	for n in get_tree().get_nodes_in_group("area_portals"):
		if (n as AreaPortal).to_area == to and Game.current_area.is_ancestor_of(n):
			return n
	return null

func _hearth_at(i: int) -> Vector3:
	var hs: Array = Game.current_area.get_meta("def")["hearths"]
	return AreaBuilder._v3(hs[i]["at"]) + Vector3(0.6, 0.5, 1.6)

func _settle_idle(max_s := 30.0) -> bool:
	return await _until(func(): return Game.stream.idle(), max_s)

## The crossing's own numbers hold the budget: no build phase ran unsliced
## on the main thread, and no frame carried more streaming work than
## streaming/hitch_ms (the single worst frame is allowed to be one the OS
## took from us; the next worst is not).
func _check_report(rep: Dictionary, what: String) -> void:
	print("    %s: worst frame %.1f ms of streaming work (next %.1f) over %d frames; longest frame %.0f ms; %s" % [what,
		float(rep.get("max_work_ms", 0.0)), float(rep.get("second_work_ms", 0.0)), int(rep.get("work_frames", 0)),
		float(rep.get("max_frame_ms", 0.0)), str(rep.get("sync", []))])
	print("      worst frame: %s" % str(rep.get("worst", {})))
	check((rep.get("sync", []) as Array).is_empty(), "%s: no synchronous build phase on the main thread" % what)
	check(float(rep.get("second_work_ms", 999.0)) <= hitch_ms,
		"%s: streaming work per frame within %.0f ms (%.1f)" % [what, hitch_ms, float(rep.get("second_work_ms", 0.0))])

func _cross_now(to: String, spawn: Vector3) -> bool:
	Game.travel_to(to, spawn)
	return await _until(func(): return Game.current_area_id == to and player.input_enabled and not Game.stream.crossing(), 180.0)

## Steered capsule along the navmesh to `to`, at walking pace; stops when
## `halt` holds. Returns the ticks walked.
func _walk(to: Vector3, halt: Callable, max_ticks := 3600) -> int:
	var map: RID = Game.current_area.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, player.global_position),
		NavigationServer3D.map_get_closest_point(map, to), true)
	path.append(to)
	var used := 0
	var stuck := 0
	var last := player.global_position
	for k in path.size():
		while used < max_ticks:
			if halt.call():
				player.sim_move = Vector3.ZERO
				return used
			var d := path[k] - player.global_position
			d.y = 0
			if d.length() < 0.8:
				break
			player.cam.yaw = atan2(-d.x, -d.z)
			player.sim_move = Vector3(0, 0, -1)
			await ticks(2)
			used += 2
			if player.global_position.distance_to(last) < 0.05:
				stuck += 2
				if stuck > 40:      # a kerb: round it
					player.sim_move = Vector3(1, 0, 0.3)
					await ticks(30)
					used += 30
					stuck = 0
			else:
				stuck = 0
			last = player.global_position
	player.sim_move = Vector3.ZERO
	return used

func _run() -> void:
	hitch_ms = float(DB.tuning("streaming/hitch_ms", 30.0))
	var cache_dir := SCRATCH + "/cache"
	StreamCache.use_dir(cache_dir)
	StreamCache.clear()
	World.reset()
	World._save_dir = SCRATCH + "/saves"
	World.delete_slot(World.active_slot)
	var st: Streamer = Game.stream
	st.look_ahead = false     # (the Long Hearth is within reach of the bridge seam)

	print("== the front door: a synchronous build, as before")
	root3d = Node3D.new()
	root3d.name = "World"
	add_child(root3d)
	Game.world_root = root3d
	var area := AreaBuilder.build("saltfell_steading")
	check(area != null and not area.has_meta("stream_late"), "AreaBuilder.build still builds whole and at once")
	root3d.add_child(area)
	Game.register_area(area, "saltfell_steading")
	StateDirector.snap(area, RH.WState.THAW)
	player = Player.new()
	player.name = "Player"
	root3d.add_child(player)
	player.sim_active = true
	player.global_position = _hearth_at(2)
	World.last_hearth = {"area": "saltfell_steading", "hearth": "hs_long_hearth"}
	await ticks(20)
	check(area.nav_thaw != null and area.nav_thaw.navigation_mesh.get_polygon_count() > 0, "its navmesh is baked on load")
	check(st.enabled() and st.idle(), "the streamer is idle")
	check(st.areas_alive() == 1, "one area stands")

	print("== a cold crossing (nothing made ready, empty cache)")
	var saltfell := Game.current_area
	var n_saltfell := _count(saltfell)
	var seam := _portal("lowe_barrows")
	check(seam != null and seam.auto, "the pass seam stands")
	var ok := await _cross_now("lowe_barrows", seam.spawn_pos)
	check(ok, "arrives in the Lowe")
	var rep: Dictionary = st.last_report
	check(not bool(rep.get("ready_at_call", true)), "it was not ready, and the black held (%.0f ms)" % float(rep.get("total_ms", 0.0)))
	_check_report(rep, "cold crossing")
	var lowe: Area = Game.current_area
	check(lowe != null and lowe.area_id == "lowe_barrows" and lowe.visible and not lowe.inert and lowe.is_in_group("nav_src"),
		"the Lowe is the live area")
	check(lowe.env != null and lowe.env.is_inside_tree() and EnvRig.active_instance == lowe.env, "its light rules")
	check(lowe.nav_thaw != null and lowe.nav_thaw.enabled and lowe.nav_thaw.navigation_mesh.get_polygon_count() > 100
		and lowe.nav_rime != null and not lowe.nav_rime.enabled and lowe.nav_rime.navigation_mesh.get_polygon_count() > 100,
		"both navmeshes stand, the live state's in the map")
	check(rep.get("nav_cache", []) == [false, false], "baked in the background (no cache yet)")
	check(player.global_position.distance_to(seam_spawn(lowe, "saltfell_steading", rep)) < 80.0 and player.is_inside_tree(), "the Bearer stands in it")
	await ticks(30)
	check(player.global_position.y > lowe.terrain.height_at(player.global_position.x, player.global_position.z) - 0.5,
		"on its ground (y %.1f)" % player.global_position.y)
	check(_under(lowe, "hearths") >= 2 and Game.find_hearth("hs_barrow_road") != null, "its hearths woke (%d)" % _under(lowe, "hearths"))
	check(Game.find_hearth("hs_long_hearth") == null, "the hearths of the area left cannot be found")
	check(_under(lowe, "area_portals") >= 3, "its seams stand")
	ok = await _settle_idle(60.0)
	check(ok and not is_instance_valid(saltfell), "the area left is freed (%d nodes)" % n_saltfell)
	check(st.areas_alive() == 1 and max_alive <= 2, "never more than two areas stood (max %d)" % max_alive)
	var n_lowe := _count(lowe)
	var n_all := _count(root3d)
	check(n_all - n_lowe < 400, "nothing of it is left in the tree (%d nodes beside the Lowe's %d)" % [n_all - n_lowe, n_lowe])
	var files := DirAccess.get_files_at(cache_dir)
	var kinds := {}
	for f in files:
		kinds[f.get_slice("_", 0)] = int(kinds.get(f.get_slice("_", 0), 0)) + 1
	check(int(kinds.get("veg", 0)) >= 2 and int(kinds.get("terrain", 0)) >= 2 and int(kinds.get("nav", 0)) >= 2,
		"ground cover, terrain and navmeshes are on disk (%s)" % str(kinds))

	print("== made ready ahead: inert until the crossing")
	st.look_ahead = true
	var kseam := _portal("kettle_fjord")
	check(kseam != null, "the Kettle Road seam stands")
	var map: RID = root3d.get_world_3d().navigation_map
	var back := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, kseam.global_position),
		NavigationServer3D.map_get_closest_point(map, _hearth_at(2)), true)
	var near := kseam.global_position
	for pt in back:
		near = pt
		if Streamer.portal_distance(kseam, pt) > 25.0:
			break
	player.global_position = near + Vector3.UP * 0.6     # on the road, some 25 m short of the seam
	ok = await _until(func(): return st.pending_id() == "kettle_fjord", 10.0)
	check(ok, "30 m from the seam the Kettle starts being made ready")
	# a save while the neighbour is still being built
	World.last_hearth = {"area": "lowe_barrows", "hearth": "hs_barrow_road"}
	var pos_then := player.global_position
	World.save_game()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(World.save_path()))
	check(saved is Dictionary and saved["last_hearth"]["area"] == "lowe_barrows" and saved["meta"]["area"] == "lowe_barrows",
		"a save made mid-preload keeps the current area's hearth")
	var sp: Array = saved["player"]["pos"] if saved is Dictionary else [0, 0, 0]
	check(Vector3(sp[0], sp[1], sp[2]).distance_to(pos_then) < 0.5 and Game.current_area_id == "lowe_barrows" and Game.current_area == lowe,
		"and the Bearer where he stands; the Lowe is still the current area")
	check(not (saved["areas"] as Dictionary).has("kettle_fjord") or int(saved["areas"]["kettle_fjord"]["state"]) == RH.WState.THAW,
		"the neighbour's memory is untouched")
	ok = await _until(func(): return st.pending_ready(), 120.0)
	check(ok, "the Kettle stands ready (cold cache)")
	var pend := st.pending_area()
	check(pend != null and pend.is_inside_tree() and pend.inert and not pend.visible and not pend.can_process(), "unseen and unprocessing")
	check(pend != null and _count(pend) > 500, "its static world is in the tree (%d nodes)" % (_count(pend) if pend != null else 0))
	check(Game.current_area == lowe and Game.current_area_id == "lowe_barrows", "it is not the current area")
	if pend != null:
		var leaked := 0
		for g in Streamer.LIVE_GROUPS + ["nav_src"]:
			leaked += _under(pend, g)
		check(leaked == 0, "in no group that play reads (%d)" % leaked)
		check(Game.find_hearth("hs_landing_ice") == null and pend.find_children("*", "Hearthstone", true, false).is_empty()
			and pend.find_children("*", "Spawner", true, false).is_empty() and pend.find_children("*", "AreaPortal", true, false).is_empty(),
			"no hearth, foe or seam of it is in the tree")
		check(pend.nav_thaw == null and pend.nav_rime == null, "no navmesh of it is in the map")
		# its ground is not in the physics space: a ray down through a Kettle
		# house hits nothing of the Kettle
		var hits := 0
		var space := root3d.get_world_3d().direct_space_state
		for h in pend.get_meta("def").get("houses", []):
			var q := PhysicsRayQueryParameters3D.create(Vector3(h["center"][0], 400.0, h["center"][1]), Vector3(h["center"][0], -100.0, h["center"][1]), 0xFFFF)
			var r := space.intersect_ray(q)
			if not r.is_empty() and pend.is_ancestor_of(r["collider"]):
				hits += 1
		check(hits == 0, "none of its colliders is in the physics space")
		check(EnvRig.active_instance == lowe.env, "the Lowe's light still rules")
	check(st.areas_alive() == 2, "two areas stand: the live one and the neighbour")

	print("== walked away again: kept a while, then let go")
	player.global_position = _hearth_at(2)      # the Open Barrow: far from every seam
	await _until(func(): return false, 3.0)
	check(st.pending_id() == "kettle_fjord", "still held three seconds on (hysteresis)")
	ok = await _until(func(): return st.pending_id() == "", float(DB.tuning("streaming/drop_after_s", 8.0)) + 6.0)
	check(ok, "let go after streaming/drop_after_s")
	ok = await _until(func(): return st.areas_alive() == 1 and st._garbage.is_empty() and st._dying.is_empty(), 30.0)
	check(ok and not is_instance_valid(pend), "and freed")
	check(_count(root3d) - _count(lowe) < 400, "the tree is back to one area (%d nodes beside it)" % (_count(root3d) - _count(lowe)))

	print("== walking to the seam: ready before arrival, crossed inside the budget")
	var d0 := Streamer.portal_distance(kseam, player.global_position)
	check(d0 > float(DB.tuning("streaming/preload_dist", 70.0)), "the walk starts outside the preload distance (%.0f m)" % d0)
	var ready_at := [-1.0]
	var watch := func() -> bool:
		if ready_at[0] < 0.0 and st.pending_ready():
			ready_at[0] = Streamer.portal_distance(kseam, player.global_position)
		return Game.current_area_id == "kettle_fjord" or st.crossing()
	var walked := await _walk(kseam.global_position, watch)
	if Game.current_area_id != "kettle_fjord" and not st.crossing():
		# the seam sits at the navmesh edge: push on over it
		player.cam.yaw = atan2(-(kseam.global_position.x - player.global_position.x), -(kseam.global_position.z - player.global_position.z))
		player.sim_move = Vector3(0, 0, -1)
		await _until(func(): return watch.call(), 6.0)
		player.sim_move = Vector3.ZERO
	ok = await _until(func(): return Game.current_area_id == "kettle_fjord" and player.input_enabled and not st.crossing(), 120.0)
	check(ok, "the Bearer walks into the Kettle (%d ticks)" % walked)
	rep = st.last_report
	check(ready_at[0] > 2.0, "the Kettle stood ready with %.0f m still to walk" % ready_at[0])
	check(bool(rep.get("ready_at_call", false)), "and was ready at the seam")
	_check_report(rep, "prepared crossing")
	print("    made ready in %.0f ms; black for %.0f ms (swap %.1f ms, settle %.0f ms, nav from cache %s, baked in %s ms)" % [
		float(rep.get("prep_ms", 0.0)), float(rep.get("total_ms", 0.0)), float(rep.get("swap_ms", 0.0)), float(rep.get("settle_ms", 0.0)),
		str(rep.get("nav_cache", [])), str(rep.get("nav_bake_ms", []))])
	print(BuildProf.table(["kettle_fjord"]))
	check(float(rep.get("swap_ms", 999.0)) <= hitch_ms, "the swap itself is one cheap frame (%.1f ms)" % float(rep.get("swap_ms", 0.0)))
	var kettle: Area = Game.current_area
	check(kettle.visible and not kettle.inert and _under(kettle, "hearths") == 2 and kettle.nav_thaw != null and kettle.nav_thaw.enabled,
		"the Kettle is live: hearths, navmesh")
	await ticks(20)
	check(player.global_position.y > kettle.terrain.height_at(player.global_position.x, player.global_position.z) - 0.5, "the Bearer stands on its ground")
	st.look_ahead = false
	ok = await _until(func(): return st.areas_alive() == 1 and st.idle(), 60.0)
	check(ok and not is_instance_valid(lowe), "the Lowe is freed")
	check(max_alive <= 2, "never more than two areas stood (max %d)" % max_alive)
	check(_count(root3d) - _count(kettle) < 400, "node count is back to one area (%d beside the Kettle's %d)" % [
		_count(root3d) - _count(kettle), _count(kettle)])
	var saved2 = JSON.parse_string(FileAccess.get_file_as_string(World.save_path()))
	var sp2: Array = saved2["player"]["pos"]
	check(Vector3(sp2[0], sp2[1], sp2[2]).distance_to(kseam.spawn_pos if is_instance_valid(kseam) else player.global_position) < 6.0
		or Vector3(sp2[0], sp2[1], sp2[2]).distance_to(player.global_position) < 6.0, "the crossing saved the Bearer on the far side")

	print("== the cache: a hit, then a corrupt one")
	var h0 := StreamCache.hits
	ok = await _cross_now("lowe_barrows", AreaBuilder._v3(DB.area_def("lowe_barrows")["start"]["pos"]) + Vector3(0, 0.5, 0))
	rep = st.last_report
	check(ok and rep.get("nav_cache", []) == [true, true], "back in the Lowe its navmeshes come from the cache")
	check(StreamCache.hits - h0 >= 4, "so do its ground cover and terrain (%d hits)" % (StreamCache.hits - h0))
	_check_report(rep, "cold crossing, warm cache")
	lowe = Game.current_area
	check(lowe.nav_thaw.navigation_mesh.get_polygon_count() > 100, "the cached navmesh is whole (%d polygons)" % lowe.nav_thaw.navigation_mesh.get_polygon_count())
	await _settle_idle(60.0)
	for f in DirAccess.get_files_at(cache_dir):
		var fa := FileAccess.open(cache_dir.path_join(f), FileAccess.WRITE)
		fa.store_string("not a cache entry")
		fa.close()
	ok = await _cross_now("kettle_fjord", AreaBuilder._v3(DB.area_def("kettle_fjord")["start"]["pos"]) + Vector3(0, 1, 0))
	rep = st.last_report
	kettle = Game.current_area
	check(ok and kettle.area_id == "kettle_fjord" and kettle.terrain != null and kettle.terrain.get_child_count() > 20,
		"every entry corrupt: the Kettle is built all the same")
	check(rep.get("nav_cache", []) == [false, false] and kettle.nav_thaw.navigation_mesh.get_polygon_count() > 100,
		"and its navmeshes baked again")
	_check_report(rep, "cold crossing, corrupt cache")
	await _settle_idle(60.0)

	print("== a rest and a turn of the memory stay inside the budget")
	var hearth := Game.find_hearth("hs_landing_ice")
	check(hearth != null, "a Kettle hearth")
	player.global_position = hearth.respawn_point() + Vector3.UP * 0.3
	await ticks(10)
	await Game.hearth_flow(hearth, player, "rest_only")
	_check_report(Game.last_rest_report, "rest")
	await Game.hearth_flow(hearth, player)       # uncleared, THAW: it stills
	check(World.get_area_state("kettle_fjord") == RH.WState.RIME, "the memory stilled")
	_check_report(Game.last_rest_report, "turn to RIME (with every foe raised)")
	var foes := _under(kettle, RH.GROUP_ENEMIES)
	check(foes > 0, "its foes stand (%d)" % foes)

	print("== a death with the kept hearth in another area")
	World.last_hearth = {"area": "lowe_barrows", "hearth": "hs_barrow_road"}
	await Game.respawn_player()
	check(Game.current_area_id == "lowe_barrows" and not player.dead, "the Bearer wakes in the Lowe")
	var hb := Game.find_hearth("hs_barrow_road")
	check(hb != null and player.global_position.distance_to(hb.global_position) < 4.0, "at the kept hearth")
	_check_report(Game.last_respawn_report, "cross-area respawn")
	check(not (Game.last_respawn_report.get("nav_cache", [true, true]) as Array).has(null), "with a navmesh")
	await ticks(30)
	check(player.global_position.y > Game.current_area.terrain.height_at(player.global_position.x, player.global_position.z) - 0.5, "on its ground")
	await _settle_idle(60.0)
	check(max_alive <= 2 and st.areas_alive() == 1, "one area stands at the end (max ever %d)" % max_alive)
	print("    main thread waited at most %.1f ms on a worker build's lock" % BuildLock.max_wait_ms)
	finish()

## Where a crossing set the Bearer down (the seam's spawn on the far side).
func seam_spawn(area: Area, back_to: String, _rep: Dictionary) -> Vector3:
	for p in area.get_meta("def").get("portals", []):
		if String(p.get("to", "")) == back_to:
			return AreaBuilder._v3(p["at"])
	return player.global_position
