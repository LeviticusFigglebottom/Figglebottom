extends TestBase
## Collision audit (docs/qa/COLLISION_AUDIT.md). Builds every area in THAW
## and RIME, and again with its release flags set, then compares what is
## DRAWN with what is SOLID:
##   1. walk_through / partial: a visible mesh at body height beside walkable
##      ground with no collider in it (or one far smaller than it)
##   2. everything on the allow-list (data/collision_audit.json) is skipped
##   3. terrain and floors: void / terrain_collider / floating /
##      unbacked_floor columns over the playable footprint, plus spawn points,
##      door thresholds, deck ends and the seams to the neighbouring areas
##   4. invisible: a primitive collider at body height with nothing drawn
## Offenders are compared against tools/test/fixtures/collision_baseline.json:
## a known one (it has an owner there) does not fail the suite, a new one does.
##
## Args (after --): --areas=a,b   --collision-out=/abs/file.json
##                  --update-baseline

const CFG_PATH := "res://data/collision_audit.json"
const BASELINE_PATH := "res://tools/test/fixtures/collision_baseline.json"
## spare physics layers for the audit's copies of the drawn meshes
const L_VIS := 21      # solid-looking geometry
const L_SOFT := 22     # water and ice sheets: drawn, but never a "floor mesh"
const VIS_MASK := 1 << (L_VIS - 1)
const SOFT_MASK := 1 << (L_SOFT - 1)

var cfg: Dictionary = {}
var T: Dictionary = {}
var area: Area
var def: Dictionary
var space: PhysicsDirectSpaceState3D
var solid_mask := 0
var terrain: Terrain
var terrain_rid: RID
var proxy_root: Node3D
var proxies: Array = []          # [geometry node, proxy body, layer bits]
var reach: Dictionary = {}       # Vector2i (1 m cell) -> PackedFloat32Array of walkable heights
var pass_name := ""
var findings: Array = []         # this pass
var merged: Dictionary = {}      # key -> finding (all passes of all areas)
var counts: Dictionary = {}      # area -> pass -> check -> n
var stats: Dictionary = {}
var _info_cache: Dictionary = {}
var _sample_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _sphere := SphereShape3D.new()
var _sq := PhysicsShapeQueryParameters3D.new()
var _labels: Dictionary = {}     # rounded centre -> "blocker#3" etc
var _re_auto := RegEx.new()
var _re_num := RegEx.new()
var unaudited: Dictionary = {}   # MultiMesh ids with no readable transforms -> instances
var _incoming: Dictionary = {}   # area id -> [[from, spawn Vector3]]

func _ready() -> void:
	_run.call_deferred()

func _arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.get_slice("=", 1)
		if a == "--" + name:
			return "1"
	return ""

func _run() -> void:
	var t_all := Time.get_ticks_msec()
	cfg = JSON.parse_string(FileAccess.get_file_as_string(CFG_PATH))
	T = cfg["thresholds"]
	_re_auto.compile("@?(\\w+?)@\\d+")
	_re_num.compile("_-?\\d+")
	var ids: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/index.json"))["areas"]
	for id in ids:
		for p in DB.area_def(id).get("portals", []):
			var to := String(p.get("to", ""))
			if not _incoming.has(to):
				_incoming[to] = []
			_incoming[to].append([id, AreaBuilder._v3(p.get("spawn", [0, 0, 0]))])
	if _arg("areas") != "":
		ids = Array(_arg("areas").split(","))
	var times := {}
	for id in ids:
		var t0 := Time.get_ticks_msec()
		await _audit_area(String(id))
		times[id] = (Time.get_ticks_msec() - t0) / 1000.0
	var total_s := (Time.get_ticks_msec() - t_all) / 1000.0
	_report(ids, times, total_s)
	finish()

# ------------------------------------------------------------------ passes

func _flags_in(o, out: Dictionary) -> void:
	if o is Dictionary:
		for k in ["require_flag", "absent_flag"]:
			if o.has(k):
				out[String(o[k])] = true
		for v in o.values():
			_flags_in(v, out)
	elif o is Array:
		for v in o:
			_flags_in(v, out)

func _audit_area(id: String) -> void:
	print("== ", id)
	var d := DB.area_def(id)
	var fl := {}
	_flags_in(d, fl)
	var rel: Array = []
	for f in fl:
		if not String(f).begins_with("ending_"):
			rel.append(f)
	for f in cfg.get("release_also", {}).get(id, []):
		rel.append(f)
	rel.sort()
	var builds: Array = [{"name": "", "flags": [], "states": [RH.WState.THAW, RIME()]}]
	if not rel.is_empty():
		builds.append({"name": "released", "flags": rel, "states": [RH.WState.THAW, RIME()]})
	if fl.has("ending_outsong"):
		# after the Outsong nothing turns any more: unfrozen ground only
		builds.append({"name": "spring", "flags": rel + ["ending_outsong"], "states": [RH.WState.THAW]})
	counts[id] = {}
	for b in builds:
		World.reset()
		Game.set_warmth(0)
		for f in b["flags"]:
			World.set_flag(String(f))
		area = AreaBuilder.build(id)
		check(area != null, "%s builds%s" % [id, "" if b["name"] == "" else " (" + b["name"] + ")"])
		if area == null:
			continue
		add_child(area)
		Game.register_area(area, id)
		# the living flock ambles (FlockWander): hold it still, or the same
		# ewe is a different offender every pass
		var fw := area.find_child("FlockWander", true, false)
		if fw != null:
			fw.process_mode = Node.PROCESS_MODE_DISABLED
		def = area.get_meta("def")
		terrain = area.terrain
		terrain_rid = RID()
		if terrain != null:
			var tb := terrain.get_node_or_null("TerrainBody") as StaticBody3D
			if tb != null:
				terrain_rid = tb.get_rid()
		await ticks(3)
		space = area.get_world_3d().direct_space_state
		_info_cache.clear()
		var canary: bool = not _canary_done and b["name"] == ""
		if canary:
			_plant_canaries()
			await ticks(2)
		_label_bodies()
		_build_proxies()
		for st in b["states"]:
			pass_name = ("thaw" if st == RH.WState.THAW else "rime") + ("" if b["name"] == "" else "+" + b["name"])
			# apply_state directly: after the Outsong World refuses to turn
			StateDirector.snap(area, st)
			_sync_proxies()
			await ticks(3)
			solid_mask = (1 << (RH.L_WORLD_BASE - 1)) | (1 << (RH.L_WORLD_LOW - 1)) \
				| (1 << ((RH.L_WORLD_RIME if st == RIME() else RH.L_WORLD_THAW) - 1))
			findings = []
			var t0 := Time.get_ticks_msec()
			_build_reach(area.nav_rime if st == RIME() else area.nav_thaw)
			if b["name"] == "" and st == RH.WState.THAW:
				_terrain_truth()
				_seams(id)
			_check_meshes()
			_check_invisible()
			_check_columns()
			_check_spots(id)
			_check_doors()
			_check_decks(st)
			if canary and st == RH.WState.THAW:
				_reap_canaries()
			var c := {}
			for f in findings:
				if String(f["id"]).contains("AuditCanary"):
					continue
				c[f["check"]] = int(c.get(f["check"], 0)) + 1
				_merge(id, f)
			counts[id][pass_name] = c
			print("  -- %s: %d findings %s, %d reach cells (%.1fs)" % [pass_name, findings.size(), str(c), reach.size(),
				(Time.get_ticks_msec() - t0) / 1000.0])
		proxy_root.queue_free()
		proxies.clear()
		RH.quench_lights(area)
		area.retire()
		await ticks(2)
		area.queue_free()
		area = null
		await ticks(3)
		_sample_cache.clear()
		_shape_cache.clear()

## The audit audits itself: three planted defects by the start of the first
## area (a box with no collider, a collider with no mesh, boards drawn 0.7 m
## over the ground with nothing under them) must each be found.
var _canary_done := false

func _plant_canaries() -> void:
	_canary_done = true
	var st := AreaBuilder._v3(def.get("start", {}).get("pos", [0, 0, 0]))
	var spots := [st + Vector3(3, 0, 0), st + Vector3(-3, 0, 0), st + Vector3(0, 0, 4)]
	for i in 3:
		var p: Vector3 = spots[i]
		if terrain != null:
			p.y = terrain.height_at(p.x, p.z)
		spots[i] = p
	var mi := MeshInstance3D.new()
	mi.name = "AuditCanaryMesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 1.6, 1.0)
	mi.mesh = bm
	mi.position = spots[0] + Vector3(0, 0.8, 0)
	area.base.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "AuditCanaryWall"
	body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.2, 1.6, 1.2)
	cs.shape = bx
	body.add_child(cs)
	body.position = spots[1] + Vector3(0, 0.8, 0)
	area.base.add_child(body)
	var fl := MeshInstance3D.new()
	fl.name = "AuditCanaryFloor"
	var fm := BoxMesh.new()
	fm.size = Vector3(3.2, 0.1, 3.2)
	fl.mesh = fm
	fl.position = spots[2] + Vector3(0, 0.7, 0)
	area.base.add_child(fl)

func _reap_canaries() -> void:
	var got := {}
	for f in findings:
		if String(f["id"]).contains("AuditCanary"):
			got[String(f["check"]) + ":" + String(f["id"])] = true
	check(got.has("walk_through:node:AuditCanaryMesh"), "self-test: a planted mesh with no collider is found")
	check(got.has("invisible:node:AuditCanaryWall"), "self-test: a planted collider with nothing drawn is found")
	check(got.has("unbacked_floor:node:AuditCanaryFloor"), "self-test: planted boards with no collider under them are found")
	if got.size() < 3:
		print("  (canary findings: %s)" % str(got.keys()))

static func RIME() -> RH.WState:
	return RH.WState.RIME

func _merge(id: String, f: Dictionary) -> void:
	var p: Vector3 = f["pos"]
	var key := "%s|%s|%s|%d,%d,%d" % [id, f["check"], f["id"], roundi(p.x), roundi(p.y), roundi(p.z)]
	if merged.has(key):
		var m: Dictionary = merged[key]
		if not (pass_name in m["passes"]):
			m["passes"].append(pass_name)
		return
	f["area"] = id
	f["passes"] = [pass_name]
	merged[key] = f

func _add(chk: String, ident: String, pos: Vector3, size: Vector3, detail: String, path := "") -> void:
	findings.append({"check": chk, "id": ident, "pos": pos, "size": size, "detail": detail, "path": path})

# ------------------------------------------------------------------ identity and the allow-list

## What a node is, for the report and the allow-list: its kit id, its scene
## file, the house it belongs to, else its cleaned node path.
func _info(n: Node) -> Dictionary:
	var iid := n.get_instance_id()
	if _info_cache.has(iid):
		return _info_cache[iid]
	var names: Array = []
	var classes: Array = []
	var kit := ""
	var scene := ""
	var cur := n
	while cur != null and cur != area:
		names.push_front(String(cur.name))
		if kit == "" and cur.has_meta("kit_id"):
			kit = str(cur.get_meta("kit_id"))
		if scene == "" and cur.scene_file_path != "":
			scene = cur.scene_file_path.get_file()
		var sc: Script = cur.get_script()
		if sc != null and String(sc.get_global_name()) != "":
			classes.append(String(sc.get_global_name()))
		cur = cur.get_parent()
	var path := "/".join(names)
	var ident := ""
	var leaf := _clean(String(n.name))
	if kit != "":
		ident = "kit:" + kit
	elif names.size() > 1 and String(names[1]).begins_with("House_"):
		ident = "house:" + String(names[1]).trim_prefix("House_") + "/" + leaf
	elif scene != "":
		ident = "scene:" + scene
	elif n is MultiMeshInstance3D:
		ident = "mm:" + leaf
	else:
		var tail: Array = names.slice(1) if names.size() > 1 else names
		ident = "node:" + _clean("/".join(tail))
		if n is MeshInstance3D and String(n.name).begins_with("@"):
			# an unnamed mesh: its material is the best name it has
			var mi := n as MeshInstance3D
			var mat: Material = mi.material_override
			if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				mat = mi.mesh.surface_get_material(0)
			var mn := ""
			if mat != null:
				mn = mat.resource_name
				if mn == "" and mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
					mn = (mat as ShaderMaterial).shader.resource_path.get_file()
			ident += "[%s %s]" % [mi.mesh.get_class() if mi.mesh != null else "", mn]
	var label := String(_labels.get(iid, ""))
	if label != "":
		ident = label
	var out := {"id": ident, "path": path, "classes": classes}
	_info_cache[iid] = out
	return out

func _clean(s: String) -> String:
	s = _re_auto.sub(s, "$1", true)
	return _re_num.sub(s, "", true)

## The first allow rule that covers this thing for `scope` ("all" covers
## walk_through and partial; "partial"; "invisible"; "surface").
func _allowed(info: Dictionary, scope: String) -> bool:
	for r in cfg["allow"]:
		var sc := String(r.get("allow", "all"))
		if sc != scope and not (sc == "all" and scope == "partial"):
			continue
		if r.has("id") and not String(info["id"]).match(String(r["id"])):
			continue
		if r.has("path") and not String(info["path"]).match(String(r["path"])):
			continue
		if r.has("class") and not (String(r["class"]) in info["classes"]):
			continue
		if r.has("area") and String(r["area"]) != area.area_id:
			continue
		if r.has("near"):
			var nr: Array = r["near"]
			if not info.has("pos") or (info["pos"] as Vector3).distance_to(Vector3(nr[0], nr[1], nr[2])) > float(nr[3]):
				continue
		return true
	return false

## Anonymous bodies get the name of the spec that made them.
func _label_bodies() -> void:
	_labels.clear()
	var by_pos := {}
	var bl: Array = def.get("blockers", [])
	for i in bl.size():
		var s: Dictionary = bl[i]
		var c := AreaBuilder._v3(s["at"]) if s.has("radius") else (AreaBuilder._v3(s["min"]) + AreaBuilder._v3(s["max"])) * 0.5
		by_pos[Vector3i(c * 10.0)] = "blocker#%d" % i
	var bx: Array = def.get("boxes", [])
	for i in bx.size():
		var c2 := (AreaBuilder._v3(bx[i]["min"]) + AreaBuilder._v3(bx[i]["max"])) * 0.5
		by_pos[Vector3i(c2 * 10.0)] = "box#%d(%s)" % [i, String(bx[i].get("mat", "M_stone"))]
	for lm in def.get("landmarks", []):
		if lm.has("blocker"):
			by_pos[Vector3i(AreaBuilder._v3(lm["at"]) * 10.0)] = "landmark_blocker:" + String(lm["scene"]).get_file()
	for layer in [area.base, area.thaw_layer, area.rime_layer]:
		for ch in layer.get_children():
			if (ch is StaticBody3D or ch is MeshInstance3D) and by_pos.has(Vector3i((ch as Node3D).position * 10.0)):
				_labels[ch.get_instance_id()] = by_pos[Vector3i((ch as Node3D).position * 10.0)]

# ------------------------------------------------------------------ drawn geometry

func _drawn(n: Node) -> bool:
	var g := n as GeometryInstance3D
	if g.visibility_range_begin > 0.0 or g.transparency >= 1.0:
		return false      # a far LOD of something audited near; a hidden sheet
	if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return false
	return true

## Every MeshInstance3D / MultiMeshInstance3D under the area that could be
## drawn in some state (visibility is tested per pass).
func _geometry(only_visible: bool) -> Array:
	var out: Array = []
	var stack: Array[Node] = [area]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Terrain or n is EnvRig or n is CharacterBody3D or n is CPUParticles3D or n is GPUParticles3D:
			continue
		if only_visible and n is Node3D and not (n as Node3D).visible:
			continue
		if (n is MeshInstance3D and (n as MeshInstance3D).mesh != null) \
				or (n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null):
			if _drawn(n):
				out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out

## World transforms of a MultiMesh's instances. The headless rendering
## server keeps no instance buffer (get_instance_transform answers identity),
## so the builders leave them on the node ("instance_xfs": Scatter, Forest).
## Without that the MultiMesh cannot be audited: it is counted and reported.
func _mm_xfs(mmi: MultiMeshInstance3D) -> Array:
	if not mmi.has_meta("instance_xfs"):
		return []
	var out: Array = []
	var gx := mmi.global_transform
	for t in mmi.get_meta("instance_xfs"):
		out.append(gx * (t as Transform3D))
	return out

## The mesh as a trimesh with the instance's scale baked in: physics bodies
## must not carry scale (a scaled concave body does not answer shape queries).
func _trimesh(mesh: Mesh, sc: Vector3) -> Shape3D:
	var k := "%d|%.3f|%.3f|%.3f" % [mesh.get_rid().get_id(), sc.x, sc.y, sc.z]
	if not _shape_cache.has(k):
		var faces := mesh.get_faces()
		if faces.is_empty():
			_shape_cache[k] = null
		else:
			if not sc.is_equal_approx(Vector3.ONE):
				for i in faces.size():
					faces[i] = faces[i] * sc
			var sh := ConcavePolygonShape3D.new()
			sh.backface_collision = true
			sh.set_faces(faces)
			_shape_cache[k] = sh
	return _shape_cache[k]

## A physics copy of what is drawn, on layers nothing else uses, so "is
## anything drawn here" is a physics query.
func _build_proxies() -> void:
	proxy_root = Node3D.new()
	proxy_root.name = "AuditProxies"
	add_child(proxy_root)
	proxies.clear()
	var min_ext := float(T["proxy_min_extent"])
	for n in _geometry(false):
		var info := _info(n)
		var bits := SOFT_MASK if _allowed(info, "surface") else VIS_MASK
		if bits == VIS_MASK and _allowed(info, "undrawn"):
			continue     # light, smoke, sky: nothing a foot or a shoulder meets
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var ab := mi.global_transform * mi.mesh.get_aabb()
			if maxf(ab.size.x, maxf(ab.size.y, ab.size.z)) < min_ext:
				continue
			var gx := mi.global_transform
			var shape := _trimesh(mi.mesh, gx.basis.get_scale())
			if shape == null:
				continue
			var body := _proxy_body(shape, gx, bits)
			body.set_meta("src", mi.get_instance_id())
			body.set_meta("wide", minf(ab.size.x, ab.size.z) >= float(T["floor_min_extent"]))
			proxies.append([mi, body, bits])
		else:
			var mmi := n as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm.mesh == null:
				continue
			var mab := mm.mesh.get_aabb()
			for t in _mm_xfs(mmi):
				var xf: Transform3D = t
				var ab2 := xf * mab
				if maxf(ab2.size.x, maxf(ab2.size.y, ab2.size.z)) < maxf(min_ext, 0.5):
					continue
				var shape2 := _trimesh(mm.mesh, xf.basis.get_scale())
				if shape2 == null:
					continue
				var b2 := _proxy_body(shape2, xf, bits)
				b2.set_meta("src", mmi.get_instance_id())
				b2.set_meta("wide", false)
				proxies.append([mmi, b2, bits])

func _proxy_body(shape: Shape3D, xf: Transform3D, bits: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = bits
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	proxy_root.add_child(body)
	body.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	return body

func _sync_proxies() -> void:
	for p in proxies:
		var n := p[0] as Node3D
		(p[1] as StaticBody3D).collision_layer = int(p[2]) if n.is_visible_in_tree() else 0

# ------------------------------------------------------------------ the playable footprint

## The navmesh of this state, cut down to the parts joined to somewhere the
## game puts the Bearer (start, hearths, portals, souls, finds, foes), as a
## 1 m grid of walkable heights.
func _build_reach(region: NavigationRegion3D) -> void:
	reach = {}
	if region == null or region.navigation_mesh == null:
		return
	var nm := region.navigation_mesh
	var verts := nm.get_vertices()
	var pc := nm.get_polygon_count()
	var parent := PackedInt32Array()
	parent.resize(pc)
	for i in pc:
		parent[i] = i
	var edge := {}
	var polys: Array = []
	for i in pc:
		var poly := nm.get_polygon(i)
		polys.append(poly)
		for k in poly.size():
			var a := poly[k]
			var b := poly[(k + 1) % poly.size()]
			var key := mini(a, b) * 1000003 + maxi(a, b)
			if edge.has(key):
				var ra := _find(parent, i)
				var rb := _find(parent, int(edge[key]))
				if ra != rb:
					parent[ra] = rb
			else:
				edge[key] = i
	var seeds: Array = [AreaBuilder._v3(def.get("start", {}).get("pos", [0, 0, 0]))]
	for key in ["hearths", "portals", "npcs", "pickups", "spawners", "plaques"]:
		for s in def.get(key, []):
			seeds.append(AreaBuilder._v3(s.get("at", [0, 0, 0])))
	for inc in _incoming.get(area.area_id, []):
		seeds.append(inc[1])
	var good := {}
	for i in pc:
		var poly: PackedInt32Array = polys[i]
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := -mn
		for vi in poly:
			mn = mn.min(verts[vi])
			mx = mx.max(verts[vi])
		for s in seeds:
			var sp: Vector3 = s
			if sp.x >= mn.x - 0.8 and sp.x <= mx.x + 0.8 and sp.z >= mn.z - 0.8 and sp.z <= mx.z + 0.8 \
					and sp.y >= mn.y - 1.5 and sp.y <= mx.y + 1.5:
				good[_find(parent, i)] = true
				break
	stats["nav_polys"] = pc
	var all := good.is_empty()      # no seed on the mesh: take all of it
	for i in pc:
		if not all and not good.has(_find(parent, i)):
			continue
		var poly: PackedInt32Array = polys[i]
		var pts := PackedVector2Array()
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := -mn
		for vi in poly:
			var v := verts[vi]
			pts.append(Vector2(v.x, v.z))
			mn = mn.min(v)
			mx = mx.max(v)
		var pl := Plane(verts[poly[0]], verts[poly[1]], verts[poly[2]])
		var small := (mx.x - mn.x) < 1.5 and (mx.z - mn.z) < 1.5
		for cx in range(int(floor(mn.x)), int(floor(mx.x)) + 1):
			for cz in range(int(floor(mn.z)), int(floor(mx.z)) + 1):
				var c := Vector2(cx + 0.5, cz + 0.5)
				if not small and not Geometry2D.is_point_in_polygon(c, pts):
					continue
				var y := (mn.y + mx.y) * 0.5
				if absf(pl.normal.y) > 0.2:
					y = clampf((pl.d - pl.normal.x * c.x - pl.normal.z * c.y) / pl.normal.y, mn.y, mx.y)
				var k := Vector2i(cx, cz)
				if not reach.has(k):
					reach[k] = PackedFloat32Array([y])
				else:
					var arr: PackedFloat32Array = reach[k]
					var dup := false
					for h in arr:
						if absf(h - y) < 0.6:
							dup = true
					if not dup:
						arr.append(y)
						reach[k] = arr

func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

## A walkable height within one cell of (x, z) with y - h inside [lo, hi];
## NAN when the Bearer cannot stand near here at that level.
func _reach_y(x: float, z: float, y: float, lo: float, hi: float) -> float:
	var cx := int(floor(x))
	var cz := int(floor(z))
	for dx in [0, -1, 1]:
		for dz in [0, -1, 1]:
			var arr = reach.get(Vector2i(cx + dx, cz + dz))
			if arr == null:
				continue
			for h in arr:
				if y - h >= lo and y - h <= hi:
					return h
	return NAN

func _reach_near_aabb(ab: AABB) -> bool:
	var x0 := int(floor(ab.position.x)) - 1
	var x1 := int(floor(ab.end.x)) + 1
	var z0 := int(floor(ab.position.z)) - 1
	var z1 := int(floor(ab.end.z)) + 1
	if (x1 - x0) * (z1 - z0) > 4000:
		return true
	for cx in range(x0, x1 + 1):
		for cz in range(z0, z1 + 1):
			var arr = reach.get(Vector2i(cx, cz))
			if arr == null:
				continue
			for h in arr:
				if h < ab.end.y and h > ab.position.y - float(T["band_max"]):
					return true
	return false

# ------------------------------------------------------------------ queries

func _ray(from: Vector3, to: Vector3, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return space.intersect_ray(q)

## Anything on `mask` within r of p (the terrain never counts: it is under
## everything).
func _touch(p: Vector3, r: float, mask: int) -> bool:
	_sphere.radius = r
	_sq.shape = _sphere
	_sq.transform = Transform3D(Basis.IDENTITY, p)
	_sq.collision_mask = mask
	_sq.exclude = [terrain_rid] if terrain_rid.is_valid() else []
	return not space.intersect_shape(_sq, 1).is_empty()

# ------------------------------------------------------------------ check 1: drawn but not solid

## Points spread over a mesh's surface (local space), with their normals.
func _samples(mesh: Mesh) -> Array:
	var k := mesh.get_rid()
	if _sample_cache.has(k):
		return _sample_cache[k]
	var faces := mesh.get_faces()
	var tri_n := faces.size() / 3
	var stride := maxi(1, tri_n / int(T["max_tris"]))
	var area_sum := 0.0
	var i := 0
	while i < tri_n:
		area_sum += (faces[i * 3 + 1] - faces[i * 3]).cross(faces[i * 3 + 2] - faces[i * 3]).length() * 0.5
		i += stride
	var per := maxf(float(T["sample_spacing"]) * float(T["sample_spacing"]), area_sum / float(T["max_samples"]))
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567 + tri_n
	var carry := 0.0
	i = 0
	while i < tri_n:
		var a := faces[i * 3]
		var b := faces[i * 3 + 1]
		var c := faces[i * 3 + 2]
		var cr := (b - a).cross(c - a)
		var ar := cr.length() * 0.5
		carry += ar / per
		while carry >= 1.0:
			carry -= 1.0
			var u := rng.randf()
			var v := rng.randf()
			if u + v > 1.0:
				u = 1.0 - u
				v = 1.0 - v
			pts.append(a + (b - a) * u + (c - a) * v)
			# Godot winds front faces clockwise
			nrm.append(-cr.normalized() if ar > 0.0 else Vector3.UP)
		i += stride
	var out := [pts, nrm, sqrt(per)]
	_sample_cache[k] = out
	return out

func _check_meshes() -> void:
	var n_mesh := 0
	for n in _geometry(true):
		var info := _info(n)
		if _allowed(info, "all") or _allowed(info, "undrawn") or _allowed(info, "surface"):
			continue
		var part_ok := _allowed(info, "partial")
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			n_mesh += 1
			_audit_mesh(mi.mesh, mi.global_transform, info, part_ok)
		else:
			var mmi := n as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm.mesh == null:
				continue
			if not mmi.has_meta("instance_xfs"):
				var uk := "%s (%s)" % [info["id"], _clean(info["path"])]
				unaudited[uk] = maxi(int(unaudited.get(uk, 0)), mm.instance_count)
				continue
			for t in _mm_xfs(mmi):
				n_mesh += 1
				_audit_mesh(mm.mesh, t, info, part_ok)
	stats["meshes"] = n_mesh

func _audit_mesh(mesh: Mesh, xf: Transform3D, info: Dictionary, part_ok: bool) -> void:
	var ab := xf * mesh.get_aabb()
	var min_h := float(T["min_height"])
	var min_w := float(T["min_width"])
	if ab.size.y < min_h or maxf(ab.size.x, ab.size.z) < min_w:
		return
	if not _reach_near_aabb(ab):
		return
	var smp := _samples(mesh)
	var pts: PackedVector3Array = smp[0]
	var nrm: PackedVector3Array = smp[1]
	var lo := float(T["band_min"])
	var hi := float(T["band_max"])
	var cen := ab.get_center()
	var cand := PackedVector3Array()
	var cand_h := PackedFloat32Array()
	for i in pts.size():
		var p := xf * pts[i]
		var o := xf.basis * nrm[i]
		o.y = 0.0
		if o.length_squared() < 0.09 * xf.basis.x.length_squared():
			o = Vector3(p.x - cen.x, 0.0, p.z - cen.z)
		o = o.normalized() if o.length_squared() > 1e-6 else Vector3.RIGHT
		var g := _reach_y(p.x + o.x * 0.45, p.z + o.z * 0.45, p.y, lo, hi)
		if is_nan(g):
			continue
		if terrain != null and terrain.contains(p.x, p.z) and p.y < _drawn_h(p.x, p.z) + 0.05:
			continue      # the part of it bedded in the ground
		cand.append(p)
		cand_h.append(p.y - g)
	if cand.size() < int(T["min_samples"]):
		return
	# a first pass over an even spread of them, then every sample near one
	# that came back bare: a hole in a long wall is a few samples of hundreds
	var n := cand.size()
	var state := PackedByteArray()      # 0 untested, 1 covered, 2 bare
	state.resize(n)
	var cover_r := float(T["cover_radius"])
	var step := maxf(1.0, float(n) / float(T["max_tests"]))
	var tested := 0
	var covered := 0
	var bare: Array[int] = []
	var f := 0.0
	while int(f) < n:
		var i := int(f)
		f += step
		if state[i] != 0:
			continue
		tested += 1
		if _touch(cand[i], cover_r, solid_mask):
			state[i] = 1
			covered += 1
		else:
			state[i] = 2
			bare.append(i)
	if bare.is_empty():
		return
	if tested < n:
		var first := bare.duplicate()
		for i in n:
			if state[i] != 0:
				continue
			for j in first:
				if cand[i].distance_squared_to(cand[j]) < 2.25:
					tested += 1
					if _touch(cand[i], cover_r, solid_mask):
						state[i] = 1
						covered += 1
					else:
						state[i] = 2
						bare.append(i)
					break
	if bare.size() < int(T["min_samples"]):
		return
	# the largest patch of bare samples that hang together
	var link := maxf(float(T["cluster_link"]), 1.7 * float(smp[2]) * xf.basis.x.length())
	var cells := {}
	for i in bare:
		var ck := Vector3i((cand[i] / link).floor())
		if not cells.has(ck):
			cells[ck] = []
		cells[ck].append(i)
	var seen := {}
	var best: Array = []
	for ck0 in cells:
		if seen.has(ck0):
			continue
		var grp: Array = []
		var stack: Array = [ck0]
		seen[ck0] = true
		while not stack.is_empty():
			var ck: Vector3i = stack.pop_back()
			grp.append_array(cells[ck])
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					for dz in [-1, 0, 1]:
						var nk: Vector3i = ck + Vector3i(dx, dy, dz)
						if cells.has(nk) and not seen.has(nk):
							seen[nk] = true
							stack.append(nk)
		if grp.size() > best.size():
			best = grp
	var umn := Vector3(1e9, 1e9, 1e9)
	var umx := -umn
	var usum := Vector3.ZERO
	var proud := 0.0
	for i in best:
		var p := cand[i]
		umn = umn.min(p)
		umx = umx.max(p)
		usum += p
		# the navmesh height is a metre-grid estimate: measure how far the
		# bare part really stands out of the floor under it
		var g := _ray(p, p + Vector3(0, -3.0, 0), solid_mask)
		if not g.is_empty():
			proud = maxf(proud, p.y - float(g["position"].y))
	var usz := umx - umn
	if proud < min_h or maxf(usz.x, usz.z) < min_w:
		return
	var dims := [usz.x, usz.y, usz.z]
	dims.sort()
	if float(dims[1]) < float(T["min_second"]):
		return      # a pole, a rail, a rope: thinner than anything a shoulder meets
	var kind := ""
	if covered == 0:
		# nothing at its surface; is anything solid inside it at all (a trunk
		# in a tree's foliage, a post in a rack)?
		var bmn := Vector3(1e9, 1e9, 1e9)
		var bmx := -bmn
		for p in cand:
			bmn = bmn.min(p)
			bmx = bmx.max(p)
		var bq := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = (bmx - bmn).max(Vector3(0.1, 0.1, 0.1))
		bq.shape = bs
		bq.transform = Transform3D(Basis.IDENTITY, (bmn + bmx) * 0.5)
		bq.collision_mask = solid_mask
		bq.exclude = [terrain_rid] if terrain_rid.is_valid() else []
		if space.intersect_shape(bq, 1).is_empty():
			kind = "walk_through"
	if kind == "" and not part_ok and best.size() >= int(T["partial_min"]):
		kind = "partial"
	if kind == "":
		return
	_add(kind, info["id"], usum / float(best.size()), ab.size, "%d of %d body-height samples have no collider within %.2f m; the largest bare patch is %d samples, %.1f x %.1f x %.1f m, standing %.1f m out of the floor" % [
		bare.size(), tested, cover_r, best.size(), usz.x, usz.y, usz.z, proud], info["path"])

# ------------------------------------------------------------------ check 4: solid but not drawn

func _check_invisible() -> void:
	var stack: Array[Node] = [area]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Terrain or n is CharacterBody3D or n is EnvRig:
			continue
		if n is CollisionShape3D and n.get_parent() is StaticBody3D:
			var body := n.get_parent() as StaticBody3D
			if (body.collision_layer & solid_mask) != 0 and not (n as CollisionShape3D).disabled:
				_audit_shape(n as CollisionShape3D, body)
		for c in n.get_children():
			stack.append(c)

func _audit_shape(cs: CollisionShape3D, body: StaticBody3D) -> void:
	var sh := cs.shape
	var half := Vector3.ZERO
	if sh is BoxShape3D:
		half = (sh as BoxShape3D).size * 0.5
	elif sh is SphereShape3D:
		half = Vector3.ONE * (sh as SphereShape3D).radius
	elif sh is CylinderShape3D:
		half = Vector3((sh as CylinderShape3D).radius, (sh as CylinderShape3D).height * 0.5, (sh as CylinderShape3D).radius)
	elif sh is CapsuleShape3D:
		half = Vector3((sh as CapsuleShape3D).radius, (sh as CapsuleShape3D).height * 0.5, (sh as CapsuleShape3D).radius)
	else:
		return      # hulls and trimeshes are made from the drawn mesh itself
	var xf := cs.global_transform
	var ab := xf * AABB(-half, half * 2.0)
	if ab.size.y < float(T["min_height"]) or maxf(ab.size.x, ab.size.z) < float(T["min_width"]):
		return
	if not _reach_near_aabb(ab):
		return
	var info := _info(body)
	if _allowed(info, "invisible"):
		return
	var round_shape := not (sh is BoxShape3D)
	var nx := clampi(int(ceil(half.x * 2.0 / 0.7)) + 1, 2, 9)
	var ny := clampi(int(ceil(half.y * 2.0 / 0.5)) + 1, 2, 9)
	var nz := clampi(int(ceil(half.z * 2.0 / 0.7)) + 1, 2, 9)
	var tested := 0
	var bare := 0
	var umn := Vector3(1e9, 1e9, 1e9)
	var umx := -umn
	var usum := Vector3.ZERO
	var r := float(T["drawn_radius"])
	for ix in nx:
		for iy in ny:
			for iz in nz:
				var l := Vector3(lerpf(-half.x, half.x, float(ix) / (nx - 1)), lerpf(-half.y, half.y, float(iy) / (ny - 1)),
					lerpf(-half.z, half.z, float(iz) / (nz - 1)))
				if round_shape and Vector2(l.x, l.z).length() > half.x:
					continue
				var p := xf * l
				if is_nan(_reach_y(p.x, p.z, p.y, 0.3, float(T["band_max"]) + 0.1)):
					continue
				tested += 1
				var drawn := terrain != null and terrain.contains(p.x, p.z) and p.y < _drawn_h(p.x, p.z) + 0.15
				if not drawn:
					drawn = _touch(p, r, VIS_MASK | SOFT_MASK)
				if not drawn:
					bare += 1
					umn = umn.min(p)
					umx = umx.max(p)
					usum += p
	if bare < 3 or bare * 2 < tested:
		return
	var usz := umx - umn
	if maxf(usz.x, usz.z) < float(T["min_width"]):
		return
	# what it was probably meant to wrap: the nearest drawn thing
	var near := ""
	_sphere.radius = maxf(ab.size.x, ab.size.z) * 0.5 + 0.5
	_sq.shape = _sphere
	_sq.transform = Transform3D(Basis.IDENTITY, ab.get_center())
	_sq.collision_mask = VIS_MASK
	_sq.exclude = []
	var nh := space.intersect_shape(_sq, 1)
	if not nh.is_empty():
		var src := instance_from_id(int((nh[0]["collider"] as Node).get_meta("src", 0)))
		if src != null:
			near = "; the nearest drawn thing is " + String(_info(src as Node)["id"])
	_add("invisible", info["id"], usum / float(bare), ab.size, "%d of %d body-height points of this %s have nothing drawn within %.2f m%s" % [
		bare, tested, sh.get_class(), r, near], info["path"])

# ------------------------------------------------------------------ check 3: terrain and floors

## The heightfield collider against the heights the mesh is drawn from.
func _terrain_truth() -> void:
	if terrain == null or not terrain_rid.is_valid():
		return
	var bad := 0
	var worst := 0.0
	var at := Vector3.ZERO
	var n := 0
	var i := 1
	while i < terrain.nx - 1:
		var j := 1
		while j < terrain.nz - 1:
			var x := terrain.origin.x + (i + 0.37) * terrain.cell
			var z := terrain.origin.y + (j + 0.61) * terrain.cell
			var ht := _drawn_h(x, z)
			var ex: Array[RID] = []
			var hit := {}
			for k in 8:
				hit = _ray(Vector3(x, ht + 0.6, z), Vector3(x, ht - 0.9, z), 1 << (RH.L_WORLD_BASE - 1), ex)
				if hit.is_empty() or hit["rid"] == terrain_rid:
					break
				ex.append(hit["rid"])
			n += 1
			var dlt := 99.0 if hit.is_empty() else absf(float(hit["position"].y) - ht)
			# (bilinear vs the collider's two triangles differ a little on a twisted cell)
			if dlt > float(T["terrain_tol"]):
				bad += 1
				if dlt > worst:
					worst = dlt
					at = Vector3(x, ht, z)
			j += 3
		i += 3
	stats["terrain_truth_samples"] = n
	check(bad == 0, "%s: heightfield collider matches the drawn heights at %d samples (worst %.2f m)" % [area.area_id, n, worst])
	if bad > 0:
		_add("terrain_collider", "terrain", at, Vector3.ZERO, "%d of %d samples: collider is %.2f m off the drawn height (worst here)" % [bad, n, worst])

## The drawn ground at (x, z): the terrain mesh's own two triangles per
## cell (Terrain._chunk_mesh splits b-c). Terrain.height_at is bilinear and
## differs from both the mesh and the collider on a twisted cell.
func _drawn_h(x: float, z: float) -> float:
	var fx := (x - terrain.origin.x) / terrain.cell
	var fz := (z - terrain.origin.y) / terrain.cell
	var i := clampi(int(floor(fx)), 0, terrain.nx - 2)
	var j := clampi(int(floor(fz)), 0, terrain.nz - 2)
	var tx := fx - i
	var tz := fz - j
	var a := terrain.h_at(i, j)
	var b := terrain.h_at(i + 1, j)
	var c := terrain.h_at(i, j + 1)
	var d := terrain.h_at(i + 1, j + 1)
	if tx + tz <= 1.0:
		return a + (b - a) * tx + (c - a) * tz
	return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)

## The reach cells joined to the inside of the area without walking through
## a seam (an auto portal's box carries the Bearer to the neighbour: ground
## past it is the neighbour's to audit, and its far edge is never reached).
func _inside_seams() -> Dictionary:
	var blocked := {}
	for p in def.get("portals", []):
		if not bool(p.get("auto", false)):
			continue
		var at := AreaBuilder._v3(p["at"])
		var inv := Basis(Vector3.UP, deg_to_rad(float(p.get("rot", 0)))).inverse()
		var zs: Array = p.get("zone", [12, 4, 2])
		var hx := float(zs[0]) * 0.5 + 0.75
		var hz := float(zs[2]) * 0.5 + 0.75
		var r := int(ceil(hx + hz))
		for cx in range(int(floor(at.x)) - r, int(floor(at.x)) + r + 1):
			for cz in range(int(floor(at.z)) - r, int(floor(at.z)) + r + 1):
				var l := inv * (Vector3(cx + 0.5, at.y, cz + 0.5) - at)
				if absf(l.x) <= hx and absf(l.z) <= hz:
					blocked[Vector2i(cx, cz)] = true
	var seeds: Array = [AreaBuilder._v3(def.get("start", {}).get("pos", [0, 0, 0]))]
	for key in ["hearths", "npcs", "pickups", "spawners", "plaques"]:
		for s in def.get(key, []):
			seeds.append(AreaBuilder._v3(s.get("at", [0, 0, 0])))
	for inc in _incoming.get(area.area_id, []):
		seeds.append(inc[1])
	var seen := {}
	var stack: Array = []
	for s in seeds:
		var sp: Vector3 = s
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var k := Vector2i(int(floor(sp.x)) + dx, int(floor(sp.z)) + dz)
				if reach.has(k) and not blocked.has(k) and not seen.has(k):
					seen[k] = true
					stack.append(k)
	while not stack.is_empty():
		var k: Vector2i = stack.pop_back()
		var ha: PackedFloat32Array = reach[k]
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nk: Vector2i = k + d
			if seen.has(nk) or blocked.has(nk) or not reach.has(nk):
				continue
			var hb: PackedFloat32Array = reach[nk]
			var joined := false
			for a in ha:
				for b in hb:
					if absf(a - b) <= 1.2:
						joined = true
			if joined:
				seen[nk] = true
				stack.append(nk)
	return seen

func _check_columns() -> void:
	var inside := _inside_seams()
	if inside.is_empty():
		inside = reach
	stats["inside_cells"] = inside.size()
	# reach cells, and two cells out past their edge; edge cells sampled finer
	var cols := {}
	for k in inside:
		var arr: PackedFloat32Array = reach[k]
		for h in arr:
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var ck := Vector3i(k.x + dx, int(round(h * 2.0)), k.y + dz)
					var own := dx == 0 and dz == 0
					if own:
						cols[ck] = [h, true]
					elif not cols.has(ck):
						var near = reach.get(Vector2i(k.x + dx, k.y + dz))
						var has := false
						if near != null:
							for h2 in near:
								if absf(h2 - h) < 1.0:
									has = true
						if not has:
							cols[ck] = [h, false]
	var raw: Array = []     # [check, pos, detail_value]
	var n := 0
	var tb := 0
	if terrain != null:
		tb = 1
	for ck in cols:
		var h: float = cols[ck][0]
		var on: bool = cols[ck][1]
		var edge := not on
		if on:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not reach.has(Vector2i(ck.x + d.x, ck.z + d.y)):
					edge = true
		var offs: Array = [Vector2(0.5, 0.5)]
		if edge:
			offs = [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
		for o in offs:
			n += 1
			_column(ck.x + o.x, ck.z + o.y, h, on, raw)
	stats["columns"] = n
	if terrain != null:
		# can the Bearer walk off the heightfield onto the horizon ring?
		var x0 := terrain.origin.x + 3.0
		var z0 := terrain.origin.y + 3.0
		var x1 := terrain.origin.x + (terrain.nx - 1) * terrain.cell - 3.0
		var z1 := terrain.origin.y + (terrain.nz - 1) * terrain.cell - 3.0
		for k in inside:
			if k.x < x0 or k.x + 1 > x1 or k.y < z0 or k.y + 1 > z1:
				raw.append(["terrain_edge", Vector3(k.x + 0.5, reach[k][0], k.y + 0.5), 0.0])
	_cluster(raw)

func _column(x: float, z: float, navy: float, on_nav: bool, raw: Array) -> void:
	var tol := float(T["surface_tol"])
	var top := navy + 1.2
	var c := _ray(Vector3(x, top, z), Vector3(x, navy - 2.5, z), solid_mask)
	var has_t := terrain != null and terrain.contains(x, z)
	var ht := _drawn_h(x, z) if has_t else -1e9
	if has_t and ht > top:
		return      # under a cliff face: a wall, not a floor
	if c.is_empty():
		var deep := _ray(Vector3(x, top, z), Vector3(x, navy - 400.0, z), solid_mask)
		if deep.is_empty():
			for o in [Vector2(0.07, 0.03), Vector2(-0.05, 0.06), Vector2(0.04, -0.07)]:
				if not _ray(Vector3(x + o.x, top, z + o.y), Vector3(x + o.x, navy - 400.0, z + o.y), solid_mask).is_empty():
					return      # a ray down a cell seam: not a hole
			# nothing at all below: the ground is drawn here, or a floor is
			var v := _ray(Vector3(x, top, z), Vector3(x, navy - 60.0, z), VIS_MASK)
			if has_t or not v.is_empty():
				raw.append(["void", Vector3(x, ht if has_t else float(v["position"].y), z), 0.0])
		return
	var yc: float = c["position"].y
	if has_t and ht > yc + tol and ht < top - 0.05:
		raw.append(["terrain_collider", Vector3(x, ht, z), ht - yc])
	if on_nav and (c["normal"] as Vector3).y > 0.7 and absf(yc - navy) < 0.6:
		# standing here: is anything drawn under the feet?
		var drawn := has_t and ht >= yc - tol
		if not drawn:
			drawn = _touch(Vector3(x, yc - 0.05, z), tol, VIS_MASK | SOFT_MASK)
		if not drawn:
			var below := _ray(Vector3(x, yc, z), Vector3(x, yc - 40.0, z), VIS_MASK | SOFT_MASK)
			var dy: float = yc - ht if has_t else 40.0
			if not below.is_empty():
				dy = minf(dy, yc - float(below["position"].y))
			raw.append(["floating", Vector3(x, yc, z), dy, _info(c["collider"] as Node)["id"]])
	# a floor drawn above the one that carries: boards the feet pass through
	var v2 := _ray(Vector3(x, top, z), Vector3(x, yc + tol, z), VIS_MASK)
	if not v2.is_empty() and (v2["normal"] as Vector3).y > 0.8 and bool((v2["collider"] as Node).get_meta("wide", false)):
		var yv: float = v2["position"].y
		var flat := true
		for o in [Vector2(0.6, 0), Vector2(-0.6, 0), Vector2(0, 0.6), Vector2(0, -0.6)]:
			var v3 := _ray(Vector3(x + o.x, yv + 0.3, z + o.y), Vector3(x + o.x, yv - 0.3, z + o.y), VIS_MASK)
			if v3.is_empty() or v3["collider"] != v2["collider"]:
				flat = false
				break
			# and no collider carries it there either
			var c3 := _ray(Vector3(x + o.x, yv + tol, z + o.y), Vector3(x + o.x, yv - tol, z + o.y), solid_mask)
			if not c3.is_empty():
				flat = false
				break
		if flat:
			raw.append(["unbacked_floor", Vector3(x, yv, z), yv - yc, _info(instance_from_id(int((v2["collider"] as Node).get_meta("src"))) as Node)["id"]])

## Neighbouring bad columns are one hole.
func _cluster(raw: Array) -> void:
	var by_kind := {}
	for r in raw:
		if not by_kind.has(r[0]):
			by_kind[r[0]] = []
		by_kind[r[0]].append(r)
	for kind in by_kind:
		var items: Array = by_kind[kind]
		var cells := {}
		for i in items.size():
			var p: Vector3 = items[i][1]
			var ck := Vector3i(int(floor(p.x / 1.5)), int(floor(p.y / 2.0)), int(floor(p.z / 1.5)))
			if not cells.has(ck):
				cells[ck] = []
			cells[ck].append(i)
		var seen := {}
		for ck0 in cells:
			if seen.has(ck0):
				continue
			var grp: Array = []
			var stack: Array = [ck0]
			seen[ck0] = true
			while not stack.is_empty():
				var ck: Vector3i = stack.pop_back()
				grp.append_array(cells[ck])
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						for dz in [-1, 0, 1]:
							var nk := ck + Vector3i(dx, dy, dz)
							if cells.has(nk) and not seen.has(nk):
								seen[nk] = true
								stack.append(nk)
			var mn := Vector3(1e9, 1e9, 1e9)
			var mx := -mn
			var worst := 0.0
			var wp := Vector3.ZERO
			var first := true
			var what := ""
			for i in grp:
				var p: Vector3 = items[i][1]
				mn = mn.min(p)
				mx = mx.max(p)
				if first or float(items[i][2]) > worst:
					worst = float(items[i][2])
					wp = p
					first = false
				if items[i].size() > 3:
					what = String(items[i][3])
			if grp.size() < int(T["cluster_min"]) and kind != "void" and kind != "terrain_collider":
				continue
			var det := "%d samples over %.1f x %.1f m" % [grp.size(), mx.x - mn.x + 0.5, mx.z - mn.z + 0.5]
			match kind:
				"floating": det += "; the collision floor is up to %.2f m above anything drawn" % worst
				"unbacked_floor": det += "; a drawn floor up to %.2f m above the floor that carries" % worst
				"terrain_collider": det += "; the drawn ground is up to %.2f m above the collision under it" % worst
				"void": det += "; no collider at all below"
				"terrain_edge": det += "; walkable ground within 3 m of the heightfield's edge"
			_add(kind, what if what != "" else "ground", wp, mx - mn, det)

## Start, hearths and the arrivals from neighbouring areas: a floor under
## them, where it is drawn, and room for the capsule.
func _check_spots(id: String) -> void:
	var spots: Array = [["start", AreaBuilder._v3(def.get("start", {}).get("pos", [0, 0, 0]))]]
	for inc in _incoming.get(id, []):
		spots.append(["arrival from " + String(inc[0]), inc[1]])
	for p in def.get("portals", []):
		spots.append(["portal to " + String(p.get("to", "")), AreaBuilder._v3(p["at"])])
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.65
	for s in spots:
		var p: Vector3 = s[1]
		if _allowed({"id": String(s[0]), "path": "", "classes": [], "pos": p}, "spot"):
			continue
		var c := _ray(p + Vector3(0, 1.0, 0), p + Vector3(0, -2.5, 0), solid_mask)
		if c.is_empty():
			_add("spawn", String(s[0]), p, Vector3.ZERO, "no collision floor within 2.5 m below")
			continue
		var yc: float = c["position"].y
		if absf(yc - p.y) > float(T["spawn_tol"]):
			_add("spawn", String(s[0]), p, Vector3.ZERO, "the floor is %.2f m from the authored height" % (yc - p.y))
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, yc + 0.85 + 0.25, p.z))
		q.collision_mask = solid_mask
		if not String(s[0]).begins_with("portal") and not space.intersect_shape(q, 1).is_empty():
			_add("spawn", String(s[0]), p, Vector3.ZERO, "the capsule does not fit here")

## The shared ground at a crossing: this area's land and its neighbour's
## must agree where the Bearer is handed over.
func _seams(id: String) -> void:
	if terrain == null:
		return
	for p in def.get("portals", []):
		var to := String(p.get("to", ""))
		var od := DB.area_def(to)
		if od.is_empty() or not od.has("terrain"):
			continue
		var ot := Terrain.new()
		if not ot.setup(od["terrain"]):
			ot.free()
			continue
		var a := AreaBuilder._v3(p["at"])
		var b := AreaBuilder._v3(p.get("spawn", p["at"]))
		var worst := 0.0
		var wp := a
		var n := 0
		for i in 13:
			var t := float(i) / 12.0
			for side in [-1.0, 0.0, 1.0]:
				var d := (b - a)
				var perp: Vector3 = Vector3(-d.z, 0, d.x).normalized() * float(side)
				var q: Vector3 = a.lerp(b, t) + perp
				if terrain.contains(q.x, q.z) and ot.contains(q.x, q.z):
					n += 1
					var dy := absf(terrain.height_at(q.x, q.z) - ot.height_at(q.x, q.z))
					if dy > worst:
						worst = dy
						wp = q
		ot.free()
		check(worst <= float(T["surface_tol"]), "%s: the land at the crossing to %s agrees with the neighbour's (%d samples, worst %.2f m)" % [id, to, n, worst])
		if worst > float(T["surface_tol"]):
			_add("seam", "crossing to " + to, wp, Vector3.ZERO, "the two areas' ground differs by %.2f m on the crossing" % worst)

## A floor profile along a line: where the capsule would have to climb more
## than it can, or where nothing carries it.
func _profile(a: Vector3, b: Vector3, y_top: float) -> Array:
	var out: Array = []
	var n := int(ceil(a.distance_to(b) / 0.1))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var c := _ray(Vector3(p.x, y_top, p.z), Vector3(p.x, y_top - 4.0, p.z), solid_mask)
		out.append([p, NAN if c.is_empty() else float(c["position"].y)])
	return out

func _check_doors() -> void:
	var step_h := _step_height()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	for hs in def.get("houses", []):
		if String(hs.get("kind", "house")) == "barrow" or not AreaBuilder._flag_ok(hs):
			continue
		var root := area.find_child("House_" + String(hs.get("id", "house")), true, false) as Node3D
		if root == null or not root.is_visible_in_tree():
			continue
		var w := float(hs["size"][0])
		var l := float(hs["size"][1])
		var gated := {}
		for d in hs.get("gate_doors", []):
			gated["%s%d" % [String(d[0]), int(d[1])]] = true
		for d in hs.get("doors", []) + hs.get("gate_doors", []):
			var side := String(d[0])
			var along_x := side == "N" or side == "S"
			var span := w if along_x else l
			var off := (-l * 0.5 if side == "N" else l * 0.5) if along_x else (-w * 0.5 if side == "W" else w * 0.5)
			var t := -span * 0.5 + 2.0 + 4.0 * int(d[1]) + (float(d[2]) if (d as Array).size() > 2 else 0.0)
			var lp: Vector3 = BuildingGen._wall_pt(along_x, off, t, 0.0)
			var ln := Vector3(0, 0, signf(off)) if along_x else Vector3(signf(off), 0, 0)
			var gx := root.global_transform
			var a := gx * (lp - ln * 1.6)
			var b := gx * (lp + ln * 1.6)
			var prof := _profile(a, b, gx.origin.y + 1.3)
			var label := "door %s%d of %s" % [side, int(d[1]), String(hs.get("id", "house"))]
			var worst := 0.0
			var wp := gx * lp
			for i in range(1, prof.size()):
				var y0: float = prof[i - 1][1]
				var y1: float = prof[i][1]
				if is_nan(y0) or is_nan(y1):
					worst = 9.0
					wp = prof[i][0]
					continue
				if absf(y1 - y0) > worst:
					worst = absf(y1 - y0)
					wp = Vector3(prof[i][0].x, maxf(y0, y1), prof[i][0].z)
			if worst > step_h + float(T["step_slack"]):
				_add("threshold", label, wp, Vector3.ZERO, ("no floor on the way through" if worst >= 9.0 else "a %.2f m step on the way through (the Bearer climbs %.2f)" % [worst, step_h]))
			if gated.has("%s%d" % [side, int(d[1])]):
				continue      # a barred door is a wall on purpose
			for i in range(0, prof.size(), 2):
				if is_nan(prof[i][1]):
					continue
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = cap
				q.transform = Transform3D(Basis.IDENTITY, Vector3(prof[i][0].x, float(prof[i][1]) + 0.75 + step_h + 0.05, prof[i][0].z))
				q.collision_mask = solid_mask
				var hits := space.intersect_shape(q, 1)
				if not hits.is_empty():
					var who := _info(hits[0]["collider"] as Node)
					if _allowed(who, "doorway"):
						break     # a veil or a barred gate stands in it on purpose
					var lo_y := 1e9
					var hi_y := -1e9
					for pr in prof:
						if not is_nan(pr[1]):
							lo_y = minf(lo_y, float(pr[1]))
							hi_y = maxf(hi_y, float(pr[1]))
					_add("threshold", label, Vector3(prof[i][0].x, float(prof[i][1]), prof[i][0].z), Vector3.ZERO,
						"the doorway is blocked by %s (the floor runs %.2f to %.2f over the 3.2 m through the door; the house floor is %.2f)" % [
						who["id"], lo_y, hi_y, gx.origin.y], who["path"])
					break

func _step_height() -> float:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	for k in g:
		if g[k] is Dictionary and (g[k] as Dictionary).has("move") and (g[k]["move"] as Dictionary).has("step_height"):
			return float(g[k]["move"]["step_height"])
		if g[k] is Dictionary and (g[k] as Dictionary).has("step_height"):
			return float(g[k]["step_height"])
	return 0.35

## Decks, jetties and bridges (the wide thin timber boxes): stepping on at
## either end.
func _check_decks(st: RH.WState) -> void:
	var step_h := _step_height()
	var bx: Array = def.get("boxes", [])
	for i in bx.size():
		var s: Dictionary = bx[i]
		if not s.get("collide", true) or not AreaBuilder._flag_ok(s):
			continue
		var tag := String(s.get("tag", "base"))
		if (tag == "thaw" and st == RIME()) or (tag == "rime" and st != RIME()):
			continue
		var mn := AreaBuilder._v3(s["min"])
		var mx := AreaBuilder._v3(s["max"])
		var size := mx - mn
		if size.y >= 0.5 or maxf(size.x, size.z) < 1.5 or minf(size.x, size.z) < 0.8:
			continue
		var c := (mn + mx) * 0.5
		var along := Vector3(1, 0, 0) if size.x >= size.z else Vector3(0, 0, 1)
		var half := maxf(size.x, size.z) * 0.5
		for e in [-1.0, 1.0]:
			var edge: Vector3 = Vector3(c.x, mx.y, c.z) + along * float(e) * half
			var prof := _profile(edge - along * float(e) * 0.6, edge + along * float(e) * 1.2, mx.y + 1.0)
			var last: float = prof[0][1]
			var out_y: float = prof[prof.size() - 1][1]
			if is_nan(last) or is_nan(out_y) or absf(out_y - mx.y) > 1.2:
				continue      # the end stands over water or a drop: not a way on
			var worst := 0.0
			var gap := 0
			var prev := last
			var k := 1
			while k < prof.size():
				var y: float = prof[k][1]
				if is_nan(y) or y < prev - step_h:
					# no floor, or one far below: a slot between two decks if
					# the floor comes back within a few samples
					var back := -1
					for m in range(1, 5):
						if k + m < prof.size() and not is_nan(prof[k + m][1]) and absf(float(prof[k + m][1]) - prev) <= step_h:
							back = m
							break
					if back > 0:
						gap = maxi(gap, back)
						k += back
						continue
					if is_nan(y):
						gap = 99
						k += 1
						continue
				worst = maxf(worst, absf(y - prev))
				prev = y
				k += 1
			var label := "box#%d(%s) end" % [i, String(s.get("mat", "M_stone"))]
			if gap * 0.1 > float(T["gap_min"]):
				_add("threshold", label, edge, size, "a gap of %s with no floor in it between the deck's end and the ground beyond" % (
					"more than a metre" if gap >= 99 else "about %.1f m" % (gap * 0.1)))
			elif worst > step_h + float(T["step_slack"]):
				_add("threshold", label, edge, size,
					"a %.2f m step between the deck and the ground at its end (the Bearer climbs %.2f)" % [worst, step_h])

# ------------------------------------------------------------------ report and gate

func _owner(f: Dictionary) -> Array:
	for r in cfg.get("owners", []):
		if r.has("check") and String(r["check"]) != String(f["check"]):
			continue
		if r.has("id") and not String(f["id"]).match(String(r["id"])):
			continue
		return [String(r["owner"]), String(r.get("fix", ""))]
	return ["Lead", ""]

func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]

func _report(ids: Array, times: Dictionary, total_s: float) -> void:
	var all: Array = merged.values()
	all.sort_custom(func(a, b):
		if a["area"] != b["area"]:
			return ids.find(a["area"]) < ids.find(b["area"])
		if a["check"] != b["check"]:
			return String(a["check"]) < String(b["check"])
		var sa: Vector3 = a["size"]
		var sb: Vector3 = b["size"]
		if sa.x * sa.y * sa.z != sb.x * sb.y * sb.z:
			return sa.x * sa.y * sa.z > sb.x * sb.y * sb.z
		return str(a["pos"]) < str(b["pos"]))
	var rows: Array = []
	for f in all:
		var ow := _owner(f)
		rows.append({"area": f["area"], "check": f["check"], "id": f["id"], "pos": _v(f["pos"]), "size": _v(f["size"]),
			"passes": f["passes"], "detail": f["detail"], "path": f["path"], "owner": ow[0], "fix": ow[1]})
	# the gate: every offender must be a known one
	var base: Dictionary = {}
	if FileAccess.file_exists(BASELINE_PATH):
		base = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
	var known: Array = base.get("offenders", [])
	var used := {}
	var fresh: Array = []
	for r in rows:
		var hit := -1
		for i in known.size():
			var k: Dictionary = known[i]
			if used.has(i) or k["area"] != r["area"] or k["check"] != r["check"] or k["id"] != r["id"]:
				continue
			var kp: Array = k["pos"]
			if Vector3(kp[0], kp[1], kp[2]).distance_to(Vector3(r["pos"][0], r["pos"][1], r["pos"][2])) <= float(T["baseline_match_m"]):
				hit = i
				break
		if hit >= 0:
			used[hit] = true
		else:
			fresh.append(r)
	print("")
	print("== counts (area / pass / check)")
	for id in ids:
		for pn in counts.get(id, {}):
			print("  %-18s %-14s %s" % [id, pn, str(counts[id][pn])])
	print("")
	print("== known offenders (the baseline: %d, each with an owner)" % known.size())
	var grp := {}
	for k in known:
		if not _area_in(ids, String(k["area"])):
			continue
		var gk := "%s | %s | %s | %s" % [k["area"], k["check"], k["id"], k.get("owner", "?")]
		grp[gk] = int(grp.get(gk, 0)) + 1
	for gk in grp:
		print("  known x%-3d %s" % [grp[gk], gk])
	var stale := 0
	for i in known.size():
		if not used.has(i) and _area_in(ids, String(known[i]["area"])):
			stale += 1
			print("  gone (fixed? drop it from the baseline): %s %s %s at %s" % [known[i]["area"], known[i]["check"], known[i]["id"], str(known[i]["pos"])])
	print("")
	print("== new offenders: %d" % fresh.size())
	for r in fresh:
		print("  NEW %s | %s | %s | at %s | size %s | %s | %s" % [r["area"], r["check"], r["id"], str(r["pos"]), str(r["size"]),
			",".join(r["passes"]), r["detail"]])
	print("")
	for id in ids:
		var n_new := 0
		var n_all := 0
		for r in rows:
			if r["area"] == id:
				n_all += 1
		for r in fresh:
			if r["area"] == id:
				n_new += 1
		check(n_new == 0, "%s: no offender outside the allow-list and the baseline (%d known, %d new)" % [id, n_all - n_new, n_new])
	print("== MultiMeshes the audit could not read (no instance_xfs, not on the allow-list): %s" % str(unaudited))
	print("audit time: %.1f s total; per area %s" % [total_s, str(times)])
	var out := {"thresholds": T, "counts": counts, "times": times, "total_s": total_s, "offenders": rows,
		"new": fresh.size(), "stale": stale, "unaudited_multimeshes": unaudited}
	if _arg("collision-out") != "":
		var fo := FileAccess.open(_arg("collision-out"), FileAccess.WRITE)
		fo.store_string(JSON.stringify(out, " "))
		fo.close()
	if _arg("update-baseline") != "":
		var keep: Array = []
		for k in known:
			if not _area_in(ids, String(k["area"])):
				keep.append(k)      # areas not run this time stay as they were
		var offs: Array = keep
		for r in rows:
			offs.append({"area": r["area"], "check": r["check"], "id": r["id"], "pos": r["pos"], "size": r["size"],
				"passes": r["passes"], "owner": r["owner"], "fix": r["fix"]})
		var fb := FileAccess.open(ProjectSettings.globalize_path(BASELINE_PATH), FileAccess.WRITE)
		fb.store_string(JSON.stringify({"doc": "Known collision offenders (tools/test/collision_audit_test.gd). Each has an owner; the suite fails on anything not listed here. Regenerate with tools/audit_collision.sh --update-baseline, and only after the new entries have been routed.",
			"offenders": offs}, " "))
		fb.close()
		print("baseline written: %d offenders" % offs.size())

func _area_in(ids: Array, a: String) -> bool:
	return ids.has(a)
