extends TestBase
## Saltfell as one landscape (ADR 0003/0005): built on terrain, thaw-first
## arrival on the Strand, the cliff path joins Strand and yard on the navmesh,
## the forced first rest at the Boat-Shed (thaw -> rime), the rime populated,
## the RIME-only frozen channel to the sea stack, the boat-shed shortcut loop
## (barred from below, unbarred from the gully above), the frost veil, and
## warmth enough for one level.

var area: Area
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _awake_foes() -> Array:
	return get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(
			func(e): return e.can_process() and not e.dead)

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, area.terrain.height_at(x, z), z)

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := area.get_world_3d().navigation_map
	var a := NavigationServer3D.map_get_closest_point(map, from)
	var b := NavigationServer3D.map_get_closest_point(map, to)
	return NavigationServer3D.map_get_path(map, a, b, true)

func _plen(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
	return l

func _reaches(p: PackedVector3Array, to: Vector3, tol := 2.5) -> bool:
	return p.size() > 1 and p[p.size() - 1].distance_to(to) < tol

## Steered capsule: face the target and walk until near it (or out of time).
func _walk_to(to: Vector3, max_ticks := 900, tol := 1.2) -> bool:
	var waited := 0
	while waited < max_ticks:
		var d := to - player.global_position
		d.y = 0
		if d.length() < tol:
			player.sim_move = Vector3.ZERO
			return true
		player.cam.yaw = atan2(-d.x, -d.z)
		player.sim_move = Vector3(0, 0, -1)
		await ticks(2)
		waited += 2
		if player.dead:
			break
	player.sim_move = Vector3.ZERO
	return false

## Steer along the navmesh's own route (the gully bends; no straight line).
func _walk_path(to: Vector3, max_ticks := 1600) -> bool:
	var p := _path(player.global_position, to)
	var used := 0
	for k in range(1, p.size()):
		var t0 := Engine.get_physics_frames()
		var ok: bool = await _walk_to(p[k], max_ticks - used, 0.7 if k < p.size() - 1 else 0.9)
		used += int(Engine.get_physics_frames() - t0)
		if not ok:
			return false
	return true

func _ray_down(x: float, z: float, top := 30.0) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -30, z), RH.M_WORLD_ALL)
	return area.get_world_3d().direct_space_state.intersect_ray(q)

func _rest_and_wait(hearth: Hearthstone) -> void:
	Game.hearth_flow(hearth, player)
	var waited := 0
	while not StateDirector.transitioning and waited < 300:
		waited += 5
		await ticks(5)
	waited = 0
	while StateDirector.transitioning and waited < 1200:
		waited += 10
		await ticks(10)

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	var t0 := Time.get_ticks_msec()
	area = AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("saltfell_steading"))
	await ticks(20)
	print("  (build + bake %d ms)" % (Time.get_ticks_msec() - t0))

	print("== one landscape")
	check(World.get_area_state("saltfell_steading") == RH.WState.THAW, "first visit finds Saltfell in thaw")
	check(area.terrain != null and area.terrain.heights.size() > 50000, "the land is a heightmap terrain")
	check(area.terrain.find_children("*", "StaticBody3D", true, false).size() == 1, "one heightmap collider")
	check(area.nav_thaw != null and area.nav_rime != null, "both navmeshes baked")
	check(area.nav_thaw.navigation_mesh.get_polygon_count() > 200,
		"the thaw navmesh covers the land (%d polys)" % area.nav_thaw.navigation_mesh.get_polygon_count())
	var shed_hearth := Game.find_hearth("hs_boat_shed")
	var yard_hearth := Game.find_hearth("hs_salt_house")
	check(shed_hearth != null and yard_hearth != null, "the Boat-Shed and the Salt House hearths stand")
	check(shed_hearth.global_position.y < 6.0 and yard_hearth.global_position.y > 18.0,
		"one hearth on the Strand, one on the shelf")
	check(_awake_foes().size() == 0, "no enemies awake in thaw")
	var npcs := area.thaw_layer.find_children("*", "NPC", true, false)
	check(npcs.size() == 2, "Ingra and Brede keep the thaw")
	check(player.is_on_floor() and absf(player.global_position.y - area.terrain.height_at(
		player.global_position.x, player.global_position.z)) < 0.6, "the Bearer stands on the shingle")
	check(area.get_tree().get_nodes_in_group("hazards").size() >= 3, "drown, ravine and fall volumes guard the edges")

	print("== the cliff path (thaw navmesh)")
	var strand := _ground(-4, 62)
	var yard := _ground(-10, 10)
	var p := _path(strand, yard)
	check(_reaches(p, yard), "a route climbs from the Strand to the yard")
	var top_y := 0.0
	for v in p:
		if v.x < -15.0 and v.z > 30.0:
			top_y = maxf(top_y, v.y)
	check(top_y > 15.0, "it switchbacks up the west cliff face (%.1f m)" % top_y)
	check(_plen(p) > 100.0, "the long way round (%.0f m)" % _plen(p))

	print("== the channel is water in thaw")
	var stack := _ground(-30, 105)
	var shore := _ground(-30, 77)
	var hit := _ray_down(-30, 94, 3.0)
	check(not hit.is_empty() and hit["position"].y < -2.0,
		"no footing over the channel (seabed %.1f)" % (hit["position"].y if not hit.is_empty() else 0.0))
	check(not _reaches(_path(shore, stack), stack), "no thaw route to the sea stack")

	print("== the first rest forces the rime")
	player.global_position = shed_hearth.respawn_point()
	await ticks(4)
	await _rest_and_wait(shed_hearth)
	check(World.get_area_state("saltfell_steading") == RH.WState.RIME, "Saltfell is rime now")
	await ticks(30)
	var foes := _awake_foes()
	var walkers := foes.filter(func(e): return e.id == "rimewalker")
	check(walkers.size() == 8, "%d rimewalkers on the Strand and in the yard (SLICE: 4 + 4)" % walkers.size())
	check(foes.filter(func(e): return e.id == "oarsman").size() == 5, "five oarsmen (SLICE: 3 on the Strand, 2 at the cliff edge)")
	check(foes.filter(func(e): return e.id == "hearthhound").size() == 2, "two hearthhounds")
	check(foes.any(func(e): return e.id == "netmender" and e.cfg.get("is_boss", false)), "the Netmender keeps the Longhouse")
	check(World.last_hearth.get("hearth", "") == "hs_boat_shed", "the Boat-Shed is the respawn anchor")

	print("== uncleared rime cannot warm")
	Game.hearth_flow(shed_hearth, player)
	var flipped := false
	for i in 24:
		await ticks(10)
		flipped = flipped or StateDirector.transitioning
	check(not flipped and World.get_area_state("saltfell_steading") == RH.WState.RIME,
			"rest only — the Netmender endures")

	print("== the frozen channel (rime only)")
	player.invulnerable = true
	hit = _ray_down(-30, 94, 3.0)
	check(not hit.is_empty() and absf(hit["position"].y - 0.06) < 0.1, "ice over the channel")
	check(_reaches(_path(shore, stack), stack), "the rime navmesh walks the ice to the stack")
	player.global_position = shore + Vector3(0, 0.3, 0)
	await ticks(6)
	var walked: bool = await _walk_to(stack, 900)
	check(walked and not player.dead and player.global_position.y > 0.0,
		"the Bearer walks the ice to the sea stack (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(player.try_interact(), "pried up the bog-iron on the stack")
	check(int(player.inventory.get("bog_iron", 0)) == 2, "2 bog-iron held")

	print("== the loop: the boat-shed back door")
	var gate: ShortcutGate = area.base.find_children("*", "ShortcutGate", true, false)[0]
	var gate_pos := gate.global_position
	player.global_position = gate_pos + Vector3(0, 0.3, 1.3)
	await ticks(6)
	var it := player.nearest_interactable()
	check(it != null and it.prompt == "Barred from the other side", "from the shed the door is barred")
	if it != null:
		it.activate(player)
	await ticks(4)
	check(not World.area_flag("saltfell_steading", "gate_boatshed_back"), "and stays barred")
	var gully_head := _ground(25, 9)
	var by_hearth := shed_hearth.respawn_point()
	var long_way := _path(gully_head, by_hearth)
	check(_reaches(long_way, by_hearth, 3.0), "the yard reaches the Boat-Shed only the long way")
	var l1 := _plen(long_way)
	check(l1 > 150.0, "the long way is long (%.0f m)" % l1)
	player.global_position = gully_head + Vector3(0, 0.4, 0)
	await ticks(6)
	walked = await _walk_path(gate_pos + Vector3(0, 0, -1.4), 1600)
	check(walked and not player.dead, "down the gully to the back of the door (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	it = player.nearest_interactable()
	check(it != null and it.prompt == "Unbar the gate", "from above it can be unbarred")
	if it != null:
		it.activate(player)
	await ticks(30)
	check(World.area_flag("saltfell_steading", "gate_boatshed_back"), "the shortcut is open for good")
	var short_way := _path(gully_head, by_hearth)
	var l2 := _plen(short_way)
	check(_reaches(short_way, by_hearth, 3.0) and l2 < l1 * 0.5,
		"the yard is now a short walk from the Boat-Shed (%.0f m, was %.0f m)" % [l2, l1])
	walked = await _walk_to(gate_pos + Vector3(0, 0, 2.5), 300, 0.8)
	walked = walked and await _walk_to(Vector3(25.2, 0, by_hearth.z), 400, 0.8)
	check(walked and player.global_position.distance_to(by_hearth) < 3.0, "through the door to the hearth")
	player.invulnerable = false

	print("== the frost veil bars the Longhouse")
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "one frost veil")
	var vp: Vector3 = veils[0].global_position
	var q := PhysicsRayQueryParameters3D.create(vp + Vector3(0, 1.2, 3), vp + Vector3(0, 1.2, -3), RH.M_WORLD_ALL)
	check(not area.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "the veil blocks the doorway")

	print("== warmth buys a level")
	walkers = _awake_foes().filter(func(e): return e.id == "rimewalker")
	for e in walkers:
		while not e.dead:
			e.take_hit(DamagePacket.new(40, 10, player))
			await ticks(2)
	await ticks(10)
	check(Game.warmth >= 60, "the rimewalkers give up %d warmth (>= 60)" % Game.warmth)
	var ui := RestUI.new(yard_hearth, player)
	get_tree().root.add_child(ui)
	await ticks(2)
	check(ui._level_cost() == 60, "level 1 -> 2 costs 60")
	var w0 := Game.warmth
	ui.choose(1)          # Grow by warmth
	ui.choose(0)          # first stat (heart)
	check(player.level == 2, "the Bearer reaches level 2")
	check(Game.warmth == w0 - 60, "60 warmth spent")
	check(player.attributes["heart"] == 9, "heart rose to 9")
	ui.close()
	await ticks(2)

	finish()
