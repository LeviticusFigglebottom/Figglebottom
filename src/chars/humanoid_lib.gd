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
static func candidates(clip: String) -> Array:
	var out := [clip]
	var al = (meta().get("aliases", {}) as Dictionary).get(clip, [])
	for a in (al if al is Array else [al]):
		if not String(a) in out:
			out.append(String(a))
	return out

## Section metadata for a resolved humanoid clip. Real clips read the
## top-level keys (start/contact/end, defaulting to the whole clip); the
## procedural fallback reads its own "procedural" block, so dropping in a
## real clip with its own timing never inherits the overlay's numbers.
static func clip_info(clip: String, procedural := false) -> Dictionary:
	var c: Dictionary = (meta().get("clips", {}) as Dictionary).get(clip, {})
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

static func weapon_cfg(kit: String) -> Dictionary:
	return (meta().get("weapons", {}) as Dictionary).get(kit, {})

static func weapon_instance(kit: String) -> Node3D:
	var path := String(weapon_cfg(kit).get("scene", ""))
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
	var out := {}
	if ap != null:
		for n in ap.get_animation_list():
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
			var info: Dictionary = clips.get(n, {})
			a.loop_mode = Animation.LOOP_LINEAR if info.get("loop", false) else Animation.LOOP_NONE
			out[n] = a
	return {"anims": out, "skel": skel, "inst": inst}
