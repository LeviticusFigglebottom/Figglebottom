class_name Enemy
extends CharacterBody3D
## Data-driven enemy: deliberate, telegraphed, punishing. Lives in the rime
## layer; navigates the active navmesh; drops warmth.

signal died(enemy)
signal struck(enemy)

## RETURN, GRAB, INTRO, TRANSITION and HOLD belong to the slice's special
## foes (a hound walking back to its threshold, a hound's grab, a holdfast's
## intro, phase change and hold); the base ticks them through _st_extra().
enum ES { IDLE, ALERT, APPROACH, COMBAT, ATTACK, STAGGER, DEAD, RETURN, GRAB, INTRO, TRANSITION, HOLD }

var id := "rimewalker"
var cfg: Dictionary = {}
var hp := 50.0
var max_hp := 50.0
var poise := 30.0
## Poise-damage divisor. 1.0 normally; the summon glyph doubles it on a boss
## so a holdfast honored by an audience is twice as hard to stagger.
var stagger_resist := 1.0
var dead := false

var state: ES = ES.IDLE
var state_t := 0.0
var target: Node3D = null
var home := Vector3.ZERO

var _atk: Dictionary = {}
var _atk_done := false
var _cooldowns: Dictionary = {}
var _think_t := 0.0
var _strafe_dir := 1.0
var _blocking := false
var phase := 1
## An idle chore from the area data (spawner "pose"): "sit" = sitting at a
## chore, mending nothing (SLICE.md 5). Such a foe rises slowly when the
## Bearer comes into perception (data rise_time).
var idle_pose := ""
var _risen := true

# corner recovery: pursuing into a wall wedge used to pin bosses in place —
# wanting to move but making no ground. Track real progress; when wedged,
# steer along the most open probed direction for a beat, then resume.
var _prev_pos := Vector3.ZERO
var _stuck_t := 0.0
var _rec_t := 0.0
var _rec_dir := Vector3.ZERO

var vis: EnemyVisual
var agent: NavigationAgent3D
var hitbox: Hitbox
var hitbox_shape: CollisionShape3D
## Armed foes strike with the weapon itself: a box wrapping the mounted
## weapon's true extent, riding the weapon mount through the swing. The
## chest-projected `hitbox` remains for the unarmed and for attacks flagged
## "body_hitbox" (charges, horn butts).
var blade_hitbox: Hitbox
var _prop_strike: PropStrike = null   # the blade against props and walls (armed foes only)
## Unarmed humanoids (the rimewalker's grown ice clubs) strike with their
## hands: one hit volume whose sphere shapes ride the hand bones each tick
## (clip_meta.json models.<id>.unarmed). One Area per swing, so a two-handed
## blow still lands once.
var fist_hitbox: Hitbox
var _fists: Dictionary = {}   # "right"/"left" -> {shape, bone, offset}
var hurtbox: Hurtbox
var hpbar: EnemyHealthBar
## How far the last _stagger() stretched the punishable state (a parry buys
## a longer breath than a poise break).
var _stagger_mult := 1.0

## Everything this foe has put into the area: ridges, pools, holes, tells,
## thrown things, the summoned. They are the area's children, not the body's,
## so they outlived it: a wall stood on after its maker was reset, a tell
## glowed for a blow that would never land. _own() keeps each one;
## _fight_over() puts them away as each goes (death, release), and leaving
## the scene (a rest, the Bearer's death: the spawner's respawn) frees them.
var _made: Array = []

func _own(n: Node) -> Node:
	_made = _made.filter(func(m): return is_instance_valid(m) and not m.is_queued_for_deletion())
	if n != null:
		_made.append(n)
	return n

func _unmake(at_once := false) -> void:
	for n in _made:
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		if at_once:
			n.queue_free()
		else:
			put_away(n)
	_made.clear()

## One made thing goes the way it goes: a ridge shatters, a pool or a hole
## greys over, thorn sinks, the summoned fall, a thrown thing breaks in the
## air. A tell on the floor is only light: it is gone.
static func put_away(n: Node) -> void:
	if n is Enemy:
		var e := n as Enemy
		if e.dead:
			return
		if e.is_in_group(RH.GROUP_ENEMIES):
			e._die()
			return
	elif n.has_method("shatter"):
		n.shatter()
		return
	elif n.has_method("close"):
		n.close()
		return
	elif n.has_method("sink"):
		n.sink()
		return
	elif n.has_method("dispel"):
		n.dispel()
		return
	if n is Node3D and not (n is FloorTelegraph or n is IceCrack) and n.is_inside_tree():
		FrostDissolve.shards(n.get_parent(), (n as Node3D).global_position, 0.5)
	n.queue_free()

## The fight is over for this one (death or release): it holds nobody, hauls
## nobody, and nothing it made is left standing.
func _fight_over() -> void:
	if hook_hold != null:
		hook_hold.end(false)
	_pull_t = 0.0
	_unmake()

## The ring the Bearer is kept out of (player._part_from_foes): the
## visible body, not the thin nav capsule ("push_r" in enemies.json,
## else the larger of col_r and 90 % of hurt_r).
func push_radius() -> float:
	return float(cfg.get("push_r", maxf(float(cfg.get("col_r", 0.4)), float(cfg.get("hurt_r", 0.45)) * 0.9)))

func setup(enemy_id: String) -> void:
	id = enemy_id
	cfg = DB.enemy(id)

func _ready() -> void:
	if cfg.is_empty():
		cfg = DB.enemy(id)
	add_to_group("targetable")
	add_to_group(RH.GROUP_ENEMIES)
	collision_layer = 1 << (RH.L_ENEMY - 1)
	collision_mask = RH.M_WORLD_ALL | (1 << (RH.L_PLAYER - 1)) | (1 << (RH.L_ENEMY - 1))
	max_hp = float(cfg.get("hp", 50))
	hp = max_hp
	poise = float(cfg.get("poise", 30))
	stagger_resist = float(cfg.get("stagger_resist", 1.0))
	home = global_position

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(cfg.get("col_r", 0.4))
	cap.height = maxf(float(cfg.get("hurt_h", 1.6)), 1.2)
	cs.shape = cap
	cs.position.y = cap.height * 0.5 + 0.05
	add_child(cs)

	vis = EnemyVisual.new()
	vis.name = "Vis"
	add_child(vis)
	vis.build(cfg)

	agent = NavigationAgent3D.new()
	agent.radius = float(cfg.get("col_r", 0.4))
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 1.2
	agent.path_max_distance = 3.0
	add_child(agent)

	hurtbox = Hurtbox.new()
	hurtbox.team = "enemy"
	var hcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = float(cfg.get("hurt_r", 0.45))
	cyl.height = float(cfg.get("hurt_h", 1.6))
	hcs.shape = cyl
	hcs.position.y = cyl.height * 0.5
	hurtbox.add_child(hcs)
	add_child(hurtbox)

	hitbox = Hitbox.new()
	hitbox.exclude = self
	hitbox.friendly_team = "enemy"
	hitbox_shape = CollisionShape3D.new()
	hitbox_shape.shape = BoxShape3D.new()
	hitbox.add_child(hitbox_shape)
	vis.add_child(hitbox)
	hitbox.on_contact = _on_hit_contact
	_build_blade_hitbox()
	_build_fist_hitbox()
	_apply_idle_pose()

	# floating health bar for regular foes; bosses ride the big HUD bar instead
	if not cfg.get("is_boss", false):
		hpbar = EnemyHealthBar.new()
		hpbar.name = "HPBar"
		add_child(hpbar)
		var vs := float(cfg.get("vis_scale", 1.0))
		hpbar.build(clampf(float(cfg.get("hurt_r", 0.45)) * 2.6, 0.7, 1.7))
		hpbar.position.y = maxf(float(cfg.get("hurt_h", 1.6)), 1.2) * vs + 0.42
		hpbar.set_ratio(1.0)

func _physics_process(dt: float) -> void:
	if dead:
		return
	state_t += dt
	_sync_fists()   # the hands ride along every tick; only a swing arms them
	if hpbar != null:
		hpbar.set_forced(_is_locked_target())
	if not is_on_floor():
		velocity.y -= 22.0 * dt
	match state:
		ES.IDLE: _st_idle(dt)
		ES.ALERT: _st_alert(dt)
		ES.APPROACH: _st_approach(dt)
		ES.COMBAT: _st_combat(dt)
		ES.ATTACK: _st_attack(dt)
		ES.STAGGER: _st_stagger(dt)
		_: _st_extra(dt)
	move_and_slide()
	_tick_pull(dt)
	_track_progress(dt)
	# stride cycles while moving; action clips own the rig during ATTACK/STAGGER
	vis.locomotion(dt, Vector2(velocity.x, velocity.z).length(), Vector2.ZERO, is_on_floor())

## Wedge detection: wanting speed but gaining no ground for ~a second means a
## corner or prop has us. Probe eight directions and commit to the most open
## one (biased toward the target) for a short burst.
func _track_progress(dt: float) -> void:
	if state == ES.APPROACH or state == ES.COMBAT:
		var gained := Vector2(global_position.x - _prev_pos.x, global_position.z - _prev_pos.z).length() / maxf(dt, 1e-4)
		var wanted := Vector2(velocity.x, velocity.z).length()
		if wanted > 0.7 and gained < 0.3:
			_stuck_t += dt
		else:
			_stuck_t = maxf(0.0, _stuck_t - 2.0 * dt)
		if _stuck_t > 0.9:
			_stuck_t = 0.0
			_begin_recover()
	else:
		_stuck_t = 0.0
	_prev_pos = global_position

func _begin_recover() -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := (target.global_position - global_position).normalized()
	var space := get_world_3d().direct_space_state
	var best := Vector3.ZERO
	var best_score := -1e9
	for i in 8:
		var d := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / 8.0)
		var ray := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.9,
			global_position + Vector3.UP * 0.9 + d * 3.0, RH.M_WORLD_ALL)
		ray.exclude = [self]
		var hit := space.intersect_ray(ray)
		var clearance := 3.0
		if not hit.is_empty():
			clearance = ((hit["position"] as Vector3) - global_position).length()
		var score := clearance + to_target.dot(d) * 0.8
		if score > best_score:
			best_score = score
			best = d
	if best != Vector3.ZERO:
		_rec_dir = best
		_rec_t = 0.65
		_strafe_dir = -_strafe_dir

func _set_state(s: ES) -> void:
	state = s
	state_t = 0.0
	if s == ES.COMBAT:
		_tgt_smooth = Vector3.ZERO   # re-seed the delayed tracker on entry

func _player() -> Node3D:
	if Shot._cam_spec != "" and not Shot._trigger_gourd:
		return null
	return Game.player

func _can_see(p: Node3D) -> bool:
	var to := p.global_position - global_position
	if to.length() > float(cfg.get("aggro_sight", 10)):
		return false
	var fwd := -vis.global_transform.basis.z
	var half_fov: float = deg_to_rad(float(cfg.get("aggro_fov", 120)) * 0.5)
	if to.length() > float(cfg.get("aggro_hear", 4)) and fwd.angle_to(to.normalized()) > half_fov:
		return false
	# line of sight through world geometry
	var ray := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.4, p.global_position + Vector3.UP * 1.0, RH.M_WORLD_ALL)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Clear line of sight to the current target through world geometry — gates
## combat so foes never swing or fire through a wall. Cheap (one ray).
func _los_clear() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var ray := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.4, target.global_position + Vector3.UP * 1.0, RH.M_WORLD_ALL)
	ray.exclude = [self]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _face(dir: Vector3, dt: float, mult := 1.0) -> void:
	dir.y = 0
	if dir.length_squared() < 0.001:
		return
	var ty := atan2(-dir.x, -dir.z)
	vis.rotation.y = lerp_angle(vis.rotation.y, ty, 1.0 - exp(-float(cfg.get("turn", 5)) * mult * dt))

# ---------------------------------------------------------------- states
func _st_idle(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 8 * dt)
	velocity.z = move_toward(velocity.z, 0, 8 * dt)
	var p := _player()
	var pick: Node3D = null
	var best := 1e9
	var cands: Array = []
	if p != null and not p.get("dead") and p.get("state") != Player.S.REST:
		cands.append(p)
	cands.append_array(get_tree().get_nodes_in_group("allies"))
	for c in cands:
		if c == null or not is_instance_valid(c) or c.get("dead"):
			continue
		var dd: float = global_position.distance_to(c.global_position)
		if dd < best:
			best = dd
			pick = c
	if pick != null and _can_see(pick):
		target = pick
		_set_state(ES.ALERT)
		if cfg.has("sfx_alert"):
			AudioDirector.sfx_at(cfg["sfx_alert"], global_position, -2.0, randf_range(0.9, 1.1))

func _st_alert(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		_set_state(ES.IDLE)   # (roused with nobody to turn to)
		return
	if not _risen:
		# a sitter gets up first: slowly, the chore set down
		_risen = true
		var rise := float(cfg.get("rise_time", 1.8))
		vis.play("stand_up", 0.25, vis.clip_length("stand_up") / maxf(rise, 0.1))
		_rise_until = rise
	_face(target.global_position - global_position, dt, 1.6 if _rise_until <= 0.0 else 0.4)
	if state_t >= maxf(0.42, _rise_until):
		_rise_until = 0.0
		vis.idle(0.3)
		_set_state(ES.APPROACH)

var _rise_until := 0.0

## Idle chores (spawner "pose"): a looping clip held until the foe rises.
## sit = mending nothing (Saltfell); sit_up = one of the barrow dead, sat up
## facing the road; kneel = a keener at a closed door (LOWE.md 2);
## sit_feast = a guest in its seat at the long table (TARNHALL.md 5).
const IDLE_POSES := {"sit": "sit_mend", "sit_up": "sit_up", "kneel": "kneel_keen", "kneel_fish": "kneel_fish",
		"sit_feast": "sit_feast"}

func _apply_idle_pose() -> void:
	if idle_pose == "" or not vis.is_humanoid() or not IDLE_POSES.has(idle_pose):
		return
	vis.play(String(IDLE_POSES[idle_pose]), 0.0)
	_risen = false

## Re-path throttle (perf, Job 4): setting target_position queues a path
## query, so each foe re-targets only when the quarry has moved enough for the
## path to change (a tolerance that grows with distance) or every 0.3 s,
## staggered per foe. Steering still follows get_next_path_position() each frame.
var _nav_goal := Vector3(INF, INF, INF)
var _nav_t := 0.0

func _nav_retarget(dt: float, dist: float) -> void:
	_nav_t -= dt
	var tp := target.global_position
	var tol := maxf(0.35, dist * 0.08)
	if _nav_t <= 0.0 or _nav_goal.distance_squared_to(tp) > tol * tol:
		agent.target_position = tp
		_nav_goal = tp
		_nav_t = 0.3 + float(get_instance_id() % 7) * 0.01

func _st_approach(dt: float) -> void:
	if not _target_valid():
		return
	var dist := global_position.distance_to(target.global_position)
	if global_position.distance_to(home) > float(cfg.get("leash", 30)):
		target = null
		_set_state(ES.IDLE)
		return
	if dist <= _max_attack_range() * 0.9 and _los_clear():
		_set_state(ES.COMBAT)
		return
	var dir: Vector3
	if _rec_t > 0.0:
		# recovery burst: sidestep out of the wedge before re-pathing
		_rec_t -= dt
		dir = _rec_dir
	else:
		_nav_retarget(dt, dist)
		var next := agent.get_next_path_position()
		dir = (next - global_position)
	dir.y = 0
	dir = dir.normalized()
	var sp := float(cfg.get("speed", 2.5))
	velocity.x = move_toward(velocity.x, dir.x * sp, 10 * dt * sp)
	velocity.z = move_toward(velocity.z, dir.z * sp, 10 * dt * sp)
	_face(dir, dt)

## In combat, facing and strafing chase a SMOOTHED target position (~0.45 s
## behind the real one) so circling a foe actually gains angle — the old
## instant tracking made walking around anyone impractical. Range checks and
## attack picks still use the true distance; windup tracking stays live.
var _tgt_smooth := Vector3.ZERO

func _st_combat(dt: float) -> void:
	if not _target_valid():
		return
	var real_to := target.global_position - global_position
	var dist := real_to.length()
	if _tgt_smooth == Vector3.ZERO:
		_tgt_smooth = target.global_position
	_tgt_smooth = _tgt_smooth.lerp(target.global_position, 1.0 - exp(-2.2 * dt))
	var to := _tgt_smooth - global_position
	_face(to, dt, 0.8)
	# tick cooldowns
	for k in _cooldowns:
		_cooldowns[k] = maxf(0.0, _cooldowns[k] - dt)
	_think_t -= dt
	if dist > _max_attack_range() * 1.25:
		_set_state(ES.APPROACH)
		return
	# a wall came between us — close in instead of swinging through it
	if not _los_clear():
		_set_state(ES.APPROACH)
		return
	# a follow-up queued by a hook that landed ("then")
	if _then_atk != "" and _pull_t <= 0.0:
		var q := attack_by_id(_then_atk)
		_then_atk = ""
		if not q.is_empty() and dist <= float(q.get("range", 3.0)) + 0.6:
			_begin_attack(q)
			return
	# choose an attack that's off cooldown and in range
	var pick := _pick_attack(dist)
	if not pick.is_empty():
		_begin_attack(pick)
		return
	# reposition: slow strafe + keep spacing (singers back away instead)
	if _think_t <= 0.0:
		_think_t = randf_range(0.8, 1.6)
		# a pair works from opposite sides ("flank"): each keeps its own side
		if cfg.get("flank", false):
			_strafe_dir = 1.0 if get_instance_id() % 2 == 0 else -1.0
		else:
			_strafe_dir = -_strafe_dir if randf() < 0.4 else _strafe_dir
		_blocking = cfg.has("block_arc") and randf() < float(cfg.get("block_chance", 0.45))
	var fwd := to.normalized()
	var side := fwd.cross(Vector3.UP) * _strafe_dir
	var keep := float(cfg.get("keep_range", 0.0))
	var closing := clampf(dist - 2.0, -0.8, 0.7)
	if keep > 0.0:
		closing = clampf(dist - keep, -1.6, 0.5)
	var want := side * 1.1 + fwd * closing
	if _rec_t > 0.0:
		# strafing pinned us against a wall — burst along the open lane instead
		_rec_t -= dt
		want = _rec_dir * 1.4
	velocity.x = move_toward(velocity.x, want.x * float(cfg.get("speed", 2.5)) * 0.55, 6 * dt)
	velocity.z = move_toward(velocity.z, want.z * float(cfg.get("speed", 2.5)) * 0.55, 6 * dt)

func _target_valid() -> bool:
	if target == null or not is_instance_valid(target) or target.get("dead") == true:
		target = null
		_set_state(ES.IDLE)
		return false
	return true

func _max_attack_range() -> float:
	var m := 0.0
	for a in cfg.get("attacks", []):
		if _attack_allowed(a):
			m = maxf(m, float(a.get("range", 2)))
	return m

## Whether an attack is in this phase's repertoire and may be chosen freely.
## Data keys: "phases": [1, 2] (or the older phase1_only / phase2_only),
## "pick": false for moves only a trigger or a chain starts.
func _attack_allowed(a: Dictionary) -> bool:
	if a.get("phase2_only", false) and phase < 2:
		return false
	if a.get("phase1_only", false) and phase >= 2:
		return false
	if a.has("phases") and not (phase in a["phases"] or float(phase) in a["phases"]):
		return false
	return a.get("pick", true) and not a.get("chain_only", false)

## A subclass may veto a pick (e.g. "only if ridges stand").
func _attack_usable(_a: Dictionary) -> bool:
	return true

func _pick_attack(dist: float) -> Dictionary:
	var pool: Array = []
	for a in cfg.get("attacks", []):
		if not _attack_allowed(a) or not _attack_usable(a):
			continue
		# "behind_only": a move for whoever has got round it (the Frost-ram's kick)
		if a.get("behind_only", false) and not _target_behind():
			continue
		if dist <= float(a.get("range", 2)) and float(a.get("min_range", 0.0)) <= dist \
				and _cooldowns.get(a["id"], 0.0) <= 0.0:
			for i in int(a.get("weight", 1)):
				pool.append(a)
	if pool.is_empty():
		return {}
	return pool[randi() % pool.size()]

func _target_behind() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var to := target.global_position - global_position
	to.y = 0.0
	return to.length() > 0.05 and (-vis.global_transform.basis.z).dot(to.normalized()) < -0.35

func attack_by_id(aid: String) -> Dictionary:
	for a in cfg.get("attacks", []):
		if String(a.get("id", "")) == aid:
			return a
	return {}

## Timing multiplier for the current phase: data "phase_speed" ([p1, p2, p3]),
## else the old rule (a second phase runs 1.35x).
func _speed_mult() -> float:
	var ps: Array = cfg.get("phase_speed", [])
	if not ps.is_empty():
		return float(ps[clampi(phase - 1, 0, ps.size() - 1)])
	return 1.35 if phase >= 2 else 1.0

## Each attack clip is played at a speed that lands its CONTACT beat exactly
## when the hitbox opens (end of windup). The beats are data:
## data/anim/clip_meta.json (mannequin_contact, and per-clip sections for
## humanoids). Before this, clips ran at their authored duration while damage
## followed the data windup, so slow attacks visibly struck early.
func _begin_attack(a: Dictionary) -> void:
	# per-phase overrides ("by_phase": {"2": {"hits": [...]}}) ride on a copy
	var bp: Dictionary = a.get("by_phase", {})
	if bp.has(str(phase)):
		a = a.duplicate()
		a.merge(bp[str(phase)], true)
	_atk = a
	_atk_done = false
	_hit_i = 0
	_chained = false
	_blocking = false
	_cooldowns[a["id"]] = float(a.get("cooldown", 2.0))
	_set_state(ES.ATTACK)
	var anim_name: String = a.get("anim", "atk_r")
	var w := float(a.get("windup", 0.5)) / _speed_mult()
	vis.play_timed(anim_name, maxf(w, 0.05), 0.08, 0.0, INF, "@" + String(a.get("id", "")))
	_atk_dir = _aim_dir()
	_atk_off = _line_offset()
	_tele = null
	_tele_shown = false
	_crack = null
	_crack_shown = false
	_tgt_last = Vector3.INF
	_tgt_vel = Vector3.ZERO
	if a.has("telegraph"):
		_tele_at = w * float(a.get("telegraph_lock", 0.7))
	if a.has("sfx_windup"):
		AudioDirector.sfx_at(String(a["sfx_windup"]), global_position, -4.0)
	if a.has("breath"):
		breath_puff(String(a["breath"]), w)

## Seconds after the windup at which each strike of a multi-strike attack
## lands ("hits": [0, 0.22, 0.6]); one strike at 0 by default.
func _hit_times() -> Array:
	return _atk.get("hits", [0.0])

var _hit_i := 0
var _chained := false
var _atk_dir := Vector3.FORWARD
## Where a line strike starts along the aim: data "offset", or, for one laid
## where the Bearer stands ("at_target": true), centred on him at commit.
var _atk_off := 0.0

## The committed aim. "aim": "back" strikes behind the body (the Turfwright
## dropping the turf door on his back onto whoever stands there).
func _aim_dir() -> Vector3:
	var f := -vis.global_transform.basis.z
	return -f if String(_atk.get("aim", "front")) == "back" else f

func _line_offset() -> float:
	var off := float(_atk.get("offset", 0.0))
	if bool(_atk.get("at_target", false)) and target != null and is_instance_valid(target):
		var to := target.global_position - global_position
		to.y = 0.0
		var reach := float(_atk.get("range", 12.0))
		off = clampf(to.length(), 0.0, reach) - float(_atk.get("length", 3.0)) * 0.5
	return off
var _tele: Node = null
var _tele_at := -1.0
## Once per attack: a freed tell compares equal to null, so without this the
## recovery spawned a fresh 0.1 s glow every tick after the strike.
var _tele_shown := false
var _crack: Node = null
var _tgt_last := Vector3.INF
var _tgt_vel := Vector3.ZERO
var _crack_shown := false

func _st_attack(dt: float) -> void:
	_sync_blade()   # the blade box wears the weapon's frame through the swing
	var sm := _speed_mult()
	var w: float = float(_atk["windup"]) / sm
	var act: float = float(_atk["active"]) / sm
	var rec: float = float(_atk["recover"]) / sm
	var hits := _hit_times()
	var last: float = float(hits[hits.size() - 1]) / sm
	var t := state_t
	# how the target is really moving (a thrown thing leads it)
	if _target_valid() and dt > 0.0:
		if _tgt_last != Vector3.INF:
			_tgt_vel = _tgt_vel.lerp((target.global_position - _tgt_last) / dt, 0.3)
		_tgt_last = target.global_position
	# track the player through most of the windup, commit at the end
	if t < w * 0.7 and _target_valid():
		_face(target.global_position - global_position, dt, float(_atk.get("track", 1.2)))
		_atk_dir = _aim_dir()
		_atk_off = _line_offset()
	if state != ES.ATTACK:
		return
	# the floor tell appears once the aim is committed, and glows to the strike
	if _atk.has("telegraph") and not _tele_shown and t >= _tele_at:
		_tele_shown = true
		_tele = _spawn_telegraph(w - t)
	# ice about to break cracks first (crack_lead seconds before the strike),
	# the cracks following the aim until it commits
	if String(_atk.get("type", "")) == "break_ice":
		var lead := float(_atk.get("crack_lead", 1.0)) / sm
		if not _crack_shown and t >= w - lead:
			_crack_shown = true
			var ic: Dictionary = _atk.get("ice", {})
			_crack = _own(IceCrack.spawn(get_parent(), _ice_centre(), String(ic.get("shape", "disc")),
					float(ic.get("radius", 2.0)), float(ic.get("inner", 0.0)), w - t))
		elif _crack != null and is_instance_valid(_crack) and t < w * 0.7:
			(_crack as IceCrack).follow(_ice_centre())
	var in_strike := false
	for h in hits:
		var ht := w + float(h) / sm
		if t >= ht and t < ht + act:
			in_strike = true
	if in_strike and _prop_strike != null and _prop_strike.live():
		_sweep_props()
	if in_strike:
		var lunge := float(_atk.get("lunge", 1.5))
		velocity.x = _atk_dir.x * lunge
		velocity.z = _atk_dir.z * lunge
	else:
		velocity.x = move_toward(velocity.x, 0, 14 * dt)
		velocity.z = move_toward(velocity.z, 0, 14 * dt)
	# each strike in turn
	while _hit_i < hits.size() and t >= w + float(hits[_hit_i]) / sm:
		if _hit_i > 0:
			# the next strike re-arms the same volumes (begin_swing clears who
			# was struck); ending them first would land a deferred disable
			# after the re-arm and swallow the strike
			# a foe's own attack clip (ADR 0012) already carries its strike
			if _atk.has("hit_anim") and not vis.has_clip("@" + String(_atk.get("id", ""))):
				vis.play_timed(String(_atk["hit_anim"]), maxf(float(_atk.get("hit_lead", 0.12)), 0.05), 0.05)
		_strike()
		_hit_i += 1
	_atk_done = _hit_i > 0
	# between strikes the volumes stay armed but bite nothing (no packet):
	# re-arming next strike must not race a deferred disable
	if _atk_done and not in_strike and _hit_i < hits.size():
		for hb in [hitbox, blade_hitbox, fist_hitbox]:
			if hb != null:
				(hb as Hitbox).packet = null
	if vis.trail != null and _atk_done and t >= w + last + act:
		vis.trail.visible = false
	if _atk_done and t >= w + last + act and (hitbox.monitoring
			or (blade_hitbox != null and blade_hitbox.monitoring)
			or (fist_hitbox != null and fist_hitbox.monitoring)):
		_end_all_swings()
	# a follow-up flows out of the strike ("chain": "back_stroke")
	if _atk.has("chain") and not _chained and t >= w + last + act:
		_chained = true
		var nxt := attack_by_id(String(_atk["chain"]))
		if not nxt.is_empty() and randf() < float(_atk.get("chain_chance", 1.0)) and _target_valid():
			_begin_attack(nxt)
			return
	if t >= w + last + act + rec:
		_attack_finished()

## One strike of the current attack, by type (data-driven):
##   melee (default), ranged, summon, nova, line, net, haul, break_ice, hook,
##   sweep, lob, pool, alert.
func _strike() -> void:
	match _atk.get("type", "melee"):
		"ranged": _fire_projectiles()
		"summon": _summon()
		"nova": _ember_nova(float(_atk.get("nova_radius", 4.2)))
		"line": _line_strike()
		"net": _net_cast()
		"haul": _haul()
		"break_ice": _break_ice()
		"hook": _hook()
		"sweep": _sweep_strike()
		"lob": _lob()
		"pool": _pour_pool()
		"alert": _alert_others(float(_atk.get("radius", 15.0)))
		"none": pass
		_:
			_open_hitbox()
			_begin_prop_strike()
			if vis.trail != null:
				vis.trail.visible = true
			AudioDirector.foe(sfx_family(), "attack", global_position)
	if _atk.has("shockwave"):
		_shockwave.call_deferred(float(_atk["shockwave"]))

## Broken ice (KETTLE.md 5, 6): a disc of black water where the aim
## committed ("ice": {"shape": "disc", "radius", "life", "sink"}, centred on
## the Bearer with "at_target"), or a ring round the body ("shape": "ring",
## "inner"). "lead" opens a second hole where he is running to. The water
## takes whoever stays on it `sink` seconds; "shock" hurts whoever stands
## on it when it opens.
func _break_ice() -> void:
	var ic: Dictionary = _atk.get("ice", {})
	var shape := String(ic.get("shape", "disc"))
	var centre := _ice_centre()
	var holes: Array = [centre]
	if float(ic.get("lead", 0.0)) > 0.0 and target is CharacterBody3D:
		var v := (target as CharacterBody3D).velocity
		v.y = 0
		var ahead := target.global_position + v * float(ic.get("lead", 0.0))
		if ahead.distance_to(centre) > float(ic.get("radius", 2.0)) * 1.5:
			holes.append(Vector3(ahead.x, centre.y, ahead.z))
	for c in holes:
		var b := BrokenIce.open(get_parent(), c, shape, float(ic.get("radius", 2.0)), float(ic.get("inner", 0.0)),
				float(ic.get("life", 6.0)), float(ic.get("sink", 1.0)))
		_own(b)
		_on_broken_ice(b)
		var p := _player()
		if p != null and not p.get("dead") and b.covers(p.global_position) and float(ic.get("shock", 0.0)) > 0.0:
			var pk := DamagePacket.new(float(ic["shock"]), float(_atk.get("poise_dmg", 20)), self)
			pk.kind = "frost"
			pk.can_be_parried = false
			pk.can_be_blocked = false
			var hb: Hurtbox = p.get("hurtbox")
			if hb != null:
				hb.receive(pk)
	Juice.shake(float(_atk.get("shake", 0.35)), 0.25)

## Where the current break_ice attack opens: on the aim (a disc), or round
## the body (a ring).
func _ice_centre() -> Vector3:
	var centre := global_position
	if String((_atk.get("ice", {}) as Dictionary).get("shape", "disc")) != "ring":
		centre += Vector3(_atk_dir.x, 0, _atk_dir.z).normalized() * _atk_off
	return centre

## A subclass keeps the holes it broke (the Ice-Cutter closes them on release).
func _on_broken_ice(_b: BrokenIce) -> void:
	pass

## Hook (the Sealer's hook, the Ice-Cutter's trace): whatever stands in the
## strip ("length" x "width" from "offset") is caught, held "snare" seconds
## (mash to break), and if he does not break it, dragged to "haul_to"
## metres from the anchor (the body; a subclass may name another: the
## Ice-Cutter drags to his hole), then "then" follows.
var _then_atk := ""
var _pull_t := 0.0
var _pull_v := Vector3.ZERO
var _pull_body: CharacterBody3D = null
var hook_hold: GrabHold = null

func _hook() -> void:
	var p := _player()
	_hook_vfx()
	if p == null or p.get("dead"):
		return
	if not in_strip(p.global_position, float(_atk.get("length", 5.0)), float(_atk.get("width", 1.2)), _atk_off):
		return
	if p.has_method("is_invulnerable") and p.is_invulnerable():
		return
	var pk := DamagePacket.new(float(_atk.get("dmg", 8)), float(_atk.get("poise_dmg", 10)), self)
	pk.can_be_parried = false
	var hb: Hurtbox = p.get("hurtbox")
	if hb != null:
		hb.receive(pk)
	var snare := float(_atk.get("snare", 0.0))
	if snare > 0.0:
		hook_hold = GrabHold.start(self, p, snare, int(_atk.get("mash", 5)))
		hook_hold.released.connect(_on_hook_released.bind(p, float(_atk.get("haul_to", 1.5)),
				String(_atk.get("then", "")), float(_atk.get("pull_time", 0.5))))
	else:
		_on_hook_released(false, p, float(_atk.get("haul_to", 1.5)), String(_atk.get("then", "")),
				float(_atk.get("pull_time", 0.5)))

func _on_hook_released(broken: bool, p: Node3D, haul_to: float, then: String, secs: float) -> void:
	hook_hold = null
	if broken or dead or not is_instance_valid(p) or p.get("dead"):
		return
	var to := _hook_anchor() - p.global_position
	to.y = 0
	var d := to.length() - haul_to
	if d > 0.1 and p is CharacterBody3D:
		_pull_body = p
		_pull_v = to.normalized() * d / maxf(secs, 0.05)
		_pull_t = secs
	_then_atk = then

## Where a hook drags the Bearer to.
func _hook_anchor() -> Vector3:
	return global_position

func _tick_pull(dt: float) -> void:
	if _pull_t <= 0.0:
		return
	_pull_t -= dt
	if _pull_body != null and is_instance_valid(_pull_body):
		_pull_body.move_and_collide(_pull_v * dt)
	if _pull_t <= 0.0:
		_pull_body = null

## The line flying out along the strip: a quick streak of frost.
func _hook_vfx() -> void:
	var length := float(_atk.get("length", 5.0))
	_line_vfx(length, 0.3, _atk_off)

## The attack's whole timeline has run: back to circling (subclasses may
## queue a follow-up, e.g. the net cast's haul into a stitch).
func _attack_finished() -> void:
	_set_state(ES.COMBAT)
	vis.idle()

func _spawn_telegraph(remaining: float) -> Node:
	var tg: Dictionary = _atk["telegraph"]
	var kind := String(tg.get("shape", "rect"))
	var size: Array = tg.get("size", [1.0, 4.0])
	var xf := Transform3D(Basis.looking_at(_atk_dir, Vector3.UP), global_position)
	xf.origin += _atk_dir * (_atk_off if _atk.get("at_target", false) else float(tg.get("offset", 0.0)))
	var tint: Array = tg.get("color", [0.55, 0.8, 1.0])
	# a lobbed thing lands after its flight: the glow holds until then
	var flight := float((_atk.get("lob", {}) as Dictionary).get("flight", 0.0))
	return _own(FloorTelegraph.spawn(get_parent(), xf, kind, size, maxf(remaining, 0.1) + flight,
			Color(tint[0], tint[1], tint[2])))

## The frost-breath tell (SPEC.md 7): a plume from the mask a beat before a
## move. kind: "up" (rises straight up: Ship oars), "forward" (a snort),
## "held" (thin and slow: the Cast), "twice" (two puffs: the double fall).
func breath_puff(kind: String, over := 0.6) -> void:
	var head := global_position + Vector3.UP * float(cfg.get("hurt_h", 1.6)) * 0.95
	if vis.is_humanoid() and vis.skel != null and vis.skel.find_bone("mixamorig_Head") >= 0:
		head = vis.bone_xform("mixamorig_Head").origin + Vector3.UP * 0.08
	elif cfg.has("head_offset"):
		var ho: Array = cfg["head_offset"]
		head = vis.global_transform * Vector3(ho[0], ho[1], ho[2])
	var fwd := -vis.global_transform.basis.z
	var p := CPUParticles3D.new()
	p.amount = 26 if kind != "held" else 14
	p.lifetime = clampf(over, 0.4, 1.6)
	p.one_shot = true
	p.explosiveness = 0.2 if kind == "held" else 0.65
	p.direction = Vector3.UP if kind == "up" else (fwd + Vector3.UP * 0.3).normalized()
	p.spread = 12.0 if kind == "up" else 24.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.4 if kind != "held" else 0.6
	p.gravity = Vector3(0, 0.35, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	p.color = Color(0.9, 0.95, 1.0, 0.5)
	p.mesh = AreaPortal.make_mote_quad(1.0)
	get_parent().add_child(p)
	p.global_position = head + fwd * 0.18
	p.emitting = true
	RH.free_after(p, p.lifetime + 0.4)
	if kind == "twice":
		var tw := create_tween()
		tw.tween_interval(over * 0.45)
		tw.tween_callback(func():
			if is_instance_valid(p):
				p.restart())

## Ground-plane test against the committed aim: inside a strip `width` wide
## running `length` forward from `offset` metres ahead.
func in_strip(pos: Vector3, length: float, width: float, offset := 0.0) -> bool:
	var to := pos - global_position
	to.y = 0.0
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var along := to.dot(fwd) - offset
	var side := absf(to.dot(fwd.cross(Vector3.UP)))
	return along >= -0.4 and along <= length and side <= width * 0.5

## A line of ice along the floor (the Oarsman's ship-oars slam, the
## Netmender's Knot and Sea-weight): damages what stands in the strip, and may
## leave a ridge that blocks movement ("ridge": {"life": 10, "breaks": 2}).
func _line_strike() -> void:
	var length := float(_atk.get("length", 4.0))
	var width := float(_atk.get("width", 1.2))
	var offset := _atk_off
	var p := _player()
	if p != null and not p.get("dead") and in_strip(p.global_position, length, width, offset):
		var hb: Hurtbox = p.get("hurtbox")
		var pk := DamagePacket.new(float(_atk.get("dmg", 20)), float(_atk.get("poise_dmg", 20)), self)
		pk.kind = String(_atk.get("kind", "frost"))   # an ice line is frost unless data says not
		pk.can_be_parried = false
		pk.can_be_blocked = bool(_atk.get("blockable", true))
		if hb != null:
			hb.receive(pk)
	_line_vfx(length, width, offset)
	if _atk.has("ridge"):
		var rd: Dictionary = _atk["ridge"]
		var r := IceRidge.new()
		r.setup(length, float(rd.get("life", 10.0)), int(rd.get("breaks", 2)), String(rd.get("style", "ice")))
		get_parent().add_child(r)
		var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
		r.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), global_position + fwd * offset)
		_own(r)
		_on_ridge(r)
	Juice.shake(float(_atk.get("shake", 0.35)), 0.25)
	AudioDirector.play("foe/ground_slam", global_position)

## Ground-plane test against the committed aim: inside a fan of `arc`
## degrees round it, between `inner` and `radius` metres (arc 360 = a ring).
func in_fan(pos: Vector3, radius: float, arc: float, inner := 0.0) -> bool:
	var to := pos - global_position
	to.y = 0.0
	var d := to.length()
	if d > radius or d < inner:
		return false
	if arc >= 359.0 or d < 0.01:
		return true
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	return fwd.angle_to(to / d) <= deg_to_rad(arc * 0.5)

func _hit_player(p: Node, dmg: float, poise: float, kind := "physical", blockable := true) -> void:
	var hb: Hurtbox = p.get("hurtbox")
	var pk := DamagePacket.new(dmg, poise, self)
	pk.kind = kind
	pk.can_be_parried = false
	pk.can_be_blocked = blockable
	if hb != null:
		hb.receive(pk)

## A sweep (the Host's table coming round, a Cupbearer going round): what
## stands in the fan round the committed aim ("sweep": {"radius", "arc",
## "inner"}) is hit, and slid "shove" metres outward; if a wall or a bench
## stops the slide it is pinned there "pin" seconds (mash to break).
func _sweep_strike() -> void:
	var sw: Dictionary = _atk.get("sweep", {})
	var radius := float(sw.get("radius", 3.0))
	var arc := float(sw.get("arc", 120.0))
	var inner := float(sw.get("inner", 0.0))
	var p := _player()
	if p != null and not p.get("dead") and in_fan(p.global_position, radius, arc, inner) \
			and not (p.has_method("is_invulnerable") and p.is_invulnerable()):
		_hit_player(p, float(_atk.get("dmg", 20)), float(_atk.get("poise_dmg", 20)),
				String(_atk.get("kind", "physical")), bool(_atk.get("blockable", true)))
		var shove := float(sw.get("shove", 0.0))
		if shove > 0.0 and p is CharacterBody3D and not p.get("dead"):
			var out := p.global_position - global_position
			out.y = 0.0
			out = out.normalized() if out.length() > 0.05 else Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
			var dist := shove
			var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.6,
					p.global_position + Vector3.UP * 0.6 + out * (shove + 0.5), RH.M_WORLD_ALL)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			var pinned := not hit.is_empty()
			if pinned:
				dist = maxf(0.0, p.global_position.distance_to(hit["position"]) - 0.5)
			_pull_body = p
			_pull_t = float(sw.get("shove_time", 0.3))
			_pull_v = out * dist / _pull_t
			if pinned and float(sw.get("pin", 0.0)) > 0.0 and hook_hold == null:
				hook_hold = GrabHold.start(self, p, float(sw["pin"]), int(sw.get("mash", 4)))
				hook_hold.released.connect(func(_b): hook_hold = null)
				pinned_bearer.emit(p)
	_sweep_vfx(radius, arc, inner)
	Juice.shake(float(_atk.get("shake", 0.3)), 0.25)
	AudioDirector.play("foe/heavy_whoosh", global_position)

signal pinned_bearer(p)

func _sweep_vfx(radius: float, arc: float, inner: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = int(clampf(radius * arc / 12.0, 24, 200))
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius * 0.92
	p.emission_ring_inner_radius = maxf(inner, radius * 0.6)
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.color = Color(0.86, 0.92, 1.0, 0.8)
	p.mesh = AreaPortal.make_mote_quad(1.2)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 0.15
	p.emitting = true
	RH.free_after(p, 1.2)

## A lob (the Host's bench throw): something heavy leaves the hands at the
## strike and comes down "flight" seconds later on the committed spot
## ("at_target" puts it where the Bearer stood; "lob": {"radius", "flight",
## "lead", "size", "spread", "spread_r", "color"}). Whoever is inside "radius" when it lands is hit. With
## "lead" a second follows where he is running to, under its own glow.
var lobbed: Array = []
signal lob_landed(at: Vector3)

func _lob() -> void:
	var lb: Dictionary = (_atk.get("lob", {}) as Dictionary).duplicate()
	lb["dmg"] = float(_atk.get("dmg", 24))          # the hit rides with the throw:
	lb["poise_dmg"] = float(_atk.get("poise_dmg", 60))   # it lands after the attack ends
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var spots: Array = [global_position + fwd * _atk_off]
	var lead := float(lb.get("lead", 0.0))
	if lead > 0.0 and target is CharacterBody3D:
		var v := (target as CharacterBody3D).velocity
		if _tgt_vel.length() > v.length():
			v = _tgt_vel   # how the Bearer has actually been moving through the windup
		v.y = 0.0
		var ahead := target.global_position + v * lead
		if ahead.distance_to(spots[0]) > float(lb.get("radius", 2.0)) * 1.4:
			spots.append(Vector3(ahead.x, spots[0].y, ahead.z))
	# "spread": n throws in a ring round the first, "spread_r" out (a Collier's coals)
	var n_spread := int(lb.get("spread", 1))
	for i in range(1, n_spread):
		var a := TAU * float(i) / float(n_spread - 1) + randf() * 0.6
		spots.append(spots[0] + Vector3(cos(a), 0.0, sin(a)) * float(lb.get("spread_r", 2.0)))
	var flight := float(lb.get("flight", 0.5))
	var from := global_position + Vector3.UP * float(cfg.get("arm_h", 1.4)) * 1.2
	for i in spots.size():
		var at: Vector3 = spots[i]
		at.y = global_position.y
		if i > 0 and _atk.has("telegraph"):
			var tg: Dictionary = _atk["telegraph"]
			var tint: Array = tg.get("color", [0.55, 0.8, 1.0])
			_own(FloorTelegraph.spawn(get_parent(), Transform3D(Basis(), at), "ring", tg.get("size", [2.0]),
					flight + 0.15 * i, Color(tint[0], tint[1], tint[2])))
		_throw_one(from, at, flight + 0.15 * i, lb)
	AudioDirector.play("foe/heavy_whoosh", global_position, -2.0)

func _throw_one(from: Vector3, at: Vector3, flight: float, lb: Dictionary) -> void:
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var sz: Array = lb.get("size", [2.2, 0.45, 0.45])
	bm.size = Vector3(sz[0], sz[1], sz[2])
	body.mesh = bm
	var m := StandardMaterial3D.new()
	var lc: Array = lb.get("color", [0.27, 0.2, 0.14])
	m.albedo_color = Color(lc[0], lc[1], lc[2])
	m.roughness = 0.9
	body.material_override = m
	get_parent().add_child(body)
	body.global_position = from
	lobbed.append(body)
	_own(body)
	var peak := maxf(from.y, at.y) + float(lb.get("arc", 2.4))
	var fly := func(k: float) -> void:
		if not is_instance_valid(body):
			return
		var pos := from.lerp(at, k)
		pos.y = lerpf(lerpf(from.y, peak, k), lerpf(peak, at.y + 0.25, k), k)
		body.global_position = pos
		body.rotation = Vector3(k * 2.4, k * 0.8, 0.0)
	var tw := body.create_tween()
	tw.tween_method(fly, 0.0, 1.0, maxf(flight, 0.05))
	tw.tween_callback(_lob_land.bind(body, at, lb))

func _lob_land(body: Node3D, at: Vector3, lb: Dictionary) -> void:
	lobbed.erase(body)
	if is_instance_valid(body):
		body.rotation = Vector3(0, randf() * TAU, 0)
		var tw := body.create_tween()
		tw.tween_interval(1.4)
		tw.tween_property(body, "scale", Vector3(1, 0.05, 1), 0.4)
		tw.tween_callback(body.queue_free)
	if dead:
		return
	var p := _player()
	if p != null and not p.get("dead"):
		var d := Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		if d <= float(lb.get("radius", 2.0)):
			_hit_player(p, float(lb.get("dmg", 24)), float(lb.get("poise_dmg", 60)), "physical", false)
	_splinters(at)
	Juice.shake(0.4, 0.25)
	AudioDirector.play("foe/ground_slam", at)
	lob_landed.emit(at)

func _splinters(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.16
	p.color = Color(0.42, 0.32, 0.22, 1.0)
	p.mesh = AreaPortal.make_mote_quad(1.0)
	get_parent().add_child(p)
	p.global_position = at + Vector3.UP * 0.3
	p.emitting = true
	RH.free_after(p, 1.4)

## A pool (the Host tipping a horn): frost spreads across the floor from
## where it pours ("pool": {"from", "to", "grow", "life", "dmg", "tick"}),
## its edge glowing as it spreads; whoever stands on it takes frost every
## tick. A subclass keeps the pools it poured.
func _pour_pool() -> void:
	var pl: Dictionary = _atk.get("pool", {})
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var at := global_position + fwd * (_atk_off if _atk.get("at_target", false) else float(pl.get("ahead", 3.0)))
	var fp := FrostPool.spawn(get_parent(), at, float(pl.get("from", 1.2)), float(pl.get("to", 6.0)),
			float(pl.get("grow", 3.0)), float(pl.get("life", 8.0)), float(pl.get("dmg", 6.0)),
			float(pl.get("tick", 0.5)), self)
	_own(fp)
	_on_pool(fp)
	AudioDirector.play("foe/cast", at, -3.0)

func _on_pool(_fp: FrostPool) -> void:
	pass

## A subclass keeps the ridges it raised (the Netmender mends them).
func _on_ridge(_r: IceRidge) -> void:
	pass

func _line_vfx(length: float, width: float, offset: float) -> void:
	var fwd := Vector3(_atk_dir.x, 0, _atk_dir.z).normalized()
	var p := CPUParticles3D.new()
	p.amount = int(clampf(length * width * 10.0, 30, 220))
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.5, 0.1, length * 0.5)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.color = Color(0.8, 0.9, 1.0, 0.9)
	p.mesh = AreaPortal.make_mote_quad(1.4)
	get_parent().add_child(p)
	p.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP),
			global_position + fwd * (offset + length * 0.5) + Vector3.UP * 0.1)
	p.emitting = true
	RH.free_after(p, 1.2)

## Override points for the net and haul types (the Netmender).
func _net_cast() -> void:
	pass

func _haul() -> void:
	pass

## What it was waiting on has happened: it turns to the Bearer and comes.
func rouse() -> void:
	if dead:
		return
	var p := _player()
	if state == ES.IDLE and p != null:
		target = p
		_set_state(ES.ALERT)

## A warning to every frost-taken within `radius` (the Hearthhound's bark):
## each one idle turns toward the Bearer and comes.
func _alert_others(radius: float) -> int:
	var n := 0
	var p := _player()
	for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		var en := e as Enemy
		if en == null or en == self or en.dead or not en.can_process():
			continue
		if en.global_position.distance_to(global_position) > radius:
			continue
		if en.state == ES.IDLE and p != null:
			en.target = p
			en._set_state(ES.ALERT)
			n += 1
	Juice.shake(0.15, 0.2)
	AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 2.0, 1.4)
	return n

## The blade's own hit volume: merge the mounted weapon's mesh extents in
## mount space, wrap them with a hand's width of forgiveness, and hang the
## box off the enemy root as top_level — physics shapes must never inherit
## the body scale, so the mount's frame is copied in by hand each attack
## frame and the scale is baked into the box size once, here.
func _build_blade_hitbox() -> void:
	if vis == null or vis.weapon_mount == null:
		return
	var merged := AABB()
	var found := false
	for n in vis.weapon_mount.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var rel := Transform3D.IDENTITY
		var walk: Node3D = mi
		while walk != null and walk != vis.weapon_mount:
			rel = walk.transform * rel
			walk = walk.get_parent() as Node3D
		var ab := rel * mi.get_aabb()
		merged = ab if not found else merged.merge(ab)
		found = true
	if not found:
		return
	merged = merged.grow(0.17)
	# the mount's real scale: the mannequin's vis_scale, or 1 for a humanoid
	var s := vis.weapon_mount.global_transform.basis.get_scale().x
	blade_hitbox = Hitbox.new()
	blade_hitbox.exclude = self
	blade_hitbox.friendly_team = hitbox.friendly_team
	blade_hitbox.on_contact = _on_hit_contact
	blade_hitbox.top_level = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = merged.size * s
	shape.shape = box
	shape.position = merged.get_center() * s
	blade_hitbox.add_child(shape)
	add_child(blade_hitbox)
	_sync_blade()

func _sync_blade() -> void:
	if blade_hitbox == null or vis.weapon_mount == null:
		return
	var m := vis.weapon_xform()
	blade_hitbox.global_transform = Transform3D(m.basis.orthonormalized(), m.origin)

func _build_fist_hitbox() -> void:
	if vis == null or not vis.is_humanoid() or blade_hitbox != null:
		return
	var un: Dictionary = HumanoidLib.model_cfg(vis.model_id).get("unarmed", {})
	for side in ["right", "left"]:
		if not un.has(side):
			continue
		if fist_hitbox == null:
			fist_hitbox = Hitbox.new()
			fist_hitbox.name = "FistHitbox"
			fist_hitbox.exclude = self
			fist_hitbox.friendly_team = hitbox.friendly_team
			fist_hitbox.on_contact = _on_hit_contact
			fist_hitbox.top_level = true
			add_child(fist_hitbox)
		var c: Dictionary = un[side]
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = float(c.get("radius", 0.2))
		cs.shape = sph
		cs.disabled = true
		fist_hitbox.add_child(cs)
		var o: Array = c.get("offset", [0, 0, 0])
		_fists[side] = {"shape": cs, "bone": String(c["bone"]), "offset": Vector3(o[0], o[1], o[2])}
	_sync_fists()

## Shapes follow this tick's hand poses (the rig poses before we tick).
func _sync_fists() -> void:
	if fist_hitbox == null:
		return
	fist_hitbox.global_transform = Transform3D(Basis.IDENTITY, global_position)
	for side in _fists:
		var f: Dictionary = _fists[side]
		var p: Vector3 = vis.bone_xform(f["bone"]) * (f["offset"] as Vector3)
		(f["shape"] as CollisionShape3D).position = p - global_position

## The fist volume at `side` in world space (for tests and debug).
func fist_position(side: String) -> Vector3:
	return fist_hitbox.global_position + (_fists[side]["shape"] as CollisionShape3D).position

## An armed foe's blade raises chips and sparks from the world as the
## Bearer's does (game.json prop_hit foe_weapons), when he is near enough
## to see it. The unarmed and the far away trace nothing.
func _begin_prop_strike() -> void:
	if vis.weapon_mount == null or vis.trail == null or not bool(DB.tuning("prop_hit/foe_weapons", true)):
		return
	if target == null or not is_instance_valid(target) \
			or global_position.distance_to(target.global_position) > float(DB.tuning("prop_hit/foe_range", 28.0)):
		if _prop_strike != null:
			_prop_strike.end()
		return
	if _prop_strike == null:
		_prop_strike = PropStrike.new(self)
	_prop_strike.begin(false)

func _sweep_props() -> void:
	var xf := vis.weapon_xform()
	_prop_strike.sweep(get_world_3d().direct_space_state,
			xf * Vector3(0, float(vis.trail.get("base_up")), 0), xf * Vector3(0, float(vis.trail.get("tip_up")), 0))

func _end_all_swings() -> void:
	if fist_hitbox != null:
		fist_hitbox.end_swing()
		for side in _fists:
			(_fists[side]["shape"] as CollisionShape3D).set_deferred("disabled", true)
	if hitbox != null:
		hitbox.end_swing()
	if blade_hitbox != null:
		blade_hitbox.end_swing()

func _open_hitbox() -> void:
	var pk := DamagePacket.new(float(_atk.get("dmg", 10)), float(_atk.get("poise_dmg", 10)), self)
	pk.kind = String(_atk.get("kind", "physical"))   # armour absorbs per kind
	# an armed foe hits with the steel itself: the box riding the weapon
	# through the swing IS the attack — no arc gate, no chest projection.
	# "The sword never touched me" is now literally never a hit.
	if blade_hitbox != null and not _atk.get("body_hitbox", false):
		blade_hitbox.arc_node = vis
		blade_hitbox.arc_deg = 360.0
		blade_hitbox.occlude = true
		_sync_blade()
		blade_hitbox.begin_swing(pk)
		return
	# bare hands: the struck hand(s) are the attack, as the blade is above
	if fist_hitbox != null and not _atk.get("body_hitbox", false):
		var hands: Array = _atk.get("hands", ["right"])
		for side in _fists:
			(_fists[side]["shape"] as CollisionShape3D).disabled = not (side in hands)
		fist_hitbox.arc_node = vis
		fist_hitbox.arc_deg = 360.0
		fist_hitbox.occlude = true
		_sync_fists()
		fist_hitbox.begin_swing(pk)
		return
	var reach := float(_atk.get("reach", 1.8))
	(hitbox_shape.shape as BoxShape3D).size = Vector3(float(_atk.get("width", 1.8)),
			float(_atk.get("height", 1.5)), reach)
	hitbox.position = Vector3(0, float(cfg.get("arm_h", 1.2)) * 0.9, -reach * 0.5 - 0.3)
	# the swing only bites inside its arc (thrusts narrow, sweeps wide) and
	# never through world geometry — the box alone was a barn door
	hitbox.arc_node = vis
	hitbox.arc_deg = float(_atk.get("arc", 150.0))
	hitbox.occlude = true
	hitbox.begin_swing(pk)

## Ranged attacks sing projectiles: count/spread fan, aimed at the player's
## chest with light lead so strafing matters but walking works.
func _fire_projectiles() -> void:
	if not _target_valid():
		return
	var from := global_position + Vector3.UP * (float(cfg.get("arm_h", 1.3)) * float(cfg.get("vis_scale", 1.0)))
	from += -vis.global_transform.basis.z * 0.5
	var aim: Vector3 = target.global_position + Vector3.UP * 1.0
	if target is CharacterBody3D:
		aim += Vector3((target as CharacterBody3D).velocity.x, 0, (target as CharacterBody3D).velocity.z) * 0.22
	var dir := (aim - from).normalized()
	var count := int(_atk.get("count", 1))
	var spread := deg_to_rad(float(_atk.get("spread_deg", 14)))
	for i in count:
		var off := 0.0 if count == 1 else lerpf(-spread, spread, float(i) / float(count - 1))
		var d := dir.rotated(Vector3.UP, off)
		var pk := DamagePacket.new(float(_atk.get("dmg", 12)), float(_atk.get("poise_dmg", 8)), self)
		pk.kind = String(_atk.get("kind", "physical"))
		pk.can_be_parried = false
		# per-attack tint (ember rings burn gold; default frost-blue)
		var pc = _atk.get("proj_color", null)
		var tint := Color(0.62, 0.75, 1.0) if pc == null else Color(pc[0], pc[1], pc[2])
		_own(Projectile.launch(get_parent(), from, d, float(_atk.get("proj_speed", 9.0)), pk, tint))
	AudioDirector.sfx_at(cfg.get("sfx_cast", "foe/cast"),
			global_position, -8.0, 1.4)

## Summons: raise minions around the caster, capped alive.
var _minions: Array = []

## Leaving the scene (the spawner's respawn, the area put away): what it
## made goes with it, at once (nothing may be added to a tree being left).
func _exit_tree() -> void:
	_unmake(true)
	_minions.clear()

func _summon() -> void:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	var max_alive := int(_atk.get("max_alive", 2))
	var want := int(_atk.get("count", 2))
	var placed := 0
	for i in want:
		if _minions.size() >= max_alive:
			break
		var e := Enemy.new()
		e.setup(_atk.get("enemy", "rimewalker"))
		get_parent().add_child(e)
		var a := TAU * float(i) / float(want) + randf() * 0.8
		e.global_position = global_position + Vector3(cos(a) * 2.6, 0.1, sin(a) * 2.6)
		e.target = target
		e._set_state(ES.ALERT)
		_minions.append(e)
		_own(e)
		placed += 1
	if placed > 0:
		Juice.shake(0.3, 0.3)
		AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, -4.0, 1.3)

func _shockwave(radius: float) -> void:
	# ring burst on slam attacks (boss): damages if close to ground zero
	await get_tree().create_timer(0.05, false).timeout
	if not is_instance_valid(self) or not is_inside_tree() or dead:
		return
	var p := _player()
	if p != null and not p.get("dead"):
		var d := global_position.distance_to(p.global_position)
		# ground-zero only counts with a clear line — a pillar is real cover
		var seen := true
		if d < radius:
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0,
					p.global_position + Vector3.UP * 1.0, RH.M_WORLD_ALL)
			seen = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		if d < radius and seen and p.has_method("take_hit"):
			var hb: Hurtbox = p.get("hurtbox")
			var pk := DamagePacket.new(float(_atk.get("dmg", 20)) * 0.7, 20.0, self)
			pk.kind = String(_atk.get("kind", "physical"))
			pk.can_be_parried = false
			if hb != null:
				hb.receive(pk)
	_ring_vfx(radius)
	Juice.shake(0.5, 0.3)
	AudioDirector.play("foe/ground_slam", global_position, 2.0)

## The ember nova: summer kept by force. A held flash at the caster,
## then a gold ring that takes everyone standing in the office's radius.
## Full damage across the whole ring (unlike the slam's ground-zero rule) —
## the telegraph is the long overhead windup, and the answer is distance.
func _ember_nova(radius: float) -> void:
	var p := _player()
	if p != null and not p.get("dead"):
		var d := global_position.distance_to(p.global_position)
		var seen := true
		if d < radius:
			var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0,
					p.global_position + Vector3.UP * 1.0, RH.M_WORLD_ALL)
			seen = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		if d < radius and seen and p.has_method("take_hit"):
			var hb: Hurtbox = p.get("hurtbox")
			var pk := DamagePacket.new(float(_atk.get("dmg", 30)), float(_atk.get("poise_dmg", 35)), self)
			pk.kind = String(_atk.get("kind", _atk.get("nova_kind", "ember")))
			pk.can_be_parried = false
			if hb != null:
				hb.receive(pk)
	var frost := String(_atk.get("nova_kind", "ember")) == "frost"
	_ring_vfx(radius, not frost)
	if frost:   # a cold sweep (the Netmender's net train): no ember light
		Juice.shake(0.4, 0.28)
		AudioDirector.play("foe/heavy_whoosh", global_position)
		return
	# the ring itself burns gold, and a breath of light rides it out
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.9, 0.6)
	flash.light_energy = 5.0
	flash.omni_range = radius + 2.0
	flash.shadow_enabled = false
	get_parent().add_child(flash)
	flash.global_position = global_position + Vector3.UP * 1.2
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.55)
	tw.tween_callback(flash.queue_free)
	Juice.shake(0.4, 0.28)
	AudioDirector.play("world/fire_whoosh", global_position)

func _ring_vfx(radius: float, is_ember := false) -> void:
	var rcol := Color(1.0, 0.86, 0.48, 0.85) if is_ember else Color(0.78, 0.84, 0.96, 0.72)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.albedo_color = rcol
	tm.material = rmat
	ring.mesh = tm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.12, 0)
	ring.scale = Vector3.ONE * 0.42
	var rtw := ring.create_tween().set_parallel(true)
	rtw.tween_property(ring, "scale", Vector3(radius, 0.85, radius), 0.48) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	rtw.tween_property(rmat, "albedo_color:a", 0.0, 0.52)
	RH.free_after(ring, 0.75)

	var p := CPUParticles3D.new()
	p.amount = 110
	p.lifetime = 0.72
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.8
	p.emission_ring_inner_radius = 0.55
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 48.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 4.6
	p.gravity = Vector3(0, -6.5, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.11
	p.color = rcol
	p.mesh = AreaPortal.make_mote_quad(1.6)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 0.25
	p.emitting = true
	RH.free_after(p, 1.6)

func _on_hit_contact(_hb: Area3D, result: String) -> void:
	if result == "hit":
		Juice.shake(0.28, 0.2)
		if blade_hitbox != null:   # steel that lands cleaves; claws keep the thud
			AudioDirector.play("combat/hit_flesh", global_position, -2.0)
	elif result == "parried" and state != ES.STAGGER:
		# on_parried already bought the full riposte breath for foes who take
		# it; this shorter flinch is only for those who shrugged the parry —
		# it must never overwrite the long window
		_stagger(1.6)

## States a subclass adds (RETURN, GRAB, INTRO, TRANSITION, HOLD).
func _st_extra(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 10 * dt)
	velocity.z = move_toward(velocity.z, 0, 10 * dt)

func _st_stagger(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 10 * dt)
	velocity.z = move_toward(velocity.z, 0, 10 * dt)
	if state_t >= float(cfg.get("stagger_time", 0.9)) * _stagger_mult:
		_set_state(ES.COMBAT if target != null else ES.IDLE)
		vis.idle()

## mult stretches the whole punishable state, not just the clip: a parry's
## 2.6 buys 2.6x the foe's stagger_time to walk up and answer.
func _stagger(mult := 1.0) -> void:
	_end_all_swings()
	_stagger_mult = mult
	_set_state(ES.STAGGER)
	vis.play("stagger", 0.05, 1.0 / mult)

# ---------------------------------------------------------------- damage
func is_invulnerable() -> bool:
	return dead

func is_blocking_toward(from_pos: Vector3) -> bool:
	if not _blocking or not cfg.has("block_arc") or state == ES.ATTACK or state == ES.STAGGER:
		return false
	var to := from_pos - global_position
	to.y = 0
	var fwd := -vis.global_transform.basis.z
	return fwd.angle_to(to.normalized()) < deg_to_rad(float(cfg["block_arc"]) * 0.5)

func on_blocked_hit(packet: DamagePacket) -> void:
	var bdir := (global_position - packet.origin).normalized() if packet != null and packet.origin != Vector3.ZERO else vis.global_transform.basis.z
	vis.flinch(bdir, 0.65)
	AudioDirector.play("combat/hit_shield", global_position)

func _is_locked_target() -> bool:
	var p := Game.player
	if p == null or not is_instance_valid(p):
		return false
	var rig = p.get("cam")
	return rig != null and rig.locked_target == self

## Which family's sounds this foe makes (data/audio.json "families").
func sfx_family() -> String:
	return String(cfg.get("sfx_family", "taken"))

func take_hit(packet: DamagePacket) -> void:
	if dead:
		return
	struck.emit(self)
	hp -= packet.amount
	# "breaks_to": damage kinds that end it outright (the Unsung break when
	# sung at: every Song the Bearer has is one of these)
	if packet.kind in cfg.get("breaks_to", []):
		hp = 0.0
	poise -= packet.poise_damage / stagger_resist
	var hdir := (global_position - packet.origin).normalized() if packet.origin != Vector3.ZERO else vis.global_transform.basis.z
	vis.flinch(hdir, 1.0)
	AudioDirector.foe(sfx_family(), "hit", global_position + Vector3.UP)
	if hpbar != null:
		hpbar.hit(hp / max_hp)
	# aggro on pain even if unseen; a phantom's blade turns heads exactly
	# like the Bearer's (this is how the summon draws foes off you)
	if packet.source != null and is_instance_valid(packet.source) \
			and (packet.source.is_in_group("player") or packet.source.is_in_group("allies")):
		if target == null or packet.source.is_in_group("allies"):
			target = packet.source
		if state == ES.IDLE:
			_set_state(ES.ALERT)
	if hp <= 0.0:
		_die()
		return
	if poise <= 0.0:
		poise = float(cfg.get("poise", 30))
		_stagger()
	_check_phase()

## Boss phase gates (a subclass may run its own: the Netmender's three).
func _check_phase() -> void:
	if cfg.get("is_boss", false) and phase == 1 and hp <= max_hp * float(cfg.get("phase2_at", 0.5)):
		phase = 2
		_enrage()

func _enrage() -> void:
	_stagger(0.6)
	AudioDirector.sfx_at(cfg.get("sfx_alert", ""), global_position, 2.0, 0.85)
	Juice.shake(0.6, 0.6)

func receive_riposte(packet: DamagePacket) -> void:
	take_hit(packet)
	if not dead:
		_stagger(1.4)

func on_parried(_host) -> void:
	if cfg.get("is_boss", false):
		return   # most bosses shrug parries (a brief flinch via _on_hit_contact)
	_end_all_swings()
	var p := _player()
	if p != null and p.has_method("on_parry_success"):
		p.on_parry_success(self)
	_stagger(2.6)   # a parry buys a long breath: the riposte window

func _die() -> void:
	dead = true
	_set_state(ES.DEAD)
	_fight_over()
	if hpbar != null:
		hpbar.set_ratio(0.0)
		hpbar.dismiss()
	_end_all_swings()
	hurtbox.set_deferred("monitorable", false)
	collision_layer = 0
	vis.play("death", 0.06)
	Game.add_warmth(int(cfg.get("warmth", 10)))
	AudioDirector.foe(sfx_family(), "death", global_position)
	if cfg.has("drop_item") and Game.player != null:
		var di: Dictionary = cfg["drop_item"]
		var iid: String = di.get("id", "relic")
		Game.player.give_item(iid, 1)
		Game.toast.emit("Claimed %s." % di.get("label", iid))
	died.emit(self)
	_fade_out.call_deferred()

func _fade_out() -> void:
	# Tripo bodies carry imported StandardMaterial3Ds: give them the frost
	# dissolve first, or they would simply vanish at the end
	FrostDissolve.apply(vis)
	await get_tree().create_timer(float(cfg.get("death_linger", 2.6)), false).timeout
	if not is_instance_valid(self):
		return
	var dur := float(cfg.get("death_dissolve", 1.6))
	var t := 0.0
	var shattered := false
	while t < dur and is_instance_valid(self):
		t += get_process_delta_time()
		_set_dissolve(t / dur)
		if not shattered and t / dur > 0.4:
			shattered = true
			FrostDissolve.shards(get_parent(), global_position, float(cfg.get("hurt_h", 1.6)))
		await get_tree().process_frame
	if is_instance_valid(self):
		queue_free()

func _set_dissolve(v: float) -> void:
	RH.set_dissolve(vis, v)
