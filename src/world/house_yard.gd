class_name HouseYard
## The working clutter round a house (docs/art/WORLD_FIDELITY.md, "Yards"):
## woodpiles under the eaves, a bench by the door, barrels, crates, sacks,
## rope and creels by the sheds. Every piece is one of KitLib's modelled
## props placed through AreaBuilder._piece, so it collides, takes the
## THAW/RIME shading and drops out by size like any authored prop.
## Slots run along each closed wall. A slot is skipped near a door or a
## corner, where the area already put something, where another house stands,
## and where the ground is not level with the floor (decks, ledges). What
## goes in a slot depends on the kind of house, so a hall, a store, a byre
## and a boat-shed each read differently. Seeded per house: always the same.

## kit id -> [length along the wall, depth out from it]
const SIZE := {"woodpile": [2.0, 0.8], "bench_3m": [2.7, 0.45], "barrel": [0.75, 0.75], "crate": [1.0, 1.0],
	"rye_sack": [0.9, 0.5], "rope_coil": [0.8, 0.8], "creel_stack": [1.4, 0.9]}
## what a kind of house keeps outside, most characteristic first
const KEEPS := {
	"hall": ["woodpile", "barrel", "bench_3m", "crate", "barrel", "woodpile", "rye_sack"],
	"store": ["barrel", "crate", "rye_sack", "barrel", "crate"],
	"byre": ["woodpile", "barrel", "crate", "woodpile"],
	"shed": ["creel_stack", "rope_coil", "barrel", "creel_stack", "rope_coil"],
	"fish": ["creel_stack", "barrel", "rope_coil"],
}
const KEEP_OUT := {"spawners": 3.2, "hearths": 3.6, "portals": 4.5, "gates": 3.5, "npcs": 2.6, "pickups": 2.2,
	"plaques": 2.2, "props": 1.9, "pieces": 1.9, "landmarks": 3.0, "frost_veils": 4.5}

static func build(area: Area, hd: HouseDetail, tag: String) -> int:
	if area.terrain == null:
		return 0
	var def := hd.area_def
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hd.id + "|yard")
	var keeps: Array = KEEPS.get(hd.style, KEEPS["store"])
	var placed: Array = []      # world xz + radius of what this yard has put down
	var n := 0
	var ki := rng.randi() % keeps.size()
	var sides: Array = ["W", "E", "N", "S"]
	for side in sides:
		if side in hd.opens:
			continue
		var sx := hd.side_xf(side)
		var span := hd.side_span(side)
		var t := -span * 0.5 + 0.9 + rng.randf() * 0.8
		while t < span * 0.5 - 0.9:
			var kit := String(keeps[ki % keeps.size()])
			var sz: Array = SIZE[kit]
			var half := float(sz[0]) * 0.5
			var tc := t + half
			var step := float(sz[0]) + rng.randf_range(0.5, 2.6)
			# leave gaps: a yard is used, not stocked
			if rng.randf() < 0.42 or tc + half > span * 0.5 - 0.5:
				t += step * 0.6
				continue
			var near_door := false
			for d in hd.doors:
				if String(d["side"]) == side and absf(float(d["t"]) - tc) < HouseDetail.DOOR_W * 0.5 + half + 1.5:
					near_door = true
			var out := 0.62 + float(sz[1]) * 0.5
			var wp := hd.world_of(sx * Vector3(tc, 0, out))
			wp.y = area.terrain.height_at(wp.x, wp.z)
			if near_door or not _clear(def, hd, area, wp, half + 0.3, placed):
				t += 1.0
				continue
			var ax := Basis(Vector3.UP, hd.yaw) * sx.basis.x
			var rot := rad_to_deg(atan2(-ax.z, ax.x)) + rng.randf_range(-7.0, 7.0)
			if kit == "barrel" or kit == "rope_coil":
				rot = rng.randf() * 360.0
			AreaBuilder._piece(area, {"kit": kit, "at": [wp.x, wp.y, wp.z], "rot": rot, "tag": tag}, true)
			placed.append(Vector3(wp.x, wp.z, half + 0.2))
			n += 1
			ki += 1
			# barrels and sacks come in twos and threes
			if (kit == "barrel" or kit == "rye_sack") and rng.randf() < 0.6:
				var wp2 := hd.world_of(sx * Vector3(tc + float(sz[0]) + 0.08, 0, out + rng.randf_range(-0.08, 0.12)))
				wp2.y = area.terrain.height_at(wp2.x, wp2.z)
				if _clear(def, hd, area, wp2, half + 0.1, []):
					AreaBuilder._piece(area, {"kit": kit, "at": [wp2.x, wp2.y, wp2.z], "rot": rng.randf() * 360.0, "tag": tag}, true)
					placed.append(Vector3(wp2.x, wp2.z, half + 0.2))
					n += 1
					step += float(sz[0])
			t += step
	return n

static func _clear(def: Dictionary, hd: HouseDetail, area: Area, wp: Vector3, r: float, placed: Array) -> bool:
	# level with the floor: not on a deck's edge, a ledge or a bank
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		var gy := area.terrain.height_at(wp.x + o.x, wp.z + o.y)
		if absf(gy - hd.origin.y) > 0.3:
			return false
	for p in placed:
		if Vector2(wp.x - p.x, wp.z - p.y).length() < r + p.z:
			return false
	for key in KEEP_OUT:
		for sp in def.get(key, []):
			var at: Array = sp.get("at", [])
			if at.size() >= 3 and Vector2(wp.x - float(at[0]), wp.z - float(at[2])).length() < r + float(KEEP_OUT[key]):
				return false
	var st: Array = def.get("start", {}).get("pos", [])
	if st.size() >= 3 and Vector2(wp.x - float(st[0]), wp.z - float(st[2])).length() < r + 3.0:
		return false
	# boxes the area authored (floors aside), and other houses
	for b in def.get("boxes", []):
		var mn: Array = b["min"]
		var mx: Array = b["max"]
		if float(mx[1]) < hd.origin.y + 0.2 or float(mn[1]) > hd.origin.y + 2.5:
			continue
		if wp.x > float(mn[0]) - r and wp.x < float(mx[0]) + r and wp.z > float(mn[2]) - r and wp.z < float(mx[2]) + r:
			return false
	for h in def.get("houses", []):
		if String(h.get("id", "")) == hd.id:
			continue
		var c := Vector2(float(h["center"][0]), float(h["center"][1]))
		if Vector2(wp.x, wp.z).distance_to(c) < maxf(float(h["size"][0]), float(h["size"][1])) * 0.75 + r + 1.0:
			return false
	return true
