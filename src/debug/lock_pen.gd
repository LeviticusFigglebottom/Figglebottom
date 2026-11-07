class_name LockPen
extends Node3D
## A small walled floor with the Bearer and three training pells in a fan
## ahead of him: the fixture for lock-on switching (the deltas suite and its
## screenshots). Pells sit left, centre and right of the Bearer's facing.

const PELLS := {
	"Left": Vector3(-3.4, 0, -6.0),
	"Centre": Vector3(0.0, 0, -7.0),
	"Right": Vector3(3.4, 0, -6.0),
}

var player: Player
var pells := {}   # name -> TrainingDummy

func _ready() -> void:
	for i in range(4):
		for j in range(4):
			var f := KitLib.instance("floor_4x4")
			f.position = Vector3(i * 4 - 6, 0, j * 4 - 10)
			KitLib.add_collision(f, RH.L_WORLD_BASE)
			add_child(f)
	for n in PELLS:
		var d := TrainingDummy.new()
		d.name = n
		d.position = PELLS[n]
		add_child(d)
		pells[n] = d
	player = Player.new()
	player.name = "Player"
	player.sim_active = true
	add_child(player)
	player.position = Vector3(0, 0.1, 0)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -140, 0)
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.34, 0.32)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.52, 0.5)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
