extends SceneTree
## Export a procedural piece (KitLib piece or BuildingGen house) as ONE mesh
## with a unique, non-overlapping UV atlas, ready for `tripo_import
## {use_original_uv: true}` + `tripo_texture` (docs/art/LOOK_PASS.md §4).
##
##   godot --headless --path . --script tools/art/export_proc_glb.gd -- \
##       --kit=drying_rack --out=raw/proc/drying_rack.glb
##   godot ... -- --house='{"id":"fishhouse_0","size":[8,8],...}' --out=...
##
## Every surface is merged (the Tripo texture replaces the family materials),
## the far-LOD slabs and colliders are dropped, and xatlas (lightmap_unwrap)
## lays out UV2, which is written as UV0 for Tripo.

func _init() -> void:
	var kit := ""
	var house := ""
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kit="):
			kit = a.get_slice("=", 1)
		elif a.begins_with("--house="):
			house = a.substr(8)
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var root: Node3D
	if kit != "":
		root = KitLib.instance(kit, 0)
	else:
		var area := Area.new()
		var spec: Dictionary = JSON.parse_string(house)
		spec["center"] = [0, 0]
		spec["yaw"] = 0
		spec["y"] = 0
		root = BuildingGen.build(area, spec)
		root.get_parent().remove_child(root)
		root.position = Vector3.ZERO
		area.free()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name == "walls_far" or m.mesh == null or not m.visible:
			continue
		var xf := _rel_xf(root, m)
		for s in m.mesh.get_surface_count():
			st.append_from(m.mesh, s, xf)
			n += 1
	st.generate_normals()
	var mesh := st.commit()
	# unique atlas for the baked texture; texel size ~2 cm
	var err := mesh.lightmap_unwrap(Transform3D.IDENTITY, 0.02)
	if err != OK:
		push_error("lightmap_unwrap failed: %d" % err)
		quit(1)
		return
	var arr := mesh.surface_get_arrays(0)
	arr[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV2]
	arr[Mesh.ARRAY_TEX_UV2] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var out_mesh := ArrayMesh.new()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.55, 0.48)
	out_mesh.surface_set_material(0, mat)
	var scene := Node3D.new()
	scene.name = (kit if kit != "" else "house")
	var omi := MeshInstance3D.new()
	omi.name = scene.name
	omi.mesh = out_mesh
	scene.add_child(omi)
	omi.owner = scene
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(scene, state)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	err = doc.write_to_filesystem(state, out)
	print("[export] %s surfaces=%d verts=%d -> %s (%d)" % [scene.name, n,
		(arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), out, err])
	quit(0 if err == OK else 1)

func _rel_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf
