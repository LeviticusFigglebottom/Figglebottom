extends TestBase
## Shepherd's Reach's encounters (REACH.md 5-9). In the arena sandbox: the
## Drover's crook, leg hook and whistle; the Frost-ram on its QuadRig, the
## charge and the kick at whoever is behind it; the Fellcaller's intro, three
## phases (and the moves each unlocks), the rising cry, the charge, the rams
## over the wall, the flock down a strip (and a cross of two), Count them, and
## her release. On the Reach itself: Calder's two audiences and the three
## notes, Sigga, the count overheard, the boots, both Keepsakes threads, the
## release (flag, card, the flock lying down now and on rebuild, the hearth,
## the fold-tally) and the scene after.

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
	await _drover()
	await _ram()
	await _fellcaller()
	arena.queue_free()
	await ticks(5)
	await _reach()
	finish()

# ------------------------------------------------------------------ Drover
func _drover() -> void:
	print("== the Drover: a crook of ice from both hands")
	await _ready_player(Vector3(0, 0.1, 2.4))
	var d := _spawn("drover", Vector3(0, 0.1, 0), 180.0)
	await ticks(8)
	check(d.vis.is_humanoid() and d.vis.model_id == "drover", "the drover.glb body")
	_face_player(d.global_position)
	_ready_foe(d)
	await ticks(2)
	var cs := d.attack_by_id("crook_sweep")
	var hp0 := player.hp
	d._begin_attack(cs)
	await _secs(float(cs["windup"]) + float(cs["active"]) + 0.15)
	check(player.hp < hp0, "the crook sweep lands (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.2)

	print("== leg hook: taken by the leg and pulled in")
	await _ready_player(d.global_position + Vector3(0, 0, 4.4))
	d.vis.rotation.y = PI
	_ready_foe(d)
	await ticks(2)
	var lh := d.attack_by_id("leg_hook")
	d._begin_attack(lh)
	await _secs(float(lh["windup"]) * 0.85)
	check(_tells() > 0, "a strip glows along the ground")
	await _secs(float(lh["windup"]) * 0.15 + 0.1)
	check(d.hook_hold != null, "the crook takes him by the leg")
	await _secs(float(lh["snare"]) + float(lh["pull_time"]) + 0.2)
	var dd := Vector2(player.global_position.x - d.global_position.x, player.global_position.z - d.global_position.z).length()
	check(dd < 2.6, "and pulls him in (%.1f m)" % dd)
	await _secs(1.6)

	print("== whistle: the rams lift their heads")
	await _ready_player(d.global_position + Vector3(0, 0, 9.0))
	var r := _spawn("frost_ram", d.global_position + Vector3(10, 0, 0), 90.0)
	await ticks(6)
	check(r.state == Enemy.ES.IDLE, "a ram stands idle, looking the other way")
	_ready_foe(d)
	var wi := d.attack_by_id("whistle_in")
	d._begin_attack(wi)
	await _secs(float(wi["windup"]) + 0.3)
	check(r.state != Enemy.ES.IDLE and r.target == player, "and comes to the whistle")
	r.free()
	d.free()
	await _secs(0.6)

# ------------------------------------------------------------------ Frost-ram
func _ram() -> void:
	print("== the Frost-ram: head down")
	await _ready_player(Vector3(0, 0.1, 8.0))
	var r := _spawn("frost_ram", Vector3(0, 0.1, 0), 180.0)
	await ticks(8)
	check(r.vis.is_quadruped() and r.vis.model_id == "frost_ram", "the frost_ram.glb body on its QuadRig")
	_face_player(r.global_position)
	_ready_foe(r)
	await ticks(2)
	var ch := r.attack_by_id("charge")
	var hp0 := player.hp
	var start := r.global_position
	r._begin_attack(ch)
	await _secs(float(ch["windup"]) * 0.85)
	check(r.vis.quad.weight("lower") > 0.3, "its head goes down on the tell")
	check(_tells() > 0, "and a strip glows the length of the charge")
	await _secs(float(ch["windup"]) * 0.15 + float(ch["active"]))
	check(player.hp < hp0, "it runs him down (%.0f -> %.0f)" % [hp0, player.hp])
	check(r.global_position.distance_to(start) > 5.0, "the length of the strip (%.1f m)" % r.global_position.distance_to(start))
	await _secs(float(ch["recover"]) + 0.3)

	print("== the kick: only at whoever is behind it")
	r.global_position = Vector3(0, 0.1, 0)
	r.vis.rotation.y = PI   # facing +z
	await _ready_player(Vector3(0, 0.1, 1.8))
	r.target = player
	check(not r._target_behind(), "in front of it: no kick")
	check(not (r._pick_attack(1.8).get("id", "") == "kick"), "it does not pick the kick from the front")
	await _ready_player(Vector3(0, 0.1, -1.7))
	check(r._target_behind(), "behind it")
	_ready_foe(r)
	var k := r.attack_by_id("kick")
	hp0 = player.hp
	r._begin_attack(k)
	await _secs(float(k["windup"]) + float(k["active"]) + 0.1)
	check(player.hp < hp0, "both hind feet (%.0f -> %.0f)" % [hp0, player.hp])
	r.free()
	await _secs(0.8)

# ------------------------------------------------------------------ the Fellcaller
func _fellcaller() -> void:
	print("== the Fellcaller: calling over the wall")
	await _ready_player(Vector3(0, 0.1, 16))
	player.invulnerable = true
	var f: Fellcaller = _spawn("fellcaller", Vector3(-2, 0.1, -2), 0.0)
	await ticks(20)
	check(f.vis.is_humanoid() and f.vis.model_id == "fellcaller", "the fellcaller.glb body")
	check(f.state == Enemy.ES.IDLE and not f.stood and f.vis.current_clip() == "call", "calling (%s)" % f.vis.current_clip())
	check(f.father_point().distance_to(Vector3(1.0, 0.1, -3.2)) < 0.2, "her father is at father_off from her")
	var own := ["call", "ram_charge", "summon"].filter(func(c):
		return f.vis.rig.has_clip(c) and not f.vis.rig.clip_anim(c).has_meta("procedural"))
	check(own.size() == 3, "her own clips (%s)" % str(own))
	var hud: HUD = arena.find_children("*", "HUD", true, false)[0]
	player.global_position = f.global_position + Vector3(4.0, 0, 5.0)
	await ticks(6)
	check(f.state == Enemy.ES.TRANSITION, "within 8 m the call stops and she turns")
	await _secs(2.7)
	check(f.stood and hud.boss_root.visible and hud.boss_name.text == "THE FELLCALLER", "the bar: THE FELLCALLER")
	var p1 := f.repertoire()
	check("horn_swing" in p1 and "rising_cry" in p1 and "head_down" in p1 and not ("call_them_in" in p1) and not ("count_them" in p1),
		"phase one: horn swing, rising cry, head down")

	print("== the rising cry: a ring that staggers")
	player.invulnerable = false
	await _ready_player(f.global_position + Vector3(0, 0, 4.5))
	_ready_foe(f)
	await ticks(2)
	var rc := f.attack_by_id("rising_cry")
	var hp0 := player.hp
	f._begin_attack(rc)
	await _secs(float(rc["windup"]) * 0.85)
	check(_tells() > 0, "a circle glows round her")
	await _secs(float(rc["windup"]) * 0.15 + 0.15)
	check(player.hp < hp0 and player.hp > hp0 - 40.0, "it reaches him, and hurts little (%.0f -> %.0f)" % [hp0, player.hp])
	check(player.state == Player.S.STAGGER, "and staggers him")
	await _secs(1.8)
	await _ready_player(f.global_position + Vector3(0, 0, 8.0))
	_ready_foe(f)
	hp0 = player.hp
	f._begin_attack(rc)
	await _secs(float(rc["windup"]) + 0.3)
	check(player.hp == hp0, "outside the circle it is only a noise")
	await _secs(1.4)

	print("== head down: the length of a strip")
	var dir := Vector3(1, 0, 0.6).normalized()
	await _ready_player(f.global_position + dir * 8.0)
	f.vis.rotation.y = atan2(-dir.x, -dir.z)
	_ready_foe(f)
	await ticks(2)
	var hd := f.attack_by_id("head_down")
	hp0 = player.hp
	var from := f.global_position
	f._begin_attack(hd)
	await _secs(float(hd["windup"]) + float(hd["active"]) + 0.1)
	check(player.hp < hp0, "the ram's horns (%.0f -> %.0f)" % [hp0, player.hp])
	check(f.global_position.distance_to(from) > 6.0, "she runs it (%.1f m)" % f.global_position.distance_to(from))
	await _secs(float(hd["recover"]) + 0.4)

	print("== the flock")
	player.invulnerable = true
	f._end_all_swings()
	f._set_state(Enemy.ES.COMBAT)
	f.take_hit(DamagePacket.new(f.max_hp * 0.37, 0, player))
	await ticks(2)
	check(f.phase == 2 and f.state == Enemy.ES.TRANSITION, "at 65% a call that does not rise")
	await _secs(3.2)
	check(f.rams_up().size() == 2, "two Frost-rams come over the wall (%d)" % f.rams_up().size())
	var p2 := f.repertoire()
	check("call_them_in" in p2 and "bring_tups" in p2 and not ("count_them" in p2), "call them in, bring tups")
	for m in f.rams_up():
		(m as Enemy).free()
	await ticks(2)

	print("== call them in: the flock down a strip")
	player.invulnerable = false
	f.global_position = Vector3(0, 0.1, -5.0)   # (the middle of the arena floor)
	await _ready_player(f.global_position + Vector3(0, 0, 7.0))
	f.vis.rotation.y = PI
	_ready_foe(f)
	await ticks(2)
	var ci := f.attack_by_id("call_them_in")
	var called := []
	var on_h := func(runs): called.append(runs)
	f.herd_called.connect(on_h)
	hp0 = player.hp
	f._begin_attack(ci)
	await _secs(float(ci["windup"]) / f._speed_mult() * 0.85)
	check(_tells() == 1, "one strip glows across the fold, through where he stands")
	await _secs(float(ci["windup"]) / f._speed_mult() * 0.15 + 0.2)
	check(called.size() == 1 and (called[0] as Array).size() == 1, "the flock comes")
	check(get_tree().get_nodes_in_group("herd_runs").size() == 1, "sheep on the strip")
	if called.size() == 1:
		var along: Vector3 = called[0][0][1]
		check(absf(along.dot(Vector3(0, 0, 1))) < 0.2, "across her aim, from the side")
	await _secs(float((ci["herd"] as Dictionary)["run"]) + 0.3)
	check(player.hp < hp0, "and goes over him (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.4)
	await _ready_player(f.global_position + Vector3(0, 0, 7.0))
	_ready_foe(f)
	hp0 = player.hp
	f._begin_attack(ci)
	await _secs(float(ci["windup"]) / f._speed_mult() + 0.05)
	player.global_position += Vector3(0, 0, -4.0)   # (out of the strip: in toward her, along her aim)
	await _secs(float((ci["herd"] as Dictionary)["run"]) + 0.3)
	check(player.hp == hp0, "step out of the strip and it goes by")
	f.herd_called.disconnect(on_h)
	await _secs(1.2)

	print("== standing over him")
	player.invulnerable = true
	f._end_all_swings()
	f._set_state(Enemy.ES.COMBAT)
	f.global_position = f.father_point() + Vector3(-9, 0, 6)   # (the fight has gone across the fold)
	await _ready_player(f.global_position + Vector3(-4, 0, 3))
	f.take_hit(DamagePacket.new(f.hp - f.max_hp * 0.25, 0, player))
	await ticks(2)
	check(f.phase == 3 and f.state == Enemy.ES.TRANSITION, "at 30% she goes back to her father")
	await _secs(3.3)
	var fd := Vector2(f.global_position.x - f.father_point().x, f.global_position.z - f.father_point().z).length()
	check(fd < 3.2, "and stands over him (%.1f m)" % fd)
	var p3 := f.repertoire()
	check("count_them" in p3 and not ("bring_tups" in p3), "count them")
	f._begin_attack(f.attack_by_id("rising_cry"))
	check((f._atk.get("hits", []) as Array).size() == 2, "the cry twice")
	f._end_all_swings()
	f._set_state(Enemy.ES.COMBAT)
	await ticks(2)
	f._begin_attack(f.attack_by_id("call_them_in"))
	await _secs(float(ci["windup"]) / f._speed_mult() + 0.1)
	check(_tells() == 2, "two strips, a cross (%d)" % _tells())
	await _secs(2.6)
	f._end_all_swings()
	f._set_state(Enemy.ES.COMBAT)
	await _ready_player(f.father_point() + Vector3(-8.0, 0.1, 2.0))
	f._cooldowns.clear()
	var ct := f.attack_by_id("count_them")
	check(f._attack_usable(ct), "the Bearer far off, and she by him")
	f._begin_attack(ct)
	await _secs(float(ct["windup"]) / f._speed_mult() + 0.2)
	check(f.state == Enemy.ES.HOLD, "she crouches to him and calls low")
	var to_f := (f.father_point() - f.global_position).normalized()
	check((-f.vis.global_transform.basis.z).dot(to_f) > 0.5, "her back to the Bearer")
	await _secs(1.5)
	f.take_hit(DamagePacket.new(10, 0, player))
	check(f.state == Enemy.ES.HOLD, "a blow does not stop her")
	await _secs(5.3)
	check(f.state != Enemy.ES.HOLD, "five quiet seconds: she stands and turns back")

	print("== the release")
	var sheep := []
	for i in 4:
		var s := KitLib.instance("sheep", 2, {})
		arena.add_child(s)
		s.global_position = Vector3(10 + i * 2, 0, 10)
		s.add_to_group("flock_rime")
		sheep.append(s)
	f.bring_rams(1, 2)
	await ticks(4)
	var ram: Enemy = f.rams_up()[0]
	while not f.dead:
		f.take_hit(DamagePacket.new(400, 0, player))
		await ticks(2)
	await _secs(0.4)
	check(f.released and f.vis.current_clip() == "call", "one soft call (%s)" % f.vis.current_clip())
	check(ram.dead, "the tups go down with it")
	await _secs(2.6)
	check(f.vis.current_clip() == "kneel_down", "and she kneels by him (%s)" % f.vis.current_clip())
	check(sheep.all(func(s): return absf((s as Node3D).scale.y - 0.58) < 0.02), "every sheep lies down")
	for s in sheep:
		(s as Node).free()
	player.invulnerable = false
	f.free()
	await ticks(3)

# ------------------------------------------------------------------ the Reach
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

func _flock(standing: bool) -> Array:
	return area.find_children("*", "Node3D", true, false).filter(func(n):
		return (n as Node3D).is_in_group("flock_rime") if standing else false)

func _build(id: String, state: RH.WState) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	World.set_area_state(id, state)
	area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	StateDirector.snap(area, state)
	await ticks(10)

func _reach() -> void:
	World._save_dir = "user://test_reach_enc"
	World.reset()
	Game.set_warmth(0)
	await _build("shepherds_reach", RH.WState.THAW)
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	player.invulnerable = true
	var hud := HUD.new()
	add_child(hud)
	await ticks(10)

	print("== the thaw: Calder at the wall, Sigga on the slope")
	var seen := _npcs()
	check(seen.has("old_calder") and seen.has("sigga") and not seen.has("sigga_fold") and not seen.has("calder_rime"), "both, before the release")
	var calder: NPC = seen.get("old_calder")
	var sigga: NPC = seen.get("sigga")
	check(calder != null and calder._vis.model_id == "old_calder" and sigga != null and sigga._vis.model_id == "sigga_thaw",
		"on their own models (old_calder, sigga_thaw)")
	if sigga != null:
		var heard := []
		var on := func(w, l): heard.append([w, l])
		sigga.overheard.connect(on)
		player.global_position = sigga.global_position + Vector3(0, 0.3, 4.0)
		await _secs(10.0)
		sigga.overheard.disconnect(on)
		check(heard.size() >= 2 and heard[0] == ["sigga", "Forty-three!"] and heard[1] == ["old_calder", "Forty-four!"],
			"the count, shouted across the slope: %s" % str(heard.slice(0, 2)))
	var ui := _talk("old_calder")
	await ticks(2)
	check(ui.text_label.text.begins_with("Hold still, Brokenhorn."), "Calder opens with a ewe's name")
	await _close(ui)
	check(World.flag("ks_calder_met") and _lines_of("calder_boots") == _expected("calder_boots", 1), "his thread starts")
	check(not World.flag("ks_calder_hum"), "he has not hummed yet")
	ui = _talk("old_calder")
	await ticks(2)
	var sounds := []
	ui.line_sounded.connect(func(p): sounds.append(p))
	var told := _all_lines(ui)
	check(told.size() == 5 and String(told[0]).begins_with("Old Leadvoice's lass"), "a second audience: who came up the fell at the Melt")
	check(sounds == [String(AudioDirector.cfg("hum", ""))] and sounds[0] != "", "he hums the Bearer's own three notes (%s)" % str(sounds))
	check(World.flag("ks_calder_hum"), "ks_calder_hum")
	await _close(ui)
	ui = _talk("sigga")
	await ticks(2)
	check(ui.text_label.text.begins_with("Stand there and they'll go round you."), "Sigga opens with her own line")
	var ids := _service_ids(ui)
	check(ids.has("give_fleece"), "she offers the spare fleece")
	ui.choose(ids.find("give_fleece"))
	check(int(player.inventory.get("armour_fleece", 0)) == 1 and not Player.armour_data("armour_fleece").is_empty(), "the Bearer takes it; it is armour")
	await _close(ui)
	check(_pickup("shepherds_whistle") != null, "the whistle is on its nail at the sheiling")
	_pickup("shepherds_whistle")._on_take(player)
	check(int(player.inventory.get("item_shepherd_whistle", 0)) == 1, "an item with a text, not warmth")

	print("== the rime: the boots, the flock, her father")
	await _build("shepherds_reach", RH.WState.RIME)
	seen = _npcs()
	check(seen.has("calder_rime") and not seen.has("old_calder"), "Old Calder is laid at the cairn")
	if seen.has("calder_rime"):
		var cr: NPC = seen["calder_rime"]
		check(cr.seated and cr._vis.rotation.x > 1.0 and cr.find_children("*", "Interactable", true, false).is_empty(), "on his back, and nothing to say")
	check(_pickup("calder_boots") != null, "his boots are by the sheiling door")
	_pickup("calder_boots")._on_take(player)
	check(_lines_of("calder_boots") == _expected("calder_boots", 2), "toes to the wall")
	var kinds := {}
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead):
		kinds[(e as Enemy).id] = true
	check(kinds.has("drover") and kinds.has("frost_ram") and kinds.has("fellcaller") and not kinds.has("rimewalker")
		and not kinds.has("hearthhound") and not kinds.has("netmender"), "the Reach's own foes, no stand-ins (%s)" % str(kinds.keys()))
	var standing := get_tree().get_nodes_in_group("flock_rime").filter(func(n): return area.is_ancestor_of(n))
	check(standing.size() == 70, "seventy sheep stand on the slope (%d)" % standing.size())
	var fc: Fellcaller = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Fellcaller and e.can_process():
			fc = e
	check(fc != null, "the Fellcaller in the fold")
	if fc != null and seen.has("calder_rime"):
		var dd := Vector2(fc.father_point().x - (seen["calder_rime"] as NPC).global_position.x,
				fc.father_point().z - (seen["calder_rime"] as NPC).global_position.z).length()
		check(dd < 1.2, "father_off points at where he lies (%.2f m)" % dd)

	print("== the release")
	var cards := []
	var on_card := func(t: String, _h: float): cards.append(t)
	Game.title_card.connect(on_card)
	player.global_position = fc.global_position + Vector3(-3.0, 0.3, 3.0)
	await ticks(4)
	fc.take_hit(DamagePacket.new(10, 0, player))
	await _secs(2.6)
	while fc != null and not fc.dead:
		fc.take_hit(DamagePacket.new(300, 0, player))
		await _secs(3.2 if fc.state == Enemy.ES.TRANSITION else 0.05)
	await _secs(2.8)
	Game.title_card.disconnect(on_card)
	check(fc.released and World.flag("ks_fellcaller_released"), "she is released (ks_fellcaller_released)")
	check("THE FELLCALLER — RELEASED" in cards, "the quiet card")
	check(standing.all(func(s): return absf((s as Node3D).scale.y - 0.58) < 0.03), "the whole slope lies down at once")
	check(Game.find_hearth("hs_high_fold") != null, "the hearth wakes in the High Fold")
	var tally := _pickup("fold_tally")
	check(tally != null and tally.global_position.distance_to(fc.father_point()) < 2.0, "the fold-tally is by his hand")
	if tally != null:
		tally._on_take(player)
	check(World.flag("ks_fold_tally_found") and _lines_of("calder_boots") == _expected("calder_boots", 3), "forty-three notches, and one cut small")
	await _build("shepherds_reach", RH.WState.RIME)
	check(get_tree().get_nodes_in_group("flock_rime").filter(func(n): return area.is_ancestor_of(n)).is_empty(),
		"in a rebuilt Reach nothing is left standing")
	var lying := area.find_children("*", "Node3D", true, false).filter(func(n):
		return absf((n as Node3D).scale.y - 0.58) < 0.001 and absf((n as Node3D).scale.x - 1.0) < 0.001)
	check(lying.size() == 70, "the seventy lie where they stood (%d)" % lying.size())
	check(Game.find_hearth("hs_high_fold") != null, "and the High Fold stays lit")

	print("== after: in the fold, in the thaw")
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])   # (out of earshot while it builds)
	await _build("shepherds_reach", RH.WState.THAW)
	seen = _npcs()
	check(seen.has("old_calder") and seen.has("sigga_fold") and not seen.has("sigga"), "the two of them in the fold")
	if seen.has("old_calder"):
		check((seen["old_calder"] as NPC).global_position.distance_to((seen["sigga_fold"] as NPC).global_position) < 3.0, "at the wall he has finished, side by side")
	if seen.has("sigga_fold"):
		var heard2 := []
		var on2 := func(w, l): heard2.append(l)
		(seen["sigga_fold"] as NPC).overheard.connect(on2)
		player.global_position = (seen["sigga_fold"] as NPC).global_position + Vector3(0, 0.3, 3.0)
		await _secs(6.0)
		check(heard2.size() >= 1 and heard2[0] == "Forty-four.", "she has got it to forty-four")
	ui = _talk("old_calder")
	await ticks(2)
	check(World.flag("ks_calder_boots_shown") and ui.text_label.text == "Those are mine.", "shown the boots, he knows them")
	await _close(ui)
	ui = _talk("old_calder")
	await ticks(2)
	check(ui.text_label.text.begins_with("Wall's done."), "and the wall is done by dark")
	await _close(ui)
	check(_lines_of("calder_boots") == _expected("calder_boots", 4), "Calder's boots: four lines, in order")
	check(int(player.inventory.get("item_calder_boots", 0)) == 1, "the Bearer still has the boots")

	print("== a Bearer who rested first: the boots shown to a Calder he never met")
	for f in ["chapter_old_calder", "met_old_calder", "ks_calder_met", "ks_calder_hum", "ks_calder_boots_shown"]:
		World.flags.erase(f)
	ui = _talk("old_calder")
	await ticks(2)
	check(_all_lines(ui) == DB.npc("old_calder")["lines_when"][1]["lines"], "he answers the boots before he starts his tale")
	check(World.flag("ks_calder_boots_shown") and not World.flag("ks_calder_met") and int(World.flag_val("chapter_old_calder", 0)) == 0,
		"and the tale has not moved on")
	await _close(ui)
	ui = _talk("old_calder")
	await ticks(2)
	check(ui.text_label.text.begins_with("Hold still, Brokenhorn."), "the first audience comes next")
	await _close(ui)
	check(World.flag("ks_calder_met") and _lines_of("calder_boots") == _expected("calder_boots", 4), "and its line heads the thread again")
	player.invulnerable = false
