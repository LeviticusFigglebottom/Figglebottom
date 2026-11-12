class_name ShortcutGate
extends Node3D
## The classic soulslike gate: barred from one side. Learned in thaw,
## a lifeline in rime. Once opened, the flag persists.

var gate_id := "gate"
var layer_bit := RH.L_WORLD_BASE   # a gate that stands in one state only takes that state's layer
var area_id := ""
var locked_prompt := "Barred from the other side"
## Width of the opening the leaves fill (a house door is 1.9 m; the old
## yard gate 3.6 m). The leaves hinge at the jambs and swing to the far side.
var door_width := 3.6
var door_height := 2.5
## Progression gates (ADR 0015): what a Holdfast keeps shut across the way on.
## open_flag is the release's world flag: the gate opens by itself when it
## turns, wherever the Bearer stands, and a rebuilt area builds it open.
var open_flag := ""
var unbar_prompt := "Unbar the gate"
var open_toast := "The gate stands open."
var plank_leaves := true        # false: the dressing is the whole gate (a net, a hedge)
var body_depth := 0.14          # how thick the thing in the gap is

var _area: Area
var _dress_specs: Array = []
var _dress_shut: Array[Node3D] = []

var _leaves: Array[Node3D] = []
var _front: Interactable
var _back: Interactable

func _ready() -> void:
	# two plank leaves, each hung from its jamb on a pivot so it really swings
	for side in ([-1.0, 1.0] if plank_leaves else []):
		var pivot := Node3D.new()
		pivot.name = "gate_leaf_%s" % ("l" if side < 0 else "r")
		pivot.position = Vector3(side * door_width * 0.5, 0, 0)
		add_child(pivot)
		var leaf := KitLib.instance("door_leaf")
		leaf.scale = Vector3(door_width * 0.5 / 0.95, door_height / 2.5, 1.0)
		leaf.position = Vector3(-side * door_width * 0.25, 0, 0)
		pivot.add_child(leaf)
		_leaves.append(pivot)
	# static collision so the closed gate truly blocks (and splits navmesh)
	var body := StaticBody3D.new()
	body.name = "GateBody"
	body.collision_layer = 1 << (layer_bit - 1)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(door_width + 0.3, door_height, body_depth)
	cs.shape = box
	cs.position.y = door_height * 0.5
	body.add_child(cs)
	add_child(body)

	# the locked face is +Z (local); the unbarring side is -Z
	_front = Interactable.new()
	_front.prompt = locked_prompt
	var reach := 1.03 + body_depth * 0.5
	_front.setup_zone(1.2, 1.6, Vector3(0, 0, reach))
	_front.activated.connect(func(_p): Game.toast.emit(locked_prompt + "."))
	add_child(_front)
	_back = Interactable.new()
	_back.prompt = unbar_prompt
	_back.setup_zone(1.2, 1.6, Vector3(0, 0, -reach))
	_back.activated.connect(_on_unbar)
	add_child(_back)

	if _is_open():
		_apply_open(true)
	set_physics_process(open_flag != "" and not _is_open())

func _is_open() -> bool:
	return World.area_flag(area_id, "gate_" + gate_id) or (open_flag != "" and World.flag(open_flag))

## The release turns its flag while the Bearer is somewhere else in the
## region: the gate answers it here, not at the next load.
func _physics_process(_dt: float) -> void:
	if World.flag(open_flag):
		set_physics_process(false)
		_apply_open(false)

## The gate's look, piece by piece (area JSON "dressing": [...]). Each piece:
##   kit | scene | scatter | hedge: what it is; offset [x, y, z] (gate-local),
##   rot (deg), scale (n or [x, y, z]), family, tag base|thaw|rime (which
##   memory it stands in), when "shut" (default) | "open" (what is left once
##   the way is clear: the net on the ground, the hurdle swung back).
func dress(area: Area, specs: Array) -> void:
	_area = area
	_dress_specs = specs
	_build_dressing("open" if _is_open() else "shut")

func _build_dressing(when: String) -> void:
	for spec in _dress_specs:
		if String(spec.get("when", "shut")) != when:
			continue
		var tag := String(spec.get("tag", "base"))
		var mode := 1 if tag == "thaw" else (2 if tag == "rime" else 0)
		var fam := String(spec.get("family", ""))
		var n: Node3D = null
		if spec.has("kit"):
			n = KitLib.instance(String(spec["kit"]), mode, spec.get("mat_remap", {}))
		elif spec.has("scene"):
			n = BuildingGen._landmark(String(spec["scene"]), fam, mode)
		else:
			var mesh: Mesh = null
			if spec.has("hedge"):
				mesh = Forest._mesh("hero|%s|%s" % [String(spec["hedge"]), fam if fam != "" else "M_thorn"], mode)
			elif spec.has("scatter"):
				var kind := String(spec["scatter"])
				var hv: Array = Scatter.HERO.get(kind, [])
				if not hv.is_empty():
					mesh = Scatter._hero_mesh(String(hv[0][0]), String(hv[0][1]), mode)
				if mesh == null:
					mesh = Scatter._mesh(kind, mode)
			if mesh != null:
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				n = mi
				if spec.has("fit"):
					# "fit": [w, h, d] stretches the mesh to that box, stood on its middle
					var bb := mesh.get_aabb()
					var f: Array = spec["fit"]
					var k := Vector3(float(f[0]) / maxf(bb.size.x, 0.01), float(f[1]) / maxf(bb.size.y, 0.01), float(f[2]) / maxf(bb.size.z, 0.01))
					var holder := Node3D.new()
					holder.add_child(mi)
					mi.scale = k
					mi.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * k
					n = holder
		if n == null:
			continue
		n.set_meta("gate_piece", gate_id)     # (not one of the area's own props: the Reach counts its flock)
		var o: Array = spec.get("offset", [0, 0, 0])
		var sc = spec.get("scale", 1.0)
		var local := Transform3D(Basis(Vector3.UP, deg_to_rad(float(spec.get("rot", 0)))),
				Vector3(float(o[0]), float(o[1]), float(o[2])))
		local.basis = local.basis.scaled_local(Vector3(sc[0], sc[1], sc[2]) if sc is Array else Vector3.ONE * float(sc))
		if spec.has("tilt"):
			local.basis = local.basis * Basis(Vector3.RIGHT, deg_to_rad(float(spec["tilt"])))
		# a piece that stands in one memory only goes on that memory's layer
		if tag == "base" or _area == null:
			add_child(n)
			n.transform = local
		else:
			# (the area is still being built, outside the tree: its layers and
			# this gate both sit at the area's origin, so local space is enough)
			_area.attach(n, tag)
			n.transform = transform * local
		if when == "shut":
			_dress_shut.append(n)

func _on_unbar(_p) -> void:
	World.set_area_flag(area_id, "gate_" + gate_id)
	World.save_game()
	_apply_open(false)
	Game.toast.emit(open_toast)
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -6.0, 0.55)

## A released Holdfast lifts the bar from wherever he is (TARNHALL.md 9):
## the flag is set and the leaves swing open by themselves.
func lift_bar() -> void:
	if _is_open():
		return
	World.set_area_flag(area_id, "gate_" + gate_id)
	_apply_open(false)
	AudioDirector.sfx_at("res://assets/audio/impact_blocked.wav", global_position, -2.0, 0.4)

func _apply_open(instant: bool) -> void:
	_front.enabled = false
	_back.enabled = false
	# what stood in the gap comes down (the net falls, the hedge unlays) and
	# what it leaves behind is set out
	for n in _dress_shut:
		if not is_instance_valid(n):
			continue
		if instant:
			n.queue_free()
		else:
			var tw := n.create_tween()
			tw.tween_property(n, "position:y", n.position.y - door_height - 0.4, 1.4)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(n.queue_free)
	if not _dress_shut.is_empty():
		_dress_shut.clear()
		_build_dressing("open")
	for c in get_children():
		if c.has_meta("gate_dressing"):
			c.visible = false         # (doors drawn as dressing swing out of the way)
	var body := get_node("GateBody") as StaticBody3D
	body.collision_layer = 0
	# a gate on a state layer (Tarnhall's doors, RIME only): the layer's
	# collision toggles restore orig_layer, so an open gate stays open
	body.set_meta("orig_layer", 0)
	for i in _leaves.size():
		var leaf := _leaves[i]
		# both leaves swing in toward the unbarring (-Z) side
		var target := deg_to_rad(100.0 if i == 0 else -100.0)
		if instant:
			leaf.rotation.y = target
		else:
			create_tween().tween_property(leaf, "rotation:y", target, 1.1)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# navmesh changed: gates count as base geometry, rebake both maps
	if Game.current_area != null and not instant:
		Game.current_area.bake_navmeshes.call_deferred()
