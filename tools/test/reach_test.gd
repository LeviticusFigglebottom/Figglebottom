extends TestBase
## Shepherd's Reach (shepherds_reach): high pasture under the glacier, up the
## fell path from Thornwold; the Upwater to the Coldwell leaves its far corner.
## THAW: the flocks on the grass, the beck deep in its cut (it drowns): over
## by the plank bridge. RIME: the beck frozen (cross anywhere), the flock
## frozen on the slope facing the High Fold; the Fellcaller behind the veil in
## the fold's gap.

const FOLD := Vector3(660.0, 0.0, -372.0)
const FOLD_R := 13.0
const GAP_A := 135.0
const BRIDGE_X := 618.0

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

func _beck_z(x: float) -> float:
	return -334.0 + 7.0 * sin(x * 0.03 + 0.6)

func _kits(layer: Node, id: String) -> Array:
	return layer.find_children("*", "Node3D", true, false).filter(func(n): return n.get_meta("kit_id", "") == id)

func _seam_check(seams: Array, other_id: String, label: String) -> void:
	var other: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/%s.json" % other_id))
	var back: Array = other["portals"].filter(func(p): return p.get("to", "") == "shepherds_reach")
	var mine: Array = seams.filter(func(p): return p.to_area == other_id)
	check(back.size() == 1 and mine.size() == 1, "%s: a seam on both sides" % label)
	if back.size() == 1 and mine.size() == 1:
		var d: float = mine[0].global_position.distance_to(AreaBuilder._v3(back[0]["at"]))
		check(d < 0.5, "%s: both sides stand on the same ground (%.2f m apart)" % [label, d])

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("shepherds_reach")
	add_child(area)
	Game.register_area(area, "shepherds_reach")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("shepherds_reach"))
	World.last_hearth = {"area": "shepherds_reach", "hearth": "hs_sheilings"}
	await ticks(20)

	print("== Shepherd's Reach")
	check(area.terrain != null and area.nav_thaw != null and area.nav_rime != null, "terrain and both navmeshes")
	check(World.get_area_state("shepherds_reach") == RH.WState.THAW, "first visit finds the pasture in thaw")
	check(Game.find_hearth("hs_fell_path") != null and Game.find_hearth("hs_sheilings") != null, "the Fell Path and Sheilings hearths stand")
	check(area.thaw_layer.find_children("*", "NPC", true, false).size() == 2, "Old Calder and Sigga keep the thaw")
	var flock := _kits(area.thaw_layer, "sheep")
	check(flock.size() >= 30, "the flocks on the high grass (%d)" % flock.size())
	check(player.is_on_floor(), "the Bearer stands on the fell path")

	print("== seams: down to Thornwold, up to the Coldwell")
	var seams := area.find_children("*", "AreaPortal", true, false).filter(func(p): return p.auto)
	check(seams.size() == 2, "two seams")
	_seam_check(seams, "thornwold", "the fell path")
	_seam_check(seams, "coldwell", "the Upwater")
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/index.json"))
	check(idx["areas"].has("shepherds_reach") and idx["graph"]["thornwold"].has("shepherds_reach") and idx["graph"]["shepherds_reach"].has("coldwell"),
		"the world graph runs Thornwold -> Shepherd's Reach -> the Coldwell")

	print("== THAW: up the fell path, over the bridge, to the High Fold")
	var start := player.global_position
	var sheil := Game.find_hearth("hs_sheilings").respawn_point()
	check(_reaches(_path(start, sheil), sheil), "the fell path climbs to the Sheilings")
	var out := Vector3(cos(deg_to_rad(GAP_A)), 0, sin(deg_to_rad(GAP_A)))
	var mouth := _ground(FOLD.x + out.x * (FOLD_R + 3.0), FOLD.z + out.z * (FOLD_R + 3.0))
	var p_thaw := _path(sheil, mouth)
	check(_reaches(p_thaw, mouth, 3.0), "a way to the High Fold's gap")
	check(_near_path(p_thaw, Vector3(BRIDGE_X, 0, _beck_z(BRIDGE_X)), 3.0), "over the plank bridge: the beck is deep")
	player.global_position = _ground(600.0, _beck_z(600.0)) + Vector3(0, 0.3, 0)
	var died := false
	for i in 40:
		await ticks(5)
		if player.dead:
			died = true
			break
	check(died, "the beck takes whoever falls in")
	await _wait_respawn()
	check(not player.dead, "and a hearth gives them back")

	print("== the first rest turns the Reach to rime")
	await _rest("hs_sheilings")
	check(World.get_area_state("shepherds_reach") == RH.WState.RIME, "the Reach is rime")
	await ticks(30)
	var foes := get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead)
	check(foes.size() >= 6, "%d foes on the pasture" % foes.size())
	var ids := {}
	for sp in def["spawners"]:
		ids[sp["enemy"]] = true
	check(ids.has("drover") and ids.has("frost_ram") and ids.has("fellcaller"), "the roster's ids: drover, frost_ram, fellcaller")
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "one veil, in the fold's gap")
	if veils.size() == 1:
		var veil: FrostVeil = veils[0]
		var boss: Node = veil.boss_spawner.current if veil.boss_spawner != null else null
		check(boss is Fellcaller and boss.cfg.get("is_boss", false), "the Fellcaller waits behind the veil")
		check(boss != null and String(boss.cfg.get("release_flag", "")) == "ks_fellcaller_released", "on her own row now, with her own release")
	var frozen := _kits(area.rime_layer, "sheep")
	check(frozen.size() >= 50, "a whole slope of white sheep (%d)" % frozen.size())
	var facing := 0
	for sh in frozen:
		var n: Node3D = sh
		var to := Vector3(FOLD.x - n.global_position.x, 0, FOLD.z - n.global_position.z).normalized()
		var fwd := -n.global_transform.basis.z
		fwd.y = 0
		if fwd.normalized().dot(to) > 0.95:
			facing += 1
	check(facing >= frozen.size() - 1, "all facing the High Fold (%d of %d)" % [facing, frozen.size()])
	var bz := _beck_z(600.0)
	check(_ray_y(600.0, bz, 120.0) > area.terrain.height_at(600.0, bz) + 1.5, "the beck frozen to the brim")
	var p_rime := _path(sheil, mouth)
	check(_reaches(p_rime, mouth, 3.0), "the rime navmesh winds between the frozen flock to the fold")
	player.invulnerable = true
	player.global_position = sheil + Vector3(0, 0.3, 0)
	await ticks(6)
	var walked: bool = await _walk_path(mouth, 500)
	check(walked, "the Bearer walks up through the flock to the fold's gap")
	if not walked:
		print("   stuck at ", player.global_position, " dead=", player.dead)
	player.invulnerable = false

	finish()
