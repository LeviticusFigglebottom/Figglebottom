class_name Scatter
## Procedural dressing on a Terrain (ADR 0003 §5): rocks, boulders, turf
## hummocks, driftwood, peat stacks, and fences (dry-stone, wattle) draped
## along authored lines so they ride the contour. Fixed seed: the same JSON
## always dresses the land the same way. Nothing is axis-aligned.
##
## "scatter": {"seed": n, "clear": [[x, z, r], ...],
##   "rules": [{"kind", "count", "region": [x0, z0, x1, z1], "slope": [min_ny, max_ny],
##              "h": [min, max], "scale": [a, b], "path_max": 0.3, "tag"}],
##   "place": [{"kind", "at": [x, z], "rot", "scale", "tag"}],
##   "fences": [{"kind": "drystone"|"wattle", "points": [[x, z], ...], "tag"}]}

const KINDS := ["rock", "boulder", "hummock", "driftwood", "peat_stack", "stone_fence", "wattle_fence",
	"standing_stone", "ice_floe", "peat_wall", "peat_row"]

static var _mesh_cache: Dictionary = {}

static func build(area: Area, terrain: Terrain, spec: Dictionary, keep_clear: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1))
	var clear: Array = keep_clear.duplicate()
	for c in spec.get("clear", []):
		clear.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	# instances grouped per (kind, tag) for one MultiMesh each
	var groups: Dictionary = {}
	for rule in spec.get("rules", []):
		var kind := String(rule.get("kind", "rock"))
		var tag := String(rule.get("tag", "base"))
		var reg: Array = rule.get("region", [-50, -50, 50, 50])
		var sl: Array = rule.get("slope", [0.0, 1.0])
		var hr: Array = rule.get("h", [-1000, 1000])
		var sc: Array = rule.get("scale", [0.6, 1.4])
		var path_max := float(rule.get("path_max", 0.35))
		var want := int(rule.get("count", 10))
		var placed := 0
		var tries := 0
		while placed < want and tries < want * 30:
			tries += 1
			var x := rng.randf_range(float(reg[0]), float(reg[2]))
			var z := rng.randf_range(float(reg[1]), float(reg[3]))
			if not terrain.contains(x, z):
				continue
			var y := terrain.height_at(x, z)
			var nrm := terrain.normal_at(x, z)
			if nrm.y < float(sl[0]) or nrm.y > float(sl[1]):
				continue
			if y < float(hr[0]) or y > float(hr[1]):
				continue
			if terrain.splat_at(x, z, 1) > path_max:
				continue
			if _blocked(clear, x, z):
				continue
			if rule.has("drop_min") and terrain.drop_at(x, z, float(rule.get("drop_r", 4.0))) < float(rule["drop_min"]):
				continue    # cliff-top boulders: only where the land falls away
			var s := rng.randf_range(float(sc[0]), float(sc[1]))
			# a stone needs a seat: no perching on a cliff lip or a knife-edge
			var fr := float(rule.get("flat", 0.9 * s + 0.4))
			var tol := fr * (1.3 if kind == "boulder" else 0.75)
			var bumpy := false
			for o in [Vector2(fr, 0), Vector2(-fr, 0), Vector2(0, fr), Vector2(0, -fr)]:
				if absf(terrain.height_at(x + o.x, z + o.y) - y) > tol:
					bumpy = true
			if bumpy:
				continue
			var xf := _seat(kind, Vector3(x, y, z), nrm, rng.randf() * TAU, s, rng)
			_add(groups, kind, tag, xf)
			placed += 1
	for p in spec.get("place", []):
		var at: Array = p["at"]
		var x := float(at[0])
		var z := float(at[1])
		var y := float(p["y"]) if p.has("y") else terrain.height_at(x, z)
		var nrm := Vector3.UP if p.has("y") else terrain.normal_at(x, z)
		var sc = p.get("scale", 1.0)
		var xf := _seat(String(p["kind"]), Vector3(x, y, z), nrm,
				deg_to_rad(float(p.get("rot", rng.randf() * 360.0))), 1.0 if sc is Array else float(sc), rng)
		if sc is Array:     # an explicit [x, y, z] scale: floes laid flat on the water
			xf.basis = xf.basis.orthonormalized().scaled_local(Vector3(sc[0], sc[1], sc[2]))
		_add(groups, String(p["kind"]), String(p.get("tag", "base")), xf)
	for f in spec.get("fences", []):
		_fence(groups, terrain, f, rng)
	for key in groups:
		var parts := String(key).split("|")
		_emit(area, parts[0], parts[1], groups[key])

static func _blocked(clear: Array, x: float, z: float) -> bool:
	for c in clear:
		var v: Vector3 = c
		if Vector2(x - v.x, z - v.y).length() < v.z:
			return true
	return false

static func _add(groups: Dictionary, kind: String, tag: String, xf: Transform3D) -> void:
	var key := kind + "|" + tag
	if not groups.has(key):
		groups[key] = []
	groups[key].append(xf)

## Seat a piece on the slope: rocks bed in and lean with the land; built
## things (peat stacks, stones) stand upright but still turn freely.
static func _seat(kind: String, pos: Vector3, nrm: Vector3, yaw: float, s: float,
		rng: RandomNumberGenerator) -> Transform3D:
	var up := Vector3.UP
	match kind:
		"rock", "boulder", "hummock", "driftwood", "ice_floe":
			up = Vector3.UP.lerp(nrm, 0.7).normalized()
		_:
			up = Vector3.UP.lerp(nrm, 0.12).normalized()
	var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, yaw)
	var sv := Vector3.ONE * s
	match kind:
		"rock", "boulder":
			sv = Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.55, 0.95), s * rng.randf_range(0.8, 1.3))
			pos.y -= s * 0.18
		"hummock":
			sv = Vector3(s, s * rng.randf_range(0.6, 1.0), s * rng.randf_range(0.7, 1.1))
			pos.y -= 0.08
		"driftwood":
			b = b * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
		"peat_stack":
			# some stacks built higher, some sagging
			sv = Vector3(s * rng.randf_range(0.9, 1.15), s * rng.randf_range(0.75, 1.45), s * rng.randf_range(0.9, 1.1))
		"standing_stone":
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
			sv = Vector3(s, s, s * 0.5)     # a slab, not a boulder
			pos.y -= 0.3
	return Transform3D(b.scaled_local(sv), pos)

static func _fence(groups: Dictionary, terrain: Terrain, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind := "stone_fence" if String(f.get("kind", "drystone")) == "drystone" else "wattle_fence"
	var tag := String(f.get("tag", "base"))
	var pts: Array = f.get("points", [])
	var seg_len := 2.0
	for k in pts.size() - 1:
		var a := Vector2(float(pts[k][0]), float(pts[k][1]))
		var b := Vector2(float(pts[k + 1][0]), float(pts[k + 1][1]))
		var n := maxi(1, int(round(a.distance_to(b) / seg_len)))
		for i in n:
			var p0 := a.lerp(b, float(i) / n)
			var p1 := a.lerp(b, float(i + 1) / n)
			var mid := (p0 + p1) * 0.5
			var h0 := terrain.height_at(p0.x, p0.y)
			var h1 := terrain.height_at(p1.x, p1.y)
			var d := p1 - p0
			var yaw := atan2(-d.y, d.x)
			var pitch := atan2(h1 - h0, d.length())
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch)
			basis = basis * Basis(Vector3.UP, rng.randf_range(-0.05, 0.05))
			var len_s := d.length() / seg_len * 1.04
			var pos := Vector3(mid.x, (h0 + h1) * 0.5 - 0.06, mid.y)
			_add(groups, kind, tag, Transform3D(basis.scaled_local(Vector3(len_s, rng.randf_range(0.9, 1.1), 1.0)), pos))

## Tripo hero meshes (assets/models/scatter, tools/art/manifest.json) that
## replace the primitive stand-ins: each instance picks one variant, so a
## field of a few hundred stones uses a handful of real rocks turned and
## scaled every way ([glb, family, size factor to fit the primitive's slot]).
## Missing files fall back to the primitives.
const HERO := {
	"rock": [["sc_stone", "M_stone_dark", 1.0], ["sc_slab", "M_stone_dark", 0.6], ["sc_cliffchunk", "M_stone_dark", 0.62]],
	"boulder": [["sc_boulder", "M_stone_dark", 1.0], ["sc_cliffchunk", "M_stone_dark", 1.1], ["sc_slab", "M_stone_dark", 1.05]],
	# the wrack line's wood: the Tripo log at under half its 3 m, and four small
	# modelled pieces (tools/art/procedural/props_saltfell.py), taken in turn
	"driftwood": [["sc_driftlog", "M_drift", 0.5], ["sc_drift_branch", "M_drift", 1.0], ["sc_drift_billet", "M_drift", 1.0],
		["sc_drift_plank", "M_drift", 1.0], ["sc_drift_stump", "M_drift", 1.0]],
	# 2 m sections laid end to end: a little oversize so each buries its
	# square end in the next
	"stone_fence": [["sc_dyke", "M_drystone", 1.16]],
	"wattle_fence": [["sc_wattle", "M_wood", 0.98]],
	# the Lowe's own stacks (BIOMES.md): cut peats laid herringbone, modelled
	# (tools/art/procedural/props_lowe.py); a straight wall and a footed row beside it
	"peat_stack": [["res://assets/models/kit/kit_lw_peat_stack_p.glb", "M_peat", 0.85]],
	"peat_wall": [["res://assets/models/kit/kit_lw_peat_wall_p.glb", "M_peat", 1.0]],
	"peat_row": [["res://assets/models/kit/kit_lw_peat_row_p.glb", "M_peat", 1.0]],
	# the Lowe's carved stone, already made for the lineups
	"standing_stone": [["res://assets/models/landmarks/lm_standing_stone.glb", "M_drystone", 0.78]],
}

## One MultiMesh per kind, tag (and hero variant), plus colliders for what
## you can't walk through.
static func _emit(area: Area, kind: String, tag: String, xfs: Array) -> void:
	var mode := 1 if tag == "thaw" else (2 if tag == "rime" else 0)
	var variants: Array = []
	for hv in HERO.get(kind, []):
		var hm := _hero_mesh(String(hv[0]), String(hv[1]), mode)
		if hm != null:
			variants.append([String(hv[0]), hm, float(hv[2])])
	if variants.is_empty():
		variants.append([kind, _mesh(kind, mode), 1.0])
	# chunked like the ground cover: one area-wide MultiMesh was never
	# frustum-culled, and its 70 m range was measured to the middle of the
	# whole area, so the Strand's pebbles blinked out as you walked the beach.
	# Each chunk holds one MultiMesh per hero variant.
	var chunks: Dictionary = {}
	for i in xfs.size():
		var vi := i % variants.size()
		var t: Transform3D = xfs[i]
		var key := Vector3i(int(floor(t.origin.x / SCATTER_CHUNK)), vi, int(floor(t.origin.z / SCATTER_CHUNK)))
		t.basis = t.basis.scaled_local(Vector3.ONE * float(variants[vi][2]))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
	var small: bool = kind in ["rock", "hummock", "driftwood"]
	for key in chunks:
		var cx: Array = chunks[key]
		var c := Vector3.ZERO
		for xf in cx:
			c += (xf as Transform3D).origin
		c /= float(cx.size())
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = variants[key.y][1]
		mm.instance_count = cx.size()
		var local: Array[Transform3D] = []
		for i in cx.size():
			var t: Transform3D = cx[i]
			t.origin -= c
			mm.set_instance_transform(i, t)
			local.append(t)
		var mmi := MultiMeshInstance3D.new()
		# the headless server keeps no instance buffer: the collision audit
		# (tools/test/collision_audit_test.gd) reads the transforms from here
		mmi.set_meta("instance_xfs", local)
		mmi.name = "Scatter_%s_%s_%d_%d" % [kind, tag, key.x, key.z] + ("" if variants.size() == 1 else "_%d" % key.y)
		mmi.multimesh = mm
		mmi.position = c
		if small:
			mmi.visibility_range_end = 70.0
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		area.attach(mmi, tag)
	var bit := AreaBuilder._tag_bit(tag)
	for i in xfs.size():
		var t: Transform3D = xfs[i]
		var vi := i % variants.size()
		var shape: Shape3D = null
		var off := Vector3.ZERO
		# physics bodies must not carry scale: bake it into the shape
		var sv := t.basis.get_scale()
		match kind:
			"stone_fence", "wattle_fence":
				var bx := BoxShape3D.new()
				bx.size = Vector3(2.0, 1.3, 0.55) * sv
				shape = bx
				off = Vector3(0, 0.62, 0)
			"rock", "boulder", "driftwood", "peat_stack", "peat_wall", "peat_row", "standing_stone", "ice_floe":
				if kind == "ice_floe" and sv.y < 1.0:
					continue      # flat channel floes: the ice sheet carries you
				# what is drawn is what stops you: the hull of this instance's
				# own mesh. (The old shapes were sized for the primitive
				# stand-ins: with the hero meshes a "small" rock stood 1.5 m
				# tall with no collider, driftwood snags were walked through,
				# and a boulder's sphere sat inside, or beside, its stone.)
				sv *= float(variants[vi][2])
				shape = _hull(variants[vi][1] as Mesh, sv, Transform3D(t.basis.orthonormalized(), t.origin), area.terrain)
				if shape == null:
					continue      # ankle stones: step over them
			_:
				continue
		var body := StaticBody3D.new()
		body.collision_layer = 1 << (bit - 1)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = off * sv
		body.add_child(cs)
		body.transform = Transform3D(t.basis.orthonormalized(), t.origin)
		Surfaces.stamp(body, Surfaces.lookup("scatter", kind))
		body.add_to_group("scatter_body")
		area.attach(body, tag)

## A scatter piece stops the Bearer once it stands this far out of the
## ground and is this wide: below that it is stepped over. (Just under the
## collision audit's 0.6 m, data/collision_audit.json, which measures from
## the navmesh.)
const SOLID_MIN_H := 0.55
const SOLID_MIN_W := 0.5
const HULL_INSET := 0.2

static var _hull_cache: Dictionary = {}

## The convex hull of `mesh` at scale sv, or null for a piece too low or too
## thin to be an obstacle where it is seated (xf: its unscaled transform).
static func _hull(mesh: Mesh, sv: Vector3, xf: Transform3D, terrain: Terrain) -> ConvexPolygonShape3D:
	if mesh == null:
		return null
	var ab := mesh.get_aabb()
	if maxf(ab.size.x * sv.x, ab.size.z * sv.z) < SOLID_MIN_W:
		return null
	var key := mesh.get_rid()
	if not _hull_cache.has(key):
		# the exact hull: the simplified one sits inside the stone, and a
		# rock that just clears the threshold measured too low to get one
		var base := mesh.create_convex_shape(true, false) as ConvexPolygonShape3D
		_hull_cache[key] = base.points if base != null else PackedVector3Array()
	var pts: PackedVector3Array = _hull_cache[key]
	if pts.size() < 4:
		return null
	var scaled := PackedVector3Array()
	scaled.resize(pts.size())
	var proud := 0.0
	# drawn in by HULL_INSET a side: a shoulder brushes the stone's flank, and
	# the ways the generators left between stones stay open (hard against
	# the mesh, two boulders closed the drove-road's notch at the tarn)
	var c := ab.get_center() * sv
	var fx := maxf(0.6, 1.0 - 2.0 * HULL_INSET / maxf(ab.size.x * sv.x, 0.01))
	var fz := maxf(0.6, 1.0 - 2.0 * HULL_INSET / maxf(ab.size.z * sv.z, 0.01))
	for i in pts.size():
		var q := pts[i] * sv
		scaled[i] = Vector3(c.x + (q.x - c.x) * fx, q.y, c.z + (q.z - c.z) * fz)
		# how far it stands out of the land under that very point: a slab
		# leaning with a slope shows more than its own thickness
		var w := xf * scaled[i]
		var ground := terrain.height_at(w.x, w.z) if terrain != null and terrain.contains(w.x, w.z) else xf.origin.y
		proud = maxf(proud, w.y - ground)
	if proud < SOLID_MIN_H:
		return null
	var out := ConvexPolygonShape3D.new()
	out.points = scaled
	return out

# ------------------------------------------------------------ meshes

## The first mesh in a hero GLB, re-shaded through MaterialLib.hero_mat.
static func _hero_mesh(name: String, family: String, mode: int) -> Mesh:
	var key := "hero|%s|%d" % [name, mode]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var path := name if name.begins_with("res://") else "res://assets/models/scatter/%s.glb" % name
	var out: Mesh = null
	if ResourceLoader.exists(path):
		var inst := (BuildLock.wload(path) as PackedScene).instantiate()
		for c in inst.find_children("*", "MeshInstance3D", true, false):
			var src := (c as MeshInstance3D).mesh
			if src == null:
				continue
			out = src.duplicate() as Mesh
			for s in out.get_surface_count():
				out.surface_set_material(s, MaterialLib.hero_mat(src.surface_get_material(s), family, mode))
			break
		inst.free()
	_mesh_cache[key] = out
	return out

static func _mesh(kind: String, mode: int) -> Mesh:
	var key := "%s|%d" % [kind, mode]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m: Mesh
	match kind:
		"rock": m = _rock_mesh(0.55, 11, "M_stone_dark", mode)
		"boulder": m = _rock_mesh(1.0, 23, "M_stone_dark", mode)
		"hummock": m = _rock_mesh(0.7, 5, "M_turf", mode, 0.45)
		"ice_floe": m = _rock_mesh(1.0, 31, "M_ice", mode, 0.3)
		"standing_stone": m = _rock_mesh(0.55, 41, "M_drystone", mode, 2.6)
		"driftwood": m = _driftwood(mode)
		"peat_stack", "peat_wall", "peat_row": m = _peat(mode)
		"stone_fence": m = _drystone(mode)
		"wattle_fence": m = _wattle(mode)
	_mesh_cache[key] = m
	return m

## A lumpy, flattened sphere: sea-worn stone or a turf tussock.
static func _rock_mesh(r: float, seed: int, fam: String, mode: int, squash := 0.75) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 7
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.3
	for i in verts.size():
		var v := verts[i]
		var k := 1.0 + 0.28 * noise.get_noise_3dv(v * 1.7)
		v *= k
		v.y *= squash
		if v.y < -r * 0.15:
			v.y = -r * 0.15 + (v.y + r * 0.15) * 0.2   # flat bed so it sits, not balances
		verts[i] = v
	arr[Mesh.ARRAY_VERTEX] = verts
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, MaterialLib.get_mat(fam, mode))
	return mesh

## boxes: [[size, pos, rot_deg], ...] merged into one surface
static func _box_stack(boxes: Array, fam: String, mode: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in boxes:
		ProcMesh.box(st, b[0], Transform3D(Basis.from_euler(Vector3(b[2]) * PI / 180.0), b[1]))
	var mesh := ProcMesh.finish(st)
	mesh.surface_set_material(0, MaterialLib.get_mat(fam, mode, true))
	return mesh

static func _driftwood(mode: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.16
	cm.height = 2.8
	cm.radial_segments = 7
	ProcMesh.append(st, cm, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.13, 0)), Vector2(TAU * 0.13, 2.8))
	var br := CylinderMesh.new()
	br.top_radius = 0.03
	br.bottom_radius = 0.07
	br.height = 1.0
	br.radial_segments = 5
	ProcMesh.append(st, br, Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.BACK, 1.0), Vector3(0.7, 0.3, 0.2)), Vector2(TAU * 0.05, 1.0), Vector2(0.3, 0.7))
	var mesh := ProcMesh.finish(st)
	mesh.surface_set_material(0, MaterialLib.get_mat("M_drift", mode, true))
	return mesh

## Cut sods stacked to dry: uneven blocks, each layer laid a little askew,
## the stack slumping to one side; the top course still has its grass on.
static func _peat(mode: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var peat := SurfaceTool.new()
	peat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := 4
	var y := 0.0
	for layer in layers:
		var lean := layer * 0.05
		var n := 3 - int(layer / 2)
		for k in n:
			var bw := rng.randf_range(0.42, 0.58)
			var bh := rng.randf_range(0.2, 0.3)
			var bd := rng.randf_range(0.8, 1.15) - layer * 0.08
			var pos := Vector3(-0.5 + (k + 0.5) * (1.0 / n) + lean + rng.randf_range(-0.05, 0.05), y + bh * 0.5, rng.randf_range(-0.08, 0.08))
			var rot := Vector3(rng.randf_range(-6, 6), rng.randf_range(-14, 14) + (layer % 2) * 8, rng.randf_range(-7, 7) - layer * 2.5)
			var xf := Transform3D(Basis.from_euler(rot * PI / 180.0), pos)
			ProcMesh.box(peat, Vector3(bw * 0.96, bh, bd), xf)
			if layer == layers - 1 or (k == n - 1 and rng.randf() < 0.3):
				ProcMesh.box(grass, Vector3(bw * 1.02, 0.07, bd * 1.02), xf * Transform3D(Basis.IDENTITY, Vector3(0, bh * 0.5 + 0.03, 0)))
		y += 0.25
	var mesh := ProcMesh.finish(peat)
	mesh.surface_set_material(0, MaterialLib.get_mat("M_peat", mode, true))
	ProcMesh.finish(grass, mesh)
	mesh.surface_set_material(1, MaterialLib.get_mat("M_turf", mode, true))
	return mesh

## Dry-stone dyke, 2 m: irregular stones in two courses with a cope.
static func _drystone(mode: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var boxes := []
	for course in 3:
		var x := -1.0
		while x < 0.98:
			var w := rng.randf_range(0.35, 0.6)
			w = minf(w, 1.0 - x)
			var hgt := 0.32 if course < 2 else 0.26
			var depth := 0.62 - course * 0.1
			boxes.append([Vector3(w * 0.96, hgt, depth), Vector3(x + w * 0.5, 0.16 + course * 0.33, rng.randf_range(-0.04, 0.04)),
				Vector3(rng.randf_range(-6, 6), rng.randf_range(-8, 8), rng.randf_range(-7, 7))])
			x += w
	return _box_stack(boxes, "M_stone", mode)

## Wattle hurdle, 2 m: stakes with woven rods.
static func _wattle(mode: int) -> ArrayMesh:
	var boxes := []
	for sx in [-0.95, -0.3, 0.35, 0.95]:
		boxes.append([Vector3(0.08, 1.25, 0.08), Vector3(sx, 0.6, 0), Vector3(0, 0, 3)])
	for k in 6:
		boxes.append([Vector3(2.0, 0.12, 0.07), Vector3(0, 0.25 + k * 0.15, (k % 2) * 0.05 - 0.025), Vector3(0, 0, 1.5 - k * 0.6)])
	return _box_stack(boxes, "M_wood", mode)

# ------------------------------------------------------------ living ground cover

const VEG_SHADER := preload("res://shaders/veg_card.gdshader")
const VEG_CHUNK := 24.0
## Card clumps cut from the painted atlases (tools/art/veg_atlas.py).
##   cell: metres across one atlas cell (the clump fills most of its width)
##   cards: crossed cards per clump; lean: how far each tips outward (rad)
##   wind: tip travel; keep/bury: RIME survivors and how deep they stand in snow
const VEG_KINDS := {
	"grass": {"atlas": "res://assets/textures/veg/T_veg_grass.png", "cell": 0.5, "cards": 3, "lean": 0.32,
		"wind": 0.09, "keep": 0.3, "bury": 0.45, "dry": Color(0.36, 0.33, 0.16), "dryness": 0.6,
		"tint_a": Color(0.58, 0.7, 0.4), "tint_b": Color(0.82, 0.84, 0.52)},
	"heather": {"atlas": "res://assets/textures/veg/T_veg_heather.png", "cell": 0.64, "cards": 3, "lean": 0.36,
		"wind": 0.035, "keep": 0.45, "bury": 0.4, "dry": Color(0.26, 0.2, 0.15), "dryness": 0.5,
		"tint_a": Color(0.8, 0.8, 0.72), "tint_b": Color(0.95, 0.85, 0.8)},
	# the pile of the turf itself: low rosettes laid almost flat, close-set and
	# near the ground's own colour, so from above the clumps stand in a sward
	# instead of reading as dots on a photo. Added under every grass rule.
	"sward": {"atlas": "res://assets/textures/veg/T_veg_grass.png", "cell": 0.4, "cards": 3, "lean": 0.95, "root_shade": 0.92,
		"wind": 0.02, "keep": 0.0, "bury": 0.5, "dry": Color(0.3, 0.29, 0.15), "dryness": 0.35,
		"tint_a": Color(0.46, 0.6, 0.33), "tint_b": Color(0.62, 0.68, 0.4)},
	# the near layer: small upright tufts between the rosettes, drawn only
	# around the camera, so the turf still has blades at arm's length
	"blades": {"atlas": "res://assets/textures/veg/T_veg_grass.png", "cell": 0.24, "cards": 2, "lean": 0.22, "root_shade": 0.85,
		"wind": 0.035, "keep": 0.0, "bury": 0.5, "dry": Color(0.32, 0.3, 0.15), "dryness": 0.4,
		"tint_a": Color(0.5, 0.64, 0.35), "tint_b": Color(0.7, 0.74, 0.44)},
	"sedge": {"atlas": "res://assets/textures/veg/T_veg_sedge.png", "cell": 0.9, "cards": 3, "lean": 0.2,
		"wind": 0.15, "keep": 0.55, "bury": 0.6, "dry": Color(0.45, 0.38, 0.2), "dryness": 0.8,
		"tint_a": Color(0.72, 0.8, 0.6), "tint_b": Color(0.95, 0.92, 0.75)},
	# ---- region species (docs/art/BIOMES.md column 2). Each region's recipe
	# is data (data/veg/<area>.json); a kind is used by one region unless the
	# table there says otherwise. Flowers keep their paint: "dryness" 0.
	# Saltfell: salt and boats
	"thrift": {"atlas": "res://assets/textures/veg/T_veg_thrift.png", "cell": 0.36, "cards": 3, "lean": 0.3,
		"wind": 0.05, "keep": 0.3, "bury": 0.5, "dry": Color(0.4, 0.33, 0.24), "dryness": 0.0,
		"tint_a": Color(0.95, 0.92, 0.92), "tint_b": Color(1.0, 0.98, 0.96)},
	"campion": {"atlas": "res://assets/textures/veg/T_veg_campion.png", "cell": 0.42, "cards": 3, "lean": 0.5,
		"wind": 0.04, "keep": 0.2, "bury": 0.5, "dry": Color(0.4, 0.38, 0.3), "dryness": 0.0,
		"tint_a": Color(0.92, 0.95, 0.92), "tint_b": Color(1.0, 1.0, 0.97)},
	"marram": {"atlas": "res://assets/textures/veg/T_veg_marram.png", "cell": 0.95, "cards": 3, "lean": 0.24,
		"wind": 0.2, "keep": 0.7, "bury": 0.45, "dry": Color(0.5, 0.43, 0.26), "dryness": 0.5,
		"tint_a": Color(0.85, 0.92, 0.82), "tint_b": Color(1.0, 0.96, 0.84)},
	"scurvy": {"atlas": "res://assets/textures/veg/T_veg_scurvy.png", "cell": 0.3, "cards": 3, "lean": 0.6,
		"wind": 0.02, "keep": 0.15, "bury": 0.5, "dry": Color(0.3, 0.3, 0.2), "dryness": 0.0,
		"tint_a": Color(0.9, 0.95, 0.9), "tint_b": Color(1.0, 1.0, 0.95)},
	"thrift_cushion": {"glb": "veg_thrift_cushion", "family": "M_turf", "keep": 0.6, "bury": 0.4, "h": 0.16},
	"kelp": {"glb": "veg_kelp", "family": "M_leather", "keep": 0.5, "bury": 0.3, "h": 0.06, "flat": true},
	# the Lowe: peat and the dead (ling heather stays here, and only here)
	"cotton": {"atlas": "res://assets/textures/veg/T_veg_cotton.png", "cell": 0.58, "cards": 3, "lean": 0.26,
		"wind": 0.16, "keep": 0.45, "bury": 0.4, "dry": Color(0.5, 0.42, 0.3), "dryness": 0.0,
		"tint_a": Color(0.94, 0.92, 0.88), "tint_b": Color(1.0, 0.99, 0.96)},
	"asphodel": {"atlas": "res://assets/textures/veg/T_veg_asphodel.png", "cell": 0.44, "cards": 3, "lean": 0.26,
		"wind": 0.06, "keep": 0.3, "bury": 0.45, "dry": Color(0.5, 0.32, 0.12), "dryness": 0.0,
		"tint_a": Color(0.95, 0.93, 0.88), "tint_b": Color(1.0, 0.98, 0.9)},
	"rush": {"atlas": "res://assets/textures/veg/T_veg_rush.png", "cell": 0.85, "cards": 3, "lean": 0.16,
		"wind": 0.1, "keep": 0.75, "bury": 0.4, "dry": Color(0.42, 0.36, 0.2), "dryness": 0.35,
		"tint_a": Color(0.88, 0.95, 0.85), "tint_b": Color(1.0, 1.0, 0.9)},
	"sphagnum": {"glb": "veg_sphagnum", "family": "M_turf", "keep": 0.7, "bury": 0.35, "h": 0.26},
	# Kettle Fjord: very little, on purpose
	"roseroot": {"atlas": "res://assets/textures/veg/T_veg_roseroot.png", "cell": 0.42, "cards": 2, "lean": 0.3, "root_shade": 0.9,
		"wind": 0.03, "keep": 0.35, "bury": 0.3, "dry": Color(0.4, 0.36, 0.26), "dryness": 0.0,
		"tint_a": Color(0.92, 0.95, 0.95), "tint_b": Color(1.0, 1.0, 0.96)},
	"frostflower": {"atlas": "res://assets/textures/veg/T_veg_frostflower.png", "cell": 0.34, "cards": 3, "lean": 0.4, "root_shade": 1.0,
		"wind": 0.0, "keep": 1.0, "bury": 0.0, "dry": Color(0.8, 0.85, 0.9), "dryness": 0.0,
		"tint_a": Color(0.92, 0.97, 1.0), "tint_b": Color(1.0, 1.0, 1.0)},
	"crowberry": {"glb": "veg_crowberry", "family": "M_turf", "keep": 0.6, "bury": 0.5, "h": 0.07, "flat": true},
	# Tarnhall: feasting
	"horsetail": {"atlas": "res://assets/textures/veg/T_veg_horsetail.png", "cell": 0.75, "cards": 3, "lean": 0.1, "root_shade": 0.8,
		"wind": 0.08, "keep": 0.5, "bury": 0.3, "dry": Color(0.45, 0.4, 0.22), "dryness": 0.2,
		"tint_a": Color(0.88, 0.95, 0.85), "tint_b": Color(1.0, 1.0, 0.92)},
	"dock": {"atlas": "res://assets/textures/veg/T_veg_dock.png", "cell": 0.95, "cards": 3, "lean": 0.22,
		"wind": 0.05, "keep": 0.4, "bury": 0.4, "dry": Color(0.4, 0.26, 0.14), "dryness": 0.25,
		"tint_a": Color(0.9, 0.95, 0.86), "tint_b": Color(1.0, 1.0, 0.92)},
	# Thornwold: charcoal and hedging (no grass cards under the canopy)
	"bracken": {"atlas": "res://assets/textures/veg/T_veg_bracken.png", "cell": 1.05, "cards": 3, "lean": 0.4,
		"wind": 0.07, "keep": 0.4, "bury": 0.45, "dry": Color(0.45, 0.27, 0.13), "dryness": 0.55,
		"tint_a": Color(0.9, 1.0, 0.85), "tint_b": Color(1.0, 0.98, 0.86)},
	"bilberry": {"atlas": "res://assets/textures/veg/T_veg_bilberry.png", "cell": 0.5, "cards": 3, "lean": 0.34,
		"wind": 0.03, "keep": 0.35, "bury": 0.5, "dry": Color(0.42, 0.24, 0.16), "dryness": 0.2,
		"tint_a": Color(0.9, 0.98, 0.88), "tint_b": Color(1.0, 1.0, 0.92)},
	"moss_cushion": {"glb": "veg_moss_cushion", "family": "M_turf", "keep": 0.5, "bury": 0.5, "h": 0.13},
	"hazel_stool": {"glb": "veg_hazel_stool", "rime_glb": "veg_hazel_stool_bare", "family": "M_leaves", "keep": 1.0, "bury": 0.04, "h": 2.4,
		"sway": 0.06, "upright": true},
	"birch_sapling": {"glb": "veg_birch_sapling", "rime_glb": "veg_birch_sapling_bare", "family": "M_leaves", "keep": 1.0, "bury": 0.04, "h": 2.6,
		"sway": 0.12, "upright": true},
	# Shepherd's Reach: sheep and folds
	"fescue": {"atlas": "res://assets/textures/veg/T_veg_grass.png", "cell": 0.26, "cards": 3, "lean": 0.36, "sward": true,
		"wind": 0.06, "keep": 0.25, "bury": 0.45, "dry": Color(0.4, 0.38, 0.18), "dryness": 0.25,
		"tint_a": Color(0.62, 0.86, 0.4), "tint_b": Color(0.8, 0.95, 0.5)},
	"matgrass": {"atlas": "res://assets/textures/veg/T_veg_matgrass.png", "cell": 0.5, "cards": 3, "lean": 0.34,
		"wind": 0.07, "keep": 0.55, "bury": 0.45, "dry": Color(0.62, 0.56, 0.4), "dryness": 0.3,
		"tint_a": Color(0.86, 0.9, 0.78), "tint_b": Color(1.0, 0.98, 0.9)},
	"avens": {"atlas": "res://assets/textures/veg/T_veg_avens.png", "cell": 0.36, "cards": 3, "lean": 0.5,
		"wind": 0.03, "keep": 0.15, "bury": 0.5, "dry": Color(0.4, 0.36, 0.26), "dryness": 0.0,
		"tint_a": Color(0.94, 0.96, 0.92), "tint_b": Color(1.0, 1.0, 0.97)},
	"thistle": {"atlas": "res://assets/textures/veg/T_veg_thistle.png", "cell": 0.95, "cards": 2, "lean": 0.08,
		"wind": 0.06, "keep": 0.6, "bury": 0.25, "dry": Color(0.5, 0.42, 0.3), "dryness": 0.15,
		"tint_a": Color(0.92, 0.95, 0.9), "tint_b": Color(1.0, 1.0, 0.96)},
	"wooltuft": {"atlas": "res://assets/textures/veg/T_veg_wooltuft.png", "cell": 0.42, "cards": 2, "lean": 0.1, "root_shade": 0.9,
		"wind": 0.12, "keep": 0.6, "bury": 0.2, "dry": Color(0.7, 0.66, 0.56), "dryness": 0.0,
		"tint_a": Color(0.95, 0.94, 0.9), "tint_b": Color(1.0, 1.0, 0.98)},
	"juniper": {"glb": "veg_juniper", "family": "M_needles", "keep": 0.8, "bury": 0.35, "h": 0.22},
	# the Coldwell: the only place in Rimeholt with flowers (THAW); in RIME
	# nothing grows, and hoar feathers stand on the stones
	"marigold": {"atlas": "res://assets/textures/veg/T_veg_marigold.png", "cell": 0.42, "cards": 3, "lean": 0.36,
		"wind": 0.04, "keep": 0.0, "bury": 0.5, "dry": Color(0.4, 0.36, 0.2), "dryness": 0.0,
		"tint_a": Color(0.95, 0.96, 0.9), "tint_b": Color(1.0, 1.0, 0.96)},
	"smock": {"atlas": "res://assets/textures/veg/T_veg_smock.png", "cell": 0.5, "cards": 3, "lean": 0.2,
		"wind": 0.1, "keep": 0.0, "bury": 0.5, "dry": Color(0.42, 0.4, 0.3), "dryness": 0.0,
		"tint_a": Color(0.95, 0.95, 0.97), "tint_b": Color(1.0, 1.0, 1.0)},
	"hoarfeather": {"atlas": "res://assets/textures/veg/T_veg_hoarfeather.png", "cell": 0.34, "cards": 3, "lean": 0.5, "root_shade": 1.0,
		"wind": 0.0, "keep": 1.0, "bury": 0.0, "dry": Color(0.8, 0.85, 0.9), "dryness": 0.0,
		"tint_a": Color(0.9, 0.96, 1.0), "tint_b": Color(1.0, 1.0, 1.0)},
	"saxifrage": {"glb": "veg_saxifrage", "family": "M_turf", "keep": 0.0, "bury": 0.5, "h": 0.11},
	"starmoss": {"glb": "veg_starmoss", "family": "M_turf", "keep": 0.0, "bury": 0.5, "h": 0.05, "flat": true},
}
const VEG_MODEL_DIR := "res://assets/models/veg/"
const VEG_RECIPE_DIR := "res://data/veg/"
static var _recipes: Dictionary = {}

## A region's own plants (data/veg/<area id>.json), or {} when it has none:
##   {"drop": [kinds of the area's own "veg" rules to leave out],
##    "veg": [rules, as below]}
## The area JSON's rules come from the generators; the recipe is laid over
## them here, so a region's plants can change without regenerating its area.
static func region_recipe(area_id: String) -> Dictionary:
	if not _recipes.has(area_id):
		var out := {}
		var path := VEG_RECIPE_DIR + area_id + ".json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				out = parsed
			else:
				push_error("Scatter: %s is not a JSON object" % path)
		_recipes[area_id] = out
	return _recipes[area_id]

## The area's own rules with the region recipe laid over them.
##
## THE ORDER, and the only place it is applied (build_veg), each step once:
##   1. the area JSON's "veg" rules, as the generator wrote them;
##   2. the region recipe (data/veg/<area>.json): its "drop" kinds leave, its
##      "veg" rules are appended. The recipe is the source of a region's plants;
##   3. the biome file (data/biomes/<area>.json "veg", Biome.veg_rules) over
##      that whole list: "density" scales a kind (0 removes it) and "swap"
##      draws one kind as another, recipe plants included; its "add" rules
##      are appended as written, unscaled.
## A kind both files remove is simply gone; plants are added by the recipe,
## so a biome's "add" stays empty unless a species is its alone.
## The rules a region's ground cover is really grown by: its recipe's, with
## its biome's laid over (the cache key is made of these).
static func rules_for(area_id: String, rules: Array) -> Array:
	return Biome.veg_rules(area_id, region_rules(area_id, rules))

static func region_rules(area_id: String, rules: Array) -> Array:
	var recipe := region_recipe(area_id)
	if recipe.is_empty():
		return rules
	var drop: Array = recipe.get("drop", [])
	var out: Array = []
	for r in rules:
		if not (String((r as Dictionary).get("kind", "grass")) in drop):
			out.append(r)
	out.append_array(recipe.get("veg", []))
	return out

## Distance from a point to the nearest building footprint (edges.buildings:
## centre, size, yaw) or fence line (scatter.fences) of the area; INF if none.
static func _wall_dist(def: Dictionary, x: float, z: float, fences: bool) -> float:
	var best := INF
	if fences:
		for f in def.get("scatter", {}).get("fences", []):
			var pts: Array = f.get("points", [])
			for k in pts.size() - 1:
				var a := Vector2(float(pts[k][0]), float(pts[k][1]))
				var b := Vector2(float(pts[k + 1][0]), float(pts[k + 1][1]))
				best = minf(best, Geometry2D.get_closest_point_to_segment(Vector2(x, z), a, b).distance_to(Vector2(x, z)))
		return best
	for b in def.get("edges", {}).get("buildings", []):
		var c: Array = b["center"]
		var sz: Array = b["size"]
		var yaw := deg_to_rad(float(b.get("yaw", 0.0)))
		var d := Vector2(x - float(c[0]), z - float(c[1])).rotated(yaw)
		var q := Vector2(absf(d.x) - float(sz[0]) * 0.5, absf(d.y) - float(sz[1]) * 0.5)
		best = minf(best, Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0))
	return best

## Smooth value noise in metres: where a kind grows thick and where it thins.
static func _patch(x: float, z: float, cell: float, seed: int) -> float:
	var fx := x / cell
	var fz := z / cell
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - ix
	var tz := fz - iz
	tx = tx * tx * (3.0 - 2.0 * tx)
	tz = tz * tz * (3.0 - 2.0 * tz)
	var h := func(a: int, b: int) -> float:
		return float(hash(Vector3i(a, b, seed)) % 10007) / 10007.0
	return lerpf(lerpf(h.call(ix, iz), h.call(ix + 1, iz), tx), lerpf(h.call(ix, iz + 1), h.call(ix + 1, iz + 1), tx), tz)
const SCATTER_CHUNK := 32.0

## "veg": [{"kind": a VEG_KINDS key, "region": [x0, z0, x1, z1],
##          "density": per m2, "h": [min, max], "tag", "range": m}]
## Clumps gather in drifts (a kind grows thick in patches and thins between
## them), crowd the edges of worn paths and settle in hollows; they thin on
## slopes and stay off bare shingle, wet shore, rock and the path itself.
## A region recipe (data/veg/<area>.json) may also say where a plant lives:
##   "slope": [min, max]   the ground normal's y (cracks and ledges; default turf slopes)
##   "bare": true          grows on shingle, wet shore and thin soil too
##   "splat": [[ch, min, max], ...]   painted layer must be in range (0 shingle, 1 path, 2 wet, 3 turf)
##   "near": [[x, z, r], ...]  only inside these circles;  "avoid": the reverse
##   "walls": [d0, d1]     metres from a building footprint;  "fences": [d0, d1] from a fence line
##   "drop_min": m         only where the land falls away this much within "drop_r" (cliff edges)
##   "level": y            stands on a level at y where the land is under it (on the ice)
##   "even": true          no drifts: spread evenly;  "scale": [a, b] clump size
##   "clear": true         keeps out of the area's scatter "clear" circles (clearings)
## `area` null: cache warming (the buffers only); `area_id` then names whose
## rules these are.
static func build_veg(area: Area, terrain: Terrain, rules: Array, seed: int, keep_clear: Array, area_id := "") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if area != null:
		area_id = area.area_id
	rules = rules_for(area_id, rules)
	var def: Dictionary = area.get_meta("def", {}) if area != null else DB.area_def(area_id)
	var area_clear: Array = def.get("scatter", {}).get("clear", [])
	var ground := Color(0.1, 0.11, 0.05)
	if area != null and terrain.has_method("palette_color"):
		ground = terrain.palette_color("turf_a")
	# the sward rides on the grass rules, after them all, so adding it moved
	# no existing clump
	var all_rules: Array = rules.duplicate()
	for rule in rules:
		var rk := String(rule.get("kind", "grass"))
		# (a region's own turf grass brings the same pile and blades: "sward")
		if rk == "grass" or bool((VEG_KINDS.get(rk, {}) as Dictionary).get("sward", false)):
			var sw: Dictionary = (rule as Dictionary).duplicate()
			sw["kind"] = "sward"
			sw["density"] = float(rule.get("density", 1.0)) * 4.0
			sw["range"] = minf(float(rule.get("range", 55.0)), 32.0)
			all_rules.append(sw)
			var bl: Dictionary = (rule as Dictionary).duplicate()
			bl["kind"] = "blades"
			bl["density"] = float(rule.get("density", 1.0)) * 6.0
			bl["range"] = 11.0
			all_rules.append(bl)
	# where every clump stands is a pure function of the rules, the seed and
	# the land: kept on disk (StreamCache) as one MultiMesh buffer per chunk
	var ck := veg_key(terrain, rules, seed, keep_clear)
	var cached: Variant = StreamCache.load_var("veg", ck)
	var hit: bool = cached is Array and (cached as Array).size() == all_rules.size()
	var store: Array = []
	var ri := -1
	for rule in all_rules:
		if AreaBuilder._cancelled():
			return     # (a worker build nobody waits for; nothing is cached)
		ri += 1
		var kind := String(rule.get("kind", "grass"))
		var tag := String(rule.get("tag", "base"))
		var reg: Array = rule.get("region", [-50, -50, 50, 50])
		var hr: Array = rule.get("h", [-1000, 1000])
		var dens := float(rule.get("density", 1.0))
		var step := 1.0 / sqrt(maxf(dens, 0.01))
		var kseed := hash(kind)
		var kcfg: Dictionary = VEG_KINDS.get(kind, VEG_KINDS["grass"])
		var size_r: Array = rule.get("scale", [0.75, 1.4])
		var upright := bool(kcfg.get("upright", false))
		var flat := bool(kcfg.get("flat", false))
		var chunks: Dictionary = {}
		var x := float(reg[2]) if hit else float(reg[0])   # (a hit walks nothing)
		while x < float(reg[2]):
			if AreaBuilder.cancel_worker and AreaBuilder._cancelled():
				return
			var z := float(reg[1])
			while z < float(reg[3]):
				var px := x + rng.randf() * step
				var pz := z + rng.randf() * step
				z += step
				if not terrain.contains(px, pz):
					continue
				var y := terrain.height_at(px, pz)
				if y < float(hr[0]) or y > float(hr[1]):
					continue
				var nrm := terrain.normal_at(px, pz)
				var p := smoothstep(0.72, 0.93, nrm.y)
				if rule.has("slope"):
					p = 1.0 if nrm.y >= float(rule["slope"][0]) and nrm.y <= float(rule["slope"][1]) else 0.0
				if rule.has("level"):
					p = 1.0
				if p <= 0.0:
					continue
				var path := terrain.splat_at(px, pz, 1)
				if path > 0.55:
					continue
				var bare := bool(rule.get("bare", false))
				if not bare:
					p *= 1.0 + 1.6 * clampf(1.0 - absf(path - 0.32) / 0.22, 0.0, 1.0)   # path edges
					if terrain.splat_at(px, pz, 0) > 0.35 or terrain.splat_at(px, pz, 2) > 0.3:
						continue      # shingle and wet shore stay bare
				var out_of_place := false
				for sp in rule.get("splat", []):
					var sv := terrain.splat_at(px, pz, int(sp[0]))
					if sv < float(sp[1]) or sv > float(sp[2]):
						out_of_place = true
				if rule.has("near") and not _blocked(_circles(rule["near"]), px, pz):
					out_of_place = true
				if rule.has("avoid") and _blocked(_circles(rule["avoid"]), px, pz):
					out_of_place = true
				if bool(rule.get("clear", false)) and _blocked(_circles(area_clear), px, pz):
					out_of_place = true
				if out_of_place:
					continue
				if rule.has("walls"):
					var wd := _wall_dist(def, px, pz, false)
					if wd < float(rule["walls"][0]) or wd > float(rule["walls"][1]):
						continue
				if rule.has("fences"):
					var fd := _wall_dist(def, px, pz, true)
					if fd < float(rule["fences"][0]) or fd > float(rule["fences"][1]):
						continue
				if rule.has("drop_min") and terrain.drop_at(px, pz, float(rule.get("drop_r", 5.0))) < float(rule["drop_min"]):
					continue
				if not bare and not rule.has("level"):
					var around := (terrain.height_at(px + 3, pz) + terrain.height_at(px - 3, pz)
							+ terrain.height_at(px, pz + 3) + terrain.height_at(px, pz - 3)) * 0.25
					p *= 1.0 + clampf((around - y) * 1.2, 0.0, 1.2)                     # hollows
					p *= 0.55 + 0.45 * terrain.splat_at(px, pz, 3)
				# drifts: thick patches a few metres across, thin ground between
				var drift := _patch(px, pz, 7.0, kseed) * 0.65 + _patch(px, pz, 2.6, kseed + 1) * 0.35
				if bool(rule.get("even", false)):
					p *= 1.0
				elif kind == "sward" or kind == "blades":
					p *= lerpf(0.55, 1.5, smoothstep(0.25, 0.75, drift))
				else:
					p *= lerpf(0.08, 1.7, smoothstep(0.38, 0.74, drift))
				if rng.randf() > p * 0.6 or _blocked(keep_clear, px, pz):
					continue
				if rule.has("level"):
					y = float(rule["level"])
					nrm = Vector3.UP
				# a clump and sometimes a smaller one grown out of its side
				var n := 1 + (1 if kind != "sward" and kind != "blades" and rng.randf() < 0.3 else 0)
				for j in n:
					var qx := px
					var qz := pz
					var s := rng.randf_range(float(size_r[0]), float(size_r[1]))
					if j > 0:
						var a := rng.randf() * TAU
						qx += cos(a) * 0.3
						qz += sin(a) * 0.3
						s *= 0.65
						if not terrain.contains(qx, qz) or terrain.splat_at(qx, qz, 1) > 0.55:
							continue
					var qy := y if rule.has("level") else terrain.height_at(qx, qz)
					var up := Vector3.UP.lerp(nrm, 0.12 if upright else (0.9 if flat else 0.5)).normalized()
					var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
					var key := Vector2i(int(floor(qx / VEG_CHUNK)), int(floor(qz / VEG_CHUNK)))
					if not chunks.has(key):
						chunks[key] = []
					# custom: atlas cell, dryness (drier where the kind is thin), value, wind phase
					var custom := Color(rng.randf(), clampf(rng.randf() * 0.7 + (0.5 - drift) * 0.8, 0.0, 1.0), rng.randf(), rng.randf())
					# cards may stand a little taller or shorter; a modelled plant is only ever scaled whole
					var tall := rng.randf_range(0.8, 1.15)
					chunks[key].append([Transform3D(b.scaled_local(Vector3(s, s if kcfg.has("glb") else s * tall, s)), Vector3(qx, qy - 0.02, qz)), custom])
			x += step
		if AreaBuilder._cancelled():
			return
		var bufs: Dictionary = cached[ri] if hit else _veg_buffers(chunks, terrain)
		store.append(bufs)
		if area == null:
			continue     # (cache warming: the buffers, and nothing made of them)
		var rng_end := float(rule.get("range", 55.0))
		if kcfg.has("glb"):
			# modelled plants: their transforms read back out of the buffers,
			# so a cache hit serves them as it serves the cards
			_emit_veg_models(area, terrain, kind, kcfg, tag, _chunks_of(bufs, terrain), rng_end)
			continue
		var mesh := _veg_mesh(kind, tag, ground)
		for key in bufs:
			var buf: PackedFloat32Array = bufs[key]
			var c := Vector3((key.x + 0.5) * VEG_CHUNK, 0, (key.y + 0.5) * VEG_CHUNK)
			c.y = terrain.height_at(c.x, c.z)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = buf.size() / 16
			mm.buffer = buf
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Veg_%s_%d_%d" % [kind, key.x, key.y]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# anchored at the chunk centre so the range test measures to the chunk
			mmi.position = c
			mmi.visibility_range_end = rng_end
			mmi.visibility_range_end_margin = 6.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			area.attach(mmi, tag)
	if not hit and not AreaBuilder._cancelled():
		StreamCache.store_var("veg", ck, store)

static func veg_key(terrain: Terrain, rules: Array, seed: int, keep_clear: Array) -> String:
	return StreamCache.key(["veg", rules, seed, keep_clear, terrain.origin, terrain.cell, terrain.nx, terrain.nz,
			terrain.heights, terrain.splat])

## _veg_buffers undone: each chunk's clumps as [world transform, custom].
static func _chunks_of(bufs: Dictionary, terrain: Terrain) -> Dictionary:
	var out := {}
	for key in bufs:
		var buf: PackedFloat32Array = bufs[key]
		var c := Vector3((key.x + 0.5) * VEG_CHUNK, 0, (key.y + 0.5) * VEG_CHUNK)
		c.y = terrain.height_at(c.x, c.z)
		var xfs: Array = []
		for o in range(0, buf.size(), 16):
			var b := Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]),
					Vector3(buf[o + 2], buf[o + 6], buf[o + 10]))
			xfs.append([Transform3D(b, Vector3(buf[o + 3], buf[o + 7], buf[o + 11]) + c),
					Color(buf[o + 12], buf[o + 13], buf[o + 14], buf[o + 15])])
		out[key] = xfs
	return out

## Each chunk's clumps as the MultiMesh's own buffer (per instance: the
## transform's three rows with the origin, relative to the chunk centre, then
## the custom data), exactly what set_instance_transform and
## set_instance_custom_data would have written.
static func _veg_buffers(chunks: Dictionary, terrain: Terrain) -> Dictionary:
	var out := {}
	for key in chunks:
		var xfs: Array = chunks[key]
		var c := Vector3((key.x + 0.5) * VEG_CHUNK, 0, (key.y + 0.5) * VEG_CHUNK)
		c.y = terrain.height_at(c.x, c.z)
		var buf := PackedFloat32Array()
		buf.resize(xfs.size() * 16)
		var o := 0
		for e in xfs:
			var t: Transform3D = e[0]
			t.origin -= c
			var b := t.basis
			var cu: Color = e[1]
			buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = t.origin.x
			buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = t.origin.y
			buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = t.origin.z
			buf[o + 12] = cu.r; buf[o + 13] = cu.g; buf[o + 14] = cu.b; buf[o + 15] = cu.a
			o += 16
		out[key] = buf
	return out

static func _circles(list: Array) -> Array:
	var out: Array = []
	for c in list:
		out.append(Vector3(float(c[0]), float(c[1]), float(c[2])))
	return out

## Plants with a body (cushions, mats, stools, saplings: tools/art/procedural/
## veg_models.py) on the same chunks and ranges as the cards. A "base" rule is
## drawn as two sets: the THAW plants, and their RIME variant: a "keep" share
## of them, each sunk "bury" of its height into the snow (and the bare mesh,
## for what loses its leaves). hero_mat lays the snow crust on what shows.
static func _emit_veg_models(area: Area, terrain: Terrain, kind: String, kcfg: Dictionary, tag: String,
		chunks: Dictionary, rng_end: float) -> void:
	var states: Array = ["thaw", "rime"] if tag == "base" else [tag]
	for st in states:
		var rime: bool = st == "rime"
		var keep := float(kcfg.get("keep", 1.0)) if rime and tag == "base" else 1.0
		if keep <= 0.0:
			continue
		var glb := String(kcfg.get("rime_glb", kcfg["glb"])) if rime else String(kcfg["glb"])
		var mesh := _veg_model_mesh(glb, String(kcfg.get("family", "M_turf")), 2 if rime else 1, float(kcfg.get("sway", 0.0)))
		if mesh == null:
			return
		var sink := float(kcfg.get("bury", 0.0)) * float(kcfg.get("h", 0.2)) if rime else 0.0
		for key in chunks:
			var xfs: Array = []
			for e in chunks[key]:
				var t: Transform3D = e[0]
				# which plants the snow has: fixed by where each one stands
				if keep < 1.0 and float(hash(Vector2i(int(t.origin.x * 7.0), int(t.origin.z * 7.0))) % 1000) / 1000.0 > keep:
					continue
				t.origin.y -= sink * t.basis.get_scale().y
				xfs.append(t)
			if xfs.is_empty():
				continue
			var c := Vector3((key.x + 0.5) * VEG_CHUNK, 0, (key.y + 0.5) * VEG_CHUNK)
			c.y = terrain.height_at(c.x, c.z)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = xfs.size()
			for i in xfs.size():
				var t2: Transform3D = xfs[i]
				t2.origin -= c
				mm.set_instance_transform(i, t2)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Veg_%s_%s_%d_%d" % [kind, st, key.x, key.y]
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.position = c
			mmi.visibility_range_end = rng_end
			mmi.visibility_range_end_margin = 6.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			area.attach(mmi, st)

## A plant model's mesh, shaded through MaterialLib.hero_mat with its own
## paint kept (tint 0) and a little wind where it has stems.
static func _veg_model_mesh(name: String, family: String, mode: int, sway: float) -> Mesh:
	var key := "vegm|%s|%s|%d" % [name, family, mode]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var path := VEG_MODEL_DIR + name + ".glb"
	var out: Mesh = null
	if ResourceLoader.exists(path):
		# (BuildLock.wload, never load: a streamed build runs this on a worker)
		var inst := (BuildLock.wload(path) as PackedScene).instantiate()
		for c in inst.find_children("*", "MeshInstance3D", true, false):
			var src := (c as MeshInstance3D).mesh
			if src == null:
				continue
			out = src.duplicate() as Mesh
			for si in out.get_surface_count():
				var m := MaterialLib.hero_mat(src.surface_get_material(si), family, mode, 0.0)
				if sway > 0.0 and m is ShaderMaterial:
					m = m.duplicate()
					(m as ShaderMaterial).set_shader_parameter("wind_sway", sway)
					(m as ShaderMaterial).set_shader_parameter("wind_height", 2.5)
				out.surface_set_material(si, m)
			break
		inst.free()
	_mesh_cache[key] = out
	return out

## One clump: a few cards crossed through the root, each tipped outward so
## the clump has a top when seen from above, each in three rows so the wind
## bends it instead of shearing it. Each card takes a different atlas cell.
static func _veg_mesh(kind: String, tag: String, ground := Color(0.1, 0.11, 0.05)) -> ArrayMesh:
	var key := "veg|%s|%s|%s" % [kind, tag, ground.to_html(false)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var k: Dictionary = VEG_KINDS.get(kind, VEG_KINDS["grass"])
	var w := float(k["cell"])
	var cards := int(k["cards"])
	var lean := float(k["lean"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in cards:
		var a := PI * (float(i) + 0.15 * sin(float(i) * 7.3)) / float(cards)
		var right := Vector3(cos(a), 0, sin(a))
		var out := Vector3(-sin(a), 0, cos(a)) * (1.0 if i % 2 == 0 else -1.0)
		# the root sits a little behind the card's lean so the cards cross
		var root := -out * w * 0.06
		var rows: Array = []
		for r in 3:
			var h := float(r) * 0.5
			# the lean grows with height: a card that curls outward
			var pos := root + Vector3.UP * (w * h * cos(lean * h)) + out * (w * h * sin(lean * h))
			rows.append([pos - right * w * 0.5, pos + right * w * 0.5, 1.0 - h])
		for r in 2:
			var lo: Array = rows[r]
			var hi: Array = rows[r + 1]
			var quad: Array = [[lo[0], Vector2(0, lo[2])], [lo[1], Vector2(1, lo[2])], [hi[1], Vector2(1, hi[2])],
				[lo[0], Vector2(0, lo[2])], [hi[1], Vector2(1, hi[2])], [hi[0], Vector2(0, hi[2])]]
			for v in quad:
				st.set_normal(Vector3.UP)
				st.set_uv(v[1])
				st.set_uv2(Vector2(float(i), 0.0))
				st.add_vertex(v[0])
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = VEG_SHADER
	mat.set_shader_parameter("atlas", load(String(k["atlas"])))
	mat.set_shader_parameter("state_mode", 1 if tag == "thaw" else (2 if tag == "rime" else 0))
	mat.set_shader_parameter("wind_strength", float(k["wind"]))
	mat.set_shader_parameter("rime_keep", float(k["keep"]))
	mat.set_shader_parameter("rime_bury", float(k["bury"]) * w)
	mat.set_shader_parameter("dry_col", k["dry"])
	mat.set_shader_parameter("tint_a", k["tint_a"])
	mat.set_shader_parameter("tint_b", k["tint_b"])
	mat.set_shader_parameter("dryness", float(k["dryness"]))
	mat.set_shader_parameter("root_shade", float(k.get("root_shade", 0.62)))
	mat.set_shader_parameter("ground_col", ground)
	mesh.surface_set_material(0, mat)
	# the wind and the lean carry vertices outside the rest box
	mesh.custom_aabb = AABB(Vector3(-w, -w * 0.6, -w), Vector3(w * 2.0, w * 1.9, w * 2.0))
	_mesh_cache[key] = mesh
	return mesh
