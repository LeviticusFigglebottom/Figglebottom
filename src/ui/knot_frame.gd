class_name KnotFrame
extends Control
## The house frame: an ember border with an interlaced knot at each corner,
## drawn procedurally (STYLE.md, UI: abstract knots, never runes or letters).
## The knot is one closed cord, a (4,3) torus-knot rosette, so a simple
## over-under-over walk along it is always a true interlace. Add it as the
## last child of a panel; it fills the panel and ignores the mouse.

## Distance of the border line from the panel edge.
@export var inset := 9.0
## Rosette radius at each corner.
@export var knot_r := 20.0
@export var cord_w := 2.4
@export var color := UITheme.EMBER
@export var gap_color := UITheme.COAL
@export var corners := true
## A second, fainter bone hairline inside the ember line.
@export var inner_line := true
## "frame": border and four corner knots; "mark": one knot, centred (a
## divider ornament, a toast's seal).
@export var mode := "frame"

const SAMPLES := 360
static var _unit: PackedVector2Array = PackedVector2Array()
static var _over: Array = []   # sample indices where the cord passes over

func _init(as_mark := false, r := 15.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if as_mark:
		mode = "mark"
		knot_r = r
		custom_minimum_size = Vector2(r, r) * 2.4
		size = custom_minimum_size
	else:
		set_anchors_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	resized.connect(queue_redraw)
	if _unit.is_empty():
		_build_unit()

## Sample the rosette once (unit radius) and find which strand is on top at
## every crossing by alternating along the cord.
static func _build_unit() -> void:
	var p := 4
	var q := 3
	var pts := PackedVector2Array()
	for i in SAMPLES:
		var t := TAU * float(i) / SAMPLES
		var rr := 0.70 + 0.30 * cos(p * t)
		pts.append(Vector2(cos(q * t), sin(q * t)) * rr)
	_unit = pts
	# crossings: every pair of non-adjacent segments that intersect
	var hits := []   # [sample_index_along_cord, crossing_id]
	var cid := 0
	for i in SAMPLES:
		var a0 := pts[i]
		var a1 := pts[(i + 1) % SAMPLES]
		for j in range(i + 2, SAMPLES):
			if i == 0 and j == SAMPLES - 1:
				continue
			var b0 := pts[j]
			var b1 := pts[(j + 1) % SAMPLES]
			if Geometry2D.segment_intersects_segment(a0, a1, b0, b1) != null:
				hits.append([i, cid])
				hits.append([j, cid])
				cid += 1
	hits.sort_custom(func(x, y): return x[0] < y[0])
	_over = []
	for k in hits.size():
		if k % 2 == 0:
			_over.append(int(hits[k][0]))

func _draw() -> void:
	if mode == "mark":
		_draw_knot(size * 0.5, knot_r)
		return
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	var line := Color(color, 0.62)
	var k := knot_r * 0.95 if corners else 0.0
	# the ember border, broken where each knot sits
	draw_line(r.position + Vector2(k, 0), Vector2(r.end.x - k, r.position.y), line, 1.0, true)
	draw_line(Vector2(r.position.x + k, r.end.y), r.end - Vector2(k, 0), line, 1.0, true)
	draw_line(r.position + Vector2(0, k), Vector2(r.position.x, r.end.y - k), line, 1.0, true)
	draw_line(Vector2(r.end.x, r.position.y + k), r.end - Vector2(0, k), line, 1.0, true)
	if inner_line:
		var ir := r.grow(-5.0)
		draw_rect(ir, Color(UITheme.BONE, 0.07), false, 1.0)
	if not corners:
		return
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		_draw_knot(c, knot_r)

func _draw_knot(center: Vector2, rad: float) -> void:
	var pts := PackedVector2Array()
	pts.resize(SAMPLES + 1)
	for i in SAMPLES:
		pts[i] = center + _unit[i] * rad
	pts[SAMPLES] = pts[0]
	# a dark seat so the border line and the panel do not show through
	if mode == "frame":
		draw_circle(center, rad * 0.98, Color(gap_color, 0.92))
	_cord(pts, 0, SAMPLES)
	# at each over-crossing: cut a gap through the under strand, then
	# lay the over strand back on top
	for i in _over:
		var a := maxi(0, i - 8)
		var b := mini(SAMPLES, i + 9)
		draw_polyline(pts.slice(a, b + 1), gap_color, cord_w + 3.2, true)
		_cord(pts, a, b)

func _cord(pts: PackedVector2Array, a: int, b: int) -> void:
	var seg := pts.slice(a, b + 1)
	draw_polyline(seg, color, cord_w, true)
	draw_polyline(seg, Color(UITheme.EMBER_HOT, 0.55), cord_w * 0.34, true)
