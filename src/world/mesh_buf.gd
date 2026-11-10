class_name MeshBuf
extends RefCounted
## Indexed triangle buffers for generated construction detail (BuildingGen):
## boards, beams, logs, stones. Like ProcMesh, every UV is in METRES with V
## along the piece's grain, and UV2.x carries one tone per piece, so
## MaterialLib's photo sets read at world scale in uv mode. Unlike ProcMesh it
## writes vertex colours (hall.gdshader: R = edge wear, G = moss zone, B = AO),
## which is how walls get contact shadow at their feet, moss on their north
## sides and soot over their doors, and it computes tangents analytically, so
## a house of forty thousand vertices costs no SurfaceTool index/tangent pass.

var verts := PackedVector3Array()
var nrms := PackedVector3Array()
var tans := PackedFloat32Array()
var uvs := PackedVector2Array()
var uv2s := PackedVector2Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
## Applied to everything emitted after it is set (a wall side, a roof slope).
var xf := Transform3D.IDENTITY
## Wear / moss / AO written on new vertices; shade passes rewrite it later.
var col := Color(0.3, 0.0, 0.92, 1.0)

var _seed := 1

func _init(seed := 1) -> void:
	_seed = seed * 2 + 1

## The next number of a small deterministic stream (uv offsets, tones).
func rnd() -> float:
	_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
	return float(_seed & 0xffff) / 65535.0

func is_empty() -> bool:
	return verts.is_empty()

func tri_count() -> int:
	return idx.size() / 3

func _tangent(a: Vector3, b: Vector3, d: Vector3, ua: Vector2, ub: Vector2, ud: Vector2, n: Vector3) -> Plane:
	var e1 := b - a
	var e2 := d - a
	var d1 := ub - ua
	var d2 := ud - ua
	var det := d1.x * d2.y - d2.x * d1.y
	if absf(det) < 1e-9:
		var t0 := e1.normalized() if e1.length_squared() > 1e-12 else Vector3.RIGHT
		return Plane(t0, 1.0)
	var t := ((e1 * d2.y - e2 * d1.y) / det)
	var bv := ((e2 * d1.x - e1 * d2.x) / det)       # dP/dV
	t = (t - n * n.dot(t)).normalized()
	# GL normal maps: green points toward decreasing v
	var w := 1.0 if n.cross(t).dot(-bv) >= 0.0 else -1.0
	return Plane(t, w)

func _push(p: Vector3, n: Vector3, tg: Plane, uv: Vector2, tone: float) -> void:
	verts.append(p)
	nrms.append(n)
	tans.append(tg.normal.x); tans.append(tg.normal.y); tans.append(tg.normal.z); tans.append(tg.d)
	uvs.append(uv)
	uv2s.append(Vector2(tone, 0.0))
	cols.append(col)

## A flat quad. Corners run counter-clockwise seen from outside.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, tone := 0.5) -> void:
	a = xf * a; b = xf * b; c = xf * c; d = xf * d
	var n := (b - a).cross(d - a)
	if n.length_squared() < 1e-14:
		n = (c - b).cross(a - b)
	n = n.normalized()
	var tg := _tangent(a, b, d, ua, ub, ud, n)
	var i := verts.size()
	_push(a, n, tg, ua, tone); _push(b, n, tg, ub, tone); _push(c, n, tg, uc, tone); _push(d, n, tg, ud, tone)
	idx.append(i); idx.append(i + 2); idx.append(i + 1)
	idx.append(i); idx.append(i + 3); idx.append(i + 2)

## A quad with its own normals (logs, rounded stones, turf). Normals are local
## to `xf` like the corners.
func quad_s(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, tone := 0.5) -> void:
	a = xf * a; b = xf * b; c = xf * c; d = xf * d
	var bs := xf.basis
	na = (bs * na).normalized(); nb = (bs * nb).normalized(); nc = (bs * nc).normalized(); nd = (bs * nd).normalized()
	var fn := (b - a).cross(d - a).normalized()
	var tg := _tangent(a, b, d, ua, ub, ud, fn)
	var i := verts.size()
	_push(a, na, tg, ua, tone); _push(b, nb, tg, ub, tone); _push(c, nc, tg, uc, tone); _push(d, nd, tg, ud, tone)
	idx.append(i); idx.append(i + 2); idx.append(i + 1)
	idx.append(i); idx.append(i + 3); idx.append(i + 2)

func tri(a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, tone := 0.5) -> void:
	a = xf * a; b = xf * b; c = xf * c
	var n := (b - a).cross(c - a).normalized()
	var tg := _tangent(a, b, c, ua, ub, uc, n)
	var i := verts.size()
	_push(a, n, tg, ua, tone); _push(b, n, tg, ub, tone); _push(c, n, tg, uc, tone)
	idx.append(i); idx.append(i + 2); idx.append(i + 1)

## quad() with the winding chosen so the face looks toward `want`.
func face(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2,
		want: Vector3, tone := 0.5) -> void:
	if (b - a).cross(d - a).dot(want) >= 0.0:
		quad(a, b, c, d, ua, ub, uc, ud, tone)
	else:
		quad(a, d, c, b, ua, ud, uc, ub, tone)

## quad_s() with the winding chosen from the first normal.
func face_s(a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, tone := 0.5) -> void:
	if (b - a).cross(d - a).dot(na + nc) >= 0.0:
		quad_s(a, b, c, d, na, nb, nc, nd, ua, ub, uc, ud, tone)
	else:
		quad_s(a, d, c, b, na, nd, nc, nb, ua, ud, uc, ub, tone)

## A round pole laid through `pts` (a roof pole following the turf, a rope).
func tube(pts: PackedVector3Array, r: float, sides := 6, hint := Vector3.BACK, tone := -1.0) -> void:
	if pts.size() < 2:
		return
	var rings: Array = []
	for k in pts.size():
		var y := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var hz := hint
		if absf(y.dot(hz)) > 0.95:
			hz = Vector3.UP
		var x := y.cross(hz).normalized()
		var z := x.cross(y).normalized()
		rings.append(Transform3D(Basis(x, y, z), pts[k]))
	extrude(round_profile(r, sides, 0.94), rings, true, true, true, tone)

func _uvo() -> Vector2:
	return Vector2(rnd() * 9.0, rnd() * 9.0)

## A box of `size` placed by `t`. grain: 0/1/2 = x/y/z runs along V; -1 = the
## longest axis. skip: bit mask of faces to leave out (1 +x, 2 -x, 4 +y, 8 -y,
## 16 +z, 32 -z), for faces buried in a wall or the ground.
func box(size: Vector3, t: Transform3D, grain := -1, skip := 0, tone := -1.0) -> void:
	var g := grain
	if g < 0:
		g = 0 if (size.x >= size.y and size.x >= size.z) else (1 if size.y >= size.z else 2)
	var h := size * 0.5
	var o := _uvo()
	if tone < 0.0:
		tone = rnd()
	var keep := xf
	xf = xf * t
	for f in 6:
		if skip & (1 << f):
			continue
		var ax := f >> 1
		var sg := 1.0 if (f & 1) == 0 else -1.0
		var u_ax := (ax + 1) % 3
		var v_ax := (ax + 2) % 3
		var pts: Array[Vector3] = []
		for k in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			var p := Vector3.ZERO
			p[ax] = sg * h[ax]
			p[u_ax] = k[0] * h[u_ax] * sg
			p[v_ax] = k[1] * h[v_ax]
			pts.append(p)
		# V along the grain when the grain lies in this face
		var gv: int = g if g != ax else v_ax
		var gu: int = u_ax if gv != u_ax else v_ax
		quad(pts[0], pts[1], pts[2], pts[3],
			Vector2(pts[0][gu], -pts[0][gv]) + o, Vector2(pts[1][gu], -pts[1][gv]) + o,
			Vector2(pts[2][gu], -pts[2][gv]) + o, Vector2(pts[3][gu], -pts[3][gv]) + o, tone)
	xf = keep

## A cross-section (x, z points, any winding) swept through `rings`: each
## ring places the section in its own XZ plane, so rings can lean, bow and
## twist (a warped stave, a sagging pole). U runs round the section, V along
## the sweep, both in metres. smooth = round log; otherwise hard arrises.
func extrude(profile: PackedVector2Array, rings: Array, smooth := false, cap_start := true, cap_end := true, tone := -1.0) -> void:
	var np := profile.size()
	if np < 3 or rings.size() < 2:
		return
	# counter-clockwise seen from +Y, so side quads face outward
	var area2 := 0.0
	var cen := Vector2.ZERO
	for i in np:
		var p := profile[i]
		var q := profile[(i + 1) % np]
		area2 += p.x * q.y - q.x * p.y
		cen += p
	cen /= float(np)
	var prof := profile
	if area2 > 0.0:
		prof = profile.duplicate()
		prof.reverse()
	if tone < 0.0:
		tone = rnd()
	var o := _uvo()
	var per := PackedFloat32Array()
	per.resize(np + 1)
	per[0] = 0.0
	for i in np:
		per[i + 1] = per[i] + prof[i].distance_to(prof[(i + 1) % np])
	var along := 0.0
	for k in rings.size() - 1:
		var r0: Transform3D = rings[k]
		var r1: Transform3D = rings[k + 1]
		var seg := r0.origin.distance_to(r1.origin)
		for i in np:
			var j := (i + 1) % np
			var pi3 := Vector3(prof[i].x, 0, prof[i].y)
			var pj3 := Vector3(prof[j].x, 0, prof[j].y)
			var a := r0 * pi3
			var b := r0 * pj3
			var c := r1 * pj3
			var d := r1 * pi3
			var ua := Vector2(per[i], -along) + o
			var ub := Vector2(per[i + 1], -along) + o
			var uc := Vector2(per[i + 1], -along - seg) + o
			var ud := Vector2(per[i], -along - seg) + o
			if smooth:
				var ni := Vector3(prof[i].x - cen.x, 0, prof[i].y - cen.y)
				var nj := Vector3(prof[j].x - cen.x, 0, prof[j].y - cen.y)
				quad_s(a, b, c, d, r0.basis * ni, r0.basis * nj, r1.basis * nj, r1.basis * ni, ua, ub, uc, ud, tone)
			else:
				quad(a, b, c, d, ua, ub, uc, ud, tone)
		along += seg
	for e in 2:
		if (e == 0 and not cap_start) or (e == 1 and not cap_end):
			continue
		var r: Transform3D = rings[0] if e == 0 else rings[rings.size() - 1]
		var c3 := r * Vector3(cen.x, 0, cen.y)
		for i in np:
			var j := (i + 1) % np
			var a := r * Vector3(prof[i].x, 0, prof[i].y)
			var b := r * Vector3(prof[j].x, 0, prof[j].y)
			if e == 0:
				tri(c3, b, a, cen + o, prof[j] + o, prof[i] + o, tone)
			else:
				tri(c3, a, b, cen + o, prof[i] + o, prof[j] + o, tone)

## Rings for a straight sweep from `a` to `b` in n segments, the section's
## local X turned toward `side` (any vector not parallel to the sweep).
static func rings_between(a: Vector3, b: Vector3, side: Vector3, n := 1) -> Array:
	var y := (b - a).normalized()
	var z := side.cross(y).normalized()
	var x := y.cross(z).normalized()
	var bs := Basis(x, y, z)
	var out: Array = []
	for k in n + 1:
		out.append(Transform3D(bs, a.lerp(b, float(k) / float(n))))
	return out

## A rectangle section with chamfered arrises (an adzed beam).
static func beam_profile(w: float, d: float, chamfer := 0.02) -> PackedVector2Array:
	var hw := w * 0.5
	var hd := d * 0.5
	var c := minf(chamfer, minf(hw, hd) * 0.6)
	return PackedVector2Array([Vector2(-hw + c, -hd), Vector2(hw - c, -hd), Vector2(hw, -hd + c), Vector2(hw, hd - c),
		Vector2(hw - c, hd), Vector2(-hw + c, hd), Vector2(-hw, hd - c), Vector2(-hw, -hd + c)])

## A round section of n sides (a pole, a log), slightly out of true.
static func round_profile(r: float, n := 8, squash := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(Vector2(cos(a) * r, sin(a) * r * squash))
	return out

## A straight chamfered beam from a to b (section w across `side`, d deep).
func beam(a: Vector3, b: Vector3, w: float, d: float, side := Vector3.RIGHT, chamfer := 0.02, tone := -1.0) -> void:
	if absf((b - a).normalized().dot(side.normalized())) > 0.98:
		side = Vector3.UP if absf((b - a).normalized().y) < 0.9 else Vector3.BACK
	extrude(beam_profile(w, d, chamfer), rings_between(a, b, side), false, true, true, tone)

## A round pole from a to b, sagging `sag` metres at mid-span.
func pole(a: Vector3, b: Vector3, r: float, sag := 0.0, sides := 7, taper := 1.0, tone := -1.0) -> void:
	var n := 1 if absf(sag) < 0.001 else 4
	var y := (b - a).normalized()
	var side := Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT
	var z := side.cross(y).normalized()
	var x := y.cross(z).normalized()
	var rings: Array = []
	for k in n + 1:
		var t := float(k) / float(n)
		var p := a.lerp(b, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		var s := lerpf(1.0, taper, t)
		rings.append(Transform3D(Basis(x * s, y, z * s), p))
	extrude(round_profile(r, sides, 0.92), rings, true, true, true, tone)

## A rounded field stone: a box whose faces swell toward a sphere.
func stone(size: Vector3, t: Transform3D, roundness := 0.4, tone := -1.0) -> void:
	var o := _uvo()
	if tone < 0.0:
		tone = rnd()
	var keep := xf
	xf = xf * t
	var inv := Vector3(1.0 / maxf(size.x, 0.01), 1.0 / maxf(size.y, 0.01), 1.0 / maxf(size.z, 0.01))
	for f in 6:
		var ax := f >> 1
		var sg := 1.0 if (f & 1) == 0 else -1.0
		var u_ax := (ax + 1) % 3
		var v_ax := (ax + 2) % 3
		var fn := Vector3.ZERO
		fn[ax] = sg
		var grid: Array = []
		var gn: Array = []
		var guv: Array = []
		for j in 3:
			for i in 3:
				var p := Vector3.ZERO
				p[ax] = sg * 0.5
				p[u_ax] = (float(i) - 1.0) * 0.5 * sg
				p[v_ax] = (float(j) - 1.0) * 0.5
				var sph := p.normalized()
				var q := p.lerp(sph * 0.64, roundness)
				grid.append(q * size)
				gn.append((fn.lerp(sph, clampf(roundness * 1.5, 0.0, 1.0)) * inv).normalized())
				guv.append(Vector2(p[u_ax] * size[u_ax], -p[v_ax] * size[v_ax]) + o)
		for j in 2:
			for i in 2:
				var a := j * 3 + i
				quad_s(grid[a], grid[a + 1], grid[a + 4], grid[a + 3], gn[a], gn[a + 1], gn[a + 4], gn[a + 3],
					guv[a], guv[a + 1], guv[a + 4], guv[a + 3], tone)
	xf = keep

## Any PrimitiveMesh (torus ring, sphere) with its UVs scaled to metres.
func append_mesh(mesh: Mesh, t: Transform3D, uv_scale := Vector2.ONE, tone := -1.0) -> void:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var tg: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT] if arr[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if tone < 0.0:
		tone = rnd()
	var o := _uvo()
	var full := xf * t
	var nb := full.basis.inverse().transposed()
	var base := verts.size()
	for i in v.size():
		var nn := (nb * n[i]).normalized()
		var tt := Plane(Vector3.RIGHT, 1.0)
		if tg.size() >= (i + 1) * 4:
			tt = Plane((full.basis * Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])).normalized(), tg[i * 4 + 3])
		_push(full * v[i], nn, tt, (uv[i] if i < uv.size() else Vector2.ZERO) * uv_scale + o, tone)
	if ix.is_empty():
		for i in v.size():
			idx.append(base + i)
	else:
		for i in ix:
			idx.append(base + i)

## Commit to a mesh (null when nothing was emitted).
func commit(mat: Material = null) -> ArrayMesh:
	if verts.is_empty():
		return null
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if mat != null:
		mesh.surface_set_material(0, mat)
	return mesh
