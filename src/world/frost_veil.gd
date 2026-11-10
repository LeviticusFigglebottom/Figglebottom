class_name FrostVeil
extends Node3D
## The frost veil before a holdfast. Rime-layer entity: pass through to
## begin the fight; it seals at your back until the holdfast rests.

signal boss_engaged

var gate_id := "fog"
var area_id := ""
var boss_spawner: Spawner = null
var has_frame := true
var plane_size := Vector2(3.4, 5.1)
## Per-veil look from the area data ("shader": {param: value}); the
## Netmender's veil is frozen net mesh in rime blue (SLICE.md 3).
var shader_params: Dictionary = {}

## Per-holdfast dressing (look pass 5): the veil is made of what the place
## froze round. Shader params (shaders/frost_veil.gdshader) plus "props":
## "thorn" grows the wood's thorn up the frame, "net" hangs the frozen net.
## An area's "shader" block still overrides any of it.
const DRESS := {
	"hall_veil": {"props": "net"},
	"open_barrow_veil": {"clods": 0.9, "tint": Color(0.80, 0.80, 0.74)},
	"breathing_hole_veil": {"cracks": 0.85, "density": 0.5, "refraction": 1.0, "tint": Color(0.72, 0.86, 0.98)},
	"long_table_veil": {"boards": 0.85, "tint": Color(0.78, 0.83, 0.90)},
	"hedge_veil": {"props": "thorn", "tint": Color(0.80, 0.84, 0.90)},
	"fold_veil": {"strands": 0.9, "tint": Color(0.90, 0.87, 0.78)},
	"wellhead_veil": {"cracks": 0.5, "density": 0.45, "refraction": 1.4, "tint": Color(0.68, 0.88, 0.96)},
}
const FRAME_GLB := "res://assets/models/landmarks/lm_veil_rime.glb"
const NET_GLB := "res://assets/models/landmarks/lm_frost_veil_net.glb"
## the sheets' spacing and bow (m): the veil's visible thickness
const SHEET_GAP := 0.2
const SHEET_BOW := 0.26

var _plane: MeshInstance3D
var _dress: Node3D   # rimed frame, drifting frost, props: melts with the veil
var _zone: Interactable
var _seal: StaticBody3D
var _engaged := false
var intercept: Node = null   # a scripted reveal may stage the first engagement
var _snap_when_ready := false

## Arenas with a second way out list extra veil
## walls in the gate spec: {"at": [x,y,z], "rot": deg, "size": [w,h]} in
## world coords. They stand only while the duel does — no walking out on a
## holdfast mid-fight.
var aux_seal_specs: Array = []
var _aux_walls: Array = []
var _aux_planes: Array = []

func _ready() -> void:
	add_to_group(RH.GROUP_RESPAWN_ON_REST)
	_plane = MeshInstance3D.new()
	_plane.mesh = sheet_mesh(plane_size)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/frost_veil.gdshader")
	var dress: Dictionary = DRESS.get(gate_id, {})
	for k in dress:
		if k != "props":
			m.set_shader_parameter(String(k), dress[k])
	for k in shader_params:
		var v = shader_params[k]
		if v is Array and (v as Array).size() == 3:
			v = Color(float(v[0]), float(v[1]), float(v[2]))
		m.set_shader_parameter(String(k), v)
	_plane.set_surface_override_material(0, m)
	_plane.position = Vector3(0, plane_size.y * 0.5, 0)
	add_child(_plane)
	_build_dress(String(dress.get("props", "")))

	_seal = StaticBody3D.new()
	_seal.collision_layer = 1 << (RH.L_WORLD_RIME - 1)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.6, 3.4, 0.3)
	cs.shape = box
	cs.position.y = 1.7
	_seal.add_child(cs)
	add_child(_seal)

	_zone = Interactable.new()
	_zone.prompt = "Part the frost veil"
	_zone.setup_zone(1.4, 2.0, Vector3(0, 0, 1.2))
	_zone.activated.connect(_on_enter)
	add_child(_zone)
	_build_aux_seals()
	if _snap_when_ready:
		snap_cleared()

## Three bowed sheets in one mesh: back, heart, front (UV2.x = -1, 0, 1).
## The outer two bow away from each other, so from the side the veil is a
## lens about 0.9 m through at the middle instead of a card's edge.
static func sheet_mesh(size: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 10
	var ny := 12
	for layer in [-1, 1, 0]:   # heart last: it refracts the two behind it
		var grid: Array = []
		for j in ny + 1:
			var row: Array = []
			for i in nx + 1:
				var u := float(i) / nx
				var v := float(j) / ny
				# bowed across and, less, up its height; pinned at the edges
				var bow := sin(u * PI) * (0.6 + 0.4 * sin(v * PI))
				var z: float = float(layer) * (SHEET_GAP + SHEET_BOW * bow)
				row.append([Vector3((u - 0.5) * size.x, (0.5 - v) * size.y, z), Vector2(u, v)])
			grid.append(row)
		for j in ny:
			for i in nx:
				for q in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
					var e: Array = grid[j + q[1]][i + q[0]]
					st.set_uv(e[1])
					st.set_uv2(Vector2(float(layer), 0.0))
					st.add_vertex(e[0])
	st.generate_normals()
	return st.commit()

func _build_dress(props: String) -> void:
	_dress = Node3D.new()
	_dress.name = "Dress"
	add_child(_dress)
	var fit := Vector3(plane_size.x / 3.4, plane_size.y / 5.1, 1.0)
	if ResourceLoader.exists(FRAME_GLB):
		var fr := _hero(FRAME_GLB, "M_veil_rime", 0.3)
		fr.scale = fit
		_dress.add_child(fr)
	elif has_frame:
		_dress.add_child(KitLib.instance("frost_veil_frame"))
	if props == "thorn" and ResourceLoader.exists(Forest.HERO_DIR + "hd_thornwall.glb"):
		# the wood's own thorn climbs both jambs and leans in over the gap
		var tm := Forest._mesh("hero|hd_thornwall|M_thorn_rime|0|1.5", 2)
		for sx in [-1.0, 1.0]:
			for k in 2:
				var mi := MeshInstance3D.new()
				mi.mesh = tm
				mi.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.5 * k * sx).rotated(Vector3.BACK, -0.2 * sx * (k + 0.4))
						.scaled_local(Vector3(1.0, 1.25 + 0.3 * k, 0.9)), Vector3(sx * (1.75 * fit.x + 0.15 - 0.3 * k), -0.05, 0.12 * (k * 2 - 1)))
				_dress.add_child(mi)
	elif props == "net" and ResourceLoader.exists(NET_GLB):
		# the Netmender's curtain: her frozen net hangs in the heart of it
		var net := _hero(NET_GLB, "M_veil_rime", 0.15)
		var bb := _aabb(net)
		var k := minf(plane_size.x * 0.92 / maxf(maxf(bb.size.x, bb.size.z), 0.1), plane_size.y * 0.8 / maxf(bb.size.y, 0.1))
		net.scale = Vector3.ONE * k
		if bb.size.z > bb.size.x:
			net.rotation.y = PI * 0.5
		net.position.y = -bb.position.y * k
		_dress.add_child(net)
	# frost hanging in the air about it: slow, drifting, never falling straight
	var p := CPUParticles3D.new()
	p.name = "FrostDrift"
	p.amount = 42
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(plane_size.x * 0.6, plane_size.y * 0.42, 0.7)
	p.direction = Vector3(0.3, -1.0, 0.0)
	p.spread = 70.0
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.22
	p.gravity = Vector3(0, -0.04, 0)
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.08
	p.color = Color(0.86, 0.93, 1.0, 0.75)
	p.mesh = AreaPortal.make_mote_quad(1.0)
	p.position = Vector3(0, plane_size.y * 0.48, 0)
	_dress.add_child(p)

## A GLB instanced with every surface on the hall shader (RIME branch).
static func _hero(path: String, family: String, tint: float) -> Node3D:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		for si in mi.mesh.get_surface_count():
			mi.set_surface_override_material(si, MaterialLib.hero_mat(mi.mesh.surface_get_material(si), family, 2, tint))
	return inst

static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var bb := mi.transform * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out

func _build_aux_seals() -> void:
	for spec in aux_seal_specs:
		var at: Array = spec.get("at", [0, 0, 0])
		var size: Array = spec.get("size", [4.2, 4.0])
		var holder := Node3D.new()
		add_child(holder)
		holder.global_position = Vector3(at[0], at[1], at[2])
		holder.global_rotation = Vector3(0, deg_to_rad(float(spec.get("rot", 0.0))), 0)
		var plane := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(float(size[0]), float(size[1]))
		plane.mesh = quad
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/frost_veil.gdshader")
		plane.set_surface_override_material(0, m)
		plane.position = Vector3(0, float(size[1]) * 0.5, 0)
		plane.visible = false
		holder.add_child(plane)
		var wall := StaticBody3D.new()
		wall.collision_layer = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(size[0]) + 0.2, float(size[1]), 0.3)
		cs.shape = box
		cs.position.y = float(size[1]) * 0.5
		wall.add_child(cs)
		holder.add_child(wall)
		_aux_walls.append(wall)
		_aux_planes.append(plane)

func _set_aux(up: bool) -> void:
	for w in _aux_walls:
		(w as StaticBody3D).collision_layer = (1 << (RH.L_WORLD_RIME - 1)) if up else 0
	for p in _aux_planes:
		(p as MeshInstance3D).visible = up

func _on_enter(player) -> void:
	if _engaged or player == null:
		return
	_engaged = true
	_zone.enabled = false
	# a scripted reveal may stage the first engagement the moment the
	# veil is parted; the step-through still carries the player in
	var staged: bool = intercept != null and is_instance_valid(intercept) \
			and intercept.has_method("on_parted") and intercept.on_parted(self, player)
	# step through the veil
	var through: Vector3 = global_position - global_transform.basis.z * 2.2
	through.y = player.global_position.y
	var tw := create_tween()
	player.lock_control(true)
	tw.tween_property(player, "global_position", through, 0.7)
	tw.tween_callback(func():
		if staged:
			return
		player.lock_control(false)
		for a in get_tree().get_nodes_in_group("allies"):
			if a.has_method("blink_to_player"):
				a.blink_to_player()
		_engage_boss())
	AudioDirector.sfx_at("res://assets/audio/veil_enter.wav", global_position, -2.0)

func _engage_boss() -> void:
	if boss_spawner != null and boss_spawner.current != null and not boss_spawner.current.dead:
		var boss := boss_spawner.current
		if boss.has_method("engage_from_veil"):
			# a holdfast with an intro (the Netmender keeps mending until the
			# Bearer comes close): she raises the bar and the music herself
			boss.engage_from_veil(Game.player)
		else:
			boss.target = Game.player
			boss._set_state(Enemy.ES.ALERT)
			AudioDirector.sfx_at(boss.cfg.get("sfx_alert", ""), boss.global_position, 2.0)
			AudioDirector.boss_theme(boss.id, 1.5)
			for hud in get_tree().get_nodes_in_group("hud"):
				hud.show_boss(boss)
		boss.died.connect(_on_boss_dead)
	_set_aux(true)
	Game.arena_locked = true
	boss_engaged.emit()

func _on_boss_dead(e) -> void:
	Game.on_boss_slain(area_id, e)
	dissolve()

## The veil re-forms with its holdfast. Dying mid-fight used to leave the gate
## sealed and mute (its zone disabled, its died-signal bound to a freed boss),
## so the arena could never be re-entered. Respawn runs with the enemy
## respawns on death/rest: unless the holdfast is slain for good, re-arm.
func respawn() -> void:
	if boss_spawner != null and boss_spawner.dead_once \
			and World.area_flag(area_id, boss_spawner.spawn_flag):
		return   # the holdfast rests forever; the veil stays down
	_engaged = false
	_zone.enabled = true
	_seal.collision_layer = 1 << (RH.L_WORLD_RIME - 1)
	_plane.transparency = 0.0
	_plane.show()
	_dress.scale = Vector3.ONE
	_dress.show()
	_set_aux(false)
	Game.arena_locked = false
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.hide_boss()

## The holdfast already rests (a prior session or an earlier visit): the veil
## must not re-form when the area is rebuilt. Cheap, instant, no tween.
## The builder calls this on a detached tree, before _ready has made the
## parts — remember the order and apply it when they exist.
func snap_cleared() -> void:
	if _zone == null:
		_snap_when_ready = true
		return
	_engaged = true
	_zone.enabled = false
	_seal.collision_layer = 0
	_plane.hide()
	_dress.hide()
	_set_aux(false)

func dissolve() -> void:
	_seal.collision_layer = 0
	_zone.enabled = false
	_set_aux(false)
	Game.arena_locked = false
	var tw := create_tween()
	tw.tween_property(_plane, "transparency", 1.0, 2.0)
	tw.tween_callback(_plane.hide)
	# the rime that framed it slumps and is gone with it
	tw.parallel().tween_property(_dress, "scale", Vector3(1.0, 0.03, 1.0), 2.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(_dress.hide)
	_meltwater()

## The veil falls as meltwater: drops run down where it stood.
func _meltwater() -> void:
	if not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.amount = 140
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(plane_size.x * 0.5, plane_size.y * 0.4, 0.05)
	p.direction = Vector3.DOWN
	p.spread = 4.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	p.color = Color(0.75, 0.86, 1.0, 0.7)
	p.mesh = AreaPortal.make_mote_quad(1.0)
	add_child(p)
	p.position = Vector3(0, plane_size.y * 0.55, 0)
	p.emitting = true
	RH.stop_emitting_after(p, 2.2)
	RH.free_after(p, 3.6)
