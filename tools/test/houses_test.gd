extends TestBase
## Houses: the construction detail (HouseDetail, HouseInterior) is dressing
## only. For every house in every area: the collision solids are exactly the
## wall segments and door heads the spec implies, nothing else under the
## house collides, the near and far LODs hand over at one distance, and the
## land knows the footprint. Then a steered capsule proves it at Saltfell:
## in through the longhouse door past the open leaves and the threshold
## stone, and up to the long wall where a side bench stands.

const AREAS := ["saltfell_steading", "kettle_fjord", "tarnhall", "coldwell", "lowe_barrows"]

func _ready() -> void:
	_run.call_deferred()

## Collision boxes BuildingGen makes for a house spec: one per wall run
## between doors, one over each door.
func _expected_solids(spec: Dictionary) -> int:
	var w := float(spec["size"][0])
	var l := float(spec["size"][1])
	var doors := {}
	for d in spec.get("doors", []) + spec.get("gate_doors", []):
		doors["%s%d" % [String(d[0]), int(d[1])]] = true
	var n := 0
	for side in ["N", "S", "W", "E"]:
		if side in spec.get("open", []):
			continue
		var span := w if (side == "N" or side == "S") else l
		var cur := -span * 0.5
		for i in int(span / 4.0):
			if doors.has("%s%d" % [side, i]):
				var g := -span * 0.5 + 2.0 + 4.0 * i
				if g - BuildingGen.DOOR_W * 0.5 - cur >= 0.05:
					n += 1
				cur = g + BuildingGen.DOOR_W * 0.5
				n += 1
		if span * 0.5 - cur >= 0.05:
			n += 1
	return n

func _colliders(n: Node, out: Array) -> void:
	if n is CollisionObject3D:
		out.append(n)
	for c in n.get_children():
		_colliders(c, out)

func _steer(body: CharacterBody3D, to: Vector3, max_ticks: int) -> void:
	for i in max_ticks:
		var d := to - body.global_position
		d.y = 0.0
		if d.length() < 0.15:
			return
		body.velocity = d.normalized() * 3.0 + Vector3(0, -4.0, 0)
		body.move_and_slide()
		await get_tree().physics_frame

func _run() -> void:
	var saltfell: Area = null
	for area_id in AREAS:
		print("== ", area_id)
		var area := AreaBuilder.build(area_id)
		check(area != null, "%s builds" % area_id)
		if area == null:
			continue
		add_child(area)
		await ticks(3)
		var def: Dictionary = area.get_meta("def", {})
		var houses: Array = def.get("houses", [])
		var built := 0
		for spec in houses:
			var root := area.find_child("House_" + String(spec.get("id", "")), true, false)
			if root == null:
				continue      # flag-gated houses are not built yet
			built += 1
			var cols: Array = []
			_colliders(root, cols)
			check(cols.size() == 1 and cols[0] is StaticBody3D, "%s: one static body, nothing else collides" % spec["id"])
			if String(spec.get("kind", "house")) == "barrow":
				continue
			var shapes := 0
			if not cols.is_empty():
				shapes = (cols[0] as Node).get_child_count()
			check(shapes == _expected_solids(spec), "%s: %d collision boxes, as the spec implies" % [spec["id"], shapes])
			var staves := root.get_node_or_null("staves") as MeshInstance3D
			var far := root.get_node_or_null("M_wood_far") as MeshInstance3D
			check(staves != null and far != null and is_equal_approx(staves.visibility_range_end, HouseDetail.LOD_MID)
				and is_equal_approx(far.visibility_range_begin, HouseDetail.LOD_MID), "%s: near and far walls hand over at %d m" % [spec["id"], int(HouseDetail.LOD_MID)])
			check(root.get_node_or_null("turf") != null and root.get_node_or_null("frame") != null and root.get_node_or_null("in_frame") != null,
				"%s: turf, frame and roof trusses present" % spec["id"])
		if area.terrain != null:
			check(area.terrain._rects.size() == mini(built, Terrain.MAX_FOOTPRINTS), "the land knows %d footprints" % built)
		if area_id == "saltfell_steading":
			saltfell = area
		else:
			area.queue_free()
			await ticks(2)
	if saltfell != null:
		print("== steered capsule: the longhouse door and the side bench")
		var body := CharacterBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.34
		cap.height = 1.8
		cs.shape = cap
		cs.position.y = 0.9
		body.add_child(cs)
		body.collision_layer = 0
		body.collision_mask = 1 << (RH.L_WORLD_BASE - 1)
		add_child(body)
		body.global_position = Vector3(0.0, 22.3, -16.5)
		await _steer(body, Vector3(0.0, 22.0, -24.0), 400)
		check(body.global_position.z < -23.5, "walked in through the longhouse door (z %.2f)" % body.global_position.z)
		# the east wall: only the wall's own collision stops the capsule (5.46)
		await _steer(body, Vector3(4.0, 22.0, -38.0), 600)
		await _steer(body, Vector3(6.5, 22.0, -38.0), 300)
		check(body.global_position.x > 5.3, "stood against the long wall through the bench (x %.2f)" % body.global_position.x)
	finish()
