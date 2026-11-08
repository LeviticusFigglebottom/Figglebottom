extends ArtLineupRegion
## Kettle Fjord art lineup: the Ice-Cutter, the three fjord frost-taken, Ivo, the Bearer in
## Ice-cutter's furs, the auger and harpoon, the fish-kettle and the sledge, at true scale.
## Run: godot --path . res://scenes/sandbox/art_lineup_kettle_fjord.tscn -- --shots
## Writes docs/screens/art_kettle_fjord_<shot>_{thaw,rime}.png.


func _config() -> void:
	region = "kettle_fjord"
	ground_thaw = [Color(0.28, 0.27, 0.25), Color(0.42, 0.40, 0.36)]
	characters = [
		[M + "characters/bearer_icefur.glb", 1.8, "walk", -5.4, M + "weapons/ice_auger.glb"],
		[M + "npcs/ivo.glb", 1.55, "idle", -4.0, ""],
		[M + "enemies/ice_fisher.glb", 1.7, "idle", -2.6, ""],
		[M + "enemies/sealer.glb", 2.0, "idle", -1.0, ""],
		[M + "enemies/sledge_dog.glb", 1.05, "walk", 0.8, ""],
		[M + "bosses/ice_cutter.glb", 3.0, "idle", 4.2, ""],
	]
	boss_clips = [
		[M + "bosses/ice_cutter.glb", "drill_down", 16.0, 0.5],
		[M + "bosses/ice_cutter.glb", "haul_trace", 20.0, 0.5],
		[M + "bosses/ice_cutter.glb", "ring_cut", 24.0, 0.45],
	]
	landmarks = [
		[M + "landmarks/lm_fish_kettle.glb", Vector3(-3.5, 0, -7.0), 15.0],
		[M + "landmarks/lm_fish_kettle.glb", Vector3(-6.5, 0, -9.0), -30.0],
		[M + "landmarks/lm_sledge.glb", Vector3(3.0, 0, -7.5), 70.0],
	]
	bench_pos = Vector3(10.5, 0.35, 0.9)
	items = [
		[M + "weapons/ice_auger.glb", Vector3(10.5, 0.72, 0.4), Vector3(0, 0, -90)],
		[M + "weapons/sealer_harpoon.glb", Vector3(10.5, 0.72, 1.2), Vector3(0, 0, -90)],
	]
	shots = [
		["row", Vector3(0.0, 1.8, 9.0), Vector3(0.0, 1.3, 0.0), 58.0],
		["boss", Vector3(3.0, 1.9, 5.0), Vector3(4.2, 1.5, 0.0), 55.0],
		["boss_back", Vector3(7.0, 2.2, -4.0), Vector3(4.2, 1.5, 0.0), 55.0],
		["enemies", Vector3(-0.8, 1.4, 4.4), Vector3(-0.8, 1.0, 0.0), 55.0],
		["npcs", Vector3(-4.7, 1.3, 3.4), Vector3(-4.7, 0.95, 0.0), 50.0],
		["landmarks", Vector3(-0.5, 2.4, -1.5), Vector3(-0.5, 0.8, -8.0), 62.0],
		["items", Vector3(10.5, 2.6, 3.2), Vector3(10.5, 0.75, 0.8), 50.0],
		["boss_clips", Vector3(20.0, 2.4, 8.5), Vector3(20.0, 1.3, 0.0), 55.0],
	]
