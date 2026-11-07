class_name AreaPortal
extends Node3D
## A doorway to another area of the highland. Optionally sealed behind a
## world flag (the tower door opens only when the holdfast rests).

var to_area := ""
var spawn_pos := Vector3.ZERO
var spawn_yaw := 1e9             # camera yaw (deg) on arrival; unset = keep
var prompt := "Pass on"
var locked_flag := ""        # world flag that must be TRUE to pass
var locked_prompt := "Sealed"
var requires_items: Array = []   # item ids the Bearer must carry to pass
var cutscene := ""               # reserved: a ride played before arriving
## A seam in continuous land (a pass, a bridge): no prompt, no marker. Walking
## into the box carries the Bearer on; the next area holds the same ground.
var auto := false
var zone_size := Vector3(12, 4, 2)

var _zone: Interactable
var _marker: OmniLight3D
var _disc: MeshInstance3D
var _pulse := 0.0

func _ready() -> void:
	if auto:
		var a := Area3D.new()
		a.name = "Seam"
		a.collision_layer = 0
		a.collision_mask = 1 << (RH.L_PLAYER - 1)
		a.monitorable = false
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = zone_size
		cs.shape = bx
		cs.position.y = zone_size.y * 0.5
		a.add_child(cs)
		a.body_entered.connect(func(b): if b == Game.player: _on_use.call_deferred(b))
		add_child(a)
		add_to_group("seams")
		return
	_zone = Interactable.new()
	_zone.prompt = prompt
	_zone.setup_zone(1.6, 2.2)
	_zone.activated.connect(_on_use)
	add_child(_zone)
	_add_marker()

## A threshold marker: a soft glowing floor sigil + a gentle light, so a stair or
## door reads as usable from across the room instead of the prompt just popping.
func _add_marker() -> void:
	var disc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.4, 2.4)
	disc.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.95, 0.8, 0.46)
	mat.albedo_texture = _radial_tex()
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(0, 0.05, 0)
	add_child(disc)
	_disc = disc
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.83, 0.52)
	light.omni_range = 3.6
	light.omni_attenuation = 1.7
	light.position = Vector3(0, 0.7, 0)
	add_child(light)
	_marker = light

static func _radial_tex() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.38, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.95),
		Color(1.0, 0.95, 0.85, 0.65),
		Color(1.0, 0.85, 0.65, 0.20),
		Color(1.0, 0.80, 0.55, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 48
	gt.height = 48
	return gt

static func make_mote_quad(sz := 1.6, col := Color.WHITE) -> QuadMesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(sz, sz)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = col
	mat.albedo_texture = _radial_tex()
	qm.material = mat
	return qm

func _unlocked() -> bool:
	if locked_flag != "":
		var ok := World.is_cleared(locked_flag.get_slice(":", 1)) \
				if locked_flag.begins_with("cleared:") else World.flag(locked_flag)
		if not ok:
			return false
	for it in requires_items:
		if Game.player == null or int(Game.player.inventory.get(it, 0)) < 1:
			return false
	return true

func _physics_process(dt: float) -> void:
	if auto:
		return
	var open := _unlocked()
	if locked_flag != "" or not requires_items.is_empty():
		_zone.prompt = prompt if open else locked_prompt
	# breathe the marker; warm gold when open, cold and dim when sealed
	_pulse += dt
	var breathe := 0.62 + 0.38 * (0.5 + 0.5 * sin(_pulse * 2.2))
	if _marker != null:
		_marker.light_energy = (1.5 if open else 0.4) * breathe
		_marker.light_color = Color(1.0, 0.83, 0.52) if open else Color(0.5, 0.56, 0.72)
	if _disc != null:
		var base: Color = Color(0.95, 0.8, 0.46) if open else Color(0.42, 0.47, 0.62)
		_disc.material_override.albedo_color = base * breathe

func _on_use(player) -> void:
	if Game.arena_locked:
		Game.toast.emit("The frost veil holds. The duel is not done.")
		return
	if not _unlocked():
		Game.toast.emit(locked_prompt + ".")
		return
	if to_area == "" or player == null:
		return
	Game.travel_to(to_area, spawn_pos, spawn_yaw)
