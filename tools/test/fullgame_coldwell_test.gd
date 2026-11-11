extends FullgameBase
## The Coldwell, end to end (COLDWELL.md), from the save the Shepherd's Reach
## walk ends on: over the seam at the High Fold's corner, the Upwater climbed
## in the last Melt with nobody on it, the Wellhead (the horn reads
## differently), Maren twice and Wren, back down to the first rest and the
## RIME, a fall and the Breathmark, the three Upwalkers and the three
## hearths, what the ice holds, the Unsung and a Song, the veil in the ring's
## gap, the Leadvoice through all three phases (her AI runs; the last
## quarter is sung, three verses, through the Sing prompt), her release (her
## name on the card, no Outsong, no warmth, no hearth, the band and the mask),
## the choice offered at the spring and walked to but NOT taken, the Melt
## remembered once more, and the last rest at the Wellhead Steps: the save
## both endings start from.
##
## COLDWELL.md defines no shortcut and no THAW-only or RIME-only route: one
## path, climbing. The nearest designed things are proved instead: the whole
## Upwater walks in both memories, and in RIME the veil stands in the ring's
## gap until she is released.

## The Bearer's blows on the Leadvoice are scaled by this, and by nothing
## else. It shortens phases one and two only: phase three is sung.
const DUEL_MULT := 2.0
const WELL := Vector3(922.0, 0.0, -478.0)
const RING_R := 10.0

const MAREN_FIRST := [
	"Have you come far? You look like you've come far.",
	"We came up to see the water go. She's never seen it go.",
	"Don't watch them out of sight, love. Turn round. Turn round when everyone else does.",
]
const MAREN_SECOND := [
	"I've an older one, down the water. Fostered, with boat-builders. Went off with a coal in a horn and wouldn't let me carry it as far as the boat.",
	"I said, keep it fed. As if anyone needs telling.",
	"Have you far to go?",
]
const MAREN_REPEAT := [
	"It's loud, isn't it. It's always this loud the first day.",
	"Have you far to go?",
]
const WREN_FIRST := ["That one's going to the sea.", "And that one."]
const WREN_SHOWN := ["I've got some like that.", "Mine have a bite in one. I did it. It didn't taste of anything."]
const HORN_HERE := "The horn a child carries down the water. The coal inside has been fed for twenty years. It was given with an instruction, and the instruction was followed."

const LEGS := ["seam", "climb_thaw", "people", "first_rest", "stilled", "upwater", "ice_falls", "steps",
	"level", "veil", "duel", "release", "choice", "melt_again", "end"]
var _skip_to := ""

var _titles: Array = []
var _cards: Array = []
var _n0 := 0
var veil: FrostVeil = null
var boss: Enemy = null
var rest: RestUI = null
var ui: DialogueUI = null
var took := false
var walked := false
var top := Vector3.ZERO
var foot := Vector3.ZERO
var _has_five := false
var _gained := 0
var _warmth_was := 0
func _on_warmth(now: int) -> void:
	# (what the frost-taken give up; a Breathmark taken back is not that)
	if now > _warmth_was and now - _warmth_was < 400:
		_gained += now - _warmth_was
	_warmth_was = now

func _init() -> void:
	region = "coldwell"
	aid = "coldwell"
	start_fixture = "fullgame_after_reach"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fullgame-leg="):
			_skip_to = a.get_slice("=", 1)

# ------------------------------------------------------------------ helpers
## (the Upwater is long: lift the polygon search cap a long route needs)
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

func _reach_len(a: Vector3, b: Vector3, tol := 2.5) -> float:
	var p := _path(a, b)
	if p.size() < 2 or _flat(p[p.size() - 1] - b).length() > tol:
		return INF
	var t := 0.0
	for i in range(1, p.size()):
		t += p[i].distance_to(p[i - 1])
	return t

func _all_lines(thread_id: String) -> Array:
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			return (t["steps"] as Array).map(func(s): return String(s["line"]))
	return []

func _expected(thread_id: String) -> Array:
	var out := []
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			for s in t["steps"]:
				if World.flag(String(s["flag"])):
					out.append(String(s["line"]))
	return out

func _souls() -> Dictionary:
	var out := {}
	for c in area.find_children("*", "NPC", true, false):
		var n := c as NPC
		if n.is_visible_in_tree() and not n.is_queued_for_deletion():
			out[n.npc_id] = n
	return out

func _choice() -> Node:
	for c in get_tree().get_nodes_in_group("ending_choice"):
		if area.is_ancestor_of(c):
			return c
	return null

func _horn() -> String:
	return String(DB.item("fostering_horn")["desc"])

## The dead stood in the frozen river: bodies, not foes.
func _river_dead() -> Array:
	return area.rime_layer.find_children("*", "Node3D", true, false).filter(func(n):
		var f := String((n as Node3D).scene_file_path)
		return (f.ends_with("enemies/upwalker.glb") or f.ends_with("enemies/unsung.glb")) \
			and (n as Node3D).is_visible_in_tree() and not _in_a_foe(n))

func _in_a_foe(n: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != area:
		if p is Enemy:
			return true
		p = p.get_parent()
	return false

## Maren and Wren stand a pace apart, and the prompt goes to whoever is
## nearer: come at the one wanted from her own side, as a player would.
func _talk(npc_id: String) -> DialogueUI:
	var n := _npc(npc_id)
	if n == null:
		return null
	var other := _npc("wren" if npc_id == "maren" else "maren")
	var who := "Speak with " + String(DB.npc(npc_id).get("short_name", ""))
	var away := _flat(n.global_position - other.global_position).normalized() if other != null else Vector3.ZERO
	for attempt in 4:
		var at := n.global_position + away.rotated(Vector3.UP, 0.5 * attempt) * 1.2
		await _walk_path(at, 3600, false)
		await _walk_to(at, 240, 0.35, false)
		await _settle()
		var it := player.nearest_interactable()
		if it != null and it.prompt == who:
			player.try_interact()
			await ticks(3)
			var dui := _ui("DialogueUI") as DialogueUI
			if dui != null:
				return dui
		print("  (talk %s, try %d: at %s, nearest %s)" % [npc_id, attempt + 1,
			str(player.global_position.snapped(Vector3.ONE * 0.1)), it.prompt if it != null else "nothing"])
	return null

func _wake_up() -> void:
	if player.dead:
		await _until(func(): return not player.dead, 10.0)
		await ticks(30)
		area = Game.current_area

## Rest (no turning) at a hearth, growing by warmth first while it lasts.
func _rest_and_grow(hearth_id: String) -> bool:
	rest = await _rest_ui_at(hearth_id)
	if rest == null:
		return false
	var i := _option_index(rest, "level")
	if i >= 0:
		rest.choose(i)
		await ticks(2)
		var n := 0
		while n < 6 and Game.warmth >= rest._level_cost():
			var lv := player.level
			rest.choose(_option_index(rest, "stat:heart" if n % 2 == 0 else "stat:might"))
			if player.level != lv + 1:
				break
			n += 1
		if n > 0:
			print("  (%d levels bought at %s: level %d)" % [n, hearth_id, player.level])
		rest.choose(_option_index(rest, "back"))
		await ticks(2)
	rest.choose(_option_index(rest, "rest"))
	await _secs(2.2)
	await _until(func(): return player.input_enabled, 6.0)
	return true

## Fight the Upwalker that stands on the path near `at` until it is down.
func _clear_upwalker(spawn_id: String) -> bool:
	var at := Vector3.ZERO
	for sp in area.get_meta("def")["spawners"]:
		if String(sp["id"]) == spawn_id:
			at = AreaBuilder._v3(sp["at"])
	for attempt in 3:
		await _wake_up()
		await _walk_path(at, 3600, true)
		await _fight(12.0, 90.0)
		if not player.dead and _foe_near(10.0) == null:
			return true
	return false

# ------------------------------------------------------- the Leadvoice
var _lv: Leadvoice = null
var _lv_home := Vector3.ZERO
var _log_n := 0
## What the fight showed. Her AI picks its own moves: the bar, the silence,
## her stillness, her shut hands and the verses are asserted; the rest is
## printed.
var _seen := {"bar": false, "music": [], "moved": 0.0, "hand": false, "ridges": 0, "unsung": 0, "upwalker": 0,
	"blows": 0, "stood_at": -1.0, "sing_prompt": false, "verses": [], "broken": 0, "song_broke": 0, "p3_blade": 0,
	"moves": {}}

func _on_blow(_who, result) -> void:
	if String(result) == "hit":
		_seen["blows"] += 1
		if _lv != null and is_instance_valid(_lv) and _lv.phase == 3:
			_seen["p3_blade"] += 1

func _sample(l: Leadvoice) -> void:
	if l.stood and hud.boss_root.visible and hud.boss_name.text == "THE LEADVOICE":
		_seen["bar"] = true
		if not (AudioDirector._active_music in _seen["music"]):
			_seen["music"].append(AudioDirector._active_music)
	_seen["moved"] = maxf(float(_seen["moved"]), _flat(l.global_position - _lv_home).length())
	if l.hitbox.monitoring or (l.fist_hitbox != null and l.fist_hitbox.monitoring) or (l.blade_hitbox != null and l.blade_hitbox.monitoring):
		_seen["hand"] = true
	_seen["ridges"] = maxi(int(_seen["ridges"]), get_tree().get_nodes_in_group("ice_ridges").filter(
		func(r): return is_instance_valid(r) and not r.is_queued_for_deletion()).size())
	_seen["unsung"] = maxi(int(_seen["unsung"]), l.dead_up("unsung").size())
	_seen["upwalker"] = maxi(int(_seen["upwalker"]), l.dead_up("upwalker").size())
	if l.state == Enemy.ES.ATTACK and not l._atk.is_empty():
		_seen["moves"][String(l._atk.get("id", "?"))] = true

## Her dead that have come close: a Song if there is breath for it (any Song
## breaks the Unsung outright), else the blade.
func _see_to_the_dead(l: Leadvoice, r := 4.5) -> void:
	var near: Array = l.dead_up("unsung").filter(func(m): return _flat((m as Enemy).global_position - player.global_position).length() < r)
	if near.is_empty():
		return
	var song := DB.song(player.attuned_song)
	if not song.is_empty() and player.breath >= float(song.get("breath", 99)) and player.state == Player.S.MOVE and player.input_enabled:
		player.sim_move = Vector3.ZERO
		player.cast_song(player.attuned_song)
		await _secs(0.9)
		var left: Array = near.filter(func(m): return is_instance_valid(m) and not (m as Enemy).dead)
		_seen["song_broke"] += near.size() - left.size()
		return
	await _fight(r + 1.0, 4.0)

## Where to stand to sing: inside the long note, outside her arms, clear of
## the well-housing, and away from an Upwalker if one has come in.
func _sing_spot(l: Leadvoice) -> Vector3:
	var best := Vector3.INF
	var bs := -INF
	var up: Array = l.dead_up("upwalker")
	for dir in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0)]:
		var at: Vector3 = l.global_position + dir * 3.8
		var s := -_flat(at - player.global_position).length()
		for u in up:
			s += minf(_flat((u as Enemy).global_position - at).length(), 8.0) * 3.0
		if s > bs:
			bs = s
			best = at
	return best

## Phase three: get inside the long note, stay outside her arms, keep the
## Unsung off for the length of a breath, and sing.
func _verses(l: Leadvoice) -> void:
	var t := 0
	while t < 60 * 30 and is_instance_valid(l) and not l.released and not player.dead and l.standing:
		_sample(l)
		if l.singing:
			player.sim_move = Vector3.ZERO
			await ticks(6)
			t += 6
			continue
		await _see_to_the_dead(l)
		if player.dead or l.released:
			return
		var d := _flat(l.global_position - player.global_position).length()
		if d > 4.2 or d < 3.4:
			var spot := _sing_spot(l)
			await _walk_path(spot, 300, false)
			await _walk_to(spot, 120, 0.5, false)
			t += 60
		var to := l.global_position - player.global_position
		player.cam.yaw = atan2(-to.x, -to.z)
		player.sim_move = Vector3.ZERO
		if player.state == Player.S.MOVE and player.input_enabled and l.sing_zone.enabled and _near_interact("Sing") != null:
			_seen["sing_prompt"] = true
			player.try_interact()
			await ticks(4)
			t += 4
		else:
			await ticks(10)
			t += 10

func _answer_leadvoice(b: Enemy) -> void:
	var l := b as Leadvoice
	if l == null or l.dead or player.dead:
		return
	if l != _lv:
		_lv = l
		_lv_home = l.global_position
		if not player.hit_landed.is_connected(_on_blow):
			player.hit_landed.connect(_on_blow)
		l.verse_sung.connect(func(n): _seen["verses"].append(n))
		l.verse_broken.connect(func(): _seen["broken"] += 1)
		_seen["verses"] = []
	_sample(l)
	_log_n += 1
	if _log_n % 5 == 0:
		print("  (duel: phase %d, she %.0f%%, state %s, %.1f m off; the Bearer %.0f/%.0f, %d gourds, breath %.0f, at %s)" % [l.phase,
			100.0 * l.hp / l.max_hp, Enemy.ES.keys()[l.state], _flat(l.global_position - player.global_position).length(),
			player.hp, player.max_hp, player.gourds, player.breath, str(player.global_position.snapped(Vector3.ONE * 0.1))])
	if l.standing and float(_seen["stood_at"]) < 0.0:
		_seen["stood_at"] = l.hp / l.max_hp
	await _see_to_the_dead(l)
	if l.standing and l.phase == 3:
		await _verses(l)

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

## Debugging only (--fullgame-leg=level|veil|duel|release|choice): by fiat,
## the world as the legs before leave it. Never a pass.
func _jump_to(leg: String) -> void:
	check(false, "DEBUG RUN from leg '%s': not the walk" % leg)
	for f in ["ks_horn_wellhead", "met_maren", "met_wren"]:
		World.set_flag(f)
	World.set_flag("chapter_maren", 2)
	for h in ["hs_upwater", "hs_ice_falls", "hs_wellhead_steps"]:
		World.set_area_flag(aid, "lit_" + h)
	World.set_area_state(aid, RH.WState.RIME)
	World.last_hearth = {"area": aid, "hearth": "hs_wellhead_steps"}
	var at: Vector3 = AreaBuilder._v3(DB.area_def(aid)["hearths"][2]["at"]) + Vector3(-1.0, 0.4, 1.0)
	Game.travel_to(aid, at)
	await _until(func(): return Game.current_area_id == aid and player.input_enabled, 12.0)
	area = Game.current_area
	await ticks(60)
	_marks()
	if leg in ["duel", "release", "choice"]:
		veil = _veil()
		await _part_veil(veil, false)
	if leg in ["release", "choice"]:
		boss = _foe("leadvoice")
		var l := boss as Leadvoice
		player.invulnerable = true
		l.take_hit(DamagePacket.new(10, 0, player))
		await _secs(2.9)
		var guard := 0
		while not l.standing and guard < 8:
			guard += 1
			l.take_hit(DamagePacket.new(900, 0, player))
			await _secs(4.4 if l.phase == 3 else 2.8)
		for i in 3:
			for m in l.dead_up():
				(m as Enemy)._die()
			l._set_state(Enemy.ES.COMBAT)
			l.sing_zone.enabled = true
			l.begin_verse(player)
			await _secs(float(l.cfg["verse_time"]) + 0.2)
			if not l.released:
				await _secs(float(l.cfg["verse_bow"]) + 0.3)
		player.invulnerable = false

func _marks() -> void:
	foot = Game.find_hearth("hs_upwater").respawn_point()
	top = Game.find_hearth("hs_wellhead_steps").respawn_point()

func _leg_seam() -> bool:
	print("== the seam at the High Fold's corner")
	check(Game.current_area_id == "shepherds_reach", "the walk starts on Shepherd's Reach (%s)" % Game.current_area_id)
	check(World.is_cleared("shepherds_reach") and World.flag("ks_fellcaller_released"), "the Fellcaller is released")
	check(not World.is_cleared(aid) and not World.flag("ks_leadvoice_released") and not World.flag("ks_horn_wellhead"),
		"the Coldwell has not been walked")
	check(World.ended() == "", "nothing has ended")
	var released := ["netmender", "turfwright", "ice_cutter", "host", "hedgelayer", "fellcaller"].filter(
		func(b): return World.flag("ks_%s_released" % b))
	check(released.size() == 6, "six Holdfasts released on the way here (%d)" % released.size())
	var before := _horn()
	check(before.begins_with("A cow's horn") and before.ends_with("since you were small."), "the horn, as it has read since Saltfell")
	_has_five = World.flag("ks_knucklebones_found") and int(player.inventory.get("item_knucklebone", 0)) > 0
	var seam := _portal_to("coldwell")
	check(seam != null and seam.auto, "the Upwater seam stands, with no door in it")
	if seam == null:
		return false
	_n0 = _titles.size()
	var into: Vector3 = AreaBuilder._v3(DB.area_def(aid)["start"]["pos"]) - seam.global_position
	into.y = 0.0
	var crossed := await _cross("coldwell", seam.global_position + into.normalized() * 1.0, 9000, false)
	check(crossed, "the Bearer walks out of the fold's corner and onto the Upwater (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return false
	_marks()
	var def: Dictionary = area.get_meta("def")
	check(player.global_position.distance_to(AreaBuilder._v3(def["start"]["pos"])) < 6.0, "set down on the path past the seam")
	check(World.get_area_state(aid) == RH.WState.THAW, "first arrival is THAW: the last Melt")
	check(_awake_foes().is_empty(), "no enemies in THAW")
	await _until(func(): return hud.last_title == "THE UPWATER", 8.0)
	var seen: Array = _titles.slice(_n0)
	var ti := seen.map(func(t): return String(t).to_upper()).find("THE COLDWELL")
	check(ti >= 0 and seen.slice(ti + 1) == ["THE UPWATER"], "the region's card, then the place (%s)" % str(seen))
	check(Game.current_area_id == "coldwell", "the seam does not carry him back")
	await _shot("arrival_thaw")
	var plaques := area.find_children("*", "LorePlaque", true, false)
	check(plaques.size() == 1 and String((plaques[0] as LorePlaque).text) == "THE COLDWELL\n\nThe river's source, under the glacier's lip.",
		"the plaque at the foot names it")
	check(Game.find_hearth("hs_upwater") != null and Game.find_hearth("hs_ice_falls") != null
		and Game.find_hearth("hs_wellhead_steps") != null and get_tree().get_nodes_in_group("hearths").filter(
			func(h): return area.is_ancestor_of(h)).size() == 3, "three hearths stand, none at the spring")
	var seams := area.find_children("*", "AreaPortal", true, false)
	check(seams.size() == 1 and (seams[0] as AreaPortal).to_area == "shepherds_reach", "one way in and no way on: this is the end of the water")
	return true

func _leg_climb_thaw() -> bool:
	print("== the Upwater, climbed in the last Melt")
	var souls := _souls()
	check(souls.has("maren") and souls.has("wren") and souls.size() == 2, "two people in the whole region (%s)" % str(souls.keys()))
	var way := _reach_len(player.global_position, top)
	check(way > 200.0 and way < INF, "one path, climbing: %.0f m to the Wellhead Steps" % way)
	var y0 := player.global_position.y
	var t0 := Engine.get_physics_frames()
	walked = await _walk_path(top, 9000, false)
	check(walked, "the Bearer walks the whole Upwater (%d ticks, %s)" % [Engine.get_physics_frames() - t0, str(player.global_position.snapped(Vector3.ONE))])
	check(player.global_position.y - y0 > 60.0, "and climbs %.0f m doing it" % (player.global_position.y - y0))
	check(not player.dead and _stilled == 0, "nothing on the way hurts him")
	check(not World.flag("ks_horn_wellhead"), "below the level the horn is only the horn")
	if not walked:
		return false
	var n_t := _titles.size()
	var maren: NPC = souls.get("maren")
	_halt = func(): return World.flag("ks_horn_wellhead")
	await _walk_path(maren.global_position, 3600, false)
	_halt = Callable()
	player.sim_move = Vector3.ZERO
	check(World.flag("ks_horn_wellhead"), "arriving at the Wellhead (ks_horn_wellhead)")
	await _until(func(): return hud.last_title == "THE WELLHEAD", 6.0)
	check(_titles.slice(n_t).has("THE WELLHEAD"), "THE WELLHEAD is named (%s)" % str(_titles.slice(n_t)))
	check(_horn() == HORN_HERE, "the horn reads differently from here on")
	check(_journal("fostering_horn") == ["The coal is still alight."], "The fostering horn: the coal is still alight")
	await _shot("wellhead_thaw")
	return true

func _leg_people() -> bool:
	print("== the Wellhead: Maren and Wren at the water")
	var souls := _souls()
	var maren: NPC = souls.get("maren")
	var wren: NPC = souls.get("wren")
	check(maren != null and wren != null and _flat(maren.global_position - WELL).length() > RING_R
		and _flat(wren.global_position - WELL).length() > RING_R, "outside the ring, at the edge of the water")
	check(maren != null and maren._vis.model_id == "maren_thaw" and wren != null and wren._vis.model_id == "wren", "on their own models")
	var ec := _choice()
	check(ec != null and not ec.is_open(), "the spring offers nothing")
	ui = await _talk("maren")
	check(ui != null, "the Bearer walks to Maren and speaks with her")
	if ui != null:
		await _shot("maren_talk")
		check(ui.name_label.text == "Maren", "her name plate (%s)" % ui.name_label.text)
		var l1: Array = await _lines_of(ui)
		check(l1 == MAREN_FIRST, "Maren's first audience, in order: she takes him for a stranger (%d)" % l1.size())
		var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(ids == ["leave"], "she has nothing to trade (%s)" % str(ids))
		await _leave(ui)
	check(_ui("DialogueUI") == null and player.input_enabled, "Leave closes the talk and hands control back")
	check(World.flag("met_maren"), "met_maren")
	ui = await _talk("wren")
	check(ui != null, "and to Wren")
	if ui != null:
		check(ui.name_label.text == "Wren", "her name plate (%s)" % ui.name_label.text)
		var w1: Array = await _lines_of(ui)
		check(w1 == WREN_FIRST, "Wren watches the flowers go (%s)" % str(w1))
		await _leave(ui)
	ui = await _talk("maren")
	check(ui != null, "Maren, a second time")
	if ui != null:
		var l2: Array = await _lines_of(ui)
		check(l2 == MAREN_SECOND, "the second audience: the older one, down the water (%d)" % l2.size())
		await _leave(ui)
	ui = await _talk("maren")
	if ui != null:
		var l3: Array = await _lines_of(ui)
		check(l3 == MAREN_REPEAT, "asked again, the water is loud (%s)" % str(l3))
		await _leave(ui)
	ui = await _talk("wren")
	check(ui != null, "Wren again")
	if ui != null:
		var w2: Array = await _lines_of(ui)
		if _has_five:
			check(w2 == WREN_SHOWN and World.flag("ks_knucklebones_shown"), "shown all five knucklebones, she knows them (%s)" % str(w2))
			check(int(player.inventory.get("item_knucklebone", 0)) == 1 and int(player.inventory.get("ks_knucklebones", 0)) == 1, "she does not take them")
		else:
			check(w2 == ["And that one."] and not World.flag("ks_knucklebones_shown"),
				"carrying one knucklebone and not the four from Saltfell, she has nothing to say about it (%s)" % str(w2))
			print("  (FINDING: this save never picked up the four knucklebones at Saltfell, so Knucklebones cannot close here)")
		await _leave(ui)
	check(_journal("knucklebones") == _expected("knucklebones"), "Knucklebones: %d of 3 lines, in order" % _journal("knucklebones").size())
	check(_journal("fostering_horn") == _all_lines("fostering_horn"), "The fostering horn: closed")
	var said := JSON.stringify(MAREN_FIRST + MAREN_SECOND + MAREN_REPEAT + WREN_FIRST + WREN_SHOWN)
	check(not said.contains("mother") and not said.contains("sister") and not said.contains("Bearer"), "nobody says what it adds up to")
	return true

func _leg_first_rest() -> bool:
	print("== down again; the first rest, at the Upwater, forces RIME")
	var t0 := Engine.get_physics_frames()
	rest = await _rest_ui_at("hs_upwater")
	check(rest != null, "the Bearer walks back down to the Upwater's hearth (%d ticks, %s)" % [Engine.get_physics_frames() - t0,
		str(player.global_position.snapped(Vector3.ONE))])
	if rest == null:
		return false
	await _shot("rest_menu_thaw")
	check(rest.title_label.text == "the Upwater", "the hearth is named (%s)" % rest.title_label.text)
	check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0 and _option_index(rest, "cold") < 0,
		"uncleared THAW: rest only, no turning back")
	rest.choose(0)
	await _wait_turn()
	_warmth_was = Game.warmth
	Game.warmth_changed.connect(_on_warmth)
	check(World.get_area_state(aid) == RH.WState.RIME, "the Coldwell is RIME now")
	check(World.last_hearth.get("hearth", "") == "hs_upwater" and _hearth_lit("hs_upwater"), "the Upwater is lit and kept")
	check(_souls().is_empty(), "Maren and Wren are gone in RIME")
	var kinds := {}
	for e in _awake_foes():
		kinds[e.id] = int(kinds.get(e.id, 0)) + 1
	check(kinds == {"upwalker": 3, "unsung": 2, "leadvoice": 1}, "the frost-taken stand: three Upwalkers, two of the Unsung, the Leadvoice (%s)" % str(kinds))
	var dead := _river_dead()
	check(dead.size() >= 10, "the unsung dead stand in the frozen river, a great many (%d)" % dead.size())
	check(dead.all(func(n): return not (n as Node).is_in_group(RH.GROUP_ENEMIES)), "they are not foes")
	check(_reach_len(player.global_position, top) < INF, "the frozen Upwater still climbs to the Wellhead Steps")
	await _shot("upwater_rime")
	return true

func _leg_stilled() -> bool:
	print("== STILLED on the Upwater, and the Breathmark")
	await _die_and_recover("hs_upwater")
	await _wake_up()
	return true

func _leg_upwater() -> bool:
	print("== RIME: the first Upwalker, standing in the way")
	var down := await _clear_upwalker("upwalker_low")
	check(down, "the Upwalker on the lower path is put down (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(_gained >= 52, "and gives up its warmth (%d gained since the first rest)" % _gained)
	await _wake_up()
	return true

func _leg_ice_falls() -> bool:
	print("== the Ice-Falls")
	check(await _rest_and_grow("hs_ice_falls"), "the Ice-Falls offers its hearth (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(_hearth_lit("hs_ice_falls") and World.last_hearth.get("hearth", "") == "hs_ice_falls"
		and World.get_area_state(aid) == RH.WState.RIME, "the Ice-Falls is lit and kept; still RIME")
	check(Game.find_hearth("hs_ice_falls").display_name == "the Ice-Falls", "the hearth is named")
	var down := await _clear_upwalker("upwalker_falls")
	check(down, "the Upwalker above the falls is put down (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _wake_up()
	var iron0 := int(player.inventory.get("bog_iron", 0))
	took = await _take("upwater_cache", "Pry up what the ice holds")
	check(took and int(player.inventory.get("bog_iron", 0)) == iron0 + 2, "what the ice holds: bog-iron (%d -> %d)" % [iron0, int(player.inventory.get("bog_iron", 0))])
	await _wake_up()
	return true

func _leg_steps() -> bool:
	print("== the last Upwalker, and the Wellhead Steps")
	var down := await _clear_upwalker("upwalker_high")
	check(down, "the Upwalker under the level is put down (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _wake_up()
	rest = await _rest_ui_at("hs_wellhead_steps")
	check(rest != null and _option_index(rest, "toggle") < 0, "the Wellhead Steps: uncleared RIME rests only (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if rest != null:
		check(rest.title_label.text == "the Wellhead Steps", "the hearth is named (%s)" % rest.title_label.text)
		rest.choose(_option_index(rest, "leave"))
		await ticks(4)
	check(await _rest_and_grow("hs_wellhead_steps"), "the Bearer rests there")
	check(_hearth_lit("hs_wellhead_steps") and World.last_hearth.get("hearth", "") == "hs_wellhead_steps", "the Wellhead Steps is lit and kept")
	check(["hs_upwater", "hs_ice_falls", "hs_wellhead_steps"].all(func(h): return _hearth_lit(h)), "all three hearths are lit")
	return true

func _leg_level() -> bool:
	print("== the level: the Unsung, and a Song")
	var two: Array = _awake_foes().filter(func(e): return e.id == "unsung")
	check(two.size() == 2, "two of the Unsung on the level (%d)" % two.size())
	check(player.attuned_song != "" and int(player.inventory.get(player.attuned_song, 0)) > 0, "the Bearer has learned a Song on the way up (%s)" % player.attuned_song)
	# the first Song learned attunes itself, and on this road that is Aud's,
	# a ward. "Any Song breaks one outright": it is sung as it is, unchanged
	# (only Songs that strike used to reach them)
	check(float(DB.song(player.attuned_song).get("damage", 0.0)) <= 0.0 or player.attuned_song != "",
		"the Song attuned is whatever the road left there (%s)" % player.attuned_song)
	var first: Enemy = two[0]
	_halt = func(): return is_instance_valid(first) and _flat(first.global_position - player.global_position).length() < 3.2
	await _walk_path(first.global_position, 3600, false)
	_halt = Callable()
	player.sim_move = Vector3.ZERO
	await _until(func(): return player.state == Player.S.MOVE, 3.0)
	var hp0 := first.hp if is_instance_valid(first) else 0.0
	var n0 := _awake_foes().filter(func(e): return e.id == "unsung").size()
	player.cast_song(player.attuned_song)
	await _secs(1.2)
	var n1 := _awake_foes().filter(func(e): return e.id == "unsung").size()
	check(n1 < n0 and (not is_instance_valid(first) or first.dead), "a Song breaks one outright (%d -> %d standing; it had %.0f of 45)" % [n0, n1, hp0])
	await _fight(16.0, 60.0)
	await _wake_up()
	check(_awake_foes().filter(func(e): return e.id == "unsung").is_empty() or _stilled > 1, "the level is cleared")
	await _shot("level_rime")
	return true

func _leg_veil() -> bool:
	print("== the frost veil in the ring's gap")
	veil = _veil()
	check(veil != null and veil.gate_id == "wellhead_veil" and _flat(veil.global_position - (WELL + Vector3(-RING_R, 0, 0))).length() < 1.0,
		"one veil, in the gap on the river side")
	if veil == null:
		return false
	boss = veil.boss_spawner.current if veil.boss_spawner != null else null
	check(boss is Leadvoice and boss.cfg.get("is_boss", false), "the Leadvoice waits behind it")
	if boss != null:
		var l := boss as Leadvoice
		check(l.state == Enemy.ES.IDLE and not l.stood and l.is_seated_pose(), "sat on the far side of the spring, bent over what she holds (%s)" % l.vis.current_clip())
		check(_flat(l.global_position - WELL).length() < 5.0 and l.global_position.x > WELL.x, "beyond the well-housing from the gap")
	check(not hud.boss_root.visible, "no bar yet")
	var parted := false
	for attempt in 3:
		parted = await _part_veil(veil, true)
		if parted:
			break
		await _wake_up()
	check(parted, "the Bearer parts the veil (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(Game.arena_locked and _flat(player.global_position - WELL).length() < RING_R, "it seals at his back, inside the ring")
	await _shot("veil_parted")
	return parted

func _leg_duel() -> bool:
	print("== the Leadvoice")
	boss = _foe("leadvoice")
	check(boss != null and boss is Leadvoice, "the Leadvoice herself")
	if boss == null:
		return false
	check(not (boss as Leadvoice).stood, "she does not look up until he is near")
	var w_before := Game.warmth
	var res: Dictionary = await _duel("leadvoice", veil, DUEL_MULT, 900.0, _answer_leadvoice)
	boss = res["boss"]
	var phases: Dictionary = res["phases"]
	print("  (seen in the fight: %s)" % str(_seen))
	check(boss != null and boss.dead and (boss as Leadvoice).released, "the Leadvoice is released (falls along the way: %d)" % int(res["deaths"]))
	check(phases.has(1) and phases.has(2) and phases.has(3), "her AI ran all three phases (%s)" % str(phases.keys()))
	check(_seen["bar"], "the bar: THE LEADVOICE")
	check(_seen["music"] == [""], "when her bar comes up the music stops, and nothing replaces it (%s)" % str(_seen["music"]))
	check(float(_seen["moved"]) < 0.3, "she does not move from where she sits (%.2f m)" % float(_seen["moved"]))
	check(not _seen["hand"], "she never opens a hand volume")
	check(int(_seen["blows"]) >= 6, "phases one and two are the Bearer's own blade (%d blows landed)" % int(_seen["blows"]))
	check(int(_seen["unsung"]) >= 2, "the Unsung stand up between them (%d at once)" % int(_seen["unsung"]))
	check(absf(float(_seen["stood_at"]) - 0.25) < 0.02, "she stands with a quarter of her left (%.2f)" % float(_seen["stood_at"]))
	check(_seen["sing_prompt"], "on her feet, the prompt is one word: Sing")
	check(_seen["verses"] == [1, 2, 3], "three verses, sung through the prompt (%s; %d broken)" % [str(_seen["verses"]), int(_seen["broken"])])
	check(Game.warmth - w_before < 200 or int(res["deaths"]) > 0, "killing her gives nothing (warmth %d -> %d: her dead only)" % [w_before, Game.warmth])
	_lv = null
	return boss != null and boss.dead

func _leg_release() -> bool:
	print("== the release")
	await _secs(1.5)
	var l := boss as Leadvoice
	check(AudioDirector._active_music == "", "nothing plays: no Outsong is sung for her (%s)" % AudioDirector._active_music)
	check(hud.last_title == "MAREN — RELEASED" and _cards.has("MAREN — RELEASED"), "the card carries her name, not the office (%s)" % hud.last_title)
	await _shot("release_card")
	check(World.is_cleared(aid) and World.flag("ks_leadvoice_released") and World.area_flag(aid, "slain_leadvoice"),
		"the Coldwell is cleared (ks_leadvoice_released)")
	check(not Game.arena_locked, "the veil falls")
	check(veil._seal.collision_layer == 0 and not veil._zone.enabled, "and cannot be parted again")
	check(not hud.boss_root.visible, "the bar is gone")
	await _secs(3.0)
	check(is_instance_valid(l) and l.is_inside_tree() and l.is_seated_pose() and _flat(l.global_position - _lv_home).length() < 0.3,
		"she sits down again, as she was, and stays (%s)" % (l.vis.current_clip() if is_instance_valid(l) else "gone"))
	check(get_tree().get_nodes_in_group("ice_ridges").filter(func(r): return is_instance_valid(r) and (r as Node).is_inside_tree() and not (r as IceRidge).is_queued_for_deletion()).is_empty(),
		"the ridges of rime fall")
	check(_awake_foes().filter(func(e): return _flat(e.global_position - WELL).length() < 20.0).is_empty(), "the Unsung go")
	check(int(l.cfg.get("warmth", 1)) == 0, "no warmth")
	check(get_tree().get_nodes_in_group("hearths").filter(func(h): return area.is_ancestor_of(h)).size() == 3, "no hearth wakes here")
	var band := _pickup("wren_band")
	var mask := _pickup("maren_mask")
	check(band != null and mask != null and band.global_position.distance_to(mask.global_position) < 2.5
		and band.global_position.distance_to(l.global_position) < 4.0, "the band and the mask, side by side on the ground in front of her")
	took = await _take("wren_band", "Take the band", false)
	check(took and int(player.inventory.get("item_wren_band", 0)) == 1 and World.flag("ks_wren_band_found"), "Take the band")
	took = await _take("maren_mask", "Take the mask", false)
	check(took and int(player.inventory.get("item_maren_mask", 0)) == 1, "Take the mask")
	check(String(DB.item("item_maren_mask")["desc"]).ends_with("This one is fifteen winters old.")
		and String(DB.item("item_wren_band")["desc"]).contains("pulled tight with the teeth"), "they read as COLDWELL.md 8 has them")
	await _shot("released")
	return true

func _leg_choice() -> bool:
	print("== the choice is offered, and walked to, and not taken")
	var ec := _choice()
	check(ec != null and ec.is_open(), "the spring offers its two things")
	if ec == null:
		return false
	check(_flat(ec.global_position - WELL).length() < RING_R and ec.global_position.x < WELL.x, "at the near side of the spring")
	check(absf(ec.spread - 2.2) < 0.01 or ec.spread < 3.0, "a pace or two apart (%.1f m)" % ec.spread)
	var lay: Vector3 = ec.to_global(Vector3(-ec.spread * 0.5, 0, 0))
	await _walk_path(lay, 2400, false)
	walked = await _walk_to(lay, 300, 0.5, false)
	await _settle()
	var it := player.nearest_interactable()
	check(walked and it != null and it.prompt == "Lay the coal in the spring", "one place to stand: Lay the coal in the spring (%s, at %s)" % [
		it.prompt if it != null else "nothing", str(player.global_position.snapped(Vector3.ONE * 0.1))])
	await _shot("choice")
	var keep: Vector3 = ec.kept_spot()
	walked = await _walk_to(keep, 300, 0.5, false)
	await _settle()
	it = player.nearest_interactable()
	check(walked and it != null and it.prompt == "Keep the horn shut, and sit", "and the other: Keep the horn shut, and sit (%s)" % (it.prompt if it != null else "nothing"))
	check(World.ended() == "" and not World.flag("ending_outsong") and not World.flag("ending_hearth_kept") and EndingDirector.active == null,
		"nothing is chosen by standing there")
	check(player.input_enabled and hud.visible, "the Bearer may still walk away")
	return true

func _leg_melt_again() -> bool:
	print("== released: the Wellhead Steps turns the memory")
	check(await _rest("hs_wellhead_steps", "toggle"), "the hearth offers to turn it now (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(World.get_area_state(aid) == RH.WState.THAW, "the last Melt again")
	check(_awake_foes().is_empty(), "nobody frost-taken in THAW")
	var souls := _souls()
	check(souls.has("maren") and souls.has("wren"), "Maren and Wren at the water, as they were (%s)" % str(souls.keys()))
	ui = await _talk("maren")
	check(ui != null, "Maren, after")
	if ui != null:
		var l: Array = await _lines_of(ui)
		check(l == MAREN_REPEAT, "she still takes him for a stranger (%s)" % str(l))
		await _leave(ui)
	check(_reach_len(top, foot) < INF, "the Upwater walks down in THAW as it does in RIME")
	return true

func _leg_end() -> bool:
	print("== and stilled again, to rest at the Wellhead Steps before the choice")
	check(await _rest("hs_wellhead_steps", "toggle"), "the Wellhead Steps turns it back")
	check(World.get_area_state(aid) == RH.WState.RIME, "RIME: as she left it")
	check(_foe("leadvoice") == null and not Game.arena_locked, "she does not get up again")
	var v2 := _veil()
	check(v2 == null or v2._seal.collision_layer == 0, "and the veil stays down")
	var sat: Array = get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e is Leadvoice and is_instance_valid(e) and area.is_ancestor_of(e))
	check(sat.size() == 1 and (sat[0] as Leadvoice).released and (sat[0] as Leadvoice).is_seated_pose(), "she is still sat at the spring (%d)" % sat.size())
	var ec := _choice()
	check(ec != null and ec.is_open(), "the choice is still offered")
	check(_reach_len(player.global_position, ec.kept_spot(), 1.0) < 40.0, "a few steps from the hearth, on foot (%.0f m)" % _reach_len(player.global_position, ec.kept_spot(), 1.0))
	check(World.last_hearth.get("area", "") == aid and World.last_hearth.get("hearth", "") == "hs_wellhead_steps", "the Wellhead Steps is the hearth kept")
	check(World.ended() == "", "and nothing has ended")
	await _shot("end_rime")
	return true

func _after_load() -> void:
	print("== the Coldwell, resumed")
	check(Game.current_area_id == aid and World.last_hearth.get("hearth", "") == "hs_wellhead_steps", "at the Wellhead Steps")
	for h in ["hs_upwater", "hs_ice_falls", "hs_wellhead_steps"]:
		check(_hearth_lit(h), "%s stays lit" % h)
	check(World.is_cleared(aid) and World.flag("ks_leadvoice_released") and World.area_flag(aid, "slain_leadvoice"), "the Leadvoice stays released")
	check(World.get_area_state(aid) == RH.WState.RIME and _awake_foes().filter(func(e): return e.cfg.get("is_boss", false)).is_empty(), "RIME, and no Holdfast to fight")
	var sat: Array = get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e is Leadvoice and is_instance_valid(e) and area.is_ancestor_of(e))
	check(sat.size() == 1 and (sat[0] as Leadvoice).released and (sat[0] as Leadvoice).dead and (sat[0] as Leadvoice).is_seated_pose()
		and _flat((sat[0] as Node3D).global_position - WELL).length() < 5.0, "she is still sat where she was left (%d)" % sat.size())
	check(not hud.boss_root.visible, "with no bar")
	var v := _veil()
	check(v == null or (v._seal.collision_layer == 0 and not v._zone.enabled), "the veil is down")
	var inv := player.inventory
	check(int(inv.get("item_wren_band", 0)) == 1 and int(inv.get("item_maren_mask", 0)) == 1, "the Pack: the band and the mask")
	check(_pickup("wren_band") == null and _pickup("maren_mask") == null, "and neither lies on the ground a second time")
	check(_horn() == HORN_HERE, "the horn still reads as it did at the wellhead")
	check(_journal("fostering_horn") == _all_lines("fostering_horn") and _journal("knucklebones") == _expected("knucklebones"), "both threads as they were left")
	var ec := _choice()
	check(ec != null and ec.is_open() and World.ended() == "", "the spring still offers its two things")
	check(_reach_len(player.global_position, ec.kept_spot(), 1.0) < 40.0, "and they can be walked to")
	check(_portal_to("shepherds_reach") != null, "the way back down stands")
