class_name FrostPool
extends Node3D
## A spreading pool of frost on the floor (TARNHALL.md 6: the Host tips a
## horn and the floor freezes where it runs). It grows from `from` to `to`
## metres across over `grow` seconds and stays `life` seconds in all; its
## edge glows as it spreads so the player can read how far it will reach.
## Whoever stands on it takes `dmg` frost every `tick` seconds (no block).
## close() greys it out early (a phase change, the release).

signal closed_over(pool)

var r_from := 1.2
var r_to := 6.0
var grow := 3.0
var life := 8.0
var dmg := 6.0
var tick := 0.5
var source: Node = null
var _t := 0.0
var _tick_t := 0.0
var _closing := false
var _sheet: MeshInstance3D
var _rim: MeshInstance3D
var _sheet_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D

static func spawn(parent: Node, at: Vector3, p_from: float, p_to: float, p_grow: float,
		p_life: float, p_dmg: float, p_tick: float, p_source: Node = null) -> FrostPool:
	var fp := FrostPool.new()
	fp.r_from = p_from
	fp.r_to = p_to
	fp.grow = maxf(p_grow, 0.05)
	fp.life = p_life
	fp.dmg = p_dmg
	fp.tick = maxf(p_tick, 0.1)
	fp.source = p_source
	parent.add_child(fp)
	fp.global_position = at
	return fp

func _ready() -> void:
	add_to_group("frost_pools")
	_sheet = MeshInstance3D.new()
	_sheet.mesh = FloorTelegraph._shape_mesh("ring", [1.0])
	_sheet_mat = _flat_mat(Color(0.78, 0.88, 1.0, 0.0))
	_sheet.material_override = _sheet_mat
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.position.y = 0.08
	add_child(_sheet)
	_rim = MeshInstance3D.new()
	_rim.mesh = FloorTelegraph._shape_mesh("annulus", [0.9, 1.0])
	_rim_mat = _flat_mat(Color(0.3, 0.58, 1.0, 0.0))
	_rim.material_override = _rim_mat
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rim.position.y = 0.1
	add_child(_rim)
	_set_r(r_from)
	var tw := create_tween()
	tw.tween_property(_sheet_mat, "albedo_color:a", 0.72, 0.25)
	tw.parallel().tween_property(_rim_mat, "albedo_color:a", 0.85, 0.25)

static func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	return m

func _set_r(r: float) -> void:
	_sheet.scale = Vector3(r, 1.0, r)
	_rim.scale = Vector3(r, 1.0, r)

## The pool's reach now.
func radius() -> float:
	return lerpf(r_from, r_to, 1.0 - pow(1.0 - clampf(_t / grow, 0.0, 1.0), 2.0))

func covers(p: Vector3) -> bool:
	if _closing:
		return false
	return Vector2(p.x - global_position.x, p.z - global_position.z).length() <= radius()

func is_open() -> bool:
	return not _closing

func _physics_process(dt: float) -> void:
	if _closing:
		return
	_t += dt
	_set_r(radius())
	# the edge glows while it spreads, then settles
	var spreading := _t < grow
	_rim_mat.albedo_color.a = (0.6 + 0.3 * sin(_t * 14.0)) if spreading else 0.35
	_tick_t -= dt
	if _tick_t <= 0.0:
		_tick_t = tick
		_bite()
	if _t >= life:
		close()

func _bite() -> void:
	var p := Game.player
	if p == null or not is_instance_valid(p) or p.get("dead") or not covers(p.global_position):
		return
	if p.has_method("is_invulnerable") and p.is_invulnerable():
		return
	var hb: Hurtbox = p.get("hurtbox")
	if hb == null:
		return
	var src: Node = source if source != null and is_instance_valid(source) else self
	var pk := DamagePacket.new(dmg, 2.0, src)
	pk.kind = "frost"
	pk.can_be_parried = false
	pk.can_be_blocked = false
	hb.receive(pk)

## Grey out and go.
func close() -> void:
	if _closing:
		return
	_closing = true
	closed_over.emit(self)
	var tw := create_tween()
	tw.tween_property(_sheet_mat, "albedo_color", Color(0.6, 0.62, 0.66, 0.0), 0.9)
	tw.parallel().tween_property(_rim_mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
