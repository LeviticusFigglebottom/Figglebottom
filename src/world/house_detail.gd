class_name HouseDetail
extends RefCounted
## The construction detail of a BuildingGen house (docs/art/WORLD_FIDELITY.md).
## BuildingGen keeps the footprint, the collision and the far silhouette; this
## builds what is seen inside ~70 m, in the house's local frame (x across,
## z along the ridge, y up from the spec's "y"):
##   walls    rounded footing stones, a sill beam, bevelled and warped staves
##            with real V-joints, bay posts, a wall plate, an eave board
##   openings a threshold stone, jambs and an eared lintel, a pair of plank
##            leaves on iron straps with a ring; shuttered window holes
##   roof     boards on rafters, purlins and a ridge beam; birch-bark sheets
##            lapping out at the eave; a turf log on hooks; lumpy turf with a
##            wavering ridge and soil at its edges; weighted poles; a louvre
## Every vertex carries wear / moss / AO (MeshBuf), written by one shade pass:
## contact shadow at the wall feet and under the eaves, moss low on north
## faces, soot over the doors and round the smoke-hole.
## Nothing here collides: BuildingGen's solids stay exactly as they were.

const DOOR_W := 1.9
const DOOR_H := 2.5
const OVER := 0.75
## Small parts (iron, bark, pegs, carving) and the whole near build drop out
## at these distances; BuildingGen's far slabs take over past LOD_MID.
const LOD_NEAR := 36.0
const LOD_MID := 70.0
const FOOT_H := 0.42       # top of the stone footing
const SILL_TOP := 0.6

var id := "house"
var style := "hall"        # hall | store | fish | byre | shed
var mode := 0
var w := 8.0
var l := 8.0
var h := 3.2
var yaw := 0.0
var rise := 3.0
var half := 4.75
var slope := 5.0
var ang := 0.6
var length := 9.5
var opens: Array = []
var doors: Array = []      # {side, t, bay, leaf}
var windows: Array = []    # {side, t0, t1, y0, y1, open}
var louvre_z := INF        # ridge position of the smoke-hole, INF = none
var origin := Vector3.ZERO
var area_def: Dictionary = {}
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()

var wood: MeshBuf          # staves, leaves, roof boards
var dark: MeshBuf          # framing: sills, plates, posts, rafters
var stone: MeshBuf
var turf: MeshBuf
var soil: MeshBuf          # the cut edges of the turf
var bark: MeshBuf
var iron: MeshBuf
var fine: MeshBuf          # small dark timber: hooks, pegs, slats, carving
var in_wood: MeshBuf       # interior fittings (never snowed on)
var in_dark: MeshBuf
var in_stone: MeshBuf
var in_cloth: MeshBuf
var in_rope: MeshBuf
var in_hide: MeshBuf        # hung goods: hams, sacks, dried fish

static var _mats: Dictionary = {}

func _init(spec: Dictionary, def: Dictionary, state_mode: int) -> void:
	id = String(spec.get("id", "house"))
	mode = state_mode
	area_def = def
	w = float(spec["size"][0])
	l = float(spec["size"][1])
	h = float(spec.get("wall_h", 3.2 if w < 12 else 3.5))
	yaw = deg_to_rad(float(spec.get("yaw", 0.0)))
	origin = Vector3(float(spec["center"][0]), float(spec.get("y", 0.0)), float(spec["center"][1]))
	opens = spec.get("open", [])
	rise = w * 0.42
	half = w * 0.5 + OVER
	slope = sqrt(half * half + rise * rise)
	ang = atan2(rise, half)
	length = l + OVER * 2.0
	style = String(spec.get("style", _style_of(id)))
	rng.seed = hash(id + "|detail")
	noise.seed = int(rng.randi() & 0xffff)
	noise.frequency = 0.45
	var sd := int(rng.randi() & 0xffff)
	wood = MeshBuf.new(sd + 1); dark = MeshBuf.new(sd + 2); stone = MeshBuf.new(sd + 3)
	turf = MeshBuf.new(sd + 4); soil = MeshBuf.new(sd + 5); bark = MeshBuf.new(sd + 6)
	iron = MeshBuf.new(sd + 7); fine = MeshBuf.new(sd + 8)
	in_wood = MeshBuf.new(sd + 9); in_dark = MeshBuf.new(sd + 10); in_stone = MeshBuf.new(sd + 11)
	in_cloth = MeshBuf.new(sd + 12); in_rope = MeshBuf.new(sd + 13); in_hide = MeshBuf.new(sd + 14)
	for d in spec.get("doors", []):
		_add_door(String(d[0]), int(d[1]), true)
	for d in spec.get("gate_doors", []):
		_add_door(String(d[0]), int(d[1]), false)     # a ShortcutGate hangs its own door
	if style == "hall" or style == "fish":
		louvre_z = l * (0.16 if style == "hall" else 0.0)
	_plan_windows()

static func _style_of(house_id: String) -> String:
	for k in [["fishhouse", "fish"], ["boatshed", "shed"], ["store", "store"], ["wellhouse", "store"], ["byre", "byre"]]:
		if house_id.begins_with(String(k[0])):
			return String(k[1])
	return "hall"

# ------------------------------------------------------------------ frames

## Wall frame of a side: x along the wall, y up, z outward; origin on the wall line.
func side_xf(side: String) -> Transform3D:
	match side:
		"N": return Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)), Vector3(0, 0, -l * 0.5))
		"S": return Transform3D(Basis(Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, 1)), Vector3(0, 0, l * 0.5))
		"W": return Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), Vector3(-w * 0.5, 0, 0))
	return Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3(w * 0.5, 0, 0))

func side_span(side: String) -> float:
	return w if (side == "N" or side == "S") else l

## Centre of bay i in the wall frame (bays count along +x for N/S, +z for W/E).
func bay_t(side: String, i: int) -> float:
	var c := -side_span(side) * 0.5 + 2.0 + 4.0 * i
	return -c if (side == "N" or side == "E") else c

## Slope frame: x down the slope from the ridge, y the slope normal, z along
## the ridge (mirrored on the -x slope so the frame stays right-handed).
func slope_xf(s: float) -> Transform3D:
	return Transform3D(Basis(Vector3(s * cos(ang), -sin(ang), 0), Vector3(s * sin(ang), cos(ang), 0), Vector3(0, 0, s)),
		Vector3(0, h - 0.05 + rise, 0))

## Height of the roof-board plane over local x.
func roof_y(x: float) -> float:
	return h - 0.05 + rise * (1.0 - absf(x) / half)

func _add_door(side: String, bay: int, leaf: bool) -> void:
	var t := bay_t(side, bay)
	if leaf:
		# a door someone else already hangs here (a gate, a kit leaf, a Tripo pair)
		var wp := world_of(side_xf(side) * Vector3(t, 0, 0))
		for key in ["gates", "props", "landmarks"]:
			for sp in area_def.get(key, []):
				if key == "props" and not String(sp.get("kit", "")).begins_with("door"):
					continue
				if key == "landmarks" and not String(sp.get("scene", "")).contains("door"):
					continue
				var at: Array = sp.get("at", [])
				if at.size() >= 3 and Vector2(float(at[0]) - wp.x, float(at[2]) - wp.z).length() < 2.6:
					leaf = false
	doors.append({"side": side, "t": t, "bay": bay, "leaf": leaf})

func world_of(p: Vector3) -> Vector3:
	return origin + Basis(Vector3.UP, yaw) * p

func _door_ts(side: String) -> Array:
	var out: Array = []
	for d in doors:
		if d["side"] == side:
			out.append(float(d["t"]))
	out.sort()
	return out

func _plan_windows() -> void:
	if style == "shed":
		return
	var y0 := 1.5 if h >= 3.1 else 1.32
	for side in ["W", "E"]:
		if side in opens:
			continue
		var n := int(l / 4.0)
		for i in n:
			var t := bay_t(side, i)
			var blocked := false
			for dt in _door_ts(side):
				if absf(float(dt) - t) < 2.2:
					blocked = true
			if blocked:
				continue
			var want := false
			match style:
				"hall": want = (i % 2) == (0 if side == "W" else 1) or n <= 3
				"byre": want = true
				_: want = i == (n - 1 if side == "W" else 0)
			if not want:
				continue
			var ww := 0.3 if style == "byre" else rng.randf_range(0.5, 0.62)
			var wh := 0.5 if style == "byre" else rng.randf_range(0.52, 0.62)
			t += rng.randf_range(-0.5, 0.5)
			var r := rng.randf()
			var open := 0.0 if r < 0.25 else (rng.randf_range(0.35, 1.1) if r < 0.45 else rng.randf_range(2.85, 3.05))
			if style == "byre":
				open = -1.0     # a bare vent slot, no shutter
			windows.append({"side": side, "t0": t - ww * 0.5, "t1": t + ww * 0.5, "y0": y0, "y1": y0 + wh, "open": open})

# ------------------------------------------------------------------- walls

func build_walls() -> void:
	for side in ["N", "S", "W", "E"]:
		if side in opens:
			continue
		var sx := side_xf(side)
		for b in [wood, dark, stone, iron, fine, in_wood, in_dark]:
			(b as MeshBuf).xf = sx
		var span := side_span(side)
		var gaps := _door_ts(side)
		var cur := -span * 0.5
		var segs: Array = []
		for g in gaps:
			segs.append([cur, float(g) - DOOR_W * 0.5])
			cur = float(g) + DOOR_W * 0.5
		segs.append([cur, span * 0.5])
		var wins: Array = []
		for wn in windows:
			if wn["side"] == side:
				wins.append(wn)
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			if b - a < 0.05:
				continue
			_footing(a, b)
			# the sill beam the staves stand in
			dark.beam(Vector3(a, (FOOT_H + SILL_TOP) * 0.5, 0.01), Vector3(b, (FOOT_H + SILL_TOP) * 0.5, 0.01),
				SILL_TOP - FOOT_H + 0.03, 0.25, Vector3.UP, 0.025)
			# staves, cut where a window opens
			var cuts: Array = [a]
			for wn in wins:
				if float(wn["t0"]) > a + 0.3 and float(wn["t1"]) < b - 0.3:
					cuts.append(float(wn["t0"]))
					cuts.append(float(wn["t1"]))
			cuts.append(b)
			cuts.sort()
			for ci in cuts.size() - 1:
				var win: Dictionary = {}
				for wn in wins:
					if absf(float(wn["t0"]) - float(cuts[ci])) < 0.001 and absf(float(wn["t1"]) - float(cuts[ci + 1])) < 0.001:
						win = wn
				_staves(float(cuts[ci]), float(cuts[ci + 1]), win)
		for wn in wins:
			_window(wn)
		# bay posts, proud of the staves inside and out
		var nb := int(span / 4.0)
		for k in range(1, nb):
			var pt := -span * 0.5 + 4.0 * k
			var clear := true
			for g in gaps:
				if absf(float(g) - pt) < DOOR_W * 0.5 + 0.4:
					clear = false
			for wn in wins:
				if pt > float(wn["t0"]) - 0.25 and pt < float(wn["t1"]) + 0.25:
					clear = false
			if clear:
				dark.beam(Vector3(pt, SILL_TOP - 0.02, 0.0), Vector3(pt, h + 0.02, 0.0), 0.2, 0.26, Vector3.RIGHT, 0.03)
		for g in gaps:
			_door_frame(side, float(g))
		# the wall plate, and the eave board closing the gap up to the roof
		dark.beam(Vector3(-span * 0.5 - 0.15, h + 0.12, 0), Vector3(span * 0.5 + 0.15, h + 0.12, 0), 0.26, 0.3, Vector3.UP, 0.03)
		if side == "W" or side == "E":
			var top := roof_y(w * 0.5 + 0.1) - 0.04
			wood.box(Vector3(span - 0.3, maxf(top - h - 0.2, 0.05), 0.035),
				Transform3D(Basis.IDENTITY, Vector3(0, (top + h + 0.2) * 0.5, 0.1)), 0)
		else:
			_gable_lining(span)
	for b in [wood, dark, stone, iron, fine, in_wood, in_dark]:
		(b as MeshBuf).xf = Transform3D.IDENTITY

## Dry-stone footing between a and b (wall frame): big rounded stones, here
## and there two stacked, a little proud of the wall on both faces.
func _footing(a: float, b: float) -> void:
	if style == "fish":
		# a house on a deck stands on sole logs, not stones
		for k in 2:
			dark.pole(Vector3(a - 0.02, 0.1 + 0.2 * k, 0.02 + 0.03 * k), Vector3(b + 0.02, 0.1 + 0.2 * k, 0.02 + 0.03 * k), 0.115, 0.0, 8, 0.9 + 0.08 * k)
		return
	# a plain core behind the stones, carried below the floor line: no light
	# or view through the joints, or under them where the ground falls away
	stone.box(Vector3(b - a, FOOT_H + 0.42, 0.34), Transform3D(Basis.IDENTITY, Vector3((a + b) * 0.5, (FOOT_H - 0.03) * 0.5 - 0.225, 0.02)), 0, 8)
	var t := a
	while t < b - 0.05:
		var bw := minf(rng.randf_range(0.42, 0.85), b - t)
		if b - t - bw < 0.25:
			bw = b - t
		var dep := rng.randf_range(0.5, 0.62)
		var c := t + bw * 0.5
		var rot := Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-3, 3)), deg_to_rad(rng.randf_range(-5, 5)), deg_to_rad(rng.randf_range(-3, 3))))
		if rng.randf() < 0.55 or bw < 0.5:
			var bh := FOOT_H + rng.randf_range(-0.02, 0.08)
			stone.stone(Vector3(bw * 1.04, bh, dep), Transform3D(rot, Vector3(c, bh * 0.5 - 0.02, 0.03)), rng.randf_range(0.42, 0.62))
		else:
			var h1 := rng.randf_range(0.2, 0.27)
			var h2 := FOOT_H + rng.randf_range(0.0, 0.07) - h1
			stone.stone(Vector3(bw * 1.04, h1 + 0.04, dep), Transform3D(rot, Vector3(c, h1 * 0.5 - 0.02, 0.03)), rng.randf_range(0.4, 0.55))
			var split := rng.randf_range(0.4, 0.6)
			stone.stone(Vector3(bw * split * 1.03, h2 + 0.03, dep * 0.92), Transform3D(rot, Vector3(t + bw * split * 0.5, h1 + h2 * 0.5 - 0.02, 0.02)), 0.42)
			stone.stone(Vector3(bw * (1.0 - split) * 1.03, h2 + 0.03, dep * 0.95), Transform3D(rot, Vector3(t + bw * split + bw * (1.0 - split) * 0.5, h1 + h2 * 0.5 - 0.02, 0.04)), 0.38)
		t += bw

## One run of staves between a and b. Each board is a six-sided section (so
## neighbours meet in a V-joint that catches the light) swept through four
## rings that bow and lean a few millimetres.
func _staves(a: float, b: float, win: Dictionary) -> void:
	var t := a
	while t < b - 0.02:
		var pw := rng.randf_range(0.2, 0.32)
		if b - t < pw + 0.14:
			pw = b - t
		var c := t + pw * 0.5
		if win.is_empty():
			_board(wood, c, pw, SILL_TOP - 0.02, h + 0.05)
		else:
			_board(wood, c, pw, SILL_TOP - 0.02, float(win["y0"]))
			_board(wood, c, pw, float(win["y1"]), h + 0.05)
		t += pw

func _board(buf: MeshBuf, c: float, pw: float, y0: float, y1: float, th := -1.0, d0 := 0.0) -> void:
	if y1 - y0 < 0.04:
		return
	if th < 0.0:
		th = rng.randf_range(0.075, 0.1)
	var bev := minf(0.013, pw * 0.2)
	var hw := pw * 0.5 + 0.003      # neighbours bite into each other: a joint, not a gap
	var ht := th * 0.5
	var prof := PackedVector2Array([Vector2(-hw, 0), Vector2(-hw + bev, ht), Vector2(hw - bev, ht), Vector2(hw, 0),
		Vector2(hw - bev, -ht), Vector2(-hw + bev, -ht)])
	var dz := d0 + rng.randf_range(-0.009, 0.009)
	var lean := rng.randf_range(-0.004, 0.004)
	var bow := rng.randf_range(-0.009, 0.009)
	var tw := rng.randf_range(-0.012, 0.012)
	var rings: Array = []
	var n := 3 if y1 - y0 > 1.2 else 1
	for k in n + 1:
		var f := float(k) / float(n)
		# more of the length sits low, where the contact shadow needs vertices
		var y := lerpf(y0, y1, f * f if n > 1 else f)
		var mid := 4.0 * f * (1.0 - f)
		rings.append(Transform3D(Basis(Vector3.UP, tw * (f - 0.5)), Vector3(c + lean * (y - y0), y, dz + bow * mid)))
	buf.extrude(prof, rings, false, true, true)

## The gable triangle seen from inside: boards from the plate up to the roof.
func _gable_lining(span: float) -> void:
	var x := -span * 0.5 + 0.02
	while x < span * 0.5 - 0.05:
		var pw := minf(rng.randf_range(0.2, 0.3), span * 0.5 - x)
		var c := x + pw * 0.5
		var lo := roof_y(absf(c) + pw * 0.5) - 0.07
		var hi := roof_y(maxf(absf(c) - pw * 0.5, 0.0)) - 0.07
		var y0 := h + 0.2
		if lo - y0 > 0.03:
			var sgn := -1.0 if c > 0.0 else 1.0
			var a := Vector3(c - pw * 0.5, y0, -0.06)
			var b := Vector3(c + pw * 0.5, y0, -0.06)
			# the roof falls away from the centre: the edge nearer it stands taller
			var ya := (lo if sgn > 0.0 else hi) if absf(c) > pw * 0.5 else hi
			var yb := (hi if sgn > 0.0 else lo) if absf(c) > pw * 0.5 else hi
			var o := Vector2(in_wood.rnd() * 7.0, in_wood.rnd() * 7.0)
			in_wood.face(a, b, Vector3(b.x, yb, -0.06 - in_wood.rnd() * 0.012), Vector3(a.x, ya, -0.06 - in_wood.rnd() * 0.012),
				Vector2(a.x, -y0) + o, Vector2(b.x, -y0) + o, Vector2(b.x, -yb) + o, Vector2(a.x, -ya) + o,
				Vector3(0, 0, -1), in_wood.rnd())
		x += pw

## Jambs, an eared lintel, the short staves over it, a worn threshold stone
## and, unless something else hangs a door here, a pair of plank leaves.
func _door_frame(side: String, gc: float) -> void:
	for s: float in [-1.0, 1.0]:
		var jx: float = gc + s * (DOOR_W * 0.5 + 0.12)
		dark.beam(Vector3(jx, 0.0, 0.0), Vector3(jx, DOOR_H + 0.02, 0.0), 0.24, 0.32, Vector3.RIGHT, 0.035)
	dark.beam(Vector3(gc - DOOR_W * 0.5 - 0.5, DOOR_H + 0.13, 0.0), Vector3(gc + DOOR_W * 0.5 + 0.5, DOOR_H + 0.13, 0.0),
		0.27, 0.34, Vector3.UP, 0.04)
	var t := gc - DOOR_W * 0.5
	while t < gc + DOOR_W * 0.5 - 0.02:
		var pw := minf(rng.randf_range(0.22, 0.3), gc + DOOR_W * 0.5 - t)
		_board(wood, t + pw * 0.5, pw, DOOR_H + 0.24, h + 0.05)
		t += pw
	# threshold: one broad flat stone, dished by feet
	stone.stone(Vector3(DOOR_W + 0.5, 0.16, 1.0), Transform3D(Basis.IDENTITY, Vector3(gc, -0.03, 0.08)), 0.22)
	var leaf := false
	for d in doors:
		if d["side"] == side and absf(float(d["t"]) - gc) < 0.01:
			leaf = bool(d["leaf"])
	if not leaf:
		return
	var lw := DOOR_W * 0.5 - 0.015
	var a1 := deg_to_rad(rng.randf_range(98.0, 118.0))
	var a2 := deg_to_rad(rng.randf_range(84.0, 104.0))
	_leaf(Transform3D(Basis(Vector3.UP, -a1), Vector3(gc - DOOR_W * 0.5 + 0.01, 0.07, 0.17)), lw, DOOR_H - 0.1, 1.0, true, false)
	_leaf(Transform3D(Basis(Vector3.UP, PI + a2), Vector3(gc + DOOR_W * 0.5 - 0.01, 0.07, 0.17)), lw, DOOR_H - 0.1, -1.0, true, true)

## A plank leaf hinged on its local y axis, boards running from x = 0 to lw.
## face = +1: the weather face is local +z. Door leaves get two ledges and a
## brace on the back, long iron straps and (ring) a ring handle on the front.
func _leaf(hinge: Transform3D, lw: float, lh: float, face: float, door: bool, ring: bool) -> void:
	var keep := wood.xf
	var full := keep * hinge
	wood.xf = full; fine.xf = full; iron.xf = full
	var th := 0.05 if door else 0.03
	var nb := maxi(2, int(round(lw / (0.19 if door else 0.2))))
	var bw := lw / float(nb)
	for k in nb:
		var off := wood.rnd() * 0.006
		wood.box(Vector3(bw - 0.006, lh - wood.rnd() * 0.02, th), Transform3D(Basis.IDENTITY, Vector3(bw * (k + 0.5), lh * 0.5, off)), 1, 0)
	# ledges (and a brace on doors) on the back
	var lz := -face * (th * 0.5 + 0.02)
	var lys: Array = [lh * 0.16, lh * 0.84]
	for ly in lys:
		fine.box(Vector3(lw - 0.04, 0.11 if door else 0.06, 0.04), Transform3D(Basis.IDENTITY, Vector3(lw * 0.5, float(ly), lz)), 0)
	if door:
		var p0 := Vector3(0.06, lh * 0.16 + 0.06, lz)
		var p1 := Vector3(lw - 0.06, lh * 0.84 - 0.06, lz)
		var dir := (p1 - p0).normalized()
		fine.box(Vector3(p0.distance_to(p1), 0.1, 0.036), Transform3D(Basis(dir, Vector3(-dir.y, dir.x, 0), Vector3(0, 0, 1)), (p0 + p1) * 0.5), 0)
	# iron: strap hinges on the weather face, tapering to a point
	var fz := face * (th * 0.5 + 0.006)
	for ly in lys:
		var sl := lw * (0.72 if door else 0.8)
		var sh := 0.05 if door else 0.03
		iron.box(Vector3(sl, sh, 0.008), Transform3D(Basis.IDENTITY, Vector3(sl * 0.5, float(ly), fz)), 0)
		iron.box(Vector3(sh * 1.2, sh * 1.2, 0.008), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), Vector3(sl, float(ly), fz)), 0)
		# the pintle the strap turns on
		iron.box(Vector3(0.03, sh * 1.8, 0.03), Transform3D(Basis.IDENTITY, Vector3(-0.012, float(ly), fz)), 1, 0)
		if door:
			for nx in [0.18, 0.42, 0.62]:
				iron.box(Vector3(0.022, 0.022, 0.012), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), Vector3(sl * float(nx) / 0.72, float(ly), fz + face * 0.008)), 0)
	if ring:
		var rc := Vector3(lw - 0.16, lh * 0.46, face * (th * 0.5 + 0.012))
		iron.box(Vector3(0.09, 0.09, 0.008), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), rc - Vector3(0, 0, face * 0.006)), 0)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.052
		tm.outer_radius = 0.068
		tm.rings = 12
		tm.ring_segments = 5
		iron.append_mesh(tm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3(1, 0, 0), 0.25 * face), rc + Vector3(0, -0.055, face * 0.016)), Vector2(0.4, 0.05))
	wood.xf = keep; fine.xf = keep; iron.xf = keep

## A window hole dressed with a frame and one ledged shutter on strap hinges.
func _window(wn: Dictionary) -> void:
	var t0: float = wn["t0"]
	var t1: float = wn["t1"]
	var y0: float = wn["y0"]
	var y1: float = wn["y1"]
	var fr := 0.07
	# frame: sill, head, jambs, deeper than the staves so the reveal is timber
	dark.box(Vector3(t1 - t0 + 0.26, fr, 0.2), Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3((t0 + t1) * 0.5, y0 - fr * 0.5, 0.03)), 0)
	dark.box(Vector3(t1 - t0 + 0.2, fr, 0.17), Transform3D(Basis.IDENTITY, Vector3((t0 + t1) * 0.5, y1 + fr * 0.5, 0.015)), 0)
	for s in [0, 1]:
		var jx := (t0 - fr * 0.5) if s == 0 else (t1 + fr * 0.5)
		dark.box(Vector3(fr, y1 - y0, 0.17), Transform3D(Basis.IDENTITY, Vector3(jx, (y0 + y1) * 0.5, 0.015)), 1)
	var open: float = wn["open"]
	if open < 0.0:
		# a byre vent: one upright bar across the slot
		fine.box(Vector3(0.035, y1 - y0, 0.035), Transform3D(Basis(Vector3.UP, 0.6), Vector3((t0 + t1) * 0.5, (y0 + y1) * 0.5, 0.0)), 1)
		return
	_leaf(Transform3D(Basis(Vector3.UP, -open), Vector3(t0 - 0.01, y0 + 0.005, 0.118)), t1 - t0 + 0.02, y1 - y0 - 0.01, 1.0, false, false)

# -------------------------------------------------------------------- roof

## Vertical thickness of the turf over the board plane at slope distance u.
func turf_v(u: float, z: float, s: float) -> float:
	var x := s * u
	var t := 0.66 + 0.11 * noise.get_noise_2d(x * 1.7, z * 1.7) + 0.06 * noise.get_noise_2d(x * 5.0 + 9.0, z * 5.0)
	# the ridge: a rounded roll whose line wavers and sags between the gables
	var hump := 1.0 - smoothstep(0.0, 1.0, u)
	t += hump * (0.2 + 0.13 * noise.get_noise_2d(z * 0.55, 40.0) + 0.05 * noise.get_noise_2d(z * 1.9, 71.0))
	# sods lap like big shingles: a faint step every course
	t += 0.035 * (fposmod(u, 0.62) / 0.62)
	return maxf(t, 0.58) / cos(ang)

func _turf_pt(s: float, u: float, z: float) -> Vector3:
	var uu := minf(u, slope)
	var p := Vector3(s * u * cos(ang), h - 0.05 + rise - u * sin(ang), z)
	var t := turf_v(uu, z, s)
	if u > slope:
		# the edge rolls over the turf log
		t *= lerpf(1.0, 0.34, smoothstep(slope, slope + 0.14, u))
	return p + Vector3(0, t, 0)

func build_roof() -> void:
	var zmin := -length * 0.5
	var zmax := length * 0.5
	for s: float in [-1.0, 1.0]:
		# --- turf: a displaced grid, normals from the surface itself -------
		var us: Array = []
		var u := 0.0
		while u < slope - 0.2:
			us.append(u)
			u += 0.31
		us.append(slope)
		us.append(slope + 0.08)
		us.append(slope + 0.14)
		var zs: Array = []
		var z := zmin
		while z < zmax - 0.25:
			zs.append(z)
			z += 0.45
		zs.append(zmax)
		var nu := us.size()
		var nz := zs.size()
		var pts: Array = []
		for i in nu:
			for j in nz:
				pts.append(_turf_pt(s, float(us[i]), float(zs[j])))
		var nrm: Array = []
		for i in nu:
			for j in nz:
				var du: Vector3 = pts[mini(i + 1, nu - 1) * nz + j] - pts[maxi(i - 1, 0) * nz + j]
				var dz: Vector3 = pts[i * nz + mini(j + 1, nz - 1)] - pts[i * nz + maxi(j - 1, 0)]
				var n := dz.cross(du).normalized() * s
				if n.y < 0.0:
					n = -n
				nrm.append(n)
		for i in nu - 1:
			for j in nz - 1:
				var a := i * nz + j
				var b := a + 1
				var c := a + nz + 1
				var d := a + nz
				turf.face_s(pts[a], pts[b], pts[c], pts[d], nrm[a], nrm[b], nrm[c], nrm[d],
					Vector2(float(zs[j]), float(us[i])), Vector2(float(zs[j + 1]), float(us[i])),
					Vector2(float(zs[j + 1]), float(us[i + 1])), Vector2(float(zs[j]), float(us[i + 1])), 0.5)
		# --- the cut soil under the eave roll and along both verges --------
		var sx := slope_xf(s)
		for j in nz - 1:
			var e0: Vector3 = pts[(nu - 1) * nz + j]
			var e1: Vector3 = pts[(nu - 1) * nz + j + 1]
			var f0 := sx * Vector3(slope + 0.1, 0.07, s * float(zs[j]))
			var f1 := sx * Vector3(slope + 0.1, 0.07, s * float(zs[j + 1]))
			soil.face(e0, e1, f1, f0, Vector2(float(zs[j]), 0), Vector2(float(zs[j + 1]), 0),
				Vector2(float(zs[j + 1]), 0.3), Vector2(float(zs[j]), 0.3), Vector3(s, -0.3, 0), 0.5)
		for end in [0, nz - 1]:
			var zn := Vector3(0, 0, -1.0 if end == 0 else 1.0)
			for i in nu - 1:
				var t0: Vector3 = pts[i * nz + end]
				var t1: Vector3 = pts[(i + 1) * nz + end]
				var b0 := sx * Vector3(float(us[i]), 0.06, s * float(zs[end]))
				var b1 := sx * Vector3(float(us[i + 1]), 0.06, s * float(zs[end]))
				soil.face(t0, t1, b1, b0, Vector2(float(us[i]), 0), Vector2(float(us[i + 1]), 0),
					Vector2(float(us[i + 1]), t1.y - b1.y), Vector2(float(us[i]), t0.y - b0.y), zn, 0.5)
		# --- slope-frame parts ---------------------------------------------
		for bf in [wood, dark, bark, fine, stone]:
			(bf as MeshBuf).xf = sx
		# roof boards, seen from below: run down the slope, lapped a hair
		var zb := zmin + 0.02
		while zb < zmax - 0.04:
			var bw := minf(rng.randf_range(0.22, 0.36), zmax - 0.02 - zb)
			var u0 := 0.0
			if louvre_z != INF and zb + bw > louvre_z - 0.42 and zb < louvre_z + 0.42:
				u0 = 0.46
			var dy := -0.05 - wood.rnd() * 0.014
			var o := Vector2(wood.rnd() * 8.0, wood.rnd() * 8.0)
			wood.face(Vector3(u0, dy, s * zb), Vector3(u0, dy, s * (zb + bw)), Vector3(slope + 0.03, dy, s * (zb + bw)), Vector3(slope + 0.03, dy, s * zb),
				Vector2(0, u0) + o, Vector2(bw, u0) + o, Vector2(bw, slope) + o, Vector2(0, slope) + o, Vector3(0, -1, 0), wood.rnd())
			zb += bw
		# the board ends at the eave, and the boards' top where the turf stops
		wood.box(Vector3(0.05, 0.1, length - 0.04), Transform3D(Basis.IDENTITY, Vector3(slope + 0.02, -0.005, 0)), 2)
		# rafters at ~1 m, their tails showing under the eave
		var nr := maxi(2, int(round(l / 1.0)))
		for k in nr + 1:
			var zr := -l * 0.5 + 0.12 + (l - 0.24) * float(k) / float(nr)
			var u0r := 0.06
			if louvre_z != INF and absf(zr - louvre_z) < 0.5:
				u0r = 0.5
			dark.beam(Vector3(u0r, -0.135, s * zr), Vector3(slope + 0.1, -0.135, s * zr), 0.1, 0.15, Vector3(0, 0, 1), 0.02)
		# a purlin under the rafters at mid-slope
		_run(dark, Vector3(slope * 0.5, -0.3, s * (-l * 0.5 + 0.1)), Vector3(slope * 0.5, -0.3, s * (l * 0.5 - 0.1)), 0.085, 6.0)
		# birch bark under the turf, its sheets lapping out past the boards
		var zk := zmin + 0.03
		while zk < zmax - 0.1:
			var kw := minf(rng.randf_range(0.32, 0.75), zmax - 0.03 - zk)
			var prot := rng.randf_range(0.05, 0.17)
			var droop := rng.randf_range(0.04, 0.22)
			var kl := 0.42 + prot
			var bs := Basis(Vector3(0, 0, 1), -droop)
			var pivot := Vector3(slope - 0.38, 0.062 + bark.rnd() * 0.012, s * (zk + kw * 0.5))
			bark.box(Vector3(kl, 0.012, kw + 0.03), Transform3D(bs, pivot + bs * Vector3(kl * 0.5, 0, 0)), 0)
			zk += kw
		# the turf log on its hooks
		_run(dark, Vector3(slope + 0.03, 0.2, s * (zmin + 0.06)), Vector3(slope + 0.03, 0.2, s * (zmax - 0.06)), 0.1, 4.6)
		var zh := zmin + rng.randf_range(0.5, 0.9)
		while zh < zmax - 0.4:
			fine.box(Vector3(0.62, 0.055, 0.075), Transform3D(Basis.IDENTITY, Vector3(slope - 0.14, 0.085, s * zh)), 0)
			fine.box(Vector3(0.07, 0.27, 0.075), Transform3D(Basis(Vector3(0, 0, 1), -0.12), Vector3(slope + 0.16, 0.2, s * zh)), 0)
			zh += rng.randf_range(1.5, 2.1)
		for bf in [wood, dark, bark, fine, stone]:
			(bf as MeshBuf).xf = Transform3D.IDENTITY
	# the ridge beam under the apex
	_run(dark, Vector3(0, h - 0.05 + rise - 0.32, -l * 0.5 + 0.1), Vector3(0, h - 0.05 + rise - 0.32, l * 0.5 - 0.1), 0.1, 6.0)
	_roof_poles()
	if louvre_z != INF:
		_louvre()

## A long log laid in lengths of about `piece`, each a little out of line.
func _run(buf: MeshBuf, a: Vector3, b: Vector3, r: float, piece: float) -> void:
	var total := a.distance_to(b)
	var n := maxi(1, int(round(total / piece)))
	for k in n:
		var p0 := a.lerp(b, float(k) / float(n))
		var p1 := a.lerp(b, float(k + 1) / float(n))
		var j0 := Vector3(buf.rnd() - 0.5, buf.rnd() - 0.5, 0) * 0.03
		var j1 := Vector3(buf.rnd() - 0.5, buf.rnd() - 0.5, 0) * 0.03
		var ext := (p1 - p0).normalized() * 0.08
		buf.pole(p0 - ext + j0, p1 + ext + j1, r * (0.92 + buf.rnd() * 0.16), 0.0, 7, 0.88 + buf.rnd() * 0.1)

## Weighted poles: pairs laid over the ridge and down each slope to hold the
## turf against the wind, a stone at the foot of some.
func _roof_poles() -> void:
	var z := -length * 0.5 + rng.randf_range(1.2, 2.0)
	while z < length * 0.5 - 1.0:
		if louvre_z == INF or absf(z - louvre_z) > 1.1:
			for s: float in [-1.0, 1.0]:
				var zz: float = z + s * 0.09
				var reach := slope * rng.randf_range(0.62, 0.8)
				var pts := PackedVector3Array()
				for u in [-0.42, -0.15, 0.12, 0.5, reach * 0.4, reach * 0.7, reach]:
					var uu: float = u
					var p := _turf_pt(s if uu >= 0.0 else -s, absf(uu), zz)
					pts.append(p + Vector3(0, 0.05 + (0.1 if uu < 0.0 else 0.0), (uu / reach) * rng.randf_range(-0.12, 0.12)))
				dark.tube(pts, rng.randf_range(0.045, 0.06), 6)
				if rng.randf() < 0.45:
					var foot := _turf_pt(s, reach + 0.12, zz)
					stone.stone(Vector3(rng.randf_range(0.22, 0.34), rng.randf_range(0.14, 0.2), rng.randf_range(0.2, 0.3)),
						Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(0, 0, 1), -s * ang), foot + Vector3(0, 0.04, 0)), 0.55)
		z += rng.randf_range(2.4, 3.6)

## The smoke-hole: a boarded curb through the turf, corner posts, slanted
## louvre slats on every side and a little boarded cap.
func _louvre() -> void:
	var cy := h - 0.05 + rise
	var top := cy + turf_v(0.0, louvre_z, 1.0) + 0.1
	var ax := 0.46
	var az := 0.52
	var c := Vector3(0, 0, louvre_z)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			dark.beam(c + Vector3(sx * ax, cy + 0.15, sz * az), c + Vector3(sx * ax, top + 0.5, sz * az), 0.08, 0.08, Vector3.RIGHT, 0.012)
	for sgn: float in [-1.0, 1.0]:
		# curb boards
		wood.box(Vector3(0.035, top - cy + 0.1, az * 2.0), Transform3D(Basis.IDENTITY, c + Vector3(sgn * ax, (top + cy) * 0.5 - 0.02, 0)), 1)
		wood.box(Vector3(ax * 2.0, top - cy + 0.1, 0.035), Transform3D(Basis.IDENTITY, c + Vector3(0, (top + cy) * 0.5 - 0.02, sgn * az)), 0)
		# slats, tipped to shed rain
		for k in 3:
			var y := top + 0.1 + 0.14 * k
			fine.box(Vector3(0.02, 0.13, az * 2.0 - 0.08), Transform3D(Basis(Vector3(0, 0, 1), sgn * 0.6), c + Vector3(sgn * (ax + 0.005), y, 0)), 2)
			fine.box(Vector3(ax * 2.0 - 0.08, 0.13, 0.02), Transform3D(Basis(Vector3.RIGHT, -sgn * 0.6), c + Vector3(0, y, sgn * (az + 0.005))), 0)
		# the cap: two board slopes
		var cap_a := 0.5
		var cw := (ax + 0.16) / cos(cap_a)
		var bs := Basis(Vector3(0, 0, 1), -sgn * cap_a)
		for k in 4:
			var bz := -az - 0.14 + (az * 2.0 + 0.28) * (float(k) + 0.5) / 4.0
			wood.box(Vector3(cw, 0.03, (az * 2.0 + 0.28) / 4.0 - 0.006), Transform3D(bs, c + Vector3(sgn * cw * 0.5 * cos(cap_a), top + 0.52 + (ax + 0.16) * tan(cap_a) * 0.5 + wood.rnd() * 0.008, bz)), 0)
	dark.pole(c + Vector3(0, top + 0.56 + (ax + 0.16) * tan(0.5), -az - 0.2), c + Vector3(0, top + 0.56 + (ax + 0.16) * tan(0.5), az + 0.2), 0.045, 0.0, 6)

## RIME: snow banked against the outside of the walls, as its own rime-only
## mesh. It follows the terrain under it, sits deeper on the lee side and in
## the corners, and is dug out in front of every door. On a deck (no land
## under the wall) it is a thin sill of snow instead.
func build_drifts(terrain: Terrain) -> ArrayMesh:
	var buf := MeshBuf.new(77)
	var prof: Array = [[0.04, 1.0], [0.3, 0.92], [0.62, 0.6], [1.0, 0.26], [1.45, 0.0]]
	var lee_dir := Vector3(-0.8, 0, 0.6)
	for side in ["N", "S", "W", "E"]:
		if side in opens:
			continue
		var sx := side_xf(side)
		var span := side_span(side)
		var gaps := _door_ts(side)
		var out_w := Basis(Vector3.UP, yaw) * sx.basis.z
		var lee := 0.72 + 0.28 * out_w.dot(lee_dir)
		var mid_w := world_of(sx * Vector3(0, 0, 0.8))
		var on_land := terrain != null and terrain.contains(mid_w.x, mid_w.z) and terrain.height_at(mid_w.x, mid_w.z) > origin.y - 0.6
		var ws := 1.0 if on_land else 0.4
		var pts: Array = []
		var nrm_rows := 0
		var t := -span * 0.5 - 0.9
		while t <= span * 0.5 + 0.9 + 0.01:
			var hb := (0.27 + 0.13 * noise.get_noise_2d(t * 1.3, 17.0 + span)) * lee * (1.0 if on_land else 0.45)
			hb *= 1.0 - smoothstep(span * 0.5 - 0.2, span * 0.5 + 0.9, absf(t))
			# corners pile up
			hb *= 1.0 + 0.5 * smoothstep(span * 0.5 - 1.6, span * 0.5 - 0.3, absf(t))
			for g in gaps:
				hb *= smoothstep(DOOR_W * 0.5 + 0.15, DOOR_W * 0.5 + 1.3, absf(t - float(g)))
			for pr in prof:
				var lp := sx * Vector3(t, 0, float(pr[0]) * ws)
				var gy := 0.0
				if on_land:
					var wp := world_of(lp)
					gy = terrain.height_at(wp.x, wp.z) - origin.y
				pts.append(lp + Vector3(0, gy + hb * float(pr[1]) - (0.03 if float(pr[1]) == 0.0 else 0.0), 0))
			nrm_rows += 1
			t += 0.5
		var np := prof.size()
		for i in nrm_rows - 1:
			for j in np - 1:
				var a: Vector3 = pts[i * np + j]
				var b: Vector3 = pts[(i + 1) * np + j]
				var c: Vector3 = pts[(i + 1) * np + j + 1]
				var d: Vector3 = pts[i * np + j + 1]
				if maxf(a.y - d.y, b.y - c.y) < 0.012 and j == 0:
					continue
				var n0 := _grid_n(pts, nrm_rows, np, i, j, sx.basis.z)
				var n1 := _grid_n(pts, nrm_rows, np, i + 1, j, sx.basis.z)
				var n2 := _grid_n(pts, nrm_rows, np, i + 1, j + 1, sx.basis.z)
				var n3 := _grid_n(pts, nrm_rows, np, i, j + 1, sx.basis.z)
				var u0 := float(i) * 0.5
				buf.face_s(a, b, c, d, n0, n1, n2, n3, Vector2(u0, float(prof[j][0])), Vector2(u0 + 0.5, float(prof[j][0])),
					Vector2(u0 + 0.5, float(prof[j + 1][0])), Vector2(u0, float(prof[j + 1][0])), 0.5)
	return buf.commit(MaterialLib.get_mat("M_snow", 2, true))

static func _grid_n(pts: Array, rows: int, cols: int, i: int, j: int, out: Vector3) -> Vector3:
	var du: Vector3 = pts[mini(i + 1, rows - 1) * cols + j] - pts[maxi(i - 1, 0) * cols + j]
	var dv: Vector3 = pts[i * cols + mini(j + 1, cols - 1)] - pts[i * cols + maxi(j - 1, 0)]
	var n := du.cross(dv).normalized()
	if n.y < 0.0:
		n = -n
	return (n + out * 0.15).normalized()

## World position of the smoke-hole mouth (for AreaBuilder's smoke).
func louvre_world() -> Vector3:
	return world_of(Vector3(0, h + rise + 1.5, louvre_z))

# ------------------------------------------------------------------- shade

## Wear / moss / AO for every vertex of a buffer, from where it sits on the
## house. `roof_top` buffers (turf, poles) only take the moss.
func shade(buf: MeshBuf, indoor: bool) -> void:
	var north := Basis(Vector3.UP, -yaw) * Vector3(0, 0, -1)     # world north, in house space
	var hw := w * 0.5
	var hl := l * 0.5
	var dpts: Array = []
	for d in doors:
		dpts.append(side_xf(String(d["side"])) * Vector3(float(d["t"]), 0, 0))
	var hole := Vector3(0, h + rise - 0.1, louvre_z)
	var n := buf.verts.size()
	for i in n:
		var p := buf.verts[i]
		var nr := buf.nrms[i]
		var inside := indoor or (absf(p.x) < hw - 0.02 and absf(p.z) < hl - 0.02)
		var ry := roof_y(p.x)
		var ao := 1.0
		var moss := 0.0
		var wear := 0.3
		if p.y > ry + 0.04 and absf(p.x) < half + 0.3:
			# on top of the roof: weathered, mossy where it faces north
			moss = 0.35 + 0.4 * maxf(nr.dot(north), 0.0)
			ao = 0.95
		elif inside:
			ao = lerpf(0.62, 0.9, smoothstep(0.0, 0.7, p.y))
			# corners gather dark
			var cd := maxf(hw - absf(p.x), hl - absf(p.z))
			ao *= lerpf(0.72, 1.0, smoothstep(0.0, 0.7, cd))
			if louvre_z != INF:
				ao *= lerpf(0.42, 1.0, smoothstep(0.3, 2.2, p.distance_to(hole)))
		else:
			# the wall foot, where rain splashes and no light gets in
			ao = lerpf(0.42, 1.0, smoothstep(0.0, 0.75, p.y))
			# under the eaves and along the rake
			if absf(p.z) < hl + OVER + 0.2:
				ao *= lerpf(0.5, 1.0, smoothstep(0.0, 1.1, ry - p.y))
			moss = (0.18 + 0.82 * maxf(nr.dot(north), 0.0)) * (1.0 - smoothstep(0.3, 2.4, p.y)) + 0.25 * (1.0 - smoothstep(0.0, 0.5, p.y))
		for dp in dpts:
			var q: Vector3 = dp
			var dh := Vector2(p.x - q.x, p.z - q.z).length()
			if dh < 1.7 and p.y < 2.3:
				wear = maxf(wear, lerpf(0.9, 0.3, dh / 1.7))
			# soot and hand-grime over the lintel
			var dy := p.y - (DOOR_H + 0.45)
			var st := exp(-(dh * dh) / 0.9 - (dy * dy) / 0.5)
			if p.y > DOOR_H - 0.1:
				ao *= 1.0 - 0.45 * st
		buf.cols[i] = Color(minf(wear, 0.9), clampf(moss, 0.0, 0.95), clampf(ao, 0.1, 0.97), 1.0)

# ------------------------------------------------------------------ attach

## A MaterialLib family with building-only tweaks (moss that follows the
## vertex mask, a paler tint for bark): a cached duplicate, so the family
## itself is untouched.
static func mat(family: String, mode_: int, variant := "", params := {}) -> Material:
	var base := MaterialLib.get_mat(family, mode_, true)
	if variant == "" or not (base is ShaderMaterial):
		return base
	var key := "%s|%d|%s" % [family, mode_, variant]
	if not _mats.has(key):
		var m := (base as ShaderMaterial).duplicate() as ShaderMaterial
		for k in params:
			m.set_shader_parameter(k, params[k])
		_mats[key] = m
	return _mats[key]

func _add(root: Node3D, buf: MeshBuf, nm: String, material: Material, range_end: float, shadows: bool, indoor := false) -> MeshInstance3D:
	if buf.is_empty():
		return null
	shade(buf, indoor)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = buf.commit(material)
	if range_end > 0.0:
		mi.visibility_range_end = range_end
		mi.visibility_range_end_margin = 4.0
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if indoor:
		mi.set_instance_shader_parameter("indoor", 1.0)
	root.add_child(mi)
	return mi

func tri_total() -> int:
	var n := 0
	for b in [wood, dark, stone, turf, soil, bark, iron, fine, in_wood, in_dark, in_stone, in_cloth, in_rope, in_hide]:
		n += (b as MeshBuf).tri_count()
	return n

func attach(root: Node3D) -> void:
	var mossy := {"moss_strength": 0.95}
	_add(root, wood, "staves", mat("M_wood", mode, "house", mossy), LOD_MID, true)
	_add(root, dark, "frame", mat("M_wood_dark", mode, "house", mossy), LOD_MID, true)
	_add(root, stone, "footing", mat("M_drystone", mode, "house", {"moss_strength": 1.0}), LOD_MID, true)
	_add(root, turf, "turf", mat("M_turf", mode), LOD_MID, true)
	_add(root, soil, "turf_edge", mat("M_peat", mode), LOD_MID, false)
	_add(root, bark, "bark", mat("M_planks", mode, "bark", {"albedo": Color(0.6, 0.56, 0.48), "moss_strength": 0.5, "roughness_v": 0.7}), LOD_NEAR, false)
	_add(root, iron, "iron", mat("M_iron", mode), LOD_NEAR, false)
	_add(root, fine, "fine", mat("M_wood_dark", mode, "house", mossy), LOD_NEAR, false)
	_add(root, in_wood, "in_wood", mat("M_wood", mode, "house", mossy), LOD_MID * 0.7, true, true)
	_add(root, in_dark, "in_frame", mat("M_wood_dark", mode, "house", mossy), LOD_MID * 0.7, true, true)
	_add(root, in_stone, "in_stone", mat("M_drystone", mode), LOD_MID * 0.7, false, true)
	_add(root, in_cloth, "in_cloth", mat("M_wool", mode), LOD_NEAR, false, true)
	_add(root, in_rope, "in_rope", mat("M_rope", mode), LOD_NEAR, false, true)
	_add(root, in_hide, "in_goods", mat("M_leather", mode, "goods", {"albedo": Color(0.36, 0.27, 0.19)}), LOD_NEAR, false, true)
