extends Node
## The numbers behind docs/qa/STREAMING.md, for every area.
##
## Default (the BEFORE table): builds each area the synchronous way
## (AreaBuilder.build), snaps it to both states, flips it, respawns its dead
## and frees it, and prints what each phase cost the main thread.
##
##   godot --headless --path . -- --scene=res://tools/qa/stream_prof.tscn --no-cache
##
## --prof-stream (the AFTER tables): walks the same areas the streamed way.
## Each is made ready as the Streamer does near a seam (worker build,
## budgeted graft), crossed into with Game.travel_to, rested in, turned to
## RIME, and left. Twice: once with an empty cache, once with it warm.
##
##   godot --headless --path . -- --scene=res://tools/qa/stream_prof.tscn --prof-stream
##
## Other arguments: --prof-out=PATH (write the markdown there),
## --prof-areas=a,b (a subset), --cache-dir=PATH, --no-cache.
## The cache used is user://prof_cache unless --cache-dir is given, and
## --prof-stream empties it first. Saves go to user://prof_saves.
## Run it under a renderer for upload costs:
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 640x360 -- --scene=... --prof-stream
## Timings on a software/CI box are relative; re-measure on the target GPU.

var _out := ""
var _areas: Array = []
var _stream := false
var _own_cache := true

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prof-out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--prof-areas="):
			_areas = Array(a.get_slice("=", 1).split(","))
		elif a == "--prof-stream":
			_stream = true
		elif a.begins_with("--cache-dir=") or a == "--no-cache":
			_own_cache = false
	if _areas.is_empty():
		_areas = DB.table("areas").get("areas", [])
	if _stream:
		_run_stream.call_deferred()
	else:
		_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c

func _emit(text: String) -> void:
	print(text)
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	if Game.stream != null:
		Game.stream.reset()
	AudioDirector.shutdown()
	get_tree().quit(0)

# ---------------------------------------------------------------- before

func _run() -> void:
	World.reset()
	World._save_dir = "user://prof_saves"
	var scopes: Array = []
	var extra := "| area | nodes | first frame ms | snap THAW ms | snap RIME ms | flip pre ms | flip settle ms | respawn ms | free ms |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|\n"
	for aid in _areas:
		BuildProf.clear(aid)
		var area := AreaBuilder.build(aid)
		var t := BuildProf.now()
		add_child(area)
		BuildProf.add(aid, "enter tree", BuildProf.now() - t, true)
		await get_tree().process_frame    # the deferred bake runs here
		t = BuildProf.now()
		StateDirector.snap(area, RH.WState.THAW)
		var snap_thaw := (BuildProf.now() - t) / 1000.0
		BuildProf.add(aid, "state snap", BuildProf.now() - t, true)
		t = BuildProf.now()
		await get_tree().process_frame
		await get_tree().process_frame
		var first := (BuildProf.now() - t) / 1000.0
		BuildProf.add(aid, "first frames (2)", BuildProf.now() - t, true)
		await _frames(4)
		var nodes := _count(area)
		t = BuildProf.now()
		area.pre_transition(RH.WState.RIME)
		var pre := (BuildProf.now() - t) / 1000.0
		t = BuildProf.now()
		area.apply_state(RH.WState.RIME)
		var settle := (BuildProf.now() - t) / 1000.0
		await _frames(3)
		t = BuildProf.now()
		StateDirector.snap(area, RH.WState.RIME)
		var snap_rime := (BuildProf.now() - t) / 1000.0
		await _frames(3)
		t = BuildProf.now()
		get_tree().call_group(RH.GROUP_RESPAWN_ON_REST, "respawn")
		await get_tree().process_frame
		var resp := (BuildProf.now() - t) / 1000.0
		await _frames(3)
		t = BuildProf.now()
		RH.free_gently(area)
		while is_instance_valid(area):
			await get_tree().process_frame
		await get_tree().process_frame
		var free_ms := (BuildProf.now() - t) / 1000.0
		BuildProf.add(aid, "free old area", BuildProf.now() - t, true)
		scopes.append(aid)
		extra += "| %s | %d | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f | %.0f |\n" % [aid, nodes, first, snap_thaw, snap_rime, pre, settle, resp, free_ms]
		print("[prof] %s done: %.0f ms main" % [aid, BuildProf.total_ms(aid)])
		await _frames(3)
	_emit("### Per-phase build, main-thread ms (synchronous `AreaBuilder.build`)\n\n" + BuildProf.table(scopes)
			+ "\n### State and teardown, ms (each one frame)\n\n" + extra)

# ---------------------------------------------------------------- after

func _until(cond: Callable, max_s := 180.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().process_frame
	return cond.call()

func _run_stream() -> void:
	var st: Streamer = Game.stream
	if _own_cache:
		StreamCache.use_dir("user://prof_cache")
		StreamCache.clear()
	World.reset()
	World._save_dir = "user://prof_saves"
	World.delete_slot(World.active_slot)
	st.look_ahead = false
	var root3d := Node3D.new()
	root3d.name = "World"
	add_child(root3d)
	Game.world_root = root3d
	# somewhere to stand first: a bare area (nothing to time)
	var bare := Area.new()
	bare.area_id = "prof_start"
	root3d.add_child(bare)
	Game.register_area(bare, "prof_start")
	var player := Player.new()
	player.name = "Player"
	root3d.add_child(player)
	player.sim_active = true
	await _frames(5)

	var out := ""
	var phase_tables := ""
	var rows := {}
	for pass_name in ["cold", "warm"]:
		var scopes: Array = []
		BuildProf.clear()
		for aid in _areas:
			World.reset()     # every pass meets the same THAW areas
			# made ready, as near a seam
			st._start_prep(aid)
			var ok: bool = await _until(func(): return st.pending_ready() or st.pending_id() == "")
			if not ok or st.pending_id() != aid:
				print("[prof] %s could not be made ready" % aid)
				continue
			await _frames(3)
			var def := DB.area_def(aid)
			var spawn: Vector3 = AreaBuilder._v3(def.get("start", {}).get("pos", [0, 0.2, 0])) + Vector3(0, 0.3, 0)
			Game.travel_to(aid, spawn)
			await _until(func(): return Game.current_area_id == aid and player.input_enabled and not st.crossing())
			var rep: Dictionary = st.last_report.duplicate(true)
			var nodes := _count(Game.current_area)
			# the area left is freed: how many frames, how much the worst
			await _until(func(): return st.idle(), 60.0)
			var free_rep: Dictionary = st.last_free.duplicate()
			await _frames(10)
			# a rest, then the turn to RIME (uncleared, THAW: it stills)
			var hearth: Hearthstone = null
			for h in get_tree().get_nodes_in_group("hearths"):
				hearth = h
				break
			var rest := {}
			var flip := {}
			if hearth != null:
				player.global_position = hearth.respawn_point() + Vector3.UP * 0.3
				await _frames(5)
				await Game.hearth_flow(hearth, player, "rest_only")
				rest = Game.last_rest_report.duplicate(true)
				await Game.hearth_flow(hearth, player)
				flip = Game.last_rest_report.duplicate(true)
			var foes := 0
			for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
				if Game.current_area.is_ancestor_of(e):
					foes += 1
			scopes.append(aid)
			rows["%s|%s" % [pass_name, aid]] = {"rep": rep, "free": free_rep, "rest": rest, "flip": flip, "nodes": nodes, "foes": foes}
			print("[prof] %s %s: ready in %.0f ms, black %.0f ms, worst frame %.1f ms" % [pass_name, aid,
				float(rep.get("prep_ms", 0.0)), float(rep.get("total_ms", 0.0)), float(rep.get("max_work_ms", 0.0))])
		phase_tables += "\n### Per-phase, %s cache: main-thread ms (+ worker-thread ms)\n\n" % pass_name + BuildProf.table(scopes)
	out += "### Crossing into each area, made ready ahead (streamed)\n\n"
	out += "| area | nodes | made ready, cold cache ms | made ready, warm cache ms | black, cold ms | black, warm ms | swap frame ms | worst frame, cold ms | worst frame, warm ms | next worst, warm ms | what the worst frame held (warm) | nav bake thaw/rime, cold ms (background) | nav from cache, warm | sync phases |\n"
	out += "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|\n"
	for aid in _areas:
		var c: Dictionary = rows.get("cold|%s" % aid, {})
		var w: Dictionary = rows.get("warm|%s" % aid, {})
		if c.is_empty() or w.is_empty():
			continue
		var cr: Dictionary = c["rep"]
		var wr: Dictionary = w["rep"]
		var worst := ""
		for k in wr.get("worst", {}):
			if float(wr["worst"][k]) >= 0.5:
				worst += "%s %.0f; " % [k, float(wr["worst"][k])]
		var bake: Array = cr.get("nav_bake_ms", [0.0, 0.0])
		out += "| %s | %d | %.0f | %.0f | %.0f | %.0f | %.1f | %.1f | %.1f | %.1f | %s | %.0f / %.0f | %s | %s |\n" % [aid, int(w["nodes"]),
			float(cr.get("prep_ms", 0.0)), float(wr.get("prep_ms", 0.0)), float(cr.get("total_ms", 0.0)), float(wr.get("total_ms", 0.0)),
			float(wr.get("swap_ms", 0.0)), float(cr.get("max_work_ms", 0.0)), float(wr.get("max_work_ms", 0.0)),
			float(wr.get("second_work_ms", 0.0)), worst, float(bake[0]), float(bake[1]), str(wr.get("nav_cache", [])),
			"none" if (wr.get("sync", []) as Array).is_empty() and (cr.get("sync", []) as Array).is_empty() else str(wr.get("sync", []))]
	out += "\n### Freeing the area left, a rest, the turn to RIME (warm pass): worst main-thread frame, ms of work\n\n"
	out += "| area | foes raised | free: worst frame ms | free: frames | rest: worst frame ms | turn to RIME: worst frame ms | what it held |\n|---|---:|---:|---:|---:|---:|---|\n"
	for aid in _areas:
		var w: Dictionary = rows.get("warm|%s" % aid, {})
		if w.is_empty():
			continue
		var held := ""
		for k in (w["flip"] as Dictionary).get("worst", {}):
			held += "%s %.1f; " % [k, float(w["flip"]["worst"][k])]
		out += "| %s | %d | %.1f | %d | %.1f | %.1f | %s |\n" % [aid, int(w["foes"]), float((w["free"] as Dictionary).get("max_ms", 0.0)),
			int((w["free"] as Dictionary).get("frames", 0)), float((w["rest"] as Dictionary).get("max_work_ms", 0.0)),
			float((w["flip"] as Dictionary).get("max_work_ms", 0.0)), held]
	out += "\nMain thread waited at most %.1f ms for a cache a worker build held (BuildLock). Cache: %d hits, %d misses.\n" % [
		BuildLock.max_wait_ms, StreamCache.hits, StreamCache.misses]
	_emit(out + phase_tables)
