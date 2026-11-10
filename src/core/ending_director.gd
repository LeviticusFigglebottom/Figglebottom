class_name EndingDirector
extends Node
## The two endings (SPEC 2, WORLD.md 6, COLDWELL.md 10; ADR 0013). Started
## by the choice at the wellhead (src/world/ending_choice.gd) once its flag
## is set; every beat's time is data (game.json "endings"). Nothing is said.
##
##   outsong      the Bearer puts the mask on and sings (the audio director's
##                Outsong); kneels; lays the coal in the spring; the melt
##                goes out from the spring and does not stop (World.spring():
##                grey light, open water, nobody remembered, hearths that
##                will not warm); control comes back; when the Bearer has
##                walked out past the stones the credits roll over the walk;
##                then the Strand at Saltfell, in spring.
##   hearth_kept  the stopper is pressed home; the remembered Melt comes back
##                over the Coldwell and nowhere else; the Bearer sits down by
##                the spring; the camera goes back and up; the credits roll
##                over it with no music; the frost comes onto the Bearer's
##                shoulders. A kept save opens on this and stays on it.

signal beat(name: String)
signal finished(ending: String)

## The director of the ending now running (or of a kept save), if any.
static var active: EndingDirector = null

var ending := ""
## The spring: the wave's origin and what the camera frames.
var spring := Vector3.ZERO
## What the Bearer faces and the camera looks past him at (the spring,
## unless an ending turns him to something else).
var focus := Vector3.INF
## Where the Bearer stood to choose (the seat, if the coal is kept).
var stand := Vector3.ZERO
## Tests: every wait is one frame, the wave is a snap, the credits are skipped.
var fast := false
var beats: Array = []
var credits: CreditsUI = null
var cam: Camera3D = null
var done := false
var _t := 0.0
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _cam_time := 1.0
var _cam_t := 0.0
var _look := Vector3.ZERO

static func begin(ending_id: String, spring_at: Vector3, stand_at: Vector3, fast_ := false) -> EndingDirector:
	var d := EndingDirector.new()
	d.ending = ending_id
	d.spring = spring_at
	d.stand = stand_at
	d.fast = fast_
	d.name = "EndingDirector"
	Engine.get_main_loop().root.add_child(d)
	return d

func _cfg(key: String, def = null):
	return DB.tuning("endings/%s/%s" % [ending, key], def)

func _ready() -> void:
	active = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ending == "outsong":
		_outsong.call_deferred()
	elif ending == "hearth_kept":
		_hearth_kept.call_deferred()

func _exit_tree() -> void:
	if active == self:
		active = null

func _beat(n: String) -> void:
	beats.append(n)
	beat.emit(n)

## Wait until `at` seconds into the ending.
func _until(at: float) -> void:
	if fast:
		await get_tree().process_frame
		return
	while _t < at:
		await get_tree().process_frame

func _process(dt: float) -> void:
	if get_tree().paused:
		return
	_t += dt
	if cam != null and is_instance_valid(cam):
		_cam_t = minf(_cam_t + dt, _cam_time)
		var k := _cam_t / _cam_time
		k = k * k * (3.0 - 2.0 * k)
		cam.global_position = _cam_from.lerp(_cam_to, k)
		cam.look_at(_look, Vector3.UP)

func _hud(on: bool) -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud is CanvasLayer:
			(hud as CanvasLayer).visible = on

func _area() -> Area:
	return Game.current_area as Area

## A camera of the ending's own. Offsets are [right, up, back] in the frame
## of the Bearer looking at the spring.
func _take_camera(from: Array, to: Array, secs: float, p: Node3D) -> void:
	var f := focus if focus != Vector3.INF else spring
	var fwd := f - p.global_position
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.2 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var at := func(o: Array) -> Vector3:
		return p.global_position + right * float(o[0]) + Vector3.UP * float(o[1]) + fwd * float(o[2])
	_cam_from = at.call(from)
	_cam_to = at.call(to)
	_cam_time = maxf(secs, 0.01)
	_cam_t = 0.0
	_look = p.global_position.lerp(f, 0.45) + Vector3.UP * 1.1
	if cam == null or not is_instance_valid(cam):
		cam = Camera3D.new()
		cam.name = "EndingCam"
		cam.fov = 48.0
		add_child(cam)
	cam.global_position = _cam_from
	cam.look_at(_look, Vector3.UP)
	cam.current = true

func _give_camera_back(p) -> void:
	if cam != null and is_instance_valid(cam):
		cam.queue_free()
	cam = null
	if p != null and p.get("cam") != null and p.cam.get("cam") != null:
		(p.cam.cam as Camera3D).current = true

func _face_spring(p) -> void:
	var to: Vector3 = (focus if focus != Vector3.INF else spring) - (p as Node3D).global_position
	if p.get("vis") != null and Vector2(to.x, to.z).length() > 0.1:
		p.vis.rotation.y = atan2(-to.x, -to.z)

func _hands_empty(p) -> void:
	if p.get("vis") == null:
		return
	for m in [p.vis.weapon_mount, p.vis.shield_mount]:
		if m != null and is_instance_valid(m):
			(m as Node3D).visible = false
	if p.vis.trail != null:
		p.vis.trail.visible = false

func _wave(to_state: RH.WState) -> void:
	var a := _area()
	if a == null:
		return
	if fast:
		StateDirector.snap(a, to_state)
	else:
		await StateDirector.transition(a, to_state, spring, true)

## Whoever sat here as a Holdfast goes with the frost.
func _let_holdfasts_go(secs: float) -> void:
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		if not (e is Enemy):
			continue
		var en := e as Enemy
		FrostDissolve.apply(en.vis)
		var tw := en.create_tween()
		tw.tween_method(func(v: float): RH.set_dissolve(en.vis, v), 0.0, 1.0, maxf(secs, 0.05))
		tw.tween_callback(en.queue_free)

func _roll_credits() -> void:
	credits = CreditsUI.new()
	credits.over_world = true
	get_tree().root.add_child(credits)
	_beat("credits")
	if fast:
		await get_tree().process_frame
		credits.skip()
	else:
		await credits.finished
	credits = null

# ---------------------------------------------------------------- the Outsong
func _outsong() -> void:
	var p = Game.player
	if p == null:
		return
	Game.arena_locked = false
	p.lock_control(true)
	_hud(false)
	_face_spring(p)
	_take_camera(_cfg("cam_from", [1.1, 2.0, -4.5]), _cfg("cam_to", [0.9, 1.6, -2.6]), float(_cfg("kneel_at", 16.0)), p)
	_beat("begin")
	await _until(float(_cfg("mask_at", 1.2)))
	# the mask goes on; the hands are empty
	p.set_model(String(DB.tuning("player/model_outsong", "")))
	_face_spring(p)
	_hands_empty(p)
	_beat("mask")
	await _until(float(_cfg("sing_at", 3.0)))
	AudioDirector.play_outsong("", 6.0)
	_beat("sing")
	await _until(float(_cfg("kneel_at", 16.0)))
	p.enter_rest()
	_hands_empty(p)
	_beat("kneel")
	await _until(float(_cfg("coal_at", 18.5)))
	_lay_coal()
	_beat("coal")
	await _until(float(_cfg("wave_at", 20.0)))
	# nobody is remembered here any more
	var a := _area()
	if a != null:
		for n in a.find_children("*", "NPC", true, false):
			(n as Node).queue_free()
	_let_holdfasts_go(4.0 if not fast else 0.05)
	await _wave(RH.WState.THAW)
	_beat("spring")
	await _until(float(_cfg("release_at", 28.5)))
	p.exit_rest()
	_hands_empty(p)
	_give_camera_back(p)
	p.lock_control(false)
	Game.snapshot_player()
	World.save_game()
	_beat("walk")
	# the walk out: past the stones, or long enough
	var t0 := _t
	while not fast and is_instance_valid(p) \
			and (p as Node3D).global_position.distance_to(spring) < float(_cfg("walk_out_r", 16.0)) \
			and _t - t0 < float(_cfg("walk_out_max", 75.0)):
		await get_tree().process_frame
	await _roll_credits()
	_last_shore()
	done = true
	_beat("end")
	finished.emit(ending)

## The coal out of the horn and into the water: a small warm light that
## goes down and out.
func _lay_coal() -> void:
	AudioDirector.sfx(AudioDirector.foley("coal_catch"), -5.0, 0.8)
	var a := _area()
	if a == null:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.28)
	l.light_energy = 4.2
	l.omni_range = 7.0
	l.shadow_enabled = false
	a.add_child(l)
	l.global_position = spring + Vector3.UP * 0.7
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", spring.y - 0.4, 4.0)
	tw.parallel().tween_property(l, "light_energy", 0.0, 5.5)
	tw.tween_callback(l.queue_free)

## After the credits: home (data "last_area"), in spring, with the HUD back.
func _last_shore() -> void:
	var to := String(_cfg("last_area", ""))
	var def := DB.area_def(to) if to != "" else {}
	if not fast and not def.is_empty() and Game.world_root != null and Game.player != null:
		var st: Dictionary = def.get("start", {})
		Game.travel_to(to, AreaBuilder._v3(st.get("pos", [0, 0.2, 0])), float(st.get("yaw", 0)))
	_hud(true)

# ---------------------------------------------------------------- the Hearth Kept
func _hearth_kept() -> void:
	var p = Game.player
	if p == null:
		return
	Game.arena_locked = false
	p.lock_control(true)
	_hud(false)
	_face_spring(p)
	_take_camera(_cfg("cam_begin", [-2.4, 1.6, -4.0]), _cfg("cam_begin", [-2.4, 1.6, -4.0]), 1.0, p)
	_beat("begin")
	await _until(float(_cfg("shut_at", 1.0)))
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -4.0, 0.55)   # the stopper, pressed home
	AudioDirector.play_music("", 3.0)
	_beat("shut")
	await _until(float(_cfg("wave_at", 2.6)))
	await _wave(RH.WState.THAW)
	AudioDirector.play_music("", 0.5)   # only the river
	_beat("melt")
	await _until(float(_cfg("sit_at", 10.0)))
	_turn_to_the_water(p)
	_sit(p)
	_take_camera(_cfg("cam_from", [1.6, 1.5, -2.6]), _cfg("cam_to", [3.5, 3.6, -5.5]), float(_cfg("cam_time", 40.0)), p)
	Game.snapshot_player()
	World.save_game()
	_beat("sit")
	await _until(float(_cfg("credits_at", 15.0)))
	await _roll_credits()
	done = true
	_beat("end")
	finished.emit(ending)
	# (it stays: the Bearer sat, the camera where it stopped)

## The woman and the child at the water's edge are what he sits down to
## watch (data "watch": the remembered one's npc id).
func _turn_to_the_water(_p) -> void:
	var a := _area()
	if a == null:
		return
	var who := String(_cfg("watch", "maren"))
	for n in a.find_children("*", "NPC", true, false):
		if (n as NPC).npc_id == who:
			focus = (n as NPC).global_position

## Sat down by the spring, facing the water, and the frost coming on.
func _sit(p) -> void:
	p.lock_control(true)
	if p.has_method("enter_rest"):
		p.enter_rest()
	_face_spring(p)
	_hands_empty(p)
	if p.get("vis") != null:
		p.vis.play(String(_cfg("sit_clip", "sit_still")), 0.8)
		_frost_over(p.vis, 0.0 if fast else float(_cfg("cam_time", 40.0)))

## The newest Holdfast: rime over the shoulders, slowly.
func _frost_over(vis: Node, secs: float) -> void:
	var rime := StandardMaterial3D.new()
	rime.albedo_color = Color(0.82, 0.9, 1.0, 0.0)
	rime.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rime.roughness = 0.55
	for mi in vis.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).material_overlay = rime
	vis.set_meta("frost_over", rime)
	if secs <= 0.0:
		rime.albedo_color.a = 0.55
	else:
		create_tween().tween_property(rime, "albedo_color:a", 0.55, secs)

## A kept save, loaded: the Bearer is sat at the spring, and stays there.
static func resume_kept(p, area: Node) -> EndingDirector:
	var d := EndingDirector.new()
	d.ending = ""          # (no flow: the state only)
	d.name = "EndingDirector"
	Engine.get_main_loop().root.add_child(d)
	d.ending = "hearth_kept"
	d.done = true
	var at := Vector3.INF
	var sp := Vector3.INF
	for c in Engine.get_main_loop().get_nodes_in_group("ending_choice"):
		if area == null or area.is_ancestor_of(c):
			at = c.kept_spot()
			sp = c.spring_point()
	if at == Vector3.INF:
		return d
	d.spring = sp
	d.stand = at
	(p as Node3D).global_position = at
	d._hud.call_deferred(false)
	d._turn_to_the_water(p)
	d._sit(p)
	var to: Array = d._cfg("cam_to", [3.5, 3.6, -5.5])
	d._take_camera(to, to, 0.01, p)
	var rime = p.vis.get_meta("frost_over", null) if p.get("vis") != null else null
	if rime is StandardMaterial3D:
		(rime as StandardMaterial3D).albedo_color.a = 0.55
	d._beat("kept")
	return d
