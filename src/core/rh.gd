class_name RH

## Build tag shown in the HUD pose line — proves WHICH code a screenshot ran
const BUILD := "R1"

## Renderer discipline for MASS teardown: freeing a subtree that carries
## lights (worst: cull-masked key rigs like a key-lit player's or the
## a boss's) in the same frame as its geometry churns can hit
## Godot's cull-pairing SIGSEGV ("did not unpair geometries from light").
## Quench every light first, give the cull a frame, then free.
static func quench_lights(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Light3D:
			(n as Light3D).visible = false
		for c in n.get_children():
			stack.append(c)

## quench + a breath + queue_free, for whole areas/stages.
static func free_gently(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	quench_lights(node)
	if node.has_method("retire"):
		node.call("retire")   # areas leave nav/collision before the lungs frames
	free_after(node, 0.06)

## queue_free `node` after `secs`, on a tween the node itself owns. A SceneTree
## timer + lambda outlives its capture when the node dies early with its
## parent (area rebuilt, puzzle freed) and fires "Lambda capture was freed";
## a node-bound tween simply dies with the node. Pausable like the tree.
static func free_after(node: Node, secs: float) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var tw := node.create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(node.queue_free)

## Stop a particle emitter after `secs` (same node-owned lifetime rule).
static func stop_emitting_after(p: Node, secs: float) -> void:
	if p == null or not is_instance_valid(p) or not p.is_inside_tree():
		return
	var tw := p.create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(p.set.bind("emitting", false))

## Apply per-subtree dissolve (`death_diss` uniform) by lazily cloning surface
## ShaderMaterials on the target character/ghost meshes. Keeping `death_diss`
## as a regular uniform instead of an `instance uniform` on `hall.gdshader`
## prevents the 4,000+ static architectural meshes in large areas from exhausting the 4,096-item OpenGL3 UBO limit.
static func set_dissolve(root: Node, v: float) -> void:
	if root == null or not is_instance_valid(root):
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var cloned := mi.has_meta("_diss_cloned")
				for s in mi.mesh.get_surface_count():
					var mat := mi.get_surface_override_material(s)
					if mat == null:
						mat = mi.mesh.surface_get_material(s)
					if mat is ShaderMaterial:
						if not cloned:
							mat = mat.duplicate()
							mi.set_surface_override_material(s, mat)
						(mat as ShaderMaterial).set_shader_parameter("death_diss", v)
				if not cloned:
					mi.set_meta("_diss_cloned", true)
		for c in n.get_children():
			stack.append(c)
## Global constants and enums for Rimeholt.

enum WState { THAW, RIME }

const STATE_NAMES := { WState.THAW: "thaw", WState.RIME: "rime" }

static func state_from_name(n: String) -> WState:
	return WState.RIME if n == "rime" else WState.THAW

## Physics layers (bit indices, 1-based as in project settings)
const L_WORLD_BASE := 1
const L_WORLD_THAW := 2
const L_WORLD_RIME := 3
const L_PLAYER := 4
const L_ENEMY := 5
const L_HURTBOX := 6
const L_INTERACT := 7
const L_CAMERA_CLIP := 8

## Masks
const M_WORLD_ALL := (1 << 0) | (1 << 1) | (1 << 2)  # base|thaw|rime
const M_WORLD_BASE_ONLY := 1 << 0

## Node groups
const GROUP_STATE_LISTENERS := "state_listeners"   # notified on world state change
const GROUP_ENEMIES := "enemies"
const GROUP_RESPAWN_ON_REST := "respawn_on_rest"
const GROUP_NAV_THAW := "nav_thaw"
const GROUP_NAV_RIME := "nav_rime"
