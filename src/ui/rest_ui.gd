class_name RestUI
extends CanvasLayer
## The hearth menu: keep hearth (rest / turn the world), grow by warmth
## (level attributes with warmth), rise. Keyboard-driven, sim-drivable.
## Opened with no hearth (Ingra's "Sit by the fire"), it is the levelling
## sheet alone: Back rises.

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

var _start := "main"
var _title := ""

func _init(l: Hearthstone, p, start := "main", title := "") -> void:
	hearth = l
	player = p
	_start = start if l != null else "level"
	_title = title

func _ready() -> void:
	layer = 20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hearth == null and player != null:
		player.lock_control(true)
	var root := Control.new()
	root.theme = UITheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UITheme.COAL, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	panel = Panel.new()
	var sb := UITheme.box("panel")
	sb.border_color = Color(0, 0, 0, 0)
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
		ci.position = Vector2(34, 22)
		ci.size = Vector2(40, 40)
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ci)
	title_label = Label.new()
	title_label.label_settings = UITheme.ls(32, UITheme.EMBER_HOT, "caps")
	title_label.position = Vector2(86, 20)
	title_label.text = hearth.display_name if hearth != null else _title
	panel.add_child(title_label)
	_top_rule = ColorRect.new()
	_top_rule.color = Color(UITheme.EMBER, 0.5)
	_top_rule.position = Vector2(PAD, TOP - 12)
	_top_rule.size = Vector2(710, 1)
	panel.add_child(_top_rule)
	list_box = VBoxContainer.new()
	list_box.position = Vector2(PAD, TOP)
	list_box.size = Vector2(710, 260)
	list_box.add_theme_constant_override("separation", 4)
	panel.add_child(list_box)
	_bot_rule = ColorRect.new()
	_bot_rule.color = Color(UITheme.BONE, 0.12)
	_bot_rule.position = Vector2(PAD, 348)
	_bot_rule.size = Vector2(710, 1)
	panel.add_child(_bot_rule)
	info_label = Label.new()
	info_label.label_settings = UITheme.ls(21, UITheme.BONE_DIM, "italic")
	info_label.position = Vector2(PAD, 360)
	info_label.size = Vector2(710, 50)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info_label)
	panel.add_child(KnotFrame.new())
	if _start == "level":
		_enter_level()
	else:
		_enter_main()

const PAD := 44.0
const TOP := 88.0

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
			("warm it" if cur == RH.WState.RIME else "let it still")})
	elif cur == RH.WState.THAW:
		_options.append({"id": "rest", "label": "Keep hearth  (the memory will still)"})
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
	var half_w: float = (maxf(need.x, 560.0) + PAD * 2.0) * 0.5
	var h: float = TOP + need.y + 128.0
	panel.offset_left = -half_w
	panel.offset_right = half_w
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5
	var inner_w := half_w * 2.0 - PAD * 2.0
	list_box.size = Vector2(inner_w, need.y)
	if _top_rule != null:
		_top_rule.size = Vector2(inner_w, 1)
	if _bot_rule != null:
		_bot_rule.position = Vector2(PAD, TOP + need.y + 14.0)
		_bot_rule.size = Vector2(inner_w, 1)
	info_label.position = Vector2(PAD, TOP + need.y + 26.0)
	info_label.size = Vector2(inner_w, 64)

func _render() -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)   # out now, so the panel measures only the new rows
		c.queue_free()
	for i in _options.size():
		var l := Label.new()
		var sel := i == _opt_i
		l.label_settings = UITheme.ls(25, UITheme.EMBER_HOT if sel else UITheme.BONE_DIM)
		l.text = ("◆   " if sel else "     ") + _options[i]["label"]
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
		if hearth == null:
			close()
		else:
			_enter_main()
	elif id.begins_with("stat:"):
		_buy_stat(id.get_slice(":", 1))

func _buy_stat(stat: String) -> void:
	var cost := _level_cost()
	if Game.warmth < cost:
		info_label.text = "Not enough warmth. %d more is needed." % (cost - Game.warmth)
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
