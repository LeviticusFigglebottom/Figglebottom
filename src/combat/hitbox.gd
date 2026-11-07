class_name Hitbox
extends Area3D
## A swing's active volume. Enable for the active window; hits each hurtbox
## at most once per swing. Reports back to the wielder via callback.

var packet: DamagePacket
var _struck: Array[Node] = []
var on_contact: Callable = Callable()   # func(hurtbox, result)
var exclude: Node = null                # wielder root — never self-hit
var friendly_team := ""                 # hurtboxes of this team are never struck
## A swing only hits inside its ARC: the planar angle from the wielder's
## facing to the victim must sit within arc_deg (360 = the old barn door).
## occlude adds a world ray — no more striking through a pillar.
var arc_deg := 360.0
var arc_node: Node3D = null             # facing source (-Z forward)
var occlude := false

func _init() -> void:
	collision_layer = 0
	collision_mask = 1 << (RH.L_HURTBOX - 1)
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area)

func begin_swing(p: DamagePacket) -> void:
	packet = p
	_struck.clear()
	monitoring = true
	# catch hurtboxes already overlapping when the window opens
	for a in get_overlapping_areas():
		_on_area(a)

func end_swing() -> void:
	set_deferred("monitoring", false)
	packet = null

## Physics is mid-flush when area_entered fires — the space is locked, and
## the occlusion ray would error every overlap. Resolve one breath later.
func _on_area(a: Area3D) -> void:
	if packet == null or not (a is Hurtbox):
		return
	_resolve.call_deferred(a)

func _resolve(a: Area3D) -> void:
	if packet == null or not is_instance_valid(a):
		return
	var host := a.owner if a.owner != null else a.get_parent()
	if host == exclude or host in _struck:
		return
	# no friendly fire
	if exclude != null and exclude.is_in_group(RH.GROUP_ENEMIES) and host.is_in_group(RH.GROUP_ENEMIES):
		return
	if friendly_team != "" and (a as Hurtbox).team == friendly_team:
		return
	if not _in_swing(host):
		return
	_struck.append(host)
	var result: String = (a as Hurtbox).receive(packet)
	if on_contact.is_valid():
		on_contact.call(a, result)

## The swing's honesty checks: inside the weapon's arc, and not through a
## wall or a pillar. Victims outside either are simply not hit.
func _in_swing(host: Node) -> bool:
	if not (host is Node3D) or arc_node == null or not is_instance_valid(arc_node):
		return true
	var origin: Vector3 = arc_node.global_position
	var to: Vector3 = (host as Node3D).global_position - origin
	to.y = 0.0
	if arc_deg < 360.0 and to.length() > 0.6:
		var fwd: Vector3 = -arc_node.global_transform.basis.z
		fwd.y = 0.0
		if fwd.normalized().angle_to(to.normalized()) > deg_to_rad(arc_deg * 0.5):
			return false
	if occlude:
		var from := origin + Vector3.UP * 1.2
		var till: Vector3 = (host as Node3D).global_position + Vector3.UP * 1.0
		var q := PhysicsRayQueryParameters3D.create(from, till, RH.M_WORLD_ALL)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return false
	return true
