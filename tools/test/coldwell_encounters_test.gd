extends TestBase
## The Coldwell's encounters (COLDWELL.md 5-9). In the arena sandbox: the
## Upwalker standing in the way, its shoulder and its fall; the Unsung, which
## any Song breaks; the Leadvoice sat, her head coming up, the held note that
## stands as a wall, Shelter putting the Bearer out of reach, Not yet (the
## Unsung stand up between them), the long note with nothing close to her,
## her standing up, a blade that no longer counts, three verses (one broken
## by a blow), and her sitting down again. She never opens a hand volume.
## On the Coldwell itself: Maren and Wren at the remembered Melt, the horn's
## new text at the wellhead, the knucklebones shown, the release (flag, card,
## no Outsong, the band and the mask) and the choice opening.

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
	at.y = 0.1
	if player.dead:
		player.revive_at(at)
		await _secs(1.5)
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.hp = player.max_hp
	player.lock_control(false)

func _ready_foe(e: Enemy) -> void:
	e.target = player
	for a in e.cfg.get("attacks", []):
		e._cooldowns[String(a["id"])] = 99.0
	e._set_state(Enemy.ES.COMBAT)

func _tells() -> int:
	return arena.find_children("*", "FloorTelegraph", true, false).size()

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
	await _upwalker()
	await _unsung()
	await _leadvoice()
	arena.queue_free()
	await ticks(5)
	await _coldwell()
	finish()

# ------------------------------------------------------------------ Upwalker
func _upwalker() -> void:
	print("== the Upwalker: in the way")
	await _ready_player(Vector3(0, 0.1, 2.0))
	var u := _spawn("upwalker", Vector3(0, 0.1, 0), 180.0)
	await ticks(8)
	check(u.vis.is_humanoid() and u.vis.model_id == "upwalker", "the upwalker.glb body")
	check(float(u.cfg["speed"]) < 1.5 and u.cfg.has("block_arc"), "slow, and it stands side-on to whoever comes")
	_face_player(u.global_position)
	_ready_foe(u)
	await ticks(2)
	var sh := u.attack_by_id("shoulder")
	var hp0 := player.hp
	var z0 := player.global_position.z
	u._begin_attack(sh)
	await _secs(float(sh["windup"]) + 0.6)
	check(player.hp < hp0 and player.hp > hp0 - 20.0, "the shoulder hurts little (%.0f -> %.0f)" % [hp0, player.hp])
	check(player.global_position.z > z0 + 1.5, "and puts him back down the path (%.1f m)" % (player.global_position.z - z0))
	await _secs(1.4)

	print("== the fall")
	u.global_position = Vector3(0, 0.1, 0)
	await _ready_player(Vector3(0, 0.1, 2.6))
	u.vis.rotation.y = PI
	_ready_foe(u)
	await ticks(2)
	var ff := u.attack_by_id("fall_forward")
	hp0 = player.hp
	u._begin_attack(ff)
	await _secs(float(ff["windup"]) * 0.85)
	check(_tells() > 0, "a strip glows its own length")
	await _secs(float(ff["windup"]) * 0.15 + float(ff["active"]) + 0.1)
	check(player.hp < hp0 - 25.0, "it goes over on him (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.2)
	check(u.state == Enemy.ES.ATTACK, "and lies there: open")
	u.free()
	await _secs(1.0)

# ------------------------------------------------------------------ the Unsung
func _unsung() -> void:
	print("== the Unsung: thin clear ice")
	await _ready_player(Vector3(0, 0.1, 0.95))
	var a := _spawn("unsung", Vector3(0, 0.1, 0), 180.0)
	await ticks(8)
	check(a.vis.is_humanoid() and a.vis.model_id == "unsung", "the unsung.glb body")
	_face_player(a.global_position)
	_ready_foe(a)
	await ticks(2)
	var rc := a.attack_by_id("reach")
	var hp0 := player.hp
	a._begin_attack(rc)
	await _secs(float(rc["windup"]) + float(rc["active"]) + 0.15)
	check(player.hp < hp0, "it reaches (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.6)
	a._end_all_swings()
	a._set_state(Enemy.ES.COMBAT)
	var blow := DamagePacket.new(5, 0, player)
	a.take_hit(blow)
	check(not a.dead, "a small blow does not end it")
	var note := DamagePacket.new(5, 0, player)
	note.kind = "ember"   # (every Song the Bearer has)
	a.take_hit(note)
	check(a.dead, "any Song breaks it")
	await _secs(1.4)
	check(not is_instance_valid(a), "and it is gone quickly")
	player.inventory["ember_throw"] = 1
	check(DB.song("ember_throw").get("type", "") == "blast", "(the Bearer's songs strike as ember)")

# ------------------------------------------------------------------ the Leadvoice
func _ridges() -> Array:
	return get_tree().get_nodes_in_group("ice_ridges").filter(func(r): return is_instance_valid(r) and not r.is_queued_for_deletion())

func _hands_shut(l: Leadvoice) -> bool:
	return not l.hitbox.monitoring and (l.fist_hitbox == null or not l.fist_hitbox.monitoring) \
			and (l.blade_hitbox == null or not l.blade_hitbox.monitoring)

func _leadvoice() -> void:
	print("== the Leadvoice: sat, bent over the child")
	await _ready_player(Vector3(0, 0.1, 15))
	player.invulnerable = true
	var l: Leadvoice = _spawn("leadvoice", Vector3(0, 0.1, -4), 180.0)
	await ticks(30)
	check(l.vis.is_humanoid() and l.vis.model_id == "leadvoice", "the leadvoice.glb body")
	check(l.state == Enemy.ES.IDLE and not l.stood and l.is_seated_pose(), "sat (%s)" % l.vis.current_clip())
	check(l.vis.rig.action_time() < 0.05, "her rising clip held at its first frame")
	var own := ["hold_note", "rise", "shelter"].filter(func(c):
		return l.vis.rig.has_clip(c) and not l.vis.rig.clip_anim(c).has_meta("procedural"))
	check(own.size() == 3, "her own clips (%s)" % str(own))
	check(l.cfg["attacks"].all(func(a): return String(a.get("type", "melee")) in ["line", "sweep", "summon"]),
		"nothing in her data is a blow")
	var hud: HUD = arena.find_children("*", "HUD", true, false)[0]
	player.global_position = l.global_position + Vector3(0, 0, 9.0)
	await ticks(6)
	check(l.state == Enemy.ES.TRANSITION, "within 10 m she lifts her head")
	await _secs(2.9)
	check(l.stood and hud.boss_root.visible and hud.boss_name.text == "THE LEADVOICE", "the bar: THE LEADVOICE")
	check(not l.standing and Vector2(l.global_position.x, l.global_position.z + 4.0).length() < 0.3, "she has not got up, or moved")
	var p1 := l.repertoire()
	check("held_note" in p1 and "shelter" in p1 and "not_yet" in p1 and not ("long_note" in p1), "phase one: held note, shelter, not yet")

	print("== the held note: the air freezes and stands")
	player.invulnerable = false
	await _ready_player(l.global_position + Vector3(0, 0, 8.0))
	_ready_foe(l)
	await ticks(2)
	var hn := l.attack_by_id("held_note")
	var hp0 := player.hp
	l._begin_attack(hn)
	check(l.is_seated_pose(), "she stays sat to hold it")
	await _secs(float(hn["windup"]) * 0.85)
	check(_tells() > 0, "a strip glows from her to him")
	await _secs(float(hn["windup"]) * 0.15 + 0.2)
	check(player.hp < hp0, "the note reaches him (%.0f -> %.0f)" % [hp0, player.hp])
	check(_ridges().size() == 1, "and a wall of rime stands where it went (%d)" % _ridges().size())
	check(_hands_shut(l), "no hand was opened")
	for r in _ridges():
		(r as IceRidge).shatter()
	await _secs(1.6)

	print("== shelter: put out of reach")
	await _ready_player(l.global_position + Vector3(0, 0, 2.2))
	_ready_foe(l)
	await ticks(2)
	var sh := l.attack_by_id("shelter")
	hp0 = player.hp
	l._begin_attack(sh)
	await _secs(float(sh["windup"]) + 0.6)
	var out := Vector2(player.global_position.x - l.global_position.x, player.global_position.z - l.global_position.z).length()
	check(out > 4.5, "the Bearer is put out to the edge (%.1f m)" % out)
	check(hp0 - player.hp <= 10.0, "hardly hurt (%.0f -> %.0f)" % [hp0, player.hp])
	check(_hands_shut(l), "no hand was opened")
	await _secs(1.4)

	print("== not yet: the Unsung stand up between them")
	await _ready_player(l.global_position + Vector3(0, 0, 10.0))
	_ready_foe(l)
	await ticks(2)
	var ny := l.attack_by_id("not_yet")
	l._begin_attack(ny)
	await _secs(float(ny["windup"]) + 0.3)
	var up := l.dead_up("unsung")
	check(up.size() == 2, "two of them (%d)" % up.size())
	if up.size() == 2:
		var mid: Vector3 = ((up[0] as Enemy).global_position + (up[1] as Enemy).global_position) * 0.5
		check(mid.z > l.global_position.z + 2.0 and mid.z < player.global_position.z - 1.0, "between her and the Bearer")
	check(not l._attack_usable(ny), "she does not call more while two stand")
	for m in l.dead_up():
		(m as Enemy).free()
	await _secs(1.0)

	print("== her head comes up")
	player.invulnerable = true
	l._end_all_swings()
	l._set_state(Enemy.ES.COMBAT)
	l.take_hit(DamagePacket.new(l.max_hp * 0.42, 0, player))
	await ticks(2)
	check(l.phase == 2 and l.state == Enemy.ES.TRANSITION, "at 60%")
	await _secs(2.7)
	check(l.dead_up("unsung").size() == 2 and not l.standing, "two more of the Unsung; she is still sat")
	for m in l.dead_up():
		(m as Enemy).free()
	var p2 := l.repertoire()
	check("long_note" in p2 and "come_up" in p2, "long note, come up")

	print("== the long note: nothing close to her")
	player.invulnerable = false
	await _ready_player(l.global_position + Vector3(0, 0, 8.0))
	_ready_foe(l)
	await ticks(2)
	var ln := l.attack_by_id("long_note")
	hp0 = player.hp
	l._begin_attack(ln)
	await _secs(float(ln["windup"]) + 0.4)
	check(player.hp < hp0, "out in the band it freezes him through (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.6)
	await _ready_player(l.global_position + Vector3(0, 0, 3.6))
	_ready_foe(l)
	hp0 = player.hp
	l._begin_attack(ln)
	await _secs(float(ln["windup"]) + 0.4)
	check(player.hp == hp0, "stood close to her there is nothing")
	await _secs(1.6)
	l._end_all_swings()
	l._set_state(Enemy.ES.COMBAT)
	l._begin_attack(l.attack_by_id("come_up"))
	await _secs(float(l.attack_by_id("come_up")["windup"]) + 0.3)
	check(l.dead_up("upwalker").size() == 1, "an Upwalker comes in by the gap")
	for m in l.dead_up():
		(m as Enemy).free()

	print("== she stands up")
	player.invulnerable = true
	l._end_all_swings()
	l._set_state(Enemy.ES.COMBAT)
	l.take_hit(DamagePacket.new(l.hp, 0, player))   # (however hard the blow)
	await ticks(2)
	check(not l.dead and l.phase == 3 and l.state == Enemy.ES.TRANSITION, "at 25%, and no blow takes her past it")
	check(not l.sing_zone.enabled, "there is nothing to sing to yet")
	await _secs(4.3)
	check(l.standing and l.sing_zone.enabled and l.sing_zone.prompt == "Sing", "on her feet for the first time: Sing")
	var hp3 := l.hp
	check(absf(hp3 - l.max_hp * 0.25) < 1.0, "a quarter of her left (%.0f)" % hp3)
	l.take_hit(DamagePacket.new(900, 0, player))
	check(l.hp == hp3 and not l.dead, "a blade no longer counts")

	print("== three verses")
	player.invulnerable = false
	var sung := []
	l.verse_sung.connect(func(n): sung.append(n))
	var broken := [0]
	l.verse_broken.connect(func(): broken[0] += 1)
	await _ready_player(l.global_position + Vector3(0, 0, 3.8))
	_ready_foe(l)
	l.begin_verse(player)
	check(l.singing and not player.input_enabled, "the Bearer stands and sings, hands down")
	await _secs(0.8)
	player.take_hit(DamagePacket.new(5, 0, l))
	await ticks(3)
	check(not l.singing and broken[0] == 1 and sung.is_empty() and l.hp == hp3, "a blow breaks the verse")
	check(player.input_enabled and l.sing_zone.enabled, "and he may begin again")
	player.hp = player.max_hp
	var u1 := _spawn("unsung", l.global_position + Vector3(3, 0, 3), 0.0)
	l._minions.append(u1)
	await ticks(4)
	l.begin_verse(player)
	await _secs(float(l.cfg["verse_time"]) + 0.2)
	check(sung == [1] and absf(l.hp - hp3 * 2.0 / 3.0) < 1.0, "one verse: a third of what was left (%.0f)" % l.hp)
	check(u1.dead, "the Unsung near enough to hear it is sung too")
	check(l.state == Enemy.ES.HOLD and l.vis.current_clip() == "shelter", "she bows her head over the child")
	await _secs(float(l.cfg["verse_bow"]) + 0.3)
	check(l.state != Enemy.ES.HOLD and l.sing_zone.enabled, "and lifts it")
	_ready_foe(l)
	l.begin_verse(player)
	await _secs(float(l.cfg["verse_time"]) + 0.2)
	await _secs(float(l.cfg["verse_bow"]) + 0.3)
	_ready_foe(l)
	check(sung == [1, 2] and not l.dead, "two")
	l.begin_verse(player)
	await _secs(float(l.cfg["verse_time"]) + 0.3)
	check(sung == [1, 2, 3] and l.released and l.dead, "three: she is released")
	await _secs(2.8)
	check(l.is_seated_pose() or l.vis.current_clip() == "rise", "she sits down again (%s)" % l.vis.current_clip())
	check(_ridges().is_empty(), "nothing of hers is left standing")
	check(int(l.cfg.get("warmth", 1)) == 0, "there is no warmth to be had of her")
	check(player.input_enabled, "the Bearer has his hands back")
	l.free()
	await ticks(3)

# ------------------------------------------------------------------ the Coldwell
var area: Area

func _talk(npc_id: String) -> DialogueUI:
	var cfg := DB.npc(npc_id)
	cfg["id"] = npc_id
	var ui := DialogueUI.new(cfg, null)
	get_tree().root.add_child(ui)
	return ui

func _all_lines(ui: DialogueUI) -> Array:
	var out := []
	while ui._phase == "lines" and ui._line_i < ui._lines.size():
		out.append(ui.text_label.text)
		ui.advance()
	return out

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
			return (t["steps"] as Array).slice(0, n).map(func(s): return String(s["line"]))
	return []

func _pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id and not p.is_queued_for_deletion():
			return p
	return null

func _npcs() -> Dictionary:
	var out := {}
	for c in area.find_children("*", "NPC", true, false):
		if (c as NPC).is_visible_in_tree():
			out[(c as NPC).npc_id] = c
	return out

func _build(id: String, state: RH.WState) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	World.set_area_state(id, state)
	area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	StateDirector.snap(area, state)
	await ticks(10)


func _coldwell() -> void:
	World._save_dir = "user://test_coldwell_enc"
	World.reset()
	Game.set_warmth(0)
	await _build("coldwell", RH.WState.THAW)
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	player.invulnerable = true
	var hud := HUD.new()
	add_child(hud)
	await ticks(10)

	print("== the thaw: the last Melt")
	var seen := _npcs()
	check(seen.has("maren") and seen.has("wren"), "Maren and Wren at the water")
	var maren: NPC = seen.get("maren")
	var wren: NPC = seen.get("wren")
	check(maren != null and maren._vis.model_id == "maren_thaw" and wren != null and wren._vis.model_id == "wren",
		"on their own models (maren_thaw, wren)")
	var before := String(DB.item("fostering_horn")["desc"])
	check(before.begins_with("A cow's horn") and not World.flag("ks_horn_wellhead"), "the horn, as it has read since Saltfell")
	player.global_position = maren.global_position + Vector3(0, 0.3, 2.0)
	await _secs(1.2)
	check(World.flag("ks_horn_wellhead"), "at the wellhead (ks_horn_wellhead)")
	var after := String(DB.item("fostering_horn")["desc"])
	check(after.begins_with("The horn a child carries down the water.") and after.ends_with("the instruction was followed."),
		"the horn reads differently here")
	check(_lines_of("fostering_horn") == _expected("fostering_horn", 1), "the coal is still alight")
	var ui := _talk("maren")
	await ticks(2)
	check(ui.text_label.text.begins_with("Have you come far?"), "Maren takes the Bearer for a stranger")
	await _close(ui)
	ui = _talk("maren")
	await ticks(2)
	var told := _all_lines(ui)
	check(told.size() == 3 and String(told[1]) == "I said, keep it fed. As if anyone needs telling.", "a second audience: the older one, down the water")
	await _close(ui)
	ui = _talk("wren")
	await ticks(2)
	check(ui.text_label.text == "That one's going to the sea." and not World.flag("ks_knucklebones_shown"), "Wren watches the flowers")
	await _close(ui)
	World.set_flag("ks_knucklebones_found")
	World.set_flag("ks_knucklebone_found")
	player.give_item("ks_knucklebones", 1)
	player.give_item("item_knucklebone", 1)
	ui = _talk("wren")
	await ticks(2)
	check(World.flag("ks_knucklebones_shown") and ui.text_label.text == "I've got some like that.", "shown the five, she knows them")
	await _close(ui)
	check(_lines_of("knucklebones") == _expected("knucklebones", 3), "Knucklebones: three lines, in order")
	check(int(player.inventory.get("item_knucklebone", 0)) == 1, "she does not take them")

	print("== the rime: the dead in the river, the Leadvoice at the wellhead")
	await _build("coldwell", RH.WState.RIME)
	var kinds := {}
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead):
		kinds[(e as Enemy).id] = true
	check(kinds.has("upwalker") and kinds.has("unsung") and kinds.has("leadvoice") and not kinds.has("rimewalker")
		and not kinds.has("keener") and not kinds.has("netmender"), "the Coldwell's own, no stand-ins (%s)" % str(kinds.keys()))
	var lv: Leadvoice = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Leadvoice and e.can_process():
			lv = e
	check(lv != null and lv.is_seated_pose(), "she is sat at the wellhead")
	var ec: Node = get_tree().get_nodes_in_group("ending_choice").filter(func(c): return area.is_ancestor_of(c))[0]
	ec.run_endings = false
	check(not ec.is_open(), "nothing is offered at the spring yet")
	check(ec.spring_point().distance_to(lv.global_position) < 6.0, "the spring is between the gap and her (%.1f m)" % ec.spring_point().distance_to(lv.global_position))

	print("== the release")
	var cards := []
	var on_card := func(t: String, _h: float): cards.append(t)
	Game.title_card.connect(on_card)
	player.global_position = lv.global_position + Vector3(0.0, 0.3, 3.6)   # (beside her; the wellhead itself is to her front)
	await ticks(4)
	lv.take_hit(DamagePacket.new(10, 0, player))
	await _secs(2.9)
	var guard := 0
	while not lv.standing and guard < 6:
		guard += 1
		lv.take_hit(DamagePacket.new(900, 0, player))
		await _secs(4.4 if lv.phase == 3 else 2.8)
	check(lv.standing and lv.phase == 3, "she stands")
	for i in 3:
		lv._set_state(Enemy.ES.COMBAT)
		for a in lv.cfg.get("attacks", []):
			lv._cooldowns[String(a["id"])] = 99.0
		for m in lv.dead_up():
			(m as Enemy)._die()
		lv.sing_zone.enabled = true
		lv.begin_verse(player)
		await _secs(float(lv.cfg["verse_time"]) + 0.2)
		if not lv.released:
			await _secs(float(lv.cfg["verse_bow"]) + 0.3)
	await _secs(1.5)
	Game.title_card.disconnect(on_card)
	check(lv.released and World.flag("ks_leadvoice_released"), "she is released (ks_leadvoice_released)")
	check("MAREN — RELEASED" in cards, "the card has her name on it")
	check(World.is_cleared("coldwell"), "the Coldwell is cleared")
	var band := _pickup("wren_band")
	var mask := _pickup("maren_mask")
	check(band != null and mask != null and band.global_position.distance_to(mask.global_position) < 2.5, "the band and the mask, set down side by side")
	if band != null:
		band._on_take(player)
	if mask != null:
		mask._on_take(player)
	check(int(player.inventory.get("item_wren_band", 0)) == 1 and int(player.inventory.get("item_maren_mask", 0)) == 1, "the Bearer takes both")
	check(String(DB.item("item_maren_mask")["desc"]).ends_with("This one is fifteen winters old."), "the mask was never burned")
	await ticks(4)
	check(ec.is_open(), "and now the spring offers its two things")
	check(ec._outsong.prompt == "Lay the coal in the spring" and ec._kept.prompt == "Keep the horn shut, and sit", "the two prompts")
	player.invulnerable = false
