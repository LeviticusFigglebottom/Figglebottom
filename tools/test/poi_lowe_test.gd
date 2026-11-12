extends PoiBase
## The Lowe's points of interest (docs/lore/POI.md 3): the Bread Mound, the
## Last Mound, Hesk's Fire, the Cutter's Bothy and the Rise. Each is walked
## to and used: the pickup can be taken, the plaque reads, the overheard
## exchange plays in order, the thread step sets.

func _ready() -> void:
	_run.call_deferred()

func _any_solid(kit: String) -> bool:
	# some stand tight against a mound, where there is no level run-up: try each
	for n in area.find_children(kit + "*", "Node3D", true, false):
		if String(n.get_meta("kit_id", "")) == kit and (n as Node3D).is_visible_in_tree() and await solid(n):
			return true
	return false

func _run() -> void:
	await setup("lowe_barrows")
	var def: Dictionary = area.get_meta("def")
	var road := ground(-38.0, -124.0)
	var hearth := ground(32.0, -163.5)

	print("== THAW: what stands there")
	for kit in ["lw_peat_sled", "lw_bier", "lw_kin_post", "lw_bloomery", "lw_spade_rack", "lw_sod_row", "lw_mound_steps", "lw_edging_stone"]:
		check(prop(kit) != null and prop(kit).find_children("*", "MeshInstance3D", true, false).size() > 0, "%s is out, modelled" % kit)
	check(area.find_children("Scatter_peat_stack*", "MultiMeshInstance3D", true, false).size() > 0
		and area.find_children("Scatter_peat_wall*", "MultiMeshInstance3D", true, false).size() > 0
		and area.find_children("Scatter_peat_row*", "MultiMeshInstance3D", true, false).size() > 0, "peat in stacks, a wall and footed rows")
	var stack_mm := area.find_children("Scatter_peat_stack*", "MultiMeshInstance3D", true, false)[0] as MultiMeshInstance3D
	check(stack_mm.multimesh.mesh.get_faces().size() / 3 > 500, "a stack is cut peats laid herringbone, not a box (%d tris)" % (stack_mm.multimesh.mesh.get_faces().size() / 3))
	check(prop("lw_heather_bunch") != null and prop("lw_heather_heap") == null, "one fresh bunch at the Last Mound's door")
	check(prop("lw_three_spades") != null and prop("lw_dinner_cloth") != null, "three spades by the bothy door, a dinner on the bench")
	check(pickup("birch_cup") == null and pickup("spade_iron") == null and pickup("small_spades") == null, "nothing to pick up yet")
	check(reaches(road, hearth), "the Barrow Road still runs from the mounds to the Drying Stacks")

	print("== the Bread Mound, THAW")
	var cloth := prop("lw_bread_cloth")
	var cup := prop("lw_birch_cup")
	check(cloth != null and cup != null, "a cloth and an upturned cup on kin_b")
	var kb: Dictionary = (def["houses"] as Array).filter(func(h): return h["id"] == "kin_b")[0]
	var pad_y := float(kb["y"])
	check(cloth.global_position.y - pad_y > 2.4 and cloth.global_position.y - pad_y < 3.6,
		"they lie on the mound's crown (%.2f m over its foot)" % (cloth.global_position.y - pad_y))
	var steps := prop("lw_mound_steps")
	var foot := steps.global_position + steps.global_transform.basis.z * 2.4
	await stand(Vector3(foot.x, area.terrain.height_at(foot.x, foot.z), foot.z))
	var family := npc("bread_family")
	check(family != null and family.find_children("*", "CollisionObject3D", true, false).is_empty(), "the family going home are voices")
	check(Vector2(player.global_position.x - family.global_position.x, player.global_position.z - family.global_position.z).length() < 12.0,
		"within 12 m of the mound at the foot of the steps")
	var heard: Array = await overhear(family, 72.0)
	var want: Array = (DB.npc("bread_family")["overhear"] as Array).map(func(e): return String(e[1]))
	check(heard_in_order(heard, want), "the exchange is overheard, six lines in order (%d heard)" % heard.size())
	# up the sod steps and along the ridge to the cloth
	var top := steps.global_position - steps.global_transform.basis.z * 1.5
	await walk_to(top, 500, 0.7)
	check(player.global_position.y - pad_y > 1.2, "the sod steps carry the Bearer up the shoulder (%.2f m)" % (player.global_position.y - pad_y))
	await walk_to(cloth.global_position, 500, 0.9)
	check(player.global_position.distance_to(cloth.global_position) < 1.6 and player.is_on_floor(),
		"and he stands at the cloth on the crown (%.2f m off)" % player.global_position.distance_to(cloth.global_position))
	await walk_to(top, 500, 0.8)
	await walk_to(Vector3(foot.x, 0, foot.z), 500, 1.0)
	check(player.global_position.y - pad_y < 0.6, "and comes down again the way he went up")

	print("== Aud and Hesk are met")
	await stand(ground(-36.0, -123.5))
	check((await talk("aud")).size() > 0 and World.flag("ks_aud_met"), "Aud is met")
	await stand(ground(-56.0, -163.0))
	check((await talk("hesk")).size() > 0 and World.flag("ks_hesk_met"), "Hesk is met")
	var hesk := npc("hesk")
	var furnace := prop("lw_bloomery")
	var back := hesk.global_transform.basis.z
	check((furnace.global_position - hesk.global_position).normalized().dot(back) > 0.7
		and furnace.global_position.distance_to(hesk.global_position) < 4.0, "his furnace is behind him")

	print("== collision: the hero props are solid")
	for kit in ["lw_bloomery", "lw_spade_rack", "lw_peat_sled", "lw_bier", "lw_kin_post", "lw_stone_b", "lw_stone_c", "lw_turf_barrow"]:
		check(await _any_solid(kit), "%s stops the Bearer" % kit)
	check(not bool(def.get("wayside", true)), "nothing strewn: the Lowe is dressed by hand")

	print("== the Rise")
	await stand(hearth)
	var txt: String = await read(plaque("THE DRYING STACKS"))
	check(txt.contains("There is more turf cut here than the Lowe has barrows."), "the plaque on the Rise reads")
	var veil: Array = def["frost_veils"][0]["at"]
	check(reaches(player.global_position, Vector3(veil[0], veil[1], veil[2] + 3.0)), "the road runs on from the Rise to the hollow")

	print("== RIME")
	await turn(RH.WState.RIME)
	check(prop("lw_heather_heap") != null and prop("lw_heather_bunch") == null, "the Last Mound: heather heaped to the height of the door")
	check(prop("lw_bread_cloth") == null, "the Bread Mound: the cloth is gone")
	check(prop("lw_three_spades") == null, "the bothy: the big spade is gone")

	await stand(Vector3(foot.x, area.terrain.height_at(foot.x, foot.z), foot.z))
	await walk_to(top, 500, 0.7)
	var bc := pickup("birch_cup")
	check(bc != null and bc.global_position.y - pad_y > 2.4, "the cup is still on the crown")
	await walk_to(bc.global_position, 500, 0.7)
	await ticks(6)
	var it := player.nearest_interactable()
	check(it != null and it.prompt == "Prise the cup off the turf" and player.try_interact(), "the cup is prised off the turf")
	await ticks(4)
	check(int(player.inventory.get("item_birch_cup", 0)) == 1, "Birch Cup in the Pack")

	var heap := prop("lw_heather_heap")
	await stand(ground(14.0, -143.0))
	txt = await read(plaque("THE LAST MOUND"))
	check(txt.contains("All of it is purple."), "the Last Mound plaque reads")
	var spade := pickup("turf_spade")
	check(spade != null and await take("turf_spade"), "the spade propping the door can still be worked loose past the heap")
	var keener: Array = (def["spawners"] as Array).filter(func(s): return s["id"] == "keener_mounds")
	var kf := deg_to_rad(float(keener[0]["face"]))
	var kpos := AreaBuilder._v3(keener[0]["at"])
	check(Vector3(-sin(kf), 0, -cos(kf)).dot((heap.global_position - kpos).normalized()) < -0.8, "the Keener at the bend has its back to the heap")

	await stand(ground(-56.0, -163.0))
	check(await take("spade_iron"), "the spade-iron is taken off the edging stone")
	check(int(player.inventory.get("item_spade_iron", 0)) == 1, "Spade-Iron in the Pack")

	await stand(hearth)
	check(await take("small_spades"), "the two small spades are taken from the bothy door")
	check(int(player.inventory.get("item_small_spades", 0)) == 1, "Two Small Spades in the Pack")
	check(reaches(player.global_position, hearth), "the bothy's pad lets him back to the hearth")

	print("== THAW again: who they belonged to")
	await turn(RH.WState.THAW)
	await stand(ground(-36.0, -123.5))
	var lines: Array = await talk("aud")
	check(lines.has("That's the miller's lot. They leave something every year and then send a child up for it."), "Aud knows whose cup it is (%s)" % str(lines.slice(0, 1)))
	check(int(player.inventory.get("item_birch_cup", 0)) == 1, "she does not take it")
	await stand(ground(-56.0, -163.0))
	lines = await talk("hesk")
	check(World.flag("ks_hesk_iron") and int(player.inventory.get("item_spade_iron", 0)) == 0, "Hesk takes the iron: the thread step sets")
	check(lines.has("He'll have it by the morning. I always have it back to him by the morning."), "he says Arne will have it by the morning")
	check(journal("hesk_tongs").any(func(l): return String(l).begins_with("Showed Hesk the half-edged spade-iron.")), "the journal has the line")
	finish()
