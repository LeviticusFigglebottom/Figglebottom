class_name EnemyVisual
extends CharVisual
## Skeletal visual for any enemy archetype per enemies.json. Body ids map
## to mannequin archetypes; weapon/shield/helm ride bones. Bosses scale up.


func build(cfg: Dictionary) -> void:
	var body_id: String = cfg.get("body", "mannequin_rime")
	var vis_scale := float(cfg.get("vis_scale", 1.55 if cfg.get("is_boss", false) else 1.0))
	build_body(body_id, float(cfg.get("anim_amp", 1.0)), float(cfg.get("anim_sway", 1.0)), vis_scale)
	stride = float(cfg.get("stride", 2.3))
	run_stride = stride * 2.0
	footsteps = cfg.get("is_boss", false)
	step_volume = -6.0

	if cfg.has("weapon"):
		mount_weapon_hand()
		weapon_kit = String(cfg["weapon"])
		var w := KitLib.instance(weapon_kit)
		weapon_mount.add_child(w)
		apply_carry_pose("idle")
		add_trail()   # armed foes cut visible arcs too
	if cfg.has("shield"):
		shield_mount = mount("farm_l")
		shield_mount.position = Vector3(-0.085, 0.18, 0.015)
		shield_mount.rotation_degrees = Vector3(0, 90, 0)
		shield_mount.add_child(KitLib.instance(cfg["shield"]))
	if cfg.has("helm") and not body_id.begins_with("mannequin_"):
		head_mount = mount("head")
		head_mount.position = Vector3(0, 0.14, 0.0)
		head_mount.add_child(KitLib.instance(cfg["helm"]))
