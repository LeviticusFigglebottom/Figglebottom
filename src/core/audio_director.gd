extends Node
## AudioDirector — music/ambience per world state, one-shot SFX helpers.
## All streams are optional: missing files no-op so headless tests run silent.
## What plays where is data: data/state_profiles.json (per-state music,
## base ambience and their crossfades) and data/audio.json (title, the
## Outsong, holdfast themes, the state wave, region ambience layers, the
## effect registry, strike surfaces, foe families, footstep ground).

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active_music := ""
var _active_ambience := ""
var _shutting_down := false
var _rite_serial := 0

const AMB_DB := -10.0

func _ready() -> void:
	_music_a = _player("Music")
	_music_b = _player("Music")

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
	play_ambience(String(prof.get("ambience", "")), float(prof.get("ambience_fade", 2.0)) * fade_scale, RH.STATE_NAMES[state])

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

# ------------------------------------------------------------ ambience
## A bed is the state's base loop plus the region's own layers (data/
## audio.json "ambience": sea and gulls at Saltfell, steam at Kettle, sheep
## on the Reach). Two beds can sound at once, and only while one is handing
## over to the other. The handover is equal-power: old = cos, new = sin of
## the same angle, so the two always sum to the same loudness and there is
## no dip in the middle (a straight dB ramp, as this used to be, leaves the
## midpoint some 17 dB down: a hole).
var _bed_cur: Dictionary = {}
var _bed_old: Dictionary = {}
var _bed_x := 1.0          # 0 = all old bed, 1 = all current bed
var _bed_tween: Tween
var _wave: Dictionary = {}

func amb_cfg() -> Dictionary:
	return cfg("ambience", {})

## The region layers for an area in a state: [[path, db], ...].
func ambience_layers(area_id: String, state_name: String) -> Array:
	var a: Dictionary = amb_cfg()
	var region: Dictionary = (a.get("regions", {}) as Dictionary).get(area_id, {})
	var out: Array = []
	for e in region.get(state_name, []):
		out.append([String(a.get("layer_path", "res://assets/audio/ambience/%s.ogg")) % String(e[0]), float(e[1])])
	return out

func _state_name() -> String:
	return RH.STATE_NAMES[World.get_area_state(Game.current_area_id)]

func _bed_player(path: String, db: float) -> AudioStreamPlayer:
	var stream := _stream(path)
	if stream == null:
		return null
	_make_looping(stream)
	var p := _player("Ambience")
	p.stream = stream
	p.volume_db = -80.0
	p.set_meta("base_db", db)
	# not from the top every time: the same eight seconds after every
	# change of state is how a loop gets recognised
	p.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
	return p

func _make_bed(key: String, path: String, layers: Array) -> Dictionary:
	var players: Array[AudioStreamPlayer] = []
	var base := _bed_player(path, float(amb_cfg().get("base_db", AMB_DB)))
	if base != null:
		players.append(base)
	for l in layers:
		var lp := _bed_player(String(l[0]), float(amb_cfg().get("base_db", AMB_DB)) + float(l[1]))
		if lp != null:
			players.append(lp)
	return {"key": key, "players": players, "gain": 0.0}

func _set_bed_gain(bed: Dictionary, g: float) -> void:
	if bed.is_empty():
		return
	bed["gain"] = g
	for p in bed["players"]:
		if is_instance_valid(p):
			(p as AudioStreamPlayer).volume_db = float(p.get_meta("base_db")) + linear_to_db(maxf(g, 0.0001))

func _free_bed(bed: Dictionary) -> void:
	for p in bed.get("players", []):
		if is_instance_valid(p):
			(p as AudioStreamPlayer).stop()
			p.queue_free()

## Where the handover stands: x 0..1. Equal power.
static func xfade_gains(x: float) -> Vector2:
	var a := clampf(x, 0.0, 1.0) * PI * 0.5
	return Vector2(cos(a), sin(a))

func _apply_xfade(x: float) -> void:
	_bed_x = x
	var g := xfade_gains(x)
	_set_bed_gain(_bed_old, g.x)
	_set_bed_gain(_bed_cur, g.y)
	if x >= 1.0 and not _bed_old.is_empty():
		_free_bed(_bed_old)
		_bed_old = {}

## What is really coming out of the Ambience players, as power relative
## to one bed at full level (1.0 = steady; the audio suite holds the
## state wave to this).
func ambience_power() -> float:
	var total := 0.0
	for bed in [_bed_old, _bed_cur]:
		var ps: Array = bed.get("players", [])
		if ps.is_empty() or not is_instance_valid(ps[0]):
			continue
		var lin := db_to_linear((ps[0] as AudioStreamPlayer).volume_db - float(ps[0].get_meta("base_db")))
		total += lin * lin
	return total

func _swap_bed(path: String, state_name: String) -> bool:
	var key := "%s|%s|%s" % [path, Game.current_area_id, state_name]
	if not _bed_cur.is_empty() and String(_bed_cur["key"]) == key:
		return false
	if _bed_tween != null and _bed_tween.is_valid():
		_bed_tween.kill()
	# a third bed never joins: whatever was still leaving is let go now
	_free_bed(_bed_old)
	_bed_old = _bed_cur
	_set_bed_gain(_bed_old, 1.0)
	_active_ambience = path
	_bed_cur = _make_bed(key, path, ambience_layers(Game.current_area_id, state_name)) if path != "" else {"key": key, "players": [], "gain": 0.0}
	_bed_x = 0.0
	return true

## Crossfade to a state's bed (base path + this area's layers for the
## state; "" for silence). state_name defaults to the area's present state.
func play_ambience(path: String, fade := 2.0, state_name := "") -> void:
	if _shutting_down:
		return
	if not _swap_bed(path, state_name if state_name != "" else _state_name()):
		return
	_wave = {}
	_bed_tween = create_tween()
	_bed_tween.tween_method(_apply_xfade, 0.0, 1.0, maxf(fade, 0.01))

# ---- the state wave: the bed changes where the front is, not afterwards
## The new state's bed starts silent under the old one. wave_update() then
## moves the handover with the wave front's distance to the listener, so
## the air changes as the frost line (or the melt) reaches the ear.
func wave_begin(env: Node, to_state: int, origin: Vector3) -> void:
	if _shutting_down or env == null:
		return
	var prof: Dictionary = env.audio_for(to_state)
	if not _swap_bed(String(prof.get("ambience", "")), RH.STATE_NAMES[to_state]):
		return
	var w: Dictionary = cfg("wave", {})
	_wave = {"origin": origin, "band": float(w.get("ambience_band", 36.0)), "min_time": float(w.get("ambience_min_time", 2.2))}
	_apply_xfade(0.0)

func wave_update(radius: float, dt: float) -> void:
	if _wave.is_empty():
		return
	var ear: Vector3 = _wave["origin"]
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam != null:
		ear = cam.global_position
	var d := Vector2(ear.x - _wave["origin"].x, ear.z - _wave["origin"].z).length()
	# half-way as the front passes; the band is how much ground the change is spread over
	var want := clampf((radius - d) / float(_wave["band"]) + 0.5, 0.0, 1.0)
	# never backwards, never faster than min_time for the whole handover
	_apply_xfade(clampf(maxf(want, _bed_x), _bed_x, _bed_x + dt / float(_wave["min_time"])))

## The wave is done: finish whatever is left of the handover at the same
## pace, without a jump.
func wave_end() -> void:
	if _wave.is_empty():
		return
	var left := 1.0 - _bed_x
	var t := float(_wave["min_time"]) * left
	_wave = {}
	if left <= 0.0:
		return
	_bed_tween = create_tween()
	_bed_tween.tween_method(_apply_xfade, _bed_x, 1.0, maxf(t, 0.01))

## A looping positional source hung on a node (a lit hearth, a frost
## veil). It dies with the node. Returns null when the stream is missing.
func loop_at(node: Node3D, bed: String, db := 0.0, preset := "near") -> AudioStreamPlayer3D:
	var stream := _stream(String(amb_cfg().get("layer_path", "res://assets/audio/ambience/%s.ogg")) % bed)
	if stream == null or _shutting_down or node == null:
		return null
	_make_looping(stream)
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "Ambience"
	p.volume_db = db
	_spatialise(p, preset)
	node.add_child(p)
	p.play(randf() * maxf(stream.get_length() - 1.0, 0.0))
	return p

# ------------------------------------------------------- sound effects
## Every effect is a key in data/audio.json "sfx" (written by tools/audio/
## build_sfx.py): a set of recorded takes plus its mix. play() never plays
## the same take twice running and varies pitch and level a little, so a
## run of footsteps or blows does not machine-gun.
var _last_take: Dictionary = {}

func sound(key: String) -> Dictionary:
	return ((cfg("sfx", {}) as Dictionary).get("sounds", {}) as Dictionary).get(key, {})

func sound_paths(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var e := sound(key)
	var pat := String((cfg("sfx", {}) as Dictionary).get("path", ""))
	for i in int(e.get("n", 0)):
		out.append(pat % [key, i + 1, String(e.get("ext", "wav"))])
	return out

func _take(key: String, n: int) -> int:
	var i := randi() % n
	if n > 1 and i == int(_last_take.get(key, -1)):
		i = (i + 1 + randi() % (n - 1)) % n
	_last_take[key] = i
	return i

func _spatialise(p: AudioStreamPlayer3D, preset: String) -> void:
	var sp: Dictionary = (cfg("spatial", {}) as Dictionary).get(preset, {})
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = float(sp.get("unit_size", 8.0))
	p.max_distance = float(sp.get("max_distance", 60.0))
	# the air takes the top off things as they get further away
	p.attenuation_filter_cutoff_hz = float(sp.get("filter_hz", 7000.0))
	p.attenuation_filter_db = float(sp.get("filter_db", -20.0))

## Play an effect by key: at a world position (Vector3), or flat (null)
## on the key's bus. db and pitch are on top of the key's own mix.
func play(key: String, pos = null, db := 0.0, pitch := 1.0) -> void:
	if _shutting_down or key == "":
		return
	var e := sound(key)
	var n := int(e.get("n", 0))
	if n <= 0:
		return
	var path := String((cfg("sfx", {}) as Dictionary).get("path", "")) % [key, _take(key, n) + 1, String(e.get("ext", "wav"))]
	var stream := _stream(path)
	if stream == null:
		return
	var vol := float(e.get("db", 0.0)) + db + randf_range(-1.0, 1.0) * float(e.get("vol", 0.0))
	var pit := pitch * (1.0 + randf_range(-1.0, 1.0) * float(e.get("pitch", 0.0)))
	if pos is Vector3:
		var p := AudioStreamPlayer3D.new()
		p.stream = stream
		p.bus = String(e.get("bus", "SFX"))
		p.volume_db = vol
		p.pitch_scale = pit
		_spatialise(p, String(e.get("dist", "mid")))
		p.finished.connect(p.queue_free)
		add_child(p)
		p.global_position = pos
		p.play()
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream
		p2.bus = String(e.get("bus", "SFX"))
		p2.volume_db = vol
		p2.pitch_scale = pit
		p2.finished.connect(p2.queue_free)
		add_child(p2)
		p2.play()

## A swing through air, by the weapon's weight (data/audio.json "swings":
## weapon class -> [normal, heavy attack]).
func swing(weapon_class: String, heavy: bool, pos: Vector3, db := 0.0) -> void:
	var m: Dictionary = cfg("swings", {})
	var pair: Array = m.get(weapon_class, m.get("default", ["combat/swing_medium", "combat/swing_heavy"]))
	play(String(pair[1 if heavy else 0]), pos, db)

## A weapon (or anything else) striking a surface: wood, stone, metal,
## ice, cloth, turf, snow (data/audio.json "impacts"). Unknown surfaces
## fall back to the map's "default".
func impact_key(surface: String) -> String:
	var m: Dictionary = cfg("impacts", {})
	return String(m.get(surface, m.get("default", "")))

func impact(surface: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	play(impact_key(surface), pos, db, pitch)

## A foe family's sound for an event: alert, attack, hit, death (data/
## audio.json "families"; an enemy names its family with "sfx_family").
func foe_key(family: String, event: String) -> String:
	var fams: Dictionary = cfg("families", {})
	var f: Dictionary = fams.get(family, fams.get("taken", {}))
	return String(f.get(event, (fams.get("taken", {}) as Dictionary).get(event, "")))

func foe(family: String, event: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	play(foe_key(family, event), pos, db, pitch)

# ----------------------------------------------------------- footsteps
## The ground under a foot: turf, shingle, plank, snow, ice, stone, mud
## or water. Under a roof it is boards. Standing in a water plane it is
## water (THAW) or ice (RIME). On the terrain, RIME lies under snow; THAW
## reads the painted splat (shingle, wet), then the slope (bare rock),
## then the area's own ground (data/audio.json footsteps.ground). Built
## decks off the terrain are plank, snowed over in RIME.
func surface_at(pos: Vector3) -> String:
	var area: Node = Game.current_area
	if area == null or not is_instance_valid(area):
		return "turf"
	var fs: Dictionary = cfg("footsteps", {})
	var rime: bool = World.get_area_state(Game.current_area_id) == RH.WState.RIME
	var state_name := "rime" if rime else "thaw"
	if _indoors(area, pos):
		return "plank"   # under a roof: boarded floors, and no snow
	var terrain = area.get("terrain")
	var on_terrain: bool = terrain != null and terrain.contains(pos.x, pos.z) \
			and absf(pos.y - terrain.height_at(pos.x, pos.z)) < float(fs.get("on_ground_tolerance", 0.45))
	if on_terrain or terrain == null:
		var wet := _in_water(area, pos, state_name, fs)
		if wet != "":
			return wet
	var ground: Dictionary = fs.get("ground", {})
	var here: Dictionary = ground.get(Game.current_area_id, {})
	var base := String(here.get(state_name, (ground.get("default", {}) as Dictionary).get(state_name, "snow" if rime else "turf")))
	if on_terrain:
		if rime:
			return base
		if terrain.splat_at(pos.x, pos.z, 0) > float(fs.get("shingle_splat", 0.45)):
			return "shingle"
		if terrain.splat_at(pos.x, pos.z, 2) > float(fs.get("wet_splat", 0.5)):
			return "mud"
		if terrain.normal_at(pos.x, pos.z).y < float(fs.get("steep_normal_y", 0.74)):
			return "stone"
		return base
	return "snow" if rime else "plank"

## "water", "ice" or "": is the foot in one of the area's water planes?
func _in_water(area: Node, pos: Vector3, state_name: String, fs: Dictionary) -> String:
	if not area.has_meta("def"):
		return ""
	for w in (area.get_meta("def") as Dictionary).get("water", []):
		var tag := String(w.get("tag", "base"))
		if tag != "base" and tag != state_name:
			continue
		var at: Array = w.get("at", [0, 0, 0])
		var dy := pos.y - float(at[1])
		if dy > float(fs.get("water_above", 0.2)) or dy < -float(fs.get("water_depth", 1.2)):
			continue
		var dx := pos.x - float(at[0])
		var dz := pos.z - float(at[2])
		if w.has("radius"):
			if dx * dx + dz * dz > float(w["radius"]) * float(w["radius"]):
				continue
		else:
			var sz: Array = w.get("size", [100, 100])
			if absf(dx) > float(sz[0]) * 0.5 or absf(dz) > float(sz[1]) * 0.5:
				continue
		return "ice" if state_name == "rime" else "water"
	return ""

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

func footstep_key(surface: String, run: bool) -> String:
	return "foot/%s_%s" % [surface, "run" if run else "walk"]

func footstep(pos: Vector3, _idx: int, volume_db := 0.0, run := false) -> void:
	play(footstep_key(surface_at(pos), run), pos, volume_db)

## Coming down from a drop: the run step of the ground, and the body after it.
func land(pos: Vector3, volume_db := 0.0) -> void:
	play(footstep_key(surface_at(pos), true), pos, volume_db + 2.0)
	play("foot/land", pos, volume_db)

## A foley path by key; lists pick a variant at random. (Kept for the few
## composed stingers that are still single files.)
func foley(key: String) -> String:
	var v = (cfg("foley", {}) as Dictionary).get(key, "")
	if v is Array:
		return String((v as Array).pick_random()) if not (v as Array).is_empty() else ""
	return String(v)

## Fire-and-forget positional SFX. `path` is an effect key ("combat/parry")
## or, for the composed stingers and voice, a res:// path.
func sfx_at(path: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if _shutting_down or path == "":
		return
	if not path.begins_with("res://"):
		# callers used to re-pitch one file into several sounds; a recording
		# bent that far stops sounding like itself
		play(path, pos, volume_db, clampf(pitch, 0.88, 1.12))
		return
	var stream := _stream(path)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	_spatialise(p, "mid")
	p.finished.connect(p.queue_free)
	add_child(p)
	p.global_position = pos
	p.play()

## Non-positional SFX (UI, stingers): an effect key or a res:// path.
func sfx(path: String, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> void:
	if _shutting_down or path == "":
		return
	if not path.begins_with("res://"):
		play(path, null, volume_db, pitch)
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
