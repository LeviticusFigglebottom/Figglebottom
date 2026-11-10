class_name FullgameEndingBase
extends FullgameBase
## What the two ending walks share (fullgame_ending_outsong_test.gd,
## fullgame_ending_kept_test.gd): the start at the Wellhead Steps on the save
## the Coldwell walk ends on, the walk to the choice, a record of every beat
## as the EndingDirector raises it (was the HUD away, where was the camera),
## a watch kept on both between beats, the real Esc sheet, and the way to the
## title and back. Each ending is played twice from the same save: once with
## the credits let go (Enter), once sat through.

const WELL := Vector3(922.0, 0.0, -478.0)
const OTHERS := ["saltfell_steading", "lowe_barrows", "kettle_fjord", "tarnhall", "thornwold", "shepherds_reach"]

var _titles: Array = []
var _cards: Array = []
var ec: Node = null
var d: EndingDirector = null
## One entry per beat, taken as the director raises it.
var _beats: Array = []
## The watch between beats: what was wrong, and when.
var _watching := false
var _want_hud := false
var _wrong: Array = []
var _watch_n := 0
var _cam_low := INF      # least height of the camera over the ground under it
var _cam_up := INF       # least y of the camera's own up
var _hp0 := 0.0
var _hp_low := INF

## Through the whole ending nothing frost-taken moves, and nothing hurts him.
func _check_unharmed(label: String) -> void:
	var live: Array = _awake_foes().filter(func(e): return e.is_physics_processing() or e.target != null)
	check(live.is_empty(), "%s: nothing frost-taken lifts a hand (%d still about)" % [label, live.size()])
	check(_hp_low >= _hp0 - 0.01 and not player.dead, "%s: and nothing hurts him (%.0f of %.0f at the least)" % [label, minf(_hp_low, player.hp), _hp0])

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _choice() -> Node:
	for c in get_tree().get_nodes_in_group("ending_choice"):
		if area.is_ancestor_of(c):
			return c
	return null

func _souls() -> Dictionary:
	var out := {}
	for c in area.find_children("*", "NPC", true, false):
		var n := c as NPC
		if n.is_visible_in_tree() and not n.is_queued_for_deletion():
			out[n.npc_id] = n
	return out

func _leadvoices() -> Array:
	return get_tree().get_nodes_in_group(RH.GROUP_ENEMIES).filter(func(e):
		return e is Leadvoice and is_instance_valid(e) and not e.is_queued_for_deletion() and area.is_ancestor_of(e) \
			and (e as Node3D).is_visible_in_tree())

func _horn() -> String:
	return String(DB.item("fostering_horn")["desc"])

func _credit_rolls() -> Array:
	return get_tree().root.find_children("*", "CreditsUI", true, false).filter(func(c): return not c.is_queued_for_deletion())

# ------------------------------------------------------------------ the camera
## The camera the player is looking through: how far it is above the ground
## under it (terrain, or whatever a ray down finds), and whether it is the
## right way up. A camera under the turf shows the world's underside.
func _cam_state() -> Dictionary:
	var c := get_viewport().get_camera_3d()
	if c == null or not is_instance_valid(c):
		return {"ok": false, "why": "no camera", "over": -INF, "up": 0.0, "name": ""}
	var at := c.global_position
	var a := Game.current_area as Area
	var over := INF
	if a != null and is_instance_valid(a) and a.terrain != null:
		over = at.y - a.terrain.height_at(at.x, at.z)
	var w := c.get_world_3d()
	if w != null:
		# solid ground overhead within reach of the sky means the camera is under it
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at, RH.M_WORLD_ALL)
		q.hit_back_faces = false
		var hit := w.direct_space_state.intersect_ray(q)
		if not hit.is_empty() and a != null and a.terrain != null and (hit["collider"] as Node) != null \
				and a.terrain.is_ancestor_of(hit["collider"] as Node):
			over = minf(over, at.y - (hit["position"] as Vector3).y)
	var up := c.global_transform.basis.y.y
	var ok := over > 0.15 and up > 0.5
	return {"ok": ok, "why": "" if ok else "%.2f m over the ground, up.y %.2f, at %s" % [over, up, str(at.snapped(Vector3.ONE * 0.1))],
		"over": over, "up": up, "name": String(c.name)}

func _physics_process(_dt: float) -> void:
	if not _watching or hud == null or not is_instance_valid(hud):
		return
	_watch_n += 1
	if Game.player != null and is_instance_valid(Game.player):
		_hp_low = minf(_hp_low, Game.player.hp)
	if _watch_n % 6 != 0:
		return
	# (the Outsong hands the HUD back the moment its last beat falls)
	if not _want_hud and d != null and is_instance_valid(d) and d.done and d.ending == "outsong":
		return
	if StateDirector.transitioning and Game.player == null:
		return
	var cs := _cam_state()
	_cam_low = minf(_cam_low, float(cs["over"]))
	_cam_up = minf(_cam_up, float(cs["up"]))
	var what := ""
	if hud.visible != _want_hud:
		what = "the HUD is %s" % ("up" if hud.visible else "away")
	elif not cs["ok"]:
		what = "the camera: " + String(cs["why"])
	if what != "" and _wrong.size() < 12:
		_wrong.append("%s (after %s)" % [what, str(d.beats[-1]) if d != null and is_instance_valid(d) and not d.beats.is_empty() else "-"])

func _watch(on: bool, want_hud := false) -> void:
	_watching = on
	_want_hud = want_hud
	if on:
		_wrong = []
		_cam_low = INF
		_cam_up = INF
		_hp_low = INF

func _on_beat(n: String) -> void:
	var cs := _cam_state()
	var cur: Area = Game.current_area as Area
	_beats.append({"beat": n, "hud": hud.visible, "cam_ok": cs["ok"], "cam_why": cs["why"], "cam": cs["name"],
		"input": player.input_enabled, "state": player.state, "model": player.vis.model_id,
		"music": AudioDirector._active_music, "thaw": cur.thaw_layer.visible and not cur.rime_layer.visible,
		"souls": _souls().keys(), "t": d._t if d != null and is_instance_valid(d) else -1.0,
		"clip": player.vis.current_clip(), "at": player.global_position})

func _beat(n: String) -> Dictionary:
	for b in _beats:
		if b["beat"] == n:
			return b
	return {}

func _beat_names() -> Array:
	return _beats.map(func(b): return String(b["beat"]))

## Every beat so far: the HUD away, the camera over the ground and upright.
func _check_beats(label: String) -> void:
	var bad_hud: Array = _beats.filter(func(b): return b["hud"]).map(func(b): return b["beat"])
	check(bad_hud.is_empty(), "%s: the HUD is away at every beat (%s)" % [label, "all" if bad_hud.is_empty() else "up at " + str(bad_hud)])
	var bad_cam: Array = _beats.filter(func(b): return not b["cam_ok"]).map(func(b): return "%s: %s" % [b["beat"], b["cam_why"]])
	check(bad_cam.is_empty(), "%s: the camera is over the ground and upright at every beat (%s)" % [label, "all" if bad_cam.is_empty() else str(bad_cam)])

func _check_watch(label: String) -> void:
	check(_wrong.is_empty(), "%s: nothing between the beats either (least %.2f m over the ground, up.y %.2f; %s)" % [label,
		_cam_low, _cam_up, "clean" if _wrong.is_empty() else str(_wrong)])

# ------------------------------------------------------------------ the start
func _begin() -> bool:
	print("== resumed at the Wellhead Steps, before the choice")
	_marks_bound()
	check(Game.current_area_id == "coldwell" and World.last_hearth.get("hearth", "") == "hs_wellhead_steps", "at the Wellhead Steps (%s)" % Game.current_area_id)
	check(World.get_area_state("coldwell") == RH.WState.RIME and World.is_cleared("coldwell") and World.flag("ks_leadvoice_released"),
		"the Coldwell stilled, the Leadvoice released")
	check(World.ended() == "" and EndingDirector.active == null, "nothing has ended")
	check(hud.visible and player.input_enabled, "the HUD up, the Bearer his own")
	var sat := _leadvoices()
	check(sat.size() == 1 and (sat[0] as Leadvoice).released and (sat[0] as Leadvoice).is_seated_pose(), "she is sat at the spring, as she was left (%d)" % sat.size())
	ec = _choice()
	check(ec != null and ec.is_open(), "the spring offers its two things")
	check(_horn().begins_with("The horn a child carries down the water."), "the horn has its coal")
	return ec != null and ec.is_open()

var _bound := false
func _marks_bound() -> void:
	if _bound:
		return
	_bound = true
	Game.area_title.connect(func(t): _titles.append(String(t)))
	Game.title_card.connect(func(t, _hold): _cards.append(String(t)))

## Walk to one of the two places to stand and check what it offers.
func _stand_at(spot: Vector3, prompt: String) -> bool:
	await _walk_path(spot, 3600, false)
	var walked := await _walk_to(spot, 300, 0.45, false)
	await _settle()
	var it := player.nearest_interactable()
	check(walked and it != null and it.prompt == prompt, "the Bearer walks to the spring: %s (%s, at %s)" % [prompt,
		it.prompt if it != null else "nothing", str(player.global_position.snapped(Vector3.ONE * 0.1))])
	return walked and it != null and it.prompt == prompt

## Take it, through the prompt, and take hold of the director it starts.
func _take_ending() -> bool:
	_beats = []
	_watch(true, false)
	_hp0 = player.hp
	var up: Array = _awake_foes()
	print("  (the frost-taken standing as he chooses: %d, %d of them after him, the nearest %.1f m off)" % [up.size(),
		up.filter(func(e): return e.target != null).size(),
		up.map(func(e): return _flat(e.global_position - player.global_position).length()).min() if not up.is_empty() else -1.0])
	var took := player.try_interact()
	d = ec.director
	check(took and d != null and is_instance_valid(d) and EndingDirector.active == d, "E: the ending begins")
	if d == null:
		return false
	d.beat.connect(_on_beat)
	return true

# ------------------------------------------------------------------ the sheet, the title
func _sheet_buttons() -> Array:
	return PauseUI._pages["main"].get_children().filter(func(c): return c is Button)

## Esc, as a player presses it. Returns whether the sheet came up.
func _esc_opens() -> bool:
	_act("ui_cancel")
	await ticks(3)
	return PauseUI.is_open() and get_tree().paused

func _esc_closes() -> bool:
	var b := _sheet_buttons()
	var names: Array = b.map(func(x): return x.text)
	if names.has("Return to the World"):
		b[names.find("Return to the World")].pressed.emit()
	await ticks(3)
	return not PauseUI.is_open() and not get_tree().paused

## Esc -> Return to the Title. Leaves the title up; returns it.
func _to_title() -> Node:
	Game.front_door = true
	var opened := await _esc_opens()
	check(opened, "Esc raises the sheet")
	if not opened:
		PauseUI.open()
		await ticks(3)
	var b := _sheet_buttons()
	var names: Array = b.map(func(x): return x.text)
	check(names.has("Return to the Title"), "it offers the title (%s)" % str(names))
	if names.has("Return to the Title"):
		b[names.find("Return to the Title")].pressed.emit()
	var title: Node = await _wait_child("res://src/ui/title_screen.gd", 90.0)
	check(title != null and Game.player == null, "back at the title, the world put away")
	check(EndingDirector.active == null and _credit_rolls().is_empty(), "and the ending with it: no director, no credits over the title")
	await _secs(1.0)
	return title

## Resume the hearth from the title. Re-binds the Bearer, the area, the HUD.
func _resume(title: Node) -> bool:
	if title == null:
		return false
	check(title.has_save, "Resume the hearth is offered")
	var mb: Array = title._main_box.get_children().filter(func(c): return c is Button)
	mb[0].pressed.emit()
	await ticks(4)
	var sb: Array = title._slots_box.get_children().filter(func(c): return c is Button)
	sb[0].pressed.emit()
	var resumed := await _until(func(): return Game.player != null and is_instance_valid(Game.player), 60.0)
	check(resumed, "the hearth resumes")
	if not resumed:
		return false
	player = Game.player
	area = Game.current_area
	hud = get_tree().get_first_node_in_group("hud")
	player.sim_active = true
	await ticks(30)
	return true

## The same starting save again (the second playing of the ending).
func _again() -> bool:
	_watch(false)
	var title := await _to_title()
	if title == null:
		return false
	var f := FileAccess.open(World.save_path(), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(_fixture_path(start_fixture)))
	f.close()
	if not await _resume(title):
		return false
	d = null
	return await _begin()
