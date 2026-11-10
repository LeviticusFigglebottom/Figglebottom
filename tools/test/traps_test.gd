extends TestBase
## Traps: ground the Bearer can drop onto and not walk out of is marked by
## tools/fix_traps.py and watched by TrapWarden. Checks that every area with a
## mask gets a warden that knows its cells, that safe ground is not marked,
## and (driving the warden's own step) that standing stranded sets the Bearer
## back on the last safe spot, while falling through or crossing does not.

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for area_id in ["saltfell_steading", "lowe_barrows", "kettle_fjord", "tarnhall"]:
		print("== ", area_id)
		var has_mask := FileAccess.file_exists(TrapWarden.mask_path(area_id))
		var area := AreaBuilder.build(area_id)
		add_child(area)
		await ticks(2)
		var w := area.get_node_or_null("TrapWarden") as TrapWarden
		check((w != null) == has_mask, "a warden exactly where a mask is (%s)" % ("mask" if has_mask else "none"))
		if w != null:
			var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TrapWarden.mask_path(area_id)))
			var run: Array = d["thaw"][0] if not (d["thaw"] as Array).is_empty() else d["rime"][0]
			var st := "thaw" if not (d["thaw"] as Array).is_empty() else "rime"
			var trap := Vector3(float(run[1]), 0.0, float(run[0]))
			trap.y = area.terrain.height_at(trap.x, trap.z)
			var def: Dictionary = area.get_meta("def", {})
			var sp: Array = def["start"]["pos"]
			var safe := Vector3(float(sp[0]), float(sp[1]), float(sp[2]))
			check(w.is_trap(trap, st), "the mask's first cell is a trap")
			check(not w.is_trap(safe, "thaw") and not w.is_trap(safe, "rime"), "the start is safe ground")
			# stand on safe ground, then stranded in the trap
			for i in 60:
				w.step(safe, true, st, 1.0 / 60.0)
			var back := Vector3.INF
			var n := 0
			while back == Vector3.INF and n < 600:
				back = w.step(trap, true, st, 1.0 / 60.0)
				n += 1
			check(back != Vector3.INF and back.distance_to(safe) < 0.01, "stranded %.1f s: set back on the last safe ground" % (n / 60.0))
			check(n > 60, "not before he has stood there a while")
			# falling through, or a moment's crossing, does nothing
			var moved := false
			for i in 400:
				if w.step(trap, false, st, 1.0 / 60.0) != Vector3.INF:
					moved = true
			check(not moved, "falling through a trap is not being stranded")
			moved = false
			for i in 30:
				if w.step(trap, true, st, 1.0 / 60.0) != Vector3.INF:
					moved = true
			check(not moved, "half a second in a trap is not being stranded")
		area.queue_free()
		await ticks(2)
	finish()
