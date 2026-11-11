class_name DrawBridge
extends Node3D
## A plank bridge on ropes, hinged at one lip of a ravine. Raised, it stands
## on end against the sky on the far side; lowered, it spans the gap for good
## (a world flag, so both areas that see it agree). Only the hinge side can
## work the windlass: from the other lip it is a shortcut you have to earn.
## Built along local -Z from the hinge: length, width.

var flag := "bridge_down"
var length := 16.0
var width := 2.4
var operable := true            # the windlass is on this side
## The far lip lies this much lower than the hinge: lowered, the deck slopes
## down to rest on it. (Laid level, the Lowe's bridge ended half a metre
## above the Saltfell yard: too high a step, so it could only be walked one way.)
var far_drop := 0.0
var prompt := "Lower the bridge"

var _deck: Node3D
var _body: StaticBody3D
var _zone: Interactable

func _ready() -> void:
	add_to_group(RH.GROUP_STATE_LISTENERS)
	_deck = Node3D.new()
	_deck.name = "Deck"
	add_child(_deck)
	var planks := SurfaceTool.new()
	planks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(flag)
	var z := 0.0
	while z < length:
		var bm := BoxMesh.new()
		bm.size = Vector3(width + rng.randf_range(-0.1, 0.15), 0.1, 0.32)
		planks.append_from(bm, 0, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)),
			Vector3(rng.randf_range(-0.05, 0.05), 0, -z - 0.18)))
		z += 0.36
	for sx in [-1.0, 1.0]:
		var rail := BoxMesh.new()
		rail.size = Vector3(0.14, 0.16, length)
		planks.append_from(rail, 0, Transform3D(Basis.IDENTITY, Vector3(sx * width * 0.5, -0.1, -length * 0.5)))
		# rope hand-lines on short posts
		var rope := BoxMesh.new()
		rope.size = Vector3(0.05, 0.05, length)
		planks.append_from(rope, 0, Transform3D(Basis.IDENTITY, Vector3(sx * (width * 0.5 + 0.05), 1.0, -length * 0.5)))
		var pz := 0.0
		while pz <= length:
			var post := BoxMesh.new()
			post.size = Vector3(0.09, 1.05, 0.09)
			planks.append_from(post, 0, Transform3D(Basis.IDENTITY, Vector3(sx * (width * 0.5 + 0.05), 0.5, -pz)))
			pz += 2.0
	planks.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = planks.commit()
	mi.mesh.surface_set_material(0, MaterialLib.get_mat("M_wood"))
	_deck.add_child(mi)
	# the windlass and its posts at the hinge
	var wl := KitLib.instance("woodpile")
	wl.position = Vector3(width * 0.5 + 1.2, 0, 1.0)
	wl.rotation.y = PI * 0.5
	add_child(wl)
	_body = StaticBody3D.new()
	_body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.3, length + 0.6)
	cs.shape = box
	cs.position = Vector3(0, -0.12, -length * 0.5)
	_body.add_child(cs)
	# hand-lines stop you walking off the side
	for sx in [-1.0, 1.0]:
		var rs := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(0.12, 1.2, length)
		rs.shape = rb
		rs.position = Vector3(sx * (width * 0.5 + 0.05), 0.6, -length * 0.5)
		_body.add_child(rs)
	_deck.add_child(_body)
	if operable:
		_zone = Interactable.new()
		_zone.prompt = prompt
		_zone.setup_zone(1.4, 1.8, Vector3(0, 0, 1.0))
		_zone.activated.connect(_on_lower)
		add_child(_zone)
	_apply(is_down(), true)

func is_down() -> bool:
	return World.flag(flag)

func _on_lower(_p) -> void:
	if is_down():
		return
	World.set_flag(flag)
	World.save_game()
	_apply(true, false)
	Game.toast.emit("The bridge comes down across the ravine.")

func _apply(down: bool, instant: bool) -> void:
	if _zone != null:
		_zone.enabled = not down
	# raised: stood on end over the hinge, a dark shape against the sky
	var target := -asin(clampf(far_drop / maxf(length, 0.1), -0.5, 0.5)) if down else deg_to_rad(88.0)
	if instant:
		_deck.rotation.x = target
	else:
		create_tween().tween_property(_deck, "rotation:x", target, 2.4)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# raised, the deck stands on end over the hinge and is as solid as it
	# looks: with its collider off the Bearer walked through the planks and
	# off the lip of the ravine behind them
	_body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	_body.set_meta("orig_layer", _body.collision_layer)
	if not instant and Game.current_area != null:
		Game.current_area.bake_navmeshes.call_deferred()

func on_world_state(_area_id: String, _s) -> void:
	pass
