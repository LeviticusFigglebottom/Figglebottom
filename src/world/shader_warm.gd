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
	mats.append_array(StateDirector.wave_materials())
	retain(mats)     # (or the shaders built here went with the holder)
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

## Specks of particle materials: a one-particle CPUParticles3D each, so the
## pipeline built is the instanced one particles draw with (colour and
## custom data per instance), not a plain mesh's. Same holder rules as draw().
static func draw_particles(cam: Camera3D, mats: Array) -> Node3D:
	if cam == null or not cam.is_inside_tree() or mats.is_empty():
		return null
	var holder := Node3D.new()
	holder.name = "ShaderWarmParticles"
	cam.add_child(holder)
	var i := 0
	for m in mats:
		var p := CPUParticles3D.new()
		p.amount = 1
		p.lifetime = 0.5
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = 0.0004
		p.emission_ring_inner_radius = 0.0001
		p.emission_ring_height = 0.0001
		p.gravity = Vector3.ZERO
		p.color_ramp = _ramp()
		var q := QuadMesh.new()
		q.size = Vector2(0.0004, 0.0004)
		q.material = m
		p.mesh = q
		p.position = Vector3(0.2 - 0.01 * i, -0.1, -40.0)
		holder.add_child(p)
		p.emitting = true
		i += 1
	return holder

static var _ramp_g: Gradient = null
static func _ramp() -> Gradient:
	if _ramp_g == null:
		_ramp_g = Gradient.new()
	return _ramp_g

## One unseen, unmoving copy of each model scene (a foe's, a soul's, a
## find's), tiny and far ahead of the camera: instancing it builds the
## pipelines its own meshes draw with (their vertex formats, skinning), which
## a speck of the material alone does not. Only imported models (.glb and the
## like): they carry no script, so standing one up for a few frames does
## nothing to play. Returns the holder (free it after a few frames), or null.
static func draw_model(cam: Camera3D, scene: PackedScene) -> Node3D:
	if cam == null or not cam.is_inside_tree() or scene == null:
		return null
	if not scene.resource_path.get_extension().to_lower() in ["glb", "gltf", "fbx", "blend", "obj"]:
		return null
	var inst := scene.instantiate() as Node3D
	if inst == null:
		return null
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		ap.free()    # (nothing plays; an autoplay would only cost)
	var holder := Node3D.new()
	holder.name = "ShaderWarmModel"
	holder.position = Vector3(0.0, -0.1, -40.0)
	holder.scale = Vector3.ONE * 0.0005
	holder.add_child(inst)
	cam.add_child(holder)
	return holder

# ------------------------------------------------------------ keeping shaders
# A shader lives only while some material uses it. When the last one goes
# (the area left is freed, the wave's particles end) the renderer frees the
# shader and every pipeline built for it; the next material of that kind
# compiles them all again, in the frame it first appears. That is the likely
# cause of the 50 to 100 ms frames a real GPU showed on every crossing
# ("graft: what acts", warm cache as bad as cold) and every turn to RIME
# ("flip: wave particles"); docs/qa/STREAMING.md. So one
# stand-in per kind of shader is kept for the whole run: a ShaderMaterial's
# Shader itself, or a copy of a StandardMaterial3D with its textures swapped
# for one blank pixel (the shader it compiles to depends on which textures
# are set, never on what they hold).

const KEEP_MAX := 1024
static var _kept: Dictionary = {}       # key -> Shader or stand-in Material
static var _seen: Dictionary = {}       # material instance id -> true
static var _blank: ImageTexture = null

## Keep the shaders `mats` draw with alive for the rest of the run. Returns
## how many new kinds were kept.
static func retain(mats: Array) -> int:
	var added := 0
	if _seen.size() > 8192:
		_seen.clear()     # (instance ids are reused: a stale entry only skips a check)
	for m in mats:
		var mat := m as Material
		if mat == null or _kept.size() >= KEEP_MAX:
			continue
		var id := mat.get_instance_id()
		if _seen.has(id):
			continue
		_seen[id] = true
		if mat.next_pass != null:
			added += retain([mat.next_pass])
		if mat is ShaderMaterial:
			var sh := (mat as ShaderMaterial).shader
			if sh != null and not _kept.has(sh.get_instance_id()):
				_kept[sh.get_instance_id()] = sh
				added += 1
		elif mat is BaseMaterial3D:
			var key := _base_key(mat as BaseMaterial3D)
			if not _kept.has(key):
				_kept[key] = _stand_in(mat as BaseMaterial3D)
				added += 1
	return added

static func retained() -> int:
	return _kept.size()

## What a StandardMaterial3D's shader is made from: its modes and flags
## (ints and bools) and which textures are set. Colours and amounts are
## uniforms and make no new shader.
static func _base_key(m: BaseMaterial3D) -> String:
	var parts := PackedStringArray([m.get_class()])
	for p in m.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var t := int(p["type"])
		if t == TYPE_INT or t == TYPE_BOOL:
			parts.append(str(m.get(p["name"])))
		elif t == TYPE_OBJECT and String(p["hint_string"]).contains("Texture"):
			parts.append("T" if m.get(p["name"]) != null else "-")
	return "|".join(parts)

static func _stand_in(m: BaseMaterial3D) -> BaseMaterial3D:
	if _blank == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_blank = ImageTexture.create_from_image(img)
	var s := m.duplicate() as BaseMaterial3D
	s.next_pass = null
	for p in s.get_property_list():
		if int(p["type"]) == TYPE_OBJECT and String(p["hint_string"]).contains("Texture") \
				and s.get(p["name"]) != null:
			s.set(p["name"], _blank)
	return s
