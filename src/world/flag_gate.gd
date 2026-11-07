class_name FlagGate
extends Node3D
## A physical barrier that stands until a world flag comes true, then sinks
## away for good. Used by quest locks and dug shortcuts.

var flag := ""
var or_cleared := ""          # area id: the gate also opens once its holdfast rests
var kit := "fence_iron_4m"
var open_sfx := "res://assets/audio/swell_warm.wav"
var open_dir := "down"          # "down" sinks away; "up" hoists (portcullis)

var _piece: Node3D
var _body: StaticBody3D
var _open := false

func setup(spec: Dictionary, tag_bit: int) -> void:
	flag = spec.get("flag", "")
	or_cleared = spec.get("or_cleared", "")
	kit = spec.get("kit", "fence_iron_4m")
	open_dir = spec.get("open_dir", "down")
	var sc := Vector3.ONE
	var sa: Array = spec.get("scale", [])
	if sa.size() == 3:
		sc = Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
	_piece = KitLib.instance(kit)
	_piece.scale = sc
	add_child(_piece)
	_body = StaticBody3D.new()
	_body.collision_layer = 1 << (tag_bit - 1)
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var sz: Array = KitLib.manifest().get(kit, {}).get("size", [4, 0.4, 3])
	box.size = Vector3(float(sz[0]) * sc.x, float(sz[2]) * sc.y,
			maxf(float(sz[1]) * sc.z, 0.4))
	cs.shape = box
	cs.position.y = float(sz[2]) * sc.y * 0.5
	_body.add_child(cs)
	add_child(_body)

func _unlocked() -> bool:
	return World.flag(flag) or (or_cleared != "" and World.is_cleared(or_cleared))

func _ready() -> void:
	if _unlocked():
		_snap_open()

func _physics_process(_dt: float) -> void:
	if not _open and _unlocked():
		_animate_open()

func _snap_open() -> void:
	_open = true
	_body.collision_layer = 0
	_piece.visible = false
	set_physics_process(false)

func _animate_open() -> void:
	_open = true
	_body.collision_layer = 0
	set_physics_process(false)
	AudioDirector.sfx_at(open_sfx, global_position, -4.0, 0.9)
	Juice.shake(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(_piece, "position:y", 3.6 if open_dir == "up" else -3.2, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _piece.visible = false)
	if Game.current_area != null:
		Game.current_area.bake_navmeshes.call_deferred()
