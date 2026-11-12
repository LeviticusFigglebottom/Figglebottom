extends TestBase
## Progression gates (ADR 0015). Every region's way on is shut by a real thing
## until that region's Holdfast is released. For each of the six gated regions:
##   - the area names its way on (the `way_on` block the journal and map read)
##   - shut, in THAW and in RIME: no navmesh route from the start to the seam,
##     and a capsule steered at the gate and at every metre of ground beside
##     it does not get through
##   - the release's flag turns while the Bearer stands in the area: the gate
##     opens, the capsule walks through, the navmesh joins up
##   - the open gate survives a rebuild of the area and a save and load
##   - from the far side it can be undone with no release at all (nobody set
##     down beyond a gate is shut out of the region behind it), and that
##     survives a rebuild too
## And at Saltfell the drawbridge still stands raised.

const GATES := [
	["saltfell_steading", "pass_net", "ks_netmender_released", "lowe_barrows"],
	["lowe_barrows", "kettle_sods", "ks_turfwright_released", "kettle_fjord"],
	["kettle_fjord", "steps_stack", "ks_ice_cutter_released", "tarnhall"],
	["tarnhall", "drove_gate", "ks_host_released", "thornwold"],
	["thornwold", "fell_hedge", "ks_hedgelayer_released", "shepherds_reach"],
	["shepherds_reach", "upwater_hurdle", "ks_fellcaller_released", "coldwell"],
]

var area: Area
var player: Player
var only := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gates-only="):
			only = a.get_slice("=", 1)
	_run.call_deferred()

func _build(aid: String) -> void:
	if area != null:
		area.queue_free()
		await ticks(3)
	area = AreaBuilder.build(aid)
	add_child(area)
	Game.register_area(area, aid)
	StateDirector.snap(area, World.get_area_state(aid))
	await ticks(24)       # (the navmesh bakes deferred)

func _gate(id: String) -> ShortcutGate:
	for g in area.find_children("*", "ShortcutGate", true, false):
		if g.gate_id == id:
			return g
	return null

func _body_on(g: ShortcutGate) -> bool:
	return (g.get_node("GateBody") as StaticBody3D).collision_layer != 0

func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, area.terrain.height_at(p.x, p.z) + 0.25, p.z)

func _route(from: Vector3, to: Vector3) -> bool:
	var map := area.get_world_3d().navigation_map
	var p := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, from),
		NavigationServer3D.map_get_closest_point(map, to), true)
	return p.size() > 1 and p[p.size() - 1].distance_to(to) < 2.5

## Steer the capsule from the near side straight at the gate line, `along`
## metres from the middle of the opening. True if he ends up beyond it.
func _push_through(g: ShortcutGate, along: float, max_ticks := 80) -> bool:
	var x := g.global_transform.basis.x.normalized()
	var z := g.global_transform.basis.z.normalized()     # +z is the near (shut) side
	player.global_position = _ground(g.global_position + x * along + z * 2.4)
	player.velocity = Vector3.ZERO
	await ticks(6)
	var t := 0
	while t < max_ticks:
		player.cam.yaw = atan2(z.x, z.z)       # walk along -z
		player.sim_move = Vector3(0, 0, -1)
		await ticks(2)
		t += 2
		if g.to_local(player.global_position).z < -1.2:
			player.sim_move = Vector3.ZERO
			return true
	player.sim_move = Vector3.ZERO
	return false

func _holds(g: ShortcutGate, span: Array, label: String) -> void:
	var through := []
	var a := float(span[0]) + 0.4
	while a <= float(span[1]) - 0.4:
		if await _push_through(g, a):
			through.append(snappedf(a, 0.1))
		a += 1.0
	check(through.is_empty(), "%s: nothing gets past at any metre of the neck (%s)" % [label, str(through)])

func _run() -> void:
	World._save_dir = "user://test_gates"
	for row in GATES:
		var aid: String = row[0]
		var gid: String = row[1]
		var flag: String = row[2]
		if only != "" and only != aid:
			continue
		print("== ", aid, ": ", gid)
		World.reset()
		Game.set_warmth(0)
		await _build(aid)
		if player == null:
			player = Player.new()
			add_child(player)
			player.sim_active = true
			add_child(HUD.new())
		var def: Dictionary = area.get_meta("def")
		var start: Vector3 = AreaBuilder._v3(def["start"]["pos"])
		player.global_position = start
		var spec: Dictionary = {}
		for gs in def.get("gates", []):
			if String(gs.get("id", "")) == gid:
				spec = gs
		var ways: Array = def.get("way_on", [])
		check(ways.size() == 1 and String(ways[0]["open_flag"]) == flag and String(ways[0]["to"]) == String(row[3])
				and String(ways[0]["name"]) != "", "the area names its way on and what opens it")
		var g := _gate(gid)
		check(g != null and not spec.is_empty(), "the gate stands")
		if g == null:
			continue
		var beyond := _ground(g.global_position - g.global_transform.basis.z.normalized() * 3.0)
		var seam_p := AreaBuilder._v3(ways[0]["seam"])
		check(g.global_position.distance_to(AreaBuilder._v3(ways[0]["at"])) < 0.5, "the way on is where the gate is")
		check(_body_on(g) and g._front.enabled, "shut on a new journey")
		if aid == "saltfell_steading":
			var br: Array = area.find_children("*", "DrawBridge", true, false)
			check(br.size() == 1 and not br[0].is_down() and not br[0].operable, "the drawbridge stands raised, its windlass on the far side")
		for st in [RH.WState.THAW, RH.WState.RIME]:
			var sn := "THAW" if st == RH.WState.THAW else "RIME"
			StateDirector.snap(area, st)
			await ticks(30)
			check(not _route(start, beyond), "%s: no route from the start to the far side of the gate" % sn)
			await _holds(g, spec["span"], sn)
		# --- the release, while he stands in the region
		StateDirector.snap(area, RH.WState.RIME)
		player.global_position = start
		World.set_flag(flag)
		await ticks(120)      # the gate answers, what stood in it comes down
		await nav_wait(area)  # and the navmesh is baked again
		check(not _body_on(g) and not g._front.enabled, "the release opens it where it stands")
		check(await _push_through(g, 0.0, 160), "RIME: the Bearer walks through")
		StateDirector.snap(area, RH.WState.THAW)
		await ticks(30)
		check(await _push_through(g, 0.0, 160), "THAW: and in the other memory")
		check(_route(start, beyond) and _route(start, seam_p - (seam_p - beyond).normalized() * 2.0), "the navmesh runs from the start through the gate to the seam")
		# --- a rebuild, and a save and load
		await _build(aid)
		g = _gate(gid)
		check(g != null and not _body_on(g), "rebuilt: it is built open")
		World.save_game()
		World.reset()
		check(not World.flag(flag), "(the journey put away)")
		check(World.load_game() and World.flag(flag), "saved and loaded: the release is kept")
		await _build(aid)
		g = _gate(gid)
		check(g != null and not _body_on(g), "and the gate is open in the loaded journey")
		# --- from the far side, with no release
		World.reset()
		await _build(aid)
		g = _gate(gid)
		check(_body_on(g), "a new journey again: shut")
		for st in [RH.WState.THAW, RH.WState.RIME]:
			StateDirector.snap(area, st)
			await ticks(20)
			var far := _ground(g.global_position - g.global_transform.basis.z.normalized() * (1.4 + g.body_depth * 0.5))
			player.global_position = far
			await ticks(10)
			check(_route(far, seam_p - (seam_p - beyond).normalized() * 2.0), "%s: beyond it the ground runs on to the seam" % ("THAW" if st == RH.WState.THAW else "RIME"))
			check(g._back.enabled and far.distance_to(g._back.zone_global()) < 2.0, "and he stands in reach of its far side")
		g._back.activate(player)
		await ticks(120)
		await nav_wait(area)
		check(not _body_on(g) and World.area_flag(aid, "gate_" + gid), "undone from the far side")
		check(await _push_through(g, 0.0, 160) or g.to_local(player.global_position).z < 0.0, "the way back is open")
		player.global_position = _ground(g.global_position + g.global_transform.basis.z.normalized() * 3.0)
		await ticks(10)
		check(_route(player.global_position, start), "and it runs back to the region's start")
		await _build(aid)
		g = _gate(gid)
		check(g != null and not _body_on(g) and not World.flag(flag), "rebuilt: still open, with no release")
	World.reset()
	finish()
