class_name CreditsUI
extends CanvasLayer
## The credits (COLDWELL.md 10): one column in the house type, rolling up
## once, slowly. Over the world (the ending goes on behind it) or on coal.
## The lines are data: game.json "credits" ([kind, text]; kinds title, sub,
## role, name, gap, knot); the pace is game.json endings/credits.

signal finished

## Over the world: no ground, only a soft dark band behind the column, and
## the column kept to the right so what is happening stays in view.
var over_world := true
const COL_X := 0.6
const COL_W := 0.36
var lines: Array = []
var _col: VBoxContainer
var _root: Control
var _t := 0.0
var _h := 0.0
var _done := false
var _leaving := false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	if lines.is_empty():
		lines = DB.tuning("credits", [])
	_root = Control.new()
	_root.theme = UITheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)
	if over_world:
		# the column's ground: coal at the middle of the screen, nothing at the sides
		var band := TextureRect.new()
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(UITheme.COAL, 0.0), Color(UITheme.COAL, 0.5), Color(UITheme.COAL, 0.72)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 256
		gt.height = 4
		band.texture = gt
		band.stretch_mode = TextureRect.STRETCH_SCALE
		band.anchor_left = COL_X - 0.08
		band.anchor_right = 1.0
		band.anchor_bottom = 1.0
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(band)
	else:
		var bg := ColorRect.new()
		bg.color = UITheme.COAL
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.add_child(bg)
	_col = VBoxContainer.new()
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.add_theme_constant_override("separation", 6)
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_col)
	for e in lines:
		_col.add_child(_line(String(e[0]), String(e[1])))
	create_tween().tween_property(_root, "modulate:a", 1.0, float(DB.tuning("endings/credits/fade", 2.5)))

func _line(kind: String, text: String) -> Control:
	if kind == "gap":
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 46)
		return sp
	if kind == "knot":
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(0, 90)
		var knot := KnotFrame.new(true, 18.0)
		knot.color = Color(UITheme.EMBER, 0.85)
		knot.custom_minimum_size = knot.size
		holder.add_child(knot)
		return holder
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match kind:
		"title":
			l.label_settings = UITheme.ls(64, UITheme.BONE, "caps")
			l.label_settings.font = UITheme.font("caps", 8)
		"sub":
			l.label_settings = UITheme.ls(24, UITheme.BONE_DIM, "italic")
		"role":
			l.label_settings = UITheme.ls(19, UITheme.ASH, "caps")
			l.label_settings.font = UITheme.font("caps", 3)
		_:
			l.label_settings = UITheme.ls(27, UITheme.BONE)
	return l

## Seconds the whole roll takes.
func duration() -> float:
	var vp := get_viewport().get_visible_rect().size
	return (vp.y + _col.get_combined_minimum_size().y) / float(DB.tuning("endings/credits/speed", 34.0)) \
			+ float(DB.tuning("endings/credits/hold", 4.0))

func _process(dt: float) -> void:
	if _done:
		return
	var vp := get_viewport().get_visible_rect().size
	_h = _col.get_combined_minimum_size().y
	var x0 := COL_X if over_world else 0.25
	var w := COL_W if over_world else 0.5
	_col.size = Vector2(vp.x * w, _h)
	_t += dt
	var y := vp.y - _t * float(DB.tuning("endings/credits/speed", 34.0))
	_col.position = Vector2(vp.x * x0, y)
	if not _leaving and y + _h < -float(DB.tuning("endings/credits/hold", 4.0)) * 4.0:
		leave()

## Freeze the roll `secs` in (the screenshot harness).
func show_at(secs: float) -> void:
	_t = secs
	_root.modulate.a = 1.0

func leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, float(DB.tuning("endings/credits/fade", 2.5)))
	tw.tween_callback(func():
		_done = true
		finished.emit()
		queue_free())

## Straight to the end (tests; nobody is made to sit through them twice).
func skip() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
