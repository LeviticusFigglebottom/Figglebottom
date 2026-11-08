extends TestBase
## Kettle Fjord (kettle_fjord): the third region, below the Lowe on the Kettle
## Road. One continuous seam back to the Lowe; in THAW the fjord is open water
## and the way along the shelf goes out round the rock spurs on jetties to the
## fish-houses on their stilts; in RIME the fjord is one sheet of ice, the
## crevasses and thin ice drown you, and the Ice-Cutter waits at the
## Breathing Hole behind its veil.

var area: Area
var player: Player

func _ready() -> void:
	_run.call_deferred()

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

## Walk a list of waypoints in turn.
func _walk_route(pts: Array, per := 700) -> bool:
	for p in pts:
		if not await _walk_to(p, per):
			return false
	return true

func _wait_respawn() -> void:
	var w := 0
	while player.dead and w < 400:
		w += 10
		await ticks(10)

func _pickup(id: String) -> Dictionary:
	for p in area.get_meta("def")["pickups"]:
		if p["id"] == id:
			return p
	return {}

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("kettle_fjord")
	add_child(area)
	Game.register_area(area, "kettle_fjord")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("kettle_fjord"))
	World.last_hearth = {"area": "kettle_fjord", "hearth": "hs_landing_ice"}
	await ticks(20)

	print("== Kettle Fjord")
	check(area.terrain != null and area.nav_thaw != null and area.nav_rime != null, "terrain and both navmeshes")
	check(World.get_area_state("kettle_fjord") == RH.WState.THAW, "first visit finds the fjord in thaw")
	check(Game.find_hearth("hs_landing_ice") != null and Game.find_hearth("hs_fish_houses") != null,
		"the Landing Ice and Fish-Houses hearths stand")
	var houses := area.base.get_children().filter(func(n): return String(n.name).begins_with("House_fishhouse"))
	check(houses.size() == 3, "three fish-houses on stilts (%d)" % houses.size())
	check(area.thaw_layer.find_children("*", "NPC", true, false).size() == 3, "Ivo, Halla and Sten keep the thaw")
	check(player.is_on_floor(), "the Bearer stands on the Kettle Road")

	print("== one continuous seam to the Lowe")
	var seams := area.find_children("*", "AreaPortal", true, false).filter(func(p): return p.auto)
	check(seams.size() == 1 and seams[0].to_area == "lowe_barrows", "a single seam, back up the Kettle Road")
	var lowe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/lowe_barrows.json"))
	var back: Array = lowe["portals"].filter(func(p): return p.get("to", "") == "kettle_fjord")
	check(back.size() == 1, "the Lowe has the other side of it")
	if back.size() == 1 and seams.size() == 1:
		var here: Vector3 = seams[0].global_position
		var there: Vector3 = AreaBuilder._v3(back[0]["at"])
		check(here.distance_to(there) < 0.5, "both sides stand on the same ground (%.2f m apart)" % here.distance_to(there))
		var land: Vector3 = AreaBuilder._v3(back[0]["spawn"])
		check(absf(land.y - area.terrain.height_at(land.x, land.z)) < 1.5, "the Lowe sets you down on the fjord's terrain")
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/index.json"))
	check(JSON.stringify(idx).contains("kettle_fjord"), "the fjord is in the area index")

	print("== the jetty route (thaw navmesh)")
	var start := player.global_position
	var landing := Game.find_hearth("hs_landing_ice").respawn_point()
	var houses_h := Game.find_hearth("hs_fish_houses").respawn_point()
	var ladle := AreaBuilder._v3(_pickup("kettle_ladle")["at"])
	var hut_door := ladle + Vector3(0, 0, 5.2)
	var cache := AreaBuilder._v3(_pickup("north_shore_cache")["at"])
	check(_reaches(_path(start, landing), landing), "the Kettle Road comes down to the Landing Ice")
	check(_reaches(_path(landing, houses_h), houses_h), "the jetties carry the path round the spur to the Fish-Houses")
	check(_reaches(_path(houses_h, hut_door), hut_door), "and out along the walk to the westmost fish-house")
	var p_cache := _path(landing, cache)
	check(not _reaches(p_cache, cache), "no thaw route over the open water to the north shore")
	if _reaches(p_cache, cache):
		print("    thaw path to the cache: ", p_cache.slice(0, 3), " ... ", p_cache.slice(p_cache.size() - 4))
	check(absf(_ray_y(-72, -328, 20) - 2.1) < 0.3, "a jetty deck stands clear of the spur")
	player.global_position = landing + Vector3(0, 0.3, 0)
	await ticks(6)
	var walked: bool = await _walk_route([Vector3(-83.0, 0, -312.0), Vector3(-83.0, 0, -328.0),
		Vector3(-61.0, 0, -328.0), Vector3(-61.0, 0, -314.0), houses_h])
	check(walked and not player.dead, "the Bearer walks the jetties to the Fish-Houses")
	if not walked:
		print("    stuck at ", player.global_position)
	player.global_position = houses_h + Vector3(0, 0.3, 0)
	await ticks(6)
	await _walk_to(Vector3(houses_h.x, 0, -330.0), 700)
	check(player.dead, "the open water takes whoever steps off the shelf")
	await _wait_respawn()
	check(not player.dead, "and a hearth gives them back")

	print("== the first rest turns the fjord to rime")
	var hearth := Game.find_hearth("hs_landing_ice")
	player.global_position = hearth.respawn_point()
	await ticks(4)
	Game.hearth_flow(hearth, player)
	var w := 0
	while not StateDirector.transitioning and w < 300:
		w += 5
		await ticks(5)
	w = 0
	while StateDirector.transitioning and w < 1200:
		w += 10
		await ticks(10)
	check(World.get_area_state("kettle_fjord") == RH.WState.RIME, "the fjord is rime")
	await ticks(30)
	var foes := get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead)
	check(foes.size() >= 8, "%d foes on the ice (stand-ins until the art lands)" % foes.size())
	var ids := {}
	for sp in def["spawners"]:
		ids[sp["enemy"]] = true
	check(ids.has("ice_fisher") and ids.has("sledge_dog") and ids.has("sealer") and ids.has("ice_cutter"),
		"the roster's ids: ice_fisher, sledge_dog, sealer, ice_cutter")
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "one veil, across the gap in the pressure ridges")
	if veils.size() == 1:
		var veil: FrostVeil = veils[0]
		check(veil.boss_spawner != null and veil.boss_spawner.current != null
				and veil.boss_spawner.current.cfg.get("is_boss", false), "the Ice-Cutter (stand-in) waits behind the veil")
		var mouth := veil.global_position + Vector3(0, 0, 3.0)
		var pm := _path(landing, mouth)
		check(_reaches(pm, mouth, 3.0), "the rime navmesh crosses the ice to the Breathing Hole")
		if not _reaches(pm, mouth, 3.0):
			print("    rime path to the hole: ", pm.size(), " ", pm.slice(pm.size() - 2), " mouth ", mouth)

	print("== the ice in rime")
	check(absf(_ray_y(-60, -330, 20) - 0.05) < 0.2, "ice over the fjord")
	check(_reaches(_path(landing, cache), cache), "the rime navmesh crosses the ice to the north shore")
	# thin ice: a crevasse drowns
	var crack := Vector3(-95.4, 0.3, -325.0)
	player.global_position = crack + Vector3(3.0, 0, 0)
	await ticks(6)
	await _walk_to(crack, 200, 0.3)
	await ticks(90)
	check(player.dead, "a crevasse in the ice takes the Bearer")
	await _wait_respawn()
	check(not player.dead and World.get_area_state("kettle_fjord") == RH.WState.RIME, "back at the hearth, still rime")
	# the walk over the ice to the north shore, along the rime navmesh
	var from := Game.find_hearth("hs_landing_ice").respawn_point()
	player.global_position = from + Vector3(0, 0.3, 0)
	await ticks(6)
	player.invulnerable = true
	var route: Array = []
	var pr := _path(from, cache)
	for k in range(1, pr.size()):
		if route.is_empty() or pr[k].distance_to(route[route.size() - 1]) > 0.6 or k == pr.size() - 1:
			route.append(pr[k])
	walked = await _walk_route(route, 400)
	if not walked:
		print("    stuck at ", player.global_position)
	check(walked and not player.dead, "the Bearer walks the ice to the north shore")
	check(player.try_interact(), "pried up what the ice holds")
	check(int(player.inventory.get("bog_iron", 0)) == 2, "2 bog-iron held")
	player.invulnerable = false

	finish()
