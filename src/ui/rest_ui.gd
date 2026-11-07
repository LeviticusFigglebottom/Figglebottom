class_name RestUI
extends CanvasLayer
## The hearth menu: keep hearth (rest / turn the world), grow by warmth
## (level attributes with warmth), rise. Keyboard-driven, sim-drivable.

var hearth: Hearthstone
var player

var _phase := "main"    # main | level

## What each point actually buys — shown beside the stat at the hearth.
const STAT_HINTS := {
	"heart": "+12 max health",
	"wind": "+6 max stamina, faster stamina recovery",
	"might": "more sword & greatsword damage",
	"craft": "more bow & spear damage",
	"lungs": "+7 max breath, faster breath recovery (songs)",
	"kinship": "stronger songs — damage and healing",
}
var _opt_i := 0
var _options: Array = []
var panel: Panel
var title_label: Label
var list_box: VBoxContainer
var info_label: Label
var _top_rule: ColorRect
var _bot_rule: ColorRect

func _init(l: Hearthstone, p) -> void:
	hearth = l
	player = p

func _ls(size: int, color: Color, bold := false) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = load("res://assets/fonts/DejaVuSerif-Bold.ttf" if bold else "res://assets/fonts/DejaVuSerif.ttf")
	ls.font_size = size
	ls.font_color = color
	ls.shadow_color = Color(0, 0, 0, 0.85)
	ls.shadow_size = 3
	ls.shadow_offset = Vector2(1, 2)
	return ls

func _ready() -> void:
	layer = 20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.010, 0.006, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.028, 0.96)
	sb.border_color = Color(0.78, 0.66, 0.40)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.78)
	sb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -385
	panel.offset_right = 385
	panel.offset_top = -210
	panel.offset_bottom = 210
	root.add_child(panel)
	var crest_path := "res://assets/ui/icons/crest.png"
	if ResourceLoader.exists(crest_path):
		var ci := TextureRect.new()
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ci.texture = load(crest_path)
		ci.position = Vector2(24, 14)
		ci.size = Vector2(38, 38)
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ci)
	title_label = Label.new()
	title_label.label_settings = _ls(28, Color(0.95, 0.82, 0.52), true)
	title_label.position = Vector2(72, 16)
	title_label.text = hearth.display_name
	panel.add_child(title_label)
	_top_rule = ColorRect.new()
	_top_rule.color = Color(0.74, 0.62, 0.38, 0.68)
	_top_rule.position = Vector2(28, 60)
	_top_rule.size = Vector2(710, 1)
	panel.add_child(_top_rule)
	list_box = VBoxContainer.new()
	list_box.position = Vector2(28, 74)
	list_box.size = Vector2(710, 260)
	list_box.add_theme_constant_override("separation", 6)
	panel.add_child(list_box)
	_bot_rule = ColorRect.new()
	_bot_rule.color = Color(0.56, 0.46, 0.28, 0.48)
	_bot_rule.position = Vector2(28, 348)
	_bot_rule.size = Vector2(710, 1)
	panel.add_child(_bot_rule)
	info_label = Label.new()
	info_label.label_settings = _ls(19, Color(0.70, 0.64, 0.52))
	info_label.position = Vector2(28, 360)
	info_label.size = Vector2(710, 50)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info_label)
	_enter_main()

func _aid() -> String:
	return hearth.area.area_id if hearth.area != null else Game.current_area_id

func _stub_hearth() -> bool:
	var def: Dictionary = hearth.area.get_meta("def", {}) if hearth.area != null else {}
	return def.get("no_still", false)

func _enter_main() -> void:
	_phase = "main"
	_options = []
	var aid := _aid()
	var cur := World.get_area_state(aid)
	if _stub_hearth():
		var def2: Dictionary = hearth.area.get_meta("def", {}) if hearth.area != null else {}
		_options.append({"id": "rest", "label": String(def2.get("stub_label",
			"Keep hearth  (rest — the memory here is thin)"))})
	elif Game.toggle_free(aid):
		_options.append({"id": "rest", "label": "Keep hearth  (rest)"})
		_options.append({"id": "toggle", "label": "Turn the memory — " +
			("warm the thaw" if cur == RH.WState.RIME else "let it still")})
	elif cur == RH.WState.THAW:
		_options.append({"id": "rest", "label": "Keep hearth  — the seeing will end"})
	else:
		_options.append({"id": "rest", "label": "Keep hearth  (rest)"})
	_options.append({"id": "level", "label": "Grow by warmth  (%d warmth held)" % Game.warmth})
	_options.append({"id": "leave", "label": "Rise"})
	info_label.text = "The hearth holds the steading's memory." if not Game.toggle_free(aid) \
		else "The holdfast rests. Keep the memory, or let it go, as you please."
	_opt_i = 0
	_render()

func _level_cost() -> int:
	var base := int(DB.tuning("levels/base_cost", 60))
	var growth := float(DB.tuning("levels/cost_growth", 1.22))
	return int(round(base * pow(growth, player.level - 1)))

func _enter_level() -> void:
	_phase = "level"
	_options = []
	var cost := _level_cost()
	for stat in DB.tuning("levels/stats", []):
		_options.append({"id": "stat:" + stat, "label": "%s  %d  →  %d   ·  %s      (%d warmth)" %
			[stat.capitalize(), player.attributes[stat], player.attributes[stat] + 1,
			STAT_HINTS.get(stat, ""), cost]})
	_options.append({"id": "back", "label": "Back"})
	info_label.text = "Level %d.  Each step costs %d warmth.  You hold %d." % [player.level, cost, Game.warmth]
	_opt_i = 0
	_render()

## The panel wears its contents: measured from the rows, never clipping a
## long line and never swimming around a short menu.
func _fit_panel() -> void:
	var need := list_box.get_combined_minimum_size()
	var half_w: float = (maxf(need.x, 540.0) + 88.0) * 0.5
	var h: float = 74.0 + need.y + 118.0
	panel.offset_left = -half_w
	panel.offset_right = half_w
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5
	var inner_w := half_w * 2.0 - 56.0
	list_box.size = Vector2(inner_w, need.y)
	if _top_rule != null:
		_top_rule.size = Vector2(inner_w, 1)
	if _bot_rule != null:
		_bot_rule.position = Vector2(28, 74.0 + need.y + 12.0)
		_bot_rule.size = Vector2(inner_w, 1)
	info_label.position = Vector2(28, 74.0 + need.y + 22.0)
	info_label.size = Vector2(inner_w, 64)

func _render() -> void:
	for c in list_box.get_children():
		c.queue_free()
	for i in _options.size():
		var l := Label.new()
		var sel := i == _opt_i
		l.label_settings = _ls(23, Color(0.98, 0.88, 0.58) if sel else Color(0.74, 0.69, 0.60), sel)
		l.text = ("◆  " if sel else "    ") + _options[i]["label"]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		l.mouse_entered.connect(func():
			if _opt_i != idx:
				_opt_i = idx
				_render())
		l.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				choose(idx)
				get_viewport().set_input_as_handled())
		list_box.add_child(l)
	_fit_panel()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_forward"):
		_opt_i = max(0, _opt_i - 1)
		_render()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_back"):
		_opt_i = min(_options.size() - 1, _opt_i + 1)
		_render()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack_light"):
		choose(_opt_i)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu") or event.is_action_pressed("dodge"):
		close()
		get_viewport().set_input_as_handled()

func choose(idx: int) -> void:
	_opt_i = clampi(idx, 0, _options.size() - 1)
	var id: String = _options[_opt_i]["id"]
	if id == "leave":
		close()
	elif id == "rest":
		_do_hearth("rest_only" if (Game.toggle_free(_aid()) or _stub_hearth()) else "auto")
	elif id == "toggle":
		_do_hearth("toggle")
	elif id == "level":
		_enter_level()
	elif id == "back":
		_enter_main()
	elif id.begins_with("stat:"):
		_buy_stat(id.get_slice(":", 1))

func _buy_stat(stat: String) -> void:
	var cost := _level_cost()
	if Game.warmth < cost:
		info_label.text = "Not enough warmth. The dead are patient; gather more."
		return
	Game.add_warmth(-cost)
	player.attributes[stat] += 1
	player.level += 1
	player.recompute_derived()
	player.hp = player.max_hp
	player.stamina = player.max_stamina
	player._emit_all()
	AudioDirector.sfx("res://assets/audio/levelup.wav", -3.0)
	Game.toast.emit("Grown by warmth — %s is now %d." % [stat.capitalize(), player.attributes[stat]])
	Game.snapshot_player()
	World.save_game()
	_enter_level()

func _do_hearth(choice: String) -> void:
	var l := hearth
	var p = player
	close()
	Game.hearth_flow(l, p, choice)

func close() -> void:
	if player != null:
		player.lock_control(false)
		player.suppress_interact()   # don't let the closing key-press re-open us
		if not player.sim_active:
			player._grab_mouse(true)
	queue_free()
