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
	"thorn_heap": {"fam": "M_rime", "stems": 12, "lean": 0.5, "core": 0.7},
}

## Tripo hero meshes (docs/art/LOOK_PASS.md, tools/art/manifest.json): each
## kind picks among its variants per instance; a "<name>_far.glb" (decimated)
## takes over past NEAR. Shaded through MaterialLib.hero_mat with the family
## given (snow crust, THAW/RIME branch) plus wind sway. Missing files fall
## back to the primitives below, so the API and layout never change.
##   kind -> [[glb name, family, wind sway m, wind height m], ...]
const HERO_TREES := {
	"pine": [["tr_pine_a", "M_needles", 0.35, 14.0], ["tr_pine_b", "M_needles", 0.3, 12.0]],
	"birch": [["tr_birch_a2", "M_leaves", 0.45, 10.0], ["tr_birch_b", "M_leaves", 0.45, 10.0]],
	"grave_pine": [["tr_grave_pine", "M_needles", 0.2, 10.0]],
	"snag": [["tr_snag", "M_bark_pine", 0.05, 9.0]],
}
## style -> [glb name, family(, more glb names)]: one ~2 m hedge section,
## repeated along the line; extra names are variants taken in turn.
## The frozen thorn is modelled (tools/art/procedural/thorn_rime.py): grown
## branch by branch at its full height, so it is set in ONE course ("single"
## in HERO_SINGLE) and never stretched: stretching a section is what turned
## the old one into flat shards.
const HERO_HEDGES := {
	"laid": ["hd_laid2", "M_thorn"],
	"thicket": ["hd_laid2", "M_thorn"],
	"thorn": ["hd_thorn3a", "M_thorn_rime", "hd_thorn3b"],
	"thorn_heap": ["hd_thorn_heap", "M_thorn_rime"],
}
## style -> overlap of neighbouring sections (fraction of a section's length)
const HERO_SINGLE := {"thorn": 0.34, "thorn_heap": 0.3}
const HERO_DIR := "res://assets/models/forest/"
## Draw budget (a real GPU counted 9.5 M primitives looking down the hedge
## maze: full-detail sections and trees out to 45-70 m, each drawn again in
## all four shadow splits). Three bands per hero now: the full mesh close by,
## the decimated mesh with shadows through the middle distance, and the
## decimated mesh without shadows beyond it, fading out at the far end.
const NEAR := 42.0
const TREE_MID := 95.0
const TREE_FAR := 170.0
const HEDGE_NEAR := 26.0
## the modelled thorn is ~20k triangles a section close up (every twig and
## thorn is geometry), so its full mesh is kept to the few sections in reach
const THORN_NEAR := 13.0
const HEDGE_MID := 60.0
const HEDGE_FAR := 110.0
const RANGE_MARGIN := 4.0

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
		var vs: Array = []
		for hv in HERO_TREES.get(kind, []):
			if ResourceLoader.exists(HERO_DIR + String(hv[0]) + ".glb"):
				vs.append(hv)
		if vs.is_empty():
			# grave pine and snag fall back to the plain pine
			_emit(area, "tree_" + ("birch" if kind == "birch" else "pine"), "base", trees[kind], 160.0)
		else:
			for vi in vs.size():
				var pick: Array = []
				for i in trees[kind].size():
					if i % vs.size() == vi:
						pick.append(trees[kind][i])
				var key := "hero|%s|%s|%s|%s" % [vs[vi][0], vs[vi][1], vs[vi][2], vs[vi][3]]
				if ResourceLoader.exists(HERO_DIR + String(vs[vi][0]) + "_far.glb"):
					_emit(area, key, "base", pick, NEAR, 0.0)
					var far_key := key.replace("hero|%s|" % vs[vi][0], "hero|%s_far|" % vs[vi][0])
					_emit(area, far_key, "base", pick, TREE_MID, NEAR)
					_emit(area, far_key, "base", pick, TREE_FAR, TREE_MID, false)
				else:
					_emit(area, key, "base", pick, 180.0)
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
		cyl.radius = {"pine": 0.3, "grave_pine": 0.7, "snag": 0.25}.get(kind, 0.2) * sv.x
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = Vector3(0, 2.0, 0)
		body.add_child(cs)
		body.position = xf.origin
		area.attach(body, "base")

## Chunked MultiMeshes of one mesh.
static func _emit(area: Area, key: String, tag: String, xfs: Array, range_end: float, range_begin := 0.0, shadows := true,
		fade := true, shadow_only := false) -> void:
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
		var label := key
		if key.begins_with("hero|"):
			# keep the node names the primitives had (tests and tools find
			# "Forest_tree_*"); the key itself carries '|'
			var hn := key.split("|")[1]
			label = ("tree_" if hn.begins_with("tr_") else "hedge_") + hn
		mmi.name = "Forest_%s_%s_%d_%d" % [label, tag, k.x, k.y]
		mmi.multimesh = mm
		mmi.position = c
		mmi.visibility_range_end = range_end
		mmi.visibility_range_end_margin = RANGE_MARGIN
		if not shadows:
			# the last band: no shadow passes, and it thins out instead of popping
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if fade:
				mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				mmi.name = "Forest_%s_%s_%d_%d_far" % [label, tag, k.x, k.y]
		if shadow_only:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			mmi.name = "Forest_%s_%s_%d_%d_shadow" % [label, tag, k.x, k.y]
		if range_begin > 0.0:
			# A range only changes state a margin past its threshold, and a
			# camera that spawns inside the margin starts with it hidden: a
			# band is certain only below end - margin and above begin + margin.
			# So each band starts two margins before the one inside it ends
			# (the old single-threshold handoff left a ring 20 m deep where a
			# fresh camera saw neither).
			mmi.visibility_range_begin = maxf(range_begin - RANGE_MARGIN * 2.0, 0.1)
			mmi.visibility_range_begin_margin = RANGE_MARGIN
		area.attach(mmi, tag)

# ------------------------------------------------------------ meshes

static func _mesh(key: String, mode: int) -> Mesh:
	var ck := "%s|%d" % [key, mode]
	if _cache.has(ck):
		return _cache[ck]
	if key.begins_with("hero|"):
		var hp := key.split("|")
		var hm := _hero(hp[1], hp[2], mode, float(hp[3]) if hp.size() > 3 else 0.0, float(hp[4]) if hp.size() > 4 else 10.0)
		_cache[ck] = hm
		return hm
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

## The first mesh of a hero GLB re-shaded through MaterialLib.hero_mat, with
## wind sway on the material when asked for.
static func _hero(name: String, fam: String, mode: int, sway: float, sway_h: float) -> Mesh:
	var path := HERO_DIR + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var inst := (load(path) as PackedScene).instantiate()
	var out: Mesh = null
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var src := (c as MeshInstance3D).mesh
		if src == null:
			continue
		out = src.duplicate() as Mesh
		for si in out.get_surface_count():
			var m := MaterialLib.hero_mat(src.surface_get_material(si), fam, mode)
			if sway > 0.0:
				m = m.duplicate()
				m.set_shader_parameter("wind_sway", sway)
				m.set_shader_parameter("wind_height", sway_h)
			out.surface_set_material(si, m)
		break
	inst.free()
	return out

## A hero hedge section's length along its own X (the GLBs are processed to
## run along X), for spacing them down a line.
static func _hero_len(name: String) -> float:
	var ck := "len|" + name
	if not _cache.has(ck):
		var m := _hero(name, "M_thorn", 0, 0.0, 1.0)
		_cache[ck] = m.get_aabb() if m != null else AABB()
	var bb: AABB = _cache[ck]
	return bb.size.x

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
	var heroes: Array = []
	var bit := AreaBuilder._tag_bit(tag)
	var hh: Array = HERO_HEDGES.get(style, [])
	var hero_ok := not hh.is_empty() and ResourceLoader.exists(HERO_DIR + String(hh[0]) + ".glb")
	var hlen := _hero_len(String(hh[0])) if hero_ok else 0.0
	var hbb: AABB = _cache.get("len|" + String(hh[0]), AABB()) if hero_ok else AABB()
	if hlen < 0.3:
		hero_ok = false
	for k in pts.size() - 1:
		var a := Vector2(float(pts[k][0]), float(pts[k][1]))
		var b := Vector2(float(pts[k + 1][0]), float(pts[k + 1][1]))
		var d := b - a
		var L := d.length()
		if L < 0.05:
			continue
		var dir := d / L
		var yaw := atan2(-dir.y, dir.x)
		if hero_ok:
			# sections end to end with a little overlap, each turned and
			# flipped at random so the repeat never lines up
			var nsec := maxi(1, int(ceil(L / (hlen * 0.85))))
			var step := L / nsec
			for i in nsec:
				var p := a + dir * (step * (i + 0.5))
				var y := terrain.height_at(p.x, p.y)
				# a tall wall is two courses of sections, not one stretched
				# section (stretching turns thorn into reeds)
				var hy := maxf(hbb.size.y, 0.3)
				var rows := maxi(1, int(ceil(h / (hy * 1.6))))
				# the bond's jitter has its own stream: the layout stream (trees,
				# stems) must not shift with a look change
				var jit := RandomNumberGenerator.new()
				jit.seed = hash(Vector2i(int(p.x * 10.0), int(p.y * 10.0)))
				for r in rows:
					var fl := 1.0 if rng.randf() < 0.5 else -1.0
					var rb := Basis(Vector3.UP, yaw + (PI if fl < 0.0 else 0.0) + (jit.randf_range(-0.14, 0.14) if r > 0 else 0.0))
					# upper courses narrower and sunk into the one below, so
					# their footing strip hides inside its mass. Each upper
					# section sits half a section along and at its own depth,
					# so the join is a ragged brick bond, not a level band.
					var sc := Vector3(step / hlen * (1.12 + 0.1 * r), h / rows / hy * (rng.randf_range(1.3, 1.45) + jit.randf_range(0.0, 0.15)), w / maxf(hbb.size.z, 0.3) * (1.0 - 0.32 * r))
					var along := dir * (step * 0.5 * float(r % 2))
					var q := p + along
					var qy := y if r == 0 else terrain.height_at(q.x, q.y)
					var sink := 0.6 if r == 0 else jit.randf_range(0.42, 0.68)
					heroes.append(Transform3D(rb.scaled_local(sc), Vector3(q.x, qy - 0.08 + r * h / rows * sink, q.y)))
		# stems
		var t := 0.0 if not hero_ok else L
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
			if not hero_ok:
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
	if hero_ok:
		var names: Array = [hh[0]]
		for vi in range(2, hh.size()):
			if ResourceLoader.exists(HERO_DIR + String(hh[vi]) + ".glb"):
				names.append(hh[vi])
		var near := THORN_NEAR if HERO_SINGLE.has(style) else HEDGE_NEAR
		# frozen wood does not sway
		var sway := "0|1.5" if HERO_SINGLE.has(style) else "0.04|1.5"
		for vi in names.size():
			var pick: Array = []
			for i in heroes.size():
				if i % names.size() == vi:
					pick.append(heroes[i])
			var hk := "hero|%s|%s|%s" % [names[vi], hh[1], sway]
			if ResourceLoader.exists(HERO_DIR + String(names[vi]) + "_far.glb"):
				var hfar := hk.replace("hero|%s|" % names[vi], "hero|%s_far|" % names[vi])
				if HERO_SINGLE.has(style):
					# the full thorn mesh would be drawn again in every shadow
					# split: close up it only receives, and the far mesh casts
					# for it (a shadow cannot show a twig anyway)
					_emit(area, hk, tag, pick, near, 0.0, false, false)
					_emit(area, hfar, tag, pick, near, 0.0, true, false, true)
				else:
					_emit(area, hk, tag, pick, near)
				_emit(area, hfar, tag, pick, HEDGE_MID, near)
				_emit(area, hfar, tag, pick, HEDGE_FAR, HEDGE_MID, false)
			else:
				_emit(area, hk, tag, pick, 140.0)
		return
	_emit(area, "stem|" + style, tag, stems, 120.0)
	_emit(area, "core|" + style, tag, cores, 140.0)
