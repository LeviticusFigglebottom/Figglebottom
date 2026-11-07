extends TestBase
## The Warmth death loop: kill reward, drop at death site, one-chance
## recovery, replacement on second death, hearth respawns enemies, and the
## land's own stakes: hard landings hurt, a ravine kills (HazardVolume).

var area: Area
var player: Player
var spawner: Spawner
var hearth: Hearthstone

func _ready() -> void:
	_run.call_deferred()

func _build_world() -> void:
	area = Area.new()
	area.area_id = "dl_test"
	add_child(area)
	Game.register_area(area, "dl_test")
	for i in range(4):
		for j in range(4):
			var f := KitLib.instance("floor_4x4")
			f.position = Vector3(i * 4 - 6, 0, j * 4 - 6)
			KitLib.add_collision(f, RH.L_WORLD_BASE)
			area.attach(f, "base")
	area.bake_navmeshes()
	World.set_area_state("dl_test", RH.WState.RIME)
	StateDirector.snap(area, RH.WState.RIME)

	hearth = Hearthstone.new()
	hearth.hearth_id = "dl_hearth"
	hearth.area = area
	area.base.add_child(hearth)
	hearth.position = Vector3(6, 0, 6)
	World.last_hearth = {"area": "dl_test", "hearth": "dl_hearth"}

	spawner = Spawner.new()
	spawner.enemy_id = "rimewalker"
	area.rime_layer.add_child(spawner)
	spawner.position = Vector3(-6, 0.1, -6)

	player = Player.new()
	add_child(player)
	player.position = Vector3(2, 0.15, 2)
	player.sim_active = true
	add_child(HUD.new())

func _run() -> void:
	_build_world()
	await ticks(10)

	print("== kill grants warmth")
	var e: Enemy = spawner.current
	check(e != null and not e.dead, "rimewalker spawned")
	Game.set_warmth(0)
	# hit it until dead with direct packets (combat mechanics already covered)
	while not e.dead:
		e.take_hit(DamagePacket.new(30, 10, player))
		await ticks(2)
	check(e.dead, "rimewalker dies")
	check(Game.warmth == 21, "warmth granted on kill (21, got %d)" % Game.warmth)

	print("== aggro: fresh spawn hunts the player")
	get_tree().call_group(RH.GROUP_RESPAWN_ON_REST, "respawn")
	await ticks(3)
	e = spawner.current
	check(e != null and not e.dead, "respawned by hearth call")
	player.global_position = e.global_position + Vector3(2.2, 0.1, 0)
	await ticks(50)
	check(e.state != Enemy.ES.IDLE, "enemy noticed the player")
	var hp0 := player.hp
	var waited := 0
	while player.hp >= hp0 and waited < 420:
		waited += 10
		await ticks(10)
	check(player.hp < hp0, "enemy attacks landed after %d ticks (hp %.0f -> %.0f, state %d)" % [waited, hp0, player.hp, e.state])

	print("== death drops a breathmark, respawn at hearth")
	player.global_position = Vector3(-4, 0.15, 4)
	await ticks(2)
	var death_pos := player.global_position
	Game.set_warmth(40)
	player.take_hit(DamagePacket.new(9999, 0, null))
	check(player.dead, "player dies")
	await ticks(15)
	check(Game.warmth == 0, "warmth dropped on death")
	check(World.breathmark != null and int(World.breathmark["amount"]) == 40, "breathmark holds 40")
	# wait out the respawn delay
	await ticks(200)
	check(not player.dead, "player respawned")
	check(player.global_position.distance_to(hearth.global_position) < 4.0, "respawned at the hearth")
	check(Game._breathmark_node != null, "breathmark wisp exists in world")
	check(Game._breathmark_node.global_position.distance_to(death_pos) < 1.5, "wisp at death site")

	print("== second death replaces the drop (first is lost)")
	Game.set_warmth(30)
	player.global_position = Vector3(5, 0.15, -5)
	await ticks(2)
	var second_pos := player.global_position
	player.take_hit(DamagePacket.new(9999, 0, null))
	await ticks(220)
	check(World.breathmark != null and int(World.breathmark["amount"]) == 30, "breathmark replaced with 30 (40 lost)")
	check(Game._breathmark_node.global_position.distance_to(second_pos) < 1.5, "wisp moved to new site")

	print("== reclaim returns the warmth")
	var before := Game.warmth
	player.global_position = Game._breathmark_node.global_position + Vector3(0.5, 0.1, 0.5)
	await ticks(5)
	check(player.try_interact(), "interact reaches the wisp")
	await ticks(5)
	check(Game.warmth == before + 30, "warmth reclaimed")
	check(World.breathmark == null, "world drop cleared")

	print("== hearth: heals, respawns enemies")
	e = spawner.current
	while e != null and not e.dead:
		e.take_hit(DamagePacket.new(50, 10, player))
		await ticks(1)
	player.hp = 20
	Game.hearth_flow(hearth, player)
	await ticks(260)
	check(player.hp == player.max_hp, "hearth heals to full")
	check(spawner.current != null and not spawner.current.dead, "hearth raises the dead again")
	check(not StateDirector.transitioning, "no state flip (uncleared rime stays rime)")
	check(World.get_area_state("dl_test") == RH.WState.RIME, "area still rime")

	print("== the land's stakes: fall and ravine volumes")
	var fall := HazardVolume.new()
	fall.kind = "fall"
	fall.size = Vector3(16, 30, 16)
	fall.position = Vector3(0, 14, 0)
	area.attach(fall, "base")
	var ravine := HazardVolume.new()
	ravine.kind = "kill"
	ravine.size = Vector3(6, 4, 6)
	ravine.position = Vector3(16, -6, 0)
	area.attach(ravine, "base")
	await ticks(4)
	player.invulnerable = true    # foes can't touch the Bearer; the land still can
	player.hp = player.max_hp
	player.global_position = Vector3(-3, 1.2, -3)
	player.velocity = Vector3.ZERO
	await ticks(40)
	check(player.hp == player.max_hp, "stepping down a metre costs nothing")
	player.global_position = Vector3(-3, 8.0, -3)
	player.velocity = Vector3.ZERO
	await ticks(90)
	check(player.hp < player.max_hp * 0.8 and not player.dead,
		"an 8 m drop onto rock hurts (hp %.0f / %.0f)" % [player.hp, player.max_hp])
	player.hp = player.max_hp
	player.global_position = Vector3(16, 2.0, 0)
	player.velocity = Vector3.ZERO
	await ticks(60)
	check(player.dead or player.hp <= 0.0, "the ravine takes the Bearer")
	await ticks(220)
	check(not player.dead and player.global_position.distance_to(hearth.global_position) < 4.0,
		"and the hearth gives them back")
	player.invulnerable = false

	finish()
