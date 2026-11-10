class_name HouseProbe
extends ReflectionProbe
## Baked-style light for one house interior (HouseInterior). The box is the
## room, wall line to wall line and floor to ridge: inside it surfaces take
## this ambient instead of the sky's, and reflect the room instead of the
## sky, so a hall is not lit and glossed like a hilltop. The ambient follows
## the world state: fire-warm bounce in THAW, a cold blue one in RIME. The
## cubemap is captured once and again when the state settles.
## The colours are look data: data/game.json "render/interior".

const DEFAULTS := {
	"thaw_color": [0.52, 0.36, 0.2], "thaw_energy": 0.62,
	"rime_color": [0.2, 0.29, 0.46], "rime_energy": 0.72,
	"blend_distance": 0.25, "intensity": 0.8,
}

## 0 = closed room, 1 = as good as outdoors (an open-fronted boat-shed).
var open_air := 0.0

var _blend := -1.0
var _settled := -1.0

static func cfg() -> Dictionary:
	var c: Dictionary = DEFAULTS.duplicate()
	var over = DB.tuning("render/interior", {})
	if over is Dictionary:
		for k in over:
			c[k] = over[k]
	return c

func _ready() -> void:
	var c := cfg()
	interior = true
	enable_shadows = false
	update_mode = ReflectionProbe.UPDATE_ONCE
	ambient_mode = ReflectionProbe.AMBIENT_COLOR
	blend_distance = float(c["blend_distance"])
	intensity = float(c["intensity"])
	max_distance = maxf(size.x, size.z) + 4.0
	_apply(StateDirector.state_blend)

func _apply(t: float) -> void:
	_blend = t
	var c := cfg()
	var a: Array = c["thaw_color"]
	var b: Array = c["rime_color"]
	ambient_color = Color(a[0], a[1], a[2]).lerp(Color(b[0], b[1], b[2]), t)
	# an open front lets the sky in: lift toward the outdoor level
	ambient_color_energy = lerpf(float(c["thaw_energy"]), float(c["rime_energy"]), t) * (1.0 + 0.6 * open_air)

func _process(_dt: float) -> void:
	var t := StateDirector.state_blend
	if absf(t - _blend) > 0.01:
		_apply(t)
	elif _settled != _blend and (t < 0.01 or t > 0.99):
		# the state has settled: capture the room again in its new light
		if _settled >= 0.0:
			update_mode = ReflectionProbe.UPDATE_ALWAYS
			update_mode = ReflectionProbe.UPDATE_ONCE
		_settled = _blend
