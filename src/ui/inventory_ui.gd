class_name InventoryUI
extends CanvasLayer
## The Pack — Tab opens it (J opens it at the Keepsakes). Its leaves come
## from the registry below: the PACK (arms and relics; drag or click an arm
## onto a hand-slot 1-5), the SONGS (known songs; click or drop one to
## attune it to X), the KEEPSAKES (the journal). Fully mouse-driven — click
## rows, click slots, or drag between them — with W/S + 1-5 + A/D still live.

const GOLD := UITheme.EMBER_HOT
const PARCH := UITheme.BONE
const DIM := UITheme.BONE_DIM

## The leaf registry, in tab order. A leaf is {key, title, fill, footer, hint}:
## `fill` names a method on this UI, or is a script path whose static
## fill(ui) lists the leaf's rows; `footer` is "hand" (the belt rail),
## "attune" (the X slot) or "" (none). A new leaf is one register_leaf()
## call (or one line here) plus its fill; nothing else in this file changes.
static var LEAVES: Array = [
	{"key": "pack", "title": "The Pack", "fill": "_fill_pack", "footer": "hand",
	 "hint": "A/D  leaf      W/S  choose      1-5 or drag  set the arm in that hand-slot      Tab  close"},
	{"key": "songs", "title": "The Songs", "fill": "_fill_songs", "footer": "attune",
	 "hint": "A/D  leaf      W/S  choose      Enter, click or drag  attune the song to X      Tab  close"},
	{"key": "armour", "title": "The Armour", "fill": "_fill_armour", "footer": "armour",
	 "hint": "A/D  leaf      W/S  choose      Enter, click or drag  wear it (again to take it off)      1-4  that slot      Tab  close"},
	{"key": "keepsakes", "title": "Keepsakes", "fill": "res://src/ui/pack/keepsakes_leaf.gd", "footer": "",
	 "hint": "A/D  leaf      W/S  read on      Tab or J  close"},
]

static func register_leaf(def: Dictionary, before := "") -> void:
	for l in LEAVES:
		if l["key"] == def.get("key", ""):
			return
	var at := LEAVES.size()
	for i in LEAVES.size():
		if LEAVES[i]["key"] == before:
			at = i
	LEAVES.insert(at, def)

var player: Node
var _scroll: ScrollContainer
var _list: VBoxContainer
var _tab := "pack"           # "pack" | "songs"
var _tab_btns := {}
var _slots: Array = []          # hand-slot drop targets (pack)
var _attune_slot: Panel = null  # the X-song drop target (songs)
var _rows: Array = []           # [{id, kind, panel, head}] in view order
var _sel := 0
var _hint: Label = null
var _belt_lbl: Label = null
var _attune_lbl: Label = null

static func open_for(p, leaf := "pack") -> void:
	if p == null or not p.get_tree().get_nodes_in_group("inventory_ui").is_empty():
		return
	p.get_tree().root.add_child(InventoryUI.new(p, leaf))

var _first_leaf := "pack"
var _frule: ColorRect = null

func _init(p, leaf := "pack") -> void:
	player = p
	_first_leaf = leaf

func _ready() -> void:
	layer = 22
	add_to_group("inventory_ui")
	player.lock_control(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.theme = UITheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UITheme.COAL, 0.70)
	root.add_child(dim)

	var panel := Panel.new()
	var sb := UITheme.box("panel")
	sb.border_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -520; panel.offset_right = 520
	panel.offset_top = -380; panel.offset_bottom = 380
	root.add_child(panel)

	# ---- tab bar: one tab per registered leaf
	for i in LEAVES.size():
		_add_tab(panel, String(LEAVES[i]["key"]), String(LEAVES[i]["title"]), 44 + i * 232)
	var rule := ColorRect.new()
	rule.color = Color(UITheme.EMBER, 0.55)
	rule.position = Vector2(44, 84); rule.size = Vector2(952, 1)
	panel.add_child(rule)

	# ---- scrolling list
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(44, 98); _scroll.size = Vector2(952, 512)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(930, 0)
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)

	# ---- hand-slot rail (pack) + attune slot (songs) share the footer band
	var frule := ColorRect.new()
	_frule = frule
	frule.color = Color(UITheme.BONE, 0.12)
	frule.position = Vector2(44, 620); frule.size = Vector2(952, 1)
	panel.add_child(frule)
	_build_hand_rail(panel)
	_build_attune_slot(panel)
	_build_armour_rail(panel)

	_hint = Label.new()
	_hint.label_settings = _ls(17, UITheme.ASH, "italic")
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = 44; _hint.offset_top = -50; _hint.offset_bottom = -26
	panel.add_child(_hint)
	panel.add_child(KnotFrame.new())

	_show_tab(_first_leaf if not _leaf(_first_leaf).is_empty() else "pack")
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)

# ------------------------------------------------------------------ tabs

func _add_tab(panel: Panel, key: String, text: String, x: float) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.position = Vector2(x, 30); b.size = Vector2(220, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", UITheme.font("caps"))
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", PARCH)
	b.add_theme_color_override("font_pressed_color", GOLD)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(func(): _show_tab(key))
	panel.add_child(b)
	_tab_btns[key] = b

func _leaf(key: String) -> Dictionary:
	for l in LEAVES:
		if l["key"] == key:
			return l
	return {}

func _leaf_step(d: int) -> void:
	var i := 0
	for k in LEAVES.size():
		if LEAVES[k]["key"] == _tab:
			i = k
	_show_tab(String(LEAVES[clampi(i + d, 0, LEAVES.size() - 1)]["key"]))

func _show_tab(key: String) -> void:
	_tab = key
	var leaf := _leaf(key)
	for k in _tab_btns:
		var on: bool = k == key
		(_tab_btns[k] as Button).add_theme_color_override("font_color", GOLD if on else DIM)
		(_tab_btns[k] as Button).add_theme_color_override("font_hover_color", GOLD if on else PARCH)
	_sel = 0
	_rebuild_list()
	var footer := String(leaf.get("footer", ""))
	# a leaf with no footer reads on down to the hint line
	_scroll.size.y = 512.0 if footer != "" else 640.0
	if _frule != null: _frule.visible = footer != ""
	for s in _slots:
		(s["panel"] as Control).visible = (footer == "hand")
	_attune_slot.visible = (footer == "attune")
	if _belt_lbl != null: _belt_lbl.visible = (footer == "hand")
	if _attune_lbl != null: _attune_lbl.visible = (footer == "attune")
	_show_armour_rail(footer == "armour")
	_hint.text = String(leaf.get("hint", "Tab  close"))

# ------------------------------------------------------------------ list

func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	var fill := String(_leaf(_tab).get("fill", ""))
	if fill.begins_with("res://"):
		load(fill).fill(self)
	elif fill != "" and has_method(fill):
		call(fill)
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
		"×%d / %d" % [player.gourds, player.gourd_max], DB.item("gourd").get("desc", ""))
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
		_relic_row(_icon_for(id), it.get("name", String(id).capitalize()), "×%d" % n,
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
		_note("    No songs yet. Somebody in the steading will know one.")

# ------------------------------------------------------------------ rows

## A selectable, draggable row (arm / gourd / song). Click acts on it; drag
## carries {id, kind} to a hand-slot or the attune slot.
func _row(id: String, kind: String, icon_path: String, nm: String, tag: String, desc: String) -> void:
	var idx := _rows.size()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box("row"))
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
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
	head.label_settings = _ls(24, PARCH, "medium")
	head.text = nm + ("      " + tag if tag != "" else "")
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var body := Label.new()
	body.label_settings = _ls(19, DIM)
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
	pc.add_theme_stylebox_override("panel", UITheme.box("row"))
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
	head.label_settings = _ls(24, PARCH, "medium")
	head.text = nm + ("      " + tag if tag != "" else "")
	col.add_child(head)
	var body := Label.new()
	body.label_settings = _ls(19, DIM)
	body.text = desc
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(820, 0)
	col.add_child(body)

func _section(text: String) -> void:
	var l := Label.new()
	l.label_settings = _ls(22, UITheme.EMBER, "caps")
	l.text = text.capitalize() if text == text.to_upper() else text
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
		pnl.add_theme_stylebox_override("panel", UITheme.box("slot"))
		pnl.position = Vector2(44 + i * 72, 634); pnl.size = Vector2(60, 60)
		pnl.set_drag_forwarding(Callable(), _can_drop_hand, _drop_hand.bind(i))
		pnl.gui_input.connect(_on_hand_input.bind(i))
		panel.add_child(pnl)
		var num := Label.new()
		num.label_settings = _ls(15, DIM)
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
	lbl.label_settings = _ls(19, DIM, "italic")
	lbl.text = "the belt"
	lbl.position = Vector2(422, 650)
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
	_attune_slot.add_theme_stylebox_override("panel", UITheme.box("slot_sel"))
	_attune_slot.position = Vector2(44, 634); _attune_slot.size = Vector2(60, 60)
	_attune_slot.set_drag_forwarding(Callable(), _can_drop_attune, _drop_attune)
	panel.add_child(_attune_slot)
	var c := Label.new()
	c.label_settings = _ls(24, GOLD, "medium")
	c.text = "X"; c.position = Vector2(22, 12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attune_slot.add_child(c)
	var lbl := Label.new()
	lbl.label_settings = _ls(19, DIM, "italic")
	lbl.text = "the song on your tongue: drop a song here, or click it"
	lbl.position = Vector2(118, 650)
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
		var st := UITheme.box("slot")
		pnl.add_theme_stylebox_override("panel", st)
		pnl.set_meta("box", st)
		pnl.position = Vector2(44 + i * 140, 628); pnl.size = Vector2(132, 70)
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
		key.label_settings = _ls(15, DIM)
		key.position = Vector2(52, 6); key.text = "%d  %s" % [i + 1, slot.capitalize()]
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_child(key)
		var nm := Label.new()
		nm.label_settings = _ls(14, PARCH)
		nm.position = Vector2(52, 26); nm.size = Vector2(74, 44)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_child(nm)
		_armour_slots.append({"slot": slot, "panel": pnl, "icon": icon, "name": nm})
	_armour_lbl = Label.new()
	_armour_lbl.label_settings = _ls(17, DIM, "italic")
	_armour_lbl.position = Vector2(44 + slots.size() * 140 + 10, 632)
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
		st.border_color = UITheme.EMBER_HOT if id != "" else UITheme.box("slot").border_color
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
	prev.add_theme_stylebox_override("panel", UITheme.box("slot_sel"))
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
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel") \
			or (event.is_action_pressed("keepsakes") and _tab == "keepsakes"):
		close(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("keepsakes"):
		_show_tab("keepsakes"); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("move_left"):
		_leaf_step(-1); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("move_right"):
		_leaf_step(1); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("move_forward"):
		_sel = maxi(_sel - 1, 0); _mark_selected(); _scroll.scroll_vertical -= 56; return
	if event.is_action_pressed("move_back"):
		_sel = clampi(_sel + 1, 0, maxi(_rows.size() - 1, 0)); _mark_selected(); _scroll.scroll_vertical += 56; return
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
		var look := UITheme.box("row_sel" if i == _sel else "row")
		(_rows[i]["panel"] as PanelContainer).add_theme_stylebox_override("panel", look)
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
		"item_rye_sack": "rye_sack", "item_net_float": "net_float",
		"item_mending_needle": "needle", "ks_child_mask": "mask",
		"fostering_horn": "crest",
		"armour_traveller_coat": "armour_coat", "armour_saltfell_oilskins": "armour_oilskins",
		# the Lowe and Kettle Fjord
		"turf_spade": "turf_spade", "ice_auger": "ice_auger", "sealer_harpoon": "harpoon",
		"turf_song": "song", "armour_barrow_cloak": "armour_cloak", "armour_icefur": "armour_icefur",
		"item_tally_stick": "tally", "item_twin_spindles": "spindles", "item_orm_cord": "knot_cord",
		"item_halla_cord": "knot_cord", "item_hesk_tongs": "tongs", "ks_woad_thread": "woad_thread",
		"item_ivo_mitten": "mitten", "item_kettle_ladle": "ladle",
		# Tarnhall
		"feast_cleaver": "cleaver", "goat_song": "song", "item_host_cup": "host_cup",
		"item_guest_tally": "guest_tally", "item_ottar_staff": "stick", "item_barrel_head": "barrel_head",
		# Thornwold
		"hedging_bill": "bill", "item_song_cord": "song_cord", "item_birch_ring": "birch_ring",
		"item_knucklebone": "knucklebone", "armour_collier": "armour_collier",
		# Shepherd's Reach, the Coldwell, and the pieces on the way up
		"item_fold_tally": "fold_tally", "item_calder_boots": "boots", "item_shepherd_whistle": "whistle",
		"armour_fleece": "armour_fleece", "armour_hall": "armour_hall", "item_latch_wool": "latch_wool", "item_wren_band": "woad_band",
		"item_maren_mask": "bare_mask",
		# points of interest: Saltfell
		"item_thole_pin": "thole_pin", "item_pan_salt": "pan_salt", "item_three_bowls": "three_bowls",
		# points of interest: the Lowe
		"item_birch_cup": "birch_cup", "item_spade_iron": "spade_iron", "item_small_spades": "small_spades",
		# points of interest: Shepherd's Reach
		"item_calder_blanket": "blanket",
	}
	return "res://assets/ui/icons/%s.png" % by.get(id, "relic")

func _ls(size: int, color: Color, weight := "regular") -> LabelSettings:
	return UITheme.ls(size, color, weight, false)

func close() -> void:
	if player != null and is_instance_valid(player):
		player.lock_control(false)
		player.suppress_interact(10)
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if player.look_compat else Input.MOUSE_MODE_CAPTURED
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -10.0)
	remove_from_group("inventory_ui")
	if player != null and is_instance_valid(player) and player.has_method("refresh_outfit"):
		player.refresh_outfit()   # the Pack is shut: he is wearing what was chosen
	queue_free()
