class_name BuildProf
## Build-phase timer for area builds, state flips and respawns
## (docs/qa/STREAMING.md). Phases are milliseconds, kept per area and per
## thread kind (main / worker), so a table can say what a build cost and
## where it ran. During a "window" (a seam crossing, a flip, a respawn) it
## also keeps the most main-thread build work any one frame carried, and the
## names of any phase that ran unsliced on the main thread.
## All statics; safe to call from worker threads.

static var enabled := true
static var _mx := Mutex.new()
## scope -> phase -> [main_ms, worker_ms, calls]
static var _phases: Dictionary = {}
static var _scope := ""            # main thread's current scope (an area id, "flip:…")
static var _lap_us := 0

## the window (crossing / flip / respawn)
static var _win := ""
static var _win_frame := -1
static var _win_frame_ms := 0.0
static var _win_max_ms := 0.0
static var _win_work: Array = []   # work ms of each frame that carried any
static var _win_cur: Dictionary = {}     # this frame's work by phase
static var _win_worst: Dictionary = {}   # the worst frame's
static var _win_wall_max_ms := 0.0
static var _win_last_us := 0
static var _win_frames := 0
static var _win_sync: Array = []   # phases that ran unsliced on the main thread
static var windows: Dictionary = {}   # name -> last closed window's report

static func is_main() -> bool:
	return OS.get_thread_caller_id() == OS.get_main_thread_id()

static func now() -> int:
	return Time.get_ticks_usec()

## Main-thread lap timing for the synchronous build: begin a scope, then
## lap(phase) books the time since the last lap to that phase.
static func begin(scope: String) -> void:
	_scope = scope
	_lap_us = now()

static func scope() -> String:
	return _scope

static func lap(phase: String) -> void:
	if not enabled:
		return
	var t := now()
	add(_scope, phase, t - _lap_us, true)
	_lap_us = t

## Skip the time since the last lap (work that belongs to nobody's phase).
static func relap() -> void:
	_lap_us = now()

## Book `usec` of `phase` under `scope`. `sync` marks work that ran as one
## unsliced block (a synchronous build phase), as against a budgeted slice.
static func add(scope_: String, phase: String, usec: int, sync := false) -> void:
	if not enabled:
		return
	var main := is_main()
	var ms := usec / 1000.0
	_mx.lock()
	if not _phases.has(scope_):
		_phases[scope_] = {}
	var row: Array = _phases[scope_].get(phase, [0.0, 0.0, 0])
	row[0 if main else 1] += ms
	row[2] += 1
	_phases[scope_][phase] = row
	if main and _win != "":
		_frame_add(ms, phase)
		if sync and ms >= 1.0:
			_win_sync.append("%s/%s %.1f" % [scope_, phase, ms])
	_mx.unlock()

## A budgeted slice of streaming work on the main thread: booked to its
## phase, and to the frame it ran in.
static func slice(scope_: String, phase: String, t0: int) -> void:
	add(scope_, phase, now() - t0, false)

static func _frame_add(ms: float, phase: String) -> void:
	var f := Engine.get_process_frames()
	if f != _win_frame:
		if _win_frame >= 0 and _win_frame_ms > 0.0:
			_win_work.append(_win_frame_ms)
		_win_frame = f
		_win_frame_ms = 0.0
		_win_cur = {}
	_win_frame_ms += ms
	_win_cur[phase] = float(_win_cur.get(phase, 0.0)) + ms
	if _win_frame_ms >= _win_max_ms:
		_win_max_ms = _win_frame_ms
		_win_worst = _win_cur.duplicate()

## Open a measuring window. Call tick() once a frame while it is open (the
## Streamer does) so the wall-clock frame time is kept beside the work time.
static func window_open(name: String) -> void:
	_mx.lock()
	_win = name
	_win_frame = -1
	_win_frame_ms = 0.0
	_win_max_ms = 0.0
	_win_work = []
	_win_cur = {}
	_win_worst = {}
	_win_wall_max_ms = 0.0
	_win_last_us = now()
	_win_frames = 0
	_win_sync = []
	_mx.unlock()

static func window_name() -> String:
	return _win

static func tick() -> void:
	if _win == "":
		return
	var t := now()
	_win_wall_max_ms = maxf(_win_wall_max_ms, (t - _win_last_us) / 1000.0)
	_win_last_us = t
	_win_frames += 1

## Close the window: {name, max_work_ms, second_work_ms, work_frames,
## max_frame_ms, frames, sync}.
##   max_work_ms: the most streaming/build work one main-thread frame carried
##   second_work_ms: the next most (one frame the OS took away from us does
##     not fail a test on a loaded box; two would)
##   work_frames: frames that carried any
##   worst: the worst frame's work by phase
##   max_frame_ms: the longest wall-clock frame (everything: game, render)
##   sync: build phases that ran unsliced on the main thread in the window
static func window_close() -> Dictionary:
	_mx.lock()
	if _win_frame_ms > 0.0:
		_win_work.append(_win_frame_ms)
	_win_work.sort()
	var second: float = _win_work[_win_work.size() - 2] if _win_work.size() >= 2 else 0.0
	var rep := {"name": _win, "max_work_ms": _win_max_ms, "second_work_ms": second, "work_frames": _win_work.size(),
		"max_frame_ms": _win_wall_max_ms, "frames": _win_frames, "sync": _win_sync.duplicate(),
		"worst": _win_worst.duplicate()}
	if _win != "":
		windows[_win] = rep
	_win = ""
	_mx.unlock()
	return rep

static func phases(scope_: String) -> Dictionary:
	_mx.lock()
	var d: Dictionary = _phases.get(scope_, {}).duplicate(true)
	_mx.unlock()
	return d

static func total_ms(scope_: String, main_only := true) -> float:
	var t := 0.0
	var d := phases(scope_)
	for k in d:
		t += float(d[k][0]) + (0.0 if main_only else float(d[k][1]))
	return t

static func clear(scope_ := "") -> void:
	_mx.lock()
	if scope_ == "":
		_phases.clear()
	else:
		_phases.erase(scope_)
	_mx.unlock()

## Markdown table: one row per phase, one column per scope ("main" or
## "main+worker" ms).
static func table(scopes: Array, titles: Array = []) -> String:
	var names: Array = []
	for s in scopes:
		for k in phases(String(s)):
			if not names.has(k):
				names.append(k)
	var out := "| phase |"
	var sep := "|---|"
	for i in scopes.size():
		out += " %s |" % (String(titles[i]) if i < titles.size() else String(scopes[i]))
		sep += "---:|"
	out += "\n" + sep + "\n"
	var tot_main: Array = []
	var tot_work: Array = []
	tot_main.resize(scopes.size()); tot_main.fill(0.0)
	tot_work.resize(scopes.size()); tot_work.fill(0.0)
	for k in names:
		out += "| %s |" % k
		for i in scopes.size():
			var row: Array = phases(String(scopes[i])).get(k, [0.0, 0.0, 0])
			tot_main[i] += float(row[0])
			tot_work[i] += float(row[1])
			out += " %s |" % _cell(float(row[0]), float(row[1]))
		out += "\n"
	out += "| **total** |"
	for i in scopes.size():
		out += " **%s** |" % _cell(float(tot_main[i]), float(tot_work[i]))
	return out + "\n"

static func _cell(main_ms: float, worker_ms: float) -> String:
	if worker_ms >= 0.05:
		return "%.0f (+%.0f w)" % [main_ms, worker_ms]
	return "%.0f" % main_ms if main_ms >= 0.5 else ("%.1f" % main_ms if main_ms > 0.0 else "0")
