class_name InventoryUI
extends CanvasLayer
## The Pack — Tab opens it. Two leaves: the PACK (arms and
## relics; drag or click an arm onto a hand-slot 1-5) and the SONGS (known
## songs; click or drop one to attune it to X). Fully mouse-driven — click
## rows, click slots, or drag between them — with W/S + 1-5 + Q/E still live.

const GOLD := Color(0.95, 0.82, 0.48)
const PARCH := Color(0.94, 0.90, 0.80)
const DIM := Color(0.64, 0.58, 0.46)

var player: Node
var _scroll: ScrollContainer
var _list: VBoxContainer
var _tab := "pack"           # "pack" | "songs" | "armour"
const TABS := ["pack", "songs", "armour"]   # A/D walks the leaves in this order
var _tab_btns := {}
var _slots: Array = []          # hand-slot drop targets (pack)
var _attune_slot: Panel = null  # the X-song drop target (songs)
var _rows: Array = []           # [{id, kind, panel, head}] in view order
var _sel := 0
var _hint: Label = null
var _belt_lbl: Label = null
var _attune_lbl: Label = null

static func open_for(p) -> void:
	if p == null or not p.get_tree().get_nodes_in_group("inventory_ui").is_empty():
		return
	p.get_tree().root.add_child(InventoryUI.new(p))

func _init(p) -> void:
	player = p

func _ready() -> void:
	layer = 22
	add_to_group("inventory_ui")
	player.lock_control(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.008, 0.006, 0.62)
	root.add_child(dim)

	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.035, 0.03, 0.97)
	sb.border_color = Color(0.76, 0.64, 0.40)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.78)
	sb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -500; panel.offset_right = 500
	panel.offset_top = -368; panel.offset_bottom = 368
	root.add_child(panel)

	# Inner hairline gold frame
	var inner := Panel.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0, 0, 0, 0)
	isb.border_color = Color(0.56, 0.46, 0.28, 0.45)
	isb.set_border_width_all(1)
	inner.add_theme_stylebox_override("panel", isb)
	inner.position = Vector2(8, 8)
	inner.size = Vector2(984, 720)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(inner)

	# ---- tab bar
	_add_tab(panel, "pack", "The Pack", 30)
	_add_tab(panel, "songs", "The Songs", 250)
	_add_tab(panel, "armour", "The Armour", 470)
	var rule := ColorRect.new()
	rule.color = Color(0.74, 0.62, 0.38, 0.72)
	rule.position = Vector2(30, 64); rule.size = Vector2(940, 2)
	panel.add_child(rule)

	# ---- scrolling list
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(30, 78); _scroll.size = Vector2(940, 520)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(920, 0)
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	# ---- hand-slot rail (pack) + attune slot (songs) share the footer band
	var frule := ColorRect.new()
	frule.color = Color(0.58, 0.48, 0.30, 0.45)
	frule.position = Vector2(30, 608); frule.size = Vector2(940, 1)
	panel.add_child(frule)
	_build_hand_rail(panel)
	_build_attune_slot(panel)
	_build_armour_rail(panel)

	_hint = Label.new()
	_hint.label_settings = _ls(16, DIM)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = 30; _hint.offset_top = -32; _hint.offset_bottom = -12
	panel.add_child(_hint)

	_show_tab("pack")
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)

# ------------------------------------------------------------------ tabs

func _add_tab(panel: Panel, key: String, text: String, x: float) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.position = Vector2(x, 18); b.size = Vector2(210, 40)
	b.add_theme_font_override("font", load("res://assets/fonts/DejaVuSerif-Bold.ttf"))
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", PARCH)
	b.pressed.connect(func(): _show_tab(key))
	panel.add_child(b)
	_tab_btns[key] = b

func _show_tab(key: String) -> void:
	_tab = key
	for k in _tab_btns:
		(_tab_btns[k] as Button).add_theme_color_override("font_color", GOLD if k == key else DIM)
	_sel = 0
	_rebuild_list()
	for s in _slots:
		(s["panel"] as Control).visible = (key == "pack")
	_attune_slot.visible = (key == "songs")
	if _belt_lbl != null: _belt_lbl.visible = (key == "pack")
	if _attune_lbl != null: _attune_lbl.visible = (key == "songs")
	_show_armour_rail(key == "armour")
	_hint.text = ("A/D — leaf     W/S — choose     1-5 or drag — set the arm in that hand-slot     Tab — close" \
		if key == "pack" else \
		"A/D — leaf     W/S — choose     Enter/click/drag — attune the song to  X     Tab — close")
	if key == "armour":
		_hint.text = "A/D — leaf     W/S — choose     Enter/click/drag — wear it (again to take it off)     1-4 — that slot     Tab — close"

# ------------------------------------------------------------------ list

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	if _tab == "pack":
		_fill_pack()
	elif _tab == "armour":
		_fill_armour()
	else:
		_fill_songs()
	_mark_selected.call_deferred()

func _fill_pack() -> void:
	_section("ARMS")
	for id in DB.table("weapons"):
		if player.owns_weapon(id):
			var w: Dictionary = DB.table("weapons")[id]
			var nm: String = w.get("name", id)
			if id == player.weapon_id: nm += "   — in hand"
			if int(player.weapon_level) > 0: nm += "  (+%d)" % int(player.weapon_level)
			var tag := ""
			if w.has("damage"):
				var base_dmg := int(w.get("damage", 0))
				var upg: Dictionary = w.get("upgrade", {})
				var per_lvl := int(upg.get("per_level", 6))
				var atk := base_dmg + int(player.weapon_level) * per_lvl
				var poise := int(w.get("poise_damage", 0))
				tag = "ATK %d   Poise %d" % [atk, poise]
			_row(id, "arm", _icon_for(id), nm, tag, w.get("desc", ""))
	_row("gourd", "gourd", "res://assets/ui/icons/gourd.png", "Gourd",
		"✕%d / %d" % [player.gourds, player.gourd_max], DB.item("gourd").get("desc", ""))
	_section("RELICS & GOODS")
	var any := false
	for id in player.inventory:
		if not DB.weapon(id).is_empty() or not DB.song(id).is_empty():
			continue
		if not Player.armour_data(id).is_empty():
			continue   # armour lives on its own leaf
		var n := int(player.inventory[id])
		if n <= 0: continue
		any = true
		var it: Dictionary = DB.item(id)
		_relic_row(_icon_for(id), it.get("name", String(id).capitalize()), "✕%d" % n,
			it.get("desc", "A keepsake of the road. Nobody remembers what it was for."))
	if not any:
		_note("    Nothing but road-dust and resolve.")

func _fill_songs() -> void:
	_section("KNOWN SONGS")
	var any := false
	for id in DB.table("songs"):
		if int(player.inventory.get(id, 0)) < 1:
			continue
		any = true
		var sp: Dictionary = DB.table("songs")[id]
		var nm: String = sp.get("name", id)
		if id == player.attuned_song: nm += "   — attuned  [X]"
		_row(id, "song", _icon_for(id), nm,
			"%d breath" % int(sp.get("breath", 0)), sp.get("desc", ""))
	if not any:
		_note("    No songs yet. The Prior of the First Breath teaches them.")

# ------------------------------------------------------------------ rows

## A selectable, draggable row (arm / gourd / song). Click acts on it; drag
## carries {id, kind} to a hand-slot or the attune slot.
func _row(id: String, kind: String, icon_path: String, nm: String, tag: String, desc: String) -> void:
	var idx := _rows.size()
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.055, 0.048, 0.04, 0.45)
	st.border_color = Color(0.42, 0.35, 0.24, 0.35)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.set_meta("box", st)
	pc.gui_input.connect(_on_row_input.bind(idx))
	pc.set_drag_forwarding(_drag_row.bind(pc, id, kind), Callable(), Callable())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	pc.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path): icon.texture = load(icon_path)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := Label.new()
	head.label_settings = _ls(22, PARCH, "res://assets/fonts/DejaVuSerif-Bold.ttf")
	head.text = nm + ("      " + tag if tag != "" else "")
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var body := Label.new()
	body.label_settings = _ls(16, Color(0.70, 0.66, 0.56))
	body.text = desc
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(820, 0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	_list.add_child(pc)
	_rows.append({"id": id, "kind": kind, "panel": pc, "head": head})

func _relic_row(icon_path: String, nm: String, tag: String, desc: String) -> void:
	# unbindable lore items — no selection, no drag
	var pc := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.044, 0.036, 0.38)
	st.border_color = Color(0.38, 0.32, 0.22, 0.30)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", st)
	_list.add_child(pc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	pc.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(52, 52)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(icon_path): icon.texture = load(icon_path)
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var head := Label.new()
	head.label_settings = _ls(22, PARCH, "res://assets/fonts/DejaVuSerif-Bold.ttf")
	head.text = nm + ("      " + tag if tag != "" else "")
	col.add_child(head)
	var body := Label.new()
	body.label_settings = _ls(16, Color(0.70, 0.66, 0.56))
	body.text = desc
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(820, 0)
	col.add_child(body)

func _section(text: String) -> void:
	var l := Label.new()
	l.label_settings = _ls(19, Color(0.80, 0.68, 0.44), "res://assets/fonts/DejaVuSerif-Bold.ttf")
	l.text = "◆  " + text
	_list.add_child(l)

func _note(text: String) -> void:
	var l := Label.new()
	l.label_settings = _ls(19, DIM)
	l.text = text
	_list.add_child(l)

func _on_row_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_sel = idx
		_mark_selected()
		_act_selected()   # click acts: song attunes; arm awaits a slot

## Clicking a song attunes it outright; clicking an arm only selects it (it
## still needs a hand-slot, by 1-5, click, or drag).
func _act_selected() -> void:
	if _sel >= _rows.size():
		return
	var r: Dictionary = _rows[_sel]
	if r["kind"] == "song":
		player.attune_song(r["id"])
		Game.toast.emit("%s is attuned. Cast with X." % _name_of(r["id"]))
		AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)
		_rebuild_list()
	elif r["kind"] == "armour":
		_toggle_armour(r["id"])

# ------------------------------------------------------------------ hand rail

func _build_hand_rail(panel: Panel) -> void:
	for i in 5:
		var pnl := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.07, 0.05, 0.92)
		st.border_color = Color(0.54, 0.45, 0.30)
		st.set_border_width_all(1); st.set_corner_radius_all(3)
		pnl.add_theme_stylebox_override("panel", st)
		pnl.position = Vector2(30 + i * 72, 622); pnl.size = Vector2(60, 60)
		pnl.set_drag_forwarding(Callable(), _can_drop_hand, _drop_hand.bind(i))
		pnl.gui_input.connect(_on_hand_input.bind(i))
		panel.add_child(pnl)
		var num := Label.new()
		num.label_settings = _ls(13, Color(0.82, 0.72, 0.52))
		num.position = Vector2(5, 1); num.text = str(i + 1)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_child(num)
		var icon := TextureRect.new()
		icon.position = Vector2(6, 6); icon.size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_child(icon)
		_slots.append({"panel": pnl, "icon": icon})
	var lbl := Label.new()
	lbl.label_settings = _ls(15, DIM)
	lbl.text = "the belt"
	lbl.position = Vector2(408, 642)
	panel.add_child(lbl)
	_belt_lbl = lbl
	_refresh_hand()

func _refresh_hand() -> void:
	for i in _slots.size():
		var id: String = String(player.hotbar[i])
		var icon: TextureRect = _slots[i]["icon"]
		icon.texture = load(_icon_for(id)) if (id != "" and ResourceLoader.exists(_icon_for(id))) else null

func _on_hand_input(event: InputEvent, i: int) -> void:
	# click a slot with an arm selected -> bind it there
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _tab == "pack" and _sel < _rows.size() and _rows[_sel]["kind"] in ["arm", "gourd"]:
			_bind_hand(i, _rows[_sel]["id"])

func _can_drop_hand(_at, data) -> bool:
	return data is Dictionary and data.get("kind", "") in ["arm", "gourd"]

func _drop_hand(_at, data, i: int) -> void:
	_bind_hand(i, data["id"])

func _bind_hand(i: int, id: String) -> void:
	player.set_hotbar_slot(i, id)
	_refresh_hand()
	Game.toast.emit("%s rides in slot %d." % [_name_of(id), i + 1])
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)

# ------------------------------------------------------------------ attune slot

func _build_attune_slot(panel: Panel) -> void:
	_attune_slot = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.10, 0.085, 0.04, 0.94)
	st.border_color = GOLD
	st.set_border_width_all(2); st.set_corner_radius_all(3)
	_attune_slot.add_theme_stylebox_override("panel", st)
	_attune_slot.position = Vector2(30, 622); _attune_slot.size = Vector2(60, 60)
	_attune_slot.set_drag_forwarding(Callable(), _can_drop_attune, _drop_attune)
	panel.add_child(_attune_slot)
	var c := Label.new()
	c.label_settings = _ls(22, GOLD, "res://assets/fonts/DejaVuSerif-Bold.ttf")
	c.text = "X"; c.position = Vector2(22, 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attune_slot.add_child(c)
	var lbl := Label.new()
	lbl.label_settings = _ls(15, DIM)
	lbl.text = "the song on your tongue  —  drop a song here, or click it"
	lbl.position = Vector2(104, 642)
	panel.add_child(lbl)
	_attune_lbl = lbl

func _can_drop_attune(_at, data) -> bool:
	return data is Dictionary and data.get("kind", "") == "song"

func _drop_attune(_at, data) -> void:
	player.attune_song(data["id"])
	Game.toast.emit("%s is attuned. Cast with X." % _name_of(data["id"]))
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)
	_rebuild_list()

# ------------------------------------------------------------------ armour leaf
## Four worn slots (head, body, hands, legs) on the footer band. A piece is
## worn by clicking/Enter on its row, dropping it on its slot, or 1-4 with it
## selected; doing it again (or clicking a filled slot) takes it off.

var _armour_slots: Array = []   # [{slot, panel, icon, name}]
var _armour_lbl: Label = null

func _build_armour_rail(panel: Panel) -> void:
	var slots: Array = Player.armour_slots()
	for i in slots.size():
		var slot := String(slots[i])
		var pnl := Panel.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.07, 0.05, 0.92)
		st.border_color = Color(0.54, 0.45, 0.30)
		st.set_border_width_all(1); st.set_corner_radius_all(3)
		pnl.add_theme_stylebox_override("panel", st)
		pnl.set_meta("box", st)
		pnl.position = Vector2(30 + i * 136, 616); pnl.size = Vector2(128, 74)
		pnl.set_drag_forwarding(Callable(), _can_drop_armour.bind(slot), _drop_armour.bind(slot))
		pnl.gui_input.connect(_on_armour_slot_input.bind(slot))
		panel.add_child(pnl)
		var icon := TextureRect.new()
		icon.position = Vector2(4, 6); icon.size = Vector2(46, 46)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_child(icon)
		var key := Label.new()
		key.label_settings = _ls(13, Color(0.82, 0.72, 0.52))
		key.position = Vector2(52, 6); key.text = "%d  %s" % [i + 1, slot.capitalize()]
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_child(key)
		var nm := Label.new()
		nm.label_settings = _ls(12, PARCH)
		nm.position = Vector2(52, 26); nm.size = Vector2(74, 44)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_child(nm)
		_armour_slots.append({"slot": slot, "panel": pnl, "icon": icon, "name": nm})
	_armour_lbl = Label.new()
	_armour_lbl.label_settings = _ls(15, DIM)
	_armour_lbl.position = Vector2(30 + slots.size() * 136 + 10, 622)
	_armour_lbl.size = Vector2(380, 70)
	panel.add_child(_armour_lbl)
	_refresh_armour()

func _show_armour_rail(on: bool) -> void:
	for a in _armour_slots:
		(a["panel"] as Control).visible = on
	if _armour_lbl != null:
		_armour_lbl.visible = on

func _refresh_armour() -> void:
	for a in _armour_slots:
		var id := String(player.armour.get(a["slot"], ""))
		var path := _icon_for(id) if id != "" else "res://assets/ui/icons/slot_%s.png" % a["slot"]
		(a["icon"] as TextureRect).texture = load(path) if ResourceLoader.exists(path) else null
		(a["name"] as Label).text = _name_of(id) if id != "" else "bare"
		var st: StyleBoxFlat = (a["panel"] as Panel).get_meta("box")
		st.border_color = GOLD if id != "" else Color(0.54, 0.45, 0.30)
	if _armour_lbl != null:
		_armour_lbl.text = "Poise %d     Weight %.1f  (%s roll)\nTurns  %d%% of blows   %d%% of the cold" % [
			int(player.max_poise), player.worn_weight(), player.roll_tier(),
			roundi(player.absorption("physical") * 100.0), roundi(player.absorption("frost") * 100.0)]

func _fill_armour() -> void:
	_section("ARMOUR")
	var any := false
	var ids: Array = []
	for id in DB.table("items"):
		if player.owns_armour(id):
			ids.append(id)
	for id in ids:
		any = true
		var a := Player.armour_data(id)
		var slot := String(a.get("slot", ""))
		var nm := _name_of(id)
		if String(player.armour.get(slot, "")) == id: nm += "   — worn"
		var ab: Dictionary = a.get("absorb", {})
		var tag := "%s   Poise %d   Blows %d%%  Cold %d%%   Wt %.1f" % [slot.capitalize(),
			int(a.get("poise", 0)), roundi(float(ab.get("phys", 0)) * 100.0),
			roundi(float(ab.get("frost", 0)) * 100.0), float(a.get("weight", 0))]
		_row(id, "armour", _icon_for(id), nm, tag, DB.item(id).get("desc", ""))
	if not any:
		_note("    Nothing to wear but the weather.")

## Wear a piece in its own slot, or take it off if it is already worn.
func _toggle_armour(id: String) -> void:
	var slot := String(Player.armour_data(id).get("slot", ""))
	if String(player.armour.get(slot, "")) == id:
		_wear(slot, "")
	else:
		_wear(slot, id)

func _wear(slot: String, id: String) -> void:
	if not player.equip_armour(slot, id):
		Game.toast.emit("That is not worn on the %s." % slot)
		return
	Game.toast.emit(("%s is worn." % _name_of(id)) if id != "" else ("The %s is bare." % slot))
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)
	_refresh_armour()
	var keep := _sel
	_rebuild_list()
	_sel = keep

## 1-4 on the Armour leaf: the selected piece into that slot (if it fits).
func _armour_key(i: int) -> void:
	var slot := String(_armour_slots[i]["slot"])
	if _sel < _rows.size() and _rows[_sel]["kind"] == "armour":
		var id := String(_rows[_sel]["id"])
		if String(player.armour.get(slot, "")) == id:
			_wear(slot, "")
		else:
			_wear(slot, id)

func _on_armour_slot_input(event: InputEvent, slot: String) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _sel < _rows.size() and _rows[_sel]["kind"] == "armour" \
			and String(Player.armour_data(_rows[_sel]["id"]).get("slot", "")) == slot \
			and String(player.armour.get(slot, "")) != String(_rows[_sel]["id"]):
		_wear(slot, String(_rows[_sel]["id"]))
	elif String(player.armour.get(slot, "")) != "":
		_wear(slot, "")   # clicking a filled slot takes the piece off

func _can_drop_armour(_at, data, slot: String) -> bool:
	return data is Dictionary and data.get("kind", "") == "armour" \
		and String(Player.armour_data(String(data["id"])).get("slot", "")) == slot

func _drop_armour(_at, data, slot: String) -> void:
	_wear(slot, String(data["id"]))

# ------------------------------------------------------------------ drag

func _drag_row(_at, ctrl: Control, id: String, kind: String) -> Variant:
	var prev := Panel.new()
	prev.size = Vector2(56, 56)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.1, 0.06, 0.95); st.border_color = GOLD
	st.set_border_width_all(1); st.set_corner_radius_all(3)
	prev.add_theme_stylebox_override("panel", st)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var ip := _icon_for(id)
	if ResourceLoader.exists(ip): icon.texture = load(ip)
	prev.add_child(icon)
	ctrl.set_drag_preview(prev)
	return {"id": id, "kind": kind}

# ------------------------------------------------------------------ keyboard

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		close(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("move_left"):
		_show_tab(TABS[maxi(TABS.find(_tab) - 1, 0)]); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("move_right"):
		_show_tab(TABS[mini(TABS.find(_tab) + 1, TABS.size() - 1)]); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("move_forward"):
		_sel = maxi(_sel - 1, 0); _mark_selected(); _scroll.scroll_vertical -= 56; return
	if event.is_action_pressed("move_back"):
		_sel = mini(_sel + 1, _rows.size() - 1); _mark_selected(); _scroll.scroll_vertical += 56; return
	if event.is_action_pressed("interact") and _sel < _rows.size():
		_act_selected(); get_viewport().set_input_as_handled(); return
	if _tab == "armour":
		for i in _armour_slots.size():
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				_armour_key(i); get_viewport().set_input_as_handled(); return
	for i in 5:
		if event.is_action_pressed("hotbar_%d" % (i + 1)) and _tab == "pack" \
				and _sel < _rows.size() and _rows[_sel]["kind"] in ["arm", "gourd"]:
			_bind_hand(i, _rows[_sel]["id"])
			get_viewport().set_input_as_handled(); return

func _mark_selected() -> void:
	for i in _rows.size():
		var st: StyleBoxFlat = _rows[i]["panel"].get_meta("box")
		st.bg_color = Color(0.16, 0.13, 0.07, 0.92) if i == _sel else Color(0.055, 0.048, 0.04, 0.45)
		st.border_color = Color(0.92, 0.78, 0.44, 0.85) if i == _sel else Color(0.42, 0.35, 0.24, 0.35)
		(_rows[i]["head"] as Label).label_settings.font_color = GOLD if i == _sel else PARCH

# ------------------------------------------------------------------ helpers

func _name_of(id: String) -> String:
	if not DB.weapon(id).is_empty(): return DB.weapon(id).get("name", id)
	if not Player.armour_data(id).is_empty(): return DB.item(id).get("name", id)
	if not DB.song(id).is_empty(): return DB.song(id).get("name", id)
	if id == "gourd": return "Gourd"
	return String(id).capitalize()

func _icon_for(id: String) -> String:
	var by := {
		"hewing_blade": "hewing_blade", "spear": "spear", "bow": "bow",
		"greatblade": "greatblade", "maul": "maul", "torch": "torch",
		"arrows": "arrows", "gourd": "gourd", "deep_gourd": "gourd", "bog_iron": "bog_iron",
		"mend": "song", "ember_throw": "song", "hearth_shout": "song",
		"long_note": "song", "warding_hum": "song",
		"armour_traveller_coat": "armour_coat", "armour_saltfell_oilskins": "armour_oilskins",
	}
	return "res://assets/ui/icons/%s.png" % by.get(id, "relic")

func _ls(size: int, color: Color, font := "res://assets/fonts/DejaVuSerif.ttf") -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = load(font); ls.font_size = size; ls.font_color = color
	return ls

func close() -> void:
	if player != null and is_instance_valid(player):
		player.lock_control(false)
		player.suppress_interact(10)
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if player.look_compat else Input.MOUSE_MODE_CAPTURED
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -10.0)
	queue_free()
