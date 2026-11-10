shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// ---------------------------------------------------------------------------
// coals.gdshader: the bed of a hearth. Charcoal lumps with fire in the cracks
// between them. THAW: lit, breathing orange under a skin of ash. RIME: the
// fire is banked almost out; a few deep cracks still hold a dull red ember.
// Follows the state wave, so a hearth dims as the rime front crosses it.
// ---------------------------------------------------------------------------

uniform vec3 hot_col : source_color = vec3(1.0, 0.5, 0.12);
uniform vec3 ember_col : source_color = vec3(0.9, 0.16, 0.03);
uniform vec3 char_col : source_color = vec3(0.035, 0.03, 0.028);
uniform vec3 ash_col : source_color = vec3(0.34, 0.32, 0.3);
uniform float glow_thaw = 5.0;
uniform float glow_rime = 0.9;
uniform float lump_scale = 21.0;

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;

varying vec3 v_op;
varying vec3 v_wp;

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Worley: x = distance to the nearest lump centre, y = distance to its edge
vec3 lumps(vec2 p) {
	vec2 n = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash2(n + g);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1; d1 = d;
				id = o.x;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2 - d1, id);
}

void vertex() {
	v_op = VERTEX;
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rime = local_rime(v_wp);
	vec3 l = lumps(v_op.xz * lump_scale + v_op.y * 3.0);
	float crack = 1.0 - smoothstep(0.0, 0.16, l.y);
	// each lump breathes on its own clock; the cracks pulse with the draught
	float breath = 0.75 + 0.25 * sin(TIME * (1.1 + l.z * 1.7) + l.z * 40.0);
	float draught = 0.85 + 0.15 * sin(TIME * 3.1 + v_op.x * 9.0 + v_op.z * 7.0);
	// the centre of the bed is the hottest
	float core = 1.0 - smoothstep(0.1, 0.42, length(v_op.xz));
	float face_heat = smoothstep(0.55, 0.0, l.x) * step(0.45, l.z) * core;
	float heat_thaw = clamp(crack * (0.55 + 0.6 * core) + face_heat * 0.55 * breath, 0.0, 1.0);
	// banked: only the deep cracks of a few lumps, in the middle
	float heat_rime = crack * crack * core * step(0.62, l.z) * 0.8;
	float heat = mix(heat_thaw, heat_rime, rime) * draught;
	vec3 body = mix(char_col, ash_col, smoothstep(0.25, 0.8, l.z) * (0.35 + 0.5 * rime) * (1.0 - crack));
	// RIME: frost settles on the cold rim of the bed
	body = mix(body, vec3(0.62, 0.66, 0.72), rime * (1.0 - core) * 0.6);
	ALBEDO = body * (1.0 - heat * 0.8);
	ROUGHNESS = 0.95;
	vec3 glow_c = mix(ember_col, hot_col, heat * (1.0 - rime * 0.85));
	EMISSION = glow_c * heat * mix(glow_thaw, glow_rime, rime);
	AO = 1.0 - crack * 0.5;
}
