shader_type canvas_item;
// ---------------------------------------------------------------------------
// post_grade.gdshader — Screen-space atmospheric vignette, low-HP
// blood-pulse, trauma radial edge glow, and 1-LSB filmic blue-noise dither.
// ---------------------------------------------------------------------------

uniform float vignette_strength : hint_range(0.0, 1.5) = 0.42;
uniform float low_hp_amount : hint_range(0.0, 1.0) = 0.0;
uniform float rime_amount : hint_range(0.0, 1.0) = 0.0;
uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color = vec3(1.0, 0.82, 0.45);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	centered.x *= 1.15; // aspect-weighted oval
	float r2 = dot(centered, centered);
	float vig = smoothstep(0.55, 1.85, r2);

	// Base optical dark-fantasy corner vignette
	vec3 col = mix(vec3(0.02, 0.016, 0.014), vec3(0.012, 0.016, 0.028), rime_amount);
	float alpha = vig * (vignette_strength + 0.12 * rime_amount);

	// Low-HP crimson pulse around screen periphery
	if (low_hp_amount > 0.001) {
		float pulse = 0.78 + 0.22 * sin(TIME * 4.8);
		float blood_vig = smoothstep(0.28, 1.55, r2) * low_hp_amount * pulse;
		col = mix(col, vec3(0.45, 0.03, 0.02), clamp(blood_vig * 1.6, 0.0, 1.0));
		alpha = max(alpha, blood_vig * 0.78);
	}

	// Parry / Heavy-Hit / World-Shift peripheral resonance flash
	if (flash_strength > 0.001) {
		float ring = smoothstep(0.25, 1.35, r2) * flash_strength;
		col = mix(col, flash_color, clamp(ring * 1.4, 0.0, 1.0));
		alpha = max(alpha, ring * 0.55);
	}

	// Subtle 1-LSB filmic grain to prevent 8-bit dark shadow banding
	float grain = (hash12(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5) * 0.010;
	COLOR = vec4(clamp(col + grain, 0.0, 1.0), clamp(alpha, 0.0, 0.88));
}
