extends LeftoversBase
## The Longhouse after the Netmender (SLICE.md 6: "At 0 she sits back down.
## The frost veil falls as meltwater. The long hearth catches. The mending
## needle lies where she sat."), in the real steading, through the real veil:
## the whole fight (every move, every phase, each phase change struck out of
## a half-wound move: phase three out of the Sea-weight, the sail overhead),
## the release, and then exactly what stands in the hall
##   - in RIME, straight after,
##   - warmed to THAW at the Long Hearth, and stilled to RIME again,
##   - in a save resumed (the area rebuilt from the flags).

const AREA := "saltfell_steading"

var area: Area
var fog: FrostVeil
var pen: Spawner
var boss: Netmender

func _ready() -> void:
	_run.call_deferred()

func _find_veil() -> FrostVeil:
	for n in area.find_children("*", "Node3D", true, false):
		if n is FrostVeil:
			return n
	return null

func _raise_area() -> void:
	area = AreaBuilder.build(AREA)
	add_child(area)
	Game.register_area(area, AREA)
	StateDirector.snap(area, World.get_area_state(AREA))

## The things a fight makes, counted wherever they are in the scene.
func _fight_things() -> Dictionary:
	var out := {"ridges": 0, "tells": 0, "cracks": 0, "pools": 0, "holes": 0, "holds": 0, "flights": 0}
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if not n.is_queued_for_deletion():
			if n is IceRidge: out["ridges"] += 1
			elif n is FloorTelegraph: out["tells"] += 1
			elif n is IceCrack: out["cracks"] += 1
			elif n is FrostPool: out["pools"] += 1
			elif n is BrokenIce: out["holes"] += 1
			elif n is GrabHold: out["holds"] += 1
			elif n is Projectile: out["flights"] += 1
		for c in n.get_children():
			stack.append(c)
	return out

func _none(things: Dictionary) -> bool:
	for k in things:
		if int(things[k]) != 0:
			return false
	return true

## What is in the scene that was not there when she stood, beside what the
## release leaves (the needle, the Long Hearth awake) and the foes of the
## yard a rest brings back.
func _beside_leavings(before: Dictionary) -> Array:
	var out: Array = []
	for n in _new_roots(before):
		if n is Pickup and (n as Pickup).pickup_id == "mending_needle":
			continue
		if n is Hearthstone and (n as Hearthstone).hearth_id == "hs_long_hearth":
			continue
		if n is NavigationRegion3D and (n == area.nav_thaw or n == area.nav_rime):
			continue   # (the fallen veil re-bakes the area's navmesh: its own two regions, new)
		if n is Enemy and _pen_of(n) != null and _pen_of(n).current == n:
			continue   # (a rest raises the yard's dead again: those are new)
		if _of_gate(n):
			continue   # (the way on opens with the release, ADR 0015: what it leaves is new)
		out.append(n)
	return out

## Made by a progression gate as it opened (its "open" dressing: the net's
## coil of rope where it hung), not by her.
func _of_gate(n: Node) -> bool:
	var p := n
	while p != null:
		if p is ShortcutGate:
			return true
		p = p.get_parent()
	return n.has_meta("gate_piece")

func _needles() -> int:
	var k := 0
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).item_id == "item_mending_needle" and not p.is_queued_for_deletion():
			k += 1
	return k

func _veil_down(v: FrostVeil) -> bool:
	return v._seal.collision_layer == 0 and not v._plane.visible and not v._dress.visible and not v._zone.enabled

func _turn(to: RH.WState) -> void:
	var h := Game.find_hearth("hs_long_hearth")
	player.global_position = h.respawn_point()
	await _t(4)
	Game.hearth_flow(h, player, "toggle")
	var w := 0
	while not StateDirector.transitioning and w < 400:
		w += 5
		await _t(5)
	while StateDirector.transitioning and w < 3000:
		w += 10
		await _t(10)
	await _secs(4.5)   # (the wave's own particles ride out)
	check(World.get_area_state(AREA) == to, "the hall is %s" % ("warm" if to == RH.WState.THAW else "still again"))

func _run() -> void:
	World.reset()
	World.set_area_state(AREA, RH.WState.RIME)
	_raise_area()
	player = Player.new()
	add_child(player)
	player.global_position = Vector3(0, 22.3, -15.0)
	player.sim_active = true
	player.invulnerable = true   # (holds and hauls still take him; blows do not)
	hud = HUD.new()
	add_child(hud)
	World.last_hearth = {"area": AREA, "hearth": "hs_salt_house"}
	await _t(25)
	fog = _find_veil()
	pen = fog.boss_spawner if fog != null else null
	boss = pen.current as Netmender if pen != null else null
	check(boss != null and fog != null, "the Netmender sits behind her veil")

	print("== through the veil; she stands")
	player.global_position = Vector3(0, 22.3, -18.6)
	await _t(6)
	var it := player.nearest_interactable()
	check(it != null and it.prompt == "Part the frost veil", "the veil offers passage")
	it.activate(player)
	await _secs(1.4)
	player.global_position = boss.global_position + Vector3(0, 0.2, 3.4)
	var w := 0
	while not boss.stood and w < 600:
		w += 2
		if boss.state == Enemy.ES.TRANSITION:
			boss.state_t = 99.0
		await _t(2)
	check(boss.stood and hud.boss_root.visible and Game.arena_locked, "she stands; the bar is up and the hall is sealed")
	park_off = Vector3(3.5, 0.2, 14.0)   # down the hall, off the kerb
	var before := _snapshot()

	print("== the whole fight, and the release")
	await _fight_boss(boss, 3)
	await _release(boss)
	check(boss.released, "she is released")
	player.global_position = boss.global_position + Vector3(0, 0.2, 5.0)
	await _secs(6.0)   # the veil falls, the card, the hearth catches

	print("== the Longhouse in RIME, after")
	var left := _beside_leavings(before)
	check(left.is_empty(), "nothing she made is left, on her or in the hall (%s)" % _list(left))
	var things := _fight_things()
	check(_none(things), "no ridge, tell, hold or flight anywhere (%s)" % str(things))
	check(is_instance_valid(boss) and pen.current == boss and boss.vis.is_visible_in_tree()
			and (boss.vis.current_clip() == "sit_still" or boss.vis.rig.action_clip() == "sit_still"),
		"she sits where she sat down")
	check(_needles() == 1, "one mending needle lies by her (%d)" % _needles())
	check(Game.find_hearth("hs_long_hearth") != null, "the Long Hearth is a Hearthstone")
	check(_veil_down(fog) and not Game.arena_locked, "the veil has fallen and bars nothing")
	check(not hud.boss_root.visible, "her bar is gone")
	check(player.input_enabled, "nothing holds the Bearer")
	var net: Node3D = get_tree().get_first_node_in_group("net_floor")
	check(net != null and net.is_visible_in_tree(), "the floor is still the net (RIME's own floor)")

	print("== warmed at the Long Hearth")
	await _turn(RH.WState.THAW)
	left = _beside_leavings(before)
	check(left.is_empty(), "nothing of the fight is in the warm hall (%s)" % _list(left))
	check(not boss.vis.is_visible_in_tree() and not net.is_visible_in_tree() and not fog.is_visible_in_tree(),
		"she, her net and her veil are RIME's: not in the warm hall")
	check(_needles() == 1 and (area.find_children("*", "Pickup", true, false).filter(
			func(p): return (p as Pickup).item_id == "item_mending_needle")[0] as Node3D).is_visible_in_tree(),
		"the needle is there in THAW too")

	print("== and stilled again")
	await _turn(RH.WState.RIME)
	left = _beside_leavings(before)
	things = _fight_things()
	check(left.is_empty() and _none(things), "nothing comes back with the RIME (%s; %s)" % [_list(left), str(things)])
	check(is_instance_valid(boss) and pen.current == boss and boss.released and boss.vis.is_visible_in_tree()
			and boss.state == Enemy.ES.DEAD, "she is still sat there, released: the rest did not raise her")
	check(_veil_down(fog) and not Game.arena_locked, "the veil stays down")
	check(_needles() == 1, "still one needle (%d)" % _needles())

	print("== a save resumed: the hall rebuilt from the flags")
	World.save_game()
	remove_child(area)
	area.queue_free()
	await _t(3)
	World.reset()
	check(World.load_game(), "the save loads")
	_raise_area()
	await _t(25)
	fog = _find_veil()
	pen = fog.boss_spawner
	var again: Enemy = pen.current if pen.current != null and is_instance_valid(pen.current) else null
	# (SLICE.md 6 does not say whether she is still sat there on a later
	# visit; only the Leadvoice is kept by data, release_stays. Either way:
	# never a Netmender to fight again.)
	check(again == null or again.dead, "no Netmender to fight (she is %s)" % ("not there" if again == null else "sat, released"))
	check(_veil_down(fog), "the veil is not raised again")
	check(_needles() == 1, "one needle, not two (%d)" % _needles())
	check(Game.find_hearth("hs_long_hearth") != null, "the Long Hearth is awake")
	things = _fight_things()
	check(_none(things), "and nothing of a fight (%s)" % str(things))
	Engine.time_scale = 1.0
	finish()
