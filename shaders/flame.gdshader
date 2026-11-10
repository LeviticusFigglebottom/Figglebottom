shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;

// ---------------------------------------------------------------------------
// Blackbody brazier / hearth flame shader:
// Translucent cobalt-indigo gas base -> incandescent white-gold core ->
// soft alpha-feathered fiery amber tongue with animated flame licks.
// ---------------------------------------------------------------------------

instance uniform vec3 flame_tint = vec3(1.0, 0.76, 0.32);
instance uniform float flame_energy = 3.8;
instance uniform float flame_base_y = 0.0;
instance uniform float flame_height = 0.16;
instance uniform float keep_in_rime = 0.0;
uniform int state_mode = 0;

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;

varying float v_h;
varying vec3 v_world_pos;
varying float v_phase;

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

void vertex() {
	float h_local = clamp((VERTEX.y - flame_base_y) / max(flame_height, 0.04), 0.0, 1.0);
	v_h = h_local;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float phase = wp.x * 3.7 + wp.z * 6.1;
	v_phase = phase;
	// Organic wind flicker around the flame's own vertical axis
	float sway = sin(TIME * 7.2 + phase) * 0.048 + sin(TIME * 15.1 + phase * 2.3) * 0.022;
	VERTEX.x += sway * pow(h_local, 1.35) * flame_height * 2.0;
	VERTEX.z += cos(TIME * 9.4 + phase) * 0.032 * pow(h_local, 1.35) * flame_height * 2.0;
	VERTEX.y = flame_base_y + (VERTEX.y - flame_base_y) * (1.0 + sin(TIME * 12.2 + phase) * 0.08);
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
	float flicker = 0.88 + 0.12 * sin(TIME * 19.0 + v_phase * 2.5);
	float h_norm = clamp(v_h, 0.0, 1.0);
	// Radial core vs outer mantle from view-space normal
	float ndv = abs(dot(normalize(NORMAL), VIEW));
	float core_mask = smoothstep(0.22, 0.78, ndv) * smoothstep(0.04, 0.22, h_norm) * smoothstep(0.86, 0.32, h_norm);

	// Animated flame lick modulation near upper tip
	float lick = 0.5 + 0.5 * sin(TIME * 16.0 - h_norm * 9.0 + v_world_pos.x * 35.0 + v_world_pos.z * 29.0);
	float tip_fade = smoothstep(1.0, 0.56 + lick * 0.18, h_norm);
	float edge_fade = smoothstep(0.05, 0.52, ndv);
	float base_fade = smoothstep(0.0, 0.09, h_norm);

	// Blackbody temperature palette:
	// Blue-indigo gas root -> brilliant white-yellow core -> luminous gold-orange mantle
	vec3 blue_root = mix(vec3(0.20, 0.38, 0.95), flame_tint * 0.7, 0.35);
	vec3 white_core = vec3(1.0, 0.86, 0.5);
	vec3 outer_fire = mix(flame_tint, flame_tint * vec3(1.05, 0.68, 0.28), smoothstep(0.35, 0.92, h_norm));

	vec3 col = mix(blue_root, outer_fire, smoothstep(0.02, 0.24, h_norm));
	col = mix(col, mix(white_core, flame_tint, 0.45), core_mask * 0.6);

	float alpha = clamp(edge_fade * tip_fade * base_fade * (0.68 + 0.32 * core_mask), 0.0, 0.96);
	ALBEDO = col;
	EMISSION = col * flame_energy * (0.9 + 0.7 * core_mask) * flicker;
	ALPHA = alpha * 0.85;
}
