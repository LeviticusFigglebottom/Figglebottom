class_name HouseInterior
## The inside of a BuildingGen house (docs/art/WORLD_FIDELITY.md): king-post
## trusses on the bay lines (tie beam, knee braces off the wall posts, king
## post, struts to the purlins), raised side benches in dwellings, a kerbed
## hearth where the floor is free, goods hung from the ties, and the light:
## a ReflectionProbe that gives the room its own ambient (warm in THAW, cold
## blue in RIME) and its own reflections instead of the sky's.
## Nothing here collides. Benches hug the wall inside the wall's own collision
## reach; everything else is above head height or flush with the floor.
## Fittings step round whatever the area already put in the room.

## Things the area JSON placed, in house space: [x, z, radius].
static func _occupied(hd: HouseDetail) -> Array:
	var out: Array = []
	var inv := Basis(Vector3.UP, -hd.yaw)
	for key in ["props", "pieces", "npcs", "pickups", "spawners", "hearths", "landmarks", "gates", "boxes"]:
		for sp in hd.area_def.get(key, []):
			var p := Vector3.INF
			var r := 0.9
			if sp.has("min") and sp.has("max"):
				var mn: Array = sp["min"]
				var mx: Array = sp["max"]
				var sx := float(mx[0]) - float(mn[0])
				var sz := float(mx[2]) - float(mn[2])
				# floors, decks and ice sheets are not furniture
				if float(mx[1]) < hd.origin.y + 0.25 or float(mn[1]) > hd.origin.y + 2.2 or maxf(sx, sz) > 30.0:
					continue
				p = Vector3((float(mn[0]) + float(mx[0])) * 0.5, 0, (float(mn[2]) + float(mx[2])) * 0.5)
				r = maxf(minf(sx, sz) * 0.5 + 0.2, 0.3)
				# a long box is a row of discs
				var long := maxf(sx, sz)
				if long > r * 3.0:
					var ax := Vector3(1, 0, 0) if sx > sz else Vector3(0, 0, 1)
					var k := -long * 0.5 + r
					while k <= long * 0.5 - r + 0.01:
						var q := inv * (p + ax * k - Vector3(hd.origin.x, 0, hd.origin.z))
						out.append(Vector3(q.x, q.z, r))
						k += r
					continue
			elif sp.has("at"):
				var at: Array = sp["at"]
				if at.size() < 3 or absf(float(at[1]) - hd.origin.y) > 3.0:
					continue
				p = Vector3(float(at[0]), 0, float(at[2]))
				if String(sp.get("kit", "")).contains("3m"):
					r = 1.7
			if p == Vector3.INF:
				continue
			var lp := inv * (p - Vector3(hd.origin.x, 0, hd.origin.z))
			if absf(lp.x) < hd.w * 0.5 + 1.0 and absf(lp.z) < hd.l * 0.5 + 1.0:
				out.append(Vector3(lp.x, lp.z, r))
	return out

static func _blocked(occ: Array, x0: float, x1: float, z0: float, z1: float) -> bool:
	for o in occ:
		var c: Vector3 = o
		var dx := maxf(maxf(x0 - c.x, c.x - x1), 0.0)
		var dz := maxf(maxf(z0 - c.y, c.y - z1), 0.0)
		if dx * dx + dz * dz < c.z * c.z:
			return true
	return false

static func build(hd: HouseDetail, root: Node3D) -> void:
	var occ := _occupied(hd)
	_trusses(hd)
	if hd.style == "hall":
		_benches(hd, occ)
	if hd.style == "hall" or hd.style == "fish":
		_hearth(hd, root, occ)
	_goods(hd)
	# Low keeps the sky ambient indoors: no probe to capture or blend
	if EnvRig.get_graphics_quality() >= 1:
		_probe(hd, root)

## Purlin position on slope s (house space): where the struts land.
static func _purlin(hd: HouseDetail, s: float) -> Vector3:
	return hd.slope_xf(s) * Vector3(hd.slope * 0.5, -0.3, 0)

static func _trusses(hd: HouseDetail) -> void:
	var d := hd.in_dark
	var n := int(hd.l / 4.0)
	var ridge_y := hd.h - 0.05 + hd.rise - 0.42
	for k in range(1, n):
		var z := -hd.l * 0.5 + 4.0 * k
		var ty := hd.h + 0.14
		# tie beam across the plates
		d.beam(Vector3(-hd.w * 0.5 + 0.02, ty, z), Vector3(hd.w * 0.5 - 0.02, ty, z), 0.2, 0.24, Vector3.UP, 0.03)
		# king post, flared a little where it meets the tie
		d.beam(Vector3(0, ty + 0.1, z), Vector3(0, ridge_y, z), 0.17, 0.17, Vector3.RIGHT, 0.025)
		for s: float in [-1.0, 1.0]:
			var pu := _purlin(hd, s)
			# strut from the foot of the king post up to the purlin
			d.beam(Vector3(s * 0.12, ty + 0.14, z), Vector3(pu.x - s * 0.05, pu.y - 0.1, z), 0.12, 0.13, Vector3(0, 0, 1), 0.02)
			# knee brace from the wall post up to the tie
			if not (("W" if s < 0.0 else "E") in hd.opens):
				var bx := s * (hd.w * 0.5 - 0.14)
				var reach := minf(1.15, hd.w * 0.16)
				d.beam(Vector3(bx, ty - 0.12 - reach, z), Vector3(bx - s * reach, ty - 0.1, z), 0.11, 0.13, Vector3(0, 0, 1), 0.02)
				# peg heads where the brace is trenailed
				hd.fine.pole(Vector3(bx - s * 0.03, ty - 0.2 - reach * 0.86, z - 0.09), Vector3(bx - s * 0.03, ty - 0.2 - reach * 0.86, z + 0.09), 0.014, 0.0, 5)

## Raised benches down the long walls of a dwelling: a boarded top on short
## posts with a front board, broken at doors and where the room is in use.
static func _benches(hd: HouseDetail, occ: Array) -> void:
	var depth := 0.5
	var top := 0.44
	for s: float in [-1.0, 1.0]:
		var side := "W" if s < 0.0 else "E"
		if side in hd.opens:
			continue
		var x1 := s * (hd.w * 0.5 - 0.07)
		var x0 := s * (hd.w * 0.5 - 0.07 - depth)
		var z := -hd.l * 0.5 + 0.35
		while z < hd.l * 0.5 - 0.5:
			var z1 := minf(z + 2.0, hd.l * 0.5 - 0.35)
			var free := not _blocked(occ, minf(x0, x1) - 0.1, maxf(x0, x1), z, z1)
			for dr in hd.doors:
				var dp: Vector3 = hd.side_xf(String(dr["side"])) * Vector3(float(dr["t"]), 0, 0)
				if absf(dp.x - x1) < 2.2 and dp.z > z - 1.5 and dp.z < z1 + 1.5:
					free = false
			if free and z1 - z > 0.8:
				var b := hd.in_wood
				var cx := (x0 + x1) * 0.5
				for k in 2:
					var bx := lerpf(x0, x1, (float(k) + 0.5) / 2.0)
					b.box(Vector3(depth * 0.5 - 0.008, 0.045, z1 - z - 0.01), Transform3D(Basis.IDENTITY, Vector3(bx, top - 0.022 - b.rnd() * 0.006, (z + z1) * 0.5)), 2)
				b.box(Vector3(0.035, top - 0.07, z1 - z - 0.01), Transform3D(Basis.IDENTITY, Vector3(x0 + s * 0.03, (top - 0.05) * 0.5, (z + z1) * 0.5)), 2)
				for pz in [z + 0.08, z1 - 0.08]:
					hd.in_dark.beam(Vector3(x0 + s * 0.06, 0.0, float(pz)), Vector3(x0 + s * 0.06, top - 0.04, float(pz)), 0.09, 0.09, Vector3.RIGHT, 0.012)
				# a fleece or a folded blanket here and there
				if b.rnd() < 0.35:
					hd.in_cloth.stone(Vector3(depth * 0.8, 0.07, 0.7 + b.rnd() * 0.4), Transform3D(Basis(Vector3.UP, (b.rnd() - 0.5) * 0.3), Vector3(cx, top + 0.03, lerpf(z, z1, 0.3 + b.rnd() * 0.4))), 0.5)
			z = z1

## A hearth on the floor under the smoke-hole: a kerb of stones set flush, a
## bed of ash and embers, and a low fire that flickers. Skipped where the
## area already keeps its own fire or the floor is in use.
static func _hearth(hd: HouseDetail, root: Node3D, occ: Array) -> void:
	var zc := hd.louvre_z if hd.louvre_z != INF else 0.0
	var hx := 0.55
	var hz := minf(hd.l * 0.09, 1.3)
	# under the smoke-hole if the floor is free there, else a step along the room
	var found := false
	for off in [0.0, 1.7, -1.7, 3.2, -3.2]:
		var zt: float = zc + off
		if absf(zt) + hz < hd.l * 0.5 - 1.1 and not _blocked(occ, -hx - 0.5, hx + 0.5, zt - hz - 0.5, zt + hz + 0.5):
			zc = zt
			found = true
			break
	if not found:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hd.id + "|hearth")
	# kerb stones round the bed
	var per: Array = []
	var t := -hx
	while t < hx:
		per.append(Vector3(t, 0, zc - hz)); per.append(Vector3(-t, 0, zc + hz))
		t += 0.3
	t = -hz
	while t < hz:
		per.append(Vector3(-hx, 0, zc + t)); per.append(Vector3(hx, 0, zc - t))
		t += 0.3
	for p in per:
		var q: Vector3 = p
		hd.in_stone.stone(Vector3(rng.randf_range(0.26, 0.36), rng.randf_range(0.12, 0.17), rng.randf_range(0.2, 0.28)),
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q + Vector3(rng.randf_range(-0.03, 0.03), 0.015, rng.randf_range(-0.03, 0.03))), 0.55)
	# ash bed, charred billets, embers
	var ash := MeshBuf.new(7)
	ash.stone(Vector3(hx * 2.0, 0.07, hz * 2.0), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, zc)), 0.25)
	for k in 5:
		var a := rng.randf() * TAU
		var c := Vector3(rng.randf_range(-0.2, 0.2), 0.07, zc + rng.randf_range(-hz * 0.5, hz * 0.5))
		var dir := Vector3(cos(a), rng.randf_range(0.0, 0.25), sin(a)) * rng.randf_range(0.22, 0.34)
		hd.in_dark.pole(c - dir, c + dir, rng.randf_range(0.035, 0.055), 0.0, 6)
	var embers := MeshBuf.new(9)
	for k in 9:
		embers.stone(Vector3(rng.randf_range(0.06, 0.13), 0.05, rng.randf_range(0.06, 0.12)),
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.25, 0.25), 0.045, zc + rng.randf_range(-hz * 0.55, hz * 0.55))), 0.6)
	for pair in [[ash, "M_peat", 0], [embers, "M_ember", 1]]:
		var mi := MeshInstance3D.new()
		mi.name = "hearth_" + ("embers" if int(pair[2]) == 1 else "ash")
		mi.mesh = (pair[0] as MeshBuf).commit(MaterialLib.get_mat(String(pair[1]), hd.mode, int(pair[2]) == 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = HouseDetail.LOD_MID * 0.7
		mi.set_instance_shader_parameter("indoor", 1.0)
		root.add_child(mi)
	# the fire's light: THAW only (flame_flicker fades it out with the frost)
	var fire := Node3D.new()
	fire.name = "hearth_fire"
	fire.position = Vector3(0, 0.45, zc)
	var lt := OmniLight3D.new()
	lt.set_script(load("res://src/world/flame_flicker.gd"))
	lt.light_color = Color(1.0, 0.6, 0.28)
	lt.light_energy = 1.5
	lt.omni_range = minf(hd.w, 9.0)
	lt.omni_attenuation = 1.5
	lt.shadow_enabled = false
	lt.distance_fade_enabled = true
	lt.distance_fade_begin = 30.0
	lt.distance_fade_length = 10.0
	fire.add_child(lt)
	root.add_child(fire)

## Goods hung from the ties, all above head height.
static func _goods(hd: HouseDetail) -> void:
	var n := int(hd.l / 4.0)
	if n < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hd.id + "|goods")
	var ty := hd.h + 0.02
	for k in range(1, n):
		var z := -hd.l * 0.5 + 4.0 * k
		match hd.style:
			"fish":
				# poles of split fish drying between this tie and the next
				for x in [-hd.w * 0.26, hd.w * 0.08, hd.w * 0.3]:
					var px: float = x + rng.randf_range(-0.2, 0.2)
					var z1 := minf(z + 3.2, hd.l * 0.5 - 0.5)
					hd.in_dark.pole(Vector3(px, ty + 0.27, z - 0.25), Vector3(px, ty + 0.27, z1), 0.03, 0.03, 6)
					var fz := z + 0.2
					while fz < z1 - 0.2:
						var fl := rng.randf_range(0.26, 0.4)
						hd.in_hide.stone(Vector3(rng.randf_range(0.07, 0.1), fl, 0.03),
							Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.08, 0.08)), Vector3(px, ty + 0.22 - fl * 0.5, fz)), 0.55)
						fz += rng.randf_range(0.11, 0.2)
			"shed":
				# spare oars and a spar laid across the ties
				if k < n - 1:
					for x in [-hd.w * 0.3, hd.w * 0.22]:
						var px: float = x + rng.randf_range(-0.3, 0.3)
						hd.in_wood.pole(Vector3(px, ty + 0.3, z - 0.5), Vector3(px + rng.randf_range(-0.2, 0.2), ty + 0.3, z + 4.4), 0.03, 0.0, 6)
						hd.in_wood.box(Vector3(0.14, 0.025, 0.7), Transform3D(Basis.IDENTITY, Vector3(px, ty + 0.3, z - 0.75)), 2)
				_coil(hd, Vector3(hd.w * 0.5 - 0.2, hd.h - 0.9, z + 0.25), rng)
			"byre":
				_coil(hd, Vector3(-hd.w * 0.5 + 0.2, hd.h - 0.9, z - 0.25), rng)
			_:
				# hams, a sack, bunches of herbs, each on its own cord
				var cnt := 3 if hd.style == "hall" else 2
				for j in cnt:
					var x := rng.randf_range(-hd.w * 0.36, hd.w * 0.36)
					if absf(x) < 0.5:
						x += 0.9
					var drop := rng.randf_range(0.25, 0.55)
					var top := Vector3(x, ty, z + rng.randf_range(-0.05, 0.05))
					hd.in_rope.pole(top, top - Vector3(0, drop, 0), 0.008, 0.0, 4)
					var r := rng.randf()
					if r < 0.4:
						hd.in_hide.stone(Vector3(0.2, 0.36, 0.16) * rng.randf_range(0.85, 1.15),
							Transform3D(Basis(Vector3.UP, rng.randf() * TAU), top - Vector3(0, drop + 0.17, 0)), 0.75)
					elif r < 0.7:
						hd.in_hide.stone(Vector3(0.3, 0.42, 0.26), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), top - Vector3(0, drop + 0.2, 0)), 0.6)
					else:
						for b in 5:
							var a := rng.randf() * TAU
							var tip := top - Vector3(cos(a) * 0.09, drop + rng.randf_range(0.25, 0.4), sin(a) * 0.09)
							hd.fine.pole(top - Vector3(0, drop, 0), tip, 0.012, 0.0, 4, 2.2)
				if k % 2 == 1:
					_coil(hd, Vector3((hd.w * 0.5 - 0.2) * (1.0 if rng.randf() < 0.5 else -1.0), hd.h - 0.95, z + 0.26), rng)

## A coil of rope hung on a peg in a wall post.
static func _coil(hd: HouseDetail, at: Vector3, rng: RandomNumberGenerator) -> void:
	var sgn := signf(at.x)
	hd.fine.pole(Vector3(at.x + sgn * 0.08, at.y + 0.2, at.z), Vector3(at.x - sgn * 0.1, at.y + 0.23, at.z), 0.016, 0.0, 5)
	for k in 3:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.15 + k * 0.006
		tm.outer_radius = 0.19 + k * 0.006
		tm.rings = 14
		tm.ring_segments = 5
		var bs := Basis(Vector3(0, 0, 1), PI * 0.5 + rng.randf_range(-0.08, 0.08)) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.1, 0.1))
		hd.in_rope.append_mesh(tm, Transform3D(bs.scaled(Vector3(1.0, 1.0, 1.25)), at - Vector3(sgn * (0.035 + k * 0.03), 0, 0)), Vector2(1.2, 0.12))

## The room's own ambient and reflections (HouseProbe).
static func _probe(hd: HouseDetail, root: Node3D) -> void:
	var p := HouseProbe.new()
	p.name = "probe"
	var top := hd.h + hd.rise
	p.size = Vector3(hd.w - 0.02, top + 0.4, hd.l - 0.02)
	p.position = Vector3(0, top * 0.5 - 0.2, 0)
	p.origin_offset = Vector3(0, minf(1.7, hd.h * 0.5) - p.position.y, 0)
	# open-fronted sheds are half outdoors: a lighter hand
	p.open_air = 0.5 if not hd.opens.is_empty() else 0.0
	root.add_child(p)
