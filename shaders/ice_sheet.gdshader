shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx, diffuse_burley;
// ---------------------------------------------------------------------------
// ice_sheet.gdshader: a hand's depth of clear sea ice over dark water.
// Whatever lies just under the surface (the boats that were leaving, the
// shingle of the shore) shows through, bent a little and tinted; with depth it
// fades into blue-black. Frost and blown snow lie in drifts on top, and pale
// cracks run through it. Composited against the screen (refraction), lit only
// for the frost and the sheen on top.
// ---------------------------------------------------------------------------

uniform int state_mode = 2;
uniform vec3 ice_tint : source_color = vec3(0.56, 0.72, 0.84);
uniform vec3 deep_tint : source_color = vec3(0.16, 0.30, 0.40);
uniform float clarity = 1.3;      // metres before the ice reads opaque
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// look pass: the CC0 ice and snow photo sets (MaterialLib binds them)
uniform sampler2D ice_alb : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ice_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_alb : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 ice_mean = vec3(1.0);
uniform vec3 snow_mean = vec3(1.0);
uniform float photo = 0.0;   // 1 once the sets are bound

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

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.3) * 0.28 + vnoise(p * 5.1) * 0.17;
}

// cracks: the edges of a coarse cell pattern, wandering
float cracks(vec2 p) {
	p += vec2(fbm(p * 0.7), fbm(p * 0.7 + 9.0)) * 1.4;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0, d2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash12(i + g), hash12(i + g + 17.0));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return 1.0 - smoothstep(0.0, 0.025, d2 - d1);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rime = local_rime(wpos);
	if (state_mode == 1 && rime > 0.5) { discard; }
	if (state_mode == 2 && rime < 0.5) { discard; }
	// how far the eye travels through ice and water to what is under it
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	v.xyz /= v.w;
	float through = max(0.0, VERTEX.z - v.z);
	vec2 wp = wpos.xz;
	float frost = smoothstep(0.6, 0.86, fbm(wp * 0.11 + vec2(3.1, 7.7)));
	float drift = smoothstep(0.66, 0.95, fbm(vec2(wp.x * 0.05, wp.y * 0.22)));
	float snow = clamp(frost * 0.7 + drift, 0.0, 1.0);
	float crk = cracks(wp * 0.07) * (1.0 - snow) * (0.25 + 0.5 * vnoise(wp * 0.05));
	// bend what is under it a little
	vec2 bend = (vec2(vnoise(wp * 1.3), vnoise(wp * 1.3 + 5.0)) - 0.5) * 0.012;
	vec3 under = textureLod(screen_tex, SCREEN_UV + bend, 0.0).rgb;
	float op = 1.0 - exp(-through / clarity);
	vec3 seen = mix(under * mix(vec3(1.0), ice_tint, 0.4) * 1.3, deep_tint, op);
	// photo detail: trapped bubbles and fractures in the ice, grain in the frost
	vec3 ice_ph = mix(vec3(1.0), texture(ice_alb, wp * 0.16).rgb / max(ice_mean, vec3(0.01)), photo);
	float ice_l = dot(ice_ph, vec3(0.3, 0.5, 0.2));
	seen *= mix(vec3(1.0), ice_ph, 0.3);
	crk = max(crk, smoothstep(1.7, 2.4, ice_l) * 0.25 * photo * (1.0 - snow));
	vec3 snow_ph = mix(vec3(1.0), texture(snow_alb, wp * 0.3).rgb / max(snow_mean, vec3(0.01)), photo);
	// the surface itself: snow-white frost, pale cracks, a cold sheen
	vec3 frost_c = vec3(0.86, 0.9, 0.95) * snow_ph;
	float cover = clamp(snow * 0.85 + crk * 0.6 + 0.04, 0.0, 1.0);
	vec2 inr = (texture(ice_nrm, wp * 0.16).rg * 2.0 - 1.0) * 0.35 * photo * (1.0 - cover);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(inr.x, 1.0, -inr.y)), 0.0)).xyz);
	ALBEDO = frost_c * cover + ice_tint * 0.12 * (1.0 - cover);
	EMISSION = seen * (1.0 - cover);
	ROUGHNESS = mix(0.06, 0.85, cover);
	SPECULAR = 0.7;
	ALPHA = 1.0;
}
