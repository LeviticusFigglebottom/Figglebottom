shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------------------------
// terrain.gdshader — splat-layered landform for Rimeholt (ADR 0003).
// Painted layers ride the vertex colour (from tools/terrain_saltfell.py):
//   R = shingle, G = worn path, B = wet shore, A = turf variation
// Derived layers:
//   rock  — on slopes steeper than ~40 deg (schist, banded)
//   snow  — RIME only: settles on top-facing surfaces, hoarfrost elsewhere
// The thaw/rime wavefront uses the same StateDirector globals as hall.gdshader.
// ---------------------------------------------------------------------------

uniform vec3 turf_a : source_color = vec3(0.17, 0.25, 0.08);
uniform vec3 turf_b : source_color = vec3(0.30, 0.31, 0.13);
uniform vec3 rock_col : source_color = vec3(0.27, 0.27, 0.28);
uniform vec3 shingle_col : source_color = vec3(0.46, 0.43, 0.39);
uniform vec3 path_col : source_color = vec3(0.29, 0.22, 0.15);
uniform vec3 snow_col : source_color = vec3(0.86, 0.90, 0.96);
uniform float rock_slope = 0.72;       // normal.y below this turns to rock
uniform float snow_cover = 0.9;
uniform int state_mode = 0;

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;
global uniform vec3 rh_wave_color;

varying vec3 v_wp;
varying vec3 v_wn;
varying vec4 v_col;

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

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

float wave_edge(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return 0.0;
	}
	float t = 1.0 - clamp(abs(rh_wave_r - distance(wp, rh_wave_origin)) / rh_wave_band, 0.0, 1.0);
	return pow(t, 2.6);
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}

void fragment() {
	float rime = local_rime(v_wp);
	vec3 n = normalize(v_wn);
	float n_macro = vnoise(v_wp * 0.045);
	float n1 = vnoise(v_wp * 0.6);
	float n2 = vnoise(v_wp * 2.7 + 7.0);
	float n3 = vnoise(v_wp * 9.0 + 3.0);

	// turf: two greens, broken by tussock noise and the painted variation
	vec3 turf = mix(turf_a, turf_b, clamp(v_col.a * 0.7 + n_macro * 0.6 - 0.15, 0.0, 1.0));
	turf *= 0.82 + 0.3 * n1 * n2 + 0.12 * n3;
	// shingle: pebbly, grey-brown
	float peb = smoothstep(0.35, 0.75, n3) * 0.25 + n2 * 0.2;
	vec3 shingle = shingle_col * (0.78 + peb + 0.08 * n1);
	// worn path: bare peaty earth with stones
	vec3 path = path_col * (0.85 + 0.25 * n2) + vec3(0.06) * smoothstep(0.8, 0.95, n3);
	// rock: banded schist, darker in the folds
	// schist: tilted bedding, blocky faces, rain streaks down the face
	float bed = sin(v_wp.y * 1.3 + v_wp.x * 0.35 + n1 * 4.0) * 0.5 + 0.5;
	float blocks = vnoise(vec3(v_wp.x * 0.35, v_wp.y * 0.9, v_wp.z * 0.35));
	float streak = vnoise(vec3(v_wp.x * 1.4, v_wp.y * 0.12, v_wp.z * 1.4));
	vec3 rock = rock_col * (0.6 + 0.4 * blocks + 0.2 * n2 + 0.1 * bed);
	rock *= 1.0 - 0.3 * smoothstep(0.55, 0.9, streak);
	rock = mix(rock, vec3(0.46, 0.46, 0.40), smoothstep(0.8, 0.95, n2 * 0.6 + n_macro * 0.5) * 0.2);
	rock = mix(rock, rock * vec3(0.8, 0.95, 0.75), smoothstep(0.5, 0.8, n_macro) * 0.4);

	vec3 col = turf;
	col = mix(col, shingle, clamp(v_col.r * 1.2 - n3 * 0.15, 0.0, 1.0));
	col = mix(col, path, clamp(v_col.g * (0.75 + 0.5 * n2), 0.0, 1.0));
	float rock_w = smoothstep(rock_slope + 0.06, rock_slope - 0.1, n.y + (n1 - 0.5) * 0.12);
	col = mix(col, rock, rock_w);
	float wet = v_col.b;
	col *= 1.0 - wet * 0.35;

	// THAW: warm evening; RIME: desaturated, then snow on tops, frost elsewhere
	vec3 thaw_col = col * vec3(1.04, 1.0, 0.92);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 rime_col = mix(col, vec3(luma), 0.55) * vec3(0.88, 0.94, 1.04);
	float top = smoothstep(0.55, 0.85, n.y + (n1 - 0.5) * 0.3);
	float snow = snow_cover * top * mix(0.7, 1.0, smoothstep(0.3, 0.7, n_macro * 0.7 + n1 * 0.3));
	snow *= 1.0 - wet * 0.8;
	// hoarfrost on the rock: broad pale sheets in the hollows, not glitter
	vec3 frost = mix(rime_col, snow_col * 0.8, 0.10 + 0.12 * n_macro);
	rime_col = mix(frost, snow_col * (0.92 + 0.08 * n2), snow);
	vec3 albedo = mix(thaw_col, rime_col, rime);
	ALBEDO = albedo;

	// micro relief
	vec3 mn = vec3(n2 - 0.5, 0.0, n3 - 0.5) * (0.18 + rock_w * 0.25);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n + mn), 0.0)).xyz);
	float rgh = mix(0.92, 0.82, rock_w);
	rgh = mix(rgh, 0.35, wet * (1.0 - rime));
	rgh = mix(rgh, 0.55, snow * rime);
	ROUGHNESS = rgh;
	SPECULAR = mix(0.35, 0.55, snow * rime);
	AO = mix(1.0, 0.6 + 0.4 * blocks, rock_w);

	vec3 emis = vec3(0.0);
	float edge = wave_edge(v_wp);
	if (edge > 0.001) {
		emis += mix(rh_wave_color, vec3(1.0, 0.92, 0.65), n2) * edge * 4.0;
	}
	// a faint cold glint on the snow in rime
	emis += vec3(0.04, 0.05, 0.07) * snow * rime * smoothstep(0.92, 0.99, n3);
	EMISSION = emis;
}
