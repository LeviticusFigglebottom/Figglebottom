extends OmniLight3D
## Every flame breathes: a slow multi-sine wobble on the flame light's
## energy, phase-scattered so a hall of braziers never pulses in step and
## specular highlights dance subtly across stone and plate armor.
## Attached by KitLib.add_flame_lights to every flame it warms.

var _base := 1.8
var _amp := 0.12
var _w := 7.0
var _p := 0.0
var _state_mode := 0

func _ready() -> void:
	_base = light_energy
	_p = randf() * TAU
	_w = randf_range(5.0, 9.0)
	_amp = randf_range(0.09, 0.15)
	var par := get_parent()
	if par != null and par.has_meta("state_mode"):
		_state_mode = int(par.get_meta("state_mode"))

func _process(_dt: float) -> void:
	var par := get_parent() as Node3D
	if par != null and not par.is_visible_in_tree():
		return
	var rime_fade := 1.0
	if _state_mode != 2:
		rime_fade = clampf(1.0 - StateDirector.state_blend, 0.0, 1.0)
	if rime_fade <= 0.005:
		light_energy = 0.0
		return
	var p = Game.player
	if p != null and global_position.distance_squared_to(p.global_position) > 1500.0:
		light_energy = _base * rime_fade
		return
	var t := Time.get_ticks_msec() * 0.001
	var wave := sin(t * _w + _p) * 0.6 + sin(t * _w * 2.7 + _p * 1.7) * 0.4
	light_energy = _base * rime_fade * (1.0 + _amp * wave)
