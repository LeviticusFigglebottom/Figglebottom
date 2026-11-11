class_name PoseHold
extends Node
## Holds a rigged dressing figure in one frame of one of its clips. Figures
## placed as area landmarks have no brain to pose them, and a rig left alone
## stands in its bind pose (arms out). Added under the figure by AreaBuilder
## for a landmark with "pose": "<clip>@<fraction of its length>".

var clip := "idle"
var at := 0.0   # 0..1 of the clip's length

static func attach(figure: Node, spec: String) -> void:
	var h := PoseHold.new()
	var parts := spec.split("@")
	h.clip = parts[0]
	h.at = float(parts[1]) if parts.size() > 1 else 0.0
	h.name = "PoseHold"
	figure.add_child(h)

func _ready() -> void:
	for ap in get_parent().find_children("*", "AnimationPlayer", true, false):
		var player := ap as AnimationPlayer
		if not player.has_animation(clip):
			continue
		player.play(clip)
		player.seek(player.get_animation(clip).length * clampf(at, 0.0, 1.0), true)
		# paused, not stopped: stop() would drop the pose back to rest
		player.pause()
		return
