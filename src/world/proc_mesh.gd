class_name ProcMesh
## Primitive geometry with real UVs in METRES, so MaterialLib's photo sets read
## at true world scale through `MaterialLib.get_mat(family, mode, true)`
## (uv_mode 1). Boxes are mapped planar per face with V running along the
## piece's grain (its longest axis unless told otherwise), so a stave's, a
## beam's or a plank's wood grain follows the board, and every box gets its
## own random UV offset so neighbouring boards never repeat the same patch.
##
## All helpers write NON-indexed vertices (normal + uv each), so one
## SurfaceTool can mix boxes and appended primitives; call finish() once to
## add tangents (the photo normal map needs them) and commit.

static var _unit_box: Array = []

## A box of `size` placed by `xf` (local to the SurfaceTool's mesh).
## grain: 0/1/2 = x/y/z runs along V; -1 = the longest axis.
static func box(st: SurfaceTool, size: Vector3, xf: Transform3D, grain := -1, uv_off := Vector2.INF) -> void:
	if _unit_box.is_empty():
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		_unit_box = bm.get_mesh_arrays()
	var verts: PackedVector3Array = _unit_box[Mesh.ARRAY_VERTEX]
	var nrms: PackedVector3Array = _unit_box[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = _unit_box[Mesh.ARRAY_INDEX]
	var g := grain
	if g < 0:
		g = 0 if (size.x >= size.y and size.x >= size.z) else (1 if size.y >= size.z else 2)
	if uv_off == Vector2.INF:
		# a stable offset from the box's own placement: deterministic per house
		var h := hash(xf.origin.snapped(Vector3.ONE * 0.01))
		uv_off = Vector2(float(h & 0xffff) / 6553.6, float((h >> 16) & 0xffff) / 6553.6)
	var nb := xf.basis.inverse().transposed()
	# UV2.x: one random tone per board, so split staves read as separate
	# pieces of timber (MaterialLib uv mode shades it)
	var tone := fposmod(uv_off.x * 7.31 + uv_off.y * 3.17, 1.0)
	for i in idx:
		var p := verts[i] * size
		var n := nrms[i]
		st.set_normal((nb * n).normalized())
		st.set_uv(_face_uv(p, n, g) + uv_off)
		st.set_uv2(Vector2(tone, 0.0))
		st.add_vertex(xf * p)

static func _face_uv(p: Vector3, n: Vector3, g: int) -> Vector2:
	var an := n.abs()
	var a := 0 if (an.x >= an.y and an.x >= an.z) else (1 if an.y >= an.z else 2)
	var o: Array = [1, 2] if a == 0 else ([0, 2] if a == 1 else [0, 1])
	var v_ax: int = g if g != a else int(o[1])
	var u_ax: int = int(o[0]) if v_ax != int(o[0]) else int(o[1])
	return Vector2(p[u_ax], -p[v_ax])

## Append any PrimitiveMesh (cylinder, torus, sphere) with its UVs scaled to
## metres: uv_scale = (around, along), e.g. (TAU * r, height) for a log.
static func append(st: SurfaceTool, mesh: Mesh, xf: Transform3D, uv_scale := Vector2.ONE, uv_off := Vector2.ZERO) -> void:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var nb := xf.basis.inverse().transposed()
	var order: PackedInt32Array = idx
	if order.is_empty():
		order.resize(verts.size())
		for i in verts.size():
			order[i] = i
	for i in order:
		st.set_normal((nb * nrms[i]).normalized())
		var uv := uvs[i] if i < uvs.size() else Vector2.ZERO
		st.set_uv(uv * uv_scale + uv_off)
		st.set_uv2(Vector2(fposmod(uv_off.x * 7.31 + uv_off.y * 3.17, 1.0), 0.0))
		st.add_vertex(xf * verts[i])

## Tangents for the photo normal map, then commit. Returns null when empty.
static func finish(st: SurfaceTool, existing: ArrayMesh = null) -> ArrayMesh:
	var probe := st.commit_to_arrays()
	if probe.is_empty() or probe[Mesh.ARRAY_VERTEX] == null or (probe[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		return existing
	st.index()
	st.generate_tangents()
	return st.commit(existing)
