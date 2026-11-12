extends Node
## Game — run orchestrator: knows the player, the current area, and drives
## high-level flows (death, respawn, hearths). Scene-facing counterpart to World.

signal warmth_changed(amount: int)
signal player_registered(player)
signal player_stilled                  # death splash
signal player_respawned
signal breathmark_reclaimed(amount: int)
signal toast(text: String)               # short diegetic messages
signal lore_panel(text: String)          # plaque/lore reading
signal area_title(text: String)          # grand entry card: the area's name
signal title_card(text: String, hold: float)   # a card held longer (a release)
signal area_cleared(area_id: String)

var player: Node = null
var current_area: Node = null
var current_area_id := ""

var warmth := 0
var _death_flow_running := false
## Test seam: run the real front door (house card, title, difficulty) even
## headless. Only tools/test/fullslice_test.gd sets it.
var front_door := false
## Test seam: scales the Bearer's damage against holdfasts only, so a
## headless run can finish a boss whose AI still fights. 1.0 in play.
var test_boss_dmg_mult := 1.0
## A duel is live behind a sealed frost veil: the arena's doors refuse until the
## holdfast rests or the Bearer does. Set/cleared by the frost veils.
var arena_locked := false

## Area streaming (ADR 0014): makes the area beyond a seam ready ahead of the
## Bearer, swaps it in at the crossing, frees the one left a little a frame.
var stream: Streamer = null
## What the last rest and the last death cost the main thread, as BuildProf
## saw them ({max_work_ms, max_frame_ms, sync, ...}; docs/qa/STREAMING.md).
var last_rest_report: Dictionary = {}
var last_respawn_report: Dictionary = {}

func _ready() -> void:
	# closing the window goes through quit() too (see there)
	get_tree().auto_accept_quit = false
	stream = Streamer.new()
	stream.name = "Streamer"
	add_child(stream)
	player_registered.connect(func(p):
		if not p.died.is_connected(_on_player_died):
			p.died.connect(_on_player_died)
	)

func _process(dt: float) -> void:
	# the hearth clock: hours walked, shown on the title's slot ledger
	if player != null and is_instance_valid(player) and not get_tree().paused:
		World.play_s += dt

func _on_player_died() -> void:
	if _death_flow_running:
		return
	_death_flow_running = true
	player_stilled.emit()
	# the drop: all carried warmth stay at the death site (replacing any
	# previous breathmark — that one is lost forever)
	if warmth > 0:
		World.set_breathmark(current_area_id, player.breathmark_spot() if player.has_method("breathmark_spot") else player.global_position, warmth)
	set_warmth(0)
	World.save_game()
	await get_tree().create_timer(float(DB.tuning("death/respawn_delay", 2.8)), false).timeout
	await respawn_player()
	_death_flow_running = false

## Behind the death's black: a kept hearth in another area has that area
## built in budgeted slices (Streamer), and the dead come back a few a frame;
## neither is a frozen frame any more.
func respawn_player() -> void:
	# return to the last hearth kept
	var hearth_area: String = String(World.last_hearth.get("area", ""))
	var fresh_area := false
	var own_window := BuildProf.window_name() == ""
	if own_window:
		BuildProf.window_open("respawn")
	while stream.crossing():
		await get_tree().process_frame     # (he fell as a seam took him: let it finish)
	hearth_area = String(World.last_hearth.get("area", ""))
	if hearth_area != "" and hearth_area != current_area_id and world_root != null:
		arena_locked = false
		if stream.enabled():
			if await stream.prepare(hearth_area, false):
				var next := stream.swap()
				var t := BuildProf.now()
				register_area(next, hearth_area)
				StateDirector.snap(next, World.get_area_state(hearth_area))
				# somewhere solid while the area's hearths join it
				player.global_position = _hearth_spot(next, String(World.last_hearth.get("hearth", "")))
				player.velocity = Vector3.ZERO
				BuildProf.slice(hearth_area, "state snap, place Bearer", t)
				await stream.settle(next)
				stream.finish()
				fresh_area = true     # its foes were raised as they joined
				own_window = false    # (the crossing closed the window)
		else:
			var old := current_area
			var next := AreaBuilder.build(hearth_area)
			if next != null:
				world_root.add_child(next)
				register_area(next, hearth_area)
				if old != null:
					RH.free_gently(old)
				StateDirector.snap(next, World.get_area_state(hearth_area))
	var pos: Vector3 = player.global_position
	var hearth := find_hearth(World.last_hearth.get("hearth", ""))
	if hearth != null:
		pos = hearth.respawn_point()
	elif current_area != null and current_area.has_method("default_spawn"):
		pos = current_area.default_spawn()
	if not fresh_area:
		# he is carried to the hearth before anything returns: the foes (a
		# Holdfast above all) come back over several frames now, and none of
		# them may find him still lying where he fell, in its arena
		player.global_position = pos
		player.velocity = Vector3.ZERO
		await respawn_dead()
	if own_window:
		last_respawn_report = BuildProf.window_close()
	else:
		last_respawn_report = stream.last_report
	player.revive_at(pos)
	refresh_breathmark()
	# dying mid-boss-fight left the boss theme looping forever; the world
	# music (and the ducked ambience) belongs to the area's state again
	if current_area != null:
		AudioDirector.end_boss_theme(current_area.env.music_for(World.get_area_state(current_area_id)), 2.5)
	player_respawned.emit()

## A holdfast has been put to rest: the area opens for free warming.
## The holdfast's own data may name a story flag (a Keepsakes turn) and the
## quiet card that replaces any victory banner (SLICE.md §1).
func on_boss_slain(area_id: String, boss: Node = null) -> void:
	World.set_cleared(area_id)
	var bcfg: Dictionary = boss.get("cfg") if boss != null and boss.get("cfg") is Dictionary else {}
	if String(bcfg.get("release_flag", "")) != "":
		World.set_flag(String(bcfg["release_flag"]))
	World.save_game()
	AudioDirector.duck_ambience(false)
	if String(bcfg.get("release_card", "")) != "":
		title_card.emit(String(bcfg["release_card"]), 3.0)
	else:
		toast.emit("The holdfast rests. The memory is yours to keep or let go.")
	_release_leavings(boss, bcfg)
	# whoever the release brings back (or sends away) in this area's other
	# memory is placed now, not at the next load
	if current_area != null and current_area_id == area_id:
		AreaBuilder.refresh_flagged(current_area)
	area_cleared.emit(area_id)
	# the Outsong is sung for them; the world's music returns once it ends
	var after := ""
	if current_area != null and current_area.area_id == area_id:
		after = current_area.env.music_for(World.get_area_state(area_id))
	if bool(bcfg.get("release_outsong", true)):
		AudioDirector.play_outsong(after, 4.0)
	else:
		# (the Leadvoice: nobody sings yet; that one is the Bearer's)
		AudioDirector.end_boss_theme("", 4.0)

## What a released holdfast leaves (SLICE.md 6), from its data:
##   release_drop: {item, scene, label, pickup_id, ahead, set_flag, at_seal} ->
##     a pickup set down in front of where it sat, toward the Bearer, so it
##     is seen at once (or, with at_seal, in the middle of the sealed hole;
##     with at_point, at the boss's drop_point())
##   release_seal: {radius} -> the boss's seal_point() hole closes for good
##   release_hearth: a hearths entry id (gated on release_flag in the area
##     data) that wakes now, so a rebuilt area keeps it
##   release_gates: [gate ids] -> their bars lift now and stay lifted
func _release_leavings(boss: Node, bcfg: Dictionary) -> void:
	_clear_of_hearth(boss, bcfg)
	# release_seal: the Holdfast's own hole closes (KETTLE.md 9)
	var seal_at := Vector3.INF
	if bcfg.has("release_seal") and boss != null and boss.has_method("seal_point"):
		seal_at = boss.seal_point()
		BrokenIce.seal_at(current_area if current_area != null else boss.get_parent(), seal_at,
				float((bcfg["release_seal"] as Dictionary).get("radius", 2.0)))
	var drop: Dictionary = bcfg.get("release_drop", {})
	if not drop.is_empty() and boss is Node3D and boss.is_inside_tree():
		var b := boss as Node3D
		var k := Pickup.new()
		k.pickup_id = String(drop.get("pickup_id", "release_drop"))
		k.area_id = current_area_id
		k.item_id = String(drop.get("item", ""))
		k.label = String(drop.get("label", "Take"))
		k.display_scene = String(drop.get("scene", ""))
		k.set_flag = String(drop.get("set_flag", ""))
		var holder: Node = current_area.base if current_area != null else b.get_parent()
		if bool(drop.get("at_seal", false)) and current_area != null:
			holder = current_area.rime_layer   # (new ice is RIME's: warmed, the hole is open water)
		holder.add_child(k)
		var toward := Vector3.ZERO
		if player != null and is_instance_valid(player):
			toward = (player as Node3D).global_position - b.global_position
		toward.y = 0.0
		if toward.length() < 0.1:
			toward = Vector3(0, 0, 1)
		k.global_position = b.global_position + toward.normalized() * float(drop.get("ahead", 2.2)) + Vector3.UP * 0.02
		if bool(drop.get("at_seal", false)) and seal_at != Vector3.INF:
			k.global_position = seal_at + Vector3.UP * 0.12   # frozen into the new ice
		elif bool(drop.get("at_point", false)) and b.has_method("drop_point"):
			k.global_position = b.drop_point()   # where the Holdfast says (the Hedgelayer: on the grave)
	# release_gates: the bars he kept lift by themselves (TARNHALL.md 9); the
	# area flag keeps them open when the area is rebuilt
	for gid in bcfg.get("release_gates", []):
		if current_area != null:
			for g in current_area.find_children("*", "ShortcutGate", true, false):
				if String(g.get("gate_id")) == String(gid):
					g.lift_bar()
		World.set_area_flag(current_area_id, "gate_" + String(gid))
	var hid := String(bcfg.get("release_hearth", ""))
	if hid != "" and current_area != null and find_hearth(hid) == null:
		var def: Dictionary = current_area.get_meta("def", {})
		for spec in def.get("hearths", []):
			if String(spec.get("id", "")) != hid:
				continue
			var h := Hearthstone.new()
			h.hearth_id = hid
			h.display_name = String(spec.get("name", "Hearthstone"))
			h.area = current_area
			current_area.base.add_child(h)
			h.position = Vector3(spec["at"][0], spec["at"][1], spec["at"][2])
			h.rotation.y = deg_to_rad(float(spec.get("rot", 0)))
			AudioDirector.sfx_at("res://assets/audio/swell_warm.wav", h.global_position, -2.0)

## release_clear (metres, opt-in): she sits back down where the fight
## ended; if that is on the hearth her release wakes, the hearth caught
## inside her body. Ease her clear of it first, away from the hearth (toward
## her own end of the hall if she fell right on it), so the hearth, the
## needle and she each have their own floor.
func _clear_of_hearth(boss: Node, bcfg: Dictionary) -> void:
	var hid := String(bcfg.get("release_hearth", ""))
	var clear := float(bcfg.get("release_clear", 0.0))
	if hid == "" or clear <= 0.0 or not (boss is Node3D) or not boss.is_inside_tree() or current_area == null:
		return
	var b := boss as Node3D
	var def: Dictionary = current_area.get_meta("def", {})
	for spec in def.get("hearths", []):
		if String(spec.get("id", "")) != hid:
			continue
		var hp := Vector3(spec["at"][0], spec["at"][1], spec["at"][2])
		var off := b.global_position - hp
		off.y = 0.0
		if off.length() >= clear:
			return
		var away := off.normalized() if off.length() > 0.2 else Vector3(0, 0, -1)
		var home = b.get("home")
		if off.length() <= 0.2 and home is Vector3:
			var to_home: Vector3 = home - hp
			to_home.y = 0.0
			if to_home.length() > 0.5:
				away = to_home.normalized()
		var target := hp + away * clear
		target.y = b.global_position.y
		b.global_position = target   # the leavings are placed from here
		return

## Where a hearth of `area` stands by its data (before the hearth itself has
## joined the tree), else the area's own spawn.
func _hearth_spot(area: Area, hearth_id: String) -> Vector3:
	var def: Dictionary = area.get_meta("def", {})
	for spec in def.get("hearths", []):
		if String(spec.get("id", "")) == hearth_id and spec.has("at"):
			return AreaBuilder._v3(spec["at"]) + Vector3(0, 0.4, 0)
	return area.default_spawn()

## The dead return: every spawner and veil of the live area, a few a frame
## (streaming/respawn_budget_ms) where it used to be one call_group.
func respawn_dead() -> void:
	if stream != null:
		await stream.respawn_all()
	else:
		get_tree().call_group(RH.GROUP_RESPAWN_ON_REST, "respawn")

func snapshot_player() -> void:
	if player == null:
		return
	World.player_data = player.to_save()
	World.player_data["warmth"] = warmth

func find_hearth(hearth_id: String) -> Hearthstone:
	for l in get_tree().get_nodes_in_group("hearths"):
		if l.hearth_id == hearth_id and not (stream != null and stream.foreign(l)):
			return l
	return null

## (Re)spawn the breathmark pickup for the current area from world data.
var _breathmark_node: Breathmark = null
func refresh_breathmark() -> void:
	if _breathmark_node != null and is_instance_valid(_breathmark_node):
		_breathmark_node.queue_free()
		_breathmark_node = null
	if World.breathmark == null or current_area == null:
		return
	if World.breathmark.get("area", "") != current_area_id:
		return
	_breathmark_node = Breathmark.new()
	_breathmark_node.amount = int(World.breathmark.get("amount", 0))
	current_area.add_child(_breathmark_node)
	_breathmark_node.global_position = World.breathmark_pos()

func register_player(p: Node) -> void:
	player = p
	player_registered.emit(p)

func register_area(area: Node, id: String) -> void:
	current_area = area
	current_area_id = id

func add_warmth(n: int) -> void:
	warmth = max(0, warmth + n)
	warmth_changed.emit(warmth)

func set_warmth(n: int) -> void:
	warmth = max(0, n)
	warmth_changed.emit(warmth)

func area_state() -> RH.WState:
	return World.get_area_state(current_area_id)

var world_root: Node3D = null   # container that owns the current area

## Cross an AreaPortal: unload the region behind, build the one ahead.
## spawn_yaw (deg) turns the camera to face into the new room — arriving
## through a door should never leave you staring back at the wall you left.
## Streamed (ADR 0014): near a seam the area ahead is already standing,
## unseen, so this is a dip to black over a one-frame swap. Called cold (a
## door far from where the Bearer was, a test's teleport) the black holds
## while the area is built in budgeted slices. Returns when the Bearer
## stands in the new area with his hands free; callers that do not await it
## watch current_area_id and player.input_enabled.
func travel_to(area_id: String, spawn_pos: Vector3, spawn_yaw := 1e9) -> void:
	if world_root == null or player == null:
		return
	if not stream.enabled():
		_travel_now(area_id, spawn_pos, spawn_yaw)
		return
	if stream.crossing():
		return    # one crossing at a time (a seam's twin reporting him again)
	arena_locked = false   # no lock survives leaving the room that set it
	player.lock_control(true)
	if not await stream.prepare(area_id):
		if player == null or not is_instance_valid(player) or stream.closing:
			return    # the world was put away under the crossing (title, quit)
		push_error("Game.travel_to: area '%s' could not be built" % area_id)
		stream.reveal()
		if player != null and is_instance_valid(player):
			player.lock_control(false)
		return
	if player == null or not is_instance_valid(player) or world_root == null:
		stream.reset()    # the world was put away under the crossing (title)
		return
	var next := stream.swap()
	var t := BuildProf.now()
	register_area(next, area_id)
	# entering an unvisited area finds it in thaw (D-009)
	StateDirector.snap(next, World.get_area_state(area_id))
	_place_player(spawn_pos, spawn_yaw)
	BuildProf.slice(area_id, "state snap, place Bearer", t)
	await stream.settle(next)
	if player == null or not is_instance_valid(player):
		stream.reset()
		return
	t = BuildProf.now()
	refresh_breathmark()
	snapshot_player()
	World.save_game()
	BuildProf.slice(area_id, "save", t)
	stream.finish()
	area_title.emit(next.arrival_title(spawn_pos))
	stream.reveal()
	player.lock_control(false)

func _place_player(spawn_pos: Vector3, spawn_yaw: float) -> void:
	player.global_position = spawn_pos
	player.velocity = Vector3.ZERO
	if abs(spawn_yaw) < 720.0:
		player.cam.yaw = deg_to_rad(spawn_yaw)
		if player.get("vis") != null:
			player.vis.rotation.y = deg_to_rad(spawn_yaw)
	# a foe of the area left is no mark any more
	if player.get("cam") != null and player.cam.get("locked_target") != null:
		player.cam.set("locked_target", null)

## The old way, whole and at once (streaming/enabled false): build, swap,
## free. Kept as the fallback.
func _travel_now(area_id: String, spawn_pos: Vector3, spawn_yaw := 1e9) -> void:
	arena_locked = false
	player.lock_control(true)
	var old := current_area
	var next := AreaBuilder.build(area_id)
	world_root.add_child(next)
	register_area(next, area_id)
	if old != null:
		RH.free_gently(old)
	StateDirector.snap(next, World.get_area_state(area_id))
	_place_player(spawn_pos, spawn_yaw)
	refresh_breathmark()
	snapshot_player()
	World.save_game()
	area_title.emit(next.arrival_title(spawn_pos))
	player.lock_control(false)

signal hearth_kept(hearth)

## Sanctuary quarters (no holdfast to put down) may turn their memory freely:
## the area def opts in with "free_warm": true. Everywhere else, the toggle
## is earned by clearing the holdfast (D-009).
## The hardness of the winter, chosen when a journey begins.
## gentle: deal 1.25x, take 0.75x | long: as the winter is | hard:
## deal 0.75x, take 1.25x. Persisted in World.flags with the save.
const DIFF := {
	"gentle": {"out": 1.25, "in": 0.75},
	"long": {"out": 1.0, "in": 1.0},
	"hard": {"out": 0.75, "in": 1.25},
}
var difficulty := "long"

func set_difficulty(id: String) -> void:
	difficulty = id if DIFF.has(id) else "long"
	World.set_flag("difficulty", difficulty)

func dmg_out_mult() -> float:
	return DIFF[difficulty]["out"]

func dmg_in_mult() -> float:
	return DIFF[difficulty]["in"]

func toggle_free(aid: String) -> bool:
	if World.ended() != "":
		return false   # the coal is in the spring, or kept shut: no hearth turns
	return World.is_cleared(aid) or bool(DB.area_def(aid).get("free_warm", false))

## The rest ceremony: kneel, heal, respawn the dead, and turn the world.
## D-009 rules: uncleared+thaw -> still (committed); uncleared+rime -> rest
## only; cleared -> free choice (RestUI passes "toggle" or "rest_only").
func hearth_flow(hearth: Hearthstone, p, choice := "auto") -> void:
	if StateDirector.transitioning:
		return
	var area := hearth.area if hearth.area != null else current_area
	var aid: String = area.area_id if area != null else current_area_id
	var cur := World.get_area_state(aid)
	var target := cur
	if World.ended() != "":
		choice = "rest_only"
	match choice:
		"toggle":
			target = RH.WState.THAW if cur == RH.WState.RIME else RH.WState.RIME
		"rest_only":
			target = cur
		_:
			if toggle_free(aid):
				target = RH.WState.THAW if cur == RH.WState.RIME else RH.WState.RIME
			elif cur == RH.WState.THAW:
				target = RH.WState.RIME

	World.last_hearth = {"area": aid, "hearth": hearth.hearth_id}
	World.set_area_flag(aid, "lit_" + hearth.hearth_id)
	var own_window := BuildProf.window_name() == ""
	if own_window:
		BuildProf.window_open("rest:" + aid)

	if p != null:
		p.lock_control(true)
		p.enter_rest()
		p.heal_full()
	AudioDirector.sfx(AudioDirector.foley("coal_catch"), -3.0)   # the coal takes in the stone
	if area != null:
		AreaBuilder.sync_flagged(area)   # what the story has changed since the area was built
	# and the Bearer hums, as always, three notes (WORLD.md 4.6; MUSIC.md)
	if p != null and AudioDirector.cfg("hum", "") != "":
		get_tree().create_timer(1.1).timeout.connect(func(): AudioDirector.sfx(String(AudioDirector.cfg("hum", "")), -11.0))

	if target != cur and area != null:
		await get_tree().create_timer(1.3).timeout   # kneel beat first
		await StateDirector.transition(area, target, hearth.global_position)
	else:
		await get_tree().create_timer(1.6).timeout

	# the dead return as the world settles into its new state (a few a frame)
	await respawn_dead()

	if p != null:
		p.heal_full()
		snapshot_player()
	var ts := BuildProf.now()
	World.save_game()
	BuildProf.slice("rest", "save", ts)
	if own_window:
		last_rest_report = BuildProf.window_close()
	hearth_kept.emit(hearth)
	if p != null:
		p.exit_rest()
		p.lock_control(false)

## Leave the game. Everything that quits goes through here (the pause
## sheet, the window's close button, the tests): a neighbour may be on a
## worker thread at that moment, and it is called off and seen to end while
## the main loop still runs (Streamer.shutdown, ADR 0014 "Quitting").
var quitting := false

func quit(code := 0) -> void:
	if quitting:
		return
	quitting = true
	if stream != null:
		await stream.shutdown()
	get_tree().quit(code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()

func _exit_tree() -> void:
	if stream != null:
		# (a bare get_tree().quit() from a debug tool lands here with a worker
		# possibly still building: reset waits for it, pumping what it needs
		# of the main thread, BuildLock.wait_idle)
		stream.reset()    # no worker build outlives the caches cleared below
	AudioDirector.shutdown()
	KitLib._scene_cache.clear()
	KitLib._shape_cache.clear()
	AreaBuilder._box_mesh_cache.clear()
	MaterialLib._cache.clear()
	MaterialLib._tex_cache.clear()
	AmbientLife._mote_tex = null
	FrostFX.clear_cache()
	FrostDissolve.clear_cache()
	EnvRig.active_instance = null
