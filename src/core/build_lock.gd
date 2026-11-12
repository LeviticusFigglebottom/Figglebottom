class_name BuildLock
## One lock round the static caches that both an area build and live play
## reach (MaterialLib, KitLib, Forest meshes): while a neighbouring area is
## being built on a worker thread (Streamer, ADR 0014), the main thread may
## ask the same caches for a material or a kit piece.
##
## The worker simply locks. The main thread must never sleep on the lock: a
## worker that holds it may itself be waiting for the main thread to answer
## a RenderingServer read (PrimitiveMesh.surface_get_arrays and friends are
## answered when the main thread flushes its queue). So the main thread spins
## on try_lock and pumps that queue until the worker lets go.
## With no worker build running the main thread does not lock at all.
##
##   var lk := BuildLock.lock()
##   ...
##   BuildLock.unlock(lk)

static var _mx := Mutex.new()
## Set and cleared on the main thread only (Streamer), before the worker
## task starts and after it is seen to have ended.
static var worker_busy := false
## Longest the main thread waited for the lock, ms (STREAMING.md).
static var max_wait_ms := 0.0
## Set by the worker while it is in a phase of plain arithmetic (ground
## cover, terrain arrays) that asks the renderer nothing: the main thread
## need not keep answering.
static var computing := false

static func lock() -> bool:
	if OS.get_thread_caller_id() != OS.get_main_thread_id():
		_mx.lock()
		return true
	if not worker_busy:
		return false
	if not _mx.try_lock():
		var t0 := Time.get_ticks_usec()
		while not _mx.try_lock():
			pump()
			OS.delay_usec(50)
			if Time.get_ticks_usec() - t0 > 2000000:
				# never hang the game on a cache: go on unlocked and say so
				push_warning("BuildLock: main thread waited 2 s for a worker build; going on without the lock")
				return false
		max_wait_ms = maxf(max_wait_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	# what the worker has just made (a material, a mesh) is only allocated
	# until the main thread carries out its queued creation: do that before
	# anything here is handed a cache entry it might draw with this frame
	pump()
	return true

static func unlock(locked: bool) -> void:
	if locked:
		_mx.unlock()

## Answer whatever the worker is waiting on the main thread for: renderer
## reads, and what it has asked to have done here (on_main).
static func pump() -> void:
	RenderingServer.force_sync()
	if _asked.is_empty():
		return
	_ask_mx.lock()
	var todo := _asked
	_asked = []
	_ask_mx.unlock()
	for e in todo:
		(e[0] as Callable).call()
		(e[1] as Semaphore).post()

static var _asked: Array = []       # [[callable, semaphore]]
static var _ask_mx := Mutex.new()

## Run `fn` on the main thread and wait for it (on the main thread: just run
## it). For the few things a build must not make beside the main thread: a
## StandardMaterial3D joins an engine-wide list the main thread works
## through every frame, updating each material's shader as it goes, and a
## worker touching the same material at that moment corrupts the heap.
static func on_main(fn: Callable) -> void:
	if OS.get_thread_caller_id() == OS.get_main_thread_id():
		fn.call()
		return
	var sem := Semaphore.new()
	_ask_mx.lock()
	_asked.append([fn, sem])
	_ask_mx.unlock()
	sem.wait()

## Main thread: wait (pumping) until no worker build runs. The synchronous
## AreaBuilder.build calls this, so two builds never share the builders'
## own statics. `done` reports whether the worker has ended.
static func wait_idle(done: Callable, max_s := 120.0) -> void:
	var t0 := Time.get_ticks_usec()
	while worker_busy and not done.call():
		pump()
		OS.delay_usec(200)
		if Time.get_ticks_usec() - t0 > int(max_s * 1000000.0):
			push_error("BuildLock: a worker build did not end in %d s" % int(max_s))
			return
