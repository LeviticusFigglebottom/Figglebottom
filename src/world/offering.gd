class_name Offering
extends Node3D
## A thing given up at a place (docs/lore/POI.md 8.1: the Melt flowers thrown
## in at the water's edge). The prompt shows only while the Bearer carries
## `item` and `set_flag` is not yet set; taking it up spends the item, sets
## the flag (a Keepsakes step) and lets whoever stands by say one line.

var item := ""
var set_flag := ""
var prompt := "Give"
var speaker := ""            # an npcs.json id: its short name goes before the line
var line := ""

var _zone: Interactable

func _ready() -> void:
	_zone = Interactable.new()
	_zone.prompt = prompt
	_zone.setup_zone(1.5, 1.6)
	_zone.activated.connect(_on_give)
	_zone.enabled = false
	add_child(_zone)

func _physics_process(_dt: float) -> void:
	_zone.enabled = can_give()

func can_give() -> bool:
	var p = Game.player
	return p != null and is_visible_in_tree() and not World.flag(set_flag) and int(p.inventory.get(item, 0)) > 0

func _on_give(player) -> void:
	if not can_give():
		return
	player.inventory[item] = int(player.inventory[item]) - 1
	if int(player.inventory[item]) <= 0:
		player.inventory.erase(item)
	World.set_flag(set_flag)
	World.save_game()
	if line != "":
		var who := String(DB.npc(speaker).get("short_name", "")) if speaker != "" else ""
		for hud in get_tree().get_nodes_in_group("hud"):
			if hud.has_method("show_overheard"):
				hud.show_overheard(who, line)
	AudioDirector.sfx("res://assets/audio/swell_warm.wav", -8.0, 0.9)
