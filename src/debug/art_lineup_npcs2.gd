extends ArtLineupRegion
## NPC batch 2 lineup (THAW only): Halla and Sten, the THAW Arne Holm with his twins Liv and
## Asta, the THAW Old Pell, Eyvind and Sigga, and the Bearer as a child, at true scale; then the
## two post-release THAW scenes: the Lowe (Arne and the twins sitting outside the barrow) and
## Kettle Fjord (Old Pell and Ivo at the fish-kettle, Halla and Sten by it).
## Run: godot --path . res://scenes/sandbox/art_lineup_npcs2.tscn -- --shots
## Writes docs/screens/art_npcs2_<shot>_thaw.png.

## [path, position, yaw (deg), clip, design height (m), seat colour]
var figures: Array = []


func _config() -> void:
	region = "npcs2"
	states = ["thaw"]
	ground_thaw = [Color(0.30, 0.27, 0.18), Color(0.44, 0.40, 0.27)]
	characters = [
		[M + "characters/bearer_child.glb", 1.2, "idle", -7.0, ""],
		[M + "npcs/liv.glb", 1.1, "idle", -5.8, ""],
		[M + "npcs/asta.glb", 1.1, "idle", -4.6, ""],
		[M + "npcs/wren.glb", 1.05, "idle", -3.4, ""],
		[M + "npcs/halla.glb", 1.7, "idle", -2.0, ""],
		[M + "npcs/sten.glb", 1.8, "idle", -0.6, ""],
		[M + "npcs/pell_thaw.glb", 1.8, "idle", 0.8, ""],
		[M + "npcs/arne_thaw.glb", 1.85, "idle", 2.2, ""],
		[M + "npcs/eyvind_thaw.glb", 1.85, "idle", 3.6, ""],
		[M + "npcs/sigga_thaw.glb", 1.75, "idle", 5.0, ""],
	]
	# the release scenes: the twins' barrow (the Lowe) and a fish-kettle (Kettle Fjord)
	landmarks = [
		[M + "landmarks/lm_barrow_door.glb", Vector3(16.0, 0, -3.2), 0.0],
		[M + "landmarks/lm_fish_kettle.glb", Vector3(29.6, 0, -1.6), 20.0],
	]
	# [path, position, yaw, clip, design height (m), seat colour]: a "sit" figure gets a sod or
	# crate sized to it; sit_talk (Arne's text-prompt clip, shared with Asta) sits on the grass
	figures = [
		[M + "npcs/arne_thaw.glb", Vector3(16.0, 0, 0.0), 0.0, "sit_talk", 1.85, TURF],
		[M + "npcs/liv.glb", Vector3(14.8, 0, 0.45), 30.0, "sit", 1.1, TURF],
		[M + "npcs/asta.glb", Vector3(17.2, 0, 0.45), -30.0, "sit_talk", 1.1, TURF],
		[M + "npcs/pell_thaw.glb", Vector3(28.4, 0, 0.0), 15.0, "sit", 1.8, WOOD],
		[M + "npcs/ivo.glb", Vector3(27.1, 0, 0.6), 40.0, "sit", 1.55, WOOD],
		[M + "npcs/sten.glb", Vector3(31.0, 0, 0.4), -30.0, "sit", 1.8, WOOD],
		[M + "npcs/halla.glb", Vector3(32.3, 0, -0.5), -50.0, "idle", 1.7, WOOD],
	]
	shots = [
		["row", Vector3(-1.0, 1.6, 8.6), Vector3(-1.0, 1.0, 0.0), 60.0],
		["children", Vector3(-5.2, 0.95, 3.2), Vector3(-5.2, 0.6, 0.0), 50.0],
		["adults", Vector3(1.5, 1.4, 4.4), Vector3(1.5, 1.0, 0.0), 55.0],
		["lowe_release", Vector3(16.0, 1.5, 4.4), Vector3(16.0, 0.8, -0.6), 55.0],
		["kettle_release", Vector3(29.6, 1.6, 5.0), Vector3(29.6, 0.8, -0.4), 55.0],
	]


const TURF := Color(0.26, 0.22, 0.14)
const WOOD := Color(0.36, 0.28, 0.19)
## the "sit" preset keeps the feet on the floor and the hips at about 0.34 of the height
const SEAT_FRAC := 0.27


func _ready() -> void:
	super._ready()
	for f in figures:
		var root := _place(f[0], f[1], f[2])
		var h: float = f[4]
		if f[3] == "sit":
			# the seat sits under the pelvis, a little behind the model's origin (models face +Z)
			var back := Basis(Vector3.UP, deg_to_rad(f[2])) * Vector3(0, 0, -0.1 * h)
			_seat(f[1] + back, Vector3(0.36 * h, SEAT_FRAC * h, 0.3 * h), f[2], f[5])
		if root != null:
			_play(root, f[3] if _has_clip(root, f[3]) else "sit")


func _has_clip(root: Node, clip: String) -> bool:
	var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return ap != null and ap.has_animation(clip)


func _seat(pos: Vector3, size: Vector3, yaw: float, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	mi.rotation_degrees.y = yaw
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)
