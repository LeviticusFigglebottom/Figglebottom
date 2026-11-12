extends TestBase
## Tarnhall's encounters (TARNHALL.md 5-9), and the Kettle ice's new crack
## warning. In the arena sandbox: ice that cracks a second before it breaks;
## the Feast-guest's seat, rise, cuffs and toast; the Cupbearer's pair and
## its three turns; the Hall-champion's shield and rush; the Host's intro,
## three phases (and the moves each unlocks), the table sweep that slides and
## pins, the bench that lands on its circle, the guests rising out of their
## seats with their horns refilled, the spreading frost, the pour, and his
## release. In the hall itself: Lusse on her model and Ottar, both Keepsakes
## threads end to end, and the release (flag, card, the bar lifted now and
## on rebuild, the hearth at the cold fire, the cup and the guest-tally).

var arena: Node
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _secs(s: float):
	await ticks(int(ceil(s * 60.0)))

func _spawn(id: String, pos: Vector3, face_deg := 0.0, pose := "") -> Enemy:
	var ecfg: Dictionary = DB.table("enemies").get(id, {})
	var e: Enemy = load(ecfg["class"]).new() if ecfg.has("class") else Enemy.new()
	e.setup(id)
	e.idle_pose = pose
	arena.add_child(e)
	e.global_position = pos
	e.home = pos
	e.vis.rotation.y = deg_to_rad(face_deg)
	return e

func _face_player(toward: Vector3) -> void:
	var d := toward - player.global_position
	player.vis.rotation.y = atan2(-d.x, -d.z)

func _ready_player(at: Vector3) -> void:
	if player.dead:
		player.revive_at(at)
		await _secs(1.5)
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.hp = player.max_hp
	player.lock_control(false)

func _combat(e: Enemy) -> void:
	e.target = player
	e._cooldowns.clear()
	e._set_state(Enemy.ES.COMBAT)

func _run() -> void:
	World.reset()
	arena = (load("res://scenes/sandbox/arena.tscn") as PackedScene).instantiate()
	add_child(arena)
	await ticks(5)
	for sp in ["PenSpawner", "WardSpawner"]:   # a quiet arena
		var n := arena.get_node_or_null(sp)
		if n != null:
			n.free()
	player = arena.get_node("Player")
	player.sim_active = true
	await ticks(3)
	await _crack()
	await _guest()
	await _cupbearer()
	await _champion()
	await _host()
	arena.queue_free()
	await ticks(5)
	await _hall()
	finish()

# ------------------------------------------------------------------ the crack
func _crack() -> void:
	print("== ice cracks a second before it breaks (Kettle, lead feedback)")
	await _ready_player(Vector3(0, 0.1, 4))
	var f := _spawn("ice_fisher", Vector3(0, 0.1, 0), 180.0)
	await ticks(4)
	_face_player(f.global_position)
	_combat(f)
	await ticks(2)
	var a := f.attack_by_id("cut_hole")
	f._begin_attack(a)
	var w := float(a["windup"])
	await _secs(w - 1.0 - 0.15)
	check(get_tree().get_nodes_in_group("ice_cracks").is_empty(), "no cracks yet with more than a second to go")
	await _secs(0.3)
	var cracks := get_tree().get_nodes_in_group("ice_cracks")
	check(cracks.size() == 1, "a second before the strike the ice cracks where it will open")
	if cracks.size() == 1:
		var c := cracks[0] as IceCrack
		check(Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z).length() < 0.6,
			"under the Bearer")
		var s0 := c.scale.x
		await _secs(0.4)
		check(is_instance_valid(c) and c.scale.x > s0 + 0.1, "and the cracks spread outward (%.2f -> %.2f)" % [s0, c.scale.x if is_instance_valid(c) else 0.0])
	check(get_tree().get_nodes_in_group("broken_ice").filter(func(b): return (b as BrokenIce).is_open()).is_empty(),
		"the ice has not opened yet")
	await _secs(0.5)
	var open := get_tree().get_nodes_in_group("broken_ice").filter(func(b): return (b as BrokenIce).is_open())
	check(open.size() == 1 and (open[0] as BrokenIce).covers(player.global_position), "then it breaks where it cracked")
	player.global_position = Vector3(0, 0.1, 12)   # off it before the sink
	for b in open:
		(b as BrokenIce).close()
	f.free()
	await _secs(0.6)
	check(get_tree().get_nodes_in_group("ice_cracks").is_empty(), "the cracks give way to the water and go")

# ------------------------------------------------------------------ Feast-guest
func _guest() -> void:
	print("== the Feast-guest: in its seat, white")
	await _ready_player(Vector3(0, 0.1, 14))
	var g := _spawn("feast_guest", Vector3(0, 0.1, 0), 180.0, "sit_feast")
	await ticks(10)
	check(g.vis.is_humanoid() and g.vis.model_id == "feast_guest", "the feast_guest.glb body")
	check(g.state == Enemy.ES.IDLE and g.vis.current_clip() == "sit_feast", "sitting at the table (%s)" % g.vis.current_clip())
	player.global_position = Vector3(0, 0.1, 5)
	_face_player(g.global_position)
	await ticks(8)
	check(g.state == Enemy.ES.ALERT, "it stands when the Bearer passes close")
	await _secs(2.0)
	print("== the toast: both fists down round itself")
	await _ready_player(g.global_position + Vector3(0, 0, 1.6))
	_face_player(g.global_position)
	_combat(g)
	await ticks(2)
	var t := g.attack_by_id("toast")
	check(t.get("type", "") == "sweep" and float((t["sweep"] as Dictionary)["arc"]) == 360.0, "a full circle round it")
	var hp0 := player.hp
	g._begin_attack(t)
	await _secs(float(t["windup"]) * 0.85)
	check(arena.find_children("*", "FloorTelegraph", true, false).size() > 0, "a 2.2 m circle glows round it")
	await _secs(float(t["windup"]) * 0.15 + 0.1)
	check(player.hp < hp0, "standing in it, the Bearer is hit (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.4)
	await _ready_player(g.global_position + Vector3(0, 0, 3.2))
	_combat(g)
	await ticks(2)
	hp0 = player.hp
	g._begin_attack(t)
	await _secs(float(t["windup"]) + 0.15)
	check(player.hp == hp0, "a step outside the circle, nothing")
	g.free()
	await ticks(2)

# ------------------------------------------------------------------ Cupbearer
func _cupbearer() -> void:
	print("== the Cupbearers: quick, in pairs")
	await _ready_player(Vector3(0, 0.1, 6))
	var c := _spawn("cupbearer", Vector3(0, 0.1, 0), 180.0)
	var c2 := _spawn("cupbearer", Vector3(3, 0.1, 0), 180.0)
	await ticks(6)
	check(c.vis.is_humanoid() and c.vis.model_id == "cupbearer", "the cupbearer.glb body")
	check(bool(c.cfg.get("flank", false)) and float(c.cfg["speed"]) > 3.0, "quick, and working a pair from both sides")
	c2.free()
	print("== going round: three turns, a cut each turn")
	await _ready_player(c.global_position + Vector3(0, 0, 1.6))
	_face_player(c.global_position)
	_combat(c)
	await ticks(2)
	var gr := c.attack_by_id("going_round")
	var hp0 := player.hp
	c._begin_attack(gr)
	await _secs(float(gr["windup"]) + 0.85)
	check(player.hp <= hp0 - 3.0 * float(gr["dmg"]) * 0.5, "three cuts land on whoever stands in the ring (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.2)
	print("== the lunge: it runs the strip")
	await _ready_player(c.global_position + Vector3(0, 0, 4.0))
	_face_player(c.global_position)
	_combat(c)
	await ticks(2)
	var start := c.global_position
	hp0 = player.hp
	var l := c.attack_by_id("lunge")
	c._begin_attack(l)
	await _secs(float(l["windup"]) + float(l["active"]) + 0.05)
	check(player.hp < hp0, "the strip's whole length is the blade's (%.0f -> %.0f)" % [hp0, player.hp])
	check(c.global_position.distance_to(start) > 1.2, "and it covers the ground (%.1f m)" % c.global_position.distance_to(start))
	c.free()
	await ticks(2)

# ------------------------------------------------------------------ Hall-champion
func _champion() -> void:
	print("== the Hall-champion: shield up")
	await _ready_player(Vector3(0, 0.1, 5))
	var h := _spawn("hall_champion", Vector3(0, 0.1, 0), 180.0)
	await ticks(6)
	check(h.vis.is_humanoid() and h.vis.model_id == "hall_champion", "the hall_champion.glb body")
	h._blocking = true
	h._set_state(Enemy.ES.APPROACH)
	check(h.is_blocking_toward(h.global_position + Vector3(0, 0, 3)), "the shield takes a blow from the front")
	check(not h.is_blocking_toward(h.global_position + Vector3(3, 0, 0)), "not from the side")
	check(float(h.cfg.get("block_chance", 0.0)) > 0.5, "it guards more often than not")
	print("== the shield rush")
	await _ready_player(h.global_position + Vector3(0, 0, 5.0))
	_face_player(h.global_position)
	_combat(h)
	await ticks(2)
	var r := h.attack_by_id("shield_rush")
	check(not bool(r.get("blockable", true)), "the rush cannot be blocked")
	var hp0 := player.hp
	h._begin_attack(r)
	await _secs(float(r["windup"]) * 0.85)
	check(arena.find_children("*", "FloorTelegraph", true, false).size() > 0, "a 1.6 x 7 m strip glows")
	await _secs(float(r["windup"]) * 0.15 + float(r["active"]))
	check(player.hp < hp0, "it runs him down (%.0f -> %.0f)" % [hp0, player.hp])
	h.free()
	await ticks(2)

# ------------------------------------------------------------------ the Host
var stills: Array = []

## Seated white guests along a bench at z = -4 (the Host's table), facing
## the table (+Z is a raw glb's front): the stills the area lays in RIME.
func _lay_seats() -> void:
	var holder: Node = Game.current_area if Game.current_area != null else arena
	for i in 7:
		var s: Node3D = (load("res://assets/models/enemies/feast_guest.glb") as PackedScene).instantiate()
		holder.add_child(s)
		s.global_position = Vector3(-9.0 + i * 3.0, 0.0, -2.6 if i % 2 == 0 else -5.4)
		s.rotation.y = PI if i % 2 == 0 else 0.0   # the near row faces back to the table at z -4
		stills.append(s)

func _wall(at: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	arena.add_child(b)
	b.global_position = at
	return b

func _host() -> void:
	print("== the Host: walking the table, filling horns")
	await _ready_player(Vector3(0, 0.1, 12))
	player.invulnerable = true
	_lay_seats()
	var h: Host = _spawn("host", Vector3(0, 0.1, 0), 0.0)   # facing -z: the table
	await ticks(20)
	check(h.vis.is_humanoid() and h.vis.model_id == "host", "the host.glb body")
	check(h.state == Enemy.ES.IDLE and not h.stood and h.vis.current_clip() == "pour_horn", "pouring (%s)" % h.vis.current_clip())
	check(h.seated().size() == 7, "seven guests in their places")
	var near: Node3D = h.seated()[0]
	check(near.global_position.z > -4.0, "his own side of the table first")
	var hud: HUD = arena.find_children("*", "HUD", true, false)[0]
	check(not hud.boss_root.visible, "no bar yet")
	player.global_position = h.global_position + Vector3(4.0, 0, 4.0)
	await ticks(6)
	check(h.state == Enemy.ES.TRANSITION and h.vis.current_clip() == "host_set_horn", "within 7 m he sets the horn down and turns")
	await _secs(2.8)
	check(h.stood and hud.boss_root.visible and hud.boss_name.text == "THE HOST", "the bar: THE HOST")

	print("== phase one: the feast")
	var p1 := h.repertoire()
	check("horn_fist" in p1 and "table_sweep" in p1 and "bench_throw" in p1 and not ("raise_guests" in p1)
		and not ("tip_horn" in p1) and not ("pour" in p1), "horn fist, table sweep, bench throw")
	var own := ["table_sweep", "bench_throw", "raise_guests"].filter(func(c):
		return h.vis.rig.has_clip(c) and not h.vis.rig.clip_anim(c).has_meta("procedural"))
	check(own.size() == 3, "his own prompt clips: table_sweep, bench_throw, raise_guests (%s)" % str(own))

	print("== the table sweep: slid outward, and pinned")
	player.invulnerable = false
	h.vis.rotation.y = PI   # facing +z
	await _ready_player(h.global_position + Vector3(0, 0, 4.0))
	_combat(h)
	await ticks(2)
	var sw := h.attack_by_id("table_sweep")
	var hp0 := player.hp
	h._begin_attack(sw)
	await _secs(float(sw["windup"]) * 0.85)
	var tells := arena.find_children("*", "FloorTelegraph", true, false)
	check(tells.size() > 0, "a fan from 1.8 to 7.5 m glows")
	await _secs(float(sw["windup"]) * 0.15 + 0.45)
	var d := Vector2(player.global_position.x - h.global_position.x, player.global_position.z - h.global_position.z).length()
	check(player.hp < hp0, "the table end comes round through him (%.0f -> %.0f)" % [hp0, player.hp])
	check(d > 6.0, "and slides him outward (%.1f m from the Host)" % d)
	await _secs(1.4)
	await _ready_player(h.global_position + Vector3(0, 0, 4.0))
	var wall := _wall(h.global_position + Vector3(0, 1.0, 5.6), Vector3(6, 2, 0.4))
	await ticks(3)
	_combat(h)
	h.vis.rotation.y = PI
	await ticks(2)
	var pins := []
	var on_pin := func(p): pins.append(p)
	h.pinned_bearer.connect(on_pin)
	h._begin_attack(sw)
	await _secs(float(sw["windup"]) + 0.1)
	check(pins.size() == 1 and h.hook_hold != null and not player.input_enabled, "against the wall he is pinned under the table edge")
	await _secs(1.2)
	check(h.hook_hold == null and player.input_enabled, "and let go (or mashed free)")
	h.pinned_bearer.disconnect(on_pin)
	wall.free()
	await _secs(1.0)
	await _ready_player(h.global_position + Vector3(0, 0, 1.2))
	_combat(h)
	h.vis.rotation.y = PI
	await ticks(2)
	hp0 = player.hp
	h._begin_attack(sw)
	await _secs(float(sw["windup"]) + 0.2)
	check(player.hp == hp0, "inside 1.8 m it passes overhead")
	await _secs(1.4)

	print("== the bench throw: it lands on the circle")
	await _ready_player(h.global_position + Vector3(0, 0, 8.0))
	_combat(h)
	await ticks(2)
	var bt := h.attack_by_id("bench_throw")
	hp0 = player.hp
	h._begin_attack(bt)
	await _secs(float(bt["windup"]) * 0.85)
	tells = arena.find_children("*", "FloorTelegraph", true, false)
	var under := tells.filter(func(t): return Vector2((t as Node3D).global_position.x - player.global_position.x,
		(t as Node3D).global_position.z - player.global_position.z).length() < 0.8)
	check(under.size() == 1, "a 2.2 m circle glows where the Bearer stands")
	await _secs(float(bt["windup"]) * 0.15 + 0.1)
	check(h.lobbed.size() == 1 and player.hp == hp0, "the bench is in the air; nothing yet")
	await _secs(float((bt["lob"] as Dictionary)["flight"]))
	check(h.lobbed.is_empty() and player.hp < hp0, "it lands on him (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.5)

	print("== the second sitting")
	player.invulnerable = true
	var phases := []
	var on_phase := func(p): phases.append(p)
	h.phase_changed.connect(on_phase)
	h.take_hit(DamagePacket.new(h.max_hp * 0.42, 0, player))
	await ticks(2)
	check(h.phase == 2 and h.state == Enemy.ES.TRANSITION and h.vis.current_clip() == "raise_guests",
		"at 60%% he spreads his arms over the table (%s)" % h.vis.current_clip())
	var hp_t := h.hp
	h.take_hit(DamagePacket.new(400, 0, player))
	check(h.hp == hp_t, "untouchable while he does")
	await _secs(3.1)
	var up := h.standing_guests()
	check(up.size() == 2, "two guests stand up out of their places (%d)" % up.size())
	check(stills.filter(func(s): return not (s as Node3D).visible).size() == 2, "their places are empty")
	check(up.size() == 2 and (up[0] as Enemy).id == "feast_guest" and (up[0] as Enemy).global_position.z > -4.0,
		"each stands up on its own side of the bench")
	check(h.filled.size() >= 2, "the horns in front of the empty places fill again (%d)" % h.filled.size())
	var p2 := h.repertoire()
	check("raise_guests" in p2 and "tip_horn" in p2 and "bench_throw" in p2 and not ("pour" in p2), "raise the guests, tip the horn")
	check(not h._attack_usable(h.attack_by_id("raise_guests")), "no more while two stand")
	for g in up:
		(g as Enemy).take_hit(DamagePacket.new(999, 0, player))
	await ticks(3)
	check(h._attack_usable(h.attack_by_id("raise_guests")), "with them down, he can raise more")
	_combat(h)
	await ticks(2)
	var rg := h.attack_by_id("raise_guests")
	h._begin_attack(rg)
	await _secs(float(rg["windup"]) / h._speed_mult() + 0.1)
	check(h.standing_guests().size() == 2, "and two more stand")
	for g in h.standing_guests():
		(g as Enemy).free()
	await ticks(2)

	print("== tip the horn: the floor freezes in a spreading pool")
	player.invulnerable = false
	h._end_all_swings()
	await _ready_player(h.global_position + Vector3(0, 0, 6.0))
	h.vis.rotation.y = PI
	_combat(h)
	await ticks(2)
	var th := h.attack_by_id("tip_horn")
	h._begin_attack(th)
	await _secs(float(th["windup"]) / h._speed_mult() + 0.1)
	check(h.open_pools() == 1, "the horn pours out a pool")
	var fp: FrostPool = h.pools[0] if not h.pools.is_empty() else null
	var r0 := fp.radius() if fp != null else 0.0
	check(fp != null and r0 < 2.0 and not fp.covers(player.global_position), "small at first: 1.2 m from where it lands (%.1f)" % r0)
	hp0 = player.hp
	h._set_state(Enemy.ES.HOLD)   # (hold him still while the pool spreads)
	h._hold_quiet = -99.0
	await _secs(3.0)
	check(fp != null and fp.radius() > 5.5 and fp.covers(player.global_position), "it spreads to 6 m and takes in the Bearer (%.1f)" % (fp.radius() if fp != null else 0.0))
	await _secs(1.2)
	check(player.hp < hp0, "the frost bites on it (%.0f -> %.0f)" % [hp0, player.hp])
	h._set_state(Enemy.ES.COMBAT)

	print("== two benches")
	# By now the Host has walked some metres after the Bearer (how far turns
	# on what his AI chose between the sections), and a run laid out from
	# where he stands ended in the arena's wall or its hearth: the Bearer
	# stopped dead, was no longer "running to" anywhere, and one bench flew.
	# Seat him back in the middle and run a lane that is clear floor.
	h._end_all_swings()
	h.global_position = Vector3(0, 0.1, 0)
	h.velocity = Vector3.ZERO
	await _ready_player(Vector3(-4.0, 0.1, 7.0))
	_combat(h)
	await ticks(2)
	h._begin_attack(bt)
	var wt := float(bt["windup"]) / h._speed_mult()
	var t0 := 0.0
	# he runs across the hall through the windup, until the benches leave
	# the Host's hands (the throw itself, not a count of ticks)
	while h.lobbed.is_empty() and h.state == Enemy.ES.ATTACK and t0 < wt + 0.5:
		player.global_position += Vector3(5.0 / 60.0, 0, 0)
		await ticks(1)
		t0 += 1.0 / 60.0
	check(absf(t0 - wt) < 0.1, "the throw comes at the end of the windup (%.2f s of %.2f)" % [t0, wt])
	check(h.lobbed.size() == 2, "the second goes where he is running to (%d in the air)" % h.lobbed.size())
	await _secs(1.5)

	print("== the last round")
	player.invulnerable = true
	h._end_all_swings()
	h._set_state(Enemy.ES.COMBAT)
	h.take_hit(DamagePacket.new(h.hp - h.max_hp * 0.2, 0, player))
	await ticks(2)
	check(h.phase == 3 and h.state == Enemy.ES.TRANSITION, "at 25% the last round")
	await _secs(3.0)
	check(h.open_pools() == 0, "his frost on the floor goes grey")
	check(h.global_position.distance_to(h.home) < 1.0, "he is back at the table")
	var p3 := h.repertoire()
	check("pour" in p3 and "table_sweep" in p3 and not ("bench_throw" in p3), "pour, the sweep, no more benches")
	h._begin_attack(sw)
	check(float((h._atk["sweep"] as Dictionary)["arc"]) == 360.0 and String((h._atk["telegraph"] as Dictionary)["shape"]) == "annulus",
		"the sweep turns right round")
	h._end_all_swings()
	h._set_state(Enemy.ES.COMBAT)

	print("== pour: his back to the Bearer")
	await _ready_player(h.global_position + Vector3(0, 0, 9.0))
	h.raise_guests(1)
	var g1: Enemy = h.standing_guests()[0] if not h.standing_guests().is_empty() else null
	if g1 != null:
		g1.hp = 5.0
	h._cooldowns.clear()
	var pr := h.attack_by_id("pour")
	check(h._attack_usable(pr), "the Bearer far off and he at the table")
	h._begin_attack(pr)
	await _secs(float(pr["windup"]) / h._speed_mult() + 0.1)
	check(h.state == Enemy.ES.HOLD and h.vis.current_clip() == "pour_horn", "he fills the horns along the table")
	check(g1 != null and g1.hp == g1.max_hp, "every guest standing is mended")
	var seats_left := h.seated().size()
	await _secs(2.0)
	h.take_hit(DamagePacket.new(10, 0, player))
	check(h.state == Enemy.ES.HOLD, "a blow does not stop him")
	await _secs(5.3)
	check(h.state != Enemy.ES.HOLD, "five quiet seconds: he turns back")
	check(h.seated().size() == seats_left - 1, "and a guest stands at an empty place (%d -> %d, %d up)" % [seats_left, h.seated().size(), h.standing_guests().size()])

	print("== the release")
	var up_before := h.standing_guests()
	while not h.dead:
		h.take_hit(DamagePacket.new(400, 0, player))
		await ticks(2)
	await ticks(20)
	check(h.released and h.vis.current_clip() == String(h.cfg.get("release_anim", "host_sit")), "he sets the horn down and sits (%s)" % h.vis.current_clip())
	check(up_before.filter(func(g): return is_instance_valid(g) and g.is_in_group(RH.GROUP_ENEMIES)).is_empty(),
		"the guests still standing sit down where they are")
	player.invulnerable = false
	h.free()
	for s in stills:
		if is_instance_valid(s):
			s.free()
	stills.clear()
	await ticks(3)

# ------------------------------------------------------------------ the hall
var area: Area

func _talk(npc_id: String) -> DialogueUI:
	var cfg := DB.npc(npc_id)
	cfg["id"] = npc_id
	var ui := DialogueUI.new(cfg, null)
	get_tree().root.add_child(ui)
	return ui

func _service_ids(ui: DialogueUI) -> Array:
	while ui._phase == "lines":
		ui.advance()
	return ui._options.map(func(o): return String(o.get("id", "")))

func _close(ui: DialogueUI) -> void:
	if is_instance_valid(ui):
		ui.close()
	await ticks(3)

func _lines_of(thread_id: String) -> Array:
	for t in Keepsakes.journal():
		if t["id"] == thread_id:
			return t["lines"]
	return []

func _expected(thread_id: String, n: int) -> Array:
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			# (the steps a point of interest adds are off this suite's road: POI.md,
			# tools/test/poi_*_test.gd walk those)
			return (t["steps"] as Array).filter(func(s): return not (String(s["flag"]) in ["ks_ivo_pole", "ks_ivo_line", "ks_ottar_pair"])) \
				.slice(0, n).map(func(s): return String(s["line"]))
	return []

func _pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id and not p.is_queued_for_deletion():
			return p
	return null

## The hall doors (Tarnhall's way on, ADR 0015, is a gate of its own).
func _gate() -> ShortcutGate:
	for g in area.find_children("*", "ShortcutGate", true, false):
		if (g as ShortcutGate).gate_id == "hall_doors":
			return g
	return null

func _build(state: RH.WState) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	World.set_area_state("tarnhall", state)
	area = AreaBuilder.build("tarnhall")
	add_child(area)
	Game.register_area(area, "tarnhall")
	StateDirector.snap(area, state)
	await ticks(10)

func _hall() -> void:
	World._save_dir = "user://test_tarnhall_enc"
	World.reset()
	Game.set_warmth(0)
	await _build(RH.WState.THAW)
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	var hud := HUD.new()
	add_child(hud)
	await ticks(10)

	print("== Lusse and Ottar keep the thaw")
	var seen := {}
	for c in area.find_children("*", "NPC", true, false):
		seen[(c as NPC).npc_id] = c
	check(seen.has("lusse") and seen.has("ottar"), "both stand in the hall")
	var lusse: NPC = seen.get("lusse")
	check(lusse != null and lusse._vis.is_humanoid() and lusse._vis.model_id == "lusse", "Lusse stands as lusse.glb")

	print("== the first meetings")
	var ui := _talk("lusse")
	await ticks(2)
	check(ui.text_label.text.begins_with("You came up the steps in time."), "Lusse opens with her own line")
	check(_lines_of("guest_tally") == _expected("guest_tally", 1), "her thread starts")
	var ids := _service_ids(ui)
	check(ids.has("sing_goat_song") and ids.has("buy_long_note"), "the chorus, and the Long Note")
	ui.choose(ids.find("sing_goat_song"))
	check(int(player.inventory.get("goat_song", 0)) == 1 and not DB.song("goat_song").is_empty(), "the Bearer has the Goat Song")
	check(_lines_of("guest_tally") == _expected("guest_tally", 2), "she had the chorus out of him")
	await _close(ui)
	ui = _talk("ottar")
	await ticks(2)
	check(ui.text_label.text.begins_with("I'm away."), "Ottar is going home")
	check(_lines_of("ottar_stick") == _expected("ottar_stick", 1), "his thread starts")
	await _close(ui)

	print("== the rime: the doors barred, the stick inside them")
	await _build(RH.WState.RIME)
	var gate := _gate()
	check(gate != null and gate.gate_id == "hall_doors" and not gate._is_open(), "the hall doors are barred")
	for pid in ["feast_cleaver", "barrel_head", "ottar_staff"]:
		check(_pickup(pid) != null, "%s is placed" % pid)
	var tally := _pickup("guest_tally")
	check(tally != null and not tally.visible, "the guest-tally is not to be had yet")
	var stick := _pickup("ottar_staff")
	if stick != null:
		stick._on_take(player)
	check(_lines_of("ottar_stick") == _expected("ottar_stick", 2), "Ottar's stick, inside the barred door")
	var kinds := {}
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead):
		kinds[(e as Enemy).id] = true
	check(kinds.has("feast_guest") and kinds.has("cupbearer") and kinds.has("hall_champion") and kinds.has("host")
		and not kinds.has("rimewalker") and not kinds.has("keener") and not kinds.has("cairn_carrier") and not kinds.has("netmender"),
		"the hall's own foes, no stand-ins (%s)" % str(kinds.keys()))

	print("== back in the thaw, carrying the stick")
	await _build(RH.WState.THAW)
	ui = _talk("ottar")
	await ticks(2)
	check(World.flag("ks_ottar_staff") and int(player.inventory.get("item_ottar_staff", 0)) == 0, "Ottar takes his stick")
	check(ui.text_label.text.begins_with("That's my stick."), "and wonders where it was")
	await _close(ui)

	print("== the release")
	await _build(RH.WState.RIME)
	var host: Host = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Host and e.can_process():
			host = e
	check(host != null and host.seated().size() >= 3, "the Host at the table, guests in their places")
	var sat: Array = host.seated() if host != null else []
	check(not sat.is_empty() and sat.all(func(g): return g is Enemy and (g as Enemy).vis.current_clip() == "sit_feast"),
		"seated on the benches (sit_feast), not standing stills")
	player.global_position = (sat[0] as Node3D).global_position + Vector3(0, 0.3, 2.5) if not sat.is_empty() else player.global_position
	await ticks(20)
	check(not sat.is_empty() and (sat[0] as Enemy).state == Enemy.ES.IDLE, "they do not stand for the Bearer passing")
	var cards := []
	var on_card := func(t: String, _h: float): cards.append(t)
	Game.title_card.connect(on_card)
	player.invulnerable = true
	player.global_position = host.global_position + Vector3(0, 0.3, 4.0)
	await ticks(4)
	host.take_hit(DamagePacket.new(10, 0, player))
	await _secs(2.8)
	while host != null and not host.dead:
		host.take_hit(DamagePacket.new(300, 0, player))
		await _secs(3.2 if host.state == Enemy.ES.TRANSITION else 0.05)
	await ticks(30)
	Game.title_card.disconnect(on_card)
	check(host.released and World.flag("ks_host_released"), "he is released (ks_host_released)")
	check("THE HOST — RELEASED" in cards, "the quiet card")
	gate = _gate()
	check(gate != null and gate._is_open() and (gate.get_node("GateBody") as StaticBody3D).collision_layer == 0,
		"the bar lifts and the doors swing open by themselves (open %s, layer %d, flag %s)" % [gate._is_open() if gate else false,
		(gate.get_node("GateBody") as StaticBody3D).collision_layer if gate else -1, World.area_flag("tarnhall", "gate_hall_doors")])
	await _secs(1.2)
	check(gate != null and absf(gate._leaves[0].rotation.y) > deg_to_rad(80.0), "the leaves stand open")
	check(Game.find_hearth("hs_long_table") != null, "the hearth wakes at the cold fire")
	var cup := _pickup("host_cup")
	check(cup != null and cup.global_position.distance_to(host.global_position) < 3.5, "his cup is left beside him")
	# the Bearer across the board when he falls: the cup is set down on his
	# side of the bench, on open floor, not in the gap under the table edge
	var north := Vector3(0, 0, -1)
	var rd: Dictionary = host.cfg["release_drop"]
	var ahead := float(rd["ahead"])
	if rd.has("clear"):
		ahead = Game._drop_reach(host, north, ahead, float(rd["clear"]))
	var at: Vector3 = host.global_position + north * ahead
	var nav_at := NavigationServer3D.map_get_closest_point(area.get_world_3d().navigation_map, at)
	# nothing over it (not in under the table), and the navmesh there itself
	# (measured on the flat: the navmesh rides up over the bench's step)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.6, at + Vector3.DOWN * 0.3, RH.M_WORLD_ALL)
	var down := area.get_world_3d().direct_space_state.intersect_ray(q)
	var top: float = (down["position"] as Vector3).y if not down.is_empty() else -INF
	check(absf(top - at.y) < 0.15 and Vector2(nav_at.x - at.x, nav_at.z - at.z).length() < 0.3,
		"across the board, the cup would still lie on open floor (%s; a stone dropped there lands at %.2f; the navmesh at %s)" % [
		at.snapped(Vector3.ONE * 0.01), top, nav_at.snapped(Vector3.ONE * 0.01)])
	if cup != null:
		cup._on_take(player)
	check(int(player.inventory.get("item_host_cup", 0)) == 1, "the Bearer takes the Host's cup")
	await _secs(0.7)
	tally = _pickup("guest_tally")
	check(tally != null and tally.visible, "the guest-tally can be untied from the door-post now")
	if tally != null:
		tally._on_take(player)
	check(World.flag("ks_guest_tally_found") and _lines_of("guest_tally") == _expected("guest_tally", 3), "the last knots, one knot")
	await _build(RH.WState.RIME)
	check(get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and (e as Enemy).cfg.get("seated", false)).is_empty(),
		"the guests have gone from the benches")
	gate = _gate()
	check(gate != null and gate._is_open(), "the doors stay open in a rebuilt hall")
	check(Game.find_hearth("hs_long_table") != null, "and the Long Table hearth stays lit")

	print("== after the release, both threads close")
	await _build(RH.WState.THAW)
	ui = _talk("lusse")
	await ticks(2)
	check(World.flag("ks_guest_tally") and ui.text_label.text.begins_with("Forty-one."), "Lusse counts the tally")
	await _close(ui)
	ui = _talk("ottar")
	await ticks(2)
	check(ui.text_label.text.begins_with("Who's opened the doors?"), "Ottar feels the air")
	await _close(ui)
	check(_lines_of("guest_tally") == _expected("guest_tally", 4), "the guest-tally: four lines, in order")
	check(_lines_of("ottar_stick") == _expected("ottar_stick", 4), "Ottar's stick: four lines, in order")
	player.invulnerable = false
