class_name Terrain
extends Node3D
## Heightmap terrain (ADR 0003). Reads the committed grid written by a
## generator (tools/terrain_*.py), builds chunked ArrayMesh with two LODs,
## a coarse horizon ring, and one HeightMapShape3D collider. The splat
## layers ride the vertex colour into shaders/terrain.gdshader.

const SHADER := preload("res://shaders/terrain.gdshader")
const LOD1_STRIDE := 4
const LOD_SWITCH := 110.0

var origin := Vector2.ZERO
var cell := 1.0
var nx := 0
var nz := 0
var heights := PackedFloat32Array()
var splat := PackedByteArray()
var spec: Dictionary = {}

static var _mat: ShaderMaterial = null

static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	return _mat

func setup(s: Dictionary) -> bool:
	spec = s
	name = "Terrain"
	var o: Array = s.get("origin", [0, 0])
	origin = Vector2(float(o[0]), float(o[1]))
	cell = float(s.get("cell", 1.0))
	var sz: Array = s.get("size", [0, 0])
	nx = int(sz[0])
	nz = int(sz[1])
	heights = _read_floats(String(s.get("source", "")))
	if heights.size() != nx * nz:
		push_error("Terrain: heightmap %s has %d samples, want %d" % [s.get("source"), heights.size(), nx * nz])
		return false
	splat = FileAccess.get_file_as_bytes(String(s.get("splat", "")))
	if splat.size() != nx * nz * 4:
		splat = PackedByteArray()
	return true

static func _read_floats(path: String) -> PackedFloat32Array:
	var b := FileAccess.get_file_as_bytes(path)
	return b.to_float32_array()

func h_at(i: int, j: int) -> float:
	return heights[clampi(j, 0, nz - 1) * nx + clampi(i, 0, nx - 1)]

## Bilinear height at world (x, z) — the same surface HeightMapShape3D holds.
func height_at(x: float, z: float) -> float:
	var fx := (x - origin.x) / cell
	var fz := (z - origin.y) / cell
	var i := clampi(int(floor(fx)), 0, nx - 2)
	var j := clampi(int(floor(fz)), 0, nz - 2)
	var tx := fx - i
	var tz := fz - j
	var a := h_at(i, j)
	var b := h_at(i + 1, j)
	var c := h_at(i, j + 1)
	var d := h_at(i + 1, j + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func normal_at(x: float, z: float) -> Vector3:
	var e := cell
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()

## Painted layer 0..1: 0 shingle, 1 path, 2 wet, 3 variation.
func splat_at(x: float, z: float, layer: int) -> float:
	if splat.is_empty():
		return 0.0
	var i := clampi(int(round((x - origin.x) / cell)), 0, nx - 1)
	var j := clampi(int(round((z - origin.y) / cell)), 0, nz - 1)
	return splat[(j * nx + i) * 4 + layer] / 255.0

func contains(x: float, z: float) -> bool:
	return x >= origin.x and z >= origin.y and x <= origin.x + (nx - 1) * cell \
		and z <= origin.y + (nz - 1) * cell

func build(layer_bit: int) -> void:
	var chunk := int(spec.get("chunk", 32))
	var cj := 0
	while cj < nz - 1:
		var ci := 0
		while ci < nx - 1:
			var w := mini(chunk, nx - 1 - ci)
			var d := mini(chunk, nz - 1 - cj)
			var lod0 := MeshInstance3D.new()
			lod0.name = "chunk_%d_%d" % [ci / chunk, cj / chunk]
			lod0.mesh = _chunk_mesh(ci, cj, w, d, 1)
			lod0.visibility_range_end = LOD_SWITCH
			lod0.visibility_range_end_margin = 8.0
			lod0.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(lod0)
			var lod1 := MeshInstance3D.new()
			lod1.name = lod0.name + "_lod1"
			lod1.mesh = _chunk_mesh(ci, cj, w, d, LOD1_STRIDE)
			lod1.visibility_range_begin = LOD_SWITCH
			lod1.visibility_range_begin_margin = 8.0
			lod1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(lod1)
			# chunks are anchored at their centre so the range test measures
			# distance to the chunk, not to the world origin
			var c := Vector3(origin.x + (ci + w * 0.5) * cell, 0, origin.y + (cj + d * 0.5) * cell)
			lod0.position = c
			lod1.position = c
			ci += chunk
		cj += chunk
	_build_far()
	_build_collider(layer_bit)

func _vertex(i: int, j: int, center: Vector3, st: SurfaceTool) -> void:
	var x := origin.x + i * cell
	var z := origin.y + j * cell
	var hx := h_at(i + 1, j) - h_at(i - 1, j)
	var hz := h_at(i, j + 1) - h_at(i, j - 1)
	st.set_normal(Vector3(-hx, 2.0 * cell, -hz).normalized())
	if not splat.is_empty():
		var k := (clampi(j, 0, nz - 1) * nx + clampi(i, 0, nx - 1)) * 4
		st.set_color(Color(splat[k] / 255.0, splat[k + 1] / 255.0, splat[k + 2] / 255.0, splat[k + 3] / 255.0))
	else:
		st.set_color(Color(0, 0, 0, 0.5))
	st.add_vertex(Vector3(x, h_at(i, j), z) - center)

func _chunk_mesh(ci: int, cj: int, w: int, d: int, stride: int) -> ArrayMesh:
	var center := Vector3(origin.x + (ci + w * 0.5) * cell, 0, origin.y + (cj + d * 0.5) * cell)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := []
	var i := 0
	while i < w:
		cols.append(ci + i)
		i += stride
	cols.append(ci + w)
	var rows := []
	var j := 0
	while j < d:
		rows.append(cj + j)
		j += stride
	rows.append(cj + d)
	var cw := cols.size()
	for r in rows:
		for c in cols:
			_vertex(c, r, center, st)
	for rj in rows.size() - 1:
		for ri in cw - 1:
			var a := rj * cw + ri
			var b := a + 1
			var c2 := a + cw
			var d2 := c2 + 1
			st.add_index(a); st.add_index(b); st.add_index(c2)
			st.add_index(b); st.add_index(d2); st.add_index(c2)
	var mesh := st.commit()
	mesh.surface_set_material(0, material())
	return mesh

## The horizon: the same landform at 8 m, sunk beneath the play grid.
func _build_far() -> void:
	var path := String(spec.get("far", ""))
	if path == "":
		return
	var fh := _read_floats(path)
	var n := int(spec.get("far_size", 0))
	if fh.size() != n * n:
		return
	var fo: Array = spec.get("far_origin", [0, 0])
	var fc := float(spec.get("far_cell", 8.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var hh := fh[j * n + i]
			var hx := fh[j * n + mini(i + 1, n - 1)] - fh[j * n + maxi(i - 1, 0)]
			var hz := fh[mini(j + 1, n - 1) * n + i] - fh[maxi(j - 1, 0) * n + i]
			st.set_normal(Vector3(-hx, 2.0 * fc, -hz).normalized())
			var shore := 1.0 if hh < 4.0 else 0.0
			st.set_color(Color(shore, 0, 0, 0.5))
			st.add_vertex(Vector3(float(fo[0]) + i * fc, hh, float(fo[1]) + j * fc))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + n)
			st.add_index(a + 1); st.add_index(a + n + 1); st.add_index(a + n)
	var mesh := st.commit()
	mesh.surface_set_material(0, material())
	var mi := MeshInstance3D.new()
	mi.name = "Horizon"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_collider(layer_bit: int) -> void:
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1 << (layer_bit - 1)
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = nx
	hm.map_depth = nz
	hm.map_data = heights
	cs.shape = hm
	# HeightMapShape3D is centred on its node with 1-unit spacing
	cs.position = Vector3(origin.x + (nx - 1) * cell * 0.5, 0, origin.y + (nz - 1) * cell * 0.5)
	cs.scale = Vector3(cell, 1, cell)
	body.add_child(cs)
	add_child(body)
