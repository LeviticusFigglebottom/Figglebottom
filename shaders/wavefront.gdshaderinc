// ---------------------------------------------------------------------------
// wavefront.gdshaderinc — the THAW/RIME state wave, shared by hall,
// hall_ds and terrain (StateDirector drives the globals).
//
// Going to RIME (rh_wave_dir = 1): a crystalline frost line races outward.
//   Its edge is jagged by the hoarfrost it grows; just behind it feathered
//   dendrites (domain-warped ridged noise) fill in over the surface, then
//   settle into the ordinary rime crust. Rim: pale blue-white.
// Going to THAW (rh_wave_dir = 0): a melt line. Behind it the surface is
//   wet-dark and glossy, drying out over a few metres; on the line a soft
//   warm bloom; ahead of it the ice starts to glisten.
// State-only meshes grow in as frost lace / melt away in soft patches.
// ---------------------------------------------------------------------------

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;
global uniform vec3 rh_wave_color;

float wf_hash3(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float wf_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float wf_noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(wf_hash2(i), wf_hash2(i + vec2(1.0, 0.0)), f.x),
	           mix(wf_hash2(i + vec2(0.0, 1.0)), wf_hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float wf_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(wf_hash3(i), wf_hash3(i + vec3(1, 0, 0)), f.x),
	               mix(wf_hash3(i + vec3(0, 1, 0)), wf_hash3(i + vec3(1, 1, 0)), f.x), f.y),
	           mix(mix(wf_hash3(i + vec3(0, 0, 1)), wf_hash3(i + vec3(1, 0, 1)), f.x),
	               mix(wf_hash3(i + vec3(0, 1, 1)), wf_hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// 0 = old state everywhere, 1 = new state (inside the wave radius)
float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

// signed distance behind the front (> 0: already changed)
float wf_signed(vec3 wp) {
	return rh_wave_r - distance(wp, rh_wave_origin);
}

// Hoarfrost dendrites on the surface's dominant plane: thin branching
// ridges (ridged value noise, domain-warped so the veins feather and fork).
float wf_dendrite(vec3 wp, vec3 n) {
	vec3 an = abs(n);
	vec2 p = (an.y > an.x && an.y > an.z) ? wp.xz : ((an.x > an.z) ? wp.zy : wp.xy);
	p *= 2.1;
	vec2 w = vec2(wf_noise2(p * 0.55), wf_noise2(p * 0.55 + 17.3)) - 0.5;
	p += w * 1.6;
	float acc = 0.0;
	float amp = 0.62;
	float fr = 1.0;
	for (int i = 0; i < 4; i++) {
		float r = 1.0 - abs(2.0 * wf_noise2(p * fr + float(i) * 13.7) - 1.0);
		acc += pow(r, 8.0) * amp;
		fr *= 2.35;
		amp *= 0.6;
	}
	return clamp(acc * 1.3, 0.0, 1.0);
}

// x: frost crystal cover   y: meltwater wetness
// z: line glow             w: sparkle (to RIME) / glisten ahead (to THAW)
vec4 wf_eval(vec3 wp, vec3 n) {
	if (rh_wave_r < -500.0) {
		return vec4(0.0);
	}
	float s = wf_signed(wp);
	float band = max(rh_wave_band, 0.5);
	if (s < -3.0 || s > band * 3.0) {
		return vec4(0.0);
	}
	if (rh_wave_dir > 0.5) {
		float den = wf_dendrite(wp, n);
		float sj = s + (den - 0.35) * 1.1;              // the line runs ahead along the crystals
		float grow = clamp(sj / (band * 0.45), 0.0, 1.0);
		float frost = smoothstep(1.0 - grow, 1.0 - grow + 0.1, den + grow * 0.3) * step(0.0, sj);
		frost *= 1.0 - smoothstep(band * 1.3, band * 2.8, s);
		float rim = exp(-pow(sj / 0.28, 2.0));
		float halo = exp(-pow((s + 0.6) / 0.8, 2.0)) * 0.05;   // cold air just ahead
		float spark = frost * step(0.93, wf_hash3(floor(wp * 22.0))) * (1.0 - grow * 0.5);
		return vec4(frost, 0.0, rim + halo, spark);
	}
	float sj = s + (wf_noise3(wp * 2.6) - 0.5) * 0.9;
	float wet = smoothstep(-0.3, 0.5, sj) * (1.0 - smoothstep(band * 0.5, band * 2.4, sj));
	// on walls the water runs: wet in vertical streaks, not blotches
	float wall = 1.0 - abs(n.y);
	float streak = wf_noise3(vec3(wp.x * 7.0, wp.y * 0.45, wp.z * 7.0));
	wet *= mix(1.0, 0.35 + 0.9 * streak, wall);
	float glow = exp(-pow(sj / 1.0, 2.0));
	float glisten = smoothstep(-2.5, 0.0, sj) * (1.0 - smoothstep(0.0, 0.3, sj));
	return vec4(0.0, wet, glow, glisten);
}

vec3 wf_albedo(vec3 a, vec4 wf) {
	a = mix(a, vec3(0.84, 0.91, 1.0), wf.x * 0.7);    // crystal white with a blue cast
	return a * mix(1.0, 0.62, wf.y);                     // wet darkening
}

float wf_roughness(float r, vec4 wf) {
	r = mix(r, 0.32, wf.x * 0.6);                       // crystal facets
	r = mix(r, 0.08, wf.y * 0.85);                      // meltwater film
	if (rh_wave_dir < 0.5) {
		r = mix(r, 0.18, wf.w * 0.7);                   // ice going glassy ahead of the melt
	}
	return r;
}

float wf_specular(float sp, vec4 wf) {
	return clamp(sp + wf.y * 0.35 + wf.x * 0.15, 0.0, 1.0);
}

vec3 wf_emission(vec4 wf) {
	if (rh_wave_dir > 0.5) {
		return rh_wave_color * (wf.z * 1.7 + wf.x * 0.12 + wf.w * 2.5);
	}
	return rh_wave_color * wf.z * (0.55 + 0.3 * wf.y);
}

// State-only meshes: the order pixels change in. Going to RIME the frost
// lace comes first (and is the last of a thaw thing to go); going to THAW
// they go in soft melting patches.
float wf_presence_noise(vec3 wp, vec3 n) {
	if (rh_wave_dir > 0.5) {
		return clamp(0.95 - wf_dendrite(wp, n) * 0.8 - wf_noise3(wp * 3.0) * 0.12, 0.02, 0.98);
	}
	return clamp(wf_noise3(wp * 2.4) * 0.75 + wf_noise3(wp * 7.0) * 0.2, 0.02, 0.98);
}

// The edge of a state-only mesh as it appears or vanishes.
vec3 wf_presence_edge(float edge) {
	if (rh_wave_dir > 0.5) {
		return rh_wave_color * edge * 2.2;
	}
	return rh_wave_color * edge * 0.6;
}
