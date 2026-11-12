class_name DragFurrow
extends Node3D
## The Drag-Mark (POI.md 2.1, RIME): one furrow a keel wide where a boat was
## hauled up the Strand over the shingle and not over its rollers. A scripted
## area entity, tag rime. The generator samples the beach under it ("rows":
## stations up the beach, each a list of [x, y, z] across the mark, odd in
## number, the keel line in the middle) and this lays the shape on top: snow
## pushed up in a berm either side, bare dark shingle down the middle.
## Nothing here collides: it is a mark, and the Bearer walks over it.

var rows: Array = []
var berm := 0.16          # how high the pushed-up snow stands, metres
var groove := 0.03        # the bare strip sits this far over the beach it is drawn on

func _ready() -> void:
	if rows.size() < 2:
		return
	var n: int = (rows[0] as Array).size()
	var mid := n / 2
	var snow := SurfaceTool.new()
	snow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bare := SurfaceTool.new()
	bare.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in rows.size():
		var row: Array = rows[i]
		var line: Array = []
		# the ends run out: the mark starts and stops without a step
		var fade := clampf(minf(float(i), float(rows.size() - 1 - i)) / 2.0, 0.0, 1.0)
		for k in n:
			var p := Vector3(float(row[k][0]), float(row[k][1]), float(row[k][2])) - global_position
			var off := absi(k - mid)
			# profile from the keel line out: bare, bare edge, berm crest, berm foot
			var lift := groove
			if off == mid:
				lift = -0.03
			elif off == mid - 1:
				lift = berm * fade * (0.8 + 0.4 * _hash(i * 7 + k))
			elif off == mid - 2:
				lift = groove + 0.02
			p.y += lift
			line.append(p)
		pts.append(line)
	for i in rows.size() - 1:
		for k in n - 1:
			var inner := (k >= mid - 2 and k < mid + 2) if mid >= 2 else false
			var st := bare if inner else snow
			var a: Vector3 = pts[i][k]
			var b: Vector3 = pts[i][k + 1]
			var c: Vector3 = pts[i + 1][k + 1]
			var d: Vector3 = pts[i + 1][k]
			var uv := func(v: Vector3) -> Vector2: return Vector2(v.x, v.z) * 0.5
			# two triangles, wound to face up (stations run up the beach, -z)
			for tri in [[a, c, b], [a, d, c]]:
				var nrm := ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3))
				var order: Array = tri if nrm.y < 0.0 else [tri[0], tri[2], tri[1]]
				for v in order:
					st.set_uv(uv.call(v))
					st.add_vertex(v)
	for pair in [[snow, "M_snow", "berm"], [bare, "M_shingle", "keel_line"]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.name = String(pair[2])
		mi.mesh = st.commit()
		mi.material_override = MaterialLib.get_mat(String(pair[1]), 2)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if String(pair[1]) == "M_shingle":
			# scraped bare: the frost has not had the time to lie on it again
			mi.set_instance_shader_parameter("indoor", 1.0)
		add_child(mi)

static func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)
