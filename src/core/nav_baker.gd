class_name NavBaker
extends RefCounted
## Both navmeshes of an area without a frozen frame (ADR 0014). One job:
##   1. fingerprint: a budgeted walk over every static collider the bake
##      would see (layer, transform, shape), hashed. Whatever a flag, a gate
##      or a lowered bridge changes shows up in it, so it is the cache key.
##   2. cache: each state's NavigationMesh is loaded from user://cache on a
##      worker when the fingerprint is known there.
##   3. miss: the source geometry is parsed in budgeted slices on the main
##      thread (the parser reads the scene tree), baked on NavigationServer's
##      background thread, and written to the cache.
## Streamer calls step(budget) once a frame until done; result is
## [thaw mesh, rime mesh] for Area.apply_nav. Area.bake_navmeshes (the
## synchronous bake) stays as it was for direct builds and runtime re-bakes.

enum P { FINGERPRINT, LOOKUP, LOADING, PARSE, BAKING, DONE, FAILED }

const SLICE_GROUP := "nav_slice"
## Top-level children parsed per slice (a house, a row of props).
const SLICE_NODES := 24

var area: Area
var phase: P = P.FINGERPRINT
var meshes: Array = [null, null]      # [thaw, rime]
var from_cache: Array = [false, false]
var keys: Array = ["", ""]
var fingerprint := 0
var bodies := 0

var _stack: Array[Node] = []
var _shape_h: Dictionary = {}
var _load_task := -1
var _loaded: Array = [null, null]
var _mx := Mutex.new()
var _slices: Array = []               # [[nodes...], layer_index]
var _slice_i := 0
var _slice_state := 0                 # each slice is parsed once per state
var _src: Array = [null, null]
var _baking := 0
var _dead := false

func _init(a: Area) -> void:
	area = a
	_stack = [a]

## The bake settings (Area._bake_nav uses the same).
static func make_mesh(nav_aabb: AABB, rime_world: bool) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.4
	mesh.cell_size = 0.20
	mesh.cell_height = 0.20
	if nav_aabb.size != Vector3.ZERO:
		mesh.filter_baking_aabb = nav_aabb
		mesh.agent_max_slope = 44.0
		# outdoors the biggest walker sets the margin: a 0.7 m Holdfast must
		# not be routed along a 0.4 m hairline past a kerb or a doorpost
		mesh.agent_radius = 0.6
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = "nav_src"
	mesh.geometry_collision_mask = state_mask(rime_world)
	return mesh

static func state_mask(rime_world: bool) -> int:
	return (1 << (RH.L_WORLD_BASE - 1)) \
		| (1 << ((RH.L_WORLD_RIME if rime_world else RH.L_WORLD_THAW) - 1)) \
		| (1 << ((RH.L_NAV_BLOCK_RIME if rime_world else RH.L_NAV_BLOCK_THAW) - 1))

func done() -> bool:
	return phase == P.DONE or phase == P.FAILED

## Stop caring: a job whose area is being left. Background work in flight
## ends on its own and is dropped.
func cancel() -> void:
	_dead = true
	phase = P.FAILED

## One budgeted slice of whatever the job is at. Returns true when done.
func step(budget_us: int) -> bool:
	if _dead or not is_instance_valid(area) or not area.is_inside_tree():
		phase = P.FAILED
		return true
	var t0 := Time.get_ticks_usec()
	match phase:
		P.FINGERPRINT:
			_fingerprint(t0, budget_us)
			BuildProf.slice(area.area_id, "nav fingerprint", t0)
		P.LOOKUP:
			_lookup()
		P.LOADING:
			_poll_load()
		P.PARSE:
			_parse(t0, budget_us)
			BuildProf.slice(area.area_id, "nav parse", t0)
		P.BAKING:
			pass    # the callbacks move it on
	return done()

# ---------------------------------------------------------------- fingerprint

func _fingerprint(t0: int, budget_us: int) -> void:
	var all_mask := state_mask(false) | state_mask(true)
	while not _stack.is_empty():
		var n: Node = _stack.pop_back()
		if n is StaticBody3D:
			var sb := n as StaticBody3D
			var layer: int = int(sb.get_meta("orig_layer")) if sb.has_meta("orig_layer") else sb.collision_layer
			if layer & all_mask:
				bodies += 1
				for c in sb.get_children():
					var cs := c as CollisionShape3D
					if cs == null or cs.disabled or cs.shape == null:
						continue
					# summed, so the order nodes joined the tree in does not matter
					fingerprint = (fingerprint + hash([layer, cs.global_transform, _shape_hash(cs.shape)])) & 0x7fffffffffff
		for c in n.get_children():
			_stack.append(c)
		if Time.get_ticks_usec() - t0 > budget_us:
			return
	phase = P.LOOKUP

func _shape_hash(s: Shape3D) -> int:
	var id := s.get_instance_id()
	if _shape_h.has(id):
		return _shape_h[id]
	var h := 0
	if s is BoxShape3D:
		h = hash([1, (s as BoxShape3D).size])
	elif s is SphereShape3D:
		h = hash([2, (s as SphereShape3D).radius])
	elif s is CapsuleShape3D:
		h = hash([3, (s as CapsuleShape3D).radius, (s as CapsuleShape3D).height])
	elif s is CylinderShape3D:
		h = hash([4, (s as CylinderShape3D).radius, (s as CylinderShape3D).height])
	elif s is ConcavePolygonShape3D:
		h = hash([5, (s as ConcavePolygonShape3D).get_faces()])
	elif s is ConvexPolygonShape3D:
		h = hash([6, (s as ConvexPolygonShape3D).points])
	elif s is HeightMapShape3D:
		var hm := s as HeightMapShape3D
		h = hash([7, hm.map_width, hm.map_depth, hm.map_data])
	else:
		h = hash(s.get_class())
	_shape_h[id] = h
	return h

# ---------------------------------------------------------------- cache

func _lookup() -> void:
	for i in 2:
		keys[i] = StreamCache.key(["nav", area.area_id, fingerprint, bodies, i, area.nav_aabb])
	if StreamCache.has_var("nav", keys[0]) or StreamCache.has_var("nav", keys[1]):
		phase = P.LOADING
		_load_task = WorkerThreadPool.add_task(_load_worker.bind(keys.duplicate(), area.nav_aabb), false, "nav cache read")
	else:
		_begin_parse()

## Worker thread. An entry is the mesh's vertices and polygons, not a saved
## Resource: ResourceLoader would not read the same user:// file twice in
## one run (the second load of a path came back null).
func _load_worker(ks: Array, nav_aabb: AABB) -> void:
	var got: Array = [null, null]
	for i in 2:
		got[i] = unpack(StreamCache.load_var("nav", String(ks[i])), nav_aabb, i == 1)
	_mx.lock()
	_loaded = got
	_mx.unlock()

## {v: vertices, p: [polygon index arrays]} of a baked mesh.
static func pack(mesh: NavigationMesh) -> Dictionary:
	var polys: Array = []
	for i in mesh.get_polygon_count():
		polys.append(mesh.get_polygon(i))
	return {"v": mesh.get_vertices(), "p": polys}

## The mesh a cache entry holds, with this build's bake settings; null when
## the entry is not one (absent, corrupt, empty).
static func unpack(entry: Variant, nav_aabb: AABB, rime_world: bool) -> NavigationMesh:
	if not (entry is Dictionary) or not (entry.get("v") is PackedVector3Array) or not (entry.get("p") is Array):
		return null
	var verts: PackedVector3Array = entry["v"]
	var polys: Array = entry["p"]
	if verts.is_empty() or polys.is_empty():
		return null
	var mesh := make_mesh(nav_aabb, rime_world)
	mesh.vertices = verts
	for poly in polys:
		if not (poly is PackedInt32Array):
			return null
		for idx in poly:
			if idx < 0 or idx >= verts.size():
				return null
		mesh.add_polygon(poly)
	return mesh

static func _store_worker(k: String, mesh: NavigationMesh) -> void:
	StreamCache.store_var("nav", k, pack(mesh))

func _poll_load() -> void:
	if not WorkerThreadPool.is_task_completed(_load_task):
		return
	WorkerThreadPool.wait_for_task_completion(_load_task)
	_load_task = -1
	_mx.lock()
	var got := _loaded
	_mx.unlock()
	for i in 2:
		if got[i] != null:
			meshes[i] = got[i]
			from_cache[i] = true
	if meshes[0] != null and meshes[1] != null:
		phase = P.DONE
	else:
		_begin_parse()

# ---------------------------------------------------------------- parse + bake

func _begin_parse() -> void:
	_slices.clear()
	var li := 0
	for layer in [area.base, area.thaw_layer, area.rime_layer]:
		var run: Array = []
		for c in layer.get_children():
			if c is NavigationRegion3D:
				continue
			if c is Terrain:
				_slices.append([[c], li])     # the heightmap is one piece of work
				continue
			run.append(c)
			if run.size() >= SLICE_NODES:
				_slices.append([run, li])
				run = []
		if not run.is_empty():
			_slices.append([run, li])
		li += 1
	_slice_i = 0
	for i in 2:
		_src[i] = null if meshes[i] != null else NavigationMeshSourceGeometryData3D.new()
	phase = P.PARSE

func _parse(t0: int, budget_us: int) -> void:
	while _slice_i < _slices.size():
		var sl: Array = _slices[_slice_i]
		var si := _slice_state
		_slice_state += 1
		if _slice_state >= 2:
			_slice_state = 0
			_slice_i += 1
		if _src[si] == null:
			continue
		var nodes: Array = sl[0]
		# the heightmap is on the base layer and the same in both states, and
		# its parse is the dearest single step (35 ms headless): parsed once,
		# for both (the next turn of this loop then finds it done)
		if si == 1 and nodes.size() == 1 and nodes[0] is Terrain and _src[0] != null:
			continue
		var both := si == 0 and nodes.size() == 1 and nodes[0] is Terrain and _src[1] != null
		var live: Array = []
		for n in nodes:
			if is_instance_valid(n) and (n as Node).is_inside_tree():
				live.append(n)
				(n as Node).add_to_group(SLICE_GROUP)
		if live.is_empty():
			continue
		# the layer that is put away has its colliders' layer bits zeroed
		# (Area.apply_state): the parser filters on them, so they are given
		# back for the length of this call
		var put_away: bool = (int(sl[1]) == 1 and area._applied == RH.WState.RIME) \
				or (int(sl[1]) == 2 and area._applied == RH.WState.THAW)
		if put_away:
			for n in live:
				area._set_layer_collision(n, true)
		var pm := make_mesh(area.nav_aabb, si == 1)
		pm.geometry_source_group_name = SLICE_GROUP
		var part := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(pm, part, area)
		(_src[si] as NavigationMeshSourceGeometryData3D).merge(part)
		if both:
			(_src[1] as NavigationMeshSourceGeometryData3D).merge(part)
		if put_away:
			for n in live:
				area._set_layer_collision(n, false)
		for n in live:
			(n as Node).remove_from_group(SLICE_GROUP)
		if Time.get_ticks_usec() - t0 > budget_us:
			return
	phase = P.BAKING
	for i in 2:
		if _src[i] == null:
			continue
		_baking += 1
		var mesh := make_mesh(area.nav_aabb, i == 1)
		NavigationServer3D.bake_from_source_geometry_data_async(mesh, _src[i], _baked.bind(i, mesh, Time.get_ticks_usec()))
	if _baking == 0:
		phase = P.DONE

func _baked(i: int, mesh: NavigationMesh, t0: int) -> void:
	_baking -= 1
	_src[i] = null
	if _dead:
		return
	_bake_ms[i] = (Time.get_ticks_usec() - t0) / 1000.0
	meshes[i] = mesh
	# kept for the next visit; written off the main thread
	WorkerThreadPool.add_task(_store_worker.bind(String(keys[i]), mesh), false, "nav cache write")
	if _baking == 0:
		phase = P.DONE

## Wall-clock ms each background bake took (0: from cache).
var _bake_ms: Array = [0.0, 0.0]

func bake_ms() -> Array:
	return _bake_ms
