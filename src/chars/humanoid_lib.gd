class_name HumanoidLib
## The shared animation library for every Mixamo-rigged humanoid (ADR 0004).
## Rigs arrive retargeted on import (tools/art/humanoid_import.py): bone axes
## overwritten to SkeletonProfileHumanoid's standard frame, names kept as
## mixamorig_*. So a rotation key from one model means the same pose on any
## other, and one AnimationLibrary (the donor's real clips plus procedural
## overlays) drives them all. A model may shadow it with its own clips.
##
## Track paths are normalised to "Skeleton3D:<bone>" (an AnimationTree rooted
## at the skeleton's parent). Hips position keys are stored in hips-heights
## and replayed through Skeleton3D.motion_scale: Godot's own
## normalize_position_tracks keys on the profile bone name and is a no-op on
## an unrenamed rig, so it is done here.

const META_PATH := "res://data/anim/clip_meta.json"
const SKEL := "Skeleton3D"
const HIPS := "mixamorig_Hips"

static var _meta: Dictionary = {}
static var _shared: AnimationLibrary = null
static var _own: Dictionary = {}       # model id -> AnimationLibrary
static var _hips_h: Dictionary = {}    # model id -> hips rest height (m)

static func meta() -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.open(META_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_meta = parsed
		if _meta.is_empty():
			push_error("HumanoidLib: cannot read %s" % META_PATH)
	return _meta

static func model_cfg(id: String) -> Dictionary:
	return (meta().get("models", {}) as Dictionary).get(id, {})

static func has_model(id: String) -> bool:
	var c := model_cfg(id)
	return not c.is_empty() and ResourceLoader.exists(String(c.get("scene", "")))

## Names to try for a game clip, best first: the clip itself, then its
## aliases (atk_over -> heavy -> slash). A clip that turns up later under any
## of these names takes over with no code change.
## With a weapon-class clip set (clip_sets, e.g. "onehand"), that set's
## clips for the game name come before everything else, so the same
## "attack_l1" is a cut with a blade and a thrust with a spear.
static func candidates(clip: String, clip_set := "") -> Array:
	var out := []
	if clip_set != "":
		var sets: Dictionary = meta().get("clip_sets", {})
		# "_all" is the weapon classes' common set; a foe's set stands alone
		for sid in ([clip_set] if clip_set.begins_with("foe_") else [clip_set, "_all"]):
			var cs = (sets.get(sid, {}) as Dictionary).get(clip, [])
			for a in (cs if cs is Array else [cs]):
				if not String(a) in out:
					out.append(String(a))
	if not clip in out:
		out.append(clip)
	var al = (meta().get("aliases", {}) as Dictionary).get(clip, [])
	for a in (al if al is Array else [al]):
		if not String(a) in out:
			out.append(String(a))
	return out

## Section metadata for a resolved humanoid clip. Real clips read the
## top-level keys (start/contact/end, defaulting to the whole clip); the
## procedural fallback reads its own "procedural" block, so dropping in a
## real clip with its own timing never inherits the overlay's numbers.
static func clip_info(clip: String, procedural := false, model := "") -> Dictionary:
	var c: Dictionary = (meta().get("clips", {}) as Dictionary).get(clip, {})
	# a model's own take on a clip (its own section times) merges over the shared row
	var mine: Dictionary = (model_cfg(model).get("clips", {}) as Dictionary).get(clip, {}) if model != "" else {}
	if mine.is_empty() and model != "":   # a borrowed take keeps its lender's sections
		mine = (model_cfg(String(model_cfg(model).get("borrow", ""))).get("clips", {}) as Dictionary).get(clip, {})
	if not mine.is_empty() and not procedural:
		c = c.duplicate()
		c.merge(mine, true)
	if procedural:
		var p: Dictionary = c.get("procedural", {})
		var merged := p.duplicate()
		if c.has("loop"):
			merged["loop"] = c["loop"]
		return merged
	var real := c.duplicate()
	real.erase("procedural")
	return real

static func is_procedural(a: Animation) -> bool:
	return a != null and a.has_meta("procedural")

## Mannequin contact fraction (its clips are authored 1 s long).
static func mannequin_contact(clip: String) -> float:
	var t: Dictionary = meta().get("mannequin_contact", {})
	return float(t.get(clip, t.get("_default", 0.56)))

static func bone(name: String) -> String:
	return String((meta().get("bone_alias", {}) as Dictionary).get(name, name))

static func mount_cfg(slot: String) -> Dictionary:
	return (meta().get("mounts", {}) as Dictionary).get(slot, {})

## The clip set a weapon kit fights with ("" = the plain aliases).
static func weapon_class(kit: String) -> String:
	return String((meta().get("weapon_class", {}) as Dictionary).get(kit, ""))

## A weapon class's own grip (mounts.<slot>@<class>), else the slot's.
static func class_mount_cfg(slot: String, clip_set: String) -> Dictionary:
	var m: Dictionary = meta().get("mounts", {})
	return m.get("%s@%s" % [slot, clip_set], m.get(slot, {}))

static func weapon_cfg(kit: String) -> Dictionary:
	return (meta().get("weapons", {}) as Dictionary).get(kit, {})

static func weapon_instance(kit: String) -> Node3D:
	var cfg := weapon_cfg(kit)
	var path := String(cfg.get("scene", ""))
	if path != "" and ResourceLoader.exists(path):
		var n := (load(path) as PackedScene).instantiate() as Node3D
		# this weapon's own seat in the fist (weapons.<kit>.seat): slid along
		# the haft and turned about it, inside the class grip
		var seat: Dictionary = cfg.get("seat", {})
		var sp: Array = seat.get("pos", [0, 0, 0])
		var sr: Array = seat.get("rot", [0, 0, 0])
		n.position = Vector3(sp[0], sp[1], sp[2])
		n.rotation_degrees = Vector3(sr[0], sr[1], sr[2])
		return n
	return null

static func prop_cfg(id: String) -> Dictionary:
	return (meta().get("props", {}) as Dictionary).get(id, {})

## A held item's Tripo mesh (props map), or null when it has none.
static func prop_instance(id: String) -> Node3D:
	var path := String(prop_cfg(id).get("scene", ""))
	if path != "" and ResourceLoader.exists(path):
		return (load(path) as PackedScene).instantiate() as Node3D
	return null

static func instance_model(id: String) -> Node3D:
	return (load(String(model_cfg(id)["scene"])) as PackedScene).instantiate() as Node3D

static func hips_height(id: String) -> float:
	if not _hips_h.has(id):
		(_extract(id)["inst"] as Node).free()
	return float(_hips_h.get(id, 1.0))

## One library for every humanoid: the donor's real clips + overlays on its idle.
static func shared_library() -> AnimationLibrary:
	if _shared == null:
		var donor := String(meta().get("donor", "rimewalker"))
		_shared = _build(donor)
		# clip-only libraries (the combat library, tools/anim): real clips on
		# the same standard frame, under their own names, for every humanoid
		for id in meta().get("libraries", []):
			if not has_model(String(id)):
				continue
			var src := _extract(String(id))
			for n in src["anims"]:
				if not _shared.has_animation(n) or is_procedural(_shared.get_animation(n)):
					if _shared.has_animation(n):
						_shared.remove_animation(n)
					_shared.add_animation(n, src["anims"][n])
			(src["inst"] as Node).free()
	return _shared

## A model's own clips (and overlays riding its own idle), or null if it
## leans wholly on the shared library.
static func own_library(id: String) -> AnimationLibrary:
	if not bool(model_cfg(id).get("own_clips", false)):
		return null
	if not _own.has(id):
		_own[id] = _build(id)
	return _own[id]

static func clear_cache() -> void:
	_shared = null
	_own.clear()
	_hips_h.clear()
	_meta.clear()

static func _build(id: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var src := _extract(id)
	var anims: Dictionary = src["anims"]
	for n in anims:
		lib.add_animation(n, anims[n])
	# another model's sectioned takes, played as this one's own (clip_meta
	# models.<id>.borrow): an outfit of the Bearer drinks and kneels as he does
	var lender := String(model_cfg(id).get("borrow", ""))
	if lender != "" and lender != id and has_model(lender):
		var lent := _extract(lender)
		for n in (model_cfg(lender).get("clips", {}) as Dictionary):
			if (lent["anims"] as Dictionary).has(n) and not lib.has_animation(n):
				lib.add_animation(n, lent["anims"][n])
		(lent["inst"] as Node).free()
	if anims.has("idle") and src["skel"] != null:
		var over := HumanoidOverlays.build(src["skel"], anims["idle"])
		for n in over:
			if not lib.has_animation(n):
				lib.add_animation(n, over[n])
	(src["inst"] as Node).free()
	return lib

## Instantiate a model, copy its clips with normalised paths and hips keys.
## Returns {anims, skel, inst}; the caller frees inst.
static func _extract(id: String) -> Dictionary:
	var inst := instance_model(id)
	var skel := inst.find_child(SKEL, true, false) as Skeleton3D
	var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hips := skel.find_bone(HIPS)
	var hh := maxf(skel.get_bone_global_rest(hips).origin.y, 0.01) if hips >= 0 else 1.0
	_hips_h[id] = hh
	var clips: Dictionary = meta().get("clips", {})
	var own_rows: Dictionary = model_cfg(id).get("clips", {})
	# weak real clips a model keeps procedural (a real clip always outranks the
	# overlay, so the only way to prefer the overlay is not to load the clip)
	var skip: Array = model_cfg(id).get("skip_clips", [])
	var out := {}
	if ap != null:
		for n in ap.get_animation_list():
			if String(n) in skip:
				continue
			var a := (ap.get_animation(n) as Animation).duplicate(true) as Animation
			for t in range(a.get_track_count() - 1, -1, -1):
				var p := a.track_get_path(t)
				var bn := String(p.get_concatenated_subnames())
				var ty := a.track_get_type(t)
				if ty == Animation.TYPE_SCALE_3D or (ty == Animation.TYPE_POSITION_3D and bn != HIPS):
					a.remove_track(t)   # rest offsets carry proportions; never borrow them
					continue
				a.track_set_path(t, NodePath(SKEL + ":" + bn))
				if ty == Animation.TYPE_POSITION_3D:
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) / hh)
			var info: Dictionary = (clips.get(n, {}) as Dictionary).duplicate()
			info.merge(own_rows.get(n, {}), true)
			a.loop_mode = Animation.LOOP_LINEAR if info.get("loop", false) else Animation.LOOP_NONE
			if info.get("root_lock", false):
				_lock_root(a)
			out[n] = a
	return {"anims": out, "skel": skel, "inst": inst}

## Text-prompt clips travel (a forward roll moves the hips a metre): gameplay
## moves the capsule, so the hips stay over the feet on the ground plane
## and keep only the vertical (the roll still drops to the floor and rises).
static func _lock_root(a: Animation) -> void:
	var t := a.find_track(NodePath(SKEL + ":" + HIPS), Animation.TYPE_POSITION_3D)
	if t < 0 or a.track_get_key_count(t) == 0:
		return
	for k in a.track_get_key_count(t):
		var v: Vector3 = a.track_get_key_value(t, k)
		a.track_set_key_value(t, k, Vector3(0.0, v.y, 0.0))
