extends PoiBase
## Shepherd's Reach's points of interest (docs/lore/POI.md 7): the Counting
## Stone, Smudge, the Lower Sheiling and the Drift Lane. Each is walked to
## and used: the pickup can be taken, the plaques read, the shortcut opens
## from the lane side only, the Smudge thread's four steps set.

const LANE_GATE := "gate_drift_lane"

func _lane_gates() -> Array:
	return area.find_children("*", "ShortcutGate", true, false).filter(func(g): return (g as ShortcutGate).gate_id == LANE_GATE)

func _ready() -> void:
	_run.call_deferred()

func _plen(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
	return l

func _outdoor(kit: String) -> Node3D:
	# the one standing in the open: house furniture does not collide
	for n in area.find_children(kit + "*", "Node3D", true, false):
		if String(n.get_meta("kit_id", "")) == kit and (n as Node3D).is_visible_in_tree() \
				and not n.find_children("*", "CollisionShape3D", true, false).is_empty():
			return n
	return null

func _run() -> void:
	await setup("shepherds_reach")
	var def: Dictionary = area.get_meta("def")
	var hearth := ground(604.0, -303.5)
	var lane: Array = [Vector2(607.0, -340.5), Vector2(615.0, -347.5), Vector2(625.0, -354.5), Vector2(636.0, -361.0), Vector2(645.0, -366.2)]
	# (the Drift Lane's; the Reach's way on, ADR 0015, is a gate of its own)
	var gate_spec: Dictionary = (def["gates"] as Array).filter(func(g): return String(g.get("id", "")) == LANE_GATE)[0]
	var gate_at := AreaBuilder._v3(gate_spec["at"])
	var up: Vector2 = ((lane[1] as Vector2) - (lane[0] as Vector2)).normalized()
	var below := ground(gate_at.x - up.x * 2.2, gate_at.z - up.y * 2.2)      # on the beck side of the gate
	var inside := ground(gate_at.x + up.x * 2.2, gate_at.z + up.y * 2.2)     # in the lane
	var lane_mid := ground((lane[2] as Vector2).x, (lane[2] as Vector2).y)
	var lane_top := ground(644.0, -365.6)        # the lane's head, short of the fold wall's foot
	var veil := AreaBuilder._v3(def["frost_veils"][0]["at"])

	print("== THAW: what stands there")
	for kit in ["sr_shearing_stool", "sr_cheese_press", "sr_wool_frame", "sr_creep_wall", "sr_slab_gate", "sr_slab_posts", "sr_crook_rack",
			"sr_counting_stone", "sr_coping_row", "sr_heather_bed_thrown", "sr_pot_bowls", "sr_smudge", "sr_ewe"]:
		check(prop(kit) != null and prop(kit).find_children("*", "MeshInstance3D", true, false).size() > 0, "%s is out, modelled" % kit)
	check(not bool(def.get("wayside", true)), "nothing strewn: the Reach is dressed by hand")
	check(pickup("calder_blanket") == null and pickup("smudge_look") == null and pickup("fold_cache") == null, "RIME's finds are not here yet")
	check(_lane_gates().filter(func(g): return (g as Node3D).is_visible_in_tree()).is_empty(),
		"the Drift Lane's gate stands open in THAW (no gate there)")
	check(reaches(below, lane_top) and _plen(_path(below, lane_top)) < 60.0, "and the lane runs from the beck's bank to the fold wall (%.0f m)" % _plen(_path(below, lane_top)))

	print("== the Lower Sheiling, THAW")
	var s0: Dictionary = (def["houses"] as Array)[0]
	var s0c := Vector3(float(s0["center"][0]), float(s0["y"]), float(s0["center"][1]))
	await stand(hearth)
	check(await walk_path(s0c + Vector3(0, 0, 0.2), 2400, 1.0), "from the hearth in through the sheiling door (the door is on the latch)")
	check(absf(player.global_position.y - s0c.y) < 0.4 and player.global_position.distance_to(s0c) < 2.0, "the Bearer stands inside it")
	var thrown := 0
	for n in area.find_children("*", "Node3D", true, false):
		if String(n.get_meta("kit_id", "")) == "sr_heather_bed_thrown" and (n as Node3D).is_visible_in_tree():
			thrown += 1
	check(thrown == 2 and prop("sr_heather_bed") == null, "two heather beds, both a mess")
	check(pickup("calder_boots") == null or not pickup("calder_boots").is_visible_in_tree(), "no boots by the door in THAW")
	check(pickup("shepherds_whistle") != null, "the whistle is still on its nail outside")

	print("== the Counting Stone, THAW")
	await stand(hearth)
	var txt: String = await read(plaque("THE COUNTING STONE"))
	check(txt.contains("Forty-three pebbles, and room in the hollow for one more."), "the THAW plaque reads")
	var stone := prop("sr_counting_stone")
	var bz := 0.0
	for b in def["boxes"]:
		if String(b.get("mat", "")) == "M_wood" and float(b["max"][0]) - float(b["min"][0]) > 2.0:
			bz = float(b["max"][2])
	check(stone.global_position.z > bz + 1.0, "the stone is on the south bank, not on the bridge (%.1f m short of the planks)" % (stone.global_position.z - bz))
	var south := ground(618.0, bz + 2.5)
	var north := ground(618.0, bz - 14.0)
	await stand(south)
	check(await walk_path(north, 1800, 1.0), "over the plank bridge, between the slab gate's posts: nothing in the way")

	print("== Smudge, THAW: Calder counts her last")
	check(pickup("smudge_pocket") != null and not pickup("smudge_pocket")._zone.enabled, "no pocket to turn out without the fleece")
	var calder := npc("old_calder")
	await stand(calder.global_position + Vector3(-2.0, 0, 1.5))
	await talk("old_calder")
	await talk("old_calder")
	check(not World.flag("ks_smudge_named"), "his two tales first")
	var lines: Array = await talk("old_calder")
	check(lines.has("Forty-one, forty-two. Where's Smudge. There's Smudge.") and World.flag("ks_smudge_named"), "then the count: Smudge is named")
	check(journal("smudge") == ["Old Calder counts a ewe called Smudge last, every time."], "the Smudge thread starts")

	print("== collision")
	for kit in ["sr_creep_wall", "sr_wool_frame", "sr_counting_stone", "sr_cheese_press", "sr_fodder_rack", "sr_stone_trough", "sr_lamb_pen"]:
		check(await solid(_outdoor(kit)), "%s stops the Bearer" % kit)
	var wall_out := ground(lane[2].x + up.y * 4.5, lane[2].y - up.x * 4.5)
	await stand(wall_out)
	await walk_to(lane_mid, 240, 0.5)
	check(Vector2(player.global_position.x - lane_mid.x, player.global_position.z - lane_mid.z).length() > 1.0, "the lane's wall is a wall: no walking through it")

	print("== RIME")
	await turn(RH.WState.RIME)
	var gate: ShortcutGate = _lane_gates()[0]
	check(gate.is_visible_in_tree() and not gate._is_open(), "the lane's gate is tied shut")
	var flock := get_tree().get_nodes_in_group("flock_rime")
	var in_lane := 0
	for sh in flock:
		var p := (sh as Node3D).global_position
		for i in lane.size() - 1:
			var a: Vector2 = lane[i]
			var b: Vector2 = lane[i + 1]
			var t := clampf((Vector2(p.x, p.z) - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			if (a + (b - a) * t).distance_to(Vector2(p.x, p.z)) < 4.0:
				in_lane += 1
	check(flock.size() == 71 and in_lane == 0, "seventy frozen sheep and Smudge, none in the lane or within 2 m of its wall (%d, %d)" % [flock.size(), in_lane])
	await stand(below)
	check(_plen(_path(below, inside)) > 40.0, "from the beck the lane is the long way round (%.0f m)" % _plen(_path(below, inside)))
	check(await use_at(below, "Tied from the other side", 1.2), "the gate says so: tied from the other side")
	await ticks(10)
	check(not gate._is_open(), "and stays tied")
	var long_way := _plen(_path(hearth, veil))

	await stand(hearth)
	check(prop("sr_heather_bed") != null, "the sheiling: one bed made")
	check(await take("calder_blanket"), "the blanket is taken off the made bed, inside the sheiling")
	check(int(player.inventory.get("item_calder_blanket", 0)) == 1, "Calder's Blanket in the Pack")
	var smudge := prop("sr_smudge")
	var door := AreaBuilder._v3([float(def["edges"]["buildings"][0]["doors"][0][0]), 0, float(def["edges"]["buildings"][0]["doors"][0][1])])
	var facing := -smudge.global_transform.basis.z
	var to_door := (Vector3(door.x, 0, door.z) - Vector3(smudge.global_position.x, 0, smudge.global_position.z)).normalized()
	var to_fold := (Vector3(veil.x, 0, veil.z) - Vector3(smudge.global_position.x, 0, smudge.global_position.z)).normalized()
	check(facing.dot(to_door) > 0.9 and facing.dot(to_fold) < 0.3, "Smudge faces the door, not the fold")
	_lore.clear()
	check(await take("smudge_look"), "the ewe can be looked at")
	check(not _lore.is_empty() and String(_lore[0]).contains("She is facing the door.") and World.flag("ks_smudge_found"), "the look reads, and the thread step sets")
	hud.lore_root.visible = false
	hud.lore_root.remove_from_group("lore_open")
	player.lock_control(false)
	await ticks(10)
	check(pickup("smudge_look") != null, "she is looked at, not taken")
	txt = await read(plaque("THE COUNTING STONE"))
	check(txt.contains("Every one of them is facing up the hill."), "the RIME plaque reads, on the same board")

	print("== the Drift Lane, from the top")
	await stand(lane_top)
	check(await walk_path(lane_mid, 1800, 1.2), "in at the lane's top beside the fold gap, and down it")
	check(await take("fold_cache"), "the cache on the wall halfway down")
	check(await use_at(inside, "Untie the gate", 1.2), "the gate is untied from the lane side")
	await ticks(90)
	check(gate._is_open() and World.area_flag("shepherds_reach", "gate_gate_drift_lane"), "it stands open, and stays so")
	var nwait := 0
	while _plen(_path(below, inside)) > 12.0 and nwait < 600:
		await ticks(10)
		nwait += 10
	check(_plen(_path(below, inside)) < 12.0, "the way through it is on the map")
	var short_way := _plen(_path(hearth, veil))
	check(short_way < long_way + 1.0, "the run from the Sheilings hearth to the fold gap by the lane (%.0f m, was %.0f m by the trod)" % [short_way, long_way])
	await stand(below)
	check(await walk_path(lane_top, 3600, 1.5), "walked: the beck, the lane, the fold gap")

	print("== THAW again")
	await turn(RH.WState.THAW)
	calder = npc("old_calder")
	await stand(calder.global_position + Vector3(-2.0, 0, 1.5))
	lines = await talk("old_calder")
	check(World.flag("ks_smudge_told") and lines.has("Never come to a call in her life, that one. She comes to a pocket."), "Calder: she comes to a pocket (%s)" % str(lines.slice(0, 1)))
	var sig := npc("sigga")
	await stand(sig.global_position + Vector3(1.5, 0, 1.5))
	await talk("sigga")
	lines = await talk("sigga")
	if not lines.has("That's not his. His is the one on the floor."):
		lines = await talk("sigga")
	check(World.flag("sigga_blanket_shown"), "Sigga is shown the blanket")
	await stand(hearth)
	player.give_item("armour_fleece", 1)
	await ticks(40)
	var w0: int = Game.warmth
	check(pickup("smudge_pocket")._zone.enabled, "with the Shepherd's Fleece, the pocket can be turned out")
	check(await take("smudge_pocket"), "by the ewe: turn out the pocket")
	check(World.flag("ks_smudge_fed") and Game.warmth - w0 == 90, "Smudge is fed: a bog-iron's worth of warmth (%d)" % (Game.warmth - w0))
	check(journal("smudge").size() == 4 and journal("smudge")[3] == "Smudge ate the oatcake from the fleece's pocket and went back to the sheiling door.", "the Smudge thread is whole, in order")
	check(journal("calder_boots").size() <= 1, "and Calder's boots is its own thread still")
	finish()
