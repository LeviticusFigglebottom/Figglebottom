class_name AreaBuilder
## Compiles data/areas/<id>.json into a live Area (DECISIONS D-007).
## Constructs: pieces, rows, fills, vault fields, props, and the entity
## lists (hearths, gates, frost veils, spawners, npcs, plaques, pickups,
## portals, cameos). Everything carries a state tag: base | thaw | rime.

static func build(area_id: String) -> Area:
	var def := DB.area_def(area_id)
	if def.is_empty():
		push_error("AreaBuilder: no def for area '%s'" % area_id)
		return null
	var area := Area.new()
	area.area_id = area_id
	area.name = "Area_" + area_id
	area.display_name = def.get("name", area_id)
	area.set_meta("def", def)

	area.env.set_overrides(def.get("env", {}))
	# the land first: buildings sit on it, they are not it (ADR 0003)
	if def.has("terrain"):
		var t := Terrain.new()
		if t.setup(def["terrain"]):
			area.base.add_child(t)
			t.build(RH.L_WORLD_BASE)
			area.terrain = t
	if def.has("nav_bounds"):
		var nb: Array = def["nav_bounds"]
		area.nav_aabb = AABB(Vector3(nb[0], nb[1], nb[2]), Vector3(nb[3] - nb[0], nb[4] - nb[1], nb[5] - nb[2]))
	for spec in def.get("water", []):
		_water(area, spec)
	for spec in def.get("hazards", []):
		var hz := HazardVolume.new()
		hz.kind = String(spec.get("kind", "fall"))
		var hmn := _v3(spec["min"])
		var hmx := _v3(spec["max"])
		hz.size = hmx - hmn
		hz.position = (hmn + hmx) * 0.5
		hz.name = "Hazard_" + hz.kind
		area.attach(hz, spec.get("tag", "base"))
	for spec in def.get("houses", []):
		if _flag_ok(spec):
			BuildingGen.build(area, spec)
	for spec in def.get("fills", []):
		_fill(area, spec)
	for spec in def.get("rows", []):
		_row(area, spec)
	for spec in def.get("pieces", []):
		_piece(area, spec, true)
	for spec in def.get("props", []):
		_piece(area, spec, _prop_collides(spec))
	for spec in def.get("skyline", []):
		var sk: Dictionary = spec.duplicate()
		sk["flames"] = false
		sk["collide"] = false
		_piece(area, sk, false)
	for spec in def.get("vault_fields", []):
		_vault_field(area, spec)
	for spec in def.get("blockers", []):
		if not _flag_ok(spec):
			continue    # a blocked way may open when the story turns
		_blocker(area, spec)
	for spec in def.get("boxes", []):
		_solid_box(area, spec)

	for spec in def.get("hearths", []):
		var l := Hearthstone.new()
		l.hearth_id = spec.get("id", "hearth")
		l.display_name = spec.get("name", "Hearthstone")
		l.area = area
		area.base.add_child(l)
		_place(l, spec)
	for spec in def.get("gates", []):
		var g := ShortcutGate.new()
		g.gate_id = spec.get("id", "gate")
		g.area_id = area_id
		g.locked_prompt = spec.get("locked_prompt", "Barred from the other side")
		g.door_width = float(spec.get("width", 3.6))
		area.base.add_child(g)
		_place(g, spec)
	for spec in def.get("spawners", []):
		var s := Spawner.new()
		s.enemy_id = spec.get("enemy", "rimewalker")
		s.face_deg = float(spec.get("face", 0))
		s.dead_once = spec.get("dead_once", false)
		s.spawn_flag = "slain_" + spec.get("id", spec.get("enemy", "e"))
		s.area_id = area_id
		var tag: String = spec.get("tag", "rime")
		area.attach(s, tag)
		_place(s, spec)
		if spec.has("frost_veil_id"):
			s.set_meta("frost_veil_id", spec["frost_veil_id"])
	for spec in def.get("frost_veils", []):
		var f := FrostVeil.new()
		f.gate_id = spec.get("id", "fog")
		f.area_id = area_id
		f.aux_seal_specs = spec.get("seals", [])
		var fg_pos := _v3(spec.get("at", [0, 0, 0]))
		for pc in def.get("pieces", []):
			var pk := String(pc.get("kit", ""))
			if pk in ["portal_4m", "arch_4m", "frost_veil_frame"]:
				var pp := _v3(pc.get("at", [0, 0, 0]))
				if Vector2(fg_pos.x - pp.x, fg_pos.z - pp.z).length() < 0.5 and absf(fg_pos.y - pp.y) < 0.5:
					f.has_frame = false
					if pk != "frost_veil_frame":
						f.plane_size = Vector2(2.05, 3.88)
					break
		area.attach(f, spec.get("tag", "rime"))
		_place(f, spec)
		# bind its boss spawner
		for s in _all_spawners(area):
			if String(s.get_meta("frost_veil_id", "")) == f.gate_id:
				f.boss_spawner = s
		# a slain holdfast stays slain: rebuilt areas must not re-arm the veil
		if World.is_cleared(area_id) or (f.boss_spawner != null
				and f.boss_spawner.dead_once
				and World.area_flag(area_id, f.boss_spawner.spawn_flag)):
			f.snap_cleared()
	for spec in def.get("npcs", []):
		if not _flag_ok(spec):
			continue      # a soul may stand only before/after a turn of the story
		var n := NPC.new()
		n.npc_id = spec.get("id", "")
		n.set_meta("state_tag", spec.get("tag", "thaw"))
		area.attach(n, spec.get("tag", "thaw"))
		_place(n, spec)
	for spec in def.get("plaques", []):
		if not _flag_ok(spec):
			continue
		var p := LorePlaque.new()
		p.text = spec.get("text", "…")
		p.set_flag = spec.get("set_flag", "")
		p.flag_toast = spec.get("flag_toast", "")
		p.style = spec.get("style", "plaque")
		area.attach(p, spec.get("tag", "base"))
		_place(p, spec)
	for spec in def.get("scripted", []):
		if not _flag_ok(spec):
			continue
		var sn: Node3D = load(spec["script"]).new()
		for k in spec.get("params", {}):
			sn.set(k, spec["params"][k])
		area.attach(sn, spec.get("tag", "base"))
		_place(sn, spec)
	for spec in def.get("pickups", []):
		if not _flag_ok(spec):
			continue    # quest relics stay unseen until their word is given
		var k := Pickup.new()
		k.pickup_id = spec.get("id", "pickup")
		k.area_id = area_id
		k.warmth = int(spec.get("warmth", 0))
		k.item_id = spec.get("item", "")
		k.item_count = int(spec.get("count", 1))
		k.label = spec.get("label", "Take")
		k.appear_flag = spec.get("appear_flag", "")
		k.display_kit = spec.get("kit", "")
		area.attach(k, spec.get("tag", "base"))
		_place(k, spec)
	for spec in def.get("flag_gates", []):
		var fgate := FlagGate.new()
		var gtag: String = spec.get("tag", "base")
		area.attach(fgate, gtag)
		_place(fgate, spec)
		fgate.setup(spec, _tag_bit(gtag))
	for spec in def.get("portals", []):
		var pt := AreaPortal.new()
		pt.to_area = spec.get("to", "")
		pt.spawn_pos = _v3(spec.get("spawn", [0, 0, 0]))
		if spec.has("spawn_yaw"):
			pt.spawn_yaw = float(spec["spawn_yaw"])
		pt.prompt = spec.get("prompt", "Pass on")
		pt.locked_flag = spec.get("locked_flag", "")
		pt.locked_prompt = spec.get("locked_prompt", "Sealed")
		pt.requires_items = spec.get("requires_items", [])
		pt.cutscene = spec.get("cutscene", "")
		area.attach(pt, spec.get("tag", "base"))
		_place(pt, spec)

	if def.has("zones"):
		var zt := ZoneTitles.new()
		zt.name = "ZoneTitles"
		zt.zones = def["zones"]
		area.add_child(zt)
	if area.terrain != null and def.has("scatter"):
		Scatter.build(area, area.terrain, def["scatter"], _keep_clear(def))

	_mark_indoors(area, def.get("houses", []))

	# ambient mood: gold motes in thaw, ash in rime, sized to the area
	var ext := _extent(def)
	area.add_ambient(ext[0], ext[1])

	area.bake_navmeshes.call_deferred()
	return area

## Snow settles on what faces the sky, but not under a roof: everything
## standing inside a house footprint (below its eaves) is masked indoor.
static func _mark_indoors(area: Area, houses: Array) -> void:
	if houses.is_empty():
		return
	var stack: Array[Node] = [area]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Terrain or String(n.name).begins_with("House_") or n is MultiMeshInstance3D:
			continue
		if n is GeometryInstance3D:
			# the area is not in the tree yet: walk the transforms up by hand
			var p := Vector3.ZERO
			var cur: Node = n
			while cur != area and cur is Node3D:
				p = (cur as Node3D).transform * p
				cur = cur.get_parent()
			for hs in houses:
				var c := Vector2(float(hs["center"][0]), float(hs["center"][1]))
				var a := deg_to_rad(float(hs.get("yaw", 0.0)))
				var d := Vector2(p.x, p.z) - c
				var lx := d.x * cos(a) - d.y * sin(a)
				var lz := d.x * sin(a) + d.y * cos(a)
				var y0 := float(hs.get("y", 0.0))
				if absf(lx) < float(hs["size"][0]) * 0.5 and absf(lz) < float(hs["size"][1]) * 0.5 \
						and p.y > y0 - 0.5 and p.y < y0 + float(hs.get("wall_h", 3.2)):
					(n as GeometryInstance3D).set_instance_shader_parameter("indoor", 1.0)
					break
		for ch in n.get_children():
			stack.append(ch)

## Scatter never lands on anything a player must reach or read.
static func _keep_clear(def: Dictionary) -> Array:
	var out: Array = []
	var radii := {"hearths": 3.5, "spawners": 2.0, "npcs": 2.5, "pickups": 1.8, "gates": 3.5,
		"frost_veils": 4.5, "plaques": 1.8, "portals": 3.0}
	for key in radii:
		for spec in def.get(key, []):
			var p := _v3(spec.get("at", [0, 0, 0]))
			out.append(Vector3(p.x, p.z, radii[key]))
	var st := _v3(def.get("start", {}).get("pos", [0, 0, 0]))
	out.append(Vector3(st.x, st.z, 3.0))
	return out

## Sea, river and pool planes on the existing water shader.
static func _water(area: Area, spec: Dictionary) -> void:
	var tag: String = spec.get("tag", "base")
	var mi := MeshInstance3D.new()
	mi.name = "Water"
	var pm := PlaneMesh.new()
	var sz: Array = spec.get("size", [100, 100])
	pm.size = Vector2(float(sz[0]), float(sz[1]))
	mi.mesh = pm
	mi.material_override = MaterialLib.get_mat("M_water", _state_mode(tag))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = _v3(spec.get("at", [0, 0, 0]))
	area.attach(mi, tag)

static func _extent(def: Dictionary) -> Array:
	if def.has("nav_bounds"):
		var nb: Array = def["nav_bounds"]
		return [Vector3(nb[0], 0, nb[2]), Vector3(nb[3], 0, nb[5])]
	var mn := Vector3(1e9, 0, 1e9)
	var mx := Vector3(-1e9, 0, -1e9)
	for spec in def.get("fills", []):
		var a := _v3(spec["min"])
		var b := _v3(spec["max"])
		mn.x = minf(mn.x, a.x); mn.z = minf(mn.z, a.z)
		mx.x = maxf(mx.x, b.x); mx.z = maxf(mx.z, b.z)
	if mn.x > mx.x:
		mn = Vector3(-20, 0, -20); mx = Vector3(20, 0, 20)
	return [mn, mx]

static func _v3(a) -> Vector3:
	return Vector3(a[0], a[1], a[2]) if a is Array and a.size() >= 3 else Vector3.ZERO

static func _place(n: Node3D, spec: Dictionary) -> void:
	n.position = _v3(spec.get("at", [0, 0, 0]))
	n.rotation.y = deg_to_rad(float(spec.get("rot", 0)))

static func _tag_bit(tag: String) -> int:
	match tag:
		"thaw": return RH.L_WORLD_THAW
		"rime": return RH.L_WORLD_RIME
	return RH.L_WORLD_BASE

## Solid furniture blocks; cloth, hangings, wall dressing and ankle-high
## clutter stay passable. Explicit "collide" in the spec always wins.
const PASSABLE_PROPS := ["beam_4m", "rime_spike"]

static func _prop_collides(spec: Dictionary) -> bool:
	if spec.has("collide"):
		return bool(spec["collide"])
	return not (String(spec.get("kit", "")) in PASSABLE_PROPS)

## Kits that are walls/openings you must pass through — these keep exact
## trimesh collision. Anything NOT here gets a solid convex blocker.
const STRUCTURAL_KITS := ["wall_4x4", "wall_low_4m", "portal_4m", "arch_4m", "floor_4x4",
	"fence_iron_4m", "gate_iron", "roof_slab_4m", "frost_veil_frame"]

static func _is_structural(kit) -> bool:
	return String(kit) in STRUCTURAL_KITS

## World-flag conditions on any spec: "require_flag" builds only once the
## flag is set; "absent_flag" builds only until it is. Evaluated at area
## build, so the highland changes shape between visits, not mid-room.
static func _flag_ok(spec: Dictionary) -> bool:
	if spec.has("require_flag") and not World.flag(String(spec["require_flag"])):
		return false
	if spec.has("absent_flag") and World.flag(String(spec["absent_flag"])):
		return false
	return true

static func _piece(area: Area, spec: Dictionary, collide: bool) -> Node3D:
	if not _flag_ok(spec):
		return null
	var tag: String = spec.get("tag", "base")
	var mode := 1 if tag == "thaw" else (2 if tag == "rime" else 0)
	var piece := KitLib.instance(spec["kit"], mode, spec.get("mat_remap", {}))
	_place(piece, spec)
	if spec.has("scale"):
		var sc = spec["scale"]
		piece.scale = _v3(sc) if sc is Array else Vector3.ONE * float(sc)
	if collide and spec.get("collide", true):
		if String(spec["kit"]) == "stair_4m":
			_stair_ramp(piece, tag, "stair_4m")   # ramp-only: step trimesh would wall off the climb
		else:
			# architecture (walls, arcades, portals, windows) keeps its exact
			# hollow shell so you can pass through openings; everything else
			# is a solid convex blocker so the capsule never wedges inside it
			KitLib.add_collision(piece, _tag_bit(tag), not _is_structural(spec["kit"]))
	if spec.get("flames", true) and (tag != "rime"):
		KitLib.add_flame_lights(piece)
	# "glow": [dy, energy, range] — a warm interior light the piece carries
	# (dome bowls, lightwells): flame auto-lights are per-brazier and too
	# short-armed to reach a 12 m shell, so big hollows bring their own sun
	if spec.has("glow"):
		var g: Array = spec["glow"]
		var gl := OmniLight3D.new()
		gl.light_color = Color(1.0, 0.9, 0.65)
		gl.position.y = float(g[0]) if g.size() > 0 else 1.5
		gl.light_energy = float(g[1]) if g.size() > 1 else 1.5
		gl.omni_range = float(g[2]) if g.size() > 2 else 8.0
		gl.shadow_enabled = false
		piece.add_child(gl)
	area.attach(piece, tag)
	return piece

## Grand stairs collide as a smooth 31-degree ramp, never as step trimesh:
## 0.24 m step faces are walls to move_and_slide, so the climb direction
## would be impassable. The ramp surface runs from the top edge (local
## origin) to the floor 0.2 below the stair base, meeting walkable ground
## flush at both ends. The sides carry RAKED parapet colliders that follow
## the slope and match the kit's visible parapets — the old full-height
## level boxes were invisible walls beside every open flight, and left the
## upper half of open flights unguarded.
static func _stair_ramp(piece: Node3D, tag: String, kit := "stair_4m") -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (_tag_bit(tag) - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.9, 0.3, 5.15)
	cs.shape = box
	cs.rotation_degrees = Vector3(-30.96, 0, 0)   # rise 2.4 over run 4.0
	cs.position = Vector3(0, -1.45, -2.12)
	body.add_child(cs)
	# parapet flanks mirror the kit variant: _l keeps only x<0, _r only x>0
	var flanks: Array = [-2.17, 2.17]
	if kit.ends_with("_l"):
		flanks = [-2.17]
	elif kit.ends_with("_r"):
		flanks = [2.17]
	for sx in flanks:
		var fs := CollisionShape3D.new()
		var fb := BoxShape3D.new()
		fb.size = Vector3(0.36, 1.5, 4.5)
		fs.shape = fb
		fs.rotation_degrees = Vector3(-30.96, 0, 0)
		# ramp center lifted along the ramp normal so the parapet top rides
		# ~1.05 m above the treads the whole way down. The tilted box's z
		# footprint must END at the stringer foot (local z -4.7): the old
		# 5.15-long box projected 0.46 m past it — an invisible wall on the
		# floor in front of every open flight.
		fs.position = Vector3(sx, -0.57, -2.35)
		body.add_child(fs)
	piece.add_child(body)

static func _row(area: Area, spec: Dictionary) -> void:
	var from := _v3(spec.get("from", [0, 0, 0]))
	var dir := _v3(spec.get("dir", [1, 0, 0]))
	var count := int(spec.get("count", 1))
	var step := float(spec.get("step", 4.0))
	# JSON numbers arrive as floats; Array.has() is type-strict, so an int
	# loop index never matches [1.0] — normalize to ints
	var skip := {}
	for s in spec.get("skip", []):
		skip[int(s)] = true
	for i in count:
		if skip.has(i):
			continue
		var sub := spec.duplicate()
		sub["at"] = [from.x + dir.x * step * i, from.y, from.z + dir.z * step * i]
		_piece(area, sub, spec.get("collide", true))

static func _fill(area: Area, spec: Dictionary) -> void:
	var mn := _v3(spec.get("min", [0, 0, 0]))
	var mx := _v3(spec.get("max", [4, 0, 4]))
	var step := float(spec.get("step", 4.0))
	var x := mn.x
	while x < mx.x - 0.01:
		# a span that doesn't divide by the tile must NOT overshoot its bound:
		# the last row used to poke past its bound —
		# a gated-off ledge nobody could reach. Clamp the edge tiles instead.
		var w := minf(step, mx.x - x)
		var z := mn.z
		while z < mx.z - 0.01:
			var dpt := minf(step, mx.z - z)
			var sub := spec.duplicate()
			sub["at"] = [x + w * 0.5, mn.y, z + dpt * 0.5]
			if w < step - 0.01 or dpt < step - 0.01:
				sub["scale"] = [w / step, 1.0, dpt / step]
			_piece(area, sub, spec.get("collide", true))
			z += step
		x += step

## Wall pieces are 4 m tall; a vault bay rises 2.19 m from its springline.
## Spring the vaults FROM the wall-top cornice so the web meets the walls and
## the apex sits inside the room, then cap with a watertight slab + a
## clerestory band closing the gap between wall-top and slab. Result: a fully
## roofed room, no vault poking above the walls, no sky leaking at the eaves.
const _WALL_TOP := 4.0
const _VAULT_APEX := 1.358

static func _vault_field(area: Area, spec: Dictionary) -> void:
	var mn := _v3(spec.get("min", [0, 0, 0]))
	var mx := _v3(spec.get("max", [4, 0, 4]))
	var tag: String = spec.get("tag", "base")
	# the cornice sits a wall-height above THIS field's floor, so a raised room
	# (a raised landing) gets full headroom instead of a ceiling
	# pressed down to the hall's 4 m. spring_top still overrides absolutely.
	var wall_top := mn.y + _WALL_TOP
	var spring := float(spec.get("spring_top", wall_top))
	# "band_from" lifts the clerestory band's lower edge (absolute Y). Raised
	# rooms open onto these halls through doorways at the field edge; a band
	# starting at the 4 m wall-top crossed those doorways at head height. Any
	# strip left open below band_from must be sealed per-edge with boxes.
	var band_from := float(spec.get("band_from", wall_top))
	# some rooms read better with a plain timber-beamed flat ceiling than groin
	# vaults; "flat": true opts a field into that (vaults stay for grander halls)
	# greybox: there is no vault kit, so every field roofs flat
	if true:
		_flat_ceiling(area, mn, mx, tag, spring, spec)
		return
	var ceil_h := spring + _VAULT_APEX + 0.2
	# decorative groin vaults, springing from the cornice
	var x := mn.x
	while x < mx.x - 0.01:
		var z := mn.z
		while z < mx.z - 0.01:
			var p := spec.duplicate()
			p["kit"] = "vault_bay_4x4"
			p["at"] = [x + 2.0, spring, z + 2.0]
			p["collide"] = false      # ceilings don't need trimesh for gameplay
			_piece(area, p, false)
			z += 4.0
		x += 4.0
	# watertight lid + clerestory band so no sky shows above the walls
	# (absolute Y). "band_mat" lets a dressed hall clad these faces in its
	# own stone — bare brick read as a raw slab wherever
	# a band face crossed an open ceiling
	var mat := MaterialLib.get_mat(spec.get("band_mat", "M_stone"), _state_mode(tag))
	_roof_box(area, tag, mat, Vector3((mn.x + mx.x) * 0.5, ceil_h + 0.15, (mn.z + mx.z) * 0.5),
			Vector3(mx.x - mn.x + 0.4, 0.3, mx.z - mn.z + 0.4), true)
	var cy := (band_from + ceil_h) * 0.5
	var ch := maxf(ceil_h - band_from, 0.1)
	var skip_bands := {}
	for sb in spec.get("skip_bands", []):
		skip_bands[String(sb)] = true
	# north / south (span x), east / west (span z)
	if not skip_bands.has("N"):
		_roof_box(area, tag, mat, Vector3((mn.x + mx.x) * 0.5, cy, mn.z), Vector3(mx.x - mn.x + 0.4, ch, 0.4), true)
	if not skip_bands.has("S"):
		_roof_box(area, tag, mat, Vector3((mn.x + mx.x) * 0.5, cy, mx.z), Vector3(mx.x - mn.x + 0.4, ch, 0.4), true)
	if not skip_bands.has("W"):
		_roof_box(area, tag, mat, Vector3(mn.x, cy, (mn.z + mx.z) * 0.5), Vector3(0.4, ch, mx.z - mn.z + 0.4), true)
	if not skip_bands.has("E"):
		_roof_box(area, tag, mat, Vector3(mx.x, cy, (mn.z + mx.z) * 0.5), Vector3(0.4, ch, mx.z - mn.z + 0.4), true)

## A flat, sensibly-high coffered ceiling: a stone lid a little above the wall
## cornice, crossed by warm timber beams, with a short clerestory band sealing
## the gap so no sky shows. Used where groin vaults would feel too busy.
static func _flat_ceiling(area: Area, mn: Vector3, mx: Vector3, tag: String, wall_top: float,
		spec: Dictionary = {}) -> void:
	var lid := wall_top + 0.85
	var mat := MaterialLib.get_mat(spec.get("lid_mat", "M_stone"), _state_mode(tag))
	var wood := MaterialLib.get_mat(spec.get("beam_mat", "M_wood"), _state_mode(tag))
	var skip_bands := {}
	for sb in spec.get("skip_bands", []):
		skip_bands[String(sb)] = true
	# the flat lid (absolute Y)
	_roof_box(area, tag, mat, Vector3((mn.x + mx.x) * 0.5, lid + 0.15, (mn.z + mx.z) * 0.5),
			Vector3(mx.x - mn.x + 0.4, 0.3, mx.z - mn.z + 0.4), true)
	var span_x := mx.x - mn.x
	var span_z := mx.z - mn.z
	if spec.get("coffer", false):
		# a TRUE coffer grid: deep beams both ways on a tight square module —
		# the grander answer to plain timber
		var m := float(spec.get("coffer_step", 2.0))
		var bx := mn.x + m
		while bx < mx.x - 0.01:
			_roof_box(area, tag, wood, Vector3(bx, lid - 0.2, (mn.z + mx.z) * 0.5),
					Vector3(0.3, 0.42, span_z))
			bx += m
		var bz := mn.z + m
		while bz < mx.z - 0.01:
			_roof_box(area, tag, wood, Vector3((mn.x + mx.x) * 0.5, lid - 0.2, bz),
					Vector3(span_x, 0.42, 0.3))
			bz += m
		# perimeter cove: a trim band where the coffers meet the walls
		_roof_box(area, tag, wood, Vector3((mn.x + mx.x) * 0.5, lid - 0.2, mn.z + 0.15),
				Vector3(span_x, 0.42, 0.3))
		_roof_box(area, tag, wood, Vector3((mn.x + mx.x) * 0.5, lid - 0.2, mx.z - 0.15),
				Vector3(span_x, 0.42, 0.3))
		_roof_box(area, tag, wood, Vector3(mn.x + 0.15, lid - 0.2, (mn.z + mx.z) * 0.5),
				Vector3(0.3, 0.42, span_z))
		_roof_box(area, tag, wood, Vector3(mx.x - 0.15, lid - 0.2, (mn.z + mx.z) * 0.5),
				Vector3(0.3, 0.42, span_z))
		# lower architrave trim along perimeter wall heads
		if not skip_bands.has("N"):
			_roof_box(area, tag, wood, Vector3((mn.x + mx.x) * 0.5, wall_top + 0.08, mn.z + 0.14),
					Vector3(span_x, 0.16, 0.28))
		if not skip_bands.has("S"):
			_roof_box(area, tag, wood, Vector3((mn.x + mx.x) * 0.5, wall_top + 0.08, mx.z - 0.14),
					Vector3(span_x, 0.16, 0.28))
		if not skip_bands.has("W"):
			_roof_box(area, tag, wood, Vector3(mn.x + 0.14, wall_top + 0.08, (mn.z + mx.z) * 0.5),
					Vector3(0.28, 0.16, span_z))
		if not skip_bands.has("E"):
			_roof_box(area, tag, wood, Vector3(mx.x - 0.14, wall_top + 0.08, (mn.z + mx.z) * 0.5),
					Vector3(0.28, 0.16, span_z))
	elif span_x >= span_z:
		var bx := mn.x + 2.0
		while bx < mx.x - 0.01:
			_roof_box(area, tag, wood, Vector3(bx, lid - 0.13, (mn.z + mx.z) * 0.5),
					Vector3(0.24, 0.26, span_z))
			bx += 4.0
	else:
		var bz := mn.z + 2.0
		while bz < mx.z - 0.01:
			_roof_box(area, tag, wood, Vector3((mn.x + mx.x) * 0.5, lid - 0.13, bz),
					Vector3(span_x, 0.26, 0.24))
			bz += 4.0
	# clerestory band closing wall-top -> lid on non-skipped perimeter sides
	# (centered on the wall grid line with 0.38 m thickness to sit flush with wall_4x4)
	var cy := (wall_top + lid) * 0.5
	var ch := maxf(lid - wall_top, 0.1)
	if not skip_bands.has("N"):
		_roof_box(area, tag, mat, Vector3((mn.x + mx.x) * 0.5, cy, mn.z), Vector3(mx.x - mn.x + 0.38, ch, 0.38), true)
	if not skip_bands.has("S"):
		_roof_box(area, tag, mat, Vector3((mn.x + mx.x) * 0.5, cy, mx.z), Vector3(mx.x - mn.x + 0.38, ch, 0.38), true)
	if not skip_bands.has("W"):
		_roof_box(area, tag, mat, Vector3(mn.x, cy, (mn.z + mx.z) * 0.5), Vector3(0.38, ch, mx.z - mn.z + 0.38), true)
	if not skip_bands.has("E"):
		_roof_box(area, tag, mat, Vector3(mx.x, cy, (mn.z + mx.z) * 0.5), Vector3(0.38, ch, mx.z - mn.z + 0.38), true)

static func _state_mode(tag: String) -> int:
	return 1 if tag == "thaw" else (2 if tag == "rime" else 0)

static var _box_mesh_cache: Dictionary = {}

## A solid box of geometry (roof slab / clerestory strip) attached to a layer.
static func _roof_box(area: Area, tag: String, mat: Material, center: Vector3, size: Vector3,
		cast_shadow: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var bm: BoxMesh = _box_mesh_cache.get(size)
	if bm == null:
		bm = BoxMesh.new()
		bm.size = size
		_box_mesh_cache[size] = bm
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = center
	area.attach(mi, tag)

## A visible solid stone block with a matching collider: stair cheeks, landing
## skirts, plinths. A modular 4 m wall grid can't tile a 4.68 m stair opening
## flush, so raised-floor edges leave slivers of exposed drop beside the stairs;
## a skirt box seals the vertical face. min/max in world space; optional "mat"
## (defaults to the wall stone) and "tag".
static func _solid_box(area: Area, spec: Dictionary) -> void:
	var tag: String = spec.get("tag", "base")
	var mn := _v3(spec["min"])
	var mx := _v3(spec["max"])
	var center := (mn + mx) * 0.5
	var size := mx - mn
	var mat := MaterialLib.get_mat(spec.get("mat", "M_stone"), _state_mode(tag))
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	area.attach(mi, tag)
	if spec.get("collide", true):
		var body := StaticBody3D.new()
		body.collision_layer = 1 << ((RH.L_WORLD_LOW if spec.get("low", false) else _tag_bit(tag)) - 1)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var cb := BoxShape3D.new()
		cb.size = size
		cs.shape = cb
		body.add_child(cs)
		body.position = center
		area.attach(body, tag)

## Invisible impassable volume (collapsed debris etc.) — dress it with props.
static func _blocker(area: Area, spec: Dictionary) -> void:
	var tag: String = spec.get("tag", "base")
	var mn := _v3(spec["min"])
	var mx := _v3(spec["max"])
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (_tag_bit(tag) - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mx - mn
	cs.shape = box
	body.add_child(cs)
	area.attach(body, tag)
	body.position = (mn + mx) * 0.5
	cs.position = Vector3.ZERO

static func _all_spawners(area: Area) -> Array:
	var out: Array = []
	var stack: Array[Node] = [area]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Spawner:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out
