extends FullgameEndingBase
## The Hearth Kept, end to end (COLDWELL.md 10, ADR 0013), from the save the
## Coldwell walk ends on: from the Wellhead Steps to the spring on foot, Keep
## the horn shut, and sit through its prompt, every beat as the director
## raises it (the HUD away, the camera over the ground, the stopper, the
## remembered Melt coming back over the Coldwell and nowhere else, the woman
## and the child at the water, the Bearer sat facing them), the credits over
## it with no music (let go with Enter the first time, sat through the
## second), the frost on his shoulders; then what a kept save is: he does not
## get up, every other region is RIME and no hearth will turn it, the sheet
## still opens, and the title and back finds him sat where he chose, twice.

const BEATS := ["begin", "shut", "melt", "sit", "credits", "end"]

func _init() -> void:
	region = "ending_kept"
	aid = "coldwell"
	start_fixture = "fullgame_after_coldwell"
	round_trip = false

func _region() -> void:
	if not await _begin():
		return
	print("== the Hearth Kept; the credits let go")
	if not await _play(true):
		return
	print("== the same save again")
	if not await _again():
		return
	print("== the Hearth Kept; the credits sat through")
	if not await _play(false):
		return
	await _after()

var _sat_down := false

func _frost() -> float:
	var rime = player.vis.get_meta("frost_over", null)
	return (rime as StandardMaterial3D).albedo_color.a if rime is StandardMaterial3D else -1.0

## Sat, held, facing the woman and the child, at the place he chose.
func _check_sat(label: String) -> void:
	check(not player.input_enabled and player.state == Player.S.REST, "%s: the Bearer is sat and does not get up" % label)
	# (the sit is played once and held: a finished one-shot reads as "")
	check(player.vis.current_clip() in [String(DB.tuning("endings/hearth_kept/sit_clip", "")), ""] and _sat_down,
		"%s: sat by the spring (%s)" % [label, player.vis.current_clip()])
	check(player.global_position.distance_to(ec.kept_spot()) < 1.0, "%s: where he chose (%.2f m off)" % [label, player.global_position.distance_to(ec.kept_spot())])
	var maren: NPC = _souls().get("maren")
	check(maren != null and _souls().has("wren"), "%s: a woman has a small child by the hand, down at the water (%s)" % [label, str(_souls().keys())])
	if maren != null:
		var to_m := _flat(maren.global_position - player.global_position).normalized()
		var facing := _flat(-player.vis.global_transform.basis.z).normalized()
		check(facing.dot(to_m) > 0.9, "%s: facing them (%.2f)" % [label, facing.dot(to_m)])
	check(_leadvoices().is_empty(), "%s: his mother is gone from where she sat" % label)
	check(not hud.visible, "%s: no HUD" % label)
	var cs := _cam_state()
	check(String(cs["name"]) == "EndingCam" and cs["ok"], "%s: the ending's camera, back and up, over the ground and upright (%.2f m over, up.y %.2f)" % [
		label, float(cs["over"]), float(cs["up"])])

func _check_world(label: String) -> void:
	check(World.get_area_state("coldwell") == RH.WState.THAW and area.thaw_layer.visible and not area.rime_layer.visible,
		"%s: the Coldwell is the Melt" % label)
	var frozen: Array = OTHERS.filter(func(a): return World.get_area_state(a) == RH.WState.RIME and not Game.toggle_free(a))
	check(frozen.size() == OTHERS.size() and not Game.toggle_free("coldwell"), "%s: every other region is RIME and no hearth will turn it (%d of %d)" % [
		label, frozen.size(), OTHERS.size()])
	World.set_area_state("tarnhall", RH.WState.THAW)
	check(World.get_area_state("tarnhall") == RH.WState.RIME, "%s: nothing warms it again" % label)

## He cannot be walked, rolled, or made to pick anything up.
func _check_held(label: String) -> void:
	var p0 := player.global_position
	player.sim_move = Vector3(0, 0, -1)
	await _secs(1.0)
	player.sim_move = Vector3.ZERO
	var used := player.try_interact()
	_act("interact")
	_act("inventory")
	await _secs(0.6)
	check(player.global_position.distance_to(p0) < 0.05 and not used and not player.input_enabled and player.state == Player.S.REST,
		"%s: no key moves him (%.2f m)" % [label, player.global_position.distance_to(p0)])
	check(_ui("RestUI") == null and _ui("DialogueUI") == null and get_tree().get_nodes_in_group("inventory_ui").is_empty(), "%s: and none opens anything" % label)

func _play(let_go: bool) -> bool:
	if not await _stand_at(ec.kept_spot(), "Keep the horn shut, and sit"):
		return false
	var chosen := []
	ec.chosen.connect(func(e): chosen.append(e))
	await _shot("choice")
	if not await _take_ending():
		return false
	check(chosen == ["hearth_kept"] and World.flag("ending_hearth_kept") and World.kept() and World.ended() == "hearth_kept" and not World.spring(),
		"ending_hearth_kept: World.kept()")
	check(not ec.is_open(), "the other is no longer offered")
	await _until(func(): return _beat_names().has("begin"), 3.0)
	check(not player.input_enabled and not hud.visible, "the HUD goes; the Bearer's hands are not the player's")
	check(String(_beat("begin").get("cam", "")) == "EndingCam", "the ending has its own camera")
	var sat_ok := await _until(func(): return _beat_names().has("sit"), 40.0)
	check(sat_ok and _beat_names() == BEATS.slice(0, 4), "its beats, in order: %s" % str(_beat_names()))
	if not sat_ok:
		return false
	check(float(_beat("shut")["t"]) < 2.0 and String(_beat("melt")["music"]) == "", "the stopper is pressed home; no music (%s)" % str(_beat("melt")["music"]))
	check(_beat("melt")["thaw"] and (_beat("melt")["souls"] as Array).has("maren") and (_beat("melt")["souls"] as Array).has("wren"),
		"the remembered Melt comes back over the Coldwell: a woman and a child at the water")
	check(int(_beat("sit")["state"]) == Player.S.REST and not _beat("sit")["input"], "he sits down by the spring")
	check(World.slot_summary(World.active_slot)["ending"] == "hearth_kept", "the save written at the ending knows how it ended")
	check(_horn().begins_with("The horn a child carries down the water."), "the horn is shut, and still has its coal")
	check(player.vis.model_id != "bearer_outsong", "nobody put a mask on")
	_sat_down = String(_beat("sit")["clip"]) == String(DB.tuning("endings/hearth_kept/sit_clip", ""))
	check(_sat_down, "the sit is played (%s)" % str(_beat("sit")["clip"]))
	await _secs(1.0)
	_check_sat("sat")
	_check_unharmed("sat")
	await _shot("sat")
	var rolled := await _until(func(): return d.beats.has("credits") and d.credits != null and is_instance_valid(d.credits), 30.0)
	check(rolled, "the credits roll over it (%.1f s in)" % d._t)
	if not rolled:
		return false
	var roll: CreditsUI = d.credits
	var texts: Array = roll.lines.map(func(e): return String(e[1]))
	check(texts.has("RIMEHOLT") and texts.has("Figglebottom Productions") and roll.lines.any(func(e): return e[0] == "knot"),
		"one column: the game, the house, the tools, a knot at the foot (%d lines)" % roll.lines.size())
	check(roll.over_world and not hud.visible and AudioDirector._active_music == "", "over the world, no HUD, no music: there is the river")
	var frost0 := _frost()
	await _shot("credits")
	var f0 := Engine.get_physics_frames()
	var whole := roll.duration()
	if let_go:
		await _secs(3.0)
		check(is_instance_valid(roll) and not d.done, "(they are rolling)")
		_act("ui_accept")
		var ended := await _until(func(): return d.done, 8.0)
		check(ended and (Engine.get_physics_frames() - f0) / 60.0 < 10.0, "Enter lets them go (%.1f s of %.0f)" % [(Engine.get_physics_frames() - f0) / 60.0, whole])
	else:
		await _secs(6.0)
		check(await _esc_opens(), "while they roll, Esc still raises the sheet")
		check(await _esc_closes(), "and Return to the World puts it away")
		var ended2 := await _until(func(): return d.done, whole + 30.0)
		var sat_s := (Engine.get_physics_frames() - f0) / 60.0
		check(ended2 and sat_s > whole * 0.5, "sat through, they end by themselves (%.0f s; the roll is %.0f s)" % [sat_s, whole])
		check(_frost() > frost0 + 0.2 and _frost() > 0.4, "while they roll, the frost comes onto his shoulders (%.2f -> %.2f)" % [frost0, _frost()])
	await ticks(10)
	check(_beat_names() == BEATS, "credits, end (%s)" % str(_beat_names()))
	_check_beats("the Hearth Kept")
	_check_watch("the Hearth Kept and its credits")
	check(is_instance_valid(d) and EndingDirector.active == d and _credit_rolls().is_empty(), "it does not end: it stays, and the credits do not come round again")
	_check_sat("after the credits")
	_check_world("after the credits")
	await _check_held("after the credits")
	return true

func _after() -> void:
	print("== a kept save: the sheet, the title, and back")
	check(await _esc_opens(), "Esc raises the sheet over the Bearer, sat")
	var names: Array = _sheet_buttons().map(func(x): return x.text)
	check(names.has("Return to the World") and names.has("Return to the Title"), "it offers the world and the title (%s)" % str(names))
	check(await _esc_closes(), "Return to the World puts it away")
	_check_sat("the sheet closed")
	for round in 2:
		_watch(false)
		var title := await _to_title()
		check(World.slot_summary(World.active_slot)["ending"] == "hearth_kept", "the slot's ledger: hearth_kept")
		if not await _resume(title):
			return
		_watch(true, false)
		await ticks(20)
		print("== resumed (%d)" % (round + 1))
		check(Game.current_area_id == World.KEPT_AREA and World.kept(), "a kept save opens on the Coldwell (%s)" % Game.current_area_id)
		ec = _choice()
		d = EndingDirector.active
		check(d != null and is_instance_valid(d) and d.beats == ["kept"], "on the Bearer, sat (%s)" % (str(d.beats) if d != null else "no director"))
		check(ec != null and not ec.is_open(), "the spring offers nothing")
		_check_sat("resumed")
		_check_world("resumed")
		check(_frost() > 0.4, "the frost is on him (%.2f)" % _frost())
		check(_credit_rolls().is_empty(), "the credits do not roll again")
		check(AudioDirector._active_music == "" or not String(AudioDirector._active_music).contains("outsong"), "nothing is sung (%s)" % AudioDirector._active_music)
		await _check_held("resumed")
		await _secs(2.0)
		check(not hud.visible, "still no HUD a moment later")
		var card = hud.get("_title_layer")
		check(card == null or not is_instance_valid(card) or not (card as CanvasLayer).visible, "and no place card over him")
		_check_watch("resumed")
		check(await _esc_opens(), "Esc raises the sheet")
		check(await _esc_closes(), "and puts it away")
	_watch(false)
