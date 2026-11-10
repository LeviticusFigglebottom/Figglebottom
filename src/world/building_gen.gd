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

	# the construction detail seen inside ~70 m (HouseDetail); the SurfaceTools
	# below now carry only the corner posts, the gable ends and the far LOD
	var hd := HouseDetail.new(spec, area.get_meta("def", {}), mode)
	_hd = hd
	var plank := SurfaceTool.new(); plank.begin(Mesh.PRIMITIVE_TRIANGLES)
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
			var mid := (a + b) * 0.5
			solids.append([_wall_pt(along_x, off, mid, h * 0.5), Vector3(b - a, h, 0.4) if along_x else Vector3(0.4, h, b - a)])
		for g in gaps:
			var gc: float = g
			solids.append([_wall_pt(along_x, off, gc, (h + DOOR_H) * 0.5 + 0.1), Vector3(DOOR_W, h - DOOR_H, 0.4) if along_x else Vector3(0.4, h - DOOR_H, DOOR_W)])
	hd.build_walls()
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

	HouseInterior.build(hd, root)
	if "--house-stats" in OS.get_cmdline_user_args():
		# triangle budget per house, for docs/art/WORLD_FIDELITY.md
		print("[house] %s %s %dx%d tris=%d (small parts %d, interior %d)" % [hd.id, hd.style, int(w), int(l), hd.tri_total(),
			hd.iron.tri_count() + hd.fine.tri_count() + hd.bark.tri_count(),
			hd.in_wood.tri_count() + hd.in_dark.tri_count() + hd.in_stone.tri_count() + hd.in_cloth.tri_count() + hd.in_rope.tri_count() + hd.in_hide.tri_count()])
	if area.terrain != null:
		# tell the land a house stands here (wall-foot shadow, worn doorways,
		# no snow under the roof, drifts against the walls)
		var dws: Array = []
		for d in hd.doors:
			var sx := hd.side_xf(String(d["side"]))
			var wp := hd.world_of(sx * Vector3(float(d["t"]), 0, 0))
			var wn := Basis(Vector3.UP, hd.yaw) * sx.basis.z
			dws.append([wp.x, wp.z, wn.x, wn.z])
		area.terrain.add_footprint(Vector2(root.position.x, root.position.z), Vector2(w * 0.5, l * 0.5),
			hd.yaw, y, 2 if not opens.is_empty() else 0, dws)
	hd.attach(root)
	_hd = null
	if tag == "base":
		# RIME: snow banked against the walls (rime-only, melts with the wave)
		var dm := hd.build_drifts(area.terrain)
		if dm != null:
			var dmi := MeshInstance3D.new()
			dmi.name = "Drift_" + hd.id
			dmi.mesh = dm
			dmi.transform = root.transform
			dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dmi.visibility_range_end = HouseDetail.LOD_MID
			dmi.visibility_range_end_margin = 4.0
			area.attach(dmi, "rime")
	if hd.style == "hall" and hd.louvre_z != INF:
		# woodsmoke drifting from the louvre while the house is lived in (THAW)
		AreaBuilder._smoke(area, hd.louvre_world())
	# far LOD: past HouseDetail.LOD_MID the boards alias into moiré stripes, so
	# the walls swap to plain plank-coloured slabs on a stone band and the roof
	# to plain turf slabs (the outline stays the same)
	var far := SurfaceTool.new(); far.begin(Mesh.PRIMITIVE_TRIANGLES)
	var far_stone := SurfaceTool.new(); far_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sd in solids:
		var sz: Vector3 = sd[1]
		_box(far, Vector3(sz.x if sz.x > 0.5 else 0.16, sz.y - (0.4 if sz.y > 3.0 else 0.0), sz.z if sz.z > 0.5 else 0.16),
			sd[0] + Vector3(0, 0.2 if sz.y > 3.0 else 0.0, 0), Vector3.ZERO)
		if sz.y > DOOR_H:
			_box(far_stone, Vector3(sz.x if sz.x > 0.5 else 0.56, 0.44, sz.z if sz.z > 0.5 else 0.56),
				Vector3(sd[0].x, 0.22, sd[0].z), Vector3.ZERO)
	for pair in [[plank, "M_wood", 0], [beam, "M_wood_dark", 0], [far, "M_wood", 1], [far_stone, "M_drystone", 1], [turf, "M_turf", 1]]:
		var st: SurfaceTool = pair[0]
		var mesh := ProcMesh.finish(st)
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, MaterialLib.get_mat(String(pair[1]), mode, true))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.name = String(pair[1]) + ("_far" if int(pair[2]) == 1 else "")
		if int(pair[2]) == 1:
			mi.visibility_range_begin = HouseDetail.LOD_MID
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

## The house being built: lets _roof and _gable (whose signatures the look
## pass shares) reach the detail builder without new arguments.
static var _hd: HouseDetail = null

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
	# near: boards on rafters, bark, a turf log, lumpy turf, weighted poles
	if _hd != null:
		_hd.build_roof()
	# far (`turf` is the far-LOD tool): the plain slabs and the ridge roll
	for s in [-1.0, 1.0]:
		var basis := Basis(Vector3.BACK, -s * ang)
		var mid := Vector3(s * half * 0.5, h + rise * 0.5 - 0.05, 0)
		var n := basis * Vector3.UP
		ProcMesh.box(turf, Vector3(slope, 0.62, length), Transform3D(basis, mid + n * 0.33))
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
			# up to the underside of the roof boards (which overhang by 0.75)
			var top := rise * (1.0 - (absf(cx) + pw * 0.5) / (half + 0.75)) - 0.12
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
		if _hd != null:
			_carve_barge(_hd.fine, Transform3D(basis, centre), blen, s, side)
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

## Carving on a barge-board: a two-strand interlace run between two fillets,
## cut as raised three-sided ridges. Abstract knotwork, never letters.
static func _carve_barge(buf: MeshBuf, xf: Transform3D, blen: float, s: float, side: float) -> void:
	var keep := buf.xf
	buf.xf = xf
	var z0 := s * 0.056
	var x0 := -blen * 0.5 + 0.55
	var x1 := blen * 0.5 - 1.25
	for e: float in [-1.0, 1.0]:
		buf.box(Vector3(x1 - x0 + 0.3, 0.014, 0.012), Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, e * 0.125, z0)), 0)
	var wave := 0.62          # one full twist of the interlace, metres
	for strand: float in [0.0, PI]:
		var pts := PackedVector3Array()
		var x := x0
		while x <= x1:
			var ph := (x - x0) / wave * TAU + strand
			# over and under: each strand rides up where it crosses the other
			pts.append(Vector3(x, 0.082 * sin(ph), z0 + s * 0.007 * (1.0 + cos(ph * 2.0 + strand)) * (1.0 if strand == 0.0 else -1.0) * side * side))
			x += 0.075
		buf.tube(pts, 0.021, 3, Vector3(0, 0, 1))
	# a lozenge boss closes each end of the run
	for bx in [x0 - 0.16, x1 + 0.16]:
		buf.box(Vector3(0.15, 0.15, 0.016), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), Vector3(float(bx), 0, z0)), 0)
	buf.xf = keep

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
	var stone := MeshBuf.new(int(rng.randi() & 0xffff))
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
				# coursed slabs: split faces, only their arrises knocked off
				_stone(stone, Vector3(bw * 0.99, bh * 1.04, rng.randf_range(0.55, 0.75)),
					Vector3(side * (x + bw * 0.5), course + bh * 0.5, bz + rng.randf_range(-0.04, 0.04)), Vector3(rng.randf_range(-3, 3), rng.randf_range(-6, 6), rng.randf_range(-3, 3)), 0.14)
				course += bh
			x += bw
		solids.append([Vector3(side * (pass_w * 0.5 + (wing - pass_w * 0.5) * 0.5), wall_h * 0.5, front - 0.4),
			Vector3(wing - pass_w * 0.5, wall_h, 1.2)])
	# the lintel and the stones over the door
	_stone(stone, Vector3(pass_w + 1.0, 0.35, 0.8), Vector3(0, pass_h + 0.18, front), Vector3(0, 0, rng.randf_range(-2, 2)), 0.2)
	_stone(stone, Vector3(pass_w + 0.6, wall_h - pass_h - 0.35, 0.65), Vector3(0, (wall_h + pass_h + 0.35) * 0.5, front), Vector3.ZERO, 0.16)
	# the passage: walls of upright slabs, capstones over, a back stone
	for side in [-1.0, 1.0]:
		var z := front
		while z > front - pass_l:
			var sl := rng.randf_range(0.6, 1.0)
			_stone(stone, Vector3(0.35, pass_h + 0.1, sl * 0.98), Vector3(side * (pass_w * 0.5 + 0.17), (pass_h + 0.1) * 0.5, z - sl * 0.5),
				Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-4, 4)), 0.16)
			z -= sl
		solids.append([Vector3(side * (pass_w * 0.5 + 0.2), pass_h * 0.5, front - pass_l * 0.5), Vector3(0.4, pass_h, pass_l)])
	var zc := front
	while zc > front - pass_l:
		var cl := rng.randf_range(0.8, 1.2)
		_stone(stone, Vector3(pass_w + 0.9, 0.3, cl), Vector3(0, pass_h + 0.18, zc - cl * 0.5), Vector3(0, rng.randf_range(-5, 5), rng.randf_range(-3, 3)))
		zc -= cl
	_stone(stone, Vector3(pass_w + 0.4, pass_h + 0.2, 0.4), Vector3(0, pass_h * 0.5, front - pass_l), Vector3.ZERO)
	solids.append([Vector3(0, pass_h * 0.5, front - pass_l - 0.1), Vector3(pass_w + 0.4, pass_h, 0.4)])
	# orthostats: two tall slabs standing either side of the doorway
	for side in [-1.0, 1.0]:
		_stone(stone, Vector3(0.5, wall_h + 0.2, 0.36), Vector3(side * (pass_w * 0.5 + 0.34), (wall_h + 0.2) * 0.5 - 0.1, front + 0.2),
			Vector3(rng.randf_range(-2, 4), rng.randf_range(-8, 8), side * rng.randf_range(1, 4)), 0.2)
	# a threshold slab, and chinking stones wedged along the foot of the facade
	_stone(stone, Vector3(pass_w + 0.5, 0.16, 1.1), Vector3(0, -0.02, front + 0.3), Vector3(0, rng.randf_range(-4, 4), 0), 0.25)
	var cx := pass_w * 0.5 + 0.7
	while cx < wing:
		for side in [-1.0, 1.0]:
			var cz := front - smoothstep(wing * 0.5, wing, cx) * 1.6 + 0.42
			_stone(stone, Vector3(rng.randf_range(0.25, 0.5), rng.randf_range(0.16, 0.3), rng.randf_range(0.22, 0.38)),
				Vector3(side * cx, 0.06, cz + rng.randf_range(-0.05, 0.08)), Vector3(rng.randf_range(-8, 8), rng.randf_range(0, 180), rng.randf_range(-8, 8)), 0.6)
		cx += rng.randf_range(0.45, 0.9)
	# the kerb: a ring of boulders holding the foot of the mound
	var ka := w * 0.5 + 1.15
	var kb := l * 0.5 - 0.05
	var ang := 0.0
	while ang < TAU:
		var kp := Vector3(sin(ang) * ka, 0, cos(ang) * kb - 0.6)
		var step := rng.randf_range(0.55, 1.0)
		# the facade closes the front of the ring
		if kp.z < front - 1.9:
			var kh := rng.randf_range(0.3, 0.62)
			_stone(stone, Vector3(step * 0.95, kh, rng.randf_range(0.4, 0.6)), kp + Vector3(0, kh * 0.5 - 0.12, 0),
				Vector3(rng.randf_range(-6, 6), rad_to_deg(ang) + rng.randf_range(-12, 12), rng.randf_range(-5, 5)), rng.randf_range(0.45, 0.7))
		ang += step / lerpf(kb, ka, absf(cos(ang)))
	# the mound: a long whaleback of turf, lumpy, a little lop-sided
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 36
	sm.rings = 16
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 1.2
	var mh := 2.6 + w * 0.12
	for i in verts.size():
		var v := verts[i]
		v *= 1.0 + 0.08 * noise.get_noise_3dv(v * 2.0) + 0.03 * noise.get_noise_3dv(v * 6.5)
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
	# the stones carry wear / moss / AO: dark at the foot and down the passage,
	# mossed low and on their north faces
	var north := Basis(Vector3.UP, -root.rotation.y) * Vector3(0, 0, -1)
	for i in stone.verts.size():
		var p := stone.verts[i]
		var ao := lerpf(0.5, 1.0, smoothstep(0.0, 0.6, p.y))
		if absf(p.x) < pass_w * 0.5 + 0.5 and p.z < front - 0.2 and p.y < pass_h + 0.4:
			ao *= lerpf(1.0, 0.3, smoothstep(front - 0.2, front - 3.5, p.z))
		var moss := (0.3 + 0.7 * maxf(stone.nrms[i].dot(north), 0.0)) * (1.0 - smoothstep(0.4, 2.2, p.y)) + 0.45 * maxf(stone.nrms[i].y, 0.0)
		stone.cols[i] = Color(0.45, clampf(moss, 0.0, 0.95), clampf(ao, 0.1, 0.97), 1.0)
	var smi := MeshInstance3D.new()
	smi.mesh = stone.commit(HouseDetail.mat("M_drystone", 0, "house", {"moss_strength": 1.0}))
	smi.name = "M_drystone"
	root.add_child(smi)
	# the lumpy mound has no metre UVs: object-aligned triplanar
	turf.generate_normals()
	var tmesh := turf.commit()
	tmesh.surface_set_material(0, MaterialLib.get_mat("M_turf", 0, false))
	var tmi := MeshInstance3D.new()
	tmi.mesh = tmesh
	tmi.name = "M_turf"
	root.add_child(tmi)
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
	if area.terrain != null:
		var mc := root.position + root.transform.basis * Vector3(0, 0, -0.6)
		var dw := root.position + root.transform.basis * Vector3(0, 0, front + 0.4)
		var dn := root.transform.basis * Vector3(0, 0, 1)
		area.terrain.add_footprint(Vector2(mc.x, mc.z), Vector2(w * 0.5 + 0.9, l * 0.5 - 0.3), root.rotation.y, y, 1, [[dw.x, dw.z, dn.x, dn.z]])
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

## A rounded field stone into a MeshBuf (the barrow's facade, passage, kerb).
static func _stone(buf: MeshBuf, size: Vector3, pos: Vector3, rot_deg: Vector3, roundness := 0.36) -> void:
	buf.stone(size, Transform3D(Basis.from_euler(rot_deg * PI / 180.0), pos), roundness)


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
