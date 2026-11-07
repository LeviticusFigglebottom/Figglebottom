class_name Interactable
extends Area3D
## Something the Bearer can use: hearths, gates, plaques, pickups, NPCs.
## Player scans for these on the interact physics layer.

signal activated(player)

@export var prompt := "Interact"
@export var enabled := true
var zone_offset := Vector3.ZERO   # where the usable spot actually is

func _init() -> void:
	collision_layer = 1 << (RH.L_INTERACT - 1)
	collision_mask = 0
	monitoring = false

func setup_zone(radius := 1.7, height := 1.6, offset := Vector3.ZERO) -> void:
	zone_offset = offset
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	cs.position = offset + Vector3(0, height * 0.5, 0)
	add_child(cs)

func activate(player) -> void:
	if enabled:
		activated.emit(player)

func zone_global() -> Vector3:
	return to_global(zone_offset)
