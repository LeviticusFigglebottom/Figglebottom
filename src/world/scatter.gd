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
	"standing_stone", "ice_floe"]

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
		"standing_stone":
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
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

## One MultiMesh per kind and tag, plus colliders for what you can't walk through.
static func _emit(area: Area, kind: String, tag: String, xfs: Array) -> void:
	var mode := 1 if tag == "thaw" else (2 if tag == "rime" else 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh(kind, mode)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Scatter_%s_%s" % [kind, tag]
	mmi.multimesh = mm
	mmi.visibility_range_end = 70.0 if kind in ["rock", "hummock", "driftwood"] else 0.0
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
				if t.basis.get_scale().x < 1.2:
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
			"standing_stone":
				var bx3 := BoxShape3D.new()
				bx3.size = Vector3(0.8, 2.6, 0.5)
				shape = bx3
				off = Vector3(0, 1.3, 0)
			"driftwood":
				if t.basis.get_scale().x < 1.3:
					continue
				var bx4 := BoxShape3D.new()
				bx4.size = Vector3(3.0, 0.5, 0.5)
				shape = bx4
				off = Vector3(0, 0.25, 0)
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
		"standing_stone": m = _box_stack([[Vector3(0.8, 2.7, 0.45), Vector3(0, 1.3, 0), Vector3(0, 0, 3)]], "M_stone_dark", mode)
		"driftwood": m = _driftwood(mode)
		"peat_stack": m = _peat(mode)
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
		var bm := BoxMesh.new()
		bm.size = b[0]
		var xf := Transform3D(Basis.from_euler(Vector3(b[2]) * PI / 180.0), b[1])
		st.append_from(bm, 0, xf)
	var mesh := st.commit()
	mesh.surface_set_material(0, MaterialLib.get_mat(fam, mode))
	return mesh

static func _driftwood(mode: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.16
	cm.height = 2.8
	cm.radial_segments = 7
	st.append_from(cm, 0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.13, 0)))
	var br := CylinderMesh.new()
	br.top_radius = 0.03
	br.bottom_radius = 0.07
	br.height = 1.0
	br.radial_segments = 5
	st.append_from(br, 0, Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.BACK, 1.0), Vector3(0.7, 0.3, 0.2)))
	var mesh := st.commit()
	mesh.surface_set_material(0, MaterialLib.get_mat("M_drift", mode))
	return mesh

## Cut peats stacked to dry, herringbone-ish, under a turf cap.
static func _peat(mode: int) -> ArrayMesh:
	var boxes := []
	for layer in 4:
		var w := 1.5 - layer * 0.22
		for k in 3:
			boxes.append([Vector3(w, 0.26, 0.3), Vector3(0, 0.13 + layer * 0.27, -0.35 + k * 0.35), Vector3(0, (layer % 2) * 9 - 4, 0)])
	var mesh := _box_stack(boxes, "M_peat", mode)
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
