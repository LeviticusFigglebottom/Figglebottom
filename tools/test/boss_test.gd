extends TestBase
## The Netmender (the Saltfell Holdfast), in the Longhouse on the shelf: frost veil engagement, phases, clear-unlock,
## free toggling with persistence — the back half of the core loop.

var area: Area
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	World.reset()
	World.set_area_state("saltfell_steading", RH.WState.RIME)
	area = AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	player = Player.new()
	add_child(player)
	player.global_position = Vector3(0, 22.3, -15.0)
	player.sim_active = true
	add_child(HUD.new())
	StateDirector.snap(area, RH.WState.RIME)
	World.last_hearth = {"area": "saltfell_steading", "hearth": "hs_salt_house"}
	await ticks(25)

	print("== the frost veil")
	var fog: FrostVeil = null
	var stack: Array[Node] = [area.rime_layer]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is FrostVeil:
			fog = n
		for c in n.get_children():
			stack.append(c)
	check(fog != null, "frost veil stands in the rime")
	check(fog.boss_spawner != null and fog.boss_spawner.current != null, "holdfast bound to the gate")
	var boss: Enemy = fog.boss_spawner.current
	check(boss.cfg.get("is_boss", false) and boss.id == "netmender", "it is the Netmender")
	check(boss.state == Enemy.ES.IDLE, "she keeps mending, undisturbed, before the veil is parted")

	player.global_position = Vector3(0, 22.3, -18.6)
	await ticks(6)
	var it := player.nearest_interactable()
	check(it != null and it.prompt == "Part the frost veil", "the veil offers passage")
	it.activate(player)
	await ticks(80)
	check(boss.target == player, "the holdfast wakes")
	check(fog._seal.collision_layer != 0, "the veil seals at your back")

	print("== he fights; the maul breaks poise")
	var hp0 := player.hp
	var waited := 0
	while player.hp >= hp0 and waited < 900:
		waited += 10
		await ticks(10)
	check(player.hp < hp0, "the maul lands (hp %.0f -> %.0f after %d ticks; boss at %s, Bearer at %s)" % [hp0, player.hp, waited,
		str(boss.global_position.snapped(Vector3.ONE * 0.1)), str(player.global_position.snapped(Vector3.ONE * 0.1))])

	print("== death mid-fight re-arms the veil (the arena can be re-entered)")
	var old_id := boss.get_instance_id()
	player.take_hit(DamagePacket.new(99999, 0, boss))
	var wd := 0
	while wd < 600 and (player.dead or fog.boss_spawner.current == null
			or not is_instance_valid(fog.boss_spawner.current)
			or fog.boss_spawner.current.get_instance_id() == old_id):
		wd += 10
		await ticks(10)
	check(not player.dead, "the Bearer stands again at the hearth")
	check(String(AudioDirector._active_music).ends_with("theme_rime.wav"),
		"the boss theme yields back to the world's")
	boss = fog.boss_spawner.current
	check(boss != null and boss.get_instance_id() != old_id and not boss.dead,
		"the holdfast is restored whole")
	check(not fog._engaged and fog._zone.enabled, "the veil stands ready to be parted again")
	check(fog._seal.collision_layer != 0, "and still bars simply walking through")
	player.global_position = Vector3(0, 22.3, -18.6)
	await ticks(6)
	it = player.nearest_interactable()
	check(it != null and it.prompt == "Part the frost veil", "the veil offers passage anew")
	it.activate(player)
	await ticks(80)
	check(boss.target == player, "the holdfast wakes a second time")

	print("== phase two at half might")
	boss.take_hit(DamagePacket.new(boss.max_hp * 0.5, 0, player))
	await ticks(5)
	check(boss.phase == 2, "the Holdfast is enraged")

	print("== the holdfast rests")
	var warmth0 := Game.warmth
	while not boss.dead:
		boss.take_hit(DamagePacket.new(160, 0, player))
		await ticks(2)
	await ticks(30)
	check(World.is_cleared("saltfell_steading"), "Saltfell is cleared")
	check(Game.warmth - warmth0 >= 1200, "his hoard of warmth passes on (%d)" % (Game.warmth - warmth0))
	check(fog._seal.collision_layer == 0, "the veil disperses")

	print("== free toggling, persisted")
	var hearth := Game.find_hearth("hs_salt_house")
	player.global_position = hearth.respawn_point()
	await ticks(4)
	Game.hearth_flow(hearth, player, "toggle")
	var w2 := 0
	while not StateDirector.transitioning and w2 < 300:
		w2 += 5
		await ticks(5)
	while StateDirector.transitioning and w2 < 1500:
		w2 += 10
		await ticks(10)
	check(World.get_area_state("saltfell_steading") == RH.WState.THAW, "the memory warms again")
	# and back
	Game.hearth_flow(hearth, player, "toggle")
	w2 = 0
	while not StateDirector.transitioning and w2 < 300:
		w2 += 5
		await ticks(5)
	while StateDirector.transitioning and w2 < 1500:
		w2 += 10
		await ticks(10)
	check(World.get_area_state("saltfell_steading") == RH.WState.RIME, "and stills at will")

	print("== save round-trip")
	World.save_game()
	var st := World.get_area_state("saltfell_steading")
	var cleared := World.is_cleared("saltfell_steading")
	World.reset()
	check(World.load_game(), "save reloads")
	check(World.get_area_state("saltfell_steading") == st, "state persisted")
	check(World.is_cleared("saltfell_steading") == cleared, "cleared persisted")
	check(World.area_flag("saltfell_steading", "slain_netmender"), "the Netmender stays at rest")

	finish()
