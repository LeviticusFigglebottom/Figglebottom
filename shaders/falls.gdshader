shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;
// ---------------------------------------------------------------------------
// falls.gdshader: a fall of water down a gully (UV.y runs down the fall).
// THAW: white water streaming, thinning to glassy at the edges.
// RIME: the same fall frozen in place: blue-white ice in long ribs, opaque.
// ---------------------------------------------------------------------------

uniform int state_mode = 0;
uniform float frozen = 0.0;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rime = local_rime(wpos);
	if (state_mode == 1 && rime > 0.5) { discard; }
	if (state_mode == 2 && rime < 0.5) { discard; }
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	if (state_mode == 2) {
		// frozen: ribs of ice hanging down the gully
		float ribs = vnoise(vec2(UV.x * 14.0, UV.y * 1.5));
		float drip = smoothstep(0.25, 0.9, ribs);
		ALBEDO = mix(vec3(0.5, 0.66, 0.78), vec3(0.88, 0.93, 0.98), drip);
		ROUGHNESS = mix(0.1, 0.5, drip);
		SPECULAR = 0.8;
		EMISSION = vec3(0.05, 0.08, 0.11) * (1.0 - drip);
		ALPHA = smoothstep(0.0, 0.25, edge) * 0.97;
	} else {
		float t = TIME * 1.6;
		float streak = vnoise(vec2(UV.x * 22.0, UV.y * 2.0 - t * 4.0)) * 0.6 + vnoise(vec2(UV.x * 50.0, UV.y * 5.0 - t * 7.0)) * 0.4;
		float white = smoothstep(0.35, 0.8, streak) * (0.55 + 0.45 * edge);
		ALBEDO = mix(vec3(0.16, 0.2, 0.2), vec3(0.92, 0.9, 0.84), white);
		EMISSION = vec3(0.12, 0.1, 0.07) * white;
		ROUGHNESS = 0.2;
		SPECULAR = 0.7;
		ALPHA = smoothstep(0.0, 0.35, edge) * mix(0.35, 0.95, white);
	}
}
