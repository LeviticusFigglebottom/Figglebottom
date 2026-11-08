class_name BuildingGen
## Procedural turf-and-stave houses (docs/art/STYLE.md): a dry-stone footing,
## stave walls of split planks between corner posts, a thick turf roof that
## overhangs the eaves and gables with a grass fringe, and gable ends with
## crossed barge-boards curling into carved, interlaced (non-runic) finials.
## Fixed seed per building id, so a house always looks the same.
## Every board, stone and sod is a ProcMesh box with metre UVs (grain along
## the board), shaded by MaterialLib's photo sets in uv mode.
##
## spec: {"id", "center": [x, z], "size": [w, l], "yaw", "y", "doors": [[side, bay]],
##        "open": [sides], "wall_h", "tag", "gate_doors": [[side, bay]]}
## Sides: N/S along local x at -z/+z, W/E along local z at -x/+x. Bays are 4 m.

const DOOR_W := 1.9
const DOOR_H := 2.5

static func build(area: Area, spec: Dictionary) -> Node3D:
	if String(spec.get("kind", "house")) == "barrow":
		return _barrow(area, spec)
	var tag := String(spec.get("tag", "base"))
	var mode := 1 if tag == "thaw" else (2 if tag == "rime" else 0)
	var w := float(spec["size"][0])
	var l := float(spec["size"][1])
	var y := float(spec.get("y", 0.0))
	var h := float(spec.get("wall_h", 3.2 if w < 12 else 3.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(spec.get("id", "house")))
	var root := Node3D.new()
	root.name = "House_" + String(spec.get("id", "house"))
	root.position = Vector3(float(spec["center"][0]), y, float(spec["center"][1]))
	root.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
	var opens: Array = spec.get("open", [])
	var doors := {}
	for d in spec.get("doors", []) + spec.get("gate_doors", []):
		doors["%s%d" % [String(d[0]), int(d[1])]] = true

	var plank := SurfaceTool.new(); plank.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stone := SurfaceTool.new(); stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var turf := SurfaceTool.new(); turf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beam := SurfaceTool.new(); beam.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solids: Array = []    # [center, size, yaw] boxes for collision (local)

	for side in ["N", "S", "W", "E"]:
		var along_x: bool = side == "N" or side == "S"
		var span := w if along_x else l
		var off := (-l * 0.5 if side == "N" else l * 0.5) if along_x else (-w * 0.5 if side == "W" else w * 0.5)
		if side in opens:
			continue
		# door gaps on this side (local coordinate along the wall)
		var gaps: Array = []
		for i in int(span / 4.0):
			if doors.has("%s%d" % [side, i]):
				gaps.append(-span * 0.5 + 2.0 + 4.0 * i)
		var segs := _segments(-span * 0.5, span * 0.5, gaps)
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			if b - a < 0.05:
				continue
			# dry-stone footing: irregular blocks, a little proud of the wall
			var t := a
			while t < b - 0.05:
				var bw := minf(rng.randf_range(0.45, 0.8), b - t)
				var bh := rng.randf_range(0.38, 0.55)
				var c := t + bw * 0.5
				var p := _wall_pt(along_x, off, c, bh * 0.5)
				_box(stone, Vector3(bw * 0.97, bh, rng.randf_range(0.5, 0.62)) if along_x else Vector3(rng.randf_range(0.5, 0.62), bh, bw * 0.97),
					p, Vector3(0, rng.randf_range(-4, 4), rng.randf_range(-3, 3)))
				t += bw
			# staves: split planks, each its own height and lean
			t = a
			while t < b - 0.02:
				var pw := minf(rng.randf_range(0.22, 0.3), b - t)
				var ph := h - 0.4 + rng.randf_range(-0.04, 0.06)
				var pc := t + pw * 0.5
				var pp := _wall_pt(along_x, off, pc, 0.4 + ph * 0.5)
				var sz := Vector3(pw * 0.96, ph, 0.12) if along_x else Vector3(0.12, ph, pw * 0.96)
				_box(plank, sz, pp, Vector3(0, 0, rng.randf_range(-0.8, 0.8)) if along_x else Vector3(rng.randf_range(-0.8, 0.8), 0, 0))
				t += pw
			var mid := (a + b) * 0.5
			solids.append([_wall_pt(along_x, off, mid, h * 0.5), Vector3(b - a, h, 0.4) if along_x else Vector3(0.4, h, b - a)])
		# over each door: a lintel and short staves; posts either side
		for g in gaps:
			var gc: float = g
			_box(beam, Vector3(DOOR_W + 0.5, 0.22, 0.26) if along_x else Vector3(0.26, 0.22, DOOR_W + 0.5),
				_wall_pt(along_x, off, gc, DOOR_H + 0.11), Vector3.ZERO)
			var t2 := gc - DOOR_W * 0.5
			while t2 < gc + DOOR_W * 0.5 - 0.02:
				var pw2 := 0.27
				var ph2 := h - DOOR_H - 0.2
				_box(plank, Vector3(pw2 * 0.96, ph2, 0.12) if along_x else Vector3(0.12, ph2, pw2 * 0.96),
					_wall_pt(along_x, off, t2 + pw2 * 0.5, DOOR_H + 0.2 + ph2 * 0.5), Vector3.ZERO)
				t2 += pw2
			for s in [-1.0, 1.0]:
				_box(beam, Vector3(0.24, DOOR_H + 0.2, 0.3) if along_x else Vector3(0.3, DOOR_H + 0.2, 0.24),
					_wall_pt(along_x, off, gc + s * (DOOR_W * 0.5 + 0.12), (DOOR_H + 0.2) * 0.5), Vector3.ZERO)
			solids.append([_wall_pt(along_x, off, gc, (h + DOOR_H) * 0.5 + 0.1), Vector3(DOOR_W, h - DOOR_H, 0.4) if along_x else Vector3(0.4, h - DOOR_H, DOOR_W)])
		# wall plate along the top
		_box(beam, Vector3(span + 0.3, 0.24, 0.3) if along_x else Vector3(0.3, 0.24, span + 0.3),
			_wall_pt(along_x, off, 0.0, h + 0.12), Vector3.ZERO)
	# corner posts, adzed square, standing on the footing
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(beam, Vector3(0.36, h + 0.3, 0.36), Vector3(sx * w * 0.5, (h + 0.3) * 0.5, sz * l * 0.5),
				Vector3(0, rng.randf_range(-6, 6), 0))

	_roof(turf, plank, beam, w, l, h, rng)
	for sz in [-1.0, 1.0]:
		if (sz < 0 and "N" in opens) or (sz > 0 and "S" in opens):
			_gable(plank, beam, w, h, sz * l * 0.5, sz, rng, true)
		else:
			_gable(plank, beam, w, h, sz * l * 0.5, sz, rng, false)

	# far LOD: past ~40 m the split staves alias into moiré stripes, so the
	# walls swap to plain plank-coloured slabs (the outline stays the same)
	var far := SurfaceTool.new(); far.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sd in solids:
		var sz: Vector3 = sd[1]
		_box(far, Vector3(sz.x if sz.x > 0.5 else 0.16, sz.y - (0.4 if sz.y > 3.0 else 0.0), sz.z if sz.z > 0.5 else 0.16),
			sd[0] + Vector3(0, 0.2 if sz.y > 3.0 else 0.0, 0), Vector3.ZERO)
	for pair in [[plank, "M_wood"], [stone, "M_drystone"], [turf, "M_turf"], [beam, "M_wood_dark"], [far, "M_wood"]]:
		var st: SurfaceTool = pair[0]
		var mesh := ProcMesh.finish(st)
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, MaterialLib.get_mat(String(pair[1]), mode, true))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = String(pair[1])
		if pair[0] == plank:
			mi.visibility_range_end = 60.0
			mi.visibility_range_end_margin = 4.0
		elif pair[0] == far:
			mi.name = "walls_far"
			mi.visibility_range_begin = 60.0
			mi.visibility_range_begin_margin = 4.0
		root.add_child(mi)

	var body := StaticBody3D.new()
	body.collision_layer = 1 << (AreaBuilder._tag_bit(tag) - 1)
	body.collision_mask = 0
	for s in solids:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = s[1]
		cs.shape = bx
		cs.position = s[0]
		body.add_child(cs)
	root.add_child(body)
	area.attach(root, tag)
	return root

static func _segments(a: float, b: float, gaps: Array) -> Array:
	var out: Array = []
	var cur := a
	gaps.sort()
	for g in gaps:
		out.append([cur, float(g) - DOOR_W * 0.5])
		cur = float(g) + DOOR_W * 0.5
	out.append([cur, b])
	return out

static func _wall_pt(along_x: bool, off: float, t: float, y: float) -> Vector3:
	return Vector3(t, y, off) if along_x else Vector3(off, y, t)

static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, rot_deg: Vector3) -> void:
	ProcMesh.box(st, size, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos))

## Thick turf over boards, overhanging eaves and gables, a turf roll on the
## ridge and a ragged grass fringe hanging at the eaves.
static func _roof(turf: SurfaceTool, plank: SurfaceTool, beam: SurfaceTool, w: float, l: float, h: float,
		rng: RandomNumberGenerator) -> void:
	var over := 0.75
	var half := w * 0.5 + over
	var rise := w * 0.42
	var slope := sqrt(half * half + rise * rise)
	var ang := atan2(rise, half)
	var length := l + over * 2.0
	for s in [-1.0, 1.0]:
		var basis := Basis(Vector3.BACK, -s * ang)
		var mid := Vector3(s * half * 0.5, h + rise * 0.5 - 0.05, 0)
		var n := basis * Vector3.UP
		ProcMesh.box(turf, Vector3(slope, 0.55, length), Transform3D(basis, mid + n * 0.33))
		ProcMesh.box(plank, Vector3(slope + 0.05, 0.1, length - 0.1), Transform3D(basis, mid))
		# grass fringe along the eave: ragged tufts hanging over the edge
		var eave := Vector3(s * half, h - 0.1, 0)
		var z := -length * 0.5 + 0.2
		while z < length * 0.5 - 0.2:
			var tw := rng.randf_range(0.3, 0.6)
			var th := rng.randf_range(0.25, 0.55)
			ProcMesh.box(turf, Vector3(0.22, th, tw),
				Transform3D(Basis(Vector3.BACK, -s * rng.randf_range(0.2, 0.5)), eave + Vector3(s * 0.05, -th * 0.35 + 0.2, z)))
			z += tw * 0.8
		# rafter ends showing under the turf
		var zr := -l * 0.5
		while zr <= l * 0.5 + 0.01:
			ProcMesh.box(beam, Vector3(half + 0.1, 0.16, 0.14),
				Transform3D(basis, Vector3(s * half * 0.5, h + rise * 0.5 - 0.22, zr)))
			zr += 2.0
	# the ridge roll
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = length
	cm.radial_segments = 8
	ProcMesh.append(turf, cm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, h + rise + 0.3, 0)), Vector2(TAU * 0.42, length))

## A gable end: vertical boards filling the triangle (or left open on an open
## side), crossed barge-boards that run past the ridge into curled horns, and
## an interlaced knot boss on the boards. Abstract, never letters.
static func _gable(plank: SurfaceTool, beam: SurfaceTool, w: float, h: float, zoff: float, s: float,
		rng: RandomNumberGenerator, open_end: bool) -> void:
	var rise := w * 0.42
	var half := w * 0.5
	if not open_end:
		var x := -half
		while x < half - 0.05:
			var pw := 0.26
			var cx := x + pw * 0.5
			var top := rise * (1.0 - absf(cx) / (half + 0.75 * 0.0)) - 0.05
			if top > 0.1:
				ProcMesh.box(plank, Vector3(pw * 0.95, top, 0.1),
					Transform3D(Basis.IDENTITY, Vector3(cx, h + top * 0.5, zoff + s * 0.05)))
			x += pw
	# barge-boards, crossing above the ridge
	var over := 0.75
	var bh := half + over
	var blen := sqrt(bh * bh + rise * rise) + 0.9
	var ang := atan2(rise, bh)
	var zb := zoff + s * (over + 0.1)
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3.BACK, -side * ang)
		# shifted toward the ridge so each board runs ~0.45 m past it
		var centre := Vector3(side * (bh * 0.5 - 0.4 * cos(ang)), h + rise * 0.5 + 0.4 * sin(ang) + 0.3, zb)
		ProcMesh.box(beam, Vector3(blen, 0.32, 0.1), Transform3D(basis, centre))
	# horns: each board end curls back on itself (a quarter torus each)
	var apex := Vector3(0, h + rise + 0.75, zb)
	for side in [-1.0, 1.0]:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.18
		tm.outer_radius = 0.3
		tm.rings = 10
		tm.ring_segments = 6
		ProcMesh.append(beam, tm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), apex + Vector3(side * 0.42, 0.25, 0)), Vector2(TAU * 0.3, 0.6))
	# the knot boss: two interlaced rings and a cross-band, carved in the boards
	if not open_end:
		var kc := Vector3(0, h + rise * 0.38, zoff + s * 0.14)
		for k in 3:
			var tk := TorusMesh.new()
			tk.inner_radius = 0.2
			tk.outer_radius = 0.28
			tk.rings = 14
			tk.ring_segments = 6
			var b := Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.0, 0.55))
			var a := k * TAU / 3.0 + PI * 0.5
			ProcMesh.append(beam, tk, Transform3D(b, kc + Vector3(cos(a), sin(a), 0) * 0.17), Vector2(TAU * 0.28, 0.5))

static func _bm(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


# ------------------------------------------------------------ barrows

## A long barrow (the Lowe): a dry-stone facade with winged walls and a
## lintelled doorway, a stone passage roofed with capstones running back into
## a long turf mound, and a turf door. THAW: the door is in. RIME: every door
## stands open, propped on a frozen spade, the passage dark behind it.
## The mound is solid; only the passage is walkable. Door faces local +Z.
static func _barrow(area: Area, spec: Dictionary) -> Node3D:
	var w := float(spec["size"][0])
	var l := float(spec["size"][1])
	var y := float(spec.get("y", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(spec.get("id", "barrow")))
	var root := Node3D.new()
	root.name = "House_" + String(spec.get("id", "barrow"))
	root.position = Vector3(float(spec["center"][0]), y, float(spec["center"][1]))
	root.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
	var stone := SurfaceTool.new(); stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var turf := SurfaceTool.new(); turf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solids: Array = []
	var front := l * 0.5
	var pass_w := 1.5
	var pass_h := 1.85
	var pass_l := minf(7.0, l * 0.55)
	var wall_h := 2.3
	var wing := w * 0.5 + 1.6
	# facade: coursed dry-stone, wings curving back into the mound
	for side in [-1.0, 1.0]:
		var x := pass_w * 0.5
		while x < wing:
			var bw := rng.randf_range(0.5, 0.9)
			var course := 0.0
			var ht := wall_h * (1.0 - smoothstep(wing * 0.6, wing, x) * 0.6)
			while course < ht:
				var bh := rng.randf_range(0.18, 0.3)
				var bz := front - smoothstep(wing * 0.5, wing, x) * 1.6
				_box(stone, Vector3(bw * 0.95, bh * 0.95, rng.randf_range(0.55, 0.75)),
					Vector3(side * (x + bw * 0.5), course + bh * 0.5, bz), Vector3(rng.randf_range(-3, 3), rng.randf_range(-6, 6), rng.randf_range(-3, 3)))
				course += bh
			x += bw
		solids.append([Vector3(side * (pass_w * 0.5 + (wing - pass_w * 0.5) * 0.5), wall_h * 0.5, front - 0.4),
			Vector3(wing - pass_w * 0.5, wall_h, 1.2)])
	# the lintel and the stones over the door
	_box(stone, Vector3(pass_w + 1.0, 0.35, 0.8), Vector3(0, pass_h + 0.18, front), Vector3(0, 0, rng.randf_range(-2, 2)))
	_box(stone, Vector3(pass_w + 0.6, wall_h - pass_h - 0.35, 0.65), Vector3(0, (wall_h + pass_h + 0.35) * 0.5, front), Vector3.ZERO)
	# the passage: walls of upright slabs, capstones over, a back stone
	for side in [-1.0, 1.0]:
		var z := front
		while z > front - pass_l:
			var sl := rng.randf_range(0.6, 1.0)
			_box(stone, Vector3(0.35, pass_h + 0.1, sl * 0.95), Vector3(side * (pass_w * 0.5 + 0.17), (pass_h + 0.1) * 0.5, z - sl * 0.5),
				Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-4, 4)))
			z -= sl
		solids.append([Vector3(side * (pass_w * 0.5 + 0.2), pass_h * 0.5, front - pass_l * 0.5), Vector3(0.4, pass_h, pass_l)])
	var zc := front
	while zc > front - pass_l:
		var cl := rng.randf_range(0.8, 1.2)
		_box(stone, Vector3(pass_w + 0.9, 0.3, cl), Vector3(0, pass_h + 0.18, zc - cl * 0.5), Vector3(0, rng.randf_range(-5, 5), rng.randf_range(-3, 3)))
		zc -= cl
	_box(stone, Vector3(pass_w + 0.4, pass_h + 0.2, 0.4), Vector3(0, pass_h * 0.5, front - pass_l), Vector3.ZERO)
	solids.append([Vector3(0, pass_h * 0.5, front - pass_l - 0.1), Vector3(pass_w + 0.4, pass_h, 0.4)])
	# the mound: a long whaleback of turf, lumpy, a little lop-sided
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 18
	sm.rings = 9
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 1.2
	var mh := 2.6 + w * 0.12
	for i in verts.size():
		var v := verts[i]
		v *= 1.0 + 0.08 * noise.get_noise_3dv(v * 2.0)
		v = Vector3(v.x * (w * 0.5 + 1.2), maxf(v.y, -0.15) * mh, v.z * l * 0.5)
		verts[i] = v
	arr[Mesh.ARRAY_VERTEX] = verts
	var mst := SurfaceTool.new()
	mst.create_from_arrays(arr)
	mst.generate_normals()
	turf.append_from(mst.commit(), 0, Transform3D(Basis.IDENTITY, Vector3(0, -0.2, -0.6)))
	# mound collision: the turf either side of the passage and behind it
	var mx := w * 0.5 + 1.0
	for side in [-1.0, 1.0]:
		solids.append([Vector3(side * (pass_w * 0.5 + 0.4 + (mx - pass_w * 0.5 - 0.4) * 0.5), 1.4, -0.6), Vector3(mx - pass_w * 0.5 - 0.4, 2.8, l - 1.2)])
	solids.append([Vector3(0, 1.4, (front - pass_l - 0.3 - l * 0.5 + 0.6) * 0.5 - 0.3), Vector3(pass_w + 0.8, 2.8, maxf(0.5, front - pass_l - 0.3 + l * 0.5 - 0.6))])
	for pair in [[stone, "M_drystone"], [turf, "M_turf"]]:
		var st: SurfaceTool = pair[0]
		var mesh: ArrayMesh
		if pair[0] == stone:
			mesh = ProcMesh.finish(st)
		else:
			# the lumpy mound has no metre UVs: object-aligned triplanar
			st.generate_normals()
			mesh = st.commit()
		mesh.surface_set_material(0, MaterialLib.get_mat(String(pair[1]), 0, pair[0] == stone))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = String(pair[1])
		root.add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	body.collision_mask = 0
	for sd in solids:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = sd[1]
		cs.shape = bx
		cs.position = sd[0]
		body.add_child(cs)
	root.add_child(body)
	area.attach(root, "base")
	# the turf door: in, in THAW; open and propped on a frozen spade in RIME
	var door_tag := String(spec.get("door", "thaw_shut"))
	var xf := root.transform
	if door_tag != "open":
		var shut_tag := "thaw" if door_tag == "thaw_shut" else "base"
		var shut := _turf_door(Vector3(pass_w + 0.1, pass_h, 0.3), true, AreaBuilder._tag_bit(shut_tag))
		shut.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, front + 0.25))
		area.attach(shut, shut_tag)
	if door_tag != "shut":
		var open_tag := "rime" if door_tag == "thaw_shut" else "base"
		var lm := _landmark("res://assets/models/landmarks/lm_barrow_door.glb")
		if lm != null:
			# the Tripo barrow door: jambs, lintel, the turf door propped on its
			# spade. Dressing only: the passage behind stays open to walk.
			lm.transform = xf * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (w / 6.0)), Vector3(0, 0, front + 0.35))
			area.attach(lm, open_tag)
		else:
			var propped := _turf_door(Vector3(pass_w + 0.1, pass_h, 0.3), false, 0)
			propped.transform = xf * Transform3D(Basis(Vector3.UP, 0.5) * Basis(Vector3.RIGHT, -0.25), Vector3(pass_w + 0.4, 0, front + 0.9))
			area.attach(propped, open_tag)
	return root

## A landmark scene with its collision stripped (we place our own).
static func _landmark(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is CollisionObject3D:
			c.get_parent().remove_child(c)
			c.free()
			continue
		for ch in c.get_children():
			stack.append(ch)
	return n

static func _turf_door(size: Vector3, collide: bool, bit: int) -> Node3D:
	var n := Node3D.new()
	n.name = "TurfDoor"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	while y < size.y - 0.05:
		var sh := rng.randf_range(0.22, 0.3)
		_box(st, Vector3(size.x, sh * 0.95, size.z), Vector3(rng.randf_range(-0.04, 0.04), y + sh * 0.5, 0), Vector3(0, 0, rng.randf_range(-2, 2)))
		y += sh
	var mi := MeshInstance3D.new()
	mi.mesh = ProcMesh.finish(st)
	mi.mesh.surface_set_material(0, MaterialLib.get_mat("M_peat", 0, true))
	n.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_mask = 0
		body.collision_layer = 1 << (bit - 1)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = size
		cs.shape = bx
		cs.position.y = size.y * 0.5
		body.add_child(cs)
		n.add_child(body)
	return n
