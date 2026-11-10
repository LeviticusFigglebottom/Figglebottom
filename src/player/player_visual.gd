class_name PlayerVisual
extends CharVisual
## The Bearer's skeletal rig: weapon in the right hand, shield strapped to the
## left forearm, swing trail. game.json player.model names the humanoid (the
## Tripo Bearer, with the hewing blade and the Saltfell board shield); without
## it the greybox mannequin and kite shield stand in (ADR 0004).

func build(weapon_kit := "hewing_blade", model := "") -> void:
	if model == "" or not build_model(model):
		build_body("mannequin_wayfarer")
	stride = 2.7
	run_stride = 5.4
	footsteps = true

	mount_weapon_hand()
	set_weapon(weapon_kit)
	add_trail()

	var board: Node3D = null
	if is_humanoid():
		shield_mount = mount_slot("shield")
		board = HumanoidLib.weapon_instance("saltfell_shield")   # the Saltfell board shield
	else:
		shield_mount = mount("farm_l")
		shield_mount.position = Vector3(-0.085, 0.18, 0.015)
		shield_mount.rotation_degrees = Vector3(0, 90, 0)   # face out from the forearm
	shield_mount.add_child(board if board != null else KitLib.instance("shield_kite"))

## The gourd in hand while drinking: its Tripo mesh on the humanoid's gourd
## slot, the greybox vessel on the mannequin. Returns the mount (the caller
## frees its BoneAttachment3D parent when the drink ends).
func mount_gourd() -> Node3D:
	if is_humanoid():
		var g := HumanoidLib.prop_instance("gourd")
		if g != null:
			var m := mount_slot(String(HumanoidLib.prop_cfg("gourd").get("slot", "gourd")))
			m.add_child(g)
			if weapon_mount != null and m.get_parent().get("bone_name") == (weapon_mount.get_parent() as BoneAttachment3D).bone_name:
				weapon_mount.visible = false   # one hand, one thing in it
			return m
	var mm := mount("hand_l")
	mm.position = Vector3(0.0, 0.05, -0.02)
	if KitLib.has_piece("gourd"):
		var vessel := KitLib.instance("gourd")
		vessel.position = Vector3(0.0, -0.03, 0.0)
		mm.add_child(vessel)
	return mm

## Swap the drawn arms: right-hand weapon kit, and the kite shield only rides
## the forearm while a one-handed blade leaves that arm free for it. The bow
## is the exception: it lives in the LEFT hand (the right pulls the string),
## standing upright across the grip.
var bow_mount: Node3D = null

func apply_loadout(weapon_kit: String, with_shield: bool) -> void:
	var ranged := weapon_kit == "bow"
	set_weapon("" if ranged else weapon_kit)
	if ranged and rig != null and bool(HumanoidLib.model_cfg(model_id).get("clip_sets", false)):
		rig.clip_set = HumanoidLib.weapon_class(weapon_kit)   # the bow rides the left hand, not the weapon mount
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

## The drink is over: free the gourd's attachment, the blade comes back out.
func unmount_gourd(m: Node3D) -> void:
	if weapon_mount != null:
		weapon_mount.visible = true
	var att := m.get_parent() if m != null and is_instance_valid(m) else null
	if att != null and is_instance_valid(att):
		att.queue_free()
