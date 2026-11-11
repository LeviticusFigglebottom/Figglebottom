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
		for i in cx.size():
			var t: Transform3D = cx[i]
			t.origin -= c
			mm.set_instance_transform(i, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Scatter_%s_%s_%d_%d" % [kind, tag, key.x, key.z] + ("" if variants.size() == 1 else "_%d" % key.y)
		mmi.multimesh = mm
		mmi.position = c
		if small:
			mmi.visibility_range_end = 70.0
			mmi.visibility_range_end_margin = 8.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		area.attach(mmi, tag)
	var bit := AreaBuilder._tag_bit(tag)
	for xf in xfs:
		var t: Transform3D = xf
		var shape: Shape3D = null
		var off := Vector3.ZERO
		match kind:
			"ice_floe":
				if t.basis.get_scale().y < 1.0:
					continue      # flat channel floes: the ice sheet carries you
				var spi := SphereShape3D.new()
				spi.radius = 0.8
				shape = spi
				off = Vector3(0, 0.2, 0)
			"boulder":
				var sp := SphereShape3D.new()
				sp.radius = 0.85
				shape = sp
				off = Vector3(0, 0.3, 0)
			"rock":
				if t.basis.get_scale().x < 0.75:
					continue    # ankle stones: step over them
				var sp2 := SphereShape3D.new()
				sp2.radius = 0.7
				shape = sp2
				off = Vector3(0, 0.15, 0)
			"stone_fence", "wattle_fence":
				var bx := BoxShape3D.new()
				bx.size = Vector3(2.0, 1.3, 0.55)
				shape = bx
				off = Vector3(0, 0.62, 0)
			"peat_stack":
				var bx2 := BoxShape3D.new()
				bx2.size = Vector3(1.5, 1.2, 1.1)
				shape = bx2
				off = Vector3(0, 0.6, 0)
			"peat_wall":
				var bxw := BoxShape3D.new()
				bxw.size = Vector3(2.2, 1.2, 0.7)
				shape = bxw
				off = Vector3(0, 0.6, 0)
			"standing_stone":
				var bx3 := BoxShape3D.new()
				bx3.size = Vector3(0.8, 2.6, 0.5)
				shape = bx3
				off = Vector3(0, 1.3, 0)
			"driftwood":
				# every piece is something to walk round or step over: a low
				# box its own length (the pieces run 0.9 to 1.5 m at scale 1)
				var bx4 := BoxShape3D.new()
				bx4.size = Vector3(1.25, 0.26, 0.34)
				shape = bx4
				off = Vector3(0, 0.13, 0)
			_:
				continue
		# physics bodies must not carry scale: bake it into the shape
		var sv := t.basis.get_scale()
		if shape is BoxShape3D:
			(shape as BoxShape3D).size *= sv
		elif shape is SphereShape3D:
			(shape as SphereShape3D).radius *= (sv.x + sv.z) * 0.5
		var body := StaticBody3D.new()
		body.collision_layer = 1 << (bit - 1)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = off * sv
		body.add_child(cs)
		body.transform = Transform3D(t.basis.orthonormalized(), t.origin)
		area.attach(body, tag)

# ------------------------------------------------------------ meshes

## The first mesh in a hero GLB, re-shaded through MaterialLib.hero_mat.
static func _hero_mesh(name: String, family: String, mode: int) -> Mesh:
	var key := "hero|%s|%d" % [name, mode]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var path := name if name.begins_with("res://") else "res://assets/models/scatter/%s.glb" % name
	var out: Mesh = null
	if ResourceLoader.exists(path):
		var inst := (load(path) as PackedScene).instantiate()
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
}

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

## "veg": [{"kind": "grass"|"heather"|"sedge", "region": [x0, z0, x1, z1],
##          "density": per m2, "h": [min, max], "tag", "range": m}]
## Clumps gather in drifts (a kind grows thick in patches and thins between
## them), crowd the edges of worn paths and settle in hollows; they thin on
## slopes and stay off bare shingle, wet shore, rock and the path itself.
static func build_veg(area: Area, terrain: Terrain, rules: Array, seed: int, keep_clear: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var ground := Color(0.1, 0.11, 0.05)
	if terrain.has_method("palette_color"):
		ground = terrain.palette_color("turf_a")
	# the sward rides on the grass rules, after them all, so adding it moved
	# no existing clump
	var all_rules: Array = rules.duplicate()
	for rule in rules:
		if String(rule.get("kind", "grass")) == "grass":
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
	for rule in all_rules:
		var kind := String(rule.get("kind", "grass"))
		var tag := String(rule.get("tag", "base"))
		var reg: Array = rule.get("region", [-50, -50, 50, 50])
		var hr: Array = rule.get("h", [-1000, 1000])
		var dens := float(rule.get("density", 1.0))
		var step := 1.0 / sqrt(maxf(dens, 0.01))
		var kseed := hash(kind)
		var chunks: Dictionary = {}
		var x := float(reg[0])
		while x < float(reg[2]):
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
				if p <= 0.0:
					continue
				var path := terrain.splat_at(px, pz, 1)
				if path > 0.55:
					continue
				p *= 1.0 + 1.6 * clampf(1.0 - absf(path - 0.32) / 0.22, 0.0, 1.0)   # path edges
				if terrain.splat_at(px, pz, 0) > 0.35 or terrain.splat_at(px, pz, 2) > 0.3:
					continue      # shingle and wet shore stay bare
				var around := (terrain.height_at(px + 3, pz) + terrain.height_at(px - 3, pz)
						+ terrain.height_at(px, pz + 3) + terrain.height_at(px, pz - 3)) * 0.25
				p *= 1.0 + clampf((around - y) * 1.2, 0.0, 1.2)                     # hollows
				p *= 0.55 + 0.45 * terrain.splat_at(px, pz, 3)
				# drifts: thick patches a few metres across, thin ground between
				var drift := _patch(px, pz, 7.0, kseed) * 0.65 + _patch(px, pz, 2.6, kseed + 1) * 0.35
				if kind == "sward" or kind == "blades":
					p *= lerpf(0.55, 1.5, smoothstep(0.25, 0.75, drift))
				else:
					p *= lerpf(0.08, 1.7, smoothstep(0.38, 0.74, drift))
				if rng.randf() > p * 0.6 or _blocked(keep_clear, px, pz):
					continue
				# a clump and sometimes a smaller one grown out of its side
				var n := 1 + (1 if kind != "sward" and kind != "blades" and rng.randf() < 0.3 else 0)
				for j in n:
					var qx := px
					var qz := pz
					var s := rng.randf_range(0.75, 1.4)
					if j > 0:
						var a := rng.randf() * TAU
						qx += cos(a) * 0.3
						qz += sin(a) * 0.3
						s *= 0.65
						if not terrain.contains(qx, qz) or terrain.splat_at(qx, qz, 1) > 0.55:
							continue
					var qy := terrain.height_at(qx, qz)
					var up := Vector3.UP.lerp(nrm, 0.5).normalized()
					var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, rng.randf() * TAU)
					var key := Vector2i(int(floor(qx / VEG_CHUNK)), int(floor(qz / VEG_CHUNK)))
					if not chunks.has(key):
						chunks[key] = []
					# custom: atlas cell, dryness (drier where the kind is thin), value, wind phase
					var custom := Color(rng.randf(), clampf(rng.randf() * 0.7 + (0.5 - drift) * 0.8, 0.0, 1.0), rng.randf(), rng.randf())
					chunks[key].append([Transform3D(b.scaled_local(Vector3(s, s * rng.randf_range(0.8, 1.15), s)), Vector3(qx, qy - 0.02, qz)), custom])
			x += step
		var mesh := _veg_mesh(kind, tag, ground)
		var rng_end := float(rule.get("range", 55.0))
		for key in chunks:
			var xfs: Array = chunks[key]
			var c := Vector3((key.x + 0.5) * VEG_CHUNK, 0, (key.y + 0.5) * VEG_CHUNK)
			c.y = terrain.height_at(c.x, c.z)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = mesh
			mm.instance_count = xfs.size()
			for i in xfs.size():
				var t: Transform3D = xfs[i][0]
				t.origin -= c
				mm.set_instance_transform(i, t)
				mm.set_instance_custom_data(i, xfs[i][1])
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
