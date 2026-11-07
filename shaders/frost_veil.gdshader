shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;

// ---------------------------------------------------------------------------
// Holdfast arena frost veil:
// Billowing multi-layered pearlescent frost-mist with soft swirling eddies
// and gentle golden-silver inner luminescence (no harsh contour stripes).
// ---------------------------------------------------------------------------

uniform vec3 tint : source_color = vec3(0.84, 0.81, 0.73);
uniform float density : hint_range(0.0, 1.0) = 0.68;

varying vec3 v_lp;
varying vec3 v_nrm;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x),
		mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x),
		mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.08 + vec3(4.3, -2.7, 1.9);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_lp = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec2 uv = v_lp.xy;
	// Counter-rotating dual-layer domain warp for billowing smoke plumes
	vec3 q = vec3(
		fbm(vec3(uv * 0.95 + vec2(0.0, -TIME * 0.14), TIME * 0.11)),
		fbm(vec3(uv * 0.95 + vec2(3.4, -TIME * 0.18), TIME * 0.13 + 5.2)),
		0.0
	);
	vec2 warped1 = uv + (q.xy - 0.5) * 0.72;
	vec2 warped2 = uv * 1.45 - (q.yx - 0.5) * 0.55 + vec2(TIME * 0.06, -TIME * 0.22);

	float cloud1 = fbm(vec3(warped1 * 1.4, TIME * 0.16));
	float cloud2 = fbm(vec3(warped2 * 1.8 + 7.1, TIME * 0.22));
	float mist = mix(cloud1, cloud2, 0.48);

	// Soft billowing density with subtle luminous crests
	float body = smoothstep(0.18, 0.78, mist);
	float crest = pow(clamp(cloud1 * cloud2 * 2.2, 0.0, 1.0), 2.2);

	// Pointed-arch framing matching frost_veil_frame intrados & threshold floor pooling
	float hx = abs(UV.x - 0.5) * 2.0;
	float hy = 1.0 - UV.y;
	float dy = max(hy - 0.565, 0.0) / 0.425;
	float max_hx = 0.90 * clamp((sqrt(max(1.0 - dy * dy * 0.91, 0.0)) - 0.305) / 0.695, 0.0, 1.0);
	float edge_x = smoothstep(max_hx, max(max_hx - 0.24, 0.0), hx);
	float edge_y = smoothstep(-0.01, 0.09, hy) * smoothstep(0.99, 0.90, hy);
	float floor_pool = smoothstep(0.18, -0.01, hy) * 0.22;
	float frame = edge_x * edge_y;

	vec3 deep_col = tint * vec3(0.52, 0.56, 0.64);
	vec3 crest_col = tint * vec3(1.22, 1.15, 0.96);
	vec3 col = mix(deep_col, crest_col, clamp(body * 0.65 + crest * 0.55, 0.0, 1.0));

	ALBEDO = col;
	EMISSION = col * (0.38 + body * 0.52 + crest * 0.65);
	ALPHA = clamp((body * density + floor_pool + 0.18 + crest * 0.20) * frame, 0.0, 0.92);
}
