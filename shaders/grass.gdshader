shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

// ---------------------------------------------------------------------------
// grass.gdshader — instanced turf, heather and sedge clumps (Scatter "veg").
// Vertex colour: rgb = blade colour, a = height along the blade (0 root, 1 tip).
// Wind: a slow travelling gust plus a fast flutter, scaled by blade height so
// roots stay planted. RIME: tips frost white, clumps stiffen (no sway).
// ---------------------------------------------------------------------------

uniform float wind_strength = 0.16;
uniform vec2 wind_dir = vec2(0.8, -0.6);
uniform vec3 tip_tint : source_color = vec3(1.0, 0.95, 0.75);
uniform int state_mode = 0;

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;

varying vec3 v_wp;
varying float v_h;

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float rime = local_rime(wp);
	float h = COLOR.a;
	float gust = sin(dot(wp.xz, wind_dir) * 0.35 - TIME * 1.7) * 0.5 + 0.5;
	float flutter = sin(TIME * 5.3 + wp.x * 2.1 + wp.z * 1.7) * 0.25;
	float bend = (gust * 0.8 + flutter) * wind_strength * h * h * (1.0 - rime * 0.85);
	// sway in world space, then back into the instance's frame
	vec3 off_w = vec3(wind_dir.x, -0.15, wind_dir.y) * bend;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off_w, 0.0)).xyz;
	// RIME: the snow has most clumps outright; the rest show only their tips
	vec3 org = MODEL_MATRIX[3].xyz;
	float keep = fract(sin(dot(org.xz, vec2(12.9898, 78.233))) * 43758.5453);
	// the survivors stand as short stiff stubs gathered in a tuft, not
	// blades splayed flat on the snow
	VERTEX.y *= 1.0 - 0.55 * rime;
	VERTEX.xz *= 1.0 - 0.6 * rime;
	if (rime > 0.5 && keep < 0.8) {
		VERTEX = vec3(0.0, -0.3, 0.0);
	}
	v_wp = wp;
	v_h = h;
	// clumps light like a soft dome, not like flat cards
	// (in RIME they light like the snow they stand in)
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), NORMAL, 0.35 * (1.0 - rime)));
}

void fragment() {
	float rime = local_rime(v_wp);
	if (state_mode == 1 && rime > 0.5) {
		discard;
	}
	if (state_mode == 2 && rime < 0.5) {
		discard;
	}
	vec3 c = COLOR.rgb * mix(0.5, 0.9, v_h);
	vec3 thaw_c = mix(c, c * tip_tint * 1.1, v_h * v_h * 0.35);
	float luma = dot(c, vec3(0.3, 0.59, 0.11));
	// frost-rimed tufts with a cap of snow: pale throughout, never dark blades
	vec3 rime_c = mix(vec3(0.78, 0.82, 0.88) + vec3(luma) * 0.1, vec3(0.95, 0.97, 1.0), smoothstep(0.05, 0.5, v_h));
	ALBEDO = mix(thaw_c, rime_c, rime);
	ROUGHNESS = 0.9;
	BACKLIGHT = mix(vec3(0.16, 0.14, 0.05), vec3(0.1, 0.12, 0.15), rime) * v_h;
	AO = mix(mix(0.55, 0.95, rime), 1.0, v_h);
}
