extends Node3D
## Watches a set of world flags; when every one is true, sets a target flag
## (once) and announces it. Multi-part objectives use this.
##   {"script": ".../seal_gate.gd", "at": [...], "params":
##     {"flags": ["lit_east", "lit_west"],
##      "target": "gate_open", "notice": "The great gate stirs."}}

var flags: Array = []
var target := ""
var notice := "Something ancient unbars."

var _done := false

func _physics_process(_dt: float) -> void:
	if _done:
		return
	if World.flag(target):
		_done = true
		return
	for f in flags:
		if not World.flag(String(f)):
			return
	World.set_flag(target)
	World.save_game()
	Game.toast.emit(notice)
	AudioDirector.play("world/gate_open", global_position)
	_done = true
