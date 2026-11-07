shader_type spatial;
// Death for Tripo characters (StandardMaterial3D on import, so hall.gdshader's
// death_diss never reached them): the body frosts over, then shatters away in
// noisy flakes with a cold rim. Textures are copied from the imported material
// by FrostDissolve.apply(); death_diss is driven by RH.set_dissolve.
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float normal_scale = 1.0;
uniform bool has_normal = false;
uniform float roughness = 0.85;
uniform float death_diss : hint_range(0.0, 1.0) = 0.0;
uniform float body_height = 1.8;
uniform vec3 frost_color : source_color = vec3(0.82, 0.9, 1.0);
uniform vec3 rim_color : source_color = vec3(0.55, 0.78, 1.0);

varying vec3 obj_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	// body-relative world position: imported meshes carry arbitrary units and
	// node scales, the dissolve should not
	obj_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - NODE_POSITION_WORLD;
}

void fragment() {
	// flakes: coarse cells broken by fine grain, shattering from the head down
	float n = vnoise(obj_pos * 7.0) * 0.7 + vnoise(obj_pos * 23.0) * 0.3;
	float height_bias = clamp(obj_pos.y / max(body_height, 0.1), 0.0, 1.0) * 0.35;
	float shatter = clamp((death_diss - 0.35) / 0.65, 0.0, 1.0);
	float t = n * 0.65 + (0.35 - height_bias);
	if (shatter > 0.0 && t < shatter * 1.05) {
		discard;
	}
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	float frost = smoothstep(0.0, 0.4, death_diss) * (0.55 + 0.45 * n);
	ALBEDO = mix(tex.rgb, frost_color, frost * 0.62);
	ROUGHNESS = mix(roughness, 0.3, frost);
	SPECULAR = mix(0.3, 0.6, frost);
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_scale;
	}
	float rim = 1.0 - smoothstep(0.0, 0.07, t - shatter * 1.05);
	EMISSION = rim_color * rim * step(0.001, shatter) * 2.2 + frost_color * frost * 0.08;
}
