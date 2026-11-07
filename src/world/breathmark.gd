class_name Breathmark
extends Node3D
## The Bearer's dropped warmth: a kneeling wisp of frozen breath and
## light. One chance — replaced (lost) if you fall again before reclaiming.

var amount := 0

func _ready() -> void:
	var zone := Interactable.new()
	zone.prompt = "Reclaim breathmark"
	zone.setup_zone(1.4, 1.4)
	zone.activated.connect(_on_reclaim)
	add_child(zone)
	# visual: a faint kneeling ghost of light + rising motes
	var ghost := CharVisual.new()
	add_child(ghost)
	ghost.build_body("mannequin_wayfarer")
	ghost.scale = Vector3(0.95, 0.95, 0.95)
	ghost.play("kneel", 0.0)
	ghost.anim.advance(1.2)   # settle straight into the kneel
	RH.set_dissolve(ghost, 0.55)
	var p := CPUParticles3D.new()
	p.amount = 32
	p.lifetime = 2.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.42
	p.direction = Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = 0.22
	p.initial_velocity_max = 0.65
	p.gravity = Vector3(0.0, 0.08, 0.0)
	p.scale_amount_min = 0.65
	p.scale_amount_max = 1.35
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.billboard_keep_scale = true
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.94, 0.76, 0.95),
		Color(1.0, 0.82, 0.42, 0.65),
		Color(0.92, 0.62, 0.22, 0.18),
		Color(0.85, 0.50, 0.15, 0.0),
	])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 32
	gt.height = 32
	mm.albedo_texture = gt
	quad.material = mm
	p.mesh = quad
	p.position.y = 0.5
	add_child(p)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position.y = 0.8
	add_child(l)

func _on_reclaim(_player) -> void:
	Game.add_warmth(amount)
	World.clear_breathmark()
	World.save_game()
	AudioDirector.sfx("res://assets/audio/breathmark.wav", -2.0)
	Game.breathmark_reclaimed.emit(amount)
	queue_free()
