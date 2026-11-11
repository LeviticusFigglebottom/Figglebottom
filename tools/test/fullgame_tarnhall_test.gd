extends FullgameBase
## Tarnhall, end to end, from the save Kettle Fjord's walk ends on: up the
## Tarn Steps seam, the feast in THAW (Ottar, Lusse, the chorus), the first
## rest and the RIME it forces, one fall on the steps and the Breathmark
## back, the frozen tarn walked to the island, the barred doors, round by
## the Byres, the veil and the Host through all three phases, the release
## (card, cup, the bar lifted, the Long Table hearth, the Outsong), the
## stick and the tally, both threads closed in THAW, and the last rest at
## the Byres.

const SEAM_SIDE := Vector3(49.75, 4.77, -302.2)
const BRIDGE := Vector3(152.75, 24.25, -332.6)
const PORCH := Vector3(177.0, 24.5, -330.0)
const DOOR := Vector3(180.0, 24.3, -329.0)
const HALL_IN := Vector3(192.0, 24.3, -329.0)
const BYRE_DOOR := Vector3(222.6, 24.3, -325.0)
## out on the tarn, well south of the causeway: water in THAW, ice in RIME
const TARN := Vector3(165.0, 22.05, -346.0)
const ICE_ROUTE := [Vector3(149.0, 22.05, -341.0), Vector3(163.0, 22.05, -348.5), Vector3(171.0, 22.05, -346.0)]

var cards: Array = []
var toasts: Array = []

func _init() -> void:
	region = "tarnhall"
	aid = "tarnhall"
	start_fixture = "fullgame_after_kettle"

# ------------------------------------------------------------------ helpers
## A section head, and how long the last one took (wall and game seconds,
## and the Bearer's falls so far): a slow box shows where the walk drags.
var _t_wall := 0
var _t_game := 0
func _mark(title: String) -> void:
	var now := Time.get_ticks_msec()
	var frames := Engine.get_physics_frames()
	if _t_wall > 0:
		print("  (%.0f s wall, %.0f s walked, %d falls so far)" % [(now - _t_wall) / 1000.0, (frames - _t_game) / 60.0, _stilled])
	_t_wall = now
	_t_game = frames
	print("== " + title)

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## A path on the navmesh as it stands now, with the polygon cap a long
## route needs lifted (the steps and the causeway are a long corridor).
func _long_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := area.get_world_3d().navigation_map
	var q := NavigationPathQueryParameters3D.new()
	q.map = map
	q.start_position = NavigationServer3D.map_get_closest_point(map, from)
	q.target_position = NavigationServer3D.map_get_closest_point(map, to)
	q.path_search_max_polygons = 200000
	var r := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(q, r)
	return r.path

func _reaches(from: Vector3, to: Vector3, tol := 2.5) -> bool:
	var p := _long_path(from, to)
	return p.size() > 1 and _flat(p[p.size() - 1], to) < tol

func _path_len(p: PackedVector3Array) -> float:
	var n := 0.0
	for i in range(1, p.size()):
		n += p[i].distance_to(p[i - 1])
	return n

func _passes(p: PackedVector3Array, pt: Vector3, tol: float) -> bool:
	for i in range(1, p.size()):
		# sample each leg: corners are far apart on a straight causeway
		var steps := maxi(1, int(p[i].distance_to(p[i - 1]) / 0.5))
		for s in steps + 1:
			if _flat(p[i - 1].lerp(p[i], float(s) / steps), pt) < tol:
				return true
	return false

## Is there walkable navmesh at pt in the state that stands? (Asked as a
## path query: map_get_closest_point also answers from the other state's
## region, which is only switched off, not taken out of the map.)
func _on_navmesh(pt: Vector3, tol := 1.0) -> bool:
	var q := NavigationPathQueryParameters3D.new()
	q.map = area.get_world_3d().navigation_map
	q.start_position = pt
	q.target_position = pt + Vector3(0.3, 0, 0)
	var r := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(q, r)
	return r.path.size() > 0 and _flat(r.path[0], pt) < tol and absf(r.path[0].y - pt.y) < 1.2

func _ray_y(x: float, z: float, top: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -30, z), RH.M_WORLD_ALL)
	var hit := area.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"].y if not hit.is_empty() else -999.0

func _wake_up() -> void:
	if player.dead:
		await _until(func(): return not player.dead, 12.0)
		await ticks(30)
		area = Game.current_area

## Walk somewhere, fighting what comes; a fall on the way is walked back
## from the hearth, as a player would.
func _go(to: Vector3, fight := true, tries := 4, max_ticks := 7200) -> bool:
	for i in tries:
		await _wake_up()
		await _walk_path(to, max_ticks, fight)
		if not player.dead and _flat(player.global_position, to) < 1.6:
			return true
		if not player.dead:
			await _walk_to(to, 300, 1.0, fight)
			if not player.dead and _flat(player.global_position, to) < 1.6:
				return true
		print("  (go %s, try %d: at %s%s)" % [str(to.snapped(Vector3.ONE * 0.1)), i + 1,
			str(player.global_position.snapped(Vector3.ONE * 0.1)), ", fallen" if player.dead else ""])
	return false

func _take_alive(pickup_id: String, prompt: String, fight := true) -> bool:
	for i in 3:
		await _wake_up()
		if await _take(pickup_id, prompt, fight):
			return true
		if _pickup(pickup_id) == null:
			return false
	return false

func _clear_near(r := 12.0, max_s := 90.0) -> void:
	for i in 3:
		await _wake_up()
		if await _fight(r, max_s):
			return

## From the hall through the door at its east end into the byre: the
## navmesh must run through it, and the Bearer walks it.
const BYRE_INNER := Vector3(216.3, 24.3, -329.0)
func _through_byre_door() -> bool:
	await _go(Vector3(213.0, 24.3, -329.0), false, 2)
	var p := _long_path(player.global_position, Vector3(221.0, 24.3, -329.0))
	var on_nav := p.size() > 1 and _passes(p, BYRE_INNER, 1.0) and _path_len(p) < 14.0
	if not on_nav:
		print("  (hall to byre on the navmesh: %.0f m, not through the door)" % _path_len(p))
	await _walk_path(Vector3(221.0, 24.3, -329.0), 900, false)
	return on_nav and not player.dead and player.global_position.x > 219.5 and absf(player.global_position.z + 329.0) < 2.5

func _gate() -> ShortcutGate:
	for g in area.find_children("*", "ShortcutGate", true, false):
		if (g as ShortcutGate).gate_id == "hall_doors":
			return g
	return null

## The white guests in their places at the long table are behind the hall's
## walls and do not stand for the Bearer: not foes to go and fight (the bot
## spent minutes trying to reach them through the wall) until the Host
## raises them.
func _awake_foes() -> Array:
	return super._awake_foes().filter(func(e): return not _sits(e))

func _sits(e: Enemy) -> bool:
	return e.cfg.get("seated", false) and e.state == Enemy.ES.IDLE

func _all_foes() -> Array:
	return super._awake_foes()

func _seated() -> Array:
	return super._awake_foes().filter(func(e): return (e as Enemy).cfg.get("seated", false))

func _standing() -> Array:
	return _awake_foes().filter(func(e): return not (e as Enemy).cfg.get("seated", false))

func _in_hall(e: Enemy) -> bool:
	return absf(e.global_position.x - 198.0) < 18.0 and absf(e.global_position.z + 330.0) < 7.0

func _expected(thread_id: String, n: int) -> Array:
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			return (t["steps"] as Array).slice(0, n).map(func(s): return String(s["line"]))
	return []

func _has(item: String) -> bool:
	return int(player.inventory.get(item, 0)) >= 1

## Against the Host the plain melee bot stands at sword's length, which is
## inside every fan he sweeps. This one fights him the way the hall teaches:
## in close, under the table (inside 1.8 m the sweep passes overhead), a
## roll through the horn fist, off the frost he pours, and a guest that has
## come up close is cut down before it cuffs him from behind.
func _fight(radius := 14.0, max_s := 90.0, boss := false) -> bool:
	if not boss:
		return await _fight_about(radius, max_s)
	if not (_foe("host") is Host):
		return await super._fight(radius, max_s, boss)
	var h := _foe("host") as Host
	var n := 0
	while n < int(max_s * 60.0):
		if player.dead:
			if not _hurts.is_empty():
				print("  (fell to the Host in phase %d: the last blows %s)" % [h.phase if is_instance_valid(h) else 0, str(_hurts.slice(-8))])
				_hurts.clear()
			return false
		if not is_instance_valid(h) or h.dead:
			player.sim_move = Vector3.ZERO
			return true
		var d := h.global_position - player.global_position
		d.y = 0
		var dist := d.length()
		var face := d
		var move := Vector3.ZERO
		var swing := false
		var atk := String(h._atk.get("id", "")) if h.state == Enemy.ES.ATTACK else ""
		var wind := float(h._atk.get("windup", 1.0)) / h._speed_mult() if atk != "" else 0.0
		if Game.arena_locked and not _in_hall_at(player.global_position) and not _out_logged:
			_out_logged = true
			print("  (the Bearer is outside the hall with the veil sealed: %s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
		if h.hook_hold != null and not h.hook_hold.is_over():
			h.hook_hold.mash()   # struggle out from under the table edge
		# the frost he pours: `pool` is under the Bearer, `his_frost` under him
		var pool: FrostPool = null
		var his_frost: FrostPool = null
		for fp in h.pools:
			if not is_instance_valid(fp) or not (fp as FrostPool).is_open():
				continue
			if _flat(player.global_position, (fp as FrostPool).global_position) <= (fp as FrostPool).radius() + 0.8:
				pool = fp
			if _flat(h.global_position, (fp as FrostPool).global_position) <= (fp as FrostPool).radius() + 1.8:
				his_frost = fp
		if player.hp < _hp_last - 0.5:
			_hurts.append("%s%s%s" % [atk if atk != "" else "-", "+frost" if pool != null else "", "+guests" if not h.standing_guests().is_empty() else ""])
		_hp_last = player.hp
		var guest: Enemy = null
		for g in h.standing_guests():
			var e := g as Enemy
			if e.state != Enemy.ES.IDLE and _flat(e.global_position, player.global_position) < 2.8:
				guest = e
		if atk == "horn_fist" and h.state_t >= wind - 0.07 and h.state_t < wind + 0.1 and dist < 6.5 and player.stamina > 1.0 \
				and player.state == Player.S.MOVE:
			player.sim_move = Vector3(1, 0, 0)
			player.try_roll()
			rolls += 1
			await ticks(8)
			n += 8
			continue
		if player.hp < player.max_hp * 0.5 and player.gourds > 0 and atk == "" and pool == null:
			player.sim_move = Vector3.ZERO
			player.try_gourd()
			await ticks(30)
			n += 30
			continue
		if pool != null:
			# off the frost: down the hall, whichever end is the nearer way out
			var side := 1.0 if player.global_position.x >= pool.global_position.x else -1.0
			var out_x := pool.global_position.x + side * 8.0
			if out_x < 183.0 or out_x > 213.0:
				out_x = pool.global_position.x - side * 8.0
			var out := Vector3(out_x, player.global_position.y, -327.0)
			var route := _path(player.global_position, out)
			face = (route[1] if route.size() > 1 else out) - player.global_position
			if route.size() > 2 and _flat(route[1], player.global_position) < 0.5:
				face = route[2] - player.global_position
			move = Vector3(0, 0, -1)
			frost_fled += 1
		elif guest != null and atk != "table_sweep":
			face = guest.global_position - player.global_position
			swing = true
		elif his_frost != null:
			# he stands in his own frost: wait it out at its edge, on the move
			# (a bench comes down where the Bearer stood)
			move = Vector3(0.7, 0, 0) if (n / 90) % 2 == 0 else Vector3(-0.7, 0, 0)
		elif dist > 1.6:
			# in under the table; along the navmesh when the fire trench is between
			if dist > 6.0:
				var route := _path(player.global_position, h.global_position)
				if route.size() > 2:
					var wp := route[1]
					if _flat(wp, player.global_position) < 0.5:
						wp = route[2]
					face = wp - player.global_position
			move = Vector3(0, 0, -1)
			swing = dist < 2.6
		else:
			swing = true
		face.y = 0
		if face.length() > 0.05:
			player.cam.yaw = atan2(-face.x, -face.z)
		player.sim_move = move
		# wind is kept back for the roll, and no blow is begun under his fist
		if swing and player.stamina > 45.0 and atk != "horn_fist":
			player.try_attack(false)
		await ticks(2)
		n += 2
		hp_low = minf(hp_low, player.hp / player.max_hp)
		if move.z < -0.5 and _blocked(2):
			await _sidestep()
			n += 36
	player.sim_move = Vector3.ZERO
	return false

## The plain bot, but a Hall-champion near is fought its own way.
func _fight_about(radius: float, max_s: float) -> bool:
	var t0 := Engine.get_physics_frames()
	while Engine.get_physics_frames() - t0 < int(max_s * 60.0):
		if player.dead:
			return false
		var f := _foe_near(radius)
		if f == null:
			player.sim_move = Vector3.ZERO
			return true
		if f.id == "hall_champion":
			await _fight_champion(f, 4.0)
		else:
			await super._fight(radius, 3.0, false)
	player.sim_move = Vector3.ZERO
	return false

## The Hall-champion holds a shield across 120 degrees of its front and
## turns most blows there. TARNHALL.md 5: strike it after it swings. The
## bot stands off at the edge of its reach, steps back from the mace and the
## bash, rolls off the line of the rush, and comes in while it recovers.
func _fight_champion(e: Enemy, max_s: float) -> void:
	var n := 0
	while n < int(max_s * 60.0) and is_instance_valid(e) and not e.dead and not player.dead:
		var d := e.global_position - player.global_position
		d.y = 0
		var dist := d.length()
		player.cam.yaw = atan2(-d.x, -d.z)
		var move := Vector3.ZERO
		var swing := false
		if player.hp < player.max_hp * 0.4 and player.gourds > 0 and e.state != Enemy.ES.ATTACK and dist > 3.5:
			player.sim_move = Vector3.ZERO
			player.try_gourd()
			await ticks(30)
			n += 30
			continue
		if e.state == Enemy.ES.ATTACK:
			var atk := String(e._atk.get("id", ""))
			var sm := e._speed_mult()
			var w := float(e._atk.get("windup", 0.5)) / sm
			var over := w + (float(e._atk.get("active", 0.2)) + float((e._hit_times() as Array)[-1])) / sm
			if e.state_t >= over:
				# it has swung: in, and strike while it recovers
				move = Vector3(0, 0, -1) if dist > 2.2 else Vector3.ZERO
				swing = dist < 2.8
			elif atk == "shield_rush":
				move = Vector3(1, 0, 0.3)   # off the strip it runs
				if e.state_t >= w - 0.1 and player.stamina > 12.0:
					player.sim_move = move
					player.try_roll()
					champion_rolls += 1
					await ticks(10)
					n += 10
					continue
			else:
				move = Vector3(0, 0, 1) if dist < 5.0 else Vector3.ZERO   # out of the mace's reach
		elif e.state == Enemy.ES.STAGGER:
			move = Vector3(0, 0, -1) if dist > 2.2 else Vector3.ZERO
			swing = dist < 2.8
		elif dist > 3.4:
			# close to the edge of its reach, along the navmesh
			var route := _path(player.global_position, e.global_position)
			if route.size() > 2 and dist > 6.0:
				var wp := route[1]
				if _flat(wp, player.global_position) < 0.5:
					wp = route[2]
				var dw := wp - player.global_position
				player.cam.yaw = atan2(-dw.x, -dw.z)
			move = Vector3(0, 0, -1)
		elif dist < 2.6:
			move = Vector3(0, 0, 0.6)
			swing = not e.is_blocking_toward(player.global_position)
		else:
			swing = not e.is_blocking_toward(player.global_position)
		player.sim_move = move
		if swing and player.stamina > 18.0:
			player.try_attack(false)
		await ticks(2)
		n += 2
		hp_low = minf(hp_low, player.hp / player.max_hp)
		if move.z < -0.5 and _blocked(2):
			await _sidestep()
			n += 36
	player.sim_move = Vector3.ZERO

var _hurts: Array = []
var _hp_last := 0.0
var frost_fled := 0
var champion_rolls := 0
var rolls := 0
var _out_logged := false
func _in_hall_at(p: Vector3) -> bool:
	return p.x > 179.5 and p.x < 216.6 and p.z > -337.5 and p.z < -322.5

## Back from the hearth after a fall, a player runs for the veil; the bot
## does too, and only fights its way there if the run fails.
var _dueling := false
func _part_veil(veil: FrostVeil, fight := true) -> bool:
	if _dueling and fight and not player.dead:
		if await super._part_veil(veil, false):
			return true
		await _wake_up()
	return await super._part_veil(veil, fight)

## Called through the duel: what the Host showed along the way.
var pins_seen := 0
var bar_seen := false
var _phase_seen := 0
var guests_seen := 0
var pools_seen := 0
func _host_each(boss: Enemy) -> void:
	var h := boss as Host
	if h == null or player.dead:
		return
	if h.phase != _phase_seen:
		_phase_seen = h.phase
		print("  (the Host: phase %d at %.0f%%, the Bearer at %.0f%%, %d falls)" % [h.phase, 100.0 * h.hp / h.max_hp,
			100.0 * player.hp / player.max_hp, _stilled])
	if h.stood and hud.boss_root.visible and hud.boss_name.text == "THE HOST":
		bar_seen = true
	guests_seen = maxi(guests_seen, h.standing_guests().size())
	pools_seen = maxi(pools_seen, h.open_pools())
	if h.hook_hold != null:
		pins_seen += 1

# ------------------------------------------------------------------ the walk
func _region() -> void:
	Game.area_title.connect(func(t: String): cards.append(t))
	Game.title_card.connect(func(t: String, _h: float): cards.append(t))
	Game.toast.connect(func(t: String): toasts.append(t))
	var leg := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fullgame-leg="):
			leg = a.get_slice("=", 1)
		elif a.begins_with("--fullgame-mult="):
			_mult = float(a.get_slice("=", 1))
	if leg != "":
		await _debug_leg(leg)
		return
	await _seam()
	if Game.current_area_id != aid:
		return   # nothing past here can run
	await _thaw()
	await _first_rest()
	await _fall()
	await _tarn()
	await _doors()
	await _byres()
	var released := await _host()
	if not released:
		return
	await _release()
	await _after_release()
	await _last_rest()

## Debugging only (never the suite's own run): --fullgame-leg=host starts
## at the Byres hearth in RIME with the earlier legs' flags faked, so the
## duel and what follows can be watched without the half hour before them.
var _mult := 3.0
func _debug_leg(leg: String) -> void:
	print("== DEBUG LEG %s (not the walk: the earlier legs are faked)" % leg)
	fails += 1
	World.set_area_state(aid, RH.WState.RIME)
	for f in ["met_lusse", "met_ottar", "ks_lusse_met", "ks_ottar_met", "ks_goat_song"]:
		World.set_flag(f)
	for h in ["hs_tarn_steps", "hs_tarn_causeway", "hs_byres"]:
		World.set_area_flag(aid, "lit_" + h)
	World.last_hearth = {"area": aid, "hearth": "hs_byres"}
	Game.travel_to(aid, Vector3(219.6, 24.6, -320.6))
	await _until(func(): return Game.current_area_id == aid and player.input_enabled, 20.0)
	area = Game.current_area
	await ticks(60)
	if leg == "byres":
		await _byres()
	if await _host():
		await _release()
		await _after_release()
		await _last_rest()

func _seam() -> void:
	_mark("the Tarn Steps: Kettle Fjord to Tarnhall")
	check(Game.current_area_id == "kettle_fjord", "the walk starts in Kettle Fjord (%s)" % Game.current_area_id)
	check(String(World.last_hearth.get("hearth", "")) == "hs_fish_houses", "at the Fish-Houses hearth")
	check(World.get_area_state("kettle_fjord") == RH.WState.THAW and World.is_cleared("kettle_fjord"),
		"Kettle Fjord released and warm")
	check(not World.areas.has(aid) or not World.is_cleared(aid), "Tarnhall not yet walked")
	var seam := _portal_to(aid, SEAM_SIDE)
	check(seam != null and seam.auto, "the Tarn Steps seam stands")
	if seam == null:
		return
	var via: Vector3 = seam.global_position + (seam.spawn_pos - seam.global_position).normalized() * 1.0
	var thaw_way := _reaches(player.global_position, seam.global_position, 3.0)
	print("  (THAW way to the seam: %s; the path ends at %s)" % [str(thaw_way),
		str(_long_path(player.global_position, seam.global_position)[-1].snapped(Vector3.ONE * 0.1))])
	if not thaw_way:
		# the fjord head is water in THAW: a player turns the memory at the
		# hearth and walks the ice
		print("  (no THAW way: turning the memory at the Fish-Houses)")
		check(await _rest("hs_fish_houses", "toggle"), "the Fish-Houses hearth turns the memory")
		check(World.get_area_state("kettle_fjord") == RH.WState.RIME, "Kettle Fjord is RIME")
		check(_reaches(player.global_position, seam.global_position, 3.0), "over the ice the seam can be reached")
	cards.clear()
	var crossed := false
	for i in 3:
		await _wake_up()
		crossed = await _cross(aid, via, 12000, true)
		if crossed:
			break
	check(crossed, "the Bearer walks up into Tarnhall (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return
	check(World.get_area_state(aid) == RH.WState.THAW, "first arrival is THAW")
	check(player.global_position.x > SEAM_SIDE.x and _flat(player.global_position, SEAM_SIDE) < 12.0,
		"set down at the foot of the Tarn Steps, past the seam (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	await _until(func(): return cards.has("THE TARN CAUSEWAY"), 8.0)
	var up: Array = cards.map(func(c): return String(c).to_upper())
	check(up.has("TARNHALL") and up.has("THE TARN CAUSEWAY") and up.find("TARNHALL") < up.find("THE TARN CAUSEWAY"),
		"the region's card, then THE TARN CAUSEWAY (%s)" % str(cards))
	check(hud.last_title == "THE TARN CAUSEWAY", "the card shown last is the zone's (%s)" % hud.last_title)
	check(_all_foes().is_empty(), "no enemies in THAW (%d)" % _all_foes().size())
	await _secs(1.0)
	check(Game.current_area_id == aid, "the seam does not carry him straight back")
	await _shot("arrival")

func _thaw() -> void:
	_mark("THAW: up the steps, over the causeway, in at the open doors")
	var steps := Game.find_hearth("hs_tarn_steps")
	check(steps != null and Game.find_hearth("hs_tarn_causeway") != null and Game.find_hearth("hs_byres") != null,
		"three hearths stand")
	check(Game.find_hearth("hs_long_table") == null, "the Long Table hearth sleeps")
	var rest := await _rest_ui_at("hs_tarn_steps")
	check(rest != null, "the Bearer climbs to the Tarn Steps hearth")
	if rest != null:
		check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0,
			"uncleared THAW: rest only, no turning back")
		check(String(rest._options[0]["label"]).contains("the memory will still"), "and the hearth says what a rest will do (%s)" % rest._options[0]["label"])
		rest.choose(_option_index(rest, "leave"))
		await ticks(6)
	check(_ui("RestUI") == null and player.input_enabled and World.get_area_state(aid) == RH.WState.THAW,
		"Rise leaves the feast as it is")
	var shore := Game.find_hearth("hs_tarn_causeway").respawn_point()
	check(await _go(shore, false), "up to the tarn shore (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _shot("causeway_thaw")
	var p_in := _long_path(player.global_position, HALL_IN)
	check(p_in.size() > 1 and _flat(p_in[p_in.size() - 1], HALL_IN) < 2.5 and _passes(p_in, BRIDGE, 3.0) and _passes(p_in, DOOR, 2.0),
		"THAW: the causeway, the plank bridge and the open doors are the way in")
	check(not _on_navmesh(TARN), "THAW: the tarn is open water, nothing to walk on")
	check(_ray_y(TARN.x, TARN.z, 40.0) < TARN.y - 0.5, "the water has no floor at its top (%.2f)" % _ray_y(TARN.x, TARN.z, 40.0))
	check(await _go(PORCH, false), "over the causeway and the bridge to the porch")
	check(_gate() == null or not _gate().is_visible_in_tree() or _gate()._is_open(), "the doors stand open in THAW")
	check(await _go(HALL_IN, false), "in at the front doors")
	await _until(func(): return hud.last_title == "THE LONG TABLE", 4.0)
	check(hud.last_title == "THE LONG TABLE", "THE LONG TABLE is named on coming in (%s)" % hud.last_title)
	await _shot("hall_thaw")
	check(_all_foes().is_empty() and _foe("host") == null, "the Host is not seen")

	_mark("Ottar and Lusse")
	check(_npc("ottar") != null and _flat(_npc("ottar").global_position, DOOR) < 3.5, "Ottar stands just inside the front door")
	var ui := await _talk("ottar")
	check(ui != null, "the Bearer speaks with Ottar")
	if ui != null:
		check(ui.name_label.text == "Ottar", "his name on the plate (%s)" % ui.name_label.text)
		var ol: Array = await _lines_of(ui)
		check(ol == DB.npc("ottar")["lines_first"] and ol.size() == 4 and String(ol[0]).begins_with("I'm away. Boots are on.")
			and String(ol[3]).begins_with("I've left my stick by the door"), "Ottar's first lines, in order (%d)" % ol.size())
		check(ui._options.size() == 1 and String(ui._options[0]["id"]) == "leave", "he has nothing to trade: Leave only")
		await _leave(ui)
	check(_ui("DialogueUI") == null and player.input_enabled, "Leave hands control back")
	check(World.flag("ks_ottar_met") and World.flag("met_ottar"), "Ottar's thread begins")
	check(_journal("ottar_stick") == _expected("ottar_stick", 1) and _journal("ottar_stick").size() == 1, "one line in the journal for him")
	check(_npc("lusse") != null and _flat(_npc("lusse").global_position, Vector3(197.0, 0, -327.4)) < 4.0, "Lusse stands on the open floor by the fire")
	ui = await _talk("lusse")
	check(ui != null, "the Bearer speaks with Lusse")
	if ui != null:
		check(ui.name_label.text == "Lusse, hall-singer", "her name on the plate (%s)" % ui.name_label.text)
		var ll: Array = await _lines_of(ui)
		check(ll == DB.npc("lusse")["lines_first"] and ll.size() == 4 and String(ll[0]).begins_with("You came up the steps in time.")
			and String(ll[3]).begins_with("Fish from the trader's boat."), "Lusse's first lines, in order (%d)" % ll.size())
		check(_journal("guest_tally") == _expected("guest_tally", 1), "her thread begins")
		var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(ids == ["sing_goat_song", "buy_long_note", "leave"], "the chorus, the Long Note, Leave (%s)" % str(ids))
		ui.choose(ids.find("sing_goat_song"))
		await ticks(4)
		check(ui.text_label.text == "Not bad. Again, and this time come in when I point.", "she answers the chorus (%s)" % ui.text_label.text)
		await _shot("lusse_chorus")
		await _leave(ui)
	check(World.flag("ks_lusse_met") and World.flag("ks_goat_song") and _has("goat_song"), "the Bearer has the Goat Song")
	check(player.attuned_song == "goat_song" or player.attuned_song != "", "a song is attuned (%s)" % player.attuned_song)
	check(_journal("guest_tally") == _expected("guest_tally", 2), "two lines for the guest-tally")
	ui = await _talk("lusse")
	check(ui != null, "Lusse, again")
	if ui != null:
		var l2: Array = await _lines_of(ui)
		check(l2 == ["There. Now you'll have it in your head till the Melt. I'm not sorry."], "after the chorus she is not sorry (%s)" % str(l2))
		var ids2: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(not ids2.has("sing_goat_song"), "the chorus is sung once")
		await _leave(ui)
	check(not World.flag("ks_ottar_staff_found") and _pickup("ottar_staff") == null or not _pickup("ottar_staff").is_visible_in_tree(),
		"no stick to be had in THAW")

	_mark("through to the Byres")
	check(await _through_byre_door(), "through the door at the high seat's end into the byre (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(await _go(BYRE_DOOR + Vector3(0, 0, 2.5), false), "and out at the cattle door")
	await _until(func(): return hud.last_title == "THE BYRES", 4.0)
	check(hud.last_title == "THE BYRES", "THE BYRES is named (%s)" % hud.last_title)
	check(_veil() == null or not _veil().is_visible_in_tree(), "no veil in THAW")

func _first_rest() -> void:
	_mark("the first rest forces RIME")
	check(await _go(Game.find_hearth("hs_tarn_causeway").respawn_point(), false, 2, 9000), "back out over the causeway")
	var rest := await _rest_ui_at("hs_tarn_causeway")
	check(rest != null, "the Tarn Causeway offers its hearth")
	if rest != null:
		check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0, "rest only")
		rest.choose(0)
		await _wait_turn()
	check(World.get_area_state(aid) == RH.WState.RIME, "Tarnhall is RIME now")
	check(World.last_hearth.get("hearth", "") == "hs_tarn_causeway" and _hearth_lit("hs_tarn_causeway"), "the Tarn Causeway is the anchor")
	check((_npc("lusse") == null or not _npc("lusse").is_visible_in_tree()) and (_npc("ottar") == null or not _npc("ottar").is_visible_in_tree()),
		"Lusse and Ottar are gone in RIME")
	await _shot("causeway_rime")
	var kinds := {}
	for e in _standing():
		kinds[(e as Enemy).id] = int(kinds.get((e as Enemy).id, 0)) + 1
	check(int(kinds.get("feast_guest", 0)) == 4 and int(kinds.get("cupbearer", 0)) == 2 and int(kinds.get("hall_champion", 0)) == 2
		and int(kinds.get("host", 0)) == 1, "the frost-taken stand: four guests, two cupbearers, two champions, the Host (%s)" % str(kinds))
	var seats := _seated()
	check(seats.size() == 5 and seats.all(func(g): return (g as Enemy).state == Enemy.ES.IDLE and (g as Enemy).vis.current_clip() == "sit_feast"),
		"five guests sit white at the long table (%d)" % seats.size())
	var yard: Enemy = null
	for e in _standing():
		if _flat((e as Enemy).global_position, Vector3(226.6, 0, -321.0)) < 1.0:
			yard = e
	check(yard != null and yard.state == Enemy.ES.IDLE and yard.vis.current_clip().begins_with("sit"),
		"one sits on a barrel in the byre yard (%s)" % (yard.vis.current_clip() if yard != null else "none"))
	var rest2 := await _rest_ui_at("hs_tarn_causeway")
	check(rest2 != null and _option_index(rest2, "toggle") < 0 and String(rest2._options[0]["label"]) == "Keep hearth  (rest)",
		"uncleared RIME: rest, and no turning back")
	if rest2 != null:
		rest2.choose(_option_index(rest2, "leave"))
		await ticks(6)

func _fall() -> void:
	_mark("STILLED on the steps, and the Breathmark")
	var guest: Enemy = null
	for e in _standing():
		if _flat((e as Enemy).global_position, Vector3(98.6, 0, -326.8)) < 2.0:
			guest = e
	check(guest != null and guest.id == "feast_guest", "a Feast-guest stands on the steps")
	await _die_and_recover("hs_tarn_causeway")
	await _wake_up()
	# and now it is put down, and the steps hearth lit on the way
	if guest != null and is_instance_valid(guest) and not guest.dead:
		await _go(guest.global_position, true, 3)
		await _clear_near(12.0, 60.0)
	check(not player.dead, "the Bearer lives through the guest on the steps")
	check(await _rest("hs_tarn_steps", "rest"), "the Tarn Steps hearth is kept")
	check(_hearth_lit("hs_tarn_steps") and World.last_hearth.get("hearth", "") == "hs_tarn_steps", "lit, and the anchor now")
	check(World.get_area_state(aid) == RH.WState.RIME, "still RIME: an uncleared hearth only rests")

func _tarn() -> void:
	_mark("RIME: the tarn is frozen, and the island can be walked to")
	var shore := Game.find_hearth("hs_tarn_causeway").respawn_point()
	check(await _go(shore, true), "up to the tarn shore again")
	check(_on_navmesh(TARN), "RIME: there is ice to walk on where the water was")
	check(absf(_ray_y(TARN.x, TARN.z, 40.0) - 22.05) < 0.2, "the ice has a floor (%.2f)" % _ray_y(TARN.x, TARN.z, 40.0))
	var south := Vector3(176.5, 24.5, -335.5)
	var over_ice := _long_path(ICE_ROUTE[2], south)
	check(over_ice.size() > 1 and _flat(over_ice[over_ice.size() - 1], south) < 2.5 and not _passes(over_ice, BRIDGE, 6.0),
		"from the ice the island is reached without the bridge (ends %s)" % (str(over_ice[over_ice.size() - 1].snapped(Vector3.ONE * 0.1)) if over_ice.size() > 0 else "nowhere"))
	var thin := get_tree().get_nodes_in_group("hazards").filter(func(h): return (h as HazardVolume).kind == "thin")
	check(thin.size() == 4, "four cracks in the ice (%d)" % thin.size())
	var ok := true
	for wp in ICE_ROUTE:
		ok = ok and await _go(wp, true, 2)
		check(not player.dead and absf(player.global_position.y - 22.05) < 0.6 or not ok,
			"on the ice at %s (y %.2f)" % [str((wp as Vector3).snapped(Vector3.ONE)), player.global_position.y])
	check(ok, "the Bearer walks out over the frozen tarn, round the crack")
	await _shot("tarn_ice")
	check(await _go(PORCH + Vector3(0, 0, -3.5), true, 3), "and up onto the island by the porch, the bridge never crossed")
	await _clear_near(12.0, 90.0)

func _doors() -> void:
	_mark("the hall doors: barred from the inside")
	var gate := _gate()
	check(gate != null and gate.is_visible_in_tree() and not gate._is_open(), "the doors are shut in RIME")
	if gate == null:
		return
	var out := gate.global_position + gate.global_transform.basis.z * 1.3
	check(out.x < gate.global_position.x, "the barred face is the porch side")
	await _go(out, true, 3)
	await _walk_to(out, 240, 0.5, true)
	await _settle()
	var it := player.nearest_interactable()
	check(it != null and it.prompt == "Barred from the inside", "the prompt: Barred from the inside (%s)" % (it.prompt if it != null else "nothing"))
	toasts.clear()
	player.try_interact()
	await ticks(6)
	check(toasts.has("Barred from the inside.") and not World.area_flag(aid, "gate_hall_doors"), "they refuse (%s)" % str(toasts))
	await _shot("doors_barred")
	var round := _long_path(player.global_position, HALL_IN)
	check(round.size() > 1 and not _passes(round, DOOR, 1.2), "no way through them on the navmesh")
	print("  (the way to the Long Table from the porch: %.0f m, ends %s)" % [_path_len(round),
		str(round[round.size() - 1].snapped(Vector3.ONE * 0.1)) if round.size() > 0 else "nowhere"])
	var before := player.global_position
	await _walk_to(DOOR + Vector3(2.0, 0, 0), 150, 0.8, false)
	check(player.global_position.x < DOOR.x, "and no way through them on foot (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	await _walk_to(before, 150, 0.8, false)
	check(await _take_alive("tarn_horn", "Take the guest's horn"), "a guest's horn on the porch")
	await _clear_near(10.0, 60.0)

func _byres() -> void:
	_mark("round by the Byres")
	var yard := Game.find_hearth("hs_byres").respawn_point()
	var round := _long_path(player.global_position, yard)
	check(round.size() > 1 and _flat(round[round.size() - 1], yard) < 2.5, "a way round the hall to the byre yard")
	check(await _go(yard, true, 5), "the Bearer fights round to the Byres (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _wake_up()
	check(await _rest("hs_byres", "rest"), "the Byres hearth is kept")
	check(_hearth_lit("hs_byres") and World.last_hearth.get("hearth", "") == "hs_byres", "the Byres is the anchor")
	check(hud.last_title == "THE BYRES" or cards.has("THE BYRES"), "THE BYRES was named")
	# the rest brought the yard back: the guest on its barrel, the champion
	# at the door, and the two in the byre hear it
	await _clear_near(12.0, 120.0)
	check(await _take_alive("barrel_head", "Prise off the barrel head"), "the fish-barrel head, half off")
	check(_has("item_barrel_head"), "in the Pack")
	var mouth := _veil().global_position + Vector3(3.0, 0, 0) if _veil() != null else HALL_IN
	var p_in := _long_path(player.global_position, mouth)
	check(p_in.size() > 1 and _flat(p_in[p_in.size() - 1], mouth) < 2.5 and _passes(p_in, BYRE_DOOR, 2.5), "in at the cattle door")
	check(await _take_alive("feast_cleaver", "Take the carving cleaver"), "the Host's carving cleaver, on the block")
	check(_has("feast_cleaver") and not DB.weapon("feast_cleaver").is_empty(), "a weapon in the Pack")
	await _clear_near(12.0, 90.0)
	check(await _take_alive("byre_cache", "Pry up"), "what the byre floor holds")
	await _clear_near(12.0, 90.0)
	check(not player.dead and _standing().filter(func(e): return (e as Enemy).id == "cupbearer").is_empty(), "both Cupbearers are down")
	await _shot("byre_rime")

var _veil_node: FrostVeil = null
func _host() -> bool:
	_mark("the frost veil")
	_veil_node = _veil(Vector3(218.0, 24.3, -329.0))
	check(_veil_node != null and _veil_node.is_visible_in_tree(), "a veil across the door through to the hall")
	if _veil_node == null:
		return false
	var parted := false
	for i in 4:
		await _wake_up()
		parted = await _part_veil(_veil_node, true)
		if parted:
			break
	check(parted and Game.arena_locked, "the veil seals at the Bearer's back")
	if not parted:
		return false
	await _until(func(): return hud.last_title == "THE LONG TABLE", 3.0)
	var host := _foe("host") as Host
	check(host != null and not host.stood and host.state == Enemy.ES.IDLE and host.vis.current_clip() == "pour_horn",
		"the Host walks the table filling horns; he does not look up")
	check(not hud.boss_root.visible, "no bar yet")
	await _shot("host_pouring")

	_mark("the Host")
	var each := func(boss: Enemy) -> void:
		await _host_each(boss)
	_dueling = true
	var r: Dictionary = await _duel("host", _veil_node, _mult, 900.0, each)
	_dueling = false
	var boss: Enemy = r["boss"]
	check(bar_seen, "within 7 m he sets the horn down and turns; the bar: THE HOST")
	check(boss != null and boss.dead, "the Host is released (falls along the way: %d)" % int(r["deaths"]))
	check(r["phases"].has(2) and r["phases"].has(3), "his AI ran all three phases (%s)" % str(r["phases"].keys()))
	check(guests_seen >= 1, "guests stood up out of their seats for him (%d at once)" % guests_seen)
	print("  (pins under the table edge: %d; pools open at once: %d; rolls through the fist: %d; ticks spent leaving the frost: %d; lowest health %.0f%%)" % [pins_seen, pools_seen, rolls, frost_fled, hp_low * 100.0])
	return boss != null and boss.dead

func _release() -> void:
	_mark("the release")
	await _secs(1.0)
	var host: Host = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Host and is_instance_valid(e):
			host = e
	check(World.flag("ks_host_released") and World.is_cleared(aid), "ks_host_released; Tarnhall is cleared")
	check(String(AudioDirector._active_music).ends_with("outsong.ogg"), "the Outsong is sung (%s)" % AudioDirector._active_music)
	check(hud.last_title == "THE HOST — RELEASED" and cards.has("THE HOST — RELEASED"), "the quiet card (%s)" % hud.last_title)
	await _shot("release_card")
	check(not Game.arena_locked, "the veil falls")
	check(_veil_node != null and _veil_node._seal.collision_layer == 0, "and no longer stops the way")
	check(not hud.boss_root.visible, "the bar is put away")
	check(host != null and host.released and host.vis.current_clip() == String(host.cfg.get("release_anim", "host_sit")),
		"he sets the horn down and sits (%s)" % (host.vis.current_clip() if host != null else "gone"))
	check(_awake_foes().filter(_in_hall).is_empty(), "nobody in the hall stands against the Bearer")
	var gate := _gate()
	check(World.area_flag(aid, "gate_hall_doors"), "the bar lifts: gate_hall_doors")
	check(gate != null and gate._is_open() and (gate.get_node("GateBody") as StaticBody3D).collision_layer == 0, "the doors stand open")
	await _secs(1.5)
	check(gate != null and absf(gate._leaves[0].rotation.y) > deg_to_rad(80.0), "the leaves have swung back")
	var cup := _pickup("host_cup")
	check(cup != null and host != null and _flat(cup.global_position, host.global_position) < 3.6, "his cup is left beside him")
	check(cup != null and _on_navmesh(cup.global_position, 1.3), "on floor the Bearer can stand on (%s)" % (str(cup.global_position.snapped(Vector3.ONE * 0.1)) if cup != null else "-"))
	check(await _take("host_cup", "Take the Host's cup", false), "the prompt: Take the Host's cup")
	check(_has("item_host_cup"), "the Host's Cup is in the Pack")
	var lt := Game.find_hearth("hs_long_table")
	check(lt != null, "the Long Table hearth wakes at the cold fire")
	var rest := await _rest_ui_at("hs_long_table")
	check(rest != null and _option_index(rest, "toggle") >= 0 and _option_index(rest, "rest") >= 0,
		"it can be rested at, and offers to turn the memory")
	if rest != null:
		check(rest.info_label.text.begins_with("The holdfast rests."), "the hearth knows he rests (%s)" % rest.info_label.text)
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.4)
		await _until(func(): return player.input_enabled, 6.0)
	check(_hearth_lit("hs_long_table") and World.last_hearth.get("hearth", "") == "hs_long_table" and World.get_area_state(aid) == RH.WState.RIME,
		"lit and kept; still RIME")
	check(_foe("host") == null, "he does not stand again")
	check(_seated().is_empty(), "and a rest does not seat his guests again (%d)" % _seated().size())
	await _shot("long_table_hearth")

	_mark("the stick and the tally")
	check(await _take("ottar_staff", "Take the walking stick", false), "Ottar's stick, leaning inside the door")
	check(_has("item_ottar_staff") and World.flag("ks_ottar_staff_found") and _journal("ottar_stick") == _expected("ottar_stick", 2),
		"found: two lines for Ottar")
	var tally := _pickup("guest_tally")
	check(tally != null and tally.is_visible_in_tree(), "the guest-tally can be untied now")
	check(await _take("guest_tally", "Untie the guest-tally", false), "untied from the door-post")
	check(_has("item_guest_tally") and World.flag("ks_guest_tally_found") and _journal("guest_tally") == _expected("guest_tally", 3),
		"found: three lines for the guest-tally")

	_mark("the short way: out at the front doors")
	await _until(func(): return _passes(_long_path(lt.respawn_point(), PORCH), DOOR, 1.2), 10.0)
	var short := _long_path(lt.respawn_point(), Game.find_hearth("hs_tarn_causeway").respawn_point())
	var by_byres := _path_len(_long_path(lt.respawn_point(), BYRE_DOOR)) + _path_len(_long_path(BYRE_DOOR, Game.find_hearth("hs_tarn_causeway").respawn_point()))
	check(short.size() > 1 and _passes(short, DOOR, 1.2), "the way to the causeway hearth runs through the doors now")
	check(_path_len(short) < by_byres - 20.0, "and is the short way (%.0f m, against %.0f m round by the Byres)" % [_path_len(short), by_byres])
	await _go(HALL_IN, false, 2)
	var t0 := Engine.get_physics_frames()
	await _walk_to(DOOR + Vector3(1.2, 0, 0), 300, 0.5, true)   # square to the doorway, then out
	var walked := await _walk_to(PORCH, 600, 1.0, true)
	check(walked and player.global_position.x < DOOR.x - 1.5, "the Bearer walks out through them onto the porch (%s, %d ticks)" % [
		str(player.global_position.snapped(Vector3.ONE * 0.1)), Engine.get_physics_frames() - t0])
	if not walked:
		for e in _awake_foes():
			if _flat((e as Enemy).global_position, player.global_position) < 20.0:
				print("  (near: %s at %s, state %d)" % [(e as Enemy).id, str((e as Enemy).global_position.snapped(Vector3.ONE * 0.1)), (e as Enemy).state])
	await _shot("doors_open")
	await _clear_near(10.0, 60.0)
	check(await _go(BRIDGE + Vector3(4.0, 0, 0.6), true, 4), "to the plank bridge, where the Hall-champion stands square to it")
	await _clear_near(12.0, 120.0)
	check(World.area_flag(aid, "slain_champion_bridge"), "the champion of the bridge is put down, once and for good")
	check(await _go(Game.find_hearth("hs_tarn_causeway").respawn_point(), true, 4), "and back over the bridge to the causeway hearth")

func _after_release() -> void:
	_mark("the feast again, the doors open")
	await _wake_up()
	check(await _rest("hs_tarn_causeway", "toggle"), "the Tarn Causeway turns the memory")
	check(World.get_area_state(aid) == RH.WState.THAW, "warmed: THAW")
	check(_all_foes().is_empty(), "no enemies; the Host is not seen")
	check(not _on_navmesh(TARN), "the tarn is open water again")
	check(await _go(HALL_IN, false, 2, 9000), "in over the causeway at the front doors")
	check(Game.find_hearth("hs_long_table") != null, "the Long Table hearth burns in THAW too")
	var ui := await _talk("ottar")
	check(ui != null, "Ottar, just inside the door")
	if ui != null:
		var o1: Array = await _lines_of(ui)
		check(o1 == ["That's my stick. Where was that? I left it by the door.", "Well. I'll sit for the end of the song, then."],
			"he takes his stick and wonders where it was (%s)" % str(o1.slice(0, 1)))
		await _leave(ui)
	check(World.flag("ks_ottar_staff") and not _has("item_ottar_staff"), "the stick is his again")
	check(toasts.has("Ottar takes his stick."), "and the game says so")
	check(not World.flag("ks_ottar_air") and _journal("ottar_stick") == _expected("ottar_stick", 3), "the doors wait for the next talk")
	ui = await _talk("ottar")
	check(ui != null, "Ottar, a second time")
	if ui != null:
		var o2: Array = await _lines_of(ui)
		check(o2 == ["Who's opened the doors? Feel that. You can smell the tarn."], "then he feels the air (%s)" % str(o2))
		await _leave(ui)
	check(World.flag("ks_ottar_air") and _journal("ottar_stick") == _expected("ottar_stick", 4) and _journal("ottar_stick").size() == 4,
		"Ottar's stick: four lines, in order")
	ui = await _talk("lusse")
	check(ui != null, "Lusse, by the fire")
	if ui != null:
		var l1: Array = await _lines_of(ui)
		check(l1 == ["Forty-one. Forty-two. Hold it still. Forty-one.", "From the goat, then. From the start. Everybody."],
			"she counts the tally twice and starts the song again (%s)" % str(l1.slice(0, 1)))
		var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(ids.has("buy_long_note"), "the Long Note is still to be learned")
		var w0 := Game.warmth
		if ids.has("buy_long_note") and w0 >= 300:
			ui.choose(ids.find("buy_long_note"))
			await ticks(4)
			check(_has("long_note") and Game.warmth == w0 - 300 and ui.text_label.text.begins_with("From the belly."),
				"learned for 300 warmth (%s)" % ui.text_label.text)
		await _shot("lusse_tally")
		await _leave(ui)
	check(World.flag("ks_guest_tally") and not _has("item_guest_tally"), "the tally is hers")
	check(toasts.has("Lusse takes the tally."), "and the game says so")
	check(_journal("guest_tally") == _expected("guest_tally", 4) and _journal("guest_tally").size() == 4, "the guest-tally: four lines, in order")
	check(_ui("DialogueUI") == null and player.input_enabled, "control is back")

func _last_rest() -> void:
	_mark("turning freely, and the last rest at the Byres")
	check(await _rest("hs_long_table", "toggle"), "the Long Table turns the memory")
	check(World.get_area_state(aid) == RH.WState.RIME, "stilled again: RIME")
	check(_foe("host") == null and _seated().is_empty(), "he does not come back, and the benches are empty")
	check(_gate() != null and _gate()._is_open() and (_gate().get_node("GateBody") as StaticBody3D).collision_layer == 0,
		"the doors stay open")
	var veil := _veil()
	check(veil == null or (veil._seal.collision_layer == 0 and not veil._plane.visible), "the veil stays down")
	# through the door the veil hung in, hall to byre, on foot
	var yard := Game.find_hearth("hs_byres").respawn_point()
	check(await _through_byre_door(), "RIME: the Bearer walks through the door the veil hung in, into the byre (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(await _go(yard, true, 3), "out at the cattle door to the yard")
	await _clear_near(10.0, 60.0)
	await _wake_up()
	check(await _rest("hs_byres", "toggle"), "the last rest, at the Byres: the memory warmed")
	check(World.last_hearth == {"area": aid, "hearth": "hs_byres"} and World.get_area_state(aid) == RH.WState.THAW,
		"the Byres is kept, Tarnhall warm")
	check(_all_foes().is_empty(), "nobody frost-taken in the feast")
	var wood := _portal_to("thornwold")
	check(wood != null and _reaches(player.global_position, wood.global_position, 4.0), "the drove-road to Thornwold lies open from here")
	await _shot("byres_end")

func _after_load() -> void:
	for h in ["hs_tarn_steps", "hs_tarn_causeway", "hs_byres", "hs_long_table"]:
		check(_hearth_lit(h) and Game.find_hearth(h) != null, "%s stands and is lit" % h)
	check(World.area_flag(aid, "gate_hall_doors"), "the hall doors stay unbarred")
	check(World.flag("ks_host_released") and World.is_cleared(aid), "the Host stays released")
	check(World.get_area_state(aid) == RH.WState.THAW and _all_foes().is_empty(), "the feast, and nobody frost-taken")
	check(_has("item_host_cup") and _has("item_barrel_head") and _has("feast_cleaver") and _has("goat_song"),
		"the cup, the barrel head, the cleaver and the Goat Song are in the Pack")
	check(not _has("item_ottar_staff") and not _has("item_guest_tally"), "the stick and the tally stay given")
	check(_journal("guest_tally").size() == 4 and _journal("ottar_stick").size() == 4, "both threads whole")
	check(_npc("lusse") != null and _npc("ottar") != null, "Lusse and Ottar keep the hall")
	check(World.is_cleared("kettle_fjord") and World.is_cleared("lowe_barrows") and World.is_cleared("saltfell_steading"),
		"the regions behind stay released")
