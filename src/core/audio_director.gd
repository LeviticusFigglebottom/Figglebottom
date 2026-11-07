extends Node
## AudioDirector — music/ambience per world state, one-shot SFX helpers.
## All streams are optional: missing files no-op so headless tests run silent.
## What plays where is data: data/state_profiles.json (per-state music,
## ambience and their crossfades) and data/audio.json (title, the Outsong,
## holdfast themes, the state wave, footstep surfaces, foley sets).

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _active_music := ""
var _active_ambience := ""
var _shutting_down := false
var _rite_serial := 0

const AMB_DB := -10.0

func _ready() -> void:
	_music_a = _player("Music")
	_music_b = _player("Music")
	_amb_a = _player("Ambience")
	_amb_b = _player("Ambience")

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func cfg(key: String, fallback = null):
	return DB.table("audio").get(key, fallback)

func music_path(key: String) -> String:
	return String((cfg("music", {}) as Dictionary).get(key, {}).get("path", ""))

func _stream(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path)

## Music/ambience beds loop. The .ogg imports carry the loop flag (the audio
## suite checks it); this is the belt to that brace for any WAV dropped in.
## The Outsong is the one piece that must NOT loop: callers say so.
func _make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var bytes_per_frame := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
			if w.stereo:
				bytes_per_frame *= 2
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / bytes_per_frame
	elif "loop" in stream:
		stream.set("loop", true)

## Crossfade to a music track (by res path); pass "" to fade out.
## fade_out < 0 uses the same time as the fade in.
func play_music(path: String, fade := 2.0, fade_out := -1.0, loop := true) -> void:
	if _shutting_down or _active_music == path:
		return
	_active_music = path
	_rite_serial += 1
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	var stream := _stream(path)
	incoming.stop()
	if stream:
		if loop:
			_make_looping(stream)
		incoming.stream = stream
		incoming.volume_db = -40.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", 0.0, maxf(fade, 0.01))
	if outgoing.playing:
		var t := create_tween()
		t.tween_property(outgoing, "volume_db", -40.0, maxf(fade if fade_out < 0.0 else fade_out, 0.01))
		t.tween_callback(outgoing.stop)

## The world's own bed for a state, with that state's crossfades
## (state_profiles.json: music_fade_in, ambience_fade).
func play_state(env: Node, state: int, fade_scale := 1.0) -> void:
	if env == null:
		return
	var prof: Dictionary = env.audio_for(state)
	play_music(String(prof.get("music", "")), float(prof.get("music_fade_in", 3.0)) * fade_scale)
	play_ambience(String(prof.get("ambience", "")), float(prof.get("ambience_fade", 2.0)) * fade_scale)

# ------------------------------------------------------------ the Outsong
## When a Holdfast is released the household's song is sung for them: the
## Outsong plays through once (it does not loop), and the world's music
## returns only after it has finished. Returns the song's length (0 if
## absent) so callers can pace what follows.
func play_outsong(then_path: String, then_fade := 4.0) -> float:
	var e: Dictionary = (cfg("music", {}) as Dictionary).get("outsong", {})
	var stream := _stream(String(e.get("path", "")))
	if stream == null:
		duck_ambience(false)
		play_music(then_path, then_fade)
		return 0.0
	duck_ambience(true)
	play_music(String(e.get("path", "")), float(e.get("fade", 1.0)), 2.0, false)
	var serial := _rite_serial
	var secs := stream.get_length()
	get_tree().create_timer(maxf(secs - 2.0, 0.1), false).timeout.connect(func() -> void:
		# only if nothing else (a rest, a death, a new area) took the music
		if serial == _rite_serial and not _shutting_down:
			duck_ambience(false)
			play_music(then_path, then_fade))
	return secs

# ------------------------------------------------------ boss battle themes
## One theme per holdfast (data/audio.json music.boss_<enemy_id>), falling
## back to the shared one. While it plays the ambience bed ducks to silence;
## combat feedback on the SFX bus stays. The theme ends (and the world's own
## sound returns) when the holdfast rests or the Bearer falls.
var _amb_base := 0.0
var _amb_ducked := false

func boss_theme(enemy_id: String, fade := 1.5) -> void:
	var path := music_path("boss_" + enemy_id)
	if path == "" or not ResourceLoader.exists(path):
		path = music_path(String(cfg("boss_fallback", "")))
	duck_ambience(true)
	play_music(path, fade)

func end_boss_theme(area_music: String, fade := 2.5) -> void:
	duck_ambience(false)
	play_music(area_music, fade)

func duck_ambience(on: bool) -> void:
	var idx := AudioServer.get_bus_index("Ambience")
	if idx < 0 or on == _amb_ducked:
		return
	if on:
		_amb_base = AudioServer.get_bus_volume_db(idx)
	_amb_ducked = on
	var target := -60.0 if on else _amb_base
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(idx, v),
			AudioServer.get_bus_volume_db(idx), target, 0.9)

## Crossfade the ambience bed (two players, like the music).
func play_ambience(path: String, fade := 2.0) -> void:
	if _shutting_down or path == _active_ambience:
		return
	_active_ambience = path
	var incoming := _amb_b if _amb_a.playing else _amb_a
	var outgoing := _amb_a if incoming == _amb_b else _amb_b
	var stream := _stream(path)
	incoming.stop()
	if stream != null:
		_make_looping(stream)
		incoming.stream = stream
		incoming.volume_db = -50.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", AMB_DB, maxf(fade, 0.01))
	if outgoing.playing:
		var t := create_tween()
		t.tween_property(outgoing, "volume_db", -50.0, maxf(fade, 0.01))
		t.tween_callback(outgoing.stop)

# --------------------------------------------------------------- foley
## The ground under a foot: turf, shingle, plank or snow. Terrain answers
## from its painted splat (shingle) and the world state (RIME lies under
## snow outdoors); house floors and built decks are plank, the latter
## snowed over in RIME.
func surface_at(pos: Vector3) -> String:
	var area: Node = Game.current_area
	if area == null or not is_instance_valid(area):
		return "turf"
	var fs: Dictionary = cfg("footsteps", {})
	var rime: bool = World.get_area_state(Game.current_area_id) == RH.WState.RIME
	if _indoors(area, pos):
		return "plank"   # under a roof: boarded floors, and no snow
	var terrain = area.get("terrain")
	if terrain != null and terrain.contains(pos.x, pos.z) \
			and absf(pos.y - terrain.height_at(pos.x, pos.z)) < float(fs.get("on_ground_tolerance", 0.45)):
		if rime:
			return "snow"
		return "shingle" if terrain.splat_at(pos.x, pos.z, 0) > float(fs.get("shingle_splat", 0.45)) else "turf"
	return "snow" if rime else "plank"

func _indoors(area: Node, pos: Vector3) -> bool:
	if not area.has_meta("def"):
		return false
	for hs in (area.get_meta("def") as Dictionary).get("houses", []):
		var c := Vector2(float(hs["center"][0]), float(hs["center"][1]))
		var a := deg_to_rad(float(hs.get("yaw", 0.0)))
		var d := Vector2(pos.x, pos.z) - c
		var lx := d.x * cos(a) - d.y * sin(a)
		var lz := d.x * sin(a) + d.y * cos(a)
		var y0 := float(hs.get("y", 0.0))
		if absf(lx) < float(hs["size"][0]) * 0.5 and absf(lz) < float(hs["size"][1]) * 0.5 \
				and pos.y > y0 - 0.5 and pos.y < y0 + float(hs.get("wall_h", 3.2)):
			return true
	return false

func footstep_path(surface: String, idx: int) -> String:
	var fs: Dictionary = cfg("footsteps", {})
	var n := int(fs.get("variants", 4))
	return String(fs.get("path", "res://assets/audio/foley/step_%s_%d.wav")) % [surface, (idx % n) + 1]

func footstep(pos: Vector3, idx: int, volume_db := 0.0) -> void:
	sfx_at(footstep_path(surface_at(pos), idx), pos, volume_db, randf_range(0.93, 1.07))

## A foley path by key; lists pick a variant at random.
func foley(key: String) -> String:
	var v = (cfg("foley", {}) as Dictionary).get(key, "")
	if v is Array:
		return String((v as Array).pick_random()) if not (v as Array).is_empty() else ""
	return String(v)

## Fire-and-forget positional SFX.
func sfx_at(path: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if _shutting_down:
		return
	var stream := _stream(path)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pos
	p.play()

## Non-positional SFX (UI, stingers).
func sfx(path: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if _shutting_down:
		return
	var stream := _stream(path)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()

func shutdown() -> void:
	_shutting_down = true
	var roots: Array[Node] = [self]
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		roots = [get_tree().root]
	var stack: Array[Node] = roots.duplicate()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is AudioStreamPlayer:
			var p := n as AudioStreamPlayer
			p.stop()
			p.stream = null
		elif n is AudioStreamPlayer3D:
			var p3 := n as AudioStreamPlayer3D
			p3.stop()
			p3.stream = null
		for c in n.get_children():
			stack.append(c)
	OS.delay_msec(60)

func _exit_tree() -> void:
	shutdown()
