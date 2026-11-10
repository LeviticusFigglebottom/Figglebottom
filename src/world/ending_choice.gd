extends Node3D
## The choice at the wellhead (SPEC §2, WORLD.md §6): a hook for the endings.
## Placed from the Coldwell's "scripted" section. Dormant until the Leadvoice
## is released (World flag `release_flag`, set by her holdfast data, or by
## `enable()`); then it offers two things to do at the spring:
##   "outsong"      lay the coal from the horn in the spring
##   "hearth_kept"  keep the horn shut and sit down by the well
## Choosing sets the World flag "ending_<id>" and emits `chosen(id)`; the
## endings themselves (the mask, the song, the last shots) belong to whoever
## builds them and listen for the flag or the signal.

signal chosen(ending: String)

var release_flag := "ks_leadvoice_released"
var spread := 2.2              # metres between the two places to stand
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
	_refresh()

func _process(_dt: float) -> void:
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

func choose(ending: String) -> void:
	if _done or ending not in ["outsong", "hearth_kept"]:
		return
	_done = true
	World.set_flag("ending_" + ending)
	_refresh()
	chosen.emit(ending)
