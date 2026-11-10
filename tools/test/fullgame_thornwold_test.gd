extends FullgameBase
## Thornwold, end to end (THORNWOLD.md), from the save the Tarnhall walk ends
## on: over the drove-road seam, Linnet and Eyvind at the clearing, the first
## rest and the RIME, a fall and the Breathmark, the knucklebone and the
## birch ring, round the plugged road to the Outer Ring, the maze between
## the rings to the veil, the Hedgelayer through all three phases, his
## release (the card, the song-cord on the grave, the gate laid down, the
## Pine), the THAW scene at the gap, the straight way out that only THAW
## has, the cord read by Lusse back in Tarnhall, and the last rest at the
## Outer Ring.

const GRAVE := Vector3(452.0, 0.0, -325.0)
const R1 := 12.0
const R3 := 26.0

const LINNET_FIRST := [
	"Mind the clamp, it's breathing. If it stops breathing, come and get me, I'll be wherever he is.",
	"Linnet. That's Eyvind. He's laying a hedge round a field we haven't got yet.",
	"He wants the gate east for the sun on the latch. The sun's got nothing to do with it. He just doesn't want the west.",
	"We're to be married after the Melt. If he decides about the gate.",
]
const ARGUMENT := [
	["eyvind", "East side. Morning sun on the latch, it won't freeze shut."],
	["linnet", "East side and the cows come out straight into the bog."],
	["eyvind", "Cows can learn."],
	["linnet", "Your cows can. My father's cows are cleverer than that."],
	["eyvind", "West, then."],
	["linnet", "West's where the wind comes from. You want the wind in your gate?"],
	["eyvind", "There's no side you'll have."],
	["linnet", "There is. I'm just not telling you yet."],
]
const AT_THE_GAP := [
	["linnet", "Well?"],
	["eyvind", "I've thought about it."],
	["linnet", "And?"],
	["eyvind", "I'm laying it flat. Across the gap. You come in whichever side you like."],
	["linnet", "That's not a gate."],
	["eyvind", "It's a gate lying down."],
	["linnet", "All right."],
]

var _titles: Array = []
var _cards: Array = []
var _n0 := 0
var _heard: Array = []
var _w0 := 0
# marks on the ground the legs share
var plug_a: Vector3
var plug_b: Vector3
var road_end: Vector3
var mouth: Vector3
var inside: Vector3
var rime_plug := INF
var rime_in := INF
var thaw_in := INF
var veil: FrostVeil = null
# (scratch the legs reuse)
var took := false
var walked := false
var crossed := false
var rest: RestUI = null
var ui: DialogueUI = null
var seam: AreaPortal = null
var souls := {}
var boss: Enemy = null

## The walk's legs, in order. --fullgame-leg=<name> (debugging only) drops
## the Bearer at the start of a later leg by fiat; such a run always fails
## its first check, so it can never pass for the walk.
const LEGS := ["seam", "clearing_thaw", "first_rest", "knucklebone", "stilled", "clearing_rime", "to_outer_ring",
	"maze", "duel", "release", "gate", "gap_thaw", "thaw_routes", "lusse", "end"]
var _skip_to := ""

func _on_heard(who, line) -> void:
	_heard.append([String(who), String(line)])

func _init() -> void:
	region = "thornwold"
	aid = "thornwold"
	start_fixture = "fullgame_after_tarnhall"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fullgame-leg="):
			_skip_to = a.get_slice("=", 1)

# ------------------------------------------------------------------ helpers
## (the maze is long: lift the polygon search cap a long route needs)
func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := area.get_world_3d().navigation_map
	var q := NavigationPathQueryParameters3D.new()
	q.map = map
	q.start_position = NavigationServer3D.map_get_closest_point(map, from)
	q.target_position = NavigationServer3D.map_get_closest_point(map, to)
	q.path_search_max_polygons = 200000
	var r := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(q, r)
	return r.path

func _g(x: float, z: float) -> Vector3:
	return Vector3(x, area.terrain.height_at(x, z), z)

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

## Length of the navmesh way from a to b, or INF when it does not get there.
func _reach_len(a: Vector3, b: Vector3, tol := 1.6) -> float:
	var p := _path(a, b)
	if p.size() < 2 or _flat(p[p.size() - 1] - b).length() > tol:
		return INF
	var t := 0.0
	for i in range(1, p.size()):
		t += p[i].distance_to(p[i - 1])
	return t

func _expected(thread_id: String) -> Array:
	var out := []
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			for s in t["steps"]:
				if World.flag(String(s["flag"])):
					out.append(String(s["line"]))
	return out

func _all_lines(thread_id: String) -> Array:
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			return (t["steps"] as Array).map(func(s): return String(s["line"]))
	return []

## Who stands here to be seen: id -> [NPC, ...].
func _souls() -> Dictionary:
	var out := {}
	for c in area.find_children("*", "NPC", true, false):
		var n := c as NPC
		if n.is_visible_in_tree() and not n.is_queued_for_deletion():
			if not out.has(n.npc_id):
				out[n.npc_id] = []
			out[n.npc_id].append(n)
	return out

func _gates_seen() -> Array:
	return area.find_children("*", "Node3D", true, false).filter(func(n):
		return (n as Node3D).scene_file_path.ends_with("hedge_gate.tscn") and (n as Node3D).is_visible_in_tree())

func _flat_gate() -> bool:
	var g := _gates_seen()
	return g.size() == 1 and absf((g[0] as Node3D).rotation_degrees.x + 90.0) < 1.0

## Walk up within earshot of `n` (not into it).
func _come_near(n: NPC, r := 4.0) -> void:
	_halt = func(): return _flat(player.global_position - n.global_position).length() < r
	await _walk_path(n.global_position, 3600, false)
	_halt = Callable()
	player.sim_move = Vector3.ZERO

func _standing_thorn() -> Array:
	return get_tree().get_nodes_in_group("thorn_walls").filter(func(w): return is_instance_valid(w) and (w as ThornWall).is_standing())

# ------------------------------------------------------- the Hedgelayer's hedges
var _duel_boss: Hedgelayer = null
var _mash_n := 0
var _log_n := 0
## What the fight showed (his AI picks its own moves: only the bar, the
## rings and the Bearer's own blows are asserted; the rest is printed).
var _seen := {"bar": false, "ring2": 0.0, "ring3": 0.0, "walls": 0, "lash": 0, "steps": 0, "measure": false, "blows": 0}

func _on_blow(_who, result) -> void:
	if String(result) == "hit":
		_seen["blows"] += 1

## Caught by the lash, a player struggles (THORNWOLD.md 6: "mash to break").
func _physics_process(_dt: float) -> void:
	if _duel_boss == null or not is_instance_valid(_duel_boss):
		return
	var hold := _duel_boss.hook_hold
	if hold != null and is_instance_valid(hold) and not hold.is_over():
		_mash_n += 1
		if _mash_n % 5 == 0:
			hold.mash()

## What the plain melee bot cannot answer by itself: the ring he raises round
## the grave (get in, or out, by its one gap) and a wall of thorn standing
## between him and the Bearer (go round its end).
func _answer_hedge(boss: Enemy) -> void:
	var h := boss as Hedgelayer
	if h == null or h.dead or player.dead:
		return
	if h != _duel_boss:
		_duel_boss = h
		if not player.hit_landed.is_connected(_on_blow):
			player.hit_landed.connect(_on_blow)
		h.stepped_out.connect(func(_at): _seen["steps"] += 1)
	_log_n += 1
	if _log_n % 5 == 0:
		print("  (duel: phase %d, he %.0f%%, state %s, %.1f m off; the Bearer %.0f/%.0f, %d gourds, at %s)" % [h.phase,
			100.0 * h.hp / h.max_hp, Enemy.ES.keys()[h.state], _flat(h.global_position - player.global_position).length(),
			player.hp, player.max_hp, player.gourds, str(player.global_position.snapped(Vector3.ONE * 0.1))])
	if h.stood and hud.boss_root.visible and hud.boss_name.text == "THE HEDGELAYER":
		_seen["bar"] = true
	_seen["walls"] = maxi(_seen["walls"], h.standing_walls().filter(func(w): return w != h.ring).size())
	if h.hook_hold != null:
		_seen["lash"] += 1
	if h.state == Enemy.ES.HOLD and not h.hidden:
		_seen["measure"] = true
	var ring := h.ring
	if ring != null and is_instance_valid(ring) and ring.is_standing():
		_seen["ring%d" % h.phase] = ring.radius
		if h.state == Enemy.ES.TRANSITION:
			return   # still rising
		var c := ring.global_position
		var pr := _flat(player.global_position - c).length()
		var br := _flat(h.global_position - c).length()
		if pr > ring.radius + 0.3 and br < ring.radius + 1.2:
			await _by_the_gap(ring, true)
		elif pr < ring.radius - 0.3 and br > ring.radius + 1.2:
			await _by_the_gap(ring, false)
		return
	if h.hidden:
		return
	# a wall between us: round its nearer end
	var from := player.global_position + Vector3.UP
	var q := PhysicsRayQueryParameters3D.create(from, h.global_position + Vector3.UP, RH.M_WORLD_ALL)
	var hit := area.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not ((hit["collider"] as Node).get_parent() is ThornWall):
		return
	var w := (hit["collider"] as Node).get_parent() as ThornWall
	if w.shape != "line" or not w.is_standing():
		return
	var best := Vector3.INF
	var bd := INF
	for s in [-1.0, 1.0]:
		var end: Vector3 = w.global_transform * Vector3(s * (w.length * 0.5 + 1.5), 0, 0)
		var d := _flat(end - player.global_position).length() + _flat(h.global_position - end).length()
		if d < bd:
			bd = d
			best = end
	await _walk_to(best, 150, 0.8, false)

## Round the ring to its gap and through it.
func _by_the_gap(ring: ThornWall, inward: bool) -> void:
	var c := ring.global_position
	var ga := deg_to_rad(ring.gap_deg)
	var lane := ring.radius + (1.7 if inward else -1.7)
	for step in 30:
		if player.dead or not is_instance_valid(ring) or not ring.is_standing():
			return
		var rel := _flat(player.global_position - c)
		var pa := atan2(rel.z, rel.x)
		var da := wrapf(ga - pa, -PI, PI)
		if absf(da) * ring.radius < 1.0:
			break
		var na := pa + clampf(da, -0.5, 0.5)
		await _walk_to(c + Vector3(cos(na), 0, sin(na)) * lane, 90, 0.7, false)
	var dir := Vector3(cos(ga), 0, sin(ga))
	await _walk_to(c + dir * (ring.radius + (-2.2 if inward else 2.2)), 150, 0.8, false)

# ------------------------------------------------------------------ the walk
func _region() -> void:
	Game.area_title.connect(func(t): _titles.append(String(t)))
	Game.title_card.connect(func(t, _hold): _cards.append(String(t)))
	for leg in LEGS:
		if _skip_to != "" and leg != _skip_to:
			continue
		if _skip_to != "":
			await _jump_to(leg)
			_skip_to = ""
		if not await call("_leg_" + leg):
			print("  (the walk stops at: %s)" % leg)
			return

func _marks() -> void:
	plug_a = _g(369.0, -316.8)             # on the road either side of the first RIME plug
	plug_b = _g(379.0, -319.0)
	road_end = _g(GRAVE.x - R3 - 3.0, GRAVE.z)   # where the road meets the outer ring
	mouth = _g(GRAVE.x - R1 - 3.0, GRAVE.z)      # before the innermost gap
	inside = _g(GRAVE.x - R1 + 3.0, GRAVE.z)     # just inside it

## Debugging only (--fullgame-leg=maze|duel|release): by fiat, the world as the
## legs before leave it. Never a pass.
func _jump_to(leg: String) -> void:
	check(false, "DEBUG RUN from leg '%s': not the walk" % leg)
	if not (leg in ["maze", "duel", "release"]):
		return
	for f in ["ks_linnet_met", "met_linnet", "got_collier_leathers", "ks_knucklebone_found"]:
		World.set_flag(f)
	for it in ["armour_collier", "item_knucklebone", "item_birch_ring", "hedging_bill"]:
		player.give_item(it, 1)
	for pk in ["knucklebone", "birch_ring", "hedging_bill", "clamp_cache"]:
		World.set_area_flag(aid, "took_" + pk)
	for h in ["hs_drove_road", "hs_colliers_clearing", "hs_outer_ring"]:
		World.set_area_flag(aid, "lit_" + h)
	World.set_area_state(aid, RH.WState.RIME)
	World.last_hearth = {"area": aid, "hearth": "hs_outer_ring"}
	var at: Vector3 = AreaBuilder._v3(DB.area_def(aid)["hearths"][2]["at"]) + Vector3(-1.0, 0.4, 1.0)
	Game.travel_to(aid, at)
	await _until(func(): return Game.current_area_id == aid and player.input_enabled, 12.0)
	area = Game.current_area
	await ticks(60)
	_marks()
	rime_in = _reach_len(road_end, mouth, 3.0)
	rime_plug = _reach_len(plug_a, plug_b)
	if leg == "duel" or leg == "release":
		veil = _veil()
		player.global_position = mouth + Vector3(0, 0.3, 0)
		await ticks(10)
		await _part_veil(veil, false)
	if leg == "release":
		boss = _foe("hedgelayer")
		boss.take_hit(DamagePacket.new(10, 0, player))
		await _secs(2.6)
		while boss != null and not boss.dead:
			boss.take_hit(DamagePacket.new(300, 0, player))
			await _secs(3.0 if boss.state == Enemy.ES.TRANSITION else 0.05)

func _leg_seam() -> bool:
	print("== the drove-road out of Tarnhall")
	check(Game.current_area_id == "tarnhall", "the walk starts in Tarnhall (%s)" % Game.current_area_id)
	check(not World.is_cleared(aid) and not World.flag("ks_hedgelayer_released"), "Thornwold has not been walked")
	seam = _portal_to("thornwold")
	check(seam != null and seam.auto, "the drove-road seam stands, with no door in it")
	if seam == null:
		return false
	_n0 = _titles.size()
	crossed = await _cross("thornwold", seam.global_position + Vector3(1.0, 0, 0), 9000, true)
	check(crossed, "the Bearer walks the drove-road through the notch into Thornwold (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return false
	_marks()
	var def: Dictionary = area.get_meta("def")
	check(player.global_position.distance_to(AreaBuilder._v3(def["start"]["pos"])) < 6.0, "set down on the road past the seam")
	check(World.get_area_state(aid) == RH.WState.THAW, "first arrival is THAW")
	check(_awake_foes().is_empty(), "no enemies in THAW")
	await _until(func(): return hud.last_title == "THE COLLIER'S CLEARING", 8.0)
	# (a place card of Tarnhall's may still have been on its way at the start)
	var seen: Array = _titles.slice(_n0)
	var ti := seen.map(func(t): return String(t).to_upper()).find("THORNWOLD")
	check(ti >= 0 and seen.slice(ti + 1) == ["THE COLLIER'S CLEARING"], "the region's card, then the place (%s)" % str(seen))
	check(Game.current_area_id == "thornwold", "the seam does not carry him back")
	await _shot("arrival_thaw")
	walked = await _walk_path(_g(316.0, -320.5), 3600, false)
	check(walked, "down the road to its head (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	var plaques := area.find_children("*", "LorePlaque", true, false)
	check(plaques.size() == 1 and String((plaques[0] as LorePlaque).text).begins_with("THORNWOLD\n"), "the plaque at the road's head names the wood")
	check(Game.find_hearth("hs_drove_road") != null and Game.find_hearth("hs_colliers_clearing") != null
		and Game.find_hearth("hs_outer_ring") != null and Game.find_hearth("hs_the_pine") == null,
		"three hearths stand; the Pine is not woken")
	return true

func _leg_clearing_thaw() -> bool:
	print("== the Collier's Clearing: Linnet and Eyvind")
	souls = _souls()
	check(souls.has("linnet") and souls.has("eyvind") and not souls.has("eyvind_gate"), "Linnet and Eyvind at the clamps (%s)" % str(souls.keys()))
	var eyvind: NPC = souls["eyvind"][0] if souls.has("eyvind") else null
	_heard = []
	if eyvind != null:
		check(eyvind.find_children("*", "Interactable", true, false).is_empty(), "Eyvind cannot be spoken to")
		eyvind.overheard.connect(_on_heard)
	ui = await _talk("linnet")
	check(ui != null, "the Bearer walks to Linnet and speaks with her")
	if ui != null:
		await _shot("linnet_talk")
		check(ui.name_label.text == "Linnet, collier", "her name plate (%s)" % ui.name_label.text)
		var lines: Array = await _lines_of(ui)
		check(lines == LINNET_FIRST, "Linnet's first lines, in order (%d)" % lines.size())
		check(World.flag("ks_linnet_met") and World.flag("met_linnet"), "her thread begins")
		var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(ids == ["give_collier_leathers", "leave"], "she offers the spare leathers (%s)" % str(ids))
		if ids.has("give_collier_leathers"):
			ui.choose(ids.find("give_collier_leathers"))
			await ticks(2)
			check(int(player.inventory.get("armour_collier", 0)) == 1 and World.flag("got_collier_leathers"), "the Bearer takes them")
			check(ui.text_label.text == "They were my brother's. He grew. Don't stand downwind of the clamps in them.", "and she says whose they were")
		await _leave(ui)
	check(_ui("DialogueUI") == null and player.input_enabled, "Leave closes the talk and hands control back")
	check(_journal("song_cord") == [_all_lines("song_cord")[0]], "Linnet's song-cord: one line")
	if eyvind != null:
		await _come_near(eyvind, 4.0)
		await _until(func(): return _heard.size() >= ARGUMENT.size(), 60.0)
		eyvind.overheard.disconnect(_on_heard)
		check(_heard.size() >= ARGUMENT.size() and _heard.slice(0, ARGUMENT.size()) == ARGUMENT,
			"the argument about the gate is overheard, all eight lines in order (%d)" % _heard.size())
		check(not World.flag("met_eyvind"), "nobody can join in")
	ui = await _talk("linnet")
	if ui != null:
		var again: Array = await _lines_of(ui)
		check(again.size() == 2 and String(again[0]).begins_with("If the smoke goes blue"), "asked again, she talks about the smoke")
		check(not ui._options.any(func(o): return String(o.get("id", "")) == "give_collier_leathers"), "the leathers are given once")
		await _leave(ui)
	return true

func _leg_first_rest() -> bool:
	print("== the first rest, at the Drove-Road, forces RIME")
	rest = await _rest_ui_at("hs_drove_road")
	check(rest != null, "the Drove-Road offers its hearth")
	if rest != null:
		await _shot("rest_menu_thaw")
		check(rest.title_label.text == "the Drove-Road", "the hearth is named (%s)" % rest.title_label.text)
		check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0, "uncleared THAW: rest only, no turning back")
		rest.choose(0)
		await _wait_turn()
	check(World.get_area_state(aid) == RH.WState.RIME, "Thornwold is RIME now")
	check(World.last_hearth.get("hearth", "") == "hs_drove_road" and _hearth_lit("hs_drove_road"), "the Drove-Road is lit and kept")
	check(_souls().is_empty(), "Linnet and Eyvind are gone in RIME")
	var kinds := {}
	for e in _awake_foes():
		kinds[e.id] = int(kinds.get(e.id, 0)) + 1
	check(_awake_foes().size() >= 6 and kinds.has("collier") and kinds.has("rime_stag") and kinds.has("hedgelayer"),
		"the frost-taken stand (%s)" % str(kinds))
	await _shot("road_rime")
	return true

func _leg_knucklebone() -> bool:
	print("== the knucklebone on the road")
	_w0 = Game.warmth
	took = await _take("knucklebone", "Pick up the knucklebone")
	check(took and int(player.inventory.get("item_knucklebone", 0)) == 1 and World.flag("ks_knucklebone_found"),
		"the knucklebone is picked up off the road")
	var kn := _journal("knucklebones")
	check(kn == _expected("knucklebones") and kn.has(_all_lines("knucklebones")[1]), "Knucklebones: the one on the road, going east (%d)" % kn.size())
	if World.flag("ks_knucklebones_found"):
		check(kn == _all_lines("knucklebones"), "with the four from Saltfell: both lines")
	else:
		print("  (the four at Saltfell were not picked up on this save: the thread shows its second line alone)")
	return true

func _leg_stilled() -> bool:
	print("== STILLED on the road, and the Breathmark")
	await _die_and_recover("hs_drove_road")
	return true

func _leg_clearing_rime() -> bool:
	print("== fight through the clearing: the ring in the ash")
	for at in [_g(342.0, -312.0), _g(349.0, -300.0)]:
		await _walk_path(at, 2400, true)
		await _fight(12.0, 60.0)
		if player.dead:
			await _until(func(): return not player.dead, 10.0)
			await ticks(30)
	check(Game.warmth > _w0 or Game.warmth > 0, "the fallen give up warmth (%d held)" % Game.warmth)
	took = await _take("birch_ring", "Take the ring from the ash")
	check(took and int(player.inventory.get("item_birch_ring", 0)) == 1, "the ring of plaited birch is taken from the eastmost clamp's ash")
	check(not World.flag("ks_birch_ring") and _journal("song_cord").size() == 1, "it waits for Linnet")
	var iron0 := int(player.inventory.get("bog_iron", 0))
	took = await _take("clamp_cache", "Rake out what the clamp kept")
	check(took and int(player.inventory.get("bog_iron", 0)) == iron0 + 2, "what the clamp kept: bog-iron")
	await _shot("clearing_rime")
	rest = await _rest_ui_at("hs_colliers_clearing")
	check(rest != null and _option_index(rest, "toggle") < 0, "the Collier's Clearing: uncleared RIME rests only")
	if rest != null:
		rest.choose(_option_index(rest, "level"))
		await ticks(2)
		var cost := rest._level_cost()
		if Game.warmth >= cost:
			var lv := player.level
			var wb := Game.warmth
			rest.choose(0)
			check(player.level == lv + 1 and Game.warmth == wb - cost, "a level bought (%d -> %d, %d warmth)" % [lv, player.level, cost])
		else:
			print("  (no level: %d warmth held, %d asked)" % [Game.warmth, cost])
		rest.choose(_option_index(rest, "back"))
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.2)
		await _until(func(): return player.input_enabled, 6.0)
	check(_hearth_lit("hs_colliers_clearing") and World.last_hearth.get("hearth", "") == "hs_colliers_clearing"
		and World.get_area_state(aid) == RH.WState.RIME, "the Collier's Clearing is lit and kept; still RIME")
	return true

func _leg_to_outer_ring() -> bool:
	print("== RIME: the road plugged, round through the wood to the Outer Ring")
	rime_plug = _reach_len(plug_a, plug_b)
	check(rime_plug > plug_a.distance_to(plug_b) * 2.5, "thorn plugs the road past the clearing (%.0f m round for %.0f m)" % [rime_plug, plug_a.distance_to(plug_b)])
	took = await _take("hedging_bill", "Take the hedging bill")
	check(took and int(player.inventory.get("hedging_bill", 0)) == 1, "the hedging bill is taken from the road's end (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(player.hotbar.has("hedging_bill"), "and seats itself in a free hand-slot")
	check(_titles.has("THE HEDGE"), "THE HEDGE is named on the way (%s)" % str(_titles.slice(_n0)))
	rime_in = _reach_len(road_end, mouth, 3.0)
	check(rime_in > road_end.distance_to(mouth) * 4.0, "the gaps have moved: from the road's end the veil is the long way round (%.0f m for %.0f m)" % [rime_in, road_end.distance_to(mouth)])
	var ring_pt := _g(GRAVE.x - R3, GRAVE.z)
	var rq := PhysicsRayQueryParameters3D.create(ring_pt + Vector3.UP * 20.0, ring_pt + Vector3.DOWN * 5.0, RH.M_WORLD_ALL)
	var rhit := area.get_world_3d().direct_space_state.intersect_ray(rq)
	check(not rhit.is_empty() and (rhit["position"] as Vector3).y - ring_pt.y > 2.8, "where the road met the outer ring, a wall of thorn")
	rest = await _rest_ui_at("hs_outer_ring")
	check(rest != null, "the Outer Ring offers its hearth (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if rest != null:
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.2)
		await _until(func(): return player.input_enabled, 6.0)
	check(_hearth_lit("hs_outer_ring") and World.last_hearth.get("hearth", "") == "hs_outer_ring", "the Outer Ring is lit and kept")
	await _shot("outer_ring")
	return true

func _leg_maze() -> bool:
	print("== the maze between the rings, and the frost veil")
	veil = _veil()
	check(veil != null and _flat(veil.global_position - (GRAVE + Vector3(-R1, 0, 0))).length() < 1.0, "one veil, in the innermost ring's gap")
	if veil == null:
		return false
	var maze := _reach_len(player.global_position, mouth, 3.0)
	check(maze > player.global_position.distance_to(mouth) * 2.0 and maze < INF, "from the Outer Ring the way winds between the rings (%.0f m)" % maze)
	var parted := false
	for attempt in 3:
		parted = await _part_veil(veil, true)
		if parted:
			break
		if player.dead:
			await _until(func(): return not player.dead, 10.0)
			await ticks(30)
	check(parted, "the Bearer walks the maze and parts the veil (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(Game.arena_locked and _flat(player.global_position - GRAVE).length() < R1, "it seals at his back, inside the innermost ring")
	await _shot("veil_parted")
	return true

func _leg_duel() -> bool:
	print("== the Hedgelayer")
	boss = _foe("hedgelayer")
	check(boss != null and boss is Hedgelayer, "the Hedgelayer himself")
	if boss != null:
		check(boss.state == Enemy.ES.IDLE and not (boss as Hedgelayer).stood and boss.vis.current_clip() == "lay_stem",
			"at the hedge, laying a stem that is already laid (%s)" % boss.vis.current_clip())
	var res: Dictionary = await _duel("hedgelayer", veil, 1.0, 720.0, _answer_hedge)
	boss = res["boss"]
	var phases: Dictionary = res["phases"]
	check(boss != null and boss.dead, "the Hedgelayer is released (deaths along the way: %d)" % int(res["deaths"]))
	check(phases.has(2) and phases.has(3), "his AI ran all three phases (%s)" % str(phases.keys()))
	check(_seen["bar"], "the bar: THE HEDGELAYER")
	check(int(_seen["blows"]) >= 8, "brought down by the Bearer's own blade (%d blows landed)" % int(_seen["blows"]))
	check(absf(float(_seen["ring2"]) - 8.0) < 0.01 and absf(float(_seen["ring3"]) - 6.0) < 0.01,
		"a ring of thorn round the grave at 8 m, closing to 6 m (%s, %s)" % [str(_seen["ring2"]), str(_seen["ring3"])])
	print("  (seen in the fight: %s)" % str(_seen))
	_duel_boss = null
	if boss == null or not boss.dead:
		return false
	return true

func _leg_release() -> bool:
	print("== the release")
	await _secs(1.0)
	check(String(AudioDirector._active_music).ends_with("outsong.ogg"), "the Outsong is sung (%s)" % AudioDirector._active_music)
	check(hud.last_title == "THE HEDGELAYER — RELEASED" and _cards.has("THE HEDGELAYER — RELEASED"), "the quiet card (%s)" % hud.last_title)
	await _shot("release_card")
	check(World.is_cleared(aid) and World.flag("ks_hedgelayer_released") and World.area_flag(aid, "slain_hedgelayer"), "Thornwold is cleared (ks_hedgelayer_released)")
	check(not Game.arena_locked, "the veil falls")
	check(boss.vis.current_clip() == "kneel_hands", "he kneels with his hands on the ground (%s)" % boss.vis.current_clip())
	await _secs(3.5)
	check(_standing_thorn().is_empty(), "every wall he raised unlays itself")
	check(_flat_gate(), "the gate lies flat across the gap; the one that leaned is gone (%d seen)" % _gates_seen().size())
	var hl := boss as Hedgelayer
	var cord := _pickup("song_cord")
	check(cord != null and cord.global_position.distance_to(hl.drop_point()) < 0.3 and _flat(cord.global_position - GRAVE).length() < 2.5,
		"the song-cord is set down on the grave")
	took = await _take("song_cord", "Take the song-cord", false)
	check(took and int(player.inventory.get("item_song_cord", 0)) == 1 and World.flag("ks_song_cord_found"),
		"the song-cord is taken (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(_journal("song_cord") == _expected("song_cord") and _journal("song_cord").has(_all_lines("song_cord")[2]), "nobody here could read it")
	await _shot("grave_cord")
	check(Game.find_hearth("hs_the_pine") != null, "the Pine wakes at the grave")
	rest = await _rest_ui_at("hs_the_pine")
	check(rest != null and _option_index(rest, "toggle") >= 0, "the Pine offers rest, and to turn the memory")
	if rest != null:
		check(rest.title_label.text == "the Pine", "the hearth is named (%s)" % rest.title_label.text)
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.2)
		await _until(func(): return player.input_enabled, 6.0)
	check(_hearth_lit("hs_the_pine") and World.last_hearth.get("hearth", "") == "hs_the_pine"
		and World.get_area_state(aid) == RH.WState.RIME, "the Pine is lit and kept; the wood still RIME")
	check(_foe("hedgelayer") == null, "he does not get up again")
	return true

func _leg_gate() -> bool:
	print("== the gate lying down: out and in by the gap, either way")
	await _walk_path(inside, 1800, true)
	walked = await _walk_to(mouth, 420, 0.8, true)
	check(walked, "out over the gate (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	walked = await _walk_to(inside, 420, 0.8, true)
	check(walked, "and in again (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	return true

func _leg_gap_thaw() -> bool:
	print("== warmed: Linnet and Eyvind at the gap")
	check(await _rest("hs_the_pine", "toggle"), "the Pine turns the memory")
	check(World.get_area_state(aid) == RH.WState.THAW, "Thornwold is THAW again")
	check(_awake_foes().is_empty(), "nobody frost-taken in THAW")
	souls = _souls()
	check(souls.has("linnet") and souls.has("eyvind_gate") and not souls.has("eyvind") and (souls.get("linnet", []) as Array).size() == 1,
		"Linnet and Eyvind stand at the gap now; nobody is left arguing at the clamps (%s)" % str(souls.keys()))
	var lin2: NPC = souls["linnet"][0] if souls.has("linnet") else null
	var ey2: NPC = souls["eyvind_gate"][0] if souls.has("eyvind_gate") else null
	check(lin2 != null and _flat(lin2.global_position - Vector3(438.4, 0, -322.6)).length() < 0.5
		and ey2 != null and _flat(ey2.global_position - Vector3(438.4, 0, -327.4)).length() < 0.5, "either side of the gate lying down")
	check(_flat_gate(), "the gate still lies across the gap")
	await _shot("gap_thaw")
	if ey2 != null:
		check(ey2.find_children("*", "Interactable", true, false).is_empty(), "Eyvind still cannot be spoken to")
		_heard = []
		ey2.overheard.connect(_on_heard)
		await _come_near(ey2, 4.0)
		await _until(func(): return _heard.size() >= AT_THE_GAP.size(), 60.0)
		ey2.overheard.disconnect(_on_heard)
		check(_heard.size() >= AT_THE_GAP.size() and _heard.slice(0, AT_THE_GAP.size()) == AT_THE_GAP,
			"overheard at the gap, seven lines in order (%s)" % str(_heard.slice(0, 2)))
	ui = await _talk("linnet")
	check(ui != null, "Linnet, at the gap")
	if ui != null:
		var l1: Array = await _lines_of(ui)
		check(l1 == ["That's mine. I had it on this morning. He made it. Don't tell him I took it off to work."], "she takes her ring (%s)" % str(l1))
		await _leave(ui)
	check(World.flag("ks_birch_ring") and int(player.inventory.get("item_birch_ring", 0)) == 0, "the ring is home")
	check(_journal("song_cord") == _all_lines("song_cord").slice(0, 3), "Linnet's song-cord: three lines, in order")
	ui = await _talk("linnet")
	check(ui != null, "Linnet, a second time")
	if ui != null:
		var l2: Array = await _lines_of(ui)
		check(l2 == ["He's laid it down. The gate. Across the gap, flat. I said that's not a gate. He said it is, it's just lying down."],
			"then the gate (%s)" % str(l2))
		await _leave(ui)
	return true

func _leg_thaw_routes() -> bool:
	print("== THAW only: straight out by the lined-up gaps, and down the open road")
	thaw_in = _reach_len(road_end, mouth, 3.0)
	check(thaw_in < road_end.distance_to(mouth) * 1.3, "the gaps line up on the road (%.0f m; in RIME %.0f m)" % [thaw_in, rime_in])
	await _walk_path(inside, 1800, false)
	var t0 := Engine.get_physics_frames()
	walked = await _walk_path(road_end, 900, false)
	check(walked, "the Bearer walks straight out through the three rings to the road (%d ticks, %s)" % [
		Engine.get_physics_frames() - t0, str(player.global_position.snapped(Vector3.ONE))])
	var thaw_plug := _reach_len(plug_a, plug_b)
	check(thaw_plug < plug_a.distance_to(plug_b) * 1.3, "no thorn across the road (%.0f m; in RIME %.0f m)" % [thaw_plug, rime_plug])
	walked = await _walk_path(plug_b, 3600, false)
	t0 = Engine.get_physics_frames()
	walked = walked and await _walk_path(plug_a, 400, false)
	check(walked, "and down the road where the plug stood (%d ticks)" % (Engine.get_physics_frames() - t0))
	walked = await _walk_path(_g(349.0, -306.0), 3600, false)
	check(walked and not _souls().has("eyvind") and _souls().get("linnet", []).size() == 1, "the clearing: the clamps, and nobody at them")
	return true

func _leg_lusse() -> bool:
	print("== back to Tarnhall: Lusse reads the cord")
	var back := _portal_to("tarnhall")
	check(back != null, "the seam back down the drove-road")
	if back == null:
		return false
	crossed = await _cross("tarnhall", back.global_position + Vector3(-1.0, 0, 0), 9000, false)
	check(crossed, "the Bearer walks back through the notch (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return false
	if World.get_area_state("tarnhall") != RH.WState.THAW:
		check(await _rest("hs_byres", "toggle"), "Tarnhall is warmed at the Byres")
	check(World.get_area_state("tarnhall") == RH.WState.THAW, "Tarnhall in THAW")
	ui = await _talk("lusse")
	check(ui != null, "the Bearer finds Lusse in the hall (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if ui != null:
		var ll: Array = await _lines_of(ui)
		check(ll == ["This is an Outsong. Somebody's tied their own. You don't see that.",
			"She starts with the clamps. Then a man with a bill. Then she doesn't know how it ends, so she's left it loose. Here."],
			"Lusse reads the cord (%s)" % str(ll.slice(0, 1)))
		await _leave(ui)
	check(World.flag("ks_song_cord_read") and int(player.inventory.get("item_song_cord", 0)) == 1, "and gives it back")
	check(_journal("song_cord") == _all_lines("song_cord"), "Linnet's song-cord: four lines, in order")
	return true

func _leg_end() -> bool:
	print("== and back, to rest at the Outer Ring")
	seam = _portal_to("thornwold")
	crossed = seam != null and await _cross("thornwold", seam.global_position + Vector3(1.0, 0, 0), 9000, false)
	check(crossed, "over the seam again")
	if not crossed:
		return false
	check(World.get_area_state(aid) == RH.WState.THAW and _awake_foes().is_empty(), "Thornwold as it was left: THAW")
	souls = _souls()
	check(souls.has("linnet") and souls.has("eyvind_gate") and not souls.has("eyvind"), "the rebuilt wood keeps them at the gap")
	check(_flat_gate() and Game.find_hearth("hs_the_pine") != null, "the gate lying down, and the Pine")
	check(await _rest("hs_outer_ring", "toggle"), "the Outer Ring turns the memory freely (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(World.get_area_state(aid) == RH.WState.RIME, "stilled again: RIME")
	check(_foe("hedgelayer") == null and not Game.arena_locked, "he does not come back")
	var v2 := _veil()
	check(v2 == null or v2._seal.collision_layer == 0, "and the veil stays down")
	check(_reach_len(road_end, mouth, 3.0) > thaw_in * 4.0, "the maze is the maze again")
	check(_flat_gate(), "the gate lies down in RIME too")
	await _shot("outer_ring_rime_cleared")
	check(await _rest("hs_outer_ring", "toggle"), "and turns it back")
	check(World.get_area_state(aid) == RH.WState.THAW, "warmed once more")
	check(World.last_hearth.get("area", "") == aid and World.last_hearth.get("hearth", "") == "hs_outer_ring", "the Outer Ring is the hearth kept")
	await _shot("end_thaw")
	return true

func _after_load() -> void:
	print("== Thornwold, resumed")
	check(Game.current_area_id == aid and World.last_hearth.get("hearth", "") == "hs_outer_ring", "at the Outer Ring")
	for h in ["hs_drove_road", "hs_colliers_clearing", "hs_outer_ring", "hs_the_pine"]:
		check(_hearth_lit(h), "%s stays lit" % h)
	check(World.is_cleared(aid) and World.flag("ks_hedgelayer_released") and World.area_flag(aid, "slain_hedgelayer"), "the Hedgelayer stays released")
	check(Game.find_hearth("hs_the_pine") != null, "the Pine still burns")
	check(_flat_gate(), "the gate still lies across the gap")
	var inv := player.inventory
	check(int(inv.get("item_song_cord", 0)) == 1 and int(inv.get("item_knucklebone", 0)) == 1 and int(inv.get("hedging_bill", 0)) == 1
		and int(inv.get("armour_collier", 0)) == 1 and int(inv.get("item_birch_ring", 0)) == 0,
		"the Pack: the song-cord, the knucklebone, the hedging bill, the leathers; the ring with Linnet")
	check(_journal("song_cord") == _all_lines("song_cord") and _journal("knucklebones") == _expected("knucklebones"), "both threads as they were left")
	var souls := _souls()
	check(souls.has("linnet") and souls.has("eyvind_gate") and not souls.has("eyvind"), "Linnet and Eyvind at the gap")
	check(_awake_foes().is_empty() and World.get_area_state(aid) == RH.WState.THAW, "a quiet wood")
	check(_portal_to("shepherds_reach") != null, "the fell path on to Shepherd's Reach stands")
