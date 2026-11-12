extends Node3D
## The choice at the wellhead (SPEC §2, WORLD.md §6). Placed from the
## Coldwell's "scripted" section. Dormant until the Leadvoice is released
## (World flag `release_flag`, set by her holdfast data, or by `enable()`);
## then it offers two things to do at the spring:
##   "outsong"      lay the coal from the horn in the spring
##   "hearth_kept"  keep the horn shut and sit down by the well
## Choosing sets the World flag "ending_<id>", emits `chosen(id)` and starts
## the ending itself (EndingDirector; `run_endings` false leaves that to
## whoever listens: the placement tests).

signal chosen(ending: String)

var release_flag := "ks_leadvoice_released"
var spread := 2.2              # metres between the two places to stand
## The spring itself, from here: metres ahead (local -Z).
var spring_ahead := 5.5
var run_endings := true
var director: EndingDirector = null
var _outsong: Interactable
var _kept: Interactable
var _done := false

func _ready() -> void:
	add_to_group("ending_choice")
	_outsong = Interactable.new()
	_outsong.prompt = "Lay the coal in the spring"
	_outsong.setup_zone(1.2, 1.6, Vector3(-spread * 0.5, 0, 0))
	_outsong.activated.connect(func(_p): choose("outsong"))
	add_child(_outsong)
	_kept = Interactable.new()
	_kept.prompt = "Keep the horn shut, and sit"
	_kept.setup_zone(1.2, 1.6, Vector3(spread * 0.5, 0, 0))
	_kept.activated.connect(func(_p): choose("hearth_kept"))
	add_child(_kept)
	_done = World.ended() != ""   # a save from after: there is nothing left to choose
	_refresh()

## (on the physics tick, the clock everything else here is told by: after a
## heavy build the engine runs several ticks to one drawn frame, and a choice
## that waited for the frame was three ticks late in opening)
func _physics_process(_dt: float) -> void:
	if not _done and not is_open() and World.flag(release_flag):
		_refresh()

func is_open() -> bool:
	return _outsong.enabled

func enable() -> void:
	World.set_flag(release_flag)
	_refresh()

func _refresh() -> void:
	var on := World.flag(release_flag) and not _done
	_outsong.enabled = on
	_kept.enabled = on

func spring_point() -> Vector3:
	return to_global(Vector3(0, 0, -spring_ahead))

## Where the Bearer sits if the coal is kept.
func kept_spot() -> Vector3:
	return to_global(Vector3(spread * 0.5, 0.05, 0))

func choose(ending: String) -> void:
	if _done or ending not in ["outsong", "hearth_kept"]:
		return
	_done = true
	World.set_flag("ending_" + ending)
	_refresh()
	chosen.emit(ending)
	if run_endings:
		var p = Game.player
		var at: Vector3 = (p as Node3D).global_position if p != null and is_instance_valid(p) else kept_spot()
		director = EndingDirector.begin(ending, spring_point(), at, bool(get_meta("fast", false)))
