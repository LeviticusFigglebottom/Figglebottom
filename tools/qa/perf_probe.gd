extends Node
## Draw-call probe for docs/qa/PERF.md: builds Saltfell, stands a camera at
## the full-slice route's worst spots (from the route log) in both states,
## and prints draw calls, objects, primitives and frame time per pose.
## Run with a renderer:
##   xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1280x720 \
##     -- --scene=res://tools/qa/perf_probe.tscn [--perf-out=PATH]

const AID := "saltfell_steading"
## [name, cam position, yaw deg, pitch deg]; player-height framing
const POSES := [
	["strand_landing", Vector3(-3.0, 4.6, 65.5), 200.0, -12.0],
	["strand_boats", Vector3(-7.0, 2.8, 77.5), 37.0, -10.0],
	["cliff_path_top", Vector3(-30.0, 24.0, 30.0), 120.0, -16.0],
	["yard_ingra", Vector3(16.5, 24.0, -2.0), 99.0, -10.0],
	["yard_salt_house", Vector3(-24.0, 24.2, 25.0), -46.0, -10.0],
	["longhouse_hall", Vector3(1.0, 24.0, -28.0), 172.0, -12.0],
]

var _out := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--perf-out="):
			_out = a.get_slice("=", 1)
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	World.reset()
	var area := AreaBuilder.build(AID)
	add_child(area)
	Game.register_area(area, AID)
	var cam := Camera3D.new()
	cam.fov = 62
	cam.far = 300.0
	add_child(cam)
	cam.make_current()
	var rows := []
	for st in [RH.WState.THAW, RH.WState.RIME]:
		World.set_area_state(AID, st)
		StateDirector.snap(area, st)
		await _frames(10)
		for p in POSES:
			cam.global_position = p[1]
			cam.rotation = Vector3(deg_to_rad(p[3]), deg_to_rad(p[2]), 0)
			await _frames(6)
			var dc := 0.0
			var ob := 0.0
			var pr := 0.0
			var ms := 0.0
			for i in 4:
				await get_tree().process_frame
				dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				ob += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
				pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
				ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var row := {"pose": p[0], "state": "rime" if st == RH.WState.RIME else "thaw",
				"draw_calls": int(dc / 4.0), "objects": int(ob / 4.0), "prims": int(pr / 4.0),
				"frame_ms": snappedf(ms / 4.0, 0.1)}
			rows.append(row)
			print("[perf] %-16s %-4s draws %5d  objects %5d  prims %8d  %6.1f ms" % [row["pose"], row["state"], row["draw_calls"], row["objects"], row["prims"], row["frame_ms"]])
	var mm := area.find_children("*", "MultiMeshInstance3D", true, false)
	var inst := 0
	for m in mm:
		inst += (m as MultiMeshInstance3D).multimesh.instance_count
	print("[perf] multimesh nodes %d, instances %d, mesh instances %d" % [mm.size(), inst,
		area.find_children("*", "MeshInstance3D", true, false).size()])
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "\t"))
	AudioDirector.shutdown()
	Game.quit()
