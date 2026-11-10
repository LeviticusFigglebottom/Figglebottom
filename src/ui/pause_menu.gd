extends CanvasLayer
## PauseUI — the Esc menu. Pauses the world (music keeps breathing), frees the
## cursor, and offers: return, settings (audio / mouse / view / graphics quality,
## persisted to user://settings.cfg), beginning the journey anew (a TRUE new
## game: the save is destroyed and the world rebuilt, not a respawn-in-place),
## and quit. Registered as an autoload; owns the Esc key. RestUI/dialogue keep
## their own input — the menu refuses to open over them.

const CFG_PATH := "user://settings.cfg"
const GOLD := UITheme.EMBER_HOT
const GOLD_DIM := UITheme.EMBER
const PARCHMENT := UITheme.BONE
const ASH := UITheme.ASH
const QUALITY_NAMES := ["Low", "High", "Ultra"]

var settings := {
	"master": 1.0, "music": 1.0, "sfx": 1.0, "ambience": 1.0,
	"sensitivity": 5.0,          # 1..10 -> cam.sensitivity = v * 0.0007
	"fov": 62.0,
	"fullscreen": false,
	"graphics_quality": -1,      # -1 = auto (High on software renderer, Ultra on GPU)
}

var _dim: ColorRect
var _panel: Panel
var _pages := {}                 # name -> VBoxContainer
var _first_button := {}          # name -> Control to focus
var _page := "main"

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	# music/ambience keep playing while the tree is paused
	AudioDirector.process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_audio()
	_apply_video()
	_apply_graphics()
	Game.player_registered.connect(func(_p): _apply_camera())
	_build()
	visible = false
	# shot-harness hook: photograph the menu itself
	if "--shot-menu" in OS.get_cmdline_user_args():
		var t := get_tree().create_timer(0.5, true, false, true)
		t.timeout.connect(open)

## Settings straight from the title screen: no game behind it, no pause,
## and both Return and Esc close the sheet instead of sliding to "main".
var _solo := false

func open_settings_solo() -> void:
	_solo = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page("settings")

func is_open() -> bool:
	return visible

func _can_open() -> bool:
	if visible or StateDirector.transitioning:
		return false
	if Game.player != null and Game.player.busy_in_menu():
		return false
	return Game.player != null

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		if _page == "main" or _solo:
			close()
		else:
			_show_page("main")
		get_viewport().set_input_as_handled()
	elif _can_open():
		open()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page("main")

func close() -> void:
	visible = false
	_solo = false
	get_tree().paused = false
	if Game.player != null and not Game.player.busy_in_menu():
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN \
				if (Game.player != null and Game.player.look_compat) \
				else Input.MOUSE_MODE_CAPTURED

## A true new game: destroy the save, forget the world, rebuild from the
## first light. `reload` is a seam for headless tests (reloading the current
## scene there would re-run the test forever).
func begin_anew(reload := true) -> void:
	Game.arena_locked = false
	World.reset()
	if FileAccess.file_exists(World.save_path()):
		DirAccess.remove_absolute(World.save_path())
	Game.set_warmth(0)
	Game.player = null
	Game.current_area = null
	Game.current_area_id = ""
	visible = false
	get_tree().paused = false
	if reload:
		# the dying scene may carry key-light rigs; dark first, then reload
		RH.quench_lights(get_tree().current_scene)
		await get_tree().process_frame
		get_tree().reload_current_scene()

## Keep the hearth and go back to the title (saved first; Resume finds it).
func return_to_title() -> void:
	visible = false
	_solo = false
	get_tree().paused = false
	if Game.world_root != null and Game.world_root.has_method("return_to_title"):
		Game.world_root.return_to_title()

# ------------------------------------------------------------------ UI build

func _ls(size: int, color: Color, weight := "regular") -> LabelSettings:
	return UITheme.ls(size, color, weight)

func _button(text: String, on_press := Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 50)
	UITheme.style_button(b, 26)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b

func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(UITheme.EMBER, 0.5)
	r.custom_minimum_size = Vector2(0, 1)
	return r

func _slider(label: String, minv: float, maxv: float, step: float, get_v: Callable,
			 set_v: Callable) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	var l := Label.new()
	l.label_settings = _ls(19, PARCHMENT)
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := Label.new()
	val.label_settings = _ls(19, GOLD_DIM)
	top.add_child(l)
	top.add_child(val)
	row.add_child(top)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = get_v.call()
	s.custom_minimum_size = Vector2(0, 22)
	val.text = _fmt(s.value, step)
	s.value_changed.connect(func(v):
		val.text = _fmt(v, step)
		set_v.call(v)
		_save_settings())
	row.add_child(s)
	return row

func _fmt(v: float, step: float) -> String:
	return ("%d" % int(v)) if step >= 1.0 else ("%d%%" % int(round(v * 100)))

func _quality_label() -> String:
	var q := EnvRig.get_graphics_quality()
	return QUALITY_NAMES[clampi(q, 0, 2)]

func _build() -> void:
	var root := Control.new()
	root.theme = UITheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	_dim = ColorRect.new()
	_dim.color = Color(UITheme.COAL, 0.66)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_dim)

	_panel = Panel.new()
	var sb := UITheme.box("panel")
	sb.border_color = Color(0, 0, 0, 0)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -290
	_panel.offset_right = 290
	root.add_child(_panel)

	var title := Label.new()
	title.label_settings = _ls(48, GOLD, "caps")
	title.text = "Rimeholt"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 30)
	title.size = Vector2(580, 54)
	_panel.add_child(title)
	var sub := Label.new()
	sub.label_settings = _ls(21, UITheme.BONE_DIM, "italic")
	sub.text = "the hearth is held"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 88)
	sub.size = Vector2(580, 26)
	_panel.add_child(sub)
	var rule := _rule()
	rule.position = Vector2(48, 128)
	rule.size = Vector2(484, 1)
	_panel.add_child(rule)

	# ---- main page
	var main := _page_box()
	main.add_child(_button("Return to the World", close))
	main.add_child(_button("Settings", func(): _show_page("settings")))
	main.add_child(_button("Return to the Title", return_to_title))
	main.add_child(_button("Begin the Journey Anew", func(): _show_page("confirm")))
	main.add_child(_button("Leave the Highland", func(): get_tree().quit()))
	_pages["main"] = main
	_first_button["main"] = main.get_child(0)

	# ---- settings page
	var st := _page_box()
	st.add_child(_slider("Master volume", 0.0, 1.0, 0.05,
		func(): return settings["master"],
		func(v): settings["master"] = v; _apply_audio()))
	st.add_child(_slider("Music", 0.0, 1.0, 0.05,
		func(): return settings["music"],
		func(v): settings["music"] = v; _apply_audio()))
	st.add_child(_slider("Effects", 0.0, 1.0, 0.05,
		func(): return settings["sfx"],
		func(v): settings["sfx"] = v; _apply_audio()))
	st.add_child(_slider("Ambience", 0.0, 1.0, 0.05,
		func(): return settings["ambience"],
		func(v): settings["ambience"] = v; _apply_audio()))
	st.add_child(_slider("Mouse sensitivity", 1.0, 10.0, 1.0,
		func(): return settings["sensitivity"],
		func(v): settings["sensitivity"] = v; _apply_camera()))
	st.add_child(_slider("Field of view", 55.0, 85.0, 1.0,
		func(): return settings["fov"],
		func(v): settings["fov"] = v; _apply_camera()))
	var gq := _button("Graphics Quality: %s" % _quality_label())
	gq.pressed.connect(func():
		var cur := EnvRig.get_graphics_quality()
		var nxt := (cur + 1) % 3
		settings["graphics_quality"] = nxt
		_apply_graphics()
		_save_settings()
		gq.text = "Graphics Quality: %s" % _quality_label())
	st.add_child(gq)
	var fs := _button("Fullscreen: —")
	fs.pressed.connect(func():
		settings["fullscreen"] = not settings["fullscreen"]
		_apply_video()
		_save_settings()
		fs.text = "Fullscreen: %s" % ("on" if settings["fullscreen"] else "off"))
	fs.text = "Fullscreen: %s" % ("on" if settings["fullscreen"] else "off")
	st.add_child(fs)
	st.add_child(_button("Return", func(): close() if _solo else _show_page("main")))
	_pages["settings"] = st
	_first_button["settings"] = gq

	# ---- begin-anew confirmation
	var cf := _page_box()
	var warn := Label.new()
	warn.label_settings = _ls(21, PARCHMENT)
	warn.text = "The steading will forget everything —\nevery hearth kept, every warmth gathered,\nevery door opened. The journey\nbegins again from the first light."
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.custom_minimum_size = Vector2(0, 150)
	cf.add_child(warn)
	cf.add_child(_button("Begin Anew — forget it all", begin_anew))
	cf.add_child(_button("Not yet", func(): _show_page("main")))
	_pages["confirm"] = cf
	_first_button["confirm"] = cf.get_child(2)

	for p in _pages.values():
		_panel.add_child(p)
	_panel.add_child(KnotFrame.new())

func _page_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = Vector2(48, 150)
	box.size = Vector2(484, 680)
	box.add_theme_constant_override("separation", 11)
	box.visible = false
	return box

func _show_page(name_: String) -> void:
	_page = name_
	for k in _pages:
		_pages[k].visible = (k == name_)
	var h: float = 150.0 + _pages[name_].get_combined_minimum_size().y + 42.0
	_panel.offset_top = -h * 0.5
	_panel.offset_bottom = h * 0.5
	var fb: Control = _first_button.get(name_)
	if fb != null:
		fb.grab_focus()

# ------------------------------------------------------------- apply / persist

func _bus(name_: String) -> int:
	return AudioServer.get_bus_index(name_)

func _apply_audio() -> void:
	for pair in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"], ["Ambience", "ambience"]]:
		var i := _bus(pair[0])
		if i < 0:
			continue
		var v: float = settings[pair[1]]
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))
		AudioServer.set_bus_mute(i, v <= 0.001)

func _apply_camera() -> void:
	if Game.player == null or not is_instance_valid(Game.player):
		return
	var cam = Game.player.cam
	if cam == null:
		return
	cam.set_sensitivity(settings["sensitivity"] * 0.0007)
	cam.set_base_fov(settings["fov"])

func _apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"]
		else DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_graphics() -> void:
	var gq := int(settings.get("graphics_quality", -1))
	if gq >= 0:
		EnvRig.set_graphics_quality(gq)
		if Game.current_area != null and is_instance_valid(Game.current_area):
			var er := Game.current_area.find_child("EnvRig", true, false) as EnvRig
			if er != null:
				er.apply_quality_tier()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(CFG_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	settings["sensitivity"] = clampf(float(settings["sensitivity"]), 1.0, 10.0)
	settings["fov"] = clampf(float(settings.get("fov", 75.0)), 50.0, 110.0)
	settings["graphics_quality"] = clampi(int(settings.get("graphics_quality", -1)), -1, 2)
