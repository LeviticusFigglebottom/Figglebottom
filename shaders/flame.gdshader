shader_type spatial;
render_mode cull_disabled, unshaded, blend_add, depth_draw_never;

// ---------------------------------------------------------------------------
// flame.gdshader: a tongue of fire on crossed cards (KitLib._flame).
// UV: u across the card, v = 1 at the base, 0 at the tip.
// The flame is drawn, not modelled: a teardrop that narrows upward, its axis
// pushed about by rising noise, its top torn off where the noise runs out.
// Colour runs deep red at the edges and tips through the tint to a pale core
// low in the body. Additive, so crossed cards build a volume, not a shape.
// ---------------------------------------------------------------------------

instance uniform vec3 flame_tint = vec3(1.0, 0.62, 0.22);
instance uniform float flame_energy = 1.0;
instance uniform float flame_base_y = 0.0;    // kept for KitLib (unused on cards)
instance uniform float flame_height = 0.16;   // kept for KitLib (unused on cards)
instance uniform float keep_in_rime = 0.0;
uniform int state_mode = 0;

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;

varying vec3 v_world_pos;
varying float v_phase;
varying float v_disc;

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.31, 289.17))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	v_phase = fract(org.x * 3.7 + org.z * 6.1 + org.y * 1.3) * 20.0;
	v_disc = UV2.x;
	float h = (UV2.x > 0.5) ? 0.0 : 1.0 - UV.y;
	// the whole tongue leans and recovers; the base stays on its fuel
	float sway = sin(TIME * 5.1 + v_phase) * 0.06 + sin(TIME * 11.3 + v_phase * 2.3) * 0.03;
	VERTEX.x += sway * h * h;
	VERTEX.z += cos(TIME * 6.7 + v_phase) * 0.04 * h * h;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rime = local_rime(v_world_pos);
	float presence = 1.0 - rime;
	if (state_mode == 2) {
		presence = rime;
	} else if (keep_in_rime > 0.5) {
		presence = 1.0;
	}
	if (presence < 0.5) {
		discard;
	}
	if (v_disc > 0.5) {
		// the heart, seen from above: a soft bright pool that boils
		vec2 c = UV * 2.0 - 1.0;
		float rr = length(c);
		float boil = vnoise(c * 3.0 + vec2(TIME * 1.3, -TIME * 1.7) + v_phase);
		float pool = (1.0 - smoothstep(0.15, 0.95, rr + (boil - 0.5) * 0.35));
		// only when looked down on; from the side the cards do the work
		float down = smoothstep(0.25, 0.7, abs(NORMAL.z));
		ALBEDO = mix(flame_tint, vec3(1.0, 0.9, 0.62), pool * 0.6) * flame_energy * (0.5 + boil);
		ALPHA = pool * down * 0.9;
	} else {
	float h = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * 1.9;
	// rising noise: a slow body and a fast lick
	float n1 = vnoise(vec2(x * 1.6 + v_phase, h * 2.4 - t));
	float n2 = vnoise(vec2(x * 3.7 - v_phase, h * 5.5 - t * 2.1));
	float n = n1 * 0.65 + n2 * 0.35;
	// the axis wanders more the higher it gets
	float axis = (n1 - 0.5) * 0.7 * h;
	// teardrop: widest a little above the base, drawn to a point
	float width = 0.72 * pow(1.0 - h, 0.7) * smoothstep(-0.05, 0.22, h) + 0.04;
	float d = abs(x - axis) / width;
	float body = 1.0 - smoothstep(0.35, 1.0, d);
	// the top tears off where the noise runs out
	float tear = smoothstep(h * 1.25 - 0.42, h * 1.25 - 0.08, n);
	float a = body * tear * smoothstep(0.0, 0.07, h);
	float heat = a * (1.0 - h * 0.75) * (0.75 + 0.5 * n2);
	vec3 edge_c = flame_tint * vec3(0.85, 0.28, 0.08);
	vec3 core_c = mix(flame_tint, vec3(1.0, 0.9, 0.62), 0.6);
	vec3 col = mix(edge_c, flame_tint, smoothstep(0.1, 0.5, heat));
	col = mix(col, core_c, smoothstep(0.5, 0.95, heat));
	float flicker = 0.9 + 0.1 * sin(TIME * 17.0 + v_phase * 2.5);
	ALBEDO = col * flame_energy * flicker * (0.55 + heat);
	ALPHA = clamp(a, 0.0, 1.0);
	}
}
