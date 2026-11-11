class_name PoiBase
extends TestBase
## Shared by the points-of-interest suites (poi_<region>, docs/lore/POI.md):
## build one region, walk a steered Bearer to each place on the navmesh, and
## use what is there the way a player does (the interact scan, the prompt).
## The frost-taken are cleared first: these suites test the places, and the
## encounter suites test the fights.

var area: Area
var player: Player
var hud: HUD
var area_id := ""
var _lore: Array = []
var _heard: Array = []

func setup(id: String) -> void:
	area_id = id
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	hud = HUD.new()
	add_child(hud)
	Game.lore_panel.connect(func(t): _lore.append(String(t)))
	StateDirector.snap(area, RH.WState.THAW)
	await ticks(20)
	var nwait := 0
	var a := player.global_position
	while _path(a, a + Vector3(6, 0, 6)).size() < 2 and nwait < 1200:
		await ticks(10)
		nwait += 10

func turn(state: RH.WState) -> void:
	StateDirector.snap(area, state)
	await ticks(6)
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		e.queue_free()
	await ticks(30)     # the other state's navmesh takes the map

func ground(x: float, z: float) -> Vector3:
	return Vector3(x, area.terrain.height_at(x, z), z)

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := area.get_world_3d().navigation_map
	var a := NavigationServer3D.map_get_closest_point(map, from)
	var b := NavigationServer3D.map_get_closest_point(map, to)
	return NavigationServer3D.map_get_path(map, a, b, true)

func reaches(from: Vector3, to: Vector3, tol := 2.5) -> bool:
	var p := _path(from, to)
	return p.size() > 1 and Vector2(p[p.size() - 1].x - to.x, p[p.size() - 1].z - to.z).length() < tol

var _stuck_from := Vector3.ZERO
var _stuck_n := 0
var _side := 1.0

func walk_to(to: Vector3, max_ticks := 900, tol := 1.0) -> bool:
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
		if player.global_position.distance_to(_stuck_from) > 0.25:
			_stuck_from = player.global_position
			_stuck_n = 0
		else:
			_stuck_n += 2
			if _stuck_n > 24:
				_side = -_side
				player.sim_move = Vector3(_side, 0, 0.2)
				await ticks(30)
				waited += 30
				_stuck_n = 0
	player.sim_move = Vector3.ZERO
	return false

func walk_path(to: Vector3, max_ticks := 5400, tol := 0.9) -> bool:
	var p := _path(player.global_position, to)
	if p.size() < 2:
		return player.global_position.distance_to(to) < 1.5
	var used := 0
	for k in range(1, p.size()):
		var t0 := Engine.get_physics_frames()
		var ok: bool = await walk_to(p[k], max_ticks - used, 0.6 if k < p.size() - 1 else tol)
		used += int(Engine.get_physics_frames() - t0)
		if not ok:
			return false
	return true

## Stand somewhere without the walk (a new leg of the test starts here).
func stand(at: Vector3) -> void:
	player.sim_move = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.global_position = at + Vector3(0, 0.3, 0)
	await ticks(20)

func pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id and (p as Node3D).is_visible_in_tree():
			return p
	return null

func npc(id: String) -> NPC:
	for n in area.find_children("*", "NPC", true, false):
		if (n as NPC).npc_id == id and (n as Node3D).is_visible_in_tree() and not n.is_queued_for_deletion():
			return n
	return null

func plaque(text_starts: String) -> LorePlaque:
	for p in area.find_children("*", "LorePlaque", true, false):
		if (p as LorePlaque).text.begins_with(text_starts) and (p as Node3D).is_visible_in_tree():
			return p
	return null

func prop(kit: String, tag := "") -> Node3D:
	for n in area.find_children(kit + "*", "Node3D", true, false):
		if String(n.get_meta("kit_id", "")) == kit and (n as Node3D).is_visible_in_tree():
			if tag == "" or _layer_of(n) == tag:
				return n
	return null

func _layer_of(n: Node) -> String:
	var cur := n
	while cur != null and cur != area:
		if cur == area.thaw_layer:
			return "thaw"
		if cur == area.rime_layer:
			return "rime"
		cur = cur.get_parent()
	return "base"

## Walk to a spot and use whatever offers the prompt. True when it was used.
func use_at(at: Vector3, prompt_prefix: String, tol := 0.8) -> bool:
	await walk_path(at, 5400, tol)
	await walk_to(at, 240, tol)
	for attempt in 4:
		var n := 0
		while (player.state != Player.S.MOVE or player._interact_suppress > 0) and n < 180:
			await ticks(2)
			n += 2
		await ticks(3)
		var it := player.nearest_interactable()
		if it != null and it.prompt.begins_with(prompt_prefix):
			return player.try_interact()
		print("  (use '%s', try %d: nearest %s, %.1f m from the spot)" % [prompt_prefix, attempt + 1,
			it.prompt if it != null else "nothing", player.global_position.distance_to(at)])
		_side = -_side
		player.sim_move = Vector3(_side, 0, 0.3)
		await ticks(24)
		player.sim_move = Vector3.ZERO
		await walk_to(at, 200, tol * 0.7)
	return false

func take(id: String) -> bool:
	var p := pickup(id)
	if p == null:
		return false
	var label := p.label
	var ok: bool = await use_at(p.global_position, label)
	await ticks(4)
	return ok

func read(pl: LorePlaque) -> String:
	if pl == null:
		return ""
	_lore.clear()
	# stand before the board, not on its post
	var front := pl.global_position + pl.global_transform.basis.z * 1.0
	var ok: bool = await use_at(front, "Read", 0.6)
	await ticks(6)
	hud.lore_root.visible = false
	hud.lore_root.remove_from_group("lore_open")
	player.lock_control(false)
	await ticks(10)
	return String(_lore[0]) if ok and not _lore.is_empty() else ""

func _ui(cls: String) -> Node:
	for c in get_tree().root.get_children():
		if c.get_script() != null and (c.get_script() as Script).get_global_name() == cls:
			return c
	return null

func _act(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_tree().root.push_input(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_tree().root.push_input(up)

## Walk up to a soul, talk, and return every line said before the menu.
func talk(npc_id: String) -> Array:
	var n := npc(npc_id)
	if n == null:
		return []
	var ok: bool = await use_at(n.global_position, "Speak with", 1.6)
	await ticks(4)
	var ui := _ui("DialogueUI") as DialogueUI
	if not ok or ui == null:
		return []
	var out := []
	var guard := 0
	while ui._phase == "lines" and guard < 40:
		out.append(ui.text_label.text)
		_act("interact")
		await ticks(2)
		guard += 1
	var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
	ui.choose(ids.find("leave"))
	await ticks(6)
	return out

## Stand within earshot and gather what is overheard for `secs` seconds.
func overhear(n: NPC, secs: float) -> Array:
	_heard.clear()
	var cb := func(_who, line): _heard.append(String(line))
	n.overheard.connect(cb)
	var t := 0
	while t < int(secs * 60.0):
		await ticks(10)
		t += 10
	n.overheard.disconnect(cb)
	return _heard.duplicate()

## True when `want` was heard in order somewhere in `heard` (the exchange
## loops, and the walk up to it may have caught a line or two already).
func heard_in_order(heard: Array, want: Array) -> bool:
	for i in range(0, heard.size() - want.size() + 1):
		if heard.slice(i, i + want.size()) == want:
			return true
	return false

## Walk the Bearer straight at a piece from level ground beside it. True when
## he is stopped short of its middle: the piece is solid, not a picture of one.
func solid(n: Node3D, stop := 0.4) -> bool:
	if n == null:
		return false
	var c := n.global_position
	for k in 8:
		var a := TAU * float(k) / 8.0
		var from := c + Vector3(cos(a), 0, sin(a)) * 3.4
		from.y = area.terrain.height_at(from.x, from.z)
		if absf(from.y - c.y) > 0.9:
			continue
		await stand(from)
		if Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length() > 0.6:
			continue        # something else stands there
		_stuck_n = -100000      # no sidestepping: straight at it
		var t := 0
		while t < 150:
			var d := c - player.global_position
			d.y = 0
			player.cam.yaw = atan2(-d.x, -d.z)
			player.sim_move = Vector3(0, 0, -1)
			await ticks(2)
			t += 2
		player.sim_move = Vector3.ZERO
		_stuck_n = 0
		var off := Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length()
		return off > stop
	return false

func journal(thread_id: String) -> Array:
	for t in Keepsakes.journal():
		if t["id"] == thread_id:
			return t["lines"]
	return []
