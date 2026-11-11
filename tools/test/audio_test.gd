extends TestBase
## Audio: every state's music and ambience resolves to a real stream that
## loops (as imported, before AudioDirector touches it), the Outsong does
## not, the buses exist, the state crossfades are data, every effect the
## game asks for is on disk, each footstep surface has its takes, footsteps
## read the ground, and the beds change hands across the state wave with
## no gap.

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

	print("== the wave bridges")
	var wave: Dictionary = DB.table("audio").get("wave", {})
	for k in ["to_rime", "to_thaw"]:
		var s := _fresh(String(wave.get(k, "")))
		check(s != null and s.get_length() > 4.0, "the wave %s bridge exists (%.1f s)" % [k, s.get_length() if s else 0.0])
		if s != null:
			check(not _loops(s), "the wave %s bridge plays once" % k)

	print("== every effect in the registry is on disk")
	var reg: Dictionary = (DB.table("audio").get("sfx", {}) as Dictionary).get("sounds", {})
	check(reg.size() > 80, "the registry is populated (%d keys)" % reg.size())
	var missing := 0
	for key in reg:
		var paths := AudioDirector.sound_paths(key)
		if paths.is_empty():
			missing += 1
		for path in paths:
			if _fresh(path) == null:
				missing += 1
				print("   missing: %s" % path)
	check(missing == 0, "every take of every key loads (%d missing)" % missing)

	print("== every sound the game asks for exists")
	var asked := {}
	_scan_keys("res://src", asked)
	for e in DB.table("enemies").values():
		for k in ["sfx_alert", "sfx_cast"]:
			if String(e.get(k, "")) != "":
				asked[String(e[k])] = "enemies.json"
		for atk in e.get("attacks", []):
			if atk is Dictionary and String(atk.get("sfx_windup", "")) != "":
				asked[String(atk["sfx_windup"])] = "enemies.json"
	var audio: Dictionary = DB.table("audio")
	for fam in audio.get("families", {}).values():
		if fam is Dictionary:
			for k in fam.values():
				asked[String(k)] = "families"
	for k in audio.get("impacts", {}):
		if k != "_doc":
			asked[String(audio["impacts"][k])] = "impacts"
	for k in audio.get("swings", {}):
		if k != "_doc":
			for v in audio["swings"][k]:
				asked[String(v)] = "swings"
	asked[AudioDirector.foley("coal_catch")] = "foley"
	var unresolved := 0
	for key in asked:
		var ok := false
		if String(key).begins_with("res://"):
			ok = _fresh(String(key)) != null
		else:
			ok = int(AudioDirector.sound(String(key)).get("n", 0)) > 0
		if not ok:
			unresolved += 1
			print("   unresolved: %s (%s)" % [key, asked[key]])
	check(asked.size() > 60 and unresolved == 0, "all %d referenced sounds resolve (%d do not)" % [asked.size(), unresolved])

	print("== footsteps: 8 surfaces, walk and run, 4+ takes each")
	var surfaces: Array = (audio.get("footsteps", {}) as Dictionary).get("surfaces", [])
	check(surfaces.size() == 8, "eight surfaces are named (%d)" % surfaces.size())
	var thin := 0
	for surf in surfaces:
		for run in [false, true]:
			if AudioDirector.sound_paths(AudioDirector.footstep_key(String(surf), run)).size() < 4:
				thin += 1
				print("   thin: %s" % AudioDirector.footstep_key(String(surf), run))
	check(thin == 0, "every surface has 4 or more takes, walking and running (%d thin)" % thin)
	check(AudioDirector.sound_paths("foot/land").size() >= 3, "there is a landing")

	print("== strike surfaces")
	for surf in ["wood", "stone", "metal", "ice", "cloth", "turf", "snow"]:
		var key := String((audio.get("impacts", {}) as Dictionary).get(surf, ""))
		check(AudioDirector.sound_paths(key).size() >= 3, "impact on %s has its set (%s)" % [surf, key])
	AudioDirector.impact("stone", Vector3.ZERO)   # must not throw
	AudioDirector.impact("no_such_surface", Vector3.ZERO)

	print("== region ambience layers")
	var regions: Dictionary = (audio.get("ambience", {}) as Dictionary).get("regions", {})
	check(regions.size() == 7, "all seven regions have their layers (%d)" % regions.size())
	var bad_layers := 0
	for rid in regions:
		for st in ["thaw", "rime"]:
			var layers := AudioDirector.ambience_layers(String(rid), st)
			if layers.is_empty():
				bad_layers += 1
			for l in layers:
				var ls := _fresh(String(l[0]))
				if ls == null or not _loops(ls):
					bad_layers += 1
					print("   bad layer: %s" % l[0])
	check(bad_layers == 0, "every region layer resolves and loops (%d bad)" % bad_layers)

	print("== the handover is equal-power")
	var worst := 0.0
	for i in 101:
		var g := AudioDirector.xfade_gains(i / 100.0)
		worst = maxf(worst, absf(g.x * g.x + g.y * g.y - 1.0))
	check(worst < 0.0001, "old^2 + new^2 = 1 all the way across (worst %.5f)" % worst)

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

	print("== the state wave: the beds change hands with no gap")
	await ticks(90)   # let the snap's own short crossfade finish
	check(absf(AudioDirector.ambience_power() - 1.0) < 0.02, "one bed at full level before the wave (%.3f)" % AudioDirector.ambience_power())
	var lo := 9.0
	var hi := 0.0
	var both := false
	var frames := 0
	StateDirector.transition(area, RH.WState.THAW, Vector3(0.0, 22.0, -30.0))
	while StateDirector.transitioning or AudioDirector._bed_x < 1.0:
		await get_tree().process_frame
		var pw := AudioDirector.ambience_power()
		lo = minf(lo, pw)
		hi = maxf(hi, pw)
		if not AudioDirector._bed_old.is_empty() and float(AudioDirector._bed_old.get("gain", 0.0)) > 0.3 \
				and float(AudioDirector._bed_cur.get("gain", 0.0)) > 0.3:
			both = true
		frames += 1
		if frames > 3000:
			break
	check(frames > 30 and frames <= 3000, "the wave ran (%d frames)" % frames)
	check(lo > 0.97 and hi < 1.03, "summed bed power stays level through the wave (%.3f to %.3f)" % [lo, hi])
	check(both, "both beds sound together as the front passes")
	check(AudioDirector._bed_old.is_empty() and String(AudioDirector._active_ambience) == String(prof["thaw"]["ambience"]),
			"afterwards only the THAW bed is left")
	check(AudioDirector._bed_cur.get("players", []).size() >= 2, "the bed carries Saltfell's own layers (%d players)" % AudioDirector._bed_cur.get("players", []).size())
	finish()

## Effect keys named in scripts: "family/name" string literals.
func _scan_keys(dir: String, out: Dictionary) -> void:
	var re := RegEx.new()
	re.compile("\"((?:foot|foley|combat|player|foe|boss|world|impact|ui)/[a-z_0-9]+)\"")
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			for line in FileAccess.get_file_as_string(dir + "/" + f).split("\n"):
				if not line.contains("AudioDirector."):
					continue   # other tables use slashed paths too
				for m in re.search_all(line):
					out[m.get_string(1)] = f
	for d in DirAccess.get_directories_at(dir):
		_scan_keys(dir + "/" + d, out)
