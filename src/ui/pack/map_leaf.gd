extends RefCounted
## The Map leaf of the Pack (M opens it): one MapView filling the leaf.
## Enter or a click goes from the whole highland into a region and back;
## W/S steps through the regions walked so far.

static func fill(ui: InventoryUI) -> void:
	var view := MapView.new()
	view.name = "MapView"
	ui._list.add_child(view)
	ui.set_meta("map_view", view)

static func view_of(ui: InventoryUI) -> MapView:
	var v = ui.get_meta("map_view", null)
	return v if v != null and is_instance_valid(v) else null

## Keys the leaf takes for itself. Returns true when the event was used.
static func input(ui: InventoryUI, event: InputEvent) -> bool:
	var v := view_of(ui)
	if v == null:
		return false
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		v.toggle()
		return true
	if event.is_action_pressed("move_forward"):
		v.step(-1)
		return true
	if event.is_action_pressed("move_back"):
		v.step(1)
		return true
	return false
