class_name KitLib
## Greybox kit: every piece is built procedurally from primitives (no art
## assets). Each mesh carries a placeholder material whose resource_name is a
## MaterialLib family, so remap_materials() routes it onto the hall shader
## exactly as authored art would be. Characters are "mannequins": a 17-bone
## Skeleton3D (the shared humanoid rest pose SkelAnim was authored against)
## with rigid primitive limbs riding BoneAttachment3Ds.

static var _manifest: Dictionary = {}
static var _scene_cache: Dictionary = {}   # kept for API parity (always empty)

## id -> {size:[x,y,z], origin}. Sizes match the greybox geometry below.
const PIECES := {
	"floor_4x4": {"size": [4, 0.25, 4], "origin": "top-center"},
	"wall_4x4": {"size": [4, 0.4, 4], "origin": "bottom-center"},
	"wall_low_4m": {"size": [4, 0.4, 1.05], "origin": "bottom-center"},
	"column_4m": {"size": [0.8, 0.8, 4], "origin": "bottom-center"},
	"pillar": {"size": [0.8, 0.8, 4], "origin": "bottom-center"},
	"portal_4m": {"size": [4, 0.4, 4], "origin": "bottom-center", "opening": [1.9, 2.9]},
	"arch_4m": {"size": [4, 0.4, 4], "origin": "bottom-center", "opening": [2.8, 3.2]},
	"stair_4m": {"size": [4, 2.4, 4], "origin": "top-center"},
	"ramp_4m": {"size": [4, 1.0, 4], "origin": "bottom-start"},
	"roof_slab_4m": {"size": [4, 4, 0.3], "origin": "center"},
	"beam_4m": {"size": [4, 0.3, 0.3], "origin": "center"},
	"gate_iron": {"size": [3.6, 0.3, 3.2], "origin": "bottom-center"},
	"fence_iron_4m": {"size": [4, 0.3, 3], "origin": "bottom-center"},
	"frost_veil_frame": {"size": [4, 1, 5.2], "origin": "bottom-center", "opening": [3.2, 3.1]},
	"hearthstone": {"size": [1.3, 1.3, 1.4], "origin": "bottom-center"},
	"brazier": {"size": [0.6, 0.6, 1.1], "origin": "bottom-center"},
	"candelabra": {"size": [0.6, 0.6, 1.1], "origin": "bottom-center"},
	"plaque": {"size": [0.74, 0.3, 1.2], "origin": "bottom-center"},
	"pell": {"size": [1.0, 0.8, 1.96], "origin": "bottom-center"},
	"barrel": {"size": [0.7, 0.7, 0.9], "origin": "bottom-center"},
	"crate": {"size": [1.0, 1.0, 1.0], "origin": "bottom-center"},
	"table_3m": {"size": [3.0, 1.0, 0.8], "origin": "bottom-center"},
	"bench_3m": {"size": [3.0, 0.4, 0.45], "origin": "bottom-center"},
	"woodpile": {"size": [2.0, 0.8, 1.0], "origin": "bottom-center"},
	"rime_spike": {"size": [0.8, 0.8, 1.8], "origin": "bottom-center"},
	"gourd": {"size": [0.17, 0.17, 0.26], "origin": "bottom-center"},
	"rye_sack": {"size": [0.9, 0.5, 0.4], "origin": "bottom-center"},
	"net_float": {"size": [0.16, 0.16, 0.12], "origin": "bottom-center"},
	"hewing_blade": {"size": [0.3, 0.05, 1.1], "origin": "grip"},
	"maul": {"size": [0.37, 0.25, 1.65], "origin": "grip"},
	"spear": {"size": [0.11, 0.05, 2.9], "origin": "grip"},
	"greatblade": {"size": [0.5, 0.05, 1.85], "origin": "grip"},
	"bow": {"size": [0.08, 0.4, 1.6], "origin": "grip"},
	"torch": {"size": [0.14, 0.14, 1.0], "origin": "grip-center"},
	"shield_kite": {"size": [0.5, 0.1, 0.6], "origin": "strap"},
	"fish_kettle": {"size": [1.6, 1.6, 2.2], "origin": "bottom-center"},
	"net_frame": {"size": [3.6, 0.4, 2.5], "origin": "bottom-center"},
	"rope_coil": {"size": [0.9, 0.9, 0.35], "origin": "bottom-center"},
	"creel_stack": {"size": [1.4, 0.8, 1.2], "origin": "bottom-center"},
	"boat_upturned": {"size": [1.8, 6.0, 1.5], "origin": "bottom-center"},
	"door_leaf": {"size": [0.95, 0.12, 2.5], "origin": "bottom-center"},
	"gable_8m": {"size": [4, 8, 3.2], "origin": "bottom-center"},
	"gable_12m": {"size": [4, 12, 4.4], "origin": "bottom-center"},
	"gable_end_8m": {"size": [8, 0.4, 3.2], "origin": "bottom-center"},
	"gable_end_12m": {"size": [12, 0.4, 4.4], "origin": "bottom-center"},
	"boat": {"size": [1.8, 6.0, 0.9], "origin": "bottom-center"},
	"drying_rack": {"size": [4.0, 1.2, 2.2], "origin": "bottom-center"},
	"ladder": {"size": [0.6, 0.2, 4.0], "origin": "bottom-center"},
	"salt_pan": {"size": [3.0, 2.0, 0.45], "origin": "bottom-center"},
	"well": {"size": [1.4, 1.4, 1.0], "origin": "bottom-center"},
	"mannequin_wayfarer": {"skeletal": true},
	"mannequin_rime": {"skeletal": true},
	"mannequin_holdfast": {"skeletal": true},
	"mannequin_thaw": {"skeletal": true},
}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = PIECES.duplicate(true)
	return _manifest

static func has_piece(id: String) -> bool:
	return PIECES.has(id)

## state_mode: 0 base / 1 thaw-only / 2 rime-only (drives dissolve behavior)
static func instance(id: String, state_mode := 0, mat_remap: Dictionary = {}) -> Node3D:
	if not PIECES.has(id):
		push_error("KitLib: unknown piece '%s'" % id)
		return Node3D.new()
	var node := Node3D.new()
	node.name = id
	if id.begins_with("mannequin_"):
		_build_mannequin(node, id)
	else:
		_build_piece(node, id)
	remap_materials(node, state_mode, mat_remap)
	node.set_meta("kit_id", id)
	node.set_meta("state_mode", state_mode)
	return node

# ------------------------------------------------------------ primitives

static var _ph_mats: Dictionary = {}

static func _ph(fam: String) -> Material:
	if not _ph_mats.has(fam):
		var m := StandardMaterial3D.new()
		m.resource_name = fam
		_ph_mats[fam] = m
	return _ph_mats[fam]

static func _box(parent: Node3D, size: Vector3, pos: Vector3, fam: String, nm := "box", rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _ph(fam)
	mi.mesh = bm
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, fam: String,
		nm := "cyl", rot := Vector3.ZERO, segs := 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	cm.material = _ph(fam)
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func _sphere(parent: Node3D, r: float, pos: Vector3, fam: String, nm := "sphere", sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 7
	sm.material = _ph(fam)
	mi.mesh = sm
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi

static func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, fam: String, nm := "capsule") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0 + 0.01)
	cm.radial_segments = 10
	cm.rings = 3
	cm.material = _ph(fam)
	mi.mesh = cm
	mi.position = pos
	parent.add_child(mi)
	return mi

## A flame tongue (M_flame shader) — add_flame_lights() finds it by name.
static func _torus(parent: Node3D, r: float, thick: float, pos: Vector3, fam: String, nm := "torus") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	var tm := TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r + thick
	tm.rings = 16
	tm.ring_segments = 6
	tm.material = _ph(fam)
	mi.mesh = tm
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _flame(parent: Node3D, pos: Vector3, h: float, r: float, nm := "flame") -> MeshInstance3D:
	return _cyl(parent, 0.0, r, h, pos + Vector3(0, h * 0.5, 0), "M_flame", nm, Vector3.ZERO, 8)

## A wall panel with a rectangular opening (w x h) centred on x.
static func _wall_with_opening(n: Node3D, w: float, h: float, ow: float, oh: float, t: float, fam: String) -> void:
	var side := (w - ow) * 0.5
	_box(n, Vector3(side, h, t), Vector3(-(ow + side) * 0.5, h * 0.5, 0), fam, "jamb_l")
	_box(n, Vector3(side, h, t), Vector3((ow + side) * 0.5, h * 0.5, 0), fam, "jamb_r")
	_box(n, Vector3(ow, h - oh, t), Vector3(0, oh + (h - oh) * 0.5, 0), fam, "lintel")

## A triangular gable end: base w on the wall top, apex h above, thickness t.
static func _prism(n: Node3D, w: float, h: float, t: float, fam: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-w * 0.5, 0, 0)
	var b := Vector3(w * 0.5, 0, 0)
	var c := Vector3(0, h, 0)
	var f := Vector3(0, 0, t * 0.5)
	var tris := [[a + f, b + f, c + f], [b - f, a - f, c - f],
		[a - f, a + f, c + f], [a - f, c + f, c - f], [b + f, b - f, c - f], [b + f, c - f, c + f]]
	for tri in tris:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "gable"
	var mesh := st.commit()
	mesh.surface_set_material(0, _ph(fam))
	mi.mesh = mesh
	n.add_child(mi)

static func _build_piece(n: Node3D, id: String) -> void:
	match id:
		"floor_4x4":
			_box(n, Vector3(4, 0.23, 4), Vector3(0, -0.135, 0), "M_stone_dark", "floor")
		"wall_4x4":
			_box(n, Vector3(4, 4, 0.38), Vector3(0, 2, 0), "M_stone", "wall")
			_box(n, Vector3(4.02, 0.3, 0.44), Vector3(0, 3.85, 0), "M_wood", "wall_cap")
		"wall_low_4m":
			_box(n, Vector3(4, 1.05, 0.38), Vector3(0, 0.525, 0), "M_stone", "wall")
		"column_4m", "pillar":
			_box(n, Vector3(0.8, 4, 0.8), Vector3(0, 2, 0), "M_wood", "post")
			_box(n, Vector3(0.95, 0.3, 0.95), Vector3(0, 0.15, 0), "M_stone_trim", "plinth")
		"portal_4m":
			_wall_with_opening(n, 4, 4, 1.9, 2.9, 0.38, "M_stone")
			_box(n, Vector3(2.3, 0.3, 0.5), Vector3(0, 3.05, 0), "M_wood", "door_beam")
		"arch_4m":
			_wall_with_opening(n, 4, 4, 2.8, 3.2, 0.38, "M_stone")
			_box(n, Vector3(3.2, 0.32, 0.5), Vector3(0, 3.36, 0), "M_wood", "arch_beam")
		"stair_4m":
			# eight treads descending toward -Z from the top edge (origin)
			for i in 8:
				var y := -0.3 * (i + 1)
				_box(n, Vector3(4, 0.3, 0.5), Vector3(0, y + 0.15, -0.25 - 0.5 * i), "M_stone_trim", "step%d" % i)
		"ramp_4m":
			# rises 1 m over 4 m toward -Z, foot at origin
			var ang := rad_to_deg(atan2(1.0, 4.0))
			_box(n, Vector3(4, 0.3, 4.12), Vector3(0, 0.35, -2.0), "M_stone_dark", "ramp", Vector3(ang, 0, 0))
		"roof_slab_4m":
			_box(n, Vector3(4, 0.3, 4), Vector3.ZERO, "M_roof", "slab")
		"beam_4m":
			_box(n, Vector3(4, 0.3, 0.3), Vector3.ZERO, "M_wood", "beam")
		"gate_iron":
			for i in 7:
				_box(n, Vector3(0.12, 3.2, 0.12), Vector3(-1.5 + i * 0.5, 1.6, 0), "M_wood", "plank%d" % i)
			_box(n, Vector3(3.6, 0.22, 0.2), Vector3(0, 0.6, 0), "M_iron", "band_lo")
			_box(n, Vector3(3.6, 0.22, 0.2), Vector3(0, 2.6, 0), "M_iron", "band_hi")
		"fence_iron_4m":
			for i in 9:
				_box(n, Vector3(0.1, 3.0, 0.1), Vector3(-2 + i * 0.5, 1.5, 0), "M_wood", "stake%d" % i)
			_box(n, Vector3(4, 0.16, 0.14), Vector3(0, 2.4, 0), "M_wood", "rail")
		"frost_veil_frame":
			_box(n, Vector3(0.4, 3.6, 0.6), Vector3(-1.8, 1.8, 0), "M_wood", "post_l")
			_box(n, Vector3(0.4, 3.6, 0.6), Vector3(1.8, 1.8, 0), "M_wood", "post_r")
			_box(n, Vector3(4.2, 0.4, 0.7), Vector3(0, 3.6, 0), "M_wood", "lintel")
		"fish_kettle":
			# a great iron fish-kettle on a tripod over the fire
			for k in 3:
				var a := TAU * k / 3.0
				_box(n, Vector3(0.09, 2.3, 0.09), Vector3(cos(a) * 0.55, 1.05, sin(a) * 0.55), "M_wood_dark", "leg%d" % k,
					Vector3(sin(a) * 14, 0, -cos(a) * 14))
			_cyl(n, 0.62, 0.48, 0.75, Vector3(0, 0.95, 0), "M_iron", "kettle", Vector3.ZERO, 16)
			_cyl(n, 0.58, 0.58, 0.04, Vector3(0, 1.31, 0), "M_marsh", "broth", Vector3.ZERO, 16)
			_box(n, Vector3(0.04, 0.7, 0.04), Vector3(0, 1.75, 0), "M_iron", "chain")
			for k in 5:
				_box(n, Vector3(0.6, 0.12, 0.12), Vector3(0, 0.08, 0), "M_wood", "fire_log%d" % k, Vector3(0, k * 36, 0))
			_flame(n, Vector3(0, 0.12, 0), 0.45, 0.28, "fire_flame")
		"net_frame":
			# a net hung to dry between two poles, sagging, floats along the head-rope
			for sx in [-1.6, 1.6]:
				_box(n, Vector3(0.1, 2.5, 0.1), Vector3(sx, 1.25, 0), "M_wood_dark", "pole", Vector3(0, 0, -sx * 2.0))
			_box(n, Vector3(3.5, 0.05, 0.05), Vector3(0, 2.3, 0), "M_leather", "head_rope")
			for k in 9:
				var x := -1.4 + k * 0.35
				var sag := 0.25 * (1.0 - pow(x / 1.5, 2.0))
				_box(n, Vector3(0.018, 1.7 - sag, 0.018), Vector3(x, 1.45 - sag * 0.5 + 0.0, 0.06 * sin(k * 1.7)), "M_robe", "cord_v%d" % k)
			for k in 6:
				var y := 0.7 + k * 0.28
				_box(n, Vector3(3.0, 0.018, 0.018), Vector3(0, y - 0.18 * (1.0 - k / 5.0), 0.04), "M_robe", "cord_h%d" % k,
					Vector3(0, 0, sin(k * 2.1) * 2.0))
			for k in 6:
				_sphere(n, 0.07, Vector3(-1.25 + k * 0.5, 2.24, 0), "M_drift", "float%d" % k, Vector3(1, 0.8, 1))
		"rope_coil":
			for k in 3:
				_torus(n, 0.3 - k * 0.04, 0.06, Vector3(0.02 * k, 0.06 + k * 0.1, -0.02 * k), "M_leather", "coil%d" % k)
		"creel_stack":
			# wicker creels, two stacked and one tipped beside them
			_cyl(n, 0.34, 0.27, 0.48, Vector3(-0.25, 0.24, 0), "M_drift", "creel_a", Vector3.ZERO, 10)
			_cyl(n, 0.34, 0.27, 0.48, Vector3(-0.22, 0.73, 0.03), "M_drift", "creel_b", Vector3(0, 0, 4), 10)
			_cyl(n, 0.34, 0.27, 0.48, Vector3(0.45, 0.28, 0.1), "M_drift", "creel_c", Vector3(0, 30, 80), 10)
			for k in 3:
				_box(n, Vector3(0.7, 0.03, 0.03), Vector3(-0.24, 0.12 + k * 0.17, 0.33), "M_wood_dark", "band%d" % k)
		"boat_upturned":
			# a boat hauled up for the ice, keel to the sky on two trestles
			for z in [-1.6, 1.6]:
				_box(n, Vector3(1.6, 0.08, 0.1), Vector3(0, 0.62, z), "M_wood", "trestle_bar")
				for sx in [-0.7, 0.7]:
					_box(n, Vector3(0.08, 0.66, 0.08), Vector3(sx, 0.31, z), "M_wood", "trestle_leg", Vector3(0, 0, sx * 14))
			_sphere(n, 1.0, Vector3(0, 0.7, 0), "M_wood", "hull", Vector3(0.85, 0.42, 3.0)).rotation_degrees = Vector3(0, 0, 180)
			_box(n, Vector3(0.12, 0.2, 5.6), Vector3(0, 1.1, 0), "M_wood", "keel")
		"door_leaf":
			# one plank leaf: four boards on two ledges and a brace
			for k in 4:
				_box(n, Vector3(0.23, 2.45, 0.07), Vector3(-0.36 + k * 0.24, 1.25, 0), "M_wood", "board%d" % k)
			for yy in [0.45, 2.05]:
				_box(n, Vector3(0.9, 0.14, 0.06), Vector3(0, yy, -0.065), "M_wood_dark", "ledge")
			_box(n, Vector3(0.1, 1.75, 0.05), Vector3(0, 1.25, -0.07), "M_wood_dark", "brace", Vector3(0, 0, 38))
			_box(n, Vector3(0.12, 0.12, 0.1), Vector3(0, 1.2, 0.06), "M_iron", "ring")
		"gable_8m", "gable_12m":
			# a turf roof bay, 4 m along local X, spanning local Z, on the wall top
			var half := 4.3 if id == "gable_8m" else 6.3
			var rise := 3.2 if id == "gable_8m" else 4.4
			var slope := sqrt(half * half + rise * rise)
			var ang := rad_to_deg(atan2(rise, half))
			for sz in [-1.0, 1.0]:
				_box(n, Vector3(4.02, 0.42, slope), Vector3(0, rise * 0.5, sz * half * 0.5), "M_turf", "turf", Vector3(sz * ang, 0, 0))
				_box(n, Vector3(4.02, 0.12, slope), Vector3(0, rise * 0.5 - 0.27, sz * half * 0.5 + sz * 0.08), "M_wood", "boards", Vector3(sz * ang, 0, 0))
			_box(n, Vector3(4.1, 0.3, 0.4), Vector3(0, rise + 0.05, 0), "M_wood", "ridge", Vector3(0, 0, 0))
		"gable_end_8m", "gable_end_12m":
			var gw := 8.0 if id == "gable_end_8m" else 12.0
			var gh := 3.2 if id == "gable_end_8m" else 4.4
			_prism(n, gw, gh, 0.38, "M_wood")
		"boat":
			_sphere(n, 1.0, Vector3(0, 0.42, 0), "M_wood", "hull", Vector3(0.85, 0.42, 3.0))
			_box(n, Vector3(0.12, 0.2, 5.6), Vector3(0, 0.05, 0), "M_wood", "keel")
			for k in 3:
				_box(n, Vector3(1.4, 0.06, 0.24), Vector3(0, 0.62, -1.2 + k * 1.2), "M_wood", "thwart%d" % k)
		"drying_rack":
			for sx in [-1.9, 1.9]:
				_box(n, Vector3(0.12, 2.3, 0.12), Vector3(sx, 1.0, 0.45), "M_wood", "leg_a", Vector3(-12, 0, 0))
				_box(n, Vector3(0.12, 2.3, 0.12), Vector3(sx, 1.0, -0.45), "M_wood", "leg_b", Vector3(12, 0, 0))
			_box(n, Vector3(4.1, 0.1, 0.1), Vector3(0, 2.1, 0), "M_wood", "rail")
			_box(n, Vector3(4.0, 0.06, 0.06), Vector3(0, 1.45, 0.3), "M_wood", "rail_lo")
			for k in 7:
				_box(n, Vector3(0.18, 0.7, 0.05), Vector3(-1.6 + k * 0.53, 1.72, 0.02), "M_drift", "fish%d" % k, Vector3(0, 0, (k % 3 - 1) * 4))
		"ladder":
			for sx in [-0.25, 0.25]:
				_box(n, Vector3(0.08, 4.0, 0.08), Vector3(sx, 2.0, 0), "M_wood", "rail")
			for k in 10:
				_box(n, Vector3(0.5, 0.05, 0.06), Vector3(0, 0.3 + k * 0.38, 0), "M_wood", "rung%d" % k)
		"salt_pan":
			_box(n, Vector3(3.0, 0.45, 2.0), Vector3(0, 0.225, 0), "M_stone", "rim")
			_box(n, Vector3(2.6, 0.06, 1.6), Vector3(0, 0.44, 0), "M_bone", "brine")
		"well":
			_cyl(n, 0.7, 0.75, 0.9, Vector3(0, 0.45, 0), "M_stone", "ring", Vector3.ZERO, 10)
			_cyl(n, 0.55, 0.55, 0.05, Vector3(0, 0.8, 0), "M_marsh", "water", Vector3.ZERO, 10)
			_box(n, Vector3(1.8, 0.1, 0.1), Vector3(0, 1.9, 0), "M_wood", "beam")
			for sx in [-0.85, 0.85]:
				_box(n, Vector3(0.1, 1.9, 0.1), Vector3(sx, 0.95, 0), "M_wood", "post")
		"hearthstone":
			_cyl(n, 0.62, 0.7, 0.35, Vector3(0, 0.175, 0), "M_stone_trim", "ring")
			_cyl(n, 0.5, 0.55, 0.2, Vector3(0, 0.45, 0), "M_stone_dark", "bed")
			for i in 5:
				var a := TAU * i / 5.0
				_box(n, Vector3(0.16, 0.12, 0.7), Vector3(cos(a) * 0.18, 0.6, sin(a) * 0.18), "M_wood", "log%d" % i, Vector3(0, -rad_to_deg(a), 14))
			_box(n, Vector3(0.4, 1.4, 0.4), Vector3(0, 0.7, -0.95), "M_stone", "standing_stone")
			_flame(n, Vector3(0, 0.55, 0), 0.9, 0.3, "hearth_flame")
		"brazier", "candelabra":
			_cyl(n, 0.08, 0.12, 0.8, Vector3(0, 0.4, 0), "M_iron", "stem")
			_cyl(n, 0.3, 0.18, 0.2, Vector3(0, 0.9, 0), "M_iron", "bowl")
			_flame(n, Vector3(0, 0.95, 0), 0.4, 0.17, "flame")
		"plaque":
			# a weathered board nailed to a driftwood stake, words cut with a
			# knife (no carved stone: runes are off the table, ORIGINALITY.md)
			_box(n, Vector3(0.12, 1.25, 0.12), Vector3(0, 0.62, 0.02), "M_wood_dark", "stake", Vector3(-4, 0, 0))
			_box(n, Vector3(0.72, 0.46, 0.05), Vector3(0, 1.02, -0.06), "M_wood", "board", Vector3(-8, 0, 2))
		"pell":
			_cyl(n, 0.12, 0.12, 1.9, Vector3(0, 0.95, 0), "M_wood", "pole")
			_box(n, Vector3(1.0, 0.12, 0.12), Vector3(0, 1.45, 0), "M_wood", "arms")
			_sphere(n, 0.18, Vector3(0, 1.82, 0), "M_cloth", "head")
			_capsule(n, 0.25, 0.8, Vector3(0, 1.15, 0), "M_cloth", "sack")
		"barrel":
			_cyl(n, 0.32, 0.32, 0.9, Vector3(0, 0.45, 0), "M_wood", "staves", Vector3.ZERO, 14)
			_cyl(n, 0.35, 0.35, 0.06, Vector3(0, 0.2, 0), "M_iron", "hoop_lo")
			_cyl(n, 0.35, 0.35, 0.06, Vector3(0, 0.7, 0), "M_iron", "hoop_hi")
		"crate":
			_box(n, Vector3(1, 1, 1), Vector3(0, 0.5, 0), "M_wood", "crate")
		"table_3m":
			_box(n, Vector3(3.0, 0.1, 1.0), Vector3(0, 0.78, 0), "M_wood", "top")
			for sx in [-1.3, 1.3]:
				_box(n, Vector3(0.12, 0.74, 0.8), Vector3(sx, 0.37, 0), "M_wood", "trestle")
		"bench_3m":
			_box(n, Vector3(3.0, 0.08, 0.4), Vector3(0, 0.44, 0), "M_wood", "seat")
			for sx in [-1.2, 1.2]:
				_box(n, Vector3(0.1, 0.42, 0.34), Vector3(sx, 0.21, 0), "M_wood", "leg")
		"woodpile":
			for i in 6:
				_cyl(n, 0.13, 0.13, 2.0, Vector3(0, 0.14 + 0.24 * float(i / 3), -0.28 + 0.28 * (i % 3)), "M_wood", "log%d" % i, Vector3(0, 0, 90))
		"rime_spike":
			_cyl(n, 0.0, 0.32, 1.8, Vector3(0, 0.9, 0), "M_rime", "spike_a", Vector3(6, 0, 4), 6)
			_cyl(n, 0.0, 0.2, 1.1, Vector3(0.35, 0.55, 0.1), "M_rime", "spike_b", Vector3(-4, 0, -18), 6)
		"rye_sack":
			# a flattened, dog-shaped sack: wide and low, one corner chewed
			_sphere(n, 0.42, Vector3(0, 0.15, 0), "M_habit", "sack", Vector3(1.0, 0.36, 0.62))
			_sphere(n, 0.12, Vector3(0.38, 0.12, 0.16), "M_habit", "corner", Vector3(1.0, 0.6, 0.8))
		"net_float":
			_cyl(n, 0.075, 0.075, 0.1, Vector3(0, 0.06, 0), "M_drift", "cork", Vector3(90, 0, 0), 14)
			_cyl(n, 0.012, 0.012, 0.22, Vector3(0, 0.06, 0), "M_leather", "line", Vector3(90, 0, 0), 6)
		"gourd":
			_sphere(n, 0.085, Vector3(0, 0.08, 0), "M_leather", "belly")
			_sphere(n, 0.05, Vector3(0, 0.19, 0), "M_leather", "neck")
		"hewing_blade":
			_cyl(n, 0.022, 0.022, 0.2, Vector3(0, 0.0, 0), "M_leather", "grip")
			_box(n, Vector3(0.26, 0.04, 0.05), Vector3(0, 0.12, 0), "M_iron", "guard")
			_box(n, Vector3(0.06, 0.92, 0.012), Vector3(0, 0.6, 0), "M_steel", "blade")
		"maul":
			_cyl(n, 0.025, 0.025, 1.3, Vector3(0, 0.45, 0), "M_wood", "haft")
			_box(n, Vector3(0.37, 0.25, 0.25), Vector3(0, 1.15, 0), "M_iron", "head")
		"spear":
			_cyl(n, 0.02, 0.02, 2.6, Vector3(0, 0.9, 0), "M_wood", "haft")
			_box(n, Vector3(0.08, 0.32, 0.012), Vector3(0, 2.36, 0), "M_steel", "leaf")
		"greatblade":
			_cyl(n, 0.025, 0.025, 0.36, Vector3(0, 0.0, 0), "M_leather", "grip")
			_box(n, Vector3(0.44, 0.05, 0.06), Vector3(0, 0.2, 0), "M_iron", "guard")
			_box(n, Vector3(0.1, 1.55, 0.016), Vector3(0, 1.0, 0), "M_steel", "blade")
		"bow":
			_box(n, Vector3(0.04, 0.8, 0.03), Vector3(0, 0.38, 0.06), "M_wood", "limb_hi", Vector3(-10, 0, 0))
			_box(n, Vector3(0.04, 0.8, 0.03), Vector3(0, -0.38, 0.06), "M_wood", "limb_lo", Vector3(10, 0, 0))
			_box(n, Vector3(0.005, 1.55, 0.005), Vector3(0, 0, -0.02), "M_cloth", "string")
		"torch":
			_cyl(n, 0.025, 0.02, 0.8, Vector3(0, 0.1, 0), "M_wood", "shaft")
			_cyl(n, 0.05, 0.04, 0.14, Vector3(0, 0.52, 0), "M_cloth", "wrap")
			_flame(n, Vector3(0, 0.58, 0), 0.3, 0.07, "flame")
		"shield_kite":
			_cyl(n, 0.3, 0.3, 0.04, Vector3(0, 0, 0.03), "M_wood", "board", Vector3(90, 0, 0), 16)
			_sphere(n, 0.07, Vector3(0, 0, 0.06), "M_iron", "boss")

# ------------------------------------------------------------ mannequins

## Bone rest transforms (parent-relative) of the shared humanoid armature.
## [name, parent, basis x, basis y, basis z, origin]
const BONES := [
	["hips", -1, Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0.96, 0)],
	["spine", 0, Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0.12, 0)],
	["chest", 1, Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0.16, 0)],
	["neck", 2, Vector3(1, 0, 0), Vector3(0, 0.9912279, -0.13216387), Vector3(0, 0.13216387, 0.99122787), Vector3(0, 0.2, 0)],
	["head", 3, Vector3(1, 0, 0), Vector3(0, 0.9962672, 0.08632297), Vector3(0, -0.08632297, 0.9962672), Vector3(0, 0.060530946, 0)],
	["uarm_r", 2, Vector3(0.976461, 0.15908569, 0.1456912), Vector3(0.14569461, -0.9844202, 0.0984414), Vector3(0.1590815, -0.074897535, -0.9844228), Vector3(0.225, 0.16, 0)],
	["farm_r", 5, Vector3(0.9858256, 0.11995543, 0.1172967), Vector3(-0.15433323, 0.9225692, 0.35362014), Vector3(-0.06579566, -0.36671057, 0.92800546), Vector3(0, 0.25395668, 0)],
	["hand_r", 6, Vector3(0.9987518, 0.0399679, 0.029957082), Vector3(-0.038756408, 0.9984483, -0.039985422), Vector3(-0.031508733, 0.038774487, 0.9987511), Vector3(0, 0.25019976, 0)],
	["uarm_l", 2, Vector3(0.976461, -0.15908569, -0.1456912), Vector3(-0.14569461, -0.9844202, 0.0984414), Vector3(-0.1590815, -0.074897535, -0.9844228), Vector3(-0.225, 0.16, 0)],
	["farm_l", 8, Vector3(0.9858256, -0.11995543, -0.1172967), Vector3(0.15433323, 0.9225692, 0.35362014), Vector3(0.06579566, -0.36671057, 0.92800546), Vector3(0, 0.25395668, 0)],
	["hand_l", 9, Vector3(0.9987518, -0.0399679, -0.029957082), Vector3(0.038756408, 0.9984483, -0.039985422), Vector3(0.031508733, 0.038774487, 0.9987511), Vector3(0, 0.25019976, 0)],
	["thigh_r", 0, Vector3(0.9998218, 0.01307659, 0.013623811), Vector3(0.0136237005, -0.9990717, -0.040871095), Vector3(0.013076716, 0.04104944, -0.9990723), Vector3(0.11, 0, 0)],
	["shin_r", 11, Vector3(0.99982166, 0.013623696, 0.013076476), Vector3(-0.011865355, 0.99193114, -0.12622122), Vector3(-0.014690564, 0.12604357, 0.99191594), Vector3(0, 0.44040886, 0)],
	["foot_r", 12, Vector3(1, 0, 0), Vector3(0, 0.2851627, 0.95847917), Vector3(0, -0.95847917, 0.2851627), Vector3(0, 0.42153996, 0)],
	["thigh_l", 0, Vector3(0.9998218, -0.01307659, -0.013623811), Vector3(-0.0136237005, -0.9990717, -0.040871095), Vector3(-0.013076716, 0.04104944, -0.9990723), Vector3(-0.11, 0, 0)],
	["shin_l", 14, Vector3(0.99982166, -0.013623696, -0.013076476), Vector3(0.011865355, 0.99193114, -0.12622122), Vector3(0.014690564, 0.12604357, 0.99191594), Vector3(0, 0.44040886, 0)],
	["foot_l", 15, Vector3(1, 0, 0), Vector3(0, 0.2851627, 0.95847917), Vector3(0, -0.95847917, 0.2851627), Vector3(0, 0.42153996, 0)],
]

## bone -> [length along +Y, radius]
const LIMBS := {
	"hips": [0.14, 0.17], "spine": [0.17, 0.16], "chest": [0.22, 0.2],
	"neck": [0.08, 0.06], "head": [0.24, 0.115],
	"uarm_r": [0.25, 0.065], "farm_r": [0.25, 0.055], "hand_r": [0.11, 0.045],
	"uarm_l": [0.25, 0.065], "farm_l": [0.25, 0.055], "hand_l": [0.11, 0.045],
	"thigh_r": [0.44, 0.085], "shin_r": [0.42, 0.065], "foot_r": [0.2, 0.05],
	"thigh_l": [0.44, 0.085], "shin_l": [0.42, 0.065], "foot_l": [0.2, 0.05],
}

## archetype -> material families + bulk
const LOOKS := {
	"mannequin_wayfarer": {"torso": "M_leather", "limb": "M_cloth", "skin": "M_wax", "accent": "M_steel", "bulk": 1.0},
	"mannequin_rime": {"torso": "M_rime_cloth", "limb": "M_rime_cloth", "skin": "M_rime", "accent": "M_rime", "bulk": 0.95},
	"mannequin_holdfast": {"torso": "M_plate_dark", "limb": "M_rime_cloth", "skin": "M_rime", "accent": "M_rime", "bulk": 1.25},
	"mannequin_thaw": {"torso": "M_cloth", "limb": "M_habit", "skin": "M_wax", "accent": "M_wood", "bulk": 1.0},
}

static func _build_mannequin(root: Node3D, id: String) -> void:
	var arm := Node3D.new()
	arm.name = "Armature"
	root.add_child(arm)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	arm.add_child(sk)
	for b in BONES:
		var i := sk.add_bone(b[0])
		if int(b[1]) >= 0:
			sk.set_bone_parent(i, int(b[1]))
		var rest := Transform3D(Basis(b[2], b[3], b[4]), b[5])
		sk.set_bone_rest(i, rest)
		sk.set_bone_pose(i, rest)
	var look: Dictionary = LOOKS.get(id, LOOKS["mannequin_wayfarer"])
	var bulk := float(look["bulk"])
	for bname in LIMBS:
		var att := BoneAttachment3D.new()
		att.name = "Part_" + bname
		sk.add_child(att)
		att.bone_name = bname
		var spec: Array = LIMBS[bname]
		var length := float(spec[0])
		var r := float(spec[1]) * bulk
		var fam: String = look["limb"]
		if bname in ["hips", "spine", "chest"]:
			fam = look["torso"]
		elif bname.begins_with("hand") or bname == "neck":
			fam = look["skin"]
		elif bname.begins_with("foot") or bname.begins_with("shin"):
			fam = "M_leather" if id != "mannequin_rime" else String(look["limb"])
		if bname == "head":
			_sphere(att, r, Vector3(0, length * 0.45, 0.0), look["skin"], "head", Vector3(0.9, 1.15, 1.0))
			# a hood / helm cap so facing reads at a glance
			_sphere(att, r * 1.08, Vector3(0, length * 0.58, 0.03), look["accent"], "cap", Vector3(0.95, 0.75, 1.05))
		elif bname in ["hips", "spine", "chest"]:
			var w := r * (2.3 if bname == "chest" else 2.0)
			var d := r * 1.25
			_box(att, Vector3(w, length + 0.04, d), Vector3(0, length * 0.5, 0), fam, "torso_" + bname)
		elif bname.begins_with("foot"):
			_box(att, Vector3(r * 2.0, length, r * 1.6), Vector3(0, length * 0.5, 0), fam, "foot")
		else:
			_capsule(att, r, length + r, Vector3(0, length * 0.5, 0), fam, "limb_" + bname)
	# a skirt/tabard panel hanging from the hips reads as clothing
	var skirt := BoneAttachment3D.new()
	skirt.name = "Part_skirt"
	sk.add_child(skirt)
	skirt.bone_name = "hips"
	_box(skirt, Vector3(0.38 * bulk, 0.36, 0.26 * bulk), Vector3(0, -0.12, 0), look["torso"], "skirt")
	if id == "mannequin_holdfast":
		var crown := BoneAttachment3D.new()
		crown.name = "Part_crown"
		sk.add_child(crown)
		crown.bone_name = "head"
		for i in 5:
			var a := TAU * i / 5.0
			_cyl(crown, 0.0, 0.035, 0.22, Vector3(cos(a) * 0.1, 0.32, sin(a) * 0.1), "M_rime", "tine%d" % i, Vector3.ZERO, 5)
		var mantle := BoneAttachment3D.new()
		mantle.name = "Part_mantle"
		sk.add_child(mantle)
		mantle.bone_name = "chest"
		_box(mantle, Vector3(0.7, 0.14, 0.4), Vector3(0, 0.2, 0), "M_rime_cloth", "mantle")

# ------------------------------------------------------------ materials

static func remap_materials(node: Node, state_mode := 0, mat_remap: Dictionary = {}) -> void:
	for mi in _mesh_instances(node):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var fam := "M_stone"
			if src != null and src.resource_name != "":
				fam = src.resource_name
			fam = fam.get_slice(".", 0)
			if mat_remap.has(fam):
				fam = String(mat_remap[fam])
			mi.set_surface_override_material(s, MaterialLib.get_mat(fam, state_mode))
			if fam == "M_flame":
				var aabb := mesh.get_aabb()
				mi.set_instance_shader_parameter("flame_base_y", aabb.position.y)
				mi.set_instance_shader_parameter("flame_height", maxf(aabb.size.y, 0.05))
				mi.set_instance_shader_parameter("flame_tint", Vector3(1.0, 0.76, 0.32))
				mi.set_instance_shader_parameter("flame_energy", 3.6)

static func _mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out

## One consolidated OmniLight3D per flame-bearing piece.
static func add_flame_lights(piece: Node3D, energy := 2.15, range_m := 7.6,
		color := Color(1.0, 0.68, 0.32)) -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	var flame_meshes: Array[MeshInstance3D] = []
	for mi in _mesh_instances(piece):
		if String(mi.name).to_lower().contains("flame"):
			flame_meshes.append(mi)
	if flame_meshes.is_empty():
		return lights
	var avg_pos := Vector3.ZERO
	for mi in flame_meshes:
		var aabb := mi.get_aabb()
		var tip_local := aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y * 0.85, aabb.size.z * 0.5)
		avg_pos += mi.transform * tip_local
	avg_pos /= float(flame_meshes.size())
	var l := OmniLight3D.new()
	l.set_script(load("res://src/world/flame_flicker.gd"))
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.45
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 28.0
	l.distance_fade_length = 10.0
	l.position = avg_pos + Vector3(0, 0.08, 0)
	piece.add_child(l)
	lights.append(l)
	return lights

## Wrap a piece's meshes in StaticBody3D colliders (cached per piece/mesh).
## convex=false -> trimesh (architecture with openings); true -> convex hull.
static var _shape_cache: Dictionary = {}

static func add_collision(piece: Node3D, layer_bit: int, convex := false) -> void:
	var kit_id := str(piece.get_meta("kit_id", "?"))
	for mi in _mesh_instances(piece):
		if mi.mesh == null or String(mi.name).contains("flame"):
			continue
		var key := kit_id + "/" + str(mi.name) + ("/cvx" if convex else "")
		var shape: Shape3D = _shape_cache.get(key)
		if shape == null:
			shape = mi.mesh.create_convex_shape() if convex else mi.mesh.create_trimesh_shape()
			_shape_cache[key] = shape
		var body := StaticBody3D.new()
		body.collision_layer = 1 << (layer_bit - 1)
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
