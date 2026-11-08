extends ArtLineupRegion
## ShepherdsReach art lineup: the Fellcaller, the Frost-ram and the Drover, Old Calder, the Bearer in
## Shepherd's fleece, the crook and the calling horn, the sheiling and the High Fold cairn, at true scale.
## Run: godot --path . res://scenes/sandbox/art_lineup_shepherds_reach.tscn -- --shots
## Writes docs/screens/art_shepherds_reach_<shot>_{thaw,rime}.png.


func _config() -> void:
	region = "shepherds_reach"
	ground_thaw = [Color(0.26, 0.30, 0.16), Color(0.40, 0.44, 0.24)]
	characters = [
		[M + "characters/bearer_fleece.glb", 1.8, "walk", -5.6, M + "weapons/shepherd_crook.glb"],
		[M + "npcs/old_calder.glb", 1.75, "idle", -4.2, ""],
		[M + "enemies/drover.glb", 2.1, "idle", -2.6, ""],
		[M + "enemies/frost_ram.glb", 1.3, "walk", -0.6, ""],
		[M + "bosses/fellcaller.glb", 3.4, "idle", 4.2, ""],
	]
	boss_clips = [
		[M + "bosses/fellcaller.glb", "call", 16.0, 0.5],
		[M + "bosses/fellcaller.glb", "ram_charge", 20.5, 0.45],
		[M + "bosses/fellcaller.glb", "summon", 25.0, 0.5],
	]
	landmarks = [
		[M + "landmarks/lm_sheiling.glb", Vector3(-4.5, 0, -9.0), 25.0],
		[M + "landmarks/lm_fold_cairn.glb", Vector3(3.0, 0, -8.0), -15.0],
	]
	bench_pos = Vector3(10.5, 0.35, 0.9)
	items = [
		[M + "weapons/shepherd_crook.glb", Vector3(10.5, 0.72, 0.4), Vector3(0, 0, -90)],
		[M + "props/fellcaller_horn.glb", Vector3(10.5, 0.85, 1.3), Vector3(0, 0, 0)],
	]
	shots = [
		["row", Vector3(0.0, 2.0, 10.0), Vector3(0.0, 1.5, 0.0), 58.0],
		["boss", Vector3(3.0, 1.9, 5.4), Vector3(4.2, 1.7, 0.0), 55.0],
		["boss_back", Vector3(7.2, 2.2, -4.4), Vector3(4.2, 1.7, 0.0), 55.0],
		["enemies", Vector3(-1.6, 1.5, 5.0), Vector3(-1.6, 1.0, 0.0), 55.0],
		["npcs", Vector3(-4.9, 1.3, 3.6), Vector3(-4.9, 0.95, 0.0), 52.0],
		["landmarks", Vector3(-0.8, 2.6, -1.5), Vector3(-0.8, 1.0, -8.5), 62.0],
		["items", Vector3(10.5, 2.6, 3.2), Vector3(10.5, 0.75, 0.8), 50.0],
		["boss_clips", Vector3(20.5, 2.4, 8.8), Vector3(20.5, 1.5, 0.0), 55.0],
	]
