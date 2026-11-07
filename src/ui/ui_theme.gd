class_name UITheme
extends RefCounted
## The one look every screen shares (docs/art/STYLE.md, UI): bone-white type
## and coal-ember accents on near-black, set in Alegreya (OFL). Screens ask
## here for colours, fonts, label settings and panel boxes instead of mixing
## their own; the same values are baked into the project Theme resource
## (assets/ui/rimeholt_theme.tres, written by build_theme()) so a bare
## Control, Label or Button already wears them.

const THEME_PATH := "res://assets/ui/rimeholt_theme.tres"
const FONT_ROMAN := "res://assets/fonts/alegreya/Alegreya-VF.ttf"
const FONT_ITALIC := "res://assets/fonts/alegreya/Alegreya-Italic-VF.ttf"

# ---- palette
const COAL := Color(0.030, 0.027, 0.025)          # near-black ground
const COAL_PANEL := Color(0.042, 0.037, 0.033, 0.96)
const COAL_ROW := Color(0.070, 0.058, 0.048, 0.55)
const BONE := Color(0.925, 0.895, 0.825)          # body text
const BONE_DIM := Color(0.700, 0.668, 0.610)      # secondary text
const ASH := Color(0.480, 0.455, 0.420)           # hints, rules at rest
const EMBER := Color(0.905, 0.470, 0.180)         # the accent: lines, marks
const EMBER_HOT := Color(1.000, 0.690, 0.360)     # selection, the live coal
const EMBER_DEEP := Color(0.430, 0.170, 0.065)    # banked coal: fills, shadow
const BLOOD := Color(0.560, 0.140, 0.090)         # heart bar, the STILLED card
const WIND := Color(0.540, 0.600, 0.470)          # stamina: lichen, not neon

const SHADOW := Color(0, 0, 0, 0.85)

static var _fonts := {}
static var _theme: Theme = null

## weight: "regular" | "medium" | "bold" | "italic" | "caps" (the font's own
## small caps, smcp: lower case set as small capitals, capitals kept full;
## for names and title cards)
static func font(weight := "regular", spacing := 0) -> Font:
	var key := "%s/%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var fv := FontVariation.new()
	fv.base_font = load(FONT_ITALIC if weight == "italic" else FONT_ROMAN)
	var wght := {"regular": 400, "medium": 500, "bold": 700, "italic": 400, "caps": 500}
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): wght.get(weight, 400)}
	if weight == "caps":
		var ts := TextServerManager.get_primary_interface()
		fv.opentype_features = {ts.name_to_tag("smcp"): 1}
		fv.spacing_glyph = 2
	if spacing != 0:
		fv.spacing_glyph = spacing
	_fonts[key] = fv
	return fv

static func ls(size: int, color := BONE, weight := "regular", shadow := true) -> LabelSettings:
	var s := LabelSettings.new()
	s.font = font(weight)
	s.font_size = size
	s.font_color = color
	if shadow:
		s.shadow_color = SHADOW
		s.shadow_size = 4
		s.shadow_offset = Vector2(0, 2)
	return s

## A flat box in the house palette. kind: "panel" (a full sheet), "plate"
## (a small HUD backing), "row" (a list row), "row_sel" (the chosen row),
## "slot" (a belt slot), "slot_sel".
static func box(kind := "panel") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match kind:
		"panel":
			sb.bg_color = COAL_PANEL
			sb.border_color = Color(EMBER.r, EMBER.g, EMBER.b, 0.55)
			sb.set_border_width_all(1)
			sb.shadow_color = Color(0, 0, 0, 0.7)
			sb.shadow_size = 18
		"plate":
			sb.bg_color = Color(COAL.r, COAL.g, COAL.b, 0.80)
			sb.border_color = Color(EMBER.r, EMBER.g, EMBER.b, 0.40)
			sb.set_border_width_all(1)
		"row":
			sb.bg_color = Color(COAL_ROW.r, COAL_ROW.g, COAL_ROW.b, 0.35)
			sb.border_color = Color(BONE.r, BONE.g, BONE.b, 0.07)
			sb.set_border_width_all(1)
		"row_sel":
			sb.bg_color = Color(EMBER_DEEP.r, EMBER_DEEP.g, EMBER_DEEP.b, 0.38)
			sb.border_color = Color(EMBER.r, EMBER.g, EMBER.b, 0.70)
			sb.set_border_width_all(1)
			sb.border_width_left = 3
		"slot":
			sb.bg_color = Color(COAL.r, COAL.g, COAL.b, 0.86)
			sb.border_color = Color(BONE.r, BONE.g, BONE.b, 0.22)
			sb.set_border_width_all(1)
			sb.shadow_color = Color(0, 0, 0, 0.5)
			sb.shadow_size = 3
		"slot_sel":
			sb.bg_color = Color(EMBER_DEEP.r, EMBER_DEEP.g, EMBER_DEEP.b, 0.55)
			sb.border_color = EMBER_HOT
			sb.set_border_width_all(2)
			sb.shadow_color = Color(0, 0, 0, 0.5)
			sb.shadow_size = 3
		"empty":
			sb.bg_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

## A one-pixel rule that fades out at both ends, in ember.
static func rule(width: float, alpha := 0.7) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.18, 0.82, 1.0])
	var c := EMBER
	g.colors = PackedColorArray([Color(c, 0.0), Color(c, alpha), Color(c, alpha), Color(c, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 2
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = Vector2(width, 1)
	tr.size = Vector2(width, 1)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

## A menu button: bare words, an ember bar at the left when chosen.
static func style_button(b: Button, size := 26) -> Button:
	b.add_theme_font_override("font", font("regular"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", BONE_DIM)
	for k in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, EMBER_HOT)
	b.add_theme_color_override("font_disabled_color", Color(ASH, 0.5))
	var empty := box("empty")
	empty.content_margin_left = 16
	var sel := box("row_sel")
	sel.content_margin_left = 16
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	for st in ["hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, sel)
	return b

## The project theme: what a Control with no overrides looks like.
static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) if ResourceLoader.exists(THEME_PATH) else build_theme()
	return _theme

static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("regular")
	t.default_font_size = 22
	t.set_color("font_color", "Label", BONE)
	t.set_color("font_shadow_color", "Label", SHADOW)
	t.set_constant("shadow_offset_y", "Label", 2)
	for k in ["normal", "disabled"]:
		t.set_stylebox(k, "Button", box("empty"))
	for k in ["hover", "focus", "pressed"]:
		t.set_stylebox(k, "Button", box("row_sel"))
	t.set_color("font_color", "Button", BONE_DIM)
	t.set_color("font_hover_color", "Button", EMBER_HOT)
	t.set_color("font_focus_color", "Button", EMBER_HOT)
	t.set_color("font_pressed_color", "Button", EMBER_HOT)
	t.set_color("font_disabled_color", "Button", Color(ASH, 0.5))
	t.set_stylebox("panel", "Panel", box("panel"))
	t.set_stylebox("panel", "PanelContainer", box("row"))
	# sliders: an ember groove and a bone grabber
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(BONE, 0.14)
	groove.content_margin_top = 2
	groove.content_margin_bottom = 2
	var filled := StyleBoxFlat.new()
	filled.bg_color = EMBER
	filled.content_margin_top = 2
	filled.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var sbar := StyleBoxFlat.new()
	sbar.bg_color = Color(EMBER, 0.55)
	sbar.content_margin_left = 3
	sbar.content_margin_right = 3
	var strack := StyleBoxFlat.new()
	strack.bg_color = Color(BONE, 0.05)
	strack.content_margin_left = 3
	strack.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", sbar)
	t.set_stylebox("grabber_highlight", "VScrollBar", sbar)
	t.set_stylebox("grabber_pressed", "VScrollBar", sbar)
	t.set_stylebox("scroll", "VScrollBar", strack)
	return t
