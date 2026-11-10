shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------------------------
// terrain.gdshader — splat-layered landform for Rimeholt (ADR 0003).
// Painted layers ride the vertex colour (from tools/terrain_*.py):
//   R = shingle, G = worn path, B = wet shore, A = turf variation
// Derived layers:
//   rock  — on slopes steeper than ~40 deg: layered schist, projected on the
//           face with its strata kept level (bed dip and pinch-out warp v)
//   snow  — RIME only: settles on top-facing ground, packed on the path
// Every layer is a CC0 photo set (assets/textures, tools/art/fetch_textures.py)
// re-tinted to the landform palette (the *_col uniforms are the layer MEANS),
// blended by height so pebbles poke through turf and turf fills the cracks
// between flags, instead of a linear cross-fade. Anti-tiling: macro drift,
// a second rotated sample, and a distance blend to a 4x lower frequency.
// The thaw/rime wavefront (frost line / melt line) is shared with
// hall.gdshader via wavefront.gdshaderinc.
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
// how far the palette re-tints each photo (1 = mean becomes the uniform)
uniform float tint_amount = 0.85;

// photo sets: albedo (sRGB), GL normal, R=AO G=rough B=height
uniform sampler2D turf_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D turf_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D turf_orh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D heath_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D heath_orh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shingle_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shingle_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shingle_orh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_orh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_orh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snowp_alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// linear means of each albedo (sets.json), to divide out before re-tinting
uniform vec3 turf_mean = vec3(0.1);
uniform vec3 heath_mean = vec3(0.1);
uniform vec3 shingle_mean = vec3(0.1);
uniform vec3 path_mean = vec3(0.1);
uniform vec3 rock_mean = vec3(0.1);
uniform vec3 snow_mean = vec3(0.7);
uniform vec3 snowp_mean = vec3(0.6);
// repeats per metre
uniform float turf_scale = 0.28;
uniform float shingle_scale = 0.6;
uniform float shingle_contrast = 0.7;   // pebble photo is busy: calm it toward its mean
uniform float path_scale = 0.3;
uniform float rock_scale = 0.11;
uniform float snow_scale = 0.22;
uniform float has_tex = 0.0;           // 0 until Terrain binds the sets

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

// rounded pebbles (cell distance): the value-noise speckle read as a
// blocky pixel mosaic on the Strand's shingle at walking distance
float pebbles(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash13(vec3(i + g, 1.7)), hash13(vec3(i + g, 9.1))) * 0.8 + 0.1;
			d = min(d, length(g + o - f));
		}
	}
	return d;
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
	v_lip = UV.x;
}

vec3 retint(vec3 c, vec3 mean, vec3 target) {
	return c / max(mean, vec3(0.002)) * mix(mean, target, tint_amount);
}

// a top-down sample with anti-tiling: a second copy rotated and offset,
// blended in by a macro noise mask; far away, a 4x lower-frequency copy
vec3 tile2(sampler2D t, vec2 uv, float m, float far) {
	vec3 a = texture(t, uv).rgb;
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.73 + vec2(0.41, 0.17);
	vec3 b = texture(t, uv2).rgb;
	vec3 c = mix(a, b, smoothstep(0.35, 0.65, m));
	if (far > 0.001) {
		c = mix(c, texture(t, uv * 0.25 + 0.5).rgb, far * 0.5);
	}
	return c;
}

void fragment() {
	float rime = local_rime(v_wp);
	vec3 n = normalize(v_wn);
	float n_macro = vnoise(v_wp * 0.045);
	float n1 = vnoise(v_wp * 0.6);
	float n2 = vnoise(v_wp * 2.7 + 7.0);
	float n3 = vnoise(v_wp * 9.0 + 3.0);
	float cam_d = distance(CAMERA_POSITION_WORLD, v_wp);
	float far = smoothstep(18.0, 70.0, cam_d);
	float mtile = vnoise(v_wp * 0.09 + 11.0);

	vec2 uvg = v_wp.xz;
	// --- ground layers (top-down) -----------------------------------------
	vec3 turf_t = retint(tile2(turf_alb, uvg * turf_scale, mtile, far), turf_mean, turf_a);
	vec3 heath_t = retint(tile2(heath_alb, uvg * turf_scale * 0.9 + 0.3, mtile, far), heath_mean, turf_b);
	vec3 shingle_t = retint(mix(shingle_mean, tile2(shingle_alb, uvg * shingle_scale, mtile, far), shingle_contrast), shingle_mean, shingle_col);
	vec3 path_t = retint(tile2(path_alb, uvg * path_scale, mtile, far), path_mean, path_col);
	vec3 o_turf = texture(turf_orh, uvg * turf_scale).rgb;
	vec3 o_heath = texture(heath_orh, uvg * turf_scale * 0.9 + 0.3).rgb;
	vec3 o_shing = texture(shingle_orh, uvg * shingle_scale).rgb;
	vec3 o_path = texture(path_orh, uvg * path_scale).rgb;

	// --- rock (schist), strata kept level --------------------------------
	float blk = hash13(floor(vec3(v_wp.x * 0.04, 0.0, v_wp.z * 0.04)));
	float bed_v = v_wp.y + v_wp.x * 0.03 * (blk - 0.5) * 2.0 + (n_macro - 0.5) * 4.0 + blk * 7.0;
	// triplanar on the two side planes (X and Z), each with v = the bed
	// coordinate so the strata stay level and dip with the beds; a flat
	// top-down plane for ledges. (A single along-face projection swirled on
	// curved faces like wood grain.)
	vec2 uvr_x = vec2(v_wp.z, -bed_v) * rock_scale;
	vec2 uvr_z = vec2(v_wp.x, -bed_v) * rock_scale + vec2(0.37, 0.0);
	vec2 uvr_top = uvg * rock_scale * 1.6;
	vec3 rw = pow(max(abs(n) - 0.15, vec3(0.0001)), vec3(4.0));
	rw /= (rw.x + rw.y + rw.z);
	vec3 rock_a = texture(rock_alb, uvr_x).rgb * rw.x + texture(rock_alb, uvr_top).rgb * rw.y + texture(rock_alb, uvr_z).rgb * rw.z;
	vec3 rock_o = texture(rock_orh, uvr_x).rgb * rw.x + texture(rock_orh, uvr_top).rgb * rw.y + texture(rock_orh, uvr_z).rgb * rw.z;
	vec2 rnx = texture(rock_nrm, uvr_x).rg * 2.0 - 1.0;
	vec2 rnz = texture(rock_nrm, uvr_z).rg * 2.0 - 1.0;
	vec2 rny = texture(rock_nrm, uvr_top).rg * 2.0 - 1.0;
	// a second, finer pass so close-up faces keep grain
	vec2 uvr_f = (abs(n.x) > abs(n.z) ? uvr_x : uvr_z) * 3.1 + 0.2;
	rock_a *= mix(vec3(1.0), texture(rock_alb, uvr_f).rgb / max(rock_mean, vec3(0.002)), 0.35 * (1.0 - far));
	vec3 rock = retint(rock_a, rock_mean, rock_col);
	// beds: each bed its own tone, an iron-stained one, seep streaks
	float bed_tone = hash13(vec3(floor(bed_v / 1.7), 7.0, 3.0));
	rock *= 0.82 + 0.3 * bed_tone;
	rock *= mix(vec3(1.0), vec3(1.06, 1.0, 0.92), step(0.6, bed_tone));
	float streak = vnoise(vec3(v_wp.x * 1.6, v_wp.y * 0.08, v_wp.z * 1.6));
	rock *= 1.0 - 0.25 * smoothstep(0.5, 0.92, streak) * (0.6 + 0.4 * n1);
	rock = mix(rock, rock * vec3(0.8, 0.95, 0.75), smoothstep(0.5, 0.8, n_macro) * 0.35);

	// --- height-blended weights ------------------------------------------
	float w_heath = clamp(v_col.a * 0.7 + n_macro * 0.6 - 0.15, 0.0, 1.0);
	float w_shing = clamp(v_col.r * 1.2 - n3 * 0.15, 0.0, 1.0);
	float w_path = clamp(v_col.g * (0.75 + 0.5 * n2), 0.0, 1.0);
	float rock_w = smoothstep(rock_slope + 0.06, rock_slope - 0.1, n.y + (n1 - 0.5) * 0.12);
	rock_w *= 1.0 - smoothstep(0.25, 0.7, v_lip + (n2 - 0.5) * 0.3);
	// each layer's height (0..1) plus its painted weight; the tallest wins,
	// with a soft 0.18 band where they interleave
	float hb = 0.18;
	float h_turf = mix(o_turf.b, o_heath.b, w_heath) * 0.6 + 0.2;
	float a_turf = (1.0 - w_shing) * (1.0 - w_path) + h_turf;
	float a_shing = w_shing * 1.6 + o_shing.b * 0.8 - 0.4;
	float a_path = w_path * 1.5 + o_path.b * 0.7 - 0.35;
	float ma = max(max(a_turf, a_shing), a_path) - hb;
	float b_turf = max(a_turf - ma, 0.0);
	float b_shing = max(a_shing - ma, 0.0) * step(0.02, w_shing);
	float b_path = max(a_path - ma, 0.0) * step(0.02, w_path);
	float bs = b_turf + b_shing + b_path + 1e-4;
	b_turf /= bs; b_shing /= bs; b_path /= bs;

	vec3 turf = mix(turf_t, heath_t, smoothstep(0.3, 0.7, w_heath + (o_heath.b - 0.5) * 0.4));
	vec3 ground = turf * b_turf + shingle_t * b_shing + path_t * b_path;
	vec3 o_g = mix(o_turf, o_heath, w_heath) * b_turf + o_shing * b_shing + o_path * b_path;
	// rock pushes through where its own relief is high
	float rk = clamp(rock_w * 1.3 + (rock_o.b - 0.5) * 0.6 * rock_w * (1.0 - rock_w) * 4.0, 0.0, 1.0);
	rk = smoothstep(0.15, 0.85, rk);
	vec3 col = mix(ground, rock, rk);
	if (has_tex < 0.5) {
		col = mix(mix(turf_a, turf_b, w_heath), rock_col, rock_w);
	}
	float wet = v_col.b;
	col *= 1.0 - wet * 0.35;

	// THAW: warm evening; RIME: desaturated, then snow on tops, frost elsewhere
	vec3 thaw_col = col * vec3(1.04, 1.0, 0.92);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 rime_col = mix(col, vec3(luma), 0.55) * vec3(0.88, 0.94, 1.04);
	float relief = mix(o_g.b, rock_o.b, rk);
	float top = smoothstep(0.55, 0.85, n.y + (n1 - 0.5) * 0.3 + (0.5 - relief) * 0.25);
	float snow = snow_cover * top * mix(0.7, 1.0, smoothstep(0.3, 0.7, n_macro * 0.7 + n1 * 0.3));
	snow *= 1.0 - wet * 0.8;
	vec3 snow_t = tile2(snow_alb, uvg * snow_scale, mtile, far) / max(snow_mean, vec3(0.01));
	vec3 snowp_t = texture(snowp_alb, uvg * snow_scale * 1.3).rgb / max(snowp_mean, vec3(0.01));
	vec3 snow_tex = mix(snow_t, snowp_t * vec3(0.93, 0.95, 0.98), b_path * step(0.5, has_tex));
	if (has_tex < 0.5) {
		snow_tex = vec3(0.92 + 0.08 * n2);
	}
	// hoarfrost on the rock: broad pale sheets in the hollows, not glitter
	vec3 frost = mix(rime_col, snow_col * 0.8, 0.10 + 0.12 * n_macro + (1.0 - relief) * 0.12);
	rime_col = mix(frost, snow_col * snow_tex, snow);
	vec3 albedo = mix(thaw_col, rime_col, rime);
	vec4 wf = wf_eval(v_wp, n);
	albedo = wf_albedo(albedo, wf);
	ALBEDO = albedo;

	// --- normal: the photo normal of whichever layer shows -----------------
	vec2 g_n = vec2(0.0);
	if (has_tex > 0.5) {
		vec2 tn = texture(turf_nrm, uvg * turf_scale).rg * 2.0 - 1.0;
		vec2 sn = texture(shingle_nrm, uvg * shingle_scale).rg * 2.0 - 1.0;
		vec2 pn = texture(path_nrm, uvg * path_scale).rg * 2.0 - 1.0;
		g_n = tn * b_turf * 0.8 + sn * b_shing * 1.2 + pn * b_path;
		vec2 snn = texture(snow_nrm, uvg * snow_scale).rg * 2.0 - 1.0;
		g_n = mix(g_n, snn * 0.6, snow * rime);
	}
	g_n *= 1.0 - far * 0.7;
	// ground: tangent frame is world X / Z; rock: along-face / down-bed
	vec3 n_ground = normalize(n + vec3(g_n.x, 0.0, -g_n.y));
	// per-plane tangent offsets (u along the plane's horizontal axis, v down the beds)
	vec3 rpert = vec3(0.0, -rnx.y, rnx.x) * rw.x + vec3(rnz.x, -rnz.y, 0.0) * rw.z + vec3(rny.x, 0.0, rny.y) * rw.y;
	vec3 n_rock = normalize(n + rpert * 1.2 * (1.0 - far * 0.5));
	vec3 nn = normalize(mix(n_ground, n_rock, rk * has_tex));
	if (has_tex < 0.5) {
		nn = normalize(n + vec3(n2 - 0.5, 0.0, n3 - 0.5) * (0.18 + rock_w * 0.25));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nn, 0.0)).xyz);

	float rough_g = mix(0.92, o_g.g, 0.6 * has_tex);
	float rgh = mix(rough_g, mix(0.84, rock_o.g, 0.5), rk);
	rgh = mix(rgh, 0.32, wet * (1.0 - rime));
	rgh = mix(rgh, 0.6, snow * rime);
	ROUGHNESS = wf_roughness(rgh, wf);
	SPECULAR = wf_specular(mix(0.4, 0.55, snow * rime), wf);
	float ao_g = mix(1.0, o_g.r, 0.8 * has_tex);
	AO = mix(ao_g, mix(1.0, rock_o.r, 0.9) * (0.75 + 0.25 * bed_tone), rk);
	AO_LIGHT_AFFECT = 0.5;

	vec3 emis = vec3(0.0);
	emis += wf_emission(wf);
	// a faint cold glint on the snow in rime
	emis += vec3(0.04, 0.05, 0.07) * snow * rime * smoothstep(0.92, 0.99, n3);
	EMISSION = emis;
}
