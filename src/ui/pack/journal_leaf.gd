extends RefCounted
## The Journal leaf of the Pack (J opens it): the quest log. The journey
## itself first ("The Outsong"), then every thread in hand, each with its
## current objective in plain words and the steps done so far beneath it,
## then the finished threads folded under "Done". Enter or a click on a
## thread pins it: the pinned objective is the one the HUD and the Map show.
## The first row switches the HUD line on and off.

static func fill(ui: InventoryUI) -> void:
	var v := Journal.view()
	var open: Dictionary = ui.get_meta("journal_open", {})
	_tracker_row(ui)
	_thread(ui, v["main"], true)
	if not (v["active"] as Array).is_empty():
		ui._section("In hand")
		for t in v["active"]:
			_thread(ui, t, true)
	if not (v["done"] as Array).is_empty():
		ui._section("Done")
		for t in v["done"]:
			_thread(ui, t, bool(open.get(t["id"], false)))
	elif (v["active"] as Array).is_empty():
		ui._note("    No other threads yet. People in THAW will have things to ask.")

## Enter or a click on a row: the tracker switch, a pin, or a fold.
static func act(ui: InventoryUI, row: Dictionary) -> void:
	match String(row["kind"]):
		"tracker":
			Journal.set_tracker(not Journal.tracker_on())
		"thread":
			Journal.set_pin(Journal.MAIN_ID if Journal.pin_id() == row["id"] else String(row["id"]))
		"done":
			var open: Dictionary = ui.get_meta("journal_open", {})
			open[row["id"]] = not bool(open.get(row["id"], false))
			ui.set_meta("journal_open", open)
	AudioDirector.play("ui/move")
	var keep := ui._sel
	ui._rebuild_list()
	ui._sel = keep

static func _panel(ui: InventoryUI, id: String, kind: String) -> VBoxContainer:
	var idx := ui._rows.size()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.box("row"))
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.gui_input.connect(ui._on_row_input.bind(idx))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(col)
	ui._list.add_child(pc)
	ui._rows.append({"id": id, "kind": kind, "panel": pc, "head": null})
	return col

static func _label(text: String, px: int, col: Color, weight := "regular") -> Label:
	var l := Label.new()
	l.label_settings = UITheme.ls(px, col, weight, false)
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(880, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _tracker_row(ui: InventoryUI) -> void:
	var col := _panel(ui, "tracker", "tracker")
	var on := Journal.tracker_on()
	var head := _label("Pinned objective on the HUD:  %s" % ("shown" if on else "hidden"), 20, UITheme.BONE, "medium")
	col.add_child(head)
	ui._rows[ui._rows.size() - 1]["head"] = head

static func _thread(ui: InventoryUI, t: Dictionary, open: bool) -> void:
	var complete: bool = t["complete"]
	var col := _panel(ui, String(t["id"]), "done" if complete else "thread")
	var pinned: bool = not complete and Journal.pinned().get("id", "") == t["id"]
	var title := String(t["title"])
	if complete:
		title += "      %d step%s" % [(t["done"] as Array).size(), "" if (t["done"] as Array).size() == 1 else "s"]
	elif pinned:
		title += "      ◆ pinned"
	var head := _label(title, 22 if complete else 27, UITheme.BONE, "caps")
	col.add_child(head)
	ui._rows[ui._rows.size() - 1]["head"] = head
	if not open:
		return
	if not complete and String(t["objective"]) != "":
		col.add_child(_label("Current objective", 16, UITheme.EMBER, "caps"))
		col.add_child(_label(String(t["objective"]), 22, UITheme.BONE))
		for x in t["extras"]:
			col.add_child(_label("Also:  " + String(x), 19, UITheme.BONE_DIM))
		var place := Journal.resolve_at(String(t["step"].get("area", t["area"])), t["step"].get("at", null)) != null
		var region := String(MapState.region(String(t["area"])).get("name", ""))
		if region != "":
			col.add_child(_label("%s%s" % [region, "   ·   marked on the Map while pinned" if place else ""], 16, UITheme.ASH, "italic"))
	if not (t["done"] as Array).is_empty():
		if not complete:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 2)
			col.add_child(gap)
		for line in t["done"]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tick := Label.new()
			tick.label_settings = UITheme.ls(18, UITheme.EMBER_DEEP.lightened(0.25), "regular", false)
			tick.text = "—"
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tick)
			var l := _label(String(line), 18, UITheme.BONE_DIM)
			l.custom_minimum_size = Vector2(840, 0)
			row.add_child(l)
			col.add_child(row)
