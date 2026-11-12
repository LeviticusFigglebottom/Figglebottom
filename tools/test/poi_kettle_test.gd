extends TestBase
## Kettle Fjord's points of interest (docs/lore/POI.md 4), each on the ground
## the terrain was widened for: the Turn in the Road (a bay off the last bend),
## the Dog Lines (a spit off the shelf), the Net-Cleft (the shortcut through
## the east spur), the Ice Camp (out on the RIME ice) and the Far Landing (a
## spit on the north shore). The boards read, the finds can be taken, the
## hurdle opens from the east only, Ivo's thread takes its two new steps, and
## the camp's Sealer waits for an Ice-fisher to be struck.

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
	area = AreaBuilder.build("kettle_fjord")
	add_child(area)
	Game.register_area(area, "kettle_fjord")
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

func _length(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i].distance_to(p[i - 1])
	return l

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

## Read the board that stands at `at` in the state now showing.
func _read_board(at: Vector3) -> String:
	_read = ""
	for n in area.find_children("*", "LorePlaque", true, false):
		var p := n as LorePlaque
		if p.global_position.distance_to(at) < 0.3 and p.is_visible_in_tree():
			for z in p.find_children("*", "Interactable", true, false):
				(z as Interactable).activate(player)
	# (a board holds the Bearer until a key is pressed: let go of it)
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.lore_root.visible = false
		hud.lore_root.remove_from_group("lore_open")
	player.lock_control(false)
	return _read

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

## Every solid prop of the region's own set (kit ids beginning `prefix`) in
## the state now showing stops the Bearer.
func _bump_all(prefix: String, state_tag: String) -> void:
	var seen := {}
	for p in def["props"]:
		var kit := String(p["kit"])
		var tag := String(p.get("tag", "base"))
		if not kit.begins_with(prefix) or not p.get("collide", true) or not (tag in ["base", state_tag]):
			continue
		seen[kit] = int(seen.get(kit, 0)) + 1
		if int(seen[kit]) > 2:
			continue            # (two of each is proof of the collider)
		var size: Array = KitLib.manifest()[kit]["size"]
		var why: String = await _bump(AreaBuilder._v3(p["at"]), minf(float(size[0]), float(size[1])) * 0.5)
		check(why == "", "%s at (%.0f, %.0f) is solid%s" % [kit, p["at"][0], p["at"][2], "" if why == "" else ": " + why])
	for l in def.get("landmarks", []):
		if not l.has("blocker") or not (String(l.get("tag", "base")) in ["base", state_tag]):
			continue
		var why2: String = await _bump(AreaBuilder._v3(l["at"]), 0.4)
		check(why2 == "", "%s is solid%s" % [String(l["scene"]).get_file(), "" if why2 == "" else ": " + why2])

func _talk(npc_id: String) -> DialogueUI:
	var cfg := DB.npc(npc_id)
	cfg["id"] = npc_id
	var ui := DialogueUI.new(cfg, null)
	get_tree().root.add_child(ui)
	return ui

func _journal(thread_id: String) -> Array:
	for t in Keepsakes.journal():
		if t["id"] == thread_id:
			return t["lines"]
	return []

func _foe(id: String) -> Enemy:
	for n in area.find_children("*", "Spawner", true, false):
		if (n as Spawner).spawn_id == id:
			return (n as Spawner).current
	return null

func _run() -> void:
	World._save_dir = "user://test_poi_kettle"
	World.reset()
	Game.set_warmth(0)
	Game.lore_panel.connect(func(t): _read = String(t))
	await _build(RH.WState.THAW)
	add_child(HUD.new())
	var boards: Array = def["plaques"]
	var turn: Dictionary = boards.filter(func(b): return String(b["text"]).begins_with("THE KETTLE ROAD") and b.get("tag") == "thaw")[0]
	var turn_at := AreaBuilder._v3(turn["at"])
	var houses_h := Game.find_hearth("hs_fish_houses").respawn_point()

	print("== 4.1 the Turn in the Road")
	check(absf(_ray_y(turn_at.x, turn_at.z, 30.0) - turn_at.y) < 0.4, "the board stands on the bay's level ground")
	var ys: Array = []
	var rot := deg_to_rad(float(turn["rot"]))
	var fwd := Vector3(-sin(rot), 0, -cos(rot))          # the board faces the road
	var side := Vector3(fwd.z, 0, -fwd.x)
	for d in [fwd * 1.0, fwd * 2.2, fwd * 1.4 + side * 1.6, fwd * 1.4 - side * 1.2]:
		ys.append(_ray_y(turn_at.x + d.x, turn_at.z + d.z, turn_at.y + 3.0))
	check(ys.max() - ys.min() < 0.9, "the bay is level enough to stand about in (%.2f m across it)" % (ys.max() - ys.min()))
	check(_reaches(_path(player.global_position, turn_at), turn_at), "the road reaches the bay")
	check(_read_board(turn_at).contains("You can smell the kettles from here."), "THAW: the board reads")
	var landing := Game.find_hearth("hs_landing_ice").respawn_point()
	check(_reaches(_path(player.global_position, landing), landing), "and the road still comes down to the Landing Ice past it")

	print("== 4.2 the Dog Lines (THAW)")
	var pole: Dictionary = _spec("pickups", "sounding_pole")
	var pole_at := AreaBuilder._v3(pole["at"])
	check(absf(_ray_y(pole_at.x, pole_at.z, 20.0) - 1.8) < 0.3, "the spit stands at shelf height")
	check(_reaches(_path(houses_h, pole_at), pole_at), "the picket is a walk from the Fish-Houses hearth")
	check(_pickup("sounding_pole") == null or not _pickup("sounding_pole").is_visible_in_tree(), "no pole in THAW: it is in Pell's hand")
	var dogs := area.thaw_layer.find_children("*", "AnimationPlayer", true, false).filter(
		func(a): return String(a.get_parent().scene_file_path).contains("sledge_dog") or String(a.owner.scene_file_path if a.owner != null else "").contains("sledge_dog"))
	check(dogs.size() == 4, "four dogs on their tethers (%d)" % dogs.size())
	# the jetty's last leg comes ashore across the spit: the walk is not cut
	player.global_position = Vector3(-61.0, 2.4, -326.0)
	await ticks(8)
	var walked: bool = await _walk_to(houses_h, 900, 1.6)
	check(walked and not player.dead, "off the jetty, over the spit, to the hearth")
	if not walked:
		print("    stopped at ", player.global_position, " dead ", player.dead)

	print("== 4.3 the Net-Cleft (THAW: lashed from the east)")
	var gate := area.find_children("*", "ShortcutGate", true, false)[0] as ShortcutGate
	var west := gate.global_position + Vector3(-7.5, 0, 0)
	var east := gate.global_position + Vector3(3.0, 0, 0)
	check(gate.gate_id == "net_cleft" and gate._front.prompt == "Lashed from the other side" and gate._back.prompt == "Cut the lashing",
		"the hurdle's two prompts")
	check(gate._front.zone_global().x < gate.global_position.x and gate._back.zone_global().x > gate.global_position.x,
		"lashed on the west face, cut from the east")
	check(absf(_ray_y(west.x + 3.0, west.z, 3.5) - 1.8) < 0.25, "the cleft's floor is at shelf height")
	check(_ray_y(west.x + 3.0, west.z + 2.6, 30.0) > 4.5 and _ray_y(west.x + 3.0, west.z - 2.6, 30.0) > 4.5, "rock stands either side of it")
	var round_way := _path(west, east)
	check(_reaches(round_way, east) and _length(round_way) > 30.0, "shut: the way to the east shelf is round by the jetty (%.0f m)" % _length(round_way))
	player.global_position = west + Vector3(0, 0.3, 0)
	await ticks(6)
	await _walk_to(east, 400)
	check(player.global_position.x < gate.global_position.x, "the hurdle is a real collider")
	gate._front.activate(player)
	check(not World.area_flag("kettle_fjord", "gate_net_cleft"), "it will not open from the west")
	player.global_position = east + Vector3(0, 0.3, 0)
	await ticks(4)
	gate._back.activate(player)
	check(World.area_flag("kettle_fjord", "gate_net_cleft"), "cut from the east: gate_net_cleft is set")
	await ticks(90)
	var through := _path(west, east)
	check(_reaches(through, east) and _length(through) < 14.0, "open: straight through on rock (%.0f m)" % _length(through))
	walked = await _walk_to(west, 700)
	check(walked, "the Bearer walks back through the cleft")
	if not walked:
		print("    stopped at ", player.global_position, " dead ", player.dead)

	print("== THAW: the set's solid props stop the Bearer")
	await _bump_all("kf_", "thaw")

	print("== RIME")
	await _build(RH.WState.RIME)
	houses_h = Game.find_hearth("hs_fish_houses").respawn_point()
	check(_read_board(turn_at).contains("Everything else has skinned over."), "4.1 RIME: the same board, the other caption")
	gate = area.find_children("*", "ShortcutGate", true, false)[0] as ShortcutGate
	check(gate._is_open(), "4.3 the hurdle stays open")
	var veil := AreaBuilder._v3(def["frost_veils"][0]["at"])
	var run := _path(houses_h, veil)
	var thin: Array = def["hazards"].filter(func(h): return h["kind"] == "thin")
	var wet := false
	for i in range(1, run.size()):
		for k in 12:
			var q: Vector3 = run[i - 1].lerp(run[i], k / 11.0)
			for h in thin:
				if q.x > h["min"][0] and q.x < h["max"][0] and q.z > h["min"][2] and q.z < h["max"][2]:
					wet = true
	check(_reaches(run, veil, 4.0) and not wet, "4.3 hearth to frost veil through the cleft with no thin ice (%.0f m)" % _length(run))
	var cache := _pickup("cleft_cache")
	check(cache != null, "4.3 the net-weights hang inside")
	if cache != null:
		cache._on_take(player)
		check(int(player.inventory.get("bog_iron", 0)) == 2, "4.3 two bog-iron taken")

	print("== 4.2 the Dog Lines (RIME)")
	var pk := _pickup("sounding_pole")
	check(pk != null and pk.label == "Take the sounding pole", "the pole leans at the picket stake")
	check(_reaches(_path(houses_h, pole_at), pole_at), "and can be walked to")
	if pk != null:
		pk._on_take(player)
	check(int(player.inventory.get("item_sounding_pole", 0)) == 1, "the pole is taken")
	for id in ["dogs_a", "dogs_b"]:
		var dg := _foe(id)
		check(dg != null and absf(dg.global_position.y - 0.15) < 0.6 and _ray_y(dg.global_position.x, dg.global_position.z, 6.0) < 0.3,
			"%s stands on the ice below the spit" % id)

	print("== 4.4 the Ice Camp")
	var winder := _pickup("line_winder")
	check(winder != null and winder.label == "Take the line-winder", "the winder is at the hut with the madder band")
	var w_at := AreaBuilder._v3(_spec("pickups", "line_winder")["at"])
	check(_reaches(_path(Game.find_hearth("hs_landing_ice").respawn_point(), w_at), w_at), "a walk over the ice from the Landing Ice hearth")
	var crack: Dictionary = thin[0]
	for p in def["props"]:
		if String(p.get("tag", "")) == "rime" and String(p["kit"]).begins_with("kf_") and float(p["at"][0]) < -100.0:
			if float(p["at"][0]) > float(crack["min"][0]) - 12.0 + 4.5:
				check(false, "%s stands too near the crevasse" % p["kit"])
	var is_hut := func(n): return String(n.get_meta("kit_id", "")).begins_with("kf_ice_hut")
	check(area.rime_layer.get_children().filter(is_hut).size() == 4, "four huts out on the ice")
	check(area.thaw_layer.get_children().filter(is_hut).size() == 4, "and the same four drawn up under the wall in THAW")
	var fa := _foe("camp_fisher_a")
	var fb := _foe("camp_fisher_b")
	var sealer := _foe("camp_sealer")
	check(fa != null and fb != null and sealer != null, "two Ice-fishers and a Sealer")
	if sealer != null and fa != null:
		player.global_position = sealer.global_position + Vector3(0, 0.2, -2.5).rotated(Vector3.UP, sealer.vis.rotation.y)
		await ticks(60)
		check(sealer.state == Enemy.ES.IDLE, "the Sealer does not rise for the Bearer alone")
		fa.take_hit(DamagePacket.new(1, 0, player))
		await ticks(20)
		check(sealer.state != Enemy.ES.IDLE and float(sealer.cfg.get("aggro_sight", 0)) > 1.0, "an Ice-fisher struck: the Sealer comes")
	for e in [fa, fb, sealer]:
		if e != null:
			e.take_hit(DamagePacket.new(99999, 0, player))
	await ticks(10)
	if winder != null:
		winder._on_take(player)
	check(int(player.inventory.get("item_line_winder", 0)) == 1, "the winder is taken")

	print("== 4.5 the Far Landing")
	var pack := _pickup("healer_pack")
	var pack_at := AreaBuilder._v3(_spec("pickups", "healer_pack")["at"])
	check(pack != null and pack.label == "Unstrap the pack", "the pack is strapped on the sledge")
	check(absf(_ray_y(pack_at.x + 1.5, pack_at.z + 0.5, 6.0) - 1.8) < 0.3, "the landing stands at shelf height")
	var over := _path(houses_h, pack_at)
	check(_reaches(over, pack_at), "RIME: over the ice and up the shingle to the landing")
	var far_board: Dictionary = boards.filter(func(b): return String(b["text"]).begins_with("THE FAR LANDING"))[0]
	check(_read_board(AreaBuilder._v3(far_board["at"])).contains("She was waiting for the ice to be made."), "the board reads")
	check(_pickup("north_shore_cache") != null and absf(AreaBuilder._v3(_spec("pickups", "north_shore_cache")["at"]).y - 1.8) < 0.3,
		"the old cache lies on the landing now")
	if pack != null:
		pack._on_take(player)
	check(int(player.inventory.get("item_healer_pack", 0)) == 1, "the pack is taken")
	check(area.find_children("House_healer_house", "", true, false).size() == 1, "the healer's house stands, shut")

	print("== RIME: the set's solid props stop the Bearer")
	await _bump_all("kf_", "rime")

	print("== Ivo's mitten: two new steps")
	var ui := _talk("ivo")
	await ticks(2)
	check(World.flag("ks_ivo_pole") and World.flag("ks_ivo_line"), "shown the pole and the winder: both flags")
	check(int(player.inventory.get("item_sounding_pole", 0)) == 1, "he does not take his grandfather's pole")
	check(int(player.inventory.get("item_line_winder", 0)) == 0, "he takes his own winder")
	check(int(player.inventory.get("item_healer_pack", 0)) == 1, "he is not shown the pack")
	# (the Journal's shape, ADR 0014: a shown find is an optional step, its
	# plain line filed after the step it belongs to)
	var lines: Array = Journal.view_of(Journal.thread_def("ivo_mitten"))["done"]
	check(lines.any(func(l): return String(l).begins_with("Showed Ivo the sounding pole.")) \
		and lines.any(func(l): return String(l).begins_with("Showed Ivo the line-winder.")),
		"the journal has both lines")
	var after := {}
	for o in Journal.thread_def("ivo_mitten").get("optional", []):
		after[String(o["flag"])] = String(o.get("after", ""))
	check(after.get("ks_ivo_pole", "") == "ks_ivo_met" and after.get("ks_ivo_line", "") == "ks_ivo_supper",
		"the pole's step sits between the meeting and the supper; the winder's after the supper")
	if is_instance_valid(ui):
		ui.close()
	await ticks(3)

	print("== THAW again: the far shore is out of reach")
	await _build(RH.WState.THAW)
	check(not _reaches(_path(Game.find_hearth("hs_fish_houses").respawn_point(), pack_at), pack_at), "no THAW way over the water to the landing")
	finish()
