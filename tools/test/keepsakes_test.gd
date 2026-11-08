extends TestBase
## The Keepsakes journal and the slice's two threads (SLICE.md §7), end to
## end through the real pickups, dialogue and services: Ingra's rye
## (meet -> rye from under the byre hound -> talk carrying it -> bog-iron and
## the cheaper Deep Gourd) and Brede's float (meet -> float out of the tide
## wall -> talk carrying it -> the oilskins gift). Lines appear in step
## order, the toast fires, the journal survives a save and load, and the
## release turns both threads to their last line.

var area: Area
var player: Player
var hud: HUD

func _ready() -> void:
	_run.call_deferred()

func _talk(npc_id: String) -> DialogueUI:
	var cfg := DB.npc(npc_id)
	cfg["id"] = npc_id
	var ui := DialogueUI.new(cfg, null)
	get_tree().root.add_child(ui)
	return ui

## Walk the dialogue to its service menu and return the option ids.
func _service_ids(ui: DialogueUI) -> Array:
	while ui._phase == "lines":
		ui.advance()
	return ui._options.map(func(o): return String(o.get("id", "")))

func _choose(ui: DialogueUI, id: String) -> bool:
	var ids := _service_ids(ui)
	var i := ids.find(id)
	if i < 0:
		return false
	ui.choose(i)
	return true

func _close(ui: DialogueUI) -> void:
	if is_instance_valid(ui):
		ui.close()
	await ticks(3)

func _pickup(id: String) -> Pickup:
	for p in area.find_children("*", "Pickup", true, false):
		if (p as Pickup).pickup_id == id:
			return p
	return null

func _journal_lines(thread_id: String) -> Array:
	for t in Keepsakes.journal():
		if t["id"] == thread_id:
			return t["lines"]
	return []

func _expected(thread_id: String, n: int) -> Array:
	for t in Keepsakes.threads_def():
		if t["id"] == thread_id:
			return (t["steps"] as Array).slice(0, n).map(func(s): return String(s["line"]))
	return []

func _save_and_reload() -> void:
	World.save_game()
	World.reset()
	check(Keepsakes.journal().is_empty(), "a reset world remembers nothing")
	check(World.load_game(), "the save loads")
	player.from_save(World.player_data)

func _run() -> void:
	World._save_dir = "user://test_keepsakes"
	World.reset()
	Game.set_warmth(0)
	area = AreaBuilder.build("saltfell_steading")
	add_child(area)
	Game.register_area(area, "saltfell_steading")
	player = Player.new()
	add_child(player)
	player.global_position = AreaBuilder._v3(area.get_meta("def")["start"]["pos"])
	player.sim_active = true
	hud = HUD.new()
	add_child(hud)
	await ticks(10)

	print("== the journal data")
	var defs := Keepsakes.threads_def()
	var ids_def := defs.map(func(t): return String(t["id"]))
	check(ids_def.slice(0, 2) == ["ingra_rye", "brede_float"], "the slice's two threads come first")
	check(_expected("ingra_rye", 1) == ["Ingra is a sack of rye short and blames a dog."], "Ingra's first line is SLICE.md's")
	check(_expected("brede_float", 4)[3] == "Brede is mending the net himself.", "Brede's last line is SLICE.md's")
	check(Keepsakes.journal().is_empty(), "a new journey remembers nothing")
	check(_pickup("rye_sack") != null and _pickup("net_float") != null, "the rye sack and the float are placed in Saltfell")

	print("== Ingra: the first meeting")
	var ui := _talk("steward_ingra")
	await ticks(2)
	check(ui.text_label.text == "You'll be off a boat. You've got the walk. Sit down before you fall down.",
		"Ingra opens with her own first line")
	check(World.flag("ks_ingra_met"), "meeting Ingra starts her thread")
	check(_journal_lines("ingra_rye") == _expected("ingra_rye", 1), "the journal shows her first line")
	check(hud._ks_label.text == "A keepsake is remembered.", "the keepsake toast is raised")
	var ids := _service_ids(ui)
	check(ids.has("buy_mend") and ids.has("deep_gourd") and ids.has("rest_level"),
		"Ingra offers the song, the Deep Gourd and the fire")
	check(not ids.has("deep_gourd_kin"), "no kin's price before the rye")
	var dg: Dictionary = ui._options[ids.find("deep_gourd")]
	check(int(dg["warmth"]) == 300 and ui._option_label(dg).begins_with("Trade for a Deep Gourd"),
		"the Deep Gourd costs 300 at first, label verbatim")
	await _close(ui)

	print("== the rye, under the byre hound")
	var sack := _pickup("rye_sack")
	sack._on_take(player)
	await ticks(2)
	check(int(player.inventory.get("item_rye_sack", 0)) == 1, "the Bearer carries the rye sack")
	check(World.flag("ks_ingra_rye_found"), "finding it is a keepsake step")
	check(_journal_lines("ingra_rye") == _expected("ingra_rye", 2), "two lines, in order")

	print("== save and load mid-thread")
	_save_and_reload()
	check(_journal_lines("ingra_rye") == _expected("ingra_rye", 2), "the journal survives the save")
	check(int(player.inventory.get("item_rye_sack", 0)) == 1, "and so does the sack")

	print("== Ingra again, carrying the sack")
	var iron0 := int(player.inventory.get("bog_iron", 0))
	ui = _talk("steward_ingra")
	await ticks(2)
	check(World.flag("ks_ingra_rye"), "talking to her with the sack closes the errand")
	check(int(player.inventory.get("item_rye_sack", 0)) == 0, "she takes the sack")
	check(int(player.inventory.get("bog_iron", 0)) == iron0 + 1, "the reward: one bog-iron")
	check(ui.text_label.text == "Found it in the byre, did you. Under that dog. Well. He's a good dog.",
		"her lines turn to the dog")
	check(_journal_lines("ingra_rye") == _expected("ingra_rye", 3), "three lines, in order")
	ids = _service_ids(ui)
	check(ids.has("deep_gourd_kin") and not ids.has("deep_gourd"), "the Deep Gourd is now offered at kin's price")
	check(int(ui._options[ids.find("deep_gourd_kin")]["warmth"]) == 150, "150 warmth instead of 300")
	Game.set_warmth(150)
	var gmax := int(player.gourd_max)
	check(_choose(ui, "deep_gourd_kin"), "the trade can be chosen")
	check(int(player.gourd_max) == gmax + 1 and Game.warmth == 0, "the gourd deepens for 150")
	check(ui.text_label.text == "That was my mother's. It leaks if you hold it wrong. Don't hold it wrong.",
		"her line, verbatim")
	await _close(ui)
	ui = _talk("steward_ingra")
	ids = _service_ids(ui)
	check(not ids.has("deep_gourd_kin") and not ids.has("deep_gourd"), "there was only the one gourd")
	Game.set_warmth(200)
	check(_choose(ui, "buy_mend"), "the Mending Song can be learned")
	check(int(player.inventory.get("mend", 0)) == 1, "the Bearer knows the Mending Song")
	check(ui.text_label.text.begins_with("Hum it over the cut, not at it."), "her line on teaching it")
	await _close(ui)
	ui = _talk("steward_ingra")
	check(_choose(ui, "rest_level"), "Sit by the fire")
	await ticks(3)
	var rest: RestUI = null
	for c in get_tree().root.get_children():
		if c is RestUI:
			rest = c
	check(rest != null and rest._phase == "level", "the fire opens the levelling sheet")
	if rest != null:
		check(rest.title_label.text == "Sit by the fire", "titled by the service")
		rest.choose(rest._options.size() - 1)   # Back rises
		await ticks(3)
	check(get_tree().root.get_children().filter(func(c): return c is RestUI).is_empty(), "Back leaves the fire")

	print("== Brede and the float")
	ui = _talk("brede")
	await ticks(2)
	check(ui.text_label.text == "Mind the oars. No, the other way. Thank you.", "Brede opens with his own line")
	check(World.flag("ks_brede_met"), "meeting Brede starts his thread")
	ids = _service_ids(ui)
	check(not ids.has("give_oilskins") and ids.has("buy_bog_iron"), "no oilskins before the float; bog-iron for sale")
	await _close(ui)
	_pickup("net_float")._on_take(player)
	await ticks(2)
	check(World.flag("ks_brede_float_found") and int(player.inventory.get("item_net_float", 0)) == 1,
		"the float is chipped out of the ice")
	ui = _talk("brede")
	await ticks(2)
	check(World.flag("ks_brede_float") and int(player.inventory.get("item_net_float", 0)) == 0,
		"he takes the float")
	check(ui.text_label.text.begins_with("That's it. That's my knot."), "his lines turn to the knot")
	check(_journal_lines("brede_float") == _expected("brede_float", 3), "three lines, in order")
	check(_choose(ui, "give_oilskins"), "the oilskins are offered")
	check(int(player.inventory.get("armour_saltfell_oilskins", 0)) == 1, "the Bearer has Brede's oilskins")
	check(player.owns_armour("armour_saltfell_oilskins"), "the gift is armour the Bearer owns")
	var poise0 := float(player.max_poise)
	check(player.equip_armour("body", "armour_saltfell_oilskins") and player.armour["body"] == "armour_saltfell_oilskins",
		"and can wear on the body")
	check(float(player.max_poise) > poise0 or player.worn_poise() > 0.0, "the oilskins add poise")
	check(ui.text_label.text == "They've been in salt water more than I have. Keep 'em that way round.", "his line, verbatim")
	await _close(ui)
	Game.set_warmth(1000)
	var bought := 0
	for k in 4:
		ui = _talk("brede")
		if _choose(ui, "buy_bog_iron"):
			bought += 1
		await _close(ui)
	check(bought == 3, "bog-iron sells three times and no more (%d)" % bought)

	print("== the release")
	var boss := Enemy.new()
	boss.cfg = DB.enemy("netmender")
	Game.on_boss_slain("saltfell_steading", boss)
	boss.free()
	check(World.flag("ks_netmender_released"), "releasing the Netmender is a story flag")
	ui = _talk("steward_ingra")
	await ticks(2)
	check(ui.text_label.text == "Eleven. Twelve. Eleven.", "Ingra counts the bowls")
	await _close(ui)
	ui = _talk("brede")
	await ticks(2)
	check(ui.text_label.text == "She does this faster. I don't know how she does it.", "Brede mends, badly")
	await _close(ui)
	check(_journal_lines("ingra_rye") == _expected("ingra_rye", 4), "Ingra's thread is whole, in order")
	check(_journal_lines("brede_float") == _expected("brede_float", 4), "Brede's thread is whole, in order")

	print("== save and load the whole journal")
	var before := Keepsakes.journal()
	_save_and_reload()
	check(Keepsakes.journal() == before, "every line survives the save, in order")
	check(int(player.inventory.get("armour_saltfell_oilskins", 0)) == 1, "the oilskins survive too")
	check(String(player.armour.get("body", "")) == "armour_saltfell_oilskins", "still worn after the load")

	print("== the Keepsakes leaf")
	InventoryUI.open_for(player, "keepsakes")
	await ticks(3)
	var inv: InventoryUI = get_tree().get_first_node_in_group("inventory_ui")
	check(inv != null and inv._tab == "keepsakes", "J's leaf opens in the Pack")
	var shown := []
	if inv != null:
		for l in inv._list.find_children("*", "Label", true, false):
			shown.append((l as Label).text)
	var want := ["Ingra's rye"] + _expected("ingra_rye", 4) + ["Brede's float"] + _expected("brede_float", 4)
	check(shown == want, "the leaf shows each thread's title and lines in order")
	check(InventoryUI.LEAVES.map(func(l): return l["key"]) == ["pack", "songs", "armour", "keepsakes"], "leaves come from the registry")
	if inv != null:
		inv.close()
	await ticks(3)

	DirAccess.remove_absolute(World.save_path())
	finish()
