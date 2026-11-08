extends TestBase
## Thornwold (thornwold): the fifth region, east of the tarn by the drove-road.
## One seam back to Tarnhall; the Collier's Clearing on the road; the Hedge:
## rings of laid hedge round the grave under the oldest pine. THAW: the gaps
## line up on the road and the way in is straight. RIME: the hedges are walls
## of frozen thorn, the road is plugged and the gaps have moved: a maze to the
## veil in the innermost gap, where the Hedgelayer waits.

const GRAVE := Vector3(452.0, 0.0, -325.0)
const R1 := 12.0
const R3 := 26.0

var area: Area
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	# (the maze is long: lift the polygon search cap a long route needs)
	var map := area.get_world_3d().navigation_map
	var q := NavigationPathQueryParameters3D.new()
	q.map = map
	q.start_position = NavigationServer3D.map_get_closest_point(map, from)
	q.target_position = NavigationServer3D.map_get_closest_point(map, to)
	q.path_search_max_polygons = 200000
	var r := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(q, r)
	return r.path

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

func _near_path(p: PackedVector3Array, pt: Vector3, tol: float) -> bool:
	for q in p:
		if Vector2(q.x - pt.x, q.z - pt.z).length() < tol:
			return true
	return false

func _walk_path(to: Vector3, per := 400) -> bool:
	var route: Array = []
	var pr := _path(player.global_position, to)
	for k in range(1, pr.size()):
		if route.is_empty() or pr[k].distance_to(route[route.size() - 1]) > 0.6 or k == pr.size() - 1:
			route.append(pr[k])
	return await _walk_route(route, per)

func _rest(id: String) -> void:
	var hearth := Game.find_hearth(id)
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

func _len(p: PackedVector3Array) -> float:
	var t := 0.0
	for i in range(1, p.size()):
		t += p[i].distance_to(p[i - 1])
	return t

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, area.terrain.height_at(x, z), z)

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("thornwold")
	add_child(area)
	Game.register_area(area, "thornwold")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("thornwold"))
	World.last_hearth = {"area": "thornwold", "hearth": "hs_colliers_clearing"}
	await ticks(20)

	print("== Thornwold")
	check(area.terrain != null and area.nav_thaw != null and area.nav_rime != null, "terrain and both navmeshes")
	check(World.get_area_state("thornwold") == RH.WState.THAW, "first visit finds the wood in thaw")
	check(Game.find_hearth("hs_drove_road") != null and Game.find_hearth("hs_colliers_clearing") != null,
		"the Drove-Road and Collier's Clearing hearths stand")
	check(area.thaw_layer.find_children("*", "NPC", true, false).size() == 1, "Linnet keeps the thaw")
	check(area.find_children("Forest_tree_*", "MultiMeshInstance3D", true, false).size() > 4, "a wood of pine and birch")
	check(player.is_on_floor(), "the Bearer stands on the drove-road")

	print("== one continuous seam back to Tarnhall")
	var seams := area.find_children("*", "AreaPortal", true, false).filter(func(p): return p.auto)
	check(seams.size() == 1 and seams[0].to_area == "tarnhall", "a single seam, back down the drove-road")
	var tarn: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/tarnhall.json"))
	var back: Array = tarn["portals"].filter(func(p): return p.get("to", "") == "thornwold")
	check(back.size() == 1, "Tarnhall has the other side of it")
	if back.size() == 1 and seams.size() == 1:
		var here: Vector3 = seams[0].global_position
		var there: Vector3 = AreaBuilder._v3(back[0]["at"])
		check(here.distance_to(there) < 0.5, "both sides stand on the same ground (%.2f m apart)" % here.distance_to(there))
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/index.json"))
	check(idx["areas"].has("thornwold") and idx["graph"]["tarnhall"].has("thornwold"), "the world graph runs Tarnhall -> Thornwold")

	print("== THAW: the drove-road, the clearing, straight in to the grave")
	var start := player.global_position
	var clearing := Game.find_hearth("hs_colliers_clearing").respawn_point()
	check(_reaches(_path(start, clearing), clearing), "the drove-road runs from the notch to the Collier's Clearing")
	var grave := _ground(GRAVE.x - 4.0, GRAVE.z + 3.0)
	var p_thaw := _path(clearing, grave)
	check(_reaches(p_thaw, grave), "the gaps in the laid hedges line up: a way to the grave")
	var thaw_len := _len(p_thaw)
	check(thaw_len < clearing.distance_to(grave) * 1.35, "and it is the straight way in (%.0f m)" % thaw_len)
	var outside := _ground(GRAVE.x, GRAVE.z - R3 - 4.0)
	player.global_position = outside + Vector3(0, 0.4, 0)
	await ticks(6)
	await _walk_to(_ground(GRAVE.x, GRAVE.z - R3 + 3.0), 200)
	var held := Vector2(player.global_position.x - GRAVE.x, player.global_position.z - GRAVE.z).length()
	check(held > R3 - 0.4, "a laid hedge holds whoever pushes at it (%.1f m out)" % held)
	player.global_position = clearing + Vector3(0, 0.3, 0)
	await ticks(6)
	var walked: bool = await _walk_path(grave, 500)
	check(walked and not player.dead, "the Bearer walks in through the rings to the grave")

	print("== the first rest turns the wood to rime")
	await _rest("hs_colliers_clearing")
	check(World.get_area_state("thornwold") == RH.WState.RIME, "Thornwold is rime")
	await ticks(30)
	var foes := get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead)
	check(foes.size() >= 5, "%d foes in the wood (stand-ins until the art lands)" % foes.size())
	var ids := {}
	for sp in def["spawners"]:
		ids[sp["enemy"]] = true
	check(ids.has("collier") and ids.has("rime_stag") and ids.has("hedgelayer"), "the roster's ids: collier, rime_stag, hedgelayer")
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "one veil, in the innermost ring's gap")
	var mouth := grave
	if veils.size() == 1:
		var veil: FrostVeil = veils[0]
		var boss: Node = veil.boss_spawner.current if veil.boss_spawner != null else null
		check(boss != null and boss.cfg.get("is_boss", false), "the Hedgelayer (stand-in) waits behind the veil")
		check(boss != null and String(boss.cfg.get("release_flag", "")) == "", "a stand-in never carries the borrowed holdfast's release")
		mouth = _ground(veil.global_position.x - 3.0, veil.global_position.z)

	print("== RIME: frozen thorn, the road plugged, a maze to the veil")
	var ring_pt := _ground(GRAVE.x, GRAVE.z - R3)
	check(_ray_y(ring_pt.x, ring_pt.z, ring_pt.y + 20.0) - ring_pt.y > 2.8, "the hedges have grown into walls of thorn")
	var p_rime := _path(clearing, mouth)
	check(_reaches(p_rime, mouth, 3.0), "the rime navmesh finds a way round to the veil")
	check(_len(p_rime) > thaw_len * 1.4, "the long way: the gaps have moved (%.0f m against %.0f m)" % [_len(p_rime), thaw_len])
	player.invulnerable = true
	player.global_position = clearing + Vector3(0, 0.3, 0)
	await ticks(6)
	walked = await _walk_path(mouth, 500)
	check(walked, "the Bearer walks the maze to the innermost gap")
	player.invulnerable = false

	finish()
