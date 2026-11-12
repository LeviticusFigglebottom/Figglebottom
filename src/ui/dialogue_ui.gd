class_name DialogueUI
extends CanvasLayer
## Minimal soulslike dialogue: name plate, line-by-line advance, then
## service options. Keyboard/gamepad driven; sim-drivable via advance()/choose().

signal closed

var npc_cfg: Dictionary
var npc_node: Node3D
var _lines: Array = []
var _line_i := 0
var _options: Array = []
var _opt_i := 0
var _phase := "lines"   # lines -> options

var text_label: Label
var name_label: Label
var options_box: VBoxContainer
var panel: Panel
var _next_glyph: Label = null

signal line_sounded(path: String)

func _init(cfg: Dictionary, node: Node3D) -> void:
	npc_cfg = cfg
	npc_node = node

func _ready() -> void:
	layer = 20
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	root.theme = UITheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# a low shade so the words sit on the scene, not on a box floating in it
	var shade := TextureRect.new()
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	sg.colors = PackedColorArray([Color(UITheme.COAL, 0.0), Color(UITheme.COAL, 0.55), Color(UITheme.COAL, 0.82)])
	var sgt := GradientTexture2D.new()
	sgt.gradient = sg
	sgt.fill_from = Vector2(0.5, 0.0)
	sgt.fill_to = Vector2(0.5, 1.0)
	sgt.width = 4
	sgt.height = 64
	shade.texture = sgt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.58
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	panel = Panel.new()
	var sb := UITheme.box("panel")
	sb.border_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -620
	panel.offset_right = 620
	panel.offset_top = -360
	panel.offset_bottom = -106
	root.add_child(panel)
	name_label = Label.new()
	name_label.label_settings = UITheme.ls(30, UITheme.EMBER_HOT, "caps")
	name_label.position = Vector2(48, 22)
	panel.add_child(name_label)
	var nrule := UITheme.rule(1144, 0.55)
	nrule.position = Vector2(48, 66)
	panel.add_child(nrule)
	text_label = Label.new()
	text_label.label_settings = UITheme.ls(28, UITheme.BONE)
	text_label.label_settings.line_spacing = 4
	text_label.position = Vector2(48, 82)
	text_label.size = Vector2(1144, 120)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(text_label)
	_next_glyph = Label.new()
	_next_glyph.label_settings = UITheme.ls(19, UITheme.ASH, "italic")
	_next_glyph.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_next_glyph.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_next_glyph.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_next_glyph.offset_left = -260
	_next_glyph.offset_right = -48
	_next_glyph.offset_top = -50
	_next_glyph.offset_bottom = -22
	_next_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_glyph.text = "E   continue"
	panel.add_child(_next_glyph)
	options_box = VBoxContainer.new()
	options_box.position = Vector2(48, 80)
	options_box.size = Vector2(1144, 160)
	options_box.add_theme_constant_override("separation", 2)
	panel.add_child(options_box)
	panel.add_child(KnotFrame.new())

	name_label.text = npc_cfg.get("name", "???")
	var nid: String = npc_cfg.get("id", "npc")
	var first := not World.flag("met_" + nid)
	World.set_flag("met_" + nid)
	if first:
		for f in npc_cfg.get("first_flags", []):
			World.set_flag(String(f))
	_run_exchanges()
	# chaptered speakers tell their tale one audience at a time; when the last
	# chapter has been told they may leave a parting gift, then fall to repeats
	var chapters: Array = npc_cfg.get("chapters", [])
	if chapters.size() > 0:
		var ci := int(World.flag_val("chapter_" + nid, 0))
		# a chapter the story has passed is not told ("chapter_absent_flags":
		# one flag per chapter, "" for none): met only after the release,
		# Calder opened on his lass calling the flock in and getting it
		# wrong, with the wall done and her beside him saying forty-four
		var gone: Array = npc_cfg.get("chapter_absent_flags", [])
		while ci < chapters.size() and ci < gone.size() and String(gone[ci]) != "" and World.flag(String(gone[ci])):
			ci += 1
			World.set_flag("chapter_" + nid, ci)
		var closing := _closing_lines()
		if not closing.is_empty():
			# an errand closed in this very talk is answered before the tale
			# goes on: a Bearer who rested before he met Calder shows him his
			# boots first, and the journal said so while Calder said nothing
			_lines = closing
		elif ci < chapters.size():
			_lines = chapters[ci]
			World.set_flag("chapter_" + nid, ci + 1)
			# a chapter may be a Keepsakes step ("chapter_flags": [[..], [..]])
			var cf: Array = npc_cfg.get("chapter_flags", [])
			if ci < cf.size():
				for f in cf[ci]:
					World.set_flag(String(f))
			if ci == chapters.size() - 1:
				_grant_gift(npc_cfg.get("gift", {}))
		else:
			_lines = _repeat_lines()
	else:
		_lines = npc_cfg.get("lines_first", []) if first else _repeat_lines()
	_show_line()

## Repeat lines follow the story: the first "lines_when" entry whose flag is
## set wins (it may raise a flag of its own, a Keepsakes step), else the
## plain repeats.
func _repeat_lines() -> Array:
	# an errand closed in this very talk is answered first: arriving with the
	# rye after the release must still hear about the dog (the release's own
	# lines, and their Keepsakes step, wait for the next talk)
	var closing := _closing_lines()
	if not closing.is_empty():
		return closing
	for w in npc_cfg.get("lines_when", []):
		if World.flag(String(w.get("flag", ""))):
			if String(w.get("set_flag", "")) != "":
				World.set_flag(String(w["set_flag"]))
			return w.get("lines", [])
	return npc_cfg.get("lines_repeat", [])

## The "lines_when" lines of an errand closed in this talk, or none.
func _closing_lines() -> Array:
	for w in npc_cfg.get("lines_when", []):
		if _closed_now.has(String(w.get("flag", ""))):
			return w.get("lines", [])
	return []

## Things handed over just by talking (SLICE.md: "talk to Ingra carrying the
## sack"): no menu entry, the errand closes when you arrive with it.
var _closed_now: Array = []

func _run_exchanges() -> void:
	var p = Game.player
	for ex in npc_cfg.get("on_talk", []):
		if ex.has("require_flag") and not World.flag(String(ex["require_flag"])):
			continue
		if ex.has("absent_flag") and World.flag(String(ex["absent_flag"])):
			continue
		var need := String(ex.get("needs_item", ""))
		if need != "" and (p == null or int(p.inventory.get(need, 0)) < 1):
			continue
		if need != "" and bool(ex.get("take_item", false)):
			p.inventory[need] = int(p.inventory[need]) - 1
			if int(p.inventory[need]) <= 0:
				p.inventory.erase(need)
		if ex.has("reward_item") and p != null:
			p.give_item(String(ex["reward_item"]), int(ex.get("reward_count", 1)))
		if ex.has("reward_warmth"):
			Game.add_warmth(int(ex["reward_warmth"]))
		if p != null:
			p.inventory_changed.emit()
		if String(ex.get("set_flag", "")) != "":
			World.set_flag(String(ex["set_flag"]))
			_closed_now.append(String(ex["set_flag"]))
		if String(ex.get("toast", "")) != "":
			Game.toast.emit(String(ex["toast"]))
		World.save_game()

## One-time parting gift once a chaptered tale is exhausted.
func _grant_gift(g: Dictionary) -> void:
	if g.is_empty() or Game.player == null:
		return
	var flag: String = g.get("flag", "gift_" + npc_cfg.get("id", "npc"))
	if World.flag(flag):
		return
	World.set_flag(flag)
	var item: String = g.get("item", "bog_iron")
	var count := int(g.get("count", 1))
	Game.player.give_item(item, count)
	var iname: String = DB.weapon(item).get("name",
		DB.song(item).get("name", DB.item(item).get("name", item)))
	Game.toast.emit(g.get("toast", "Received %s x%d" % [iname, count]))
	AudioDirector.play("world/pickup")

func _show_line() -> void:
	options_box.visible = false
	text_label.visible = true
	if _next_glyph != null:
		_next_glyph.visible = true
	if _line_i < _lines.size():
		text_label.text = String(_lines[_line_i])
		_speak(String(_lines[_line_i]))
		# a line may carry a sound of its own ("line_sfx": {line: [path, db,
		# pitch]}): Old Calder humming three notes (REACH.md 7)
		var ls: Dictionary = npc_cfg.get("line_sfx", {})
		if ls.has(text_label.text):
			var e: Array = ls[text_label.text]
			AudioDirector.sfx(String(e[0]), float(e[1]) if e.size() > 1 else 0.0, float(e[2]) if e.size() > 2 else 1.0)
			line_sounded.emit(String(e[0]))
	else:
		_stop_voice()
		_enter_options()

# ---------------------------------------------------------------- voice
## Every soul speaks: each dialog line has a recorded reading keyed by the
## line's own hash (assets/audio/voice/<npc>/<sha1:12>.mp3). Advancing a
## line cuts the old reading; closing the panel silences it with the UI.
var _voice: AudioStreamPlayer = null

func _speak(line: String) -> void:
	_stop_voice()
	var path := "res://assets/audio/voice/%s/%s.mp3" % [npc_cfg.get("id", ""), line.sha1_text().substr(0, 12)]
	if not ResourceLoader.exists(path):
		return
	_voice = AudioStreamPlayer.new()
	_voice.stream = load(path)
	_voice.bus = "SFX"
	_voice.volume_db = 1.0
	add_child(_voice)
	_voice.play()

func _stop_voice() -> void:
	if _voice != null and is_instance_valid(_voice):
		_voice.stop()
		_voice.queue_free()
	_voice = null

func _enter_options() -> void:
	_phase = "options"
	_options = []
	for o in npc_cfg.get("services", []):
		# a once-bought service (a learned song, the one deep gourd) is
		# done: it leaves the menu instead of tempting a second purchase
		if o.has("once_flag") and World.flag(String(o["once_flag"])):
			continue
		# story-gated services: an errand not yet given, a parcel not carried
		if o.has("require_flag") and not World.flag(String(o["require_flag"])):
			continue
		if o.has("absent_flag") and World.flag(String(o["absent_flag"])):
			continue
		if o.has("needs_item") and Game.player != null \
				and int(Game.player.inventory.get(String(o["needs_item"]), 0)) < 1:
			continue
		# a stock that runs out (three lumps of bog-iron, and no more)
		if o.has("limit") and int(World.flag_val("bought_" + String(o.get("id", "")), 0)) >= int(o["limit"]):
			continue
		_options.append(o)
	_options.append({"id": "leave", "label": "Leave"})
	text_label.visible = false
	if _next_glyph != null:
		_next_glyph.visible = false
	options_box.visible = true
	_opt_i = 0
	# a long stock list must not spill past the panel: grow the panel upward
	# so every option (and Leave) stays inside the frame
	var over := maxi(0, _options.size() - 5)
	panel.offset_top = -360 - over * 40
	_render_options()

func _render_options() -> void:
	for c in options_box.get_children():
		c.queue_free()
	for i in _options.size():
		var o: Dictionary = _options[i]
		var l := Label.new()
		var selected := i == _opt_i
		l.label_settings = UITheme.ls(26, UITheme.EMBER_HOT if selected else UITheme.BONE_DIM)
		l.text = ("◆   " if selected else "     ") + _option_label(o)
		l.custom_minimum_size = Vector2(0, 38)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx := i
		l.mouse_entered.connect(func():
			if _opt_i != idx:
				_opt_i = idx
				_render_options())
		l.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				choose(idx)
				get_viewport().set_input_as_handled())
		options_box.add_child(l)

## The label is the data's, word for word; a price is set beside it.
func _option_label(o: Dictionary) -> String:
	var t: String = o.get("label", o.get("id", "?"))
	if o.has("warmth") and int(o["warmth"]) > 0:
		t += "   ·   %d warmth" % int(o["warmth"])
	return t

func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack_light"):
		advance()
		get_viewport().set_input_as_handled()
	elif _phase == "options" and event.is_action_pressed("move_forward"):
		_opt_i = max(0, _opt_i - 1)
		_render_options()
	elif _phase == "options" and event.is_action_pressed("move_back"):
		_opt_i = min(_options.size() - 1, _opt_i + 1)
		_render_options()

## advance current line, or activate the selected option
func advance() -> void:
	if _phase == "lines":
		_line_i += 1
		_show_line()
	else:
		_activate(_options[_opt_i])

func choose(idx: int) -> void:
	if _phase != "options":
		while _phase == "lines":
			advance()
	_opt_i = clampi(idx, 0, _options.size() - 1)
	_activate(_options[_opt_i])

func _activate(o: Dictionary) -> void:
	var p = Game.player
	match o.get("type", o.get("id", "")):
		"leave":
			close()
		"upgrade":
			var cost := int(o.get("warmth", 150))
			var have_glass := int(p.inventory.get("bog_iron", 0))
			if p.weapon_level >= 5:
				text_label.text = o.get("line_max", "The blade holds all the iron it can carry.")
				_flash_line()
			elif have_glass < 1:
				text_label.text = o.get("line_no_glass",
					"Bring me bog-iron from the rime, Bearer. The frost heaves it up out of the fen.")
				_flash_line()
			elif Game.warmth < cost:
				text_label.text = String(o.get("line_no_warmth",
					"Warmth first. %d of it, or the deal stays cold.")) % cost
				_flash_line()
			else:
				p.inventory["bog_iron"] = have_glass - 1
				Game.add_warmth(-cost)
				p.weapon_level += 1
				Game.toast.emit("The edge takes the iron. %s +%d" % [p.weapon_data().get("name", "Weapon"), p.weapon_level])
				AudioDirector.sfx("res://assets/audio/levelup.wav", -4.0)
				text_label.text = o.get("line_done",
					"There. A better edge. Try not to die somewhere I can't retrieve it.")
				_flash_line()
		"gourd_up":
			var cost2 := int(o.get("warmth", 300))
			if World.flag(o.get("once_flag", "bought_deep_gourd")):
				text_label.text = "I had only the one gourd to spare."
				_flash_line()
			elif Game.warmth < cost2:
				text_label.text = "That's %d warmth. Come back when you've got it." % cost2
				_flash_line()
			else:
				World.set_flag(o.get("once_flag", "bought_deep_gourd"))
				Game.add_warmth(-cost2)
				var fitem: String = o.get("item", "deep_gourd")
				if fitem != "" and int(p.inventory.get(fitem, 0)) < 1:
					p.give_item(fitem, 1)
				p.gourd_max += 1
				p.gourds = p.gourd_max
				p.gourds_changed.emit(p.gourds, p.gourd_max)
				Game.toast.emit("Gourd deepened (+1 draught).")
				AudioDirector.sfx("res://assets/audio/levelup.wav", -4.0)
				text_label.text = o.get("line_done", "Drink it slow. It was brewed for a longer winter than this.")
				_flash_line()
		"buy":
			var item: String = o.get("item", "")
			var qty := int(o.get("count", 1))
			var price := int(o.get("warmth", 100))
			var is_arm := not DB.weapon(item).is_empty()
			var is_song := not DB.song(item).is_empty()
			if o.has("once_flag") and World.flag(String(o["once_flag"])):
				text_label.text = o.get("line_have", "That is already yours.")
				_flash_line()
			elif (is_arm or is_song) and int(p.inventory.get(item, 0)) > 0:
				text_label.text = o.get("line_have", "You carry that already.")
				_flash_line()
			elif Game.warmth < price:
				text_label.text = "That's %d warmth. Come back when you've got it." % price
				_flash_line()
			else:
				Game.add_warmth(-price)
				p.give_item(item, qty)
				if o.has("once_flag"):
					World.set_flag(String(o["once_flag"]))
				if o.has("limit"):
					var bk := "bought_" + String(o.get("id", ""))
					World.set_flag(bk, int(World.flag_val(bk, 0)) + 1)
				var iname: String = DB.weapon(item).get("name",
					DB.song(item).get("name", DB.item(item).get("name", item)))
				Game.toast.emit("Received %s%s." % [iname, (" x%d" % qty) if qty > 1 else ""])
				AudioDirector.sfx("res://assets/audio/levelup.wav", -6.0)
				text_label.text = o.get("line_done", "Sold. Spend it on staying alive.")
				_flash_line()
		"gift":
			# freely given, once: Brede's spare oilskins
			var gitem: String = o.get("item", "")
			var gflag: String = o.get("once_flag", "gift_" + String(o.get("id", "")))
			if World.flag(gflag):
				text_label.text = o.get("line_have", "That's yours already.")
			else:
				World.set_flag(gflag)
				p.give_item(gitem, int(o.get("count", 1)))
				Game.toast.emit("Received: %s" % DB.item(gitem).get("name", gitem))
				AudioDirector.play("ui/confirm")
				World.save_game()
				text_label.text = o.get("line_done", "")
			_flash_line()
		"level_up":
			# "Sit by the fire": the levelling sheet, and the speaker says nothing
			close()
			if p != null:
				p.lock_control(true)
				get_tree().root.add_child(RestUI.new(null, p, "level", String(o.get("label", ""))))
			return
		"song":
			# holdfast songs carry their own law — the node that opened this
			# dialogue judges the attempt and hands back the line to speak.
			# a song that begins a FIGHT closes the audience on the spot.
			if npc_node != null and npc_node.has_method("_song"):
				var said := String(npc_node._song(o))
				if o.get("close", false):
					Game.toast.emit(said)
					close()
					return
				text_label.text = said
			else:
				text_label.text = "..."
			_flash_line()
		"deliver":
			var ditem: String = o.get("item", "")
			var dflag: String = o.get("flag", "delivered")
			if World.flag(dflag):
				text_label.text = o.get("line_have", "That kindness is already done.")
			elif int(p.inventory.get(ditem, 0)) < 1:
				text_label.text = o.get("line_missing", "You do not carry it.")
			else:
				p.inventory[ditem] = int(p.inventory[ditem]) - 1
				if bool(o.get("gourd_up", false)):
					p.gourd_max += 1
					p.gourds = p.gourd_max
					p.gourds_changed.emit(p.gourds, p.gourd_max)
				if o.has("reward_item"):
					p.give_item(String(o["reward_item"]), int(o.get("reward_count", 1)))
				if o.has("reward_warmth"):
					Game.add_warmth(int(o["reward_warmth"]))
				p.inventory_changed.emit()
				World.set_flag(dflag)
				World.save_game()
				Game.toast.emit(o.get("toast", "Delivered."))
				AudioDirector.sfx("res://assets/audio/swell_warm.wav", -6.0, 1.0)
				text_label.text = o.get("line_done", "It is received, and dearly.")
			_flash_line()
		"dig":
			var cost3 := int(o.get("warmth", 180))
			var fl: String = o.get("flag", "dug_shortcut")
			if World.flag(fl):
				text_label.text = "Dug is dug. Mind the tailings."
				_flash_line()
			elif Game.warmth < cost3:
				text_label.text = "Stone before sympathy: %d warmth buys the shovel's arc." % cost3
				_flash_line()
			else:
				Game.add_warmth(-cost3)
				World.set_flag(fl)
				World.save_game()
				Game.toast.emit("Somewhere below, rubble shifts.")
				AudioDirector.sfx("res://assets/audio/swell_warm.wav", -4.0)
				text_label.text = o.get("done_line", "There. A door where there was wall.")
				_flash_line()
		_:
			close()

func _flash_line() -> void:
	_phase = "lines"
	_lines = [text_label.text]
	_line_i = 0
	text_label.visible = true
	if _next_glyph != null:
		_next_glyph.visible = true
	options_box.visible = false

var _closing := false

func close() -> void:
	if _closing:
		return
	_closing = true
	if Game.player != null:
		Game.player.exit_dialogue()
		if not Game.player.sim_active:
			Game.player._grab_mouse(true)
	closed.emit()
	World.save_game()
	queue_free()
