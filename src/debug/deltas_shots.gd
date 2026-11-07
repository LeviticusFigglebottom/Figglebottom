extends Node
## Screenshots for the combat deltas: a lock-on switch (centre pell, then a
## right flick onto the right pell) and the Pack's Armour leaf.
## Run: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . \
##        --rendering-driver vulkan --resolution 1920x1080 -- --sandbox=deltas_shots

const OUT := "res://docs/screens/"
var pen: LockPen
var _f := 0

func _ready() -> void:
	pen = LockPen.new()
	add_child(pen)
	add_child(HUD.new())

func _process(_d: float) -> void:
	_f += 1
	var p := pen.player
	match _f:
		20:
			p.cam.yaw = 0.0
			p.cam.try_lock(get_tree().get_nodes_in_group("targetable"))
		110:
			_save("deltas_lock_1_centre.png")
		112:
			p.cam.mouse_look(Vector2(90, 0))   # the flick
		200:
			_save("deltas_lock_2_right.png")
		202:
			p.cam.try_lock([])
			p.give_item("armour_saltfell_oilskins")
			InventoryUI.open_for(p)
		206:
			var ui: InventoryUI = get_tree().get_first_node_in_group("inventory_ui")
			ui._show_tab("armour")
			ui._sel = 1
		230:
			_save("deltas_armour_leaf.png")
			AudioDirector.shutdown()
			get_tree().quit()

func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("[shot] saved ", OUT + name)
