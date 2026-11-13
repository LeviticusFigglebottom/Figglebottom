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
	if rep.has("graft_items"):
		print("      dearest grafts: %s" % str(rep["graft_items"]))
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
	st.warm_ahead = false     # (hits and misses are counted here; the warming has its own part below)

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
	# what makes a StandardMaterial3D is left out of the worker build and made
	# on the main thread during the graft (AreaBuilder._for_main)
	var emitters := pend.find_children("*", "CPUParticles3D", true, false).size() + pend.find_children("*", "GPUParticles3D", true, false).size() if pend != null else 0
	check(emitters >= 5 and BuildProf.phases("kettle_fjord").has("graft: particles, weather (main-thread steps)"),
		"its particles and weather were made on the main thread (%d emitters)" % emitters)
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
	await _rebakes()
	await _settle_idle(60.0)
	await _warms(cache_dir)
	await _settle_idle(60.0)
	_keeping()
	_quits()
	check(max_alive <= 2 and st.areas_alive() == 1, "one area stands at the end (max ever %d)" % max_alive)
	print("    main thread waited at most %.1f ms on a worker build's lock" % BuildLock.max_wait_ms)
	finish()

## Shaders outlive the materials that made them (ShaderWarm.retain): the
## area left takes no shader with it, so the next one compiles nothing anew.
func _keeping() -> void:
	print("== shaders kept for the run")
	check(ShaderWarm.retained() > 0, "the crossings kept shaders (%d kinds)" % ShaderWarm.retained())
	var a := StandardMaterial3D.new()
	a.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	a.albedo_texture = FrostFX.soft_tex()
	a.cull_mode = BaseMaterial3D.CULL_FRONT
	a.albedo_color = Color(0.3, 0.2, 0.1)
	var b := a.duplicate() as StandardMaterial3D
	b.albedo_color = Color(0.9, 0.9, 0.9)      # a uniform: the same shader
	var c := a.duplicate() as StandardMaterial3D
	c.albedo_texture = null                    # no texture: another shader
	var n0 := ShaderWarm.retained()
	var added := ShaderWarm.retain([a, b, c, a])
	check(added == 2 and ShaderWarm.retained() == n0 + 2, "one stand-in per kind of shader (%d new of 3 materials)" % added)
	var key := ShaderWarm._base_key(a)
	var stand: BaseMaterial3D = ShaderWarm._kept.get(key)
	check(stand != null and stand != a and stand.albedo_texture != null and stand.albedo_texture != a.albedo_texture
		and stand.albedo_texture.get_width() == 1 and ShaderWarm._base_key(stand) == key,
		"the stand-in holds one blank pixel, not the texture, and compiles to the same shader")
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/frost_veil.gdshader")
	ShaderWarm.retain([sm])
	check(ShaderWarm._kept.get(sm.shader.get_instance_id()) == sm.shader, "a ShaderMaterial's shader itself is kept")
	check(StateDirector.wave_materials()[0] == StateDirector.wave_materials()[0] and StateDirector.wave_materials().size() == 5,
		"the wave's particle materials are made once")

## The game is quit while a neighbour is on a worker thread: the process
## must go, promptly (it once never did: ADR 0014, "Quitting"). Each case is
## its own process (tools/qa/quit_probe.gd), killed after a minute, so a hang
## fails here and not at the suite's time limit. The whole matrix
## (four kinds of work, three ways of quitting) is tools/qa/quit_check.sh.
func _quits() -> void:
	print("== quitting with a build in flight")
	for c in [["preload", "tree"], ["preload", "game"], ["crossing", "close"]]:
		# portable: no `timeout` (on Windows that is cmd's pause, and the
		# child never ran). The child logs to a file; Godot keeps the clock.
		var log_path := ProjectSettings.globalize_path("user://quit_probe/%s_%s.log" % [c[0], c[1]])
		DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
		if FileAccess.file_exists(log_path):
			DirAccess.remove_absolute(log_path)
		var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--log-file", log_path,
			"--path", ProjectSettings.globalize_path("res://"),
			"--", "--scene=res://tools/qa/quit_probe.tscn", "--quit-case=" + String(c[0]), "--quit-how=" + String(c[1]),
			"--quit-after-ms=1500", "--cache-dir=user://quit_probe/cache"])
		var t0 := Time.get_ticks_msec()
		while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < 60000:
			OS.delay_msec(10)
		var gone_ms := int(Time.get_unix_time_from_system() * 1000.0)
		var code := -1
		if pid > 0 and OS.is_process_running(pid):
			OS.kill(pid)
			code = 124            # as `timeout` reported a hang
		elif pid > 0:
			code = OS.get_process_exit_code(pid)
		var text := FileAccess.get_file_as_string(log_path)
		var asked := -1
		for line in text.split("\n"):
			if line.begins_with("[quit] asked at "):
				asked = int(line.trim_prefix("[quit] asked at "))
		var took := gone_ms - asked if asked > 0 else -1
		check(code == 0 and asked > 0 and took < 3000,
			"%s in flight, quit by %s: the process is gone %d ms after the asking (exit %d)" % [c[0], c[1], took, code])
		check(not text.contains("did not end"), "and no worker had to be given up on")

## Idle time warms the cache: a neighbour never visited on this machine has
## its ground cover and terrain computed before the Bearer walks to its seam.
func _warms(cache_dir: String) -> void:
	var st: Streamer = Game.stream
	print("== idle time: the neighbours' cache entries are computed ahead")
	StreamCache.clear()
	check(DirAccess.get_files_at(cache_dir).is_empty(), "an empty cache, the Bearer standing in the Lowe")
	var t0 := Time.get_ticks_msec()
	st.warm_ahead = true
	var began := await _until(func(): return st.cache_warming() != "", 20.0)
	check(began, "with nothing else to do, a neighbour's entries are being computed (%s)" % st.cache_warming())
	check(st.areas_alive() == 1 and st.pending_area() == null, "nothing is built or grafted for it")
	var ok := await _until(func(): return st.warmed.has("kettle_fjord") and st.warmed.has("saltfell_steading"), 240.0)
	print("    warmed %s in %.1f s of idle time" % [str(st.warmed), (Time.get_ticks_msec() - t0) / 1000.0])
	var kinds := {}
	for f in DirAccess.get_files_at(cache_dir):
		kinds[f.get_slice("_", 0)] = int(kinds.get(f.get_slice("_", 0), 0)) + 1
	check(ok and int(kinds.get("veg", 0)) == 2 and int(kinds.get("terrain", 0)) == 2,
		"both neighbours' ground cover and terrain are on disk (%s)" % str(kinds))
	st.warm_ahead = false
	var m0 := StreamCache.misses
	var h0 := StreamCache.hits
	var t1 := Time.get_ticks_msec()
	ok = await _cross_now("kettle_fjord", AreaBuilder._v3(DB.area_def("kettle_fjord")["start"]["pos"]) + Vector3(0, 1, 0))
	check(ok and StreamCache.hits - h0 >= 2 and StreamCache.misses - m0 <= 2,
		"the Kettle is then made ready from the cache: ground cover and terrain hit, only the navmeshes are baked (%d hits, %d misses, %.1f s)" % [
		StreamCache.hits - h0, StreamCache.misses - m0, (Time.get_ticks_msec() - t1) / 1000.0])
	_check_report(st.last_report, "crossing after warming")
	# called off at once when a build is wanted
	st.warm_ahead = true
	st._wc_checked.clear()
	StreamCache.clear()
	await _settle_idle(60.0)
	began = await _until(func(): return st.cache_warming() != "", 20.0)
	var tc := Time.get_ticks_usec()
	st.yield_to_sync_build()
	var stop_ms := (Time.get_ticks_usec() - tc) / 1000.0
	# (a synchronous build waits for it; a preload near a seam does not wait at all)
	check(began and st.cache_warming() == "" and stop_ms < 250.0, "a build that is wanted calls the warming off (%.1f ms)" % stop_ms)
	st.warm_ahead = false

## How far the navmesh is from `p`.
func _nav_gap(p: Vector3) -> float:
	var map: RID = Game.current_area.get_world_3d().navigation_map
	return NavigationServer3D.map_get_closest_point(map, p).distance_to(p)

func _route(from: Vector3, to: Vector3, tol := 2.5) -> bool:
	var map: RID = Game.current_area.get_world_3d().navigation_map
	var pth := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, from),
		NavigationServer3D.map_get_closest_point(map, to), true)
	return pth.size() > 1 and pth[pth.size() - 1].distance_to(to) < tol

## The routes change while the area is lived in (the bridge comes down, a
## release opens the way on): the navmesh is baked again in the background,
## the old one answering until the new one is in the map (Streamer.rebake).
func _rebakes() -> void:
	var st: Streamer = Game.stream
	var lowe: Area = Game.current_area
	print("== the bridge comes down: the navmesh is baked again, off the main thread")
	var t_sync := Time.get_ticks_usec()
	lowe.bake_navmeshes()
	print("    (the synchronous bake this replaces: %.0f ms in one frame)" % ((Time.get_ticks_usec() - t_sync) / 1000.0))
	await ticks(4)
	var bridges: Array = lowe.find_children("*", "DrawBridge", true, false)
	check(bridges.size() == 1 and not bridges[0].is_down(), "the Lowe's bridge stands raised")
	if bridges.size() == 1:
		var br: DrawBridge = bridges[0]
		var near: Vector3 = br.global_position + br.global_transform.basis.z * 2.0
		# (the Lowe's nav bounds end 2.5 m out along the deck: Saltfell has the rest)
		var on_deck: Vector3 = br.global_position - br.global_transform.basis.z * 1.6
		# (the map takes in a new navmesh on the navigation server's own
		# thread, some frames after it is set: on a loaded box, more than a few)
		await _until(func(): return _nav_gap(near) < 1.0, 5.0)
		var d_up := _nav_gap(on_deck)
		var old_thaw := lowe.nav_thaw
		br._on_lower(player)
		check(lowe.nav_pending, "a re-bake is asked for")
		await ticks(6)
		check(lowe.nav_thaw == old_thaw and is_instance_valid(old_thaw) and (old_thaw.enabled or lowe.nav_rime.enabled),
			"the old navmesh answers meanwhile")
		await nav_wait(lowe, 60.0)
		check(not lowe.nav_pending and lowe.nav_thaw != old_thaw, "nav_ready: new navmeshes are in the map")
		_check_report(st.last_rebake, "bridge re-bake")
		print("    bridge re-bake: %.0f ms from the windlass to the map (the deck takes %.1f s), bake %s ms in the background, cache %s" % [
			float(st.last_rebake.get("ms", 0.0)), DrawBridge.LOWER_S, str(st.last_rebake.get("bake_ms", [])), str(st.last_rebake.get("from_cache", []))])
		await _until(func(): return _nav_gap(on_deck) < 0.6 and _route(near, on_deck, 0.6), 5.0)
		var d_down := _nav_gap(on_deck)
		check(d_down < 0.6 and d_down < d_up - 0.5 and _route(near, on_deck, 0.6),
			"and a route runs out onto the deck (navmesh %.2f m from a point 1.6 m along it; raised: %.2f m)" % [d_down, d_up])
		var regions := 0
		for c in lowe.get_children():
			if c is NavigationRegion3D and not c.is_queued_for_deletion():
				regions += 1
		check(regions == 2, "two regions stand, no more (%d)" % regions)

	print("== a release opens the way on: slain, gate, re-bake")
	var way: Dictionary = (lowe.get_meta("def")["way_on"] as Array)[0]
	var gate: ShortcutGate = null
	for g in lowe.find_children("*", "ShortcutGate", true, false):
		if g.gate_id == String(way["gate"]):
			gate = g
	check(gate != null and (gate.get_node("GateBody") as StaticBody3D).collision_layer != 0, "the way on stands shut")
	if gate == null:
		return
	var zn: Vector3 = gate.global_transform.basis.z.normalized()
	var front: Vector3 = gate.global_position + zn * 3.0
	var beyond: Vector3 = gate.global_position - zn * 3.0
	front.y = lowe.terrain.height_at(front.x, front.z) + 0.25
	beyond.y = lowe.terrain.height_at(beyond.x, beyond.z) + 0.25
	check(not _route(front, beyond), "no route through it")
	var t_rel := Time.get_ticks_usec()
	BuildProf.window_open("release")
	World.set_flag(String(way["open_flag"]))
	Game.on_boss_slain("lowe_barrows")
	var slain_ms := (Time.get_ticks_usec() - t_rel) / 1000.0
	var asked := await _until(func(): return lowe.nav_pending, 5.0)
	check(asked and (gate.get_node("GateBody") as StaticBody3D).collision_layer == 0, "the gate answers the release and asks for a re-bake")
	check(not _route(front, beyond), "meanwhile the old navmesh still says shut")
	await nav_wait(lowe, 60.0)
	var rel := BuildProf.window_close()
	check(not lowe.nav_pending, "nav_ready fires")
	_check_report(rel, "release: slain to routes open")
	print("    release: %.0f ms from the Holdfast's fall to the new routes; re-bake %s ms in the background; Game.on_boss_slain itself (save, leavings, song: not streaming work) %.0f ms" % [
		(Time.get_ticks_usec() - t_rel) / 1000.0, str(st.last_rebake.get("bake_ms", [])), slain_ms])
	await _until(func(): return _route(front, beyond), 5.0)
	check(_route(front, beyond), "and a route runs through the opened gate")

## Where a crossing set the Bearer down (the seam's spawn on the far side).
func seam_spawn(area: Area, back_to: String, _rep: Dictionary) -> Vector3:
	for p in area.get_meta("def").get("portals", []):
		if String(p.get("to", "")) == back_to:
			return AreaBuilder._v3(p["at"])
	return player.global_position
