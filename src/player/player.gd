class_name Player
extends CharacterBody3D
## The Bearer. Deliberate, stamina-gated soulslike controller.
## States are explicit; every action spends before it swings. Combat numbers
## come from data (game.json + weapons/movesets), visuals from PlayerVisual.

signal health_changed(hp: float, max_hp: float)
signal stamina_changed(st: float, max_st: float)
signal gourds_changed(n: int, max_n: int)
signal died
signal state_changed(s: int)
signal hit_landed(target, result: String)
signal weapon_changed(id: String)
signal hotbar_changed
signal breath_changed(v: float, mx: float)
signal attune_changed(id: String)
signal inventory_changed
signal armour_changed

enum S { MOVE, ROLL, BACKSTEP, ATTACK, BLOCK, PARRY, RIPOSTE, GOURD, STAGGER, REST, TALK, DEAD }

# --- attributes & derived -------------------------------------------------
## Every point does something: heart holds life, wind the breath
## (cap AND recovery), might the sword and greatsword, craft the bow
## and spear, lungs the breath (cap AND warming), kinship the songs.
var attributes := {}   # filled at base_stat in _init
var breath := 0.0
var max_breath := 0.0               # stays 0 until the first song is learned
var _cast_cd := 0.0
var level := 1
var max_hp := 100.0
var hp := 100.0
var max_stamina := 80.0
var stamina := 80.0
var _winded := 0.0      # spent to zero: a beat of winded before attacking
var max_poise := 30.0
var poise := 30.0
var gourd_max := 3
var gourds := 3
var weapon_id := "hewing_blade"
var weapon_level := 0
var inventory: Dictionary = {}    # item_id -> count
## Worn armour, slot -> item id ("" = bare). Slots and the starting coat
## come from game.json player/armour; each piece's numbers from items.json.
var armour: Dictionary = {}

# --- state ------------------------------------------------------------------
var state: S = S.MOVE
var state_t := 0.0
var dead := false
var input_enabled := true
var _recap_cd := 0.0
## pointer-compat look: some machines (remote play, VMs, absolute-injected
## mice) never deliver RELATIVE motion to a captured window — m0 forever.
## Fallback: confine+hide the cursor, track its frame-to-frame movement in
## window pixels, warp it home only when it nears the rim. Auto-engages
## after 2.5 s of captured silence.
var look_compat := false
var _cap_dead_t := 0.0
var _dead_last_mp := Vector2i(-1000001, -1000001)   # starvation-probe cursor sample
var _cmp_last := Vector2(-1, -1)   # last cursor pos, WINDOW px; x<0 = resync
var _mo_n := 0           # motion events this window
var motion_rate := 0     # published events/second for the HUD diagnostics
var _mo_t := 0.0

# roll / iframes
var _iframe_from := 0.0
var _iframe_to := 0.0
var _roll_dir := Vector3.ZERO
var _roll_speed := 0.0
var _roll_dur := 0.0        # this roll's duration (its weight tier's), set as it starts

# attack
var _atk: Dictionary = {}
var _atk_is_heavy := false
var _combo_i := 0
var _atk_hit_open := false
var _queued: String = ""
var _lunge := 0.0
var _atk_kind := ""          # "light" | "heavy" | "sprint": which moveset entry is swinging
var _sprinting := false      # set by _st_move each frame the Bearer is at a sprint

# blocking / parry
var _blocking := false
var _parry_from := 0.0
var _parry_to := 0.0

# the bow: hold to draw, release to loose, RMB sights
var _bow_drawing := false
var _bow_t := 0.0

## The belt, slots 1-5: three blades, the bow, and the gourd.
var hotbar: Array = ["hewing_blade", "torch", "", "", "gourd"]
var attuned_song := ""    # the song bound to C, chosen in the Songs tab

# regen bookkeeping
var _stam_delay := 0.0
var _poise_delay := 0.0

# riposte: the parry primes a target for a WINDOW, not forever — roughly
# as long as the parried foe stays reeling
var _riposte_target: Node3D = null
var _riposte_t := 0.0

# out-of-bounds failsafe
var _last_ground := Vector3.ZERO

# brief interact lockout (in physics frames) so the key-press that closes a menu
# can't reopen it — only needs to outlast the closing press's one-frame bleed
var _interact_suppress := 0

var vis: PlayerVisual
var cam: CameraRig
var hitbox: Hitbox
var hitbox_shape: CollisionShape3D
var prop_strike: PropStrike     # the blade against props, walls and ground
var hurtbox: Hurtbox
var _interact_scan: Area3D
var _nadir_light: OmniLight3D

var sim_move := Vector3.ZERO      # sim driver writes camera-space intent here
var sim_active := false
var _floor_y := -INF                # last grounded height (step-up / stair snap)
var sim_block := false
var sim_sprint := false

@onready var T: Dictionary = DB.table("game")["player"]

func _init() -> void:
	for st in DB.tuning("levels/stats", ["heart", "wind", "might", "craft", "lungs", "kinship"]):
		attributes[String(st)] = base_stat()
	armour = starting_armour()

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 << (RH.L_PLAYER - 1)
	collision_mask = RH.M_WORLD_ALL | (1 << (RH.L_WORLD_LOW - 1))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.65
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)
	# stair snapping: stay on the ground walking down steps and deck edges
	floor_snap_length = maxf(floor_snap_length, float(T["move"].get("snap_down", 0.1)))

	vis = PlayerVisual.new()
	vis.name = "Vis"
	add_child(vis)
	# "model" (optional) selects a humanoid body; absent, the mannequin stands in
	vis.build(DB.weapon(weapon_id).get("kit", "hewing_blade"), body_model())

	cam = CameraRig.new()
	cam.name = "CamRig"
	add_child(cam)

	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.team = "player"
	var hcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38
	cyl.height = 1.6
	hcs.shape = cyl
	hcs.position.y = 0.85
	hurtbox.add_child(hcs)
	add_child(hurtbox)

	hitbox = Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.exclude = self
	hitbox.friendly_team = "player"   # a summoned comrade is never struck
	hitbox_shape = CollisionShape3D.new()
	hitbox_shape.shape = BoxShape3D.new()
	hitbox.add_child(hitbox_shape)
	vis.add_child(hitbox)
	hitbox.on_contact = _on_hit_contact
	prop_strike = PropStrike.new(self)

	_interact_scan = Area3D.new()
	_interact_scan.name = "InteractScan"
	_interact_scan.collision_layer = 0
	_interact_scan.collision_mask = 1 << (RH.L_INTERACT - 1)
	var ics := CollisionShape3D.new()
	var isph := SphereShape3D.new()
	isph.radius = 1.9
	ics.shape = isph
	ics.position.y = 0.9
	_interact_scan.add_child(ics)
	add_child(_interact_scan)

	_nadir_light = OmniLight3D.new()
	_nadir_light.name = "NadirLight"
	_nadir_light.position = Vector3(0, 1.25, 0)
	_nadir_light.omni_range = 3.8
	_nadir_light.omni_attenuation = 1.65
	_nadir_light.light_energy = 0.32
	_nadir_light.light_color = Color(1.0, 0.76, 0.46)
	_nadir_light.shadow_enabled = false
	add_child(_nadir_light)

	recompute_derived()
	hp = max_hp
	stamina = max_stamina
	poise = max_poise
	Game.register_player(self)
	_emit_all()
	look_compat = bool(PauseUI.settings.get("look_compat", false))
	if not sim_active:
		_grab_mouse(true)

func recompute_derived() -> void:
	var base: Dictionary = T["base"]
	var per: Dictionary = T["per_level"]
	max_breath = (70.0 + _over_base("lungs") * 7.0) if knows_any_song() else 0.0
	breath = minf(breath, max_breath)
	max_hp = float(base["hp"]) + _over_base("heart") * float(per["heart_hp"])
	max_stamina = float(base["stamina"]) + _over_base("wind") * float(per["wind_stamina"])
	max_poise = float(base["poise"]) + worn_poise()
	poise = minf(poise, max_poise)

func _emit_all() -> void:
	health_changed.emit(hp, max_hp)
	stamina_changed.emit(stamina, max_stamina)
	gourds_changed.emit(gourds, gourd_max)

# --------------------------------------------------------------- input
## The camera only receives relative motion reliably while the mouse is
## captured. Capture engages on the first click (a user gesture — required
## by browsers for pointer-lock), Esc frees the cursor, clicking back in
## recaptures it. The recapturing click is swallowed so it doesn't also swing.
func _grab_mouse(on: bool) -> void:
	if not on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN if look_compat \
				else Input.MOUSE_MODE_CAPTURED

func _captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			or Input.mouse_mode == Input.MOUSE_MODE_CONFINED_HIDDEN

## Mouse-bound combat actions (LMB swing / RMB block) stay quiet while the
## cursor is free, so clicking back into the window doesn't also attack.
func _mouse_ok() -> bool:
	return sim_active or _captured()

## True while a modal owns the keys (hearth rest menu / dialogue) — the pause
## menu refuses to open over these; they close on their own terms.
func busy_in_menu() -> bool:
	return state == S.REST or state == S.TALK \
			or not get_tree().get_nodes_in_group("inventory_ui").is_empty() \
			or not get_tree().get_nodes_in_group("lore_open").is_empty()

## Mouse-look lives in _input (fires before any UI) so no Control can eat the
## motion. Guarded on capture + control so it never fires during menus/talk.
## Esc belongs to PauseUI (opening the menu frees the cursor; closing it
## recaptures) — clicking back into the window still reclaims after any
## other focus loss.
func _input(event: InputEvent) -> void:
	if sim_active:
		return
	if event is InputEventMouseMotion:
		_mo_n += 1
		# look works from relative motion even if the OS refuses the capture
		# grab (remote desktop, overlays): degraded but never dead. Menus and
		# dialogue still own the cursor.
		if input_enabled and not look_compat and (_captured() or (not PauseUI.is_open()
				and state != S.REST and state != S.TALK)):
			cam.mouse_look(event.relative)
		return
	if event is InputEventMouseButton and event.pressed and not _captured() \
			and not PauseUI.is_open():
		# reclaim the cursor; consume the click so it isn't also an attack
		_grab_mouse(true)
		get_viewport().set_input_as_handled()

# ------------------------------------------------------ dialogue control
## Talking freezes the Bearer in a dedicated state so no action (least of
## all a re-interact) can fire. Control is restored one frame LATE on exit so
## the same keypress that closed the menu can't reopen it.
func enter_dialogue() -> void:
	input_enabled = false
	velocity = Vector3.ZERO
	_set_state(S.TALK)
	# TALK skips locomotion updates; a live walk/run cycle would jog in place
	if vis != null and vis.current_clip() in ["walk", "run"]:
		vis.play("idle", 0.2)

func exit_dialogue() -> void:
	_finish_dialogue.call_deferred()

func _finish_dialogue() -> void:
	if state == S.TALK:
		_set_state(S.MOVE)
	input_enabled = true
	# standard reopen prevention: the press that closed the dialogue (or an
	# eager follow-up tap) must not immediately re-enter it
	suppress_interact(10)
	vis.back_to_idle()

func _move_input() -> Vector3:
	if sim_active:
		return sim_move
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector3(v.x, 0, v.y)

# --------------------------------------------------------------- physics
func _physics_process(dt: float) -> void:
	state_t += dt
	# capture watchdog: whenever the focused window should own the cursor and
	# doesn't — first frame after boot, alt-tab return, an OS quirk dropping
	# the grab — take it back. Interval-gated: on machines where capture is
	# refused outright, per-frame attempts would warp the pointer every frame.
	_mo_t += dt
	if _mo_t >= 1.0:
		motion_rate = _mo_n
		_mo_n = 0
		_mo_t = 0.0
	_recap_cd = maxf(0.0, _recap_cd - dt)
	var play_owns := not sim_active and not dead and input_enabled \
			and not PauseUI.is_open() and state != S.REST and state != S.TALK
	if play_owns and not _captured() and get_window().has_focus() and _recap_cd == 0.0:
		_grab_mouse(true)
		_recap_cd = 0.5
	# pointer-compat auto-engage keys on the REMOTE-DESKTOP signature: the
	# cursor POSITION drifts while relative motion is starved (injected
	# absolute moves bypass the capture grab). An untouched mouse produces
	# neither, so normal play can idle forever without tripping this —
	# the old idle-timer version flipped compat on for anyone who stood
	# still 2.5 s and then their look went through the warp loop for the
	# rest of the session.
	if play_owns and not look_compat and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and get_window().has_focus():
		var mp := DisplayServer.mouse_get_position()
		var pos_moved := _dead_last_mp.x > -1000000 and mp != _dead_last_mp
		_dead_last_mp = mp
		if _mo_n > 0 or motion_rate > 0:
			_cap_dead_t = 0.0
		elif pos_moved:
			_cap_dead_t += dt
		if _cap_dead_t > 1.2:
			look_compat = true
			_grab_mouse(true)
	else:
		_dead_last_mp = Vector2i(-1000001, -1000001)
	# compat look: frame-to-frame cursor movement is the look delta, all in
	# WINDOW pixels. Viewport coords are content-scaled and disagree with
	# warp_mouse's client pixels on a stretched/maximized window — mixing
	# the two spaces injected a phantom offset every frame (constant pitch
	# push + erratic yaw). The cursor roams an inner region and is only
	# warped home from the rim; after a warp we resync instead of trusting
	# it landed, since remote layers can apply warps a frame late.
	if look_compat and play_owns and _captured() and get_window().has_focus():
		var win := get_window()
		var c := Vector2(win.size) * 0.5
		var m := Vector2(DisplayServer.mouse_get_position() - win.position)
		var dmm := m - _cmp_last
		if _cmp_last.x >= 0.0 and dmm != Vector2.ZERO:
			cam.mouse_look(dmm)
		_cmp_last = m
		if absf(m.x - c.x) > c.x * 0.5 or absf(m.y - c.y) > c.y * 0.5:
			Input.warp_mouse(c)
			_cmp_last = Vector2(-1, -1)
	else:
		_cmp_last = Vector2(-1, -1)
	if _interact_suppress > 0:
		_interact_suppress -= 1
	if not is_on_floor():
		velocity.y -= 22.0 * dt
	else:
		velocity.y = maxf(velocity.y, -0.5)
		if state == S.MOVE and global_position.y > -20.0:
			_last_ground = global_position
	# failsafe: geometry should make this unreachable, but never fall forever
	if global_position.y < -25.0 and not dead:
		global_position = _last_ground + Vector3.UP * 0.6
		velocity = Vector3.ZERO
		hp = maxf(hp - max_hp * 0.25, 1.0)
		health_changed.emit(hp, max_hp)
		Juice.shake(0.4, 0.25)

	match state:
		S.MOVE: _st_move(dt)
		S.ROLL: _st_roll(dt)
		S.BACKSTEP: _st_backstep(dt)
		S.ATTACK: _st_attack(dt)
		S.BLOCK: _st_block(dt)
		S.PARRY: _st_parry(dt)
		S.RIPOSTE: _st_riposte(dt)
		S.GOURD: _st_gourd(dt)
		S.STAGGER: _st_stagger(dt)
		S.REST, S.TALK, S.DEAD:
			velocity.x = move_toward(velocity.x, 0, 20 * dt)
			velocity.z = move_toward(velocity.z, 0, 20 * dt)

	_regen(dt)
	_step_up(dt)
	move_and_slide()
	_part_from_foes()
	if is_on_floor():
		_floor_y = global_position.y
	elif _floor_y - global_position.y >= -0.05 and _floor_y - global_position.y < float(T["move"].get("snap_down", 0.0)):
		_snap_down()
	_unwedge(dt)
	_unpin()

	var gs := Vector2(velocity.x, velocity.z).length()
	var lean := Vector2.ZERO
	if state == S.MOVE:
		var lv := vis.global_transform.basis.inverse() * velocity
		lean = Vector2(lv.x, -lv.z) * 0.12
	_apply_outfit()
	# held poses (kneel at rest, death) must not blend back to idle
	if state != S.DEAD and state != S.REST and state != S.TALK:
		vis.locomotion(dt, gs, lean, is_on_floor())
	if _nadir_light != null:
		var bt: float = (1.0 if Game.area_state() == RH.WState.RIME else 0.0)
		_nadir_light.light_color = Color(1.0, 0.76, 0.46).lerp(Color(0.90, 0.78, 0.58), bt * 0.55)
		_nadir_light.light_energy = lerpf(0.28, 0.48, bt)
	if not sim_active:
		cam.stick_look(Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down"), dt)

## Bodies keep their room. The Bearer's capsule does not collide with the
## frost-taken (a hard contact wedged him on a 3 m Holdfast and let him
## clip into her), so after each move he is eased back out of any foe's
## body ring (combat/body_push in game.json, the foe's push_radius()). A
## roll or backstep passes straight through, as before: the i-frame dodge
## through a swing is part of the feel. Walking and lunging stop at the
## body instead of inside it.
func _part_from_foes() -> void:
	if dead or state == S.ROLL or state == S.BACKSTEP:
		return
	var my_r := float(DB.tuning("combat/body_push/bearer_r", 0.34))
	var max_step := float(DB.tuning("combat/body_push/max_step", 0.25))
	for node in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
		var e := node as Enemy
		if e == null or e.dead or not e.is_inside_tree() or not e.can_process() or not e.is_visible_in_tree():
			continue
		if absf(e.global_position.y - global_position.y) > 2.0:
			continue
		var d := global_position - e.global_position
		d.y = 0.0
		var reach := my_r + e.push_radius()
		var l := d.length()
		if l >= reach:
			continue
		var n := d / l if l > 0.001 else Vector3(vis.global_transform.basis.z.x, 0.0, vis.global_transform.basis.z.z).normalized()
		# a collide-move, so being pushed never shoves him through a wall
		move_and_collide(n * minf(reach - l, max_step))
		var inward := -velocity.dot(n)
		if inward > 0.0:
			velocity += n * inward

func _set_state(s: S) -> void:
	if s != S.MOVE:
		_sprinting = false
	if s == S.MOVE:
		apply_carry_pose()
	if state == S.GOURD and s != S.GOURD:
		_show_gourd(false)   # a stagger or a death mid-drink drops the gourd
		if vis.shield_mount != null:
			vis.shield_mount.visible = not bool(weapon_data().get("two_handed", false))
	state = s
	state_t = 0.0
	if s != S.MOVE:
		if _bow_drawing:
			_nock_arrow(false)   # a roll, a stagger, a menu — the arrow is lost
		_bow_drawing = false
		cam.zoomed = false
	state_changed.emit(s)

# Safety net: convex prop colliders already prevent wedging, but if the
# player ever ends a frame DEEP inside a static body (spawn on a prop, a
# state-swap materializing geometry around them), push straight out. The
# depth gate keeps normal wall-resting (shallow contact) from triggering,
# so this never fights ordinary sliding.
var _wedge_t := 0.0
const _WEDGE_DEPTH := 0.12
## Step up onto a kerb, threshold or deck edge no higher than move/step_height
## (game.json). A capsule on move_and_slide alone stops dead at any ledge
## taller than its own rounding. Probe: blocked ahead by something wall-like ->
## room to rise -> free ahead once risen -> walkable ground under that point.
## Then lift the body by the measured rise and let move_and_slide carry on.
func _step_up(dt: float) -> void:
	# (just lifted onto a step counts as grounded: the next riser may come
	# before move_and_slide has settled the feet)
	if dead or not (is_on_floor() or absf(global_position.y - _floor_y) < 0.05):
		return
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if hv.length_squared() < 0.01:
		return
	var step_h := float(T["move"].get("step_height", 0.0))
	if step_h <= 0.0:
		return
	var probe := hv.normalized() * maxf(hv.length() * dt, float(T["move"].get("step_probe", 0.12)))
	var p := PhysicsTestMotionParameters3D.new()
	var r := PhysicsTestMotionResult3D.new()
	p.margin = safe_margin
	p.from = global_transform
	p.motion = probe
	p.max_collisions = 4
	if not PhysicsServer3D.body_test_motion(get_rid(), p, r):
		return                                   # nothing ahead
	var wall := false
	for i in r.get_collision_count():
		wall = wall or r.get_collision_normal(i).y <= 0.75
	if not wall:
		return                                   # only floor or a slope: move_and_slide walks it
	p.max_collisions = 1
	p.motion = Vector3.UP * step_h
	if PhysicsServer3D.body_test_motion(get_rid(), p, r):
		return                                   # no headroom
	var up := global_transform
	up.origin.y += step_h
	p.from = up
	p.motion = probe
	if PhysicsServer3D.body_test_motion(get_rid(), p, r):
		return                                   # still blocked: too tall to step
	var fwd := up
	fwd.origin += probe
	p.from = fwd
	p.motion = Vector3.DOWN * (step_h + 0.05)
	if not PhysicsServer3D.body_test_motion(get_rid(), p, r):
		return
	if r.get_collision_normal().y < cos(floor_max_angle):
		return                                   # would stand on something too steep
	var rise := step_h - r.get_travel().length()
	if rise <= 0.02:
		return
	global_position.y += rise + 0.01
	_floor_y = global_position.y
	velocity.y = maxf(velocity.y, 0.0)

## Stair snapping past a step's edge: the capsule's rounded foot rolls over the
## nosing, where the contact is too steep to count as floor and the built-in
## snap lets go. Look straight down instead; if walkable ground lies within
## move/snap_down, set the Bearer on it once the body clears the nosing.
func _snap_down() -> void:
	if dead or velocity.y > 0.0:
		return
	var snap := float(T["move"].get("snap_down", 0.0))
	if snap <= 0.0:
		return
	var from := global_position + Vector3.UP * 0.2
	var q := PhysicsRayQueryParameters3D.create(from, Vector3(global_position.x, minf(_floor_y, global_position.y) - snap, global_position.z), collision_mask)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit["normal"].y < cos(floor_max_angle):
		return
	var to := global_transform
	to.origin.y = hit["position"].y + 0.01
	var p := PhysicsTestMotionParameters3D.new()
	p.from = to
	p.motion = Vector3.ZERO
	p.margin = safe_margin
	p.recovery_as_collision = true
	if PhysicsServer3D.body_test_motion(get_rid(), p):
		return                                   # still over the nosing
	global_position = to.origin
	velocity.y = 0.0
	apply_floor_snap()

func _unwedge(dt: float) -> void:
	if dead:
		return
	# zero-motion probe with recovery-as-collision reports a resting overlap
	var col := move_and_collide(Vector3.ZERO, true, 0.001, true)
	if col == null or col.get_depth() <= _WEDGE_DEPTH:
		_wedge_t = 0.0
		return
	_wedge_t += dt
	if _wedge_t < 0.2:
		return
	# resolve it fully this frame: push out along each contact normal
	for _i in 8:
		var c := move_and_collide(Vector3.ZERO, true, 0.001, true)
		if c == null or c.get_depth() <= _WEDGE_DEPTH:
			break
		var n := c.get_normal()
		n.y = 0.0
		if n.length_squared() < 0.01:
			n = (global_position - c.get_position()) * Vector3(1, 0, 1)
		if n.length_squared() < 0.001:
			n = Vector3(0.3, 0, 0.3)   # truly ambiguous — nudge diagonally
		global_position += n.normalized() * maxf(c.get_depth(), 0.15)
	velocity = Vector3.ZERO
	_wedge_t = 0.0

## Second safety net: a capsule resting on the ground with its side exactly
## on a box collider's upright edge (the end of a hedge section) can be held
## by the solver: every motion test, even straight away from the box, travels
## nothing, with only the floor reported and no wall. Found by the Thornwold
## maze walk at a thorn hedge's end. A hair of lift breaks the contact; the
## floor snap sets him down again a step further on.
var _pin_ticks := 0
const _PIN_TICKS := 3
const _PIN_LIFT := 0.02
func _unpin() -> void:
	var want := Vector2(velocity.x, velocity.z).length()
	var real := get_real_velocity()
	if dead or want < 1.0 or is_on_wall() or not is_on_floor() or Vector2(real.x, real.z).length() > 0.02:
		_pin_ticks = 0
		return
	_pin_ticks += 1
	if _pin_ticks >= _PIN_TICKS:
		global_position.y += _PIN_LIFT
		_pin_ticks = 0

func _face(dir: Vector3, dt: float, speed := 11.0) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target := atan2(-dir.x, -dir.z)
	vis.rotation.y = lerp_angle(vis.rotation.y, target, 1.0 - exp(-speed * dt))

func _desired_dir() -> Vector3:
	var mi := _move_input()
	if mi.length_squared() < 0.0001:
		return Vector3.ZERO
	return (cam.move_basis() * Vector3(mi.x, 0, mi.z)).normalized()

func _spend(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stam_delay = float(T["stamina"]["regen_delay"])
	if stamina <= 0.0:
		_winded = 0.5   # the empty bar costs a beat before the next swing
	stamina_changed.emit(stamina, max_stamina)

func _regen(dt: float) -> void:
	_winded = maxf(_winded - dt, 0.0)
	_no_atk_toast = maxf(_no_atk_toast - dt, 0.0)
	_riposte_t = maxf(_riposte_t - dt, 0.0)
	if _riposte_t <= 0.0:
		_riposte_target = null
	# stamina
	if _stam_delay > 0.0:
		_stam_delay -= dt
	elif stamina < max_stamina and state != S.ROLL and state != S.ATTACK and state != S.RIPOSTE:
		var mult: float = float(T["stamina"]["regen_block_mult"]) if _blocking else 1.0
		mult *= 1.0 + _over_base("wind") * 0.02   # wind quickens the breath
		stamina = minf(stamina + float(T["stamina"]["regen"]) * mult * dt, max_stamina)
		stamina_changed.emit(stamina, max_stamina)
	if max_breath > 0.0 and breath < max_breath:
		breath = minf(breath + (3.5 + _over_base("lungs") * 0.45) * dt, max_breath)
		breath_changed.emit(breath, max_breath)
	if _cast_cd > 0.0:
		_cast_cd -= dt
	# poise
	if _poise_delay > 0.0:
		_poise_delay -= dt
	elif poise < max_poise:
		poise = minf(poise + float(T["poise_regen"]) * dt, max_poise)

# --------------------------------------------------------------- states
func _st_move(dt: float) -> void:
	_sprinting = false
	if not input_enabled:
		velocity.x = move_toward(velocity.x, 0, 20 * dt)
		velocity.z = move_toward(velocity.z, 0, 20 * dt)
		return
	var dir := _desired_dir()
	if sim_active and sim_block and not _blocking:
		_enter_block()
		return
	var sprinting: bool = _pressed("sprint") and dir != Vector3.ZERO and stamina > 1.0 and cam.locked_target == null
	_sprinting = sprinting
	var mv: Dictionary = T["move"]
	var speed: float = float(mv["run"])
	if sprinting:
		speed = float(mv["sprint"])
		_spend(float(T["stamina"]["sprint_cost"]) * dt)
	elif cam.locked_target != null:
		speed = float(mv["strafe"]) * 1.35
	cam.set_sprinting(sprinting, dt)

	if _bow_drawing or cam.zoomed:
		speed = float(mv["strafe"])   # a drawn bow walks, it does not run

	var acc: float = float(mv["accel"])
	velocity.x = move_toward(velocity.x, dir.x * speed, acc * dt * speed)
	velocity.z = move_toward(velocity.z, dir.z * speed, acc * dt * speed)

	if cam.locked_target != null and is_instance_valid(cam.locked_target):
		_face(cam.locked_target.global_position - global_position, dt)
	else:
		_face(dir, dt)

	if not sim_active:
		for hi in hotbar.size():
			if Input.is_action_just_pressed("hotbar_%d" % (hi + 1)):
				_hotbar_use(hi)
				break
		if Input.is_action_just_pressed("inventory") and not PauseUI.is_open():
			InventoryUI.open_for(self)
			return
		if Input.is_action_just_pressed("cast_song") and attuned_song != "":
			cast_song(attuned_song)
		if _bow_equipped():
			# the bow owns LMB (draw/loose) and RMB (the sight): the melee
			# swing, block and parry handlers must not eat the same presses —
			# try_attack on the draw's own click killed the draw the frame
			# it began, which is why the string could never be held
			_bow_move_input(dt)
		if Input.is_action_just_pressed("dodge"):
			_try_roll(dir)
		elif not _bow_equipped() and Input.is_action_just_pressed("attack_light") and _mouse_ok():
			if _pressed("sprint"):
				try_attack(false)  # sprint attack folded into light for pass 1
			else:
				try_attack(false)
		elif not _bow_equipped() and Input.is_action_just_pressed("attack_heavy"):
			try_attack(true)
		elif not _bow_equipped() and Input.is_action_just_pressed("parry"):
			try_parry()
		elif not _bow_equipped() and Input.is_action_pressed("block") and _mouse_ok():
			_enter_block()
		elif Input.is_action_just_pressed("gourd"):
			try_gourd()
		elif Input.is_action_just_pressed("interact"):
			try_interact()
		elif Input.is_action_just_pressed("lock_on"):
			cam.try_lock(get_tree().get_nodes_in_group("targetable"))

func try_roll() -> bool:
	return _try_roll(_desired_dir())

func _try_roll(dir: Vector3) -> bool:
	var cost := float(T["stamina"]["roll_cost"])
	if stamina < 1.0 or dead:
		return false
	var R: Dictionary = T["roll"]
	_spend(cost)
	if dir == Vector3.ZERO:
		# neutral backstep
		_set_state(S.BACKSTEP)
		_roll_dir = vis.global_transform.basis.z    # backwards
		_roll_speed = float(R["backstep_speed"])
		_iframe_from = float(R["backstep_iframe_start"])
		_iframe_to = float(R["backstep_iframe_end"])
		vis.play("backstep", 0.05)
		Juice.spawn_hit_fx(global_position + Vector3(0, 0.08, 0), -_roll_dir, "dust")
		return true
	_set_state(S.ROLL)
	_roll_dir = dir.normalized()
	_roll_speed = roll_param("speed")
	_iframe_from = roll_param("iframe_start")
	_iframe_to = roll_param("iframe_end")
	_roll_dur = roll_param("duration")
	vis.rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)
	vis.play("roll", 0.03, vis.clip_length("roll") / _roll_dur)
	Juice.spawn_hit_fx(global_position + Vector3(0, 0.08, 0), -_roll_dir, "dust")
	AudioDirector.sfx_at("res://assets/audio/roll.wav", global_position, -6.0, randf_range(0.95, 1.05))
	return true

func _st_roll(dt: float) -> void:
	var dur := _roll_dur
	var k := 1.0 - smoothstep(0.55, 1.0, state_t / dur) * 0.85
	velocity.x = _roll_dir.x * _roll_speed * k
	velocity.z = _roll_dir.z * _roll_speed * k
	if state_t >= dur:
		_set_state(S.MOVE)
		vis.back_to_idle()

func _st_backstep(dt: float) -> void:
	var R: Dictionary = T["roll"]
	var dur := float(R["backstep_duration"])
	var k := 1.0 - smoothstep(0.3, 1.0, state_t / dur)
	velocity.x = _roll_dir.x * _roll_speed * k
	velocity.z = _roll_dir.z * _roll_speed * k
	if state_t >= dur:
		_set_state(S.MOVE)
		vis.back_to_idle()

func is_invulnerable() -> bool:
	if state == S.ROLL or state == S.BACKSTEP:
		return state_t >= _iframe_from and state_t <= _iframe_to
	return state == S.REST or dead

# --- arms & the belt -------------------------------------------------------
func owns_weapon(id: String) -> bool:
	return id in ["hewing_blade", "torch"] or int(inventory.get(id, 0)) > 0

func _hotbar_use(i: int) -> void:
	var slot: String = String(hotbar[i])
	if slot == "":
		return
	if slot == "gourd":
		try_gourd()
	elif not DB.song(slot).is_empty():
		cast_song(slot)
	else:
		equip_weapon(slot)

## Bind an item into a hand-slot (from the pack). A weapon lives in one
## slot only; binding it again just moves it.
func set_hotbar_slot(i: int, id: String) -> void:
	if i < 0 or i >= hotbar.size():
		return
	if id != "gourd" and DB.weapon(id).is_empty():
		return
	for k in hotbar.size():
		if String(hotbar[k]) == id:
			hotbar[k] = ""
	hotbar[i] = id
	hotbar_changed.emit()

func equip_weapon(id: String) -> void:
	if dead or id == weapon_id or DB.weapon(id).is_empty():
		return
	if not owns_weapon(id):
		Game.toast.emit("You do not carry that.")
		return
	if state != S.MOVE and state != S.BLOCK:
		return
	if state == S.BLOCK:
		_blocking = false
		_set_state(S.MOVE)
		vis.back_to_idle()
	weapon_id = id
	_combo_i = 0
	_bow_drawing = false
	cam.zoomed = false
	_refresh_weapon_visual()
	weapon_changed.emit(id)
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -12.0)

## How each arm rides the fist at rest. The spear is carried tip-skyward
## (relaxed arms ran it through the floor), the greatsword shoulders, the
## bow stands upright. Attacks zero the mount so strikes lead true.
const CARRY_POSE := {
	"torch": Vector3(155, 0, 0),   # upright, a hair of forward cant (180 leaned back)
	"spear": Vector3(180, 0, 0),
	"greatblade": Vector3(-40, 0, 0),
}
var _torch_light: OmniLight3D = null

func _refresh_weapon_visual() -> void:
	var w := weapon_data()
	vis.apply_loadout(w.get("kit", "hewing_blade"), not bool(w.get("two_handed", false)))
	apply_carry_pose()
	if _torch_light != null:
		_torch_light.queue_free()
		_torch_light = null
	if weapon_id == "torch":
		_torch_light = OmniLight3D.new()
		_torch_light.light_color = Color(1.0, 0.72, 0.38)
		_torch_light.omni_range = 8.0
		_torch_light.light_energy = 1.8
		_torch_light.position = Vector3(0, 0.8, 0)
		vis.weapon_mount.add_child(_torch_light)

func apply_carry_pose() -> void:
	vis.apply_carry_pose()

func give_item(item: String, count := 1) -> void:
	inventory[item] = int(inventory.get(item, 0)) + count
	if not DB.song(item).is_empty():
		# the first song learned wakes the breath-bar and attunes itself to C;
		# the rest wait in the Songs tab to be chosen
		if max_breath <= 0.0:
			recompute_derived()
			breath = max_breath
			breath_changed.emit(breath, max_breath)
		if attuned_song == "":
			attune_song(item)
	elif not DB.weapon(item).is_empty() and not hotbar.has(item):
		# a newly won arm seats itself in the first open hand-slot
		for i in hotbar.size():
			if String(hotbar[i]) == "":
				hotbar[i] = item
				hotbar_changed.emit()
				break
	inventory_changed.emit()

## Bind a known song to C (chosen in the Songs tab).
func attune_song(id: String) -> void:
	if DB.song(id).is_empty() or int(inventory.get(id, 0)) < 1:
		return
	attuned_song = id
	attune_changed.emit(id)

# --- armour -------------------------------------------------------------------
static func armour_slots() -> Array:
	return DB.tuning("player/armour/slots", ["head", "body", "hands", "legs"])

## Slot -> id for a new Bearer: every slot bare but what game.json starts worn.
static func starting_armour() -> Dictionary:
	var out := {}
	var start: Dictionary = DB.tuning("player/armour/start", {})
	for slot in armour_slots():
		out[slot] = String(start.get(slot, ""))
	return out

## The armour block of an item ({} when it is not armour).
static func armour_data(id: String) -> Dictionary:
	return DB.item(id).get("armour", {}) if id != "" else {}

func owns_armour(id: String) -> bool:
	if armour_data(id).is_empty():
		return false
	return id in starting_armour().values() or int(inventory.get(id, 0)) > 0

## Wear `id` in its own slot (an empty id bares `slot`). Fails on a piece
## not carried or meant for another slot.
func equip_armour(slot: String, id: String) -> bool:
	if not slot in armour_slots():
		return false
	if id != "":
		var a := armour_data(id)
		if a.is_empty() or String(a.get("slot", "")) != slot or not owns_armour(id):
			return false
	armour[slot] = id
	recompute_derived()
	armour_changed.emit()
	if slot == "body":
		refresh_outfit()
	return true

func _worn() -> Array:
	var out := []
	for slot in armour_slots():
		var a := armour_data(String(armour.get(slot, "")))
		if not a.is_empty():
			out.append(a)
	return out

func worn_poise() -> float:
	var t := 0.0
	for a in _worn():
		t += float(a.get("poise", 0))
	return t

func worn_weight() -> float:
	var t := 0.0
	for a in _worn():
		t += float(a.get("weight", 0))
	return t

## Summed share of a `kind` of blow the worn pieces turn (0..absorb_cap).
func absorption(kind: String) -> float:
	var key := String((DB.tuning("player/armour/absorb_kind", {}) as Dictionary).get(kind, ""))
	if key == "":
		return 0.0
	var t := 0.0
	for a in _worn():
		t += float((a.get("absorb", {}) as Dictionary).get(key, 0.0))
	return clampf(t, 0.0, float(DB.tuning("player/armour/absorb_cap", 0.8)))

## light / medium / heavy by worn weight. Medium is player.roll unchanged.
func roll_tier() -> String:
	var w := worn_weight()
	if w < float(DB.tuning("player/armour/light_under", 3.0)):
		return "light"
	if w > float(DB.tuning("player/armour/heavy_over", 12.0)):
		return "heavy"
	return "medium"

func roll_param(key: String) -> float:
	var tier: Dictionary = DB.tuning("player/armour/roll_tiers/" + roll_tier(), {})
	return float(tier.get(key, T["roll"][key]))

# --- the bow ----------------------------------------------------------------
func _bow_equipped() -> bool:
	return bool(weapon_data().get("ranged", false))

## Hold LMB: nock and draw (slow walk). Release: loose. RMB: sight the eye.
func _bow_move_input(dt: float) -> void:
	cam.zoomed = Input.is_action_pressed("block") and _mouse_ok()
	if not _bow_drawing and Input.is_action_just_pressed("attack_light") and _mouse_ok():
		if int(inventory.get("arrows", 0)) < 1:
			Game.toast.emit("The quiver is empty. Find or buy more arrows.")
		elif stamina > 1.0:
			_bow_drawing = true
			_bow_t = 0.0
			vis.play("bow_draw", 0.1)
			_nock_arrow(true)
	if _bow_drawing:
		_bow_t += dt
		# once the string reaches the cheek, hand the pose to an explicit
		# looping hold — the draw clip ending must never let the arm sag
		if _bow_t > 0.72 and vis.current_clip() != "bow_hold":
			vis.play("bow_hold", 0.08)
		# the shaft stays docked LEVEL, pointing where the archer faces —
		# the hand bone's own frame tilts with the draw and can't be trusted
		if _nock != null and is_instance_valid(_nock):
			_nock.global_transform.basis = vis.global_transform.basis
		if not Input.is_action_pressed("attack_light"):
			_bow_release()
	_set_crosshair(_bow_drawing or (cam.zoomed and _bow_equipped()))

var _xhair_on := false

## A quiet gold sight-dot while the string is drawn or the eye is sighted.
func _set_crosshair(on: bool) -> void:
	if on == _xhair_on:
		return
	_xhair_on = on
	for h in get_tree().get_nodes_in_group("hud"):
		if h.has_method("set_crosshair"):
			h.set_crosshair(on)

## The nocked shaft rides the bow while the string is drawn.
var _nock: Node3D = null

func _nock_arrow(on: bool) -> void:
	if _nock != null and is_instance_valid(_nock):
		_nock.queue_free()
	_nock = null
	if on and vis.bow_mount != null:
		_nock = Projectile.make_arrow()
		vis.bow_mount.add_child(_nock)
		# bow mount: +Y runs along the stave. The shaft docks ACROSS it at
		# the grip, riding the string plane, pointing where the archer faces
		_nock.position = Vector3(0, 0.06, 0.1)
		_nock.rotation_degrees = Vector3(0, 0, 0)

func _bow_release() -> void:
	_bow_drawing = false
	_nock_arrow(false)
	vis.back_to_idle(0.2)
	if _bow_t < 0.45:
		return          # string never came to the cheek — no loose, no arrow
	if vis.has_clip("bow_loose"):
		vis.play("bow_loose", 0.03)   # the release; locomotion takes over when it has played
	if int(inventory.get("arrows", 0)) < 1 or stamina < 1.0 or _winded > 0.0 or dead:
		return
	var w := weapon_data()
	_spend(float(w["stamina"]["light"]))
	inventory["arrows"] = int(inventory["arrows"]) - 1
	inventory_changed.emit()
	var from := global_position + Vector3.UP * 1.45
	var aim: Vector3
	if cam.locked_target != null and is_instance_valid(cam.locked_target):
		aim = (cam.locked_target.global_position + Vector3.UP * 1.0) - from
	else:
		aim = -cam.cam.global_transform.basis.z   # straight through the sight
	var k := clampf(_bow_t / 1.1, 0.25, 1.0)      # a fuller draw bites deeper
	var pk := DamagePacket.new(_attack_damage(lerpf(0.55, 1.25, k)),
			float(w.get("poise_damage", 10)) * k, self)
	pk.kind = "arrow"
	pk.can_be_parried = false
	var pr := Projectile.launch_arrow(get_parent(), from, aim, 26.0 + 16.0 * k, pk)
	pr.team = "player"
	vis.rotation.y = atan2(-aim.x, -aim.z)
	AudioDirector.sfx_at("res://assets/audio/whoosh_l.wav", global_position, -6.0, 1.4)

# --- attacks ---------------------------------------------------------------
func weapon_data() -> Dictionary:
	return DB.weapon(weapon_id)

## The stat every attribute starts at (game.json levels/base_stat). Scaling
## counts only points ABOVE it, so a fresh Bearer is not secretly +10%.
func base_stat() -> int:
	return int(DB.tuning("levels/base_stat", 8))

func _over_base(stat: String) -> float:
	return float(int(attributes.get(stat, base_stat())) - base_stat())

## Flat damage the smith's bog-iron adds per level (weapons.json
## upgrade.per_level). A weapon without one falls back to 14% of its base.
func upgrade_bonus(w: Dictionary, lvl: int) -> float:
	var upg: Dictionary = w.get("upgrade", {})
	var per := float(upg.get("per_level", float(w.get("damage", 10)) * 0.14))
	return per * float(lvl)

func _attack_damage(mult: float) -> float:
	var w := weapon_data()
	var scal: Dictionary = w.get("scaling", {})
	var k := float(DB.tuning("levels/scaling_per_point", 0.02))
	var s: float = 1.0
	for stat in ["might", "craft", "kinship"]:
		s += _over_base(stat) * float(scal.get(stat, 0.0)) * k
	var base := float(w.get("damage", 10)) + upgrade_bonus(w, weapon_level)
	return base * s * mult * Game.dmg_out_mult()

var _no_atk_toast := 0.0

func try_attack(heavy: bool) -> bool:
	if dead or _bow_equipped():
		return false
	if weapon_data().get("no_attack", false):
		if _no_atk_toast <= 0.0:
			_no_atk_toast = 2.5
			Game.toast.emit("The torch is for the dark, not the duel.")
		return false
	if state == S.ATTACK:
		# queue combo link during recovery
		_queued = "heavy" if heavy else "light"
		return false
	if state != S.MOVE and state != S.BLOCK:
		return false
	if not heavy and _riposte_target != null and try_riposte():
		return true
	if not heavy and state == S.MOVE and _sprinting:
		return _sprint_attack()
	return _chain_attack(heavy)

## A light pressed at a full sprint: the run-in strike (movesets.json
## `sprint`), its own windup, lunge and cost (weapons.json stamina.sprint).
func _sprint_attack() -> bool:
	var w := weapon_data()
	var ms := DB.moveset(w.get("moveset", "longsword"))
	if not ms.has("sprint"):
		return _chain_attack(false)
	if stamina < 1.0 or _winded > 0.0:
		return false
	var st: Dictionary = w["stamina"]
	_spend(float(st.get("sprint", st["light"])))
	_combo_i = 0
	_sprinting = false
	_begin_attack(ms["sprint"], false, "sprint")
	return true

## Starts a swing regardless of current attack state (combo links use this).
func _chain_attack(heavy: bool) -> bool:
	var w := weapon_data()
	if w.get("no_attack", false):
		return false
	var cost: float = float(w["stamina"]["heavy" if heavy else "light"])
	if stamina < 1.0 or _winded > 0.0:
		return false
	var ms := DB.moveset(w.get("moveset", "longsword"))
	var m: Dictionary
	if heavy:
		m = ms["heavy"]
	else:
		var lights: Array = ms["lights"]
		_combo_i = _combo_i % lights.size()
		m = lights[_combo_i]
	_spend(cost)
	_begin_attack(m, heavy, "heavy" if heavy else "light")
	return true

func _begin_attack(m: Dictionary, heavy: bool, kind := "") -> void:
	_atk = m
	_atk_is_heavy = heavy
	_atk_kind = kind if kind != "" else ("heavy" if heavy else "light")
	_atk_hit_open = false
	_queued = ""
	_blocking = false
	if vis.weapon_mount != null and not vis.is_humanoid():
		vis.weapon_mount.rotation_degrees = Vector3.ZERO   # mannequin clips lead with a bare mount; a humanoid's grip is data
	_set_state(S.ATTACK)
	# face lock target or input dir instantly-ish
	var dir := _desired_dir()
	if cam.locked_target != null and is_instance_valid(cam.locked_target):
		dir = cam.locked_target.global_position - global_position
	if dir != Vector3.ZERO:
		vis.rotation.y = atan2(-dir.x, -dir.z)
	_lunge = float(m.get("lunge", 2.0))
	var anim_name: String = m.get("anim", "attack_l1")
	# contact frames are data (clip_meta.json); the clip is timed to the strike
	var strike_t := maxf(float(m.get("windup", 0.30)) + float(m.get("active", 0.14)) * 0.45, 0.12)
	vis.play_timed(anim_name, strike_t, 0.07 if vis.is_humanoid() else 0.05, 0.55, 1.85)
	vis.anticipate(strike_t)

func _st_attack(dt: float) -> void:
	var wind := float(_atk["windup"])
	var act := float(_atk["active"])
	var rec := float(_atk["recovery"])
	var t := state_t
	# lunge through the active window
	if t >= wind and t < wind + act + 0.05:
		var fwd := -vis.global_transform.basis.z
		velocity.x = fwd.x * _lunge
		velocity.z = fwd.z * _lunge
	else:
		velocity.x = move_toward(velocity.x, 0, 26 * dt)
		velocity.z = move_toward(velocity.z, 0, 26 * dt)

	# the ribbon starts a beat before the hitbox opens, so the whole arc into
	# the contact is drawn (anim polish; the hit window itself is untouched)
	if vis.is_humanoid() and not vis.trail.visible and not _atk_hit_open and t >= wind - vis.trail_lead():
		vis.trail.visible = true
	if not _atk_hit_open and t >= wind:
		_atk_hit_open = true
		_open_hitbox(_atk)
		vis.trail.visible = true
		AudioDirector.sfx_at("res://assets/audio/swing.wav", global_position, -9.0,
				randf_range(0.94, 1.1) * (0.85 if _atk_is_heavy else 1.0))
	if _atk_hit_open and t >= wind + act and hitbox.monitoring:
		hitbox.end_swing()
		vis.trail.visible = false
	# the same window, against the world: chips off a post, sparks off iron
	if prop_strike.live():
		if t < wind + act:
			_sweep_props()
		else:
			prop_strike.end()

	# combo input capture during recovery
	if not sim_active and t > wind + act:
		if Input.is_action_just_pressed("attack_light") and _mouse_ok():
			_queued = "light"
		elif Input.is_action_just_pressed("attack_heavy"):
			_queued = "heavy"
		elif Input.is_action_just_pressed("dodge"):
			_queued = "roll"

	var total := wind + act + rec
	var chain_at := wind + act + rec * float(_atk.get("chain_from", 0.6))
	if t >= chain_at and _queued != "":
		var q := _queued
		_queued = ""
		hitbox.end_swing()
		match q:
			"light":
				_combo_i += 1
				if not _chain_attack(false):
					_set_state(S.MOVE)
			"heavy":
				if not _chain_attack(true):
					_set_state(S.MOVE)
			"roll":
				_combo_i = 0
				if not _try_roll(_desired_dir()):
					_set_state(S.MOVE)
		return
	if t >= total:
		_combo_i = 0
		hitbox.end_swing()
		vis.trail.visible = false
		_set_state(S.MOVE)
		vis.back_to_idle(0.28 if vis.is_humanoid() else 0.2)   # the recovery eases out

func _open_hitbox(m: Dictionary) -> void:
	var hb: Dictionary = m.get("hitbox", {})
	var reach := float(hb.get("reach", 1.7))
	var width := float(hb.get("width", 1.8))
	var height := float(hb.get("height", 1.5))
	(hitbox_shape.shape as BoxShape3D).size = Vector3(width, height, reach)
	hitbox.position = Vector3(0, 1.1, -reach * 0.5 - 0.2)
	var pk := DamagePacket.new(_attack_damage(float(m.get("dmg_mult", 1.0))),
			float(weapon_data().get("poise_damage", 20)) * float(m.get("poise_mult", 1.0)), self)
	pk.origin = global_position
	hitbox.begin_swing(pk)
	prop_strike.begin(_atk_is_heavy)
	if _atk_is_heavy:
		_chip_frozen(reach)

## The blade's edge this tick, from the pose (the ribbon's own two points).
func _sweep_props() -> void:
	var xf := vis.weapon_xform()
	var base_up := 0.12
	var tip_up := 1.08
	if vis.trail != null:
		base_up = float(vis.trail.get("base_up"))
		tip_up = float(vis.trail.get("tip_up"))
	prop_strike.sweep(get_world_3d().direct_space_state, xf * Vector3(0, base_up, 0), xf * Vector3(0, tip_up, 0))

## A heavy blow chips out what is frozen in close in front (the float in
## the tide wall): pickups in group chip_heavy within reach and ahead.
func _chip_frozen(reach: float) -> void:
	var fwd := -vis.global_transform.basis.z
	fwd.y = 0.0
	for p in get_tree().get_nodes_in_group("chip_heavy"):
		var n := p as Node3D
		if n == null or not n.is_visible_in_tree():
			continue
		var d := n.global_position - global_position
		d.y = 0.0
		if d.length() <= reach + 0.9 and (d.length() < 0.4 or fwd.normalized().dot(d.normalized()) > 0.3):
			n.call("chip", self)

func _on_hit_contact(_hb: Area3D, result: String) -> void:
	hit_landed.emit(_hb.owner, result)
	var fx_pos := _hb.global_position + Vector3(0, 1.05, 0) if _hb != null else (global_position + Vector3(0, 1.1, 0))
	var fx_dir := (global_position - fx_pos).normalized()
	match result:
		"hit":
			Juice.hitstop(0.09 if _atk_is_heavy else 0.06)
			vis.impact_dig(1.5 if _atk_is_heavy else 1.0)   # held on the impact pose by the hit-stop
			Juice.shake(0.35 if _atk_is_heavy else 0.2, 0.18)
			Juice.spawn_hit_fx(fx_pos, fx_dir, "heavy" if _atk_is_heavy else "blood")
			# every foe is frost-taken: the edge meets rime and frozen wool
			AudioDirector.sfx_at("res://assets/audio/slash.wav", global_position, -9.0, randf_range(0.9, 1.1))
			AudioDirector.sfx_at(AudioDirector.foley("frost_hit"), fx_pos, -3.0,
					randf_range(0.82, 0.92) if _atk_is_heavy else randf_range(0.95, 1.08))
		"blocked":
			Juice.hitstop(0.05)
			Juice.spawn_hit_fx(fx_pos, fx_dir, "spark")
			AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -4.0)
			AudioDirector.sfx_at("res://assets/audio/shield_ding.wav", global_position, -5.0,
					randf_range(0.95, 1.12))
		"parried":
			pass  # on_parried() handles our stagger

# --- block / parry ----------------------------------------------------------
var _block_react := false   # a block_hit react is playing over the guard hold

func _enter_block() -> void:
	if stamina <= 0.0 or not weapon_data().has("block"):
		return   # the bow gives no guard — RMB sights instead
	_blocking = true
	_block_react = false
	_set_state(S.BLOCK)
	vis.play("block", 0.08)

func _st_block(dt: float) -> void:
	if not input_enabled or not _pressed("block"):
		_blocking = false
		_set_state(S.MOVE)
		vis.back_to_idle()
		return
	if _block_react and vis.action_done():
		_block_react = false
		vis.play("block", 0.12)
	var dir := _desired_dir()
	var mv: Dictionary = T["move"]
	velocity.x = move_toward(velocity.x, dir.x * float(mv["strafe"]), 10 * dt * float(mv["strafe"]))
	velocity.z = move_toward(velocity.z, dir.z * float(mv["strafe"]), 10 * dt * float(mv["strafe"]))
	if cam.locked_target != null and is_instance_valid(cam.locked_target):
		_face(cam.locked_target.global_position - global_position, dt)
	elif dir != Vector3.ZERO:
		_face(dir, dt, 6.0)
	if not sim_active:
		if Input.is_action_just_pressed("attack_light") and _mouse_ok():
			try_attack(false)
		elif Input.is_action_just_pressed("parry"):
			try_parry()
		elif Input.is_action_just_pressed("dodge"):
			_blocking = false
			_try_roll(dir)

func is_blocking_toward(from_pos: Vector3) -> bool:
	if not _blocking or stamina <= 0.0:
		return false
	var to := from_pos - global_position
	to.y = 0
	var fwd := -vis.global_transform.basis.z
	return fwd.angle_to(to.normalized()) < 1.15

## Guard quality is the weapon's: a shield shrugs what a spear-haft barely
## turns; the greatsword's flat sits between them.
func on_blocked_hit(packet: DamagePacket) -> void:
	var b: Dictionary = weapon_data().get("block", {"stab": 0.85, "chip": 0.14})
	_spend(packet.amount * float(b.get("stab", 0.85)))
	hp = maxf(hp - packet.amount * float(b.get("chip", 0.14)) * Game.dmg_in_mult(), 1.0)
	health_changed.emit(hp, max_hp)
	Juice.shake(0.18, 0.12)
	var bdir := (global_position - packet.origin).normalized() if packet.origin != Vector3.ZERO else vis.global_transform.basis.z
	vis.flinch(bdir, 0.75)
	if state == S.BLOCK and vis.has_clip("block_hit"):
		vis.play("block_hit", 0.02)   # the guard soaks it; _st_block returns to the hold
		_block_react = true
	Juice.spawn_hit_fx(global_position + Vector3(0, 1.15, 0) - bdir * 0.35, -bdir, "spark")
	if stamina <= 0.0:
		_guard_break()

func _guard_break() -> void:
	_blocking = false
	_stagger(0.9)

func try_parry() -> bool:
	if dead or (state != S.MOVE and state != S.BLOCK):
		return false
	var P: Dictionary = T["parry"]
	_spend(float(P["stamina"]))
	_blocking = false
	_set_state(S.PARRY)
	_parry_from = float(P["windup"])
	_parry_to = float(P["windup"]) + float(P["window"])
	vis.play("parry", 0.03)
	return true

func _st_parry(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 16 * dt)
	velocity.z = move_toward(velocity.z, 0, 16 * dt)
	var P: Dictionary = T["parry"]
	if state_t >= _parry_to + float(P["recovery"]):
		_set_state(S.MOVE)
		vis.back_to_idle()

func is_parrying_toward(from_pos: Vector3) -> bool:
	if state != S.PARRY or state_t < _parry_from or state_t > _parry_to:
		return false
	var to := from_pos - global_position
	to.y = 0
	var fwd := -vis.global_transform.basis.z
	return fwd.angle_to(to.normalized()) < 1.0

## Called by an enemy when we parried them; they enter a punishable state.
func on_parry_success(enemy: Node3D) -> void:
	_riposte_target = enemy
	_riposte_t = 2.6   # matches the parried foe's long stagger breath
	Juice.hitstop(0.14, 0.03)
	Juice.shake(0.4, 0.2)
	var ppos := (global_position + enemy.global_position) * 0.5 + Vector3(0, 1.15, 0) if enemy != null else (global_position + Vector3(0, 1.15, 0))
	Juice.spawn_hit_fx(ppos, Vector3.UP, "parry")
	AudioDirector.sfx_at("res://assets/audio/parry.wav", global_position, 0.0)

## Riposte / backstab entry (crit states).
func try_riposte() -> bool:
	if _riposte_target == null or not is_instance_valid(_riposte_target):
		return false
	if global_position.distance_to(_riposte_target.global_position) > 2.4:
		return false
	if not _riposte_target.has_method("receive_riposte"):
		return false
	_set_state(S.RIPOSTE)
	var dir: Vector3 = _riposte_target.global_position - global_position
	vis.rotation.y = atan2(-dir.x, -dir.z)
	vis.play("riposte", 0.05)
	var target := _riposte_target
	_riposte_target = null
	_do_riposte_damage.call_deferred(target)
	return true

func _do_riposte_damage(target: Node3D) -> void:
	await get_tree().create_timer(0.34, false).timeout
	if is_instance_valid(target) and state == S.RIPOSTE:
		var pk := DamagePacket.new(_attack_damage(3.25), 999.0, self)
		pk.can_be_blocked = false
		pk.can_be_parried = false
		pk.is_riposte = true
		target.receive_riposte(pk)
		Juice.hitstop(0.12, 0.04)
		Juice.shake(0.5, 0.25)
		Juice.spawn_hit_fx(target.global_position + Vector3(0, 1.1, 0), (global_position - target.global_position).normalized(), "heavy")

func _st_riposte(dt: float) -> void:
	velocity.x = 0
	velocity.z = 0
	if state_t >= 0.9:
		_set_state(S.MOVE)
		vis.back_to_idle()

# --- gourd -------------------------------------------------------------------
var _gourd_fx_fired := false

func try_gourd() -> bool:
	if gourds <= 0 or dead or state != S.MOVE:
		return false
	gourds -= 1
	gourds_changed.emit(gourds, gourd_max)
	_gourd_fx_fired = false
	_set_state(S.GOURD)
	# the real drink clip is fitted to the data use_time, as the roll is
	var gr := vis.clip_length("gourd") / float(T["gourd"]["use_time"]) if vis.is_humanoid() else 1.0
	vis.play("gourd", 0.08, gr)
	_show_gourd(true)
	if vis.shield_mount != null:
		vis.shield_mount.visible = false   # the gourd arm carries no shield
	AudioDirector.sfx("res://assets/audio/gourd.wav", -6.0)
	return true

func knows_any_song() -> bool:
	for sid in DB.table("songs"):
		if int(inventory.get(sid, 0)) > 0:
			return true
	return false

## The learned songs. Cast from the hotbar; each takes the whole hearth-bar
## economy seriously: breath gates it, a short cooldown stops mashing.
func cast_song(id: String) -> void:
	var sp := DB.song(id)
	if sp.is_empty() or dead or int(inventory.get(id, 0)) < 1:
		return
	if state != S.MOVE or _cast_cd > 0.0:
		return
	var cost := float(sp.get("breath", 30))
	if breath < cost:
		Game.toast.emit("The breath is spent. Rest, or let it regather.")
		return
	breath -= cost
	breath_changed.emit(breath, max_breath)
	_cast_cd = 0.7
	# the shield rides the casting forearm; tucked away for the gesture or
	# every song reads as a guard-raise
	if vis != null and vis.shield_mount != null:
		vis.shield_mount.visible = false
		var stw := create_tween()
		stw.tween_interval(0.85)
		stw.tween_callback(func():
			if vis != null and is_instance_valid(vis) and vis.shield_mount != null and state != S.GOURD:
				vis.shield_mount.visible = not bool(weapon_data().get("two_handed", false)))
	var dev: float = 1.0 + _over_base("kinship") * 0.025   # songs.json is rebalanced for (stat - base)
	match String(sp.get("type", "")):
		"heal":
			vis.play("cast_self", 0.1)
			hp = minf(hp + max_hp * float(sp.get("power", 0.3)), max_hp)
			health_changed.emit(hp, max_hp)
			Juice.shake(0.08, 0.1)
			AudioDirector.sfx("res://assets/audio/swell_warm.wav", -8.0, 1.3)
			_ember_flash(1.4, 4.0)
			_spawn_gourd_heal_fx()
		"blast":
			vis.play("cast", 0.08)
			var from := global_position + Vector3.UP * 1.45
			var aim: Vector3
			if cam.locked_target != null and is_instance_valid(cam.locked_target):
				aim = (cam.locked_target.global_position + Vector3.UP * 1.0) - from
			else:
				aim = -cam.cam.global_transform.basis.z
			var pk := DamagePacket.new(float(sp.get("damage", 50)) * dev, 26, self)
			pk.kind = "ember"
			pk.can_be_parried = false
			var pr := Projectile.launch(get_parent(), from, aim, 30.0, pk, Color(1.0, 0.88, 0.5))
			pr.team = "player"
			vis.rotation.y = atan2(-aim.x, -aim.z)
			AudioDirector.sfx("res://assets/audio/whoosh_h.wav", -6.0, 1.2)
			_ember_flash(1.2, 3.0)
		"lance":
			vis.play("cast_lance", 0.08)
			var lfrom := global_position + Vector3.UP * 1.45
			var laim: Vector3
			if cam.locked_target != null and is_instance_valid(cam.locked_target):
				laim = ((cam.locked_target.global_position + Vector3.UP * 1.0) - lfrom).normalized()
			else:
				laim = -cam.cam.global_transform.basis.z
			var llen := float(sp.get("length", 24.0))
			# one held note: everything within a blade's width of the line
			var lend := lfrom + laim * llen
			for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
				if e is Node3D and e.has_method("take_hit"):
					var ep: Vector3 = (e as Node3D).global_position + Vector3.UP * 1.0
					var t := clampf((ep - lfrom).dot(laim), 0.0, llen)
					if ep.distance_to(lfrom + laim * t) <= 1.1:
						var pk3 := DamagePacket.new(float(sp.get("damage", 85)) * dev, 40, self)
						pk3.kind = "ember"
						pk3.can_be_parried = false
						e.take_hit(pk3)
			_lance_beam(lfrom, lend)
			vis.rotation.y = atan2(-laim.x, -laim.z)
			Juice.shake(0.2, 0.18)
			AudioDirector.sfx("res://assets/audio/whoosh_h.wav", -4.0, 1.5)
			_ember_flash(1.6, 4.0)
		"ward":
			vis.play("cast_ward", 0.1)
			_ward_hp = float(sp.get("absorb", 70)) * dev
			_ward_until = Time.get_ticks_msec() / 1000.0 + float(sp.get("duration", 9.0))
			_ward_glow()
			Game.toast.emit("The Warding Hum settles over you.")
			AudioDirector.sfx("res://assets/audio/swell_warm.wav", -6.0, 1.1)
			_ember_flash(1.5, 3.5)
		"burst":
			vis.play("cast", 0.08, 0.85)
			var r := float(sp.get("radius", 4.5))
			for e in get_tree().get_nodes_in_group(RH.GROUP_ENEMIES):
				if e is Node3D and e.global_position.distance_to(global_position) <= r:
					if e.has_method("take_hit"):
						var pk2 := DamagePacket.new(float(sp.get("damage", 90)) * dev, 60, self)
						pk2.kind = "ember"
						e.take_hit(pk2)
			Juice.shake(0.35, 0.3)
			AudioDirector.sfx("res://assets/audio/swell_warm.wav", -3.0, 0.8)
			_ember_flash(3.2, 7.5)
			_burst_nova(r)

## The Burst made visible: a golden ring racing out along the stones to the
## song's true radius, motes thrown outward, a breath of scorch-light.
func _burst_nova(radius: float) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.86
	tm.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.85, 0.5, 0.85)
	tm.material = mat
	ring.mesh = tm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0, 0.12, 0)
	ring.scale = Vector3.ONE * 0.4
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(radius, 0.9, radius), 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	RH.free_after(ring, 0.8)
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.9
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = radius * 1.1
	p.initial_velocity_max = radius * 1.9
	p.gravity = Vector3(0, -3.5, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.09
	p.color = Color(1.0, 0.86, 0.5)
	p.mesh = AreaPortal.make_mote_quad(1.6)
	get_parent().add_child(p)
	p.global_position = global_position + Vector3.UP * 0.5
	p.emitting = true
	RH.free_after(p, 1.4)

## A brief warmed light on the Bearer — every song glows.
func _ember_flash(energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.86, 0.5)
	l.omni_range = rng
	l.light_energy = energy
	l.position = Vector3(0, 1.4, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.55)
	tw.tween_callback(l.queue_free)

func _st_gourd(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 12 * dt)
	velocity.z = move_toward(velocity.z, 0, 12 * dt)
	var use_time := float(T["gourd"]["use_time"])
	if _gourd_mount != null and is_instance_valid(_gourd_mount) and not vis.is_humanoid():
		# (a humanoid's real drink clip carries the gourd to the mouth itself)
		# Keep _gourd_mount anchored in the gauntleted left hand (hand_l) while
		# orienting the gourd in character space so its golden spout tips directly
		# into the visor slit (matching posegrid gourd 0.50).
		_gourd_mount.position = Vector3(0.0, 0.05, -0.02)
		var u := clampf(state_t / maxf(use_time, 0.01), 0.0, 1.0)
		var sip_pulse := 0.0
		if u >= 0.24 and u <= 0.84:
			sip_pulse = pow(sin(((u - 0.24) / 0.60) * PI * 2.0 - PI * 0.35) * 0.5 + 0.5, 1.4) * 6.0
		_gourd_mount.global_transform.basis = vis.global_transform.basis * Basis.from_euler(Vector3(
			deg_to_rad(8.0),
			deg_to_rad(-12.0),
			deg_to_rad(-34.0 - sip_pulse)
		))
	if not _gourd_fx_fired and state_t >= use_time * 0.62:
		_gourd_fx_fired = true
		if hp < max_hp:
			hp = minf(hp + float(T["gourd"]["heal"]), max_hp)
			health_changed.emit(hp, max_hp)
		_spawn_gourd_heal_fx()
	if state_t >= use_time:
		_show_gourd(false)
		_set_state(S.MOVE)
		vis.back_to_idle()

## Golden gourd restoration aura: warm amber bloom, ascending bokeh motes,
## vertical golden light-wisps, and delicate rising filament rings.
func _spawn_gourd_heal_fx() -> void:
	_ember_flash(1.85, 4.2)
	var parent_node := get_parent() if get_parent() != null else self
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.96, 0.80, 0.98),
		Color(1.0, 0.84, 0.42, 0.78),
		Color(0.94, 0.62, 0.20, 0.28),
		Color(0.85, 0.48, 0.14, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 48
	gt.height = 48

	var life_grad := Gradient.new()
	life_grad.offsets = PackedFloat32Array([0.0, 0.15, 0.70, 1.0])
	life_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.65),
		Color(1.0, 0.95, 0.82, 1.0),
		Color(1.0, 0.82, 0.48, 0.80),
		Color(0.8, 0.45, 0.15, 0.0),
	])

	# 1. Ascending golden bokeh motes from waist to crown
	var motes := CPUParticles3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.15, 0.15)
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.vertex_color_use_as_albedo = true
	mmat.albedo_texture = gt
	mmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mmat.billboard_keep_scale = true
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.material = mmat
	motes.mesh = qm
	motes.amount = 42
	motes.lifetime = 0.85
	motes.preprocess = 0.28
	motes.explosiveness = 0.35
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = 0.46
	motes.emission_ring_inner_radius = 0.18
	motes.emission_ring_height = 0.85
	motes.direction = Vector3.UP
	motes.spread = 16.0
	motes.initial_velocity_min = 0.95
	motes.initial_velocity_max = 1.95
	motes.gravity = Vector3(0, 0.65, 0)
	motes.scale_amount_min = 0.75
	motes.scale_amount_max = 1.45
	motes.color_ramp = life_grad
	parent_node.add_child(motes)
	motes.global_position = global_position + Vector3(0, 0.85, 0)
	RH.stop_emitting_after(motes, 0.65)
	RH.free_after(motes, 1.55)

	# 2. Vertical golden light-wisps (Y-billboarded streaks rising around the torso)
	var wisps := CPUParticles3D.new()
	var wqm := QuadMesh.new()
	wqm.size = Vector2(0.065, 0.38)
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.vertex_color_use_as_albedo = true
	wmat.albedo_texture = gt
	wmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	wmat.billboard_keep_scale = true
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wqm.material = wmat
	wisps.mesh = wqm
	wisps.amount = 20
	wisps.lifetime = 0.70
	wisps.preprocess = 0.22
	wisps.explosiveness = 0.40
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	wisps.emission_ring_axis = Vector3.UP
	wisps.emission_ring_radius = 0.40
	wisps.emission_ring_inner_radius = 0.20
	wisps.emission_ring_height = 0.65
	wisps.direction = Vector3.UP
	wisps.spread = 8.0
	wisps.initial_velocity_min = 1.15
	wisps.initial_velocity_max = 2.15
	wisps.gravity = Vector3(0, 0.5, 0)
	wisps.scale_amount_min = 0.80
	wisps.scale_amount_max = 1.35
	wisps.color_ramp = life_grad
	parent_node.add_child(wisps)
	wisps.global_position = global_position + Vector3(0, 0.80, 0)
	RH.stop_emitting_after(wisps, 0.55)
	RH.free_after(wisps, 1.35)

	# 3. Two paper-thin, delicate golden filament rings rising from waist to shoulders
	for i in range(2):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		var r_base := 0.46 - float(i) * 0.08
		tm.inner_radius = r_base
		tm.outer_radius = r_base + 0.012
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rmat.albedo_color = Color(1.0, 0.86, 0.44, 0.48 - float(i) * 0.10)
		tm.material = rmat
		ring.mesh = tm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent_node.add_child(ring)
		var y0 := 0.48 + float(i) * 0.22
		ring.global_position = global_position + Vector3(0, y0, 0)
		ring.scale = Vector3(0.82, 0.5, 0.82)
		var tw := ring.create_tween().set_parallel(true)
		tw.tween_property(ring, "global_position", global_position + Vector3(0, y0 + 1.05, 0), 0.65) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "scale", Vector3(1.14, 0.5, 1.14), 0.65) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(rmat, "albedo_color:a", 0.0, 0.68)
		RH.free_after(ring, 0.75)

## The gourd itself, mounted in the off-hand only while he drinks —
## held world-upright, tipped back toward the visor as the arm rises.
var _gourd_mount: Node3D = null
var _gourd_base_basis := Basis.IDENTITY
var _gourd_tilt := 36.0   # drinking tilt; pivots around the belly center

func _show_gourd(on: bool) -> void:
	if on:
		if _gourd_mount == null:
			_gourd_mount = vis.mount_gourd()
			if not vis.is_humanoid():
				_gourd_mount.global_transform.basis = vis.global_transform.basis * Basis.from_euler(Vector3(
					deg_to_rad(8.0),
					deg_to_rad(-12.0),
					deg_to_rad(-34.0)
				))
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.82, 0.42)
			glow.light_energy = 0.85
			glow.omni_range = 1.6
			glow.shadow_enabled = false
			glow.position = Vector3(0.0, 0.11, 0.0)
			_gourd_mount.add_child(glow)
	elif _gourd_mount != null:
		vis.unmount_gourd(_gourd_mount)
		_gourd_mount = null

# --- damage intake -----------------------------------------------------------
# ---- the Warding Hum: a skin of remembered warmth that spends itself first
var _ward_hp := 0.0
var _ward_until := 0.0
var invulnerable := false
var _stagger_dur := 0.6

func _ward_active() -> bool:
	return _ward_hp > 0.0 and Time.get_ticks_msec() / 1000.0 < _ward_until

func _ward_glow() -> void:
	var l := OmniLight3D.new()
	l.name = "WardGlow"
	l.light_color = Color(1.0, 0.88, 0.6)
	l.light_energy = 1.1
	l.omni_range = 2.6
	l.shadow_enabled = false
	l.position.y = 1.2
	add_child(l)
	var life := _ward_until - Time.get_ticks_msec() / 1000.0
	var tw := l.create_tween()
	tw.tween_interval(maxf(life - 0.6, 0.1))
	tw.tween_property(l, "light_energy", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

## The lance made visible: a gold seam hanging in the air a breath, then gone.
func _lance_beam(from: Vector3, to: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.09
	cm.height = from.distance_to(to)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.92, 0.6, 0.85)
	cm.material = mat
	beam.mesh = cm
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP if absf(from.direction_to(to).y) < 0.98 else Vector3.RIGHT)
	beam.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var tw := beam.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(beam.queue_free)

func take_hit(packet: DamagePacket) -> void:
	if dead or invulnerable:
		return
	# worn armour turns a share of the blow before anything else sees it
	packet.amount *= 1.0 - absorption(packet.kind)
	# the Warding Hum takes the world's anger first
	if _ward_active():
		var soak := minf(_ward_hp, packet.amount * Game.dmg_in_mult())
		_ward_hp -= soak
		packet.amount = maxf(packet.amount - soak / maxf(Game.dmg_in_mult(), 0.001), 0.0)
		_ember_flash(1.2, 2.6)
		AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -8.0, 1.4)
		if _ward_hp <= 0.0:
			Game.toast.emit("The Warding Hum fades.")
		if packet.amount <= 0.0:
			poise -= packet.poise_damage * 0.4
			_poise_delay = 2.0
			return
	hp = maxf(hp - packet.amount * Game.dmg_in_mult(), 0.0)
	health_changed.emit(hp, max_hp)
	poise -= packet.poise_damage
	_poise_delay = 2.0
	var hdir := (global_position - packet.origin).normalized() if packet.origin != Vector3.ZERO else vis.global_transform.basis.z
	# struck from behind: the blow travels the way the Bearer faces
	_hit_from_back = hdir.dot(-vis.global_transform.basis.z) > 0.3
	vis.flinch(hdir, 1.15)
	Juice.spawn_hit_fx(global_position + Vector3(0, 1.1, 0), -hdir, "blood")
	Juice.shake(0.3, 0.2)
	AudioDirector.sfx_at("res://assets/audio/impact_flesh.wav", global_position, -6.0, 0.85)
	if hp <= 0.0:
		_fell_to_land = packet.kind == "hazard"
		_die()
	elif poise <= 0.0:
		poise = max_poise
		_stagger(float(T["stagger_time"]))

var _hit_from_back := false
## Where the Breathmark hangs. Taken by the sea or a ravine, the death spot
## is under water or out of reach; the warmth waits on the last ground stood
## on instead, so the one chance to take it back is a real one.
var _fell_to_land := false
func breathmark_spot() -> Vector3:
	if _fell_to_land and _last_ground != Vector3.ZERO:
		return _last_ground
	return global_position

func _stagger(dur: float) -> void:
	_stagger_dur = maxf(dur, 0.2)
	_set_state(S.STAGGER)
	_blocking = false
	hitbox.end_swing()
	vis.cancel_anticipation()
	var clip := "stagger_back" if _hit_from_back and vis.has_clip("stagger_back") else "stagger"
	_hit_from_back = false
	vis.play(clip, 0.03, 0.7 / _stagger_dur)

func _st_stagger(dt: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 8 * dt)
	velocity.z = move_toward(velocity.z, 0, 8 * dt)
	if state_t >= _stagger_dur:
		_set_state(S.MOVE)
		vis.back_to_idle()

func _die() -> void:
	if dead:
		return
	dead = true
	_set_state(S.DEAD)
	hitbox.end_swing()
	vis.play("death", 0.1)
	AudioDirector.sfx("res://assets/audio/death.wav", 0.0, 1.0, "UI")
	died.emit()

## External control (rest ceremony, dialogue, respawn)
## The body the Bearer wears: game.json player.model, or after the Outsong
## the robes and the mask it was sung in (player.model_outsong).
func body_model() -> String:
	var m := String(T.get("model", ""))
	var o := String(T.get("model_outsong", ""))
	if World.spring() and o != "" and HumanoidLib.has_model(o):
		return o
	# the body armour he wears is the body he is seen in (items.json
	# armour.model); bare, or a piece with no model of its own, is the
	# traveller he arrived as
	var worn := String(armour_data(String(armour.get("body", ""))).get("model", ""))
	if worn != "" and HumanoidLib.has_model(worn):
		return worn
	return m

## The worn outfit has changed (an equip, a load): the body follows when it
## can. Not while the Pack is open (he changes when it closes, not once per
## row tried on), and not in the middle of a swing, a roll or a drink.
var _outfit_dirty := false

func refresh_outfit() -> void:
	_outfit_dirty = true
	_apply_outfit()

func _apply_outfit() -> void:
	if not _outfit_dirty or vis == null or dead:
		return
	if not (state == S.MOVE or state == S.REST or state == S.TALK):
		return
	if is_inside_tree() and not get_tree().get_nodes_in_group("inventory_ui").is_empty():
		return
	_outfit_dirty = false
	set_model(body_model())

## Change bodies in place (the Outsong: the Bearer puts the mask on). The
## swing volume rides the visual, so it moves across.
func set_model(model: String) -> void:
	if vis == null or model == "" or not HumanoidLib.has_model(model) or vis.model_id == model:
		return
	var old := vis
	if hitbox != null and hitbox.get_parent() == old:
		old.remove_child(hitbox)
	# what the old body had in its hands does not cross over: the new one
	# mounts its own (weapon, shield and, on the next drink, the gourd)
	if _gourd_mount != null and is_instance_valid(_gourd_mount):
		old.unmount_gourd(_gourd_mount)
	_gourd_mount = null
	if _torch_light != null:
		_torch_light.queue_free()
		_torch_light = null
	old.name = "VisOld"
	vis = PlayerVisual.new()
	vis.name = "Vis"
	add_child(vis)
	vis.build(DB.weapon(weapon_id).get("kit", "hewing_blade"), model)
	vis.rotation = old.rotation
	if hitbox != null:
		vis.add_child(hitbox)
	old.queue_free()
	# the same arms in the same hands: bow, two-handed carry, shield, torch
	_refresh_weapon_visual()
	if state == S.REST:
		vis.play("kneel", 0.0)

func lock_control(on: bool) -> void:
	input_enabled = not on
	if on:
		velocity = Vector3.ZERO
		# menus freeze input mid-stride; settle the gait so he does not jog
		# in place behind the parchment
		if vis != null and vis.current_clip() in ["walk", "run"]:
			vis.play("idle", 0.2)

func enter_rest() -> void:
	_set_state(S.REST)
	vis.play("kneel", 0.2)

func exit_rest() -> void:
	_set_state(S.MOVE)
	vis.back_to_idle()

func revive_at(pos: Vector3) -> void:
	global_position = pos
	dead = false
	invulnerable = false
	hp = max_hp
	stamina = max_stamina
	poise = max_poise
	gourds = gourd_max
	breath = max_breath
	_ward_hp = 0.0
	_ward_until = 0.0
	_winded = 0.0
	_stam_delay = 0.0
	_poise_delay = 0.0
	_combo_i = 0
	_blocking = false
	_riposte_target = null
	_riposte_t = 0.0
	_show_gourd(false)
	_set_crosshair(false)
	if vis != null and vis.trail != null:
		vis.trail.visible = false
	velocity = Vector3.ZERO
	_set_state(S.MOVE)
	vis.play("RESET")
	vis.back_to_idle()
	breath_changed.emit(breath, max_breath)
	_emit_all()

func heal_full() -> void:
	hp = max_hp
	gourds = gourd_max
	breath = max_breath
	breath_changed.emit(breath, max_breath)
	_emit_all()

func _pressed(action: String) -> bool:
	if sim_active:
		match action:
			"block": return sim_block
			"sprint": return sim_sprint
		return false
	if action == "block" and not _mouse_ok():
		return false
	return input_enabled and Input.is_action_pressed(action)

# --- interaction ---------------------------------------------------------------
func nearest_interactable() -> Interactable:
	if state == S.GOURD:
		return null
	var best: Interactable = null
	var best_d := INF
	for a in _interact_scan.get_overlapping_areas():
		if a is Interactable and (a as Interactable).enabled:
			var d := global_position.distance_squared_to((a as Interactable).zone_global())
			if d < best_d:
				best_d = d
				best = a
	return best

## Suppress interaction for a few frames. Menus call this as they close so the
## same key-press that dismissed them can't immediately re-activate the prop —
## it only has to outlast that press's one-frame just_pressed bleed.
func suppress_interact(frames := 3) -> void:
	_interact_suppress = maxi(_interact_suppress, frames)

func try_interact() -> bool:
	if state != S.MOVE or _interact_suppress > 0:
		return false
	if _riposte_target != null and try_riposte():
		return true
	var it := nearest_interactable()
	if it == null:
		return false
	it.activate(self)
	return true

# --- save --------------------------------------------------------------------
func to_save() -> Dictionary:
	return {
		"attributes": attributes, "level": level, "gourd_max": gourd_max,
		"weapon": weapon_id, "weapon_level": weapon_level,
		"inventory": inventory, "hotbar": hotbar, "attuned_song": attuned_song,
		"armour": armour.duplicate(),
		"pos": [global_position.x, global_position.y, global_position.z],
	}

func from_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	var sa: Dictionary = d.get("attributes", {})
	if sa.has("vitality") and not sa.has("heart"):
		sa["heart"] = sa["vitality"]   # older saves named it vitality
	for k in attributes:
		attributes[k] = int(sa.get(k, attributes[k]))
	level = int(d.get("level", 1))
	gourd_max = int(d.get("gourd_max", 3))
	weapon_id = d.get("weapon", "hewing_blade")
	weapon_level = int(d.get("weapon_level", 0))
	inventory = d.get("inventory", {})
	var hb: Array = d.get("hotbar", [])
	if hb.size() == 5:
		hotbar = hb
	attuned_song = d.get("attuned_song", "")
	armour = starting_armour()
	if d.has("armour"):
		armour = {}
		for slot in armour_slots():
			armour[slot] = String((d["armour"] as Dictionary).get(slot, ""))
	armour_changed.emit()
	recompute_derived()
	heal_full()
	refresh_outfit()   # a loaded Bearer stands up in what he was wearing
	_refresh_weapon_visual()
	weapon_changed.emit(weapon_id)
	inventory_changed.emit()
