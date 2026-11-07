shader_type sky;
// ---------------------------------------------------------------------------
// Atmospheric sky shader for Rimeholt.
//   * Thaw: long midsummer sunset — Rayleigh/Mie optical
//     depth horizon scattering, blazing solar corona, crepuscular rays, and
//     back-lit multi-octave stratocumulus clouds.
//   * Rime: frozen polar night — pale silver-indigo
//     corona around a drowned/eclipsed disc, cold drifting ash clouds, and
//     twinkling stars.
// ---------------------------------------------------------------------------

uniform vec3 top_color : source_color = vec3(0.32, 0.18, 0.14);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.62, 0.28);
uniform vec3 sun_color : source_color = vec3(1.0, 0.84, 0.50);
uniform vec3 ground_color : source_color = vec3(0.10, 0.08, 0.07);
uniform vec3 sun_dir = vec3(0.35, 0.16, -0.92);
uniform float rime : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.31, 289.17))) * 43758.5453);
}

// Integer-lattice hash without sin() (pcg3d, Jarzynski & Olano 2020):
// stable on large cell ids, no row artefacts.
vec3 star_hash3(vec3 c) {
	uvec3 v = uvec3(ivec3(c) + ivec3(32768));
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	return vec3(v) * (1.0 / float(0xffffffffu));
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.52;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.07;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	vec3 sd = normalize(sun_dir);
	float cos_theta = dot(dir, sd);
	float sun_prox = max(cos_theta, 0.0);

	// Smooth Rayleigh / Mie optical-depth vertical gradient (no cartoon steps)
	vec3 col;
	if (up < 0.0) {
		float gt = clamp(-up * 2.8, 0.0, 1.0);
		col = mix(horizon_color * 0.45, ground_color, smoothstep(0.0, 1.0, gt));
	} else {
		float opt_depth = exp(-up * 3.2);
		vec3 zenith = top_color * mix(0.85, 0.55, rime);
		col = mix(zenith, horizon_color, pow(opt_depth, 0.78));
		// Forward Mie scattering warm belt along the horizon toward the sun
		float mie_belt = exp(-abs(up) * 5.5) * (0.45 + 0.55 * pow(sun_prox, 2.0));
		col += horizon_color * mie_belt * 0.52 * (1.0 - 0.72 * rime);
	}

	// Thaw solar disc vs rime pale-moon corona
	float disc_thaw = smoothstep(0.9945, 0.9982, sun_prox);
	float corona_inner = pow(sun_prox, 36.0);
	float corona_outer = pow(sun_prox, 5.5);
	float crepuscular = pow(sun_prox, 8.0) * (0.65 + 0.35 * sin(atan(dir.x - sd.x, dir.y - sd.y) * 18.0));

	// In rime, the core of the sun is eclipsed dark while its rim burns cold silver-gold
	float eclipse_core = smoothstep(0.9962, 0.9985, sun_prox);
	float eclipse_ring = smoothstep(0.9920, 0.9965, sun_prox) * (1.0 - eclipse_core * 0.92);

	vec3 thaw_sun = sun_color * (disc_thaw * 2.4 + corona_inner * 1.45 + corona_outer * 0.36 + crepuscular * 0.16);
	vec3 rime_sun = mix(sun_color, vec3(0.58, 0.72, 0.98), 0.7) * (eclipse_ring * 1.65 + corona_inner * 0.75 + corona_outer * 0.18);
	col += mix(thaw_sun, rime_sun, rime);
	col = mix(col, vec3(0.01, 0.015, 0.03), eclipse_core * rime * 0.88);

	// Multi-layered volumetric stratocumulus cloud deck with silver-lining rim
	if (up > -0.04) {
		float skyband = smoothstep(-0.03, 0.12, up) * smoothstep(0.92, 0.18, up);
		if (skyband > 0.001) {
			vec2 cuv = dir.xz / (max(up, 0.0) + 0.24);
			cuv += vec2(TIME * 0.008, TIME * 0.003);
			float m1 = fbm(cuv * 0.65 + 1.7);
			float m2 = fbm(cuv * 1.85 - 3.4);
			float cloud_density = smoothstep(0.42, 0.78, m1 * 0.72 + m2 * 0.28) * skyband;
			if (cloud_density > 0.001) {
				// Directional thickness derivative toward the sun for realistic self-shadowing
				vec2 sun_uv_step = sd.xz * 0.08;
				float m_toward = fbm((cuv + sun_uv_step) * 0.65 + 1.7);
				float self_shadow = clamp(1.0 - max(m_toward - m1, 0.0) * 3.8, 0.18, 1.0);
				float phase_hg = 0.35 + 0.65 * pow(sun_prox, 3.2);

				vec3 cloud_dark = mix(top_color * 0.38, vec3(0.035, 0.045, 0.075), rime);
				vec3 cloud_lit = mix(sun_color * 1.35, vec3(0.38, 0.48, 0.68), rime);
				vec3 c_col = mix(cloud_dark, cloud_lit, self_shadow * phase_hg);
				// Silver lining along thin cloud edges near the sun
				float edge_lining = smoothstep(0.2, 0.55, cloud_density) * (1.0 - smoothstep(0.55, 0.88, cloud_density));
				c_col += cloud_lit * edge_lining * pow(sun_prox, 4.0) * 1.4;

				col = mix(col, c_col, cloud_density * (0.90 - 0.18 * rime));
			}
		}
	}

	// Rime high-altitude starfield (occluded by clouds and horizon haze).
	// A 3D lattice sampled ON the unit sphere: uniform density with no
	// horizon stretch (the old dir.xz/up plane smeared cells into dashes),
	// a sin-free integer hash (sin() on large cell ids lost precision and
	// lined the stars up in rows), and a round jittered point per cell
	// instead of a whole-cell fill.
	if (rime > 0.001 && up > 0.02) {
		float sky_mask = smoothstep(0.04, 0.42, up);
		vec3 sp = dir * 150.0;
		vec3 cell = floor(sp);
		vec3 h = star_hash3(cell);
		float star = 0.0;
		if (h.z > 0.985) {
			vec3 centre = cell + 0.25 + 0.5 * h;
			float d = length(sp - centre);
			float size = mix(0.045, 0.11, fract(h.x * 7.13));
			star = smoothstep(size, 0.0, d);
		}
		float tw = 0.6 + 0.4 * sin(TIME * (1.4 + 2.2 * h.y) + h.x * 37.0);
		col += vec3(0.76, 0.84, 1.0) * star * tw * sky_mask * rime * 1.2;
	}

	COLOR = col;
}
