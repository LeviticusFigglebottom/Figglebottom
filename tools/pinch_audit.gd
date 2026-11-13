extends Node
## Pinch-gap audit (tools/audit_pinch.sh): in every area, in THAW and in RIME, every pair of solid bodies whose
## footprints stand closer than the Bearer's capsule (0.68 m) but do not touch. A capsule rolled or pushed into
## such a gap can wedge (the Longhouse table/column, fullslice seed 5). Each body's footprint is its collider
## above step height (0.35 m over its own foot), projected on the ground: convex shapes as polygons, trimeshes
## triangle by triangle. A gap counts as "on a route" when the navmesh reaches within 1 m of it and it lies within
## 2 m of a navmesh path from the area's start to one of its hearths, portals, pickups or gates.
##   --areas=a,b   only these   --out=/abs/path.json   every gap as JSON
const CAPSULE_D := 0.68
const MIN_GAP := 0.02
const STEP := 0.35
const REACH := 1.0
const ROUTE := 2.0
const CELL := 2.0

var _out: Array = []

func _ready() -> void:
	_run.call_deferred()

func _arg(name: String, def := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.get_slice("=", 1)
	return def

func _run() -> void:
	var ids: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/index.json")) as Dictionary)["areas"]
	var only := _arg("areas")
	if only != "":
		ids = Array(only.split(","))
	for id in ids:
		for st in [RH.WState.THAW, RH.WState.RIME]:
			await _audit(String(id), st)
	var path := _arg("out")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_out, " "))
	var on_route := _out.filter(func(g): return g["route"])
	print("PINCH total %d gaps, %d on a route" % [_out.size(), on_route.size()])
	AudioDirector.shutdown()
	get_tree().quit(0)

func _audit(id: String, st: int) -> void:
	World.reset()
	World.set_area_state(id, st)
	var area: Area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	StateDirector.snap(area, st)
	# the build bakes on the next frame (deferred): wait for its regions, then for the map to take them
	var waited := 0
	while (area.nav_thaw == null or area.nav_rime == null or area.nav_pending) and waited < 1200:
		await get_tree().physics_frame
		waited += 1
	StateDirector.snap(area, st)      # (the regions are made disabled; the state turns its own on)
	var map0 := area.get_world_3d().navigation_map
	var probe := Vector3.ZERO
	for i in 600:     # until the map answers near the start (the first build of a session takes longer)
		await get_tree().physics_frame
		probe = NavigationServer3D.map_get_closest_point(map0, _start(area))
		if probe.distance_to(_start(area)) < 3.0:
			break
	print("NAV %s %s start %s -> %s" % [id, "rime" if st == RH.WState.RIME else "thaw", str(_start(area)), str(probe)])
	var mask := (1 << (RH.L_WORLD_BASE - 1)) | (1 << ((RH.L_WORLD_RIME if st == RH.WState.RIME else RH.L_WORLD_THAW) - 1)) \
			| (1 << (RH.L_WORLD_LOW - 1))
	var items: Array = []     # [body_index, PackedVector2Array polygon (>= 2 points), Rect2, y0, y1]
	var bodies: Array = []
	for b in area.find_children("*", "StaticBody3D", true, false):
		var body := b as StaticBody3D
		if body.collision_layer & mask == 0 or not body.is_inside_tree() or _is_ground(body):
			continue
		var bi := bodies.size()
		bodies.append(body)
		for cs in body.get_children():
			if not cs is CollisionShape3D or (cs as CollisionShape3D).disabled:
				continue
			_footprints(cs as CollisionShape3D, bi, items)
	# grid
	var grid := {}
	for k in items.size():
		var r: Rect2 = items[k][2]
		for gx in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
			for gz in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
				var key := Vector2i(gx, gz)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(k)
	var best := {}     # "bi|bj" -> [d, mid3]
	var touching := {}   # pairs that meet somewhere: one piece of furniture (a table at the wall), not a gap
	for key in grid:
		var cell: Array = grid[key]
		for a in cell.size():
			for c in range(a + 1, cell.size()):
				var A: Array = items[cell[a]]
				var B: Array = items[cell[c]]
				if A[0] == B[0]:
					continue
				if A[4] < B[3] or B[4] < A[3]:    # no common height band
					continue
				if not (A[2] as Rect2).grow(CAPSULE_D).intersects(B[2]):
					continue
				var res := _poly_dist(A[1], B[1])
				var d: float = res[0]
				var pk := "%d|%d" % [mini(A[0], B[0]), maxi(A[0], B[0])]
				if d <= MIN_GAP:
					touching[pk] = true
					continue
				if d >= CAPSULE_D:
					continue
				var y := maxf(A[3], B[3])
				if not best.has(pk) or d < best[pk][0]:
					best[pk] = [d, Vector3(res[1].x, y, res[1].y)]
	var map := area.get_world_3d().navigation_map
	var routes := _routes(area, map)
	for pk in best:
		if touching.has(pk):
			continue
		var bi := int(pk.get_slice("|", 0))
		var bj := int(pk.get_slice("|", 1))
		var d: float = best[pk][0]
		var mid: Vector3 = best[pk][1]
		var near := NavigationServer3D.map_get_closest_point(map, mid)
		var reach := Vector2(near.x - mid.x, near.z - mid.z).length() <= REACH and absf(near.y - mid.y) < 1.5
		var on_route := reach and _near_routes(mid, routes)
		var g := {"area": id, "state": "rime" if st == RH.WState.RIME else "thaw", "gap": snappedf(d, 0.001),
			"at": [snappedf(mid.x, 0.01), snappedf(mid.y, 0.01), snappedf(mid.z, 0.01)],
			"a": _name(bodies[bi]), "b": _name(bodies[bj]), "reach": reach, "route": on_route}
		_out.append(g)
		print("GAP %-18s %-4s %.3f m at (%7.2f, %6.2f, %7.2f)  %s | %s%s" % [id, g["state"], d, mid.x, mid.y, mid.z,
			g["a"], g["b"], ("  ROUTE" if on_route else ("  reach" if reach else ""))])
	area.queue_free()
	for i in 3:
		await get_tree().process_frame

func _is_ground(body: Node) -> bool:
	var n := body
	while n != null:
		if n.name == "Terrain" or n is Terrain:
			return true
		n = n.get_parent()
	return false

func _name(body: Node) -> String:
	var n := body
	while n != null and not n.has_meta("kit_id"):
		n = n.get_parent()
		if n is Area:
			break
	if n != null and n.has_meta("kit_id"):
		var p := (n as Node3D).global_position
		return "%s@(%.1f,%.1f)" % [n.get_meta("kit_id"), p.x, p.z]
	var q := (body as Node3D).global_position
	var mesh := body.get_parent()
	var owner_n := mesh.get_parent() if mesh != null else null
	return "%s/%s/%s@(%.1f,%.1f)" % [String(owner_n.name) if owner_n else "?", String(mesh.name), String(body.name), q.x, q.z]

## Footprint polygons of one collision shape, at least STEP above its own foot.
func _footprints(cs: CollisionShape3D, bi: int, items: Array) -> void:
	var xf := cs.global_transform
	var sh := cs.shape
	var pts := PackedVector3Array()
	if sh is ConvexPolygonShape3D:
		pts = (sh as ConvexPolygonShape3D).points
	elif sh is BoxShape3D:
		var e := (sh as BoxShape3D).size * 0.5
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					pts.append(Vector3(e.x * sx, e.y * sy, e.z * sz))
	elif sh is CylinderShape3D or sh is CapsuleShape3D:
		var r: float = sh.radius
		var h: float = sh.height * 0.5
		for k in 12:
			var a := TAU * k / 12.0
			pts.append(Vector3(cos(a) * r, -h, sin(a) * r))
			pts.append(Vector3(cos(a) * r, h, sin(a) * r))
	elif sh is ConcavePolygonShape3D:
		var faces := (sh as ConcavePolygonShape3D).get_faces()
		var w := PackedVector3Array()
		for f in faces:
			w.append(xf * f)
		var y0 := INF
		for p in w:
			y0 = minf(y0, p.y)
		for t in range(0, w.size() - 2, 3):
			var tri := [w[t], w[t + 1], w[t + 2]]
			var ty1 := maxf(tri[0].y, maxf(tri[1].y, tri[2].y))
			var ty0 := minf(tri[0].y, minf(tri[1].y, tri[2].y))
			if ty1 - y0 < STEP or ty0 - y0 > 2.2:   # a floor or step, or wholly overhead
				continue
			var poly := PackedVector2Array([Vector2(tri[0].x, tri[0].z), Vector2(tri[1].x, tri[1].z), Vector2(tri[2].x, tri[2].z)])
			items.append([bi, poly, _rect(poly), y0, ty1])
		return
	if pts.is_empty():
		return
	var w2 := PackedVector3Array()
	var lo := INF
	var hi := -INF
	for p in pts:
		var q := xf * p
		w2.append(q)
		lo = minf(lo, q.y)
		hi = maxf(hi, q.y)
	if hi - lo < STEP:
		return     # steppable
	var flat := PackedVector2Array()
	for q in w2:
		flat.append(Vector2(q.x, q.z))   # a convex body is a prism over its outline
	var hull := Geometry2D.convex_hull(flat)
	if hull.size() < 2:
		return
	items.append([bi, hull, _rect(hull), lo, hi])

func _rect(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

## [min distance, closest midpoint] between two polygons (or segments); 0 when they overlap.
func _poly_dist(a: PackedVector2Array, b: PackedVector2Array) -> Array:
	if a.size() >= 3 and b.size() >= 3 and not Geometry2D.intersect_polygons(a, b).is_empty():
		return [0.0, a[0]]
	if a.size() >= 3 and Geometry2D.is_point_in_polygon(b[0], a):
		return [0.0, b[0]]
	if b.size() >= 3 and Geometry2D.is_point_in_polygon(a[0], b):
		return [0.0, a[0]]
	var best := INF
	var mid := Vector2.ZERO
	for i in a.size():
		var a0 := a[i]
		var a1 := a[(i + 1) % a.size()]
		for j in b.size():
			var b0 := b[j]
			var b1 := b[(j + 1) % b.size()]
			var cp := Geometry2D.get_closest_points_between_segments(a0, a1, b0, b1)
			var d := cp[0].distance_to(cp[1])
			if d < best:
				best = d
				mid = (cp[0] + cp[1]) * 0.5
	return [best, mid]

func _start(area: Area) -> Vector3:
	var def: Dictionary = area.get_meta("def", {})
	if def.has("start"):
		var sp: Array = (def["start"] as Dictionary).get("pos", [0, 0, 0])
		return Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
	return Vector3.ZERO

## Navmesh paths from the start to every hearth, portal, pickup and gate.
func _routes(area: Area, map: RID) -> Array:
	var def: Dictionary = area.get_meta("def", {})
	var from := _start(area)
	var goals: Array = []
	for key in ["hearths", "portals", "pickups", "gates"]:
		for e in def.get(key, []):
			var at = (e as Dictionary).get("at", (e as Dictionary).get("pos", null))
			if at is Array and (at as Array).size() >= 3:
				goals.append(Vector3(float(at[0]), float(at[1]), float(at[2])))
	var paths: Array = []
	for g in goals:
		var p := NavigationServer3D.map_get_path(map, from, g, true)
		if p.size() >= 2:
			paths.append(p)
	return paths

func _near_routes(at: Vector3, routes: Array) -> bool:
	var q := Vector2(at.x, at.z)
	for p in routes:
		var path: PackedVector3Array = p
		for i in path.size() - 1:
			var cp := Geometry2D.get_closest_point_to_segment(q, Vector2(path[i].x, path[i].z), Vector2(path[i + 1].x, path[i + 1].z))
			if cp.distance_to(q) <= ROUTE:
				return true
	return false
