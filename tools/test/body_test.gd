extends TestBase
## Bodies keep their room (player._part_from_foes): walking or lunging into
## a frost-taken stops at its body ring instead of inside it; a roll still
## passes through (the i-frame dodge is unchanged); the Netmender's ring is
## her visible bulk, not her thin nav capsule.

var arena: Node
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _spawn(id: String, pos: Vector3) -> Enemy:
	var ecfg: Dictionary = DB.table("enemies").get(id, {})
	var e: Enemy = load(ecfg["class"]).new() if ecfg.has("class") else Enemy.new()
	e.setup(id)
	arena.add_child(e)
	e.global_position = pos
	e.home = pos
	return e

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _run() -> void:
	arena = (load("res://scenes/sandbox/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await ticks(5)
	for sp in ["PenSpawner", "WardSpawner"]:
		var n := arena.get_node_or_null(sp)
		if n != null:
			n.free()
	player = arena.get_node("Player")
	player.sim_active = true
	player.invulnerable = true
	await ticks(3)
	var base := player.global_position

	print("== walking into a rimewalker stops at its body")
	var e := _spawn("rimewalker", base + Vector3(0, 0, -4.0))
	e.set_physics_process(false)   # a statue: the test is the Bearer's body, not its AI
	e.max_hp = 99999.0
	e.hp = 99999.0                 # and one that a heavy blow does not fell
	await ticks(5)
	var reach: float = float(DB.tuning("combat/body_push/bearer_r", 0.34)) + e.push_radius()
	check(e.push_radius() >= 0.4, "a rimewalker keeps a body ring (%.2f m)" % e.push_radius())
	player.cam.yaw = 0.0
	player.sim_move = Vector3(0, 0, -1)
	var closest := 99.0
	for i in 90:
		await ticks(1)
		closest = minf(closest, _flat(player.global_position, e.global_position))
	player.sim_move = Vector3.ZERO
	check(closest >= reach - 0.06, "the Bearer stops at the ring (closest %.2f, ring %.2f)" % [closest, reach])

	print("== a lunge does not carry him into it")
	player.vis.rotation.y = 0.0
	player.try_attack(true)
	closest = 99.0
	for i in 60:
		await ticks(1)
		closest = minf(closest, _flat(player.global_position, e.global_position))
	check(closest >= reach - 0.06, "a heavy lunge ends at the body (closest %.2f)" % closest)
	await ticks(30)

	print("== a roll still passes through")
	player.global_position = e.global_position + Vector3(0, 0.1, 1.3)
	player.velocity = Vector3.ZERO
	await ticks(10)
	var z0 := player.global_position.z
	player.cam.yaw = 0.0
	player.sim_move = Vector3(0, 0, -1)
	await ticks(2)
	check(player.try_roll(), "the Bearer rolls at it")
	closest = 99.0
	for i in 50:
		await ticks(1)
		closest = minf(closest, _flat(player.global_position, e.global_position))
	player.sim_move = Vector3.ZERO
	check(closest < reach * 0.7, "the roll carries him through its ring (closest %.2f)" % closest)
	check(player.global_position.z < e.global_position.z, "and out the far side (z %.2f -> %.2f, foe %.2f)" % [z0, player.global_position.z, e.global_position.z])
	e.queue_free()
	await ticks(5)

	print("== the Netmender's ring is her bulk")
	var nm := _spawn("netmender", base + Vector3(0, 0, -6.0))
	nm.set_physics_process(false)
	await ticks(5)
	check(nm.push_radius() >= 0.85, "her ring is wider than her nav capsule (%.2f m)" % nm.push_radius())
	player.global_position = base
	player.velocity = Vector3.ZERO
	await ticks(5)
	player.cam.yaw = 0.0
	player.sim_move = Vector3(0, 0, -1)
	closest = 99.0
	for i in 120:
		await ticks(1)
		closest = minf(closest, _flat(player.global_position, nm.global_position))
	player.sim_move = Vector3.ZERO
	var nreach := float(DB.tuning("combat/body_push/bearer_r", 0.34)) + nm.push_radius()
	check(closest >= nreach - 0.06, "no walking into the Netmender (closest %.2f, ring %.2f)" % [closest, nreach])
	finish()
