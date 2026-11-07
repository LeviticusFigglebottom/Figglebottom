class_name NPC
extends Node3D
## A living soul of the thaw state. Faces the Bearer when near; talk
## opens dialogue with lore + services.

var npc_id := ""
var cfg: Dictionary = {}

var _vis: CharVisual

func _ready() -> void:
	cfg = DB.npc(npc_id)
	cfg["id"] = npc_id
	_vis = CharVisual.new()
	add_child(_vis)
	var body_id: String = cfg.get("body", "mannequin_thaw")
	_vis.build_body(body_id, 0.8, 0.9)
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
	if cfg.get("pose", "") == "kneel":
		_vis.play("pray", 0.0)
		set_physics_process(false)
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
	add_child(body)
	# the mute keep their words to themselves: no prompt, no dialogue
	if not cfg.get("mute", false):
		var zone := Interactable.new()
		zone.prompt = "Speak with %s" % cfg.get("short_name", cfg.get("name", "?"))
		zone.setup_zone(1.8, 1.8)
		zone.activated.connect(_on_talk)
		add_child(zone)

func _physics_process(dt: float) -> void:
	if _vis == null or not is_visible_in_tree():
		return
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
		_vis.rotation.y = ty
		if player.get("vis") != null:
			player.vis.rotation.y = atan2(to.x, to.z)
	player.enter_dialogue()
	_vis.play("talk", 0.4)
	var ui := DialogueUI.new(cfg, self)
	ui.tree_exited.connect(func() -> void:
		if is_instance_valid(_vis):
			_vis.back_to_idle(0.4))
	get_tree().root.add_child(ui)
	AudioDirector.sfx("res://assets/audio/ui_tick.wav", -8.0)
