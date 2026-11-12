class_name FullgameBase
extends TestBase
## Shared driver for the full-game region walks (fullgame_<region>_test.gd):
## the same capsule-steered Bearer as tools/test/fullslice_test.gd, started
## from the save the previous region's walk ended on
## (tools/test/fixtures/fullgame_after_<previous>.json), through the REAL
## world scene and its load path. A region suite sets `region`, `aid` and
## `start_fixture`, implements `_region()`, and the base boots, then checks
## the save -> title -> load round trip and (with --fullgame-write-fixture)
## writes the save the next region starts from.
##
## Optional: --fullgame-shots=DIR captures player-camera screenshots along
## the route as qa_<region>_NN_<name>.png (needs a renderer:
## tools/qa/fullgame_shots.sh <region>).

## Short region key (lowe, kettle, tarnhall, thornwold): names the save
## dir, the shots and the fixture written at the end.
var region := ""
## The area id this walk plays through (data/areas/<aid>.json).
var aid := ""
## Fixture name (no extension) under tools/test/fixtures/ to start from.
var start_fixture := ""
## False for a walk that does not end on a live Bearer at a kept hearth in a
## cleared `aid` (the endings): it checks its own way to the title and back.
var round_trip := true

var world: Node3D
var area: Area
var player: Player
var hud: HUD
var shots_dir := ""
var write_fixture := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fullgame-shots="):
			shots_dir = a.get_slice("=", 1)
		elif a == "--fullgame-write-fixture":
			write_fixture = true
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

## A walk gives up as soon as this holds (crossing a seam: the ground under
## the Bearer has changed areas, and the old waypoint lies back over it).
var _halt := Callable()

## Steered capsule: face the point and walk; stop for foes that come at us.
func _walk_to(to: Vector3, max_ticks := 900, tol := 1.0, fight := true) -> bool:
	var waited := 0
	while waited < max_ticks:
		if player.dead:
			break
		if _halt.is_valid() and _halt.call():
			player.sim_move = Vector3.ZERO
			return false
		if fight:
			var f := _foe_near(7.0, true)
			if f != null:
				player.sim_move = Vector3.ZERO
				# (the fight's own time counts: a foe that cannot be reached
				# must not hold the walk for ever)
				var f0 := Engine.get_physics_frames()
				await _fight(16.0, 60.0)
				waited += int(Engine.get_physics_frames() - f0)
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
		if _blocked(2):
			await _sidestep()
			waited += 36
	player.sim_move = Vector3.ZERO
	return false

## True when a planned path does not arrive: it ends away from the goal's
## own place on the navmesh, on some scrap of it the Bearer happens to stand
## nearest (a barrow's passage has no navmesh floor, only fragments).
func _stranded(p: PackedVector3Array, to: Vector3) -> bool:
	if p.size() < 2:
		return true
	var goal := NavigationServer3D.map_get_closest_point(area.get_world_3d().navigation_map, to)
	var end := p[p.size() - 1]
	return Vector2(end.x - goal.x, end.z - goal.z).length() > 2.0

func _walk_path(to: Vector3, max_ticks := 3600, fight := true) -> bool:
	var p := _path(player.global_position, to)
	var used := 0
	# off the navmesh's joined-up ground a player just walks toward where he
	# is going; so does this, a few seconds at a time, until a path arrives
	var tries := 0
	while _stranded(p, to) and tries < 4 and player.global_position.distance_to(to) > 1.5 and not player.dead:
		tries += 1
		var t1 := Engine.get_physics_frames()
		await _walk_to(to, mini(240, max_ticks - used), 1.2, fight)
		used += int(Engine.get_physics_frames() - t1) + 1
		await ticks(1)
		p = _path(player.global_position, to)
	if p.size() < 2:
		return player.global_position.distance_to(to) < 1.5
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
		# (measured on the flat, and never without a tick: a waypoint on a deck
		# overhead is "reached" from the ice under it, and re-planning there
		# spun this loop for ever without yielding)
		var off := player.global_position - p[k - 1]
		if fight and Vector2(off.x, off.z).length() > 2.5:
			p = _path(player.global_position, to)
			k = 1
			await ticks(1)
			used += 1
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
				# a swing goes where the stick points, else where the body
				# already faces: backing off (or standing as the foe circles)
				# it cut the air beside him. Turn to the foe to strike.
				if player.sim_move.z > 0.0:
					player.sim_move = Vector3.ZERO
				player.vis.rotation.y = player.cam.yaw
				player.try_attack(false)
		await ticks(3)
		n += 3
		hp_low = minf(hp_low, player.hp / player.max_hp)
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

# ------------------------------------------------------------------- shots
var _shot_i := 0
func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot_i += 1
	var img := get_viewport().get_texture().get_image()
	var path := "%s/qa_%s_%02d_%s.png" % [shots_dir, region, _shot_i, name]
	img.save_png(path)
	print("  [shot] ", path)

# ------------------------------------------------------- region-walk pieces
var _stilled := 0
var _warmth_at_death := 0
func _on_stilled() -> void:
	_stilled += 1
	_warmth_at_death = Game.warmth
	var pl := Game.player as Node3D
	print("  (stilled #%d: %s at %s, %s, carrying %d)" % [_stilled, Game.current_area_id,
		str(pl.global_position.snapped(Vector3.ONE * 0.1)) if pl != null else "?",
		"RIME" if World.get_area_state(Game.current_area_id) == RH.WState.RIME else "THAW", Game.warmth])

func _settle() -> void:
	await _until(func(): return player.state == Player.S.MOVE and player._interact_suppress == 0, 3.0)
	await ticks(2)

func _foe(id: String) -> Enemy:
	for e in _awake_foes():
		if e.id == id:
			return e
	return null

func _hearth_lit(hearth_id: String) -> bool:
	return World.area_flag(aid, "lit_" + hearth_id)

## Walk into another area across a seam (auto portal) or through a door
## (prompted portal). `via` is a point on this side, at or just past the
## portal. Re-binds `area` once the new one stands. Returns true on arrival.
func _cross(to_area: String, via: Vector3, max_ticks := 9000, fight := false) -> bool:
	var stilled0 := _stilled
	_halt = func(): return Game.current_area_id == to_area
	await _walk_path(via, max_ticks, fight)
	if Game.current_area_id != to_area:
		# a seam sits at the navmesh edge: push on over it; a door wants a hand
		await _walk_to(via, 240, 0.4, fight)
	_halt = Callable()
	player.sim_move = Vector3.ZERO
	if Game.current_area_id != to_area:
		await _settle()
		var it := player.nearest_interactable()
		if it != null and it.get_parent() is AreaPortal:
			player.try_interact()
	var ok := await _until(func(): return Game.current_area_id == to_area and player.input_enabled, 12.0)
	if ok and _stilled != stilled0:
		# a fall on the way wakes the Bearer at the last hearth, which may
		# itself be in `to_area`: that is not a crossing
		area = Game.current_area
		print("  (cross to %s: the Bearer fell on the way and woke at %s)" % [to_area,
			str(player.global_position.snapped(Vector3.ONE * 0.1))])
		return false
	if ok:
		area = Game.current_area
		await ticks(30)
	else:
		print("  (cross to %s: still in %s at %s)" % [to_area, Game.current_area_id,
			str(player.global_position.snapped(Vector3.ONE * 0.1))])
	return ok

## The portal of this area that leads to `to_area` nearest to `near`.
func _portal_to(to_area: String, near := Vector3.INF) -> AreaPortal:
	var best: AreaPortal = null
	var bd := INF
	for p in area.find_children("*", "AreaPortal", true, false):
		if (p as AreaPortal).to_area != to_area:
			continue
		var d := 0.0 if near == Vector3.INF else (p as Node3D).global_position.distance_to(near)
		if best == null or d < bd:
			best = p
			bd = d
	return best

## Rest at a hearth with the given RestUI option ("rest", "toggle", ...),
## and wait the turn out if the world turns. Returns false if the hearth or
## the option is not offered.
func _rest(hearth_id: String, option := "rest") -> bool:
	var rest := await _rest_ui_at(hearth_id)
	if rest == null:
		return false
	var i := _option_index(rest, option)
	if i < 0:
		print("  (hearth %s offers %s, not %s)" % [hearth_id, str(rest._options.map(func(o): return o["id"])), option])
		rest.choose(_option_index(rest, "leave"))
		await ticks(4)
		return false
	var before := World.get_area_state(Game.current_area_id)
	var turns := option == "toggle" or (option == "rest" and before == RH.WState.THAW and not Game.toggle_free(Game.current_area_id))
	rest.choose(i)
	if turns:
		await _wait_turn()
	else:
		await _secs(2.2)
		await _until(func(): return player.input_enabled, 6.0)
	if _ui("RestUI") != null:
		var r2 := _ui("RestUI") as RestUI
		r2.choose(_option_index(r2, "leave"))
		await ticks(4)
	return true

## Take a pickup by id: walk to it, check the prompt, use it.
func _take(pickup_id: String, prompt_prefix := "", fight := true) -> bool:
	var pk := _pickup(pickup_id)
	if pk == null or not pk.is_visible_in_tree():
		print("  (pickup %s: %s)" % [pickup_id, "missing" if pk == null else "hidden"])
		return false
	await _walk_path(pk.global_position, 6000, fight)
	if fight:
		await _fight(10.0, 60.0)
	if player.dead:
		return false
	await _walk_to(pk.global_position, 400, 0.6, fight)
	await _settle()
	var it := player.nearest_interactable()
	if prompt_prefix != "" and (it == null or not it.prompt.begins_with(prompt_prefix)):
		print("  (pickup %s: prompt is %s)" % [pickup_id, it.prompt if it != null else "nothing"])
		return false
	player.try_interact()
	await ticks(6)
	return true

## Face a point and bring the blade down hard (chipping things out of ice).
func _heavy_at(at: Vector3) -> void:
	var dw := at - player.global_position
	player.cam.yaw = atan2(-dw.x, -dw.z)
	player.vis.rotation.y = player.cam.yaw
	player.sim_move = Vector3.ZERO
	await _until(func(): return player.state == Player.S.MOVE and player.stamina > 30.0, 4.0)
	player.try_attack(true)
	await _secs(1.4)

## One real death to the frost-taken and the Breathmark taken back, with the
## same checks as the slice. Needs warmth carried and foes standing (RIME).
func _die_and_recover(hearth_id: String) -> void:
	if player.dead:
		await _until(func(): return not player.dead, 10.0)
	if Game.warmth <= 0:
		var f2 := _foe_near(120.0, false, 40.0)
		if f2 != null:
			await _walk_path(f2.global_position, 2400, false)
			await _fight(12.0, 40.0)
	var carried := Game.warmth
	check(carried > 0, "warmth carried into the fall (%d)" % carried)
	var stilled0 := _stilled
	var killer := _foe_near(300.0, false, 60.0)
	check(killer != null, "a frost-taken stands near (%s)" % (killer.id if killer != null else "none"))
	if killer != null:
		await _walk_path(killer.global_position, 3600, false)
	var t_out := 0
	var last_poke := -9999
	# a Bearer grown by several regions takes a long time to bring down
	while _stilled == stilled0 and t_out < 60 * 480:
		var f3 := _foe_near(30.0)
		if f3 == null:
			f3 = _foe_near(300.0, false, 60.0)
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
				# a blow wakes a foe that has not seen him; never enough to win
				if f3.target == null and t_out - last_poke > 60 * 8 and player.try_attack(false):
					last_poke = t_out
		await ticks(3)
		t_out += 3
	player.sim_move = Vector3.ZERO
	if _stilled == stilled0:
		var fz := _foe_near(300.0, false, 60.0)
		print("  (not brought down: the Bearer at %s, %.0f of %.0f hp, state %d; nearest %s at %s, %.1f m, state %d, target %s, hp %.0f)" % [
			str(player.global_position.snapped(Vector3.ONE * 0.1)), player.hp, player.max_hp, player.state,
			fz.id if fz != null else "none", str(fz.global_position.snapped(Vector3.ONE * 0.1)) if fz != null else "-",
			fz.global_position.distance_to(player.global_position) if fz != null else -1.0,
			fz.state if fz != null else -1, str(fz.target != null) if fz != null else "-", fz.hp if fz != null else -1.0])
	check(_stilled > stilled0, "the frost-taken bring the Bearer down")
	await _secs(1.2)
	var death_seen := player.dead and hud.splash.modulate.a > 0.5
	carried = _warmth_at_death
	check(death_seen and hud.splash_label.text.to_upper() == "STILLED", "STILLED (%s)" % hud.splash_label.text)
	await _shot("stilled")
	check(World.breathmark != null and int(World.breathmark["amount"]) == carried
			and String(World.breathmark["area"]) == aid, "the warmth hangs as a Breathmark in this region")
	var bpos := World.breathmark_pos()
	check(await _until(func(): return not player.dead, 10.0), "the Bearer wakes at the hearth")
	area = Game.current_area
	var h := Game.find_hearth(hearth_id)
	check(h != null and player.global_position.distance_to(h.respawn_point()) < 3.0, "at %s" % hearth_id)
	check(_path(player.global_position, bpos).size() > 0, "the mark waits on ground the Bearer can reach (y %.2f)" % bpos.y)
	check(Game.warmth == 0, "with nothing carried")
	var bm_tries := 0
	var w_before := 0
	var bm_amount := carried
	while bm_tries < 3 and World.breathmark != null:
		bm_tries += 1
		await _until(func(): return not player.dead, 10.0)
		await ticks(20)
		await _walk_path(bpos, 7200, true)
		if player.dead:
			continue
		await _walk_to(bpos, 300, 0.6, true)
		if player.dead:
			continue
		await _settle()
		if bm_tries == 1 or _near_interact("Reclaim") != null:
			await _shot("breathmark")
		var offered := _near_interact("Reclaim") != null
		if not offered and bm_tries < 3:
			# a fight on the way back pulled the Bearer off the spot: walk to it again
			print("  (breathmark, try %d: at %s, %.1f m off the mark)" % [bm_tries,
				str(player.global_position.snapped(Vector3.ONE * 0.1)), player.global_position.distance_to(bpos)])
			continue
		check(offered, "the Breathmark offers itself")
		w_before = Game.warmth
		bm_amount = int(World.breathmark["amount"]) if World.breathmark != null else 0
		player.try_interact()
		await ticks(6)
	check(World.breathmark == null and Game.warmth - w_before == bm_amount,
		"the warmth is taken back (+%d of %d, first fall carried %d, %d tries)" % [Game.warmth - w_before, bm_amount, carried, bm_tries])

## The frost veil nearest `near` (or the only one), its front, and passage.
func _veil(near := Vector3.INF) -> FrostVeil:
	var best: FrostVeil = null
	var bd := INF
	for v in area.rime_layer.find_children("*", "FrostVeil", true, false):
		var d := 0.0 if near == Vector3.INF else (v as Node3D).global_position.distance_to(near)
		if best == null or d < bd:
			best = v
			bd = d
	return best

func _part_veil(veil: FrostVeil, fight := true) -> bool:
	var front := veil.global_position + veil.global_transform.basis.z * 1.3
	# a fight on the way ends the walk early: take the path again, never the
	# straight line through a wall
	for attempt in 4:
		await _walk_path(front, 6000, fight)
		if fight:
			await _fight(10.0, 60.0)
		if player.dead:
			return false
		if Vector2(front.x - player.global_position.x, front.z - player.global_position.z).length() < 1.5:
			break
	await _walk_to(front, 300, 0.6, fight)
	await _settle()
	if _near_interact("Part") == null:
		# some veils face the other way round
		front = veil.global_position - veil.global_transform.basis.z * 1.3
		await _walk_path(front, 2400, fight)
		await _walk_to(front, 300, 0.6, fight)
		await _settle()
	if _near_interact("Part") == null:
		var it := player.nearest_interactable()
		print("  (veil: at %s, nearest %s)" % [str(player.global_position.snapped(Vector3.ONE * 0.1)), it.prompt if it != null else "nothing"])
		return false
	player.try_interact()
	await _secs(1.5)
	return Game.arena_locked

## The duel: the Holdfast's own AI runs every phase; only the Bearer's blows
## on it are scaled (Game.test_boss_dmg_mult). On a death the Bearer walks
## back from `hearth_id` and parts the veil again. `each` (optional) is
## called every two seconds of the fight with the boss, for per-boss
## mechanics the plain melee bot must answer. Returns {boss, phases, deaths}.
func _duel(boss_id: String, veil: FrostVeil, mult := 3.0, max_s := 600.0, each := Callable()) -> Dictionary:
	var boss := _foe(boss_id)
	Game.test_boss_dmg_mult = mult if shots_dir == "" else maxf(mult, 20.0)
	var phases := {}
	var shot_phases := {}
	var t_fight := 0
	var deaths := 0
	while boss != null and not boss.dead and t_fight < int(60 * max_s):
		if player.dead or not Game.arena_locked:
			# fallen, or the veil not yet parted again: never fight the
			# Holdfast through the wall from outside its arena
			if player.dead:
				deaths += 1
				await _until(func(): return not player.dead, 10.0)
				await ticks(30)
				area = Game.current_area
			await _part_veil(veil if is_instance_valid(veil) else _veil(), true)
			boss = _foe(boss_id)
			t_fight += 120
			continue
		phases[boss.phase] = true
		if boss.phase >= 2 and not shot_phases.has(boss.phase):
			shot_phases[boss.phase] = true
			await _shot("%s_phase%d" % [boss_id, boss.phase])
		if each.is_valid():
			await each.call(boss)
		await _fight(60.0, 2.0, true)
		t_fight += 120
	Game.test_boss_dmg_mult = 1.0
	return {"boss": boss, "phases": phases, "deaths": deaths}

## Pause -> Return to the Title -> Resume, and the generic things a load
## must keep. A region adds its own checks after (flags, gates, hearths).
func _save_title_load() -> bool:
	print("== save, the title, and back")
	var lvl := player.level
	var inv := player.inventory.duplicate()
	var flags_before := World.flags.duplicate(true)
	var areas_before := World.areas.duplicate(true)
	var journal_before := Keepsakes.journal()
	var state_before := World.get_area_state(aid)
	Game.front_door = true   # the real title, headless
	PauseUI.open()
	await ticks(3)
	await _shot("pause_menu")
	var pb: Array = PauseUI._pages["main"].get_children().filter(func(c): return c is Button)
	var titles: Array = pb.map(func(b): return b.text)
	check(titles.has("Return to the Title"), "the pause sheet offers the title (%s)" % str(titles))
	if titles.has("Return to the Title"):
		pb[titles.find("Return to the Title")].pressed.emit()
	var title: Node = await _wait_child("res://src/ui/title_screen.gd", 90.0)
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
		await _shot("title_resume")
		sb[0].pressed.emit()
	var resumed := await _until(func(): return Game.player != null and is_instance_valid(Game.player), 60.0)
	check(resumed, "the hearth resumes")
	Game.front_door = false
	if not resumed:
		return false
	player = Game.player
	area = Game.current_area
	hud = get_tree().get_first_node_in_group("hud")
	player.sim_active = true
	await ticks(30)
	check(Game.current_area_id == String(World.last_hearth["area"]), "in the kept hearth's region (%s)" % Game.current_area_id)
	check(player.level == lvl, "level kept (%d)" % player.level)
	var inv_now := {}
	for k in player.inventory:
		inv_now[k] = int(player.inventory[k])
	var inv_was := {}
	for k in inv:
		inv_was[k] = int(inv[k])
	check(inv_now == inv_was, "the Pack kept")
	check(World.is_cleared(aid) and World.get_area_state(aid) == state_before, "%s cleared, its memory as it was left" % aid)
	check(Keepsakes.journal() == journal_before, "the Keepsakes kept, in order")
	var lost := []
	for k in flags_before:
		var was = flags_before[k]
		var now = World.flags.get(k)
		# (a counted flag, a speaker's chapter, is an int until the save's
		# JSON hands it back a float: 2 and 2.0 are the same chapter)
		var numbers: bool = (was is int or was is float) and (now is int or now is float)
		if (numbers and float(was) != float(now)) or (not numbers and str(now) != str(was)):
			lost.append(k)
	check(lost.is_empty(), "story flags kept (%s)" % str(lost))
	var lost_a := []
	for id in areas_before:
		for k in areas_before[id]["flags"]:
			if not World.area_flag(id, k):
				lost_a.append(id + ":" + k)
		if World.is_cleared(id) != bool(areas_before[id]["cleared"]):
			lost_a.append(id + ":cleared")
	check(lost_a.is_empty(), "every region's flags kept (%s)" % str(lost_a))
	var h := Game.find_hearth(String(World.last_hearth["hearth"]))
	check(h != null and player.global_position.distance_to(h.respawn_point()) < 2.0, "back at the kept hearth")
	await _shot("resumed")
	return true

# ------------------------------------------------------------------ the run
func _save_dir() -> String:
	# (per process: two runs of one walk at once, from two checkouts, wrote
	# over each other's slot and both failed some forty checks)
	return "user://test_fullgame_%s%s_%d" % [region, "_shots" if shots_dir != "" else "", OS.get_process_id()]

func _fixture_path(name: String) -> String:
	return "res://tools/test/fixtures/%s.json" % name

func _run() -> void:
	Game.player_stilled.connect(_on_stilled)
	World._save_dir = _save_dir()
	for i in range(1, World.SLOTS + 1):
		World.delete_slot(i)
	World.reset()
	Game.set_warmth(0)
	World.active_slot = 1
	DirAccess.make_dir_recursive_absolute(World._save_dir)
	var src := FileAccess.get_file_as_string(_fixture_path(start_fixture))
	check(src != "", "the starting save exists (%s)" % start_fixture)
	if src == "":
		finish()
		return
	var f := FileAccess.open(World.save_path(), FileAccess.WRITE)
	f.store_string(src)
	f.close()

	print("== resume from %s" % start_fixture)
	world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(world)
	if not DisplayServer.get_name().contains("headless"):
		# with a window (the shots run) the world scene opens on its real
		# front door: let the house card go and resume the hearth
		await _until(func(): return _child_of_type(world, "res://src/ui/house_card.gd") != null, 30.0)
		await _secs(1.0)
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.pressed = true
		get_tree().root.push_input(key)
		var title: Node = await _wait_child("res://src/ui/title_screen.gd", 240.0)
		if title != null:
			await _secs(1.0)
			var mb: Array = title._main_box.get_children().filter(func(c): return c is Button)
			mb[0].pressed.emit()
			await ticks(4)
			var sb: Array = title._slots_box.get_children().filter(func(c): return c is Button)
			sb[0].pressed.emit()
	var began := await _until(func(): return Game.player != null and is_instance_valid(Game.player), 240.0)
	check(began, "the hearth resumes: the Bearer stands in the world")
	if not began:
		finish()
		return
	player = Game.player
	area = Game.current_area
	hud = get_tree().get_first_node_in_group("hud")
	player.sim_active = true
	await ticks(30)
	check(hud != null, "the HUD is raised")

	await _region()

	# the next region starts from this save: a fall the walk did not notice
	# would leave its warmth lying behind for good
	check(World.breathmark == null, "no Breathmark is left lying behind (%s)" % str(World.breathmark))
	if round_trip and is_instance_valid(player) and not player.dead:
		if await _save_title_load():
			await _after_load()
	if write_fixture and fails == 0:
		World.save_game()
		var out := ProjectSettings.globalize_path(_fixture_path("fullgame_after_" + region))
		DirAccess.copy_absolute(World.save_path(), out)
		print("  [fixture] ", out)
	elif write_fixture:
		print("  [fixture] not written: %d failures" % fails)
	for i in range(1, World.SLOTS + 1):
		World.delete_slot(i)
	finish()

## The region's walk. Override.
func _region() -> void:
	pass

## Region-specific checks after the save -> title -> load round trip. Override.
func _after_load() -> void:
	pass
