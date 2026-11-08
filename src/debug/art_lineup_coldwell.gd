extends ArtLineupRegion
## Coldwell art lineup: the Leadvoice (Maren holding Wren), the Upwalker and the Unsung, Maren and
## Wren in THAW, the Bearer in Outsong robes, and the Wellhead stones, at true scale.
## Run: godot --path . res://scenes/sandbox/art_lineup_coldwell.tscn -- --shots
## Writes docs/screens/art_coldwell_<shot>_{thaw,rime}.png.


func _config() -> void:
	region = "coldwell"
	ground_thaw = [Color(0.30, 0.26, 0.18), Color(0.42, 0.38, 0.28)]
	characters = [
		[M + "characters/bearer_outsong.glb", 1.8, "idle", -5.6, ""],
		[M + "npcs/maren_thaw.glb", 1.75, "idle", -4.2, ""],
		[M + "npcs/wren.glb", 1.05, "idle", -3.3, ""],
		[M + "enemies/upwalker.glb", 1.9, "walk", -1.8, ""],
		[M + "enemies/unsung.glb", 1.8, "idle", -0.3, ""],
		[M + "bosses/leadvoice.glb", 4.0, "idle", 4.4, ""],
	]
	boss_clips = [
		[M + "bosses/leadvoice.glb", "hold_note", 16.0, 0.5],
		[M + "bosses/leadvoice.glb", "rise", 20.5, 0.5],
		[M + "bosses/leadvoice.glb", "shelter", 25.0, 0.6],
	]
	landmarks = [
		[M + "landmarks/lm_wellhead.glb", Vector3(1.0, 0, -12.0), 0.0],
	]
	shots = [
		["row", Vector3(0.0, 2.0, 10.0), Vector3(0.0, 1.5, 0.0), 58.0],
		["boss", Vector3(3.2, 2.2, 6.4), Vector3(4.4, 2.0, 0.0), 55.0],
		["boss_back", Vector3(7.4, 2.6, -5.2), Vector3(4.4, 2.0, 0.0), 55.0],
		["enemies", Vector3(-1.1, 1.5, 5.0), Vector3(-1.1, 1.0, 0.0), 55.0],
		["npcs", Vector3(-4.4, 1.3, 3.6), Vector3(-4.4, 0.95, 0.0), 52.0],
		["landmarks", Vector3(1.0, 4.5, -3.0), Vector3(1.0, 0.5, -12.0), 60.0],
		["boss_clips", Vector3(20.5, 2.8, 10.4), Vector3(20.5, 1.8, 0.0), 55.0],
	]
