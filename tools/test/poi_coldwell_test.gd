extends TestBase
## The Coldwell's points of interest (docs/lore/POI.md 8): the Flower Bank,
## the Shelter at the Ice-Falls and the Sitting Place on their three ledges
## beside the Upwater, and the Thread-Post on the wellhead's level. The boards
## read in both states, the flowers are picked and thrown in beside Maren and
## Wren (the "Melt flowers" thread), the walker in the shelter sits until the
## Bearer comes, and the ledges are level ground that can be walked on and off.

var area: Area
var player: Player
var def: Dictionary
var _read := ""

func _ready() -> void:
	_run.call_deferred()

func _build(state: RH.WState) -> void:
	if area != null:
		area.queue_free()
		player.queue_free()
		await ticks(4)
	World.set_area_state("coldwell", state)
	area = AreaBuilder.build("coldwell")
	add_child(area)
	Game.register_area(area, "coldwell")
	player = Player.new()
	add_child(player)
	def = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	StateDirector.snap(area, state)
	await ticks(60)        # (both navmeshes bake off the main thread: give them time on a loaded box)

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

func _spec(list: String, id: String) -> Dictionary:
	for p in def[list]:
		if String(p.get("id", "")) == id:
			return p
	return {}

func _pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id and not p.is_queued_for_deletion():
			return p
	return null

func _let_go() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.lore_root.visible = false
		hud.lore_root.remove_from_group("lore_open")
	player.lock_control(false)

func _board(prefix: String, tag: String) -> Dictionary:
	for b in def["plaques"]:
		if String(b["text"]).begins_with(prefix) and String(b.get("tag", "base")) == tag:
			return b
	return {}

func _read_board(prefix: String, tag: String) -> String:
	_read = ""
	var b := _board(prefix, tag)
	if b.is_empty():
		return ""
	var at := AreaBuilder._v3(b["at"])
	for n in area.find_children("*", "LorePlaque", true, false):
		var p := n as LorePlaque
		if p.global_position.distance_to(at) < 0.3 and p.is_visible_in_tree():
			for z in p.find_children("*", "Interactable", true, false):
				(z as Interactable).activate(player)
	_let_go()
	return _read

func _foe(id: String) -> Enemy:
	for n in area.find_children("*", "Spawner", true, false):
		if (n as Spawner).spawn_id == id:
			return (n as Spawner).current
	return null

func _prop(kit: String, tag: String) -> Dictionary:
	for p in def["props"]:
		if String(p["kit"]) == kit and String(p.get("tag", "base")) in ["base", tag]:
			return p
	return {}

func _bump(at: Vector3, reach: float) -> String:
	for k in 8:
		var dir := Vector3(sin(k * PI / 4.0), 0, cos(k * PI / 4.0))
		var from := at + dir * (reach + 1.6)
		if absf(_ray_y(from.x, from.z, at.y + 2.2) - at.y) > 0.35 or absf(_ray_y(at.x + dir.x * (reach + 0.8), at.z + dir.z * (reach + 0.8), at.y + 2.2) - at.y) > 0.35:
			continue
		player.global_position = from + Vector3(0, 0.25, 0)
		player.velocity = Vector3.ZERO
		await ticks(4)
		await _walk_to(at, 260, 0.25)
		var d := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
		if player.dead:
			return "the Bearer died on the way in"
		return "" if d > 0.3 else "walked through it"
	return "no ground beside it to walk in from"

func _bump_all(state_tag: String) -> void:
	var seen := {}
	for p in def["props"]:
		var kit := String(p["kit"])
		var tag := String(p.get("tag", "base"))
		if not kit.begins_with("cw_") or kit == "cw_shelter" or not p.get("collide", true) or not (tag in ["base", state_tag]):
			continue
		seen[kit] = int(seen.get(kit, 0)) + 1
		if int(seen[kit]) > 2:
			continue
		var size: Array = KitLib.manifest()[kit]["size"]
		var why: String = await _bump(AreaBuilder._v3(p["at"]), minf(float(size[0]), float(size[1])) * 0.5)
		check(why == "", "%s at (%.0f, %.0f) is solid%s" % [kit, p["at"][0], p["at"][2], "" if why == "" else ": " + why])

## A ledge is level ground: rays over a spread of points round `mid`.
func _level(mid: Vector3, r: float) -> float:
	var ys: Array = []
	for k in 6:
		ys.append(_ray_y(mid.x + cos(k * PI / 3.0) * r, mid.z + sin(k * PI / 3.0) * r, mid.y + 1.6))
	return ys.max() - ys.min()

func _run() -> void:
	World._save_dir = "user://test_poi_coldwell"
	World.reset()
	Game.set_warmth(0)
	Game.lore_panel.connect(func(t): _read = String(t))
	await _build(RH.WState.THAW)
	add_child(HUD.new())
	var start := player.global_position
	var steps_h := Game.find_hearth("hs_wellhead_steps").respawn_point()

	print("== 8.1 the Flower Bank (THAW)")
	var fl := _pickup("melt_flowers")
	var fl_at := AreaBuilder._v3(_spec("pickups", "melt_flowers")["at"])
	check(fl != null and fl.label == "Pick a bunch", "a bunch to pick on the bank")
	check(_level(fl_at, 1.2) < 0.4, "the ledge is level (%.2f m)" % _level(fl_at, 1.2))
	check(_reaches(_path(start, fl_at), fl_at), "the path reaches it")
	check(not _prop("cw_flower_basket", "thaw").is_empty(), "somebody's basket is put down there")
	var give: Offering = null
	for n in area.find_children("*", "", true, false):
		if n is Offering:
			give = n
	check(give != null and not give.can_give(), "nothing to throw in without the flowers")
	if fl != null:
		fl._on_take(player)
	check(int(player.inventory.get("item_melt_flowers", 0)) == 1, "the bunch is picked")
	if give != null:
		var maren: Vector3 = AreaBuilder._v3(_spec("npcs", "maren")["at"])
		check(give.global_position.distance_to(maren) < 4.0, "the place to throw them is beside Maren and Wren")
		check(give.can_give() and give.prompt == "Throw them in", "carrying them: Throw them in")
		player.global_position = give.global_position + Vector3(0, 0.2, 0.5)
		await ticks(4)
		give._zone.activate(player)
		check(World.flag("ks_melt_flowers") and int(player.inventory.get("item_melt_flowers", 0)) == 0, "thrown in: ks_melt_flowers, and the bunch is gone")
		var said := ""
		for hud in get_tree().get_nodes_in_group("hud"):
			said = hud.overheard_label.text
		check(said == "Wren: And that one.", "Wren says her own line (%s)" % said)
		check(not give.can_give(), "it is done once")
	var lines: Array = []
	for t in Keepsakes.journal():
		if t["id"] == "melt_flowers":
			lines = t["lines"]
	check(lines == ["The flowers went down the water. Wren watched them out of sight."], "the journal has the Melt flowers thread")

	print("== 8.2 the Shelter at the Ice-Falls (THAW)")
	var sh: Dictionary = _prop("cw_shelter", "thaw")
	var sh_at := AreaBuilder._v3(sh["at"])
	var yaw := deg_to_rad(float(sh["rot"]))
	var front := Vector3(sin(yaw), 0, cos(yaw))
	var apron := sh_at + front * 2.0
	check(_level(apron, 0.8) < 0.4, "the ledge is level before the shelter (%.2f m)" % _level(apron, 0.8))
	check(_read_board("THE ICE-FALLS", "thaw").contains("The rack is nearly empty. Everyone is up at the water."), "THAW board reads")
	check(not _prop("cw_staff_rack", "thaw").is_empty() and def["props"].filter(func(p): return p["kit"] == "cw_staff_heap" and p.get("tag") != "rime").is_empty(),
		"four sticks on the rack, none on the ground")
	var falls_h := Game.find_hearth("hs_ice_falls").respawn_point()
	check(_reaches(_path(falls_h, sh_at), sh_at, 3.0), "a step off the path from the Ice-Falls hearth")
	# in under the roof and out again: the shelter's shell is real, and open at the front
	player.global_position = sh_at + front * 3.4 + Vector3(0, 0.3, 0)
	await ticks(6)
	var went_in: bool = await _walk_to(sh_at + front * 0.3, 400, 0.6)
	check(went_in, "the Bearer walks in at the open front")
	await _walk_to(sh_at - front * 4.0, 200, 0.5)
	check((player.global_position - sh_at).dot(-front) < 1.9, "and the back wall stops him")
	player.global_position = falls_h + Vector3(0, 0.3, 0)
	await ticks(6)
	var on_up := true
	for wp in _path(falls_h, steps_h):
		if on_up and not await _walk_to(wp, 1500, 1.0):
			on_up = false
	check(on_up and not player.dead, "the path past the shelter and the rail is not cut: on up to the Wellhead Steps")
	if not on_up:
		print("    stopped at ", player.global_position)

	print("== 8.3 the Sitting Place (THAW)")
	var bench := AreaBuilder._v3(_prop("cw_slab_bench", "thaw")["at"])
	check(_level(bench, 1.4) < 0.45, "the ledge is level (%.2f m)" % _level(bench, 1.4))
	check(_reaches(_path(steps_h, bench), bench, 3.0), "a step off the path above the hearth")
	check(_read_board("THE WELLHEAD STEPS", "thaw").contains("Children are carried the last part, so they see it all at once."), "THAW board reads")
	check(def["props"].filter(func(p): return p["kit"] == "cw_rope_rail" and AreaBuilder._v3(p["at"]).distance_to(bench) < 5.0).size() == 3,
		"railed on its open sides")
	# off the ledge's open end and back: no trap (the audit says so too)
	player.global_position = bench + Vector3(0, 0.4, 0)
	await ticks(6)
	var back: bool = await _walk_to(steps_h, 900, 1.6)
	check(back, "from the bench back to the hearth")

	print("== 8.4 the Thread-Post (THAW)")
	var post := AreaBuilder._v3(_prop("cw_thread_post", "thaw")["at"])
	var veil := AreaBuilder._v3(def["frost_veils"][0]["at"])
	check(post.distance_to(veil) >= 10.0, "the post stands %.1f m from the frost veil" % post.distance_to(veil))
	check(_read_board("THE WELLHEAD\n", "thaw").contains("Blue, red and yellow. Eleven. It was a mild winter."), "THAW board reads")
	check(_reaches(_path(steps_h, post), post, 3.0), "on the level between the two houses")
	check(not _prop("cw_dipper_trough", "thaw").is_empty(), "the dipper trough stands at the spring's overflow")

	print("== THAW: the set's solid props stop the Bearer")
	await _bump_all("thaw")

	print("== RIME")
	await _build(RH.WState.RIME)
	check(_pickup("melt_flowers") == null or not _pickup("melt_flowers").is_visible_in_tree(), "8.1 no flowers under the snow")
	var holder: Array = def["landmarks"].filter(func(l): return String(l["scene"]).contains("upwalker") and l.has("scale") and l.get("tag") == "rime")
	check(holder.size() == 1 and not _prop("cw_flower_bunch", "rime").is_empty(), "8.1 one of the standing dead in the river holds a bunch")
	check(_read_board("THE ICE-FALLS", "rime").contains("Nobody has wanted one going down."), "8.2 RIME board reads")
	check(not _prop("cw_staff_rack_full", "rime").is_empty()
		and def["props"].filter(func(p): return p["kit"] == "cw_staff_heap" and p.get("tag") == "rime").size() == 3, "8.2 the rack full, and more about the shelter")
	var sitter := _foe("upwalker_falls")
	check(sitter != null, "8.2 the walker that got this far is in the shelter")
	if sitter != null:
		check(sitter.global_position.distance_to(sh_at) < 2.6 and sitter.idle_pose == "sit" and not sitter._risen, "8.2 seated on the bench")
		check(is_equal_approx(float(sitter.cfg.get("rise_time", 0)), 2.4), "8.2 slow to rise (2.4 s, this place's own)")
		check(not is_equal_approx(float(DB.table("enemies")["upwalker"].get("rise_time", 1.8)), 2.4), "8.2 (the roster's own rise is untouched)")
		player.global_position = sh_at + front * 3.6 + Vector3(0, 0.3, 0)
		var w := 0
		while sitter.state == Enemy.ES.IDLE and w < 400:
			w += 10
			await ticks(10)
		check(sitter.state != Enemy.ES.IDLE, "8.2 it gets up when the Bearer comes")
		sitter.take_hit(DamagePacket.new(99999, 0, player))
		await ticks(6)
	check(_read_board("THE WELLHEAD STEPS", "rime").contains("The snow on this bench has been sat in, at the left end only."), "8.3 RIME board reads")
	check(not _prop("cw_slab_bench_snow", "rime").is_empty(), "8.3 the bench under snow")
	check(_read_board("THE WELLHEAD\n", "rime").contains("The same eleven threads, white with frost."), "8.4 RIME board reads")
	steps_h = Game.find_hearth("hs_wellhead_steps").respawn_point()
	check(_reaches(_path(AreaBuilder._v3(def["start"]["pos"]), veil), veil, 4.0), "the Upwater still runs from the seam to the frost veil")
	print("== RIME: the set's solid props stop the Bearer")
	await _bump_all("rime")
	finish()
