shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------------------------
// hall.gdshader — stylized PBR surface shader for Rimeholt.
// Provides:
//   * Physically-Based Schlick-GGX Specular & Burley Diffuse BRDF
//   * Photo PBR sets (assets/textures, tools/art/fetch_textures.py): albedo,
//     normal and AO/rough/height, sampled either through the mesh's metre UVs
//     (uv_mode 1: ProcMesh output, plank-aligned) or object-aligned triplanar
//     (uv_mode 0: anything else; rotates with the object, world metre scale)
//   * The family albedo stays the authority for the mean colour: the photo is
//     divided by its own mean (tex_mean) and re-tinted, so palettes still work
//   * Anti-tiling: macro brightness/hue drift plus a distance blend to a
//     4x lower-frequency sample of the same set
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

// Photo PBR set (MaterialLib.TEXTURES): albedo, GL normal, R=AO G=rough B=height
uniform sampler2D detail_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tex_mean = vec3(0.2);          // linear mean of detail_tex (sets.json)
uniform float tex_rough_mean = 0.7;         // mean of the roughness channel
uniform float tex_scale = 0.5;              // repeats per metre
uniform float tex_strength : hint_range(0.0, 1.0) = 0.0;   // 0 = legacy flat look
uniform float tex_tint : hint_range(0.0, 1.0) = 1.0;       // 1 = mean pulled to albedo
uniform float tex_contrast = 1.0;           // detail contrast around the mean
uniform int uv_mode = 0;                    // 0 object triplanar, 1 mesh UV in metres
uniform float board_tone = 1.0;
// wind sway for trees and hedges (Forest hero meshes): object-space bend that
// grows with height squared; RIME freezes it
uniform float wind_sway = 0.0;              // metres of tip travel
uniform float wind_height = 12.0;           // height the full sway is reached at             // uv mode: ProcMesh UV2.x per-board tone (0 for imported meshes)
uniform int use_local_triplanar = 0; // 1 = lock triplanar to mesh/limb space (characters)
// RIME snow: the snow set, sampled top-down
uniform sampler2D snow_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D snow_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 snow_mean = vec3(0.7);
uniform float snow_scale = 0.35;

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

// Transformation wave globals, frost/melt look (set by StateDirector)
#include "res://shaders/wavefront.gdshaderinc"

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;
varying vec4 v_col;
varying vec3 v_obj_pos;   // world metres in the object's own (rotated) frame
varying vec3 v_obj_nrm;
varying vec3 v_ax_x;      // the object's rotation, to bring normals back to world
varying vec3 v_ax_y;
varying vec3 v_ax_z;

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

void vertex() {
	if (wind_sway > 0.0) {
		vec3 org = MODEL_MATRIX[3].xyz;
		float hgt = clamp(VERTEX.y / wind_height, 0.0, 1.4);
		float ph = dot(org.xz, vec2(0.13, 0.17));
		float g = sin(TIME * 0.8 + ph) * 0.6 + sin(TIME * 2.1 + ph * 1.7 + VERTEX.y * 0.3) * 0.25;
		float frozen = 1.0 - 0.85 * local_rime(org);
		vec3 wdir = (inverse(MODEL_MATRIX) * vec4(0.8, 0.0, -0.6, 0.0)).xyz;
		VERTEX += normalize(wdir) * g * wind_sway * hgt * hgt * frozen;
	}
	v_local_pos = VERTEX;
	v_local_nrm = normalize(NORMAL);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
	// object-aligned, world-scaled frame: textures turn with a rotated house
	// or a scattered rock, keep their metre scale under instance scaling, and
	// stay continuous across abutting pieces that share a rotation
	v_ax_x = normalize(MODEL_MATRIX[0].xyz);
	v_ax_y = normalize(MODEL_MATRIX[1].xyz);
	v_ax_z = normalize(MODEL_MATRIX[2].xyz);
	mat3 rt = transpose(mat3(v_ax_x, v_ax_y, v_ax_z));
	v_obj_pos = rt * v_world_pos;
	v_obj_nrm = rt * v_world_nrm;
}

// one projected sample of the set (albedo, AO/rough/height, normal xy)
struct TexS {
	vec3 alb;
	vec3 orh;
	vec2 nxy;
};

TexS tex_at(vec2 uv) {
	TexS t;
	t.alb = texture(detail_tex, uv).rgb;
	t.orh = texture(orm_tex, uv).rgb;
	t.nxy = texture(normal_tex, uv).rg * 2.0 - 1.0;
	return t;
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
		diss_n = wf_presence_noise(v_world_pos, v_world_nrm);
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
	// (with a photo set bound, base is replaced below; the noise only shades
	// families that have no set: emissive trims, cloud banks, bone)
	if (albedo_from_vc == 1) {
		base = v_col.rgb * (0.85 + 0.3 * n1);
	}

	// ---- photo PBR set ------------------------------------------------------
	float cav_ao = 1.0;
	float rough_mod = 0.5;
	float metal_mask = 1.0;
	float h_field = 0.5;
	vec3 world_nrm = normalize(v_world_nrm);
	float cam_d = distance(CAMERA_POSITION_WORLD, v_world_pos);

	if (tex_strength > 0.001) {
		vec3 alb = vec3(0.0);
		vec3 orh = vec3(1.0, tex_rough_mean, 0.5);
		vec3 far_alb = vec3(0.0);
		float far_w = smoothstep(14.0, 48.0, cam_d);
		if (uv_mode == 1 && use_local_triplanar == 0) {
			// ProcMesh metre UVs: grain runs along each board
			vec2 uv = UV * tex_scale;
			TexS t = tex_at(uv);
			alb = t.alb;
			orh = t.orh;
			if (far_w > 0.001) {
				far_alb = texture(detail_tex, uv * 0.25 + 0.37).rgb;
			}
			vec2 nxy = t.nxy * normal_scale * tex_strength * (1.0 - far_w * 0.6);
			vec3 nv = normalize(TANGENT * nxy.x + BINORMAL * nxy.y + NORMAL);
			world_nrm = normalize((INV_VIEW_MATRIX * vec4(nv, 0.0)).xyz);
		} else {
			vec3 tp_pos = (use_local_triplanar == 1) ? (v_local_pos * 1.8) : v_obj_pos;
			vec3 tp_nrm = normalize((use_local_triplanar == 1) ? v_local_nrm : v_obj_nrm);
			vec3 an = max(abs(tp_nrm) - 0.2, vec3(0.0001));
			vec3 tw = pow(an, vec3(4.0));
			tw /= (tw.x + tw.y + tw.z);
			vec2 uv_x = tp_pos.zy * tex_scale * vec2(sign(tp_nrm.x), 1.0);
			vec2 uv_y = tp_pos.xz * tex_scale + 0.31;
			vec2 uv_z = tp_pos.xy * tex_scale * vec2(-sign(tp_nrm.z), 1.0) + 0.57;
			vec2 nx = vec2(0.0);
			vec2 ny = vec2(0.0);
			vec2 nz = vec2(0.0);
			alb = vec3(0.0);
			orh = vec3(0.0);
			if (tw.x > 0.01) {
				TexS t = tex_at(uv_x);
				alb += t.alb * tw.x; orh += t.orh * tw.x; nx = t.nxy;
				if (far_w > 0.001) { far_alb += texture(detail_tex, uv_x * 0.25 + 0.37).rgb * tw.x; }
			}
			if (tw.y > 0.01) {
				TexS t = tex_at(uv_y);
				alb += t.alb * tw.y; orh += t.orh * tw.y; ny = t.nxy;
				if (far_w > 0.001) { far_alb += texture(detail_tex, uv_y * 0.25 + 0.37).rgb * tw.y; }
			}
			if (tw.z > 0.01) {
				TexS t = tex_at(uv_z);
				alb += t.alb * tw.z; orh += t.orh * tw.z; nz = t.nxy;
				if (far_w > 0.001) { far_alb += texture(detail_tex, uv_z * 0.25 + 0.37).rgb * tw.z; }
			}
			float ns = normal_scale * tex_strength * (1.0 - far_w * 0.6);
			nx *= ns; ny *= ns; nz *= ns;
			// whiteout-style: each plane's tangent offsets in the frame's axes
			vec3 pert = vec3(0.0, nx.y, nx.x * sign(tp_nrm.x)) * tw.x
					+ vec3(ny.x, 0.0, ny.y) * tw.y
					+ vec3(-nz.x * sign(tp_nrm.z), nz.y, 0.0) * tw.z;
			vec3 n_obj = normalize(tp_nrm + pert);
			if (use_local_triplanar == 1) {
				world_nrm = normalize((MODEL_MATRIX * vec4(n_obj, 0.0)).xyz);
			} else {
				world_nrm = normalize(v_ax_x * n_obj.x + v_ax_y * n_obj.y + v_ax_z * n_obj.z);
			}
		}
		if (far_w > 0.001) {
			alb = mix(alb, mix(alb, far_alb, 0.5), far_w);
		}
		// the photo divided by its own mean and re-tinted by the family albedo
		vec3 rel = alb / max(tex_mean, vec3(0.002));
		rel = mix(vec3(1.0), rel, tex_contrast);
		vec3 tint = mix(tex_mean, albedo.rgb, tex_tint);
		// macro drift: big soft patches of lighter/darker, warmer/cooler stuff
		vec3 drift = vec3(1.0) + (n_macro - 0.5) * vec3(0.26, 0.22, 0.18) + (vnoise(v_world_pos * 0.07 + 5.0) - 0.5) * vec3(-0.06, 0.0, 0.08);
		vec3 textured = tint * rel * drift;
		if (uv_mode == 1 && use_local_triplanar == 0) {
			// ProcMesh UV2.x: each board / stone its own tone and weathering
			float bt = UV2.x;
			textured *= mix(vec3(1.0), mix(vec3(0.84, 0.86, 0.9), vec3(1.12, 1.08, 1.02), bt), board_tone);
		}
		base = mix(base, textured, tex_strength);
		cav_ao = mix(1.0, orh.r, tex_strength);
		rough_mod = clamp(0.5 + (orh.g - tex_rough_mean), 0.0, 1.0);
		h_field = orh.b;
		metal_mask = 1.0 - clamp((orh.g - tex_rough_mean) * 2.0, 0.0, 0.6);
	}

	// Micro-grain surface normal perturbation for un-textured or weathered stone
	vec3 micro_n = vec3(n2 - 0.5, fract(n1 + n2) - 0.5, n1 - 0.5) * 0.16 * detail_strength * (1.0 - tex_strength);
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
		float top = smoothstep(0.45, 0.8, world_nrm.y + (n1 - 0.5) * 0.35 + (0.5 - h_field) * 0.35 * tex_strength);
		vec2 suv = v_world_pos.xz * snow_scale;
		vec3 snow_ph = texture(snow_tex, suv).rgb / max(snow_mean, vec3(0.01));
		vec3 snow_c = vec3(0.86, 0.90, 0.96) * mix(vec3(0.94 + 0.06 * n1), snow_ph, 0.8);
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

	// the wavefront: hoarfrost growing / meltwater darkening
	vec4 wf = wf_eval(v_world_pos, world_nrm);
	final_albedo = wf_albedo(final_albedo, wf);

	ALBEDO = final_albedo;

	// Physically-Based Metallic, Specular & Roughness
	float met = clamp(metallic_v * mix(0.72, 1.15, metal_mask) * (1.0 - moss * 0.85), 0.0, 1.0);
	METALLIC = met;

	float rgh = roughness_v + (rough_mod - 0.5) * 0.40 + rime * 0.02 - edge_chip * 0.16 + moss * 0.22 - arch_grime * 0.12;
	rgh = mix(rgh, 0.88, horiz_ledge * 0.5);
	rgh = mix(rgh, 0.08, puddle * 0.88); // wet puddles gleam under moonlight & torchlight
	rgh = wf_roughness(rgh, wf);
	ROUGHNESS = clamp(rgh, 0.05, 1.0);

	float spec = specular_v * mix(0.42, 1.22, cav_ao) * (1.0 - horiz_ledge * 0.45) + puddle * 0.42;
	SPECULAR = clamp(wf_specular(spec, wf), 0.05, 1.0);

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

	// The wavefront: a pale frost line / a warm melt bloom, and the edge of
	// state-only meshes growing in as lace or melting away
	emis += wf_emission(wf);
	if (state_mode != 0 && presence < 0.999 && presence > 0.001) {
		emis += wf_presence_edge(1.0 - smoothstep(0.0, 0.12, presence - diss_n));
	}
	if (death_diss > 0.001) {
		float dn2 = hash13(floor(v_world_pos * 16.0));
		emis += vec3(0.65, 0.78, 1.25) * (1.0 - smoothstep(0.0, 0.2, dn2 - death_diss)) * 2.4;
	}

	EMISSION = emis;
}
