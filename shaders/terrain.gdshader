shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------------------------
// terrain.gdshader — splat-layered landform for Rimeholt (ADR 0003).
// Painted layers ride the vertex colour (from tools/terrain_saltfell.py):
//   R = shingle, G = worn path, B = wet shore, A = turf variation
// Derived layers:
//   rock  — on slopes steeper than ~40 deg (schist, banded)
//   snow  — RIME only: settles on top-facing surfaces, hoarfrost elsewhere
// The thaw/rime wavefront (frost line / melt line) is shared with hall.gdshader
// via wavefront.gdshaderinc.
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

#include "res://shaders/wavefront.gdshaderinc"

varying vec3 v_wp;
varying vec3 v_wn;
varying vec4 v_col;
varying float v_lip;

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

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
	v_lip = UV.x;
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
	// schist in beds: each bed its own tone, beds dip gently along the
	// coast; rain and seep streak the face downward from every ledge
	float bed_y = v_wp.y + v_wp.x * 0.03 + (n_macro - 0.5) * 1.6;
	float bed_i = floor(bed_y / 1.7);
	float bed_f = fract(bed_y / 1.7);
	float bed_tone = hash13(vec3(bed_i, 7.0, 3.0));
	float blocks = vnoise(vec3(v_wp.x * 0.35, v_wp.y * 0.9, v_wp.z * 0.35));
	float streak = vnoise(vec3(v_wp.x * 1.6, v_wp.y * 0.08, v_wp.z * 1.6));
	vec3 rock = rock_col * (0.62 + 0.3 * bed_tone + 0.22 * blocks + 0.12 * n2);
	rock *= mix(vec3(1.0), vec3(1.06, 1.0, 0.92), step(0.6, bed_tone));      // a warmer, iron-stained bed
	rock *= 1.0 - 0.22 * smoothstep(0.8, 1.0, bed_f) - 0.18 * smoothstep(0.0, 0.08, 0.08 - bed_f);
	rock *= 1.0 - 0.32 * smoothstep(0.5, 0.92, streak) * (0.6 + 0.4 * n1);
	rock = mix(rock, rock * vec3(0.8, 0.95, 0.75), smoothstep(0.5, 0.8, n_macro) * 0.4);

	vec3 col = turf;
	col = mix(col, shingle, clamp(v_col.r * 1.2 - n3 * 0.15, 0.0, 1.0));
	col = mix(col, path, clamp(v_col.g * (0.75 + 0.5 * n2), 0.0, 1.0));
	float rock_w = smoothstep(rock_slope + 0.06, rock_slope - 0.1, n.y + (n1 - 0.5) * 0.12);
	// grass lips: turf rolls over the cliff top and down the first metre
	rock_w *= 1.0 - smoothstep(0.25, 0.7, v_lip + (n2 - 0.5) * 0.3);
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
	vec4 wf = wf_eval(v_wp, n);
	albedo = wf_albedo(albedo, wf);
	ALBEDO = albedo;

	// micro relief
	vec3 mn = vec3(n2 - 0.5, 0.0, n3 - 0.5) * (0.18 + rock_w * 0.25);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n + mn), 0.0)).xyz);
	float rgh = mix(0.92, 0.82, rock_w);
	rgh = mix(rgh, 0.35, wet * (1.0 - rime));
	rgh = mix(rgh, 0.55, snow * rime);
	ROUGHNESS = wf_roughness(rgh, wf);
	SPECULAR = wf_specular(mix(0.35, 0.55, snow * rime), wf);
	AO = mix(1.0, 0.6 + 0.4 * blocks, rock_w);

	vec3 emis = vec3(0.0);
	emis += wf_emission(wf);
	// a faint cold glint on the snow in rime
	emis += vec3(0.04, 0.05, 0.07) * snow * rime * smoothstep(0.92, 0.99, n3);
	EMISSION = emis;
}
