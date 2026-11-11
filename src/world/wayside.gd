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

const STEP := 27.0
const RECIPES := {
	"saltfell_steading": {"cairn": 2, "stones": 1, "racks": 2, "boat": 3, "sledge": 2, "stacks": 1},
	"lowe_barrows": {"stones": 4, "cairn": 3, "sledge": 1},
	"kettle_fjord": {"racks": 3, "boat": 2, "cairn": 1, "stacks": 1},
	"tarnhall": {"sledge": 2, "stacks": 2, "cairn": 2, "stones": 1},
	"shepherds_reach": {"cairn": 3, "stones": 3, "sledge": 1},
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
	var warden := area.get_node_or_null("TrapWarden") as TrapWarden
	var n := 0
	var x := float(nb[0]) + STEP * 0.5
	while x < float(nb[3]):
		var z := float(nb[2]) + STEP * 0.5
		while z < float(nb[5]):
			var p := Vector3(x + rng.randf_range(-9.0, 9.0), 0, z + rng.randf_range(-9.0, 9.0))
			z += STEP
			var roll := rng.randf()
			var kind := _pick(rec, rng)
			if roll > 0.8 or not t.contains(p.x, p.z):
				continue
			p.y = t.height_at(p.x, p.z)
			if p.y < float(nb[1]) or p.y > float(nb[4]):
				continue
			var shingle := t.splat_at(p.x, p.z, 0)
			# boats lie on the shingle and nowhere else; racks and stacks may
			# stand there too, stones and cairns keep to the turf
			if (kind == "boat" and shingle <= 0.4) or (shingle > 0.4 and not (kind in ["boat", "racks", "stacks"])):
				continue
			if not _level(t, p, 3.2) or not _free(def, p, 3.5):
				continue
			if warden != null and (warden.is_trap(p, "thaw") or warden.is_trap(p, "rime")):
				continue
			_group(area, t, kind, p, rng)
			if "--house-stats" in OS.get_cmdline_user_args():
				print("[wayside]   %s at %s" % [kind, p.snapped(Vector3.ONE * 0.1)])
			n += 1
		x += STEP
	return n

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

## Level, dry, and off the worn road.
static func _level(t: Terrain, p: Vector3, r: float) -> bool:
	if t.normal_at(p.x, p.z).y < 0.965 or t.splat_at(p.x, p.z, 2) > 0.3:
		return false
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if absf(t.height_at(p.x + o.x, p.z + o.y) - p.y) > 0.55 or t.splat_at(p.x + o.x, p.z + o.y, 1) > 0.22:
			return false
	return true

static func _free(def: Dictionary, p: Vector3, r: float) -> bool:
	for key in KEEP_OUT:
		for sp in def.get(key, []):
			var at: Array = sp.get("at", [])
			if at.size() >= 3 and Vector2(p.x - float(at[0]), p.z - float(at[2])).length() < r + float(KEEP_OUT[key]):
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
			if key == "hazards":
				# a hazard is a volume: only one that reaches this ground counts,
				# and a "fall" volume is ground you may stand on
				if String(b.get("kind", "fall")) == "fall" or p.y + 0.5 < float(mn[1]) or p.y - 1.0 > float(mx[1]):
					continue
			if p.x > float(mn[0]) - r - 2.0 and p.x < float(mx[0]) + r + 2.0 and p.z > float(mn[2]) - r - 2.0 and p.z < float(mx[2]) + r + 2.0:
				return false
	for h in def.get("houses", []):
		var c := Vector2(float(h["center"][0]), float(h["center"][1]))
		if Vector2(p.x, p.z).distance_to(c) < maxf(float(h["size"][0]), float(h["size"][1])) * 0.75 + r + 7.0:
			return false
	for w in def.get("water", []):
		var wa: Array = w.get("at", [])
		if wa.size() >= 3 and Vector2(p.x - float(wa[0]), p.z - float(wa[2])).length() < r + float(w.get("radius", 6.0)) + 2.0:
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
		_:
			_kit(area, t, "woodpile", p, yaw)
			_kit(area, t, "woodpile", p + side * 1.5 + fwd * 0.3, yaw + rng.randf_range(-8, 8))
			_kit(area, t, "crate", p - side * 1.9, yaw + rng.randf_range(-20, 20))
			_kit(area, t, "bench_3m", p + fwd * 2.4, yaw + 90.0)

static func _kit(area: Area, t: Terrain, kit: String, p: Vector3, yaw: float) -> void:
	AreaBuilder._piece(area, {"kit": kit, "at": [p.x, t.height_at(p.x, p.z), p.z], "rot": yaw, "tag": "base"}, true)

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
