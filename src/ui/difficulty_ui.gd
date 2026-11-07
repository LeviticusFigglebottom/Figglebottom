class_name DifficultyUI
extends CanvasLayer
## The hardness of the winter: chosen once, before a fresh journey.
## Keyboard-driven like the hearth menu; the middle way is the default.

signal chosen(id: String)

## From the title's New Journey, Esc backs out (emits ""): nothing is
## lost until a winter is actually chosen.
var cancellable := false

var _options := [
	{"id": "gentle", "label": "The Gentle Thaw",
	 "desc": "The cold bites softer. Your hand lands harder (deal 1.25x, take 0.75x)."},
	{"id": "long", "label": "The Long Winter",
	 "desc": "The winter as it is."},
	{"id": "hard", "label": "The Hard Frost",
	 "desc": "The cold bites deeper. Your hand lands lighter (deal 0.75x, take 1.25x)."},
]
var _opt_i := 1   # The Long Winter is the default
var _rows: Array = []
var _desc: Label
var _done := false

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
	layer = 85
	var back := ColorRect.new()
	back.color = Color(0.012, 0.010, 0.008, 1.0)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.028, 0.96)
	sb.border_color = Color(0.78, 0.66, 0.40)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.78)
	sb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -250
	panel.offset_bottom = 250
	add_child(panel)
	var crest_path := "res://assets/ui/icons/crest.png"
	if ResourceLoader.exists(crest_path):
		var ci := TextureRect.new()
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ci.texture = load(crest_path)
		ci.position = Vector2(28, 22)
		ci.size = Vector2(44, 44)
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ci)
	var title := Label.new()
	title.label_settings = _ls(30, Color(0.95, 0.82, 0.52), true)
	title.position = Vector2(84, 22)
	title.text = "How Long the Winter"
	panel.add_child(title)
	var sub := Label.new()
	sub.label_settings = _ls(18, Color(0.68, 0.62, 0.52))
	sub.position = Vector2(84, 62)
	sub.text = "How hard a road will this journey be?"
	panel.add_child(sub)
	var trule := ColorRect.new()
	trule.color = Color(0.74, 0.62, 0.38, 0.68)
	trule.position = Vector2(32, 98)
	trule.size = Vector2(656, 1)
	panel.add_child(trule)
	var box := VBoxContainer.new()
	box.position = Vector2(32, 120)
	box.size = Vector2(656, 210)
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	for opt in _options:
		var l := Label.new()
		box.add_child(l)
		_rows.append(l)
	var brule := ColorRect.new()
	brule.color = Color(0.56, 0.46, 0.28, 0.48)
	brule.position = Vector2(32, 344)
	brule.size = Vector2(656, 1)
	panel.add_child(brule)
	_desc = Label.new()
	_desc.label_settings = _ls(19, Color(0.76, 0.70, 0.58))
	_desc.position = Vector2(32, 358)
	_desc.size = Vector2(656, 80)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_desc)
	var hint := Label.new()
	hint.label_settings = _ls(16, Color(0.54, 0.50, 0.42))
	hint.position = Vector2(32, 450)
	hint.text = "W/S to weigh, E or click to choose. This holds for the whole journey."
	panel.add_child(hint)
	_render()

func _render() -> void:
	for i in _rows.size():
		var sel: bool = i == _opt_i
		var l: Label = _rows[i]
		l.label_settings = _ls(25, Color(0.98, 0.88, 0.58) if sel else Color(0.74, 0.69, 0.60), sel)
		l.text = ("◆  " if sel else "    ") + _options[i]["label"] \
				+ ("      (default)" if _options[i]["id"] == "hearth" else "")
	_desc.text = _options[_opt_i]["desc"]

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if cancellable and event.is_action_pressed("ui_cancel"):
		_done = true
		chosen.emit("")
		queue_free()
		return
	if event.is_action_pressed("move_forward"):
		_opt_i = max(0, _opt_i - 1)
		_render()
	elif event.is_action_pressed("move_back"):
		_opt_i = min(_options.size() - 1, _opt_i + 1)
		_render()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack_light") \
			or (event is InputEventMouseButton and event.pressed):
		_done = true
		AudioDirector.sfx("res://assets/audio/rest_chime.wav", -6.0)
		chosen.emit(_options[_opt_i]["id"])
		queue_free()
