shader_type spatial;
render_mode cull_disabled, unshaded, blend_add, depth_draw_never;

// ---------------------------------------------------------------------------
// Weapon swing ribbon shader:
// Razor-sharp leading blade edge with dual-octave air-cut streaks and warm
// golden-steel trailing wake.
// UV.x: 0 at current blade edge -> 1 at trailing tail
// UV.y: 0 at hilt base -> 1 at blade tip
// ---------------------------------------------------------------------------

uniform vec3 tint : source_color = vec3(0.96, 0.91, 0.80);
uniform float energy = 2.15;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float along = clamp(1.0 - UV.x, 0.0, 1.0);
	// Dual-octave directional speed-lines along the arc
	float s1 = vnoise(vec2(UV.x * 4.5 - TIME * 14.0, UV.y * 24.0));
	float s2 = vnoise(vec2(UV.x * 9.0 - TIME * 22.0, UV.y * 48.0));
	float streak = 0.55 + 0.30 * s1 + 0.15 * s2;
	// Concentrate brilliance near the blade tip (UV.y 0.60..0.96) and leading edge (UV.x ~ 0)
	float tip_weight = smoothstep(0.0, 0.20, UV.y) * (0.40 + 0.60 * smoothstep(0.32, 0.88, UV.y)) * smoothstep(1.0, 0.92, UV.y);
	float lead_edge = pow(along, 4.2) * 1.85;
	float tip_trace = smoothstep(0.82, 0.95, UV.y) * smoothstep(1.0, 0.93, UV.y) * pow(along, 1.15) * 0.9;
	float ribbon = (pow(along, 1.45) * streak + tip_trace) * tip_weight;

	vec3 wake_col = mix(tint * vec3(1.0, 0.78, 0.52), tint, along);
	vec3 col = mix(wake_col, vec3(1.0, 0.99, 0.95), clamp(lead_edge, 0.0, 1.0));
	ALBEDO = vec3(0.0);
	EMISSION = col * energy * (ribbon + lead_edge * tip_weight * 0.85);
	ALPHA = clamp((ribbon + lead_edge * 0.55) * 0.94, 0.0, 1.0);
}
