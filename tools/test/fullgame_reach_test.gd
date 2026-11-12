extends FullgameBase
## Shepherd's Reach, end to end (REACH.md), from the save the Thornwold walk
## ends on: up the fell path through the seam, the whistle at the sheiling,
## Sigga on the slope and Old Calder at the wall (both his audiences), the
## first rest at the Fell Path and the RIME, a fall and the Breathmark, his
## boots by the sheiling door, over the frozen beck where THAW has only the
## bridge, up between the seventy to the veil, the Fellcaller through all
## three phases, her release (the card, the flock lying down, the fold-tally
## by his hand, kept through a save and a resume before it is taken, the
## High Fold), the THAW scene in the fold, the boots shown, and the last rest
## at the High Fold, the hearth nearest the Upwater.

const FOLD := Vector3(660.0, 0.0, -372.0)
const FOLD_R := 13.0
const GAP_A := 135.0
const BRIDGE_X := 618.0
## Where the beck is crossed on the ice: well up from the bridge.
const ICE_X := 584.0

const SIGGA_FIRST := [
	"Stand there and they'll go round you. Stand anywhere else and they'll go through you.",
	"Sigga. That's my father up at the wall, putting back what he put back last year.",
	"He says forty-four. There are forty-three. I can count. He taught me.",
	"He's had a cough since shearing. He says it's the wool. Before that it was the hay.",
]
const SIGGA_REPEAT := [
	"They come to a call. Dogs are for people who can't call.",
	"If he asks, I've had my supper.",
]
const CALDER_FIRST := [
	"Hold still, Brokenhorn. Not you. Her. The one with the torn ear.",
	"Wall comes down every winter and I put it back every summer. The wall and I have an understanding.",
	"That's my lass calling. Sigga. She'll have them in by dark, and then she'll count them, and she'll get forty-three.",
	"It's forty-four. She's left the same one out since she was six. I've never said which.",
]
const CALDER_SECOND := [
	"Old Leadvoice's lass came up this way at the Melt. She's Leadvoice herself now, they tell me. I still see her with her knees skinned.",
	"Had a little one up on her shoulders. Going up to see the water go.",
	"Singing to it. Not one of the ones for the dead, I know those, I've stood outside enough doors. This went",
	"Mm. Mm, mm.",
	"No. It's gone. She'd know how it goes on.",
]
const CALDER_REPEAT := [
	"Forty-one, forty-two. Where's Smudge. There's Smudge.",
	"Mind the beck. It's colder than it looks and it looks cold.",
]
const CALDER_BOOTS := [
	"Those are mine.",
	"I've got mine on. Look.",
	"Well. Put them by the door. Toes to the wall, or she'll only move them.",
]
const CALDER_AFTER := [
	"Wall's done. First time it's been done by dark since I was a young man.",
	"I might sit a while.",
]
const THE_COUNT := [
	["sigga", "Forty-three!"],
	["old_calder", "Forty-four!"],
	["sigga", "Forty-three, Da. I've been round twice."],
	["old_calder", "Then you've left her out twice."],
	["sigga", "Left who out?"],
	["old_calder", "Go round again."],
]
const IN_THE_FOLD := [
	["sigga", "Forty-four."],
	["old_calder", "There. Who was it?"],
	["sigga", "Me. You've got me down as a ewe."],
	["old_calder", "You came when you were called. That's all the stick knows."],
	["sigga", "Since when?"],
	["old_calder", "Since you were six."],
	["sigga", "Put your boots on, Da."],
	["old_calder", "In a bit."],
]

var _titles: Array = []
var _cards: Array = []
var _n0 := 0
var _heard: Array = []
var _sounds: Array = []
# marks on the ground the legs share
var gap_out: Vector3      # on the trod, just below the fold's gap
var gap_in: Vector3       # just inside it
var ice_s: Vector3        # either side of the beck, away from the bridge
var ice_n: Vector3
var thaw_over := INF
var rime_over := INF
var thaw_bed := 0.0
var veil: FrostVeil = null
# (scratch the legs reuse)
var took := false
var walked := false
var crossed := false
var rest: RestUI = null
var ui: DialogueUI = null
var souls := {}
var boss: Enemy = null

## The walk's legs, in order. --fullgame-leg=<name> (debugging only) drops
## the Bearer at the start of a later leg by fiat; such a run always fails
## its first check, so it can never pass for the walk.
const LEGS := ["seam", "sheilings_thaw", "trod_thaw", "first_rest", "stilled", "sheilings_rime", "ice", "slope",
	"veil", "duel", "release", "resume_tally", "gap", "fold_thaw", "thaw_routes", "end"]
var _skip_to := ""

func _on_heard(who, line) -> void:
	_heard.append([String(who), String(line)])

func _init() -> void:
	region = "reach"
	aid = "shepherds_reach"
	start_fixture = "fullgame_after_thornwold"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fullgame-leg="):
			_skip_to = a.get_slice("=", 1)

# ------------------------------------------------------------------ helpers
## (long ways round: lift the polygon search cap a long route needs)
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

func _beck_z(x: float) -> float:
	return -334.0 + 7.0 * sin(x * 0.03 + 0.6)

## The top of whatever is solid at (x, z), from high above.
func _ray_y(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 160.0, z), Vector3(x, -30.0, z), RH.M_WORLD_ALL)
	var hit := area.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else -999.0

## Length of the navmesh way from a to b, or INF when it does not get there.
func _reach_len(a: Vector3, b: Vector3, tol := 1.6) -> float:
	var p := _path(a, b)
	if p.size() < 2 or _flat(p[p.size() - 1] - b).length() > tol:
		return INF
	var t := 0.0
	for i in range(1, p.size()):
		t += p[i].distance_to(p[i - 1])
	return t

func _path_near(a: Vector3, b: Vector3, pt: Vector3, tol: float) -> bool:
	var p := _path(a, b)
	for i in range(1, p.size()):
		var seg := Geometry2D.get_closest_point_to_segment(Vector2(pt.x, pt.z), Vector2(p[i - 1].x, p[i - 1].z), Vector2(p[i].x, p[i].z))
		if seg.distance_to(Vector2(pt.x, pt.z)) < tol:
			return true
	return false

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

## Walk up within earshot of `n` (not into it).
func _come_near(n: NPC, r := 4.0) -> void:
	_halt = func(): return _flat(player.global_position - n.global_position).length() < r
	await _walk_path(n.global_position, 3600, false)
	_halt = Callable()
	player.sim_move = Vector3.ZERO

func _flock_standing() -> Array:
	return get_tree().get_nodes_in_group("flock_rime").filter(func(n):
		return is_instance_valid(n) and area.is_ancestor_of(n) and (n as Node3D).is_visible_in_tree())

## The sheep of the RIME layer that lie (the area's flagged props, or the
## standing ones the release has laid down).
func _flock_lying() -> Array:
	return area.rime_layer.find_children("*", "Node3D", true, false).filter(func(n):
		# (the three ewes at the Upwater hurdles are the gate's, ADR 0015: the seventy are the slope's)
		return String(n.get_meta("kit_id", "")) == "sheep" and not n.has_meta("gate_piece") \
				and absf((n as Node3D).scale.y - 0.58) < 0.03 and (n as Node3D).is_visible_in_tree())

func _wake_up() -> void:
	if player.dead:
		await _until(func(): return not player.dead, 10.0)
		await ticks(30)
		area = Game.current_area

## Fight whatever stands near a spot, and stay till it is quiet.
func _clear_at(at: Vector3, r := 14.0) -> void:
	for attempt in 3:
		await _walk_path(at, 3600, true)
		await _fight(r, 90.0)
		if not player.dead:
			return
		await _wake_up()

# --------------------------------------------------------- the Fellcaller's fold
var _duel_boss: Fellcaller = null
var _mash_n := 0
var _log_n := 0
## What the fight showed (her AI picks its own moves: only the bar, the
## phases and the Bearer's own blows are asserted; the rest is printed).
var _seen := {"bar": false, "rams": 0, "herds": 0, "cross": 0, "count": false, "guard_max": 0.0, "blows": 0, "hooks": 0}

func _on_blow(_who, result) -> void:
	if String(result) == "hit":
		_seen["blows"] += 1

func _on_herd(runs: Array) -> void:
	_seen["herds"] += 1
	if runs.size() > 1:
		_seen["cross"] += 1

## Caught by a Drover's crook, a player struggles (REACH.md 5: "mash to break").
func _physics_process(_dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if not is_instance_valid(e) or not (e is Enemy):
			continue
		var hold: GrabHold = (e as Enemy).hook_hold
		if hold != null and is_instance_valid(hold) and not hold.is_over():
			_mash_n += 1
			if _mash_n % 5 == 0:
				hold.mash()
				_seen["hooks"] += 1
	if _duel_boss != null and is_instance_valid(_duel_boss) and _duel_boss.phase == 3 and not _duel_boss.dead \
			and (_duel_boss.state == Enemy.ES.COMBAT or _duel_boss.state == Enemy.ES.HOLD):
		_seen["guard_max"] = maxf(float(_seen["guard_max"]), _flat(_duel_boss.global_position - _duel_boss.father_point()).length())

## What the plain melee bot cannot answer by itself: the tups she brings over
## the wall (put them down when they are on him; the bot only looks at her).
func _answer_fold(b: Enemy) -> void:
	var f := b as Fellcaller
	if f == null or f.dead or player.dead:
		return
	if f != _duel_boss:
		_duel_boss = f
		if not player.hit_landed.is_connected(_on_blow):
			player.hit_landed.connect(_on_blow)
		f.herd_called.connect(_on_herd)
	_log_n += 1
	if _log_n % 5 == 0:
		print("  (duel: phase %d, she %.0f%%, state %s, %.1f m off; the Bearer %.0f/%.0f, %d gourds, at %s; %d tups)" % [f.phase,
			100.0 * f.hp / f.max_hp, Enemy.ES.keys()[f.state], _flat(f.global_position - player.global_position).length(),
			player.hp, player.max_hp, player.gourds, str(player.global_position.snapped(Vector3.ONE * 0.1)), f.rams_up().size()])
	if f.stood and hud.boss_root.visible and hud.boss_name.text == "THE FELLCALLER":
		_seen["bar"] = true
	_seen["rams"] = maxi(int(_seen["rams"]), f.rams_up().size())
	if f.state == Enemy.ES.HOLD:
		_seen["count"] = true
	var ram := _foe_near(4.5)
	if ram != null and f.state != Enemy.ES.HOLD:
		await _fight(5.0, 5.0)

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
	var out := Vector3(cos(deg_to_rad(GAP_A)), 0, sin(deg_to_rad(GAP_A)))
	gap_out = _g(FOLD.x + out.x * (FOLD_R + 3.0), FOLD.z + out.z * (FOLD_R + 3.0))
	gap_in = _g(FOLD.x + out.x * (FOLD_R - 3.0), FOLD.z + out.z * (FOLD_R - 3.0))
	var bz := _beck_z(ICE_X)
	ice_s = _g(ICE_X, bz + 6.5)
	ice_n = _g(ICE_X, bz - 6.5)

## Debugging only (--fullgame-leg=<leg from sheilings_rime on>): by fiat, the
## world as the legs before leave it. Never a pass.
func _jump_to(leg: String) -> void:
	check(false, "DEBUG RUN from leg '%s': not the walk" % leg)
	var li := LEGS.find(leg)
	if li < LEGS.find("sheilings_rime"):
		return
	for f in ["ks_calder_met", "ks_calder_hum", "met_old_calder", "met_sigga", "got_fleece"]:
		World.set_flag(f)
	World.set_flag("chapter_old_calder", 2)
	for it in ["armour_fleece", "item_shepherd_whistle"]:
		player.give_item(it, 1)
	World.set_area_flag(aid, "took_shepherds_whistle")
	for h in ["hs_fell_path", "hs_sheilings"]:
		World.set_area_flag(aid, "lit_" + h)
	if li > LEGS.find("sheilings_rime"):
		World.set_flag("ks_calder_boots_found")
		player.give_item("item_calder_boots", 1)
		World.set_area_flag(aid, "took_calder_boots")
	World.set_area_state(aid, RH.WState.RIME)
	World.last_hearth = {"area": aid, "hearth": "hs_sheilings"}
	var at: Vector3 = AreaBuilder._v3(DB.area_def(aid)["hearths"][1]["at"]) + Vector3(-1.0, 0.4, 1.0)
	Game.travel_to(aid, at)
	await _until(func(): return Game.current_area_id == aid and player.input_enabled, 12.0)
	area = Game.current_area
	await ticks(60)
	_marks()
	thaw_over = 80.0
	thaw_bed = _g(ICE_X, _beck_z(ICE_X)).y
	if li >= LEGS.find("veil"):
		player.global_position = gap_out + Vector3(-2.0, 0.3, 2.0)
		await ticks(10)
	if li >= LEGS.find("duel"):
		veil = _veil()
		await _part_veil(veil, false)
	if li >= LEGS.find("release"):
		boss = _foe("fellcaller")
		boss.take_hit(DamagePacket.new(10, 0, player))
		await _secs(2.6)
		while boss != null and not boss.dead:
			boss.take_hit(DamagePacket.new(300, 0, player))
			await _secs(3.2 if boss.state == Enemy.ES.TRANSITION else 0.05)

func _leg_seam() -> bool:
	print("== the fell path out of Thornwold")
	check(Game.current_area_id == "thornwold", "the walk starts in Thornwold (%s)" % Game.current_area_id)
	check(World.last_hearth.get("hearth", "") == "hs_outer_ring" and World.is_cleared("thornwold"), "at the Outer Ring, the wood cleared")
	check(not World.is_cleared(aid) and not World.flag("ks_fellcaller_released") and World.areas.get(aid, {}).get("flags", {}).is_empty(), "the Reach has not been walked")
	var seam := _portal_to("shepherds_reach")
	check(seam != null and seam.auto, "the fell-path seam stands, with no door in it")
	if seam == null:
		return false
	_n0 = _titles.size()
	crossed = await _cross("shepherds_reach", seam.global_position + Vector3(1.0, 0, 0), 9000, false)
	check(crossed, "the Bearer walks the fell path through the seam into the Reach (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return false
	_marks()
	var def: Dictionary = area.get_meta("def")
	check(player.global_position.distance_to(AreaBuilder._v3(def["start"]["pos"])) < 6.0, "set down on the path past the seam")
	check(World.get_area_state(aid) == RH.WState.THAW, "first arrival is THAW")
	check(_awake_foes().is_empty(), "no enemies in THAW")
	await _until(func(): return hud.last_title == "THE SHEILINGS", 8.0)
	var seen: Array = _titles.slice(_n0)
	var ti := seen.map(func(t): return String(t).to_upper()).find("SHEPHERD'S REACH")
	check(ti >= 0 and seen.slice(ti + 1) == ["THE SHEILINGS"], "the region's card, then the place (%s)" % str(seen))
	await _secs(1.0)
	check(Game.current_area_id == aid, "the seam does not carry him back")
	await _shot("arrival_thaw")
	check(Game.find_hearth("hs_fell_path") != null and Game.find_hearth("hs_sheilings") != null and Game.find_hearth("hs_high_fold") == null,
		"two hearths stand; the High Fold is not woken")
	var h := Game.find_hearth("hs_fell_path")
	walked = await _walk_path(h.respawn_point(), 5400, false)
	check(walked, "up the fell path to where it comes out onto the grass (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	var plaques := area.find_children("*", "LorePlaque", true, false)
	check(plaques.size() == 1 and String((plaques[0] as LorePlaque).text).begins_with("SHEPHERD'S REACH\n"), "the plaque at the path's head names the Reach")
	return true

func _leg_sheilings_thaw() -> bool:
	print("== THAW: the Sheilings, the whistle on its nail")
	souls = _souls()
	check(souls.has("old_calder") and souls.has("sigga") and not souls.has("sigga_fold") and not souls.has("calder_rime")
		and souls.size() == 2, "Old Calder and Sigga keep the thaw (%s)" % str(souls.keys()))
	check(_pickup("calder_boots") == null or not _pickup("calder_boots").is_visible_in_tree(), "no boots by the door in THAW")
	took = await _take("shepherds_whistle", "Take the shepherd's whistle", false)
	check(took and int(player.inventory.get("item_shepherd_whistle", 0)) == 1, "the shepherd's whistle is taken off its nail (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(String(DB.table("items")["item_shepherd_whistle"].get("desc", "")).begins_with("A whistle cut from a ewe's shin-bone"), "an item with a text")
	await _shot("sheilings_thaw")
	return true

func _leg_trod_thaw() -> bool:
	print("== THAW: over the plank bridge, Sigga on the slope, Old Calder at the wall")
	var sigga: NPC = souls["sigga"][0] if souls.has("sigga") else null
	var calder: NPC = souls["old_calder"][0] if souls.has("old_calder") else null
	if sigga == null or calder == null:
		return false
	# the only way over
	var bridge := Vector3(BRIDGE_X, 0, _beck_z(BRIDGE_X))
	thaw_over = _reach_len(ice_s, ice_n)
	thaw_bed = _ray_y(ICE_X, _beck_z(ICE_X))
	check(thaw_over < INF and thaw_over > ice_s.distance_to(ice_n) * 3.0 and _path_near(ice_s, ice_n, bridge, 2.0),
		"the beck is deep: from bank to bank is round by the bridge (%.0f m for %.0f m)" % [thaw_over, ice_s.distance_to(ice_n)])
	check(thaw_bed < minf(ice_s.y, ice_n.y) - 1.5, "the cut is open, %.1f m down" % (minf(ice_s.y, ice_n.y) - thaw_bed))
	check(_path_near(player.global_position, sigga.global_position, bridge, 2.0), "the way to the trod is over the plank bridge")
	_heard = []
	sigga.overheard.connect(_on_heard)
	_n0 = _titles.size()
	var z0 := player.global_position.z
	await _come_near(sigga, 9.0)
	check(not player.dead and player.global_position.z < _beck_z(player.global_position.x) and z0 > _beck_z(BRIDGE_X),
		"the Bearer crosses the bridge dry (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _until(func(): return _heard.size() >= THE_COUNT.size(), 60.0)
	sigga.overheard.disconnect(_on_heard)
	check(_heard.size() >= THE_COUNT.size() and _heard.slice(0, THE_COUNT.size()) == THE_COUNT,
		"the count, shouted across the slope: six lines in order (%s)" % str(_heard.slice(0, 2)))
	ui = await _talk("sigga")
	check(ui != null, "the Bearer walks to Sigga and speaks with her")
	if ui != null:
		await _shot("sigga_talk")
		check(ui.name_label.text == "Sigga Calder", "her name plate (%s)" % ui.name_label.text)
		var lines: Array = await _lines_of(ui)
		check(lines == SIGGA_FIRST, "Sigga's first lines, in order (%d)" % lines.size())
		var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(ids == ["give_fleece", "leave"], "she offers the spare fleece (%s)" % str(ids))
		if ids.has("give_fleece"):
			check(String(ui._options[ids.find("give_fleece")].get("label", "")) == "Take the spare fleece", "by its name")
			ui.choose(ids.find("give_fleece"))
			await ticks(2)
			check(int(player.inventory.get("armour_fleece", 0)) == 1 and World.flag("got_fleece") and not Player.armour_data("armour_fleece").is_empty(),
				"the Bearer takes it; it is armour")
			check(ui.text_label.text == "It's his old one. He won't wear it, he says it makes him cough. Everything makes him cough.", "and she says whose it was")
		await _leave(ui)
	check(_ui("DialogueUI") == null and player.input_enabled, "Leave closes the talk and hands control back")
	check(_journal("calder_boots").is_empty(), "Sigga alone starts no thread")
	ui = await _talk("sigga")
	if ui != null:
		var again: Array = await _lines_of(ui)
		check(again == SIGGA_REPEAT, "asked again, she talks about calling (%s)" % str(again.slice(0, 1)))
		check(not ui._options.any(func(o): return String(o.get("id", "")) == "give_fleece"), "the fleece is given once")
		await _leave(ui)

	ui = await _talk("old_calder")
	check(ui != null, "the Bearer climbs the trod to Old Calder at the gap (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(_titles.slice(_n0).has("THE HIGH FOLD"), "THE HIGH FOLD is named on the way (%s)" % str(_titles.slice(_n0)))
	if ui != null:
		await _shot("calder_talk")
		check(ui.name_label.text == "Old Calder", "his name plate (%s)" % ui.name_label.text)
		var c1: Array = await _lines_of(ui)
		check(c1 == CALDER_FIRST, "Calder's first audience, in order (%d)" % c1.size())
		check(World.flag("ks_calder_met") and not World.flag("ks_calder_hum"), "his thread begins; he has not hummed")
		check(ui._options.map(func(o): return String(o.get("id", ""))) == ["leave"], "he has nothing to sell")
		await _leave(ui)
	check(_journal("calder_boots") == [_all_lines("calder_boots")[0]], "Calder's boots: one line")
	ui = await _talk("old_calder")
	check(ui != null, "Old Calder, a second audience")
	if ui != null:
		_sounds = []
		ui.line_sounded.connect(func(p): _sounds.append(String(p)))
		var c2: Array = await _lines_of(ui)
		check(c2 == CALDER_SECOND, "who came up the fell at the Melt, in order (%d)" % c2.size())
		check(_sounds == [String(AudioDirector.cfg("hum", ""))] and _sounds[0] != "", "he hums the Bearer's own three notes, once (%s)" % str(_sounds))
		check(World.flag("ks_calder_hum"), "ks_calder_hum")
		await _leave(ui)
	check(_journal("calder_boots") == [_all_lines("calder_boots")[0]], "the hum has no journal line")
	ui = await _talk("old_calder")
	if ui != null:
		var c3: Array = await _lines_of(ui)
		check(c3 == CALDER_REPEAT, "a third time, he counts (%s)" % str(c3.slice(0, 1)))
		await _leave(ui)
	# the fold stands open in THAW: no veil, nobody in it
	walked = await _walk_path(gap_in, 1800, false)
	check(walked and not Game.arena_locked, "the gap stands open in THAW (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	return true

func _leg_first_rest() -> bool:
	print("== the first rest, at the Fell Path, forces RIME")
	rest = await _rest_ui_at("hs_fell_path")
	check(rest != null, "the Fell Path offers its hearth (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if rest != null:
		await _shot("rest_menu_thaw")
		check(rest.title_label.text == "the Fell Path", "the hearth is named (%s)" % rest.title_label.text)
		check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0, "uncleared THAW: rest only, no turning back")
		rest.choose(0)
		await _wait_turn()
	check(World.get_area_state(aid) == RH.WState.RIME, "the Reach is RIME now")
	check(World.last_hearth.get("hearth", "") == "hs_fell_path" and _hearth_lit("hs_fell_path"), "the Fell Path is lit and kept")
	souls = _souls()
	check(not souls.has("old_calder") and not souls.has("sigga") and not souls.has("sigga_fold"), "Calder and Sigga are gone in RIME (%s)" % str(souls.keys()))
	var kinds := {}
	for e in _awake_foes():
		kinds[e.id] = int(kinds.get(e.id, 0)) + 1
	check(int(kinds.get("drover", 0)) == 3 and int(kinds.get("frost_ram", 0)) == 3 and int(kinds.get("fellcaller", 0)) == 1 and kinds.size() == 3,
		"the frost-taken stand: three Drovers, three Frost-rams, the Fellcaller (%s)" % str(kinds))
	check(_flock_standing().size() == 70 and _flock_lying().is_empty(), "seventy sheep stand frozen on the slope (%d)" % _flock_standing().size())
	await _shot("fell_path_rime")
	return true

func _leg_stilled() -> bool:
	print("== STILLED on the fell path, and the Breathmark")
	await _die_and_recover("hs_fell_path")
	return true

func _leg_sheilings_rime() -> bool:
	print("== fight through to the Sheilings: the boots by the door")
	var w0 := Game.warmth
	await _clear_at(_g(556.0, -323.0))
	await _clear_at(_g(622.0, -294.0))
	check(Game.warmth > w0, "the fallen give up warmth (%d held)" % Game.warmth)
	took = await _take("calder_boots", "Take the boots")
	if not took and player.dead:
		await _wake_up()
		took = await _take("calder_boots", "Take the boots")
	check(took and int(player.inventory.get("item_calder_boots", 0)) == 1 and World.flag("ks_calder_boots_found"),
		"Calder's boots are taken from the sheiling door (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(_journal("calder_boots") == _all_lines("calder_boots").slice(0, 2), "Calder's boots: two lines, in order")
	check(not World.flag("ks_calder_boots_shown"), "they wait for Calder")
	await _shot("boots_rime")
	rest = await _rest_ui_at("hs_sheilings")
	check(rest != null and _option_index(rest, "toggle") < 0, "the Sheilings: uncleared RIME rests only")
	if rest != null:
		check(rest.title_label.text == "the Sheilings", "the hearth is named (%s)" % rest.title_label.text)
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
	check(_hearth_lit("hs_sheilings") and World.last_hearth.get("hearth", "") == "hs_sheilings"
		and World.get_area_state(aid) == RH.WState.RIME, "the Sheilings is lit and kept; still RIME")
	return true

func _leg_ice() -> bool:
	print("== RIME only: over the beck on the ice, where THAW has only the bridge")
	rime_over = _reach_len(ice_s, ice_n)
	check(rime_over < ice_s.distance_to(ice_n) * 1.3, "the beck is iced to the brim: straight over (%.0f m; in THAW %.0f m)" % [rime_over, thaw_over])
	var top := _ray_y(ICE_X, _beck_z(ICE_X))
	check(top > thaw_bed + 1.5, "the ice stands %.1f m over the bed THAW showed" % (top - thaw_bed))
	for attempt in 3:
		await _walk_path(ice_s, 3600, true)
		await _fight(12.0, 60.0)
		if player.dead:
			await _wake_up()
			continue
		if _flat(player.global_position - ice_s).length() < 1.5:
			break
	var t0 := Engine.get_physics_frames()
	walked = await _walk_to(ice_n, 600, 0.9, false)
	check(walked and not player.dead, "the Bearer walks over the ice, nowhere near the bridge (%d ticks, %s)" % [
		Engine.get_physics_frames() - t0, str(player.global_position.snapped(Vector3.ONE * 0.1))])
	await _shot("beck_ice")
	return true

func _leg_slope() -> bool:
	print("== the trod: between the seventy to the fold")
	await _clear_at(_g(624.0, -341.0))
	await _clear_at(_g(642.0, -358.0))
	var iron0 := int(player.inventory.get("bog_iron", 0))
	took = await _take("fold_cache", "Pry up what the frost holds")
	if not took and player.dead:
		await _wake_up()
		took = await _take("fold_cache", "Pry up what the frost holds")
	check(took and int(player.inventory.get("bog_iron", 0)) == iron0 + 2, "what the frost holds below the fold: bog-iron (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	# the seventy are obstacles: every one of them solid, and the way goes between
	var flock := _flock_standing()
	var solid := 0
	for s in flock:
		var sp := (s as Node3D).global_position
		if _ray_y(sp.x, sp.z) > area.terrain.height_at(sp.x, sp.z) + 0.4:
			solid += 1
	check(flock.size() == 70 and solid >= 66, "the frozen flock is in the way (%d of %d solid)" % [solid, flock.size()])
	await _shot("the_seventy")
	return true

func _leg_veil() -> bool:
	print("== the frost veil in the fold's gap")
	veil = _veil()
	check(veil != null and _flat(veil.global_position - (gap_out + gap_in) * 0.5).length() < 1.0, "one veil, in the gap of the High Fold")
	if veil == null:
		return false
	var cr: NPC = _souls()["calder_rime"][0] if _souls().has("calder_rime") else null
	check(cr != null and cr.seated and cr._vis.rotation.x > 1.0 and cr.find_children("*", "Interactable", true, false).is_empty(),
		"Old Calder is laid out at the cairn, on his back, with nothing to say")
	var parted := false
	for attempt in 3:
		parted = await _part_veil(veil, true)
		if parted:
			break
		await _wake_up()
	check(parted, "the Bearer climbs between the sheep and parts the veil (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(Game.arena_locked and _flat(player.global_position - FOLD).length() < FOLD_R, "it seals at his back, inside the fold")
	await _shot("veil_parted")
	return parted

func _leg_duel() -> bool:
	print("== the Fellcaller")
	boss = _foe("fellcaller")
	check(boss != null and boss is Fellcaller, "the Fellcaller herself")
	if boss != null:
		var fc := boss as Fellcaller
		check(boss.state == Enemy.ES.IDLE and not fc.stood and boss.vis.current_clip() == "call" and not hud.boss_root.visible,
			"calling out over the wall, her back to him; no bar yet (%s)" % boss.vis.current_clip())
		var cr: NPC = _souls()["calder_rime"][0] if _souls().has("calder_rime") else null
		check(cr != null and _flat(cr.global_position - fc.father_point()).length() < 1.2, "her father at the foot of the cairn, where she guards")
	var res: Dictionary = await _duel("fellcaller", veil, 1.0, 900.0, _answer_fold)
	boss = res["boss"]
	var phases: Dictionary = res["phases"]
	check(boss != null and boss.dead, "the Fellcaller is released (deaths along the way: %d)" % int(res["deaths"]))
	check(phases.has(2) and phases.has(3), "her AI ran all three phases (%s)" % str(phases.keys()))
	check(_seen["bar"], "the bar: THE FELLCALLER")
	check(int(_seen["blows"]) >= 8, "brought down by the Bearer's own blade (%d blows landed)" % int(_seen["blows"]))
	check(int(_seen["rams"]) >= 1, "Frost-rams came over the fold wall (%d at once)" % int(_seen["rams"]))
	check(float(_seen["guard_max"]) < 7.0 + 2.5, "in the count she kept by her father (%.1f m at most)" % float(_seen["guard_max"]))
	print("  (seen in the fight: %s)" % str(_seen))
	_duel_boss = null
	return boss != null and boss.dead

func _leg_release() -> bool:
	print("== the release")
	var fc := boss as Fellcaller
	await _secs(1.0)
	check(String(AudioDirector._active_music).ends_with("outsong.ogg"), "the Outsong is sung (%s)" % AudioDirector._active_music)
	check(hud.last_title == "THE FELLCALLER — RELEASED" and _cards.has("THE FELLCALLER — RELEASED"), "the quiet card (%s)" % hud.last_title)
	await _shot("release_card")
	check(World.is_cleared(aid) and World.flag("ks_fellcaller_released") and World.area_flag(aid, "slain_fellcaller"), "the Reach is cleared (ks_fellcaller_released)")
	check(not Game.arena_locked, "the veil falls")
	check(_awake_foes().filter(func(e): return _flat(e.global_position - FOLD).length() < FOLD_R + 4.0).is_empty(), "the tups go down with her")
	await _secs(2.5)
	check(boss.vis.current_clip() == "kneel_down", "she kneels beside her father (%s)" % boss.vis.current_clip())
	check(_flock_standing().size() == 70 and _flock_lying().size() == 70, "every sheep on the slope lies down (%d of %d)" % [_flock_lying().size(), _flock_standing().size()])
	var tally := _pickup("fold_tally")
	check(tally != null and tally.is_visible_in_tree() and tally.global_position.distance_to(fc.drop_point()) < 0.3
		and _flat(tally.global_position - fc.father_point()).length() < 1.5, "the fold-tally is set down by his hand")
	check(area.find_children("*", "Pickup", true, false).filter(func(p): return (p as Pickup).pickup_id == "fold_tally").size() == 1, "one tally, not two")
	await _shot("release_fold")
	check(Game.find_hearth("hs_high_fold") != null, "the High Fold wakes inside the fold")
	rest = await _rest_ui_at("hs_high_fold")
	check(rest != null and _option_index(rest, "toggle") >= 0, "the High Fold offers rest, and to turn the memory (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	if rest != null:
		check(rest.title_label.text == "the High Fold", "the hearth is named (%s)" % rest.title_label.text)
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.2)
		await _until(func(): return player.input_enabled, 6.0)
	if _ui("RestUI") != null:
		var r2 := _ui("RestUI") as RestUI
		r2.choose(_option_index(r2, "leave"))
		await ticks(4)
	check(_hearth_lit("hs_high_fold") and World.last_hearth.get("hearth", "") == "hs_high_fold"
		and World.get_area_state(aid) == RH.WState.RIME, "the High Fold is lit and kept; the Reach still RIME")
	check(_foe("fellcaller") == null, "she does not get up again")
	check(int(player.inventory.get("item_fold_tally", 0)) == 0 and not World.flag("ks_fold_tally_found"), "the tally is still on the ground")
	return true

func _leg_resume_tally() -> bool:
	print("== the game put down before the tally is taken")
	if not await _save_title_load():
		return false
	_marks()
	check(World.last_hearth.get("hearth", "") == "hs_high_fold" and World.get_area_state(aid) == RH.WState.RIME, "resumed at the High Fold, in RIME")
	var tally := _pickup("fold_tally")
	check(tally != null and tally.is_visible_in_tree(), "the fold-tally is still by his hand in the resumed Reach")
	check(area.find_children("*", "Pickup", true, false).filter(func(p): return (p as Pickup).pickup_id == "fold_tally").size() == 1, "one tally, not two")
	var cr: NPC = _souls()["calder_rime"][0] if _souls().has("calder_rime") else null
	check(cr != null and tally != null and _flat(tally.global_position - cr.global_position).length() < 2.0, "beside him, where she set it down")
	took = await _take("fold_tally", "Take the fold-tally", false)
	check(took and int(player.inventory.get("item_fold_tally", 0)) == 1 and World.flag("ks_fold_tally_found"),
		"the fold-tally is taken (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(_journal("calder_boots") == _all_lines("calder_boots").slice(0, 3), "Calder's boots: three lines, in order")
	check(String(DB.table("items")["item_fold_tally"].get("desc", "")).contains("forty-three notches"), "forty-three notches, and one cut small")
	check(_flock_standing().is_empty() and _flock_lying().size() == 70, "the seventy lie where they stood (%d)" % _flock_lying().size())
	check(_foe("fellcaller") == null and not Game.arena_locked, "nobody calls in the fold")
	await _shot("tally_taken")
	return true

func _leg_gap() -> bool:
	print("== the gap stands open: out and in, either way")
	var v2 := _veil()
	check(v2 == null or v2._seal.collision_layer == 0, "the veil stays down")
	await _walk_path(gap_in, 1800, true)
	walked = await _walk_to(gap_out, 420, 0.8, true)
	check(walked, "out by the gap (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	walked = await _walk_to(gap_in, 420, 0.8, true)
	check(walked, "and in again (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	return true

func _leg_fold_thaw() -> bool:
	print("== warmed: Calder and Sigga in the fold")
	check(await _rest("hs_high_fold", "toggle"), "the High Fold turns the memory")
	check(World.get_area_state(aid) == RH.WState.THAW, "the Reach is THAW again")
	check(_awake_foes().is_empty(), "nobody frost-taken in THAW")
	souls = _souls()
	check(souls.has("old_calder") and souls.has("sigga_fold") and not souls.has("sigga") and not souls.has("calder_rime")
		and (souls.get("old_calder", []) as Array).size() == 1,
		"Calder and Sigga stand in the fold now; nobody is left on the slope or at the gap (%s)" % str(souls.keys()))
	var cal: NPC = souls["old_calder"][0] if souls.has("old_calder") else null
	var sig: NPC = souls["sigga_fold"][0] if souls.has("sigga_fold") else null
	check(cal != null and sig != null and _flat(cal.global_position - FOLD).length() < FOLD_R and cal.global_position.distance_to(sig.global_position) < 3.0,
		"at the wall he has finished, side by side")
	var boots := area.find_children("*", "Node3D", true, false).filter(func(n):
		return (n as Node3D).scene_file_path.ends_with("calder_boots.tscn") and (n as Node3D).is_visible_in_tree())
	check(boots.size() == 1 and cal != null and _flat((boots[0] as Node3D).global_position - cal.global_position).length() < 2.0,
		"his boots off beside him (%d seen)" % boots.size())
	await _shot("fold_thaw")
	if sig != null:
		check(sig.find_children("*", "Interactable", true, false).is_empty(), "Sigga cannot be spoken to here")
		_heard = []
		sig.overheard.connect(_on_heard)
		await _come_near(sig, 5.0)
		await _until(func(): return _heard.size() >= IN_THE_FOLD.size(), 80.0)
		sig.overheard.disconnect(_on_heard)
		check(_heard.size() >= IN_THE_FOLD.size() and _heard.slice(0, IN_THE_FOLD.size()) == IN_THE_FOLD,
			"overheard in the fold, eight lines in order (%s)" % str(_heard.slice(0, 2)))
	ui = await _talk("old_calder")
	check(ui != null, "Old Calder, in the fold")
	if ui != null:
		var l1: Array = await _lines_of(ui)
		check(l1 == CALDER_BOOTS, "shown his own boots (%s)" % str(l1))
		await _leave(ui)
	check(World.flag("ks_calder_boots_shown") and int(player.inventory.get("item_calder_boots", 0)) == 1, "he does not take them")
	check(_journal("calder_boots") == _all_lines("calder_boots"), "Calder's boots: four lines, in order")
	ui = await _talk("old_calder")
	check(ui != null, "Old Calder, a second time")
	if ui != null:
		var l2: Array = await _lines_of(ui)
		check(l2 == CALDER_AFTER, "then the wall (%s)" % str(l2))
		await _leave(ui)
	return true

func _leg_thaw_routes() -> bool:
	print("== THAW only: down the open slope and back over the bridge")
	var over := _reach_len(ice_s, ice_n)
	var bridge := Vector3(BRIDGE_X, 0, _beck_z(BRIDGE_X))
	check(over > rime_over * 3.0 and _path_near(ice_n, ice_s, bridge, 2.0), "the beck runs again: bank to bank is by the bridge (%.0f m; in RIME %.0f m)" % [over, rime_over])
	check(_ray_y(ICE_X, _beck_z(ICE_X)) < minf(ice_s.y, ice_n.y) - 1.5, "and the cut is open")
	# where the seventy stood, the slope is clear
	var fold_cache := _g(651.0, -354.0)
	walked = await _walk_path(gap_out, 1800, false)
	var t0 := Engine.get_physics_frames()
	walked = walked and await _walk_path(_g(BRIDGE_X, _beck_z(BRIDGE_X) - 7.0), 1800, false)
	check(walked, "down the trod over open grass (%d ticks)" % (Engine.get_physics_frames() - t0))
	check(_ray_y(fold_cache.x + 3.0, fold_cache.z) < fold_cache.y + 1.0, "no frozen flock in THAW")
	walked = await _walk_path(ice_s, 3600, false)
	check(walked and not player.dead and player.global_position.z > _beck_z(player.global_position.x),
		"and over the plank bridge to the Sheilings' side (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	return true

func _leg_end() -> bool:
	print("== and back up, to rest at the High Fold")
	check(await _rest("hs_high_fold", "toggle"), "the High Fold turns the memory freely (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(World.get_area_state(aid) == RH.WState.RIME, "stilled again: RIME")
	check(_foe("fellcaller") == null and not Game.arena_locked, "she does not come back")
	var v2 := _veil()
	check(v2 == null or v2._seal.collision_layer == 0, "and the veil stays down")
	check(_flock_standing().is_empty() and _flock_lying().size() == 70, "the flock lies in every later RIME (%d)" % _flock_lying().size())
	check(_souls().keys() == ["calder_rime"], "her father at the cairn (%s)" % str(_souls().keys()))
	check(_reach_len(ice_s, ice_n) < ice_s.distance_to(ice_n) * 1.3, "the beck iced again")
	await _shot("high_fold_rime_cleared")
	check(await _rest("hs_high_fold", "toggle"), "and turns it back")
	check(World.get_area_state(aid) == RH.WState.THAW, "warmed once more")
	check(World.last_hearth.get("area", "") == aid and World.last_hearth.get("hearth", "") == "hs_high_fold", "the High Fold is the hearth kept")
	var up := _portal_to("coldwell")
	check(up != null and up.auto and _reach_len(player.global_position, up.global_position, 4.0) < INF, "the Upwater on to the Coldwell stands, and can be walked to")
	check(Game.current_area_id == aid, "the Bearer stays in the Reach")
	await _shot("end_thaw")
	return true

func _after_load() -> void:
	print("== the Reach, resumed")
	check(Game.current_area_id == aid and World.last_hearth.get("hearth", "") == "hs_high_fold", "at the High Fold")
	for h in ["hs_fell_path", "hs_sheilings", "hs_high_fold"]:
		check(_hearth_lit(h), "%s stays lit" % h)
	check(World.is_cleared(aid) and World.flag("ks_fellcaller_released") and World.area_flag(aid, "slain_fellcaller"), "the Fellcaller stays released")
	check(Game.find_hearth("hs_high_fold") != null, "the High Fold still burns")
	var inv := player.inventory
	check(int(inv.get("item_fold_tally", 0)) == 1 and int(inv.get("item_calder_boots", 0)) == 1 and int(inv.get("item_shepherd_whistle", 0)) == 1
		and int(inv.get("armour_fleece", 0)) == 1, "the Pack: the fold-tally, Calder's boots, the whistle, the fleece")
	check(_pickup("fold_tally") == null, "no second tally at the cairn")
	check(_journal("calder_boots") == _all_lines("calder_boots"), "Calder's boots as it was left: four lines")
	check(World.flag("ks_calder_hum"), "and the hum")
	var s := _souls()
	check(s.has("old_calder") and s.has("sigga_fold") and not s.has("sigga") and (s.get("old_calder", []) as Array).size() == 1, "Calder and Sigga in the fold")
	check(_awake_foes().is_empty() and World.get_area_state(aid) == RH.WState.THAW, "a quiet pasture")
	check(_portal_to("coldwell") != null and _portal_to("thornwold") != null, "the seams stand: down to Thornwold, up to the Coldwell")
