extends TestBase
## After anything that takes the Bearer's body or his control away (a
## plaque, a talk, the Pack, a rest, a drink, a Song, a roll, a stagger, a
## death, a seam), he is handed back whole: feet on the ground, the visual at
## rest, S.MOVE with control, idle when standing, the gait cycling when he
## walks, and able to swing. Every case starts mid-stride with the move key
## still held, as a player arrives at a sign. The frost-taken get the same
## check after a stagger, an interrupted attack, a chore pose and a respawn.

const FEET := ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]
const HIPS := "mixamorig_Hips"
## metres a foot or the hips may sit off their idle height (the idle breathes)
const TOL := 0.06

var area: Area
var player: Player
var hud: HUD
var hearth: Hearthstone
var spawner: Spawner

var _foot0 := 0.0     # lowest foot bone above the capsule's floor, at idle
var _hip0 := 0.0
var _swing0 := 0.0    # how far a foot lifts through a healthy stride
var _vis_pos0 := Vector3.ZERO

func _ready() -> void:
	_run.call_deferred()

func _build_world() -> void:
	World.reset()
	World._save_dir = "user://test_grounded"
	area = Area.new()
	area.area_id = "gr_test"
	add_child(area)
	Game.register_area(area, "gr_test")
	for i in range(8):
		for j in range(8):
			var f := KitLib.instance("floor_4x4")
			f.position = Vector3(i * 4 - 14, 0, j * 4 - 14)
			KitLib.add_collision(f, RH.L_WORLD_BASE)
			area.attach(f, "base")
	area.bake_navmeshes()
	World.set_area_state("gr_test", RH.WState.RIME)
	StateDirector.snap(area, RH.WState.RIME)

	hearth = Hearthstone.new()
	hearth.hearth_id = "gr_hearth"
	hearth.area = area
	area.base.add_child(hearth)
	hearth.position = Vector3(12, 0, 12)
	World.last_hearth = {"area": "gr_test", "hearth": "gr_hearth"}

	spawner = Spawner.new()
	spawner.enemy_id = "rimewalker"
	area.rime_layer.add_child(spawner)
	spawner.position = Vector3(-12, 0.1, -12)

	player = Player.new()
	add_child(player)
	player.position = Vector3(0, 0.15, 8)
	player.sim_active = true
	hud = HUD.new()
	add_child(hud)

# ------------------------------------------------------------------ measuring
## Lowest foot bone above the floor under the body (a CharacterBody's origin
## is its capsule's foot).
func _feet(v: CharVisual, floor_y: float) -> float:
	var low := INF
	for b in FEET:
		if v.skel.find_bone(b) >= 0:
			low = minf(low, v.bone_xform(b).origin.y - floor_y)
	return low

func _hips(v: CharVisual, floor_y: float) -> float:
	return v.bone_xform(HIPS).origin.y - floor_y

## Walk `n` ticks along -Z; returns [metres covered, foot lift range, the
## rig's clip at the end].
func _walk(n: int) -> Array:
	var from := player.global_position
	var lo := INF
	var hi := -INF
	player.cam.yaw = 0.0
	player.sim_move = Vector3(0, 0, -1)
	for i in n:
		await ticks(1)
		if i >= n / 3:   # past the blend out of idle
			var y := player.vis.bone_xform(FEET[0]).origin.y - player.global_position.y
			lo = minf(lo, y)
			hi = maxf(hi, y)
	var clip := player.vis.current_clip()
	var d := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	return [d, hi - lo, clip]

## Put him back in the middle and set him walking, key held.
func _stride() -> void:
	player.sim_move = Vector3.ZERO
	player.global_position = Vector3(0, 0.05, 8)
	player.velocity = Vector3.ZERO
	player.vis.rotation.y = 0.0
	await ticks(20)
	player.cam.yaw = 0.0
	player.sim_move = Vector3(0, 0, -1)
	await ticks(35)

func _until(cond: Callable, max_ticks := 600) -> bool:
	var n := 0
	while not cond.call() and n < max_ticks:
		await ticks(2)
		n += 2
	return cond.call()

## The whole hand-back contract, after `what`.
func _grounded(what: String) -> void:
	player.sim_move = Vector3.ZERO
	await ticks(60)
	var v := player.vis
	check(player.state == Player.S.MOVE and player.input_enabled and not player.dead,
		"%s: S.MOVE with control (state %s, input %s)" % [what, Player.S.keys()[player.state], player.input_enabled])
	check(v.position.is_equal_approx(_vis_pos0) and v.scale.is_equal_approx(Vector3.ONE)
			and v.body.position.is_zero_approx() and v.body.scale.is_equal_approx(Vector3.ONE)
			and absf(v.rotation.x) < 0.01 and absf(v.rotation.z) < 0.01,
		"%s: the visual is back at rest (pos %s, scale %s, tilt %.2f/%.2f)" % [what, v.position, v.scale, v.rotation.x, v.rotation.z])
	var f := _feet(v, player.global_position.y)
	var h := _hips(v, player.global_position.y)
	check(absf(f - _foot0) < TOL and absf(h - _hip0) < TOL,
		"%s: feet on the ground (feet %+.3f m, hips %+.3f m off idle)" % [what, f - _foot0, h - _hip0])
	check(v.current_clip() == "idle" and v.rig.action_clip() == "" and v.rig._w_act < 0.05,
		"%s: standing, the gait's idle owns the rig (clip '%s', action '%s', weight %.2f)" % [what, v.current_clip(), v.rig.action_clip(), v.rig._w_act])
	var w: Array = await _walk(50)
	check(float(w[0]) > 1.5 and String(w[2]) in ["walk", "run"] and v.rig.action_clip() == "" and float(w[1]) > _swing0 * 0.5,
		"%s: walking, the stride cycles (%.1f m, clip '%s', action '%s', foot lift %.2f of %.2f m)" % [what, w[0], w[2], v.rig.action_clip(), w[1], _swing0])
	player.sim_move = Vector3.ZERO
	await ticks(25)
	player.stamina = player.max_stamina
	var swung := player.try_attack(false)
	check(swung and player.state == Player.S.ATTACK and v.current_clip() == "attack_l1",
		"%s: a swing starts (clip '%s')" % [what, v.current_clip()])
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await ticks(40)
	check(player.state == Player.S.MOVE and absf(_feet(v, player.global_position.y) - _foot0) < TOL and v.current_clip() == "idle",
		"%s: and ends back on his feet at idle" % what)

func _press_key() -> void:
	# the lore panel ignores the first quarter second (wall clock)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 320:
		await ticks(2)
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = true
	get_tree().root.push_input(ev)
	await ticks(3)

func _ui(cls: String) -> Node:
	for c in get_tree().root.get_children():
		if c.get_script() != null and (c.get_script() as Script).get_global_name() == cls:
			return c
	return null

func _hit(amount: float, poise: float) -> void:
	var pk := DamagePacket.new(amount, poise, null)
	pk.origin = player.global_position + Vector3(0, 0, -1)
	player.take_hit(pk)

# ------------------------------------------------------------------ the run
func _run() -> void:
	_build_world()
	await ticks(40)
	check(player.vis.is_humanoid(), "the Bearer wears his real body (%s)" % player.vis.model_id)
	_vis_pos0 = player.vis.position
	_foot0 = _feet(player.vis, player.global_position.y)
	_hip0 = _hips(player.vis, player.global_position.y)
	var w: Array = await _walk(60)
	_swing0 = float(w[1])
	player.sim_move = Vector3.ZERO
	print("== at rest: feet %.3f m, hips %.3f m above the floor; a stride lifts a foot %.3f m" % [_foot0, _hip0, _swing0])
	check(absf(_foot0) < 0.2 and _hip0 > 0.6 and _swing0 > 0.05, "the measures read a standing, striding body")
	await _grounded("fresh")

	await _signs()
	await _talks()
	await _menus()
	await _rests()
	await _pickups()
	await _body_actions()
	await _hurts()
	await _held_and_carried()
	await _outfit()
	await _seam()
	await _foes()
	finish()

func _signs() -> void:
	print("== control locked and handed back mid-stride")
	await _stride()
	player.lock_control(true)
	await ticks(45)
	check(player.vis.current_clip() == "idle" and player.velocity.length() < 0.1, "locked, he settles to idle instead of jogging in place")
	player.lock_control(false)
	await _grounded("lock_control")

	print("== a lore panel opened mid-stride")
	await _stride()
	Game.lore_panel.emit("A test inscription.")
	await ticks(5)
	check(hud.lore_root.visible and not player.input_enabled, "the panel is up and holds him")
	await _press_key()
	check(not hud.lore_root.visible, "any key puts it away")
	await _grounded("lore panel")

	print("== a real plaque, walked up to and read")
	var pl := LorePlaque.new()
	pl.text = "Here the road was mended."
	area.attach(pl, "base")
	pl.global_position = Vector3(0.6, 0, 4.2)
	await _stride()
	await _until(func(): return player.nearest_interactable() != null, 120)
	check(player.try_interact() and hud.lore_root.visible, "he reads it without breaking stride")
	await _press_key()
	await _grounded("plaque")
	pl.queue_free()

	print("== a note that is taken by the reading")
	var note := LorePlaque.new()
	note.style = "note"
	note.text = "Gone to the shore."
	note.set_flag = "gr_note"
	area.attach(note, "base")
	note.global_position = Vector3(0.6, 0, 4.2)
	await _stride()
	await _until(func(): return player.nearest_interactable() != null, 120)
	check(player.try_interact() and hud.lore_root.visible, "he takes the note up")
	await _press_key()
	await _grounded("note")

func _talks() -> void:
	print("== a talk begun mid-stride")
	var n := NPC.new()
	n.npc_id = "brede"
	n.spec = {"id": "brede"}
	n.set_meta("state_tag", "base")
	area.attach(n, "base")
	n.global_position = Vector3(1.2, 0, 3.5)
	await ticks(5)
	await _stride()
	n._on_talk(player)
	await ticks(30)
	var ui := _ui("DialogueUI") as DialogueUI
	check(ui != null and player.state == Player.S.TALK, "the talk holds him in S.TALK")
	check(player.vis.current_clip() == "idle", "and he stands to listen (clip '%s')" % player.vis.current_clip())
	if ui != null:
		ui.close()
	await _grounded("dialogue")

	print("== 'sit by the fire' from a talk: the levelling sheet, then away")
	await _stride()
	n._on_talk(player)
	await ticks(10)
	ui = _ui("DialogueUI") as DialogueUI
	if ui != null:
		ui.close()
	player.lock_control(true)
	var sheet := RestUI.new(null, player, "level", "")
	get_tree().root.add_child(sheet)
	await ticks(30)
	sheet.close()
	await _grounded("talk into the levelling sheet")
	n.queue_free()

func _menus() -> void:
	print("== the Pack opened mid-stride")
	await _stride()
	var inv := InventoryUI.new(player, "pack")
	get_tree().root.add_child(inv)
	await ticks(40)
	check(not player.input_enabled, "the Pack holds him")
	inv.close()
	await ticks(2)
	if is_instance_valid(inv) and not inv.is_queued_for_deletion():
		inv.queue_free()
	await _grounded("pack")

func _rests() -> void:
	print("== the hearth: the choice sheet, closed without resting")
	await _stride()
	hearth._on_activated(player)
	await ticks(30)
	var sheet := _ui("RestUI") as RestUI
	check(sheet != null and not player.input_enabled, "the hearth's sheet holds him")
	if sheet != null:
		sheet.close()
	await _grounded("hearth sheet")

	print("== the hearth: a rest, kneel and rise")
	await _stride()
	hearth._on_activated(player)
	await ticks(10)
	sheet = _ui("RestUI") as RestUI
	if sheet != null:
		sheet.close()
	Game.hearth_flow(hearth, player, "rest_only")
	await ticks(40)
	check(player.state == Player.S.REST and player.vis.current_clip() == "kneel", "he kneels at the stone (clip '%s')" % player.vis.current_clip())
	await _until(func(): return player.state == Player.S.MOVE and player.input_enabled, 600)
	await _grounded("rest")

	print("== the hearth: a rest that turns the world")
	World.set_cleared("gr_test")
	await _stride()
	Game.hearth_flow(hearth, player, "toggle")
	await _until(func(): return player.state == Player.S.REST, 60)
	await _until(func(): return player.state == Player.S.MOVE and player.input_enabled and not StateDirector.transitioning, 1800)
	check(World.get_area_state("gr_test") == RH.WState.THAW, "the area turned to thaw")
	await _grounded("rest and turn (thaw)")
	Game.hearth_flow(hearth, player, "toggle")
	await _until(func(): return player.state == Player.S.REST, 60)
	await _until(func(): return player.state == Player.S.MOVE and player.input_enabled and not StateDirector.transitioning, 1800)
	check(World.get_area_state("gr_test") == RH.WState.RIME, "and back to rime")
	await _grounded("rest and turn (rime)")

func _pickup(id: String) -> Pickup:
	var k := Pickup.new()
	k.pickup_id = id
	k.area_id = "gr_test"
	return k

func _pickups() -> void:
	print("== a thing picked up mid-stride")
	var k := _pickup("gr_take")
	k.warmth = 5
	area.attach(k, "base")
	k.global_position = Vector3(0.5, 0, 4.2)
	await _stride()
	await _until(func(): return player.nearest_interactable() != null, 120)
	check(player.try_interact(), "he takes it")
	await _grounded("pickup")

	print("== a thing only looked at")
	var look := _pickup("gr_look")
	look.look_text = "One set of prints."
	area.attach(look, "base")
	look.global_position = Vector3(0.5, 0, 4.2)
	await _stride()
	await _until(func(): return player.nearest_interactable() != null, 120)
	check(player.try_interact() and hud.lore_root.visible, "he looks, and the words come up")
	await _press_key()
	await _grounded("looked-at pickup")
	look.queue_free()

	print("== a thing chipped out of the ice with a heavy blow")
	var ice := _pickup("gr_chip")
	ice.chip_heavy = true
	ice.warmth = 5
	area.attach(ice, "base")
	await _stride()
	player.sim_move = Vector3.ZERO
	await ticks(20)
	ice.global_position = player.global_position + Vector3(0, 0, -1.2)
	player.vis.rotation.y = 0.0
	await ticks(3)
	player.stamina = player.max_stamina
	check(player.try_attack(true), "he swings heavy at it")
	await _until(func(): return World.area_flag("gr_test", "took_gr_chip"), 240)
	check(World.area_flag("gr_test", "took_gr_chip"), "the blow chips it free")
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("chipped pickup")

func _body_actions() -> void:
	print("== a drink from the gourd")
	await _stride()
	player.gourds = 2
	player.hp = player.max_hp * 0.5
	check(player.try_gourd(), "he drinks")
	await _until(func(): return player.state == Player.S.MOVE, 480)
	await _grounded("gourd")

	for sid in ["mend", "ember_throw", "long_note", "warding_hum", "hearth_shout"]:
		print("== a Song: %s" % sid)
		player.inventory[sid] = 1
		player.max_breath = 200.0
		player.breath = 200.0
		player._cast_cd = 0.0
		await _stride()
		player.cast_song(sid)
		await ticks(2)
		check(player.vis.rig.action_active(), "the cast takes the rig (clip '%s')" % player.vis.current_clip())
		await ticks(120)
		await _grounded("song " + sid)

	print("== a roll, and a backstep")
	await _stride()
	player.stamina = player.max_stamina
	check(player.try_roll() and player.state == Player.S.ROLL, "he rolls")
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("roll")
	await _stride()
	player.sim_move = Vector3.ZERO
	await ticks(25)
	player.stamina = player.max_stamina
	check(player.try_roll() and player.state == Player.S.BACKSTEP, "standing, he backsteps")
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("backstep")

	print("== a guard raised and dropped, and a parry that meets nothing")
	await _stride()
	player.sim_block = true
	await ticks(40)
	check(player.state == Player.S.BLOCK, "the guard is up")
	player.sim_block = false
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("block")
	await _stride()
	player.stamina = player.max_stamina
	check(player.try_parry(), "he parries the air")
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("parry")

func _hurts() -> void:
	print("== staggered mid-stride, mid-swing and mid-drink")
	await _stride()
	_hit(1.0, 999.0)
	check(player.state == Player.S.STAGGER, "the blow staggers him")
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("stagger")
	await _stride()
	player.stamina = player.max_stamina
	player.try_attack(true)
	await ticks(8)
	_hit(1.0, 999.0)
	check(player.state == Player.S.STAGGER, "a blow breaks his swing")
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("stagger out of a swing")
	await _stride()
	player.gourds = 2
	player.try_gourd()
	await ticks(10)
	_hit(1.0, 999.0)
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _grounded("stagger out of a drink")

	print("== a blow soaked while control is locked (a panel up)")
	await _stride()
	Game.lore_panel.emit("Words, while something swings.")
	await ticks(10)
	_hit(1.0, 999.0)
	await _until(func(): return player.state == Player.S.MOVE, 240)
	await _press_key()
	await _grounded("stagger behind a panel")

	print("== death and the walk back from the hearth")
	await _stride()
	_hit(99999.0, 10.0)
	check(player.dead and player.state == Player.S.DEAD, "he dies")
	await ticks(40)
	check(player.vis.current_clip() in ["death", ""], "into the death clip")
	await _until(func(): return not player.dead, 1200)
	check(not player.dead, "and wakes at the hearth")
	player.global_position = Vector3(0, 0.05, 8)   # (room to walk: the stone is in the way there)
	await _grounded("death and revive")

	print("== death behind an open panel")
	await _stride()
	Game.lore_panel.emit("The last thing he read.")
	await ticks(10)
	_hit(99999.0, 10.0)
	await _until(func(): return not player.dead, 1200)
	if hud.lore_root.visible:
		await _press_key()
	player.global_position = Vector3(0, 0.05, 8)
	await _grounded("death behind a panel")

func _held_and_carried() -> void:
	print("== seized and let go (a grab hold)")
	await _stride()
	GrabHold.start(self, player, 0.6, 99)
	await ticks(10)
	check(not player.input_enabled, "the hold takes his control")
	await _until(func(): return player.input_enabled, 240)
	await _grounded("grab hold")

	print("== carried through a frost veil")
	var veil := FrostVeil.new()
	area.attach(veil, "rime")
	veil.global_position = Vector3(0, 0, 4.0)
	await ticks(5)
	await _stride()
	veil._on_enter(player)
	await ticks(10)
	check(not player.input_enabled, "the veil carries him")
	await _until(func(): return player.input_enabled, 240)
	await _grounded("frost veil")
	veil.queue_free()

func _outfit() -> void:
	print("== a change of body (the mask goes on) and back")
	var other := String(DB.tuning("player/model_outsong", ""))
	if other == "" or not HumanoidLib.has_model(other):
		print("  (no second body in this build)")
		return
	var mine := player.vis.model_id
	await _stride()
	player.set_model(other)
	await ticks(5)
	check(player.vis.model_id == other, "he wears the other body")
	# (bodies differ in build: re-read the rest measures for this one)
	var keep := [_foot0, _hip0, _swing0]
	player.sim_move = Vector3.ZERO
	await ticks(60)
	check(player.vis.current_clip() == "idle", "the new body stands at idle (clip '%s')" % player.vis.current_clip())
	check(absf(_feet(player.vis, player.global_position.y)) < 0.2, "with its feet on the floor (%.3f m)" % _feet(player.vis, player.global_position.y))
	player.set_model(mine)
	_foot0 = keep[0]
	_hip0 = keep[1]
	_swing0 = keep[2]
	await _grounded("body swapped and swapped back")

func _seam() -> void:
	print("== across a seam into a built area")
	var root := Node3D.new()
	add_child(root)
	remove_child(area)
	root.add_child(area)
	Game.world_root = root
	await _stride()
	var sp: Array = (DB.area_def("saltfell_steading").get("start", {}) as Dictionary).get("pos", [0, 0.2, 0])
	player.invulnerable = true
	Game.travel_to("saltfell_steading", Vector3(sp[0], float(sp[1]) + 0.2, sp[2]))
	# (a streamed crossing is not instant: the steading is built behind the
	# black first, from an empty cache here; ADR 0014)
	var t0 := Time.get_ticks_msec()
	while not (Game.current_area_id == "saltfell_steading" and player.input_enabled) and Time.get_ticks_msec() - t0 < 180000:
		await ticks(5)
	area = Game.current_area
	await ticks(90)
	check(Game.current_area_id == "saltfell_steading" and player.is_on_floor(), "he stands in the steading")
	player.sim_move = Vector3.ZERO
	await ticks(30)
	var v := player.vis
	check(player.state == Player.S.MOVE and player.input_enabled, "seam: S.MOVE with control")
	check(absf(_feet(v, player.global_position.y) - _foot0) < TOL and v.position.is_equal_approx(_vis_pos0),
		"seam: feet on the ground (%+.3f m)" % (_feet(v, player.global_position.y) - _foot0))
	check(v.current_clip() == "idle" and v.rig.action_clip() == "", "seam: the gait's idle owns the rig (action '%s')" % v.rig.action_clip())
	# real ground: steer whichever way is open, only the stride matters
	var best := 0.0
	var lift := 0.0
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var from := player.global_position
		var lo := INF
		var hi := -INF
		player.cam.yaw = yaw
		player.sim_move = Vector3(0, 0, -1)
		for i in 50:
			await ticks(1)
			if i >= 16:
				var y := v.bone_xform(FEET[0]).origin.y - player.global_position.y
				lo = minf(lo, y)
				hi = maxf(hi, y)
		var d := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
		if d > best:
			best = d
			lift = hi - lo
		if d > 1.5:
			break
	player.sim_move = Vector3.ZERO
	check(best > 1.5 and lift > _swing0 * 0.5 and v.rig.action_clip() == "", "seam: walking, the stride cycles (%.1f m, lift %.2f m)" % [best, lift])
	await ticks(30)
	player.stamina = player.max_stamina
	check(player.try_attack(false), "seam: a swing starts")
	await _until(func(): return player.state == Player.S.MOVE, 240)

# ------------------------------------------------------------------ the frost-taken
func _spawn(id: String, pos: Vector3, pose := "") -> Enemy:
	var ecfg: Dictionary = DB.table("enemies").get(id, {})
	var e: Enemy = load(ecfg["class"]).new() if ecfg.has("class") else Enemy.new()
	e.setup(id)
	e.idle_pose = pose
	add_child(e)
	e.global_position = pos
	e.home = pos
	e.max_hp = 99999.0
	e.hp = 99999.0
	return e

## A foe stands on its floor, at rest, with no clip stuck on it.
func _foe_grounded(e: Enemy, what: String, foot0: float, hip0: float) -> void:
	var v := e.vis
	check(v.position.is_zero_approx() and v.scale.is_equal_approx(Vector3.ONE) and v.body.position.is_zero_approx(),
		"%s: its visual is at rest (pos %s)" % [what, v.position])
	check(absf(_feet(v, e.global_position.y) - foot0) < TOL and absf(_hips(v, e.global_position.y) - hip0) < TOL,
		"%s: feet on the ground (feet %+.3f m, hips %+.3f m off idle)" % [what, _feet(v, e.global_position.y) - foot0, _hips(v, e.global_position.y) - hip0])
	check(v.rig.action_clip() == "" and v.current_clip() in ["idle", "walk", "run"],
		"%s: the gait owns the rig (clip '%s', action '%s')" % [what, v.current_clip(), v.rig.action_clip()])

func _foes() -> void:
	print("== the frost-taken: staggered, interrupted, roused from a chore, respawned")
	player.sim_move = Vector3.ZERO
	player.invulnerable = true
	var base := player.global_position
	# a statue far from the Bearer gives the standing measures
	var e := _spawn("rimewalker", base + Vector3(3, 0.1, 0))
	check(e.vis.is_humanoid(), "a rimewalker wears a humanoid body")
	e.set_physics_process(false)
	await ticks(40)
	var foot0 := _feet(e.vis, e.global_position.y)
	var hip0 := _hips(e.vis, e.global_position.y)
	print("  (rimewalker at rest: feet %.3f m, hips %.3f m)" % [foot0, hip0])
	check(absf(foot0) < 0.2 and hip0 > 0.5, "it stands on the floor")

	e.set_physics_process(true)
	e._stagger()
	await ticks(10)
	check(e.state == Enemy.ES.STAGGER and e.vis.current_clip() == "stagger", "it staggers")
	await _until(func(): return e.state != Enemy.ES.STAGGER, 300)
	e.set_physics_process(false)
	e.velocity = Vector3.ZERO
	e.vis.locomotion(0.016, 0.0)
	await ticks(50)
	await _foe_grounded(e, "foe after a stagger", foot0, hip0)

	e.set_physics_process(true)
	e.target = player
	var atk: Dictionary = (e.cfg.get("attacks", []) as Array)[0] if not (e.cfg.get("attacks", []) as Array).is_empty() else {}
	if atk.is_empty():
		atk = e._pick_attack(1.0)
	if not atk.is_empty():
		e._begin_attack(atk)
		await ticks(6)
		check(e.state == Enemy.ES.ATTACK, "it winds up a blow")
		e._stagger()
		await _until(func(): return e.state != Enemy.ES.STAGGER, 300)
		e.set_physics_process(false)
		e.velocity = Vector3.ZERO
		for i in 50:
			e.vis.locomotion(0.016, 0.0)
			await ticks(1)
		await _foe_grounded(e, "foe after an interrupted attack", foot0, hip0)
	e.queue_free()

	# a sitter: roused by a blow, it must be on its feet when it comes
	var s := _spawn("rimewalker", base + Vector3(-3, 0.1, 0), "sit")
	await ticks(20)
	if s.vis.rig.action_clip() != "":
		check(_hips(s.vis, s.global_position.y) < hip0 - 0.15, "a sitter sits (hips %.2f m)" % _hips(s.vis, s.global_position.y))
		s.take_hit(DamagePacket.new(1.0, 0.0, player))
		await _until(func(): return s.state == Enemy.ES.APPROACH or s.state == Enemy.ES.COMBAT or s.state == Enemy.ES.ATTACK, 400)
		s.set_physics_process(false)
		s.velocity = Vector3.ZERO
		for i in 60:
			s.vis.locomotion(0.016, 0.0)
			await ticks(1)
		await _foe_grounded(s, "sitter roused by a blow", foot0, hip0)
		s.queue_free()

		# staggered where it sits
		var s2 := _spawn("rimewalker", base + Vector3(-3, 0.1, 3), "sit")
		await ticks(20)
		var pk := DamagePacket.new(1.0, 9999.0, player)
		s2.take_hit(pk)
		check(s2.state == Enemy.ES.STAGGER, "a sitter is staggered where it sits")
		await _until(func(): return s2.state != Enemy.ES.STAGGER and s2.state != Enemy.ES.ALERT, 500)
		await ticks(20)
		s2.set_physics_process(false)
		s2.velocity = Vector3.ZERO
		for i in 60:
			s2.vis.locomotion(0.016, 0.0)
			await ticks(1)
		await _foe_grounded(s2, "sitter staggered in its seat", foot0, hip0)
		s2.queue_free()
	else:
		print("  (this rimewalker has no sit clip)")
		s.queue_free()

	# a respawn hands back a fresh body on the floor
	var sp := Spawner.new()
	sp.enemy_id = "rimewalker"
	add_child(sp)
	sp.global_position = base + Vector3(4, 0.1, 4)
	await ticks(10)
	var first: Enemy = sp.current
	if first != null:
		first.take_hit(DamagePacket.new(999999.0, 10.0, player))
		await ticks(20)
	sp.respawn()
	await ticks(5)
	var r: Enemy = sp.current
	check(r != null and r != first and not r.dead, "the spawner raises it again")
	if r != null:
		r.set_physics_process(false)
		await ticks(50)
		await _foe_grounded(r, "foe after a respawn", foot0, hip0)
