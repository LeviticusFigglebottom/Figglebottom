extends TestBase
## The vertical slice, start to finish, through the REAL game: the world
## scene's own front door (house card, title, New journey, the choice of
## winter), then a capsule-steered Bearer walks Saltfell on the navmesh:
## Brede on the Strand, the cliff path, Ingra in the yard, the forced first
## rest, the yard fought through, the rye and the float out of the rime, one
## level, the gully shortcut, one death and its Breathmark, the frost veil
## and the Netmender (her AI runs; only the Bearer's blows against her are
## scaled, Game.test_boss_dmg_mult), the release (Outsong, the needle, the
## Long Hearth), both Keepsakes threads closed in THAW, free turning, and a
## save -> title -> load round trip.
##
## Optional: --fullslice-shots=DIR captures player-camera screenshots along
## the route (needs a renderer: tools/qa/fullslice_shots.sh); --perf=PATH
## writes a frame-time log per route leg.

const AID := "saltfell_steading"
var world: Node3D
var area: Area
var player: Player
var shots_dir := ""
var perf_path := ""
## --keep-save=PATH copies the finished slot out: the full-game suites
## (fullgame_*_test.gd) start from it (fixtures/fullgame_after_saltfell.json)
var keep_save := ""
var _perf_rows: Array = []
var _leg := "boot"
var _leg_frames: Array = []
var _leg_dc_max := 0.0
var _leg_dc_pos := ""
var _leg_obj_max := 0.0
var _leg_fps_min := 1e9

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fullslice-shots="):
			shots_dir = a.get_slice("=", 1)
		elif a.begins_with("--perf="):
			perf_path = a.get_slice("=", 1)
		elif a.begins_with("--keep-save="):
			keep_save = a.get_slice("=", 1)
	if shots_dir != "":
		# software rendering runs a few frames a second; let physics keep
		# game time near real time instead of crawling at 8 steps a frame
		Engine.max_physics_steps_per_frame = 30
	_run.call_deferred()

# ------------------------------------------------------------------ helpers
func _secs(s: float):
	await ticks(int(s * 60.0))

## Waits on game time, and at least as long in wall time: a software
## renderer can spend seconds of real time building a title stop.
func _until(cond: Callable, max_s := 20.0) -> bool:
	var n := 0
	var t0 := Time.get_ticks_msec()
	while not cond.call() and (n < int(max_s * 60.0) or Time.get_ticks_msec() - t0 < int(max_s * 1000.0)):
		await ticks(5)
		n += 5
	return cond.call()

func _act(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_tree().root.push_input(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_tree().root.push_input(up)

func _child_of_type(parent: Node, script_path: String) -> Node:
	for c in parent.get_children():
		if c.get_script() != null and (c.get_script() as Script).resource_path == script_path:
			return c
	return null

func _wait_child(script_path: String, max_s: float) -> Node:
	await _until(func(): return _child_of_type(world, script_path) != null, max_s)
	return _child_of_type(world, script_path)

func _ui(cls: String) -> Node:
	for c in get_tree().root.get_children():
		if c.is_class(cls) or (c.get_script() != null and (c.get_script() as Script).get_global_name() == cls):
			return c
	return null

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := area.get_world_3d().navigation_map
	var a := NavigationServer3D.map_get_closest_point(map, from)
	var b := NavigationServer3D.map_get_closest_point(map, to)
	return NavigationServer3D.map_get_path(map, a, b, true)

## The progression gate on the pass (ADR 0015).
func _pass_gate() -> ShortcutGate:
	for g in area.find_children("*", "ShortcutGate", true, false):
		if g.gate_id == "pass_net":
			return g
	return null

func _pass_shut() -> bool:
	var g := _pass_gate()
	return g != null and (g.get_node("GateBody") as StaticBody3D).collision_layer != 0

func _reaches_pass(to: Vector3) -> bool:
	var p := _path(player.global_position, to)
	return p.size() > 1 and p[p.size() - 1].distance_to(to) < 2.5

func _awake_foes() -> Array:
	return get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(
			func(e): return is_instance_valid(e) and e.is_inside_tree() and e.can_process() and not e.dead)

func _foe_near(r: float, only_alert := false, max_dy := 4.0) -> Enemy:
	var best: Enemy = null
	var bd := r
	for e in _awake_foes():
		if e.cfg.get("is_boss", false) and not only_alert:
			continue
		var d: float = (e.global_position - player.global_position).length()
		if absf(e.global_position.y - player.global_position.y) > max_dy:
			continue
		if only_alert and e.target == null:
			continue
		if d < bd:
			bd = d
			best = e
	return best

## Low furniture (the hearth kerb) is left out of the navmesh on purpose:
## foes step over it, the Bearer walks round. A steered Bearer that stops
## dead sidesteps along the obstacle, as a player would.
var _stuck_from := Vector3.ZERO
var _stuck_n := 0
var _side := 1.0
func _blocked(step: int) -> bool:
	if player.global_position.distance_to(_stuck_from) > 0.25:
		_stuck_from = player.global_position
		_stuck_n = 0
		return false
	_stuck_n += step
	return _stuck_n > 24

func _sidestep() -> void:
	_side = -_side if randf() < 0.3 else _side
	player.sim_move = Vector3(_side, 0, 0.2)
	await ticks(36)
	_stuck_n = 0

## Steered capsule: face the point and walk; stop for foes that come at us.
func _walk_to(to: Vector3, max_ticks := 900, tol := 1.0, fight := true) -> bool:
	var waited := 0
	while waited < max_ticks:
		if player.dead:
			break
		if fight:
			var f := _foe_near(7.0, true)
			if f != null:
				player.sim_move = Vector3.ZERO
				await _fight(16.0, 60.0)
				if player.dead:
					break
		var d := to - player.global_position
		d.y = 0
		if d.length() < tol:
			player.sim_move = Vector3.ZERO
			return true
		player.cam.yaw = atan2(-d.x, -d.z)
		player.sim_move = Vector3(0, 0, -1)
		await ticks(2)
		waited += 2
		_sample()
		if _blocked(2):
			await _sidestep()
			waited += 36
	player.sim_move = Vector3.ZERO
	return false

func _walk_path(to: Vector3, max_ticks := 3600, fight := true) -> bool:
	var p := _path(player.global_position, to)
	if p.size() < 2:
		return player.global_position.distance_to(to) < 1.5
	var used := 0
	var k := 1
	while k < p.size():
		var t0 := Engine.get_physics_frames()
		var last := k == p.size() - 1
		var ok: bool = await _walk_to(p[k], max_ticks - used, 0.6 if not last else 0.9, fight)
		used += int(Engine.get_physics_frames() - t0)
		if not ok:
			return false
		if fight and _foe_near(7.0, true) == null and used % 2 == 0:
			pass
		k += 1
		# a fight pulls the Bearer off the line; re-plan from where we stand
		if fight and player.global_position.distance_to(p[k - 1]) > 2.5:
			p = _path(player.global_position, to)
			k = 1
	return true

## A plain melee bot: close in, light swings, drink below 40%, roll back out
## of a windup now and then. Returns true when nothing awake is near.
var hp_low := 1.0
func _fight(radius := 14.0, max_s := 90.0, boss := false) -> bool:
	var n := 0
	while n < int(max_s * 60.0):
		if player.dead:
			return false
		var foe: Enemy = null
		if boss:
			for e in _awake_foes():
				if e.cfg.get("is_boss", false):
					foe = e
		else:
			foe = _foe_near(radius)
		if foe == null:
			player.sim_move = Vector3.ZERO
			return true
		var d := foe.global_position - player.global_position
		d.y = 0
		player.cam.yaw = atan2(-d.x, -d.z)
		var reach := 2.4 if not boss else 3.4
		if player.hp < player.max_hp * 0.4 and player.gourds > 0 and d.length() > 4.0:
			player.sim_move = Vector3.ZERO
			player.try_gourd()
		elif player.hp < player.max_hp * 0.4 and player.gourds > 0:
			player.sim_move = Vector3(0, 0, 1)   # back off to drink
		elif d.length() > reach:
			# close in along the navmesh: the hearth kerb splits the hall
			var route := _path(player.global_position, foe.global_position)
			if route.size() > 2 or (route.size() == 2 and d.length() > 6.0):
				var wp := route[1]
				if Vector2(wp.x - player.global_position.x, wp.z - player.global_position.z).length() < 0.5 and route.size() > 2:
					wp = route[2]
				var dw := wp - player.global_position
				player.cam.yaw = atan2(-dw.x, -dw.z)
			player.sim_move = Vector3(0, 0, -1)
		else:
			# hold a sword's length off; walking into a body clips through it
			player.sim_move = Vector3(0, 0, 0.5) if d.length() < reach * 0.55 else Vector3.ZERO
			if foe.state == Enemy.ES.ATTACK and foe.state_t < 0.25 and randf() < 0.35 and player.stamina > 30.0:
				player.sim_move = Vector3(1 if randf() < 0.5 else -1, 0, 0.4)
				player.try_roll()
			elif player.stamina > 18.0:
				player.try_attack(false)
		await ticks(3)
		n += 3
		hp_low = minf(hp_low, player.hp / player.max_hp)
		_sample()
		if player.sim_move.z < -0.5 and _blocked(3):
			await _sidestep()
			n += 36
	player.sim_move = Vector3.ZERO
	return false

func _near_interact(prompt_prefix: String) -> Interactable:
	var it := player.nearest_interactable()
	if it != null and it.prompt.begins_with(prompt_prefix):
		return it
	return null

func _npc(id: String) -> NPC:
	for n in area.find_children("*", "NPC", true, false):
		if (n as NPC).npc_id == id:
			return n
	return null

func _pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id:
			return p
	return null

## Walk up to a speaker and talk through to the service menu. Returns the
## open DialogueUI (or null).
func _talk(npc_id: String) -> DialogueUI:
	var n := _npc(npc_id)
	if n == null:
		return null
	for attempt in 3:
		await _walk_path(n.global_position, 3600, false)
		await _walk_to(n.global_position, 240, 1.6, false)
		await _until(func(): return player.state == Player.S.MOVE and player._interact_suppress == 0, 3.0)
		await ticks(2)
		if _near_interact("Speak with") != null:
			player.try_interact()
			await ticks(3)
			var ui := _ui("DialogueUI") as DialogueUI
			if ui != null:
				return ui
		var it := player.nearest_interactable()
		print("  (talk %s, try %d: %.1f m off, nearest %s)" % [npc_id, attempt + 1,
			player.global_position.distance_to(n.global_position), it.prompt if it != null else "nothing"])
		await _sidestep()
	return null

func _lines_of(ui: DialogueUI) -> Array:
	var out := []
	while ui._phase == "lines":
		out.append(ui.text_label.text)
		_act("interact")
		await ticks(2)
	return out

func _leave(ui: DialogueUI) -> void:
	if not is_instance_valid(ui):
		return
	if ui._phase == "lines":
		await _lines_of(ui)
	var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
	ui.choose(ids.find("leave"))
	await ticks(4)

func _journal(thread_id: String) -> Array:
	for t in Keepsakes.journal():
		if t["id"] == thread_id:
			return t["lines"]
	return []

func _rest_ui_at(hearth_id: String) -> RestUI:
	var h := Game.find_hearth(hearth_id)
	if h == null:
		return null
	for attempt in 3:
		await _walk_path(h.respawn_point(), 3600, true)
		await _walk_to(h.respawn_point(), 200, 0.8, false)
		await _until(func(): return player.state == Player.S.MOVE and player._interact_suppress == 0, 3.0)
		await ticks(2)
		if _near_interact("Keep hearth") != null:
			player.try_interact()
			await ticks(3)
			var ui := _ui("RestUI") as RestUI
			if ui != null:
				return ui
		var it := player.nearest_interactable()
		print("  (hearth %s, try %d: at %s, %.1f m off, nearest %s)" % [hearth_id, attempt + 1,
			str(player.global_position.snapped(Vector3.ONE * 0.1)), player.global_position.distance_to(h.respawn_point()),
			it.prompt if it != null else "nothing"])
		await _sidestep()
	return null

func _wait_turn() -> void:
	await _until(func(): return StateDirector.transitioning, 6.0)
	await _until(func(): return not StateDirector.transitioning, 30.0)
	await _until(func(): return player.input_enabled, 6.0)
	await ticks(20)

func _option_index(ui: RestUI, id: String) -> int:
	for i in ui._options.size():
		if String(ui._options[i]["id"]) == id:
			return i
	return -1

# ------------------------------------------------------------- shots / perf
var _shot_i := 0
func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot_i += 1
	var img := get_viewport().get_texture().get_image()
	var path := "%s/slice_%02d_%s.png" % [shots_dir, _shot_i, name]
	img.save_png(path)
	print("  [shot] ", path)

func _set_leg(name: String) -> void:
	_flush_leg()
	_leg = name

func _sample() -> void:
	if perf_path == "":
		return
	_leg_frames.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if dc > _leg_dc_max:
		_leg_dc_max = dc
		_leg_dc_pos = str(player.global_position.snapped(Vector3.ONE)) + " yaw %.0f" % rad_to_deg(player.cam.yaw)
	_leg_obj_max = maxf(_leg_obj_max, Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_leg_fps_min = minf(_leg_fps_min, Engine.get_frames_per_second())

func _flush_leg() -> void:
	if perf_path == "" or _leg_frames.is_empty():
		_leg_frames = []
		return
	var worst := 0.0
	var tot := 0.0
	for f in _leg_frames:
		worst = maxf(worst, f)
		tot += f
	_perf_rows.append({
		"leg": _leg, "frames": _leg_frames.size(), "avg_ms": tot / _leg_frames.size(), "worst_ms": worst,
		"fps_min": _leg_fps_min, "fps_end": Engine.get_frames_per_second(),
		"draw_calls_max": _leg_dc_max, "draw_calls_max_at": _leg_dc_pos,
		"objects_max": _leg_obj_max,
		"prims_end": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"multimesh_nodes": area.find_children("*", "MultiMeshInstance3D", true, false).size() if area != null else 0,
		"multimesh_visible": area.find_children("*", "MultiMeshInstance3D", true, false).filter(
			func(m): return m.is_visible_in_tree()).size() if area != null else 0,
	})
	_leg_frames = []
	_leg_dc_max = 0.0
	_leg_obj_max = 0.0
	_leg_fps_min = 1e9

# ------------------------------------------------------------------ the run
var _stilled := 0
var _warmth_at_death := 0
func _on_stilled() -> void:
	_stilled += 1
	_warmth_at_death = Game.warmth

func _run() -> void:
	Game.player_stilled.connect(_on_stilled)
	# its own save dir per mode: a shots run beside a headless run must not
	# find the other's hearth in slot I (the title would ask to forget it)
	World._save_dir = "user://test_fullslice" + ("_shots" if shots_dir != "" else "")
	for i in range(1, World.SLOTS + 1):
		World.delete_slot(i)
	World.reset()
	Game.set_warmth(0)
	Game.front_door = true

	print("== boot: the house card, the title, a new journey, the winter")
	world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(world)
	check(await _until(func(): return _child_of_type(world, "res://src/ui/house_card.gd") != null, 5.0),
		"the house card comes up first")
	var card: HouseCard = _child_of_type(world, "res://src/ui/house_card.gd")
	await _secs(2.6)
	await _shot("house_card")
	check(card._words.modulate.a > 0.5, "Figglebottom Productions fades in")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	get_tree().root.push_input(key)
	var title: Node = await _wait_child("res://src/ui/title_screen.gd", 90.0)
	check(title != null, "a key lets the card go; the title rises")
	if title == null:
		finish()
		return
	await _secs(1.5)
	await _shot("title")
	check(not title.has_save, "no hearth kept yet: no Resume")
	var buttons: Array = title._main_box.get_children().filter(func(c): return c is Button)
	check(buttons.size() == 2 and buttons[0].text == "New journey", "New journey and Settings")
	buttons[0].pressed.emit()
	await ticks(4)
	var slots: Array = title._slots_box.get_children().filter(func(c): return c is Button)
	check(slots.size() == 4 and String(slots[0].text).begins_with("Hearth I"), "three hearths and Back")
	slots[0].pressed.emit()
	var diff: Node = await _wait_child("res://src/ui/difficulty_ui.gd", 90.0)
	check(diff != null, "the winter is weighed after New journey")
	if diff == null:
		finish()   # nothing past here can run; fail fast instead of hanging
		return
	await ticks(4)
	check(String(diff._rows[1].text).contains("(default)"), "The Long Winter is marked as the default")
	await _shot("difficulty")
	_act("move_forward")
	await ticks(2)
	check(diff._opt_i == 0, "W weighs toward The Gentle Thaw")
	_act("interact")
	var began := await _until(func(): return Game.player != null and is_instance_valid(Game.player), 60.0)
	check(began, "the journey begins: the Bearer stands in the world")
	if not began:
		finish()
		return
	check(Game.difficulty == "gentle", "The Gentle Thaw holds")
	player = Game.player
	area = Game.current_area
	player.sim_active = true
	await ticks(30)

	_set_leg("strand_thaw")
	print("== the Strand, in THAW")
	check(World.get_area_state(AID) == RH.WState.THAW, "first arrival is THAW")
	var hud: HUD = get_tree().get_first_node_in_group("hud")
	check(hud != null, "the HUD is raised")
	await _until(func(): return hud != null and hud.last_title == "THE STRAND", 8.0)
	check(hud != null and hud.last_title == "THE STRAND", "the region's card, then THE STRAND (%s)" % (hud.last_title if hud != null else "?"))
	check(_awake_foes().is_empty(), "no enemies in THAW")
	await _shot("strand_arrival")
	var ui := await _talk("brede")
	check(ui != null, "the Bearer walks to Brede and speaks with him")
	if ui != null:
		await _shot("brede_talk")
		var lines: Array = await _lines_of(ui)
		check(lines.size() == 5 and lines[0] == "Mind the oars. No, the other way. Thank you.", "Brede's first lines, in order")
		check(World.flag("ks_brede_met"), "Brede's thread begins")
		await _leave(ui)
	check(_ui("DialogueUI") == null and player.input_enabled, "Leave closes the talk and hands control back")

	_set_leg("cliff_path")
	print("== the cliff path to the yard")
	var ingra := _npc("steward_ingra")
	check(ingra != null and ingra.is_visible_in_tree(), "Ingra keeps the yard in THAW")
	var walked := await _walk_path(Vector3(-12, 22, 14), 6000, false)
	check(walked and player.global_position.y > 18.0, "the Bearer climbs the cliff path to the shelf (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _secs(1.0)
	check(hud.last_title == "SALTFELL", "SALTFELL is named on reaching the yard (%s)" % hud.last_title)
	await _shot("yard_thaw")
	ui = await _talk("steward_ingra")
	check(ui != null, "the Bearer speaks with Ingra")
	if ui != null:
		await _shot("ingra_talk")
		var il: Array = await _lines_of(ui)
		check(il.size() == 5 and il[3].begins_with("We're short a sack of rye."), "Ingra's first lines, in order")
		await _leave(ui)
	check(World.flag("ks_ingra_met"), "Ingra's thread begins")
	# ADR 0015: the pass to the Lowe is shut until the Netmender is released
	check(_pass_gate() != null and _pass_shut(), "THAW: the net hangs across the pass to the Lowe")
	var pass_seam := Vector3(-89, 22.5, -84.0)
	check(not _reaches_pass(pass_seam), "and no route runs from the yard to the pass seam")
	check(_journal("ingra_rye").size() == 1 and _journal("brede_float").size() == 1, "two threads, one line each")

	_set_leg("first_rest")
	print("== the first rest forces RIME")
	var rest := await _rest_ui_at("hs_salt_house")
	check(rest != null, "the Salt House offers its hearth")
	check(_pass_shut(), "the pass is still shut at the first rest")
	if rest != null:
		await _shot("rest_menu_thaw")
		check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0,
			"uncleared THAW: rest only, no turning back")
		rest.choose(0)
		await _wait_turn()
	check(World.get_area_state(AID) == RH.WState.RIME, "Saltfell is RIME now")
	check(World.last_hearth.get("hearth", "") == "hs_salt_house", "the Salt House is the anchor")
	check(_npc("steward_ingra") == null or not _npc("steward_ingra").is_visible_in_tree(), "Ingra is gone in RIME")
	await _shot("yard_rime")
	check(_awake_foes().size() >= 10, "the frost-taken stand (%d)" % _awake_foes().size())

	_set_leg("yard_fight")
	print("== fight through the yard to the byre")
	var w0 := Game.warmth
	for at in [Vector3(-4, 22, 12), Vector3(2, 22, 3)]:
		await _walk_path(at, 1800, true)
		await _fight(12.0, 60.0)
		if player.dead:
			break
	check(not player.dead, "the Bearer lives through the yard")
	check(Game.warmth > w0, "the fallen give up warmth (%d)" % (Game.warmth - w0))
	await _shot("yard_fight")
	var sack := _pickup("rye_sack")
	check(sack != null and sack.is_visible_in_tree(), "the rye sack lies in the byre in RIME")
	if sack != null:
		await _walk_path(sack.global_position + Vector3(2.5, 0, 0), 2400, true)
		await _fight(10.0, 60.0)
		await _walk_to(sack.global_position, 300, 0.6, true)
		await _shot("byre_rye")
		await ticks(4)
		if _near_interact("Take the rye") != null:
			player.try_interact()
		await ticks(6)
	check(int(player.inventory.get("item_rye_sack", 0)) == 1 and World.flag("ks_ingra_rye_found"),
		"the rye sack is taken from under the byre dog")

	_set_leg("level_up")
	print("== one level at the Salt House")
	# a few more of the yard for the price of a level
	var tries := 0
	while Game.warmth < 60 and tries < 4 and not player.dead:
		var f := _foe_near(60.0)
		if f == null:
			break
		await _walk_path(f.global_position, 1800, true)
		await _fight(12.0, 60.0)
		tries += 1
	check(Game.warmth >= 60, "warmth enough for a level (%d)" % Game.warmth)
	rest = await _rest_ui_at("hs_salt_house")
	if rest != null:
		rest.choose(_option_index(rest, "level"))
		await ticks(2)
		await _shot("level_sheet")
		var lv := player.level
		var cost := rest._level_cost()
		var wb := Game.warmth
		rest.choose(0)
		check(player.level == lv + 1 and Game.warmth == wb - cost, "a level bought (%d -> %d, %d warmth)" % [lv, player.level, cost])
		rest.choose(_option_index(rest, "back"))
		rest.choose(_option_index(rest, "leave"))
		await ticks(4)
	check(_ui("RestUI") == null and player.input_enabled, "Rise hands control back")

	_set_leg("gully")
	print("== the gully shortcut")
	var gate: ShortcutGate = area.base.find_children("*", "ShortcutGate", true, false)[0]
	var back := gate.global_position + Vector3(0, 0, -1.4)
	walked = await _walk_path(back, 4800, true)
	check(walked and not player.dead, "down the gully to the barred side (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _shot("gully_gate")
	await ticks(4)
	var it := _near_interact("Unbar")
	check(it != null, "from above the gate can be unbarred")
	if it != null:
		player.try_interact()
	await _secs(1.0)
	check(World.area_flag(AID, "gate_boatshed_back"), "the shortcut stands open")
	walked = await _walk_to(gate.global_position + Vector3(0, 0, 2.5), 400, 0.8, true)
	check(walked, "through the boat-shed to the Strand")

	_set_leg("strand_rime")
	print("== the float, out of the frozen tide")
	var flt := _pickup("net_float")
	check(flt != null and flt.is_visible_in_tree(), "the float waits in the ice wall")
	if flt != null:
		walked = await _walk_path(flt.global_position, 6000, true)
		await _fight(12.0, 90.0)
		if not player.dead:
			await _walk_to(flt.global_position, 400, 0.6, true)
		await _shot("strand_float")
		var walls := area.rime_layer.find_children("*", "TideWall", true, false)
		check(walls.size() == 1, "the tide froze into a wall along the Strand")
		await _until(func(): return player.state == Player.S.MOVE and player._interact_suppress == 0, 3.0)
		await ticks(2)
		check(_near_interact("Chip the float") != null, "the float shows its prompt")
		player.try_interact()
		await ticks(6)
		check(int(player.inventory.get("item_net_float", 0)) == 0, "a hand alone cannot free it")
		# face the wall and bring the blade down hard
		for attempt in 4:
			if int(player.inventory.get("item_net_float", 0)) == 1:
				break
			var dw := flt.global_position - player.global_position if is_instance_valid(flt) else Vector3.FORWARD
			player.cam.yaw = atan2(-dw.x, -dw.z)
			player.vis.rotation.y = player.cam.yaw
			player.sim_move = Vector3.ZERO
			await _until(func(): return player.state == Player.S.MOVE and player.stamina > 30.0, 4.0)
			player.try_attack(true)
			await _secs(1.4)
	check(int(player.inventory.get("item_net_float", 0)) == 1 and World.flag("ks_brede_float_found"),
		"a heavy blow chips the float out of the ice")
	await _shot("strand_rime")

	_set_leg("death")
	print("== STILLED, and the Breathmark")
	if player.dead:
		await _until(func(): return not player.dead, 10.0)
	if Game.warmth <= 0:
		var f2 := _foe_near(80.0)
		if f2 != null:
			await _walk_path(f2.global_position, 2400, false)
			await _fight(12.0, 30.0)
	var carried := Game.warmth
	check(carried > 0, "warmth carried into the fall (%d)" % carried)
	# lower the blade among the frost-taken: they do the rest
	var stilled0 := _stilled
	var killer := _foe_near(200.0, false, 40.0)
	check(killer != null, "a frost-taken stands near (%s)" % (killer.id if killer != null else "none"))
	if killer != null:
		await _walk_path(killer.global_position, 3600, false)
	var t_out := 0
	var last_poke := -9999
	while _stilled == stilled0 and t_out < 60 * 180:
		var f3 := _foe_near(30.0)
		if f3 == null:
			f3 = _foe_near(200.0, false, 40.0)
		if f3 != null and not player.dead:
			var d3 := f3.global_position - player.global_position
			player.cam.yaw = atan2(-d3.x, -d3.z)
			if Vector2(d3.x, d3.z).length() > 6.0:
				await _walk_path(f3.global_position, 600, false)
				t_out += 600
			elif Vector2(d3.x, d3.z).length() > 2.0:
				player.sim_move = Vector3(0, 0, -1)
			else:
				player.sim_move = Vector3.ZERO
				# a blow now and then wakes it; never enough to win
				if t_out - last_poke > 60 * 8 and player.try_attack(false):
					last_poke = t_out
		await ticks(3)
		t_out += 3
	player.sim_move = Vector3.ZERO
	check(_stilled > stilled0, "the frost-taken bring the Bearer down")
	await _secs(1.2)
	var death_seen := player.dead and hud.splash.modulate.a > 0.5
	carried = _warmth_at_death
	check(death_seen and hud.splash_label.text.to_upper() == "STILLED", "STILLED (%s)" % hud.splash_label.text)
	await _shot("stilled")
	check(World.breathmark != null and int(World.breathmark["amount"]) == carried, "the warmth hangs as a Breathmark")
	var bpos := World.breathmark_pos()
	check(_path(player.global_position, bpos).size() > 0, "it waits on ground the Bearer can reach (y %.2f)" % bpos.y)
	check(await _until(func(): return not player.dead, 10.0), "the Bearer wakes at the hearth")
	check(player.global_position.distance_to(Game.find_hearth("hs_salt_house").respawn_point()) < 3.0, "at the Salt House")
	check(Game.warmth == 0, "with nothing carried")
	# the way back runs past the risen dead; falling again with nothing
	# carried leaves the Breathmark where it hangs, so a player simply tries
	# again (falling WITH warmth would replace it: checked below)
	var bm_tries := 0
	var w_before := 0
	var bm_amount := carried
	while bm_tries < 3 and World.breathmark != null:
		bm_tries += 1
		await _until(func(): return not player.dead, 10.0)
		await ticks(20)
		walked = await _walk_path(bpos, 7200, true)
		if player.dead:
			continue
		await _walk_to(bpos, 300, 0.6, true)
		if player.dead:
			continue
		await _until(func(): return player.state == Player.S.MOVE and player._interact_suppress == 0, 3.0)
		await ticks(2)
		if bm_tries == 1 or _near_interact("Reclaim") != null:
			await _shot("breathmark")
		check(_near_interact("Reclaim") != null, "the Breathmark offers itself")
		w_before = Game.warmth
		bm_amount = int(World.breathmark["amount"]) if World.breathmark != null else 0
		player.try_interact()
		await ticks(6)
	# (a fall on the way back with fresh warmth replaces the mark: the old one
	# is lost for good, by the rule, and the new one is what is taken back)
	check(World.breathmark == null and Game.warmth - w_before == bm_amount,
		"the warmth is taken back (+%d of %d, first fall carried %d, %d tries)" % [Game.warmth - w_before, bm_amount, carried, bm_tries])

	_set_leg("to_veil")
	print("== the frost veil")
	var veil: FrostVeil = area.rime_layer.find_children("*", "FrostVeil", true, false)[0]
	var veil_front := veil.global_position + veil.global_transform.basis.z * 1.3
	# rest at the Salt House first (and fill the gourd) on the way
	rest = await _rest_ui_at("hs_salt_house")
	if rest != null:
		rest.choose(0)
		await _wait_turn()
	walked = await _walk_path(veil_front, 4800, true)
	await _fight(10.0, 60.0)
	await _walk_to(veil_front, 300, 0.6, true)
	await _shot("frost_veil")
	await ticks(4)
	check(_near_interact("Part the frost veil") != null, "the veil offers passage")
	player.try_interact()
	await _secs(1.5)
	check(Game.arena_locked, "the veil seals at the Bearer's back")

	_set_leg("boss")
	print("== the Netmender")
	var boss: Enemy = null
	for e in _awake_foes():
		if e.id == "netmender":
			boss = e
	check(boss != null, "the Netmender sits mending")
	await _shot("netmender_mending")
	# a software renderer runs the duel at a frame or two a second; the
	# Bearer's swings lose contact frames there, so the shots run hits harder
	Game.test_boss_dmg_mult = 3.0 if shots_dir == "" else 20.0
	var phases := {}
	var t_fight := 0
	var deaths := 0
	while boss != null and not boss.dead and t_fight < 60 * 480:
		if player.dead:
			deaths += 1
			await _until(func(): return not player.dead, 10.0)
			await ticks(30)
			boss = null
			for e in _awake_foes():
				if e.id == "netmender":
					boss = e
			walked = await _walk_path(veil_front, 4800, true)
			await _walk_to(veil_front, 300, 0.6, true)
			await ticks(4)
			if _near_interact("Part") != null:
				player.try_interact()
			await _secs(1.5)
			continue
		phases[boss.phase] = true
		if boss.phase == 2 and not phases.has("shot2"):
			phases["shot2"] = true
			await _shot("netmender_phase2")
		await _fight(40.0, 2.0, true)
		t_fight += 120
	Game.test_boss_dmg_mult = 1.0
	check(boss != null and boss.dead, "the Netmender is released (deaths along the way: %d)" % deaths)
	check(phases.has(2) and phases.has(3), "her AI ran all three phases (%s)" % str(phases.keys()))

	_set_leg("release")
	print("== the release")
	await _secs(1.0)
	check(String(AudioDirector._active_music).ends_with("outsong.ogg"), "the Outsong is sung (%s)" % AudioDirector._active_music)
	check(hud.last_title == "THE NETMENDER — RELEASED", "the quiet card (%s)" % hud.last_title)
	await _shot("release_card")
	check(World.is_cleared(AID) and World.flag("ks_netmender_released"), "Saltfell is cleared")
	check(not Game.arena_locked, "the veil falls")
	check(_pass_gate() != null and not _pass_shut(), "the net across the pass has come down")
	var needle := _pickup("mending_needle")
	if needle == null:
		for pk in area.find_children("*", "Pickup", true, false):
			if (pk as Pickup).item_id == "item_mending_needle":
				needle = pk
	check(needle != null, "the mending needle lies where she sat")
	if needle != null:
		await _walk_path(needle.global_position, 1200, false)
		await _walk_to(needle.global_position, 600, 0.5, false)
		await _until(func(): return player.state == Player.S.MOVE and player._interact_suppress == 0, 3.0)
		await ticks(2)
		await _shot("needle")
		var nit := player.nearest_interactable()
		print("  (at the needle: %s, %.1f m)" % [nit.prompt if nit != null else "nothing", player.global_position.distance_to(needle.global_position)])
		player.try_interact()
		await ticks(6)
	check(int(player.inventory.get("item_mending_needle", 0)) == 1, "the needle is taken")
	var lh := Game.find_hearth("hs_long_hearth")
	check(lh != null, "the Long Hearth wakes")
	rest = await _rest_ui_at("hs_long_hearth")
	check(rest != null and _option_index(rest, "toggle") >= 0, "the Long Hearth offers to turn the memory")
	if rest != null:
		await _shot("long_hearth_menu")
		rest.choose(_option_index(rest, "toggle"))
		await _wait_turn()
	check(World.get_area_state(AID) == RH.WState.THAW, "warmed: THAW again")
	check(World.last_hearth.get("hearth", "") == "hs_long_hearth", "the Long Hearth is lit and kept")
	await _shot("longhouse_thaw")

	check(not _pass_shut(), "THAW: the pass stays open")
	await ticks(40)
	check(_reaches_pass(Vector3(-89, 22.5, -84.0)), "and the yard's navmesh runs through the dyke to the pass seam")

	_set_leg("keepsakes")
	print("== both threads close in THAW")
	ui = await _talk("steward_ingra")
	check(ui != null, "Ingra, in THAW again")
	if ui != null:
		var l1: Array = await _lines_of(ui)
		check(l1.size() > 0 and String(l1[0]).begins_with("Found it in the byre"), "she takes the rye and speaks of the dog (%s)" % str(l1.slice(0, 1)))
		await _leave(ui)
	check(World.flag("ks_ingra_rye") and int(player.inventory.get("item_rye_sack", 0)) == 0, "the rye is home")
	check(not World.flag("ks_ingra_count"), "the bowls wait for the next talk")
	ui = await _talk("steward_ingra")
	check(ui != null, "Ingra, a second time")
	if ui != null:
		var l2: Array = await _lines_of(ui)
		check(l2.size() > 0 and l2[0] == "Eleven. Twelve. Eleven.", "then she counts the bowls")
		await _leave(ui)
	check(_journal("ingra_rye").size() == 4, "Ingra's thread is whole (%d)" % _journal("ingra_rye").size())
	walked = await _walk_path(Vector3(25.0, 4.0, 52.0), 7200, false)
	ui = await _talk("brede")
	check(ui != null, "down to the Strand for Brede")
	if ui != null:
		var b1: Array = await _lines_of(ui)
		check(b1.size() > 0 and String(b1[0]).begins_with("That's it. That's my knot."), "he takes the float")
		await _shot("brede_float")
		await _leave(ui)
	ui = await _talk("brede")
	check(ui != null, "Brede, a second time")
	if ui != null:
		var b2: Array = await _lines_of(ui)
		check(b2.size() > 0 and b2[0] == "She does this faster. I don't know how she does it.", "then he mends, badly")
		await _leave(ui)
	check(_journal("brede_float").size() == 4, "Brede's thread is whole (%d)" % _journal("brede_float").size())

	_set_leg("toggle")
	print("== turning freely")
	rest = await _rest_ui_at("hs_boat_shed")
	check(rest != null and _option_index(rest, "toggle") >= 0, "the Boat-Shed turns freely too")
	if rest != null:
		rest.choose(_option_index(rest, "toggle"))
		await _wait_turn()
	check(World.get_area_state(AID) == RH.WState.RIME, "stilled again: RIME")
	await _shot("strand_rime_cleared")
	check(_awake_foes().filter(func(e): return e.id == "netmender").is_empty(), "she does not come back")
	rest = await _rest_ui_at("hs_boat_shed")
	if rest != null:
		rest.choose(_option_index(rest, "toggle"))
		await _wait_turn()
	check(World.get_area_state(AID) == RH.WState.THAW, "and warmed once more")
	await _shot("strand_thaw_end")

	_set_leg("save_load")
	print("== save, the title, and back")
	var lvl := player.level
	var inv := player.inventory.duplicate()
	var flags_before := World.flags.duplicate()
	var journal_before := Keepsakes.journal()
	PauseUI.open()
	await ticks(3)
	await _shot("pause_menu")
	var pb: Array = PauseUI._pages["main"].get_children().filter(func(c): return c is Button)
	var titles: Array = pb.map(func(b): return b.text)
	check(titles.has("Return to the Title"), "the pause sheet offers the title (%s)" % str(titles))
	if titles.has("Return to the Title"):
		pb[titles.find("Return to the Title")].pressed.emit()
	title = await _wait_child("res://src/ui/title_screen.gd", 90.0)
	check(title != null, "back at the title")
	check(Game.player == null, "the world is put away")
	check(title != null and title.has_save, "Resume the hearth is offered")
	await _secs(1.5)
	if title != null:
		var mb: Array = title._main_box.get_children().filter(func(c): return c is Button)
		check(mb[0].text == "Resume the hearth", "first choice is Resume")
		mb[0].pressed.emit()
		await ticks(4)
		var sb: Array = title._slots_box.get_children().filter(func(c): return c is Button)
		check(String(sb[0].text).contains("The Gentle Thaw"), "the ledger names the winter (%s)" % sb[0].text)
		await _shot("title_resume")
		sb[0].pressed.emit()
	var resumed := await _until(func(): return Game.player != null and is_instance_valid(Game.player), 60.0)
	check(resumed, "the hearth resumes")
	if not resumed:
		finish()
		return
	player = Game.player
	area = Game.current_area
	player.sim_active = true
	await ticks(30)
	check(player.level == lvl, "level kept (%d)" % player.level)
	check(int(player.inventory.get("item_mending_needle", 0)) == 1 and int(player.inventory.get("bog_iron", 0)) == int(inv.get("bog_iron", 0)), "the Pack kept")
	check(World.is_cleared(AID) and World.get_area_state(AID) == RH.WState.THAW, "Saltfell cleared and warm")
	check(Keepsakes.journal() == journal_before, "the Keepsakes kept, in order")
	check(World.area_flag(AID, "gate_boatshed_back"), "the shortcut stays open")
	check(Game.find_hearth("hs_long_hearth") != null, "the Long Hearth still burns")
	check(Game.difficulty == "gentle", "the winter kept")
	check(player.global_position.distance_to(Game.find_hearth(String(World.last_hearth["hearth"])).respawn_point()) < 2.0, "back at the kept hearth")
	check(flags_before.has("ks_brede_mending") and World.flag("ks_brede_mending"), "story flags kept")
	await _shot("resumed")

	_flush_leg()
	if perf_path != "":
		var f := FileAccess.open(perf_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_perf_rows, "\t"))
	Game.front_door = false
	if keep_save != "":
		World.save_game()
		DirAccess.copy_absolute(World.save_path(), keep_save)
	for i in range(1, World.SLOTS + 1):
		World.delete_slot(i)
	finish()
