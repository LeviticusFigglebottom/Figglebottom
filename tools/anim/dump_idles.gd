extends SceneTree
## Writes tools/anim/foe_idles.json: every humanoid model's idle stance as the
## game shows it (first frame of its own idle, after Godot's retarget import):
## per bone, the skeleton-space rotation that takes its rest to its pose, and
## the hips height as a fraction of rest. build_combat_lib.py keys each foe's
## clips on this stance. Run: godot --headless --path . -s tools/anim/dump_idles.gd

func _init() -> void:
	var out := {}
	var models: Dictionary = HumanoidLib.meta().get("models", {})
	for id in models:
		var cfg: Dictionary = models[id]
		if String(cfg.get("rig", "")) == "quadruped" or not ResourceLoader.exists(String(cfg.get("scene", ""))):
			continue
		var inst := (load(String(cfg["scene"])) as PackedScene).instantiate() as Node3D
		root.add_child(inst)
		var sk := inst.find_child("Skeleton3D", true, false) as Skeleton3D
		var ap := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if sk == null or ap == null or not ap.has_animation("idle"):
			inst.free()
			continue
		ap.play("idle")
		ap.seek(0.0, true)
		ap.advance(0.0)
		var bones := {}
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i)
			if not bn.begins_with("mixamorig_"):
				continue
			var d := (sk.get_bone_global_pose(i).basis.orthonormalized() * sk.get_bone_global_rest(i).basis.orthonormalized().inverse()).get_rotation_quaternion()
			bones[bn.trim_prefix("mixamorig_")] = [snappedf(d.w, 0.0001), snappedf(d.x, 0.0001), snappedf(d.y, 0.0001), snappedf(d.z, 0.0001)]
		var hi := sk.find_bone("mixamorig_Hips")
		var hr := sk.get_bone_global_rest(hi).origin.y
		out[id] = {"hips": snappedf(sk.get_bone_global_pose(hi).origin.y / maxf(hr, 0.001), 0.0001), "bones": bones}
		inst.free()
	var f := FileAccess.open("res://tools/anim/foe_idles.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " ") + "\n")
	f.close()
	print("wrote foe_idles.json: ", out.size(), " models")
	quit()
