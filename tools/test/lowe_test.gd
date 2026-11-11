extends TestBase
## The Lowe (lowe_barrows): built on its own terrain in Saltfell's coordinates,
## both seams back to Saltfell, the road from the pass to the Open Barrow on
## the navmesh, the bog that drowns in THAW and carries you in RIME, the
## drawbridge lowered from this side (a shortcut that stays down), the barrows
## that open in RIME, and the Turfwright's arena behind its veil.

var area: Area
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, area.terrain.height_at(x, z), z)

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := area.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, from),
		NavigationServer3D.map_get_closest_point(map, to), true)

func _reaches(p: PackedVector3Array, to: Vector3, tol := 2.5) -> bool:
	return p.size() > 1 and p[p.size() - 1].distance_to(to) < tol

func _ray_y(x: float, z: float, top: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -30, z), RH.M_WORLD_ALL)
	var hit := area.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"].y if not hit.is_empty() else -999.0

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

func _awake_foes() -> Array:
	return get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(
			func(e): return e.can_process() and not e.dead)

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("lowe_barrows")
	add_child(area)
	Game.register_area(area, "lowe_barrows")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("lowe_barrows"))
	World.last_hearth = {"area": "lowe_barrows", "hearth": "hs_barrow_road"}
	await ticks(20)

	print("== the Lowe")
	check(area.terrain != null and area.nav_thaw != null and area.nav_rime != null, "terrain and both navmeshes")
	check(World.get_area_state("lowe_barrows") == RH.WState.THAW, "first visit finds the Lowe in thaw")
	check(Game.find_hearth("hs_barrow_road") != null, "the Barrow Road hearth stands")
	var houses := area.base.get_children().filter(func(n): return String(n.name).begins_with("House_"))
	check(houses.size() == 5, "four kin-barrows and the twin barrow (%d)" % houses.size())
	# (the family going home from the Bread Mound are voices, never seen: POI.md 3.1)
	check(area.thaw_layer.find_children("*", "NPC", true, false).filter(
		func(n): return not DB.npc((n as NPC).npc_id).get("unseen", false)).size() == 2, "Aud and Hesk keep the thaw")
	check(player.is_on_floor(), "the Bearer stands on the pass")
	var seams := area.find_children("*", "AreaPortal", true, false).filter(func(p): return p.auto and p.to_area == "saltfell_steading")
	check(seams.size() == 2, "two seams back to Saltfell: the pass and the bridge")

	print("== the Barrow Road (thaw navmesh)")
	var start := player.global_position
	var veil: FrostVeil = area.rime_layer.find_children("*", "FrostVeil", true, false)[0]
	var arena_mouth := veil.global_position + Vector3(0, 0, 3.0)
	check(_reaches(_path(start, arena_mouth), arena_mouth, 3.0), "the road runs from the pass to the Open Barrow")
	var hinge := _ground(-8, -85.5)
	check(_reaches(_path(start, hinge), hinge), "and along the ravine rim to the bridge windlass")

	print("== the bog drowns in thaw")
	var isle := Vector3(-39.5, 0, -189.2)
	isle.y = area.terrain.height_at(isle.x, isle.z)
	var shore := _ground(-40, -160)
	check(not _reaches(_path(shore, isle), isle), "no thaw route to the peat island")
	player.global_position = shore + Vector3(0, 0.3, 0)
	await ticks(6)
	await _walk_to(isle, 600)
	check(player.dead, "the black water takes the Bearer")
	var w := 0
	while player.dead and w < 400:
		w += 10
		await ticks(10)
	check(not player.dead, "and the Barrow Road hearth gives them back")

	print("== the drawbridge, lowered from this side")
	var bridge: DrawBridge = area.find_children("*", "DrawBridge", true, false)[0]
	check(not bridge.is_down(), "the bridge stands raised")
	var mid_z := -76.0
	check(_ray_y(-8, mid_z, 30) < 15.0, "nothing spans the ravine yet")
	player.global_position = bridge.global_position + Vector3(0, 0.3, -1.6)
	await ticks(8)
	var it := player.nearest_interactable()
	check(it != null and it.prompt == "Lower the bridge", "the windlass offers itself")
	if it != null:
		it.activate(player)
	await ticks(200)
	check(World.flag("lowe_bridge_down"), "the bridge is down for good (world flag)")
	check(absf(_ray_y(-8, mid_z, 30) - bridge.global_position.y) < 0.4, "the deck spans the ravine")

	print("== the first rest turns the Lowe to rime")
	var hearth := Game.find_hearth("hs_barrow_road")
	player.global_position = hearth.respawn_point()
	await ticks(4)
	Game.hearth_flow(hearth, player)
	w = 0
	while not StateDirector.transitioning and w < 300:
		w += 5
		await ticks(5)
	w = 0
	while StateDirector.transitioning and w < 1200:
		w += 10
		await ticks(10)
	check(World.get_area_state("lowe_barrows") == RH.WState.RIME, "the Lowe is rime")
	await ticks(30)
	var foes := _awake_foes()
	check(foes.size() >= 7, "%d foes walk the Lowe (stand-ins until the art lands)" % foes.size())
	check(veil.boss_spawner != null and veil.boss_spawner.current != null
			and veil.boss_spawner.current.cfg.get("is_boss", false), "the Turfwright (stand-in) waits behind the veil")

	print("== the bog freezes in rime")
	var bog_w: float = float(def["water"][2]["at"][1])
	check(absf(_ray_y(-30, -190, 60) - bog_w) < 0.3, "ice over the black water")
	check(_reaches(_path(shore, isle), isle), "the rime navmesh crosses the ice to the island")
	player.invulnerable = true
	player.global_position = shore + Vector3(0, 0.3, 0)
	await ticks(6)
	var walked: bool = await _walk_to(isle, 900, 1.0)
	check(walked and not player.dead, "the Bearer walks the frozen bog")
	check(player.try_interact(), "pried up the bog-iron on the island")
	check(int(player.inventory.get("bog_iron", 0)) == 2, "2 bog-iron held")
	player.invulnerable = false

	finish()
