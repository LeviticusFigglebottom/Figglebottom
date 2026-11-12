extends Node
## Fills the streaming cache (ADR 0014, src/core/stream_cache.gd) for every
## area, so no first visit computes anything at a seam:
##   - terrain arrays and ground cover (AreaBuilder.warm_cache), and
##   - both navmeshes of the area as a new journey finds it (NavBaker; the
##     key is the colliders' fingerprint, so a journey that has opened gates
##     bakes its own once, in the background).
##
##   tools/qa/warm_cache.sh [--cache-dir=PATH] [--warm-areas=a,b] [--warm-no-nav]
##
## Without --cache-dir it fills user://cache, the game's own. An entry's key
## holds the builder scripts' source and the engine version: fill the cache
## with the same build that will read it (an exported build reads .gdc, the
## editor .gd: their keys differ).

var _areas: Array = []
var _nav := true

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--warm-areas="):
			_areas = Array(a.get_slice("=", 1).split(","))
		elif a == "--warm-no-nav":
			_nav = false
	if _areas.is_empty():
		_areas = DB.table("areas").get("areas", [])
	_run.call_deferred()

func _run() -> void:
	if Game.stream != null:
		Game.stream.look_ahead = false
		Game.stream.warm_ahead = false
	World.reset()
	var t_all := Time.get_ticks_msec()
	for id in _areas:
		var aid := String(id)
		var t0 := Time.get_ticks_msec()
		var did := AreaBuilder.warm_cache(aid)
		var line := "[warm] %s: terrain and ground cover %s in %.1f s" % [aid, "computed" if did else "already there", (Time.get_ticks_msec() - t0) / 1000.0]
		if _nav:
			t0 = Time.get_ticks_msec()
			var area := AreaBuilder.build(aid)
			if area != null:
				add_child(area)
				StateDirector.snap(area, RH.WState.THAW)
				await get_tree().process_frame
				await get_tree().process_frame     # (the build's own deferred bake)
				var nb := NavBaker.new(area)
				while not nb.step(50000):
					await get_tree().process_frame
				line += "; navmeshes %s in %.1f s" % ["already there" if nb.from_cache == [true, true] else
					("baked" if nb.phase == NavBaker.P.DONE else "FAILED"), (Time.get_ticks_msec() - t0) / 1000.0]
				for i in 30:
					await get_tree().process_frame     # (the entries are written by a worker)
				area.queue_free()
				await get_tree().process_frame
				await get_tree().process_frame
		print(line)
	var bytes := 0
	var n := 0
	for f in DirAccess.get_files_at(StreamCache.dir()):
		n += 1
		var fa := FileAccess.open(StreamCache.dir().path_join(f), FileAccess.READ)
		if fa != null:
			bytes += fa.get_length()
			fa.close()
	print("[warm] done in %.0f s: %d entries, %.1f MB in %s" % [(Time.get_ticks_msec() - t_all) / 1000.0, n, bytes / 1048576.0,
		ProjectSettings.globalize_path(StreamCache.dir())])
	if Game.stream != null:
		Game.stream.reset()
	AudioDirector.shutdown()
	get_tree().quit(0)
