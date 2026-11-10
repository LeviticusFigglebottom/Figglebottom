class_name Hearthhound
extends Enemy
## A household dog that froze waiting at a door (SLICE.md 5). It guards a
## threshold: lies across it, sits up and barks once when it sees the Bearer
## (alerting every frost-taken within 15 m), lunges to bite, and will not go
## more than `leash` metres from home: past that it walks back and lies down.
## A lunge that lands from behind becomes a grab-shake (GrabHold: mash to
## break). The model is a Tripo quadruped (QuadRig poses over its one walk).

var barked := false
var grab: GrabHold = null
var _grab_tick := 0.0
var _grabbed: Node3D = null

func _ready() -> void:
	super._ready()
	_lie_down(0.0)

func _lie_down(blend := 0.6) -> void:
	if vis.quad != null:
		vis.quad.only("lie", blend)

func leash() -> float:
	return float(cfg.get("leash", 8.0))

func away_from_home() -> float:
	var d := global_position - home
	d.y = 0
	return d.length()

# ---------------------------------------------------------------- idle / bark
func _st_idle(dt: float) -> void:
	super._st_idle(dt)
	if state == ES.ALERT and not barked:
		# the first sight of the Bearer: sit up and bark, then fight
		barked = true
		_face(target.global_position - global_position, 1.0, 50.0)
		_begin_attack(attack_by_id("guard_bark"))

func _st_alert(dt: float) -> void:
	if vis.quad != null and vis.quad.weight("lie") > 0.0:
		vis.quad.set_pose("lie", 0.0, 0.35)   # up off the threshold
	super._st_alert(dt)

# ---------------------------------------------------------------- the leash
func _st_approach(dt: float) -> void:
	if _target_valid() and _beyond_leash(target.global_position):
		_go_home()
		return
	super._st_approach(dt)

func _st_combat(dt: float) -> void:
	if _target_valid() and _beyond_leash(target.global_position):
		_go_home()
		return
	super._st_combat(dt)

## The Bearer stands where the hound may not follow: out past its leash (with
## the lunge's reach allowed), or the hound itself has strayed too far.
func _beyond_leash(pos: Vector3) -> bool:
	var to := pos - home
	to.y = 0
	return away_from_home() > leash() or to.length() > leash() + float(attack_by_id("lunge_bite").get("range", 3.0))

func _go_home() -> void:
	target = null
	_end_all_swings()
	_set_state(ES.RETURN)

func _st_extra(dt: float) -> void:
	match state:
		ES.RETURN: _st_return(dt)
		ES.GRAB: _st_grab(dt)
		_: super._st_extra(dt)

func _st_return(dt: float) -> void:
	var to := home - global_position
	to.y = 0
	if to.length() < 0.5:
		velocity.x = 0
		velocity.z = 0
		_set_state(ES.IDLE)
		barked = false   # it will warn again
		_lie_down()
		return
	agent.target_position = home
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0
	if dir.length() < 0.05:
		dir = to
	dir = dir.normalized()
	var sp := float(cfg.get("speed", 3.6)) * 0.6
	velocity.x = move_toward(velocity.x, dir.x * sp, 10 * dt * sp)
	velocity.z = move_toward(velocity.z, dir.z * sp, 10 * dt * sp)
	_face(dir, dt)

# ---------------------------------------------------------------- the bite
func _strike() -> void:
	# a keyed strike (clip_meta strikes) already carries its own extension
	if String(_atk.get("id", "")) == "lunge_bite" and vis.quad != null and not vis.quad.striking():
		vis.quad.only("lunge", 0.06)
	super._strike()

func _on_hit_contact(hb: Area3D, result: String) -> void:
	super._on_hit_contact(hb, result)
	if result != "hit" or state != ES.ATTACK or String(_atk.get("id", "")) != "lunge_bite":
		return
	var p := _player()
	if p != null and from_behind(p):
		_begin_grab(p)

## Whether the hound is behind the Bearer: the angle between his facing and
## the direction to the hound passes the data threshold.
func from_behind(p: Node3D) -> bool:
	var pv: Node3D = p.get("vis")
	var facing := -(pv if pv != null else p).global_transform.basis.z
	facing.y = 0
	var to := global_position - p.global_position
	to.y = 0
	if to.length() < 0.01 or facing.length() < 0.01:
		return false
	var g: Dictionary = cfg.get("grab", {})
	return rad_to_deg(facing.normalized().angle_to(to.normalized())) > float(g.get("behind_deg", 100.0))

func _begin_grab(p: Node3D) -> void:
	var g: Dictionary = cfg.get("grab", {})
	_end_all_swings()
	_grabbed = p
	grab = GrabHold.start(self, p, float(g.get("max_time", 2.4)), int(g.get("mash", 6)))
	grab.released.connect(_on_grab_released)
	_grab_tick = 0.0
	_set_state(ES.GRAB)
	if vis.quad != null:
		vis.quad.only("hold", 0.08)
		vis.quad.shake = 1.0
	Juice.shake(0.35, 0.25)

func _st_grab(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	if _grabbed == null or not is_instance_valid(_grabbed):
		return
	# the Bearer is held at the jaws, his back to the hound
	var fwd := -vis.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var hold_at := global_position + fwd * 1.05
	hold_at.y = _grabbed.global_position.y
	_grabbed.global_position = _grabbed.global_position.lerp(hold_at, 1.0 - exp(-14.0 * dt))
	var g: Dictionary = cfg.get("grab", {})
	_grab_tick += dt
	if _grab_tick >= float(g.get("tick", 0.4)):
		_grab_tick = 0.0
		var hb: Hurtbox = _grabbed.get("hurtbox")
		if hb != null:
			var pk := DamagePacket.new(float(g.get("dmg", 6.0)), float(g.get("poise_dmg", 4.0)), self)
			pk.can_be_blocked = false
			pk.can_be_parried = false
			hb.receive(pk)
		Juice.shake(0.18, 0.12)

func _on_grab_released(broken: bool) -> void:
	grab = null
	_grabbed = null
	if vis.quad != null:
		vis.quad.shake = 0.0
	if dead:
		return
	if broken:   # shaken off: a short stagger, the window to answer
		_stagger(float(cfg.get("grab", {}).get("release_stagger", 1.2)))
	else:
		_set_state(ES.COMBAT)
		vis.idle()

func _die() -> void:
	if grab != null:
		grab.end(false)
	super._die()
