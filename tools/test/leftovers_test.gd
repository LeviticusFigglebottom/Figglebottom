extends LeftoversBase
## What a foe leaves behind. For every enemy id in enemies.json: it uses every
## move it has (each one skipped to its strike, so that whatever the move
## raises, throws, pours or summons is standing), a telegraphed move is left
## half wound up, and then it
##   - dies in the fight (a Holdfast is released: all three phases first),
##   - is reset mid-fight by its spawner's respawn() (what a rest and the
##     Bearer's death both call),
## and the scene is counted: every node that was not there before must be
## gone, except what the lore says a released Holdfast leaves (SLICE.md 6,
## LOWE 8, KETTLE 9, TARNHALL 9, THORNWOLD 9, REACH 9, COLDWELL 9). Then the
## real paths, on the long-lived things (bay walls, the ice band, the ring,
## pools, cairns): the Bearer dies mid-fight, and a rest turns RIME to THAW.
## Every regular foe is also watched as it shatters: each mesh of it that is
## drawn (the Oarsman's ice oar) must go with the body, not hang there whole.

const STEP := 34.0          # metres between pens: nobody sees the next one
const LEAVINGS := {         # what the lore leaves, beside the drops in the data
	"ice_cutter": ["sealed ice"],
	"hedgelayer": ["laid gate"],
}

var area: Area
var hearth: Hearthstone
var pens: Dictionary = {}       # id -> Spawner (dies / is released here)
var reset_pens: Dictionary = {} # id -> Spawner (is reset here)
var regulars: Array = []
var bosses: Array = []
var stills: Array = []
var _undrawn: Dictionary = {}   # id -> meshes that never shattered
var _oar_gap := -1.0

func _ready() -> void:
	_run.call_deferred()

# ------------------------------------------------------------------ the world
func _build_world() -> void:
	World.reset()
	area = Area.new()
	area.area_id = "lo_test"
	add_child(area)
	Game.register_area(area, "lo_test")
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 << (RH.L_WORLD_BASE - 1)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(900, 1, 900)
	cs.shape = box
	cs.position.y = -0.5
	floor_body.add_child(cs)
	area.attach(floor_body, "base")
	World.set_area_state("lo_test", RH.WState.RIME)
	StateDirector.snap(area, RH.WState.RIME)
	hearth = Hearthstone.new()
	hearth.hearth_id = "lo_hearth"
	hearth.area = area
	area.base.add_child(hearth)
	hearth.position = Vector3(-60, 0, -60)
	World.last_hearth = {"area": "lo_test", "hearth": "lo_hearth"}
	player = Player.new()
	add_child(player)
	player.position = Vector3(-60, 0.15, -56)
	player.sim_active = true
	player.invulnerable = true   # (holds and hauls still take him; blows do not)
	hud = HUD.new()
	add_child(hud)

	var table: Dictionary = DB.table("enemies")
	for id in table:
		if not (table[id] is Dictionary) or not (table[id] as Dictionary).has("attacks"):
			continue
		if bool((table[id] as Dictionary).get("is_boss", false)):
			bosses.append(String(id))
		else:
			regulars.append(String(id))
	# (the Leadvoice's release shatters every ridge in the scene: she goes
	# first, so that it cannot hide what another foe left standing)
	bosses.erase("leadvoice")
	bosses.push_front("leadvoice")
	var k := 0
	for id in bosses + regulars:
		pens[id] = _pen(id, Vector3((k % 8) * STEP, 0.1, (k / 8) * STEP), bosses.has(id))
		reset_pens[id] = _pen(id, Vector3((k % 8) * STEP, 0.1, (k / 8) * STEP + 200.0), false)
		k += 1

func _pen(id: String, at: Vector3, once: bool) -> Spawner:
	var s := Spawner.new()
	s.name = ("Pen_" if once or not bosses.has(id) else "ResetPen_") + id
	s.enemy_id = id
	s.dead_once = once
	s.area_id = "lo_test"
	s.spawn_flag = "slain_" + id
	area.rime_layer.add_child(s)
	s.position = at
	return s

## White stills at a table by the Host (the area lays these in RIME): the
## guests he raises stand up out of them.
func _lay_seats(by: Spawner) -> void:
	for i in 4:
		var s: Node3D = (load("res://assets/models/enemies/feast_guest.glb") as PackedScene).instantiate()
		area.rime_layer.add_child(s)
		s.global_position = by.global_position + Vector3(-4.5 + i * 3.0, 0.0, -6.0)
		stills.append(s)

## How far a mesh has shattered: the death_diss of the material it is
## actually drawn with (an override wins over the surfaces'), -1 if that
## material cannot shatter at all.
func _diss(mi: MeshInstance3D) -> float:
	var m: Material = mi.material_override
	if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
		m = mi.get_surface_override_material(0)
		if m == null:
			m = mi.mesh.surface_get_material(0)
	if not (m is ShaderMaterial) or not _can_shatter((m as ShaderMaterial).shader):
		return -1.0
	var v = (m as ShaderMaterial).get_shader_parameter("death_diss")
	return float(v) if v != null else 0.0

var _shatters: Dictionary = {}   # shader -> has the death_diss uniform

func _can_shatter(sh: Shader) -> bool:
	if sh == null:
		return false
	if not _shatters.has(sh):
		var has := false
		for u in sh.get_shader_uniform_list():
			has = has or String(u.get("name", "")) == "death_diss"
		_shatters[sh] = has
	return _shatters[sh]

## Watch a body from its death to its going: every mesh of it that is drawn.
func _watch(e: Enemy) -> void:
	var id := e.id
	var seen := {}
	var since := 0
	while is_instance_valid(e) and e.is_inside_tree():
		for n in e.vis.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var key := String(e.get_path_to(mi))
			seen[key] = maxf(float(seen.get(key, -1.0)), _diss(mi))
		since += 2
		if e is Oarsman and since == 60:
			# a second into the fall: the oar is still in the hands
			var o := e as Oarsman
			var x := o.oar_xform()
			_oar_gap = o.oar.global_position.distance_to(x.origin - x.basis.y * float(o.get("_oar_grip")))
		await _t(2)
	var whole: Array = []
	for key in seen:
		if float(seen[key]) < 0.5:
			whole.append(String(key).get_file())
	_undrawn[id] = whole

# ------------------------------------------------------------------ the run
func _run() -> void:
	_build_world()
	await _t(12)
	for id in pens:
		for s in [pens[id], reset_pens[id]]:
			var e: Enemy = (s as Spawner).current
			if e != null:
				e.set_physics_process(false)   # each wakes at its turn
	_lay_seats(pens["host"])
	_lay_seats(reset_pens["host"])
	await _t(3)
	check(pens.size() == regulars.size() + bosses.size() and bosses.size() == 7,
		"a pen for every enemy id: %d foes, %d Holdfasts" % [regulars.size(), bosses.size()])
	await _dies_in_the_fight()
	await _reset_mid_fight()
	await _the_bearer_dies()
	await _a_rest_turns_the_world()
	Engine.time_scale = 1.0
	finish()

# -- (a) dies in the fight, (b) is released
func _dies_in_the_fight() -> void:
	print("== every foe uses every move, then dies; every Holdfast is released")
	var before := _snapshot()
	var holdfasts := {}
	var at_once := {}   # id -> what it made that did not go with it (named then: it may be gone by the end)
	for id in bosses:
		var b: Enemy = (pens[id] as Spawner).current
		holdfasts[id] = b
		await _fight_boss(b, 3)
		await _release(b)
		if not b.dead:
			check(false, "%s was released" % id)
		_park(b)
		await _secs(3.5)   # (a hedge unlays stem by stem; a hole greys over)
		at_once[id] = _list(_made_left(before, pens[id], holdfasts))
	for id in regulars:
		var e: Enemy = (pens[id] as Spawner).current
		await _fight(e)
		e.take_hit(DamagePacket.new(1e6, 0, player))
		_watch(e)
		_park(e)
		await _secs(1.6)   # (a hole greys over, a pool goes grey)
		at_once[id] = _list(_made_left(before, pens[id], holdfasts))
	for id in bosses + regulars:
		check(at_once[id] == "nothing", "%s: what it made went with it (%s)" % [id, at_once[id]])
	player.global_position = hearth.global_position + Vector3(0, 0.15, 4)
	await _secs(7.5)   # the longest linger and dissolve, a wall unlaid, a hole frozen over
	check(player.input_enabled, "nothing still holds the Bearer")
	var left := {}      # pen -> what stands in it that should not
	var leavings := {}  # label -> count
	for n in _new_roots(before):
		var label := _leaving(n as Node, holdfasts)
		if label != "":
			leavings[label] = int(leavings.get(label, 0)) + 1
			continue
		var pen := _pen_of(n)
		var key := pen.enemy_id if pen != null else "(the area)"
		if not left.has(key):
			left[key] = []
		(left[key] as Array).append(n)
	for id in regulars:
		var pen: Spawner = pens[id]
		var body: Array = [pen.current] if pen.current != null and is_instance_valid(pen.current) else []
		check(body.is_empty() and not left.has(id),
			"%s: dead, nothing of it is left (%s)" % [id, _list(body + (left.get(id, []) as Array))])
		var whole: Array = _undrawn.get(id, ["(it never went)"])
		check(whole.is_empty(), "%s: every mesh of it shattered with the body (whole to the end: %s)"
				% [id, ", ".join(whole) if not whole.is_empty() else "none"])
	check(_oar_gap >= 0.0 and _oar_gap < 0.08,
		"the Oarsman's oar stays in his hands as he falls (%.2f m from them a second in)" % _oar_gap)
	for id in bosses:
		var b: Enemy = holdfasts[id]
		var here := is_instance_valid(b) and b.is_inside_tree() and b.vis.is_visible_in_tree()
		check(here and not left.has(id), "%s: released and still there, with nothing it made (%s)"
				% [id, _list(left.get(id, []) as Array)])
		var want: Array = []
		for dk in ["release_drop", "release_drop2"]:
			if b.cfg.has(dk):
				want.append("pickup " + String((b.cfg[dk] as Dictionary).get("pickup_id", "")))
		want.append_array(LEAVINGS.get(id, []))
		var missing: Array = want.filter(func(w): return not leavings.has(w))
		check(missing.is_empty(), "%s leaves what the lore says: %s (missing: %s)"
				% [id, ", ".join(want), ", ".join(missing) if not missing.is_empty() else "none"])
	check(not left.has("(the area)"), "nothing else was put into the area (%s)" % _list(left.get("(the area)", []) as Array))
	var host := holdfasts["host"] as Host
	check(host.filled.size() > 0 and int(leavings.get("filled horn", 0)) == host.filled.size()
			and int(leavings.get("seated guest", 0)) == host.guests.size(),
		"the Host's guests sit down where they are, their horns full (%d guests, %d horns)"
			% [int(leavings.get("seated guest", 0)), int(leavings.get("filled horn", 0))])
	_released = holdfasts
	_release_leavings = leavings

var _released: Dictionary = {}
var _release_leavings: Dictionary = {}

## What stands in a pen that its foe made and that is not on its way out
## (the summoned, falling with it, are) nor one of the lore's leavings.
func _made_left(before: Dictionary, pen: Spawner, holdfasts: Dictionary) -> Array:
	var out: Array = []
	for n in _new_roots(before):
		if _pen_of(n) == pen and _leaving(n, holdfasts) == "" and not (n is Enemy and (n as Enemy).dead):
			out.append(n)
	return out

## What the lore leaves after a release; "" for anything else.
func _leaving(n: Node, holdfasts: Dictionary) -> String:
	if n is Pickup:
		return "pickup " + (n as Pickup).pickup_id
	if n.is_in_group("sealed_ice"):
		return "sealed ice"
	if n.has_meta("laid"):
		return "laid gate"
	var host := holdfasts.get("host") as Host
	if host != null and is_instance_valid(host):
		if host.filled.has(n):
			return "filled horn"
		if host.guests.has(n) and not (n as Enemy).is_physics_processing():
			return "seated guest"
	return ""

# -- (c) reset by the spawner: a rest, or the Bearer's death
func _reset_mid_fight() -> void:
	print("== every foe is reset mid-fight (its spawner's respawn)")
	for id in bosses + regulars:
		var pen: Spawner = reset_pens[id]
		var e: Enemy = pen.current
		var before := _snapshot()
		if bosses.has(id):
			await _fight_boss(e, 2)
		else:
			await _fight(e)
		pen.respawn()
		await _secs(1.2)   # (a flash or a streak plays out; a tell would not)
		var left: Array = _new_roots(before).filter(func(n): return n != pen.current)
		var fresh := pen.current != null and is_instance_valid(pen.current) and pen.current != e and not pen.current.dead
		check(fresh and left.is_empty(), "%s: reset whole, nothing of the old fight is left (%s)" % [id, _list(left)])
		pen.current.set_physics_process(false)
		if id == "host":
			check(stills.all(func(s): return (s as Node3D).visible and not (s as Node3D).has_meta("risen")),
				"the Host's guests are back in their places")
	check(player.input_enabled, "nothing still holds the Bearer")

## The fights whose things last longest: bay walls and the ice band (for
## good), the ring of thorn, a pool, cairns, a hole in the ice.
const LASTING := ["turfwright", "ice_cutter", "hedgelayer", "host", "netmender", "cairn_carrier", "ice_fisher", "oarsman"]

func _fight_lasting() -> void:
	for id in LASTING:
		var e: Enemy = (reset_pens[id] as Spawner).current
		if bosses.has(id):
			await _fight_boss(e, 2)
		else:
			await _fight(e)

func _currents() -> Array:
	var out: Array = []
	for id in reset_pens:
		out.append((reset_pens[id] as Spawner).current)
	for id in pens:
		out.append((pens[id] as Spawner).current)
	return out

# -- (e) the Bearer dies mid-fight
func _the_bearer_dies() -> void:
	print("== the Bearer dies mid-fight: the fight is put away with the reset")
	var before := _snapshot()
	await _fight_lasting()
	var old: Array = LASTING.map(func(id): return (reset_pens[id] as Spawner).current)
	player.invulnerable = false
	player.take_hit(DamagePacket.new(99999, 0, old[0]))
	check(player.dead, "the Bearer dies")
	var w := 0
	while player.dead and w < 900:
		w += 10
		await _t(10)
	await _secs(1.2)
	check(not player.dead, "and stands again at the hearth")
	player.invulnerable = true
	var cur := _currents()
	var left: Array = _new_roots(before).filter(func(n): return not cur.has(n) and not (n is Breathmark))
	var fresh := true
	for i in LASTING.size():
		var now: Enemy = (reset_pens[LASTING[i]] as Spawner).current
		fresh = fresh and now != null and is_instance_valid(now) and now != old[i] and not now.dead
		now.set_physics_process(false)
	check(fresh and left.is_empty(), "every foe is whole again and nothing of the old fights is left (%s)" % _list(left))

# -- (d) a rest, and the world turned to THAW and back
func _a_rest_turns_the_world() -> void:
	print("== a rest turns RIME to THAW: the fight is put away, the released keep what they left")
	var before := _snapshot()
	await _fight_lasting()
	player.global_position = hearth.respawn_point()
	await _t(4)
	Game.hearth_flow(hearth, player, "toggle")
	var w := 0
	while not StateDirector.transitioning and w < 400:
		w += 5
		await _t(5)
	while StateDirector.transitioning and w < 3000:
		w += 10
		await _t(10)
	await _secs(4.5)   # (the wave's own particles ride out)
	check(World.get_area_state("lo_test") == RH.WState.THAW, "the memory is warm")
	var cur := _currents()
	var left: Array = _new_roots(before).filter(func(n): return not cur.has(n))
	check(left.is_empty(), "in THAW nothing of the fights is left, in sight or out of it (%s)" % _list(left))
	StateDirector.snap(area, RH.WState.RIME)
	await _t(10)
	cur = _currents()
	left = _new_roots(before).filter(func(n): return not cur.has(n))
	check(left.is_empty(), "and nothing comes back with the RIME (%s)" % _list(left))
	for id in bosses:
		var b: Enemy = _released[id]
		check(is_instance_valid(b) and (pens[id] as Spawner).current == b and b.dead and b.vis.is_visible_in_tree(),
			"%s is still where it was released" % id)
	var kept := true
	for n in area.find_children("*", "Pickup", true, false):
		kept = kept and (n as Node3D).is_visible_in_tree()
	var drops := area.find_children("*", "Pickup", true, false).size()
	var want := 0
	for label in _release_leavings:
		if String(label).begins_with("pickup "):
			want += int(_release_leavings[label])
	check(kept and drops == want, "what they left is all still there (%d of %d drops)" % [drops, want])
