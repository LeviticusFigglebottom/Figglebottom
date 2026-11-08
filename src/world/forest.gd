class_name Forest
## Procedural wood (Thornwold): pine and birch, laid hedges, frozen thorn and
## the thickets that hold a wood's edges. Simple geometry (primitive meshes
## with their own UVs, MaterialLib families only) so the materials carry the
## look; one MultiMesh per kind and state, chunked for visibility range.
##
## "forest": {"seed": n, "clear": [[x, z, r], ...],
##   "trees": [{"kind": "pine"|"birch", "count", "region": [x0, z0, x1, z1],
##              "scale": [a, b], "path_max": 0.25, "slope_min": 0.8}],
##   "place": [{"kind", "at": [x, z], "scale"}],
##   "hedges": [{"pts": [[x, z], ...], "style": "laid"|"thorn"|"thicket",
##               "h", "w", "tag"}]}

const CHUNK := 32.0
const STYLES := {
	"laid": {"fam": "M_thorn", "stems": 7, "lean": 0.62, "core": 0.55},
	"thorn": {"fam": "M_rime", "stems": 9, "lean": 0.35, "core": 0.6},
	"thicket": {"fam": "M_thorn", "stems": 11, "lean": 0.2, "core": 0.75},
}

static var _cache: Dictionary = {}

static func build(area: Area, terrain: Terrain, spec: Dictionary, keep_clear: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1))
	var clear: Array = keep_clear.duplicate()
	for c in spec.get("clear", []):
		clear.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	var trees: Dictionary = {}       # kind -> [Transform3D]
	for rule in spec.get("trees", []):
		var kind := String(rule.get("kind", "pine"))
		var reg: Array = rule["region"]
		var sc: Array = rule.get("scale", [0.8, 1.2])
		var want := int(rule.get("count", 50))
		var placed := 0
		var tries := 0
		while placed < want and tries < want * 20:
			tries += 1
			var x := rng.randf_range(float(reg[0]), float(reg[2]))
			var z := rng.randf_range(float(reg[1]), float(reg[3]))
			if not terrain.contains(x, z) or Scatter._blocked(clear, x, z):
				continue
			if terrain.splat_at(x, z, 1) > float(rule.get("path_max", 0.25)):
				continue
			if terrain.normal_at(x, z).y < float(rule.get("slope_min", 0.8)):
				continue
			var s := rng.randf_range(float(sc[0]), float(sc[1]))
			_tree(trees, kind, Vector3(x, terrain.height_at(x, z) - 0.15, z), s, rng)
			placed += 1
	for p in spec.get("place", []):
		var at: Array = p["at"]
		var x := float(at[0])
		var z := float(at[1])
		_tree(trees, String(p["kind"]), Vector3(x, terrain.height_at(x, z) - 0.15, z), float(p.get("scale", 1.0)), rng)
	for kind in trees:
		_emit(area, "tree_" + kind, "base", trees[kind], 160.0)
		_tree_bodies(area, kind, trees[kind])
	for hd in spec.get("hedges", []):
		_hedge(area, terrain, hd, rng)

static func _tree(trees: Dictionary, kind: String, pos: Vector3, s: float, rng: RandomNumberGenerator) -> void:
	if not trees.has(kind):
		trees[kind] = []
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.03, 0.03))
	trees[kind].append(Transform3D(b.scaled(Vector3(s, s * rng.randf_range(0.9, 1.12), s)), pos))

static func _tree_bodies(area: Area, kind: String, xfs: Array) -> void:
	var bit := AreaBuilder._tag_bit("base")
	for t in xfs:
		var xf: Transform3D = t
		var sv := xf.basis.get_scale()
		var body := StaticBody3D.new()
		body.collision_layer = 1 << (bit - 1)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = (0.3 if kind == "pine" else 0.2) * sv.x
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = Vector3(0, 2.0, 0)
		body.add_child(cs)
		body.position = xf.origin
		area.attach(body, "base")

## Chunked MultiMeshes of one mesh.
static func _emit(area: Area, key: String, tag: String, xfs: Array, range_end: float) -> void:
	var mode := 1 if tag == "thaw" else (2 if tag == "rime" else 0)
	var mesh := _mesh(key, mode)
	var chunks: Dictionary = {}
	for t in xfs:
		var xf: Transform3D = t
		var k := Vector2i(int(floor(xf.origin.x / CHUNK)), int(floor(xf.origin.z / CHUNK)))
		if not chunks.has(k):
			chunks[k] = []
		chunks[k].append(xf)
	for k in chunks:
		var list: Array = chunks[k]
		var c := Vector3((k.x + 0.5) * CHUNK, 0.0, (k.y + 0.5) * CHUNK)
		c.y = (list[0] as Transform3D).origin.y
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var t2: Transform3D = list[i]
			t2.origin -= c
			mm.set_instance_transform(i, t2)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Forest_%s_%s_%d_%d" % [key, tag, k.x, k.y]
		mmi.multimesh = mm
		mmi.position = c
		mmi.visibility_range_end = range_end
		mmi.visibility_range_end_margin = 10.0
		area.attach(mmi, tag)

# ------------------------------------------------------------ meshes

static func _mesh(key: String, mode: int) -> Mesh:
	var ck := "%s|%d" % [key, mode]
	if _cache.has(ck):
		return _cache[ck]
	var am := ArrayMesh.new()
	match key:
		"tree_pine":
			# a tall bare stem and a ragged crown of needle tiers near the top
			_part(am, _cyl(0.1, 0.3, 15.0, 8), Transform3D(Basis.IDENTITY, Vector3(0, 7.5, 0)), "M_bark_pine", mode)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 5:
				var r := 2.3 - i * 0.38
				var y := 8.0 + i * 1.5
				st.append_from(_cyl(0.0, r, 2.4, 9), 0, Transform3D(Basis(Vector3.UP, i * 0.9), Vector3(0.15 * sin(i * 2.0), y, 0.15 * cos(i * 1.3))))
			_commit(am, st, "M_needles", mode)
		"tree_birch":
			# a slim pale stem leaning a little, a light loose crown
			_part(am, _cyl(0.07, 0.17, 12.0, 8), Transform3D(Basis(Vector3.FORWARD, 0.03), Vector3(0, 6.0, 0)), "M_bark_birch", mode)
			var st2 := SurfaceTool.new()
			st2.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 4:
				var sm := SphereMesh.new()
				sm.radius = 1.5 - i * 0.12
				sm.height = 2.0
				sm.radial_segments = 8
				sm.rings = 4
				st2.append_from(sm, 0, Transform3D(Basis.IDENTITY, Vector3(0.6 * sin(i * 2.4), 8.0 + i * 1.1, 0.6 * cos(i * 2.4))))
			_commit(am, st2, "M_leaves", mode)
		_:
			# hedge stem: a thin square rod 1 m long (scaled per instance)
			var parts := key.split("|")
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 1.0, 0.05) if parts[0] == "stem" else Vector3(1.0, 1.0, 1.0)
			var fam: String = STYLES.get(parts[1], STYLES["laid"])["fam"]
			_part(am, bm, Transform3D.IDENTITY, fam, mode)
	_cache[ck] = am
	return am

static func _cyl(rt: float, rb: float, h: float, segs: int) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = rt
	cm.bottom_radius = rb
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return cm

static func _part(am: ArrayMesh, src: Mesh, xf: Transform3D, fam: String, mode: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(src, 0, xf)
	_commit(am, st, fam, mode)

static func _commit(am: ArrayMesh, st: SurfaceTool, fam: String, mode: int) -> void:
	st.generate_normals()
	st.commit(am)
	am.surface_set_material(am.get_surface_count() - 1, MaterialLib.get_mat(fam, mode))

# ------------------------------------------------------------ hedges

## A hedge along a line: stems laid at a lean and crossing, a dense core, and
## box colliders segment by segment.
static func _hedge(area: Area, terrain: Terrain, hd: Dictionary, rng: RandomNumberGenerator) -> void:
	var style := String(hd.get("style", "laid"))
	var tag := String(hd.get("tag", "base"))
	var st: Dictionary = STYLES.get(style, STYLES["laid"])
	var h := float(hd.get("h", 1.3))
	var w := float(hd.get("w", 1.0))
	var pts: Array = hd["pts"]
	var stems: Array = []
	var cores: Array = []
	var bit := AreaBuilder._tag_bit(tag)
	for k in pts.size() - 1:
		var a := Vector2(float(pts[k][0]), float(pts[k][1]))
		var b := Vector2(float(pts[k + 1][0]), float(pts[k + 1][1]))
		var d := b - a
		var L := d.length()
		if L < 0.05:
			continue
		var dir := d / L
		var yaw := atan2(-dir.y, dir.x)
		# stems
		var t := 0.0
		while t < L:
			var p := a + dir * t
			var y := terrain.height_at(p.x, p.y)
			for i in int(st["stems"]):
				var off := (rng.randf() - 0.5) * w
				var q := p + Vector2(-dir.y, dir.x) * off
				var lean := float(st["lean"]) * (1.0 if i % 2 == 0 else -1.0) + rng.randf_range(-0.3, 0.3)
				var ln := h * rng.randf_range(0.9, 1.5)
				var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, lean) * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
				var top := bs * Vector3(0, ln, 0)
				var lift := clampf(h / maxf(top.y, 0.1), 0.7, 1.4)
				stems.append(Transform3D(bs.scaled_local(Vector3(1, ln * lift, 1)), Vector3(q.x, y - 0.1, q.y) + bs * Vector3(0, ln * lift * 0.5, 0)))
			t += 0.45
		# a dense core and one collider per ~2 m
		var n := maxi(1, int(ceil(L / 2.0)))
		for i in n:
			var p0 := a + dir * (L * (i + 0.5) / n)
			var y0 := terrain.height_at(p0.x, p0.y)
			var seg := L / n
			var cb := Basis(Vector3.UP, yaw)
			var core := float(st["core"])
			cores.append(Transform3D(cb.scaled_local(Vector3(seg * 1.02, h * core, w * core)), Vector3(p0.x, y0 + h * core * 0.5 - 0.05, p0.y)))
			var body := StaticBody3D.new()
			body.collision_layer = 1 << (bit - 1)
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(seg + 0.2, h + 0.4, maxf(w, 0.8))
			cs.shape = bx
			body.add_child(cs)
			body.transform = Transform3D(cb, Vector3(p0.x, y0 + h * 0.5, p0.y))
			area.attach(body, tag)
	_emit(area, "stem|" + style, tag, stems, 120.0)
	_emit(area, "core|" + style, tag, cores, 140.0)
