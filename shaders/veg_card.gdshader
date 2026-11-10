shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_lambert, specular_disabled;

// ---------------------------------------------------------------------------
// veg_card.gdshader: instanced ground-cover clumps (Scatter "veg") as crossed
// alpha cards cut from a 2x2 atlas of painted clumps (tools/art/veg_atlas.py).
// UV:  0..1 inside one atlas cell, v = 0 at the tips, 1 at the root.
// UV2: x = this card's cell offset (so one clump mixes atlas cells).
// INSTANCE_CUSTOM: x = base cell (0..1), y = dryness, z = value jitter,
//                  w = wind phase.
// Wind: a slow travelling gust plus a flutter, scaled by height so the roots
// stay planted. RIME: most clumps are under the snow; the survivors stand
// half-buried, stiff, and frosted pale from the tips down.
// ---------------------------------------------------------------------------

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float wind_strength = 0.16;
uniform vec2 wind_dir = vec2(0.8, -0.6);
// colour drift across a field: the clump texture is multiplied by a tint
// that wanders between these two, plus a per-clump dryness toward straw
uniform vec3 tint_a : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 tint_b : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 dry_col : source_color = vec3(0.42, 0.36, 0.2);
uniform float dryness = 0.6;         // how far the driest clumps go to straw
// the ground the clump stands in: roots sink into it instead of ending on a line
uniform vec3 ground_col : source_color = vec3(0.1, 0.11, 0.05);
uniform float rime_keep = 0.38;     // share of clumps that still show in RIME
uniform float rime_bury = 0.5;      // how much of a survivor is under the snow
uniform float alpha_cut = 0.42;
uniform int state_mode = 0;

global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;

varying vec3 v_wp;
varying vec3 v_n;
varying vec4 v_inst;
varying float v_cell;
varying float v_dist;

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(41.31, 289.17))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(41.31, 289.17))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(41.31, 289.17))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(41.31, 289.17))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	float rime = local_rime(org);
	float h = 1.0 - UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(dot(wp.xz, wind_dir) * 0.35 - TIME * 1.7 + INSTANCE_CUSTOM.w * 0.7) * 0.5 + 0.5;
	float flutter = sin(TIME * 5.3 + wp.x * 2.1 + wp.z * 1.7 + INSTANCE_CUSTOM.w * 6.0) * 0.25;
	float bend = (gust * 0.8 + flutter) * wind_strength * h * h * (1.0 - rime * 0.9);
	vec3 off_w = vec3(wind_dir.x, -0.15, wind_dir.y) * bend;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off_w, 0.0)).xyz;
	// RIME: the snow has most clumps outright; the rest stand half-buried
	float keep = fract(sin(dot(org.xz, vec2(12.9898, 78.233))) * 43758.5453);
	VERTEX.y -= rime * rime_bury * 0.5;
	VERTEX.xz *= 1.0 - 0.25 * rime;
	if (rime > 0.5 && keep > rime_keep) {
		VERTEX = vec3(0.0, -1.0, 0.0);
	}
	// a clump lights like a soft dome, not like flat cards: the normal leans
	// from straight up toward "outward from the root", the same on both faces
	vec3 dome = normalize(vec3(VERTEX.x * 0.9, 0.55, VERTEX.z * 0.9));
	dome = normalize(mix(dome, vec3(0.0, 1.0, 0.0), rime * 0.6));
	v_n = normalize((MODELVIEW_MATRIX * vec4(dome, 0.0)).xyz);
	v_wp = wp;
	v_inst = INSTANCE_CUSTOM;
	v_cell = mod(floor(INSTANCE_CUSTOM.x * 3.999) + UV2.x, 4.0);
	v_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	float rime = local_rime(v_wp);
	if (state_mode == 1 && rime > 0.5) {
		discard;
	}
	if (state_mode == 2 && rime < 0.5) {
		discard;
	}
	float cell = floor(v_cell + 0.5);
	vec2 cuv = clamp(UV, vec2(0.004), vec2(0.996));
	vec2 uv = (cuv + vec2(mod(cell, 2.0), floor(cell * 0.5))) * 0.5;
	vec4 t = texture(atlas, uv);
	float h = 1.0 - UV.y;
	// mips thin the blades out: lean on the alpha with distance to keep cover
	float a = t.a * (1.0 + clamp(v_dist / 30.0, 0.0, 1.0) * 0.9);
	if (a < alpha_cut) {
		discard;
	}
	float drift = vnoise(v_wp.xz * 0.11) * 0.65 + vnoise(v_wp.xz * 0.43 + 7.3) * 0.35;
	vec3 c = t.rgb * mix(tint_a, tint_b, drift);
	float luma = dot(c, vec3(0.3, 0.59, 0.11));
	// dry clumps bleach toward straw, most at the tips
	float dry = clamp(v_inst.y * 1.3 - 0.35 + (drift - 0.5) * 0.5, 0.0, 1.0) * mix(0.45, 1.0, h);
	c = mix(c, dry_col * (0.55 + luma * 2.2), dry * dryness);
	c *= mix(0.7, 1.0, v_inst.z);
	// roots sink into the turf colour and its shade
	float root = smoothstep(0.0, 0.3, h);
	vec3 thaw_c = mix(ground_col, c, mix(0.35, 1.0, root)) * mix(0.62, 1.0, root);
	// frosted: pale throughout, whiter toward the tips, never dark blades
	vec3 frost = mix(vec3(0.62, 0.66, 0.72) + vec3(luma) * 0.6, vec3(0.9, 0.93, 0.98), smoothstep(0.15, 0.75, h));
	vec3 rime_c = mix(mix(c, vec3(luma), 0.6) * 1.3 + 0.12, frost, 0.72);
	ALBEDO = mix(thaw_c, rime_c, rime);
	NORMAL = v_n;
	ROUGHNESS = mix(0.85, 0.7, rime);
	BACKLIGHT = mix(vec3(0.2, 0.18, 0.07), vec3(0.1, 0.12, 0.15), rime) * h;
	AO = mix(mix(0.5, 0.9, rime), 1.0, root);
	AO_LIGHT_AFFECT = 0.4;
}
