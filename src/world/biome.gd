class_name Biome
## What makes a region its own (docs/art/BIOMES.md): data/biomes/<area>.json.
## One file per region, read by the builders, so the look of a place is data
## in one place and the area generators keep to layout and entities.
##
## {
##   "terrain": {
##     "palette": {"turf_a": [r, g, b], ...},   layer means the photos are re-tinted to
##                                              (any colour uniform of terrain.gdshader)
##     "sets":    {"turf": "sr_turf", ...},     photo set per layer: turf, heath, shingle,
##                                              path, rock, snow, snowp (assets/textures/<set>)
##     "shader":  {"bed_thickness": 0.6, ...}   any float uniform: rock character, scales,
##                                              snow_cover, puddle_amount, snow_ripple
##   },
##   "env":     {"thaw": {...}, "rime": {...}}, state-profile keys (data/state_profiles.json);
##                                              laid over the area's own "env" block
##   "weather": {...},                          Weather keys, laid over the area's "weather"
##   "veg":     {                               ground cover (Scatter.build_veg rules)
##     "density": {"heather": 0.0, "grass": 1.4},   factor per kind; 0 removes it
##     "swap":    {"heather": "sedge"},             draw one kind as another
##     "add":     [ {veg rule}, ... ]               extra rules: new species land here
##   }                                              (branch feat/poi-thornwold-plants)
## }
## Every key is optional; a region with no file looks as its generator made it.

static var _cache: Dictionary = {}

static func of(area_id: String) -> Dictionary:
	if not _cache.has(area_id):
		var d := {}
		var p := "res://data/biomes/%s.json" % area_id
		# --no-biome: the regions as their generators made them (before/after shots)
		if FileAccess.file_exists(p) and not ("--no-biome" in OS.get_cmdline_user_args()):
			var j = JSON.parse_string(FileAccess.get_file_as_string(p))
			if j is Dictionary:
				d = j
			else:
				push_error("Biome: %s does not parse" % p)
		_cache[area_id] = d
	return _cache[area_id]

## `base` with the biome's block laid over it, one level deep per sub-key
## (so "env": {"thaw": {...}} replaces single profile keys, not the profile).
static func over(base: Dictionary, top: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in top:
		if out.has(k) and out[k] is Dictionary and top[k] is Dictionary:
			var m: Dictionary = out[k]
			for k2 in top[k]:
				m[k2] = top[k][k2]
		else:
			out[k] = top[k]
	return out

## The area's veg rules as the biome wants them drawn.
static func veg_rules(area_id: String, rules: Array) -> Array:
	var v: Dictionary = of(area_id).get("veg", {})
	if v.is_empty():
		return rules
	var dens: Dictionary = v.get("density", {})
	var swap: Dictionary = v.get("swap", {})
	var out: Array = []
	for r in rules:
		var rule: Dictionary = (r as Dictionary).duplicate()
		var kind := String(rule.get("kind", "grass"))
		var f := float(dens.get(kind, 1.0))
		if f <= 0.0:
			continue
		rule["density"] = float(rule.get("density", 1.0)) * f
		if swap.has(kind):
			rule["kind"] = String(swap[kind])
		out.append(rule)
	for extra in v.get("add", []):
		out.append(extra)
	return out
