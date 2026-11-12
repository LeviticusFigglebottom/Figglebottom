extends Node
## Quits the game while streaming work is in flight, to prove the process
## exits promptly (ADR 0014, "Quitting"). One case per run:
##
##   godot --headless --path . -- --scene=res://tools/qa/quit_probe.tscn --quit-case=preload
##
## Cases: preload (a neighbour being built on a worker), warm (idle-time
## cache warming), rebake (a background navmesh re-bake), crossing (in the
## black of a seam). --quit-how=game (Game.quit, the default: what the pause
## sheet and the tests use), tree (a bare get_tree().quit(), the last resort
## _exit_tree must survive), close (the window's close request).
## --quit-after-ms=N waits that long after the work has started.
## Prints "[quit] ..." lines; the caller times the process (tools/qa/quit_check.sh).

var _case := "preload"
var _how := "game"
var _after_ms := 300

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quit-case="):
			_case = a.get_slice("=", 1)
		elif a.begins_with("--quit-how="):
			_how = a.get_slice("=", 1)
		elif a.begins_with("--quit-after-ms="):
			_after_ms = int(a.get_slice("=", 1))
	_run.call_deferred()

func _wait(cond: Callable, max_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().process_frame
	return cond.call()

func _run() -> void:
	var st: Streamer = Game.stream
	st.look_ahead = false
	st.warm_ahead = false
	World.reset()
	World._save_dir = "user://quit_probe/saves"
	var root := Node3D.new()
	root.name = "World"
	add_child(root)
	Game.world_root = root
	var area := AreaBuilder.build("tarnhall")
	root.add_child(area)
	Game.register_area(area, "tarnhall")
	StateDirector.snap(area, RH.WState.THAW)
	var player := Player.new()
	player.name = "Player"
	root.add_child(player)
	Game.player = player
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"]) + Vector3(0, 0.5, 0)
	for i in 20:
		await get_tree().process_frame
	# everything below starts from nothing on disk, so the work is long
	StreamCache.clear()
	var started := false
	match _case:
		"preload":
			st._start_prep("kettle_fjord")
			started = await _wait(func(): return st.pending_id() == "kettle_fjord", 5.0)
		"warm":
			st.warm_ahead = true
			started = await _wait(func(): return st.cache_warming() != "", 20.0)
		"rebake":
			area.rebake_navmeshes()
			started = area.nav_pending
		"crossing":
			Game.travel_to("kettle_fjord", AreaBuilder._v3(DB.area_def("kettle_fjord")["start"]["pos"]) + Vector3(0, 1, 0))
			started = await _wait(func(): return st.crossing(), 5.0)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < _after_ms:
		await get_tree().process_frame
	print("[quit] case=%s how=%s started=%s after=%d ms prep=%s warming=%s nav_pending=%s crossing=%s" % [_case, _how, started,
		_after_ms, st.pending_id(), st.cache_warming(), area.nav_pending, st.crossing()])
	print("[quit] asked at %d" % int(Time.get_unix_time_from_system() * 1000.0))
	match _how:
		"tree":
			get_tree().quit(0 if started else 3)
		"close":
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		_:
			Game.quit(0 if started else 3)
