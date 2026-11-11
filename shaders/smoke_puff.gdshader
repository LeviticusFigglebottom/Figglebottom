shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// ---------------------------------------------------------------------------
// smoke_puff.gdshader: one soft puff of torch smoke on a CPUParticles3D quad
// (BrandFire). Billboarded here; its fade is read from the particle's own
// age (INSTANCE_CUSTOM.y, 0 at birth to 1 at death), so it never depends on
// a colour ramp: thin and dark where it leaves the flame, paler and wider
// as it rises, gone before it dies.
// ---------------------------------------------------------------------------

uniform vec3 young : source_color = vec3(0.15, 0.13, 0.11);
uniform vec3 old : source_color = vec3(0.46, 0.46, 0.47);
uniform float density = 0.3;

varying float v_life;

void vertex() {
	v_life = INSTANCE_CUSTOM.y;
	float ang = INSTANCE_CUSTOM.x;
	float grow = mix(0.3, 1.0, sqrt(v_life));
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)) * grow;
	mat4 face = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	face = face * mat4(vec4(cos(ang), -sin(ang), 0.0, 0.0), vec4(sin(ang), cos(ang), 0.0, 0.0),
			vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	face = face * mat4(vec4(sc.x, 0.0, 0.0, 0.0), vec4(0.0, sc.y, 0.0, 0.0), vec4(0.0, 0.0, sc.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float soft = smoothstep(1.0, 0.15, r);
	float fade = smoothstep(0.0, 0.12, v_life) * (1.0 - smoothstep(0.35, 1.0, v_life));
	ALBEDO = mix(young, old, v_life);
	ALPHA = soft * soft * fade * density;
}
