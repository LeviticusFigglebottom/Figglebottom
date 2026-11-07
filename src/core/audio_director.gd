extends Node
## AudioDirector — music/ambience per world state, one-shot SFX helpers.
## All streams are optional: missing files no-op so headless tests run silent.

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _active_music := ""
var _shutting_down := false

func _ready() -> void:
	_music_a = AudioStreamPlayer.new(); _music_a.bus = "Music"; add_child(_music_a)
	_music_b = AudioStreamPlayer.new(); _music_b.bus = "Music"; add_child(_music_b)
	_ambience = AudioStreamPlayer.new(); _ambience.bus = "Ambience"; add_child(_ambience)

func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path)

## Music/ambience beds must LOOP: the synth tracks are short (~20 s) and WAV
## imports don't loop by default, so a track played once and the world fell
## silent. Mutating the (cached) stream resource is idempotent.
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
func play_music(path: String, fade := 2.0) -> void:
	if _shutting_down or _active_music == path:
		return
	_active_music = path
	var incoming := _music_b if _music_a.playing else _music_a
	var outgoing := _music_a if incoming == _music_b else _music_b
	var stream := _stream(path)
	incoming.stop()
	if stream:
		_make_looping(stream)
		incoming.stream = stream
		incoming.volume_db = -40.0
		incoming.play()
		create_tween().tween_property(incoming, "volume_db", 0.0, fade)
	if outgoing.playing:
		var t := create_tween()
		t.tween_property(outgoing, "volume_db", -40.0, fade)
		t.tween_callback(outgoing.stop)

# ------------------------------------------------------ boss battle themes
## One theme per holdfast (assets/audio/boss/<enemy_id>.mp3), falling back to
## the shared boss track. While one plays, the ambience bed ducks to silence
## so the orchestra owns the air; combat feedback on the SFX bus stays. The
## theme ends (and the world's own sound returns) when the holdfast rests or
## the Bearer falls.
var _amb_base := 0.0
var _amb_ducked := false

func boss_theme(enemy_id: String, fade := 1.5) -> void:
	var path := "res://assets/audio/boss/%s.mp3" % enemy_id
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/theme_boss.wav"
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

func play_ambience(path: String, fade := 2.0) -> void:
	if _shutting_down:
		return
	var stream := _stream(path)
	if stream == null:
		_ambience.stop()
		_ambience.stream = null
		return
	if _ambience.stream == stream and _ambience.playing:
		return
	_ambience.stop()
	_make_looping(stream)
	_ambience.stream = stream
	_ambience.volume_db = -10.0
	_ambience.play()

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
