extends Node3D
## Health-bar sandbox: a rank of real Enemy nodes with their floating bars
## popped to different fractions, for visual sign-off. AI/physics are frozen so
## they hold still for the shot. Run:
##   tools/shot.sh docs/wip/hpbar.png --sandbox=hpbar --shot-cam=0,1.9,6.2,0,-6

func _ready() -> void:
	# lighting + sky so the scene reads
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.055, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.52, 0.6)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.1
	add_child(sun)

	# a stone floor slab
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.28, 0.28, 0.3)
	fl.material_override = fm
	add_child(fl)

	# three foes at staggered health, bars forced visible
	_foe("rimewalker", Vector3(-2.4, 0, 0), 0.38)
	_foe("netmender", Vector3(0, 0, 0), 0.72)
	_foe("rimewalker", Vector3(2.4, 0, 0), 0.94)

func _foe(id: String, pos: Vector3, ratio: float) -> void:
	var en := Enemy.new()
	en.setup(id)
	add_child(en)
	en.global_position = pos
	en.set_physics_process(false)   # hold the pose; bars still animate via _process
	if en.vis != null:
		en.vis.rotation.y = PI       # face +Z toward the shot camera
		en.vis.idle()
	if en.hpbar != null:
		en.hpbar.set_forced(true)
		en.hpbar.hit(ratio)
