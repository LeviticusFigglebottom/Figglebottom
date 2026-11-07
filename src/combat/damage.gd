class_name DamagePacket
## One hit, in flight: who, how hard, from where.

var amount := 10.0
var poise_damage := 10.0
var source: Node3D = null          # attacker root
var origin := Vector3.ZERO         # where the swing came from (for block arcs)
var can_be_blocked := true
var can_be_parried := true
var is_riposte := false
var kind := "physical"

func _init(p_amount := 10.0, p_poise := 10.0, p_source: Node3D = null) -> void:
	amount = p_amount
	poise_damage = p_poise
	source = p_source
	if source != null:
		origin = source.global_position
