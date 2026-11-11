extends TestBase
## Look pass 5: the behaviour that came with the new art. A veil keeps its
## seal and zone and melts with its dressing; the Reach's living flock ambles
## on a tether; the Coldwell's river dead hold a pose; the Hedgelayer's wall
## is built from the modelled thorn and still blocks.

var area: Area

func _ready() -> void:
	_run.call_deferred()

func _boot(id: String, state: int) -> Dictionary:
	if area != null:
		area.queue_free()
		await ticks(2)
	World.reset()
	area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	StateDirector.snap(area, state)
	await ticks(6)
	return area.get_meta("def")

func _run() -> void:
	print("== frost veils have volume, the same gate")
	await _boot("thornwold", RH.WState.RIME)
	var veils := area.rime_layer.find_children("*", "FrostVeil", true, false)
	check(veils.size() == 1, "Thornwold's veil")
	if veils.size() == 1:
		var v: FrostVeil = veils[0]
		var bb := v._plane.get_aabb()
		check(bb.size.z > 0.7, "the sheets are %.2f m through (not a card)" % bb.size.z)
		check(v._seal.collision_layer == 1 << (RH.L_WORLD_RIME - 1), "the seal is on the RIME world layer, as before")
		var box := (v._seal.get_child(0) as CollisionShape3D).shape as BoxShape3D
		check(box.size.is_equal_approx(Vector3(3.6, 3.4, 0.3)), "the seal's box is unchanged")
		check(v._zone.enabled, "the zone is live")
		check(v._dress.get_child_count() >= 2 and v._dress.visible, "it is dressed: rimed frame and drifting frost")
		check(v._dress.find_children("*", "CPUParticles3D", true, false).size() == 1, "frost drifts about it")
		v.snap_cleared()
		check(not v._plane.visible and not v._dress.visible and v._seal.collision_layer == 0, "cleared: sheets, dressing and seal all gone")
		v.respawn()
		check(v._plane.visible and v._dress.visible and v._zone.enabled, "re-armed: everything back")

	print("== the Hedgelayer's wall")
	var w := ThornWall.raise(area, Vector3(448.0, 37.8, -321.0), 0.3, 9.0, 3.0, 0.0)
	await ticks(40)
	check(w.bodies.size() >= 5, "%d colliders along 9 m" % w.bodies.size())
	var mms := w.find_children("*", "MultiMeshInstance3D", true, false)
	check(mms.size() == 1 and (mms[0] as MultiMeshInstance3D).multimesh.mesh.get_faces().size() / 3 > 3000,
			"built from the modelled thorn sections")
	check(w.is_standing() and w.distance_to(Vector3(448.0, 37.8, -321.0)) < 1.0, "standing where it was raised")
	w.sink(0.2)
	check((w.bodies[0] as StaticBody3D).collision_layer == 0, "sunk: it stops blocking at once")
	var hedges := area.rime_layer.find_children("Forest_hedge_hd_thorn3*", "MultiMeshInstance3D", true, false)
	check(hedges.size() > 6, "the frozen hedges use the modelled thorn (%d chunks)" % hedges.size())
	var shadow_only := hedges.filter(func(h): return (h as MultiMeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	check(shadow_only.size() > 0, "close up the light mesh casts for the heavy one")

	print("== the living flock ambles")
	await _boot("shepherds_reach", RH.WState.THAW)
	var fws := area.thaw_layer.find_children("FlockWander", "", true, false)
	check(fws.size() == 1, "one flock keeper in THAW")
	if fws.size() == 1:
		var fw: FlockWander = fws[0]
		check(fw.ewes.size() >= 60, "%d ewes out (a few more than before)" % fw.ewes.size())
		var cam := Camera3D.new()
		add_child(cam)
		cam.global_position = (fw.ewes[0] as Node3D).global_position + Vector3(0, 3, 6)
		cam.make_current()
		var start: Array = fw.ewes.map(func(e): return (e as Node3D).position)
		for s in fw._st:
			s["wait"] = 0.05
		await ticks(600)
		var moved := 0
		var worst := 0.0
		var off_ground := 0.0
		for i in fw.ewes.size():
			var n := fw.ewes[i] as Node3D
			var d := Vector2(n.position.x - start[i].x, n.position.z - start[i].z).length()
			moved += 1 if d > 0.3 else 0
			worst = maxf(worst, d)
			off_ground = maxf(off_ground, absf(n.position.y - area.terrain.height_at(n.position.x, n.position.z)))
		check(moved >= 3, "%d ewes near the camera have stepped off their mark" % moved)
		check(worst <= FlockWander.TETHER + 0.05, "none past her tether (furthest %.2f m)" % worst)
		check(off_ground < 0.2, "all still on the ground (%.2f m)" % off_ground)
		cam.queue_free()
	StateDirector.snap(area, RH.WState.RIME)
	await ticks(4)
	check(area.rime_layer.find_children("FlockWander", "", true, false).is_empty(), "the frozen flock has no keeper: stills")

	print("== the river dead hold a pose")
	await _boot("coldwell", RH.WState.RIME)
	var holds := area.rime_layer.find_children("PoseHold", "", true, false)
	check(holds.size() >= 15, "%d posed figures in the river" % holds.size())
	var posed := 0
	var playing := 0
	for h in holds:
		for ap in (h as Node).get_parent().find_children("*", "AnimationPlayer", true, false):
			var player := ap as AnimationPlayer
			posed += 1 if player.assigned_animation == (h as PoseHold).clip else 0
			playing += 1 if player.is_playing() else 0
	check(posed == holds.size(), "each on its clip, not the bind pose")
	check(playing == 0, "and held still")
	var springs := area.rime_layer.find_children("Water", "MeshInstance3D", true, false)
	check(springs.size() == 1, "the spring is iced over in RIME")
	finish()
