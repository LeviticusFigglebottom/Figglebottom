class_name StreamCache
## Disk cache for what an area build can keep between runs (ADR 0014):
## ground-cover instance buffers, terrain chunk arrays, baked navmeshes.
## Entries live in user://cache/<kind>_<key>.<ext>; the key is a content hash
## of every input the cached thing was computed from PLUS the source of the
## builder scripts, so data or code that changes can only miss, never serve
## something stale. A missing, short or corrupt entry reads as a miss and the
## caller builds as before. Safe to call from worker threads.
##   --cache-dir=PATH   keep the cache somewhere else (tests: a scratch dir)
##   --no-cache         never read or write (always build)

## Bump when a cached layout changes shape (the content of an entry, not the
## builders: their source is hashed into every key already).
const VERSION := 4
## The scripts whose output is cached, or feeds what is cached.
const CODE := [
	"res://src/world/scatter.gd", "res://src/world/terrain.gd", "res://src/world/area.gd",
	"res://src/world/area_builder.gd", "res://src/world/building_gen.gd", "res://src/world/house_detail.gd",
	"res://src/world/house_interior.gd", "res://src/world/house_yard.gd", "res://src/world/forest.gd",
	"res://src/world/kit_lib.gd", "res://src/world/wayside.gd", "res://src/world/mesh_buf.gd",
	"res://src/world/proc_mesh.gd", "res://src/core/nav_baker.gd",
]
## Oldest entries go once the cache holds more than this (user data budget).
const MAX_BYTES := 512 * 1024 * 1024

static var enabled := true
static var _dir := "user://cache"
static var _seed := ""       # a second, read-only place to look (shipped beside the executable)
static var _ready := false
static var _code_sig := ""
static var _mx := Mutex.new()
static var hits := 0
static var misses := 0

static func _setup() -> void:
	if _ready:
		return
	_mx.lock()
	if not _ready:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--cache-dir="):
				_dir = arg.get_slice("=", 1)
			elif arg == "--no-cache":
				enabled = false
			elif arg.begins_with("--cache-seed="):
				_seed = arg.get_slice("=", 1)
		# a cache shipped with the game (tools/qa/warm_cache.sh): read-only,
		# looked in when user://cache has no entry
		if _seed == "":
			var beside := OS.get_executable_path().get_base_dir().path_join("cache_seed")
			if DirAccess.dir_exists_absolute(beside):
				_seed = beside
		_code_sig = _hash_code()
		if enabled:
			DirAccess.make_dir_recursive_absolute(_dir)
		_ready = true
	_mx.unlock()

## Tests: point the cache at a scratch directory (and forget the counters).
static func use_dir(path: String, on := true) -> void:
	_setup()
	_mx.lock()
	_dir = path
	_seed = ""
	enabled = on
	hits = 0
	misses = 0
	if on:
		DirAccess.make_dir_recursive_absolute(_dir)
	_mx.unlock()

static func dir() -> String:
	_setup()
	return _dir

## The builders' own source, hashed: an exported build carries compiled
## scripts (.gdc) instead, which hash as well. With neither readable only
## VERSION and the engine version stand guard.
static func _hash_code() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(("v%d|%s" % [VERSION, Engine.get_version_info().get("string", "")]).to_utf8_buffer())
	for p in CODE:
		var b := PackedByteArray()
		for cand in [p, p + "c", p.get_basename() + ".gdc"]:
			if FileAccess.file_exists(cand):
				b = FileAccess.get_file_as_bytes(cand)
				break
		ctx.update(("%s:%d" % [p, b.size()]).to_utf8_buffer())
		if not b.is_empty():
			ctx.update(b)
	return ctx.finish().hex_encode()

static func code_sig() -> String:
	_setup()
	return _code_sig

## A key from any mix of Variants (strings, numbers, packed arrays, nested
## containers). Packed arrays are hashed by content.
static func key(parts: Array) -> String:
	_setup()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(_code_sig.to_utf8_buffer())
	for p in parts:
		if p is PackedByteArray:
			ctx.update(("b%d" % (p as PackedByteArray).size()).to_utf8_buffer())
			if not (p as PackedByteArray).is_empty():
				ctx.update(p)
		elif p is PackedFloat32Array:
			var fb := (p as PackedFloat32Array).to_byte_array()
			ctx.update(("f%d" % fb.size()).to_utf8_buffer())
			if not fb.is_empty():
				ctx.update(fb)
		else:
			ctx.update(var_to_bytes(p))
		ctx.update("|".to_utf8_buffer())
	return ctx.finish().hex_encode()

static func path_of(kind: String, k: String, ext := "bin") -> String:
	return dir().path_join("%s_%s.%s" % [kind, k, ext])

## A cached Variant, or null on a miss (absent, unreadable, wrong shape).
static func load_var(kind: String, k: String) -> Variant:
	_setup()
	if not enabled:
		return null
	var p := _find(kind, k)
	var out: Variant = null
	if p != "":
		var f := FileAccess.open_compressed(p, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if f != null:
			# [magic, payload]: a truncated or foreign file fails one of the two
			var head = f.get_var(false) if f.get_length() > 8 else null
			if head is String and head == "RHC%d" % VERSION and f.get_position() < f.get_length():
				out = f.get_var(false)
				if f.get_error() != OK:
					out = null
			f.close()
	_mx.lock()
	if out == null:
		misses += 1
	else:
		hits += 1
	_mx.unlock()
	return out

static func store_var(kind: String, k: String, value: Variant) -> void:
	_setup()
	if not enabled or value == null:
		return
	var p := path_of(kind, k)
	# written beside, then renamed: a crash mid-write leaves no half entry
	var tmp := "%s.%d.part" % [p, OS.get_thread_caller_id()]
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return
	f.store_var("RHC%d" % VERSION, false)
	f.store_var(value, false)
	var ok := f.get_error() == OK
	f.close()
	if ok:
		DirAccess.rename_absolute(tmp, p)
	else:
		DirAccess.remove_absolute(tmp)

static func has_var(kind: String, k: String) -> bool:
	_setup()
	return enabled and _find(kind, k) != ""

## Where an entry is: the cache itself, else the shipped seed, else "".
static func _find(kind: String, k: String) -> String:
	var p := path_of(kind, k)
	if FileAccess.file_exists(p):
		return p
	if _seed != "":
		p = _seed.path_join("%s_%s.bin" % [kind, k])
		if FileAccess.file_exists(p):
			return p
	return ""

## Drop the oldest entries past MAX_BYTES (and any stray .part files).
## Cheap enough for boot: a directory listing and a sort.
static func prune(max_bytes := MAX_BYTES) -> void:
	_setup()
	if not enabled:
		return
	var d := DirAccess.open(_dir)
	if d == null:
		return
	var files: Array = []
	var total := 0
	for f in d.get_files():
		var p := _dir.path_join(f)
		if f.contains(".part"):
			# another run may be writing it this second: only old strays go
			if Time.get_unix_time_from_system() - FileAccess.get_modified_time(p) > 600:
				DirAccess.remove_absolute(p)
			continue
		var fa := FileAccess.open(p, FileAccess.READ)
		var sz := fa.get_length() if fa != null else 0
		total += sz
		files.append([FileAccess.get_modified_time(p), p, sz])
	if total <= max_bytes:
		return
	files.sort()
	for e in files:
		DirAccess.remove_absolute(String(e[1]))
		total -= int(e[2])
		if total <= max_bytes:
			break

static func clear() -> void:
	_setup()
	var d := DirAccess.open(_dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(_dir.path_join(f))
