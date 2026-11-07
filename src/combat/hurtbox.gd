class_name Hurtbox
extends Area3D
## Receives DamagePackets. The owner node implements the reaction contract:
##   take_hit(packet: DamagePacket, result: String)
## and optionally: is_invulnerable() / is_blocking_toward(pos) /
## is_parrying_toward(pos) / on_blocked_hit(packet) / on_parried(attacker)
## result is one of: "hit", "blocked", "parried", "immune".

signal hurt(packet: DamagePacket, result: String)

@export var team := "neutral"   # "player" | "enemy" | "neutral"

func _init() -> void:
	collision_layer = 1 << (RH.L_HURTBOX - 1)
	collision_mask = 0
	monitoring = false
	monitorable = true

func receive(packet: DamagePacket) -> String:
	var host := owner if owner != null else get_parent()
	var result := "hit"
	if host.has_method("is_invulnerable") and host.is_invulnerable():
		result = "immune"
	elif packet.can_be_parried and host.has_method("is_parrying_toward") \
			and host.is_parrying_toward(packet.origin):
		result = "parried"
		if packet.source != null and packet.source.has_method("on_parried"):
			packet.source.on_parried(host)
	elif packet.can_be_blocked and host.has_method("is_blocking_toward") \
			and host.is_blocking_toward(packet.origin):
		result = "blocked"
		if host.has_method("on_blocked_hit"):
			host.on_blocked_hit(packet)
	else:
		if host.has_method("take_hit"):
			host.take_hit(packet)
	hurt.emit(packet, result)
	return result
