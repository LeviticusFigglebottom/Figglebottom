class_name MapView
extends Control
## The Map, drawn. The land is baked (tools/ui/build_map.py): a dim base of
## the whole highland, and one parchment sheet per region laid over it once
## the Bearer has walked into that region, so country not yet visited stays
## dark. Everything else is drawn here from MapState.markers(): Hearthstones,
## the frost veil, the ways on, found places, the pinned objective and the
## Bearer. Two views: the whole highland, and one region.

const INK := Color(0.20, 0.14, 0.09)
const PAPER := Color(0.90, 0.85, 0.73)
const ICE := Color(0.74, 0.86, 0.96)

var mode := "overview"      # "overview" | "region"
var area := ""              # the region shown (and the one picked out in the overview)
var _tex := {}
var _t := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(930, 628)
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_STOP
	area = Game.current_area_id if MapState.region_seen(Game.current_area_id) else ""
	if area == "":
		for r in MapState.regions():
			if MapState.region_seen(r):
				area = r
				break

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()     # the Bearer's mark and the pin breathe

func _texture(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

# ---------------------------------------------------------------- views

func seen_regions() -> Array:
	return MapState.regions().filter(func(r): return MapState.region_seen(r))

func show_overview() -> void:
	mode = "overview"
	queue_redraw()

func show_region(id: String) -> void:
	if not MapState.region_seen(id):
		return
	area = id
	mode = "region"
	queue_redraw()

func toggle() -> void:
	if mode == "overview" and area != "":
		show_region(area)
	else:
		show_overview()

## Step to the next (or previous) discovered region.
func step(d: int) -> void:
	var seen := seen_regions()
	if seen.is_empty():
		return
	var i := seen.find(area)
	area = seen[posmod(i + d, seen.size())]
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if mode == "overview":
				var hit := region_at(event.position)
				if hit != "":
					show_region(hit)
			else:
				show_overview()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			show_overview()
			accept_event()

## The discovered region under a point of the overview ("" if none).
func region_at(at: Vector2) -> String:
	var w := _world_at(at)
	var best := ""
	var best_d := 1e9
	for r in seen_regions():
		var m := MapState.region(r)
		var o := Vector2(m["origin"][0], m["origin"][1])
		var s := Vector2(m["size_m"][0], m["size_m"][1])
		if Rect2(o, s).has_point(w):
			var d := w.distance_to(o + s * 0.5)
			if d < best_d:
				best_d = d
				best = r
	return best

# ---------------------------------------------------------------- transform

const HEAD := 40.0
const FOOT := 34.0

## The world rectangle on show, in metres (x east, z south).
func _frame() -> Rect2:
	var m: Dictionary = MapState.meta().get("world", {})
	if mode == "region" and area != "":
		m = MapState.region(area)
	if m.is_empty():
		return Rect2(0, 0, 1, 1)
	return Rect2(m["origin"][0], m["origin"][1], m["size_m"][0], m["size_m"][1])

func _scale() -> float:
	var f := _frame()
	return minf(size.x / f.size.x, (size.y - HEAD - FOOT) / f.size.y)

func to_view(world: Vector2) -> Vector2:
	var f := _frame()
	var k := _scale()
	var off := Vector2((size.x - f.size.x * k) * 0.5, HEAD + (size.y - HEAD - FOOT - f.size.y * k) * 0.5)
	return off + (world - f.position) * k

func _world_at(view: Vector2) -> Vector2:
	var f := _frame()
	var k := _scale()
	var off := Vector2((size.x - f.size.x * k) * 0.5, HEAD + (size.y - HEAD - FOOT - f.size.y * k) * 0.5)
	return f.position + (view - off) / k

func _rect_of(m: Dictionary) -> Rect2:
	var a := to_view(Vector2(m["origin"][0], m["origin"][1]))
	return Rect2(a, Vector2(m["size_m"][0], m["size_m"][1]) * _scale())

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.032, 0.030))
	var meta := MapState.meta()
	if meta.is_empty():
		_text(Vector2(20, 60), "The map has not been drawn.", 20, UITheme.BONE_DIM)
		return
	var base := _texture(String(meta["world"]["image"]))
	if base != null:
		draw_texture_rect(base, _rect_of(meta["world"]), false, Color(1, 1, 1, 0.9 if mode == "overview" else 0.55))
	# the sheets: the region on show last, so it lies on top where two overlap
	var order: Array = seen_regions()
	if order.has(area):
		order.erase(area)
		order.append(area)
	for r in order:
		var m := MapState.region(r)
		var t := _texture(String(m.get("image", "")))
		if t == null:
			continue
		var dim := 1.0
		if mode == "region" and r != area:
			dim = 0.42
		draw_texture_rect(t, _rect_of(m), false, Color(dim, dim, dim, 1.0))
	if mode == "overview":
		_draw_links()
	for mk in MapState.markers("" if mode == "overview" else area):
		_draw_marker(mk)
	if mode == "overview":
		for r in seen_regions():
			var m := MapState.region(r)
			var at := to_view(Vector2(m["label_at"][0], m["label_at"][1]))
			_label(at + Vector2(0, -16), String(m["name"]), 21 if r != area else 23, true, r == area)
	_draw_head()
	_draw_legend()
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color(UITheme.EMBER, 0.35), false, 1.0)

func _draw_head() -> void:
	draw_rect(Rect2(0, 0, size.x, HEAD), Color(0.035, 0.032, 0.030, 0.92))
	draw_line(Vector2(0, HEAD), Vector2(size.x, HEAD), Color(UITheme.EMBER, 0.35), 1.0)
	var title := "Rimeholt"
	if mode == "region" and area != "":
		title = String(MapState.region(area).get("name", area))
	draw_string(UITheme.font("caps"), Vector2(16, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UITheme.EMBER_HOT)
	var n := seen_regions().size()
	var total := MapState.regions().size()
	var note := "%d of %d regions walked" % [n, total]
	if mode == "region":
		var st := "RIME" if World.get_area_state(area) == RH.WState.RIME else "THAW"
		note = "in %s%s" % [st, "   ·   Holdfast released" if World.is_cleared(area) else ""]
	draw_string(UITheme.font("italic"), Vector2(0, 27), note, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16, 17, UITheme.BONE_DIM)

func _draw_legend() -> void:
	var y := size.y - FOOT
	draw_rect(Rect2(0, y, size.x, FOOT), Color(0.035, 0.032, 0.030, 0.92))
	draw_line(Vector2(0, y), Vector2(size.x, y), Color(UITheme.BONE, 0.12), 1.0)
	var x := 18.0
	var items := [["bearer", "You"], ["hearth_last", "Last rest"], ["hearth", "Hearthstone"], ["hearth_seen", "not yet rested at"],
		["veil", "Frost veil"], ["veil_released", "Holdfast released"], ["seam", "Way on"], ["pin", "Pinned objective"]]
	var f := UITheme.font("regular")
	for it in items:
		var c := Vector2(x + 8, y + FOOT * 0.5)
		match it[0]:
			"bearer": _glyph_bearer(c, 0.0)
			"hearth_last": _glyph_hearth(c, true, true)
			"hearth": _glyph_hearth(c, true, false)
			"hearth_seen": _glyph_hearth(c, false, false)
			"veil": _glyph_veil(c, false)
			"veil_released": _glyph_veil(c, true)
			"seam": _glyph_seam(c, true)
			"pin": _glyph_pin(c)
		draw_string(f, Vector2(x + 22, y + FOOT * 0.5 + 5), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UITheme.BONE_DIM)
		x += 30 + f.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 12

## The ways between regions on the overview: a dotted line from one
## region's name, through the seam, to the next. A way whose far end has
## not been walked stops at the seam.
func _draw_links() -> void:
	var done := {}
	for r in seen_regions():
		for mk in MapState.markers(r):
			if mk["kind"] != "seam":
				continue
			var key := "%s>%s" % [r, mk["to"]]
			if done.has(key):
				continue
			done[key] = true
			var a := MapState.region(r)
			var pts := [to_view(Vector2(a["label_at"][0], a["label_at"][1])), to_view(mk["pos"])]
			if mk["known"]:
				if done.has("%s>%s" % [mk["to"], r]):
					continue
				var b := MapState.region(String(mk["to"]))
				pts.append(to_view(Vector2(b["label_at"][0], b["label_at"][1])))
			for i in pts.size() - 1:
				_dotted(pts[i], pts[i + 1], Color(UITheme.EMBER_DEEP, 0.9))

func _dotted(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 7.0)
	for i in range(1, n):
		draw_circle(a.lerp(b, float(i) / n), 1.5, col)

func _draw_marker(mk: Dictionary) -> void:
	var at := to_view(mk["pos"])
	if at.y < HEAD - 6 or at.y > size.y - FOOT + 6:
		return
	var near := mode == "region"
	match String(mk["kind"]):
		"hearth":
			_glyph_hearth(at, mk["rested"], mk["last"])
			if near:
				_label(at + Vector2(0, 21), HUD._caps_case(String(mk["name"]).to_upper()), 15, false, mk["last"])
		"veil":
			_glyph_veil(at, mk["released"])
		"seam":
			if near:
				_glyph_seam(at, mk["known"])
				var txt: String = mk["label"]
				if mk["known"]:
					txt = "to %s" % mk["to_name"] if txt == "" else "%s, to %s" % [txt, mk["to_name"]]
				if txt != "":
					_label(at + Vector2(0, -15), txt, 14, false, false, true)
		"place":
			if near:
				_label(at, String(mk["name"]), 18 if mk["zone"] else 14, bool(mk["zone"]), false, not bool(mk["zone"]))
		"pin":
			_glyph_pin(at)
		"bearer":
			_glyph_bearer(at, float(mk["yaw"]))

# ---- glyphs: small inked marks, not pictures

func _glyph_hearth(c: Vector2, rested: bool, last: bool) -> void:
	if last:
		draw_circle(c, 13.0 + sin(_t * 2.4) * 1.2, Color(UITheme.EMBER_HOT, 0.28))
		draw_arc(c, 12.0, 0, TAU, 28, UITheme.EMBER_HOT, 1.6, true)
	var stone := Rect2(c + Vector2(-6.5, -1), Vector2(13, 7))
	draw_rect(stone.grow(1.2), INK)
	draw_rect(stone, PAPER if rested else Color(0.55, 0.50, 0.42))
	if rested:
		var flame := PackedVector2Array([c + Vector2(-4, -1), c + Vector2(0, -10), c + Vector2(4, -1)])
		draw_colored_polygon(flame, UITheme.EMBER)
		draw_polyline(PackedVector2Array([flame[0], flame[1], flame[2]]), INK, 1.2, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-1.8, -1), c + Vector2(0, -5.5), c + Vector2(1.8, -1)]), UITheme.EMBER_HOT)

func _glyph_veil(c: Vector2, released: bool) -> void:
	var col := Color(0.48, 0.46, 0.42) if released else ICE
	for i in 3:
		var x := (i - 1) * 5.5
		var h := 13.0 if i == 1 else 9.0
		var shard := PackedVector2Array([c + Vector2(x - 2.8, 6), c + Vector2(x, 6 - h), c + Vector2(x + 2.8, 6)])
		draw_colored_polygon(shard, col)
		draw_polyline(PackedVector2Array([shard[0], shard[1], shard[2], shard[0]]), INK, 1.2, true)
	if released:
		# the veil is down: a line through it
		draw_line(c + Vector2(-10, 8), c + Vector2(10, -8), INK, 2.6, true)
		draw_line(c + Vector2(-10, 8), c + Vector2(10, -8), PAPER, 1.2, true)

func _glyph_seam(c: Vector2, known: bool) -> void:
	var col := UITheme.EMBER if known else Color(0.62, 0.42, 0.24)
	var d := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)])
	draw_colored_polygon(d, col)
	draw_polyline(PackedVector2Array([d[0], d[1], d[2], d[3], d[0]]), INK, 1.3, true)

func _glyph_pin(c: Vector2) -> void:
	var r := 11.0 + sin(_t * 3.0) * 1.5
	draw_arc(c, r, 0, TAU, 28, INK, 3.4, true)
	draw_arc(c, r, 0, TAU, 28, UITheme.EMBER_HOT, 1.8, true)
	draw_circle(c, 3.6, INK)
	draw_circle(c, 2.4, UITheme.EMBER_HOT)

func _glyph_bearer(c: Vector2, yaw: float) -> void:
	# facing: Godot yaw 0 looks down -z, which is up the sheet
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var tri := PackedVector2Array([c + fwd * 10.0, c - fwd * 6.0 + side * 6.5, c - fwd * 2.5, c - fwd * 6.0 - side * 6.5])
	draw_circle(c, 12.0, Color(UITheme.BONE, 0.16))
	draw_colored_polygon(tri, UITheme.BONE)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), INK, 1.6, true)

func _label(at: Vector2, text: String, px: int, caps: bool, lit := false, italic := false) -> void:
	var f := UITheme.font("caps" if caps else ("italic" if italic else "medium"))
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := Vector2(clampf(at.x - w * 0.5, 4.0, size.x - w - 4.0), at.y + px * 0.35)
	draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 5, Color(PAPER, 0.85))
	draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(0.42, 0.13, 0.03) if lit else INK)

func _text(at: Vector2, text: String, px: int, col: Color) -> void:
	draw_string(UITheme.font("regular"), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
