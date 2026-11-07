class_name ShortcutGate
extends Node3D
## The classic soulslike gate: barred from one side. Learned in thaw,
## a lifeline in rime. Once opened, the flag persists.

var gate_id := "gate"
var area_id := ""
var locked_prompt := "Barred from the other side"

var _leaves: Array[Node3D] = []
var _front: Interactable
var _back: Interactable

func _ready() -> void:
	var vis := KitLib.instance("gate_iron")
	add_child(vis)
	for mi in KitLib._mesh_instances(vis):
		var nm := String(mi.name)
		if nm.contains("gate_leaf"):
			_leaves.append(mi)
	# static collision so the closed gate truly blocks (and splits navmesh)
	var body := StaticBody3D.new()
	body.name = "GateBody"
	body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.3, 0.14)
	cs.shape = box
	cs.position.y = 1.15
	body.add_child(cs)
	add_child(body)

	# the locked face is +Z (local); the unbarring side is -Z
	_front = Interactable.new()
	_front.prompt = locked_prompt
	_front.setup_zone(1.2, 1.6, Vector3(0, 0, 1.1))
	_front.activated.connect(func(_p): Game.toast.emit(locked_prompt + "."))
	add_child(_front)
	_back = Interactable.new()
	_back.prompt = "Unbar the gate"
	_back.setup_zone(1.2, 1.6, Vector3(0, 0, -1.1))
	_back.activated.connect(_on_unbar)
	add_child(_back)

	if _is_open():
		_apply_open(true)

func _is_open() -> bool:
	return World.area_flag(area_id, "gate_" + gate_id)

func _on_unbar(_p) -> void:
	World.set_area_flag(area_id, "gate_" + gate_id)
	World.save_game()
	_apply_open(false)
	Game.toast.emit("The gate stands open.")
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -6.0, 0.55)

func _apply_open(instant: bool) -> void:
	_front.enabled = false
	_back.enabled = false
	var body := get_node("GateBody") as StaticBody3D
	body.collision_layer = 0
	for i in _leaves.size():
		var leaf := _leaves[i]
		var target := deg_to_rad(-104.0 if i == 0 else 104.0)
		if instant:
			leaf.rotation.y = target
		else:
			create_tween().tween_property(leaf, "rotation:y", target, 1.1)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# navmesh changed: gates count as base geometry, rebake both maps
	if Game.current_area != null and not instant:
		Game.current_area.bake_navmeshes.call_deferred()
