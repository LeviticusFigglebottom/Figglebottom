class_name Wayside
## Things met along the way (docs/art/WORLD_FIDELITY.md, "Wayside"): cairns,
## rows of standing stones, a sledge left with its load, drying racks, an
## upturned boat with its gear, a stack-yard. Each is a small group of the
## modelled pieces the game already has (Tripo landmarks through
## BuildingGen._landmark, KitLib props through AreaBuilder._piece), set down
## on level ground off the road, with colliders, the same in THAW and RIME.
## Which groups an area gets is its own (RECIPES), so the Lowe is stones and
## cairns, the Kettle is racks and boats, the Reach is cairns and folds' kin.
## Placement is seeded per area and steps round everything the area authored:
## spawners, hearths, veils, houses, boxes, hazards, traps, the road itself.

const STEP := 19.0
## where the whole yard is trodden earth, groups may stand on it (off its middle)
const TRODDEN := {"tarnhall": 0.9, "kettle_fjord": 0.9}
## small regions are searched on a finer grid; the fjord's cliff tops are out of reach
const FINE := {"tarnhall": 10.0, "kettle_fjord": 9.0}
const Y_MAX := {"kettle_fjord": 12.0}
const MAX_GROUPS := 26      # a region is dressed, not stocked
const RECIPES := {
	"saltfell_steading": {"cairn": 2, "stones": 1, "racks": 2, "boat": 3, "sledge": 2, "stacks": 1},
	"lowe_barrows": {"stones": 4, "cairn": 3, "sledge": 1},
	"kettle_fjord": {"racks": 3, "boat": 2, "cairn": 1, "stacks": 1},
	"tarnhall": {"sledge": 2, "stacks": 2, "cairn": 2, "stones": 1},
	"shepherds_reach": {"cairn": 3, "stones": 3, "sledge": 2, "stacks": 1},
	"thornwold": {"stacks": 4, "sledge": 2, "cairn": 2, "stones": 1},
	"coldwell": {"cairn": 3, "stones": 3},
}
const KEEP_OUT := {"spawners": 10.0, "hearths": 7.0, "portals": 9.0, "gates": 6.0, "npcs": 6.0, "pickups": 4.5,
	"plaques": 4.0, "props": 4.0, "pieces": 4.0, "landmarks": 7.0, "frost_veils": 10.0}
const LM := "res://assets/models/landmarks/"

static func build(area: Area, def: Dictionary) -> int:
	var rec: Dictionary = RECIPES.get(area.area_id, {})
	var t := area.terrain
	if rec.is_empty() or t == null or not def.has("nav_bounds"):
		return 0
	var nb: Array = def["nav_bounds"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(area.area_id + "|wayside")
	# where the Bearer goes: the start, hearths, foes, things to pick up or read
	var anchors: Array = []
	var st0: Array = def.get("start", {}).get("pos", [])
	if st0.size() >= 3:
		anchors.append(Vector3(float(st0[0]), float(st0[1]), float(st0[2])))
	for key in ["hearths", "spawners", "pickups", "plaques", "npcs", "frost_veils"]:
		for sp in def.get(key, []):
			var at: Array = sp.get("at", [])
			if at.size() >= 3:
				anchors.append(Vector3(float(at[0]), float(at[1]), float(at[2])))
	var warden := area.get_node_or_null("TrapWarden") as TrapWarden
	var n := 0
	var step := float(FINE.get(area.area_id, STEP))
	var jit := step * 0.34
	var y_max := minf(float(nb[4]), float(Y_MAX.get(area.area_id, 1e9)))
	var x := float(nb[0]) + step * 0.5
	while x < float(nb[3]):
		var z := float(nb[2]) + step * 0.5
		while z < float(nb[5]):
			var p := Vector3(x + rng.randf_range(-jit, jit), 0, z + rng.randf_range(-jit, jit))
			z += step
			var roll := rng.randf()
			var kind := _pick(rec, rng)
			if roll > 0.88 or not t.contains(p.x, p.z):
				_why("roll"); continue
			p.y = t.height_at(p.x, p.z)
			if p.y < float(nb[1]) or p.y > y_max:
				_why("height"); continue
			var shingle := t.splat_at(p.x, p.z, 0)
			# boats lie on the shingle and nowhere else; racks and stacks may
			# stand there too, stones and cairns keep to the turf
			if (kind == "boat" and shingle <= 0.4) or (shingle > 0.4 and not (kind in ["boat", "racks", "stacks"])):
				_why("shingle"); continue
			if not _near_play(anchors, p):
				_why("far"); continue
			if not _level(t, p, 3.2, float(TRODDEN.get(area.area_id, 0.4))):
				_why("level"); continue
			if not _free(def, p, 3.5):
				_why("taken"); continue
			if n >= MAX_GROUPS or _in_thicket(def, p, 3.0):
				_why("thicket"); continue
			if warden != null and (warden.is_trap(p, "thaw") or warden.is_trap(p, "rime")):
				continue
			_group(area, t, kind, p, rng)
			if "--house-stats" in OS.get_cmdline_user_args():
				print("[wayside]   %s at %s" % [kind, p.snapped(Vector3.ONE * 0.1)])
			n += 1
		x += step
	# second pass: something within a short walk of every hearth and every
	# thing to read or pick up. Narrow regions (a fjord shore, a hall's
	# island, a mountain path) have no room on the grid above.
	var seeds: Array = []
	for key in ["hearths", "plaques", "pickups"]:
		for sp in def.get(key, []):
			var at: Array = sp.get("at", [])
			if at.size() >= 3:
				seeds.append(Vector3(float(at[0]), float(at[1]), float(at[2])))
	var put: Array = []
	for sd in seeds:
		var s0: Vector3 = sd
		var done := 0
		for attempt in 40:
			if done >= 2 or n >= MAX_GROUPS:
				break
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(6.5, 17.0)
			var p := Vector3(s0.x + cos(ang) * dist, 0, s0.z + sin(ang) * dist)
			if not t.contains(p.x, p.z):
				continue
			p.y = t.height_at(p.x, p.z)
			if absf(p.y - s0.y) > (5.0 if attempt >= 20 else 2.5) or p.y > y_max:
				_why("2:height"); continue
			var shingle := t.splat_at(p.x, p.z, 0)
			var kind := _pick(rec, rng)
			# tight ground: after twenty tries for a group, a single piece will do
			var small := attempt >= 20
			if small:
				kind = ["creel", "coil", "creel"][rng.randi() % 3] if shingle > 0.4 else ["cairn", "stone1", "pile1", "cask"][rng.randi() % 4]
			elif (kind == "boat" and shingle <= 0.4) or (shingle > 0.4 and not (kind in ["boat", "racks", "stacks"])):
				continue
			var crowded := false
			for q in put:
				if (q as Vector3).distance_to(p) < 9.0:
					crowded = true
			if crowded:
				_why("2:crowded"); continue
			if (small and not _stands(t, p)) or (not small and not _level(t, p, 2.6, 0.92)):
				_why("2:level"); continue
			if not _free(def, p, 1.4 if small else 2.8, 0.45 if small else 1.0):
				_why("2:taken"); continue
			if _in_thicket(def, p, 2.5):
				_why("2:thicket"); continue
			if warden != null and (warden.is_trap(p, "thaw") or warden.is_trap(p, "rime")):
				continue
			_group(area, t, kind, p, rng)
			if "--house-stats" in OS.get_cmdline_user_args():
				print("[wayside]   %s at %s (by a hearth or find)" % [kind, p.snapped(Vector3.ONE * 0.1)])
			put.append(p)
			done += 1
			n += 1
	n += _decks(area, t, def, rng)
	if "--house-stats" in OS.get_cmdline_user_args():
		print("[wayside] %s rejected: %s" % [area.area_id, str(_whys)])
	_whys.clear()
	return n

## Working gear on jetties and decks (the Kettle stands on them, not on land):
## a creel stack, a coil and a cask, a barrel, set near a deck's edge on top
## of the boards. Decks are the area's wide flat timber boxes that collide.
static func _decks(area: Area, t: Terrain, def: Dictionary, rng: RandomNumberGenerator) -> int:
	var n := 0
	var put: Array = []
	for b in def.get("boxes", []):
		if not (String(b.get("mat", "")) in ["M_wood", "M_planks"]) or not b.get("collide", true) or String(b.get("tag", "base")) != "base":
			continue
		var mn: Array = b["min"]
		var mx: Array = b["max"]
		var sx := float(mx[0]) - float(mn[0])
		var sz := float(mx[2]) - float(mn[2])
		if float(mx[1]) - float(mn[1]) > 0.6 or minf(sx, sz) < 2.2 or maxf(sx, sz) < 5.0:
			continue
		var top := float(mx[1])
		# decks only: timber well clear of the land under it, or over water
		var mid := Vector3((float(mn[0]) + float(mx[0])) * 0.5, top, (float(mn[2]) + float(mx[2])) * 0.5)
		if t.contains(mid.x, mid.z) and t.height_at(mid.x, mid.z) > top - 0.4:
			continue
		var want := clampi(int(sx * sz / 45.0) + 1, 1, 3)
		for attempt in 14:
			if want <= 0 or n >= 18:
				break
			# against one long edge, clear of the ends
			var along_x := sx >= sz
			var p := mid
			if along_x:
				p.x = rng.randf_range(float(mn[0]) + 1.2, float(mx[0]) - 1.2)
				p.z = (float(mn[2]) + 0.7) if rng.randf() < 0.5 else (float(mx[2]) - 0.7)
			else:
				p.z = rng.randf_range(float(mn[2]) + 1.2, float(mx[2]) - 1.2)
				p.x = (float(mn[0]) + 0.7) if rng.randf() < 0.5 else (float(mx[0]) - 0.7)
			var ok := true
			for q in put:
				if (q as Vector3).distance_to(p) < 3.5:
					ok = false
			for key in KEEP_OUT:
				for sp in def.get(key, []):
					var at: Array = sp.get("at", [])
					if at.size() >= 3 and absf(float(at[1]) - top) < 3.0 and Vector2(p.x - float(at[0]), p.z - float(at[2])).length() < 1.2 + float(KEEP_OUT[key]) * 0.6:
						ok = false
			for h in def.get("houses", []):
				var c := Vector2(float(h["center"][0]), float(h["center"][1]))
				if Vector2(p.x, p.z).distance_to(c) < maxf(float(h["size"][0]), float(h["size"][1])) * 0.5 + 1.6:
					ok = false
			if not ok:
				continue
			var kind: String = ["creel_stack", "barrel", "rope_coil", "crate"][rng.randi() % 4]
			_kit(area, t, kind, p, rng.randf() * 360.0, top)
			if kind != "creel_stack" and rng.randf() < 0.5:
				var q2 := p + (Vector3(0.95, 0, 0) if along_x else Vector3(0, 0, 0.95))
				_kit(area, t, "barrel" if kind != "barrel" else "rope_coil", q2, rng.randf() * 360.0, top)
			put.append(p)
			want -= 1
			n += 1
	return n

static var _whys := {}
static func _why(k: String) -> void:
	_whys[k] = int(_whys.get(k, 0)) + 1

static func _pick(rec: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in rec:
		total += int(rec[k])
	var r := rng.randi() % maxi(total, 1)
	for k in rec:
		r -= int(rec[k])
		if r < 0:
			return String(k)
	return String(rec.keys()[0])

## Ground a single piece can stand on: not a cliff, not in the water's edge.
static func _stands(t: Terrain, p: Vector3) -> bool:
	return t.normal_at(p.x, p.z).y >= 0.8 and t.splat_at(p.x, p.z, 2) < 0.7 and t.splat_at(p.x, p.z, 1) < 0.92

## Level, dry, and off the worn road.
static func _level(t: Terrain, p: Vector3, r: float, path_max := 0.4, flat := 0.95) -> bool:
	if t.normal_at(p.x, p.z).y < flat or t.splat_at(p.x, p.z, 2) > 0.3:
		return false
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if absf(t.height_at(p.x + o.x, p.z + o.y) - p.y) > 0.7 or t.splat_at(p.x + o.x, p.z + o.y, 1) > path_max:
			return false
	return true

## Within sight and on a level with somewhere the Bearer goes: not on a cliff
## top or a far shore he will never stand on.
static func _near_play(anchors: Array, p: Vector3) -> bool:
	for a in anchors:
		var q: Vector3 = a
		if absf(q.y - p.y) < 5.0 and Vector2(q.x - p.x, q.z - p.z).length() < 42.0:
			return true
	return false

## Inside a declared thicket or hedge (either state), or within r of its edge.
static func _in_thicket(def: Dictionary, p: Vector3, r: float) -> bool:
	for th in def.get("edges", {}).get("thickets", []):
		var poly: Array = th.get("poly", [])
		for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
			var x: float = p.x + o.x
			var z: float = p.z + o.y
			var inside := false
			for k in poly.size():
				var a: Array = poly[k]
				var b: Array = poly[(k + 1) % poly.size()]
				if (float(a[1]) > z) != (float(b[1]) > z) and x < float(a[0]) + (z - float(a[1])) / (float(b[1]) - float(a[1])) * (float(b[0]) - float(a[0])):
					inside = not inside
			if inside:
				return true
	return false

## ks scales the keep-out radii: a single small prop may stand closer.
static func _free(def: Dictionary, p: Vector3, r: float, ks := 1.0) -> bool:
	for key in KEEP_OUT:
		for sp in def.get(key, []):
			var at: Array = sp.get("at", [])
			if at.size() >= 3 and Vector2(p.x - float(at[0]), p.z - float(at[2])).length() < r + float(KEEP_OUT[key]) * ks:
				return false
	var st: Array = def.get("start", {}).get("pos", [])
	if st.size() >= 3 and Vector2(p.x - float(st[0]), p.z - float(st[2])).length() < r + 9.0:
		return false
	for key in ["boxes", "hazards", "blockers"]:
		for b in def.get(key, []):
			if not (b.has("min") and b.has("max")):
				continue
			var mn: Array = b["min"]
			var mx: Array = b["max"]
			if maxf(float(mx[0]) - float(mn[0]), float(mx[2]) - float(mn[2])) > 60.0 and key == "boxes":
				continue        # ice sheets and floors under everything
			# these are volumes: only one that reaches this ground counts (an ice
			# sheet's blocker lies under the shore), and a "fall" volume is
			# ground you may stand on
			if p.y + 0.5 < float(mn[1]) or p.y - 1.0 > float(mx[1]):
				continue
			if key == "hazards" and String(b.get("kind", "fall")) == "fall":
				continue
			if p.x > float(mn[0]) - r - 2.0 and p.x < float(mx[0]) + r + 2.0 and p.z > float(mn[2]) - r - 2.0 and p.z < float(mx[2]) + r + 2.0:
				return false
	# a house's footprint and the yard round it (HouseYard dresses that)
	for h in def.get("houses", []):
		var c := Vector2(float(h["center"][0]), float(h["center"][1]))
		var ha := deg_to_rad(float(h.get("yaw", 0.0)))
		var dd := Vector2(p.x, p.z) - c
		var lx := dd.x * cos(ha) - dd.y * sin(ha)
		var lz := dd.x * sin(ha) + dd.y * cos(ha)
		if absf(lx) < float(h["size"][0]) * 0.5 + r + 3.5 and absf(lz) < float(h["size"][1]) * 0.5 + r + 3.5:
			return false
	# water: only where this ground is at the water's level
	for w in def.get("water", []):
		var wa: Array = w.get("at", [])
		if wa.size() < 3 or p.y > float(wa[1]) + 0.9:
			continue
		if w.has("size"):
			var ws: Array = w["size"]
			if absf(p.x - float(wa[0])) < float(ws[0]) * 0.5 + r and absf(p.z - float(wa[2])) < float(ws[1]) * 0.5 + r:
				return false
		elif Vector2(p.x - float(wa[0]), p.z - float(wa[2])).length() < r + float(w.get("radius", 6.0)) + 2.0:
			return false
	return true

static func _group(area: Area, t: Terrain, kind: String, p: Vector3, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf() * 360.0
	var fwd := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
	var side := Vector3(-fwd.z, 0, fwd.x)
	match kind:
		"cairn":
			_landmark(area, t, "lm_fold_cairn.glb", p, yaw, rng.randf_range(0.8, 1.15), 0.0)
		"stones":
			var cnt := rng.randi_range(3, 5)
			var bend := rng.randf_range(-0.12, 0.12)
			for i in cnt:
				var k := float(i) - float(cnt - 1) * 0.5
				var q := p + fwd * k * 2.6 + side * bend * k * k
				_landmark(area, t, "lm_standing_stone.glb", q, rng.randf() * 360.0, rng.randf_range(0.7, 1.2), rng.randf_range(-7.0, 7.0))
		"sledge":
			_landmark(area, t, "lm_sledge.glb", p, yaw, 1.0, 0.0)
			_kit(area, t, "woodpile", p + side * 2.3 + fwd * rng.randf_range(-0.6, 0.6), yaw + rng.randf_range(-12, 12))
			_kit(area, t, "barrel", p - side * 1.8 + fwd * 1.0, rng.randf() * 360.0)
		"racks":
			var cnt := rng.randi_range(2, 3)
			for i in cnt:
				_kit(area, t, "drying_rack", p + side * (float(i) - float(cnt - 1) * 0.5) * 2.6, yaw + rng.randf_range(-5, 5))
			_kit(area, t, "creel_stack", p + fwd * 3.0 + side * rng.randf_range(-1.5, 1.5), rng.randf() * 360.0)
		"boat":
			_kit(area, t, "boat_upturned", p, yaw)
			_kit(area, t, "rope_coil", p + side * 2.2 + fwd * 1.2, rng.randf() * 360.0)
			_kit(area, t, "creel_stack", p - side * 2.4 - fwd * 0.8, rng.randf() * 360.0)
		"stone1":
			_landmark(area, t, "lm_standing_stone.glb", p, yaw, rng.randf_range(0.75, 1.1), rng.randf_range(-6.0, 6.0))
		"pile1":
			_kit(area, t, "woodpile", p, yaw)
		"cask":
			_kit(area, t, "barrel", p, yaw)
			_kit(area, t, "crate", p + side * 1.0, yaw + rng.randf_range(-25, 25))
		"creel":
			_kit(area, t, "creel_stack", p, yaw)
		"coil":
			_kit(area, t, "rope_coil", p, yaw)
			_kit(area, t, "barrel", p + side * 0.95, yaw)
		_:
			_kit(area, t, "woodpile", p, yaw)
			_kit(area, t, "woodpile", p + side * 1.5 + fwd * 0.3, yaw + rng.randf_range(-8, 8))
			_kit(area, t, "crate", p - side * 1.9, yaw + rng.randf_range(-20, 20))
			_kit(area, t, "bench_3m", p + fwd * 2.4, yaw + 90.0)

static func _kit(area: Area, t: Terrain, kit: String, p: Vector3, yaw: float, y := INF) -> void:
	AreaBuilder._piece(area, {"kit": kit, "at": [p.x, t.height_at(p.x, p.z) if y == INF else y, p.z], "rot": yaw, "tag": "base"}, true)

## A Tripo landmark set on the ground with a box collider fitted to it.
static func _landmark(area: Area, t: Terrain, file: String, p: Vector3, yaw: float, sc: float, tilt: float) -> void:
	var lm := BuildingGen._landmark(LM + file)
	if lm == null:
		return
	var bb := AABB()
	var first := true
	for c in lm.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := mi.transform * mi.mesh.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	var y := t.height_at(p.x, p.z)
	lm.position = Vector3(p.x, y - bb.position.y * sc - 0.06, p.z)
	lm.rotation_degrees = Vector3(tilt, yaw, 0.0)
	lm.scale = Vector3.ONE * sc
	area.attach(lm, "base")
	if first:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = bb.size * sc * Vector3(0.8, 1.0, 0.8)
	cs.shape = bx
	body.add_child(cs)
	body.position = Vector3(p.x, y + bx.size.y * 0.5, p.z)
	body.rotation_degrees.y = yaw
	area.attach(body, "base")
