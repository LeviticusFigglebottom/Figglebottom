extends TestBase
## Thornwold's encounters (THORNWOLD.md 5-9). In the arena sandbox: the
## Collier's rake and cinders; the Rime-stag on its QuadRig, the bound and the
## thorn shake; the Hedgelayer's intro, three phases (and the moves each
## unlocks), walls of thorn rising behind the Bearer and blocking, the lash
## that drags, the ring round the grave that closes in, into the hedge and out
## of it by the Bearer, Where it goes, and his release (every wall unlays, the
## gate lies down). In the wood itself: Linnet and Eyvind's overheard argument,
## both Keepsakes threads, Lusse reading the cord, and the release (flag,
## card, the gate laid down now and on rebuild, the hearth at the pine, the
## song-cord on the grave, the scene after).

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
	at.y = 0.1   # (the arena floor: a foe sunk a little would put him under it)
	if player.dead:
		player.revive_at(at)
		await _secs(1.5)
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.hp = player.max_hp
	player.lock_control(false)

## Ready to strike with nothing else picked meanwhile.
func _ready_foe(e: Enemy) -> void:
	e.target = player
	for a in e.cfg.get("attacks", []):
		e._cooldowns[String(a["id"])] = 99.0
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
	await _collier()
	await _stag()
	await _hedgelayer()
	arena.queue_free()
	await ticks(5)
	await _wood()
	finish()

# ------------------------------------------------------------------ Collier
func _collier() -> void:
	print("== the Collier: black hands")
	await _ready_player(Vector3(0, 0.1, 2.0))
	var c := _spawn("collier", Vector3(0, 0.1, 0), 180.0)
	await ticks(8)
	check(c.vis.is_humanoid() and c.vis.model_id == "collier", "the collier.glb body")
	check(float(c.cfg["speed"]) < 2.0, "slow")
	_face_player(c.global_position)
	_ready_foe(c)
	await ticks(2)
	var r := c.attack_by_id("rake")
	var hp0 := player.hp
	c._begin_attack(r)
	await _secs(float(r["windup"]) * 0.85)
	check(arena.find_children("*", "FloorTelegraph", true, false).size() > 0, "a fan glows along the ground")
	await _secs(float(r["windup"]) * 0.15 + 0.1)
	check(player.hp < hp0, "the rake catches him at shin height (%.0f -> %.0f)" % [hp0, player.hp])
	await _secs(1.4)

	print("== cinders: coals onto circles round the Bearer")
	await _ready_player(c.global_position + Vector3(0, 0, 6.0))
	_ready_foe(c)
	await ticks(2)
	var cn := c.attack_by_id("cinders")
	hp0 = player.hp
	c._begin_attack(cn)
	await _secs(float(cn["windup"]) + 0.1)
	check(c.lobbed.size() == 3, "three coals in the air (%d)" % c.lobbed.size())
	await _secs(float((cn["lob"] as Dictionary)["flight"]) + 0.2)
	check(player.hp < hp0, "one lands on him (%.0f -> %.0f)" % [hp0, player.hp])
	c.free()
	await _secs(1.0)

# ------------------------------------------------------------------ Rime-stag
func _stag() -> void:
	print("== the Rime-stag: frozen mid-bound")
	await _ready_player(Vector3(0, 0.1, 8.0))
	var s := _spawn("rime_stag", Vector3(0, 0.1, 0), 180.0)
	await ticks(8)
	check(s.vis.is_quadruped() and s.vis.model_id == "rime_stag", "the rime_stag.glb body on its QuadRig")
	_face_player(s.global_position)
	_ready_foe(s)
	await ticks(2)
	var b := s.attack_by_id("bound")
	var hp0 := player.hp
	var start := s.global_position
	s._begin_attack(b)
	await _secs(float(b["windup"]) * 0.5)
	check(s.vis.quad.weight("rear") > 0.3, "it rears on the tell")
	await _secs(float(b["windup"]) * 0.5 + float(b["active"]))
	check(player.hp < hp0, "it comes down on him (%.0f -> %.0f)" % [hp0, player.hp])
	check(s.global_position.distance_to(start) > 4.0, "the length of the strip (%.1f m)" % s.global_position.distance_to(start))
	await _secs(1.2)
	await _ready_player(s.global_position + Vector3(0, 0, 1.8))
	_ready_foe(s)
	await ticks(2)
	var sh := s.attack_by_id("thorn_shake")
	hp0 = player.hp
	s._begin_attack(sh)
	await _secs(float(sh["windup"]) + 0.15)
	check(player.hp < hp0, "thorn off the antlers rakes everything round it")
	s.free()
	await _secs(1.0)

# ------------------------------------------------------------------ the Hedgelayer
func _walls(h: Hedgelayer) -> Array:
	return h.standing_walls().filter(func(w): return w != h.ring)

func _blocked(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.0, to + Vector3.UP * 1.0, RH.M_WORLD_ALL)
	return not arena.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _hedgelayer() -> void:
	print("== the Hedgelayer: laying a stem that is already laid")
	await _ready_player(Vector3(0, 0.1, 14))
	player.invulnerable = true
	var h: Hedgelayer = _spawn("hedgelayer", Vector3(-4, 0.1, 4), 270.0)
	await ticks(20)
	check(h.vis.is_humanoid() and h.vis.model_id == "hedgelayer", "the hedgelayer.glb body")
	check(h.state == Enemy.ES.IDLE and not h.stood and h.vis.current_clip() == "lay_stem", "at the hedge (%s)" % h.vis.current_clip())
	check(h.grave_point().distance_to(Vector3(0, 0.1, 0)) < 0.2, "the grave is at grave_off from him")
	var own := ["raise_wall", "step_into", "thorn_lash"].filter(func(c):
		return h.vis.rig.has_clip(c) and not h.vis.rig.clip_anim(c).has_meta("procedural"))
	check(own.size() == 3, "his own prompt clips (%s)" % str(own))
	var hud: HUD = arena.find_children("*", "HUD", true, false)[0]
	player.global_position = h.global_position + Vector3(4.0, 0, 3.0)
	await ticks(6)
	check(h.state == Enemy.ES.TRANSITION, "within 7 m he lets the stem go and turns")
	await _secs(2.4)
	check(h.stood and hud.boss_root.visible and hud.boss_name.text == "THE HEDGELAYER", "the bar: THE HEDGELAYER")
	var p1 := h.repertoire()
	check("bill" in p1 and "thorn_lash" in p1 and "raise_wall" in p1 and not ("step_into" in p1) and not ("where_it_goes" in p1),
		"phase one: bill, thorn lash, raise a wall")

	print("== raise a wall: thorn rises behind the Bearer")
	player.invulnerable = false
	await _ready_player(h.global_position + Vector3(0, 0, 6.0))
	h.vis.rotation.y = PI
	_ready_foe(h)
	await ticks(2)
	var rw := h.attack_by_id("raise_wall")
	h._begin_attack(rw)
	await _secs(float(rw["windup"]) * 0.85)
	check(arena.find_children("*", "FloorTelegraph", true, false).size() > 0, "a strip glows across the floor behind him")
	await _secs(float(rw["windup"]) * 0.15 + 0.6)
	var ws := _walls(h)
	check(ws.size() == 1, "a wall of thorn rises (%d)" % ws.size())
	if ws.size() == 1:
		var w: ThornWall = ws[0]
		var d := w.distance_to(player.global_position)
		check(d > 1.5 and d < 4.0, "behind the Bearer, %.1f m off" % d)
		check(_blocked(player.global_position, player.global_position + Vector3(0, 0, 6.0)), "it stops the way back")
	await _secs(1.2)
	for w2 in _walls(h):
		(w2 as ThornWall).sink(0.1)
	await _secs(0.4)

	print("== thorn lash: caught and dragged in")
	var away := Vector3(h.global_position.x, 0, h.global_position.z).direction_to(Vector3(2, 0, 0))
	await _ready_player(h.global_position + away * 7.0)   # (toward the middle of the arena floor)
	h.vis.rotation.y = atan2(-away.x, -away.z)
	_ready_foe(h)
	await ticks(2)
	var tl := h.attack_by_id("thorn_lash")
	h._begin_attack(tl)
	await _secs(float(tl["windup"]) + 0.1)
	check(h.hook_hold != null, "the lash catches him")
	await _secs(float(tl["snare"]) + float(tl["pull_time"]) + 0.2)
	var dd := Vector2(player.global_position.x - h.global_position.x, player.global_position.z - h.global_position.z).length()
	check(dd < 3.2, "and drags him in (%.1f m)" % dd)
	await _secs(2.0)

	print("== the rings")
	player.invulnerable = true
	h._end_all_swings()
	h._set_state(Enemy.ES.COMBAT)
	h.take_hit(DamagePacket.new(h.max_hp * 0.42, 0, player))
	await ticks(2)
	check(h.phase == 2 and h.state == Enemy.ES.TRANSITION, "at 60% he drives his hands into the ground")
	await _secs(3.0)
	check(h.ring != null and is_instance_valid(h.ring) and absf(h.ring.radius - 8.0) < 0.01, "a ring of thorn round the grave, 8 m out")
	if h.ring != null:
		check(h.ring.distance_to(h.global_position) < 2.5, "with its gap where he stands")
	var p2 := h.repertoire()
	check("step_into" in p2 and not ("where_it_goes" in p2), "into the hedge")

	print("== into the hedge, out by the Bearer")
	player.invulnerable = false
	await _ready_player(h.grave_point() + Vector3(-3.0, 0.1, 5.5))
	_ready_foe(h)
	await ticks(2)
	var si := h.attack_by_id("step_into")
	var outs := []
	var on_out := func(at): outs.append(at)
	h.stepped_out.connect(on_out)
	var hp0 := player.hp
	h._begin_attack(si)
	await _secs(float(si["windup"]) / h._speed_mult() + 0.2)
	check(h.hidden and not h.vis.visible, "the thorn closes over him")
	var hp_in := h.hp
	h.take_hit(DamagePacket.new(100, 0, player))
	check(h.hp == hp_in, "nothing reaches him in there")
	await _secs(float(si["gone"]) + 0.2)
	check(arena.find_children("*", "FloorTelegraph", true, false).size() > 0, "a circle glows where he will come out")
	await _secs(float(si["out_tell"]))
	check(outs.size() == 1 and not h.hidden, "he steps out of the hedge")
	if outs.size() == 1:
		check(h.ring.distance_to(outs[0]) < 2.2 and (outs[0] as Vector3).distance_to(player.global_position) < 4.0,
			"out of the ring, by the Bearer (%.1f m)" % (outs[0] as Vector3).distance_to(player.global_position))
	check(player.hp < hp0, "with a Bill across the circle (%.0f -> %.0f)" % [hp0, player.hp])
	h.stepped_out.disconnect(on_out)
	await _secs(1.5)

	print("== the gap")
	player.invulnerable = true
	h._end_all_swings()
	h._set_state(Enemy.ES.COMBAT)
	h.take_hit(DamagePacket.new(h.hp - h.max_hp * 0.2, 0, player))
	await ticks(2)
	check(h.phase == 3 and h.state == Enemy.ES.TRANSITION, "at 25% the ring closes in")
	await _secs(3.0)
	check(h.ring != null and absf(h.ring.radius - 6.0) < 0.01, "to 6 m")
	var p3 := h.repertoire()
	check("where_it_goes" in p3 and not ("raise_wall" in p3), "where it goes")
	var tl3 := h.attack_by_id("thorn_lash")
	h._begin_attack(tl3)
	check((h._atk.get("hits", []) as Array).size() == 2, "the lash twice")
	h._end_all_swings()
	h._set_state(Enemy.ES.COMBAT)
	h.global_position = h.ring.nearest_point(h.global_position) if h.ring.distance_to(h.global_position) > 2.5 else h.global_position
	await _ready_player(h.global_position + Vector3(0, 0.1, 0) + (h.global_position - h.grave_point()).normalized() * 7.0)
	h._cooldowns.clear()
	var wg := h.attack_by_id("where_it_goes")
	check(h._attack_usable(wg), "the Bearer far off and he in the gap")
	h._begin_attack(wg)
	await _secs(float(wg["windup"]) / h._speed_mult() + 0.1)
	check(h.state == Enemy.ES.HOLD and h.vis.current_clip() == "measure_gap", "he measures the gap, his back to the Bearer")
	await _secs(2.0)
	h.take_hit(DamagePacket.new(10, 0, player))
	check(h.state == Enemy.ES.HOLD, "a blow does not stop him")
	await _secs(5.3)
	check(h.state != Enemy.ES.HOLD, "five quiet seconds: he turns back")

	print("== the release")
	var wl := ThornWall.raise(arena, h.global_position + Vector3(3, 0, 0), 0.0, 6.0, 3.0, 99.0)
	h.walls.append(wl)
	await ticks(4)
	while not h.dead:
		h.take_hit(DamagePacket.new(400, 0, player))
		await ticks(2)
	await _secs(0.6)
	check(h.released and h.vis.current_clip() == "kneel_hands", "he kneels at the gap (%s)" % h.vis.current_clip())
	await _secs(2.4)
	check(get_tree().get_nodes_in_group("thorn_walls").filter(func(w): return (w as ThornWall).is_standing()).is_empty(),
		"every wall he raised unlays itself")
	check(h.laid_gate != null and absf(h.laid_gate.rotation_degrees.x + 90.0) < 1.0, "the gate lies down flat across the gap")
	player.invulnerable = false
	h.free()
	await ticks(3)

# ------------------------------------------------------------------ the wood
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

func _gates() -> Array:
	return area.find_children("*", "Node3D", true, false).filter(func(n):
		return (n as Node3D).scene_file_path.ends_with("lm_hedge_gate.glb") and (n as Node3D).is_visible_in_tree())

func _build(id: String, state: RH.WState) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	World.set_area_state(id, state)
	area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	StateDirector.snap(area, state)
	await ticks(10)

func _wood() -> void:
	World._save_dir = "user://test_thornwold_enc"
	World.reset()
	Game.set_warmth(0)
	await _build("thornwold", RH.WState.THAW)
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	player.invulnerable = true
	var hud := HUD.new()
	add_child(hud)
	await ticks(10)

	print("== Linnet and Eyvind at the clearing, arguing about the gate")
	var seen := _npcs()
	check(seen.has("linnet") and seen.has("eyvind") and not seen.has("eyvind_gate"), "both at the clearing")
	var linnet: NPC = seen.get("linnet")
	var eyvind: NPC = seen.get("eyvind")
	check(linnet != null and linnet._vis.model_id == "linnet" and eyvind != null and eyvind._vis.model_id == "eyvind_thaw",
		"on their own models (linnet, eyvind_thaw)")
	check(eyvind != null and eyvind.find_children("*", "Interactable", true, false).is_empty(), "Eyvind cannot be spoken to")
	if eyvind != null:
		var heard := []
		var on := func(w, l): heard.append([w, l])
		eyvind.overheard.connect(on)
		player.global_position = eyvind.global_position + Vector3(0, 0.3, 3.0)
		await _secs(10.0)
		eyvind.overheard.disconnect(on)
		var want: Array = DB.npc("eyvind")["overhear"]
		check(heard.size() >= 2 and heard[0] == want[0] and heard[1] == want[1], "overheard: %s" % str(heard.slice(0, 2)))
	var ui := _talk("linnet")
	await ticks(2)
	check(ui.text_label.text.begins_with("Mind the clamp"), "Linnet opens with her own line")
	check(_lines_of("song_cord") == _expected("song_cord", 1), "her thread starts")
	var ids := _service_ids(ui)
	check(ids.has("give_collier_leathers"), "she offers the spare leathers")
	ui.choose(ids.find("give_collier_leathers"))
	check(int(player.inventory.get("armour_collier", 0)) == 1, "the Bearer takes them")
	await _close(ui)

	print("== the rime: the knucklebone, the ring, the bill")
	await _build("thornwold", RH.WState.RIME)
	for pid in ["knucklebone", "birch_ring", "hedging_bill"]:
		check(_pickup(pid) != null, "%s is placed" % pid)
	if _pickup("knucklebone") != null:
		_pickup("knucklebone")._on_take(player)
	check(_lines_of("knucklebones") == _expected("knucklebones", 1), "a knucklebone on the road, going east")
	if _pickup("birch_ring") != null:
		_pickup("birch_ring")._on_take(player)
	var kinds := {}
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e): return e.can_process() and not e.dead):
		kinds[(e as Enemy).id] = true
	check(kinds.has("collier") and kinds.has("rime_stag") and kinds.has("hedgelayer") and not kinds.has("rimewalker")
		and not kinds.has("hearthhound") and not kinds.has("netmender"), "the wood's own foes, no stand-ins (%s)" % str(kinds.keys()))
	check(_gates().size() == 1, "the gate leans on the hedge, unhung")

	print("== back in the thaw, with the ring")
	await _build("thornwold", RH.WState.THAW)
	ui = _talk("linnet")
	await ticks(2)
	check(World.flag("ks_birch_ring") and ui.text_label.text.begins_with("That's mine."), "Linnet takes her ring")
	await _close(ui)

	print("== the release")
	await _build("thornwold", RH.WState.RIME)
	var hl: Hedgelayer = null
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if e is Hedgelayer and e.can_process():
			hl = e
	check(hl != null, "the Hedgelayer at the grave")
	var cards := []
	var on_card := func(t: String, _h: float): cards.append(t)
	Game.title_card.connect(on_card)
	player.global_position = hl.global_position + Vector3(3.0, 0.3, 3.0)
	await ticks(4)
	hl.take_hit(DamagePacket.new(10, 0, player))
	await _secs(2.4)
	while hl != null and not hl.dead:
		hl.take_hit(DamagePacket.new(300, 0, player))
		await _secs(3.0 if hl.state == Enemy.ES.TRANSITION else 0.05)
	await _secs(2.5)
	Game.title_card.disconnect(on_card)
	check(hl.released and World.flag("ks_hedgelayer_released"), "he is released (ks_hedgelayer_released)")
	check("THE HEDGELAYER — RELEASED" in cards, "the quiet card")
	check(get_tree().get_nodes_in_group("thorn_walls").filter(func(w): return (w as ThornWall).is_standing()).is_empty(),
		"the ring he raised unlays")
	var g := _gates()
	check(g.size() == 1 and absf((g[0] as Node3D).rotation_degrees.x + 90.0) < 1.0, "the gate lies flat across the gap, the leaning one gone")
	check(Game.find_hearth("hs_the_pine") != null, "the hearth wakes at the pine")
	var cord := _pickup("song_cord")
	check(cord != null and cord.global_position.distance_to(hl.grave_point()) < 2.5, "the song-cord is on the grave")
	if cord != null:
		cord._on_take(player)
	check(World.flag("ks_song_cord_found") and _lines_of("song_cord") == _expected("song_cord", 3), "nobody here could read it")
	await _build("thornwold", RH.WState.RIME)
	g = _gates()
	check(g.size() == 1 and absf((g[0] as Node3D).rotation_degrees.x + 90.0) < 1.0, "the gate stays down in a rebuilt wood")
	check(Game.find_hearth("hs_the_pine") != null, "and the Pine stays lit")

	print("== after: at the gap, in the thaw")
	await _build("thornwold", RH.WState.THAW)
	seen = _npcs()
	check(seen.has("linnet") and seen.has("eyvind_gate") and not seen.has("eyvind"), "Linnet and Eyvind at the gap now")
	if seen.has("linnet"):
		check((seen["linnet"] as NPC).global_position.distance_to(AreaBuilder._v3(area.get_meta("def")["npcs"][2]["at"])) < 0.5,
			"by the gate lying down")
	ui = _talk("linnet")
	await ticks(2)
	check(ui.text_label.text.begins_with("He's laid it down."), "Linnet: it's a gate lying down")
	await _close(ui)

	print("== Lusse reads the cord")
	World.set_flag("met_lusse")   # (an old friend by now: her own words, not her first ones)
	ui = _talk("lusse")
	await ticks(2)
	check(World.flag("ks_song_cord_read") and ui.text_label.text.begins_with("This is an Outsong."), "Lusse reads it")
	check(int(player.inventory.get("item_song_cord", 0)) == 1, "and gives it back")
	await _close(ui)
	check(_lines_of("song_cord") == _expected("song_cord", 4), "Linnet's song-cord: four lines, in order")
	player.invulnerable = false
