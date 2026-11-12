extends PoiBase
## The three weapons placed as finds (ADR 0015 left them with nothing that
## gave them): the spear at the Holms' kin-post on the Lowe, the greatblade
## in the oar-stand at Tarnhall's landing, the bow on the lower sheiling's
## wall on Shepherd's Reach. For each: it is there in THAW and in RIME, it can
## be seen from the route and does not stand in it, a steered Bearer walks
## from the route to it and takes it, equips it, and lands a hit with it.

const FINDS := [
	# area, pickup id, weapon, a route point beside it, and a farther one the route must still reach
	["lowe_barrows", "kin_spear", "spear", Vector2(-52.5, -116.7), Vector2(-38.0, -124.0)],
	["tarnhall", "oar_greatblade", "greatblade", Vector2(130.5, -333.0), Vector2(146.0, -333.2)],
	["shepherds_reach", "sheiling_bow", "bow", Vector2(604.0, -306.5), Vector2(617.0, -327.0)],
]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for f in FINDS:
		await _find(String(f[0]), String(f[1]), String(f[2]), f[3], f[4])
		await _teardown()
	finish()

func _teardown() -> void:
	for n in [hud, player, area]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await ticks(10)

func _find(id: String, pid: String, weapon: String, route2: Vector2, far2: Vector2) -> void:
	print("== %s: the %s" % [id, weapon])
	await setup(id)
	var route := ground(route2.x, route2.y)
	var far := ground(far2.x, far2.y)
	var p := pickup(pid)
	check(p != null and p.item_id == weapon, "the %s is placed in THAW" % weapon)
	if p == null:
		return
	var shown := _shown_at(p)
	var shown_off := Vector2(shown.x - p.global_position.x, shown.z - p.global_position.z).length()
	check(shown_off < 1.5, "its own model is shown at the find (%.2f m off the prompt)" % shown_off)
	var off := Vector2(p.global_position.x - route.x, p.global_position.z - route.z).length()
	check(off > 2.5 and off < 14.0, "a short step off the route (%.1f m)" % off)
	check(_seen_from(route, shown), "it can be seen from the route")
	check(reaches(route, far), "the route past it is open")
	await turn(RH.WState.RIME)
	check(pickup(pid) != null, "and it is there in RIME")
	check(_seen_from(route, shown, RH.WState.RIME), "seen from the route in RIME too")
	check(reaches(route, far), "the route past it is open in RIME")
	await turn(RH.WState.THAW)

	var np := _path(route, p.global_position)
	print("  (nav from the route ends %.2f m from the prompt)" % (Vector2(np[np.size() - 1].x - p.global_position.x, np[np.size() - 1].z - p.global_position.z).length() if np.size() > 0 else -1.0))
	await stand(route)
	var took: bool = await take(pid)
	check(took, "a steered Bearer walks from the route to it and takes it")
	await ticks(10)
	check(int(player.inventory.get(weapon, 0)) == 1 and player.hotbar.has(weapon), "the %s is in the Pack and on the Belt" % weapon)
	check(World.area_flag(id, "took_" + pid), "the find is remembered")
	check(pickup(pid) == null, "and is gone from where it was")
	if weapon == "bow":
		check(int(player.inventory.get("arrows", 0)) == 20, "twenty arrows come with the bow")

	player.equip_weapon(weapon)
	await ticks(4)
	check(player.weapon_id == weapon, "the %s is equipped" % weapon)
	if player.weapon_id != weapon:
		return
	# back on the route, facing along it: open ground for the pell
	await stand(route)
	var along := far - route
	player.vis.rotation.y = atan2(-along.x, -along.z)
	var dummy := await _pell(4.5 if weapon == "bow" else 1.6)
	var hits0 := dummy.hits_taken
	var hp0 := dummy.hp
	if weapon == "bow":
		# the bow is drawn on held input (no sim channel): draw to the cheek and loose
		player.cam.locked_target = dummy
		player._bow_drawing = true
		player._bow_t = 1.1
		player._bow_release()
		await ticks(90)
		check(int(player.inventory.get("arrows", 0)) == 19, "one arrow loosed")
	else:
		player.try_attack(false)
		await ticks(50)
	check(dummy.hits_taken == hits0 + 1 and dummy.hp < hp0, "a %s hit lands on the pell (%.0f damage)" % [weapon, hp0 - dummy.hp])
	player.cam.locked_target = null
	dummy.queue_free()

## A pell on the ground in front of the Bearer, him squared to it.
func _pell(dist: float) -> TrainingDummy:
	player.sim_move = Vector3.ZERO
	player.velocity = Vector3.ZERO
	await ticks(20)
	var fwd := -player.vis.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var at := player.global_position + fwd * dist
	at.y = area.terrain.height_at(at.x, at.z)
	var d := TrainingDummy.new()
	area.add_child(d)
	d.global_position = at
	player.vis.rotation.y = atan2(-fwd.x, -fwd.z)
	await ticks(4)
	return d

## Where the find's own model is (the prompt zone may stand off it).
func _shown_at(p: Pickup) -> Vector3:
	for c in p.get_children():
		if c is Node3D and not (c is Interactable) and not (c is Light3D):
			return (c as Node3D).global_position + Vector3(0, 0.4, 0)
	return p.global_position + Vector3(0, 0.5, 0)

## Nothing solid between an eye on the route and the find.
func _seen_from(route: Vector3, target: Vector3, state := RH.WState.THAW) -> bool:
	var q := PhysicsRayQueryParameters3D.create(route + Vector3(0, 1.6, 0), target)
	var layer := RH.L_WORLD_THAW if state == RH.WState.THAW else RH.L_WORLD_RIME
	q.collision_mask = (1 << (RH.L_WORLD_BASE - 1)) | (1 << (layer - 1))
	var hit := area.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(target) < 0.6
