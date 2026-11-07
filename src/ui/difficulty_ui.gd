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

func _ls(size: int, color: Color, weight := "regular") -> LabelSettings:
	return UITheme.ls(size, color, weight)

func _ready() -> void:
	layer = 85
	var root := Control.new()
	root.theme = UITheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var back := ColorRect.new()
	back.color = UITheme.COAL
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var panel := Panel.new()
	var sb := UITheme.box("panel")
	sb.border_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -260
	panel.offset_bottom = 260
	root.add_child(panel)
	var crest_path := "res://assets/ui/icons/crest.png"
	if ResourceLoader.exists(crest_path):
		var ci := TextureRect.new()
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ci.texture = load(crest_path)
		ci.position = Vector2(42, 34)
		ci.size = Vector2(46, 46)
		ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ci)
	var title := Label.new()
	title.label_settings = _ls(34, UITheme.EMBER_HOT, "caps")
	title.position = Vector2(100, 28)
	title.text = "How Long the Winter"
	panel.add_child(title)
	var sub := Label.new()
	sub.label_settings = _ls(21, UITheme.BONE_DIM, "italic")
	sub.position = Vector2(100, 70)
	sub.text = "How hard a road will this journey be?"
	panel.add_child(sub)
	var trule := ColorRect.new()
	trule.color = Color(UITheme.EMBER, 0.5)
	trule.position = Vector2(44, 112)
	trule.size = Vector2(672, 1)
	panel.add_child(trule)
	var box := VBoxContainer.new()
	box.position = Vector2(44, 134)
	box.size = Vector2(672, 210)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	for opt in _options:
		var l := Label.new()
		box.add_child(l)
		_rows.append(l)
	var brule := ColorRect.new()
	brule.color = Color(UITheme.BONE, 0.12)
	brule.position = Vector2(44, 344)
	brule.size = Vector2(672, 1)
	panel.add_child(brule)
	_desc = Label.new()
	_desc.label_settings = _ls(22, UITheme.BONE)
	_desc.position = Vector2(44, 360)
	_desc.size = Vector2(672, 80)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_desc)
	var hint := Label.new()
	hint.label_settings = _ls(18, UITheme.ASH, "italic")
	hint.position = Vector2(44, 462)
	hint.text = "W/S to weigh, E or click to choose. This holds for the whole journey."
	panel.add_child(hint)
	panel.add_child(KnotFrame.new())
	_render()

func _render() -> void:
	for i in _rows.size():
		var sel: bool = i == _opt_i
		var l: Label = _rows[i]
		l.label_settings = _ls(28, UITheme.EMBER_HOT if sel else UITheme.BONE_DIM)
		l.text = ("◆   " if sel else "     ") + _options[i]["label"] \
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
