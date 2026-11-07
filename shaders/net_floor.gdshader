shader_type spatial;
// The Longhouse floor in RIME (SLICE.md 4): one frozen net, wall to wall,
// with the boards showing through. Knotted rope lines on a diamond grid;
// only the rope is drawn. `slide` moves the whole net (the Netmender hauls
// the floor toward her); `pulse` brightens it (her phase changes).
render_mode cull_disabled, depth_draw_opaque;

uniform vec2 slide = vec2(0.0);
uniform float cell = 0.42;
uniform float rope = 0.035;
uniform vec3 rope_color : source_color = vec3(0.74, 0.8, 0.86);
uniform vec3 frost_color : source_color = vec3(0.9, 0.95, 1.0);
uniform float pulse = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (wpos.xz - slide) / cell;
	// diamond mesh: two families of diagonal lines
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 0.7071;
	vec2 d = abs(fract(q) - 0.5);
	float w = rope / cell;
	float line = max(1.0 - smoothstep(w * 0.6, w, 0.5 - d.x), 1.0 - smoothstep(w * 0.6, w, 0.5 - d.y));
	// knots where the lines cross
	vec2 k = abs(fract(q + 0.5) - 0.5);
	float knot = 1.0 - smoothstep(w * 1.4, w * 2.1, length(k));
	float m = max(line, knot);
	if (m < 0.5) {
		discard;
	}
	float frost = fract(sin(dot(floor(q), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(rope_color, frost_color, 0.35 + 0.35 * frost);
	ROUGHNESS = 0.7;
	EMISSION = vec3(0.35, 0.6, 1.0) * pulse * (0.6 + knot);
}
