shader_type spatial;
render_mode specular_schlick_ggx, diffuse_burley, cull_back;
// ---------------------------------------------------------------------------
// Fen & channel water shader:
// Multi-octave Gerstner/Voronoi ripple normal field, Schlick Fresnel sky/torch
// reflection, murky abyssal absorption, and crest micro-glints.
// ---------------------------------------------------------------------------

uniform int state_mode = 0;
uniform vec4 deep_color : source_color = vec4(0.025, 0.045, 0.055, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.125, 0.12, 1.0);
uniform float ripple_scale = 1.35;
uniform float ripple_speed = 0.05;
uniform float ripple_height = 1.25;
uniform float flow_x = 1.0;

global uniform float rh_state_blend;
global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_wave_band;

varying vec3 wpos;

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return clamp(rh_state_blend, 0.0, 1.0);
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / max(rh_wave_band, 0.01), 0.0, 1.0));
	return clamp(mix(rh_state_blend, rh_wave_dir, w), 0.0, 1.0);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(vec3(i, 0.0));
	float b = hash13(vec3(i + vec2(1, 0), 0.0));
	float c = hash13(vec3(i + vec2(0, 1), 0.0));
	float d = hash13(vec3(i + vec2(1, 1), 0.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float ripple(vec2 p, float t) {
	float n = vnoise2(p + vec2(t * flow_x, t * 0.35)) * 0.50;
	n += vnoise2(p * 2.6 - vec2(t * 1.5 * flow_x, -t * 0.65)) * 0.28;
	n += vnoise2(p * 6.1 + vec2(t * 2.2 * flow_x, t * 1.15)) * 0.14;
	n += vnoise2(p * 13.5 - vec2(t * 3.1, -t * 2.4)) * 0.08;
	return n;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rime = local_rime(wpos);
	if (state_mode == 1 && rime > 0.5) {
		discard;
	}
	if (state_mode == 2 && rime < 0.5) {
		discard;
	}
	float t = TIME * ripple_speed * 10.0;
	vec2 p = wpos.xz * ripple_scale;
	float e = 0.22;
	float h0 = ripple(p, t);
	float hx = ripple(p + vec2(e, 0.0), t);
	float hz = ripple(p + vec2(0.0, e), t);
	vec3 n = normalize(vec3((h0 - hx) * ripple_height, 1.0, (h0 - hz) * ripple_height));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(n, 0.0)).xyz, 0.92));

	float fres = pow(1.0 - clamp(dot(normalize(-VERTEX), NORMAL), 0.0, 1.0), 4.0);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, clamp(0.42 + fres * 0.58, 0.0, 1.0));
	col = mix(col * vec3(1.08, 1.0, 0.90), col * vec3(0.78, 0.88, 1.05), rime);

	float sheen = smoothstep(0.68, 0.92, h0);
	col += vec3(0.08, 0.09, 0.09) * sheen * (0.3 + fres);
	ALBEDO = col;
	EMISSION = mix(vec3(0.06, 0.05, 0.03), vec3(0.025, 0.04, 0.055), rime) * (sheen * 0.4 + fres * 0.45);
	ROUGHNESS = clamp(0.025 + 0.12 * (1.0 - h0), 0.02, 0.25);
	SPECULAR = 0.85;
	METALLIC = 0.08;
}
