extends ArtLineupRegion
## Thornwold art lineup: the Hedgelayer, the Collier and the Rime-stag, Linnet, the Bearer in
## Collier's leathers, the hedging bill and Linnet's song-cord, the charcoal clamp and the hedge gap, at true scale.
## Run: godot --path . res://scenes/sandbox/art_lineup_thornwold.tscn -- --shots
## Writes docs/screens/art_thornwold_<shot>_{thaw,rime}.png.


func _config() -> void:
	region = "thornwold"
	ground_thaw = [Color(0.26, 0.24, 0.14), Color(0.38, 0.36, 0.20)]
	characters = [
		[M + "characters/bearer_collier.glb", 1.8, "walk", -5.6, M + "weapons/hedging_bill.glb"],
		[M + "npcs/linnet.glb", 1.65, "idle", -4.2, ""],
		[M + "enemies/collier.glb", 1.8, "idle", -2.8, ""],
		[M + "enemies/rime_stag.glb", 2.4, "walk", -0.6, ""],
		[M + "bosses/hedgelayer.glb", 3.6, "idle", 4.2, ""],
	]
	boss_clips = [
		[M + "bosses/hedgelayer.glb", "raise_wall", 16.0, 0.5],
		[M + "bosses/hedgelayer.glb", "step_into", 20.5, 0.5],
		[M + "bosses/hedgelayer.glb", "thorn_lash", 25.0, 0.4],
	]
	landmarks = [
		[M + "landmarks/lm_charcoal_clamp.glb", Vector3(-5.0, 0, -9.0), 20.0],
		[M + "landmarks/lm_hedge_gate.glb", Vector3(2.5, 0, -8.0), -10.0],
	]
	bench_pos = Vector3(10.5, 0.35, 0.9)
	items = [
		[M + "weapons/hedging_bill.glb", Vector3(10.5, 0.72, 0.4), Vector3(0, 0, -90)],
		[M + "props/song_cord.glb", Vector3(10.5, 0.70, 1.3), Vector3(0, 0, 0)],
	]
	shots = [
		["row", Vector3(0.0, 2.0, 10.0), Vector3(0.0, 1.5, 0.0), 58.0],
		["boss", Vector3(3.0, 2.0, 5.8), Vector3(4.2, 1.8, 0.0), 55.0],
		["boss_back", Vector3(7.2, 2.3, -4.7), Vector3(4.2, 1.8, 0.0), 55.0],
		["enemies", Vector3(-1.7, 1.5, 5.0), Vector3(-1.7, 1.0, 0.0), 55.0],
		["npcs", Vector3(-4.9, 1.3, 3.6), Vector3(-4.9, 0.95, 0.0), 52.0],
		["landmarks", Vector3(-1.0, 2.6, -1.5), Vector3(-1.0, 0.9, -8.5), 62.0],
		["items", Vector3(10.5, 2.6, 3.2), Vector3(10.5, 0.75, 0.8), 50.0],
		["boss_clips", Vector3(20.5, 2.5, 9.4), Vector3(20.5, 1.6, 0.0), 55.0],
	]
