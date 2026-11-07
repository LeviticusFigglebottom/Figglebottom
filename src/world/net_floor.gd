class_name NetFloor
extends Node3D
## The Netmender's arena floor (SLICE.md 4, 6): the whole Longhouse floor is
## one frozen net. A scripted area entity (gen_steading.py "scripted", tag
## rime) placed at the floor's centre; size is [width, length] in metres. The
## holdfast finds it by group and drives it: slide() hauls the net (and what
## stands on it) toward her, pulse() lights it on a phase change.

var size := [11.6, 31.6]
var _mat: ShaderMaterial
var _mi: MeshInstance3D

func _ready() -> void:
	add_to_group("net_floor")
	_mi = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(float(size[0]), float(size[1]))
	_mi.mesh = pm
	_mi.position.y = 0.03
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/net_floor.gdshader")
	_mi.material_override = _mat
	add_child(_mi)

## Whether a world point stands on the net.
func covers(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) <= float(size[0]) * 0.5 and absf(l.z) <= float(size[1]) * 0.5 and absf(l.y) < 1.5

## The net slides `dist` metres along `dir` (world, horizontal) over `secs`.
func slide(dir: Vector3, dist: float, secs: float) -> void:
	var from: Vector2 = _mat.get_shader_parameter("slide")
	var to := from + Vector2(dir.x, dir.z).normalized() * dist
	var tw := create_tween()
	tw.tween_method(func(v: Vector2): _mat.set_shader_parameter("slide", v), from, to, secs) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func slide_offset() -> Vector2:
	return _mat.get_shader_parameter("slide")

func pulse(strength := 1.0, secs := 1.2) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): _mat.set_shader_parameter("pulse", v), strength, 0.0, secs)
