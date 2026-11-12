extends Node
## PerfTour: real-GPU profiling runner. Boots the real world for one area at
## one state and quality tier, walks the Bearer (and so the gameplay camera)
## through viewpoints taken from the area def, and records frame timings per
## viewpoint. The viewpoints are: start, up to three hearths (looking out from
## the stone), the frost veil, and a high overview (worst case).
## The viewpoints come from data, so new areas need no new code.
## Run (tools/perf_tour.sh does all areas x states x tiers):
##   godot --path . --resolution 1920x1080 -- --sandbox=perf_tour \
##     --area=saltfell_steading --state=rime --perf-quality=1 \
##     --perf-out=/abs/out.json [--perf-shots=/abs/dir] [--perf-secs=5] [--perf-cap=120]
## Frames are capped (default 120) so the owner's PC keeps headroom. Per-frame GPU
## and CPU render times come from RenderingServer's measured times, so the cost
## is still visible under the cap. avg / 1%-low FPS are uncapped-equivalent:
## 1000 / max(cpu_ms, gpu_ms) per frame. Wall-clock hitches (>33 ms) are counted too.

const WORLD := preload("res://scenes/world.tscn")

var _quality := 1
var _out := ""
var _shots := ""
var _secs := 5.0
var _settle := 2.0
var _settle_extra := 0.0   # --perf-settle=N adds N s to every settle
var _cap := 120
var _area_id := ""
var _state := ""
var _census_on := false
var _ablate: PackedStringArray = []   # freeze a class of nodes to price it by difference

var _views: Array = []      # [{name, kind:"player"|"free", pos, yaw | look}]
var _vi := -1
var _phase := ""            # "load" | "settle" | "sample" | "done"
var _t := 0.0
var _last_us := 0
var _samples: Dictionary = {}
var _results: Array = []
var _free_cam: Camera3D = null
var _vp_rid: RID

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-quality="):
			_quality = int(arg.get_slice("=", 1))
		elif arg.begins_with("--perf-out="):
			_out = arg.get_slice("=", 1)
		elif arg.begins_with("--perf-shots="):
			_shots = arg.get_slice("=", 1)
		elif arg.begins_with("--perf-secs="):
			_secs = float(arg.get_slice("=", 1))
		elif arg.begins_with("--perf-cap="):
			_cap = int(arg.get_slice("=", 1))
		elif arg.begins_with("--area="):
			_area_id = arg.get_slice("=", 1)
		elif arg.begins_with("--perf-settle="):
			_settle_extra = float(arg.get_slice("=", 1))
		elif arg == "--perf-census":
			_census_on = true
		elif arg.begins_with("--perf-census-at="):
			var c := arg.get_slice("=", 1).split(",")
			_census_at = Vector3(float(c[0]), float(c[1]), float(c[2]))
			if c.size() > 3:
				_census_r = float(c[3])
		elif arg.begins_with("--perf-ablate="):
			_ablate = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--state="):
			_state = arg.get_slice("=", 1)
	# vsync would pin every reading to the monitor's refresh; the cap leaves headroom
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = _cap
	EnvRig.set_graphics_quality(_quality)
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	add_child(WORLD.instantiate())
	_phase = "load"

func _process(_d: float) -> void:
	match _phase:
		"load":
			# wait for world_root to place the Bearer, then a beat for the area to settle
			if Game.player != null and is_instance_valid(Game.player):
				EnvRig.set_graphics_quality(_quality)   # a saved setting must not win
				_apply_ablation(get_tree().root)
				if _census_on:
					_census(get_tree().root)
				_build_views()
				_next_view()
		"settle":
			_hold_player()
			_t += get_process_delta_time()
			if _t >= _settle:
				_phase = "sample"
				_t = 0.0
				_last_us = Time.get_ticks_usec()
				_samples = {"frame": [], "cpu": [], "gpu": [], "bound": [], "draws": [], "prims": [], "objs": [],
						"proc": [], "phys": [], "rcpu": []}
		"sample":
			_hold_player()
			var now := Time.get_ticks_usec()
			_samples["frame"].append((now - _last_us) / 1000.0)
			_last_us = now
			# main-thread cost: scripts + physics + render submission (physics counted
			# every frame, so this errs high)
			var rcpu := RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) 					+ RenderingServer.get_frame_setup_time_cpu()
			var proc := 1000.0 * Performance.get_monitor(Performance.TIME_PROCESS)
			var phys := 1000.0 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			var cpu := rcpu + proc + phys
			_samples["proc"].append(proc)
			_samples["phys"].append(phys)
			_samples["rcpu"].append(rcpu)
			var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
			_samples["cpu"].append(cpu)
			_samples["gpu"].append(gpu)
			_samples["bound"].append(maxf(cpu, gpu))
			_samples["draws"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			_samples["prims"].append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			_samples["objs"].append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			_t += get_process_delta_time()
			if _t >= _secs:
				_finish_view()
				_next_view()

func _build_views() -> void:
	var area: Node = Game.current_area
	var def: Dictionary = area.get_meta("def")
	var nb: Array = def.get("nav_bounds", [-50, 0, -50, 50, 20, 50])
	var centre := Vector3((nb[0] + nb[3]) * 0.5, 0.0, (nb[2] + nb[5]) * 0.5)
	var st: Dictionary = def.get("start", {})
	_views.append({"name": "start", "kind": "player",
			"pos": AreaBuilder._v3(st.get("pos", [0, 0.2, 0])),
			"yaw": deg_to_rad(float(st.get("yaw", 0)))})
	var hs: Array = def.get("hearths", [])
	var n_hearths := 0
	for hd in hs:
		# flag-gated hearths are not built yet; take the first three that are
		var h = Game.find_hearth(String(hd["id"]))
		if h == null or n_hearths >= 3:
			continue
		n_hearths += 1
		var out_dir: Vector3 = h.global_transform.basis.z
		_views.append({"name": String(hd["id"]), "kind": "player",
				"pos": _clear_spot(h.respawn_point(), out_dir), "yaw": atan2(-out_dir.x, -out_dir.z)})
	var veils: Array = def.get("frost_veils", [])
	if not veils.is_empty():
		var v := AreaBuilder._v3(veils[0]["at"])
		var back := (centre - v)
		back.y = 0.0
		back = back.normalized() * 10.0 if back.length() > 0.1 else Vector3(0, 0, 10)
		var p := v + back
		p.y = maxf(v.y, _ground(area, p)) + 0.6
		_views.append({"name": String(veils[0]["id"]), "kind": "player",
				"pos": p, "yaw": atan2(back.x, back.z)})
	var top := Vector3(centre.x, float(nb[4]) + 12.0, float(nb[5]) + 12.0)
	_views.append({"name": "overview", "kind": "free", "pos": top,
			"look": Vector3(centre.x, float(nb[1]), centre.z)})

## Ablation classes: enemies, npcs, ambient (AmbientLife), weather (Weather
## followers), particles (every CPUParticles3D), and areas' own scripts.
func _apply_ablation(n: Node) -> void:
	if _ablate.is_empty():
		return
	var hit := false
	if "scatter_bodies" in _ablate and n is StaticBody3D and n.is_in_group("scatter_body"):
		(n as StaticBody3D).collision_layer = 0   # price the scatter colliders by difference
		return
	if "areas" in _ablate and n is Area3D:
		(n as Area3D).monitoring = false
		(n as Area3D).monitorable = false
	if "player" in _ablate and n is Player:
		n.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if "bodies" in _ablate and n is CharacterBody3D and not (n is Player):
		n.process_mode = Node.PROCESS_MODE_DISABLED
		return
	if "casts" in _ablate and (n is RayCast3D or n is ShapeCast3D):
		n.set("enabled", false)
	if "camera_arm" in _ablate and n is SpringArm3D:
		(n as SpringArm3D).collision_mask = 0
	if "enemies" in _ablate and (n is Enemy):
		hit = true
	elif "npcs" in _ablate and (n is NPC):
		hit = true
	elif "ambient" in _ablate and (n is AmbientLife):
		hit = true
	elif "weather" in _ablate and (n is Weather):
		hit = true
	elif "particles" in _ablate and (n is CPUParticles3D or n is GPUParticles3D):
		hit = true
	else:
		var sc: Script = n.get_script()
		if sc != null:
			for a in _ablate:
				if a.begins_with("script:") and sc.resource_path.contains(a.substr(7)):
					hit = true
	if hit:
		n.process_mode = Node.PROCESS_MODE_DISABLED
		return
	for c in n.get_children():
		_apply_ablation(c)

## --perf-census: print how many nodes of each script process per frame, so
## script time can be priced by script ("--perf-ablate=script:<path part>").
func _census(root: Node) -> void:
	_area_census(root)
	_hearth_census()
	var counts := {}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n.is_processing() or n.is_physics_processing()):
			continue
		var sc: Script = n.get_script()
		var key := sc.resource_path if sc != null else n.get_class()
		counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b])
	for k in keys:
		print("[census] %5d  %s" % [counts[k], k])
	_mesh_census(root)

## Triangles drawn per mesh resource within _census_r of _census_at (LOD 0,
## before culling): finds the asset behind a primitive spike.
var _census_at := Vector3.INF
var _census_r := 80.0

func _mesh_census(root: Node) -> void:
	if _census_at == Vector3.INF:
		return
	var tris := {}
	var inst := {}
	var cache := {}
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi.global_position.distance_to(_census_at) > _census_r:
			continue
		var mesh: Mesh = null
		var count := 1
		if gi is MeshInstance3D:
			mesh = (gi as MeshInstance3D).mesh
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh != null:
			var mm := (gi as MultiMeshInstance3D).multimesh
			mesh = mm.mesh
			count = mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if mesh == null:
			continue
		var key := mesh.resource_path if mesh.resource_path != "" else "%s:%s" % [gi.get_parent().name, gi.name]
		if not cache.has(mesh):
			cache[mesh] = mesh.get_faces().size() / 3
		tris[key] = int(tris.get(key, 0)) + int(cache[mesh]) * count
		inst[key] = int(inst.get(key, 0)) + count
	var keys := tris.keys()
	keys.sort_custom(func(a, b): return tris[a] > tris[b])
	for k in keys.slice(0, 20):
		print("[meshes] %8dk tris  %5d inst  %s" % [tris[k] / 1000, inst[k], k])

func _ground(area: Node, p: Vector3) -> float:
	var terr = area.get("terrain")
	if terr != null:
		return terr.height_at(p.x, p.z)
	return p.y

func _next_view() -> void:
	_vi += 1
	if _vi >= _views.size():
		_write()
		_phase = "done"
		AudioDirector.shutdown()
		get_tree().quit()
		return
	var v: Dictionary = _views[_vi]
	if v["kind"] == "free":
		if _free_cam == null:
			_free_cam = Camera3D.new()
			_free_cam.fov = 62.0
			_free_cam.far = 4000.0
			add_child(_free_cam)
		_free_cam.global_position = v["pos"]
		_free_cam.look_at(v["look"], Vector3.UP)
		_free_cam.current = true
	_hold_player()
	_phase = "settle"
	# the first view also eats shader/pipeline compiles; give it longer
	_settle = (4.0 if _vi == 0 else 2.0) + _settle_extra
	_t = 0.0

## Pin the Bearer to the viewpoint, unhurtable, so the gameplay camera frames it.
func _hold_player() -> void:
	var pl = Game.player
	if pl == null or not is_instance_valid(pl):
		return
	if pl.hurtbox != null:
		pl.hurtbox.monitorable = false
		pl.hurtbox.monitoring = false
	var v: Dictionary = _views[_vi]
	if v["kind"] == "player":
		pl.global_position = v["pos"]
		pl.velocity = Vector3.ZERO
		pl.cam.yaw = v["yaw"]

func _finish_view() -> void:
	var v: Dictionary = _views[_vi]
	var fr: Array = _samples["frame"]
	var res := {
		"area": _area_id, "state": _state, "quality": _quality, "view": v["name"],
		"frames": fr.size(),
		# uncapped-equivalent: what the frame costs, not what the limiter allowed
		"avg_fps": 1000.0 / maxf(_mean(_samples["bound"]), 0.01),
		"low1_fps": 1000.0 / maxf(_pct(_samples["bound"], 0.99), 0.01),
		# wall clock under the cap: only hitches show here
		"wall_avg_fps": 1000.0 / _mean(fr),
		"wall_ms_max": _pct(fr, 1.0),
		"hitches_33ms": fr.filter(func(x): return float(x) > 33.3).size(),
		"cpu_ms": _mean(_samples["cpu"]),
		"proc_ms": _mean(_samples["proc"]),
		"phys_ms": _mean(_samples["phys"]),
		"rcpu_ms": _mean(_samples["rcpu"]),
		"ablate": ",".join(_ablate),
		"gpu_ms": _mean(_samples["gpu"]),
		"gpu_ms_p99": _pct(_samples["gpu"], 0.99),
		"draws": _mean(_samples["draws"]),
		"prims": _mean(_samples["prims"]),
		"objects": _mean(_samples["objs"]),
		"vram_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"tex_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"buf_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0,
		"cam": _cam_pos(),
	}
	_results.append(res)
	print("[perf] %s %s q%d %-16s avg %.0f  1%%low %.0f  hitch %d  gpu %.2fms  cpu %.2fms (proc %.2f phys %.2f rend %.2f)  draws %.0f  prims %.0fk  vram %.0fMB" % [
			_area_id, _state, _quality, v["name"], res["avg_fps"], res["low1_fps"], res["hitches_33ms"],
			res["gpu_ms"], res["cpu_ms"], res["proc_ms"], res["phys_ms"], res["rcpu_ms"], res["draws"], res["prims"] / 1000.0, res["vram_mb"]])
	if _shots != "":
		var img := get_viewport().get_texture().get_image()
		img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
		DirAccess.make_dir_recursive_absolute(_shots)
		img.save_png("%s/%s_%s_q%d_%s.png" % [_shots, _area_id, _state, _quality, v["name"]])

func _cam_pos() -> Array:
	var c := get_viewport().get_camera_3d()
	if c == null:
		return []
	var p := c.global_position
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]

func _write() -> void:
	if _out == "":
		return
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var f := FileAccess.open(_out, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_video_adapter_api_version(),
		"cpu": OS.get_processor_name(),
		"os": OS.get_name() + " " + OS.get_version(),
		"resolution": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"cap": _cap, "secs": _secs,
		"results": _results}, "  "))

static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / a.size()

## q-th percentile (0..1) by nearest rank: frame_ms at 0.99 is the 1%-low frame
static func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[clampi(int(ceil(q * s.size())) - 1, 0, s.size() - 1)])


## --perf-census: every monitoring Area3D whose mask takes the scatter
## colliders' layers, with how many scatter hulls its shapes overlap. A static
## volume monitors static bodies too, every physics step.
func _area_census(root: Node) -> void:
	var smask := 0
	var bodies: Array = get_tree().get_nodes_in_group("scatter_body")
	for b in bodies:
		smask |= (b as StaticBody3D).collision_layer
	var rows := {}
	for a in root.find_children("*", "Area3D", true, false):
		var ar := a as Area3D
		if not ar.monitoring or (ar.collision_mask & smask) == 0:
			continue
		var aabb := AABB()
		var first := true
		for cs in ar.find_children("*", "CollisionShape3D", false, false):
			var sh := (cs as CollisionShape3D).shape
			if sh == null:
				continue
			var bb := (cs as CollisionShape3D).global_transform * sh.get_debug_mesh().get_aabb()
			aabb = bb if first else aabb.merge(bb)
			first = false
		var hits := 0
		for b in bodies:
			if aabb.has_point((b as Node3D).global_position):
				hits += 1
		var sc: Script = ar.get_script()
		var key := "%s (%s)" % [sc.resource_path.get_file() if sc != null else "Area3D", ar.get_parent().name]
		var r: Array = rows.get(key, [0, 0, Vector3.ZERO])
		rows[key] = [int(r[0]) + 1, int(r[1]) + hits, aabb.size if aabb.size.length() > (r[2] as Vector3).length() else r[2]]
	var keys := rows.keys()
	keys.sort_custom(func(x, y): return rows[x][1] > rows[y][1])
	print("[areas] %d scatter bodies, mask %d" % [bodies.size(), smask])
	for k in keys:
		print("[areas] %4d areas  %5d hulls inside  largest %s  %s" % [rows[k][0], rows[k][1], rows[k][2], k])


## --perf-census: does a Bearer's capsule overlap anything solid where the
## game respawns him at each hearth (respawn_point) and where the tour pins
## him (2 m further out)? A capsule held inside a convex hull costs the
## physics server milliseconds a tick.
func _hearth_census() -> void:
	var space := get_viewport().get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Game.player.collision_mask if Game.player != null else 1
	if Game.player != null:
		q.exclude = [Game.player.get_rid()]
	for hd in DB.area_def(Game.current_area_id).get("hearths", []):
		var h = Game.find_hearth(String(hd["id"]))
		if h == null:
			continue
		var out_dir: Vector3 = h.global_transform.basis.z
		for tag in ["respawn", "tour"]:
			var p: Vector3 = h.respawn_point() + (out_dir * 2.0 if tag == "tour" else Vector3.ZERO)
			q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 0.95, 0))
			var hits := space.intersect_shape(q, 8)
			var names := []
			for r in hits:
				var c = r["collider"]
				names.append("%s%s" % [c.name, " [scatter]" if c is Node and (c as Node).is_in_group("scatter_body") else ""])
			print("[hearth] %-18s %-7s at %s overlaps %d %s" % [hd["id"], tag, p, hits.size(), names])


## Where the tour stands the Bearer at a hearth: 2 m out from its respawn
## point, stepped further out until his capsule is clear of every solid but
## the ground. _hold_player pins him there every frame, and a capsule held
## inside a convex hull made the physics server work milliseconds a tick
## (Lowe's hs_drying_stacks, inside a peat stack: 16 ms of physics, the whole
## of the "Lowe physics" regression). Falls back to the respawn point.
func _clear_spot(rp: Vector3, out_dir: Vector3) -> Vector3:
	var space := get_viewport().get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Game.player.collision_mask if Game.player != null else 1
	if Game.player != null:
		q.exclude = [Game.player.get_rid()]
	for d in [2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 0.0]:
		var p := rp + out_dir * d
		q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.0, 0))   # lifted clear of the ground it stands on
		var solid := false
		for r in space.intersect_shape(q, 8):
			if not (r["collider"] is Node and String((r["collider"] as Node).name) == "TerrainBody"):
				solid = true
		if not solid:
			return p
	return rp
