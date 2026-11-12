extends TestBase
## Tarnhall's points of interest (docs/lore/POI.md 5): the Seven Landings on
## the south shore, the Porch, the Cook-Yard on its terrace behind the hall,
## and the South Window on the walk along the south wall. The boards read,
## the finds can be taken, the overheard exchanges play, the look through the
## window is held and given back, and Ottar's thread takes its new step.

var area: Area
var player: Player
var def: Dictionary
var _read := ""
var _heard: Array = []

func _ready() -> void:
	_run.call_deferred()

func _build(state: RH.WState) -> void:
	if area != null:
		area.queue_free()
		player.queue_free()
		await ticks(4)
	World.set_area_state("tarnhall", state)
	area = AreaBuilder.build("tarnhall")
	add_child(area)
	Game.register_area(area, "tarnhall")
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

func _read_board(at: Vector3) -> String:
	_read = ""
	for n in area.find_children("*", "LorePlaque", true, false):
		var p := n as LorePlaque
		if p.global_position.distance_to(at) < 0.3 and p.is_visible_in_tree():
			for z in p.find_children("*", "Interactable", true, false):
				(z as Interactable).activate(player)
	_let_go()
	return _read

func _talk(npc_id: String) -> DialogueUI:
	var cfg := DB.npc(npc_id)
	cfg["id"] = npc_id
	var ui := DialogueUI.new(cfg, null)
	get_tree().root.add_child(ui)
	return ui

func _npc(id: String) -> NPC:
	for n in area.find_children("*", "NPC", true, false):
		if (n as NPC).npc_id == id:
			return n
	return null

func _foe(id: String) -> Enemy:
	for n in area.find_children("*", "Spawner", true, false):
		if (n as Spawner).spawn_id == id:
			return (n as Spawner).current
	return null

## Stand by a soul with something to be overheard and collect what is said.
func _overhear(id: String, lines: int) -> Array:
	_heard = []
	var n := _npc(id)
	if n == null:
		return []
	n.overheard.connect(func(_who, line): _heard.append(String(line)))
	n.cfg["overhear_every"] = 0.1
	player.global_position = n.global_position + Vector3(1.5, 0.2, 1.5)
	var w := 0
	while _heard.size() < lines and w < 600:
		w += 5
		await ticks(5)
	return _heard

## Walk the Bearer at a solid prop from whichever side has ground to stand on:
## it must stop him short of its middle. -> "" or what went wrong.
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

func _bump_all(prefix: String, state_tag: String) -> void:
	var seen := {}
	for p in def["props"]:
		var kit := String(p["kit"])
		var tag := String(p.get("tag", "base"))
		if not kit.begins_with(prefix) or not p.get("collide", true) or not (tag in ["base", state_tag]):
			continue
		seen[kit] = int(seen.get(kit, 0)) + 1
		if int(seen[kit]) > 2:
			continue
		var size: Array = KitLib.manifest()[kit]["size"]
		var why: String = await _bump(AreaBuilder._v3(p["at"]), minf(float(size[0]), float(size[1])) * 0.5)
		check(why == "", "%s at (%.0f, %.0f) is solid%s" % [kit, p["at"][0], p["at"][2], "" if why == "" else ": " + why])

func _board(prefix: String, tag: String) -> Dictionary:
	for b in def["plaques"]:
		if String(b["text"]).begins_with(prefix) and String(b.get("tag", "base")) == tag:
			return b
	return {}

func _run() -> void:
	World._save_dir = "user://test_poi_tarnhall"
	World.reset()
	Game.set_warmth(0)
	Game.lore_panel.connect(func(t): _read = String(t))
	await _build(RH.WState.THAW)
	add_child(HUD.new())
	var fy: float = float(_spec("houses", "hall")["y"])
	var causeway_h := Game.find_hearth("hs_tarn_causeway").respawn_point()
	var byres_h := Game.find_hearth("hs_byres").respawn_point()

	print("== 5.1 the Seven Landings (THAW)")
	var boats: Array = def["props"].filter(func(p): return p["kit"] == "boat" and p.get("tag") == "thaw")
	check(boats.size() == 7, "seven boats at the shore (%d)" % boats.size())
	var oars: Array = def["props"].filter(func(p): return p["kit"] == "th_boat_oars" and p.get("tag") == "thaw")
	check(oars.size() == 1, "one has its oars left in")
	for b in boats:
		var cd: float = _causeway_d(float(b["at"][0]), float(b["at"][2]))
		if cd < 6.0:
			check(false, "a boat lies within %.1f m of the causeway" % cd)
	var said: Array = await _overhear("landing_guest_a", 5)
	check(said.size() >= 5 and said[0] == "Is that the goat one? They've not got far." and said[4] == "Last year there was no fish.",
		"the two late guests are overheard (%d lines)" % said.size())
	var ga := _npc("landing_guest_a")
	check(ga != null and _reaches(_path(causeway_h, ga.global_position), ga.global_position), "and can be walked up to from the hearth")
	check(ga != null and ga.find_children("*", "Interactable", true, false).is_empty(), "nobody there can be spoken to")
	var across := _path(causeway_h, Vector3(180.0, fy, -329.0))
	check(_reaches(across, Vector3(180.0, fy, -329.0), 3.5), "the causeway is still the way over")

	print("== 5.2 the Porch (THAW)")
	check(_pickup("rowan_stick") == null or not _pickup("rowan_stick").is_visible_in_tree(), "no stick on the porch in THAW")
	var door := Vector3(179.0, fy + 0.2, -329.0)
	for p in def["props"] + def["landmarks"]:
		if String(p.get("tag", "base")) != "rime" and p.get("collide", true) and p.has("kit") and String(p["kit"]).begins_with("th_"):
			if Vector2(float(p["at"][0]) - door.x, float(p["at"][2]) - door.z).length() < 1.2:
				check(false, "%s stands in front of the doors" % p["kit"])
	player.global_position = Vector3(176.5, fy + 0.5, -329.0)
	await ticks(6)
	var inside: bool = await _walk_to(Vector3(182.5, fy, -329.0), 500)
	check(inside, "THAW: in off the porch through the open doors")

	print("== 5.3 the Cook-Yard (THAW)")
	var vat: Dictionary = def["props"].filter(func(p): return p["kit"] == "th_ale_vat")[0]
	var vat_at := AreaBuilder._v3(vat["at"])
	check(absf(_ray_y(vat_at.x - 3.5, vat_at.z + 2.8, fy + 3.0) - fy) < 0.2, "the terrace floor is at the island's level")
	check(_ray_y(vat_at.x, -348.6, fy + 3.0) < fy - 2.0, "its north face drops sheer to the tarn")
	var cook := _npc("cook_a")
	check(cook != null and _reaches(_path(byres_h, cook.global_position), cook.global_position, 3.0),
		"a walk from the byre yard round the hall's north-east corner")
	said = await _overhear("cook_a", 5)
	check(said.size() >= 5 and said[0] == "He's sent back for more. Again." and said[4] == "Then he'll want it kept hot for them.",
		"the two cooks are overheard (%d lines)" % said.size())
	check(_pickup("vat_dipper") == null or not _pickup("vat_dipper").is_visible_in_tree(), "no dipper to take in THAW")
	player.global_position = byres_h + Vector3(0, 0.3, 0)
	await ticks(6)
	var walked: bool = await _walk_route([Vector3(233.5, 0, -324.0), Vector3(233.5, 0, -338.2), Vector3(216.5, 0, -338.6), Vector3(211.0, 0, -341.6)])
	check(walked and not player.dead, "the Bearer walks it: yard, east end, the 3 m walk, the terrace")
	if not walked:
		print("    stopped at ", player.global_position)

	print("== 5.4 the South Window (THAW)")
	var looks := area.find_children("*", "", true, false).filter(func(n): return n is LookIn and n.is_visible_in_tree())
	check(looks.size() == 1, "one place to look in, in this state (%d)" % looks.size())
	if looks.size() == 1:
		var li := looks[0] as LookIn
		check(li.caption == "They are on the ninth verse. The high seat is empty." and li.prompt == "Look in", "THAW caption and prompt")
		check(_reaches(_path(Vector3(177.0, fy, -321.5), li.global_position), li.global_position, 2.0), "the walk runs from the porch's end to the window")
		check(_reaches(_path(li.global_position, byres_h), byres_h), "and on to the byre yard")
		li.seconds = 0.6
		player.global_position = li.global_position + Vector3(0, 0.2, 0.8)
		await ticks(4)
		for z in li.find_children("*", "Interactable", true, false):
			(z as Interactable).activate(player)
		await ticks(4)
		check(li.looking and not player.input_enabled and get_viewport().get_camera_3d().get_parent() == li, "the look is held: the eye is at the pane")
		var w := 0
		while li.looking and w < 300:
			w += 5
			await ticks(5)
		check(not li.looking and player.input_enabled, "then control comes back")
	var ys: Array = []
	var x := 177.0
	while x <= 230.0:
		ys.append(_ray_y(x, -321.5, fy + 2.0))
		x += 3.0
	check(ys.max() - ys.min() < 0.35, "the walk is level from the porch to the byre yard (%.2f m)" % (ys.max() - ys.min()))
	player.global_position = Vector3(177.2, fy + 0.4, -321.4)
	await ticks(6)
	walked = await _walk_route([Vector3(190.0, 0, -321.3), Vector3(214.0, 0, -321.3), byres_h], 900)
	check(walked and not player.dead, "the Bearer walks the south wall from the porch to the byres")
	if not walked:
		print("    stopped at ", player.global_position)

	print("== THAW: the set's solid props stop the Bearer")
	await _bump_all("th_", "thaw")

	print("== RIME")
	await _build(RH.WState.RIME)
	byres_h = Game.find_hearth("hs_byres").respawn_point()
	var lb := _board("THE TARN CAUSEWAY", "rime")
	check(_read_board(AreaBuilder._v3(lb["at"])).contains("One was left ready to go, with the oars in."), "5.1 the landing's board reads")
	check(def["props"].filter(func(p): return p["kit"] == "boat" and p.get("tag") == "rime").size() == 7
		and def["props"].filter(func(p): return p["kit"] == "th_boat_oars" and p.get("tag") == "rime").size() == 1,
		"5.1 the same seven in the ice, the oars still in the one")
	var stick := _pickup("rowan_stick")
	check(stick != null and stick.label == "Take the stick", "5.2 the rowan stick leans by the barred doors")
	if stick != null:
		var s_at := stick.global_position
		var to_stick := _path(Game.find_hearth("hs_tarn_causeway").respawn_point(), s_at)
		check(_reaches(to_stick, s_at), "5.2 and can be walked to")
		if not _reaches(to_stick, s_at):
			print("    path ends at ", to_stick[to_stick.size() - 1] if to_stick.size() > 0 else "nowhere", " for ", s_at)
		stick._on_take(player)
	check(int(player.inventory.get("item_rowan_stick", 0)) == 1, "5.2 the stick is taken")
	var gate := area.find_children("*", "ShortcutGate", true, false)[0] as ShortcutGate
	check(not gate._is_open(), "5.2 the doors are still barred from inside")
	var dipper := _pickup("vat_dipper")
	check(dipper != null and dipper.label == "Take the dipper", "5.3 the dipper hangs on the vat's rim")
	var ca := _foe("cupbearer_vat_a")
	var cb := _foe("cupbearer_vat_b")
	check(ca != null and cb != null and (ca.global_position.x - vat_at.x) * (cb.global_position.x - vat_at.x) < 0.0,
		"5.3 two Cupbearers, one each side of the vat")
	check(ca != null and bool(ca.cfg.get("flank", false)), "5.3 they work as a pair (flank)")
	var ice_y: float = _ray_y(vat_at.x, -350.5, fy + 1.0)
	check(fy - ice_y > 1.8, "5.3 no way up the terrace from the ice (%.1f m of wall)" % (fy - ice_y))
	var yard_spot := Vector3(vat_at.x + 4.5, vat_at.y, vat_at.z + 1.6)
	check(_reaches(_path(byres_h, yard_spot), yard_spot, 3.0), "5.3 RIME: reached from the byre yard")
	for e in [ca, cb]:
		if e != null:
			e.take_hit(DamagePacket.new(99999, 0, player))
	await ticks(10)
	if dipper != null:
		dipper._on_take(player)
	check(int(player.inventory.get("item_vat_dipper", 0)) == 1, "5.3 the dipper is taken")
	looks = area.find_children("*", "", true, false).filter(func(n): return n is LookIn and n.is_visible_in_tree())
	check(looks.size() == 1 and (looks[0] as LookIn).caption == "Everyone is sitting down. One man is on his feet, going along the table with a horn.",
		"5.4 RIME: the window's other caption")
	print("== RIME: the set's solid props stop the Bearer")
	await _bump_all("th_", "rime")

	print("== Ottar's stick, and what Lusse says of the dipper")
	var ui := _talk("ottar")
	await ticks(2)
	check(World.flag("ks_ottar_pair"), "shown the rowan stick: ks_ottar_pair")
	check(int(player.inventory.get("item_rowan_stick", 0)) == 1, "he does not take it: it is hers")
	# (the Journal's shape, ADR 0014: a shown find is an optional step, its
	# plain line filed after the step it belongs to)
	var opt: Array = (Journal.thread_def("ottar_stick").get("optional", []) as Array).filter(func(o): return o["flag"] == "ks_ottar_pair")
	check(opt.size() == 1 and String(opt[0].get("after", "")) == "ks_ottar_staff_found", "the new step follows step 2")
	var jl: Array = Journal.view_of(Journal.thread_def("ottar_stick"))["done"]
	check(jl.any(func(l): return String(l).begins_with("Showed Ottar the second stick, from the porch.")), "the journal has the line")
	if is_instance_valid(ui):
		ui.close()
	await ticks(3)
	ui = _talk("lusse")
	await ticks(2)
	check(World.flag("ks_vat_dipper_shown"), "Lusse is shown the dipper")
	var shown := false
	for w2 in DB.npc("lusse").get("lines_when", []):
		if String(w2.get("flag", "")) == "ks_vat_dipper_shown":
			shown = (w2["lines"] as Array).has("He's had that vat filled twice since noon. He counts the horns, not the guests.")
	check(shown, "and has her line for it")
	if is_instance_valid(ui):
		ui.close()
	await ticks(3)
	finish()

func _walk_route(pts: Array, per := 700) -> bool:
	for p in pts:
		if not await _walk_to(p, per):
			return false
	return true

## Distance from (x, z) to the causeway's centre line (tarn_land.CAUSEWAY).
func _causeway_d(x: float, z: float) -> float:
	var a := Vector2(131.0, -334.5)
	var b := Vector2(171.5, -331.0)
	var p := Vector2(x, z)
	var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return p.distance_to(a + (b - a) * t)
