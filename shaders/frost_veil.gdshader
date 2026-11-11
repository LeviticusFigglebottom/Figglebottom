shader_type spatial;
render_mode cull_disabled, unshaded, blend_mix, depth_draw_never;

// ---------------------------------------------------------------------------
// Holdfast arena frost veil. A veil is three bowed sheets (FrostVeil builds
// them; UV2.x = -1 / 0 / +1 for back / heart / front), not one card:
//  - each sheet carries its own drifting mist, sampled with a parallax
//    offset so there is mist "inside" the sheet as the camera moves;
//  - the heart sheet refracts what is behind it and carries the region's
//    dressing: frozen net, hanging fleece strands, ice cracks, door-board
//    seams, sod clods;
//  - sheets brighten where they turn edge-on, so from the side the veil is
//    a lens of frost with a thickness, never a line.
// ---------------------------------------------------------------------------

uniform vec3 tint : source_color = vec3(0.84, 0.81, 0.73);
// a veil may be a curtain of frozen net (the Netmender's, SLICE.md 3):
// diamond mesh in metres; 0 strength is plain mist
uniform float mesh_size = 0.34;
uniform float mesh_strength : hint_range(0.0, 1.0) = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.68;
// regional dressing (FrostVeil.DRESS; an area's "shader" block overrides)
uniform float strands : hint_range(0.0, 1.0) = 0.0;   // fleece caught and frozen
uniform float cracks : hint_range(0.0, 1.0) = 0.0;    // sheet ice
uniform float boards : hint_range(0.0, 1.0) = 0.0;    // a door's planks under the ice
uniform float clods : hint_range(0.0, 1.0) = 0.0;     // frozen sod
uniform float refraction : hint_range(0.0, 2.0) = 0.6;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;

varying vec3 v_lp;
varying float v_layer;
varying vec3 v_view_l;

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

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.52;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.08 + vec3(4.3, -2.7, 1.9);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	v_layer = UV2.x;
	v_lp = VERTEX;
	// each sheet breathes on its own beat
	float ph = v_layer * 2.1;
	VERTEX.z += (sin(VERTEX.y * 1.3 + TIME * 0.5 + ph) * 0.05 + sin(VERTEX.x * 1.7 - TIME * 0.37 + ph * 1.7) * 0.04)
			* smoothstep(0.0, 0.8, VERTEX.y);
	vec3 cam_l = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	v_view_l = cam_l - VERTEX;
}

void fragment() {
	vec3 vl = normalize(v_view_l);
	// mist a little way inside the sheet: slides against the surface layer
	vec2 par = vl.xy / max(abs(vl.z), 0.3);
	vec2 uv = v_lp.xy + vec2(v_layer * 3.7, v_layer * 1.9);
	float tt = TIME * (1.0 + v_layer * 0.25);
	// Counter-rotating dual-layer domain warp for billowing smoke plumes
	vec3 q = vec3(
		fbm(vec3(uv * 0.95 + vec2(0.0, -tt * 0.14), tt * 0.11)),
		fbm(vec3(uv * 0.95 + vec2(3.4, -tt * 0.18), tt * 0.13 + 5.2)),
		0.0
	);
	vec2 warped1 = uv + (q.xy - 0.5) * 0.72;
	vec2 warped2 = (uv - par * 0.16) * 1.45 - (q.yx - 0.5) * 0.55 + vec2(tt * 0.06, -tt * 0.22);

	float cloud1 = fbm(vec3(warped1 * 1.4, tt * 0.16));
	float cloud2 = fbm(vec3(warped2 * 1.8 + 7.1, tt * 0.22));
	float mist = mix(cloud1, cloud2, 0.48);

	// Soft billowing density with subtle luminous crests
	float body = smoothstep(0.18, 0.78, mist);
	float crest = pow(clamp(cloud1 * cloud2 * 2.2, 0.0, 1.0), 2.2);

	// Pointed-arch framing & threshold floor pooling
	float hx = abs(UV.x - 0.5) * 2.0;
	float hy = 1.0 - UV.y;
	float dy = max(hy - 0.565, 0.0) / 0.425;
	float max_hx = 0.90 * clamp((sqrt(max(1.0 - dy * dy * 0.91, 0.0)) - 0.305) / 0.695, 0.0, 1.0);
	float edge_x = smoothstep(max_hx, max(max_hx - 0.24, 0.0), hx);
	float edge_y = smoothstep(-0.01, 0.09, hy) * smoothstep(0.99, 0.90, hy);
	float floor_pool = smoothstep(0.18, -0.01, hy) * 0.22;
	float frame = edge_x * edge_y;

	vec3 deep_col = tint * vec3(0.72, 0.77, 0.87);
	vec3 crest_col = tint * vec3(1.16, 1.17, 1.14);
	vec3 col = mix(deep_col, crest_col, clamp(body * 0.65 + crest * 0.55, 0.0, 1.0));

	float heart = 1.0 - abs(v_layer);     // 1 on the middle sheet
	float dress = 0.0;

	// the frozen net: diamond mesh with rimed knots, sagging a little
	vec2 m = v_lp.xy / mesh_size;
	m.y += sin(m.x * 0.7) * 0.12;
	vec2 dg = vec2(m.x + m.y, m.x - m.y) * 0.7071;
	vec2 cell = abs(fract(dg) - 0.5);
	float twine = 1.0 - smoothstep(0.035, 0.085, min(cell.x, cell.y));
	float knot = 1.0 - smoothstep(0.06, 0.16, length(0.5 - cell));
	float net = clamp(twine + knot * 0.8, 0.0, 1.0) * mesh_strength * heart;
	col = mix(col, vec3(0.93, 0.97, 1.0), net * 0.75);
	dress += net * 0.6;

	// fleece: locks of wool hanging in the gap, stiff with rime; every sheet
	// has its own, so they cross as the camera moves
	if (strands > 0.001) {
		float lock = vnoise(vec3(v_lp.x * 9.0 + v_layer * 13.0, v_lp.y * 0.55 + sin(v_lp.x * 3.0) * 0.3, v_layer * 5.0));
		float fine = vnoise(vec3(v_lp.x * 46.0 + v_layer * 31.0, v_lp.y * 2.2, 3.0));
		float hang = smoothstep(0.42, 0.72, lock) * (0.55 + 0.45 * fine);
		hang *= smoothstep(0.0, 0.35, hy + lock * 0.5 - 0.25);   // locks end ragged above the floor
		col = mix(col, vec3(0.95, 0.92, 0.84), hang * strands * 0.8);
		dress += hang * strands * 0.75;
	}
	// sheet ice: a web of fine white fractures, and a clearer pane
	if (cracks > 0.001) {
		float c1 = abs(fbm(vec3(v_lp.xy * 1.3 + v_layer * 4.0, 2.0)) - 0.5);
		float c2 = abs(fbm(vec3(v_lp.xy * 3.1 + 9.0, 5.0 + v_layer)) - 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.018, c1)) + (1.0 - smoothstep(0.0, 0.012, c2)) * 0.6;
		crack *= cracks;
		col = mix(col, vec3(0.94, 0.98, 1.0), clamp(crack, 0.0, 1.0));
		dress += crack * 0.7;
	}
	// a door under the ice: plank seams, frost creeping out from each
	if (boards > 0.001) {
		float bx = v_lp.x / 0.29 + 0.5;
		float seam = abs(fract(bx) - 0.5);
		float tone = hash13(vec3(floor(bx), 3.0, 7.0));
		float grain = vnoise(vec3(v_lp.x * 30.0, v_lp.y * 1.6, floor(bx)));
		vec3 wood = vec3(0.50, 0.50, 0.53) * (0.8 + 0.4 * tone) * (0.85 + 0.3 * grain);
		float creep = smoothstep(0.5, 0.2, seam + (cloud1 - 0.5) * 0.5);   // frost thickest at the seams
		float plank = heart * boards * (1.0 - creep * 0.85);
		col = mix(col, wood, plank * 0.6);
		col = mix(col, vec3(0.2, 0.2, 0.22), heart * boards * (1.0 - smoothstep(0.0, 0.03, 0.5 - seam)) * 0.6);
		dress += heart * boards * 0.7;
	}
	// frozen sod: dark clods of turf lifted into the veil, thick at the foot
	if (clods > 0.001) {
		float cl = fbm(vec3(v_lp.xy * 2.6 + v_layer * 6.0, 1.0));
		float rise = smoothstep(0.75, 0.0, hy) * 0.3;
		float clod = smoothstep(0.56 - rise, 0.66 - rise, cl) * clods;
		vec3 earth = mix(vec3(0.16, 0.13, 0.10), vec3(0.24, 0.26, 0.16), vnoise(vec3(v_lp.xy * 14.0, 4.0)));
		// rime on the upper edge of each clod
		float lip = smoothstep(0.0, 0.05, fbm(vec3((v_lp.xy + vec2(0.0, 0.04)) * 2.6 + v_layer * 6.0, 1.0)) - cl);
		col = mix(col, mix(earth, vec3(0.9, 0.93, 0.97), lip * 0.6), clod);
		dress += clod * 0.85;
	}

	// a sheet seen edge-on thickens: the veil has a rim from the side
	float graze = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rimf = pow(graze, 2.0);
	col = mix(col, crest_col, rimf * 0.5);

	float a = (body * density * 0.8 + floor_pool + 0.12 + crest * 0.20) * mix(0.5, 0.8, heart);
	a = a + dress + rimf * 0.45;
	a = clamp(a * frame, 0.0, 0.94);

	// the heart sheet bends what is behind it
	vec3 emis = col * (0.30 + body * 0.42 + crest * 0.55 + dress * 0.25);
	if (heart > 0.5 && refraction > 0.001) {
		vec2 bend = (q.xy - 0.5) * 0.045 * refraction * frame;
		// (level 0 and a second tap: the screen copy's higher mips are not
		// reliable on every driver, and came out black under lavapipe)
		vec3 behind = 0.5 * (textureLod(screen_tex, SCREEN_UV + bend, 0.0).rgb + textureLod(screen_tex, SCREEN_UV - bend * 0.6, 0.0).rgb);
		float glass = clamp(0.55 * refraction, 0.0, 0.9) * frame;
		// what shows through is the bent scene, tinted; the mist sits on it
		vec3 through_c = behind * mix(vec3(1.0), tint * 1.05, 0.5) + tint * 0.11;
		ALBEDO = vec3(0.0);
		EMISSION = mix(through_c, col + emis * 0.6, a);
		ALPHA = max(a, glass);
	} else {
		ALBEDO = col;
		EMISSION = emis;
		ALPHA = a;
	}
}
