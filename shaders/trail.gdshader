shader_type spatial;
// blend_mix, not add: an additive ribbon vanishes over lit snow (RIME)
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;

// ---------------------------------------------------------------------------
// Weapon swing ribbon shader:
// Razor-sharp leading blade edge with dual-octave air-cut streaks and warm
// golden-steel trailing wake.
// UV.x: 0 at current blade edge -> 1 at trailing tail
// UV.y: 0 at hilt base -> 1 at blade tip
// ---------------------------------------------------------------------------

uniform vec3 tint : source_color = vec3(0.96, 0.91, 0.80);
uniform float energy = 0.6;
// 1 = a brand's fire: torn orange streamers and sparks, no pale leading edge
uniform float ember = 0.0;
// opacity of the wake: a maul drags a heavy smear, a spear point barely marks the air
uniform float weight = 1.0;

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

	vec3 wake_col = mix(tint * vec3(1.0, 0.72, 0.42), tint, along);
	// how white the leading edge flashes follows `energy`: steel catches the
	// light (0.6 and up is the full flash), a wooden maul head only smears
	vec3 col = mix(wake_col, vec3(1.0, 0.99, 0.95), clamp(lead_edge, 0.0, 1.0) * clamp(energy * 1.7, 0.0, 1.0));
	// unshaded materials output ALBEDO only (EMISSION is dropped): the glow
	// rides the albedo, a little over 1 at the leading edge so it blooms
	ALBEDO = col * (1.0 + energy * lead_edge * tip_weight);
	float body = pow(along, 0.9) * streak * tip_weight;
	ALPHA = clamp((body + tip_trace * tip_weight) * 0.62 * weight + lead_edge * tip_weight * 0.5, 0.0, 0.9);
	if (ember > 0.5) {
		// fire left in the air: tongues that tear apart as they age, hottest
		// at the head, cooling to a dull red; sparks scattered through it
		float tear = vnoise(vec2(UV.x * 7.0 - TIME * 3.0, UV.y * 9.0 + TIME * 2.2));
		float lick = vnoise(vec2(UV.x * 16.0 - TIME * 9.0, UV.y * 5.0));
		float hold = smoothstep(UV.x * 1.15 - 0.25, UV.x * 1.15 + 0.2, tear * 0.7 + lick * 0.3);
		float band = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.7, UV.y);
		float heat = along * hold * band;
		vec3 fire = mix(tint * vec3(0.8, 0.22, 0.05), tint, smoothstep(0.15, 0.6, heat));
		fire = mix(fire, vec3(1.0, 0.92, 0.66), smoothstep(0.65, 1.0, heat));
		float sp = step(0.965, hash(floor(vec2(UV.x * 60.0 - TIME * 8.0, UV.y * 34.0)))) * along * band;
		ALBEDO = fire * (1.0 + energy * heat) + vec3(1.0, 0.8, 0.4) * sp * 1.5;
		ALPHA = clamp(heat * 0.85 * weight + sp, 0.0, 0.92);
	}
}
