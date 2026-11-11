shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx, diffuse_burley;
// ---------------------------------------------------------------------------
// spring.gdshader: the Coldwell spring in its ring of stones. Not a sheet of
// colour: clear water you can see the bed through at the rim (refracted
// against the screen, like shaders/ice_sheet.gdshader), going down into a
// dark, still eye in the middle where it comes up out of the ground. The
// only movement is the slow swell of the upwelling, ringing outward.
// ---------------------------------------------------------------------------

uniform int state_mode = 1;
uniform float radius = 2.55;
uniform vec3 shallow_tint : source_color = vec3(0.62, 0.80, 0.80);
uniform vec3 deep_tint : source_color = vec3(0.012, 0.035, 0.045);
uniform float clarity = 0.7;      // metres of water before the bed is lost
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

global uniform float rh_state_blend;
global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_wave_band;

varying vec3 wpos;
varying vec3 lpos;

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return clamp(rh_state_blend, 0.0, 1.0);
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / max(rh_wave_band, 0.01), 0.0, 1.0));
	return clamp(mix(rh_state_blend, rh_wave_dir, w), 0.0, 1.0);
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rime = local_rime(wpos);
	if (state_mode == 1 && rime > 0.5) { discard; }
	if (state_mode == 2 && rime < 0.5) { discard; }
	float r = clamp(length(lpos.xz) / radius, 0.0, 1.0);
	// the swell: slow rings leaving the middle, dying before the rim
	float ring = sin(r * 26.0 - TIME * 1.1) * (1.0 - r) * (1.0 - r) * smoothstep(0.0, 0.12, r);
	vec2 rdir = normalize(lpos.xz + vec2(1e-4));
	vec2 slope = rdir * ring * 0.05 + (vec2(vnoise(wpos.xz * 2.1 + TIME * 0.08), vnoise(wpos.xz * 2.1 + 7.0 - TIME * 0.06)) - 0.5) * 0.03;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(slope.x, 1.0, slope.y)), 0.0)).xyz);
	// how much water the eye looks through to the bed
	float zd = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, zd, 1.0);
	v.xyz /= v.w;
	float through = max(0.0, VERTEX.z - v.z);
	vec3 under = textureLod(screen_tex, SCREEN_UV + slope * 0.35, 0.0).rgb;
	// the eye of the spring: the bed falls away, whatever the mesh under it is
	float eye = smoothstep(0.78, 0.18, r);
	float op = clamp(1.0 - exp(-through / clarity) * (1.0 - eye * 0.96), 0.0, 1.0);
	vec3 seen = mix(under * shallow_tint, deep_tint, op);
	// a thread of pale silt carried up and round, just off the centre
	float silt = smoothstep(0.62, 0.9, vnoise(vec2(atan(lpos.z, lpos.x) * 2.0 + TIME * 0.05, r * 7.0 - TIME * 0.12))) * eye * (1.0 - eye) * 1.2;
	seen += vec3(0.05, 0.07, 0.07) * silt;
	ALBEDO = vec3(0.0);
	EMISSION = seen;
	ROUGHNESS = 0.03;
	SPECULAR = 0.65;
	ALPHA = 1.0;
}
