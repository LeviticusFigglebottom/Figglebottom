extends TestBase
## Combat verification: stamina, i-frames, hits, combos, block, parry/riposte,
## gourd — against the training dummy in the arena sandbox.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena = (load("res://scenes/sandbox/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await ticks(5)
	var player: Player = arena.get_node("Player")
	var dummy: TrainingDummy = arena.get_node("Dummy")
	player.sim_active = true

	print("== roll: stamina + i-frames")
	var st0 := player.stamina
	player.sim_move = Vector3(0, 0, -1)
	player.try_roll()
	await ticks(1)
	check(player.state == Player.S.ROLL, "enters ROLL")
	check(absf(st0 - player.stamina - float(player.T["stamina"]["roll_cost"])) < 0.6, "roll spends stamina")
	await ticks(6)  # ~0.10s in
	check(player.is_invulnerable(), "i-frames active mid-roll (t=~0.10)")
	await ticks(16) # ~0.36s in
	check(not player.is_invulnerable(), "i-frames over late roll (t=~0.36)")
	await ticks(30)
	check(player.state == Player.S.MOVE, "roll returns to MOVE")
	player.sim_move = Vector3.ZERO

	print("== light attack hits the pell")
	player.global_position = dummy.global_position + Vector3(0, 0.1, 1.6)
	player.vis.rotation.y = 0.0   # face -Z toward dummy
	player.velocity = Vector3.ZERO
	await ticks(2)
	var hits0 := dummy.hits_taken
	var hp0 := dummy.hp
	player.try_attack(false)
	await ticks(40)
	check(dummy.hits_taken == hits0 + 1, "one hit registered")
	check(dummy.hp < hp0, "damage applied")
	check(dummy.last_result == "hit", "result is 'hit'")
	await ticks(30)

	print("== combo: queued second light")
	player.global_position = dummy.global_position + Vector3(0, 0.1, 1.6)
	player.vis.rotation.y = 0.0
	hits0 = dummy.hits_taken
	player.try_attack(false)
	await ticks(10)
	player.try_attack(false)   # queue during first swing
	await ticks(80)
	check(dummy.hits_taken == hits0 + 2, "two hits from chained lights")
	await ticks(20)

	print("== block reduces damage, drains stamina")
	player.global_position = dummy.global_position - dummy.global_transform.basis.z * 1.4 + Vector3(0, 0.1, 0)
	player.vis.rotation.y = PI + dummy.rotation.y   # face the dummy
	player.velocity = Vector3.ZERO
	var php0 := player.hp
	st0 = player.stamina
	player.sim_block = true
	await ticks(3)
	check(player.state == Player.S.BLOCK, "enters BLOCK")
	dummy.attack_now()
	await ticks(45)
	check(player.hp > php0 - 6.0, "blocked: chip damage only (hp %.1f -> %.1f)" % [php0, player.hp])
	check(player.stamina < st0 - 5.0, "blocked: stamina paid")
	player.sim_block = false
	await ticks(10)

	print("== i-frame dodge through the swing")
	php0 = player.hp
	dummy.attack_now()
	await ticks(24)              # swing lands at ~0.5s; roll at ~0.4
	player.sim_move = Vector3(0, 0, -1)
	player.try_roll()
	player.sim_move = Vector3.ZERO
	await ticks(20)
	check(absf(player.hp - php0) < 0.01, "no damage taken while rolling through")
	await ticks(30)

	print("== parry -> riposte")
	player.global_position = dummy.global_position - dummy.global_transform.basis.z * 1.3 + Vector3(0, 0.1, 0)
	player.vis.rotation.y = PI + dummy.rotation.y
	player.velocity = Vector3.ZERO
	dummy.attack_now()
	await ticks(22)              # dummy active at 0.50s; parry window 0.08..0.24 after start
	player.try_parry()
	await ticks(14)
	check(player._riposte_target == dummy, "parry connected (riposte primed)")
	var dhp0 := dummy.hp
	check(player.try_riposte(), "riposte executes")
	await ticks(40)
	check(dummy.hp < dhp0 - 50.0, "riposte lands critical damage (-%.0f)" % (dhp0 - dummy.hp))

	print("== winded: an empty bar costs a beat")
	await ticks(60)
	player.stamina = 4.0
	player._spend(4.0)
	check(player._winded > 0.0, "spending to zero winds him")
	player.stamina = player.max_stamina
	check(not player._chain_attack(false), "no chain attacking while winded, whatever the bar says")
	await ticks(36)
	check(player._chain_attack(false), "half a beat later the blade answers")
	await ticks(80)
	player.velocity = Vector3.ZERO

	print("== gourd heals")
	player.hp = 40.0
	var fl0 := player.gourds
	await ticks(30)
	check(player.try_gourd(), "gourd starts")
	await ticks(75)
	check(player.gourds == fl0 - 1, "gourd consumed")
	check(player.hp > 40.0, "hp restored (%.0f)" % player.hp)

	finish()
