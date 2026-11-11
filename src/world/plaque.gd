class_name LorePlaque
extends Node3D
## Engraved lore stands — the highland speaks in inscriptions.
## style "note": not a stand but a folded paper on the ground, lamplit —
## for words somebody LEFT rather than words somebody carved. A note that
## sets a flag is taken up by the reading: it lifts, glows out, and is gone.

var text := "..."
var set_flag := ""      # a read that MEANS something: swearing the amend
var flag_toast := ""
var style := "plaque"   # "plaque" | "note"

var _paper: Node3D = null

func _ready() -> void:
	var zone := Interactable.new()
	if style == "note":
		_paper = Node3D.new()
		add_child(_paper)
		var page := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.34, 0.012, 0.46)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.93, 0.89, 0.78)
		mat.roughness = 0.9
		pm.material = mat
		page.mesh = pm
		page.position = Vector3(0, 0.02, 0)
		page.rotation.y = deg_to_rad(24)
		_paper.add_child(page)
		var crease := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.3, 0.014, 0.05)
		cm.material = mat
		crease.mesh = cm
		crease.position = Vector3(0.04, 0.028, -0.08)
		crease.rotation.y = deg_to_rad(-14)
		_paper.add_child(crease)
		# the small light it keeps: a stub of lamp beside it
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.86, 0.55)
		l.light_energy = 1.1
		l.omni_range = 2.8
		l.shadow_enabled = false
		l.position = Vector3(0, 0.5, 0)
		_paper.add_child(l)
		var motes := CPUParticles3D.new()
		motes.amount = 8
		motes.lifetime = 2.2
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		motes.emission_sphere_radius = 0.25
		motes.direction = Vector3.UP
		motes.gravity = Vector3(0, 0.25, 0)
		motes.initial_velocity_min = 0.08
		motes.initial_velocity_max = 0.2
		motes.scale_amount_min = 0.55
		motes.scale_amount_max = 1.15
		var mm := QuadMesh.new()
		mm.size = Vector2(0.055, 0.055)
		var mmat := StandardMaterial3D.new()
		mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mmat.billboard_keep_scale = true
		mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mmat.albedo_texture = AreaPortal._radial_tex()
		mmat.albedo_color = Color(1.0, 0.90, 0.58, 0.72)
		mm.material = mmat
		motes.mesh = mm
		motes.position.y = 0.15
		_paper.add_child(motes)
		zone.prompt = "Read the note"
	else:
		add_child(KitLib.instance("plaque"))
		zone.prompt = "Read"
	zone.setup_zone(1.3, 1.4)
	zone.activated.connect(func(_p):
		Game.lore_panel.emit(text)
		if set_flag != "" and not World.flag(set_flag):
			World.set_flag(set_flag)
			World.save_game()
			if flag_toast != "":
				Game.toast.emit(flag_toast)
			AudioDirector.play("world/plaque")
			if style == "note":
				_taken(zone))
	add_child(zone)

## the note is taken by its reader: rises a hand's width, burns to light
func _taken(zone: Interactable) -> void:
	zone.enabled = false
	if _paper == null:
		queue_free()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_paper, "position:y", 0.55, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_paper, "rotation:y", deg_to_rad(70), 1.1)
	tw.tween_property(_paper, "scale", Vector3(0.02, 0.02, 0.02), 1.1) \
		.set_delay(0.35)
	tw.chain().tween_callback(queue_free)
