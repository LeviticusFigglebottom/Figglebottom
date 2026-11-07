shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

// ---------------------------------------------------------------------------
// Leaded window glass shader:
// Vertex colors carry jewel tones and lead-came outlines; procedural
// jewel-facet variation and antique glass ripple normal perturbation catch
// hall light; burns in Thaw, cold moonlit glass in Rime.
// ---------------------------------------------------------------------------

uniform float thaw_glow = 1.32;
uniform float rime_glow = 0.18;
uniform int state_mode = 0;

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;
global uniform vec3 rh_wave_color;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying vec3 v_local_pos;
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

void vertex() {
	v_local_pos = VERTEX;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}

void fragment() {
	float rime = local_rime(v_world_pos);
	float presence = 1.0;
	if (state_mode == 1) {
		presence = 1.0 - rime;
	} else if (state_mode == 2) {
		presence = rime;
	}
	if (presence < 0.999 && presence < hash13(floor(v_world_pos * 14.0))) {
		discard;
	}

	// Detect dark lead cames vs jewel glass facets via vertex luminance
	float luma = dot(v_col.rgb, vec3(0.299, 0.587, 0.114));
	float is_lead = 1.0 - smoothstep(0.08, 0.22, luma);

	// Enrich pale cyan shards into deep jewel tones
	vec3 glass_col = v_col.rgb;
	if (is_lead < 0.5 && v_col.b > v_col.r * 1.08 && v_col.g > v_col.r * 1.08) {
		float cell = hash13(floor(v_local_pos * 5.5));
		vec3 sapphire = vec3(0.14, 0.30, 0.78);
		vec3 ruby = vec3(0.78, 0.14, 0.16);
		vec3 amber = vec3(0.92, 0.64, 0.16);
		vec3 emerald = vec3(0.14, 0.56, 0.36);
		vec3 violet = vec3(0.48, 0.18, 0.68);
		if (cell < 0.38) {
			glass_col = sapphire;
		} else if (cell < 0.62) {
			glass_col = amber;
		} else if (cell < 0.80) {
			glass_col = ruby;
		} else if (cell < 0.92) {
			glass_col = violet;
		} else {
			glass_col = emerald;
		}
	}

	// Hand-blown antique glass ripple normal perturbation + procedural lead lattice
	float n1 = vnoise(v_world_pos * 7.5);
	float n2 = vnoise(v_world_pos * 18.0 + 4.3);
	vec2 lp = v_local_pos.xy * 6.0;
	float diag_lead = smoothstep(0.92, 0.97, max(abs(sin(lp.x + lp.y)), abs(sin(lp.x - lp.y))));
	float lead_mask = clamp(is_lead + diag_lead * 0.75, 0.0, 1.0);

	vec3 wn = normalize(v_world_nrm + vec3(n1 - 0.5, n2 - 0.5, (n1 - n2) * 0.5) * 0.22 * (1.0 - lead_mask));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	ALBEDO = mix(glass_col * (0.45 + 0.28 * n1), vec3(0.06, 0.065, 0.075), lead_mask);
	ROUGHNESS = mix(0.10 + 0.08 * n2, 0.58, lead_mask);
	METALLIC = mix(0.05, 0.88, lead_mask);
	SPECULAR = 0.88;

	vec3 rime_glass = mix(glass_col, vec3(0.32, 0.44, 0.68), 0.55);
	vec3 emit_tint = mix(glass_col, rime_glass, rime);
	float glow = mix(thaw_glow, rime_glow, rime) * (1.0 - lead_mask) * (0.78 + 0.42 * n1);
	EMISSION = emit_tint * glow;

	if (rh_wave_r > -500.0) {
		float d = distance(v_world_pos, rh_wave_origin);
		float t = 1.0 - clamp(abs(rh_wave_r - d) / rh_wave_band, 0.0, 1.0);
		EMISSION += rh_wave_color * pow(t, 3.0) * 5.5;
	}
}
