shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------------------------
// hall.gdshader — stylized PBR surface shader for Rimeholt.
// Provides:
//   * Physically-Based Schlick-GGX Specular & Burley Diffuse BRDF
//   * Triplanar Tangent-Derivative Normal Mapping (world or bone-local space)
//   * Full RGB Detail Chromatic Modulation + Packed ORM+Height unpacking
//   * Deep Mortar/Crevice Shadowing, Vertical Rain/Soot Streaks & Ground Damp
//   * Height-blended Rime mortar moss, damp flagstone puddles & crack fissures
//   * Subsurface wax/skin backlight & velvet/cloth grazing sheen
//   * thaw/rime transformation wavefront (StateDirector globals)
// ---------------------------------------------------------------------------

// Surface family parameters (configured by MaterialLib per family)
uniform vec4 albedo : source_color = vec4(0.7, 0.66, 0.58, 1.0);
uniform float roughness_v : hint_range(0.0, 1.0) = 0.82;
uniform float metallic_v : hint_range(0.0, 1.0) = 0.0;
uniform float specular_v : hint_range(0.0, 1.0) = 0.5;
uniform float normal_scale : hint_range(0.0, 3.0) = 1.35;
uniform float sss_strength : hint_range(0.0, 1.0) = 0.0;
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.0;

uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float detail_scale = 1.6;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.30;
uniform float wear_strength : hint_range(0.0, 1.0) = 0.5;
uniform float moss_strength : hint_range(0.0, 1.0) = 0.85;
uniform float crack_strength : hint_range(0.0, 1.0) = 0.45;
uniform float ramp_quantize : hint_range(0.0, 1.0) = 0.0;

// Multi-map PBR triplanar textures (1024x1024)
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.5;
uniform float tex_strength : hint_range(0.0, 1.0) = 0.0;
uniform int use_local_triplanar = 0; // 1 = lock triplanar to mesh/limb space

// Emission (gold trim, braziers, lit windows). gate: 0 = always, 1 = thaw, 2 = rime
uniform vec3 emission_color : source_color = vec3(0.0);
uniform float emission_energy = 0.0;
uniform int emission_gate = 0;

// State behavior: 0 = base (morphs), 1 = thaw-only, 2 = rime-only
uniform int state_mode = 0;
uniform int albedo_from_vc = 0;
// RIME snow crust on top-facing world surfaces (MaterialLib.SNOW)
uniform float snow_strength : hint_range(0.0, 1.0) = 0.0;
// 1 under a roof (AreaBuilder._mark_indoors): no snow falls indoors
instance uniform float indoor = 0.0;

// Per-subtree dissolve (deaths, pickups fading out; applied via RH.set_dissolve)
uniform float death_diss : hint_range(0.0, 1.0) = 0.0;

// Transformation wave globals (set by StateDirector)
global uniform float rh_wave_r;
global uniform vec3 rh_wave_origin;
global uniform float rh_wave_dir;
global uniform float rh_state_blend;
global uniform float rh_wave_band;
global uniform vec3 rh_wave_color;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;
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
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
	           mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float local_rime(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return rh_state_blend;
	}
	float d = distance(wp, rh_wave_origin);
	float w = smoothstep(0.0, 1.0, clamp((rh_wave_r - d) / rh_wave_band, 0.0, 1.0));
	return mix(rh_state_blend, rh_wave_dir, w);
}

float wave_edge(vec3 wp) {
	if (rh_wave_r < -500.0) {
		return 0.0;
	}
	float d = distance(wp, rh_wave_origin);
	float t = 1.0 - clamp(abs(rh_wave_r - d) / rh_wave_band, 0.0, 1.0);
	return pow(t, 2.6);
}

void vertex() {
	v_local_pos = VERTEX;
	v_local_nrm = normalize(NORMAL);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}

void fragment() {
	float rime = local_rime(v_world_pos);

	// Presence / dissolve for state-exclusive meshes
	float presence = 1.0;
	if (state_mode == 1) {
		presence = 1.0 - rime;
	} else if (state_mode == 2) {
		presence = rime;
	}
	float diss_n = 0.0;
	if (presence < 0.999) {
		diss_n = hash13(floor(v_world_pos * 8.0));
		if (presence < diss_n) {
			discard;
		}
	}
	if (death_diss > 0.001) {
		float dn = hash13(floor(v_world_pos * 16.0));
		if (death_diss > dn) {
			discard;
		}
	}

	// Vertex color masks: R = edge wear, G = moss zone, B = vertex AO
	float wear = v_col.r * wear_strength;
	float mossm = v_col.g;
	float ceiling_relax = smoothstep(-0.15, -0.65, v_world_nrm.y);
	float vao = mix(1.0, v_col.b, mix(0.85, 0.28, ceiling_relax));
	if (v_col.r > 0.98 && v_col.g > 0.98 && v_col.b > 0.98) {
		wear = 0.14 * wear_strength;
		mossm = clamp(1.0 - v_world_pos.y * 0.65, 0.0, 1.0);
		vao = 0.92;
	}
	if (albedo_from_vc == 1) {
		wear = 0.0;
		mossm = 0.0;
		vao = 1.0;
	}

	// Macro & meso world-space noise breakup so large stone expanses never tile flatly
	float n_macro = vnoise(v_world_pos * 0.28);
	float n1 = vnoise(v_world_pos * detail_scale);
	float n2 = vnoise(v_world_pos * detail_scale * 3.7 + 11.0);
	vec3 base = albedo.rgb * (1.0 - detail_strength * 0.45 + detail_strength * (n1 * 0.52 + n2 * 0.28 + n_macro * 0.20));
	if (albedo_from_vc == 1) {
		base = v_col.rgb * (0.85 + 0.3 * n1);
	}

	// Triplanar PBR sampling (world-space for architecture, local-space for characters/gear)
	vec3 tp_pos = (use_local_triplanar == 1) ? (v_local_pos * 1.8) : v_world_pos;
	vec3 tp_nrm = normalize((use_local_triplanar == 1) ? v_local_nrm : v_world_nrm);

	float cav_ao = 1.0;
	float rough_mod = 0.5;
	float metal_mask = 1.0;
	float h_field = 0.5;
	vec3 world_nrm = normalize(v_world_nrm);

	if (tex_strength > 0.001) {
		vec3 an = max(abs(tp_nrm) - 0.12, vec3(0.0001));
		vec3 tw = pow(an, vec3(4.0));
		tw /= (tw.x + tw.y + tw.z);

		vec2 uv_x = tp_pos.zy * tex_scale;
		vec2 uv_y = tp_pos.xz * tex_scale;
		vec2 uv_z = tp_pos.xy * tex_scale;

		// 1. Full RGB Albedo detail (per-block chromatic variation & mortar tinting)
		vec3 tx = texture(detail_tex, uv_x).rgb;
		vec3 ty = texture(detail_tex, uv_y).rgb;
		vec3 tz = texture(detail_tex, uv_z).rgb;
		vec3 td = tx * tw.x + ty * tw.y + tz * tw.z;
		base *= mix(vec3(1.0), td * 2.02, tex_strength);

		// 2. ORM + Height (R=Cavity AO, G=Roughness mod, B=Metallic mask, A=Height)
		vec4 ox = texture(orm_tex, uv_x);
		vec4 oy = texture(orm_tex, uv_y);
		vec4 oz = texture(orm_tex, uv_z);
		vec4 orm = ox * tw.x + oy * tw.y + oz * tw.z;
		cav_ao = mix(1.0, orm.r, tex_strength);
		rough_mod = mix(0.5, orm.g, tex_strength);
		metal_mask = mix(1.0, orm.b, tex_strength * 0.5);
		h_field = orm.a;

		// 3. UDN Triplanar Normal Mapping
		vec2 nx = (texture(normal_tex, uv_x).rg * 2.0 - 1.0) * normal_scale * tex_strength;
		vec2 ny = (texture(normal_tex, uv_y).rg * 2.0 - 1.0) * normal_scale * tex_strength;
		vec2 nz = (texture(normal_tex, uv_z).rg * 2.0 - 1.0) * normal_scale * tex_strength;

		// Tangent-plane perturbations aligned to world/local axes
		vec3 pert_x = vec3(0.0, -nx.y, nx.x);
		vec3 pert_y = vec3(ny.x, 0.0, -ny.y);
		vec3 pert_z = vec3(nz.x, -nz.y, 0.0);
		vec3 d_nrm = pert_x * tw.x + pert_y * tw.y + pert_z * tw.z;
		if (use_local_triplanar == 1) {
			d_nrm = (MODEL_MATRIX * vec4(d_nrm, 0.0)).xyz;
		}
		world_nrm = normalize(world_nrm + d_nrm);
	}

	// Micro-grain surface normal perturbation for un-textured or weathered stone
	vec3 micro_n = vec3(n2 - 0.5, fract(n1 + n2) - 0.5, n1 - 0.5) * 0.16 * detail_strength;
	world_nrm = normalize(world_nrm + micro_n);
	NORMAL = normalize((VIEW_MATRIX * vec4(world_nrm, 0.0)).xyz);

	// Deep mortar / crevice mask & architectural ground-soot / rain streaks
	float crevice_mask = smoothstep(0.44, 0.12, h_field);
	float crack = crevice_mask * (0.48 + 0.52 * n1) * crack_strength;

	// Architectural weathering: rising damp near floor (y=0..0.95m) & vertical water/soot streaks
	float arch_grime = 0.0;
	if (use_local_triplanar == 0 && albedo_from_vc == 0) {
		float wall_mask = clamp(1.0 - abs(world_nrm.y) * 1.4, 0.0, 1.0);
		float streak_n = (wall_mask > 0.001) ? vnoise(vec3(v_world_pos.x * 2.2, v_world_pos.y * 0.32, v_world_pos.z * 2.2)) : 1.0;
		float ground_damp = (1.0 - smoothstep(0.0, 0.92, max(v_world_pos.y, 0.0))) * (0.55 + 0.45 * n_macro);
		arch_grime = clamp(wall_mask * ((1.0 - streak_n) * 0.18 + ground_damp * 0.34) + ground_damp * 0.16, 0.0, 0.48);
	}

	// Edge-chip highlight & metallic edge burnishing from wear mask
	float edge_chip = wear * smoothstep(0.38, 0.86, h_field);
	base = mix(base, base * 1.26 + vec3(0.04, 0.036, 0.03), edge_chip * 0.58);

	// Apply mortar cavity & crevice shadowing to BOTH Thaw and Rime so masonry never looks flat
	float mortar_shade = (1.0 - crack * 0.34) * mix(0.72, 1.0, cav_ao) * (1.0 - arch_grime * 0.48);

	// THAW look: rich weathered golden-limestone & burnished iron/bronze with dark mortar joints
	vec3 thaw_col = base * vec3(1.02, 0.98, 0.91) * mortar_shade;

	// RIME look: moody cold silver-slate ashlar masonry, crevice-first moss & damp flagstones
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	vec3 rime_col = mix(base, vec3(luma), 0.52) * vec3(0.90, 0.95, 1.02) * mortar_shade;

	// Moss settles into mortar crevices (low h_field) first, then spreads up from bases
	float moss_up = clamp(world_nrm.y * 0.55 + 0.58, 0.0, 1.0);
	float moss = mossm * moss_strength * moss_up * smoothstep(0.30, 0.76, n_macro * 0.45 + crevice_mask * 0.68);
	vec3 moss_tone = mix(vec3(0.09, 0.15, 0.07), vec3(0.17, 0.23, 0.12), n_macro);
	rime_col = mix(rime_col, moss_tone, clamp(moss, 0.0, 0.74));
	thaw_col = mix(thaw_col, moss_tone * vec3(1.12, 1.08, 0.92), clamp(moss * 0.35, 0.0, 0.32));

	// Damp sheen on flat horizontal floors in rime (broad macro-scale puddles)
	float floor_zone = smoothstep(0.14, 0.03, abs(v_local_pos.y));
	float puddle = rime * floor_zone * clamp((world_nrm.y - 0.88) * 8.0, 0.0, 1.0)
			* smoothstep(0.36, 0.74, n_macro * 0.80 + (1.0 - h_field) * 0.25) * (1.0 - metallic_v);
	rime_col = mix(rime_col, rime_col * 0.82, puddle * 0.38);

	// Snow settles on whatever faces the sky; hoarfrost greys the rest
	if (snow_strength > 0.001 && use_local_triplanar == 0 && indoor < 0.5) {
		float top = smoothstep(0.45, 0.8, world_nrm.y + (n1 - 0.5) * 0.35);
		vec3 snow_c = vec3(0.86, 0.90, 0.96) * (0.94 + 0.06 * n1);
		rime_col = mix(rime_col, snow_c, top * snow_strength);
		// hoarfrost: a soft pale bloom, broad not speckled
		rime_col = mix(rime_col, vec3(0.74, 0.80, 0.88), (1.0 - top) * snow_strength * 0.16 * smoothstep(0.3, 0.8, n_macro));
	}
	vec3 final_albedo = mix(thaw_col, rime_col, rime);

	// View vector & Fresnel for velvet cloth sheen and moonlit atmospheric rim
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	float ndv = clamp(dot(world_nrm, view_dir), 0.0, 1.0);
	// Gently restrain grazing Fresnel & specular glare on elevated horizontal ledges
	// without darkening their diffuse albedo or ambient occlusion at shallow angles
	float horiz_ledge = (1.0 - floor_zone) * smoothstep(0.75, 0.92, world_nrm.y) * (1.0 - smoothstep(0.08, 0.42, ndv));
	float fres = pow(1.0 - ndv, 3.2) * (1.0 - horiz_ledge * 0.55);

	// Cloth / velvet grazing microfiber sheen (heavy wool look)
	if (sheen_strength > 0.001) {
		vec3 sheen_col = mix(final_albedo * 1.45 + vec3(0.06, 0.05, 0.04), vec3(0.62, 0.70, 0.86) * luma, rime * 0.5);
		final_albedo = mix(final_albedo, sheen_col, fres * sheen_strength * cav_ao);
	}

	ALBEDO = final_albedo;

	// Physically-Based Metallic, Specular & Roughness
	float met = clamp(metallic_v * mix(0.72, 1.15, metal_mask) * (1.0 - moss * 0.85), 0.0, 1.0);
	METALLIC = met;

	float rgh = roughness_v + (rough_mod - 0.5) * 0.40 + rime * 0.02 - edge_chip * 0.16 + moss * 0.22 - arch_grime * 0.12;
	rgh = mix(rgh, 0.88, horiz_ledge * 0.5);
	rgh = mix(rgh, 0.08, puddle * 0.88); // wet puddles gleam under moonlight & torchlight
	ROUGHNESS = clamp(rgh, 0.05, 1.0);

	float spec = specular_v * mix(0.42, 1.22, cav_ao) * (1.0 - horiz_ledge * 0.45) + puddle * 0.42;
	SPECULAR = clamp(spec, 0.05, 1.0);

	float total_ao = clamp(vao * cav_ao * (1.0 - crack * 0.38) * (1.0 - arch_grime * 0.28), 0.08, 1.0);
	AO = mix(1.0, total_ao, 0.88);
	AO_LIGHT_AFFECT = 0.68;

	// Subsurface wax / skin translucency under flames and sun
	if (sss_strength > 0.001) {
		BACKLIGHT = mix(vec3(0.92, 0.48, 0.18), vec3(0.42, 0.56, 0.84), rime * 0.65) * sss_strength * 0.48;
	}

	// Cavity-masked top-down atmospheric & moonlit graze for crisp silhouettes
	float sky_facing = clamp(world_nrm.y * 0.45 + 0.60, 0.0, 1.0);
	vec3 rim_c = mix(vec3(1.0, 0.80, 0.52), vec3(0.54, 0.70, 1.0), rime);
	vec3 emis = rim_c * fres * rim_strength * mix(0.055, 0.12, rime) * total_ao * sky_facing;
	// Upward floor-bounce fill on downward-facing ceilings & vault soffits (where directional sun & sky_fill have N.L <= 0)
	float ceil_face = smoothstep(-0.15, -0.75, world_nrm.y);
	vec3 bounce_col = mix(vec3(0.32, 0.27, 0.20), vec3(0.16, 0.20, 0.28), rime);
	emis += final_albedo * bounce_col * ceil_face * total_ao;

	// Surface emission (gold trim, braziers, lit windows) gated by state
	float gate = 1.0;
	if (emission_gate == 1) {
		gate = 1.0 - rime;
	} else if (emission_gate == 2) {
		gate = rime;
	}
	emis += emission_color * emission_energy * gate;

	// The Wavefront: frost/ember crust & dissolution
	float edge = wave_edge(v_world_pos);
	if (edge > 0.001) {
		float ember_vein = smoothstep(0.32, 0.78, (1.0 - h_field) * 0.65 + n2 * 0.55);
		float diss_edge = 0.0;
		if (state_mode != 0 && presence < 0.999) {
			diss_edge = 1.0 - smoothstep(0.0, 0.25, presence - diss_n);
		}
		vec3 core_fire = mix(rh_wave_color, vec3(1.0, 0.92, 0.65), edge * ember_vein);
		emis += core_fire * (edge * (3.5 + 4.5 * ember_vein) + diss_edge * edge * 14.0);
	}
	if (death_diss > 0.001) {
		float dn2 = hash13(floor(v_world_pos * 16.0));
		emis += vec3(0.65, 0.78, 1.25) * (1.0 - smoothstep(0.0, 0.2, dn2 - death_diss)) * 2.4;
	}

	EMISSION = emis;
}
