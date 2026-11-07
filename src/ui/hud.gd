class_name HUD
extends CanvasLayer
## The Bearer's HUD: covenant crest + vitals top-left, gourd bottom-left,
## warmth plaque bottom-right, interact prompt center, boss bar with trailing
## damage ghost bottom-center, death splash, diegetic toasts.

# font weights (UITheme.font): every label is set in the house serif
const SERIF := "regular"
const SERIF_B := "medium"

var hp_fill: ColorRect
var breath_panel: Control
var breath_fill: ColorRect
var hp_ghost: ColorRect
var st_fill: ColorRect
var hp_panel: Control
var st_panel: Control
var gourd_label: Label
var warmth_label: Label
var prompt_label: Label
var toast_label: Label
var splash: Control
var splash_label: Label
var vignette: ColorRect
var boss_root: Control
var boss_fill: ColorRect
var boss_name: Label

var _post_mat: ShaderMaterial = null
var _flash_strength := 0.0
var _hp_edge: ColorRect = null
var _st_edge: ColorRect = null
var _breath_edge: ColorRect = null
var _boss_ghost: ColorRect = null
var _boss_ghost_ratio := 1.0
var _prompt_plate: Panel = null
var _crest_icon: TextureRect = null
var _hp_ratio := 1.0
var _ghost_ratio := 1.0
var _st_ratio := 1.0
var _boss: Node = null

const HP_W := 420.0
const ST_W := 340.0
const BAR_X := 92.0

var lore_root: Control
var lore_text: Label
var _lore_panel: Panel
var _lore_hint: Label
var pose_label: Label

# the belt: five slots along the bottom edge (1-4 arms, 5 the gourd)
var hotbar_root: Control
var _slots: Array = []
var arrows_chip: Label
var song_panel: Panel
var song_icon: TextureRect
var song_cost: Label
const SLOT_ICON := {
	"hewing_blade": "res://assets/ui/icons/hewing_blade.png",
	"spear": "res://assets/ui/icons/spear.png",
	"bow": "res://assets/ui/icons/bow.png",
	"greatblade": "res://assets/ui/icons/greatblade.png",
	"maul": "res://assets/ui/icons/maul.png",
	"gourd": "res://assets/ui/icons/gourd.png",
	"torch": "res://assets/ui/icons/torch.png",
}

var _xhair: Control = null

## The archer's sight: a small gold ring-dot dead centre, shown only while
## the string is drawn or the eye is sighted.
func set_crosshair(on: bool) -> void:
	if _xhair == null:
		_xhair = Control.new()
		_xhair.set_anchors_preset(Control.PRESET_CENTER)
		_xhair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := ColorRect.new()
		dot.color = Color(UITheme.EMBER_HOT, 0.9)
		dot.size = Vector2(5, 5)
		dot.position = Vector2(-2.5, -2.5)
		dot.rotation = PI / 4
		_xhair.add_child(dot)
		for off in [Vector2(-11, -1), Vector2(7, -1), Vector2(-1, -11), Vector2(-1, 7)]:
			var tick := ColorRect.new()
			tick.color = Color(UITheme.EMBER_HOT, 0.55)
			tick.size = Vector2(4, 2) if abs(off.x) > abs(off.y) else Vector2(2, 4)
			tick.position = off
			_xhair.add_child(tick)
		add_child(_xhair)
	_xhair.visible = on

func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_build()
	Game.lore_panel.connect(show_lore)
	Game.warmth_changed.connect(_on_warmth)
	Game.player_stilled.connect(_on_forgotten)
	Game.player_respawned.connect(func(): _fade_splash(false))
	Game.breathmark_reclaimed.connect(func(n): show_toast("Breathmark reclaimed — %d warmth." % n))
	Game.toast.connect(show_toast)
	Game.area_title.connect(show_area_title)
	Game.title_card.connect(show_area_title)
	World.flag_raised.connect(_on_flag_raised)
	Juice.post_flash_requested.connect(_on_post_flash)
	StateDirector.transition_started.connect(_on_transition)
	if Game.player != null:
		_bind_player(Game.player)
	else:
		Game.player_registered.connect(_bind_player)

func _bind_player(p) -> void:
	if not p.health_changed.is_connected(_on_hp):
		p.health_changed.connect(_on_hp)
		p.stamina_changed.connect(_on_stamina)
		p.breath_changed.connect(_on_breath)
		p.gourds_changed.connect(_on_gourds)
		p.weapon_changed.connect(func(_id): _refresh_hotbar())
		p.inventory_changed.connect(_refresh_hotbar)
		p.attune_changed.connect(func(_id): _refresh_song())
		p.hotbar_changed.connect(_refresh_hotbar)
	_on_hp(p.hp, p.max_hp)
	_on_stamina(p.stamina, p.max_stamina)
	_on_breath(p.breath, p.max_breath)
	_on_gourds(p.gourds, p.gourd_max)
	_on_warmth(Game.warmth)
	_refresh_hotbar()

func _font(weight: String, size: int, color: Color, shadow := true) -> LabelSettings:
	return UITheme.ls(size, color, weight, shadow)

func _bar(parent: Control, y: float, w: float, h: float, back: Color) -> Array:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = back
	sb.border_color = Color(UITheme.BONE, 0.30)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 5
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(BAR_X, y)
	panel.size = Vector2(w, h)
	parent.add_child(panel)
	var ghost := ColorRect.new()
	ghost.color = Color(UITheme.EMBER_HOT, 0.62)
	ghost.position = Vector2(2, 2)
	ghost.size = Vector2(w - 4, h - 4)
	panel.add_child(ghost)
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = Vector2(w - 4, h - 4)
	panel.add_child(fill)
	var sheen := ColorRect.new()
	sheen.color = Color(UITheme.BONE, 0.14)
	sheen.position = Vector2(2, 2)
	sheen.size = Vector2(w - 4, maxf(2.0, (h - 4) * 0.35))
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sheen)
	var edge := ColorRect.new()
	edge.color = Color(UITheme.BONE, 0.85)
	edge.position = Vector2(w - 4, 2)
	edge.size = Vector2(2, h - 4)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(edge)
	return [panel, fill, ghost, edge]

func _build() -> void:
	var root := Control.new()
	root.theme = UITheme.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.5, 0.05, 0.05, 0.0)   # the post shader's hurt pulse
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psh := load("res://shaders/post_grade.gdshader") as Shader
	if psh != null:
		_post_mat = ShaderMaterial.new()
		_post_mat.shader = psh
		vignette.material = _post_mat
	root.add_child(vignette)

	# Hearth crest at top-left anchor beside the vitals bars
	var crest_path := "res://assets/ui/icons/crest.png"
	if ResourceLoader.exists(crest_path):
		_crest_icon = TextureRect.new()
		_crest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_crest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_crest_icon.texture = load(crest_path)
		_crest_icon.position = Vector2(18, 18)
		_crest_icon.size = Vector2(64, 64)
		_crest_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_crest_icon)

	var back := Color(UITheme.COAL, 0.86)
	var r1 := _bar(root, 30, HP_W, 14, back)
	hp_panel = r1[0]; hp_fill = r1[1]; hp_ghost = r1[2]; _hp_edge = r1[3]
	hp_fill.color = UITheme.BLOOD
	var r2 := _bar(root, 50, ST_W, 10, back)
	st_panel = r2[0]; st_fill = r2[1]; _st_edge = r2[3]
	st_fill.color = UITheme.WIND
	(r2[2] as ColorRect).color = Color(0, 0, 0, 0)
	# the breath-bar: breath, warmed only once a song is learned
	var r3 := _bar(root, 66, ST_W * 0.8, 8, back)
	breath_panel = r3[0]; breath_fill = r3[1]; _breath_edge = r3[3]
	breath_fill.color = UITheme.EMBER
	(r3[2] as ColorRect).color = Color(0, 0, 0, 0)
	breath_panel.visible = false

	# Bottom-left Gourd plaque backing
	var gourd_plate := Panel.new()
	var fsb := UITheme.box("plate")
	gourd_plate.add_theme_stylebox_override("panel", fsb)
	gourd_plate.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	gourd_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gourd_plate.offset_left = 20
	gourd_plate.offset_right = 198
	gourd_plate.offset_top = -94
	gourd_plate.offset_bottom = -48
	gourd_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gourd_plate)

	gourd_label = Label.new()
	gourd_label.label_settings = _font(SERIF_B, 27, UITheme.BONE)
	gourd_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	gourd_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gourd_label.offset_left = 32
	gourd_label.offset_top = -90
	gourd_label.offset_bottom = -50
	gourd_label.text = "Gourd  ×3"
	root.add_child(gourd_label)

	# Bottom-right Warmth plaque backing + soul-flame emblem
	var warmth_plate := Panel.new()
	var osb := UITheme.box("plate")
	warmth_plate.add_theme_stylebox_override("panel", osb)
	warmth_plate.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	warmth_plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	warmth_plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	warmth_plate.offset_left = -256
	warmth_plate.offset_right = -20
	warmth_plate.offset_top = -96
	warmth_plate.offset_bottom = -50
	warmth_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(warmth_plate)

	var warmth_icon_path := "res://assets/ui/icons/warmth.png"
	if ResourceLoader.exists(warmth_icon_path):
		var oi := TextureRect.new()
		oi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		oi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		oi.texture = load(warmth_icon_path)
		oi.position = Vector2(10, 8)
		oi.size = Vector2(30, 30)
		oi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		warmth_plate.add_child(oi)

	warmth_label = Label.new()
	warmth_label.label_settings = _font(SERIF_B, 27, UITheme.EMBER_HOT)
	warmth_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	warmth_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	warmth_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	warmth_label.offset_left = -300
	warmth_label.offset_top = -92
	warmth_label.offset_right = -32
	warmth_label.offset_bottom = -52
	warmth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	warmth_label.text = "0 warmth"

	# the surveyor's line: area, state and the live camera pose in exactly the
	# form tools/shot.sh --shot-cam takes, so any player screenshot can be
	# replayed 1:1 headlessly (dim, small, out of the composition's way)
	pose_label = Label.new()
	pose_label.label_settings = _font(SERIF, 14, Color(UITheme.ASH, 0.6))
	pose_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pose_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pose_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pose_label.offset_left = -560
	pose_label.offset_top = -34
	pose_label.offset_right = -10
	pose_label.offset_bottom = -10
	pose_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pose_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pose_label)
	root.add_child(warmth_label)

	# Interact prompt plate
	_prompt_plate = Panel.new()
	var psb := UITheme.box("plate")
	psb.bg_color = Color(UITheme.COAL, 0.84)
	_prompt_plate.add_theme_stylebox_override("panel", psb)
	_prompt_plate.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_plate.offset_left = -210
	_prompt_plate.offset_top = 96
	_prompt_plate.offset_right = 210
	_prompt_plate.offset_bottom = 142
	_prompt_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_plate.visible = false
	root.add_child(_prompt_plate)

	prompt_label = Label.new()
	prompt_label.label_settings = _font(SERIF, 26, UITheme.BONE)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.offset_left = -200
	prompt_label.offset_top = 100
	prompt_label.offset_right = 200
	prompt_label.offset_bottom = 140
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.text = ""
	root.add_child(prompt_label)

	toast_label = Label.new()
	toast_label.label_settings = _font("italic", 30, UITheme.BONE)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_left = -400
	toast_label.offset_top = 120
	toast_label.offset_right = 400
	toast_label.offset_bottom = 180
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	root.add_child(toast_label)

	_build_hotbar(root)

	# boss bar with ornate gold rule and trailing damage-ghost bar
	boss_root = Control.new()
	boss_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_root.visible = false
	root.add_child(boss_root)
	boss_name = Label.new()
	boss_name.label_settings = _font("caps", 34, UITheme.BONE)
	boss_name.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	boss_name.grow_vertical = Control.GROW_DIRECTION_BEGIN
	boss_name.offset_left = -400
	boss_name.offset_top = -178
	boss_name.offset_right = 400
	boss_name.offset_bottom = -138
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_root.add_child(boss_name)
	var brule := ColorRect.new()
	brule.color = Color(UITheme.EMBER, 0.6)
	brule.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	brule.grow_vertical = Control.GROW_DIRECTION_BEGIN
	brule.offset_left = -360
	brule.offset_right = 360
	brule.offset_top = -138
	brule.offset_bottom = -137
	boss_root.add_child(brule)
	var bp := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.COAL, 0.88)
	sb.border_color = Color(UITheme.BONE, 0.30)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.65)
	sb.shadow_size = 5
	bp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bp.offset_left = -500
	bp.offset_top = -132
	bp.offset_right = 500
	bp.offset_bottom = -116
	bp.add_theme_stylebox_override("panel", sb)
	boss_root.add_child(bp)
	_boss_ghost = ColorRect.new()
	_boss_ghost.color = Color(UITheme.EMBER_HOT, 0.62)
	_boss_ghost.position = Vector2(2, 2)
	_boss_ghost.size = Vector2(996, 12)
	bp.add_child(_boss_ghost)
	boss_fill = ColorRect.new()
	boss_fill.color = UITheme.BLOOD
	boss_fill.position = Vector2(2, 2)
	boss_fill.size = Vector2(996, 12)
	bp.add_child(boss_fill)
	var bsheen := ColorRect.new()
	bsheen.color = Color(UITheme.BONE, 0.12)
	bsheen.position = Vector2(2, 2)
	bsheen.size = Vector2(996, 4)
	bsheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp.add_child(bsheen)

	# lore panel (plaques, item descriptions)
	lore_root = Control.new()
	lore_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	lore_root.visible = false
	root.add_child(lore_root)
	var ldim := ColorRect.new()
	ldim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ldim.color = Color(UITheme.COAL, 0.66)
	lore_root.add_child(ldim)
	_lore_panel = Panel.new()
	var lsb := UITheme.box("panel")
	lsb.border_color = Color(0, 0, 0, 0)
	_lore_panel.add_theme_stylebox_override("panel", lsb)
	_lore_panel.position = Vector2(510, 330)
	_lore_panel.size = Vector2(900, 400)
	lore_root.add_child(_lore_panel)
	lore_text = Label.new()
	lore_text.label_settings = _font(SERIF, 28, UITheme.BONE, false)
	lore_text.position = Vector2(46, 46)
	lore_text.size = Vector2(808, 260)
	lore_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lore_panel.add_child(lore_text)
	_lore_hint = Label.new()
	_lore_hint.label_settings = _font("italic", 19, UITheme.ASH, false)
	_lore_hint.position = Vector2(46, 340)
	_lore_hint.text = "press any key"
	_lore_panel.add_child(_lore_hint)
	_lore_panel.add_child(KnotFrame.new())

	# death splash: STILLED, held still. Bone on coal, no blood-red shout.
	splash = Control.new()
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash.modulate.a = 0.0
	root.add_child(splash)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(UITheme.COAL, 0.62)
	splash.add_child(dim)
	var band := TextureRect.new()
	band.texture = _band_tex(0.86)
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 0.40
	band.anchor_bottom = 0.60
	splash.add_child(band)
	splash_label = Label.new()
	splash_label.label_settings = _font("caps", 104, UITheme.BONE, false)
	splash_label.label_settings.shadow_color = Color(0, 0, 0, 0.9)
	splash_label.label_settings.shadow_size = 18
	splash_label.set_anchors_preset(Control.PRESET_CENTER)
	splash_label.offset_left = -600
	splash_label.offset_top = -86
	splash_label.offset_right = 600
	splash_label.offset_bottom = 40
	splash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	splash_label.text = "Stilled"
	splash.add_child(splash_label)
	_ornament(splash, 0.535, 0.30)

	# the keepsake toast: small, off to the left, never in the way
	_ks_toast = HBoxContainer.new()
	_ks_toast.position = Vector2(28, 106)
	_ks_toast.add_theme_constant_override("separation", 12)
	_ks_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ks_toast.modulate.a = 0.0
	root.add_child(_ks_toast)
	var seal := KnotFrame.new(true, 10.0)
	_ks_toast.add_child(seal)
	_ks_label = Label.new()
	_ks_label.label_settings = _font("italic", 23, UITheme.BONE)
	_ks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ks_toast.add_child(_ks_label)

## A soft horizontal band of coal, clear at both ends.
func _band_tex(alpha: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	var c := UITheme.COAL
	g.colors = PackedColorArray([Color(c, 0.0), Color(c, alpha * 0.75), Color(c, alpha),
		Color(c, alpha * 0.75), Color(c, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 4
	return t

## The card ornament: an ember rule each side of a knot, centred at
## anchor y, spanning half_w of the screen width either side.
func _ornament(parent: Control, y: float, half_w: float) -> void:
	for side in [-1, 1]:
		var r := UITheme.rule(10, 0.75)
		r.anchor_top = y
		r.anchor_bottom = y
		r.offset_bottom = 1
		if side < 0:
			r.anchor_left = 0.5 - half_w
			r.anchor_right = 0.5
			r.offset_right = -22
		else:
			r.anchor_left = 0.5
			r.anchor_right = 0.5 + half_w
			r.offset_left = 22
		parent.add_child(r)
	var k := KnotFrame.new(true, 11.0)
	k.anchor_left = 0.5
	k.anchor_right = 0.5
	k.anchor_top = y
	k.anchor_bottom = y
	k.offset_left = -k.size.x * 0.5
	k.offset_right = k.size.x * 0.5
	k.offset_top = -k.size.y * 0.5
	k.offset_bottom = k.size.y * 0.5
	parent.add_child(k)

var _ks_toast: HBoxContainer = null
var _ks_label: Label = null
var _ks_tw: Tween = null

func _on_flag_raised(flag: String) -> void:
	if Keepsakes.is_step_flag(flag):
		show_keepsake_toast()

func show_keepsake_toast() -> void:
	_ks_label.text = Keepsakes.toast_text()
	if _ks_tw != null and _ks_tw.is_valid():
		_ks_tw.kill()
	_ks_tw = create_tween()
	_ks_tw.tween_property(_ks_toast, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	_ks_tw.tween_interval(3.2)
	_ks_tw.tween_property(_ks_toast, "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)

func _process(dt: float) -> void:
	# the surveyor's line follows the live camera every frame
	var cam := get_viewport().get_camera_3d()
	if cam != null and Game.current_area_id != "":
		var st := "rime" if Game.area_state() == RH.WState.RIME else "thaw"
		var p := cam.global_position
		var r := cam.global_rotation_degrees
		var cap := "free"
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			cap = "cap"
		elif Input.mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN:
			cap = "cfn"
		var lock := ""
		if Game.player != null and Game.player.cam != null \
				and Game.player.cam.locked_target != null:
			lock = " lock"
		var mo := 0
		if Game.player != null:
			mo = Game.player.motion_rate
		pose_label.text = "%s | %s %s  %.1f,%.1f,%.1f,%.1f,%.1f,%.0f  s%.1f %s m%d%s" % [
			RH.BUILD, Game.current_area_id, st, p.x, p.y, p.z, r.y, r.x, cam.fov,
			float(PauseUI.settings.get("sensitivity", 5.0)), cap, mo, lock]
	elif pose_label != null:
		pose_label.text = ""
	# bar smoothing: fill snaps, ghost bleeds down slowly
	hp_fill.size.x = (HP_W - 4) * _hp_ratio
	_ghost_ratio = maxf(_hp_ratio, _ghost_ratio - dt * 0.25)
	hp_ghost.size.x = (HP_W - 4) * _ghost_ratio
	st_fill.size.x = (ST_W - 4) * _st_ratio
	if _hp_edge != null:
		_hp_edge.position.x = 2.0 + maxf(0.0, hp_fill.size.x - 2.0)
		_hp_edge.visible = _hp_ratio > 0.01
	if _st_edge != null:
		_st_edge.position.x = 2.0 + maxf(0.0, st_fill.size.x - 2.0)
		_st_edge.visible = _st_ratio > 0.01
	if vignette.color.a > 0.0:
		vignette.color.a = maxf(0.0, vignette.color.a - dt * 1.6)
	if _post_mat != null:
		_flash_strength = move_toward(_flash_strength, 0.0, dt * 2.6)
		var low_hp := clampf((0.35 - _hp_ratio) / 0.35, 0.0, 1.0)
		_post_mat.set_shader_parameter("low_hp_amount", maxf(low_hp, vignette.color.a * 2.0))
		_post_mat.set_shader_parameter("rime_amount", (1.0 if Game.area_state() == RH.WState.RIME else 0.0))
		_post_mat.set_shader_parameter("flash_strength", _flash_strength)
	# interact prompt
	if Game.player != null and not Game.player.dead:
		var it = Game.player.nearest_interactable()
		var remote_cam := cam != null and cam.name == "ShotCam"
		# a menu or cutscene owns the screen: the world's prompts wait outside it
		var want_prompt := ""
		if it != null and Game.player.input_enabled and not Game.player.busy_in_menu() and not PauseUI.is_open() and not remote_cam:
			want_prompt = "[E]  %s" % it.prompt
		if prompt_label.text != want_prompt:
			prompt_label.text = want_prompt
	if _prompt_plate != null:
		_prompt_plate.visible = prompt_label.text != ""
	# boss bar track
	if _boss != null and is_instance_valid(_boss) and boss_root.visible:
		var br := clampf(_boss.hp / _boss.max_hp, 0.0, 1.0)
		boss_fill.size.x = 996.0 * br
		_boss_ghost_ratio = maxf(br, _boss_ghost_ratio - dt * 0.22)
		if _boss_ghost != null:
			_boss_ghost.size.x = 996.0 * _boss_ghost_ratio
		if _boss.dead:
			hide_boss()

func _on_hp(hp: float, max_hp: float) -> void:
	var r := clampf(hp / max_hp, 0.0, 1.0)
	if r < _hp_ratio:
		vignette.color.a = 0.28
	_hp_ratio = r

func _on_stamina(st: float, max_st: float) -> void:
	_st_ratio = clampf(st / max_st, 0.0, 1.0)

func _on_gourds(n: int, mx: int) -> void:
	gourd_label.text = "Gourd  ×%d" % n
	_refresh_hotbar()

# ------------------------------------------------------------------ hotbar
## Five slots on the bottom edge: press 1-5 to draw that arm (5 drinks).
func _build_hotbar(root: Control) -> void:
	hotbar_root = Control.new()
	hotbar_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotbar_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar_root.offset_left = -170
	hotbar_root.offset_right = 170
	hotbar_root.offset_top = -86
	hotbar_root.offset_bottom = -22
	hotbar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hotbar_root)
	_slots.clear()
	for i in 5:
		var panel := Panel.new()
		var sb := UITheme.box("slot")
		panel.add_theme_stylebox_override("panel", sb)
		panel.position = Vector2(i * 70, 4)
		panel.size = Vector2(60, 60)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar_root.add_child(panel)
		var icon := TextureRect.new()
		icon.position = Vector2(4, 4)
		icon.size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		var num := Label.new()
		num.label_settings = _font(SERIF_B, 15, UITheme.BONE_DIM)
		num.position = Vector2(5, 1)
		num.text = str(i + 1)
		panel.add_child(num)
		var count := Label.new()
		count.label_settings = _font(SERIF_B, 17, UITheme.BONE)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		count.grow_vertical = Control.GROW_DIRECTION_BEGIN
		count.offset_left = -34
		count.offset_top = -22
		count.offset_right = -5
		count.offset_bottom = -2
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.text = ""
		panel.add_child(count)
		_slots.append({"panel": panel, "style": sb, "icon": icon, "count": count})
	arrows_chip = Label.new()
	arrows_chip.label_settings = _font(SERIF_B, 22, UITheme.BONE)
	arrows_chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	arrows_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	arrows_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	arrows_chip.offset_left = -170
	arrows_chip.offset_right = 170
	arrows_chip.offset_top = -116
	arrows_chip.offset_bottom = -90
	arrows_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrows_chip.visible = false
	root.add_child(arrows_chip)
	# the attuned song: a gilt slot to the LEFT of the belt, marked X
	song_panel = Panel.new()
	song_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	song_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	song_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	song_panel.offset_left = -250
	song_panel.offset_right = -190
	song_panel.offset_top = -82
	song_panel.offset_bottom = -22
	var rsb := UITheme.box("slot")
	rsb.border_color = Color(UITheme.EMBER, 0.85)
	song_panel.add_theme_stylebox_override("panel", rsb)
	song_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(song_panel)
	song_icon = TextureRect.new()
	song_icon.position = Vector2(4, 4)
	song_icon.size = Vector2(52, 52)
	song_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	song_icon.stretch_mode = TextureRect.STRETCH_SCALE
	song_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	song_panel.add_child(song_icon)
	var rkey := Label.new()
	rkey.label_settings = _font(SERIF_B, 15, UITheme.EMBER_HOT)
	rkey.position = Vector2(5, 1)
	rkey.text = "X"
	song_panel.add_child(rkey)
	song_cost = Label.new()
	song_cost.label_settings = _font(SERIF_B, 16, UITheme.BONE)
	song_cost.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	song_cost.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	song_cost.grow_vertical = Control.GROW_DIRECTION_BEGIN
	song_cost.offset_left = -34
	song_cost.offset_top = -22
	song_cost.offset_right = -5
	song_cost.offset_bottom = -2
	song_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	song_panel.add_child(song_cost)
	_refresh_song()

func _refresh_song() -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or song_panel == null:
		return
	var sid: String = p.attuned_song
	song_panel.visible = sid != "" and not DB.song(sid).is_empty()
	if song_panel.visible:
		song_icon.texture = load("res://assets/ui/icons/song.png")
		song_cost.text = str(int(DB.song(sid).get("breath", 0)))

func _refresh_hotbar() -> void:
	var p = Game.player
	if p == null or not is_instance_valid(p) or _slots.is_empty():
		return
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var id: String = String(p.hotbar[i])
		var icon_path: String = SLOT_ICON.get(id, "")
		var tex: Texture2D = null
		if icon_path != "" and ResourceLoader.exists(icon_path):
			tex = load(icon_path)
		(slot["icon"] as TextureRect).texture = tex
		var owned: bool = id != "" and (id == "gourd" or p.owns_weapon(id))
		var selected: bool = id == p.weapon_id
		(slot["icon"] as TextureRect).modulate.a = 0.98 if owned else 0.22
		var sb: StyleBoxFlat = slot["style"]
		var look := UITheme.box("slot_sel" if selected else "slot")
		sb.border_color = look.border_color
		sb.set_border_width_all(2 if selected else 1)
		sb.bg_color = look.bg_color
		var c: Label = slot["count"]
		if id == "gourd":
			c.text = str(p.gourds)
		elif id == "bow" and owned:
			c.text = str(int(p.inventory.get("arrows", 0)))
		else:
			c.text = ""
	var bow_up: bool = p.weapon_id == "bow"
	arrows_chip.visible = bow_up
	if bow_up:
		arrows_chip.text = "Arrows  ×%d" % int(p.inventory.get("arrows", 0))

func _on_breath(v: float, mx: float) -> void:
	breath_panel.visible = mx > 0.0
	if mx > 0.0:
		breath_fill.size.x = maxf((breath_panel.size.x - 4.0) * v / mx, 0.0)
		if _breath_edge != null:
			_breath_edge.position.x = 2.0 + maxf(0.0, breath_fill.size.x - 2.0)
			_breath_edge.visible = v > 0.5
	var p = Game.player
	if song_cost != null and p != null and is_instance_valid(p) and p.attuned_song != "":
		var cost := float(DB.song(p.attuned_song).get("breath", 0))
		song_cost.label_settings.font_color = UITheme.BONE if v >= cost else UITheme.ASH

func _on_warmth(n: int) -> void:
	warmth_label.text = "%d warmth" % n

func _on_forgotten() -> void:
	_fade_splash(true)

func _fade_splash(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(splash, "modulate:a", 1.0 if on else 0.0, 0.9 if on else 0.5)

func _on_transition(_a: String, to_state: RH.WState) -> void:
	show_toast("The memory stills." if to_state == RH.WState.RIME else "The memory warms.")

var _toast_tw: Tween = null
var _lore_opened_at := 0.0

func show_toast(text: String) -> void:
	toast_label.text = text
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(toast_label, "modulate:a", 1.0, 0.4)
	_toast_tw.tween_interval(2.4)
	_toast_tw.tween_property(toast_label, "modulate:a", 0.0, 0.8)

func show_lore(text: String) -> void:
	lore_text.text = text
	# the panel fits the words, not the other way round: measure the wrapped
	# text and grow the frame so nothing spills past the border or the hint
	var f: Font = lore_text.label_settings.font
	var need := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
			808.0, lore_text.label_settings.font_size).y
	var h := clampf(need + 150.0, 400.0, 860.0)
	lore_text.size = Vector2(808, h - 140.0)
	_lore_panel.size = Vector2(900, h)
	var vp := get_viewport().get_visible_rect().size
	_lore_panel.position = Vector2((vp.x - 900.0) * 0.5, maxf((vp.y - h) * 0.5, 40.0))
	_lore_hint.position = Vector2(46, h - 60.0)
	lore_root.visible = true
	lore_root.add_to_group("lore_open")
	_lore_opened_at = Time.get_ticks_msec() * 0.001
	if Game.player:
		Game.player.lock_control(true)
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -6.0)

func _input(event: InputEvent) -> void:
	if lore_root != null and lore_root.visible:
		if Time.get_ticks_msec() * 0.001 - _lore_opened_at < 0.25:
			get_viewport().set_input_as_handled()
			return
		if ((event is InputEventKey and not event.is_echo()) or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
			lore_root.visible = false
			lore_root.remove_from_group("lore_open")
			if Game.player:
				Game.player.lock_control(false)
				if Game.player.has_method("suppress_interact"):
					Game.player.suppress_interact(8)
			get_viewport().set_input_as_handled()

## J opens the Pack at the Keepsakes leaf (the Bearer's own keys stay in
## player.gd; this is a menu key, so the HUD owns it).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("keepsakes"):
		return
	var p = Game.player
	if p == null or not is_instance_valid(p) or p.dead or not p.input_enabled:
		return
	if p.busy_in_menu() or PauseUI.is_open():
		return
	InventoryUI.open_for(p, "keepsakes")
	get_viewport().set_input_as_handled()

func show_boss(boss: Node) -> void:
	_boss = boss
	_boss_ghost_ratio = 1.0
	boss_name.text = boss.cfg.get("name", "???")
	boss_root.visible = true

func hide_boss() -> void:
	boss_root.visible = false
	_boss = null


# ---------------------------------------------------------------- area title
## The house announces itself: a grand serif card, centre-screen, a thin
## gold rule beneath — faded in, held a breath, and let go.
var _title_layer: CanvasLayer = null

func show_area_title(text: String, hold := 2.2) -> void:
	if _title_layer != null and is_instance_valid(_title_layer):
		_title_layer.queue_free()
	_title_layer = CanvasLayer.new()
	_title_layer.layer = 11
	add_child(_title_layer)
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_layer.add_child(box)
	var tband := TextureRect.new()
	tband.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tband.stretch_mode = TextureRect.STRETCH_SCALE
	tband.texture = _band_tex(0.62)
	tband.anchor_left = 0.14
	tband.anchor_right = 0.86
	tband.anchor_top = 0.27
	tband.anchor_bottom = 0.45
	tband.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tband)
	var name_l := Label.new()
	name_l.label_settings = _font("caps", 64, UITheme.BONE, true)
	name_l.label_settings.shadow_size = 12
	# SLICE.md: small caps, no subtitle. Lower the authored capitals so the
	# font's small caps carry the word, with a true capital up front.
	name_l.text = _caps_case(text)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.anchor_left = 0.0
	name_l.anchor_right = 1.0
	name_l.anchor_top = 0.29
	name_l.anchor_bottom = 0.40
	box.add_child(name_l)
	_ornament(box, 0.405, 0.16)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(box, "modulate:a", 0.0, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var layer_ref := _title_layer
	tw.tween_callback(func():
		if is_instance_valid(layer_ref):
			layer_ref.queue_free())

## "THE STRAND" -> "The Strand", which the caps face then sets in small caps
## (lower case -> small caps, capitals stay full). Short words stay low.
static func _caps_case(text: String) -> String:
	var words := text.split(" ")
	var out := PackedStringArray()
	for i in words.size():
		var w := words[i].to_lower()
		if i > 0 and w in ["the", "of", "and", "a"]:
			out.append(w)
		elif w.length() > 0:
			out.append(w.substr(0, 1).to_upper() + w.substr(1))
		else:
			out.append(w)
	return " ".join(out)

func _on_post_flash(kind: String, might: float) -> void:
	_flash_strength = clampf(might, 0.0, 1.0)
	if _post_mat != null:
		var col := Color(0.85, 0.14, 0.10)
		if kind == "parry":
			col = Color(1.0, 0.90, 0.55)
		elif kind == "spark":
			col = Color(1.0, 0.76, 0.36)
		_post_mat.set_shader_parameter("flash_color", Vector3(col.r, col.g, col.b))
