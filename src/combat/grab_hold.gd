class_name GrabHold
extends Node
## A hold on the Bearer (the Hearthhound's grab-shake, the Netmender's net
## snare): his controls are locked while the holder pins him; mashing dodge
## or attack breaks free after `mash_needed` presses, else the hold lets go
## by itself after `max_time`. The holder moves him; this only counts.

signal released(broken: bool)

var victim: Node3D
var max_time := 1.5
var mash_needed := 6
var presses := 0
var t := 0.0
var _over := false

static func start(holder: Node, p_victim: Node3D, p_max: float, p_mash: int) -> GrabHold:
	var g := GrabHold.new()
	g.victim = p_victim
	g.max_time = p_max
	g.mash_needed = p_mash
	holder.add_child(g)
	if p_victim != null and p_victim.has_method("lock_control"):
		p_victim.lock_control(true)
	return g

## One struggle (tests and scripted input call this; the keyboard and pad
## arrive through _physics_process).
func mash() -> void:
	presses += 1

func is_over() -> bool:
	return _over

func _physics_process(dt: float) -> void:
	if _over:
		return
	t += dt
	if Input.is_action_just_pressed("dodge") or Input.is_action_just_pressed("attack_light") \
			or Input.is_action_just_pressed("attack_heavy"):
		mash()
	if victim == null or not is_instance_valid(victim) or bool(victim.get("dead")):
		end(false)
	elif presses >= mash_needed:
		end(true)
	elif t >= max_time:
		end(false)

func end(broken: bool) -> void:
	if _over:
		return
	_over = true
	if victim != null and is_instance_valid(victim) and victim.has_method("lock_control") \
			and not bool(victim.get("dead")):
		victim.lock_control(false)
	released.emit(broken)
	queue_free()

func _exit_tree() -> void:
	if not _over:   # the holder died or left mid-hold: never strand the Bearer
		_over = true
		if victim != null and is_instance_valid(victim) and victim.has_method("lock_control"):
			victim.lock_control(false)
