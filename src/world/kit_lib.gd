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
	"sheep": {"size": [0.6, 1.3, 1.0], "origin": "bottom-center"},
	"hearth_fire": {"size": [1.4, 1.4, 0.9], "origin": "bottom-center"},
	"hearth_logs": {"size": [1.4, 1.4, 0.4], "origin": "bottom-center"},
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
	# the Long Table's places (look pass 5): a horn beaker, the same frozen
	# over, a bread board, and a soapstone fat lamp lit or cold
	"feast_horn": {"size": [0.1, 0.1, 0.3], "origin": "bottom-center"},
	"feast_horn_frozen": {"size": [0.1, 0.1, 0.34], "origin": "bottom-center"},
	"trencher": {"size": [0.46, 0.34, 0.12], "origin": "bottom-center"},
	"fat_lamp": {"size": [0.25, 0.18, 0.1], "origin": "bottom-center"},
	"fat_lamp_cold": {"size": [0.25, 0.18, 0.1], "origin": "bottom-center"},
	"well": {"size": [1.4, 1.4, 1.0], "origin": "bottom-center"},
	# --- Kettle Fjord's own set (docs/art/BIOMES.md 3; tools/art/procedural/poi_props_b.py and Tripo)
	"kf_ice_hut": {"size": [2.4, 1.7, 2.3], "origin": "bottom-center"},
	"kf_tool_rack": {"size": [1.8, 0.5, 1.7], "origin": "bottom-center"},
	"kf_dog_picket": {"size": [3.4, 1.0, 2.1], "origin": "bottom-center"},
	"kf_windbreak": {"size": [2.2, 1.2, 1.7], "origin": "bottom-center"},
	"kf_jig_frame": {"size": [0.9, 0.2, 0.8], "origin": "bottom-center"},
	"kf_fish_cord": {"size": [1.8, 0.6, 0.95], "origin": "bottom-center"},
	"kf_ice_blocks": {"size": [2.0, 1.0, 0.9], "origin": "bottom-center"},
	"kf_bough_markers": {"size": [0.7, 0.7, 1.1], "origin": "bottom-center"},
	"kf_net_hurdle": {"size": [0.95, 0.12, 2.4], "origin": "bottom-center"},
	"kf_door_band": {"size": [0.1, 0.04, 0.36], "origin": "bottom-center"},
	"kf_ice_hut_b": {"size": [1.5, 2.6, 1.7], "origin": "bottom-center"},
	"kf_kettle_tripod": {"size": [1.75, 1.45, 1.8], "origin": "bottom-center"},
	# --- Tarnhall's own set
	"th_spit": {"size": [3.0, 1.1, 1.5], "origin": "bottom-center"},
	"th_ale_vat": {"size": [2.0, 1.7, 1.35], "origin": "bottom-center"},
	"th_bake_oven": {"size": [2.2, 2.3, 1.9], "origin": "bottom-center"},
	"th_carving_frame": {"size": [2.2, 1.1, 2.2], "origin": "bottom-center"},
	"th_ale_tub": {"size": [1.2, 1.0, 0.75], "origin": "bottom-center"},
	"th_hanging": {"size": [1.5, 0.1, 1.9], "origin": "bottom-center"},
	"th_horn_rack": {"size": [2.5, 0.35, 2.1], "origin": "bottom-center"},
	"th_trestles": {"size": [2.9, 1.5, 0.85], "origin": "bottom-center"},
	"th_oar_stand": {"size": [2.0, 1.1, 2.9], "origin": "bottom-center"},
	"th_rush_bundles": {"size": [1.3, 1.2, 0.7], "origin": "bottom-center"},
	"th_horn_window": {"size": [1.06, 0.1, 0.68], "origin": "bottom-center"},
	"th_pail": {"size": [0.37, 0.37, 0.34], "origin": "bottom-center"},
	"th_boat_oars": {"size": [1.0, 2.8, 0.15], "origin": "bottom-center"},
	# --- the Coldwell's own set
	"cw_thread_post": {"size": [0.9, 0.9, 2.4], "origin": "bottom-center"},
	"cw_flower_basket": {"size": [0.6, 0.46, 0.4], "origin": "bottom-center"},
	"cw_dipper_trough": {"size": [1.9, 1.1, 1.3], "origin": "bottom-center"},
	"cw_offering_cairn": {"size": [1.2, 1.2, 0.9], "origin": "bottom-center"},
	"cw_water_yoke": {"size": [1.5, 0.6, 0.8], "origin": "bottom-center"},
	"cw_shelter": {"size": [6.5, 3.6, 2.7], "origin": "bottom-center"},
	"cw_staff_rack": {"size": [2.2, 0.5, 1.45], "origin": "bottom-center"},
	"cw_staff_rack_full": {"size": [2.2, 0.5, 1.45], "origin": "bottom-center"},
	"cw_staff_heap": {"size": [1.3, 1.5, 1.4], "origin": "bottom-center"},
	"cw_rope_rail": {"size": [3.1, 0.12, 1.05], "origin": "bottom-center"},
	"cw_slab_bench": {"size": [1.9, 0.5, 0.5], "origin": "bottom-center"},
	"cw_slab_bench_snow": {"size": [1.9, 0.5, 0.6], "origin": "bottom-center"},
	"cw_ice_column_a": {"size": [1.2, 0.8, 2.2], "origin": "bottom-center"},
	"cw_ice_column_b": {"size": [1.8, 0.9, 3.6], "origin": "bottom-center"},
	"cw_ice_column_c": {"size": [2.4, 1.0, 5.2], "origin": "bottom-center"},
	"cw_flower_bunch": {"size": [0.16, 0.16, 0.32], "origin": "bottom-center"},
	# --- Thornwold's own prop set (BIOMES.md; tools/art/procedural/thornwold_props.py,
	# and two Tripo pieces: the shaving horse and the riddle stand)
	"tw_clamp_a": {"size": [3.7, 3.7, 2.3], "origin": "bottom-center"},
	"tw_clamp_b": {"size": [3.8, 3.6, 2.1], "origin": "bottom-center"},
	"tw_clamp_c": {"size": [4.5, 4.5, 1.0], "origin": "bottom-center"},
	"tw_cordwood": {"size": [2.45, 1.15, 1.45], "origin": "bottom-center"},
	"tw_hurdle": {"size": [1.87, 0.1, 1.54], "origin": "bottom-center"},
	"tw_stake_bundle": {"size": [1.63, 0.48, 0.46], "origin": "bottom-center"},
	"tw_stile": {"size": [2.67, 1.35, 1.59], "origin": "bottom-center"},
	"tw_charcoal_sacks": {"size": [1.94, 1.45, 1.0], "origin": "bottom-center"},
	"tw_gatepost": {"size": [0.59, 0.51, 1.64], "origin": "bottom-center"},
	"tw_collier_hut": {"size": [4.2, 4.0, 3.35], "origin": "bottom-center"},
	"tw_hut_yard": {"size": [0.8, 0.8, 0.45], "origin": "bottom-center"},
	"tw_hut_thaw": {"size": [2.0, 1.7, 1.0], "origin": "bottom-center"},
	"tw_hut_rime": {"size": [2.1, 2.9, 1.3], "origin": "bottom-center"},
	"tw_shaving_horse": {"size": [0.57, 1.39, 0.95], "origin": "bottom-center"},
	"tw_riddle_stand": {"size": [1.65, 1.2, 1.5], "origin": "bottom-center"},
	"tw_sledge": {"size": [0.75, 1.93, 0.85], "origin": "bottom-center"},
	"tw_hedging_tools": {"size": [1.09, 0.92, 0.95], "origin": "bottom-center"},
	"tw_wood_shelter": {"size": [2.09, 2.89, 2.3], "origin": "bottom-center"},
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
## Pieces with a Tripo hero variant (docs/art/LOOK_PASS.md): the GLB is
## placed in the primitive's footprint and shaded through MaterialLib.hero_mat
## (state branch, snow crust, dissolve). Same id, same size, same origin, so
## every generator that places the piece gets the variant; a missing file
## falls back to the primitives.
##   glb, family, length (m along local Z), yaw (deg), lift (m), flip (keel up)
const HERO_PIECES := {
	"boat": {"glb": "res://assets/models/landmarks/lm_brede_boat.glb", "family": "M_wood", "length": 6.0, "yaw": 90.0, "lift": 0.0},
	"drying_rack": {"glb": "res://assets/models/kit/kit_drying_rack_hero.glb", "family": "M_wood", "length": 4.0, "yaw": 90.0, "lift": 0.0},
	"boat_upturned": {"glb": "res://assets/models/landmarks/lm_brede_boat.glb", "family": "M_wood", "length": 5.8, "yaw": 90.0, "lift": 1.32, "flip": true},
	# every rest site: the carved hearthstone, its slab at the back (-z)
	"hearthstone": {"glb": "res://assets/models/kit/kit_hearthstone.glb", "family": "M_stone", "length": 1.6, "yaw": 0.0, "lift": 0.0},
	"fish_kettle": {"glb": "res://assets/models/landmarks/lm_fish_kettle.glb", "family": "M_iron", "length": 1.75, "yaw": 0.0, "lift": 0.0},
	# longhouse and yard furniture (look pass 3)
	"table_3m": {"glb": "res://assets/models/kit/kit_table_hero.glb", "family": "M_wood", "length": 3.0, "yaw": 0.0, "lift": 0.0},
	"bench_3m": {"glb": "res://assets/models/kit/kit_bench_hero.glb", "family": "M_wood", "length": 2.7, "yaw": 0.0, "lift": 0.0},
	"barrel": {"glb": "res://assets/models/kit/kit_barrel_hero.glb", "family": "M_wood", "length": 0.74, "yaw": 0.0, "lift": 0.0},
	"rope_coil": {"glb": "res://assets/models/kit/kit_rope_coil_hero.glb", "family": "M_rope", "length": 0.7, "yaw": 0.0, "lift": 0.0},
	"creel_stack": {"glb": "res://assets/models/kit/kit_creel_stack_hero.glb", "family": "M_drift", "length": 1.4, "yaw": 0.0, "lift": 0.0},
	"well": {"glb": "res://assets/models/kit/kit_well_hero.glb", "family": "M_stone", "length": 1.7, "yaw": 0.0, "lift": 0.0},
	# a wrought fire basket on three legs; the flame is added over its logs
	"brazier": {"glb": "res://assets/models/kit/kit_brazier_hero.glb", "family": "M_iron", "length": 0.71, "yaw": 0.0, "lift": 0.0},
	# modelled in Blender (look pass 5, tools/art/procedural/kit_props.py):
	# authored at the footprint, so no "length"; "tint" 0 keeps their atlas
	# colours (several materials share one texture)
	"woodpile": {"glb": "res://assets/models/kit/kit_woodpile_p.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"hearth_logs": {"glb": "res://assets/models/kit/kit_hearth_logs_p.glb", "family": "M_wood_dark", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"hearth_fire": {"glb": "res://assets/models/kit/kit_hearth_logs_p.glb", "family": "M_wood_dark", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"salt_pan": {"glb": "res://assets/models/kit/kit_salt_pan_p.glb", "family": "M_stone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"net_frame": {"glb": "res://assets/models/kit/kit_net_frame_p.glb", "family": "M_rope", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"plaque": {"glb": "res://assets/models/kit/kit_plaque_p.glb", "family": "M_wood", "yaw": 180.0, "lift": 0.0, "tint": 0.0},
	"door_leaf": {"glb": "res://assets/models/kit/kit_door_leaf_p.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"rime_spike": {"glb": "res://assets/models/kit/kit_rime_spike_p.glb", "family": "M_veil_rime", "yaw": 0.0, "lift": 0.0, "tint": 0.3},
	"feast_horn": {"glb": "res://assets/models/kit/kit_feast_horn_p.glb", "family": "M_bone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"feast_horn_frozen": {"glb": "res://assets/models/kit/kit_feast_horn_frozen_p.glb", "family": "M_bone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"trencher": {"glb": "res://assets/models/kit/kit_trencher_p.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"fat_lamp": {"glb": "res://assets/models/kit/kit_fat_lamp_p.glb", "family": "M_stone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"fat_lamp_cold": {"glb": "res://assets/models/kit/kit_fat_lamp_p.glb", "family": "M_stone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	# --- Kettle Fjord's own set: four from Tripo, the rest modelled (poi_props_b.py)
	"kf_ice_hut": {"glb": "res://assets/models/kit/kf_ice_hut.glb", "family": "M_wood", "length": 2.4, "yaw": 0.0, "lift": 0.0},
	"kf_tool_rack": {"glb": "res://assets/models/kit/kf_tool_rack.glb", "family": "M_drift", "length": 1.8, "yaw": 0.0, "lift": 0.0},
	"kf_dog_picket": {"glb": "res://assets/models/kit/kf_dog_picket.glb", "family": "M_rope", "length": 3.4, "yaw": 0.0, "lift": 0.0},
	"kf_windbreak": {"glb": "res://assets/models/kit/kf_windbreak.glb", "family": "M_leather", "length": 2.2, "yaw": 0.0, "lift": 0.0},
	"kf_jig_frame": {"glb": "res://assets/models/kit/kf_jig_frame.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"kf_fish_cord": {"glb": "res://assets/models/kit/kf_fish_cord.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"kf_ice_blocks": {"glb": "res://assets/models/kit/kf_ice_blocks.glb", "family": "M_ice", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"kf_bough_markers": {"glb": "res://assets/models/kit/kf_bough_markers.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"kf_net_hurdle": {"glb": "res://assets/models/kit/kf_net_hurdle.glb", "family": "M_rope", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"kf_door_band": {"glb": "res://assets/models/kit/kf_door_band.glb", "family": "M_wool", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"kf_ice_hut_b": {"glb": "res://assets/models/kit/kf_ice_hut_b.glb", "family": "M_leather", "length": 2.6, "yaw": 0.0, "lift": 0.0},
	"kf_kettle_tripod": {"glb": "res://assets/models/kit/kf_kettle_tripod.glb", "family": "M_iron", "length": 1.75, "yaw": 0.0, "lift": 0.0},
	# --- Tarnhall's own set: Tripo, then the modelled pieces
	"th_spit": {"glb": "res://assets/models/kit/th_spit.glb", "family": "M_iron", "length": 3.0, "yaw": 0.0, "lift": 0.0},
	"th_ale_vat": {"glb": "res://assets/models/kit/th_ale_vat.glb", "family": "M_wood", "length": 2.1, "yaw": 0.0, "lift": 0.0},
	"th_bake_oven": {"glb": "res://assets/models/kit/th_bake_oven.glb", "family": "M_stone", "length": 2.3, "yaw": 0.0, "lift": 0.0},
	"th_carving_frame": {"glb": "res://assets/models/kit/th_carving_frame.glb", "family": "M_wood", "length": 2.2, "yaw": 0.0, "lift": 0.0},
	"th_ale_tub": {"glb": "res://assets/models/kit/th_ale_tub.glb", "family": "M_wood", "length": 1.1, "yaw": 0.0, "lift": 0.0},
	"th_hanging": {"glb": "res://assets/models/kit/th_hanging.glb", "family": "M_wool", "length": 1.68, "yaw": 0.0, "lift": 0.0},
	"th_horn_rack": {"glb": "res://assets/models/kit/th_horn_rack.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"th_trestles": {"glb": "res://assets/models/kit/th_trestles.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"th_oar_stand": {"glb": "res://assets/models/kit/th_oar_stand.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"th_rush_bundles": {"glb": "res://assets/models/kit/th_rush_bundles.glb", "family": "M_rope", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"th_horn_window": {"glb": "res://assets/models/kit/th_horn_window.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"th_pail": {"glb": "res://assets/models/kit/th_pail.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"th_boat_oars": {"glb": "res://assets/models/kit/th_boat_oars.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	# --- the Coldwell's own set
	"cw_thread_post": {"glb": "res://assets/models/kit/cw_thread_post.glb", "family": "M_wood", "length": 0.92, "yaw": 0.0, "lift": 0.0},
	"cw_flower_basket": {"glb": "res://assets/models/kit/cw_flower_basket.glb", "family": "M_drift", "length": 0.6, "yaw": 0.0, "lift": 0.0},
	"cw_dipper_trough": {"glb": "res://assets/models/kit/cw_dipper_trough.glb", "family": "M_stone", "length": 1.9, "yaw": 0.0, "lift": 0.0},
	"cw_offering_cairn": {"glb": "res://assets/models/kit/cw_offering_cairn.glb", "family": "M_stone", "length": 1.2, "yaw": 0.0, "lift": 0.0},
	"cw_water_yoke": {"glb": "res://assets/models/kit/cw_water_yoke.glb", "family": "M_wood", "length": 1.5, "yaw": 0.0, "lift": 0.0},
	"cw_shelter": {"glb": "res://assets/models/kit/cw_shelter.glb", "family": "M_stone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_staff_rack": {"glb": "res://assets/models/kit/cw_staff_rack.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_staff_rack_full": {"glb": "res://assets/models/kit/cw_staff_rack_full.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_staff_heap": {"glb": "res://assets/models/kit/cw_staff_heap.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_rope_rail": {"glb": "res://assets/models/kit/cw_rope_rail.glb", "family": "M_rope", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_slab_bench": {"glb": "res://assets/models/kit/cw_slab_bench.glb", "family": "M_stone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_slab_bench_snow": {"glb": "res://assets/models/kit/cw_slab_bench_snow.glb", "family": "M_stone", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_ice_column_a": {"glb": "res://assets/models/kit/cw_ice_column_a.glb", "family": "M_ice", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_ice_column_b": {"glb": "res://assets/models/kit/cw_ice_column_b.glb", "family": "M_ice", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_ice_column_c": {"glb": "res://assets/models/kit/cw_ice_column_c.glb", "family": "M_ice", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"cw_flower_bunch": {"glb": "res://assets/models/kit/cw_flower_bunch.glb", "family": "M_wool", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	# the Reach flocks: a ewe with her head up and one grazing, taken in turn
	"sheep": {"glb": "res://assets/models/kit/kit_ewe_a.glb", "alt": ["res://assets/models/kit/kit_ewe_b.glb"],
		"family": "M_fleece", "length": 1.15, "yaw": 90.0, "lift": 0.0,
		# unrigged: the hall shader swings head and ears (graze_* uniforms).
		# glb file -> [amp, pivot x, pivot y, from x, from y, mode, ear y]
		"graze": {"kit_ewe_a.glb": [0.34, 0.22, 0.62, 0.2, 0.5, 0.0, 0.9],
			"kit_ewe_b.glb": [0.3, 0.26, 0.56, 0.3, -1.0, 1.0, 9.0]}},
	# --- Thornwold's own prop set: authored at the footprint, atlas colours kept
	"tw_clamp_a": {"glb": "res://assets/models/kit/kit_tw_clamp_a.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_clamp_b": {"glb": "res://assets/models/kit/kit_tw_clamp_b.glb", "family": "M_turf", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_clamp_c": {"glb": "res://assets/models/kit/kit_tw_clamp_c.glb", "family": "M_turf", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_cordwood": {"glb": "res://assets/models/kit/kit_tw_cordwood.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_hurdle": {"glb": "res://assets/models/kit/kit_tw_hurdle.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_stake_bundle": {"glb": "res://assets/models/kit/kit_tw_stake_bundle.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_stile": {"glb": "res://assets/models/kit/kit_tw_stile.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_charcoal_sacks": {"glb": "res://assets/models/kit/kit_tw_charcoal_sacks.glb", "family": "M_felt", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_gatepost": {"glb": "res://assets/models/kit/kit_tw_gatepost.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_collier_hut": {"glb": "res://assets/models/kit/kit_tw_collier_hut.glb", "family": "M_turf", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_hut_yard": {"glb": "res://assets/models/kit/kit_tw_hut_yard.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_hut_thaw": {"glb": "res://assets/models/kit/kit_tw_hut_thaw.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_hut_rime": {"glb": "res://assets/models/kit/kit_tw_hut_rime.glb", "family": "M_wood", "yaw": 0.0, "lift": 0.0, "tint": 0.0},
	"tw_shaving_horse": {"glb": "res://assets/models/kit/kit_tw_shaving_horse.glb", "family": "M_wood", "length": 1.39, "yaw": 0.0, "lift": 0.0},
	"tw_riddle_stand": {"glb": "res://assets/models/kit/kit_tw_riddle_stand.glb", "family": "M_wood", "length": 1.65, "yaw": 0.0, "lift": 0.0},
	"tw_sledge": {"glb": "res://assets/models/kit/kit_tw_sledge.glb", "family": "M_wood", "length": 1.93, "yaw": 0.0, "lift": 0.0},
	"tw_hedging_tools": {"glb": "res://assets/models/kit/kit_tw_hedging_tools.glb", "family": "M_wood", "length": 1.09, "yaw": 0.0, "lift": 0.0},
	"tw_wood_shelter": {"glb": "res://assets/models/kit/kit_tw_wood_shelter.glb", "family": "M_wood", "length": 2.89, "yaw": 0.0, "lift": 0.0},
}
static var _hero_turn := 0

static func instance(id: String, state_mode := 0, mat_remap: Dictionary = {}) -> Node3D:
	if not PIECES.has(id):
		push_error("KitLib: unknown piece '%s'" % id)
		return Node3D.new()
	var node := Node3D.new()
	node.name = id
	if id.begins_with("mannequin_"):
		_build_mannequin(node, id)
	elif HERO_PIECES.has(id) and ResourceLoader.exists(String(HERO_PIECES[id]["glb"])):
		_build_hero(node, id)
	else:
		_build_piece(node, id)
	remap_materials(node, state_mode, mat_remap)
	node.set_meta("kit_id", id)
	node.set_meta("state_mode", state_mode)
	return node

static func _build_hero(n: Node3D, id: String) -> void:
	var h: Dictionary = HERO_PIECES[id]
	var glb := String(h["glb"])
	if h.has("alt"):
		var all: Array = [glb] + (h["alt"] as Array)
		_hero_turn += 1
		var pick := String(all[_hero_turn % all.size()])
		if ResourceLoader.exists(pick):
			glb = pick
	var inst := (load(glb) as PackedScene).instantiate() as Node3D
	# colliders come from the generator's own shapes, not the landmark's
	for c in inst.find_children("*", "CollisionObject3D", true, false):
		c.get_parent().remove_child(c)
		c.free()
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb := m.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
		m.set_meta("hero_family", String(h.get("family", "M_wood")))
		if h.has("tint"):
			m.set_meta("hero_tint", float(h["tint"]))
		if h.has("graze") and (h["graze"] as Dictionary).has(glb.get_file()):
			m.set_meta("hero_graze", h["graze"][glb.get_file()])
	var long := maxf(aabb.size.x, aabb.size.z)
	var sc := float(h.get("length", long)) / maxf(long, 0.01)
	inst.scale = Vector3.ONE * sc
	inst.rotation_degrees = Vector3(0, float(h.get("yaw", 0.0)), 180.0 if h.get("flip", false) else 0.0)
	inst.position.y = float(h.get("lift", 0.0))
	n.add_child(inst)
	if id == "hearthstone":
		_hearth_bed(n, 0.42, 0.05)
	if id == "hearth_fire":
		# the long fire, lit: coals glowing through the ash under the logs
		_sphere(n, 0.36, Vector3(0, 0.06, 0), "M_coals", "bed", Vector3(1.0, 0.2, 0.82))
		_flame(n, Vector3(0, 0.16, 0), 0.75, 0.35, "fire_flame")
		_flame(n, Vector3(0.18, 0.14, 0.1), 0.45, 0.22, "fire_flame_b")
		_embers(n, Vector3(0, 0.3, 0), 0.25, 8)
	if id == "fat_lamp":
		# a rush wick burns small and steady at the lip
		_flame(n, Vector3(0.118, 0.1, -0.006), 0.07, 0.022, "wick_flame")
	if id == "brazier":
		_flame(n, Vector3(0, 0.9, 0), 0.42, 0.16, "flame")
		_flame(n, Vector3(0.07, 0.9, -0.05), 0.28, 0.11, "flame_b")
		_embers(n, Vector3(0, 1.0, 0), 0.1, 8)
	if id == "boat_upturned":
		# keep the trestles it rests on
		for z in [-1.6, 1.6]:
			_box(n, Vector3(1.6, 0.08, 0.1), Vector3(0, 0.62, z), "M_wood", "trestle_bar")
			for sx in [-0.7, 0.7]:
				_box(n, Vector3(0.08, 0.66, 0.08), Vector3(sx, 0.31, z), "M_wood", "trestle_leg", Vector3(0, 0, sx * 14))

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
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = _flame_cards(h, r)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static var _flame_meshes: Dictionary = {}

## Three cards crossed on the flame's axis (flame.gdshader draws the tongue
## on each; additive, so they build a volume from any side).
static func _flame_cards(h: float, r: float) -> ArrayMesh:
	var key := "%.2f|%.2f" % [h, r]
	if _flame_meshes.has(key):
		return _flame_meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := r * 2.6
	var hh := h * 1.25
	for i in 3:
		var a := PI * float(i) / 3.0
		var right := Vector3(cos(a), 0, sin(a)) * w * 0.5
		var quad: Array = [[-right, Vector2(0, 1)], [right, Vector2(1, 1)], [right + Vector3.UP * hh, Vector2(1, 0)],
			[-right, Vector2(0, 1)], [right + Vector3.UP * hh, Vector2(1, 0)], [-right + Vector3.UP * hh, Vector2(0, 0)]]
		for v in quad:
			st.set_normal(Vector3.UP)
			st.set_uv(v[1])
			st.set_uv2(Vector2.ZERO)
			st.add_vertex(v[0])
	# a level disc low in the flame: from above the cards are edge-on, and
	# this is the bright heart you look down into (UV2.x = 1 marks it)
	var dr := w * 0.42
	var dy := hh * 0.14
	var disc: Array = [[Vector3(-dr, dy, -dr), Vector2(0, 0)], [Vector3(dr, dy, -dr), Vector2(1, 0)], [Vector3(dr, dy, dr), Vector2(1, 1)],
		[Vector3(-dr, dy, -dr), Vector2(0, 0)], [Vector3(dr, dy, dr), Vector2(1, 1)], [Vector3(-dr, dy, dr), Vector2(0, 1)]]
	for v in disc:
		st.set_normal(Vector3.UP)
		st.set_uv(v[1])
		st.set_uv2(Vector2(1, 0))
		st.add_vertex(v[0])
	var mesh := st.commit()
	mesh.surface_set_material(0, _ph("M_flame"))
	mesh.custom_aabb = AABB(Vector3(-w, 0, -w), Vector3(w * 2.0, hh * 1.1, w * 2.0))
	_flame_meshes[key] = mesh
	return mesh

static var _ember_mat: StandardMaterial3D = null

## Sparks lifting off a fire: a handful of bright points that rise, drift and
## go out. CPU particles: a dozen per fire is cheaper than a GPU system each.
static func _embers(parent: Node3D, pos: Vector3, spread: float, amount := 10) -> CPUParticles3D:
	if _ember_mat == null:
		_ember_mat = StandardMaterial3D.new()
		_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ember_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_ember_mat.vertex_color_use_as_albedo = true
		_ember_mat.albedo_color = Color(1.0, 0.55, 0.2)
	var p := CPUParticles3D.new()
	p.name = "embers"
	p.amount = amount
	p.lifetime = 1.8
	p.randomness = 0.6
	p.lifetime_randomness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread
	p.direction = Vector3.UP
	p.spread = 22.0
	p.gravity = Vector3(0.12, 0.35, -0.08)
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1.6, 1.0, 0.45, 1.0))
	fade.set_color(1, Color(0.9, 0.15, 0.02, 0.0))
	p.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.011, 0.011)
	q.material = _ember_mat
	p.mesh = q
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

## The fire in a hearthstone's ring: a mound of coals (coals.gdshader: lit in
## THAW, banked to a faint ember in RIME) with a few low tongues of flame over
## it and a small steady ember light that outlasts the flames.
static func _hearth_bed(n: Node3D, r: float, y: float) -> void:
	var coals := _sphere(n, r, Vector3(0, y, 0), "M_coals", "coals", Vector3(1.0, 0.24, 1.0))
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tongues: Array = [[Vector3(0.0, 0.1, 0.02), 0.5, 0.14], [Vector3(-0.15, 0.08, 0.1), 0.34, 0.11],
		[Vector3(0.14, 0.08, -0.08), 0.4, 0.12], [Vector3(0.04, 0.07, 0.18), 0.26, 0.09]]
	for i in tongues.size():
		var t: Array = tongues[i]
		var f := _flame(n, Vector3(0, y, 0) + t[0], t[1], t[2], "hearth_flame" if i == 0 else "hearth_flame_%d" % i)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_embers(n, Vector3(0, y + 0.15, 0), 0.18)
	var ember := OmniLight3D.new()
	ember.name = "ember_glow"
	ember.light_color = Color(1.0, 0.36, 0.12)
	ember.light_energy = 0.06
	ember.omni_range = 1.1
	ember.omni_attenuation = 1.6
	ember.shadow_enabled = false
	ember.distance_fade_enabled = true
	ember.distance_fade_begin = 24.0
	ember.distance_fade_length = 8.0
	ember.position = Vector3(0, y + 0.22, 0)
	n.add_child(ember)

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
		"sheep":
			# a fell ewe: a round fleece on four thin legs, a dark face
			_sphere(n, 0.5, Vector3(0, 0.72, 0), "M_fleece", "fleece", Vector3(0.62, 0.62, 1.05))
			_box(n, Vector3(0.2, 0.26, 0.34), Vector3(0, 0.86, -0.62), "M_leather", "face", Vector3(-28, 0, 0))
			_box(n, Vector3(0.3, 0.1, 0.08), Vector3(0, 0.98, -0.52), "M_leather", "ears")
			for lx in [-0.16, 0.16]:
				for lz in [-0.32, 0.32]:
					_box(n, Vector3(0.07, 0.5, 0.07), Vector3(lx, 0.25, lz), "M_wood_dark", "leg")
		"hearth_fire", "hearth_logs":
			# a fire on the long hearth: split logs crossed on the embers
			# (hearth_logs: the same fire, out; RIME)
			for k in 4:
				_box(n, Vector3(1.2, 0.14, 0.14), Vector3(0, 0.1 + (k % 2) * 0.12, 0), "M_wood_dark", "log%d" % k, Vector3(0, k * 47, 4))
			_box(n, Vector3(1.0, 0.05, 0.8), Vector3(0, 0.03, 0), "M_ember" if id == "hearth_fire" else "M_stone_dark", "bed")
			if id == "hearth_fire":
				_flame(n, Vector3(0, 0.2, 0), 0.75, 0.35, "fire_flame")
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
			_hearth_bed(n, 0.4, 0.5)
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
			# a boarded chest, not a cube: four courses of boards a side with
			# gaps, corner battens standing proud, a lid of four boards
			_box(n, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.47, 0), "M_wood_dark", "core")
			for k in 4:
				var by := 0.14 + k * 0.245
				for side in 4:
					var ang := side * 90.0
					var off := Vector3(0, by, 0.47).rotated(Vector3.UP, deg_to_rad(ang))
					_box(n, Vector3(0.96 - 0.01 * (k % 2), 0.225, 0.05), off, "M_drift" if (k + side) % 3 == 0 else "M_wood", "board", Vector3(0, ang, 0))
			for cx in [-1.0, 1.0]:
				for cz in [-1.0, 1.0]:
					_box(n, Vector3(0.1, 0.99, 0.1), Vector3(cx * 0.47, 0.495, cz * 0.47), "M_wood_dark", "batten")
			for k in 4:
				_box(n, Vector3(0.245, 0.05, 1.02), Vector3(-0.375 + k * 0.25, 1.0, 0), "M_wood", "lid", Vector3(0, (k % 2) * 1.2 - 0.6, 0))
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
		if mi.has_meta("hero_family"):
			# a remap of the hero's family re-skins it (a ewe frozen to rime)
			# but keeps its baked detail
			var hfam := String(mi.get_meta("hero_family"))
			if mat_remap.has(hfam):
				hfam = String(mat_remap[hfam])
			mi.set_meta("family", hfam)   # what a blade meets here (Surfaces)
			for s in mesh.get_surface_count():
				var hm := MaterialLib.hero_mat(mesh.surface_get_material(s), hfam, state_mode,
						float(mi.get_meta("hero_tint", 0.55)))
				if mi.has_meta("hero_graze") and state_mode != 2:
					hm = _graze_mat(hm, mi.get_meta("hero_graze"))
				mi.set_surface_override_material(s, hm)
			continue
		for s in mesh.get_surface_count():
			var src := mesh.surface_get_material(s)
			var fam := "M_stone"
			if src != null and src.resource_name != "":
				fam = src.resource_name
			fam = fam.get_slice(".", 0)
			if mat_remap.has(fam):
				fam = String(mat_remap[fam])
			if s == 0:
				mi.set_meta("family", fam)   # what a blade meets here (Surfaces)
			mi.set_surface_override_material(s, MaterialLib.get_mat(fam, state_mode))
			if fam == "M_flame":
				var aabb := mesh.get_aabb()
				mi.set_instance_shader_parameter("flame_base_y", aabb.position.y)
				mi.set_instance_shader_parameter("flame_height", maxf(aabb.size.y, 0.05))
				mi.set_instance_shader_parameter("flame_tint", Vector3(1.0, 0.6, 0.2))
				mi.set_instance_shader_parameter("flame_energy", 1.0)

static var _graze_cache: Dictionary = {}

## A hero material with the living-stock head swing set (one copy per source
## material, shared by the whole flock).
static func _graze_mat(src: Material, g: Array) -> Material:
	var key := src.get_instance_id()
	if not _graze_cache.has(key):
		var m := src.duplicate() as ShaderMaterial
		m.set_shader_parameter("graze_amp", float(g[0]))
		m.set_shader_parameter("graze_pivot", Vector2(float(g[1]), float(g[2])))
		m.set_shader_parameter("graze_from", Vector2(float(g[3]), float(g[4])))
		m.set_shader_parameter("graze_mode", float(g[5]))
		m.set_shader_parameter("graze_ear_y", float(g[6]))
		_graze_cache[key] = m
	return _graze_cache[key]

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
	# above the flame tips, so the stones around a fire are lit, not burnt out
	l.position = avg_pos + Vector3(0, 0.45, 0)
	piece.add_child(l)
	lights.append(l)
	return lights

## Wrap a piece's meshes in StaticBody3D colliders (cached per piece/mesh).
## convex=false -> trimesh (architecture with openings); true -> convex hull.
static var _shape_cache: Dictionary = {}

## Each collider is stamped with the surface a blade meets on it: `surface`
## when the caller knows better, else the kit's own, else its mesh's family.
static func add_collision(piece: Node3D, layer_bit: int, convex := false, surface := "") -> void:
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
		Surfaces.stamp(body, surface if surface != "" else Surfaces.for_kit(kit_id, String(mi.get_meta("family", ""))))
		body.set_meta(PropStrike.META_GROUP, piece.get_instance_id())   # one piece, one burst
		mi.add_child(body)
