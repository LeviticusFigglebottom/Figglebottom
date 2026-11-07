class_name HouseCard
extends CanvasLayer
## The house card on boot, before the title: FIGGLEBOTTOM PRODUCTIONS on
## coal, a slow fade, and one ember drifting up through it. Quiet and
## sincere (owner decision, docs/handoffs/live/CONSOLIDATED.md). Any key,
## click or button lets it go early.

signal finished

const NAME := "Figglebottom Productions"
const T_DARK := 0.7
const T_IN := 1.8
const T_HOLD := 2.6
const T_OUT := 1.5

## The screenshot harness holds the card once it has faded in.
var hold_forever := false

var _root: Control
var _words: Control
var _ember: TextureRect
var _t := 0.0
var _leaving := false
var _done := false
var _ember_from := Vector2.ZERO

func _ready() -> void:
	layer = 95
	_root = Control.new()
	_root.theme = UITheme.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = UITheme.COAL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	_words = Control.new()
	_words.set_anchors_preset(Control.PRESET_FULL_RECT)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_words.modulate.a = 0.0
	_root.add_child(_words)
	var l := Label.new()
	l.text = NAME
	l.label_settings = UITheme.ls(58, UITheme.BONE, "caps", false)
	l.label_settings.font = UITheme.font("caps", 7)   # small capitals want air
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 0.42
	l.anchor_bottom = 0.52
	_words.add_child(l)
	var knot := KnotFrame.new(true, 16.0)
	knot.color = Color(UITheme.EMBER, 0.85)
	knot.anchor_left = 0.5
	knot.anchor_right = 0.5
	knot.anchor_top = 0.575
	knot.anchor_bottom = 0.575
	knot.offset_left = -knot.size.x * 0.5
	knot.offset_right = knot.size.x * 0.5
	knot.offset_top = -knot.size.y * 0.5
	knot.offset_bottom = knot.size.y * 0.5
	_words.add_child(knot)

	# the single ember: a soft coal-orange glow that rises and sways
	_ember = TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.86, 0.6, 1.0), Color(UITheme.EMBER_HOT, 0.85),
		Color(UITheme.EMBER, 0.22), Color(UITheme.EMBER, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	_ember.texture = gt
	_ember.size = Vector2(26, 26)
	_ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ember.modulate.a = 0.0
	_root.add_child(_ember)

func _process(dt: float) -> void:
	if _done:
		return
	_t += dt
	var vp := get_viewport().get_visible_rect().size
	if _ember_from == Vector2.ZERO:
		_ember_from = Vector2(vp.x * 0.5 + 150.0, vp.y * 0.80)
	var a_in := clampf((_t - T_DARK) / T_IN, 0.0, 1.0)
	a_in = a_in * a_in * (3.0 - 2.0 * a_in)
	if not _leaving:
		_words.modulate.a = a_in
		if not hold_forever and _t > T_DARK + T_IN + T_HOLD:
			_leave(T_OUT)
	# the ember rises the whole time, slowly, swaying like a real one
	var et := maxf(_t - T_DARK * 0.5, 0.0)
	var rise := minf(et * 46.0, vp.y * 0.55)
	if hold_forever:
		rise = minf(rise, vp.y * 0.19)
	var sway := sin(et * 0.9) * 22.0 + sin(et * 2.3) * 5.0
	_ember.position = _ember_from + Vector2(sway, -rise) - _ember.size * 0.5
	var flick := 0.82 + 0.18 * sin(et * 7.0) * sin(et * 3.1)
	var life := clampf(et / 1.2, 0.0, 1.0) * clampf(1.0 - (rise - vp.y * 0.38) / (vp.y * 0.17), 0.0, 1.0)
	_ember.modulate.a = life * flick * (1.0 if not _leaving else _words.modulate.a)

func _input(event: InputEvent) -> void:
	if _leaving or _done:
		return
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed)
	if press:
		get_viewport().set_input_as_handled()
		_leave(0.45)

func _leave(t: float) -> void:
	_leaving = true
	var tw := create_tween()
	tw.tween_property(_words, "modulate:a", 0.0, t * minf(1.0, _words.modulate.a + 0.2)) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		_done = true
		finished.emit()
		queue_free())
