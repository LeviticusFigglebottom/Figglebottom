extends RefCounted
## The Keepsakes leaf of the Pack: every thread the Bearer has started, its
## revealed lines in order, set like an item description. No markers, no
## objectives, nothing about what to do next (SPEC.md §1, pillar 4).

static func fill(ui: InventoryUI) -> void:
	var threads := Keepsakes.journal()
	if threads.is_empty():
		ui._note("    Nothing is remembered yet.")
		return
	for ti in threads.size():
		var t: Dictionary = threads[ti]
		if ti > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 14)
			ui._list.add_child(gap)
		var head := Label.new()
		head.label_settings = UITheme.ls(30, UITheme.EMBER_HOT, "caps", false)
		head.text = String(t["title"])
		ui._list.add_child(head)
		var rule := UITheme.rule(420, 0.45)
		ui._list.add_child(rule)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 22)
		pad.add_theme_constant_override("margin_top", 8)
		pad.add_child(col)
		ui._list.add_child(pad)
		for line in t["lines"]:
			var l := Label.new()
			l.label_settings = UITheme.ls(25, UITheme.BONE, "regular", false)
			l.text = String(line)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(860, 0)
			col.add_child(l)
