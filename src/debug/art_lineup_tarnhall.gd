extends ArtLineupRegion
## Tarnhall art lineup: the Host, the three hall frost-taken, Lusse, the Bearer in Guest-garb, the
## cleaver and hall shield, the great doors, the high seat and the guest-tally post, at true scale.
## Run: godot --path . res://scenes/sandbox/art_lineup_tarnhall.tscn -- --shots
## Writes docs/screens/art_tarnhall_<shot>_{thaw,rime}.png.


func _config() -> void:
	region = "tarnhall"
	ground_thaw = [Color(0.30, 0.24, 0.17), Color(0.44, 0.36, 0.25)]
	characters = [
		[M + "characters/bearer_hall.glb", 1.8, "walk", -5.6, M + "weapons/feast_cleaver.glb"],
		[M + "npcs/lusse.glb", 1.7, "idle", -4.2, ""],
		[M + "enemies/feast_guest.glb", 1.8, "idle", -2.8, ""],
		[M + "enemies/cupbearer.glb", 1.7, "idle", -1.4, ""],
		[M + "enemies/hall_champion.glb", 2.1, "idle", 0.2, ""],
		[M + "bosses/host.glb", 4.0, "idle", 4.6, ""],
	]
	boss_clips = [
		[M + "bosses/host.glb", "table_sweep", 16.0, 0.45],
		[M + "bosses/host.glb", "bench_throw", 20.5, 0.5],
		[M + "bosses/host.glb", "raise_guests", 25.0, 0.6],
	]
	landmarks = [
		[M + "landmarks/lm_hall_doors.glb", Vector3(-1.0, 0, -11.0), 0.0],
		[M + "landmarks/lm_high_seat.glb", Vector3(5.5, 0, -7.0), -20.0],
		[M + "landmarks/lm_guest_post.glb", Vector3(-6.0, 0, -7.5), 0.0],
	]
	bench_pos = Vector3(10.5, 0.35, 0.9)
	items = [
		[M + "weapons/feast_cleaver.glb", Vector3(10.5, 0.72, 0.4), Vector3(0, 0, -90)],
		[M + "weapons/tarnhall_shield.glb", Vector3(10.5, 0.75, 1.3), Vector3(-90, 0, 0)],
	]
	shots = [
		["row", Vector3(0.0, 2.0, 10.0), Vector3(0.0, 1.5, 0.0), 58.0],
		["boss", Vector3(3.3999999999999995, 2.2, 6.4), Vector3(4.6, 2.0, 0.0), 55.0],
		["boss_back", Vector3(7.6, 2.6, -5.2), Vector3(4.6, 2.0, 0.0), 55.0],
		["enemies", Vector3(-1.3, 1.5, 5.0), Vector3(-1.3, 1.0, 0.0), 55.0],
		["npcs", Vector3(-4.9, 1.3, 3.6), Vector3(-4.9, 0.95, 0.0), 52.0],
		["landmarks", Vector3(-0.5, 2.6, -1.0), Vector3(-0.5, 2.0, -9.0), 68.0],
		["items", Vector3(10.5, 2.6, 3.2), Vector3(10.5, 0.75, 0.8), 50.0],
		["boss_clips", Vector3(20.5, 2.8, 10.4), Vector3(20.5, 1.8, 0.0), 55.0],
	]
