class_name LookIn
extends Node3D
## A place to put an eye to (docs/lore/POI.md 5.4, the South Window): the
## prompt, then a held look through the gap with one line under it, then
## control comes back. Placed from an area's "scripted" list, once per state
## (the caption differs). The node faces the wall (local -Z is the way in).

var prompt := "Look in"
var caption := ""
var seconds := 4.0          # how long the look is held
var eye = Vector3(0, 1.5, 0.15)        # where the eye goes, local (a Vector3, or [x, y, z] from area data)
var look_at_local = Vector3(0, 1.1, -6.0)
var fov := 38.0

var looking := false
signal looked

var _zone: Interactable

func _ready() -> void:
	_zone = Interactable.new()
	_zone.prompt = prompt
	_zone.setup_zone(1.1, 1.6, Vector3(0, 0, 0.6))
	_zone.activated.connect(_on_look)
	add_child(_zone)

func _on_look(player) -> void:
	if looking or player == null:
		return
	looking = true
	_zone.enabled = false
	player.lock_control(true)
	var cam := Camera3D.new()
	cam.fov = fov
	add_child(cam)
	cam.position = AreaBuilder._v3(eye) if eye is Array else eye
	cam.look_at(to_global(AreaBuilder._v3(look_at_local) if look_at_local is Array else look_at_local), Vector3.UP)
	var before := get_viewport().get_camera_3d()
	cam.current = true
	for hud in get_tree().get_nodes_in_group("hud"):
		if hud.has_method("show_overheard"):
			hud.show_overheard("", caption, maxf(seconds - 1.0, 0.5))
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(before):
		before.current = true
	cam.queue_free()
	if is_instance_valid(player):
		player.lock_control(false)
	_zone.enabled = true
	looking = false
	looked.emit()
