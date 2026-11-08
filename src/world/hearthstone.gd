class_name Hearthstone
extends Node3D
## THE rest site and world-toggle. Keeping hearth here heals, respawns the
## dead, anchors the Bearer's return — and turns the world over between
## its thaw and its rime. (DECISIONS D-008/D-009)

@export var hearth_id := "hearth"
@export var display_name := "Hearthstone"

var area: Area = null
var zone: Interactable
var _flame: GeometryInstance3D = null

var _light: OmniLight3D = null

func _ready() -> void:
	add_to_group(RH.GROUP_STATE_LISTENERS)
	add_to_group("hearths")
	var vis := KitLib.instance("hearthstone")
	add_child(vis)
	# solid post — you rest at the hearth, you don't walk through it
	var lbody := StaticBody3D.new()
	lbody.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	lbody.collision_mask = 0
	var lcs := CollisionShape3D.new()
	var lcyl := CapsuleShape3D.new()
	lcyl.radius = 0.38
	lcyl.height = 2.4
	lcs.shape = lcyl
	lcs.position.y = 1.2
	lbody.add_child(lcs)
	vis.add_child(lbody)
	_flame = _find_flame(vis)
	if _flame != null:
		_flame.set_instance_shader_parameter("keep_in_rime", 1.0)
	var lights := KitLib.add_flame_lights(vis, 3.2, 8.8)
	if lights.size() > 0:
		_light = lights[0]
	zone = Interactable.new()
	zone.prompt = "Keep hearth"
	zone.setup_zone(1.9, 1.8)
	zone.activated.connect(_on_activated)
	add_child(zone)
	_tint_for(World.get_area_state(_area_id()))

func _area_id() -> String:
	return area.area_id if area != null else Game.current_area_id

func _find_flame(root: Node) -> GeometryInstance3D:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D and String(n.name).contains("hearth_flame"):
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _on_activated(player) -> void:
	if player == null:
		Game.hearth_flow(self, null)
		return
	player.lock_control(true)
	player.velocity = Vector3.ZERO
	get_tree().call_group("hud", "clear_area_title")
	var ui := RestUI.new(self, player)
	get_tree().root.add_child(ui)
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)

func on_world_state(area_id: String, s: RH.WState) -> void:
	if area_id == _area_id():
		_tint_for(s)

func _tint_for(s: RH.WState) -> void:
	if _flame == null:
		return
	if s == RH.WState.RIME:
		_flame.set_instance_shader_parameter("flame_tint", Vector3(0.45, 0.68, 1.0))
		_flame.set_instance_shader_parameter("flame_energy", 3.4)
		if _light:
			_light.light_color = Color(0.48, 0.68, 1.0)
			_light.light_energy = 2.8
	else:
		_flame.set_instance_shader_parameter("flame_tint", Vector3(1.0, 0.72, 0.28))
		_flame.set_instance_shader_parameter("flame_energy", 3.8)
		if _light:
			_light.light_color = Color(1.0, 0.68, 0.32)
			_light.light_energy = 3.4

func respawn_point() -> Vector3:
	return global_position + global_transform.basis.z * 1.4
