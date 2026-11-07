class_name FrostFX
extends RefCounted
## Particle dressing for the state wave and the RIME air: six-armed snow
## crystals, soft motes (pollen, warm dust, steam) and meltwater drips.
## Textures are drawn once in code and cached (no art files to source).

static var _crystal: ImageTexture = null
static var _soft: ImageTexture = null
static var _drip: ImageTexture = null

## A six-armed dendrite crystal, white on transparent.
static func crystal_tex() -> ImageTexture:
	if _crystal != null:
		return _crystal
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := Vector2(s, s) * 0.5
	for arm in 6:
		var a := TAU * arm / 6.0 + PI / 2.0
		var dir := Vector2(cos(a), sin(a))
		_line(img, c, c + dir * 29.0, 1.6)
		# side branches, shorter toward the tip, swept outward
		for k in [0.38, 0.6, 0.8]:
			var base: Vector2 = c + dir * 29.0 * float(k)
			var blen := 10.0 * (1.15 - float(k))
			for sgn in [-1.0, 1.0]:
				var b := dir.rotated(float(sgn) * deg_to_rad(58.0))
				_line(img, base, base + b * blen, 1.0)
	_crystal = ImageTexture.create_from_image(img)
	return _crystal

## A soft round mote with a bright core.
static func soft_tex() -> ImageTexture:
	if _soft != null:
		return _soft
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s * 0.5, y + 0.5 - s * 0.5).length() / (s * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_soft = ImageTexture.create_from_image(img)
	return _soft

## A falling droplet: a short vertical streak with a round head.
static func drip_tex() -> ImageTexture:
	if _drip != null:
		return _drip
	var w := 16
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := absf(x + 0.5 - w * 0.5) / (w * 0.5)
			var head := clampf(1.0 - Vector2(dx, (y - h * 0.8) / (w * 0.5)).length(), 0.0, 1.0)
			var tail := clampf(1.0 - dx * 2.2, 0.0, 1.0) * clampf(float(y) / (h * 0.8), 0.0, 1.0) * 0.55
			img.set_pixel(x, y, Color(1, 1, 1, maxf(head, tail)))
	_drip = ImageTexture.create_from_image(img)
	return _drip

static func _line(img: Image, a: Vector2, b: Vector2, r: float) -> void:
	var n := int(a.distance_to(b) * 2.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for y in range(int(p.y - r - 1), int(p.y + r + 2)):
			for x in range(int(p.x - r - 1), int(p.x + r + 2)):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var d := Vector2(x + 0.5, y + 0.5).distance_to(p)
				var al := clampf(r + 0.5 - d, 0.0, 1.0)
				if al > img.get_pixel(x, y).a:
					img.set_pixel(x, y, Color(1, 1, 1, al))

## A billboarded particle material.
static func material(tex: Texture2D, color: Color, additive := false, align_y := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if align_y else BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.albedo_color = color
	return mat

static func clear_cache() -> void:
	_crystal = null
	_soft = null
	_drip = null
