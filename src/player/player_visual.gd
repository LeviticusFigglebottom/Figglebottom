class_name PlayerVisual
extends CharVisual
## The Bearer's skeletal rig: weapon in the right hand, kite shield strapped
## to the left forearm, swing trail. The body is the greybox mannequin until
## game.json player.model names a humanoid (HumanoidLib, ADR 0004).

func build(weapon_kit := "hewing_blade", model := "") -> void:
	if model == "" or not build_model(model):
		build_body("mannequin_wayfarer")
	stride = 2.7
	run_stride = 5.4
	footsteps = true

	mount_weapon_hand()
	set_weapon(weapon_kit)
	add_trail()

	if is_humanoid():
		shield_mount = mount_slot("shield")
	else:
		shield_mount = mount("farm_l")
		shield_mount.position = Vector3(-0.085, 0.18, 0.015)
		shield_mount.rotation_degrees = Vector3(0, 90, 0)   # face out from the forearm
	shield_mount.add_child(KitLib.instance("shield_kite"))

## Swap the drawn arms: right-hand weapon kit, and the kite shield only rides
## the forearm while a one-handed blade leaves that arm free for it. The bow
## is the exception: it lives in the LEFT hand (the right pulls the string),
## standing upright across the grip.
var bow_mount: Node3D = null

func apply_loadout(weapon_kit: String, with_shield: bool) -> void:
	var ranged := weapon_kit == "bow"
	set_weapon("" if ranged else weapon_kit)
	if bow_mount == null and ranged:
		bow_mount = mount("hand_l")
		bow_mount.position = Vector3(0, 0.06, 0)
	if bow_mount != null:
		for c in bow_mount.get_children():
			c.queue_free()
		if ranged:
			bow_mount.add_child(KitLib.instance(weapon_kit))
			bow_mount.rotation_degrees = Vector3(90, 0, 0)
	if shield_mount != null:
		shield_mount.visible = with_shield
