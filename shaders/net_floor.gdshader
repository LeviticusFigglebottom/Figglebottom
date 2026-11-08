shader_type spatial;
// The Longhouse floor in RIME (SLICE.md 4): one frozen fishing net, wall to
// wall, the boards showing through. A diamond mesh of twisted twine, each
// bar sagging a little between its knots, a fat sheet-bend knot at every
// crossing, rime furring the knots and catching along the bars. Only the
// twine is drawn. `slide` moves the whole net (she hauls the floor toward
// her); `pulse` lights it (her phase changes). A hanging sheet (the net train
// lifted like a sail) maps by UV instead of world xz.
render_mode cull_disabled, depth_draw_opaque;

uniform vec2 slide = vec2(0.0);
uniform float cell = 0.34;          // knot to knot (m)
uniform float rope = 0.032;         // twine width (m)
uniform float sag = 0.12;           // bar sag, in cells
uniform vec3 rope_color : source_color = vec3(0.24, 0.27, 0.31);
uniform vec3 tar_color : source_color = vec3(0.16, 0.15, 0.14);
uniform vec3 frost_color : source_color = vec3(0.82, 0.88, 0.95);
uniform float pulse = 0.0;
uniform bool use_uv = false;
uniform vec2 uv_size = vec2(4.0, 3.2);

varying vec3 wpos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = use_uv ? UV * uv_size / cell : (wpos.xz - slide) / cell;
	// diamond mesh: knots on a grid rotated 45 degrees
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.70710678;
	vec2 id = floor(q);
	vec2 f = fract(q);
	float w = rope / cell;
	// each bar bows between its two knots (a sine along the bar, zero at
	// the knots), by an amount hashed from the bar itself so both cells that
	// share it agree, and the net does not lie ruler-straight
	float bow = sin(f.y * 3.14159);
	float bow2 = sin(f.x * 3.14159);
	float sl = sag * (hash2(vec2(id.x, id.y) + 0.17) - 0.5) * 2.0;
	float sr = sag * (hash2(vec2(id.x + 1.0, id.y) + 0.17) - 0.5) * 2.0;
	float sb = sag * (hash2(vec2(id.x, id.y) + 5.3) - 0.5) * 2.0;
	float st = sag * (hash2(vec2(id.x, id.y + 1.0) + 5.3) - 0.5) * 2.0;
	float ex = min(abs(f.x - sl * bow), abs(1.0 - f.x + sr * bow));
	float ey = min(abs(f.y - sb * bow2), abs(1.0 - f.y + st * bow2));
	float bar_x = 1.0 - smoothstep(w * 0.35, w * 0.55, ex);
	float bar_y = 1.0 - smoothstep(w * 0.35, w * 0.55, ey);
	// knots at the cell corners: a squashed lump, a little off-round
	vec2 kc = f - round(f);
	kc.x *= 1.0 + 0.35 * hash2(round(q));
	float knot = 1.0 - smoothstep(w * 1.15, w * 1.45, length(kc));
	float m = max(max(bar_x, bar_y), knot);
	if (m < 0.5) {
		discard;
	}
	// twine twist: a fine diagonal stripe along each bar
	float twist = 0.5 + 0.5 * sin((q.x + q.y) * 90.0);
	vec3 twine = mix(rope_color, tar_color, 0.35 * twist);
	// rime: knots heavily furred, bars flecked
	float fleck = step(0.72, hash2(floor(p * 22.0)));
	float rime = clamp(knot * 0.75 + fleck * 0.45 + 0.12, 0.0, 1.0);
	ALBEDO = mix(twine, frost_color, rime);
	ROUGHNESS = mix(0.85, 0.35, rime);
	SPECULAR = mix(0.2, 0.6, rime);
	EMISSION = vec3(0.35, 0.6, 1.0) * pulse * (0.4 + knot);
}
