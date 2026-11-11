extends FullgameBase
## Kettle Fjord, end to end (KETTLE.md), from the save the Lowe's walk ends
## on: down the Kettle Road through the seam, the Landing Ice and the jetties
## in THAW, Ivo, Halla and Sten at the Fish-Houses, the first rest (RIME),
## the ice walked wall to wall (the harpoon, the north shore, the ladle, the
## cord, the auger), one death and its Breathmark, the frost veil and the
## Ice-Cutter (his AI runs all three phases; only the Bearer's blows are
## scaled), the release (the hole seals, the mitten in the new ice, the
## Outsong), Old Pell and Ivo at the fish-kettle in THAW, both Keepsakes
## threads closed, and a last rest at the Fish-Houses.

const HS_LANDING := "hs_landing_ice"
const HS_HOUSES := "hs_fish_houses"
const BOSS := "ice_cutter"

const IVO_FIRST := [
	"Hold that one. Not by the collar, she bites.",
	"Grandfather says the ice isn't made yet. It's made. I walked on it this morning, out past the houses.",
	"The healer's across at the far landing. Somebody's got to fetch her. Everybody keeps saying somebody.",
	"Lost a mitten in the dog-pen. This one's Grandfather's. Don't tell him, he'll have me looking for it till dark.",
]
const HALLA_FIRST := [
	"If you're buying, I've salt, needles and a little iron. If you're selling, I've no room.",
	"Halla. That's my boat, and that's my cord, and every knot on it's mine.",
	"Sold the whole catch to the Tarnhall people for their feast. Forty barrels. They'll be eating it till the Melt.",
	"We go on the morning tide. Sten'll be better at sea. It's the land air that's doing it.",
]
const STEN_FIRST := [
	"Sorry. Don't mind me. It's the crossing, it gets in your chest.",
	"Sten. I row for Halla. When she lets me. She says I cough out of time.",
	"We'll be gone in the morning. Nobody here needs to catch anything off me.",
	"I'd shake your hand. Best not.",
]
const KETTLE_TALK := [
	["pell", "Stir it from the bottom. It catches."],
	["ivo", "I am stirring it from the bottom."],
	["pell", "Then from lower down."],
	["ivo", "The ice'll be made by the new moon. You said."],
	["pell", "I said maybe. Eat your supper."],
	["ivo", "Fish again."],
	["pell", "Sixty years. I only know the one way."],
]
const IVO_THREAD := [
	"Ivo is harnessing the dogs and says he is not going anywhere.",
	"The supper was still on the hook. The ladle was frozen standing up in it.",
	"The mitten was in the ice where the hole had been, palm up.",
	"Ivo put the mitten on. Both of his are his own now.",
]
const HALLA_THREAD := [
	"Halla keeps her cargo on a knot-cord and says every knot on it is hers.",
	"Halla's cord was tied to the mooring post. There was a knot at the end in another hand.",
	"Halla read the last knot and called Sten over, and then told him to stay where he was.",
	"Halla has put Sten by the fire in the end house.",
]

var cards: Array = []          # every title card raised, in order
var hole := Vector3.INF        # the Breathing Hole's centre
var _planned_falls := 0

func _init() -> void:
	region = "kettle"
	aid = "kettle_fjord"
	start_fixture = "fullgame_after_lowe"

func _on_area_title(t: String) -> void:
	cards.append(t)

func _on_title_card(t: String, _hold: float) -> void:
	cards.append(t)

# ------------------------------------------------------------ region helpers
func _def() -> Dictionary:
	return area.get_meta("def")

func _spec(list: String, id: String) -> Dictionary:
	for s in _def().get(list, []):
		if String(s.get("id", "")) == id:
			return s
	return {}

func _reaches(p: PackedVector3Array, to: Vector3, tol := 2.5) -> bool:
	return p.size() > 1 and Vector2(p[p.size() - 1].x - to.x, p[p.size() - 1].z - to.z).length() < tol

func _path_len(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i].distance_to(p[i - 1])
	return l

func _thin_volumes(live_only := true) -> Array:
	var out := []
	for h in area.find_children("*", "HazardVolume", true, false):
		var hv := h as HazardVolume
		if hv.kind != "thin" or hv.is_queued_for_deletion() or hv.get_parent() is BrokenIce:
			continue
		if live_only and not hv.can_process():
			continue
		out.append(hv)
	return out

func _hole_hazards() -> int:
	var n := 0
	for hv in _thin_volumes(false):
		if Vector2(hv.global_position.x - hole.x, hv.global_position.z - hole.z).length() < 2.0:
			n += 1
	return n

func _open_ice() -> Array:
	return get_tree().get_nodes_in_group("broken_ice").filter(
			func(b): return is_instance_valid(b) and (b as BrokenIce).is_open())

func _alive() -> void:
	if player.dead:
		await _until(func(): return not player.dead, 12.0)
		await ticks(40)
		area = Game.current_area
		_scan_thin()

## Take a pickup, coming back for it if the frost-taken win a round.
func _take_alive(pickup_id: String, prompt_prefix: String, tries := 3) -> bool:
	for attempt in tries:
		await _alive()
		if _pickup(pickup_id) == null:
			return true
		if await _take(pickup_id, prompt_prefix, true) and not player.dead and _pickup(pickup_id) == null:
			return true
		await ticks(10)
		if not player.dead and (_pickup(pickup_id) == null or _pickup(pickup_id).is_queued_for_deletion()):
			return true
	return false

func _rest_alive(hearth_id: String, option := "rest", tries := 3) -> bool:
	for attempt in tries:
		await _alive()
		if await _rest(hearth_id, option) and not player.dead:
			return true
	return false

func _talk_lines(npc_id: String) -> Array:
	var ui := await _talk(npc_id)
	if ui == null:
		return []
	var lines: Array = await _lines_of(ui)
	await _leave(ui)
	return lines

## Talk through to the menu and choose a service. Returns the line answered.
func _service(npc_id: String, service_id: String) -> String:
	var ui := await _talk(npc_id)
	if ui == null:
		return ""
	await _lines_of(ui)
	var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
	var said := ""
	if ids.has(service_id):
		ui.choose(ids.find(service_id))
		await ticks(3)
		said = ui.text_label.text
	else:
		print("  (%s offers %s, not %s)" % [npc_id, str(ids), service_id])
	await _leave(ui)
	return said

# ------------------------------------------------- the ice: a bot that looks
## Thin ice the fjord itself carries (crevasses, the cut holes, the Breathing
## Hole): rectangles on the ice the Bearer keeps off, as a player would.
var _thin: Array = []
## Ice about to break (a committed Cut a hole, Drill down or Ring cut):
## [centre, inner, outer], rebuilt every step of a fight.
var _tells: Array = []
var _veer := 1.0

func _scan_thin() -> void:
	_thin.clear()
	if Game.current_area_id != aid:
		return
	for hv in _thin_volumes(false):
		_thin.append(Rect2(hv.global_position.x - hv.size.x * 0.5, hv.global_position.z - hv.size.z * 0.5,
				hv.size.x, hv.size.z))

func _on_ice() -> bool:
	return Game.current_area_id == aid and World.get_area_state(aid) == RH.WState.RIME

func _scan_tells() -> void:
	_tells.clear()
	for e in _awake_foes():
		var f := e as Enemy
		if f.state != Enemy.ES.ATTACK or String(f._atk.get("type", "")) != "break_ice":
			continue
		var ic: Dictionary = f._atk.get("ice", {})
		if String(ic.get("shape", "disc")) != "ring" and f.state_t < float(f._atk.get("windup", 1.0)) * 0.6 / f._speed_mult():
			continue   # (a disc's aim still follows the Bearer; a ring is cut round the body)
		_tells.append([f._ice_centre(), float(ic.get("inner", 0.0)), float(ic.get("radius", 2.0))])

## A foe leaning on its auger or its picks to break the ice under the Bearer
## (Cut a hole, Drill down): the circle follows him until the aim commits.
func _ice_threat() -> Enemy:
	for e in _awake_foes():
		var f := e as Enemy
		if f.state != Enemy.ES.ATTACK or String(f._atk.get("type", "")) != "break_ice" or f.target != player:
			continue
		if String((f._atk.get("ice", {}) as Dictionary).get("shape", "disc")) == "ring":
			continue
		if f.state_t <= float(f._atk.get("windup", 1.0)) / f._speed_mult() + 0.1:
			return f
	return null

## Whether a point on the ice is, or is about to be, open water.
func _wet(p: Vector3, pad := 0.5) -> bool:
	if not _on_ice() or p.y > 1.2:
		return false   # (the decks and the shelf stand over it)
	var q := Vector2(p.x, p.z)
	for r in _thin:
		if (r as Rect2).grow(pad).has_point(q):
			return true
	for b in get_tree().get_nodes_in_group("broken_ice"):
		var bi := b as BrokenIce
		if not is_instance_valid(bi) or not bi.is_open():
			continue
		var d := Vector2(p.x - bi.global_position.x, p.z - bi.global_position.z).length()
		if d <= bi.radius + pad and d >= bi.inner - pad:
			return true
	for t in _tells:
		var d2 := Vector2(p.x - t[0].x, p.z - t[0].z).length()
		if d2 <= float(t[2]) + pad and d2 >= float(t[1]) - pad:
			return true
	return false

## The heading nearest `want` that keeps the Bearer off open water; on it
## already, the shortest way off.
func _safe_heading(want: Vector3) -> Vector3:
	var p := player.global_position
	want.y = 0
	want = want.normalized() if want.length() > 0.01 else Vector3.ZERO
	if _wet(p, 0.25):
		var best := want
		var bd := 99.0
		for i in 16:
			var d := Vector3(sin(TAU * i / 16.0), 0, cos(TAU * i / 16.0))
			for s in [0.6, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0]:
				if not _wet(p + d * s, 0.4):
					var cost: float = s - 0.4 * d.dot(want)
					if cost < bd:
						bd = cost
						best = d
					break
		return best
	if want == Vector3.ZERO:
		return want
	for a in [0.0, 30.0, 60.0, 90.0, 120.0, 150.0]:
		for sgn in [_veer, -_veer]:
			var d := want.rotated(Vector3.UP, deg_to_rad(a * sgn))
			if not _wet(p + d * 0.7) and not _wet(p + d * 1.4):
				if a > 0.0:
					_veer = sgn
				return d
			if a == 0.0:
				break
	return Vector3.ZERO

func _go(want: Vector3, sprint := false) -> void:
	var h := _safe_heading(want)
	player.sim_sprint = sprint
	if h == Vector3.ZERO:
		player.sim_move = Vector3.ZERO
		return
	player.cam.yaw = atan2(-h.x, -h.z)
	player.sim_move = Vector3(0, 0, -1)

## Ground under a point within a step of the Bearer's feet (a jetty's edge
## and the shelf's lip have none: open water in THAW, a drop in RIME).
func _footing(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, player.global_position.y + 1.0, p.z),
			Vector3(p.x, player.global_position.y - 0.9, p.z), player.collision_mask)
	q.exclude = [player.get_rid()]
	return not area.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## A blind sidestep here can end in the fjord (off a jetty in THAW, into a
## crevasse in RIME): step to the side that has ground, or not at all.
func _sidestep() -> void:
	if Game.current_area_id != aid:
		await super._sidestep()
		return
	_side = -_side if randf() < 0.3 else _side
	var yaw := player.cam.yaw
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var p := player.global_position
	for attempt in 2:
		var a := p + right * _side * 1.2
		var b := p + right * _side * 2.4
		if _footing(a) and _footing(b) and not _wet(a) and not _wet(b):
			player.sim_move = Vector3(_side, 0, 0.2)
			await ticks(36)
			_stuck_n = 0
			return
		_side = -_side
	_stuck_n = 0
	await ticks(6)

# ------------------------------------------------------------ the plank ways
## The navmesh climbs onto a deck from the shingle beside it (half a metre);
## the Bearer cannot, and a player would not try: he goes to the foot of the
## planks. These read the decks out of the area data (edges.state_floors).
func _floors() -> Array:
	return (_def()["edges"] as Dictionary)["state_floors"]

## The jetty round the first spur: [foot on the Landing side, the corner, the
## far corner, foot on the Fish-Houses side].
func _jetty() -> Array:
	var f: Array = _floors()
	var out_leg: Dictionary = f[0]
	var along: Dictionary = f[1]
	var back: Dictionary = f[2]
	var xa := (float(out_leg["min"][0]) + float(out_leg["max"][0])) * 0.5
	var xb := (float(back["min"][0]) + float(back["max"][0])) * 0.5
	var zo := (float(along["min"][1]) + float(along["max"][1])) * 0.5
	var y := float(out_leg["y"])
	return [Vector3(xa, y, float(out_leg["max"][1]) + 1.2), Vector3(xa, y, zo), Vector3(xb, y, zo),
		Vector3(xb, y, float(back["max"][1]) + 1.2)]

func _walk_jetty(to_houses: bool) -> bool:
	var pts := _jetty()
	if not to_houses:
		pts.reverse()
	if not await _walk_path(pts[0], 6000, false):
		return false
	for k in range(1, pts.size()):
		if not await _walk_to(pts[k], 1200, 0.5, false):
			print("  (jetty: stopped at %s on the way to %s)" % [str(player.global_position.snapped(Vector3.ONE * 0.1)), str(pts[k])])
			return false
	return not player.dead

## A fish-house's walk: [the foot on the shingle, a step onto the planks, the door].
func _house_walk(i: int) -> Array:
	var b: Dictionary = (_def()["edges"]["buildings"] as Array)[i]
	var door := Vector3(float(b["doors"][0][0]), float(b["y"]), float(b["doors"][0][1]))
	for f in _floors():
		var w := float(f["max"][0]) - float(f["min"][0])
		if String(f["tag"]) == "base" and w < 3.0 and door.x > float(f["min"][0]) and door.x < float(f["max"][0]) \
				and float(f["min"][1]) < door.z + 1.0 and float(f["max"][1]) > door.z:
			var cx := (float(f["min"][0]) + float(f["max"][0])) * 0.5
			return [Vector3(cx, door.y, float(f["max"][1]) + 1.2), Vector3(cx, door.y, float(f["max"][1]) - 1.2), door]
	return []

## Take what lies inside a fish-house: up its walk from the shore and in at
## the door, on foot, coming back for it if the frost-taken win a round.
var _house_floor_y := {}
func _take_in_house(pickup_id: String, prompt_prefix: String, house_i: int) -> bool:
	var wk := _house_walk(house_i)
	if wk.is_empty():
		print("  (house %d has no walk to its door)" % house_i)
		return false
	for attempt in 3:
		await _alive()
		var pk := _pickup(pickup_id)
		if pk == null:
			return true
		await _walk_path(wk[0], 6000, true)
		await _fight(12.0, 60.0)
		if player.dead:
			continue
		var ok := await _walk_to(wk[0], 400, 0.5, true)
		ok = ok and await _walk_to(wk[1], 400, 0.5, true)
		ok = ok and await _walk_to(wk[2], 900, 0.5, true)
		if not ok or player.dead:
			print("  (house %d, try %d: stopped at %s)" % [house_i, attempt + 1, str(player.global_position.snapped(Vector3.ONE * 0.1))])
			continue
		await _walk_path(pk.global_position, 1200, true)
		await _walk_to(pk.global_position, 400, 0.6, true)
		await _settle()
		if player.dead:
			continue
		var it := player.nearest_interactable()
		if it == null or not it.prompt.begins_with(prompt_prefix):
			print("  (%s: at %s, prompt is %s)" % [pickup_id, str(player.global_position.snapped(Vector3.ONE * 0.1)), it.prompt if it != null else "nothing"])
			continue
		_house_floor_y[pickup_id] = player.global_position.y
		player.try_interact()
		await ticks(6)
		return true
	return false

## The melee bot of the base, on ice: the same close-in, light swings, gourd
## and rolls, but it watches the floor. It keeps off the crevasses and the
## Breathing Hole, steps off ice that glows or has broken, struggles against
## a hook, and stands off while the Ice-Cutter cannot be hurt.
var boss_holes_seen := 0
var boss_band_seen := false
var boss_moves_seen := {}
func _fight(radius := 14.0, max_s := 90.0, boss := false) -> bool:
	if not _on_ice():
		return await super._fight(radius, max_s, boss)
	var n := 0
	var k := 0
	while n < int(max_s * 60.0):
		if player.dead:
			player.sim_sprint = false
			return false
		var foe: Enemy = _foe(BOSS) if boss else _foe_near(radius)
		if foe == null:
			player.sim_move = Vector3.ZERO
			player.sim_sprint = false
			return true
		k += 1
		_scan_tells()
		for e in _awake_foes():
			var h: GrabHold = (e as Enemy).hook_hold
			if h != null and is_instance_valid(h) and k % 2 == 0:
				h.mash()   # caught on a hook: struggle
		if foe is IceCutter:
			var ic := foe as IceCutter
			boss_holes_seen = maxi(boss_holes_seen, ic.open_holes())
			boss_band_seen = boss_band_seen or (ic.band != null and is_instance_valid(ic.band) and ic.band.is_open())
			if ic.state == Enemy.ES.ATTACK or ic.state == Enemy.ES.HOLD:
				boss_moves_seen[String(ic._atk.get("id", "?"))] = true
		var p := player.global_position
		var d := foe.global_position - p
		d.y = 0
		var dist := d.length()
		var dn := d.normalized() if dist > 0.01 else Vector3.FORWARD
		var reach := 2.0 if not boss else 3.2   # (a Sealer stands off at 2.4 m: come inside it)
		var low := player.hp < player.max_hp * 0.4 and player.gourds > 0
		player.sim_sprint = false
		var threat := _ice_threat()
		if _wet(p, 0.25):
			_go(dn, true)   # off it, now
		elif threat != null:
			# the ice under the Bearer is about to go, and the break staggers
			# whoever is on it: a walk started when it opens is too late. Keep
			# running, round him, until it has opened behind.
			var off := p - threat.global_position
			off.y = 0
			var tang := Vector3(-off.z, 0, off.x).normalized() * _veer
			var radial := off.normalized() * (0.6 if off.length() < 5.0 else (-0.4 if off.length() > 8.0 else 0.0))
			_go(tang + radial, true)
		elif boss and foe is IceCutter and _band_between(foe as IceCutter):
			await _cross_band(foe as IceCutter)
			n += 40
		elif low and dist > 4.0:
			player.sim_move = Vector3.ZERO
			player.cam.yaw = atan2(-dn.x, -dn.z)
			player.try_gourd()
		elif low:
			_go(-dn)   # back off to drink
		elif foe.state == Enemy.ES.TRANSITION and boss and (foe as IceCutter).stood:
			# he cannot be hurt while he cuts the ring: stand off, between
			# the hole and where the band will open
			if dist < 4.5:
				_go(-dn)
			else:
				player.sim_move = Vector3.ZERO
		elif dist > reach or absf(foe.global_position.y - p.y) > 1.2:
			var wp := dn
			if not boss:
				# close in along the navmesh: the ridges and the jetty posts
				var route := _path(p, foe.global_position)
				if route.size() > 2:
					var w := route[1]
					if Vector2(w.x - p.x, w.z - p.z).length() < 0.5:
						w = route[2]
					wp = w - p
			_go(wp)
		else:
			player.cam.yaw = atan2(-dn.x, -dn.z)
			var right := Vector3(-dn.z, 0, dn.x)
			if _wet(p + dn * 1.2, 0.3):
				_go(right * _veer)   # he stands over water: come round
			else:
				# hold a sword's length off (a step back, still facing him)
				var back_ok := dist < reach * 0.55 and not _wet(p - dn * 1.0) and not _wet(p - dn * 2.0)
				player.sim_move = Vector3(0, 0, 0.5) if back_ok else Vector3.ZERO
				var s := 1.0 if randf() < 0.5 else -1.0
				var roll_dir := (right * s - dn * 0.4).normalized()
				var roll_ok := true
				for r in [1.0, 2.0, 3.0, 4.0, 5.0]:
					roll_ok = roll_ok and not _wet(p + roll_dir * r, 0.4)
				if foe.state == Enemy.ES.ATTACK and foe.state_t < 0.25 and randf() < 0.35 and player.stamina > 30.0 and roll_ok:
					player.sim_move = Vector3(s, 0, 0.4)
					player.try_roll()
				elif player.stamina > 18.0:
					player.try_attack(false)
		await ticks(3)
		n += 3
		hp_low = minf(hp_low, player.hp / player.max_hp)
		if n % 900 == 0:
			print("  (fight, %d s: at %s; %s %s at %s, %.1f m, hp %.0f/%.0f, state %d; my hp %.0f)" % [n / 60,
				str(p.snapped(Vector3.ONE * 0.1)), foe.id, foe.name, str(foe.global_position.snapped(Vector3.ONE * 0.1)), dist,
				foe.hp, foe.max_hp, foe.state, player.hp])
		if player.sim_move.z < -0.5 and _blocked(3):
			await _sidestep()
			n += 36
	player.sim_move = Vector3.ZERO
	player.sim_sprint = false
	return false

## Phase two's band of open water lies between the Bearer and him.
func _band_between(ic: IceCutter) -> bool:
	if ic.band == null or not is_instance_valid(ic.band) or not ic.band.is_open():
		return false
	var c := ic.band.global_position
	var mid := (ic.band.inner + ic.band.radius) * 0.5
	var rp := Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length()
	var rb := Vector2(ic.global_position.x - c.x, ic.global_position.z - c.z).length()
	return (rp > mid) != (rb > mid)

## "A band of black water that can only be crossed quickly": a sprint
## straight over it, toward the hole or away.
func _cross_band(ic: IceCutter) -> void:
	var c := ic.band.global_position
	var out := player.global_position - c
	out.y = 0
	var r := out.length()
	var inward := r > (ic.band.inner + ic.band.radius) * 0.5
	var dir := -out.normalized() if inward else out.normalized()
	player.cam.yaw = atan2(-dir.x, -dir.z)
	player.sim_move = Vector3(0, 0, -1)
	player.sim_sprint = true
	var t := 0
	while t < 150 and not player.dead and is_instance_valid(ic.band) and ic.band.is_open():
		var rr := Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length()
		if (inward and rr < ic.band.inner - 1.2) or (not inward and rr > ic.band.radius + 1.2):
			break
		await ticks(2)
		t += 2
	player.sim_sprint = false
	player.sim_move = Vector3.ZERO

func _on_stilled() -> void:
	super._on_stilled()
	var near := _foe_near(12.0, true)
	print("  (stilled at %s, in %s, %s; on thin ice: %s; nearest foe: %s)" % [str(player.global_position.snapped(Vector3.ONE * 0.1)),
		Game.current_area_id, "RIME" if World.get_area_state(Game.current_area_id) == RH.WState.RIME else "THAW",
		str(_wet(player.global_position, 0.0)),
		("%s, state %d, %s, %.1f m" % [near.id, near.state, String(near._atk.get("id", "-")),
			near.global_position.distance_to(player.global_position)]) if near != null else "none"])

# -------------------------------------------------------------------- region
## Halla's flask: bought if the Bearer carries its price, refused in her
## words if not (he may reach the fjord with nothing; she is asked again
## once it has paid him).
func _flask(ui: DialogueUI) -> void:
	var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
	if not ids.has("buy_flask"):
		return
	var gmax := int(player.gourd_max)
	var w0 := Game.warmth
	ui.choose(ids.find("buy_flask"))
	await ticks(3)
	if w0 >= 320:
		check(int(player.gourd_max) == gmax + 1 and Game.warmth == w0 - 320, "the flask deepens the gourd for 320 warmth")
		check(ui.text_label.text == "Keep the cork in. That's all the advice you get for free.", "her line on the flask")
	else:
		check(int(player.gourd_max) == gmax and Game.warmth == w0 and not World.flag("bought_halla_flask"),
			"with %d warmth the flask stays hers" % w0)
		check(ui.text_label.text == "That's 320 warmth. Come back when you've got it.", "and she says what it costs (%s)" % ui.text_label.text)

func _region() -> void:
	Game.area_title.connect(_on_area_title)
	Game.title_card.connect(_on_title_card)

	print("== the Kettle Road: the Lowe to the fjord")
	check(Game.current_area_id == "lowe_barrows", "the walk starts in the Lowe (%s)" % Game.current_area_id)
	check(World.get_area_state("lowe_barrows") == RH.WState.THAW and World.is_cleared("lowe_barrows"),
		"the Lowe is released and warm")
	check(not World.areas.has(aid), "Kettle Fjord has not been seen yet")
	var seam := _portal_to(aid)
	check(seam != null and seam.auto, "the Kettle Road seam stands, and asks nothing")
	if seam == null:
		return
	var road: Vector3 = seam.global_position
	var down := Vector3(-1, 0, -1).normalized()   # the road's second leg, toward the fjord
	var to_seam := _path(player.global_position, road)
	check(_reaches(to_seam, road, 3.0), "the Kettle Road can be walked from %s (%.0f m)"
		% [String(World.last_hearth.get("hearth", "?")), _path_len(to_seam)])
	cards.clear()
	var crossed := await _cross(aid, road + down * 1.0, 14000, false)
	check(crossed, "the Bearer walks down the road into Kettle Fjord (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	if not crossed:
		return
	_scan_thin()

	print("== the Landing Ice, in THAW")
	check(World.get_area_state(aid) == RH.WState.THAW, "first arrival is THAW")
	check(_awake_foes().is_empty(), "no enemies in THAW (%d)" % _awake_foes().size())
	await _until(func(): return cards.has("THE LANDING ICE"), 8.0)
	var ci := cards.find("Kettle Fjord")
	check(ci >= 0 and cards.size() == ci + 2 and cards[ci + 1] == "THE LANDING ICE",
		"the region's card, then THE LANDING ICE (%s)" % str(cards))
	check(hud.last_title == "THE LANDING ICE", "the card shows it (%s)" % hud.last_title)
	check(_thin_volumes().is_empty(), "no thin ice in THAW: the fjord is open water")
	var landing := Game.find_hearth(HS_LANDING)
	var houses := Game.find_hearth(HS_HOUSES)
	check(landing != null and houses != null and get_tree().get_nodes_in_group("hearths").size() == 2,
		"two hearths: the Landing Ice and the Fish-Houses")
	if landing == null or houses == null:
		return
	var landing_at := landing.respawn_point()
	var houses_at := houses.respawn_point()
	var walked := await _walk_path(landing_at, 9000, false)
	check(walked and not player.dead, "down the cleft to the Landing Ice (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	await _shot("landing_thaw")
	var plaque: LorePlaque = null
	for pl in area.find_children("*", "LorePlaque", true, false):
		if (pl as LorePlaque).text.begins_with("KETTLE FJORD\n"):      # (the points of interest have boards of their own)
			plaque = pl
	check(plaque != null and plaque.text.begins_with("KETTLE FJORD\n"), "the plaque at the road's foot reads KETTLE FJORD")
	if plaque != null:
		await _walk_path(plaque.global_position, 1200, false)
		await _walk_to(plaque.global_position, 240, 1.2, false)
		await _settle()
		check(_near_interact("Read") != null, "and can be read")
	var rest := await _rest_ui_at(HS_LANDING)
	check(rest != null, "the Landing Ice offers its hearth")
	if rest != null:
		check(String(rest._options[0]["id"]) == "rest" and _option_index(rest, "toggle") < 0,
			"uncleared THAW: rest only, no turning back")
		rest.choose(_option_index(rest, "leave"))   # not yet: the people first
		await ticks(6)
	check(World.get_area_state(aid) == RH.WState.THAW and _ui("RestUI") == null, "Rise leaves the evening as it is")

	print("== THAW: open water, and the jetties round the spur")
	var cache := AreaBuilder._v3(_spec("pickups", "north_shore_cache")["at"])
	var veil_at := AreaBuilder._v3(_spec("frost_veils", "breathing_hole_veil")["at"])
	var ice_mid := AreaBuilder._v3(_spec("spawners", "fisher_landing")["at"])   # where a fisher will kneel
	check(not _reaches(_path(landing_at, cache), cache), "THAW: no way over the water to the north shore")
	check(not _reaches(_path(landing_at, ice_mid), ice_mid, 1.5), "THAW: nor out onto the fjord between the hearths")
	var thaw_way := _path(landing_at, houses_at)
	var thaw_len := _path_len(thaw_way)
	var out_z := 0.0
	for q in thaw_way:
		out_z = minf(out_z, q.z)
	check(_reaches(thaw_way, houses_at) and out_z < -320.0,
		"THAW: the way to the Fish-Houses goes out round the spur on the jetty (%.0f m, out to z %.0f)" % [thaw_len, out_z])
	cards.clear()
	walked = await _walk_jetty(true)
	check(walked and not player.dead, "the Bearer walks the jetty round the spur (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	walked = await _walk_path(houses_at, 3000, false)
	check(walked and not player.dead, "to the Fish-Houses (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	check(cards.has("THE FISH-HOUSES") and hud.last_title == "THE FISH-HOUSES", "THE FISH-HOUSES is named (%s)" % str(cards))
	await _shot("fish_houses_thaw")

	print("== Ivo, Halla and Sten")
	check(_npc("pell") == null, "no Old Pell yet")
	var ivo0 := _npc("ivo")
	_ivo_first = ivo0
	check(ivo0 != null and ivo0.is_visible_in_tree() and not ivo0.seated, "Ivo stands by the dogs")
	var lines: Array = await _talk_lines("ivo")
	check(lines == IVO_FIRST, "Ivo's first lines, in order (%d)" % lines.size())
	check(World.flag("ks_ivo_met") and World.flag("met_ivo"), "Ivo's thread begins")
	check(_journal("ivo_mitten") == IVO_THREAD.slice(0, 1), "his first journal line")
	check(_ui("DialogueUI") == null and player.input_enabled, "Leave closes the talk and hands control back")
	lines = await _talk_lines("ivo")
	check(lines.size() >= 1 and lines[0] == "I'm not going anywhere. That's what he said to say.",
		"Ivo again: he is not going anywhere (%s)" % str(lines.slice(0, 1)))
	var ui := await _talk("halla")
	check(ui != null, "the Bearer speaks with Halla")
	if ui != null:
		lines = await _lines_of(ui)
		check(lines == HALLA_FIRST, "Halla's first lines, in order (%d)" % lines.size())
		var ids: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(ids.has("buy_bog_iron") and ids.has("buy_harpoon") and ids.has("buy_flask"),
			"she sells iron, a harpoon and a flask (%s)" % str(ids))
		var labels: Array = ui._options.map(func(o): return ui._option_label(o))
		check(labels.any(func(l): return String(l).begins_with("Trade for a stoppered flask"))
			and labels.any(func(l): return String(l).begins_with("Buy a sealing harpoon"))
			and labels.any(func(l): return String(l).begins_with("Buy a lump of iron")), "labels as KETTLE.md gives them")
		await _flask(ui)
		await _leave(ui)
	check(World.flag("ks_halla_met") and _journal("halla_cord") == HALLA_THREAD.slice(0, 1), "Halla's thread begins")
	ui = await _talk("sten")
	check(ui != null, "the Bearer speaks with Sten")
	if ui != null:
		lines = await _lines_of(ui)
		check(lines == STEN_FIRST, "Sten's first lines, in order (%d)" % lines.size())
		var sids: Array = ui._options.map(func(o): return String(o.get("id", "")))
		check(sids.has("give_icefur"), "he offers his coat")
		if sids.has("give_icefur"):
			check(ui._option_label(ui._options[sids.find("give_icefur")]).begins_with("Take Sten's fur coat"), "labelled as KETTLE.md gives it")
			ui.choose(sids.find("give_icefur"))
			await ticks(3)
			check(ui.text_label.text == "Have it. I'm roasting. Don't let her see, it's on the cargo cord.", "his line on the coat")
		await _leave(ui)
	check(int(player.inventory.get("armour_icefur", 0)) == 1 and player.owns_armour("armour_icefur"), "the Ice-Fur Coat is in the Pack")
	check(player.equip_armour("body", "armour_icefur"), "and can be worn")
	lines = await _talk_lines("sten")
	check(lines.size() >= 1 and lines[0] == "Sorry.", "Sten again: sorry (%s)" % str(lines.slice(0, 1)))
	check(_journal("ivo_mitten").size() == 1 and _journal("halla_cord").size() == 1, "two threads, one line each")
	await _shot("fish_houses_people")

	print("== the first rest: the Landing Ice forces RIME")
	walked = await _walk_jetty(false) and await _walk_path(landing_at, 3000, false)
	check(walked and not player.dead, "back along the jetty to the Landing Ice (%s)" % str(player.global_position.snapped(Vector3.ONE)))
	rest = await _rest_ui_at(HS_LANDING)
	check(rest != null, "the hearth again")
	if rest != null:
		rest.choose(_option_index(rest, "rest"))
		await _wait_turn()
	check(World.get_area_state(aid) == RH.WState.RIME, "Kettle Fjord is RIME now")
	check(String(World.last_hearth.get("hearth", "")) == HS_LANDING and _hearth_lit(HS_LANDING), "the Landing Ice is lit and kept")
	for id in ["ivo", "halla", "sten"]:
		check(_npc(id) == null or not _npc(id).is_visible_in_tree(), "%s is gone in RIME" % id)
	await ticks(30)
	_scan_thin()
	var foes := _awake_foes()
	var kinds := {}
	for e in foes:
		kinds[(e as Enemy).id] = int(kinds.get((e as Enemy).id, 0)) + 1
	# (nine on the road and the ice, and the Ice Camp's three: POI.md 4.4)
	check(foes.size() == 12 and int(kinds.get("ice_fisher", 0)) == 6 and int(kinds.get("sealer", 0)) == 3
		and int(kinds.get("sledge_dog", 0)) == 2 and int(kinds.get(BOSS, 0)) == 1, "the frost-taken stand where they froze (%s)" % str(kinds))
	check(_thin_volumes().size() == 7, "RIME: crevasses, cut holes and the Breathing Hole give underfoot (%d thin volumes)" % _thin_volumes().size())
	var boss0 := _foe(BOSS) as IceCutter
	check(boss0 != null and not boss0.stood, "the Ice-Cutter kneels at the Breathing Hole")
	if boss0 != null:
		hole = boss0.hole_point()
	check(_hole_hazards() == 1, "the hole is open water under thin ice")
	rest = await _rest_ui_at(HS_LANDING)
	check(rest != null and _option_index(rest, "toggle") < 0 and _option_index(rest, "rest") >= 0, "uncleared RIME: rest only")
	if rest != null:
		rest.choose(_option_index(rest, "leave"))
		await ticks(6)
	await _shot("landing_rime")

	print("== RIME: the ice, wall to wall")
	check(_reaches(_path(landing_at, cache), cache) and _reaches(_path(landing_at, ice_mid), ice_mid, 1.5),
		"RIME: the navmesh crosses the ice, to the north shore and anywhere between")
	var rime_now := _path(landing_at, houses_at)
	check(_reaches(rime_now, houses_at) and _path_len(rime_now) < thaw_len - 3.0,
		"RIME: the short way to the Fish-Houses is straight over the ice (%.0f m, %.0f m by the jetty)" % [_path_len(rime_now), thaw_len])
	var w_before := Game.warmth
	check(await _take_alive("sealer_harpoon", "Work the harpoon free"), "out onto the ice to the boat that was leaving")
	check(int(player.inventory.get("sealer_harpoon", 0)) == 1, "the Sealer's Harpoon is worked free")
	check(player.global_position.y < 0.6 and not player.dead, "the Bearer stands on the fjord (y %.2f)" % player.global_position.y)
	await _fight(14.0, 90.0)
	await _alive()
	await _shot("ice_harpoon")
	# the RIME-only route: over the ice to the north shore, round the crevasse
	check(await _take_alive("north_shore_cache", "Pry up what the ice holds"), "the Bearer walks the ice to the north shore")
	check(int(player.inventory.get("bog_iron", 0)) >= 4 and World.area_flag(aid, "took_north_shore_cache"),
		"what the ice held there (bog-iron %d)" % int(player.inventory.get("bog_iron", 0)))
	await _fight(14.0, 90.0)
	check(Game.warmth > w_before or _stilled > 0, "the fallen give up warmth (%d)" % (Game.warmth - w_before))

	print("== the Fish-Houses in RIME: the ladle, the cord, the auger")
	cards.clear()
	check(await _take_in_house("kettle_ladle", "Take the ladle", 0), "up the walk and into the westmost house, to the pot on its hook")
	check(float(_house_floor_y.get("kettle_ladle", 0.0)) > 2.0, "standing on its floor (y %.2f)" % float(_house_floor_y.get("kettle_ladle", 0.0)))
	check(int(player.inventory.get("item_kettle_ladle", 0)) == 1 and World.flag("ks_ivo_supper"), "the ladle is taken from the frozen pot")
	check(_journal("ivo_mitten") == IVO_THREAD.slice(0, 2), "Ivo's supper is remembered")
	await _shot("ladle")
	check(await _take_alive("halla_cord", "Untie the cord"), "out to the mooring post at the middle house")
	check(int(player.inventory.get("item_halla_cord", 0)) == 1 and World.flag("ks_halla_cord_found"), "Halla's cord is untied")
	check(_journal("halla_cord") == HALLA_THREAD.slice(0, 2), "the last knot is remembered")
	check(await _take_in_house("ice_auger", "Take the auger", 2), "up the walk and into the eastmost house, to the tool bench")
	check(float(_house_floor_y.get("ice_auger", 0.0)) > 2.0, "standing on its floor (y %.2f)" % float(_house_floor_y.get("ice_auger", 0.0)))
	check(int(player.inventory.get("ice_auger", 0)) == 1 and player.owns_weapon("ice_auger"), "the spare Ice-Cutter's Auger is taken")
	check(await _rest_alive(HS_HOUSES, "rest"), "the Fish-Houses hearth is kept")
	check(_hearth_lit(HS_HOUSES) and String(World.last_hearth.get("hearth", "")) == HS_HOUSES
		and World.get_area_state(aid) == RH.WState.RIME, "lit, the anchor, and still RIME")
	print("  (falls so far, none of them planned: %d)" % _stilled)

	await _finale()
	Game.area_title.disconnect(_on_area_title)
	Game.title_card.disconnect(_on_title_card)

## From the Fish-Houses hearth, lit, in RIME: the death and the Breathmark,
## the veil, the duel, the release, the THAW after it, and the last rest.
var _ivo_first: NPC = null
func _finale() -> void:
	var veil_at := AreaBuilder._v3(_spec("frost_veils", "breathing_hole_veil")["at"])
	var landing := Game.find_hearth(HS_LANDING)
	var houses := Game.find_hearth(HS_HOUSES)
	var lines: Array = []
	if hole == Vector3.INF and _foe(BOSS) != null:
		hole = (_foe(BOSS) as IceCutter).hole_point()
	print("== STILLED on the ice, and the Breathmark")
	_planned_falls = 1
	await _die_and_recover(HS_HOUSES)
	await _alive()

	print("== grown by warmth at the Fish-Houses")
	var lv0 := player.level
	var rest := await _rest_ui_at(HS_HOUSES)
	check(rest != null and _option_index(rest, "level") >= 0, "the hearth offers to grow by warmth")
	if rest != null:
		rest.choose(_option_index(rest, "level"))
		await ticks(2)
		var turn := 0
		while Game.warmth >= rest._level_cost() and turn < 12:
			var want := "stat:heart" if turn % 2 == 0 else "stat:might"
			var cost := rest._level_cost()
			var wb := Game.warmth
			var lv := player.level
			rest.choose(_option_index(rest, want))
			await ticks(2)
			if player.level != lv + 1 or Game.warmth != wb - cost:
				break
			turn += 1
		check(player.level > lv0, "levels bought with what the fjord gave (%d -> %d, %d warmth left)" % [lv0, player.level, Game.warmth])
		rest.choose(_option_index(rest, "back"))
		rest.choose(_option_index(rest, "leave"))
		await ticks(6)
	check(_ui("RestUI") == null and player.input_enabled, "Rise hands control back")

	print("== the frost veil")
	check(await _rest_alive(HS_HOUSES, "rest"), "a rest first, to fill the gourd")
	var veil := _veil(veil_at)
	check(veil != null and veil.boss_spawner != null, "one veil, across the gap in the pressure ridges")
	if veil == null:
		return
	var parted := false
	for attempt in 3:
		await _alive()
		parted = await _part_veil(veil, true)
		if parted and not player.dead:
			break
	check(parted and Game.arena_locked, "the veil seals at the Bearer's back")
	check(cards.has("THE BREATHING HOLE"), "THE BREATHING HOLE is named (%s)" % str(cards))
	await _shot("breathing_hole")

	print("== the Ice-Cutter")
	var ic := _foe(BOSS) as IceCutter
	check(ic != null and not ic.stood and ic.vis.current_clip() == "kneel_drill", "he kneels at the rim, drilling")
	check(not hud.boss_root.visible, "no bar until he stands")
	var result: Dictionary = await _duel(BOSS, veil, 3.0, 900.0, _duel_each)
	var slain: Enemy = result["boss"]
	check(slain != null and slain.dead, "the Ice-Cutter is released (falls along the way: %d)" % int(result["deaths"]))
	check(_bar_seen, "the bar named him: THE ICE-CUTTER")
	var phases: Dictionary = result["phases"]
	check(phases.has(2) and phases.has(3), "his AI ran all three phases (%s)" % str(phases.keys()))
	check(boss_band_seen, "phase two cut the ring round the arena")
	check(boss_holes_seen > 0, "he broke the floor (%d holes open at once; moves seen: %s)" % [boss_holes_seen, str(boss_moves_seen.keys())])
	if slain == null or not slain.dead:
		return

	print("== the release")
	await _secs(1.0)
	check(String(AudioDirector._active_music).ends_with("outsong.ogg"), "the Outsong is sung (%s)" % AudioDirector._active_music)
	check(hud.last_title == "THE ICE-CUTTER — RELEASED" and cards.has("THE ICE-CUTTER — RELEASED"), "the quiet card (%s)" % hud.last_title)
	await _shot("release_card")
	check(World.is_cleared(aid) and World.flag("ks_ice_cutter_released"), "Kettle Fjord is cleared")
	check(not Game.arena_locked, "the veil falls")
	check((slain as IceCutter).released and is_instance_valid(slain) and slain.vis.current_clip() == "rest_auger",
		"he kneels at the rim and lets the auger rest")
	await ticks(10)
	check(_hole_hazards() == 0, "the hole skins over: no thin ice left under it")
	check(_open_ice().is_empty(), "the ring and every broken patch close")
	check(get_tree().get_nodes_in_group("hearths").size() == 2, "no hearth wakes here")
	_scan_thin()
	var mitten := _pickup("ivo_mitten")
	check(mitten != null and Vector2(mitten.global_position.x - hole.x, mitten.global_position.z - hole.z).length() < 0.3,
		"Ivo's mitten is frozen into the new ice, in the middle of the hole")
	var mittens := area.find_children("*", "Pickup", true, false).filter(
			func(k): return (k as Pickup).pickup_id == "ivo_mitten" and not k.is_queued_for_deletion())
	check(mittens.size() == 1, "one mitten (%d)" % mittens.size())
	check(await _take("ivo_mitten", "Chip the mitten free", false), "the Bearer walks out onto the new ice")
	check(not player.dead and Vector2(player.global_position.x - hole.x, player.global_position.z - hole.z).length() < 1.4,
		"and it holds (%.1f m from the middle)" % Vector2(player.global_position.x - hole.x, player.global_position.z - hole.z).length())
	check(int(player.inventory.get("item_ivo_mitten", 0)) == 1 and World.flag("ks_ivo_mitten_found"), "the mitten is chipped free")
	check(_journal("ivo_mitten") == IVO_THREAD.slice(0, 3), "and remembered")
	await _shot("mitten")

	print("== after the release, THAW: Old Pell and Ivo at the fish-kettle")
	check(await _rest_alive(HS_HOUSES, "toggle"), "the Fish-Houses now offers to turn the memory")
	check(World.get_area_state(aid) == RH.WState.THAW, "warmed: THAW again")
	check(_awake_foes().is_empty(), "nobody frost-taken in THAW")
	var pell := _npc("pell")
	var ivo := _npc("ivo")
	check(pell != null and pell.is_visible_in_tree() and pell.seated, "Old Pell sits at the westmost fish-kettle")
	var ivos := area.find_children("*", "NPC", true, false).filter(func(n): return (n as NPC).npc_id == "ivo" and not n.is_queued_for_deletion())
	check(ivos.size() == 1 and ivo != null and ivo.is_visible_in_tree() and ivo.seated, "one Ivo, sitting (%d)" % ivos.size())
	if pell != null and ivo != null:
		check(pell.global_position.distance_to(ivo.global_position) < 4.5, "across the fire from each other")
		check(_ivo_first == null or not is_instance_valid(_ivo_first) or ivo != _ivo_first, "Ivo has moved from the dogs")
		check(pell.find_children("*", "Interactable", true, false).is_empty(), "Pell cannot be spoken to")
		var heard := []
		var on_heard := func(who: String, line: String): heard.append([who, line])
		pell.overheard.connect(on_heard)
		await _walk_path(pell.global_position + Vector3(-1.5, 0, 2.5), 1200, false)
		check(player.global_position.distance_to(pell.global_position) < 8.0, "the Bearer stands within earshot")
		await _until(func(): return heard.size() >= KETTLE_TALK.size(), 4.6 * 8 + 16.0)
		pell.overheard.disconnect(on_heard)
		# (the talk loops; whatever was heard first, it must hold all seven in order)
		var from := heard.find(KETTLE_TALK[0])
		check(from >= 0 and heard.slice(from, from + 7) == KETTLE_TALK or _is_rotation(heard.slice(0, 7), KETTLE_TALK),
			"overheard, in order: %s" % str(heard.map(func(h): return String(h[1]).left(14))))
		check(hud.overheard_label.text.begins_with("Pell: ") or hud.overheard_label.text.begins_with("Ivo: "),
			"low over the belt, with who said it (%s)" % hud.overheard_label.text)
		await _shot("pell_and_ivo")

	print("== both threads close")
	lines = await _talk_lines("ivo")
	check(lines.size() == 2 and lines[0] == "That's mine. Where was it? I had it this morning."
		and lines[1] == "There. Both my own. You can give Grandfather his back, I'm not going near him.",
		"Ivo takes his mitten (%s)" % str(lines.slice(0, 1)))
	check(World.flag("ks_ivo_mitten") and int(player.inventory.get("item_ivo_mitten", 0)) == 0, "the mitten is home")
	check(ivo == null or not is_instance_valid(ivo) or ivo._vis.current_clip() == "sit", "he talks from where he sits")
	check(_journal("ivo_mitten") == IVO_THREAD, "Ivo's mitten: four lines, in order (%d)" % _journal("ivo_mitten").size())
	lines = await _talk_lines("halla")
	check(lines.size() == 2 and lines[0] == "That's not my knot. I don't tie it like that. One man, sick."
		and lines[1] == "Sten. Come here. No, stay there. Stay there.", "Halla reads the last knot (%s)" % str(lines.slice(0, 1)))
	check(World.flag("ks_halla_cord") and int(player.inventory.get("item_halla_cord", 0)) == 0, "she takes the cord")
	check(not World.flag("ks_halla_bed") and _journal("halla_cord") == HALLA_THREAD.slice(0, 3), "the end house waits for the next talk")
	lines = await _talk_lines("halla")
	check(lines.size() == 1 and lines[0] == "I've put him in the end house by the fire. He can come down on the next boat. There's always a next boat.",
		"Halla, a second time: Sten is by the fire (%s)" % str(lines.slice(0, 1)))
	check(World.flag("ks_halla_bed") and _journal("halla_cord") == HALLA_THREAD, "Halla's cord: four lines, in order (%d)" % _journal("halla_cord").size())
	if not World.flag("bought_halla_flask"):
		# the Bearer came down the Kettle Road with nothing to trade; the
		# fjord has paid him since
		var hui := await _talk("halla")
		check(hui != null, "Halla again, for the flask")
		if hui != null:
			await _lines_of(hui)
			await _flask(hui)
			await _leave(hui)
	check(World.flag("bought_halla_flask"), "the flask is bought")

	print("== turning freely, and the last rest")
	check(await _rest_alive(HS_HOUSES, "toggle"), "the Fish-Houses turns the memory back")
	check(World.get_area_state(aid) == RH.WState.RIME, "stilled again: RIME")
	await ticks(30)
	check(_foe(BOSS) == null, "he does not come back")
	check(_hole_hazards() == 0 and _thin_volumes().size() == 6, "the hole stays closed; the crevasses do not (%d)" % _thin_volumes().size())
	var v2 := _veil(veil_at)
	check(v2 == null or not v2._zone.enabled, "no veil to part")
	check(await _rest_alive(HS_HOUSES, "toggle"), "and warms it once more")
	check(World.get_area_state(aid) == RH.WState.THAW, "THAW at the end")
	# the Fish-Houses is the hearth nearest the Tarn Steps
	var tarn := _portal_to("tarnhall")
	check(tarn != null, "the Tarn Steps seam stands, for the next walk")
	if tarn != null:
		var dl := landing.global_position.distance_to(tarn.global_position)
		var dh := houses.global_position.distance_to(tarn.global_position)
		check(dh < dl, "the Fish-Houses is the hearth nearest it (%.0f m; the Landing Ice %.0f m)" % [dh, dl])
	check(await _rest_alive(HS_HOUSES, "rest"), "the last rest, at the Fish-Houses")
	check(String(World.last_hearth.get("area", "")) == aid and String(World.last_hearth.get("hearth", "")) == HS_HOUSES,
		"the kept hearth is the Fish-Houses")
	check(World.get_area_state(aid) == RH.WState.THAW, "a rest in a released region turns nothing")
	print("  (falls in all: %d, planned: %d; lowest health %.0f%%)" % [_stilled, _planned_falls + int(result["deaths"]), hp_low * 100.0])

func _is_rotation(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for k in b.size():
		var ok := true
		for i in b.size():
			ok = ok and a[i] == b[(i + k) % b.size()]
		if ok:
			return true
	return false

## Every two seconds of the duel: what the bar shows.
var _bar_seen := false
func _duel_each(boss: Enemy) -> void:
	if boss is IceCutter and (boss as IceCutter).stood and hud.boss_root.visible and hud.boss_name.text == "THE ICE-CUTTER":
		_bar_seen = true
	_scan_thin()
	_each_n += 1
	if _each_n % 8 == 0:
		var hp := Vector2(boss.global_position.x - hole.x, boss.global_position.z - hole.z).length()
		print("  (duel %d s: he is at %s, %.1f m from the hole, phase %d, state %d, hp %.0f/%.0f; the Bearer at %s, hp %.0f, gourds %d, locked %s)" % [
			_each_n * 2, str(boss.global_position.snapped(Vector3.ONE * 0.1)), hp, boss.phase, boss.state, boss.hp, boss.max_hp,
			str(player.global_position.snapped(Vector3.ONE * 0.1)), player.hp, player.gourds, str(Game.arena_locked)])
var _each_n := 0

func _after_load() -> void:
	print("== Kettle Fjord after the load")
	_scan_thin()
	check(Game.current_area_id == aid, "the hearth resumes in Kettle Fjord")
	var standing := world.find_children("*", "Area", true, false).filter(func(a): return not a.is_queued_for_deletion())
	check(standing.size() == 1 and standing[0] == area, "one fjord stands: the one that was left was put away (%d)" % standing.size())
	check(Game.find_hearth(HS_HOUSES) != null and Game.find_hearth(HS_HOUSES).area == area, "its hearth is this fjord's")
	check(_hearth_lit(HS_LANDING) and _hearth_lit(HS_HOUSES), "both hearths stay lit")
	check(String(World.last_hearth.get("hearth", "")) == HS_HOUSES, "the Fish-Houses is still the anchor")
	check(World.is_cleared(aid) and World.flag("ks_ice_cutter_released") and World.area_flag(aid, "slain_ice_cutter"),
		"the Ice-Cutter stays released")
	check(World.get_area_state(aid) == RH.WState.THAW, "the fjord stays warm")
	for id in ["sealer_harpoon", "north_shore_cache", "kettle_ladle", "halla_cord", "ice_auger", "ivo_mitten"]:
		check(World.area_flag(aid, "took_" + id) and _pickup(id) == null, "%s stays taken" % id)
	check(int(player.inventory.get("sealer_harpoon", 0)) == 1 and int(player.inventory.get("ice_auger", 0)) == 1
		and int(player.inventory.get("armour_icefur", 0)) == 1 and int(player.inventory.get("item_kettle_ladle", 0)) == 1,
		"the harpoon, the auger, the coat and the ladle are in the Pack")
	check(int(player.inventory.get("item_ivo_mitten", 0)) == 0 and int(player.inventory.get("item_halla_cord", 0)) == 0,
		"the mitten and the cord stay given")
	check(int(player.inventory.get("item_tally_stick", 0)) == 1, "what the Lowe left is still carried")
	check(String(player.armour.get("body", "")) == "armour_icefur", "Sten's coat is still worn")
	check(_journal("ivo_mitten") == IVO_THREAD and _journal("halla_cord") == HALLA_THREAD, "both threads whole")
	check(World.flag("bought_halla_flask") and World.flag("got_sten_icefur"), "the flask and the coat stay bought and given")
	var pell := _npc("pell")
	var ivo := _npc("ivo")
	check(pell != null and pell.is_visible_in_tree() and ivo != null and ivo.seated, "Pell and Ivo are at the kettle still")
	# the hole: sealed in the rebuilt fjord, in RIME as well
	hole = AreaBuilder._v3(_spec("spawners", "ice_cutter")["at"]) + Vector3(0, 0, 2.64)
	check(_hole_hazards() == 0, "the sealed hole stays sealed in the rebuilt fjord")
	check(await _rest_alive(HS_HOUSES, "toggle"), "the memory still turns freely")
	check(World.get_area_state(aid) == RH.WState.RIME, "RIME after the load")
	await ticks(30)
	_scan_thin()
	check(_foe(BOSS) == null and _hole_hazards() == 0 and _thin_volumes().size() == 6, "no Ice-Cutter, no hole (%d thin volumes live of %d, %d frost-taken)"
		% [_thin_volumes().size(), _thin_volumes(false).size(), _awake_foes().size()])
	var veil := _veil()
	check(veil == null or not veil._zone.enabled, "the veil stays down")
	var over := await _walk_path(hole, 9000, true)
	await _walk_to(hole, 300, 0.6, false)
	await _secs(1.5)
	check(over and not player.dead and Vector2(player.global_position.x - hole.x, player.global_position.z - hole.z).length() < 1.2,
		"the Bearer stands on the new ice where the hole was (%s)" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
	check(await _rest_alive(HS_HOUSES, "toggle"), "back to the Fish-Houses, and warm again")
	check(World.get_area_state(aid) == RH.WState.THAW and String(World.last_hearth.get("hearth", "")) == HS_HOUSES,
		"the walk ends in THAW at the Fish-Houses")
