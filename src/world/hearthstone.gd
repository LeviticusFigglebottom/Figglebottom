class_name Hearthstone
extends Node3D
## THE rest site and world-toggle. Keeping hearth here heals, respawns the
## dead, anchors the Bearer's return — and turns the world over between
## its thaw and its rime. (DECISIONS D-008/D-009)

@export var hearth_id := "hearth"
@export var display_name := "Hearthstone"

var area: Area = null
var zone: Interactable
var _flames: Array[GeometryInstance3D] = []

var _light: OmniLight3D = null

func _ready() -> void:
	add_to_group(RH.GROUP_STATE_LISTENERS)
	add_to_group("hearths")
	var vis := KitLib.instance("hearthstone")
	add_child(vis)
	# solid post — you rest at the hearth, you don't walk through it
	var lbody := StaticBody3D.new()
	lbody.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	lbody.collision_mask = 0
	var lcs := CollisionShape3D.new()
	var lcyl := CapsuleShape3D.new()
	# waist-high: enough to stop a body, low enough for the camera's swept
	# sphere to pass over. A 2.4 m invisible post folded the arm into the
	# Bearer's cloak whenever the hearth was behind him (every rest at the
	# Long Hearth, every wake at a hearth)
	lcyl.radius = 0.38
	lcyl.height = 0.95
	lcs.shape = lcyl
	lcs.position.y = 0.475
	lbody.add_child(lcs)
	Surfaces.stamp_kind(lbody, "hearth")
	vis.add_child(lbody)
	_flames = _find_flames(vis)
	var lights := KitLib.add_flame_lights(vis, 2.2, 8.8)
	if lights.size() > 0:
		_light = lights[0]
	zone = Interactable.new()
	zone.prompt = "Keep hearth"
	zone.setup_zone(1.9, 1.8)
	zone.activated.connect(_on_activated)
	add_child(zone)
	var hc: Dictionary = AudioDirector.amb_cfg().get("hearth", {})
	_crackle = AudioDirector.loop_at(self, String(hc.get("bed", "")), float(hc.get("db", 0.0)))
	_tint_for(World.get_area_state(_area_id()))

func _area_id() -> String:
	return area.area_id if area != null else Game.current_area_id

func _find_flames(root: Node) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D and String(n.name).contains("hearth_flame"):
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out

func _on_activated(player) -> void:
	if player == null:
		Game.hearth_flow(self, null)
		return
	player.lock_control(true)
	player.velocity = Vector3.ZERO
	get_tree().call_group("hud", "clear_area_title")
	var ui := RestUI.new(self, player)
	get_tree().root.add_child(ui)
	AudioDirector.play("ui/open")

var _crackle: AudioStreamPlayer3D

func on_world_state(area_id: String, s: RH.WState) -> void:
	if area_id == _area_id():
		_tint_for(s)

## THAW: low warm tongues over lit coals. RIME: the flames are out (the flame
## shader drops them as the front passes) and only the banked coals and their
## ember light are left, so the tint only matters while the wave is crossing.
func _tint_for(s: RH.WState) -> void:
	var rime := s == RH.WState.RIME
	for f in _flames:
		f.set_instance_shader_parameter("flame_tint", Vector3(1.0, 0.4, 0.1) if rime else Vector3(1.0, 0.5, 0.14))
		f.set_instance_shader_parameter("flame_energy", 0.7 if rime else 0.9)
	# sparks only while there is a flame to throw them
	for e in find_children("embers", "CPUParticles3D", true, false):
		(e as CPUParticles3D).emitting = not rime
	if _crackle != null:
		# banked coals tick; they do not crackle
		var hc: Dictionary = AudioDirector.amb_cfg().get("hearth", {})
		_crackle.volume_db = float(hc.get("db", 0.0)) + (float(hc.get("rime_db", -14.0)) if rime else 0.0)
	if _light:
		_light.light_color = Color(1.0, 0.68, 0.32)
		_light.light_energy = 2.2

func respawn_point() -> Vector3:
	return global_position + global_transform.basis.z * 1.4
