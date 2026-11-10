class_name Pickup
extends Node3D
## A cache: a small brazier flame over the item. Grants warmth
## and/or items once; persistence via area flag.

var pickup_id := ""
var area_id := ""
var warmth := 0
var item_id := ""
var item_count := 1
var label := "Take"
## quest reveals inside an already-built area: stay hidden and inert until
## the flag turns true, THEN appear — a build-time require_flag can't do
## this, because talking to the quest-giver doesn't rebuild the room
var appear_flag := ""
## optional true shape (quest relics): shown instead of the candelabrum
var display_kit := ""
## or a Tripo mesh (the Mending Needle where the Netmender sat)
var display_scene := ""
## a story flag raised on taking it (a Keepsakes step, say)
var set_flag := ""
## the shown thing sits this high (the float frozen into the tide wall's
## face at chest height, SLICE.md 2); the prompt zone stays on the ground
var display_lift := 0.0
## frozen in: only a heavy blow from close in front frees it (the Bearer's
## heavy swing calls chip()); using it only says so
var chip_heavy := false
var chip_hint := "The ice holds it fast. A heavy blow might chip it free."

## a thing that is looked at, not taken (one set of footprints in the ice):
## the words go up on the reading panel, the flag is raised, and it stays
var look_text := ""

var _zone: Interactable
var _shown := true

func _ready() -> void:
	if World.area_flag(area_id, "took_" + pickup_id):
		queue_free()
		return
	_zone = Interactable.new()
	_zone.prompt = label
	_zone.setup_zone(1.2, 1.4)
	if chip_heavy:
		add_to_group("chip_heavy")
		_zone.activated.connect(func(_p): Game.toast.emit(chip_hint))
	else:
		_zone.activated.connect(_on_take)
	add_child(_zone)
	if display_scene != "" and ResourceLoader.exists(display_scene):
		var mesh := (load(display_scene) as PackedScene).instantiate() as Node3D
		if not mesh.get_meta("upright", false):
			mesh.rotation_degrees = Vector3(0, 0, 90)   # lying on the boards
		# (a thing that stands, like the Host's cup, says so: metadata/upright)
		mesh.position.y = 0.05 + display_lift
		add_child(mesh)
		var gl := OmniLight3D.new()
		gl.light_color = Color(0.95, 0.93, 0.86)
		gl.light_energy = 1.0
		gl.omni_range = 2.4
		gl.shadow_enabled = false
		gl.position.y = 0.6
		add_child(gl)
	elif display_kit != "" and KitLib.has_piece(display_kit):
		# a relic shows ITSELF — its own shape on the stones, kept in a
		# small gold shimmer instead of the brazier
		var relic := KitLib.instance(display_kit)
		relic.position.y = display_lift
		add_child(relic)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.88, 0.58)
		l.light_energy = 1.3
		l.omni_range = 3.2
		l.shadow_enabled = false
		l.position.y = 0.7 + display_lift * 0.8
		add_child(l)
		var tw := l.create_tween()
		tw.set_loops(0)
		tw.tween_property(l, "light_energy", 0.8, 1.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(l, "light_energy", 1.3, 1.3).set_trans(Tween.TRANS_SINE)
	else:
		var brazier := KitLib.instance("brazier")
		brazier.scale = Vector3(0.55, 0.55, 0.55)
		add_child(brazier)
		KitLib.add_flame_lights(brazier, 1.4, 3.5)
	if appear_flag != "" and not World.flag(appear_flag):
		visible = false
		_zone.enabled = false
		_shown = false
		var t := Timer.new()
		t.wait_time = 0.5
		t.timeout.connect(func():
			if not _shown and World.flag(appear_flag):
				_shown = true
				visible = true
				_zone.enabled = true
				t.queue_free())
		add_child(t)
		t.start()

## A heavy blow landed on it (player.gd, the heavy swing's contact).
func chip(player) -> void:
	if chip_heavy and is_inside_tree() and _shown:
		AudioDirector.sfx(AudioDirector.foley("frost_hit"), -2.0)
		_on_take(player)

func _on_take(player) -> void:
	if look_text != "":
		if set_flag != "":
			World.set_flag(set_flag)
		Game.lore_panel.emit(look_text)
		World.save_game()
		return
	World.set_area_flag(area_id, "took_" + pickup_id)
	if set_flag != "":
		World.set_flag(set_flag)
	if warmth > 0:
		Game.add_warmth(warmth)
	if item_id != "" and player != null:
		player.give_item(item_id, item_count)
	var what := []
	if warmth > 0:
		what.append("%d warmth" % warmth)
	if item_id != "":
		var iname: String = DB.weapon(item_id).get("name",
			DB.song(item_id).get("name", DB.item(item_id).get("name", item_id)))
		what.append("%s ×%d" % [iname, item_count])
	Game.toast.emit("Received: " + " · ".join(what))
	AudioDirector.sfx("res://assets/audio/warmth.wav", -4.0)
	World.save_game()
	queue_free()
