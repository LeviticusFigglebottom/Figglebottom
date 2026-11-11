class_name ShortcutGate
extends Node3D
## The classic soulslike gate: barred from one side. Learned in thaw,
## a lifeline in rime. Once opened, the flag persists.

var gate_id := "gate"
var layer_bit := RH.L_WORLD_BASE   # a gate that stands in one state only takes that state's layer
var area_id := ""
var locked_prompt := "Barred from the other side"
## Width of the opening the leaves fill (a house door is 1.9 m; the old
## yard gate 3.6 m). The leaves hinge at the jambs and swing to the far side.
var door_width := 3.6
var door_height := 2.5
## A gate that is not a pair of plank doors (the Drift Lane's slip-rails,
## tied with wool): no leaves, its look is the area's "dressing" alone
var leaves := true
var open_prompt := "Unbar the gate"
var open_toast := "The gate stands open."

var _leaves: Array[Node3D] = []
var _front: Interactable
var _back: Interactable

func _ready() -> void:
	# two plank leaves, each hung from its jamb on a pivot so it really swings
	for side in ([-1.0, 1.0] if leaves else []):
		var pivot := Node3D.new()
		pivot.name = "gate_leaf_%s" % ("l" if side < 0 else "r")
		pivot.position = Vector3(side * door_width * 0.5, 0, 0)
		add_child(pivot)
		var leaf := KitLib.instance("door_leaf")
		leaf.scale = Vector3(door_width * 0.5 / 0.95, door_height / 2.5, 1.0)
		leaf.position = Vector3(-side * door_width * 0.25, 0, 0)
		pivot.add_child(leaf)
		_leaves.append(pivot)
	# static collision so the closed gate truly blocks (and splits navmesh)
	var body := StaticBody3D.new()
	body.name = "GateBody"
	body.collision_layer = 1 << (layer_bit - 1)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(door_width + 0.3, door_height, 0.14)
	cs.shape = box
	cs.position.y = door_height * 0.5
	body.add_child(cs)
	add_child(body)

	# the locked face is +Z (local); the unbarring side is -Z
	_front = Interactable.new()
	_front.prompt = locked_prompt
	_front.setup_zone(1.2, 1.6, Vector3(0, 0, 1.1))
	_front.activated.connect(func(_p): Game.toast.emit(locked_prompt + "."))
	add_child(_front)
	_back = Interactable.new()
	_back.prompt = open_prompt
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
	Game.toast.emit(open_toast)
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -6.0, 0.55)

## A released Holdfast lifts the bar from wherever he is (TARNHALL.md 9):
## the flag is set and the leaves swing open by themselves.
func lift_bar() -> void:
	if _is_open():
		return
	World.set_area_flag(area_id, "gate_" + gate_id)
	_apply_open(false)
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -2.0, 0.4)

func _apply_open(instant: bool) -> void:
	_front.enabled = false
	_back.enabled = false
	for c in get_children():
		if c.has_meta("gate_dressing"):
			c.visible = false         # (doors drawn as dressing swing out of the way)
	var body := get_node("GateBody") as StaticBody3D
	body.collision_layer = 0
	# a gate on a state layer (Tarnhall's doors, RIME only): the layer's
	# collision toggles restore orig_layer, so an open gate stays open
	body.set_meta("orig_layer", 0)
	for i in _leaves.size():
		var leaf := _leaves[i]
		# both leaves swing in toward the unbarring (-Z) side
		var target := deg_to_rad(100.0 if i == 0 else -100.0)
		if instant:
			leaf.rotation.y = target
		else:
			create_tween().tween_property(leaf, "rotation:y", target, 1.1)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# navmesh changed: gates count as base geometry, rebake both maps
	if Game.current_area != null and not instant:
		Game.current_area.bake_navmeshes.call_deferred()
