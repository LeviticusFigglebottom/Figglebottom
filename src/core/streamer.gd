class_name Streamer
extends Node
## Area streaming (ADR 0014): the area beyond a seam is made ready before the
## Bearer reaches it, so that crossing is a swap and not a build.
##
##   near a seam   the neighbour is built on a worker thread, taken apart
##                 (AreaBuilder.build_detached), and its static world grafted
##                 into the tree a few milliseconds a frame: unseen, inert,
##                 in no group that play reads. Its materials are drawn once.
##   at the seam   Game.travel_to: a short dip to black, the swap (one cheap
##                 frame), then what acts (hearths, foes, souls, portals) is
##                 grafted and the navmeshes read from the cache or baked in
##                 the background, and the light comes back.
##   after         the area left is freed a little a frame.
## Never more than two areas stand: the live one, and one coming or going.
## Tuning: data/game.json "streaming". Numbers: docs/qa/STREAMING.md.

enum St { BUILD, GRAFT, COLLECT, WARM, READY, FAILED }

## Groups play reads: an area being left gives up its seats in them at the
## swap, though it stands a few more frames while it is freed.
const LIVE_GROUPS := [RH.GROUP_ENEMIES, RH.GROUP_RESPAWN_ON_REST, RH.GROUP_STATE_LISTENERS, "targetable", "allies",
	"hearths", "seams", "area_portals", "hazards", "net_floor", "ice_ridges", "sealed_ice", "chip_heavy",
	"ending_choice"]

class Prep:
	var area_id := ""
	var stage: St = St.BUILD
	var task := -1
	var mx := Mutex.new()
	var built := false
	var result: Dictionary = {}
	var flag_names: Array = []
	var flag_sig := ""
	var area: Area = null
	var world: Array = []
	var wi := 0
	var late: Array = []
	## Scenes and scripts what acts will load (foe and soul models, finds):
	## read on the worker and held until the crossing is over, so no _ready
	## reads a GLB on the main thread.
	var preloaded: Array = []
	var warm_stack: Array[Node] = []
	var warm_found: Dictionary = {}
	var warm_mats: Array = []
	var warm_i := 0
	var warm_holders: Array = []     # [[holder, frames left]]
	var far_s := 0.0
	var dropped := false
	var t0_us := 0
	var ready_us := 0

signal crossing_done(report: Dictionary)

## The neighbour being made ready, if any.
var _prep: Prep = null
## A build whose neighbour was let go before the worker ended.
var _orphans: Array[Prep] = []
## Areas left, being freed: [{root, wait, stack}], and loose nodes never grafted.
var _dying: Array = []
var _garbage: Array = []
## What acts in the live area and is not in the tree yet (settle()).
var _late: Array = []
var _late_i := 0
var _nav: NavBaker = null
var _nav_area: Area = null
var _held: Array = []          # resources read ahead for what acts (until settled)
## What raising one foe costs (its spawner defers it past our timer), learnt
## from the frames it happened in; ms.
var _foe_est_ms := 6.0
var _foes_this_frame := 0

var _crossing := false
var _cold := false
var _reap_first := false       # a crossing waits for the freeing to end
## Off: nothing is made ready ahead (tests that count nodes; a crossing then
## builds behind its black).
var look_ahead := true
## The area just left is not made ready again at once: the Bearer has only
## just walked out of it.
var _left_id := ""
var _left_until_us := 0
var _scan_t := 0.0
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _fade_tw: Tween = null
var _stamp_us := 0

## The last crossing, for tests and STREAMING.md:
##   {area, ready_at_call, wait_ms, swap_ms, settle_ms, max_work_ms,
##    max_frame_ms, sync, nav_cache: [thaw, rime], nav_bake_ms: [thaw, rime]}
var last_report: Dictionary = {}
## Crossings so far, and how many found the neighbour ready.
var crossings := 0
var crossings_ready := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # a crossing ends even under the pause sheet
	# old cache entries go, off the main thread (a directory listing)
	WorkerThreadPool.add_task(StreamCache.prune, false, "cache prune")

static func cfg(key: String, def: Variant) -> Variant:
	return DB.tuning("streaming/" + key, def)

func enabled() -> bool:
	return bool(cfg("enabled", true)) and Game.world_root != null

# ---------------------------------------------------------------- what stands

## The neighbour being made ready (inert), or null.
func pending_area() -> Area:
	return _prep.area if _prep != null else null

func pending_id() -> String:
	return _prep.area_id if _prep != null else ""

func pending_ready() -> bool:
	return _prep != null and _prep.stage == St.READY

## Areas in the tree or on their way into it: live, pending, being freed.
func areas_alive() -> int:
	var n := 0
	if Game.current_area != null and is_instance_valid(Game.current_area):
		n += 1
	if _prep != null:
		n += 1
	for d in _dying:
		if is_instance_valid(d["root"]):
			n += 1
	return n + _orphans.size()

func crossing() -> bool:
	return _crossing

## Nothing coming, nothing going: the live area alone.
func idle() -> bool:
	return _prep == null and _dying.is_empty() and _garbage.is_empty() and _orphans.is_empty() \
			and _late_i >= _late.size() and _nav == null and not _crossing

## True for a node that stands in the tree but is no part of the live world
## (the inert neighbour, an area being freed).
func foreign(n: Node) -> bool:
	if _prep != null and _prep.area != null and _prep.area.is_ancestor_of(n):
		return true
	for d in _dying:
		if is_instance_valid(d["root"]) and (d["root"] as Node).is_ancestor_of(n):
			return true
	return false

# ---------------------------------------------------------------- the frame

func _process(dt: float) -> void:
	BuildProf.tick()
	var budget := int(float(cfg("cold_budget_ms" if _cold else "budget_ms", 4.0)) * 1000.0)
	var t0 := Time.get_ticks_usec()
	_poll_orphans()
	if _prep != null:
		_advance(_prep, t0, budget)
	_tick_warm()
	if not _crossing and look_ahead and enabled():
		_scan_t -= dt
		if _scan_t <= 0.0:
			_scan_t = float(cfg("scan_s", 0.25))
			_scan(float(cfg("scan_s", 0.25)))
	# freeing keeps to its own small share, unless a crossing is waiting on it
	var free_budget := int(float(cfg("free_budget_ms", 2.5)) * 1000.0)
	if _reap_first:
		free_budget = maxi(free_budget, budget - (Time.get_ticks_usec() - t0))
	_reap(free_budget)

# ---------------------------------------------------------------- looking ahead

## Horizontal distance from `p` to a portal's zone box.
static func portal_distance(portal: AreaPortal, p: Vector3) -> float:
	var lp := portal.to_local(p)
	var dx := maxf(absf(lp.x) - portal.zone_size.x * 0.5, 0.0) if portal.auto else absf(lp.x)
	var dz := maxf(absf(lp.z) - portal.zone_size.z * 0.5, 0.0) if portal.auto else absf(lp.z)
	return Vector2(dx, dz).length()

func _scan(dt: float) -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or Game.current_area == null or not is_instance_valid(Game.current_area):
		return
	if p.get("dead") == true:
		return
	var pos: Vector3 = (p as Node3D).global_position
	var want := ""
	var want_d := float(cfg("preload_dist", 70.0))
	var held_d := INF     # to the nearest way into the neighbour already held
	for n in get_tree().get_nodes_in_group("area_portals"):
		var portal := n as AreaPortal
		if portal == null or portal.to_area == "" or not Game.current_area.is_ancestor_of(portal):
			continue
		if not portal._unlocked():
			continue     # a sealed door leads nowhere yet
		if portal.to_area == _left_id and Time.get_ticks_usec() < _left_until_us:
			continue
		var d := portal_distance(portal, pos)
		if _prep != null and portal.to_area == _prep.area_id:
			held_d = minf(held_d, d)
		if d < want_d:
			want_d = d
			want = portal.to_area
	if _prep != null:
		var stale: bool = _prep.built and _prep.flag_sig != _flag_sig(_prep.area_id, _prep.flag_names)
		if want == _prep.area_id and not stale:
			_prep.far_s = 0.0
			return
		# hysteresis: let go only after the Bearer has stayed away a while,
		# or has plainly made for another seam
		if stale:
			_drop_prep()
			return
		if want != "" or held_d > float(cfg("drop_dist", 110.0)):
			_prep.far_s += dt
			var limit := float(cfg("retarget_after_s", 1.5)) if want != "" else float(cfg("drop_after_s", 8.0))
			if _prep.far_s >= limit:
				_drop_prep()
		else:
			_prep.far_s = 0.0
		return
	if want != "" and _dying.is_empty() and _garbage.is_empty() and _orphans.is_empty():
		_start_prep(want)

# ---------------------------------------------------------------- making ready

func _start_prep(area_id: String) -> void:
	var prep := Prep.new()
	prep.area_id = area_id
	prep.t0_us = Time.get_ticks_usec()
	_prep = prep
	BuildLock.worker_busy = true
	prep.task = WorkerThreadPool.add_task(_build_worker.bind(prep), false, "area build " + area_id)

## Worker thread: the whole build, off the tree.
func _build_worker(prep: Prep) -> void:
	var def := DB.area_def(prep.area_id)
	var names: Array = []
	_flag_names(def, names)
	var sig := _flag_sig(prep.area_id, names)
	var t := Time.get_ticks_usec()
	var out := AreaBuilder.build_detached(prep.area_id)
	BuildProf.add(prep.area_id, "worker build (whole)", Time.get_ticks_usec() - t)
	t = Time.get_ticks_usec()
	var held := _preload_actors(def)
	BuildProf.add(prep.area_id, "worker: models read ahead", Time.get_ticks_usec() - t)
	prep.mx.lock()
	prep.preloaded = held
	prep.result = out
	prep.flag_names = names
	prep.flag_sig = sig
	prep.built = true
	prep.mx.unlock()

## The scenes and scripts an area's foes, souls and finds will load when they
## join the tree, loaded here (worker thread) so they are in the resource
## cache by then. Paths come from the same tables the actors read.
static func _preload_actors(def: Dictionary) -> Array:
	var paths := {}
	var models := {}
	var enemies: Dictionary = DB.table("enemies")
	for sp in def.get("spawners", []):
		var id := String(sp.get("enemy", "rimewalker"))
		if not enemies.has(id) and sp.has("stand_in"):
			id = String(sp["stand_in"])
		var ecfg: Dictionary = enemies.get(id, {})
		if ecfg.has("class"):
			paths[String(ecfg["class"])] = true
		if String(ecfg.get("model", "")) != "":
			models[String(ecfg["model"])] = true
	for n in def.get("npcs", []):
		var ncfg: Dictionary = DB.npc(String(n.get("id", "")))
		if String(ncfg.get("model", "")) != "":
			models[String(ncfg["model"])] = true
	for k in def.get("pickups", []):
		if String(k.get("scene", "")) != "":
			paths[String(k["scene"])] = true
	if not models.is_empty():
		# (read here, not through HumanoidLib: its table is the main thread's)
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(HumanoidLib.META_PATH))
		var table: Dictionary = parsed.get("models", {}) if parsed is Dictionary else {}
		for m in models:
			var scene := String((table.get(m, {}) as Dictionary).get("scene", ""))
			if scene != "":
				paths[scene] = true
	var held: Array = []
	for path in paths:
		if ResourceLoader.exists(path):
			var r: Resource = load(path)
			if r != null:
				held.append(r)
	return held

## Every story flag an area def builds by ("require_flag" / "absent_flag").
static func _flag_names(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if (k == "require_flag" or k == "absent_flag") and v[k] is String:
				if not out.has(v[k]):
					out.append(v[k])
			else:
				_flag_names(v[k], out)
	elif v is Array:
		for e in v:
			_flag_names(e, out)

## What the build read of the story: if it reads differently at the seam,
## the neighbour made ready is the wrong one and is built again.
static func _flag_sig(area_id: String, names: Array) -> String:
	var s := "%s|%s|%s" % [World.ended(), World.is_cleared(area_id), World.get_area_state(area_id)]
	for n in names:
		s += "|%s=%s" % [n, World.flag(String(n))]
	return s

func _task_done(prep: Prep) -> bool:
	if prep.task < 0:
		return true
	if not WorkerThreadPool.is_task_completed(prep.task):
		return false
	WorkerThreadPool.wait_for_task_completion(prep.task)
	prep.task = -1
	return true

func _poll_orphans() -> void:
	for i in range(_orphans.size() - 1, -1, -1):
		var o := _orphans[i]
		if _task_done(o):
			_orphans.remove_at(i)
			_bin_result(o.result)
	if _orphans.is_empty() and (_prep == null or _prep.task < 0):
		BuildLock.worker_busy = false

## A built area that will never stand: its loose nodes are freed in slices.
func _bin_result(res: Dictionary) -> void:
	for e in res.get("world", []):
		_garbage.append(e[1])
	for e in res.get("late", []):
		_garbage.append(e[1])
	if res.get("area") != null:
		_garbage.append(res["area"])

func _advance(prep: Prep, t0: int, budget: int) -> void:
	match prep.stage:
		St.BUILD:
			if not _task_done(prep):
				# the worker may be waiting on a RenderingServer read: answer it
				# now and not at the end of the frame
				BuildLock.pump()
				return
			BuildLock.worker_busy = not _orphans.is_empty()
			var res := prep.result
			if res.is_empty() or Game.world_root == null:
				prep.stage = St.FAILED
				return
			var ts := Time.get_ticks_usec()
			prep.area = res["area"]
			prep.world = res["world"]
			prep.late = res["late"]
			prep.area.set_inert(true)
			prep.area.quiet_state(World.get_area_state(prep.area_id))
			Game.world_root.add_child(prep.area)
			prep.stage = St.GRAFT
			BuildProf.slice(prep.area_id, "graft: area root", ts)
		St.GRAFT:
			var ts := Time.get_ticks_usec()
			while prep.wi < prep.world.size():
				var e: Array = prep.world[prep.wi]
				prep.wi += 1
				(e[0] as Node).add_child(e[1])
				if Time.get_ticks_usec() - t0 > budget:
					break
			BuildProf.slice(prep.area_id, "graft: static world", ts)
			if prep.wi >= prep.world.size():
				prep.world = []
				prep.warm_stack = [prep.area]
				for e in prep.late:
					prep.warm_stack.append(e[1])   # what acts draws too
				prep.stage = St.COLLECT
		St.COLLECT:
			var ts := Time.get_ticks_usec()
			var left := maxi(budget - (ts - t0), 500)
			if ShaderWarm.collect(prep.warm_stack, prep.warm_found, left):
				prep.warm_mats = ShaderWarm.materials(prep.warm_found)
				prep.warm_found = {}
				prep.stage = St.WARM
			BuildProf.slice(prep.area_id, "warm: collect materials", ts)
		St.WARM:
			var cam := get_viewport().get_camera_3d()
			var headless := DisplayServer.get_name() == "headless"
			if cam == null or headless or prep.warm_i >= prep.warm_mats.size():
				if prep.warm_holders.is_empty():
					prep.warm_mats = []
					prep.stage = St.READY
					prep.ready_us = Time.get_ticks_usec()
				return
			var ts := Time.get_ticks_usec()
			var n := int(cfg("warm_batch", 32))
			var batch := prep.warm_mats.slice(prep.warm_i, prep.warm_i + n)
			prep.warm_i += n
			var holder := ShaderWarm.draw(cam, batch)
			if holder != null:
				prep.warm_holders.append([holder, int(cfg("warm_frames", 4))])
			BuildProf.slice(prep.area_id, "warm: draw materials", ts)

func _tick_warm() -> void:
	if _prep == null:
		return
	for i in range(_prep.warm_holders.size() - 1, -1, -1):
		var h: Array = _prep.warm_holders[i]
		h[1] = int(h[1]) - 1
		if int(h[1]) <= 0:
			if is_instance_valid(h[0]):
				(h[0] as Node).queue_free()
			_prep.warm_holders.remove_at(i)

## Let the neighbour go (the Bearer walked away, or the story moved on).
func _drop_prep() -> void:
	var prep := _prep
	if prep == null:
		return
	_prep = null
	for h in prep.warm_holders:
		if is_instance_valid(h[0]):
			(h[0] as Node).queue_free()
	if prep.task >= 0:
		_orphans.append(prep)     # the worker cannot be stopped: binned when it ends
		return
	for k in range(prep.wi, prep.world.size()):
		_garbage.append(prep.world[k][1])
	for e in prep.late:
		_garbage.append(e[1])
	if prep.area != null and prep.area.is_inside_tree():
		_dying.append({"root": prep.area, "wait": 1, "stack": []})
	elif not prep.result.is_empty() and prep.area == null:
		_bin_result(prep.result)

## The synchronous AreaBuilder.build is about to run on the main thread: any
## worker build ends first (the builders' statics are one build's at a time).
func yield_to_sync_build() -> void:
	if not BuildLock.worker_busy:
		return
	var tasks: Array = []
	if _prep != null and _prep.task >= 0:
		tasks.append(_prep.task)
	for o in _orphans:
		if o.task >= 0:
			tasks.append(o.task)
	BuildLock.wait_idle(func() -> bool:
		for t in tasks:
			if not WorkerThreadPool.is_task_completed(t):
				return false
		return true)

## Drop everything at once (the return to the title: the world is torn down
## behind its veil, so nothing here needs spreading out).
func reset() -> void:
	_drop_prep()
	yield_to_sync_build()
	_poll_orphans()
	if _nav != null:
		_nav.cancel()
		_nav = null
	for e in _late.slice(_late_i):
		_garbage.append(e[1])
	_late = []
	_late_i = 0
	_held = []
	for d in _dying:
		if is_instance_valid(d["root"]):
			(d["root"] as Node).queue_free()
	_dying = []
	for n in _garbage:
		if is_instance_valid(n):
			(n as Node).free()
	_garbage = []
	_crossing = false
	_cold = false
	_reap_first = false
	_set_fade(0.0)

# ---------------------------------------------------------------- the crossing

## Have `area_id` standing ready (unseen) and the screen black. True when it
## is; false when it could not be built. `fade`: dip to black first (a death
## or the front door is black already).
func prepare(area_id: String, fade := true) -> bool:
	_crossing = true
	crossings += 1
	var t_call := Time.get_ticks_usec()
	var was_ready := _prep != null and _prep.area_id == area_id and _prep.stage == St.READY \
			and _prep.flag_sig == _flag_sig(area_id, _prep.flag_names)
	BuildProf.window_open("crossing:" + area_id)
	last_report = {"area": area_id, "ready_at_call": was_ready, "t_call": t_call}
	if fade:
		await _fade_to(1.0, float(cfg("fade_out_s", 0.12)))
	_cold = true     # behind the black the frame can carry more
	if _prep != null and (_prep.area_id != area_id
			or (_prep.built and _prep.flag_sig != _flag_sig(area_id, _prep.flag_names))):
		_drop_prep()
	# never three areas: what is still being freed goes first
	_reap_first = true
	while _prep == null and not (_dying.is_empty() and _garbage.is_empty() and _orphans.is_empty()):
		await get_tree().process_frame
	_reap_first = false
	if _prep == null:
		_start_prep(area_id)
	while _prep != null and _prep.stage != St.READY and _prep.stage != St.FAILED:
		await get_tree().process_frame
	if _prep == null or _prep.stage == St.FAILED:
		_prep = null
		_end_crossing()
		return false
	if was_ready:
		crossings_ready += 1
	last_report["wait_ms"] = (Time.get_ticks_usec() - t_call) / 1000.0
	return true

## One frame: the area left goes dark and silent, the one made ready becomes
## the world. The caller registers it, snaps its state and places the Bearer.
func swap() -> Area:
	var ts := Time.get_ticks_usec()
	var prep := _prep
	_prep = null
	var next := prep.area
	var old := Game.current_area
	if old != null and is_instance_valid(old) and old != next:
		_left_id = old.area_id
		_left_until_us = Time.get_ticks_usec() + int(float(cfg("recross_cooldown_s", 6.0)) * 1000000.0)
		retire(old)
	next.set_inert(false)
	# the env rig and whatever else hangs off the area's own root first: the
	# state snap that follows needs them
	var rest: Array = []
	for e in prep.late:
		if e[0] == next:
			next.add_child(e[1])
		else:
			rest.append(e)
	_late = rest
	_late_i = 0
	_held = prep.preloaded
	BuildProf.slice(next.area_id, "swap", ts)
	last_report["swap_ms"] = (Time.get_ticks_usec() - ts) / 1000.0
	last_report["prep_ms"] = (prep.ready_us - prep.t0_us) / 1000.0
	return next

## An area being left: out of sight and hearing at once, freed over the next
## frames. Its lights go dark with it (hidden), so the cull has let go of
## them before the first node is freed.
func retire(old: Area) -> void:
	old.set_inert(true)
	for g in LIVE_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if old.is_ancestor_of(n):
				(n as Node).remove_from_group(g)
	for a in old.find_children("*", "AudioStreamPlayer3D", true, false):
		(a as AudioStreamPlayer3D).stop()
	# one WorldEnvironment rules a scene: the old one leaves before the new enters
	if old.env != null and is_instance_valid(old.env) and old.env.get_parent() == old:
		old.remove_child(old.env)
		old.env.queue_free()
	if _nav_area == old and _nav != null:
		_nav.cancel()
		_nav = null
	_dying.append({"root": old, "wait": int(cfg("free_wait_frames", 3)), "stack": []})

## What acts in the new area joins it, a little a frame, and its navmeshes
## are read or baked; returns when the live state's navmesh is in the map.
func settle(area: Area) -> void:
	var t_settle := Time.get_ticks_usec()
	while _late_i < _late.size():
		await get_tree().process_frame     # (never in the swap's own frame)
		_graft_late(area)
	_late = []
	_late_i = 0
	_held = []
	if is_instance_valid(area) and area.is_inside_tree():
		_nav = NavBaker.new(area)
		_nav_area = area
		while _nav != null and not _nav.done():
			_nav.step(int(float(cfg("settle_budget_ms", 8.0)) * 1000.0))
			if not _nav.done():
				await get_tree().process_frame
		if _nav != null and _nav.phase == NavBaker.P.DONE and is_instance_valid(area):
			var ts := Time.get_ticks_usec()
			area.apply_nav(_nav.meshes[0], _nav.meshes[1])
			BuildProf.slice(area.area_id, "nav apply", ts)
			last_report["nav_cache"] = _nav.from_cache.duplicate()
			last_report["nav_bake_ms"] = _nav.bake_ms().duplicate()
		elif is_instance_valid(area) and area.is_inside_tree() and area == Game.current_area:
			area.bake_navmeshes()    # the old way, rather than no navmesh at all
		_nav = null
		_nav_area = null
	last_report["settle_ms"] = (Time.get_ticks_usec() - t_settle) / 1000.0

## The crossing is over (the caller has saved): close the measuring window.
func finish() -> void:
	_end_crossing()

func _end_crossing() -> void:
	var rep := BuildProf.window_close()
	last_report["max_work_ms"] = rep.get("max_work_ms", 0.0)
	last_report["second_work_ms"] = rep.get("second_work_ms", 0.0)
	last_report["work_frames"] = rep.get("work_frames", 0)
	last_report["worst"] = rep.get("worst", {})
	last_report["max_frame_ms"] = rep.get("max_frame_ms", 0.0)
	last_report["sync"] = rep.get("sync", [])
	last_report["total_ms"] = (Time.get_ticks_usec() - int(last_report.get("t_call", Time.get_ticks_usec()))) / 1000.0
	_cold = false
	_crossing = false
	crossing_done.emit(last_report)

## Bring the light back (not awaited by the crossing).
func reveal() -> void:
	_fade_to(0.0, float(cfg("fade_in_s", 0.3)))

func _graft_late(area: Area) -> void:
	var budget := int(float(cfg("settle_budget_ms", 8.0)) * 1000.0)
	var t0 := Time.get_ticks_usec()
	# what a _ready defers (a spawner raising its foe) runs later this frame:
	# stamped on both sides so its cost is booked too, and counted against
	# the budget by what the last ones cost
	_stamp_open.call_deferred()
	_foes_this_frame = 0
	while _late_i < _late.size():
		var e: Array = _late[_late_i]
		_late_i += 1
		if not is_instance_valid(e[0]) or not is_instance_valid(e[1]):
			continue
		# a soul, a hearth, a veil: each builds a model in its _ready, and
		# has a frame to itself
		var heavy: bool = e[1] is NPC or e[1] is Hearthstone or e[1] is FrostVeil
		if heavy and Time.get_ticks_usec() - t0 > 1000:
			_late_i -= 1
			break
		(e[0] as Node).add_child(e[1])
		area.settle_new(e[1], "thaw" if e[0] == area.thaw_layer else ("rime" if e[0] == area.rime_layer else "base"))
		if e[1] is Spawner:
			_foes_this_frame += 1
		if heavy or Time.get_ticks_usec() - t0 + int(_foes_this_frame * _foe_est_ms * 1000.0) > budget:
			break
	BuildProf.slice(area.area_id, "graft: what acts", t0)
	_stamp_close.call_deferred(area.area_id)

func _stamp_open() -> void:
	_stamp_us = Time.get_ticks_usec()

func _stamp_close(scope: String) -> void:
	var us := Time.get_ticks_usec() - _stamp_us
	BuildProf.add(scope, "graft: deferred (foes raised)", us, false)
	if _foes_this_frame > 0:
		_foe_est_ms = lerpf(_foe_est_ms, us / 1000.0 / _foes_this_frame, 0.5)

# ---------------------------------------------------------------- freeing

func _reap(budget: int) -> void:
	if _dying.is_empty() and _garbage.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var scope := "free"
	while not _garbage.is_empty():
		var g = _garbage.pop_back()
		if is_instance_valid(g):
			_free_some(g as Node, t0, budget)
			if is_instance_valid(g):
				_garbage.append(g)     # a big one: more of it next frame
		if Time.get_ticks_usec() - t0 > budget:
			BuildProf.slice(scope, "free: never grafted", t0)
			return
	while not _dying.is_empty():
		var d: Dictionary = _dying[0]
		var root: Node = d["root"]
		if not is_instance_valid(root):
			_dying.pop_front()
			continue
		if int(d["wait"]) > 0:
			d["wait"] = int(d["wait"]) - 1
			break
		_free_some(root, t0, budget)
		if is_instance_valid(root):
			break
		_dying.pop_front()
	BuildProf.slice(scope, "free: old area", t0)

## Free `root` from its leaves in, stopping when the budget is spent. A node
## with many children is entered and emptied; a small subtree goes whole.
func _free_some(root: Node, t0: int, budget: int) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var top: Node = stack[stack.size() - 1]
		var n := top.get_child_count()
		if n == 0:
			stack.pop_back()
			top.free()
		else:
			var c := top.get_child(n - 1)
			if c.get_child_count() > 24:
				stack.append(c)
			else:
				c.free()
		if Time.get_ticks_usec() - t0 > budget:
			return

# ---------------------------------------------------------------- the dead, brought back

## Every spawner (and veil) of the live area respawns, a few a frame. What
## Game used to do in one call_group. Returns when all have.
func respawn_all() -> void:
	var list: Array = []
	for n in get_tree().get_nodes_in_group(RH.GROUP_RESPAWN_ON_REST):
		if not foreign(n):
			list.append(n)
	var budget := int(float(cfg("respawn_budget_ms", 4.0)) * 1000.0)
	var i := 0
	while i < list.size():
		var t0 := Time.get_ticks_usec()
		while i < list.size():
			var n = list[i]
			i += 1
			if is_instance_valid(n) and (n as Node).is_inside_tree():
				n.call("respawn")
			if Time.get_ticks_usec() - t0 > budget:
				break
		BuildProf.slice("respawn", "respawn: foes", t0)
		if i < list.size():
			await get_tree().process_frame

# ---------------------------------------------------------------- the dip to black

func _ensure_fade() -> void:
	if _fade_layer != null:
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 90
	_fade_layer.name = "StreamFade"
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 1)
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)
	add_child(_fade_layer)

func _set_fade(a: float) -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	if _fade_rect != null:
		_fade_rect.modulate.a = a

func _fade_to(a: float, secs: float) -> void:
	_ensure_fade()
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	if secs <= 0.0:
		_fade_rect.modulate.a = a
		return
	var tw := create_tween()
	_fade_tw = tw
	tw.tween_property(_fade_rect, "modulate:a", a, secs)
	# (polled, not awaited on `finished`: a tween killed by the next fade
	# never finishes, and would leave this call waiting for good)
	while tw.is_valid() and tw.is_running():
		await get_tree().process_frame
