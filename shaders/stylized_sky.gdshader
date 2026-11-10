shader_type sky;
// ---------------------------------------------------------------------------
// Rimeholt's sky. Every colour and amount comes from data/state_profiles.json
// through EnvRig.blend(), so the two states (and the wave between them) are
// one continuous sky, and an area's "env" block can retune it.
//   THAW: a low evening sun. Three-stop gradient (zenith, mid band, horizon),
//         a haze belt that glows toward the sun and cools away from it, a sun
//         disc in its corona, and two cloud layers (high streaks, a broken
//         deck) lit from below on the sun side.
//   RIME: deep blue overcast. The same deck, closed over and unlit; a veiled
//         pale disc; a few stars in the gaps; a faint aurora ribbon behind it.
// ---------------------------------------------------------------------------

uniform vec3 top_color : source_color = vec3(0.17, 0.22, 0.33);
uniform vec3 mid_color : source_color = vec3(0.62, 0.5, 0.45);
uniform vec3 horizon_color : source_color = vec3(0.93, 0.66, 0.38);
uniform vec3 haze_color : source_color = vec3(1.0, 0.76, 0.46);
uniform vec3 sun_color : source_color = vec3(1.0, 0.84, 0.50);
uniform vec3 ground_color : source_color = vec3(0.10, 0.08, 0.07);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.72, 0.5);
uniform vec3 cloud_shade : source_color = vec3(0.3, 0.27, 0.34);
uniform vec3 aurora_color : source_color = vec3(0.3, 0.9, 0.62);
uniform vec3 sun_dir = vec3(0.35, 0.16, -0.92);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float sun_disc : hint_range(0.0, 2.0) = 1.0;
uniform float aurora : hint_range(0.0, 1.0) = 0.0;
uniform float stars : hint_range(0.0, 1.0) = 0.0;
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

float fbm3(vec2 p) {
	float v = 0.0, a = 0.55;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = rot * p * 2.13;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float up = dir.y;
	vec3 sd = normalize(sun_dir);
	float sun_prox = max(dot(dir, sd), 0.0);
	// how far round the horizon from the sun this direction is (1 = at it)
	float az = dot(normalize(dir.xz + vec2(1e-5)), normalize(sd.xz + vec2(1e-5))) * 0.5 + 0.5;
	float az3 = az * az * az;

	vec3 col;
	float t = pow(clamp(up, 0.0, 1.0), 0.6);
	if (up < 0.0) {
		float gt = clamp(-up * 2.8, 0.0, 1.0);
		vec3 hz = mix(horizon_color, haze_color, 0.35 + 0.5 * az3);
		col = mix(hz * 0.5, ground_color, smoothstep(0.0, 1.0, gt));
	} else {
		// three stops: the horizon band, the pale mid sky, the zenith
		col = mix(horizon_color, mid_color, smoothstep(0.0, 0.42, t));
		col = mix(col, top_color, smoothstep(0.2, 0.85, t));
		// the far side of the sky is dusk already: cooler and dimmer low down
		vec3 dusk = mix(mid_color, top_color, 0.7);
		col = mix(col, dusk, (1.0 - az) * (1.0 - az) * (1.0 - smoothstep(0.0, 0.7, t)) * 0.7);
		// horizon haze: a thick belt that glows toward the sun
		float belt = exp(-up * 7.5);
		col = mix(col, haze_color * (0.55 + 0.6 * az3), belt * (0.3 + 0.6 * az3));
	}

	// the sun: disc, tight corona, wide forward-scatter bloom
	float disc = smoothstep(0.99905, 0.99945, sun_prox);
	float corona = pow(sun_prox, 48.0) * 0.9 + pow(sun_prox, 7.0) * 0.3;
	vec3 sun_add = sun_color * (disc * 3.0 + corona) * sun_disc;

	float cloud_a = 0.0;
	vec3 cloud_c = vec3(0.0);
	if (up > -0.02) {
		// flatten the dome onto a plane overhead; clouds sink into the haze
		// at the horizon instead of ending on a line
		vec2 cuv = dir.xz / (max(up, 0.0) + 0.16);
		float band = smoothstep(0.0, 0.14, up);
		vec2 drift = vec2(TIME * 0.006, TIME * 0.0025);
		// domain warp: brushed, torn edges instead of round puffs
		vec2 warp = vec2(fbm3(cuv * 0.8 + 11.0), fbm3(cuv * 0.8 - 5.0)) - 0.5;
		vec2 p = cuv * vec2(0.42, 0.62) + drift + warp * 0.55;
		float m = fbm(p + 1.7);
		float lo = 0.78 - cloud_cover * 0.62;
		float dens = smoothstep(lo, lo + 0.26, m);
		// high streaks, drawn out along the wind
		float streak = fbm3(cuv * vec2(0.16, 1.1) + drift * 2.0 + warp * 0.3 + 23.0);
		float hi = smoothstep(0.62 - cloud_cover * 0.2, 0.9, streak) * 0.55;
		// lit from below-sunward: sample the deck a step toward the sun
		float m_sun = fbm(p + sd.xz * 0.11 + 1.7);
		float shade = clamp(0.5 + (m - m_sun) * 4.5, 0.0, 1.0);
		float toward = 0.25 + 0.75 * pow(az, 2.0);
		// a closed deck has no sunward side to speak of: its relief comes from
		// its own thickness (thin places glow, heavy bellies go dark)
		float mott = fbm3(p * 2.7 + 4.0);
		float relief = clamp((1.0 - dens) * 0.6 + (mott - 0.42) * 1.5, 0.0, 1.0);
		float light = max(shade * toward * (1.0 - dens * 0.45), relief * (0.3 + 0.5 * cloud_cover));
		vec3 c_deck = mix(cloud_shade, cloud_lit, light);
		// thin edges burn near the sun
		float edge = dens * (1.0 - dens) * 4.0;
		c_deck += sun_color * edge * pow(sun_prox, 5.0) * 0.9 * sun_disc;
		vec3 c_hi = mix(mid_color, cloud_lit, 0.35 + 0.65 * az3);
		cloud_a = max(dens * 0.94, hi * (1.0 - dens)) * band;
		cloud_c = mix(c_hi, c_deck, clamp(dens * 1.4, 0.0, 1.0));
		// distant cloud takes the haze
		cloud_c = mix(cloud_c, col, exp(-up * 9.0) * 0.75);
	}

	// behind the cloud: stars (RIME only)
	if (stars > 0.001 && up > 0.02) {
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
		col += vec3(0.76, 0.84, 1.0) * star * tw * sky_mask * stars;
	}
	col += sun_add * (1.0 - cloud_a * 0.8);
	col = mix(col, cloud_c, cloud_a);
	if (aurora > 0.001 && up > 0.03) {
		// two slow ribbons on the overhead plane, combed into vertical rays
		vec2 q = dir.xz / (up + 0.3);
		float wob = vnoise(vec2(q.x * 0.7 + TIME * 0.006, 3.1 + TIME * 0.004));
		float c1 = 1.1 + 0.55 * sin(q.x * 0.9 + wob * 3.0);
		float c2 = -0.9 + 0.4 * sin(q.x * 0.6 - wob * 2.2 + 1.3);
		float r1 = exp(-pow((q.y - c1) / 0.22, 2.0));
		float r2 = exp(-pow((q.y - c2) / 0.3, 2.0)) * 0.6;
		float rays = 0.45 + 0.55 * vnoise(vec2(q.x * 9.0 + wob * 2.0, TIME * 0.02));
		float glow = (r1 + r2) * rays * smoothstep(0.03, 0.3, up) * smoothstep(1.0, 0.55, up);
		vec3 ac = mix(aurora_color, aurora_color.brg * vec3(0.5, 0.6, 1.0), clamp(q.y * 0.3 + 0.3, 0.0, 1.0));
		// the overcast veils it but does not hide it: it glows through the deck
		col += ac * glow * aurora * (1.0 - cloud_a * 0.55);
	}
	// the sun still glows through thin cloud
	col += sun_color * pow(sun_prox, 14.0) * 0.25 * sun_disc * cloud_a;

	COLOR = col;
}
