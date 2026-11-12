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
// Close-up (docs/art/WORLD_FIDELITY.md): parallax on the path and the
// shingle, a finer second sample of each layer inside a few metres, puddles
// in THAW that freeze to ice patches in RIME, a glossed wet shore with a
// wrack line, and the ground under buildings. Terrain.add_footprint() tells
// the shader where houses stand, so the land meets them: contact shadow at
// the wall foot, a strip of bare trodden earth, washed gravel under the
// eaves, a worn way out of every door, no snow under a roof, and in RIME an
// unbroken fall of snow at the wall foot (the bank itself is geometry:
// HouseDetail.build_drifts, because a 1 m grid cannot hug a wall).
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
// close-up detail
uniform float parallax_depth = 0.055;  // metres of relief on path and shingle
uniform float detail_near = 7.0;       // the finer second sample fades out by here
// rock character, per region (data/biomes/<area>.json "shader")
uniform float bed_thickness = 1.7;     // metres between bedding planes
uniform float bed_strength = 1.0;      // 0 = massive rock with no beds (granite), 1 = strongly bedded
uniform float joint_vertical = 0.0;    // upright joints top to bottom (granite walls, slate cleavage)
uniform float joint_spacing = 2.6;     // metres between upright joints
uniform float streak_strength = 0.25;  // dark water stains down the face
uniform float rock_moss = 0.35;        // green wash in the damp hollows
uniform vec3 rock_stain : source_color = vec3(1.06, 1.0, 0.92);   // tint of the odd bed (iron, lichen)
uniform float rock_relief = 0.55;       // strength of the cliffs' macro normal
uniform float snow_ripple = 1.0;       // wind ripple and drift relief on RIME snow
uniform float puddle_amount = 0.5;     // 0 = none; raises the puddle / ice-patch cover
// buildings standing on this land (Terrain.add_footprint)
uniform int house_count = 0;
uniform vec4 house_rect[16];           // xz centre, half width, half length
uniform vec4 house_rot[16];            // cos and sin of the yaw, floor y, kind
                                       // kind: 0 house, 1 mound, 2 open-fronted shed
uniform int door_count = 0;
uniform vec4 door_at[24];              // xz of the threshold, xz of the way out

#include "res://shaders/wavefront.gdshaderinc"

varying vec3 v_wp;
varying vec3 v_wn;
varying vec4 v_col;
varying float v_lip;
varying float v_horizon;   // 1 on the coarse horizon mesh (Terrain._build_far)

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

// Signed distance (metres, negative inside) from wp to the nearest building
// footprint; dir = the way out from its wall (world xz); kind as house_rot.w.
float house_sdf(vec3 wp, out vec2 dir, out float kind) {
	float best = 1000.0;
	dir = vec2(0.0, 1.0);
	kind = 0.0;
	for (int i = 0; i < house_count; i++) {
		vec4 r = house_rect[i];
		vec4 o = house_rot[i];
		vec2 d = wp.xz - r.xy;
		if (abs(d.x) + abs(d.y) > (r.z + r.w) * 1.5 + 8.0 || abs(wp.y - o.z) > 4.0) {
			continue;
		}
		vec2 l = vec2(d.x * o.x - d.y * o.y, d.x * o.y + d.y * o.x);
		vec2 q = abs(l) - r.zw;
		float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
		if (sd < best) {
			best = sd;
			kind = o.w;
			vec2 g = max(q, vec2(0.0));
			if (g.x + g.y < 0.0001) {
				g = (q.x > q.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
			}
			g = normalize(g) * sign(l + vec2(0.00001));
			dir = vec2(g.x * o.x + g.y * o.y, -g.x * o.y + g.y * o.x);
		}
	}
	return best;
}

// 1 on the worn way out of a door, fading over a few metres.
float door_wear(vec3 wp) {
	float w = 0.0;
	for (int i = 0; i < door_count; i++) {
		vec2 rel = wp.xz - door_at[i].xy;
		if (abs(rel.x) + abs(rel.y) > 8.0) {
			continue;
		}
		float along = dot(rel, door_at[i].zw);
		float across = abs(rel.x * door_at[i].w - rel.y * door_at[i].z);
		w = max(w, smoothstep(1.7, 0.5, across + max(along, 0.0) * 0.12) * smoothstep(4.5, 0.4, along) * smoothstep(-1.2, -0.4, along));
	}
	return w;
}

// Where the RIME snow lies unbroken against a wall, by signed distance sd.
float drift_at(float sd, float kind) {
	return (kind < 0.5 || kind > 1.5) ? smoothstep(1.9, 0.15, sd) * step(0.0, sd) : 0.0;
}

void vertex() {
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
	v_lip = UV.x;
	v_horizon = UV.y;
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

	// --- buildings standing on the land -----------------------------------
	vec2 hdir = vec2(0.0, 1.0);
	float hkind = 0.0;
	float hsd = 1000.0;
	float foot = 0.0;        // bare trodden strip at the wall foot
	float roofed = 0.0;      // under a roof: no snow, an earth floor
	float drip = 0.0;        // washed gravel under the eaves
	float contact = 1.0;     // contact shadow
	float tread = 0.0;       // the worn way out of a door
	if (house_count > 0) {
		hsd = house_sdf(v_wp, hdir, hkind);
		if (hsd < 5.0) {
			float out_d = max(hsd, 0.0);
			if (hkind < 0.5 || hkind > 1.5) {
				roofed = step(hsd, 0.0);
				foot = (1.0 - smoothstep(0.1, 1.05, out_d + (n2 - 0.5) * 0.5)) * (1.0 - roofed);
				drip = exp(-pow((hsd - 0.82) / 0.11, 2.0)) * (0.45 + 0.55 * n2);
				contact = 1.0 - 0.5 * exp(-out_d * 2.6) * (1.0 - roofed);
			} else {
				// a mound: the turf darkens where it tucks under the stones
				contact = 1.0 - 0.35 * exp(-out_d * 2.0) * step(0.0, hsd);
			}
		}
		tread = door_wear(v_wp);
	}

	vec2 uvg = v_wp.xz;
	// --- parallax on the worn and the stony ground --------------------------
	vec3 view_w = normalize(CAMERA_POSITION_WORLD - v_wp);
	float near = (1.0 - smoothstep(detail_near * 0.4, detail_near, cam_d)) * has_tex;
	float w_path_p = clamp(max(max(v_col.g, foot * 0.8), max(tread, roofed * step(hkind, 0.5))), 0.0, 1.0);
	float w_shing_p = clamp(max(v_col.r, drip * 0.7), 0.0, 1.0);
	float par = (1.0 - smoothstep(7.0, 18.0, cam_d)) * has_tex * max(w_path_p, w_shing_p) * parallax_depth;
	if (par > 0.0005) {
		vec2 pdir = view_w.xz / max(view_w.y, 0.28);
		for (int k = 0; k < 2; k++) {
			float hp = texture(path_orh, uvg * path_scale).b;
			float hs = texture(shingle_orh, uvg * shingle_scale).b;
			float hh = (w_shing_p > w_path_p) ? hs : hp;
			uvg = v_wp.xz - pdir * (1.0 - hh) * par;
		}
	}
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
	// beds of uneven thickness (even strata read as a tiled band on a cliff)
	float bed_c = (bed_v + 2.2 * vnoise(vec3(bed_v * 0.19, blk * 5.0, 3.0)) + 0.5 * n1) / bed_thickness;
	float bed_f = fract(bed_c);
	float bed_tone = hash13(vec3(floor(bed_c), 7.0, 3.0));
	// each bed stands a little proud of the one above: a lit ledge at its
	// top, a line of shade under it, and joints that crack it into blocks
	float ledge = smoothstep(0.84, 0.98, bed_f) * bed_strength;
	float undercut = (1.0 - smoothstep(0.0, 0.14, bed_f)) * bed_strength;
	float jn = vnoise(vec3(v_wp.x * 0.38, floor(bed_c) * 3.1, v_wp.z * 0.38));
	float joint = smoothstep(0.47, 0.5, jn) * (1.0 - smoothstep(0.5, 0.53, jn)) * bed_strength;
	// upright joints: the face splits into columns and slabs from top to foot
	if (joint_vertical > 0.001) {
		float along = (abs(n.x) > abs(n.z) ? v_wp.z : v_wp.x) / joint_spacing;
		along += 0.35 * vnoise(vec3(along * 0.7, v_wp.y * 0.05, 9.0));
		float jf = abs(fract(along + hash13(vec3(floor(v_wp.y * 0.07), 2.0, 5.0)) * 0.4) - 0.5);
		joint = max(joint, (1.0 - smoothstep(0.0, 0.035, jf)) * joint_vertical);
	}
	// macro relief: buttresses and hollows metres across, so a flat facet of
	// the heightfield does not shade as one plane
	float m0 = vnoise(v_wp * 0.11);
	float m1 = vnoise(v_wp * 0.37 + 4.0);
	vec3 mgrad = vec3(0.0);
	if (n.y < rock_slope + 0.2) {
		mgrad = (vec3(vnoise(v_wp * 0.11 + vec3(0.04, 0.0, 0.0)), vnoise(v_wp * 0.11 + vec3(0.0, 0.04, 0.0)),
				vnoise(v_wp * 0.11 + vec3(0.0, 0.0, 0.04))) - m0) / 0.04
			+ (vec3(vnoise(v_wp * 0.37 + vec3(4.05, 4.0, 4.0)), vnoise(v_wp * 0.37 + vec3(4.0, 4.05, 4.0)),
				vnoise(v_wp * 0.37 + vec3(4.0, 4.0, 4.05))) - m1) / 0.05 * 0.45;
	}
	rock *= 0.78 + 0.22 * m0 + 0.14 * m1;
	rock *= 1.0 - 0.3 * undercut - 0.38 * joint * (1.0 - far * 0.6);
	rock *= 1.0 + (0.3 * bed_tone - 0.18) * bed_strength;
	rock *= mix(vec3(1.0), rock_stain, step(0.6, bed_tone) * max(bed_strength, 0.35));
	float streak = vnoise(vec3(v_wp.x * 1.6, v_wp.y * 0.08, v_wp.z * 1.6));
	rock *= 1.0 - streak_strength * smoothstep(0.5, 0.92, streak) * (0.6 + 0.4 * n1);
	rock = mix(rock, rock * vec3(0.8, 0.95, 0.75), smoothstep(0.5, 0.8, n_macro) * rock_moss);

	// --- height-blended weights ------------------------------------------
	float w_heath = clamp(v_col.a * 0.7 + n_macro * 0.6 - 0.15, 0.0, 1.0);
	float w_shing = clamp(v_col.r * 1.2 - n3 * 0.15, 0.0, 1.0);
	float w_path = clamp(v_col.g * (0.75 + 0.5 * n2), 0.0, 1.0);
	// buildings: bare earth at the wall foot, inside, and out of each door;
	// a line of washed gravel where the eaves drip
	w_path = max(w_path, max(max(foot, tread * (0.7 + 0.3 * n2)), roofed * step(hkind, 0.5)));
	w_shing = max(w_shing * (1.0 - roofed * step(hkind, 0.5)), drip * 0.75 * (1.0 - tread));
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
	// far ground: fields of heather and turf, outcrops and a rolling relief, so
	// the horizon's coarse sheets are not one flat colour
	float vfar = max(smoothstep(120.0, 420.0, cam_d), v_horizon * smoothstep(30.0, 90.0, cam_d)) * (1.0 - rk);
	vec2 far_tilt = vec2(0.0);
	if (vfar > 0.002) {
		float f1 = vnoise(v_wp * 0.0065 + 2.0);
		float f2 = vnoise(v_wp * 0.023 + 9.0);
		float f3 = vnoise(v_wp * 0.06 + 5.0);
		vec3 far_tint = mix(turf_a * 0.85, turf_b * 1.1, smoothstep(0.3, 0.7, f1 * 0.6 + f2 * 0.4));
		far_tint = mix(far_tint, rock_col * 0.9, smoothstep(0.6, 0.72, f2 * 0.55 + f3 * 0.45) * 0.55);
		col = mix(col, mix(col, far_tint, 0.65) * (0.82 + 0.36 * f3), vfar);
		far_tilt = (vec2(vnoise(v_wp * 0.023 + vec3(9.03, 9.0, 9.0)), vnoise(v_wp * 0.023 + vec3(9.0, 9.0, 9.03))) - f2) / 0.03 * 0.5 * vfar;
	}
	// the finer second sample: grit, blades and pebble faces at foot distance
	vec2 g_fine = vec2(0.0);
	if (near > 0.01) {
		vec3 f_turf = texture(turf_alb, uvg * turf_scale * 3.7 + 0.21).rgb / max(turf_mean, vec3(0.002));
		vec3 f_path = texture(path_alb, uvg * path_scale * 3.3 + 0.47).rgb / max(path_mean, vec3(0.002));
		vec3 f_all = f_turf * b_turf + f_path * (b_path + b_shing);
		col = mix(col, col * mix(vec3(1.0), f_all, 0.55), near * (1.0 - rk));
		vec2 fn_t = texture(turf_nrm, uvg * turf_scale * 3.7 + 0.21).rg * 2.0 - 1.0;
		vec2 fn_p = texture(path_nrm, uvg * path_scale * 3.3 + 0.47).rg * 2.0 - 1.0;
		g_fine = (fn_t * b_turf + fn_p * (b_path + b_shing)) * near * 0.7;
	}
	col *= contact;
	// trodden earth is darker and tighter than the open path
	col *= 1.0 - 0.18 * max(tread, foot * 0.6);
	float wet = v_col.b;
	col *= 1.0 - wet * 0.35;
	// the wrack line: a ragged dark band where the last tide stopped
	float wrack = exp(-pow((wet - 0.42) / 0.07, 2.0)) * smoothstep(0.35, 0.7, n2 * 0.6 + n3 * 0.4) * step(0.02, wet);
	col = mix(col, vec3(0.05, 0.045, 0.03), wrack * 0.55);
	// puddles (THAW) / ice patches (RIME): the low places of worn ground
	float flat_g = smoothstep(0.95, 0.985, n.y);
	float pud_n = vnoise(v_wp * 0.42 + 3.0) * 0.7 + vnoise(v_wp * 1.3 + 17.0) * 0.3;
	float pud_w = clamp(b_path * 1.3, 0.0, 1.0) * flat_g * (1.0 - roofed) * (1.0 - rk) * (1.0 - foot);
	// none along a wall foot (they would mirror the fire through the wall);
	// the worn way out of a door keeps its own
	pud_w *= max(smoothstep(1.0, 2.8, hsd), tread);
	float pud_edge = pud_n + (0.5 - o_path.b) * 0.22 + (puddle_amount - 0.5) * 0.3;
	float puddle = smoothstep(0.57, 0.62, pud_edge) * pud_w;
	float damp = smoothstep(0.46, 0.58, pud_edge) * pud_w;

	// THAW: warm evening; RIME: desaturated, then snow on tops, frost elsewhere
	vec3 thaw_col = col * vec3(1.04, 1.0, 0.92);
	thaw_col *= 1.0 - 0.3 * damp;
	thaw_col = mix(thaw_col, thaw_col * vec3(0.42, 0.4, 0.38), puddle);
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 rime_col = mix(col, vec3(luma), 0.55) * vec3(0.88, 0.94, 1.04);
	float relief = mix(o_g.b, rock_o.b, rk);
	float top = smoothstep(0.55, 0.85, n.y + (n1 - 0.5) * 0.3 + (0.5 - relief) * 0.25);
	float snow = snow_cover * top * mix(0.7, 1.0, smoothstep(0.3, 0.7, n_macro * 0.7 + n1 * 0.3));
	snow *= 1.0 - wet * 0.8;
	// no snow under a roof; a full smooth bank against the walls; the way
	// out of a door trodden down to packed snow
	float drift = drift_at(hsd, hkind) * (1.0 - tread);
	snow = max(snow, drift) * (1.0 - roofed);
	vec3 snow_t = tile2(snow_alb, uvg * snow_scale, mtile, far) / max(snow_mean, vec3(0.01));
	vec3 snowp_t = texture(snowp_alb, uvg * snow_scale * 1.3).rgb / max(snowp_mean, vec3(0.01));
	vec3 snow_tex = mix(snow_t, snowp_t * vec3(0.93, 0.95, 0.98), b_path * step(0.5, has_tex));
	if (has_tex < 0.5) {
		snow_tex = vec3(0.92 + 0.08 * n2);
	}
	// hoarfrost on the rock: broad pale sheets in the hollows, not glitter
	vec3 frost = mix(rime_col, snow_col * 0.8, 0.10 + 0.12 * n_macro + (1.0 - relief) * 0.12);
	// drifts: paler crests, blue in the hollows; ripples cut by the wind
	float dr0 = vnoise(vec3(v_wp.xz * 0.16, 2.0));
	float sn_across = dot(v_wp.xz, vec2(0.6, 0.8));
	float sn_phase = sn_across * 6.5 + 7.0 * vnoise(vec3(v_wp.xz * 0.33, 1.0)) + dot(v_wp.xz, vec2(0.8, -0.6)) * 0.5;
	float sn_amp = smoothstep(0.3, 0.7, vnoise(vec3(v_wp.xz * 0.06, 4.0))) * (1.0 - far) * snow_ripple;
	vec3 snow_shade = mix(vec3(0.8, 0.87, 1.0), vec3(1.03, 1.02, 1.0), smoothstep(0.25, 0.75, dr0)) * (0.97 + 0.03 * sin(sn_phase) * sn_amp);
	rime_col = mix(frost, snow_col * snow_tex * snow_shade, snow);
	// ice patches: grey-blue glaze with pale wind-scoured veins
	float vein = smoothstep(0.86, 0.97, 1.0 - abs(vnoise(v_wp * 3.1 + 5.0) * 2.0 - 1.0));
	vec3 ice_c = mix(vec3(0.34, 0.42, 0.5), vec3(0.72, 0.8, 0.88), vein * 0.7 + 0.15 * n2);
	rime_col = mix(rime_col, ice_c, puddle * 0.85);
	// an unheated floor under a roof takes hoarfrost, not snow
	rime_col = mix(rime_col, vec3(0.6, 0.66, 0.74), roofed * (0.22 + 0.2 * n_macro + 0.12 * n2));
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
	if (snow * rime > 0.01) {
		// the wind ripple's slope, and the roll of the drifts under it
		vec2 rip = vec2(0.6, 0.8) * cos(sn_phase) * 0.22 * sn_amp;
		vec2 dgr = (vec2(vnoise(vec3(v_wp.xz * 0.16 + vec2(0.05, 0.0), 2.0)), vnoise(vec3(v_wp.xz * 0.16 + vec2(0.0, 0.05), 2.0))) - dr0) / 0.05;
		g_n += (vec2(rip.x, -rip.y) - vec2(dgr.x, -dgr.y) * 0.22 * snow_ripple) * snow * rime;
	}
	g_n += vec2(-far_tilt.x, far_tilt.y);
	g_n *= 1.0 - far * 0.7;
	g_n += g_fine;
	// standing water and ice lie flat
	g_n *= 1.0 - puddle;
	// ground: tangent frame is world X / Z; rock: along-face / down-bed
	vec3 n_ground = normalize(n + vec3(g_n.x, 0.0, -g_n.y));
	// per-plane tangent offsets (u along the plane's horizontal axis, v down the beds)
	vec3 rpert = vec3(0.0, -rnx.y, rnx.x) * rw.x + vec3(rnz.x, -rnz.y, 0.0) * rw.z + vec3(rny.x, 0.0, rny.y) * rw.y;
	vec3 n_rock = normalize(n + rpert * 1.2 * (1.0 - far * 0.5));
	// macro relief and the ledges (kept at distance: this is the cliff's form)
	n_rock = normalize(n_rock - (mgrad - n * dot(mgrad, n)) * rock_relief + vec3(0.0, 0.55, 0.0) * ledge - vec3(0.0, 0.3, 0.0) * undercut);
	vec3 nn = normalize(mix(n_ground, n_rock, rk * has_tex));
	if (has_tex < 0.5) {
		nn = normalize(n + vec3(n2 - 0.5, 0.0, n3 - 0.5) * (0.18 + rock_w * 0.25));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nn, 0.0)).xyz);

	float rough_g = mix(0.92, o_g.g, 0.6 * has_tex);
	float rgh = mix(rough_g, mix(0.84, rock_o.g, 0.5), rk);
	// the wet shore glosses toward the waterline, rippled; frozen in RIME
	rgh = mix(rgh, mix(0.34, 0.16, smoothstep(0.4, 0.95, wet + (n2 - 0.5) * 0.2)), wet * (1.0 - rime));
	rgh = mix(rgh, 0.42, wet * rime * 0.6);
	rgh = mix(rgh, 0.6, snow * rime);
	rgh = mix(rgh, mix(0.05, 0.14, rime), puddle);
	rgh = mix(rgh, rgh * 0.75, damp * (1.0 - puddle) * (1.0 - rime));
	ROUGHNESS = wf_roughness(rgh, wf);
	float spec = mix(0.4, 0.55, snow * rime);
	spec = mix(spec, 0.62, max(wet * (1.0 - rime), puddle));
	SPECULAR = wf_specular(spec, wf);
	float ao_g = mix(1.0, o_g.r, 0.8 * has_tex);
	AO = mix(ao_g, mix(1.0, rock_o.r, 0.9) * (0.75 + 0.25 * bed_tone), rk) * contact;
	AO_LIGHT_AFFECT = 0.5;

	vec3 emis = vec3(0.0);
	emis += wf_emission(wf);
	// a faint cold glint on the snow in rime
	emis += vec3(0.04, 0.05, 0.07) * snow * rime * smoothstep(0.92, 0.99, n3);
	// sparkle: single crystals that flash as the eye moves, near the camera
	float sp_h = hash13(floor(v_wp * 70.0));
	float sp = step(0.992, fract(sp_h * 17.3 + dot(view_w, vec3(3.1, 5.3, 7.7)) * 3.0)) * step(0.4, sp_h);
	emis += vec3(0.55, 0.62, 0.75) * sp * snow * rime * (1.0 - smoothstep(6.0, 28.0, cam_d));
	EMISSION = emis;
}
