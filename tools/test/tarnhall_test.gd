extends TestBase
## Tarnhall (tarnhall): the fourth region, up the Tarn Steps from Kettle
## Fjord's head. One continuous seam back to the fjord; in THAW the feast is
## at full roar and the doors stand open, and the tarn is deep: the causeway
## and its plank bridge are the way over. In RIME the doors are barred from
## inside, the tarn is frozen (its cracks drown), and the way in is round by
## the byres to the Long Table, where the Host waits behind the veil. Once in,
## the bar lifts from inside: a shortcut back out to the causeway.

const HALL_IN := Vector3(192.0, 24.3, -329.0)
const PORCH := Vector3(177.0, 24.5, -330.0)
const BYRE_DOOR := Vector3(222.6, 24.3, -325.0)
const BRIDGE := Vector3(152.75, 24.25, -332.6)

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

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("tarnhall")
	add_child(area)
	Game.register_area(area, "tarnhall")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("tarnhall"))
	World.last_hearth = {"area": "tarnhall", "hearth": "hs_tarn_causeway"}
	await ticks(20)

	print("== Tarnhall")
	check(area.terrain != null and area.nav_thaw != null and area.nav_rime != null, "terrain and both navmeshes")
	check(World.get_area_state("tarnhall") == RH.WState.THAW, "first visit finds the feast in thaw")
	check(Game.find_hearth("hs_tarn_steps") != null and Game.find_hearth("hs_tarn_causeway") != null,
		"the Tarn Steps and Tarn Causeway hearths stand")
	var names := area.base.get_children().map(func(n): return String(n.name))
	check(names.has("House_hall") and names.has("House_byres"), "the great hall and the byres at its east gable")
	check(area.thaw_layer.find_children("*", "NPC", true, false).size() == 2, "Lusse and Ottar keep the thaw")
	check(player.is_on_floor(), "the Bearer stands at the foot of the Tarn Steps")

	print("== one continuous seam down to Kettle Fjord")
	var seams := area.find_children("*", "AreaPortal", true, false).filter(func(p): return p.auto)
	var down := seams.filter(func(p): return p.to_area == "kettle_fjord")
	check(down.size() == 1, "one seam down the Tarn Steps to Kettle Fjord")
	check(seams.filter(func(p): return p.to_area == "thornwold").size() == 1, "and one out by the drove-road to Thornwold")
	seams = down
	var kettle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/kettle_fjord.json"))
	var back: Array = kettle["portals"].filter(func(p): return p.get("to", "") == "tarnhall")
	check(back.size() == 1, "Kettle Fjord has the other side of it")
	if back.size() == 1 and seams.size() == 1:
		var here: Vector3 = seams[0].global_position
		var there: Vector3 = AreaBuilder._v3(back[0]["at"])
		check(here.distance_to(there) < 0.5, "both sides stand on the same ground (%.2f m apart)" % here.distance_to(there))
		var land: Vector3 = AreaBuilder._v3(back[0]["spawn"])
		check(absf(land.y - area.terrain.height_at(land.x, land.z)) < 1.5, "Kettle sets you down on Tarnhall's terrain")
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/index.json"))
	check(idx["areas"].has("tarnhall") and idx["graph"]["kettle_fjord"].has("tarnhall"), "the world graph runs Kettle Fjord -> Tarnhall")

	print("== THAW: up the steps, over the causeway, in at the open doors")
	var start := player.global_position
	var shore := Game.find_hearth("hs_tarn_causeway").respawn_point()
	check(_reaches(_path(start, shore), shore), "the Tarn Steps climb from the fjord head to the tarn shore")
	var p_in := _path(shore, HALL_IN)
	check(_reaches(p_in, HALL_IN), "the causeway and the open doors lead to the Long Table")
	check(_near_path(p_in, BRIDGE, 3.0), "over the plank bridge (the tarn is deep)")
	check(_near_path(p_in, PORCH, 4.0), "and in off the porch")
	# the hall's east door and the byre's west door are one doorway (they
	# stood 2 m apart once, each opening on the other building's wall)
	var byre_in := Vector3(221.0, 24.3, -329.0)
	var p_by := _path(HALL_IN, byre_in)
	check(_reaches(p_by, byre_in, 1.5) and _near_path(p_by, Vector3(216.3, 24.3, -329.0), 1.0) and p_by.size() > 1
		and absf(_ray_y(216.3, -329.0, 26.0) - 24.3) < 0.3, "the door at the high seat's end opens into the byre")
	check(absf(_ray_y(BRIDGE.x, BRIDGE.z, 40) - BRIDGE.y) < 0.2, "the bridge deck spans the channel")
	player.global_position = shore + Vector3(0, 0.3, 0)
	await ticks(6)
	var walked: bool = await _walk_path(HALL_IN)
	check(walked and not player.dead, "the Bearer walks the causeway and into the feast")
	var wood_seam: Node3D = area.find_children("*", "AreaPortal", true, false).filter(func(p): return p.auto and p.to_area == "thornwold")[0]
	var notch := wood_seam.global_position + Vector3(-3.0, 0, 0)
	var pn := _path(shore, notch)
	check(_reaches(pn, notch, 3.0), "the drove-road leaves the tarn's far shore (thaw: round by the shore)")
	if not _reaches(pn, notch, 3.0):
		print("    ends ", pn[pn.size() - 1] if pn.size() > 0 else Vector3.ZERO, " notch ", notch)
	player.global_position = Vector3(165.0, 22.4, -345.0)
	var died := false
	for i in 40:
		await ticks(5)
		if player.dead:
			died = true
			break
	check(died, "the tarn takes whoever falls in off the causeway")
	await _wait_respawn()
	check(not player.dead, "and a hearth gives them back")

	print("== the first rest turns Tarnhall to rime")
	await _rest("hs_tarn_causeway")
	check(World.get_area_state("tarnhall") == RH.WState.RIME, "Tarnhall is rime")
	await ticks(30)
	var foes := get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead)
	check(foes.size() >= 7, "%d foes about the hall (stand-ins until the art lands)" % foes.size())
	var ids := {}
	for sp in def["spawners"]:
		ids[sp["enemy"]] = true
	check(ids.has("feast_guest") and ids.has("cupbearer") and ids.has("hall_champion") and ids.has("host"),
		"the roster's ids: feast_guest, cupbearer, hall_champion, host")
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "one veil, at the byres' door into the hall")
	if veils.size() == 1:
		var veil: FrostVeil = veils[0]
		var boss: Node = veil.boss_spawner.current if veil.boss_spawner != null else null
		check(boss != null and boss.cfg.get("is_boss", false), "the Host waits behind the veil")
		check(boss != null and boss is Host and String(boss.cfg.get("release_flag", "")) == "ks_host_released",
			"the Host himself, no stand-in, with his own release")

	print("== RIME: the doors barred, the way round by the byres")
	var gate: ShortcutGate = area.rime_layer.find_children("*", "ShortcutGate", true, false)[0]
	player.global_position = PORCH + Vector3(-0.5, 0.3, 1.0)
	await ticks(8)
	var it := player.nearest_interactable()
	check(it != null and it.prompt == "Barred from the inside", "the hall doors are barred from the inside")
	var mouth: Vector3 = veils[0].global_position + Vector3(3.0, 0, 0) if veils.size() > 0 else HALL_IN
	var p_rime := _path(PORCH, mouth)
	check(_reaches(p_rime, mouth, 3.0) and _near_path(p_rime, BYRE_DOOR, 3.0), "the rime navmesh goes round by the byres to the veil")
	check(absf(_ray_y(165.0, -345.0, 40) - 22.05) < 0.2, "ice over the tarn")
	var crack := Vector3(156.0, 22.4, -344.0)
	player.global_position = crack + Vector3(0, 0, 3.0)
	await ticks(6)
	await _walk_to(crack, 200, 0.3)
	await ticks(90)
	check(player.dead, "a crack in the tarn ice takes the Bearer")
	await _wait_respawn()
	check(not player.dead and World.get_area_state("tarnhall") == RH.WState.RIME, "back at the hearth, still rime")
	player.invulnerable = true
	player.global_position = PORCH + Vector3(0, 0.3, 4.0)
	await ticks(6)
	walked = await _walk_path(BYRE_DOOR + Vector3(0, 0, 2.0))
	check(walked, "round the hall to the cattle door")
	walked = await _walk_path(HALL_IN)
	check(walked, "through the byres and into the Long Table")
	player.global_position = gate.global_position + gate.global_transform.basis.z * -1.3 + Vector3(0, 0.3, 0)
	await ticks(8)
	it = player.nearest_interactable()
	check(it != null and it.prompt == "Unbar the gate", "from inside, the bar lifts")
	if it != null:
		it.activate(player)
	await ticks(30)
	check(World.area_flag("tarnhall", "gate_hall_doors"), "the doors stand open for good (a shortcut to the causeway)")
	player.invulnerable = false

	finish()
