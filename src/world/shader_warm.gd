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
