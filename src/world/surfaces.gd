class_name Surfaces
## What a blade meets: wood, stone, metal, ice, cloth, turf or snow. The
## table is data (data/surfaces.json). Whoever builds a collider stamps it
## (a `surface` meta) from what it already knows: the kit, the material
## family, the landmark file, the kind of thing. Nothing is tagged by hand.

const META := &"surface"
const NONE := "none"        # takes a blow in silence (a soul's body, water)
const GROUND := "ground"    # settled at the blow: turf, shingle, plank or snow

static func table() -> Dictionary:
	return DB.table("surfaces")

static func all() -> Array:
	return table().get("surfaces", [])

static func known(s: String) -> bool:
	return s in all()

static func fallback() -> String:
	return String(table().get("default", "stone"))

## One row of one section ("families", "kits", "landmarks", "scatter",
## "kinds"); "" when the table has no word for it.
static func lookup(section: String, key: String) -> String:
	return String((table().get(section, {}) as Dictionary).get(key, ""))

static func for_family(fam: String) -> String:
	return lookup("families", fam.get_slice(".", 0))

## A kit piece: its own override first, else the family of the mesh struck.
static func for_kit(kit: String, fam := "") -> String:
	var s := lookup("kits", kit)
	return s if s != "" else for_family(fam)

## A Tripo landmark by file ("res://…/lm_fold_cairn.glb"), else its family,
## else what landmarks are by default.
static func for_landmark(path: String, fam := "") -> String:
	var s := lookup("landmarks", path.get_file().get_basename())
	if s == "" and fam != "":
		s = for_family(fam)
	return s if s != "" else lookup("kinds", "landmark")

static func stamp(body: Object, surface: String) -> void:
	if body != null and surface != "":
		body.set_meta(META, surface)

static func stamp_kind(body: Object, kind: String) -> void:
	stamp(body, lookup("kinds", kind))

## The stamp as written (unsettled): "" when the collider carries none.
static func stamped(collider: Object) -> String:
	if collider == null or not collider.has_meta(META):
		return ""
	return String(collider.get_meta(META))

## The surface struck at `pos` on `collider`: one of all(), or NONE.
static func of(collider: Object, pos: Vector3) -> String:
	var s := stamped(collider)
	if s == "":
		s = fallback()
	if s == GROUND:
		# the land reads as the footsteps do: shingle, a boarded floor, snow
		s = String((table().get(GROUND, {}) as Dictionary).get(AudioDirector.surface_at(pos), "turf"))
	if known(s):
		return s
	return NONE if s == NONE else fallback()
