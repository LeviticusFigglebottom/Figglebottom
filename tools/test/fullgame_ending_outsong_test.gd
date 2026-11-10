extends FullgameEndingBase
## The Outsong, end to end (COLDWELL.md 10, ADR 0013), from the save the
## Coldwell walk ends on: from the Wellhead Steps to the spring on foot, Lay
## the coal in the spring through its prompt, every beat as the director
## raises it (the HUD away, the camera over the ground, the mask, the song,
## the kneel, the coal, the melt that does not stop), control back with no
## HUD, the walk out past the stones, the credits over the walk (let go with
## Enter the first time, sat through the second), the Strand at Saltfell in
## spring with the HUD back, the two masks on the pegs, a hearth that rests
## and will not warm, the sheet, the title and back, and over the seam to
## the Lowe: nobody remembered there, nobody kept.

const BEATS := ["begin", "mask", "sing", "kneel", "coal", "spring", "walk"]

func _init() -> void:
	region = "ending_outsong"
	aid = "coldwell"
	start_fixture = "fullgame_after_coldwell"
	round_trip = false

func _region() -> void:
	if not await _begin():
		return
	print("== the Outsong; the credits let go")
	if not await _play(true):
		return
	print("== the same save again")
	if not await _again():
		return
	print("== the Outsong; the credits sat through")
	if not await _play(false):
		return
	await _after()

func _spring_light() -> bool:
	var a := Game.current_area as Area
	if a == null or not a.env.profiles.has("spring"):
		return false
	var s: Array = a.env.profiles["spring"]["sun_color"]
	return a.env.sun.light_color.is_equal_approx(Color(s[0], s[1], s[2]))

func _play(let_go: bool) -> bool:
	var lay: Vector3 = ec.to_global(Vector3(-ec.spread * 0.5, 0, 0))
	if not await _stand_at(lay, "Lay the coal in the spring"):
		return false
	var chosen := []
	ec.chosen.connect(func(e): chosen.append(e))
	await _shot("choice")
	if not await _take_ending():
		return false
	check(chosen == ["outsong"] and World.flag("ending_outsong") and World.spring() and World.ended() == "outsong" and not World.kept(),
		"ending_outsong: World.spring()")
	check(not ec.is_open(), "the other is no longer offered")
	await _until(func(): return _beat_names().has("begin"), 3.0)
	check(not player.input_enabled and not hud.visible, "the HUD goes; the Bearer's hands are not the player's")
	check(String(_beat("begin").get("cam", "")) == "EndingCam", "the ending has its own camera (%s)" % str(_beat("begin").get("cam", "")))
	var sat := _leadvoices()
	if not sat.is_empty():
		var to_her := _flat((sat[0] as Node3D).global_position - player.global_position).normalized()
		var facing := -player.vis.global_transform.basis.z
		check(_flat(facing).normalized().dot(to_her) > 0.8, "he stands facing his mother across the spring (%.2f)" % _flat(facing).normalized().dot(to_her))
	_check_unharmed("as it begins")
	await _until(func(): return _beat_names().has("sing"), 10.0)
	await _shot("sing")
	var walk_ok := await _until(func(): return _beat_names().has("walk"), 90.0)
	check(walk_ok and _beat_names() == BEATS, "its beats, in order: %s" % str(_beat_names()))
	if not walk_ok:
		return false
	_check_beats("the Outsong")
	check(String(_beat("mask")["model"]) == "bearer_outsong", "he puts the mask on: the Outsong robes (%s)" % str(_beat("mask")["model"]))
	check(String(_beat("sing")["music"]).contains("outsong"), "he sings: the Outsong, begun by him (%s)" % str(_beat("sing")["music"]))
	check(int(_beat("kneel")["state"]) == Player.S.REST, "he kneels")
	check(float(_beat("coal")["t"]) > float(_beat("kneel")["t"]) + 1.0, "and opens the horn: the coal goes into the water (%.1f s)" % float(_beat("coal")["t"]))
	check(_beat("spring")["thaw"] and (_beat("spring")["souls"] as Array).is_empty(), "the melt goes out from the spring: open ground, nobody remembered")
	check(not _beat("spring")["input"] and _beat("walk")["input"], "then control comes back")
	check(_hp_low >= _hp0 - 0.01 and not player.invulnerable, "unharmed, and his own again (%.0f of %.0f)" % [_hp_low, _hp0])
	print("  (music at each beat: %s)" % str(_beats.map(func(b): return "%s=%s" % [b["beat"], String(b["music"]).get_file()])))
	check(not hud.visible, "with no HUD")
	check(String(_beat("walk")["cam"]) != "EndingCam" and get_viewport().get_camera_3d() == player.cam.cam, "and his own camera")
	check(player.state == Player.S.MOVE and player.vis.model_id == "bearer_outsong", "on his feet, in the robes")
	check(World.slot_summary(World.active_slot)["ending"] == "outsong", "the save written at the ending knows how it ended")
	check(_horn().ends_with("It is empty. The inside is black to the lip."), "the horn is empty")
	check(area.thaw_layer.visible and not area.rime_layer.visible and _spring_light(), "the Coldwell: running water, the grey of a real spring morning")
	check(_souls().is_empty() and _awake_foes().is_empty(), "no Maren, no Wren, nothing frost-taken")
	await _secs(4.5)
	check(_leadvoices().is_empty(), "Maren and the child have gone with the frost")
	check(area.rime_layer.find_children("*", "Node3D", false, false).all(func(n): return not (n as Node3D).is_visible_in_tree()), "the dead in the river are gone")
	check(String(AudioDirector._active_music).contains("outsong"), "the song is still going")
	await _shot("spring")

	print("== the walk out, and the credits over it")
	var out := Game.find_hearth("hs_wellhead_steps").respawn_point()
	_halt = func(): return d.beats.has("credits")
	var t0 := Engine.get_physics_frames()
	await _walk_path(out, 3600, false)
	_halt = Callable()
	var rolled := await _until(func(): return d.beats.has("credits") and d.credits != null and is_instance_valid(d.credits), 90.0)
	var off := _flat(player.global_position - WELL).length()
	check(rolled, "past the stones, the credits roll (%.0f m from the spring, %d ticks)" % [off, Engine.get_physics_frames() - t0])
	if not rolled:
		return false
	check(off >= 15.0, "not before he has walked out (%.1f m)" % off)
	var roll: CreditsUI = d.credits
	var texts: Array = roll.lines.map(func(e): return String(e[1]))
	check(texts.has("RIMEHOLT") and texts.has("Figglebottom Productions") and roll.lines.any(func(e): return e[0] == "knot"),
		"one column: the game, the house, the tools, a knot at the foot (%d lines)" % roll.lines.size())
	check(roll.over_world and not hud.visible, "over the world, and still no HUD")
	var p0 := player.global_position
	walked_on = await _walk_path(Game.find_hearth("hs_ice_falls").respawn_point(), 240, false)
	check(_flat(player.global_position - p0).length() > 8.0 and player.input_enabled, "and he can keep walking (%.0f m on)" % _flat(player.global_position - p0).length())
	await _shot("credits")
	var c0 := Time.get_ticks_msec()
	var f0 := Engine.get_physics_frames()
	var whole := roll.duration()
	if let_go:
		await _secs(3.0)
		check(is_instance_valid(roll) and not d.done, "(they are rolling)")
		_act("ui_accept")
		var ended := await _until(func(): return d.done, 8.0)
		check(ended and (Engine.get_physics_frames() - f0) / 60.0 < 10.0, "Enter lets them go (%.1f s of %.0f)" % [(Engine.get_physics_frames() - f0) / 60.0, whole])
	else:
		# (Space and E are still the Bearer's on the walk out: they roll on)
		_act("dodge")
		_act("interact")
		await _secs(2.0)
		check(is_instance_valid(roll) and not d.done, "a roll or a hand on something does not end them")
		var ended2 := await _until(func(): return d.done, whole + 30.0)
		var sat_s := (Engine.get_physics_frames() - f0) / 60.0
		check(ended2 and sat_s > whole * 0.5, "sat through, they end by themselves (%.0f s; the roll is %.0f s)" % [sat_s, whole])
	print("  (credits: %.1f s of wall time)" % ((Time.get_ticks_msec() - c0) / 1000.0))
	_check_watch("the Outsong and its credits")
	_watch(false)
	check(d.beats == BEATS + ["credits", "end"], "credits, end (%s)" % str(d.beats.slice(BEATS.size())))

	print("== after the credits: the Strand at Saltfell, in spring")
	var home := await _until(func(): return Game.current_area_id == "saltfell_steading" and player.input_enabled, 30.0)
	check(home, "the Bearer is set down at Saltfell (%s)" % Game.current_area_id)
	if not home:
		return false
	area = Game.current_area
	await ticks(30)
	_watch(true, true)
	check(hud.visible, "the HUD is back now that the Bearer has control")
	var cs := _cam_state()
	check(cs["ok"] and get_viewport().get_camera_3d() == player.cam.cam, "his own camera, over the ground and upright (%.2f m over, up.y %.2f)" % [float(cs["over"]), float(cs["up"])])
	var start: Vector3 = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	check(_flat(player.global_position - start).length() < 4.0 and player.is_on_floor(), "on the Strand, on his feet (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(area.thaw_layer.visible and not area.rime_layer.visible and _spring_light(), "grey and green")
	check(_souls().is_empty() and _awake_foes().is_empty(), "and empty: no Ingra, no Brede, nothing frost-taken")
	await _secs(3.0)
	_check_watch("the first seconds at Saltfell")
	await _shot("strand")
	return true

var walked_on := false

func _masks() -> Array:
	return area.find_children("*", "Node3D", true, false).filter(func(n):
		var f := String((n as Node3D).scene_file_path)
		return (f.ends_with("child_mask.tscn") or f.ends_with("mourning_mask.tscn")) and (n as Node3D).is_visible_in_tree())

func _nearest_hearth() -> Hearthstone:
	var best: Hearthstone = null
	var bd := INF
	for h in get_tree().get_nodes_in_group("hearths"):
		if not area.is_ancestor_of(h):
			continue
		var p := _path(player.global_position, (h as Hearthstone).respawn_point())
		var l := 0.0
		for i in range(1, p.size()):
			l += p[i].distance_to(p[i - 1])
		if p.size() > 1 and l < bd:
			bd = l
			best = h
	return best

func _after() -> void:
	print("== the world after: nothing softlocks")
	var p0 := player.global_position
	var masks := _masks()
	check(masks.size() == 2, "inside the Longhouse door there are two masks on the low pegs (%d)" % masks.size())
	if masks.size() > 0:
		var at: Vector3 = (masks[0] as Node3D).global_position
		_halt = func(): return _flat(player.global_position - at).length() < 3.0
		await _walk_path(at, 5400, false)
		_halt = Callable()
		check(_flat(player.global_position - at).length() < 4.5, "the Bearer walks up from the Strand to the pegs (%.0f m walked, %s)" % [
			_flat(player.global_position - p0).length(), str(player.global_position.snapped(Vector3.ONE * 0.1))])
	var h := _nearest_hearth()
	check(h != null, "the hearthstones are still there to rest at")
	if h == null:
		return
	var rest := await _rest_ui_at(h.hearth_id)
	check(rest != null, "%s offers its hearth" % h.hearth_id)
	if rest != null:
		var ids: Array = rest._options.map(func(o): return String(o["id"]))
		check(ids.has("rest") and ids.has("cold") and not ids.has("toggle"), "it can be rested at, and asked for more (%s)" % str(ids))
		check(String(rest._options[ids.find("cold")]["label"]) == "Warm the stone", "Warm the stone")
		rest.choose(ids.find("cold"))
		await ticks(2)
		check(rest.info_label.text == "The horn is empty.", "the answer is four words: %s" % rest.info_label.text)
		check(_ui("RestUI") != null, "(the sheet stays up)")
		rest.choose(_option_index(rest, "rest"))
		await _secs(2.4)
		await _until(func(): return player.input_enabled, 8.0)
		if _ui("RestUI") != null:
			var r2 := _ui("RestUI") as RestUI
			r2.choose(_option_index(r2, "leave"))
			await ticks(4)
	check(World.last_hearth.get("area", "") == "saltfell_steading" and World.last_hearth.get("hearth", "") == h.hearth_id, "the hearth is kept")
	check(area.thaw_layer.visible and World.get_area_state("saltfell_steading") == RH.WState.THAW and not StateDirector.transitioning, "resting turns nothing")
	check(player.input_enabled and player.state == Player.S.MOVE and hud.visible, "the Bearer rises, the HUD up")
	for a in OTHERS + ["coldwell"]:
		check(World.get_area_state(a) == RH.WState.THAW and not Game.toggle_free(a), "%s: thawed for good" % a)

	print("== the sheet, the title, and back")
	check(await _esc_opens(), "Esc raises the sheet")
	check(await _esc_closes(), "Return to the World puts it away")
	var before := player.global_position
	await _walk_to(player.global_position + Vector3(2.0, 0, 2.0), 120, 0.6, false)
	check(player.global_position.distance_to(before) > 0.5, "and the Bearer walks on")
	_watch(false)
	var title := await _to_title()
	check(World.slot_summary(World.active_slot)["ending"] == "outsong", "the slot's ledger: outsong")
	if not await _resume(title):
		return
	_watch(true, true)
	check(Game.current_area_id == "saltfell_steading" and World.spring(), "resumed at Saltfell, still spring")
	var h2 := Game.find_hearth(String(World.last_hearth["hearth"]))
	check(h2 != null and player.global_position.distance_to(h2.respawn_point()) < 2.0, "at the hearth kept")
	check(hud.visible and player.input_enabled, "the HUD up, the Bearer his own")
	check(player.vis.model_id == "bearer_outsong", "in the robes and the mask (%s)" % player.vis.model_id)
	check(area.thaw_layer.visible and _spring_light() and _souls().is_empty() and _awake_foes().is_empty(), "the yard grey and green and empty")
	check(_masks().size() == 2, "two masks on the pegs")
	check(EndingDirector.active == null and _credit_rolls().is_empty(), "no ending runs a second time")
	var cs := _cam_state()
	check(cs["ok"], "the camera over the ground and upright (%s)" % str(cs["why"]))

	print("== over the pass to the Lowe: nobody remembered")
	var seam := _portal_to("lowe_barrows")
	check(seam != null, "the pass stands")
	if seam == null:
		return
	var into: Vector3 = AreaBuilder._v3(DB.area_def("lowe_barrows")["start"]["pos"]) - seam.global_position
	into.y = 0.0
	var crossed := await _cross("lowe_barrows", seam.global_position + into.normalized() * 1.0, 12000, false)
	check(crossed, "the Bearer walks over it (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return
	await ticks(60)
	check(World.get_area_state("lowe_barrows") == RH.WState.THAW and area.thaw_layer.visible and not area.rime_layer.visible, "the Lowe is its unfrozen ground")
	check(_spring_light(), "under the grey light")
	var thaw_people: Array = (area.get_meta("def")["npcs"] as Array).filter(func(n): return String(n.get("tag", "thaw")) == "thaw").map(func(n): return String(n["id"]))
	check(not thaw_people.is_empty() and _souls().is_empty(), "nobody is remembered in it: no %s" % str(thaw_people))
	check(_awake_foes().is_empty(), "and nothing frost-taken")
	check(hud.visible and player.input_enabled, "the Bearer walks on, the HUD up")
	var hl := _nearest_hearth()
	if hl != null:
		var r := await _rest_ui_at(hl.hearth_id)
		check(r != null and _option_index(r, "toggle") < 0 and _option_index(r, "cold") >= 0, "its hearth rests, and will not turn (%s)" % hl.hearth_id)
		if r != null:
			r.choose(_option_index(r, "leave"))
			await ticks(4)
	check(player.input_enabled and not player.dead, "nothing holds him")
	_check_watch("the world after")
	_watch(false)
