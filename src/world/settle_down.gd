class_name SettleDown
extends Node
## Seats its parent on whatever solid is under it once the world is live
## (area JSON "settle": true). For things set on a shape only the engine
## knows: the crown of a kin-mound is lumpy turf (BuildingGen._barrow), and
## a cloth laid on it must lie on it, not at the height a script guessed.

var offset := 0.0        # metres above the surface found
var reach := 2.5         # how far above and below the authored height to look

func _ready() -> void:
	_seat.call_deferred()

func _seat() -> void:
	var p := get_parent() as Node3D
	if p == null or not p.is_inside_tree():
		return
	# the area's colliders reach the physics server a frame after they enter the tree
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var from := p.global_position + Vector3.UP * reach
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * reach * 2.0, RH.M_WORLD_ALL)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		p.global_position.y = (hit["position"] as Vector3).y + offset
	queue_free()
