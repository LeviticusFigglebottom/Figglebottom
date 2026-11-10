class_name MaterialLib
## The single source of visual truth: every kit surface maps to one of these
## shared ShaderMaterials. Variants exist per state-mode (base / thaw-only /
## rime-only) so layer-exclusive meshes dissolve correctly during the wave.
##
## Look pass (docs/art/LOOK_PASS.md): the tiling families carry a CC0 photo
## PBR set (TEXTURES -> assets/textures/<set>/, fetched and graded by
## tools/art/fetch_textures.py). The family "albedo" stays the authority for
## the MEAN colour; the photo supplies the detail. Two ways to map it:
##   get_mat(family, mode)        object-aligned triplanar at world metre
##                                scale: right for anything (kit primitives,
##                                rocks, imported meshes without metre UVs)
##   get_mat(family, mode, true)  the mesh's own UVs, in metres: use with
##                                ProcMesh output so grain follows each board

const HALL := preload("res://shaders/hall.gdshader")
const HALL_DS := preload("res://shaders/hall_ds.gdshader")
## Thin-shell families rendered double-sided (backface normal flipped in the
## shader). Empty on purpose: cull-off shading washed out lit roof slopes
## (wrong shadow bias on what were backfaces) — the gable kits emit true
## two-sided GEOMETRY instead, which lights and shadows correctly.
const DOUBLE_SIDED := {}
## Families that take a snow crust on their top faces in RIME.
const SNOW := {"M_timber": 0.75, "M_planks": 0.8, "M_drystone_wall": 0.85, "M_schist": 0.9, "M_shingle": 0.9, "M_snow": 1.0, "M_stone": 0.85, "M_stone_trim": 0.85, "M_stone_dark": 0.8, "M_wood": 0.75, "M_wood_dark": 0.75, "M_drystone": 0.85,
	"M_roof": 0.95, "M_turf": 0.95, "M_peat": 0.8, "M_needles": 0.8, "M_leaves": 0.7, "M_thorn": 0.6, "M_wool": 0.5, "M_bark_pine": 0.4, "M_drift": 0.85, "M_terrain": 0.9}

## family -> [set, repeats per metre, strength(, tint, contrast)]. Sets live in
## assets/textures/<set>/T_<set>_{albedo,normal,orh}.jpg; their linear means
## are in assets/textures/sets.json. Scale targets ~512 px/m near the player.
const TEXTURES := {
	"M_wood": ["timber", 0.55, 1.0], "M_timber": ["timber", 0.55, 1.0], "M_wood_dark": ["timber", 0.5, 1.0],
	"M_drift": ["timber", 0.6, 1.0, 1.0, 1.2], "M_planks": ["planks", 0.4, 1.0],
	# fieldstone has white shell flecks that read as veined marble at full
	# contrast on a box; walling stones take the stacked-stone set instead
	"M_stone": ["fieldstone", 0.55, 1.0, 1.0, 0.55], "M_stone_trim": ["fieldstone", 0.6, 1.0, 1.0, 0.55], "M_drystone": ["drystone", 0.55, 1.0, 1.0, 0.85],
	"M_stone_dark": ["rock", 0.4, 1.0], "M_schist": ["schist", 0.2, 1.0], "M_roof": ["schist", 0.35, 1.0],
	"M_drystone_wall": ["drystone", 0.4, 1.0], "M_shingle": ["shingle", 0.45, 1.0],
	"M_turf": ["turf", 0.4, 1.0], "M_peat": ["peat", 0.6, 1.0], "M_marsh": ["peat", 0.4, 1.0], "M_terrain": ["path", 0.3, 1.0],
	"M_snow": ["snow", 0.3, 1.0], "M_ice": ["ice", 0.25, 0.85, 1.0, 0.7],
	"M_iron": ["iron", 0.8, 1.0], "M_rope": ["rope", 2.5, 1.0],
	"M_wool": ["wool", 1.4, 1.0], "M_fleece": ["wool", 1.1, 1.0], "M_felt": ["felt", 1.2, 1.0],
	"M_cloth": ["wool", 1.4, 1.0], "M_robe": ["wool", 1.4, 1.0], "M_robe_boss": ["wool", 1.4, 1.0], "M_rime_cloth": ["wool", 1.4, 1.0],
	"M_habit": ["felt", 1.2, 1.0], "M_shroud": ["felt", 1.2, 1.0], "M_leather": ["leather", 1.2, 1.0],
}
const TEX_DIR := "res://assets/textures/"
const GLASS := preload("res://shaders/glass.gdshader")
const FLAME := preload("res://shaders/flame.gdshader")
const COALS := preload("res://shaders/coals.gdshader")
const WATER := preload("res://shaders/water.gdshader")
const ICE_SHEET := preload("res://shaders/ice_sheet.gdshader")
const FALLS := preload("res://shaders/falls.gdshader")

## family -> {albedo, rough, metallic, specular, normal_scale, rim, sss, sheen, local_uv, extras...}
const FAMILIES := {
	"M_stone":        {"albedo": Color(0.44, 0.43, 0.39), "rough": 0.88, "metallic": 0.0, "specular": 0.48, "normal_scale": 1.30, "rim": 0.28},
	"M_stone_trim":   {"albedo": Color(0.50, 0.47, 0.42), "rough": 0.82, "metallic": 0.0, "specular": 0.52, "normal_scale": 1.20, "rim": 0.36, "moss": 0.08},
	"M_stone_dark":   {"albedo": Color(0.36, 0.37, 0.34), "rough": 0.90, "metallic": 0.0, "specular": 0.46, "normal_scale": 1.35, "rim": 0.22, "moss": 1.0},
	"M_iron":         {"albedo": Color(0.17, 0.15, 0.14), "rough": 0.44, "metallic": 0.86, "specular": 0.72, "normal_scale": 1.15, "rim": 0.85, "wear": 0.28, "moss": 0.0, "crack": 0.0},
	# silvered, split timber (STYLE.md: brown-grey, silvered where weathered)
	"M_wood":         {"albedo": Color(0.40, 0.35, 0.29), "rough": 0.80, "metallic": 0.0, "specular": 0.42, "normal_scale": 1.20, "rim": 0.24, "moss": 0.3},
	"M_gold":         {"albedo": Color(0.82, 0.60, 0.22), "rough": 0.28, "metallic": 0.92, "specular": 0.85, "normal_scale": 0.90, "rim": 1.05, "moss": 0.0, "crack": 0.0,
					   "emission": Color(1.0, 0.75, 0.3), "emission_energy": 0.35, "emission_gate": 1},
	"M_ember":        {"albedo": Color(0.5, 0.14, 0.05), "rough": 0.78, "metallic": 0.0, "specular": 0.40, "rim": 0.3, "moss": 0.0, "crack": 0.0,
					   "emission": Color(1.0, 0.42, 0.12), "emission_energy": 2.6, "emission_gate": 1},
	"M_wax":          {"albedo": Color(0.85, 0.79, 0.62), "rough": 0.54, "metallic": 0.0, "specular": 0.55, "normal_scale": 0.95, "rim": 0.75, "sss": 0.68, "moss": 0.0, "crack": 0.0},
	"M_cloth":        {"albedo": Color(0.44, 0.07, 0.10), "rough": 0.90, "metallic": 0.0, "specular": 0.32, "normal_scale": 1.10, "rim": 0.48, "sheen": 0.58, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_bell":         {"albedo": Color(0.42, 0.30, 0.15), "rough": 0.42, "metallic": 0.85, "specular": 0.72, "normal_scale": 1.15, "rim": 0.85, "moss": 0.15, "crack": 0.0},
	"M_bronze":       {"albedo": Color(0.38, 0.27, 0.14), "rough": 0.38, "metallic": 0.88, "specular": 0.75, "normal_scale": 1.10, "rim": 0.95, "moss": 0.0, "crack": 0.0,
					   "emission": Color(0.45, 0.3, 0.1), "emission_energy": 0.06},
	"M_brass":        {"albedo": Color(0.64, 0.48, 0.22), "rough": 0.34, "metallic": 0.88, "specular": 0.78, "normal_scale": 1.00, "rim": 0.95, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_mosaic":       {"albedo": Color(0.58, 0.46, 0.28), "rough": 0.58, "metallic": 0.12, "specular": 0.62, "normal_scale": 1.25, "rim": 0.5, "moss": 0.15, "crack": 0.2},
	"M_bone":         {"albedo": Color(0.72, 0.68, 0.56), "rough": 0.78, "metallic": 0.0, "specular": 0.48, "normal_scale": 1.15, "rim": 0.55, "sss": 0.22, "moss": 0.1, "crack": 0.25},
	"M_shroud":       {"albedo": Color(0.62, 0.6, 0.54), "rough": 0.92, "metallic": 0.0, "specular": 0.30, "normal_scale": 1.10, "rim": 0.4, "sheen": 0.48, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_wraith":       {"albedo": Color(0.20, 0.24, 0.33), "rough": 0.72, "metallic": 0.15, "specular": 0.55, "normal_scale": 1.05, "rim": 1.5, "sheen": 0.65, "local_uv": 1, "moss": 0.0, "crack": 0.0,
					   "emission": Color(0.25, 0.38, 0.62), "emission_energy": 0.1},
	"M_robe":         {"albedo": Color(0.23, 0.24, 0.28), "rough": 0.90, "metallic": 0.0, "specular": 0.32, "normal_scale": 1.10, "rim": 0.5, "sheen": 0.52, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_robe_boss":    {"albedo": Color(0.24, 0.19, 0.26), "rough": 0.88, "metallic": 0.08, "specular": 0.42, "normal_scale": 1.15, "rim": 1.1, "sheen": 0.62, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_habit":        {"albedo": Color(0.55, 0.51, 0.44), "rough": 0.90, "metallic": 0.0, "specular": 0.32, "normal_scale": 1.10, "rim": 0.45, "sheen": 0.46, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_leather":      {"albedo": Color(0.30, 0.20, 0.12), "rough": 0.68, "metallic": 0.0, "specular": 0.52, "normal_scale": 1.10, "rim": 0.38, "sheen": 0.22, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	# deep slate: lit slopes must stay dark enough to sit INTO the dusk grade
	# (the old 0.33-0.40 albedo read as flat white once lit sides became visible)
	"M_roof":         {"albedo": Color(0.14, 0.13, 0.14), "rough": 0.86, "metallic": 0.0, "specular": 0.48, "normal_scale": 1.30, "rim": 0.25, "moss": 0.5, "crack": 0.0},
	"M_backdrop":     {"albedo": Color(0.72, 0.60, 0.47), "rough": 0.96, "metallic": 0.0, "specular": 0.35, "normal_scale": 0.85, "rim": 0.15, "moss": 0.0, "crack": 0.0, "wear": 0.15},
	"M_backdrop_dark": {"albedo": Color(0.16, 0.12, 0.10), "rough": 1.0, "metallic": 0.0, "specular": 0.25, "rim": 0.0, "moss": 0.0, "crack": 0.0},
	# gilding: gold trim. Faint thaw-gated
	# glow so it reads warm at dusk; in rime the gate kills it and the
	# cold grade tarnishes the albedo.
	"M_gild":         {"albedo": Color(0.92, 0.68, 0.25), "rough": 0.28, "metallic": 0.92, "specular": 0.85, "normal_scale": 0.85, "rim": 1.15, "moss": 0.0, "crack": 0.0,
					   "emission": Color(1.0, 0.78, 0.32), "emission_energy": 0.3, "emission_gate": 1},
	# lit dwelling windows across the city — warm lamplight in thaw, dead dark
	# panes in rime (same gate the gold uses).
	"M_citywindow":   {"albedo": Color(0.14, 0.10, 0.08), "rough": 0.9, "metallic": 0.0, "specular": 0.5, "rim": 0.1, "moss": 0.0, "crack": 0.0,
					   "emission": Color(1.0, 0.66, 0.28), "emission_energy": 1.7, "emission_gate": 1},
	# the drowned flats: near-black wet peat with a low-rough sheen
	"M_marsh":        {"albedo": Color(0.10, 0.13, 0.11), "rough": 0.26, "metallic": 0.0, "specular": 0.65, "normal_scale": 1.10, "rim": 0.5, "moss": 1.0, "crack": 0.0},
	# the valley floor between the panorama's terraces: dark packed earth, so
	# exposed ground reads as ground — not as a bright hole in the map
	"M_terrain":      {"albedo": Color(0.15, 0.12, 0.09), "rough": 0.95, "metallic": 0.0, "specular": 0.35, "normal_scale": 1.15, "rim": 0.05, "moss": 0.45, "crack": 0.0},
	"M_steel":        {"albedo": Color(0.62, 0.65, 0.70), "rough": 0.30, "metallic": 0.90, "specular": 0.80, "normal_scale": 1.10, "rim": 1.0, "local_uv": 1, "moss": 0.0, "crack": 0.0, "wear": 0.3},
	"M_plate_dark":   {"albedo": Color(0.24, 0.26, 0.31), "rough": 0.34, "metallic": 0.88, "specular": 0.76, "normal_scale": 1.15, "rim": 0.95, "local_uv": 1, "moss": 0.0, "crack": 0.0, "wear": 0.32},
	"M_chainmail":    {"albedo": Color(0.38, 0.40, 0.45), "rough": 0.42, "metallic": 0.82, "specular": 0.68, "normal_scale": 1.35, "rim": 0.85, "local_uv": 1, "moss": 0.0, "crack": 0.0, "wear": 0.25},
	# the wood (Thornwold): bark, needles, leaves, laid thorn
	"M_bark_pine":    {"albedo": Color(0.30, 0.20, 0.14), "rough": 0.92, "metallic": 0.0, "specular": 0.35, "normal_scale": 1.3, "rim": 0.2, "moss": 0.35},
	"M_bark_birch":   {"albedo": Color(0.58, 0.56, 0.52), "rough": 0.88, "metallic": 0.0, "specular": 0.40, "normal_scale": 1.1, "rim": 0.3, "moss": 0.15, "crack": 0.6},
	"M_needles":      {"albedo": Color(0.12, 0.20, 0.12), "rough": 0.90, "metallic": 0.0, "specular": 0.30, "rim": 0.45, "sss": 0.3, "moss": 0.0, "crack": 0.0},
	"M_leaves":       {"albedo": Color(0.32, 0.40, 0.16), "rough": 0.85, "metallic": 0.0, "specular": 0.30, "rim": 0.5, "sss": 0.45, "moss": 0.0, "crack": 0.0},
	"M_thorn":        {"albedo": Color(0.24, 0.17, 0.11), "rough": 0.90, "metallic": 0.0, "specular": 0.35, "rim": 0.3, "moss": 0.25, "crack": 0.0},
	"M_foliage":      {"albedo": Color(0.2, 0.32, 0.16), "rough": 0.88, "metallic": 0.0, "specular": 0.40, "rim": 0.55, "sss": 0.35, "moss": 0.0, "crack": 0.0, "vc": 1},
	# polished pale stone: ivory marble, no moss (nothing decays
	# above the hours), light cracking only. Gold trim rides M_gild.
	"M_marble":       {"albedo": Color(0.88, 0.86, 0.79), "rough": 0.38, "metallic": 0.0, "specular": 0.62, "normal_scale": 0.90, "rim": 0.55, "moss": 0.0, "crack": 0.12, "wear": 0.18},
	"M_marble_floor": {"albedo": Color(0.78, 0.76, 0.70), "rough": 0.32, "metallic": 0.0, "specular": 0.66, "normal_scale": 0.85, "rim": 0.45, "moss": 0.0, "crack": 0.1, "wear": 0.15},
	# cloud banks: near-white, sun-kissed tops, strong rim so
	# the edges catch the gold — no weathering of any kind
	# frost-taken flesh and cloth: pale blue ice with a faint cold glow
	"M_rime":         {"albedo": Color(0.70, 0.82, 0.92), "rough": 0.30, "metallic": 0.0, "specular": 0.75, "rim": 1.4, "sss": 0.5, "moss": 0.0, "crack": 0.3, "wear": 0.0,
					   "emission": Color(0.35, 0.55, 0.85), "emission_energy": 0.12},
	"M_rime_cloth":   {"albedo": Color(0.30, 0.36, 0.44), "rough": 0.85, "metallic": 0.0, "specular": 0.40, "rim": 0.9, "sheen": 0.5, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	# the land's own stuff (terrain scatter and turf-roofed houses)
	# weathered, silvered timber for posts, plates and carving
	"M_wood_dark":    {"albedo": Color(0.27, 0.22, 0.17), "rough": 0.85, "metallic": 0.0, "specular": 0.40, "normal_scale": 1.20, "rim": 0.3, "moss": 0.25},
	# dry-stone footings: warm grey-brown fieldstone, lichened
	"M_drystone":     {"albedo": Color(0.42, 0.41, 0.36), "rough": 0.92, "metallic": 0.0, "specular": 0.40, "normal_scale": 1.3, "rim": 0.25, "moss": 0.6},
	"M_turf":         {"albedo": Color(0.27, 0.30, 0.16), "rough": 0.95, "metallic": 0.0, "specular": 0.30, "rim": 0.35, "moss": 0.6, "crack": 0.0, "wear": 0.0},
	"M_peat":         {"albedo": Color(0.19, 0.15, 0.11), "rough": 0.97, "metallic": 0.0, "specular": 0.28, "rim": 0.15, "moss": 0.2, "crack": 0.1},
	"M_drift":        {"albedo": Color(0.55, 0.52, 0.47), "rough": 0.90, "metallic": 0.0, "specular": 0.35, "rim": 0.4, "moss": 0.0, "crack": 0.35, "wear": 0.4},
	"M_ice":          {"albedo": Color(0.66, 0.80, 0.90), "rough": 0.12, "metallic": 0.0, "specular": 0.85, "rim": 1.3, "sss": 0.55, "moss": 0.0, "crack": 0.25, "wear": 0.0,
					   "emission": Color(0.30, 0.50, 0.75), "emission_energy": 0.08},
	# look-pass families (aliases of the above with a set each)
	"M_timber":       {"albedo": Color(0.40, 0.35, 0.29), "rough": 0.80, "metallic": 0.0, "specular": 0.42, "normal_scale": 1.20, "rim": 0.24, "moss": 0.3},
	"M_planks":       {"albedo": Color(0.36, 0.31, 0.26), "rough": 0.82, "metallic": 0.0, "specular": 0.42, "normal_scale": 1.20, "rim": 0.24, "moss": 0.3},
	"M_drystone_wall": {"albedo": Color(0.40, 0.40, 0.36), "rough": 0.92, "metallic": 0.0, "specular": 0.40, "normal_scale": 1.3, "rim": 0.25, "moss": 0.6},
	"M_schist":       {"albedo": Color(0.33, 0.34, 0.31), "rough": 0.88, "metallic": 0.0, "specular": 0.45, "normal_scale": 1.3, "rim": 0.25, "moss": 0.5},
	"M_shingle":      {"albedo": Color(0.47, 0.45, 0.41), "rough": 0.88, "metallic": 0.0, "specular": 0.40, "normal_scale": 1.2, "rim": 0.2, "moss": 0.0, "crack": 0.0},
	"M_snow":         {"albedo": Color(0.86, 0.89, 0.94), "rough": 0.6, "metallic": 0.0, "specular": 0.5, "normal_scale": 0.8, "rim": 0.6, "sss": 0.2, "moss": 0.0, "crack": 0.0, "wear": 0.0},
	"M_wool":         {"albedo": Color(0.52, 0.48, 0.41), "rough": 0.92, "metallic": 0.0, "specular": 0.30, "normal_scale": 1.0, "rim": 0.4, "sheen": 0.5, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	# living fleece on the Reach ewes: off-white undyed wool, a shade of cream in it
	"M_fleece":       {"albedo": Color(0.7, 0.66, 0.56), "rough": 0.94, "metallic": 0.0, "specular": 0.28, "normal_scale": 1.0, "rim": 0.45, "sheen": 0.6, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_felt":         {"albedo": Color(0.42, 0.40, 0.36), "rough": 0.95, "metallic": 0.0, "specular": 0.28, "normal_scale": 0.9, "rim": 0.4, "sheen": 0.4, "local_uv": 1, "moss": 0.0, "crack": 0.0},
	"M_rope":         {"albedo": Color(0.46, 0.39, 0.29), "rough": 0.9, "metallic": 0.0, "specular": 0.30, "normal_scale": 1.3, "rim": 0.3, "moss": 0.1, "crack": 0.0, "wear": 0.2},
	"M_cloud":        {"albedo": Color(0.96, 0.93, 0.87), "rough": 1.0, "metallic": 0.0, "specular": 0.25, "rim": 0.9, "sss": 0.45, "moss": 0.0, "crack": 0.0, "wear": 0.0},
}

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _sets: Dictionary = {}

## The photo set `name`: {albedo, normal, orh: Texture2D, mean: Vector3
## (linear), rough: float}. Empty when the set is not shipped.
static func tex_set(name: String) -> Dictionary:
	if _sets.is_empty():
		var f := FileAccess.open(TEX_DIR + "sets.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_sets = d
		if _sets.is_empty():
			_sets = {"_": {}}
	if not _sets.has(name):
		return {}
	var meta: Dictionary = _sets[name]
	var base := TEX_DIR + "%s/T_%s_" % [name, name]
	var alb := _load_tex(base + "albedo.jpg")
	if alb == null:
		return {}
	var m: Array = meta.get("mean_lin", [0.2, 0.2, 0.2])
	return {"albedo": alb, "normal": _load_tex(base + "normal.jpg"), "orh": _load_tex(base + "orh.jpg"),
		"mean": Vector3(m[0], m[1], m[2]), "rough": float(meta.get("rough_mean", 0.7))}

static func _load_tex(res_path: String) -> Texture2D:
	if _tex_cache.has(res_path):
		return _tex_cache[res_path]
	var tex: Texture2D = null
	if ResourceLoader.exists(res_path):
		tex = load(res_path)
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
	_tex_cache[res_path] = tex
	return tex

static var _hero_cache: Dictionary = {}

## A Tripo hero mesh's own baked PBR (albedo / normal / glTF metal-rough)
## shaded by the hall shader, so it takes the same THAW warmth, RIME snow
## crust on its top faces, wavefront frost and dissolve as everything else.
## `family` supplies the non-texture behaviour (rim, snow, specular).
## A family's authored mean colour (for things that must sit on it).
static func family_albedo(family: String) -> Color:
	return (FAMILIES.get(family, FAMILIES["M_stone"]) as Dictionary)["albedo"]

## `tint`: how far the baked mean is pulled to the family albedo (0 keeps it).
static func hero_mat(src: Material, family: String, state_mode := 0, tint := 0.55) -> Material:
	var std := src as BaseMaterial3D
	if std == null or std.albedo_texture == null:
		return get_mat(family, state_mode)
	var key := "%d|%s|%d|%.2f" % [src.get_instance_id(), family, state_mode, tint]
	if _hero_cache.has(key):
		return _hero_cache[key]
	var base := get_mat(family, state_mode) as ShaderMaterial
	var mat := base.duplicate() as ShaderMaterial
	mat.set_shader_parameter("detail_tex", std.albedo_texture)
	mat.set_shader_parameter("normal_tex", std.normal_texture if std.normal_enabled else null)
	# glTF metallicRoughness: G = roughness (what the shader reads), B = metal
	mat.set_shader_parameter("orm_tex", std.roughness_texture)
	mat.set_shader_parameter("tex_rough_mean", 0.75)
	mat.set_shader_parameter("tex_scale", 1.0)
	mat.set_shader_parameter("tex_strength", 1.0)
	# keep the baked colour, pulled a third of the way to the family mean so
	# a field of hero rocks sits in the same value range as the ground
	var mean := _tex_mean(std.albedo_texture)
	mat.set_shader_parameter("tex_mean", mean)
	mat.set_shader_parameter("tex_tint", tint if mean != Vector3.ZERO else 0.0)
	mat.set_shader_parameter("tex_contrast", 1.0)
	mat.set_shader_parameter("uv_mode", 1)
	mat.set_shader_parameter("board_tone", 0.0)
	mat.set_shader_parameter("normal_scale", 1.0)
	mat.set_shader_parameter("crack_strength", 0.0)  # B is metalness, not height
	mat.set_shader_parameter("moss_strength", 0.0)
	mat.set_shader_parameter("detail_strength", 0.0)
	_hero_cache[key] = mat
	return mat

## Linear mean of a texture (8x8 downsample), for re-tinting hero albedos.
static func _tex_mean(t: Texture2D) -> Vector3:
	var img := t.get_image()
	if img == null or img.is_empty():
		return Vector3.ZERO
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	var acc := Vector3.ZERO
	for y in 8:
		for x in 8:
			var c := img.get_pixel(x, y).srgb_to_linear()
			acc += Vector3(c.r, c.g, c.b)
	return acc / 64.0

## uv = true: sample the photo set through the mesh's UVs, in metres (ProcMesh
## output). Leave false for anything else (object-aligned triplanar).
static func get_mat(family: String, state_mode := 0, uv := false) -> Material:
	var key := "%s|%d|%d" % [family, state_mode, int(uv)]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	if family == "M_glass":
		mat.shader = GLASS
		mat.set_shader_parameter("state_mode", state_mode)
	elif family == "M_water":
		mat.shader = WATER
		mat.set_shader_parameter("state_mode", state_mode)
	elif family == "M_ice_sheet":
		mat.shader = ICE_SHEET
		mat.set_shader_parameter("state_mode", state_mode)
		var ice := tex_set("ice")
		var sn := tex_set("snow")
		if not ice.is_empty() and not sn.is_empty():
			mat.set_shader_parameter("ice_alb", ice["albedo"])
			mat.set_shader_parameter("ice_nrm", ice["normal"])
			mat.set_shader_parameter("ice_mean", ice["mean"])
			mat.set_shader_parameter("snow_alb", sn["albedo"])
			mat.set_shader_parameter("snow_mean", sn["mean"])
			mat.set_shader_parameter("photo", 1.0)
	elif family == "M_falls":
		mat.shader = FALLS
		mat.set_shader_parameter("state_mode", state_mode)
	elif family == "M_flame":
		mat.shader = FLAME
		mat.set_shader_parameter("state_mode", state_mode)
	elif family == "M_coals":
		# a hearth's bed: its own shader, lit in THAW and banked in RIME
		mat.shader = COALS
	else:
		mat.shader = HALL_DS if DOUBLE_SIDED.has(family) else HALL
		var f: Dictionary = FAMILIES.get(family, FAMILIES["M_stone"])
		mat.set_shader_parameter("albedo", f["albedo"])
		mat.set_shader_parameter("roughness_v", f.get("rough", 0.88))
		mat.set_shader_parameter("metallic_v", f.get("metallic", 0.0))
		mat.set_shader_parameter("specular_v", f.get("specular", 0.5))
		mat.set_shader_parameter("normal_scale", f.get("normal_scale", 1.15))
		mat.set_shader_parameter("rim_strength", f.get("rim", 0.35))
		mat.set_shader_parameter("sss_strength", f.get("sss", 0.0))
		mat.set_shader_parameter("sheen_strength", f.get("sheen", 0.0))
		mat.set_shader_parameter("use_local_triplanar", f.get("local_uv", 0))
		mat.set_shader_parameter("wear_strength", f.get("wear", 0.5))
		mat.set_shader_parameter("moss_strength", f.get("moss", 0.85))
		mat.set_shader_parameter("crack_strength", f.get("crack", 0.45))
		mat.set_shader_parameter("emission_color", f.get("emission", Color.BLACK))
		mat.set_shader_parameter("emission_energy", f.get("emission_energy", 0.0))
		mat.set_shader_parameter("emission_gate", f.get("emission_gate", 0))
		mat.set_shader_parameter("state_mode", state_mode)
		mat.set_shader_parameter("albedo_from_vc", f.get("vc", 0))
		mat.set_shader_parameter("snow_strength", SNOW.get(family, 0.0))
		if TEXTURES.has(family):
			var spec: Array = TEXTURES[family]
			var ts := tex_set(String(spec[0]))
			if not ts.is_empty():
				mat.set_shader_parameter("detail_tex", ts["albedo"])
				mat.set_shader_parameter("normal_tex", ts["normal"])
				mat.set_shader_parameter("orm_tex", ts["orh"])
				mat.set_shader_parameter("tex_mean", ts["mean"])
				mat.set_shader_parameter("tex_rough_mean", ts["rough"])
				mat.set_shader_parameter("tex_scale", float(spec[1]))
				mat.set_shader_parameter("tex_strength", float(spec[2]))
				mat.set_shader_parameter("tex_tint", float(spec[3]) if spec.size() > 3 else 1.0)
				mat.set_shader_parameter("tex_contrast", float(spec[4]) if spec.size() > 4 else 1.0)
				mat.set_shader_parameter("uv_mode", 1 if uv else 0)
				# the photo carries its own relief: the noise "detail" would
				# only fight it
				mat.set_shader_parameter("detail_strength", 0.12)
		if SNOW.has(family):
			var sn := tex_set("snow")
			if not sn.is_empty():
				mat.set_shader_parameter("snow_tex", sn["albedo"])
				mat.set_shader_parameter("snow_nrm", sn["normal"])
				mat.set_shader_parameter("snow_mean", sn["mean"])
	_cache[key] = mat
	return mat
