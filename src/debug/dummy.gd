class_name TrainingDummy
extends StaticBody3D
## Training pell: takes hits (logs them), optionally swings back on a cycle
## so block/parry/i-frames can be exercised deterministically.

signal was_hit(packet: DamagePacket, result: String)

@export var auto_attack := false
@export var attack_interval := 3.0

var hp := 99999.0
var poise := 40.0
var max_poise := 40.0
var staggered_until := 0.0
var hits_taken := 0
var last_result := ""
var dead := false

var hitbox: Hitbox
var _cycle_t := 0.0
var _swing_t := -1.0
var vis: Node3D

func _ready() -> void:
	add_to_group("targetable")
	add_to_group(RH.GROUP_ENEMIES)
	collision_layer = 1 << (RH.L_ENEMY - 1)
	collision_mask = 0
	vis = KitLib.instance("pell")
	add_child(vis)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 1.9
	cs.shape = cyl
	cs.position.y = 0.95
	add_child(cs)

	var hb := Hurtbox.new()
	hb.team = "enemy"
	var hcs := CollisionShape3D.new()
	var c2 := CylinderShape3D.new()
	c2.radius = 0.42
	c2.height = 1.9
	hcs.shape = c2
	hcs.position.y = 0.95
	hb.add_child(hcs)
	add_child(hb)
	hb.hurt.connect(_on_hurt)

	hitbox = Hitbox.new()
	hitbox.exclude = self
	var hbs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 1.4, 1.6)
	hbs.shape = box
	hitbox.add_child(hbs)
	hitbox.position = Vector3(0, 1.2, -1.0)
	add_child(hitbox)

func _on_hurt(packet: DamagePacket, result: String) -> void:
	hits_taken += 1
	last_result = result
	if result == "hit":
		hp -= packet.amount
		poise -= packet.poise_damage
		if poise <= 0.0:
			poise = max_poise
			staggered_until = Time.get_ticks_msec() / 1000.0 + 0.8
		# spin the arms a little for feedback
		if vis:
			var tw := create_tween()
			tw.tween_property(vis, "rotation:y", vis.rotation.y + 0.5, 0.3).set_ease(Tween.EASE_OUT)
	was_hit.emit(packet, result)
	print("[dummy] %s: dmg=%.1f poise_dmg=%.1f total_hits=%d" % [result, packet.amount, packet.poise_damage, hits_taken])

func _physics_process(dt: float) -> void:
	if auto_attack:
		_cycle_t += dt
		if _cycle_t >= attack_interval:
			_cycle_t = 0.0
			attack_now()
	if _swing_t >= 0.0:
		_swing_t += dt
		if _swing_t >= 0.5 and not hitbox.monitoring:
			var pk := DamagePacket.new(18.0, 20.0, self)
			hitbox.begin_swing(pk)
		if _swing_t >= 0.66:
			hitbox.end_swing()
			_swing_t = -1.0

## Telegraphed swing: 0.5 s windup, 0.16 s active.
func attack_now() -> void:
	if _swing_t < 0.0:
		_swing_t = 0.0

func is_invulnerable() -> bool:
	return false

func receive_riposte(packet: DamagePacket) -> void:
	_on_hurt(packet, "hit")

func on_parried(_by: Node) -> void:
	_swing_t = -1.0
	hitbox.end_swing()
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		players[0].on_parry_success(self)
