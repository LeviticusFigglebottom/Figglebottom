class_name Area
extends Node3D
## One region of the highland in both of its lives. Owns the Base geometry and
## the Thaw/Rime layers, both navmeshes, the env rig, hearths and gates.
## AreaBuilder assembles these from data; sandboxes build them by hand.
## StateDirector drives apply_state(); nothing else touches layers directly.

var area_id := "area"
var display_name := "Somewhere"

var base: Node3D
var thaw_layer: Node3D
var rime_layer: Node3D
var env: EnvRig
var nav_thaw: NavigationRegion3D
var nav_rime: NavigationRegion3D
var terrain: Terrain = null
## Terrain areas bake only the playable footprint (the horizon is scenery).
var nav_aabb := AABB()

var _applied: int = -1

func _init() -> void:
	add_to_group("nav_src")   # navmesh bakes parse this subtree
	base = Node3D.new(); base.name = "Base"; add_child(base)
	thaw_layer = Node3D.new(); thaw_layer.name = "ThawLayer"; add_child(thaw_layer)
	rime_layer = Node3D.new(); rime_layer.name = "RimeLayer"; add_child(rime_layer)
	env = EnvRig.new(); env.name = "Env"; add_child(env)

func state() -> RH.WState:
	return World.get_area_state(area_id)

func default_spawn() -> Vector3:
	var def: Dictionary = get_meta("def", {})
	var st: Dictionary = def.get("start", {})
	var p: Array = st.get("pos", [])
	if p.size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	var hearths: Array = def.get("hearths", [])
	if not hearths.is_empty():
		var lp: Array = hearths[0].get("at", [0, 0.2, 0])
		if lp.size() >= 3:
			return Vector3(float(lp[0]), float(lp[1]) + 0.2, float(lp[2]) + 1.4)
	return Vector3(0, 0.3, 0)

## Attach a kit piece (or any node) to a layer. state_tag: "base"|"thaw"|"rime"
func attach(node: Node3D, state_tag := "base") -> void:
	match state_tag:
		"thaw": thaw_layer.add_child(node)
		"rime": rime_layer.add_child(node)
		_: base.add_child(node)

## Hard-apply a state: layer visibility, collision, nav swap, env snap.
## The transformation wave calls this at its END; loads call it directly.
func apply_state(s: RH.WState) -> void:
	_applied = s
	var rime_on := s == RH.WState.RIME
	_set_layer_active(thaw_layer, not rime_on)
	_set_layer_active(rime_layer, rime_on)
	if nav_thaw != null:
		nav_thaw.enabled = not rime_on
	if nav_rime != null:
		nav_rime.enabled = rime_on
	env.snap(s)
	# state-aware entities (hearth flames, doors, spawners) react themselves
	get_tree().call_group(RH.GROUP_STATE_LISTENERS, "on_world_state", area_id, s)

## During the wave both layers are visible (shader dissolve owns pixel
## presence); collision swaps immediately to the target so routes change.
func pre_transition(target: RH.WState) -> void:
	thaw_layer.visible = true
	rime_layer.visible = true
	_set_layer_collision(thaw_layer, target != RH.WState.RIME)
	_set_layer_collision(rime_layer, target == RH.WState.RIME)

func _set_layer_active(layer: Node3D, on: bool) -> void:
	layer.visible = on
	_set_layer_collision(layer, on)
	layer.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

func _set_layer_collision(layer: Node3D, on: bool) -> void:
	var stack: Array[Node] = [layer]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionObject3D:
			var co := n as CollisionObject3D
			if not co.has_meta("orig_layer"):
				co.set_meta("orig_layer", co.collision_layer)
			co.collision_layer = int(co.get_meta("orig_layer")) if on else 0
		for c in n.get_children():
			stack.append(c)

## Ambient particle beds per state (motes / ashfall).
func add_ambient(mn: Vector3, mx: Vector3) -> void:
	var center := (mn + mx) * 0.5
	var size := mx - mn
	# pollen and warm dust catching the low sun — soft alpha, not glowing orbs
	var motes := _ambient_emitter(size, Color(0.86, 0.74, 0.5, 0.14), 0.1, Vector3(0.12, 0.05, 0.0), 46)
	motes.position = center + Vector3(0, 2.2, 0)
	thaw_layer.add_child(motes)
	# snow crystals sifting down through the rime air
	var snow := _ambient_emitter(size, Color(0.88, 0.93, 1.0, 0.7), 0.5, Vector3(0.25, -0.5, 0.1), 90)
	var smat := FrostFX.material(FrostFX.crystal_tex(), Color(0.88, 0.93, 1.0, 0.7))
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	(snow.mesh as QuadMesh).material = smat
	snow.angle_max = 360.0
	snow.position = center + Vector3(0, 4.0, 0)
	rime_layer.add_child(snow)
	# life: distant birds wheel over thaw; petals drift; crows keep the rime
	var birds := _ambient_emitter(size * 1.6, Color(0.13, 0.10, 0.09, 0.9), 1.6, Vector3(1.6, 0.06, 0.5), 24)
	birds.position = center + Vector3(0, 15.0, 0)
	birds.emission_box_extents.y = 5.0
	thaw_layer.add_child(birds)
	var petals := _ambient_emitter(size, Color(0.9, 0.78, 0.76, 0.34), 0.4, Vector3(0.3, -0.22, 0.12), 30)
	petals.position = center + Vector3(0, 3.4, 0)
	thaw_layer.add_child(petals)
	var crows := _ambient_emitter(size * 1.3, Color(0.06, 0.05, 0.07, 0.95), 1.3, Vector3(1.1, 0.04, -0.4), 12)
	crows.position = center + Vector3(0, 11.0, 0)
	crows.emission_box_extents.y = 4.0
	rime_layer.add_child(crows)

## Soft alpha-blended flecks (motes/snow/petals/birds). Deliberately NOT additive:
## additive + the environment's bloom turned these into big white orbs.
func _ambient_emitter(size: Vector3, color: Color, scale_max: float, drift: Vector3, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size.x * 0.5, 3.2, size.z * 0.5)
	p.direction = drift.normalized() if drift.length() > 0.01 else Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = drift.length() * 0.5
	p.initial_velocity_max = drift.length() * 1.4
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.008
	p.scale_amount_max = 0.018 * (1.0 + scale_max)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# honour the colour's own alpha at the centre (was forced to 1.0, which made
	# these read as solid pale orbs) and fade to nothing at the rim
	var grad := Gradient.new()
	grad.set_color(0, color)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 32
	gt.height = 32
	mat.albedo_texture = gt
	quad.material = mat
	p.mesh = quad
	return p

func _exit_tree() -> void:
	retire()
	if get_tree() != null:
		for n in get_tree().get_nodes_in_group("nav_src"):
			if n != self and n is Area:
				var other := n as Area
				if other._applied >= 0:
					if other.nav_thaw != null:
						other.nav_thaw.enabled = other._applied != RH.WState.RIME
					if other.nav_rime != null:
						other.nav_rime.enabled = other._applied == RH.WState.RIME
				break

## Bake both navmeshes from the current geometry (on load, and again when
## base routes change — an opened gate, cleared rubble).
func bake_navmeshes() -> void:
	# retire the old regions BEFORE freeing: queue_free leaves them enabled in
	# the shared map for the rest of the frame, overlapping the fresh bake
	# ("Navigation map synchronization had N edge errors")
	if nav_thaw != null:
		nav_thaw.enabled = false
		NavigationServer3D.region_set_map(nav_thaw.get_rid(), RID())
		nav_thaw.queue_free()
	if nav_rime != null:
		nav_rime.enabled = false
		NavigationServer3D.region_set_map(nav_rime.get_rid(), RID())
		nav_rime.queue_free()
	if not is_in_group("nav_src"):
		return   # a retired area never bakes again
	# If another Area is still sitting in the tree at the same origin (e.g. a
	# test inspecting two areas side by side), keep its geometry and regions out
	# of this bake and out of the shared navigation map so their polygons never
	# collide in the same rasterizer cells.
	var siblings: Array[Area] = []
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("nav_src"):
			if n != self and n is Area:
				var other := n as Area
				siblings.append(other)
				other.remove_from_group("nav_src")
				if other.nav_thaw != null:
					other.nav_thaw.enabled = false
				if other.nav_rime != null:
					other.nav_rime.enabled = false
	nav_thaw = _bake_nav("NavThaw", false)
	nav_rime = _bake_nav("NavRime", true)
	for other in siblings:
		if is_instance_valid(other):
			other.add_to_group("nav_src")
	if _applied >= 0:
		nav_thaw.enabled = _applied != RH.WState.RIME
		nav_rime.enabled = _applied == RH.WState.RIME
		_set_layer_collision(thaw_layer, _applied != RH.WState.RIME)
		_set_layer_collision(rime_layer, _applied == RH.WState.RIME)

## Called when the area is being left (RH.free_gently): it lingers a few
## frames to quench its lights, and in that window it must not take part in
## the world. Leave the nav_src group so the next area's bake can't parse
## this geometry, shut both navmeshes off so they don't overlap the new
## area's in the shared map, and drop all collision so the arriving player
## never lands on the old area's floors.
func retire() -> void:
	remove_from_group("nav_src")
	if nav_thaw != null:
		nav_thaw.enabled = false
	if nav_rime != null:
		nav_rime.enabled = false
	for layer in [base, thaw_layer, rime_layer]:
		_set_layer_collision(layer, false)

func _bake_nav(name_: String, rime_world: bool) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = name_
	region.enabled = false
	add_child(region)
	var map_rid := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map_rid, 0.20)
	NavigationServer3D.map_set_cell_height(map_rid, 0.20)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.8
	mesh.agent_max_climb = 0.4
	mesh.cell_size = 0.20
	mesh.cell_height = 0.20
	if nav_aabb.size != Vector3.ZERO:
		mesh.filter_baking_aabb = nav_aabb
		mesh.agent_max_slope = 44.0
		# outdoors the biggest walker sets the margin: a 0.7 m Holdfast must
		# not be routed along a 0.4 m hairline past a kerb or a doorpost
		mesh.agent_radius = 0.6
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = "nav_src"
	mesh.geometry_collision_mask = (1 << (RH.L_WORLD_BASE - 1)) \
		| (1 << ((RH.L_WORLD_RIME if rime_world else RH.L_WORLD_THAW) - 1))
	region.navigation_mesh = mesh
	# make sure every layer's colliders carry their true layer bits for the
	# mask filter (they may have been zeroed by a previous apply_state)
	_set_layer_collision(thaw_layer, true)
	_set_layer_collision(rime_layer, true)
	region.bake_navigation_mesh(false)   # synchronous on load
	region.enabled = false
	return region
