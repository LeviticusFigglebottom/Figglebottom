extends TestBase
## The planned deltas (SURVEY §3, §6, §8, §12): lock-on target switching,
## data-read weapon upgrades, (stat - base) scaling, the sprint attack,
## armour slots (poise, absorption, weight tiers, the Pack leaf, saves),
## save_version with its migration hook, and the worn body armour as the
## Bearer's body (items.json armour.model).

## Base damage BEFORE the (stat - base) delta. A fresh Bearer (every stat at
## 8) must still deal exactly what these did under the old formula.
const OLD_DAMAGE := {"hewing_blade": 42.0, "maul": 66.0, "spear": 38.0,
	"greatblade": 74.0, "bow": 34.0, "torch": 0.0}
const OLD_SONGS := {"ember_throw": 58.0, "hearth_shout": 95.0, "long_note": 88.0}

var pen: LockPen
var player: Player

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	pen = LockPen.new()
	add_child(pen)
	await ticks(5)
	player = pen.player
	await _lock_switching()
	_upgrades()
	_scaling()
	await _sprint_attack()
	await _armour()
	await _armour_leaf()
	await _saves()
	await _outfits()
	finish()

func _near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) <= eps

# ------------------------------------------------------------------ 1. lock
func _lock_switching() -> void:
	print("== lock-on: switching between three pells")
	var cam := player.cam
	var L: TrainingDummy = pen.pells["Left"]
	var C: TrainingDummy = pen.pells["Centre"]
	var R: TrainingDummy = pen.pells["Right"]
	check(DB.tuning("camera/lock/flick_px") != null and DB.tuning("camera/lock/stick_threshold") != null,
		"switch tuning lives in game.json camera/lock")
	cam.yaw = 0.0
	await ticks(3)
	cam.try_lock(get_tree().get_nodes_in_group("targetable"))
	check(cam.locked_target == C, "lock picks the pell straight ahead")
	await ticks(20)
	cam.mouse_look(Vector2(20, 0))
	check(cam.locked_target == C, "a small drift does not switch")
	await ticks(20)
	cam.mouse_look(Vector2(90, 0))
	check(cam.locked_target == R, "a right flick moves to the right pell")
	await ticks(30)
	cam.mouse_look(Vector2(90, 0))
	check(cam.locked_target == R, "a flick with nothing further right keeps the lock (no break)")
	await ticks(30)
	cam.mouse_look(Vector2(-90, 0))
	check(cam.locked_target == C, "a left flick takes the NEAREST on the left (centre, not far left)")
	await ticks(30)
	cam.mouse_look(Vector2(-90, 0))
	check(cam.locked_target == L, "another left flick reaches the left pell")
	await ticks(30)
	cam.mouse_look(Vector2(-90, 0))
	check(cam.locked_target == L, "the hardest flick never breaks the lock")
	await ticks(30)
	# right stick: one switch per push, re-armed by returning toward centre
	var dt := 1.0 / 60.0
	cam.stick_look(Vector2(1, 0), dt)
	check(cam.locked_target == C, "the right stick switches right")
	await ticks(30)
	cam.stick_look(Vector2(1, 0), dt)
	check(cam.locked_target == C, "a held stick does not keep switching")
	cam.stick_look(Vector2(0, 0), dt)
	cam.stick_look(Vector2(1, 0), dt)
	check(cam.locked_target == R, "stick released and pushed again switches again")
	await ticks(30)
	# the scorer on its own, from the centre: screen angle picks the side
	cam.locked_target = C
	await ticks(40)
	var cands := [L, C, R]
	check(cam.pick_switch_target(1, cands) == R and cam.pick_switch_target(-1, cands) == L,
		"screen-space scoring: right of centre is Right, left is Left")
	# a pell that falls is never switched to
	R.dead = true
	check(cam.pick_switch_target(1, cands) == null, "a dead pell is not a valid target")
	R.dead = false
	# breaking: the lock button, or range
	cam.try_lock([])
	check(cam.locked_target == null, "the lock button still breaks the lock")
	cam.try_lock(get_tree().get_nodes_in_group("targetable"))
	check(cam.locked_target != null, "relock")
	player.global_position = Vector3(0, 0.1, 22.0)
	await ticks(3)
	check(cam.locked_target == null, "walking out of break_range breaks the lock")
	player.global_position = Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	cam.yaw = 0.0
	await ticks(5)

# ------------------------------------------------------------------ 2. upgrades
func _upgrades() -> void:
	print("== weapon upgrades read upgrade.per_level")
	var all_have := true
	for id in DB.table("weapons"):
		var u: Dictionary = DB.weapon(id).get("upgrade", {})
		all_have = all_have and u.has("per_level")
	check(all_have, "every weapon carries upgrade.per_level")
	player.weapon_id = "hewing_blade"
	var w := DB.weapon("hewing_blade")
	var per := float(w["upgrade"]["per_level"])
	player.weapon_level = 0
	var d0 := player._attack_damage(1.0)
	player.weapon_level = 3
	var d3 := player._attack_damage(1.0)
	check(_near(d3 - d0, 3.0 * per * Game.dmg_out_mult()),
		"+3 adds 3 x per_level (%.2f -> %.2f)" % [d0, d3])
	check(not _near(d3, d0 * (1.0 + 0.14 * 3.0)), "no longer the hardcoded 14%")
	check(_near(player.upgrade_bonus({"damage": 50.0}, 2), 14.0),
		"a weapon without per_level falls back to 14% of its base")
	player.weapon_level = 0

# ------------------------------------------------------------------ 3. scaling
func _scaling() -> void:
	print("== stat scaling counts (stat - base)")
	check(player.base_stat() == int(DB.tuning("levels/base_stat", -1)), "base stat comes from data")
	var all_same := true
	for id in OLD_DAMAGE:
		player.weapon_id = id
		var scal: Dictionary = DB.weapon(id).get("scaling", {})
		var old_s := 1.0
		for st in scal:
			old_s += 8.0 * float(scal[st]) * 0.02    # the old formula: stat * k
		var old: float = float(OLD_DAMAGE[id]) * old_s * Game.dmg_out_mult()
		var now := player._attack_damage(1.0)
		if not _near(now, old):
			all_same = false
			print("    %s: old %.3f now %.3f" % [id, old, now])
	check(all_same, "a fresh Bearer deals exactly the old damage with every weapon")
	player.weapon_id = "hewing_blade"
	var fresh := player._attack_damage(1.0)
	check(_near(fresh, float(DB.weapon("hewing_blade")["damage"]) * Game.dmg_out_mult()),
		"at base stats the multiplier is exactly 1")
	player.attributes["might"] = 10
	var up := player._attack_damage(1.0)
	check(_near(up / fresh, 1.0 + 2.0 * 0.6 * 0.02), "two points of might add 2 x 0.6 x 2%")
	player.attributes["might"] = player.base_stat()
	var songs_same := true
	for sid in OLD_SONGS:
		var dev := 1.0 + float(player.attributes["kinship"] - player.base_stat()) * 0.025
		songs_same = songs_same and _near(float(DB.song(sid)["damage"]) * dev, float(OLD_SONGS[sid]) * 1.2)
	check(songs_same, "songs: a fresh Bearer's songs hit as hard as before")

# ------------------------------------------------------------------ 4. sprint
func _sprint_attack() -> void:
	print("== sprint attack")
	var ok := true
	for ms_id in DB.table("movesets"):
		var sp: Dictionary = DB.moveset(ms_id).get("sprint", {})
		for k in ["windup", "active", "recovery", "lunge"]:
			ok = ok and sp.has(k)
	check(ok, "every moveset has a sprint entry with windup/active/recovery/lunge")
	var st_ok := true
	for id in DB.table("weapons"):
		st_ok = st_ok and (DB.weapon(id)["stamina"] as Dictionary).has("sprint")
	check(st_ok, "every weapon has a sprint stamina cost")
	check(HumanoidLib.candidates("attack_sprint") == ["attack_sprint", "heavy", "slash"],
		"clip alias attack_sprint falls back to heavy, then slash")
	var C: TrainingDummy = pen.pells["Centre"]
	player.cam.locked_target = null
	player.weapon_id = "hewing_blade"
	player._refresh_weapon_visual()
	player.global_position = C.global_position + Vector3(0, 0.1, 3.8)
	player.velocity = Vector3.ZERO
	player.vis.rotation.y = 0.0
	player.stamina = player.max_stamina
	player.sim_move = Vector3(0, 0, -1)
	player.sim_sprint = true
	await ticks(14)
	check(player._sprinting, "running with sprint held is a sprint")
	var st0 := player.stamina
	var hp0 := C.hp
	var hits0 := C.hits_taken
	check(player.try_attack(false), "attacking at a sprint swings")
	player.sim_move = Vector3.ZERO
	player.sim_sprint = false
	var ms := DB.moveset("longsword")
	check(player._atk_kind == "sprint" and player._atk == ms["sprint"], "it is the sprint attack, not a light")
	check(_near(st0 - player.stamina, float(DB.weapon("hewing_blade")["stamina"]["sprint"]), 0.6),
		"it spends the sprint stamina cost")
	check(player.vis.current_clip() == "attack_sprint", "plays the attack_sprint clip (alias-backed)")
	await ticks(70)
	check(C.hits_taken == hits0 + 1, "the run-in strike lands on the pell")
	var exp_dmg := player._attack_damage(float(ms["sprint"]["dmg_mult"]))
	check(_near(hp0 - C.hp, exp_dmg, 0.01), "with the sprint dmg_mult (%.1f)" % (hp0 - C.hp))
	await ticks(30)
	check(player.state == Player.S.MOVE, "and recovers to MOVE")
	player.velocity = Vector3.ZERO
	player.try_attack(false)
	check(player._atk_kind == "light", "standing still the same press is a plain light")
	await ticks(70)

# ------------------------------------------------------------------ 5. armour
func _armour() -> void:
	print("== armour: poise, absorption, weight tiers")
	var items: Dictionary = DB.table("items")
	var coat := Player.armour_data("armour_traveller_coat")
	var oil := Player.armour_data("armour_saltfell_oilskins")
	check(String(coat.get("slot", "")) == "body" and String(oil.get("slot", "")) == "body",
		"Traveller's Coat and Saltfell Oilskins are body armour")
	check(String(items["armour_traveller_coat"]["desc"]).begins_with("A long coat of grey southern wool")
		and String(items["armour_saltfell_oilskins"]["desc"]).begins_with("Brede's spare oilskin smock"),
		"their descriptions are SLICE.md's")
	check(player.armour == {"head": "", "body": "armour_traveller_coat", "hands": "", "legs": ""},
		"a new Bearer starts in the coat, other slots bare")
	var base := float(DB.tuning("player/base/poise"))
	check(_near(player.max_poise, base + float(coat["poise"])), "poise = 30 + the coat's (%.0f)" % player.max_poise)
	check(not player.equip_armour("head", "armour_traveller_coat"), "a coat will not go on the head")
	check(not player.equip_armour("body", "armour_saltfell_oilskins"), "oilskins not carried cannot be worn")
	# three test pieces fill the other slots
	items["test_helm"] = {"name": "Test Helm", "armour": {"slot": "head", "poise": 5, "absorb": {"phys": 0.10, "frost": 0.05}, "weight": 4.0}}
	items["test_mitts"] = {"name": "Test Mitts", "armour": {"slot": "hands", "poise": 3, "absorb": {"phys": 0.05, "frost": 0.02}, "weight": 3.0}}
	items["test_greaves"] = {"name": "Test Greaves", "armour": {"slot": "legs", "poise": 4, "absorb": {"phys": 0.08, "frost": 0.03}, "weight": 5.0}}
	for id in ["test_helm", "test_mitts", "test_greaves"]:
		player.give_item(id)
		check(player.equip_armour(String(items[id]["armour"]["slot"]), id), "wear %s" % id)
	# coat 2 + helm 5 + mitts 3 + greaves 4 = 14 poise; phys .03+.10+.05+.08 = .26
	check(_near(player.max_poise, base + 14.0), "poise = 30 + 2 + 5 + 3 + 4 = %.0f" % player.max_poise)
	check(_near(player.absorption("physical"), 0.26), "physical absorption sums to 26%")
	check(_near(player.absorption("frost"), 0.18), "frost absorption sums to 18%")
	check(_near(player.absorption("ember"), 0.0), "ember is not turned by wool")
	player.hp = player.max_hp
	player.take_hit(DamagePacket.new(100.0, 0.0, null))
	check(_near(player.max_hp - player.hp, 74.0 * Game.dmg_in_mult(), 0.01),
		"a 100 blow costs 74 hp (%.2f)" % (player.max_hp - player.hp))
	player.hp = player.max_hp
	var fk := DamagePacket.new(100.0, 0.0, null)
	fk.kind = "frost"
	player.take_hit(fk)
	check(_near(player.max_hp - player.hp, 82.0 * Game.dmg_in_mult(), 0.01), "a 100 frost blow costs 82")
	player.hp = player.max_hp
	await ticks(140)   # let the stagger from those blows settle
	# weight 3.5 + 4 + 3 + 5 = 15.5 > heavy_over: the heavy roll
	check(player.roll_tier() == "heavy", "15.5 weight is the heavy roll")
	var H: Dictionary = DB.tuning("player/armour/roll_tiers/heavy")
	var R: Dictionary = DB.tuning("player/roll")
	check(float(H["duration"]) > float(R["duration"]) and float(H["iframe_end"]) - float(H["iframe_start"])
		< float(R["iframe_end"]) - float(R["iframe_start"]), "heavy: slower roll, shorter i-frames (data)")
	var roll_len := await _measure_roll()
	check(_near(roll_len, float(H["duration"]), 0.05), "heavy roll lasts %.2f s" % roll_len)
	# medium = today's numbers: the coat alone
	for s in ["head", "hands", "legs"]:
		player.equip_armour(s, "")
	check(player.roll_tier() == "medium" and _near(player.roll_param("duration"), float(R["duration"]))
		and _near(player.roll_param("iframe_end"), float(R["iframe_end"])),
		"the coat alone is the medium roll, the old numbers unchanged")
	roll_len = await _measure_roll()
	check(_near(roll_len, float(R["duration"]), 0.05), "medium roll lasts %.2f s" % roll_len)
	player.equip_armour("body", "")
	check(player.roll_tier() == "light" and player.roll_param("duration") < float(R["duration"]), "bare is the light roll")
	check(_near(player.max_poise, base), "bare poise is the base 30")
	player.equip_armour("body", "armour_traveller_coat")
	# (the Netmender's moves follow SLICE.md 6 now: her ice knots and the
	# sea-weight are the frost blows; the old frost heave is gone)
	var heave := {}
	for a in DB.enemy("netmender")["attacks"]:
		if a["id"] == "knot":
			heave = a
	check(String(heave.get("kind", "")) == "frost", "the Netmender's ice knots strike as frost")
	for id in ["test_helm", "test_mitts", "test_greaves"]:
		items.erase(id)
		player.inventory.erase(id)

func _measure_roll() -> float:
	player.velocity = Vector3.ZERO
	player.stamina = player.max_stamina
	player.sim_move = Vector3(1, 0, 0)
	player.try_roll()
	player.sim_move = Vector3.ZERO
	var t := 0.0
	while player.state == Player.S.ROLL and t < 2.0:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	await ticks(10)
	return t

# ------------------------------------------------------------------ 5b. the leaf
func _armour_leaf() -> void:
	print("== Pack: the Armour leaf")
	player.give_item("armour_saltfell_oilskins")
	InventoryUI.open_for(player)
	await ticks(2)
	var ui: InventoryUI = get_tree().get_first_node_in_group("inventory_ui")
	check(ui != null, "the Pack opens")
	ui._show_tab("armour")
	await ticks(2)
	var ids := []
	for r in ui._rows:
		ids.append(r["id"])
	check(ids == ["armour_traveller_coat", "armour_saltfell_oilskins"], "the leaf lists the carried armour")
	check(ui._armour_slots.size() == 4 and ui._armour_slots.map(func(a): return a["slot"]) == ["head", "body", "hands", "legs"],
		"four slots: head, body, hands, legs")
	var relics_has_coat := false
	ui._show_tab("pack")
	await ticks(1)
	for l in ui._list.find_children("*", "Label", true, false):
		if (l as Label).text.contains("Oilskins") or (l as Label).text.contains("Traveller"):
			relics_has_coat = true
	check(not relics_has_coat, "armour is not listed again among relics")
	ui._show_tab("armour")
	await ticks(1)
	# keyboard: select the oilskins, Enter wears them
	ui._sel = 1
	ui._act_selected()
	check(player.armour["body"] == "armour_saltfell_oilskins", "Enter wears the selected piece")
	check(_near(player.max_poise, 30.0 + 4.0), "poise follows the oilskins (34)")
	ui._act_selected()
	check(player.armour["body"] == "", "Enter again takes it off")
	# number key into a slot: 2 = body
	ui._sel = 0
	ui._armour_key(1)
	check(player.armour["body"] == "armour_traveller_coat", "2 puts the selected coat in the body slot")
	ui._armour_key(0)
	check(player.armour["body"] == "armour_traveller_coat" and player.armour["head"] == "", "1 (head) refuses a coat")
	# drag and drop
	var drag := {"id": "armour_saltfell_oilskins", "kind": "armour"}
	check(not ui._can_drop_armour(Vector2.ZERO, drag, "head"), "oilskins cannot be dropped on the head")
	check(ui._can_drop_armour(Vector2.ZERO, drag, "body"), "oilskins can be dropped on the body")
	ui._drop_armour(Vector2.ZERO, drag, "body")
	check(player.armour["body"] == "armour_saltfell_oilskins", "dropping them wears them")
	ui._refresh_armour()
	check(String(ui._armour_slots[1]["name"].text) == "Saltfell Oilskins", "the body slot shows them")
	ui.close()
	await ticks(2)

# ------------------------------------------------------------------ 5c/6. saves
func _saves() -> void:
	print("== saves: armour persists, save_version, migration")
	World._save_dir = "user://test_deltas_saves"
	World.active_slot = 1
	DirAccess.make_dir_recursive_absolute(World._save_dir)
	World.delete_slot(1)
	player.equip_armour("body", "armour_saltfell_oilskins")
	World.save_game()
	var saved = JSON.parse_string(FileAccess.open(World.save_path(), FileAccess.READ).get_as_text())
	# (2 brought armour; ADR 0013 made it 3 for the endings)
	check(int(saved.get("save_version", 0)) == World.SAVE_VERSION and World.SAVE_VERSION >= 2,
		"saves carry save_version %d" % World.SAVE_VERSION)
	check(String(saved["player"]["armour"]["body"]) == "armour_saltfell_oilskins", "the save holds the worn armour")
	player.equip_armour("body", "armour_traveller_coat")
	check(World.load_game(), "the slot loads")
	player.from_save(World.player_data)
	check(player.armour["body"] == "armour_saltfell_oilskins" and _near(player.max_poise, 34.0),
		"loading puts the oilskins back on")
	# the version-1 fixture
	var fx_path := "res://tools/test/fixtures/save_v1.json"
	var v1: Dictionary = JSON.parse_string(FileAccess.open(fx_path, FileAccess.READ).get_as_text())
	check(int(v1.get("version", 0)) == 1 and not v1.has("save_version") and not v1["player"].has("armour"),
		"fixture is a genuine version-1 save")
	var m := World.migrate(v1.duplicate(true))
	check(int(m["save_version"]) == World.SAVE_VERSION and not m.has("version"), "migrate() lifts it to the current version")
	check(m["player"]["armour"] == Player.starting_armour(), "a v1 Bearer is dressed in the starting coat")
	check(int(m["player"]["level"]) == 4 and int(m["breathmark"]["amount"]) == 57
		and bool(m["areas"]["saltfell_strand"]["flags"]["took_strand_bog_iron"]), "nothing else is lost")
	check(World.migrate(m.duplicate(true)) == m, "migrating a current save changes nothing")
	# the fixture through the real load path
	var f := FileAccess.open(World.save_path(), FileAccess.WRITE)
	f.store_string(FileAccess.open(fx_path, FileAccess.READ).get_as_text())
	f = null
	check(World.load_game(), "a v1 slot loads")
	player.from_save(World.player_data)
	check(player.armour["body"] == "armour_traveller_coat" and player.level == 4 and player.attributes["might"] == 10,
		"and the Bearer comes back whole, in the coat")
	World.delete_slot(1)

# ------------------------------------------------------------------ 7. outfits
## The body armour worn is the body seen: item id -> model is data
## (items.json armour.model), every outfit is a registered, retargeted rig
## that fights with the shared combat library, and the arms stay in his hands.
func _outfits() -> void:
	print("== outfits: the worn body armour is the Bearer's body")
	var items: Dictionary = DB.table("items")
	var base := String(DB.tuning("player/model", ""))
	var outfits := {}
	for id in items:
		var a: Dictionary = (items[id] as Dictionary).get("armour", {}) if items[id] is Dictionary else {}
		if String(a.get("slot", "")) == "body" and a.has("model"):
			outfits[id] = String(a["model"])
	check(outfits.size() >= 6 and outfits.get("armour_traveller_coat", "") == base,
		"every body piece names its model in items.json (%d); the coat is %s" % [outfits.size(), base])
	for id in outfits:
		var cfg := HumanoidLib.model_cfg(String(outfits[id]))
		var imp := FileAccess.get_file_as_string(String(cfg.get("scene", "")) + ".import")
		check(HumanoidLib.has_model(String(outfits[id])) and bool(cfg.get("clip_sets", false))
			and imp.contains("retarget/bone_map") and imp.contains("mixamo_bone_map"),
			"%s -> %s: registered, retargeted, on the combat clip sets" % [id, outfits[id]])
	player.equip_armour("body", "armour_traveller_coat")
	await ticks(3)
	check(player.vis.model_id == base, "in the coat he is %s" % player.vis.model_id)
	for id in outfits:
		if id == "armour_traveller_coat":
			continue
		player.give_item(id)
		check(player.equip_armour("body", id), "wear %s" % id)
		await ticks(3)
		var v := player.vis
		check(v.model_id == String(outfits[id]) and v.is_humanoid(), "%s: the body is %s" % [id, v.model_id])
		check(v.weapon_mount != null and v.weapon_mount.get_child_count() > 0 and v.weapon_mount.visible
			and v.shield_mount != null and v.shield_mount.get_child_count() > 0
			and (v.weapon_mount.get_parent() as BoneAttachment3D).bone_name == "mixamorig_RightHand",
			"%s: blade in the right hand, board on the arm" % outfits[id])
		check(player.hitbox.get_parent() == v and v.trail != null, "%s: the swing volume and the ribbon ride it" % outfits[id])
		check(v.rig.clip_set == "onehand" and v.rig.qualified("attack_l1") == "sw_light_a"
			and v.rig.qualified("riposte") == "sw_stab" and v.rig.qualified("roll") == "dive_roll",
			"%s: fights with the shared library (%s)" % [outfits[id], v.rig.qualified("attack_l1")])
		check(v.rig.qualified("kneel") == "own/rest" and v.rig.qualified("gourd") == "own/drink",
			"%s: kneels and drinks as the traveller does (%s, %s)" % [outfits[id], v.rig.qualified("kneel"), v.rig.qualified("gourd")])
		var gm := v.mount_gourd()
		check(gm != null and gm.get_child_count() > 0, "%s: the gourd has a hand to go in" % outfits[id])
		v.unmount_gourd(gm)
	check(get_tree().get_nodes_in_group("player").size() <= 1 and player.find_children("Vis*", "PlayerVisual", false, false).size() <= 2,
		"old bodies are not left behind")
	# a two-handed arm keeps the board off the new body
	player.give_item("greatblade")
	player.equip_weapon("greatblade")
	player.equip_armour("body", "armour_saltfell_oilskins")
	await ticks(3)
	check(player.vis.model_id == "bearer_oilskins" and player.vis.rig.clip_set == "twohand"
		and not player.vis.shield_mount.visible, "a greatblade crosses over: two hands, no board")
	player.equip_weapon("hewing_blade")
	await ticks(2)
	# bare, and a piece with no model of its own: the traveller
	player.equip_armour("body", "")
	await ticks(40)
	check(player.vis.model_id == base, "bare, he is the traveller he arrived as (%s)" % player.vis.model_id)
	items["test_sark"] = {"name": "Test Sark", "armour": {"slot": "body", "model": "bearer_nobody", "poise": 1, "absorb": {}, "weight": 1.0}}
	player.give_item("test_sark")
	player.equip_armour("body", "test_sark")
	await ticks(3)
	check(player.vis.model_id == base, "a model that does not exist falls back to %s" % base)
	# the Pack: tried on with it open, changed when it closes
	InventoryUI.open_for(player, "armour")
	await ticks(3)
	var ui := get_tree().get_first_node_in_group("inventory_ui") as InventoryUI
	check(ui != null, "the Pack opens")
	player.equip_armour("body", "armour_collier")
	await ticks(4)
	check(player.armour["body"] == "armour_collier" and player.vis.model_id == base,
		"worn in the Pack: the stats change at once, the body waits (%s)" % player.vis.model_id)
	ui.close()
	await ticks(3)
	check(player.vis.model_id == "bearer_collier", "the Pack closes and he is in the leathers (%s)" % player.vis.model_id)
	# a save puts the outfit back on
	World._save_dir = "user://test_deltas_saves"
	World.active_slot = 1
	DirAccess.make_dir_recursive_absolute(World._save_dir)
	World.delete_slot(1)
	player.equip_armour("body", "armour_fleece")
	await ticks(3)
	World.save_game()
	player.equip_armour("body", "armour_traveller_coat")
	await ticks(3)
	check(player.vis.model_id == base, "back in the coat")
	check(World.load_game(), "the slot loads")
	player.from_save(World.player_data)
	await ticks(3)
	check(player.armour["body"] == "armour_fleece" and player.vis.model_id == "bearer_fleece",
		"loading stands him up in the fleece (%s)" % player.vis.model_id)
	check(player.vis.weapon_mount != null and player.vis.weapon_mount.get_child_count() > 0, "with his blade")
	World.delete_slot(1)
	items.erase("test_sark")
	player.equip_armour("body", "armour_traveller_coat")
	await ticks(3)
