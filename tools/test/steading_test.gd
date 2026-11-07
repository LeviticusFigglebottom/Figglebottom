extends TestBase
## Saltfell Steading integration: build from data, thaw-first arrival, the
## forced first rest (thaw -> rime), the rime populated, an uncleared rime
## cannot warm again, the frost veil bars the long hall, warmth from the
## rimewalkers buys one level (1 -> 2 costs 60), the bog-iron pickup.

var area: Area
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _awake_foes() -> Array:
	return get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(
			func(e): return e.can_process() and not e.dead)

func _run() -> void:
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	player = Player.new()
	add_child(player)
	var def: Dictionary = area.get_meta("def")
	player.global_position = AreaBuilder._v3(def["start"]["pos"])
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, World.get_area_state("saltfell_steading"))
	await ticks(20)

	print("== structure")
	check(World.get_area_state("saltfell_steading") == RH.WState.THAW, "first visit finds the steading in thaw")
	check(area.base.get_child_count() > 60, "base geometry built (%d nodes)" % area.base.get_child_count())
	check(area.nav_thaw != null and area.nav_rime != null, "both navmeshes baked")
	var hearth := Game.find_hearth("steading_hearth")
	check(hearth != null, "the steading hearthstone stands")
	check(_awake_foes().size() == 0, "no enemies awake in thaw")
	var npcs := area.thaw_layer.find_children("*", "NPC", true, false)
	check(npcs.size() == 1, "the steward keeps the thaw")
	check(player.is_on_floor() or player.global_position.y > -0.5, "the Bearer stands on the yard floor")

	print("== the first rest forces the rime")
	player.global_position = hearth.respawn_point()
	await ticks(4)
	Game.hearth_flow(hearth, player)
	var waited := 0
	while not StateDirector.transitioning and waited < 300:
		waited += 5
		await ticks(5)
	check(StateDirector.transitioning, "the wave begins after the kneel")
	waited = 0
	while StateDirector.transitioning and waited < 1200:
		waited += 10
		await ticks(10)
	check(World.get_area_state("saltfell_steading") == RH.WState.RIME, "the steading is rime now")
	await ticks(30)
	var foes := _awake_foes()
	var walkers := foes.filter(func(e): return e.id == "rimewalker")
	check(walkers.size() >= 4 and walkers.size() <= 6, "%d rimewalkers walk the yard" % walkers.size())
	check(foes.any(func(e): return e.cfg.get("is_boss", false)), "the holdfast keeps the long hall")
	check(World.last_hearth.get("hearth", "") == "steading_hearth", "the hearth is the respawn anchor")

	print("== uncleared rime cannot warm")
	Game.hearth_flow(hearth, player)
	var flipped := false
	for i in 24:
		await ticks(10)
		flipped = flipped or StateDirector.transitioning
	check(not flipped and World.get_area_state("saltfell_steading") == RH.WState.RIME,
			"rest only — the holdfast endures")

	print("== the frost veil bars the long hall")
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "one frost veil")
	var q := PhysicsRayQueryParameters3D.create(Vector3(0, 1.2, -27), Vector3(0, 1.2, -33), RH.M_WORLD_ALL)
	check(not area.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "the veil blocks the doorway")

	print("== warmth buys a level")
	walkers = _awake_foes().filter(func(e): return e.id == "rimewalker")
	for e in walkers:
		while not e.dead:
			e.take_hit(DamagePacket.new(40, 10, player))
			await ticks(2)
	await ticks(10)
	check(Game.warmth >= 60, "the rimewalkers give up %d warmth (>= 60)" % Game.warmth)
	var ui := RestUI.new(hearth, player)
	get_tree().root.add_child(ui)
	await ticks(2)
	check(ui._level_cost() == 60, "level 1 -> 2 costs 60")
	var w0 := Game.warmth
	ui.choose(1)          # Grow by warmth
	ui.choose(0)          # first stat (heart)
	check(player.level == 2, "the Bearer reaches level 2")
	check(Game.warmth == w0 - 60, "60 warmth spent")
	check(player.attributes["heart"] == 9, "heart rose to 9")
	ui.close()
	await ticks(2)

	print("== bog-iron on the terrace (rime)")
	player.global_position = Vector3(19.5, 1.3, 6.6)
	await ticks(8)
	check(player.try_interact(), "pried up the bog-iron")
	check(int(player.inventory.get("bog_iron", 0)) == 2, "2 bog-iron held")

	finish()
