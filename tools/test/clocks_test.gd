extends TestBase
## The hitstop's and the ward's clocks (gpu/walk-ticks). In play they read the wall clock, as they
## always did; only a deterministic walk (--deterministic) counts frames instead. Here, in play:
## a hitstop holds its duration in real seconds, stacked stops extend, and the Warding Hum lasts
## its songs.json duration.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena = (load("res://scenes/sandbox/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await ticks(5)
	var player: Player = arena.get_node("Player")
	player.sim_active = true

	print("== hitstop: its duration in real seconds, then time_scale 1 again")
	for dur in [0.06, 0.09, 0.14]:
		await ticks(2)
		var t0 := Time.get_ticks_usec()
		Juice.hitstop(dur, 0.05)
		check(is_equal_approx(Engine.time_scale, 0.05), "time slows at once (%.2f s)" % dur)
		while not is_equal_approx(Engine.time_scale, 1.0) and Time.get_ticks_usec() - t0 < 2000000:
			await get_tree().process_frame
		var took := (Time.get_ticks_usec() - t0) / 1000000.0
		# a frame either side: the restore is seen on the first frame after the clock passes it
		check(took >= dur - 0.002 and took <= dur + 0.05, "a %.2f s hitstop holds %.3f s" % [dur, took])
	await ticks(2)
	Juice.hitstop(0.09)
	Juice.hitstop(0.05)
	var t1 := Time.get_ticks_usec()
	while not is_equal_approx(Engine.time_scale, 1.0) and Time.get_ticks_usec() - t1 < 2000000:
		await get_tree().process_frame
	check((Time.get_ticks_usec() - t1) / 1000000.0 >= 0.08, "a shorter stop inside a longer one does not cut it short")

	print("== the Warding Hum lasts its songs.json duration")
	var sp := DB.song("warding_hum")
	var want := float(sp.get("duration", 8.0))
	player.inventory["warding_hum"] = 1
	player.max_breath = 100.0     # (0 until a first song is learned)
	player.breath = player.max_breath
	await ticks(60)
	var t0w := Time.get_ticks_usec()
	player.cast_song("warding_hum")
	check(player._ward_active(), "the ward is up")
	while player._ward_active() and Time.get_ticks_usec() - t0w < int((want + 3.0) * 1000000.0):
		await get_tree().physics_frame
	var lasted := (Time.get_ticks_usec() - t0w) / 1000000.0
	check(absf(lasted - want) <= 0.05, "it holds %.3f s (data %.1f s)" % [lasted, want])
	finish()
