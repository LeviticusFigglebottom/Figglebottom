extends FullgameBase
## The Lowe, end to end, from the save the slice walk ends on: over the pass
## in THAW, Aud and Hesk, the forced first rest at the Barrow Road, the
## drawbridge lowered and walked both ways across the second seam, Orm's
## cord out of the first barrow, one death and its Breathmark, the frozen
## bog to the tongs and the peat island, the road fought through to the
## Drying Stacks, the frost veil and the Turfwright (his AI runs all three
## phases; only the Bearer's blows on him are scaled), the release (card,
## Outsong, tally-stick, the Open Barrow hearth), Arne and his girls in
## THAW, both Keepsakes threads closed in separate talks, and the last
## rest at the Open Barrow, the hearth nearest the Kettle Fjord seam.

## The Bearer's blows on the Turfwright are scaled by this, and by nothing
## else (the slice's own figure for the Netmender).
const DUEL_MULT := 3.0
const ISLE := Vector3(-39.5, 44.44, -189.2)
const BOG_SHORE := Vector3(-40, 44.0, -160)

var _cards: Array = []

func _init() -> void:
	region = "lowe"
	aid = "lowe_barrows"
	start_fixture = "fullgame_after_saltfell"

# ------------------------------------------------------------ region helpers
func _on_card(text: String, _hold := 0.0) -> void:
	_cards.append(text)

var _gained := 0
var _warmth_was := 0
func _on_warmth(now: int) -> void:
	if now > _warmth_was:
		_gained += now - _warmth_was
	_warmth_was = now

## At an open hearth sheet: grow by warmth while it lasts, heart and might
## by turns (what a player puts warmth in before a Holdfast). Leaves the
## sheet on its main page. Returns the levels bought.
func _grow(rest: RestUI, most := 12) -> int:
	rest.choose(_option_index(rest, "level"))
	await ticks(2)
	var bought := 0
	while bought < most and Game.warmth >= rest._level_cost():
		var lv := player.level
		rest.choose(_option_index(rest, "stat:heart" if bought % 2 == 0 else "stat:might"))
		if player.level != lv + 1:
			break
		bought += 1
	rest.choose(_option_index(rest, "back"))
	await ticks(2)
	return bought

## The thread's first n lines. `without`: a step this walk does not take (the
## points of interest add one to a thread, found off the thread's own road).
func _expected(thread_id: String, n: int, without := "") -> Array:
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			return (t["steps"] as Array).filter(func(s): return String(s["flag"]) != without).slice(0, n).map(func(s): return String(s["line"]))
	return []

func _has(item: String) -> int:
	return int(player.inventory.get(item, 0))

func _reaches(to: Vector3, from: Vector3, tol := 2.5) -> bool:
	var p := _path(from, to)
	return p.size() > 1 and Vector2(p[p.size() - 1].x - to.x, p[p.size() - 1].z - to.z).length() < tol

func _ray_y(x: float, z: float, top: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -30, z), RH.M_WORLD_ALL)
	var hit := area.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"].y if not hit.is_empty() else -999.0

func _bridge() -> DrawBridge:
	var b := area.find_children("*", "DrawBridge", true, false)
	return b[0] if not b.is_empty() else null

func _bog_hazard() -> HazardVolume:
	for h in area.find_children("*", "HazardVolume", true, false):
		if (h as HazardVolume).kind == "bog":
			return h
	return null

func _visible_npc(id: String) -> NPC:
	for n in area.find_children("*", "NPC", true, false):
		if (n as NPC).npc_id == id and (n as NPC).is_visible_in_tree():
			return n
	return null

func _service_ids(ui: DialogueUI) -> Array:
	return ui._options.map(func(o): return String(o.get("id", "")))

func _pos() -> String:
	return str(player.global_position.snapped(Vector3.ONE * 0.1))

func _wake() -> void:
	if player.dead:
		await _until(func(): return not player.dead, 10.0)
		await ticks(30)
		area = Game.current_area

## Walk somewhere through the frost-taken, coming back from the hearth if
## they bring the Bearer down on the way (a player just tries again).
func _go(to: Vector3, tries := 3) -> bool:
	for i in tries:
		await _wake()
		if await _walk_path(to, 7200, true):
			return true
		if not player.dead:
			await _fight(12.0, 60.0)
			if await _walk_path(to, 3600, true):
				return true
	return false

## _take, but a fall on the way is walked off and tried again.
func _fetch(pickup_id: String, prompt_prefix: String, tries := 3) -> bool:
	for i in tries:
		await _wake()
		if await _take(pickup_id, prompt_prefix, true) and not player.dead:
			return true
		if _pickup(pickup_id) == null:
			return true
	return false

## Straight along a line of points and over a seam (a bridge deck: the far
## side's navmesh need not hold it, and a detour by the rim ends in the
## ravine). A fall on the way is not a crossing.
func _cross_line(to_area: String, pts: Array) -> bool:
	var stilled0 := _stilled
	_halt = func(): return Game.current_area_id == to_area
	for p in pts:
		if Game.current_area_id == to_area or player.dead:
			break
		await _walk_to(p, 900, 0.5, false)
	_halt = Callable()
	player.sim_move = Vector3.ZERO
	var ok := await _until(func(): return Game.current_area_id == to_area and player.input_enabled, 12.0)
	area = Game.current_area
	if ok:
		await ticks(30)
	if not ok or _stilled != stilled0:
		print("  (cross to %s: in %s at %s, falls %d)" % [to_area, Game.current_area_id, _pos(), _stilled - stilled0])
	return ok and _stilled == stilled0

## A thing inside a barrow passage: the navmesh stops at the door (the dead
## sit in the mouth; nothing paths further in), so the last metres are
## walked straight from where the Bearer stands.
func _take_inside(pickup_id: String, prompt_prefix: String) -> bool:
	var pk := _pickup(pickup_id)
	if pk == null or not pk.is_visible_in_tree():
		return false
	await _walk_to(pk.global_position, 600, 0.6, true)
	await _fight(8.0, 60.0)
	await _walk_to(pk.global_position, 300, 0.6, true)
	await _settle()
	if _near_interact(prompt_prefix) == null:
		var it := player.nearest_interactable()
		print("  (pickup %s: at %s, %.1f m off, prompt %s)" % [pickup_id, _pos(),
			player.global_position.distance_to(pk.global_position), it.prompt if it != null else "nothing"])
		return false
	player.try_interact()
	await ticks(6)
	return true

# ----------------------------------------------------------------- the walk
func _region() -> void:
	Game.area_title.connect(_on_card)
	Game.title_card.connect(_on_card)
	_warmth_was = Game.warmth
	Game.warmth_changed.connect(_on_warmth)

	print("== the pass: Saltfell to the Lowe")
	check(Game.current_area_id == "saltfell_steading", "the walk starts in Saltfell")
	var seam := _portal_to("lowe_barrows", Vector3(-89, 23, -85))
	check(seam != null, "the pass seam stands")
	var crossed := await _cross("lowe_barrows", seam.global_position + Vector3(0, 0, -1.0))
	check(crossed, "the Bearer walks over the pass into the Lowe (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return

	print("== the Lowe, in THAW")
	check(World.get_area_state(aid) == RH.WState.THAW, "first arrival is THAW")
	await _until(func(): return hud.last_title == "THE BARROW ROAD", 8.0)
	check(_cards.size() >= 2 and String(_cards[_cards.size() - 2]).to_upper() == "THE LOWE"
		and _cards[_cards.size() - 1] == "THE BARROW ROAD", "the region's card, then THE BARROW ROAD (%s)" % str(_cards))
	check(hud.last_title == "THE BARROW ROAD", "the card on the HUD (%s)" % hud.last_title)
	check(_awake_foes().is_empty(), "no enemies in THAW")
	check(Game.find_hearth("hs_barrow_road") != null and Game.find_hearth("hs_drying_stacks") != null
		and Game.find_hearth("hs_open_barrow") == null, "two hearths stand; the Open Barrow is cold")
	check(_visible_npc("arne") == null and _visible_npc("liv") == null, "no Arne, no twins yet")
	check(not _bridge().is_down() and not World.flag("lowe_bridge_down"), "the bridge stands raised")
	await _shot("pass_thaw")

	print("== Aud on the road")
	var ui := await _talk("aud")
	check(ui != null, "the Bearer walks to Aud and speaks with her (%s)" % _pos())
	if ui != null:
		await _shot("aud_talk")
		var al: Array = await _lines_of(ui)
		check(al == DB.npc("aud")["lines_first"] and al.size() == 5
			and String(al[0]).begins_with("Keep to the road, love."), "Aud's first lines, in order (%d)" % al.size())
		var ids := _service_ids(ui)
		check(ids.has("buy_turf_song") and ids.has("rest_level") and not ids.has("give_barrow_cloak"),
			"she teaches the Turf-Laying Song and sits you down; no cloak yet (%s)" % str(ids))
		var w0 := Game.warmth
		ui.choose(ids.find("buy_turf_song"))
		await ticks(4)
		check(_has("turf_song") == 1 and Game.warmth == w0 - 240, "the Turf-Laying Song is learned for 240 warmth")
		check(ui.text_label.text.begins_with("It's counting, mostly."), "and she says how it goes (%s)" % ui.text_label.text.left(30))
		await _leave(ui)
	check(_ui("DialogueUI") == null and player.input_enabled, "Leave closes the talk and hands control back")
	check(World.flag("ks_aud_met"), "Aud's thread begins")
	check("THE KIN-MOUNDS" in _cards, "THE KIN-MOUNDS is named among the barrows (%s)" % hud.last_title)

	print("== Hesk at the cutting")
	ui = await _talk("hesk")
	check(ui != null, "the Bearer walks to Hesk and speaks with him (%s)" % _pos())
	if ui != null:
		await _shot("hesk_talk")
		var hl: Array = await _lines_of(ui)
		check(hl == DB.npc("hesk")["lines_first"] and hl.size() == 5
			and hl[0] == "Don't stand there, you're in my draught. There. No. There.", "Hesk's first lines, in order (%d)" % hl.size())
		var ids2 := _service_ids(ui)
		check(ids2.has("fold_iron") and ids2.has("buy_bog_iron") and ids2.has("buy_maul") and not ids2.has("fold_iron_kin"),
			"he folds iron, sells bog-iron and the post maul (%s)" % str(ids2))
		await _leave(ui)
	check(World.flag("ks_hesk_met"), "Hesk's thread begins")
	check(_journal("aud_cord") == _expected("aud_cord", 1) and _journal("hesk_tongs") == _expected("hesk_tongs", 1),
		"two threads, one line each")

	print("== the bog in THAW: black water")
	var bog := _bog_hazard()
	check(bog != null and bog.is_visible_in_tree() and bog.can_process(), "the bog drags and drowns in THAW")
	check(not _reaches(ISLE, BOG_SHORE), "no THAW route to the peat island")
	check(_pickup("hesk_tongs") == null or not _pickup("hesk_tongs").is_visible_in_tree(), "the tongs are under the water")

	print("== the first rest forces RIME")
	var rest := await _rest_ui_at("hs_barrow_road")
	check(rest != null, "the Barrow Road offers its hearth (%s)" % _pos())
	if rest != null:
		await _shot("rest_menu_thaw")
		check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0,
			"uncleared THAW: rest only, no turning back")
		# Saltfell's warmth, spent before the winter comes down
		var lv0 := player.level
		var hp0 := player.max_hp
		var grown := await _grow(rest)
		check(grown > 0 and player.level == lv0 + grown and player.max_hp > hp0 and Game.warmth < rest._level_cost(),
			"%d levels grown by warmth (%d -> %d, %d warmth left)" % [grown, lv0, player.level, Game.warmth])
		rest.choose(_option_index(rest, "rest"))
		await _wait_turn()
	check(World.get_area_state(aid) == RH.WState.RIME, "the Lowe is RIME now")
	check(World.last_hearth.get("hearth", "") == "hs_barrow_road" and _hearth_lit("hs_barrow_road"), "the Barrow Road is the anchor")
	check(_visible_npc("aud") == null and _visible_npc("hesk") == null, "Aud and Hesk are gone in RIME")
	var foes := _awake_foes()
	var kinds := {}
	for e in foes:
		kinds[(e as Enemy).id] = int(kinds.get((e as Enemy).id, 0)) + 1
	check(foes.size() == 10 and int(kinds.get("barrow_sleeper", 0)) == 4 and int(kinds.get("keener", 0)) == 3
		and int(kinds.get("cairn_carrier", 0)) == 2 and int(kinds.get("turfwright", 0)) == 1,
		"the frost-taken stand (%s)" % str(kinds))
	check(foes.filter(func(e): return (e as Enemy).idle_pose == "sit_up").size() == 3, "three of the dead sit up in the barrow mouths")
	rest = await _rest_ui_at("hs_barrow_road")
	check(rest != null and String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0,
		"uncleared RIME: rest only")
	if rest != null:
		rest.choose(_option_index(rest, "leave"))
		await ticks(4)
	await _shot("road_rime")

	print("== the drawbridge, lowered from the Lowe side")
	var bridge := _bridge()
	var windlass := bridge.global_position + Vector3(0, 0, -1.0)
	_gained = 0
	check(await _go(windlass), "along the ravine rim to the windlass (%s)" % _pos())
	await _fight(12.0, 60.0)
	check(not player.dead, "the Bearer lives past the sleeper at the windlass")
	check(_gained > 0, "the fallen give up warmth (%d)" % _gained)
	await _walk_to(windlass, 300, 0.5, true)
	await _settle()
	check(_ray_y(-8, -76.0, 30) < 15.0, "nothing spans the ravine yet")
	check(_near_interact("Lower the bridge") != null, "the windlass offers itself")
	await _shot("windlass")
	player.try_interact()
	await _secs(3.2)
	check(World.flag("lowe_bridge_down") and bridge.is_down(), "the bridge is down for good (world flag)")
	check(absf(_ray_y(-8, -76.0, 30) - bridge.global_position.y) < 0.4, "the deck spans the ravine")
	check(_near_interact("Lower the bridge") == null, "the windlass has nothing more to give")
	var deck_y := bridge.global_position.y + 0.1
	check(_portal_to("saltfell_steading", Vector3(-8, 22, -75.7)) != null, "the bridge seam stands on the Lowe side")
	var falls0 := _stilled
	crossed = await _cross_line("saltfell_steading", [Vector3(-8, deck_y, -83.5), Vector3(-8, deck_y, -74.4)])
	check(crossed, "over the deck and the second seam into Saltfell (%s)" % _pos())
	if crossed:
		var over: bool = await _walk_to(Vector3(-8, deck_y, -66.0), 600, 1.0, false)
		check(over and player.is_on_floor() and not player.dead, "off the far end onto the Saltfell yard (%s)" % _pos())
		check(_bridge() != null and _bridge().is_down(), "Saltfell sees the same bridge down")
		check(_reaches(Vector3(-2, 22, 3), player.global_position, 3.0), "the yard lies ahead: the shortcut joins the two regions")
		await _shot("bridge_saltfell_side")
		check(_portal_to("lowe_barrows", Vector3(-8, 22, -75.7)) != null, "the bridge seam stands on the Saltfell side")
		crossed = await _cross_line("lowe_barrows", [Vector3(-8, deck_y, -67.5), Vector3(-8, deck_y, -77.0)])
		check(crossed, "and back over it into the Lowe (%s)" % _pos())
		over = await _walk_to(Vector3(-8, deck_y, -85.5), 600, 1.0, true)
		check(over and not player.dead, "off the deck at the windlass (%s)" % _pos())
		check(World.get_area_state(aid) == RH.WState.RIME and _bridge().is_down(), "the Lowe is as it was left: RIME, bridge down")
	check(_stilled == falls0, "nobody fell into the ravine (%d)" % (_stilled - falls0))
	print("  (the deck on the Lowe's navmesh: %s)" % str(_reaches(Vector3(-8, 22.1, -72.0), Vector3(-8, 22.1, -86.0), 1.5)))
	area = Game.current_area

	print("== Orm's cord, in the first barrow")
	check(await _fetch("orm_cord", "Take the knot-cord"), "to the mouth of the first barrow (%s)" % _pos())
	check(_has("item_orm_cord") == 1 and World.flag("ks_aud_cord_found"), "the knot-cord is taken from the one who sat up there")
	var wg := Game.warmth
	check(await _take_inside("kin_a_grave_goods", "Take what was left"), "further in, the grave goods (%s)" % _pos())
	check(Game.warmth >= wg + 60, "60 warmth for the road")
	await _shot("kin_a")

	print("== STILLED, and the Breathmark")
	await _die_and_recover("hs_barrow_road")

	print("== the frozen bog")
	bog = _bog_hazard()
	check(bog != null and not bog.can_process(), "in RIME the black water takes nobody")
	check(_reaches(ISLE, BOG_SHORE), "the RIME navmesh crosses the ice to the peat island")
	check(await _fetch("hesk_tongs", "Chip the tongs out of the ice"), "over the ice to the tongs (%s)" % _pos())
	check(_has("item_hesk_tongs") == 1 and World.flag("ks_hesk_tongs_found"), "Hesk's tongs are chipped out of the ice")
	var bog_w := float((area.get_meta("def") as Dictionary)["water"][3]["at"][1])
	check(absf(player.global_position.y - bog_w) < 0.6 and Vector2(player.global_position.x + 40.0, player.global_position.z + 190.0).length() < 30.0,
		"the Bearer stands on the bog ice (y %.2f, ice %.2f)" % [player.global_position.y, bog_w])
	var iron0 := _has("bog_iron")
	check(await _fetch("peat_island_iron", "Pry up the bog-iron"), "on to the peat island (%s)" % _pos())
	check(_has("bog_iron") == iron0 + 2, "two lumps of bog-iron pried up")
	await _secs(4.0)
	check(not player.dead, "four seconds on the ice and nothing gives")
	check(_journal("aud_cord") == _expected("aud_cord", 2) and _journal("hesk_tongs") == _expected("hesk_tongs", 2),
		"both finds are remembered")
	await _shot("bog_rime")

	print("== the Kin-Mounds, fought through")
	check(await _fetch("woad_thread", "Untie the thread"), "to the closed barrow (%s)" % _pos())
	check(_has("ks_woad_thread") == 1, "the woad thread is untied from its stone")
	check(await _fetch("turf_spade", "Work the spade loose"), "to the last barrow on the road (%s)" % _pos())
	check(_has("turf_spade") == 1 and player.hotbar.has("turf_spade"), "the Turf Spade comes loose and seats itself in a hand-slot")
	await _shot("kin_d")

	print("== the Drying Stacks")
	rest = null
	for i in 3:
		await _wake()
		rest = await _rest_ui_at("hs_drying_stacks")
		if rest != null:
			break
	check(rest != null, "the Drying Stacks offers its hearth (%s)" % _pos())
	if rest != null:
		# what the road gave, spent before the Holdfast
		var lv := player.level
		var bought := await _grow(rest)
		print("  (%d more levels from the road: %d -> %d, %d warmth left)" % [bought, lv, player.level, Game.warmth])
		check(_option_index(rest, "toggle") < 0, "still no turning back")
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.2)
		await _until(func(): return player.input_enabled, 6.0)
	check(World.last_hearth.get("hearth", "") == "hs_drying_stacks" and _hearth_lit("hs_drying_stacks"),
		"the Drying Stacks is lit and kept")
	check(World.get_area_state(aid) == RH.WState.RIME, "and the Lowe stays RIME")

	print("== the frost veil")
	var veil := _veil()
	check(veil != null, "a frost veil stands across the gap in the sod wall")
	var veil_at := veil.global_position
	var parted := false
	for i in 3:
		await _wake()
		parted = await _part_veil(veil, true)
		if parted:
			break
	check(parted and Game.arena_locked, "the veil seals at the Bearer's back (%s)" % _pos())
	check(player.global_position.z < veil.global_position.z - 1.5 and player.is_on_floor(),
		"and he stands inside the ring, on the turf (%s)" % _pos())
	await _secs(1.0)
	check("THE OPEN BARROW" in _cards, "THE OPEN BARROW is named inside the ring (%s)" % hud.last_title)

	print("== the Turfwright")
	var tw := _foe("turfwright") as Turfwright
	check(tw != null, "the Turfwright stands at the twins' barrow")
	if tw == null:
		return
	check(tw.state == Enemy.ES.IDLE and not tw.stood and tw.sod_at == "spade", "holding the last sod up to the door, his back to the road")
	check(not hud.boss_root.visible, "no bar until he turns")
	await _shot("turfwright_door")
	var seen := {"bar": false, "walls": 0, "hold": false, "phase": 0, "n": 0}
	var each := func(b: Enemy) -> void:
		var t := b as Turfwright
		seen["n"] = int(seen["n"]) + 1
		if t.phase != int(seen["phase"]) or int(seen["n"]) % 30 == 0:
			seen["phase"] = t.phase
			print("  (duel %d s: phase %d, he has %.0f of %.0f, state %d at %s; the Bearer %.0f hp, %d gourds, at %s, falls %d)" % [
				int(seen["n"]) * 2, t.phase, t.hp, t.max_hp, t.state, str(t.global_position.snapped(Vector3.ONE * 0.1)),
				player.hp, player.gourds, _pos(), _stilled])
		if t.stood and hud.boss_root.visible and hud.boss_name.text == "THE TURFWRIGHT":
			seen["bar"] = true
		seen["walls"] = maxi(int(seen["walls"]), t.live_walls())
		if t.state == Enemy.ES.HOLD:
			seen["hold"] = true
	var res: Dictionary = await _duel("turfwright", veil, DUEL_MULT, 900.0, each)
	tw = res["boss"] as Turfwright
	var phases: Dictionary = res["phases"]
	check(tw != null and tw.dead, "the Turfwright is released (deaths along the way: %d)" % int(res["deaths"]))
	check(seen["bar"], "he set the sod down, turned, and the bar read THE TURFWRIGHT")
	check(phases.has(2) and phases.has(3), "his AI ran all three phases (%s)" % str(phases.keys()))
	check(int(seen["walls"]) == 4, "the four bay walls stood in phase two (%d)" % int(seen["walls"]))
	print("  (the last turf held at the door: %s)" % str(seen["hold"]))

	print("== the release")
	await _secs(1.0)
	check(String(AudioDirector._active_music).ends_with("outsong.ogg"), "the Outsong is sung (%s)" % AudioDirector._active_music)
	check(hud.last_title == "THE TURFWRIGHT — RELEASED" and "THE TURFWRIGHT — RELEASED" in _cards, "the quiet card (%s)" % hud.last_title)
	await _shot("release_card")
	check(World.flag("ks_turfwright_released"), "the release flag is set")
	check(World.is_cleared(aid), "the Lowe is cleared")
	check(not Game.arena_locked, "the veil falls")
	check(tw != null and tw.released and tw.sod_at == "door", "he lays the sod in the doorway")
	check(tw != null and tw.live_ridges() == 0 and tw.live_walls() == 0, "the cuts and the bay walls sink back")
	var stick := _pickup("tally_stick")
	check(stick != null and stick.item_id == "item_tally_stick" and tw != null
		and stick.global_position.distance_to(tw.global_position) < 3.0, "the tally-stick lies in front of where he knelt")
	check(await _take("tally_stick", "Take the tally-stick", false), "the Bearer walks to it (%s)" % _pos())
	check(_has("item_tally_stick") == 1, "Arne's tally-stick is taken")
	await _shot("tally_stick")
	check(Game.find_hearth("hs_open_barrow") != null, "the Open Barrow hearth wakes")
	check(_awake_foes().filter(func(e): return e.id == "turfwright").is_empty(), "nothing left to fight at the door")

	print("== the Open Barrow hearth")
	rest = await _rest_ui_at("hs_open_barrow")
	check(rest != null and _option_index(rest, "toggle") >= 0 and _option_index(rest, "rest") >= 0,
		"it can be rested at, and offers to turn the memory (%s)" % _pos())
	if rest != null:
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.2)
		await _until(func(): return player.input_enabled, 6.0)
	check(World.last_hearth.get("hearth", "") == "hs_open_barrow" and _hearth_lit("hs_open_barrow"), "the Open Barrow is lit and kept")
	check(World.get_area_state(aid) == RH.WState.RIME, "a plain rest keeps the RIME")
	check(_foe("turfwright") == null, "he does not come back with the rest")
	check(_near_interact("Part") == null and not Game.arena_locked, "and the veil stays down")
	var spindles := _pickup("twin_spindles")
	check(spindles != null and spindles.is_visible_in_tree(), "the twins' spindles lie on the threshold stone")
	if spindles != null and spindles.is_visible_in_tree():
		check(await _take("twin_spindles", "Take the spindles", true), "the Bearer walks to the threshold (%s)" % _pos())
		check(_has("item_twin_spindles") == 1, "the spindles are taken")
	check(await _rest("hs_open_barrow", "toggle"), "the memory is turned at the Open Barrow")
	check(World.get_area_state(aid) == RH.WState.THAW, "warmed: THAW again")
	check(_awake_foes().is_empty(), "no enemies in THAW")

	print("== Arne and his girls outside the barrow")
	var arne := _visible_npc("arne")
	var liv := _visible_npc("liv")
	var asta := _visible_npc("asta")
	check(arne != null and liv != null and asta != null, "Arne, Liv and Asta are there")
	if arne != null and liv != null and asta != null:
		var heard := []
		var on_heard := func(who: String, line: String): heard.append([who, line])
		arne.overheard.connect(on_heard)
		check(arne.seated and liv.seated and asta.seated, "all three sit")
		check(arne._vis.current_clip() == "sit_talk" and liv._vis.current_clip() == "sit" and asta._vis.current_clip() == "sit",
			"Arne talks from the grass, a sod under each girl")
		check(liv.global_position.distance_to(arne.global_position) < 2.0 and asta.global_position.distance_to(arne.global_position) < 2.0
			and liv.global_position.x < arne.global_position.x and asta.global_position.x > arne.global_position.x, "the twins either side of him")
		var door := Vector3(46.0, arne.global_position.y, -214.0)
		check((-arne.global_transform.basis.z).dot(arne.global_position - door) > 0.0, "outside the barrow, their backs to it")
		var by := arne.global_position + Vector3(0.5, 0, 4.0)
		await _walk_path(by, 2400, false)
		await _settle()
		check(player.global_position.distance_to(arne.global_position) < 9.0, "the Bearer stands by them (%s)" % _pos())
		var it := player.nearest_interactable()
		check(it == null or not it.prompt.begins_with("Speak with"), "nobody in the scene can be spoken to")
		await _secs(12.0)
		var want: Array = DB.npc("arne")["overhear"]
		check(heard.size() >= 2 and want.find(heard[0]) >= 0 and want[(want.find(heard[0]) + 1) % want.size()] == heard[1],
			"the argument is overheard, in order (%s)" % str(heard.slice(0, 2)))
		check(hud.overheard_label.text.begins_with("Liv: ") or hud.overheard_label.text.begins_with("Arne: ")
			or hud.overheard_label.text.begins_with("Asta: "), "low over the belt, with who said it (%s)" % hud.overheard_label.text)
		await _shot("arne_and_the_twins")
		await _until(func(): return heard.has(want[want.size() - 1]), 4.6 * 9 + 16.0)
		check(heard.has(want[want.size() - 1]), "to the last line: %s (heard %d)" % [str(want[want.size() - 1][1]), heard.size()])
		arne.overheard.disconnect(on_heard)

	print("== Orm's cord goes home")
	ui = await _talk("aud")
	check(ui != null, "Aud, in THAW again (%s)" % _pos())
	if ui != null:
		var a1: Array = await _lines_of(ui)
		check(a1 == DB.npc("aud")["lines_when"][1]["lines"] and String(a1[0]).begins_with("That's Orm's cord."),
			"she takes the cord and will not be told (%s)" % str(a1.slice(0, 1)))
		check(World.flag("ks_aud_cord") and _has("item_orm_cord") == 0, "the cord is hers")
		check(not World.flag("ks_aud_heather"), "the heather waits for the next talk")
		var ids3 := _service_ids(ui)
		check(ids3.has("give_barrow_cloak") and not ids3.has("buy_turf_song"), "Orm's working cloak is offered; the song is already learned (%s)" % str(ids3))
		if ids3.has("give_barrow_cloak"):
			ui.choose(ids3.find("give_barrow_cloak"))
			await ticks(4)
			check(_has("armour_barrow_cloak") == 1 and ui.text_label.text.begins_with("He was long in the arm."), "the Bearer takes the cloak")
		await _shot("aud_cord")
		await _leave(ui)
	check(_journal("aud_cord") == _expected("aud_cord", 3), "three lines in her thread")
	ui = await _talk("aud")
	check(ui != null, "Aud, a second time")
	if ui != null:
		var a2: Array = await _lines_of(ui)
		check(a2 == DB.npc("aud")["lines_when"][0]["lines"] and String(a2[0]).begins_with("I've moved the heather."),
			"then she has moved the heather (%s)" % str(a2.slice(0, 1)))
		check(not _service_ids(ui).has("give_barrow_cloak"), "the cloak is not offered twice")
		await _leave(ui)
	check(World.flag("ks_aud_heather") and _journal("aud_cord") == _expected("aud_cord", 4),
		"Orm's cord: four lines, in order (%d)" % _journal("aud_cord").size())

	print("== Hesk's tongs go home")
	var iron1 := _has("bog_iron")
	ui = await _talk("hesk")
	check(ui != null, "Hesk, in THAW again (%s)" % _pos())
	if ui != null:
		var h1: Array = await _lines_of(ui)
		check(h1 == DB.npc("hesk")["lines_when"][1]["lines"] and String(h1[0]).begins_with("Never that good, these."),
			"he takes the tongs and runs them down (%s)" % str(h1.slice(0, 1)))
		check(World.flag("ks_hesk_tongs") and _has("item_hesk_tongs") == 0, "the tongs are his again")
		check(_has("bog_iron") == iron1 + 1, "and he gives a lump of bog-iron for them")
		check(not World.flag("ks_hesk_wind"), "the wind waits for the next talk")
		var ids4 := _service_ids(ui)
		check(ids4.has("fold_iron_kin") and not ids4.has("fold_iron"), "he folds iron for less now (%s)" % str(ids4))
		if ids4.has("fold_iron_kin"):
			var wl := player.weapon_level
			var wf := Game.warmth
			var can := Game.warmth >= 140
			ui.choose(ids4.find("fold_iron_kin"))
			await ticks(4)
			if can:
				check(player.weapon_level == wl + 1 and Game.warmth == wf - 140 and _has("bog_iron") == iron1,
					"a lump folded into the blade for 140 warmth (+%d)" % player.weapon_level)
				check(ui.text_label.text.begins_with("There. It'll hold an edge now."), "and he says so")
			else:
				check(player.weapon_level == wl and ui.text_label.text == "140 warmth for the fire. Peat doesn't cut itself.",
					"short of warmth, he names his price (%s)" % ui.text_label.text)
		await _shot("hesk_tongs")
		await _leave(ui)
	check(_journal("hesk_tongs") == _expected("hesk_tongs", 3), "three lines in his thread")
	ui = await _talk("hesk")
	check(ui != null, "Hesk, a second time")
	if ui != null:
		var h2: Array = await _lines_of(ui)
		check(h2 == DB.npc("hesk")["lines_when"][0]["lines"] and h2[0] == "Wind's come right. First time all summer. I don't trust it.",
			"then the wind has come right (%s)" % str(h2.slice(0, 1)))
		await _leave(ui)
	check(World.flag("ks_hesk_wind") and _journal("hesk_tongs") == _expected("hesk_tongs", 4, "ks_hesk_iron"),
		"Hesk's tongs: four lines, in order (%d)" % _journal("hesk_tongs").size())

	print("== the bog in THAW again")
	bog = _bog_hazard()
	check(bog != null and bog.can_process() and not _reaches(ISLE, BOG_SHORE), "the black water is back: no way to the island")
	check(_reaches(Vector3(-67.4, 36.4, -253.5), player.global_position, 3.0), "the road on to Kettle Fjord lies open")
	print("== turned again at the Drying Stacks: RIME without its Holdfast")
	check(await _rest("hs_drying_stacks", "toggle"), "the Drying Stacks turns freely now (%s)" % _pos())
	check(World.get_area_state(aid) == RH.WState.RIME, "stilled again: RIME")
	check(_awake_foes().size() == 9 and _foe("turfwright") == null, "the frost-taken stand again; he does not (%d)" % _awake_foes().size())
	check(_visible_npc("arne") == null and _visible_npc("aud") == null, "the living are gone with the THAW")
	# (a veil that fell with its Holdfast came back as an unseen wall here)
	var q := PhysicsRayQueryParameters3D.create(veil_at + Vector3(0, 1.2, 3.0), veil_at + Vector3(0, 1.2, -3.0), RH.M_WORLD_ALL)
	q.exclude = [player.get_rid()]
	check(area.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "nothing stands in the gap of the sod wall")
	check(await _go(veil_at + Vector3(0, 0, 3.0)), "back to the gap (%s)" % _pos())
	await _fight(12.0, 60.0)
	var through: bool = await _walk_to(veil_at + Vector3(0, 0, -4.0), 900, 0.8, true)
	check(through and player.global_position.z < veil_at.z - 2.0, "and the Bearer walks straight in through it (%s)" % _pos())
	check(_near_interact("Part") == null and not Game.arena_locked, "nothing to part, nothing sealed")
	check(await _rest("hs_open_barrow", "toggle"), "and the memory is warmed again at the Open Barrow (%s)" % _pos())
	check(World.last_hearth.get("hearth", "") == "hs_open_barrow" and String(World.last_hearth.get("area", "")) == aid,
		"the Open Barrow is the kept hearth")
	check(World.get_area_state(aid) == RH.WState.THAW, "and the Lowe is left warm")
	await _shot("open_barrow_thaw_end")
	Game.area_title.disconnect(_on_card)
	Game.title_card.disconnect(_on_card)
	Game.warmth_changed.disconnect(_on_warmth)

func _after_load() -> void:
	print("== the Lowe, resumed")
	check(_hearth_lit("hs_barrow_road") and _hearth_lit("hs_drying_stacks") and _hearth_lit("hs_open_barrow"), "all three hearths lit")
	check(Game.find_hearth("hs_open_barrow") != null, "the Open Barrow hearth still stands")
	check(World.flag("lowe_bridge_down") and _bridge() != null and _bridge().is_down(), "the bridge stays down")
	check(absf(_ray_y(-8, -80.0, 30) - _bridge().global_position.y) < 0.4, "its deck still spans the ravine")
	check(World.is_cleared(aid) and World.flag("ks_turfwright_released") and World.get_area_state(aid) == RH.WState.THAW,
		"the Lowe cleared and warm")
	check(_has("item_tally_stick") == 1 and _has("turf_spade") == 1 and _has("ks_woad_thread") == 1
		and _has("armour_barrow_cloak") == 1 and _has("turf_song") == 1 and _has("item_twin_spindles") == 1,
		"the tally-stick, the spade, the thread, the cloak, the song and the spindles are in the Pack")
	check(_has("item_orm_cord") == 0 and _has("item_hesk_tongs") == 0, "the cord and the tongs stayed with their people")
	check(_journal("aud_cord").size() == 4 and _journal("hesk_tongs").size() == 4, "both threads whole")
	check(_visible_npc("arne") != null and _visible_npc("liv") != null and _visible_npc("asta") != null
		and _visible_npc("aud") != null and _visible_npc("hesk") != null, "Arne and his girls, Aud and Hesk keep the THAW")
	check(_awake_foes().is_empty() and not Game.arena_locked, "no frost-taken, no veil")
	check(Game.difficulty == "gentle", "the winter kept")
