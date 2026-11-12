class_name ShaderWarm
## Draws one tiny quad of each costly in-play material in front of a camera
## for a few frames, under the title's black veil, so the GPU pipelines are
## built before play needs them: the first frost-taken shattering, the
## first frost veil, the first ice, the net floor. Without it the first of
## each hitched mid-play.

const SHADERS := [
	"res://shaders/frost_dissolve.gdshader",
	"res://shaders/frost_veil.gdshader",
	"res://shaders/net_floor.gdshader",
	"res://shaders/flame.gdshader",
	"res://shaders/ice.gdshader",
	"res://shaders/trail.gdshader",
]
## material families from MaterialLib, in the state modes play uses
const FAMILIES := [["M_ice", 2], ["M_rime", 2], ["M_rime_cloth", 2], ["M_wood", 1], ["M_wood", 2], ["M_drift", 2], ["M_peat", 2]]
const FRAMES := 4

static func warm(parent: Node3D, cam: Camera3D) -> void:
	if parent == null or cam == null or not parent.is_inside_tree():
		return
	var holder := Node3D.new()
	holder.name = "ShaderWarm"
	cam.add_child(holder)
	var mats: Array[Material] = []
	for path in SHADERS:
		if ResourceLoader.exists(path):
			var m := ShaderMaterial.new()
			m.shader = load(path)
			mats.append(m)
	var diss := mats[0] as ShaderMaterial
	if diss != null:
		var d2 := diss.duplicate() as ShaderMaterial
		d2.set_shader_parameter("death_diss", 0.6)   # the shattering branch too
		mats.append(d2)
	for f in FAMILIES:
		mats.append(MaterialLib.get_mat(String(f[0]), int(f[1])))
	var i := 0
	for m in mats:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.002, 0.002)
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# a row just past the near plane, inside the frustum
		mi.position = Vector3(-0.01 + 0.0025 * i, 0.0, -cam.near - 0.05)
		holder.add_child(mi)
		i += 1
	var tree := parent.get_tree()
	for k in FRAMES:
		await tree.process_frame
	if is_instance_valid(holder):
		holder.queue_free()

# ------------------------------------------------------------ incoming areas
# A neighbour made ready ahead of a seam (Streamer, ADR 0014) is hidden until
# the swap, so nothing of it has been drawn: its materials are gathered and
# drawn here first, so the first frame after the swap compiles nothing.

## Every material the subtrees on `stack` draw with (surface materials,
## overrides, MultiMesh meshes, particle meshes), keyed by instance id into
## `out`. Budgeted: call again with the same stack until it returns true.
static func collect(stack: Array[Node], out: Dictionary, budget_us: int) -> bool:
	var t0 := Time.get_ticks_usec()
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GeometryInstance3D:
			var gi := n as GeometryInstance3D
			_keep(out, gi.material_override)
			_keep(out, gi.material_overlay)
			var mesh: Mesh = null
			if n is MeshInstance3D:
				mesh = (n as MeshInstance3D).mesh
				if mesh != null:
					for s in mesh.get_surface_count():
						_keep(out, (n as MeshInstance3D).get_surface_override_material(s))
			elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
				mesh = (n as MultiMeshInstance3D).multimesh.mesh
			elif n is CPUParticles3D:
				mesh = (n as CPUParticles3D).mesh
			elif n is GPUParticles3D:
				mesh = (n as GPUParticles3D).draw_pass_1
			if mesh != null and not out.has(-mesh.get_instance_id()):
				out[-mesh.get_instance_id()] = null    # (a mesh seen once: marker only)
				for s in mesh.get_surface_count():
					_keep(out, mesh.surface_get_material(s))
		for c in n.get_children():
			stack.append(c)
		if Time.get_ticks_usec() - t0 > budget_us:
			return false
	return true

static func _keep(out: Dictionary, m: Material) -> void:
	if m != null:
		out[m.get_instance_id()] = m

## The gathered materials, without the mesh markers.
static func materials(collected: Dictionary) -> Array[Material]:
	var mats: Array[Material] = []
	for k in collected:
		if collected[k] is Material:
			mats.append(collected[k])
	return mats

## Specks of the given materials well ahead of the camera, inside the frustum
## and the sun's shadow reach: far too small to light a pixel, but submitted,
## so their pipelines (colour, depth and shadow passes) are built. The caller
## frees the holder after a few frames.
static func draw(cam: Camera3D, mats: Array) -> Node3D:
	if cam == null or not cam.is_inside_tree() or mats.is_empty():
		return null
	var holder := Node3D.new()
	holder.name = "ShaderWarmArea"
	cam.add_child(holder)
	var q := QuadMesh.new()
	q.size = Vector2(0.0004, 0.0004)
	var i := 0
	for m in mats:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(-0.2 + 0.01 * (i % 40), -0.1 + 0.01 * (i / 40), -40.0)
		holder.add_child(mi)
		i += 1
	return holder
