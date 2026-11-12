class_name IntroDirector
extends Node
## The opening (docs/lore/INTRO.md): played once, before the Strand, on a new
## journey. A camera of its own goes through Saltfell as it stands (the
## Longhouse in THAW, the same room as the frost wave crosses it, a cold
## hearthstone taking the coal) while short cards say what SPEC 2 says: the
## hearths and the Outsong, the sickness and the frost, the Holdfasts, the
## Bearer and the coal, the spring up the water and the two ways it can end.
##
## Every beat is data (game.json "intro": text, seconds, camera, what turns).
## Nothing it does is kept: the waves it runs are not saved, the hearth it
## shows is not lit, and when it ends (or is skipped, at any card) Saltfell
## is in THAW with the Bearer on the Strand, as a journey began before it.
## It raises World flag "intro_seen", which the save carries.

signal beat(id: String)
signal finished

const FLAG := "intro_seen"
## Held to skip. Any press shows the prompt, quietly.
const SKIP_ACTIONS := ["interact", "ui_accept", "ui_cancel"]

## The intro now running, if any.
static var active: IntroDirector = null

var player: Player
var area: Area
## Tests: each beat waits for next() instead of the clock, and waves snap.
var manual := false
var beats: Array = []          # ids, as they began
var card_text := ""            # the card now up ("" between cards)
var skipped := false
var done := false
var cam: Camera3D = null

var _cfg: Dictionary = {}
var _layer: CanvasLayer
var _card: Control
var _label: Label
var _prompt: Label
var _shade: ColorRect
var _t := 0.0                  # seconds into the current beat
var _beat_secs := 1.0
var _go_next := false
var _hold := 0.0
var _prompt_t := 0.0
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _look_from := Vector3.ZERO
var _look_to := Vector3.ZERO
var _spawn := Vector3.ZERO
var _spawn_yaw := 0.0
var _stilled: Array = []       # frost-taken held still while the frost is shown
var _rime_shown := false
var _ending := false

## Whether a journey that has just begun should open on the intro.
static func wanted(fresh: bool) -> bool:
	return fresh and not World.flag(FLAG) and not (DB.tuning("intro/beats", []) as Array).is_empty()

static func begin(p: Player, a: Area, manual_ := false) -> IntroDirector:
	var d := IntroDirector.new()
	d.player = p
	d.area = a
	d.manual = manual_
	d.name = "IntroDirector"
	Engine.get_main_loop().root.add_child(d)
	return d

func _ready() -> void:
	active = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = DB.tuning("intro", {})
	World.set_flag(FLAG)
	_spawn = player.global_position
	_spawn_yaw = player.cam.yaw
	player.lock_control(true)
	player.invulnerable = true
	_build_ui()
	_run.call_deferred()

func _exit_tree() -> void:
	if active == self:
		active = null

# ---------------------------------------------------------------------- UI
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 92
	add_child(_layer)
	var root := Control.new()
	root.theme = UITheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	# the ground the words stand on: coal rising from the foot of the frame
	var band := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(UITheme.COAL, 0.0), Color(UITheme.COAL, 0.62), Color(UITheme.COAL, 0.86)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	band.texture = gt
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.anchor_top = 0.60
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.modulate.a = 0.0
	root.add_child(_card)
	_card.add_child(band)
	_label = Label.new()
	_label.label_settings = UITheme.ls(int(_cfg.get("card_size", 30)), UITheme.BONE, "regular")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0.16
	_label.anchor_right = 0.84
	_label.anchor_top = 0.62
	_label.anchor_bottom = 0.90
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_label)
	_prompt = Label.new()
	_prompt.text = String(_cfg.get("skip_prompt", "Hold E to skip"))
	_prompt.label_settings = UITheme.ls(18, UITheme.ASH, "italic")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.anchor_left = 0.6
	_prompt.anchor_right = 0.975
	_prompt.anchor_top = 0.935
	_prompt.anchor_bottom = 0.985
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.modulate.a = 0.0
	root.add_child(_prompt)
	# coal over everything: the way in, the cut between places, the way out
	_shade = ColorRect.new()
	_shade.color = UITheme.COAL
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_shade)

func card_alpha() -> float:
	return _card.modulate.a

func prompt_alpha() -> float:
	return _prompt.modulate.a

# ------------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if _ending or done:
		return
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventAction and event.pressed)
	if press:
		_prompt_t = float(_cfg.get("prompt_secs", 3.5))

func _skip_held() -> bool:
	for a in SKIP_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false

## Let the intro go now (the hold, or a test).
func skip() -> void:
	if _ending or done:
		return
	skipped = true
	_end()

## Manual mode: let the beat now up end.
func next() -> void:
	_go_next = true

# -------------------------------------------------------------------- run
func _process(dt: float) -> void:
	if done:
		return
	# from the first card to the last the HUD is away
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud is CanvasLayer and (hud as CanvasLayer).visible:
			(hud as CanvasLayer).visible = false
	_hold_frost_taken()
	if _ending:
		return
	_t += dt
	# the skip: held, with the prompt shown while it is
	if _skip_held():
		_hold += dt
		_prompt_t = maxf(_prompt_t, 0.6)
		if _hold >= float(_cfg.get("skip_hold", 0.9)):
			skip()
			return
	else:
		_hold = 0.0
	_prompt_t = maxf(_prompt_t - dt, 0.0)
	_prompt.modulate.a = move_toward(_prompt.modulate.a, 0.85 if _prompt_t > 0.0 else 0.0, dt * 2.5)
	if cam != null and is_instance_valid(cam):
		var k := clampf(_t / maxf(_beat_secs, 0.01), 0.0, 1.0) if not manual else 0.5
		k = k * k * (3.0 - 2.0 * k)
		cam.global_position = _cam_from.lerp(_cam_to, k)
		cam.look_at(_look_from.lerp(_look_to, k), Vector3.UP)

func _v(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

func _run() -> void:
	cam = Camera3D.new()
	cam.name = "IntroCam"
	cam.fov = float(_cfg.get("fov", 50.0))
	add_child(cam)
	var list: Array = _cfg.get("beats", [])
	var fade := float(_cfg.get("card_fade", 1.1))
	var place := ""
	for i in list.size():
		var b: Dictionary = list[i]
		if _ending:
			return
		# a new place is cut to through coal
		var here := String(b.get("place", place))
		if here != place and i > 0 and not manual:
			await _shade_to(1.0, float(_cfg.get("cut_fade", 0.7)))
			if _ending:
				return
		_frame(b)
		_bearer(b)
		_t = 0.0
		_go_next = false
		_beat_secs = float(b.get("secs", 8.0))
		beats.append(String(b.get("id", str(i))))
		beat.emit(String(b.get("id", str(i))))
		if (here != place or i == 0) and not manual:
			_shade_to(0.0, float(_cfg.get("cut_fade", 0.7)) if i > 0 else float(_cfg.get("open_fade", 1.6)))
		elif manual:
			_shade.color.a = 0.0
		place = here
		_turn(b)
		# the card comes up a moment into the beat, and goes before its end
		card_text = String(b.get("text", ""))
		_label.text = card_text
		var tw := create_tween()
		tw.tween_interval(0.0 if manual else float(b.get("card_at", 0.9)))
		tw.tween_property(_card, "modulate:a", 1.0, 0.01 if manual else fade)
		while not _ending and ((manual and not _go_next) or (not manual and _t < _beat_secs - fade)):
			await get_tree().process_frame
		if _ending:
			return
		if tw.is_valid():
			tw.kill()
		if not manual:
			var out := create_tween()
			out.tween_property(_card, "modulate:a", 0.0, fade)
			await out.finished
		else:
			_card.modulate.a = 0.0
		card_text = ""
	if not _ending:
		_end()

func _shade_to(a: float, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(_shade, "color:a", a, maxf(secs, 0.01))
	await tw.finished

## The beat's camera. Absolute ("from", "to", "look", optional "look_to"),
## or about a hearth ("hearth": id; then the three are [right, up, back]
## from the Bearer's place at it, as he faces the stone).
func _frame(b: Dictionary) -> void:
	var c: Dictionary = b.get("cam", {})
	if c.is_empty():
		return
	var from := _v(c.get("from", [0, 2, 0]))
	var to := _v(c.get("to", c.get("from", [0, 2, 0])))
	var look := _v(c.get("look", [0, 1, -1]))
	var look_to := _v(c.get("look_to", c.get("look", [0, 1, -1])))
	var h := Game.find_hearth(String(b.get("hearth", "")))
	if h != null:
		var at := h.respawn_point()
		var fwd := h.global_position - at
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
		var right := fwd.cross(Vector3.UP)
		var rel := func(o: Vector3) -> Vector3:
			return at + right * o.x + Vector3.UP * o.y + fwd * o.z
		from = rel.call(from)
		to = rel.call(to)
		look = rel.call(look)
		look_to = rel.call(look_to)
	_cam_from = from
	_cam_to = to
	_look_from = look
	_look_to = look_to
	cam.global_position = from
	cam.look_at(look, Vector3.UP)
	cam.current = true

## Where the Bearer is for this beat: kneeling at the beat's hearth, or
## ("bearer": "start") standing on the Strand. Otherwise where he was.
func _bearer(b: Dictionary) -> void:
	if String(b.get("bearer", "")) == "start":
		# on the Strand, where the journey begins, looking where the camera looks
		if player.state == Player.S.REST:
			player.exit_rest()
		player.global_position = _spawn
		player.velocity = Vector3.ZERO
		var c: Dictionary = b.get("cam", {})
		if player.vis != null and c.has("look"):
			var lk := _v(c["look"]) - _spawn
			player.vis.rotation.y = atan2(-lk.x, -lk.z)
		return
	var h := Game.find_hearth(String(b.get("hearth", "")))
	if h == null:
		return
	player.global_position = h.respawn_point()
	player.velocity = Vector3.ZERO
	var to := h.global_position - player.global_position
	if player.vis != null and Vector2(to.x, to.z).length() > 0.05:
		player.vis.rotation.y = atan2(-to.x, -to.z)
	if player.state != Player.S.REST:
		player.enter_rest()

## What the beat turns: "wave": "rime" | "thaw" from "origin" (or from the
## beat's hearth); "coal": true sets the coal on the hearthstone first.
func _turn(b: Dictionary) -> void:
	var h := Game.find_hearth(String(b.get("hearth", "")))
	if bool(b.get("coal", false)) and h != null:
		_set_coal(h)
	var w := String(b.get("wave", ""))
	if w == "":
		return
	var to_state := RH.WState.RIME if w == "rime" else RH.WState.THAW
	var origin := _v(b["origin"]) if b.has("origin") else (h.global_position if h != null else player.global_position)
	if to_state == RH.WState.RIME:
		_rime_shown = true
	if manual:
		_apply(to_state)
	else:
		_wave_after(float(b.get("wave_at", 1.5)), to_state, origin)

func _wave_after(secs: float, to_state: RH.WState, origin: Vector3) -> void:
	await get_tree().create_timer(secs).timeout
	if _ending or done or not is_instance_valid(area):
		return
	# shown, never kept: no state is written and nothing is saved
	StateDirector.transition(area, to_state, origin, true, false, false)

## A state put on without the wave or the save (manual mode, and the end).
func _apply(to_state: RH.WState) -> void:
	StateDirector.cancel()
	StateDirector._set_g("rh_state_blend", 1.0 if to_state == RH.WState.RIME else 0.0)
	StateDirector._set_g("rh_wave_r", -1000.0)
	area.apply_state(to_state)

## The coal out of the horn and onto the stone: a small warm light that
## takes, as it does at every rest.
func _set_coal(h: Hearthstone) -> void:
	AudioDirector.sfx(AudioDirector.foley("coal_catch"), -3.0)
	var l := OmniLight3D.new()
	l.name = "IntroCoal"
	l.light_color = Color(1.0, 0.62, 0.28)
	l.light_energy = 0.0
	l.omni_range = 6.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = h.global_position + Vector3.UP * 0.55
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 3.6, 1.2)
	tw.tween_interval(5.0)
	tw.tween_property(l, "light_energy", 0.0, 3.0)
	tw.tween_callback(l.queue_free)

## Nothing frost-taken lifts a hand while the frost is only being shown.
func _hold_frost_taken() -> void:
	if not _rime_shown:
		return
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		var en := e as Enemy
		if en == null or not is_instance_valid(en) or not en.is_physics_processing():
			continue
		en.target = null
		en.velocity = Vector3.ZERO
		en.set_physics_process(false)
		_stilled.append(en)

# -------------------------------------------------------------------- end
## Hand the world back exactly as a journey began before there was an
## intro: Saltfell in THAW, the Bearer standing on the Strand, the HUD up.
func _end() -> void:
	if _ending:
		return
	_ending = true
	_prompt.modulate.a = 0.0
	var out := float(_cfg.get("end_fade", 0.9)) if not manual else 0.01
	var tw := create_tween()
	tw.tween_property(_shade, "color:a", 1.0, out)
	tw.parallel().tween_property(_card, "modulate:a", 0.0, out * 0.6)
	await tw.finished
	card_text = ""
	StateDirector.cancel()
	if is_instance_valid(area):
		StateDirector.snap(area, RH.WState.THAW)
	for en in _stilled:
		if is_instance_valid(en):
			(en as Enemy).set_physics_process(true)
	_stilled.clear()
	_rime_shown = false
	if is_instance_valid(player):
		if player.state == Player.S.REST:
			player.exit_rest()
		player.global_position = _spawn
		player.velocity = Vector3.ZERO
		player.cam.yaw = _spawn_yaw
		if player.vis != null:
			player.vis.rotation.y = _spawn_yaw
		if player.cam.get("cam") != null:
			(player.cam.cam as Camera3D).current = true
		player.invulnerable = false
		player.lock_control(false)
	if cam != null and is_instance_valid(cam):
		cam.queue_free()
	cam = null
	done = true
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud is CanvasLayer:
			(hud as CanvasLayer).visible = true
	finished.emit()
	# the Strand comes up out of the coal
	var up := create_tween()
	up.tween_property(_shade, "color:a", 0.0, float(_cfg.get("open_fade", 1.6)) if not manual else 0.01)
	await up.finished
	queue_free()
