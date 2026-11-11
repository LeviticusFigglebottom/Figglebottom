extends Node
## Build-phase table for docs/qa/STREAMING.md: builds every area the
## synchronous way, snaps it to both states, flips it, respawns its dead and
## frees it, and prints what each phase cost on the main thread.
##   godot --headless --path . -- --scene=res://tools/qa/stream_prof.tscn \
##       [--prof-out=PATH] [--prof-areas=a,b] [--prof-keep-cache]
## Timings on a software/CI box are relative; re-measure on the target GPU.

var _out := ""
var _areas: Array = []
var _keep_cache := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prof-out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--prof-areas="):
			_areas = Array(a.get_slice("=", 1).split(","))
		elif a == "--prof-keep-cache":
			_keep_cache = true
	if _areas.is_empty():
		_areas = DB.table("areas").get("areas", [])
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c

func _run() -> void:
	World.reset()
	if not _keep_cache and ClassDB.class_exists("Node") and Engine.has_meta("stream_cache_off"):
		pass
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
	var text := "### Per-phase build, main-thread ms (synchronous `AreaBuilder.build`)\n\n" + BuildProf.table(scopes) \
			+ "\n### State and teardown, ms\n\n" + extra
	print(text)
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	AudioDirector.shutdown()
	get_tree().quit(0)
