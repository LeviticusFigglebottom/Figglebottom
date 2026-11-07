extends TestBase
## Audio: every state's music and ambience resolves to a real stream that
## loops (as imported, before AudioDirector touches it), the Outsong does
## not, the buses exist, the state crossfades are data, the wave/foley sets
## are on disk, and footsteps read the ground (shingle, turf, plank, snow).

func _ready() -> void:
	_run.call_deferred()

func _fresh(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	# CACHE_MODE_IGNORE: judge the import, not a resource the director looped
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioStream

func _loops(s: AudioStream) -> bool:
	if s is AudioStreamOggVorbis:
		return (s as AudioStreamOggVorbis).loop
	if s is AudioStreamWAV:
		return (s as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return bool(s.get("loop")) if "loop" in s else false

func _run() -> void:
	print("== buses")
	for b in ["Music", "Ambience", "SFX", "UI"]:
		check(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)

	print("== every state's music and ambience")
	var f := FileAccess.open("res://data/state_profiles.json", FileAccess.READ)
	var prof: Dictionary = JSON.parse_string(f.get_as_text())
	for st in ["thaw", "rime"]:
		var p: Dictionary = prof[st]
		for key in ["music", "ambience"]:
			var path := String(p.get(key, ""))
			var s := _fresh(path)
			check(s != null, "%s %s resolves (%s)" % [st, key, path])
			if s != null:
				check(_loops(s), "%s %s is flagged to loop" % [st, key])
				check(s.get_length() > 40.0, "%s %s is a long bed, not a sting (%.1f s)" % [st, key, s.get_length()])
		check(float(p.get("music_fade_in", 0.0)) > 0.0 and float(p.get("ambience_fade", 0.0)) > 0.0,
				"%s crossfades are set in state_profiles.json" % st)

	print("== title, Outsong, holdfast themes")
	var music: Dictionary = DB.table("audio").get("music", {})
	check(music.has("title") and music.has("outsong"), "audio.json names the title and the Outsong")
	for k in music:
		var e: Dictionary = music[k]
		var s := _fresh(String(e.get("path", "")))
		check(s != null, "%s resolves (%s)" % [k, e.get("path", "")])
		if s != null:
			check(_loops(s) == bool(e.get("loop", true)), "%s loop flag is %s" % [k, str(bool(e.get("loop", true)))])
	check(AudioDirector.music_path("boss_netmender") != "", "the Netmender has her own theme")

	print("== the wave and the foley")
	var wave: Dictionary = DB.table("audio").get("wave", {})
	for k in ["to_rime", "to_thaw"]:
		var s := _fresh(String(wave.get(k, "")))
		check(s != null and s.get_length() > 4.0, "the wave %s breath exists (%.1f s)" % [k, s.get_length() if s else 0.0])
	for k in ["frost_hit", "frost_fall", "coal_catch"]:
		var path := AudioDirector.foley(k)
		check(_fresh(path) != null, "foley %s resolves (%s)" % [k, path])
	var missing := 0
	for surf in ["turf", "shingle", "plank", "snow"]:
		for i in 4:
			if _fresh(AudioDirector.footstep_path(surf, i)) == null:
				missing += 1
	check(missing == 0, "every footstep surface has its 4 variants (%d missing)" % missing)

	print("== the director plays a state's bed, crossfaded")
	World.reset()
	var area := AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	StateDirector.snap(area, RH.WState.THAW)
	await ticks(4)
	check(String(AudioDirector._active_music) == String(prof["thaw"]["music"]), "THAW music is playing")
	check(String(AudioDirector._active_ambience) == String(prof["thaw"]["ambience"]), "THAW ambience is playing")

	print("== footsteps read the ground")
	var strand := Vector3(-4.0, area.terrain.height_at(-4.0, 62.0), 62.0)
	var hall := Vector3(0.0, 22.15, -36.0)
	var s_thaw := AudioDirector.surface_at(strand)
	var h_thaw := AudioDirector.surface_at(hall)
	check(s_thaw == "shingle", "THAW: the Strand is shingle (got %s)" % s_thaw)
	check(h_thaw == "plank", "THAW: the Longhouse floor is plank (got %s)" % h_thaw)
	StateDirector.snap(area, RH.WState.RIME)
	await ticks(2)
	var s_rime := AudioDirector.surface_at(strand)
	var h_rime := AudioDirector.surface_at(hall)
	check(s_rime == "snow", "RIME: the Strand lies under snow (got %s)" % s_rime)
	check(h_rime == "plank", "RIME: no snow falls indoors (got %s)" % h_rime)
	check(String(AudioDirector._active_music) == String(prof["rime"]["music"]), "RIME music follows the state")
	finish()
