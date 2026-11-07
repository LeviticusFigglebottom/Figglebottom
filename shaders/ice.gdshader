shader_type spatial;
// Translucent grown ice (the Oarsman's oar): cold body tint, bright fresnel
// rim, frozen streaks along the grain, a faint inner glow so it reads against
// snow. death_diss shatters it with its bearer (RH.set_dissolve).
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec3 body_color : source_color = vec3(0.62, 0.8, 0.95);
uniform vec3 rim_color : source_color = vec3(0.85, 0.95, 1.0);
uniform float opacity = 0.62;
uniform float death_diss : hint_range(0.0, 1.0) = 0.0;

varying vec3 lpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	if (death_diss > 0.35 && hash(floor(lpos * 18.0)) < (death_diss - 0.35) * 1.6) {
		discard;
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	// streaks along the shaft (local Y), broken into cells
	float streak = smoothstep(0.55, 1.0, hash(floor(vec3(lpos.x * 40.0, lpos.y * 3.0, lpos.z * 40.0))));
	ALBEDO = mix(body_color, rim_color, fres * 0.7 + streak * 0.25);
	ROUGHNESS = 0.06 + streak * 0.25;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	EMISSION = body_color * (0.12 + fres * 0.35);
	ALPHA = clamp(opacity + fres * 0.35 + streak * 0.15, 0.0, 1.0);
}
