class_name EnemyVisual
extends CharVisual
## Skeletal visual for any enemy archetype per enemies.json. A "model" key
## selects a Mixamo-rigged humanoid (HumanoidLib); without one (or if the
## model is missing) the body id maps to a mannequin archetype. Weapon,
## shield and helm ride bones. Mannequin bosses scale up.


func build(cfg: Dictionary) -> void:
	var model := String(cfg.get("model", ""))
	var four := model != "" and build_quadruped(model)
	var humanoid := not four and model != "" and build_model(model)
	var body_id: String = cfg.get("body", "mannequin_rime")
	if not humanoid and not four:
		var vis_scale := float(cfg.get("vis_scale", 1.55 if cfg.get("is_boss", false) else 1.0))
		build_body(body_id, float(cfg.get("anim_amp", 1.0)), float(cfg.get("anim_sway", 1.0)), vis_scale)
	stride = float(cfg.get("stride", 2.3))
	run_stride = stride * 2.0
	footsteps = cfg.get("is_boss", false)
	step_volume = -6.0

	var armed: bool = cfg.has("weapon") and not (humanoid
			and bool(HumanoidLib.model_cfg(model).get("bare_hands", false)))
	if armed:
		mount_weapon_hand()
		set_weapon(String(cfg["weapon"]))
		add_trail()   # armed foes cut visible arcs too
	if cfg.has("shield"):
		if humanoid:
			shield_mount = mount_slot("shield")
		else:
			shield_mount = mount("farm_l")
			shield_mount.position = Vector3(-0.085, 0.18, 0.015)
			shield_mount.rotation_degrees = Vector3(0, 90, 0)
		shield_mount.add_child(KitLib.instance(cfg["shield"]))
	if cfg.has("helm") and not humanoid and not body_id.begins_with("mannequin_"):
		head_mount = mount("head")
		head_mount.position = Vector3(0, 0.14, 0.0)
		head_mount.add_child(KitLib.instance(cfg["helm"]))
