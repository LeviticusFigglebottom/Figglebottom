extends TestBase
## The blade on the world: the surface table knows every kit, family,
## landmark and scatter kind the areas use; a swing into wood, stone, iron,
## ice, wool and the ground raises exactly one burst of the right surface
## on the collider, with its sound; clear air and foes raise none; nothing
## stops the clock; bursts free themselves; the per-collider cooldown holds.

var arena: Node
var area: Area
var player: Player
var hits: Array = []          # [collider, pos, normal, surface, burst, sound was requested, sound path]

func _ready() -> void:
	_run.call_deferred()

func _on_struck(col: Object, pos: Vector3, normal: Vector3, surface: String, burst: Node3D) -> void:
	hits.append([col, pos, normal, surface, burst, _sound_playing(burst),
			String(burst.get_meta("sound", "")) if burst != null else ""])

## The director made a positional player for the burst's sound, at the blow.
func _sound_playing(burst: Node3D) -> bool:
	if burst == null:
		return false
	var want := AudioDirector.sound_paths(String(burst.get_meta("sound", "")))
	for c in AudioDirector.get_children():
		var p := c as AudioStreamPlayer3D
		if p != null and p.stream != null and want.has(p.stream.resource_path) \
				and p.global_position.distance_to(burst.global_position) < 0.3:
			return true
	return false

func _bursts() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group(PropHitFX.GROUP):
		if not b.is_queued_for_deletion():
			n += 1
	return n

func _prop(kit: String, pos: Vector3, remap := {}) -> Node3D:
	var p := KitLib.instance(kit, 0, remap)
	p.position = pos
	KitLib.add_collision(p, RH.L_WORLD_BASE, true)
	arena.add_child(p)
	return p

## Stand `dist` south of `pos`, face it (-Z), swing, and let the swing and
## its bursts run out.
func _swing_at(pos: Vector3, dist: float, heavy := false, wait := 110) -> void:
	player.global_position = pos + Vector3(0, 0.1, dist)
	player.vis.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await ticks(3)
	hits.clear()
	player.try_attack(heavy)
	await ticks(wait)

## The point is on the collider: a short ray down the normal meets it there.
func _on_collider(h: Array) -> bool:
	var pos: Vector3 = h[1]
	var n: Vector3 = h[2]
	var q := PhysicsRayQueryParameters3D.create(pos + n * 0.25, pos - n * 0.25, PropStrike.WORLD_MASK)
	var r := player.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or (r["position"] as Vector3).distance_to(pos) > 0.06:   # (a crate's boards stand 4.5 cm proud of its core)
		return false
	# (a boarded crate is many colliders: any of the same piece will do)
	var a: Object = h[0]
	var b: Object = r["collider"]
	return a == b or (a.has_meta(PropStrike.META_GROUP) and a.get_meta(PropStrike.META_GROUP) == b.get_meta(PropStrike.META_GROUP, -1))

func _one(label: String, want: String) -> void:
	check(hits.size() == 1, "%s: exactly one burst (%d)" % [label, hits.size()])
	if hits.is_empty():
		return
	var h: Array = hits[0]
	check(String(h[3]) == want, "%s: the surface is %s (%s)" % [label, want, h[3]])
	check(_on_collider(h), "%s: the burst is on the collider" % label)
	var snd := String(h[6])
	check(snd == "impact/%s" % want and bool(h[5]),
			"%s: the %s strike sound was asked of the director" % [label, want])

func _run() -> void:
	_table()
	await _arena()
	await _land()
	finish()

# ------------------------------------------------------------------ the table
func _walk(o, out: Dictionary) -> void:
	if o is Dictionary:
		if o.has("kit"):
			out["kits"][String(o["kit"])] = true
		for f in ["mat", "family"]:
			if o.has(f) and o[f] is String:
				out["fams"][String(o[f])] = true
		if o.has("mat_remap"):
			for v in (o["mat_remap"] as Dictionary).values():
				out["fams"][String(v)] = true
		if o.has("scene") and o.has("blocker"):
			out["lms"][String(o["scene"])] = String(o.get("family", ""))
		for k in o:
			_walk(o[k], out)
	elif o is Array:
		for v in o:
			_walk(v, out)

func _ok(s: String) -> bool:
	return Surfaces.known(s) or s == Surfaces.NONE

func _table() -> void:
	print("== the table")
	var all := Surfaces.all()
	var need := ["wood", "stone", "metal", "ice", "cloth", "turf", "snow"]
	check(need.all(func(s): return s in all), "the seven surfaces are named (%s)" % str(all))
	check(Surfaces.known(Surfaces.fallback()), "the default is one of them (%s)" % Surfaces.fallback())
	var bad: Array = []
	for fam in MaterialLib.FAMILIES:
		if not _ok(Surfaces.for_family(String(fam))):
			bad.append(fam)
	check(bad.is_empty(), "every material family has a surface (unknown: %s)" % str(bad))

	var used := {"kits": {}, "fams": {}, "lms": {}}
	var ids: Array = []
	for f in DirAccess.get_files_at("res://data/areas"):
		if f.ends_with(".json") and f != "index.json":
			ids.append(f.get_basename())
			_walk(DB.area_def(f.get_basename()), used)
	# what the wayside sets down between the authored places
	for k in ["woodpile", "barrel", "crate", "bench_3m", "drying_rack", "creel_stack", "boat_upturned", "rope_coil", "door_leaf", "hearthstone", "stair_4m"]:
		used["kits"][k] = true
	for lm in ["lm_fold_cairn.glb", "lm_standing_stone.glb", "lm_sledge.glb"]:
		used["lms"][lm] = ""
	check(ids.size() >= 7, "all seven regions were read (%d)" % ids.size())
	bad = []
	for fam in used["fams"]:
		if not _ok(Surfaces.for_family(String(fam))):
			bad.append(fam)
	check(bad.is_empty(), "every family the areas name has a surface (unknown: %s)" % str(bad))
	bad = []
	var said := {}
	for kit in used["kits"]:
		if not KitLib.has_piece(String(kit)) or String(kit).begins_with("mannequin_"):
			continue
		var piece := KitLib.instance(String(kit))
		for mi in KitLib._mesh_instances(piece):
			if mi.mesh == null or String(mi.name).contains("flame"):
				continue
			var s := Surfaces.for_kit(String(kit), String(mi.get_meta("family", "")))
			if not _ok(s):
				bad.append("%s/%s (%s)" % [kit, mi.name, mi.get_meta("family", "?")])
			else:
				said[String(kit)] = s
		piece.free()
	check(bad.is_empty(), "every kit the areas place resolves, mesh by mesh (%d kits; unknown: %s)" % [used["kits"].size(), str(bad)])
	print("     kits: ", said)
	bad = []
	for lm in used["lms"]:
		# a landmark with a collider is named in the table, or carries a family
		var s := Surfaces.lookup("landmarks", String(lm).get_file().get_basename())
		if s == "" and String(used["lms"][lm]) != "":
			s = Surfaces.for_family(String(used["lms"][lm]))
		if not _ok(s):
			bad.append(lm)
	check(bad.is_empty(), "every landmark that blocks has a surface (%d; unknown: %s)" % [used["lms"].size(), str(bad)])
	bad = []
	for kind in ["ice_floe", "boulder", "rock", "stone_fence", "wattle_fence", "peat_stack", "standing_stone", "driftwood"]:
		if not _ok(Surfaces.lookup("scatter", kind)):
			bad.append(kind)
	check(bad.is_empty(), "every solid scatter kind has a surface (unknown: %s)" % str(bad))
	bad = []
	for sec in ["families", "kits", "landmarks", "scatter", "kinds"]:
		var d: Dictionary = Surfaces.table().get(sec, {})
		for k in d:
			if not _ok(String(d[k])) and String(d[k]) != Surfaces.GROUND:
				bad.append("%s/%s=%s" % [sec, k, d[k]])
	check(bad.is_empty(), "no row of the table names a surface that is not one (%s)" % str(bad))
	bad = []
	for s in all:
		var fx: Dictionary = Surfaces.table()["fx"].get(s, {})
		# (the recorded strike sets: audio.json "impacts")
		var takes := AudioDirector.sound_paths(AudioDirector.impact_key(s))
		if (fx.get("layers", []) as Array).is_empty() or takes.is_empty() or AudioDirector.impact_key(s) != "impact/" + s:
			bad.append(s)
			continue
		for p in takes:
			if not ResourceLoader.exists(String(p)):
				bad.append(p)
	check(bad.is_empty(), "every surface has particle layers and a sound on disk (%s)" % str(bad))

# ------------------------------------------------------------------ the arena
func _arena() -> void:
	arena = (load("res://scenes/sandbox/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await ticks(5)
	for sp in ["PenSpawner", "WardSpawner"]:   # a quiet arena
		var n := arena.get_node_or_null(sp)
		if n != null:
			n.free()
	player = arena.get_node("Player")
	player.sim_active = true
	player.prop_strike.struck.connect(_on_struck)
	var dummy: TrainingDummy = arena.get_node("Dummy")
	await ticks(3)
	var stop0: int = Juice._hitstop_until_ms
	var at := Vector3(5, 0, 5)

	print("== a swing in clear air")
	await _swing_at(Vector3(-5, 0, 4), 1.4)
	check(hits.is_empty() and _bursts() == 0, "nothing struck, nothing raised (%d hits, %d bursts)" % [hits.size(), _bursts()])

	print("== wood: a boarded crate (many colliders, one piece)")
	var crate := _prop("crate", at)
	await ticks(2)
	DB.table("game")["prop_hit"]["max_per_swing"] = 8      # the piece itself must answer once
	var kids0 := get_tree().current_scene.get_child_count()
	player.global_position = at + Vector3(0, 0.1, 1.4)
	player.vis.rotation.y = 0.0
	await ticks(3)
	hits.clear()
	player.try_attack(false)
	var seen := 0
	for i in 40:
		await ticks(1)
		seen = maxi(seen, _bursts())
	check(seen == 1, "one burst node stands while the blade passes (%d)" % seen)
	if not hits.is_empty() and is_instance_valid(hits[0][4]):
		var b: Node3D = hits[0][4]
		check(b.get_child_count() >= 2 and b.get_child(0) is CPUParticles3D and (b.get_child(0) as CPUParticles3D).one_shot,
				"it is a few one-shot emitters (%d layers)" % b.get_child_count())
	_one("crate", "wood")
	await ticks(90)
	check(_bursts() == 0 and get_tree().current_scene.get_child_count() == kids0,
			"the burst freed itself (%d left, scene children %d -> %d)" % [_bursts(), kids0, get_tree().current_scene.get_child_count()])
	DB.table("game")["prop_hit"]["max_per_swing"] = 2

	print("== the cooldown is per collider")
	await _swing_at(at, 1.4)
	check(hits.size() == 1, "a second swing, after the cooldown, bursts again (%d)" % hits.size())
	DB.table("game")["prop_hit"]["cooldown"] = 30.0
	await _swing_at(at, 1.4)
	check(hits.size() == 1, "(a burst under a long cooldown)")
	await _swing_at(at, 1.4)
	check(hits.is_empty() and _bursts() == 0, "inside the cooldown the same crate stays quiet (%d)" % hits.size())
	DB.table("game")["prop_hit"]["cooldown"] = 0.3
	player.prop_strike._cool.clear()

	print("== a chained pair: one burst a swing")
	player.global_position = at + Vector3(0, 0.1, 1.4)
	player.vis.rotation.y = 0.0
	await ticks(3)
	hits.clear()
	player.try_attack(false)
	await ticks(10)
	player.try_attack(false)
	await ticks(130)
	check(hits.size() == 2, "two swings, two bursts (%d)" % hits.size())
	crate.free()

	print("== stone: the hearthstone")
	var hearth: Node3D = arena.get_node_or_null("Hearthstone")
	for c in arena.get_children():
		if c is Hearthstone:
			hearth = c
	await _swing_at(hearth.global_position, 1.3, true)
	_one("hearthstone", "stone")

	print("== metal: a brazier")
	var brazier := _prop("brazier", at)
	await ticks(2)
	await _swing_at(at, 1.4)
	_one("brazier", "metal")
	if not hits.is_empty() and is_instance_valid(hits[0][4]):
		check((hits[0][4] as Node).find_children("*", "OmniLight3D", true, false).size() <= 1, "sparks carry at most one brief light")
	brazier.free()

	print("== ice: a wall re-skinned to ice (mat_remap), and a rime spike")
	var wall := _prop("column_4m", at, {"M_wood": "M_ice", "M_stone": "M_ice", "M_wood_dark": "M_ice"})
	await ticks(2)
	await _swing_at(at, 1.4)
	_one("ice column", "ice")
	wall.free()
	var spike := _prop("rime_spike", at)
	await ticks(2)
	await _swing_at(at, 1.2, true)
	_one("rime spike", "ice")
	spike.free()

	print("== cloth: a ewe's fleece")
	var ewe := _prop("sheep", at)
	await ticks(2)
	await _swing_at(at, 1.2)
	_one("ewe", "cloth")
	ewe.free()

	print("== a soul's body takes the blow in silence")
	var post := StaticBody3D.new()
	post.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	var pcs := CollisionShape3D.new()
	var pcap := CapsuleShape3D.new()
	pcap.radius = 0.36
	pcap.height = 1.6
	pcs.shape = pcap
	pcs.position.y = 0.85
	post.add_child(pcs)
	Surfaces.stamp_kind(post, "npc")
	arena.add_child(post)
	post.global_position = at
	await ticks(2)
	await _swing_at(at, 1.3)
	check(hits.is_empty() and _bursts() == 0, "no burst from a body stamped as a soul (%d)" % hits.size())
	post.free()
	var bare := StaticBody3D.new()
	bare.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	var bcs := CollisionShape3D.new()
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(1, 2, 1)
	bcs.shape = bbox
	bcs.position.y = 1.0
	bare.add_child(bcs)
	arena.add_child(bare)
	bare.global_position = at
	await ticks(2)
	await _swing_at(at, 1.5)
	check(hits.size() == 1 and String(hits[0][3]) == Surfaces.fallback(), "an unstamped collider answers as the default (%s)" % Surfaces.fallback())
	bare.free()

	check(Juice._hitstop_until_ms == stop0 and is_equal_approx(Engine.time_scale, 1.0),
			"none of those blows stopped the clock")

	print("== a foe takes the hit; the world raises nothing for it")
	player.global_position = dummy.global_position + Vector3(0, 0.1, 1.6)
	player.vis.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await ticks(3)
	hits.clear()
	var took := dummy.hits_taken
	player.try_attack(false)
	await ticks(100)
	check(dummy.hits_taken == took + 1, "the pell was hit")
	check(hits.is_empty() and _bursts() == 0, "no prop burst for a foe (%d)" % hits.size())
	check(Juice._hitstop_until_ms != stop0, "(and a foe's hit still stops the clock, as before)")

	print("== an armed foe's blade raises chips too")
	# (no foe in enemies.json carries a weapon today, and the Rimewalker's
	# body is bare-handed: arm its mannequin stand-in for this one check)
	var ecfg: Dictionary = DB.table("enemies")["rimewalker"]
	var model = ecfg.get("model", "")
	ecfg["weapon"] = "hewing_blade"
	ecfg.erase("model")
	var foe := Enemy.new()
	foe.setup("rimewalker")
	arena.add_child(foe)
	ecfg.erase("weapon")
	ecfg["model"] = model
	var crate2 := _prop("crate", at)
	foe.global_position = at + Vector3(0, 0.05, 1.3)
	foe.home = foe.global_position
	foe.vis.rotation.y = 0.0
	player.global_position = at + Vector3(0, 0.1, -6.0)
	await ticks(4)
	var foe_hits: Array = []
	foe.target = player
	foe._begin_attack(foe.attack_by_id("swipe"))
	for i in 120:
		await ticks(1)
		if foe._prop_strike != null and foe._prop_strike.struck.get_connections().is_empty():
			foe._prop_strike.struck.connect(func(c, _p, _n, sfc, _b): foe_hits.append([c, sfc]))
			foe_hits.append(["armed", ""])
	print("     foe: ", foe_hits.map(func(h): return h[1]))
	check(foe_hits.size() >= 1, "the armed foe traced its blade")
	check(foe_hits.filter(func(h): return String(h[1]) == "wood").size() == 1, "one wood burst from the foe's swing at the crate")
	foe.free()
	crate2.free()

	arena.queue_free()
	await ticks(4)

# ------------------------------------------------------------------ the land
## A bank the blade will meet: the ground a stride ahead stands waist-high.
func _bank() -> Vector3:
	var t := area.terrain
	var st: Array = area.get_meta("def").get("start", {}).get("pos", [0, 0, 0])
	var c := Vector3(float(st[0]), 0, float(st[2]))
	var space := area.get_world_3d().direct_space_state
	for ring in range(1, 60):
		for k in ring * 8:
			var a := TAU * k / (ring * 8)
			var x := c.x + cos(a) * ring * 2.0
			var z := c.z + sin(a) * ring * 2.0
			if not t.contains(x, z) or not t.contains(x, z - 2.0):
				continue
			var h := t.height_at(x, z)
			var rise := t.height_at(x, z - 1.1) - h
			if rise < 0.7 or rise > 1.2 or t.splat_at(x, z - 1.0, 0) > 0.2 or t.splat_at(x, z, 0) > 0.2:
				continue
			if AudioDirector.surface_at(Vector3(x, t.height_at(x, z - 1.0), z - 1.0)) != "turf":
				continue
			# only the land itself ahead: no wall, rock or fence in the way
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, h + 1.0, z), Vector3(x, h + 1.0, z - 2.5), PropStrike.WORLD_MASK)
			var r := space.intersect_ray(q)
			if r.is_empty() or (r["collider"] as Node).name != "TerrainBody":
				continue
			var q2 := PhysicsRayQueryParameters3D.create(Vector3(x, h + 0.3, z + 1.5), Vector3(x, h + 0.3, z - 0.3), PropStrike.WORLD_MASK)
			var r2 := space.intersect_ray(q2)
			if not r2.is_empty() and (r2["collider"] as Node).name != "TerrainBody":
				continue
			return Vector3(x, h, z)
	return Vector3.INF

func _land() -> void:
	print("== Saltfell, built: every collider carries a surface")
	World.reset()
	area = AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	StateDirector.snap(area, RH.WState.THAW)
	await ticks(6)
	var bare := {}
	var wrong: Array = []
	var by := {}
	var n := 0
	for node in area.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		var layer := int(body.get_meta("orig_layer", body.collision_layer))
		if layer & PropStrike.WORLD_MASK == 0:
			continue
		n += 1
		var s := Surfaces.stamped(body)
		if s == "":
			var who := String(body.get_parent().name) + "/" + String(body.name)
			bare[who] = int(bare.get(who, 0)) + 1
		elif not _ok(s) and s != Surfaces.GROUND:
			wrong.append(s)
		by[s] = int(by.get(s, 0)) + 1
	print("     ", n, " world colliders: ", by)
	check(bare.is_empty(), "no world collider is left to the default (%s)" % str(bare))
	check(wrong.is_empty(), "every stamp is a surface (%s)" % str(wrong))
	check(Surfaces.stamped(area.terrain.get_node("TerrainBody")) == Surfaces.GROUND, "the land is stamped as ground, settled at the blow")

	print("== the ground: turf in THAW, snow in RIME")
	player = Player.new()
	add_child(player)
	player.sim_active = true
	player.prop_strike.struck.connect(_on_struck)
	var spot := _bank()
	check(spot != Vector3.INF, "found a turf bank to strike (%s)" % str(spot))
	if spot == Vector3.INF:
		return
	var stop0: int = Juice._hitstop_until_ms
	player.global_position = spot + Vector3(0, 0.15, 0)
	await ticks(20)
	await _swing_at(player.global_position - Vector3(0, 0.1, 0), 0.0, true)
	_one("the bank (thaw)", "turf")
	if not hits.is_empty():
		check((hits[0][0] as Node).name == "TerrainBody", "it was the land that was struck")
	StateDirector.snap(area, RH.WState.RIME)
	await ticks(6)
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		e.set_physics_process(false)      # nobody walks in on the test
	player.global_position = spot + Vector3(0, 0.15, 0)
	await ticks(20)
	await _swing_at(player.global_position - Vector3(0, 0.1, 0), 0.0, true)
	_one("the bank (rime)", "snow")
	check(Juice._hitstop_until_ms == stop0, "the ground stops no clock either")
	await ticks(60)
	check(_bursts() == 0, "all bursts are gone at the end (%d)" % _bursts())
