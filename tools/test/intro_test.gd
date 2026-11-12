extends TestBase
## The opening (docs/lore/INTRO.md, src/core/intro_director.gd), through the
## real front door: it plays once on a new journey, after the winter is
## chosen; every card comes up in order while the HUD is away and the Bearer
## is held; the frost wave and the melt are shown and neither is kept; it
## hands over on the Strand in THAW exactly as a journey began before it; a
## load never plays it; a new journey on another hearth does; and it can be
## let go at any card.
##
## Optional: --intro-shots=DIR holds each card and captures it as
## intro_NN_<id>.png (needs a renderer: tools/qa/intro_shots.sh).

const AID := "saltfell_steading"
var world: Node3D
var shots_dir := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--intro-shots="):
			shots_dir = a.get_slice("=", 1)
	if shots_dir != "":
		Engine.max_physics_steps_per_frame = 30
	_run.call_deferred()

func _secs(s: float):
	await ticks(int(s * 60.0))

func _until(cond: Callable, max_s := 20.0) -> bool:
	var n := 0
	var t0 := Time.get_ticks_msec()
	while not cond.call() and (n < int(max_s * 60.0) or Time.get_ticks_msec() - t0 < int(max_s * 1000.0)):
		await ticks(5)
		n += 5
	return cond.call()

func _child_of_type(parent: Node, script_path: String) -> Node:
	for c in parent.get_children():
		if c.get_script() != null and (c.get_script() as Script).resource_path == script_path:
			return c
	return null

func _wait_child(script_path: String, max_s: float) -> Node:
	await _until(func(): return _child_of_type(world, script_path) != null, max_s)
	return _child_of_type(world, script_path)

func _hud() -> HUD:
	return get_tree().get_first_node_in_group("hud") as HUD

func _intro() -> IntroDirector:
	return IntroDirector.active

func _cards() -> Array:
	return (DB.tuning("intro/beats", []) as Array).map(func(b): return String(b["text"]))

func _ids() -> Array:
	return (DB.tuning("intro/beats", []) as Array).map(func(b): return String(b["id"]))

## From the title: New journey on `slot` (1..3), the winter at row `diff_i`.
## Returns once the Bearer stands in the world (the intro, if any, running).
func _new_journey(title: Node, slot: int, diff_i: int) -> bool:
	var buttons: Array = title._main_box.get_children().filter(func(c): return c is Button)
	var names: Array = buttons.map(func(b): return b.text)
	buttons[names.find("New journey")].pressed.emit()
	await ticks(4)
	var slots: Array = title._slots_box.get_children().filter(func(c): return c is Button)
	slots[slot - 1].pressed.emit()
	var diff: Node = await _wait_child("res://src/ui/difficulty_ui.gd", 90.0)
	if diff == null:
		return false
	await ticks(4)
	diff._opt_i = diff_i
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = down
		get_tree().root.push_input(ev)
	return await _until(func(): return Game.player != null and is_instance_valid(Game.player), 60.0)

func _to_title() -> Node:
	PauseUI.open()
	await ticks(3)
	var pb: Array = PauseUI._pages["main"].get_children().filter(func(c): return c is Button)
	var titles: Array = pb.map(func(b): return b.text)
	pb[titles.find("Return to the Title")].pressed.emit()
	return await _wait_child("res://src/ui/title_screen.gd", 90.0)

## What must hold the moment the intro hands over (sat through or skipped).
func _handed_over(label: String, start: Vector3) -> void:
	var p := Game.player as Player
	var hud := _hud()
	check(_intro() == null or _intro().done, "%s: the intro is over" % label)
	check(p != null and p.input_enabled and not p.invulnerable and p.state == Player.S.MOVE,
		"%s: the Bearer has control, on his feet" % label)
	check(p != null and p.global_position.distance_to(start) < 1.0, "%s: on the Strand, where a journey begins (%s)" % [label, str(p.global_position.snapped(Vector3.ONE * 0.1)) if p != null else "?"])
	check(p != null and (p.cam.cam as Camera3D).current, "%s: his own camera is back" % label)
	check(hud != null and hud.visible, "%s: the HUD is up" % label)
	check(World.get_area_state(AID) == RH.WState.THAW and (Game.current_area as Area)._applied == RH.WState.THAW
			and is_zero_approx(StateDirector.state_blend) and not StateDirector.transitioning,
		"%s: Saltfell is in THAW, nothing turning" % label)
	var foes: Array = get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(
			func(e): return is_instance_valid(e) and e.is_inside_tree() and e.can_process() and not e.dead)
	check(foes.is_empty(), "%s: no frost-taken stand (%d)" % [label, foes.size()])
	check(not World.area_flag(AID, "lit_hs_salt_house") and String(World.last_hearth.get("hearth", "")) == "",
		"%s: the hearth it showed is not lit or kept" % label)
	check(World.flag(IntroDirector.FLAG), "%s: the journey remembers it has seen it" % label)

var _shot_i := 0
func _shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_shot_i += 1
	var path := "%s/intro_%02d_%s.png" % [shots_dir, _shot_i, id]
	get_viewport().get_texture().get_image().save_png(path)
	print("  [shot] ", path)

func _run() -> void:
	World._save_dir = "user://test_intro" + ("_shots" if shots_dir != "" else "")
	for i in range(1, World.SLOTS + 1):
		World.delete_slot(i)
	World.reset()
	Game.set_warmth(0)
	Game.front_door = true
	check(_cards().size() == 9 and _cards().all(func(t): return String(t).length() > 20 and String(t).length() < 200),
		"nine short cards in the data")

	print("== the front door: card, title, a new journey, the winter")
	world = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	add_child(world)
	await _until(func(): return _child_of_type(world, "res://src/ui/house_card.gd") != null, 30.0)
	await _secs(1.0)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	get_tree().root.push_input(key)
	var title: Node = await _wait_child("res://src/ui/title_screen.gd", 240.0)
	check(title != null, "the title rises")
	if title == null:
		finish()
		return
	check(_intro() == null, "nothing plays before a journey is chosen")
	var began := await _new_journey(title, 1, 2)
	check(began, "a new journey on Hearth I, The Hard Frost")
	if not began:
		finish()
		return
	check(Game.difficulty == "hard", "the winter chosen holds (%s)" % Game.difficulty)
	var p := Game.player as Player
	var start: Vector3 = AreaBuilder._v3((Game.current_area as Area).get_meta("def")["start"]["pos"])

	if shots_dir != "":
		await _shots()
		finish()
		return

	print("== the intro, sat through")
	check(await _until(func(): return _intro() != null, 5.0), "the intro begins once the Bearer stands in the world")
	var intro := _intro()
	if intro == null:
		finish()
		return
	var hud := _hud()
	check(World.flag(IntroDirector.FLAG), "its flag is raised as it begins")
	check(not p.input_enabled and p.invulnerable, "the Bearer is held, and nothing can still him")
	check(await _until(func(): return intro.cam != null and intro.cam.current, 3.0), "it takes a camera of its own")
	check(hud != null and hud.last_title == "", "no place is named yet")
	var hud_seen := false
	var blend_max := 0.0
	var rime_applied := false
	var world_said_rime := false
	var foes_moved := 0
	var prompt_max := 0.0
	var cam_low := false
	var texts := {}
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(intro) and not intro.done:
		if intro.card_text != "" and intro.card_alpha() > 0.9:
			texts[intro.card_text] = true
		hud_seen = hud_seen or (hud != null and hud.visible)
		blend_max = maxf(blend_max, StateDirector.state_blend)
		rime_applied = rime_applied or (Game.current_area as Area)._applied == RH.WState.RIME
		world_said_rime = world_said_rime or World.get_area_state(AID) == RH.WState.RIME
		prompt_max = maxf(prompt_max, intro.prompt_alpha())
		for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
			if is_instance_valid(e) and (e as Enemy).target != null:
				foes_moved += 1
		if intro.cam != null and is_instance_valid(intro.cam) and intro.cam.global_position.y < 1.0:
			cam_low = true
		await ticks(4)
		if Time.get_ticks_msec() - t0 > 240000:
			break
	check(is_instance_valid(intro) and intro.done and not intro.skipped, "it runs to its end by itself")
	check(intro.beats == _ids(), "every beat, in order (%s)" % str(intro.beats))
	var missing: Array = _cards().filter(func(t): return not texts.has(t))
	check(missing.is_empty(), "every card came up whole (%d missing)" % missing.size())
	check(not hud_seen, "the HUD stays away throughout")
	check(blend_max > 0.99 and rime_applied, "the frost wave crosses Saltfell (blend %.2f)" % blend_max)
	check(not world_said_rime and not World.any_slot(), "and is not kept: the memory is not turned, nothing is saved")
	check(foes_moved == 0, "nothing frost-taken turns to the Bearer")
	check(is_zero_approx(prompt_max), "no skip prompt until a key is touched")
	check(not cam_low, "the camera never goes under the ground")
	await ticks(4)
	_handed_over("sat through", start)
	check(Game.difficulty == "hard" and World.flag_val("difficulty", "") == "hard", "the winter chosen still applies")
	await _until(func(): return hud.last_title == "THE STRAND", 12.0)
	check(hud.last_title == "THE STRAND", "then THE STRAND is named (%s)" % hud.last_title)
	check(await _until(func(): return _intro() == null, 6.0), "and the intro is gone")
	p.sim_active = true
	p.sim_move = Vector3(0, 0, -1)
	var from := p.global_position
	await _secs(1.0)
	p.sim_move = Vector3.ZERO
	check(p.global_position.distance_to(from) > 1.0, "the Bearer walks")

	print("== a load never plays it")
	title = await _to_title()
	check(title != null and title.has_save, "back at the title, a hearth to resume")
	if title == null:
		finish()
		return
	await _secs(1.0)
	var mb: Array = title._main_box.get_children().filter(func(c): return c is Button)
	mb[0].pressed.emit()
	await ticks(4)
	var sb: Array = title._slots_box.get_children().filter(func(c): return c is Button)
	sb[0].pressed.emit()
	check(await _until(func(): return Game.player != null and is_instance_valid(Game.player), 60.0), "the journey resumes")
	await _secs(1.5)
	p = Game.player
	check(_intro() == null and p.input_enabled and _hud().visible, "no intro on a load: control and the HUD at once")
	check(World.flag(IntroDirector.FLAG), "the save carries the flag")

	print("== a new journey on another hearth plays it; held, it lets go")
	title = await _to_title()
	if title == null:
		finish()
		return
	await _secs(1.0)
	began = await _new_journey(title, 2, 0)
	check(began and Game.difficulty == "gentle", "a new journey on Hearth II, The Gentle Thaw")
	check(await _until(func(): return _intro() != null, 5.0), "the intro plays for the new journey")
	intro = _intro()
	if intro == null:
		finish()
		return
	hud = _hud()
	# into the third card, mid-wave, then hold the key
	await _until(func(): return intro.beats.size() >= 3 and StateDirector.transitioning, 60.0)
	check(intro.beats.size() == 3 and StateDirector.transitioning, "three cards in, the frost wave running")
	var tap := InputEventKey.new()
	tap.keycode = KEY_W
	tap.pressed = true
	get_tree().root.push_input(tap)
	await _secs(0.6)
	check(intro.prompt_alpha() > 0.5 and intro._prompt.text == "Hold E to skip" and not intro.skipped,
		"any key shows the prompt, quietly, and skips nothing (%s)" % intro._prompt.text)
	Input.action_press("interact")
	await _secs(0.4)
	check(not intro.skipped, "a short press does not skip")
	await _until(func(): return intro.skipped, 3.0)
	Input.action_release("interact")
	check(intro.skipped, "held, it lets go")
	intro = null
	await _until(func(): return _intro() == null or _intro().done, 6.0)
	await ticks(4)
	_handed_over("skipped mid-wave", start)
	check(Game.difficulty == "gentle", "the winter chosen still applies after a skip")
	check(await _until(func(): return _hud().last_title == "THE STRAND", 12.0), "THE STRAND is named")
	check(not World.any_slot() or World.slot_summary(2) == null, "skipping saves nothing on the new hearth")
	await _until(func(): return _intro() == null, 6.0)

	print("== let go at each card")
	p = Game.player
	var area := Game.current_area as Area
	for k in _ids().size():
		World.flags.erase(IntroDirector.FLAG)
		var d := IntroDirector.begin(p, area, true)
		await ticks(3)
		for j in k:
			d.next()
			await ticks(3)
		var at_card := d.card_text
		var ok_card: bool = d.beats.size() == k + 1 and at_card == _cards()[k] and d.card_alpha() > 0.9
		d.skip()
		d = null
		await _until(func(): return _intro() == null or _intro().done, 6.0)
		await ticks(3)
		var hud2 := _hud()
		var back: bool = p.input_enabled and not p.invulnerable and p.state == Player.S.MOVE \
				and p.global_position.distance_to(start) < 1.0 and (p.cam.cam as Camera3D).current \
				and hud2.visible and area._applied == RH.WState.THAW and World.get_area_state(AID) == RH.WState.THAW \
				and is_zero_approx(StateDirector.state_blend)
		check(ok_card and back, "card %d (%s): up, let go, and the Strand handed back" % [k + 1, _ids()[k]])
		await _until(func(): return _intro() == null, 6.0)
	check(not IntroDirector.wanted(true), "seen: not wanted again on this journey")
	check(not IntroDirector.wanted(false), "never wanted on a load")

	Game.front_door = false
	for i in range(1, World.SLOTS + 1):
		World.delete_slot(i)
	finish()

## Each card held and captured (manual mode: the beat waits, the waves snap).
func _shots() -> void:
	await _until(func(): return _intro() != null, 30.0)
	var first := _intro()
	if first != null:
		first.skip()
		await _until(func(): return _intro() == null, 30.0)
	World.flags.erase(IntroDirector.FLAG)
	var d := IntroDirector.begin(Game.player, Game.current_area, true)
	for k in _ids().size():
		await _until(func(): return d.beats.size() == k + 1 and d.card_alpha() > 0.9, 30.0)
		for i in 6:
			await RenderingServer.frame_post_draw
		await _shot(_ids()[k])
		d.next()
	d.skip()
	await _until(func(): return _intro() == null, 30.0)
	Game.front_door = false
