extends TestBase
## The Coldwell (coldwell): the last area. The Upwater, a long, quiet climb
## along the mountain's shoulder beside the river, the land falling away
## behind toward every region; the Wellhead: a ring of stones round the spring
## under the glacier. THAW: the last Melt, Maren and Wren at the water.
## RIME: the unsung dead in the frozen river, the Leadvoice behind the veil.
## The `ending_choice` hook waits at the spring for her release.

const WELL := Vector3(922.0, 0.0, -478.0)

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
	area = AreaBuilder.build("coldwell")
	add_child(area)
	Game.register_area(area, "coldwell")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("coldwell"))
	World.last_hearth = {"area": "coldwell", "hearth": "hs_upwater"}
	await ticks(20)

	print("== the Coldwell")
	check(area.terrain != null and area.nav_thaw != null and area.nav_rime != null, "terrain and both navmeshes")
	check(World.get_area_state("coldwell") == RH.WState.THAW, "first visit finds the last Melt")
	for h in ["hs_upwater", "hs_ice_falls", "hs_wellhead_steps"]:
		check(Game.find_hearth(h) != null, "the hearth %s stands" % h)
	check(area.thaw_layer.find_children("*", "NPC", true, false).size() == 2, "Maren and Wren at the water")
	check(player.is_on_floor(), "the Bearer stands at the foot of the Upwater")
	var ec_list := get_tree().get_nodes_in_group("ending_choice")
	check(ec_list.size() == 1, "the ending_choice hook stands at the spring")

	print("== one continuous seam back down to the Reach")
	var seams := area.find_children("*", "AreaPortal", true, false).filter(func(p): return p.auto)
	check(seams.size() == 1 and seams[0].to_area == "shepherds_reach", "a single seam: this is the end of the water")
	var reach: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/areas/shepherds_reach.json"))
	var back: Array = reach["portals"].filter(func(p): return p.get("to", "") == "coldwell")
	check(back.size() == 1, "the Reach has the other side of it")
	if back.size() == 1 and seams.size() == 1:
		var d: float = seams[0].global_position.distance_to(AreaBuilder._v3(back[0]["at"]))
		check(d < 0.5, "both sides stand on the same ground (%.2f m apart)" % d)

	print("== the Upwater: long, quiet, climbing; every region below")
	var start := player.global_position
	var top := Game.find_hearth("hs_wellhead_steps").respawn_point()
	var p_up := _path(start, top)
	check(_reaches(p_up, top), "the Upwater climbs from the Reach to the Wellhead")
	check(_len(p_up) > 200.0, "a long way up (%.0f m)" % _len(p_up))
	check(top.y - start.y > 60.0, "and a high one (%.0f m of climb)" % (top.y - start.y))
	var lows := 0
	for k in range(1, p_up.size()):
		if p_up[k].y < p_up[k - 1].y - 1.0:
			lows += 1
	check(lows <= 2, "it climbs all the way (%d dips)" % lows)
	var on_way := 0
	for sp in def["spawners"]:
		if AreaBuilder._v3(sp["at"]).distance_to(_ground(WELL.x, WELL.z)) > 30.0:
			on_way += 1
	check(on_way <= 4, "a quiet climb: few foes on the way (%d)" % on_way)
	var tb: Dictionary = def["terrain"]
	var fo: Array = tb["far_origin"]
	var fspan := float(tb["far_cell"]) * (float(tb["far_size"]) - 1.0)
	check(float(fo[0]) < -100.0 and float(fo[0]) + fspan > 960.0, "the far land spans the whole country, the coast to the glacier")
	var eye := top + Vector3(0, 1.7, 0)
	var dirv := Vector3(-0.92, -0.12, 0.37).normalized()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dirv * 160.0, RH.M_WORLD_ALL)
	var hit := area.get_world_3d().direct_space_state.intersect_ray(q)
	check(hit.is_empty(), "looking back down the water, nothing near stands in the way")
	print("   walking the Upwater...")
	player.invulnerable = true
	var walked: bool = await _walk_path(top, 600)
	check(walked, "the Bearer walks the whole Upwater to the Wellhead Steps")
	player.invulnerable = false

	print("== the first rest turns the Coldwell to rime")
	await _rest("hs_wellhead_steps")
	check(World.get_area_state("coldwell") == RH.WState.RIME, "the Coldwell is rime")
	await ticks(30)
	var foes := get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead)
	check(foes.size() >= 5, "%d frost-taken" % foes.size())
	var ids := {}
	for sp in def["spawners"]:
		ids[sp["enemy"]] = true
	check(ids.has("upwalker") and ids.has("unsung") and ids.has("leadvoice"), "the roster's ids: upwalker, unsung, leadvoice")
	var dead := 0
	for lm in def["landmarks"]:
		if lm.get("tag", "") == "rime" and String(lm["scene"]).contains("/enemies/"):
			dead += 1
	check(dead >= 10, "the unsung dead stand in the frozen river (%d)" % dead)
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "one veil, in the ring's gap")
	if veils.size() == 1:
		var veil: FrostVeil = veils[0]
		var boss: Node = veil.boss_spawner.current if veil.boss_spawner != null else null
		check(boss is Leadvoice and boss.cfg.get("is_boss", false), "the Leadvoice waits behind the veil")
		check(boss != null and String(boss.cfg.get("release_flag", "")) == "ks_leadvoice_released", "on her own row now, with her own release")
		var mouth := _ground(veil.global_position.x - 3.0, veil.global_position.z)
		check(_reaches(_path(start, mouth), mouth, 3.0), "the rime Upwater still climbs to the veil")

	print("== the ending hook")
	if ec_list.size() == 1:
		var ec: Node = ec_list[0]
		check(not ec.is_open(), "dormant until she is released")
		var got := []
		ec.run_endings = false   # (the hook only: the endings have their own suite)
		ec.chosen.connect(func(e): got.append(e))
		ec.enable()
		check(ec.is_open() and World.flag("ks_leadvoice_released"), "open once she is released")
		ec.choose("hearth_kept")
		check(got == ["hearth_kept"] and World.flag("ending_hearth_kept"), "choosing sets ending_hearth_kept and says so")
		ec.choose("outsong")
		check(got.size() == 1 and not World.flag("ending_outsong"), "and the choice is made once")

	finish()
