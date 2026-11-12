class_name NPC
extends Node3D
## A living soul of the thaw state. Faces the Bearer when near; talk
## opens dialogue with lore + services.

var npc_id := ""
var cfg: Dictionary = {}
## The area's own spec for this soul (pose and seat may be set per place:
## the same Ivo stands by the dogs, or sits at the kettle after the release).
var spec: Dictionary = {}
## Seated (npcs.json or area "pose": "sit", "sit_talk"): keeps its clip, does
## not turn for the Bearer, does not stand to greet.
var seated := false

var _vis: CharVisual

func _ready() -> void:
	cfg = DB.npc(npc_id)
	cfg["id"] = npc_id
	_vis = CharVisual.new()
	add_child(_vis)
	# a Tripo villager (npcs.json "model"); the mannequin stands in otherwise
	var model := String(cfg.get("model", ""))
	if model == "" or not _vis.build_model(model):
		_vis.build_body(String(cfg.get("body", "mannequin_thaw")), 0.8, 0.9)
	_look_t = randf_range(4.0, 9.0)
	# carried prop (a torch, a tool) in one hand
	var carry: String = cfg.get("carry", "")
	if carry != "" and KitLib.has_piece(carry):
		var m := _vis.mount("hand_%s" % cfg.get("carry_hand", "l"))
		m.position = Vector3(0, 0.08, 0)
		m.rotation_degrees = Vector3(CharVisual.CARRY_POSE.get(carry, Vector3.ZERO))
		var held := KitLib.instance(carry)
		m.add_child(held)
		KitLib.add_flame_lights(held, 1.2, 3.0)
	# kneeling souls keep their pose; they do not turn for you
	var pose := String(spec.get("pose", cfg.get("pose", "")))
	if pose == "kneel":
		_vis.play("pray", 0.0)
		set_physics_process(false)
	elif pose.begins_with("sit"):
		_sit(pose)
	elif pose == "lie":
		# laid out on the back, head toward local +Z (Old Calder at the cairn)
		seated = true
		_vis.rotation.x = deg_to_rad(88.0)
		_vis.position.y = 0.2
	if cfg.get("frozen", false):
		_freeze_over()
	_overhear = cfg.get("overhear", [])
	# a body: you cannot walk through a living soul
	var tag := String(get_meta("state_tag", "thaw"))
	var bit: int = RH.L_WORLD_THAW if tag == "thaw" else (RH.L_WORLD_RIME if tag == "rime" else RH.L_WORLD_BASE)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << (bit - 1)
	body.collision_mask = 0
	var bcs := CollisionShape3D.new()
	var bcap := CapsuleShape3D.new()
	bcap.radius = 0.36
	bcap.height = 1.6
	bcs.shape = bcap
	bcs.position.y = 0.85
	body.add_child(bcs)
	Surfaces.stamp_kind(body, "npc")   # a blade raises no chips from a living soul
	add_child(body)
	if pose == "lie":
		body.rotation.x = deg_to_rad(88.0)
		body.position.y = -0.5
	# the mute keep their words to themselves: no prompt, no dialogue
	if not cfg.get("mute", false):
		var zone := Interactable.new()
		zone.prompt = "Speak with %s" % cfg.get("short_name", cfg.get("name", "?"))
		zone.setup_zone(1.8, 1.8)
		zone.activated.connect(_on_talk)
		add_child(zone)

## Humanoid villagers fidget: now and then they look about (their own
## "look" clip), and they greet whoever speaks to them.
var _look_t := 6.0

func _physics_process(dt: float) -> void:
	if _vis == null or not is_visible_in_tree():
		return
	_tick_overhear(dt)
	if seated:
		return
	if _vis.is_humanoid():
		_vis.locomotion(dt, 0.0)   # a finished greet or look yields to idle
		_look_t -= dt
		if _look_t <= 0.0:
			_look_t = randf_range(9.0, 16.0)
			if _vis.current_clip() == "idle" and _vis.rig.has_clip("look"):
				_vis.play("look", 0.5)
	var p = Game.player
	if p == null:
		return
	var d2 := global_position.distance_squared_to(p.global_position)
	if d2 < 32.0:
		var to: Vector3 = p.global_position - global_position
		# World bearing to the player, expressed in the NPC node's local frame.
		# All mannequin bodies face -Z at local rotation 0.
		var ty := wrapf(atan2(-to.x, -to.z) - global_rotation.y, -PI, PI)
		if absf(ty) < deg_to_rad(100.0):
			_vis.rotation.y = lerp_angle(_vis.rotation.y, ty, 1.0 - exp(-5.5 * dt))
		elif absf(_vis.rotation.y) > 0.01:
			_vis.rotation.y = lerp_angle(_vis.rotation.y, 0.0, 1.0 - exp(-2.0 * dt))
	elif d2 > 49.0 and absf(_vis.rotation.y) > 0.01:
		_vis.rotation.y = lerp_angle(_vis.rotation.y, 0.0, 1.0 - exp(-2.0 * dt))

func _on_talk(player) -> void:
	if player == null:
		return
	var to: Vector3 = player.global_position - global_position
	if to.length_squared() > 0.001:
		var ty := atan2(-to.x, -to.z) - global_rotation.y
		if not seated:
			_vis.rotation.y = ty
		if player.get("vis") != null:
			player.vis.rotation.y = atan2(to.x, to.z)
		# frame the speaker over the Bearer's right shoulder: from behind,
		# the Bearer's own hood hid whoever was talking
		if player.get("cam") != null and player.cam.locked_target == null:
			player.cam.yaw = atan2(to.x, to.z) + deg_to_rad(float(DB.tuning("camera/talk_yaw_off", 28.0)))
	get_tree().call_group("hud", "clear_area_title")
	player.enter_dialogue()
	if not seated:   # (a seated soul talks from where it sits)
		_vis.play("greet" if _vis.is_humanoid() and _vis.rig.has_clip("greet") else "talk", 0.4)
	var ui := DialogueUI.new(cfg, self)
	ui.tree_exited.connect(func() -> void:
		if is_instance_valid(_vis) and not seated:
			_vis.back_to_idle(0.4))
	get_tree().root.add_child(ui)
	AudioDirector.play("ui/open")

## One of the dead the frost kept where they sat (npcs.json "frozen": Old
## Calder at the fold cairn, in RIME): rimed over, and still.
func _freeze_over() -> void:
	var rime := StandardMaterial3D.new()
	rime.albedo_color = Color(0.82, 0.9, 1.0, 0.62)
	rime.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rime.roughness = 0.55
	rime.emission_enabled = true
	rime.emission = Color(0.5, 0.62, 0.8)
	rime.emission_energy_multiplier = 0.12
	for mi in _vis.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).material_overlay = rime
	set_physics_process(false)
	# (the pose it has is the pose it keeps, once the rig has taken it)
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(_vis) and _vis.rig != null:
			_vis.rig.active = false)

# ---------------------------------------------------------------- sitting
## Sit (the model's own "sit" loop, feet on the floor, hips at about a third
## of its height) on a seat sized to it: a sod or a crate under the pelvis
## ("seat": "turf" | "wood" | "none"; design "height" in metres). "sit_talk"
## sits on the ground itself and needs none. A clip the model lacks falls
## back to "sit".
func _sit(pose: String) -> void:
	seated = true
	var clip := pose
	if _vis.is_humanoid() and not _vis.rig.has_clip(clip):
		clip = "sit"
	_vis.play(clip, 0.0)
	var seat := String(spec.get("seat", cfg.get("seat", "turf" if clip == "sit" else "none")))
	if seat == "none" or clip != "sit":
		return
	var h := float(cfg.get("height", 1.8))
	var mi := MeshInstance3D.new()
	mi.name = "Seat"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.36 * h, SEAT_FRAC * h, 0.3 * h)
	mi.mesh = bm
	# under the pelvis, a little behind the body's origin (it faces -Z)
	mi.position = Vector3(0, SEAT_FRAC * h * 0.5, 0.1 * h)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SEAT_COLOURS.get(seat, SEAT_COLOURS["turf"])
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)

const SEAT_FRAC := 0.27
const SEAT_COLOURS := {"turf": Color(0.26, 0.22, 0.14), "wood": Color(0.36, 0.28, 0.19)}

# ---------------------------------------------------------------- overheard
## A conversation the Bearer can only overhear ("overhear": [[speaker id,
## line], ...] in npcs.json): within overhear_r metres it plays a line every
## overhear_every seconds, low over the belt, and rests a while at the end.
var _overhear: Array = []
var _over_i := 0
var _over_t := 0.0
signal overheard(speaker: String, line: String)

func _tick_overhear(dt: float) -> void:
	if _overhear.is_empty():
		return
	_over_t -= dt
	if _over_t > 0.0:
		return
	var p = Game.player
	if p == null or not is_instance_valid(p):
		return
	if p.get("state") == Player.S.TALK:
		# the Bearer is in a talk: what is overheard waits (Linnet was
		# heard arguing with Eyvind in the same breath as she spoke to him)
		_over_t = 0.5
		return
	var r := float(cfg.get("overhear_r", 8.0))
	if global_position.distance_squared_to(p.global_position) > r * r:
		_over_t = 0.5
		return
	var entry: Array = _overhear[_over_i]
	var who := String(entry[0])
	var name := String(DB.npc(who).get("short_name", who.capitalize())) if who != "" else ""
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("show_overheard"):
			hud.show_overheard(name, String(entry[1]))
	overheard.emit(who, String(entry[1]))
	_over_i += 1
	_over_t = float(cfg.get("overhear_every", 4.6))
	if _over_i >= _overhear.size():
		_over_i = 0
		_over_t += float(cfg.get("overhear_rest", 14.0))
