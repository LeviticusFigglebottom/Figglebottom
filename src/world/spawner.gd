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

## the area spec's "absent_flag": once that story flag is raised the foe is
## gone for good (Tarnhall's seated guests, once the Host is released). The
## builder leaves such a spawner out of a rebuilt area; this keeps a rest in
## the same visit from seating them again.
var absent_flag := ""
## the area spec's own id for this foe, and the ids of the foes it waits on
## ("wakes_with"): its sight and hearing are data, and they are nought until
## one of those is struck (or it is)
var spawn_id := ""
var wakes_with: Array = []
## enemy data set for this place only (the area spec's "rise_time")
var cfg_over := {}

var current: Enemy = null

func _ready() -> void:
	add_to_group(RH.GROUP_RESPAWN_ON_REST)
	respawn.call_deferred()

func respawn() -> void:
	if dead_once and area_id != "" and World.area_flag(area_id, spawn_flag):
		_reseal.call_deferred()
		_leave_released()
		return
	if current != null and is_instance_valid(current):
		current.queue_free()
	if absent_flag != "" and World.flag(absent_flag):
		current = null
		return
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
	if not cfg_over.is_empty():
		var oc: Dictionary = current.cfg.duplicate(true)
		oc.merge(cfg_over, true)
		current.cfg = oc
	current.idle_pose = pose
	add_child(current)
	if not wakes_with.is_empty():
		var woken: Dictionary = current.cfg
		var deaf: Dictionary = woken.duplicate(true)
		deaf.merge({"aggro_sight": 0.0, "aggro_hear": 0.0}, true)
		current.cfg = deaf
		_bind_wakes.call_deferred(current, woken)
	current.global_position = global_position
	current.vis.rotation.y = deg_to_rad(face_deg)
	if dead_once:
		current.died.connect(func(_e): World.set_area_flag(area_id, spawn_flag))

## The foes this one waits on are spawned by now: the first of them struck
## rouses it.
func _bind_wakes(mine: Enemy, woken: Dictionary) -> void:
	if mine == null or not is_instance_valid(mine):
		return
	var wake := func(_e):
		if is_instance_valid(mine) and mine.cfg != woken:
			mine.cfg = woken
			mine.rouse()
	mine.struck.connect(wake)
	for n in get_tree().get_nodes_in_group(RH.GROUP_RESPAWN_ON_REST):
		var sp := n as Spawner
		if sp == null or not (sp.spawn_id in wakes_with) or sp.current == null or not is_instance_valid(sp.current):
			continue
		sp.current.struck.connect(wake)

## A released Holdfast that stays where it sat (data "release_stays": the
## Leadvoice, COLDWELL.md 6 and 9) is still there in a rebuilt area. Without
## this a save resumed after her release found the wellhead empty, and both
## endings played to nobody.
func _leave_released() -> void:
	var ecfg: Dictionary = DB.table("enemies").get(enemy_id, {})
	if not bool(ecfg.get("release_stays", false)) or not ecfg.has("class"):
		return
	if current != null and is_instance_valid(current):
		return
	current = load(ecfg["class"]).new()
	current.setup(enemy_id)
	add_child(current)
	current.global_position = global_position
	current.vis.rotation.y = deg_to_rad(face_deg)
	if current.has_method("rest_released"):
		current.rest_released()

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
