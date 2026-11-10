extends TestBase
## The post-release THAW scenes (LOWE.md 8, KETTLE.md 9): NPCs that sit
## (npcs.json / area "pose": "sit", "sit_talk", with a seat sized to them),
## that keep their pose and do not turn or stand to greet, and conversations
## the Bearer can only overhear ("overhear"). The Lowe: Arne with Liv and
## Asta outside the twins' barrow, only once the Turfwright is released.
## Kettle Fjord: Old Pell and Ivo at the fish-kettle, only once the
## Ice-Cutter is released; Ivo moves there from the dogs and can still be
## given his mitten.

var area: Area
var player: Player
var hud: HUD

func _ready() -> void:
	_run.call_deferred()

func _secs(s: float):
	await ticks(int(ceil(s * 60.0)))

func _build(id: String, state: RH.WState) -> void:
	if area != null and is_instance_valid(area):
		area.free()
	World.set_area_state(id, state)
	area = AreaBuilder.build(id)
	add_child(area)
	Game.register_area(area, id)
	StateDirector.snap(area, state)
	await ticks(10)

func _npcs() -> Dictionary:
	var out := {}
	for c in area.find_children("*", "NPC", true, false):
		var n := c as NPC
		if n.is_visible_in_tree():
			if out.has(n.npc_id):
				out[n.npc_id + "#2"] = n
			else:
				out[n.npc_id] = n
	return out

func _talkable(n: NPC) -> bool:
	return not n.find_children("*", "Interactable", true, false).is_empty()

func _seat(n: NPC) -> MeshInstance3D:
	return n.get_node_or_null("Seat") as MeshInstance3D

## Stand by `n` and collect what is overheard for `secs` seconds.
func _listen(n: NPC, secs: float) -> Array:
	var heard := []
	var on := func(who: String, line: String): heard.append([who, line])
	n.overheard.connect(on)
	player.global_position = n.global_position + Vector3(0, 0.3, 3.0)
	await _secs(secs)
	n.overheard.disconnect(on)
	return heard

func _run() -> void:
	World._save_dir = "user://test_release_scenes"
	World.reset()
	await _build("lowe_barrows", RH.WState.THAW)
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	player.invulnerable = true
	hud = HUD.new()
	add_child(hud)
	await ticks(10)
	await _lowe()
	await _kettle()
	finish()

# ------------------------------------------------------------------ the Lowe
func _lowe() -> void:
	print("== the Lowe in THAW, before the release: the turf-cutters' yard")
	var seen := _npcs()
	check(not seen.has("arne") and not seen.has("liv") and not seen.has("asta"), "no Arne, no twins yet")

	print("== after the release: Arne and his girls outside the barrow")
	World.set_flag("ks_turfwright_released")
	await _build("lowe_barrows", RH.WState.THAW)
	seen = _npcs()
	check(seen.has("arne") and seen.has("liv") and seen.has("asta"), "Arne, Liv and Asta are there")
	if not (seen.has("arne") and seen.has("liv") and seen.has("asta")):
		return
	var arne: NPC = seen["arne"]
	var liv: NPC = seen["liv"]
	var asta: NPC = seen["asta"]
	check(arne._vis.is_humanoid() and arne._vis.model_id == "arne_thaw" and liv._vis.model_id == "liv"
		and asta._vis.model_id == "asta", "on their own models (arne_thaw, liv, asta)")
	check(arne.seated and liv.seated and asta.seated, "all three sit")
	check(arne._vis.current_clip() == "sit_talk", "Arne talks, sitting on the grass (%s)" % arne._vis.current_clip())
	check(liv._vis.current_clip() == "sit" and asta._vis.current_clip() == "sit",
		"the twins sit on sods (%s, %s): Asta's smock no longer spreads into a disc" % [liv._vis.current_clip(), asta._vis.current_clip()])
	check(_seat(arne) == null and _seat(liv) != null and _seat(asta) != null, "a sod under each twin, none under Arne")
	if _seat(liv) != null:
		var top := (_seat(liv).mesh as BoxMesh).size.y
		check(absf(top - 0.27 * 1.1) < 0.01, "the sod is sized to a child (%.2f m high)" % top)
	check(not _talkable(arne) and not _talkable(liv) and not _talkable(asta), "nobody in the scene can be spoken to")
	var door: Vector3 = AreaBuilder._v3([46.0, 47.5, -214.0])
	var out := -arne.global_transform.basis.z
	check(out.dot(arne.global_position - door) > 0.0, "facing out, their backs to the barrow")
	check(liv.global_position.distance_to(arne.global_position) < 2.0 and asta.global_position.distance_to(arne.global_position) < 2.0,
		"the twins either side of him")

	print("== overheard")
	var y0 := liv._vis.rotation.y
	var heard := await _listen(arne, 12.0)
	check(absf(liv._vis.rotation.y - y0) < 0.01, "a seated soul does not turn to the Bearer")
	var want: Array = DB.npc("arne")["overhear"]
	check(heard.size() >= 2 and heard[0] == want[0] and heard[1] == want[1],
		"the argument starts at the start, in order (%s)" % str(heard.slice(0, 2)))
	check(hud.overheard_label.text.begins_with("Liv: ") or hud.overheard_label.text.begins_with("Arne: ")
		or hud.overheard_label.text.begins_with("Asta: "), "low over the belt, with who said it (%s)" % hud.overheard_label.text)
	heard = await _listen(arne, 4.6 * 8 + 1.0)
	check(heard.size() >= 5 and heard[heard.size() - 1] == want[want.size() - 1],
		"to the last line: %s (heard %s)" % [str(want[want.size() - 1]), str(heard.map(func(h): return h[1].left(12)))])
	player.global_position = arne.global_position + Vector3(0, 0.3, 30.0)
	var quiet := []
	var on := func(w, l): quiet.append(l)
	arne.overheard.connect(on)
	await _secs(6.0)
	arne.overheard.disconnect(on)
	check(quiet.is_empty(), "out of earshot, nothing")

	print("== RIME after the release: not there")
	await _build("lowe_barrows", RH.WState.RIME)
	check(not _npcs().has("arne"), "the scene is THAW only")

# ------------------------------------------------------------------ Kettle Fjord
func _kettle() -> void:
	print("== Kettle Fjord in THAW, before the release: Ivo with the dogs")
	await _build("kettle_fjord", RH.WState.THAW)
	var seen := _npcs()
	check(seen.has("ivo") and not seen.has("ivo#2") and not seen.has("pell"), "Ivo, no Pell")
	check(seen.has("ivo") and not (seen["ivo"] as NPC).seated, "Ivo standing by the dogs")
	var ivo_before: Vector3 = (seen["ivo"] as NPC).global_position if seen.has("ivo") else Vector3.ZERO

	print("== after the release: Pell and Ivo at the kettle")
	World.set_flag("ks_ice_cutter_released")
	await _build("kettle_fjord", RH.WState.THAW)
	seen = _npcs()
	check(seen.has("pell") and seen.has("ivo") and not seen.has("ivo#2"), "Old Pell, and one Ivo")
	if not (seen.has("pell") and seen.has("ivo")):
		return
	var pell: NPC = seen["pell"]
	var ivo: NPC = seen["ivo"]
	check(pell._vis.model_id == "pell_thaw" and pell.seated and pell._vis.current_clip() == "sit", "Pell sits (pell_thaw, sit)")
	check(ivo.seated and ivo._vis.current_clip() == "sit" and ivo.global_position.distance_to(ivo_before) > 1.0,
		"Ivo has moved to the kettle and sits")
	check(_seat(pell) != null and _seat(ivo) != null, "each on a crate")
	if _seat(ivo) != null:
		check(absf((_seat(ivo).mesh as BoxMesh).size.y - 0.27 * 1.55) < 0.01, "Ivo's crate is sized to him")
	check(pell.global_position.distance_to(ivo.global_position) < 4.5, "across the fire from each other")
	var kettle := Vector3.INF
	for k in area.find_children("*", "Node3D", true, false):
		if String(k.name).contains("fish_kettle") and (kettle == Vector3.INF
				or (k as Node3D).global_position.distance_to(pell.global_position) < kettle.distance_to(pell.global_position)):
			kettle = (k as Node3D).global_position
	if kettle != Vector3.INF:
		var f := -pell.global_transform.basis.z
		var to := kettle - pell.global_position
		to.y = 0
		check(f.dot(to.normalized()) > 0.7, "Pell faces the kettle")
	check(not _talkable(pell) and _talkable(ivo), "Pell cannot be spoken to; Ivo can")

	print("== overheard at the kettle")
	var heard := await _listen(pell, 6.0)
	var want: Array = DB.npc("pell")["overhear"]
	check(heard.size() >= 1 and heard[0] == want[0], "Pell: %s" % str(want[0][1]))
	heard = await _listen(pell, 4.6 * 6 + 1.0)
	check(heard.size() >= 4 and heard[heard.size() - 1] == want[want.size() - 1], "to the last line (heard %s)" % str(heard.map(func(h): return h[1].left(12))))

	print("== Ivo's mitten still goes home")
	player.give_item("item_ivo_mitten", 1)
	var cfg := DB.npc("ivo")
	cfg["id"] = "ivo"
	ivo._on_talk(player)
	await ticks(4)
	check(World.flag("ks_ivo_mitten"), "seated, he takes the mitten")
	check(ivo._vis.current_clip() == "sit", "and talks from where he sits (%s)" % ivo._vis.current_clip())
	for ui in get_tree().root.find_children("*", "DialogueUI", true, false):
		(ui as DialogueUI).close()
	await ticks(4)
	check(ivo._vis.current_clip() == "sit", "still sitting after")
