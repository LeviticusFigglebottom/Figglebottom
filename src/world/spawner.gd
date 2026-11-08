class_name Spawner
extends Node3D
## Spawns one enemy; respawns it when hearth is kept (unless dead_once and
## already slain, tracked via World area flags).

@export var enemy_id := "rimewalker"
@export var dead_once := false     # minibosses: stay dead once killed
@export var face_deg := 0.0
var spawn_flag := ""               # area flag name for dead_once tracking
var pose := ""                     # idle chore ("sit"), see Enemy.idle_pose
var area_id := ""
## the roster id this spawner stands in for (its own row not in yet): the
## stand-in fights, but never carries the stand-in's story (no release flag,
## card or leavings of the holdfast it borrows the body of)
var stand_in_for := ""

var current: Enemy = null

func _ready() -> void:
	add_to_group(RH.GROUP_RESPAWN_ON_REST)
	respawn.call_deferred()

func respawn() -> void:
	if dead_once and area_id != "" and World.area_flag(area_id, spawn_flag):
		_reseal.call_deferred()
		return
	if current != null and is_instance_valid(current):
		current.queue_free()
	var ecfg: Dictionary = DB.table("enemies").get(enemy_id, {})
	if ecfg.has("class"):
		current = load(ecfg["class"]).new()
	else:
		current = Enemy.new()
	current.setup(enemy_id)
	if stand_in_for != "":
		var c: Dictionary = current.cfg.duplicate(true)
		for k in ["release_flag", "release_card", "release_drop", "release_hearth"]:
			c.erase(k)
		c["name"] = stand_in_for.capitalize()
		current.cfg = c
		current.set_meta("roster_id", stand_in_for)
	current.idle_pose = pose
	add_child(current)
	current.global_position = global_position
	current.vis.rotation.y = deg_to_rad(face_deg)
	if dead_once:
		current.died.connect(func(_e): World.set_area_flag(area_id, spawn_flag))

## A released Holdfast that closed a hole (release_seal) keeps it closed in a
## rebuilt area: the hole lies hole_ahead metres along the way it faced.
func _reseal() -> void:
	var ecfg: Dictionary = DB.table("enemies").get(enemy_id, {})
	if not ecfg.has("release_seal") or not is_inside_tree():
		return
	var a := deg_to_rad(face_deg)
	var at := global_position + Vector3(-sin(a), 0, -cos(a)) * float(ecfg.get("hole_ahead", 0.0))
	var area: Node = get_parent()
	while area != null and not (area is Area):
		area = area.get_parent()
	BrokenIce.seal_at(area if area != null else get_parent(), at,
			float((ecfg["release_seal"] as Dictionary).get("radius", 2.0)))
