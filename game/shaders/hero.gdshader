shader_type spatial;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// The hero's body: the imported model's albedo + normal maps (as its StandardMaterial3D drew
// them), plus rain soaking the suit (wet.gdshaderinc, driven by world/soak.gd).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform float normal_depth = 1.0;
// 1: the Vanguard's sci-fi look is re-dressed as old lamellar: the tan plastic plates become
// worn black lacquered leather (scratches through to brown hide), the red stripes a dull
// cinnabar lacquer, the blue-grey fittings and helmet mask blackened iron, and the glossy visor
// glass a matte indigo face cloth.
uniform float restyle = 1.0;
// an oxblood-umber lacquer, not black: at 0.082/0.054/0.041 the 2 m `herocu` lens read the
// whole torso as one dull near-black mass against the sunlit meadow
uniform vec3 lacquer : source_color = vec3(0.125, 0.062, 0.042);
uniform vec3 hide : source_color = vec3(0.28, 0.17, 0.088);
uniform vec3 cinnabar : source_color = vec3(0.34, 0.06, 0.036);
uniform vec3 face_cloth : source_color = vec3(0.028, 0.030, 0.042);
// 1: a wearer with no armour (Hesper): the plates become layered undyed wool, the iron
// fittings (knee caps, bracers, collar) old linen bindings, the red stripes a faded russet
// patch -- matte cloth, no metal, so a crouched figure reads as one soft bundle of cloth
uniform float cloth_body = 0.0;
uniform vec3 wool : source_color = vec3(0.30, 0.29, 0.27);
uniform vec3 linen : source_color = vec3(0.44, 0.41, 0.35);
uniform vec3 patch_col : source_color = vec3(0.20, 0.12, 0.08);
// (cloth_body) the dark undersuit between the plates (legs, waist, inner arms): hose and
// breeches of the same wool, a few shades darker -- left as the raw near-black suit it read
// as black plate greaves and cuisses on every villager's legs
uniform float hose_shade = 0.55;
// (cloth_body) the plate bevels in the normal map kept this much: at full depth the knee
// cops and pauldron rims caught the sun like hard shells under the wool
uniform float cloth_normal = 0.3;
// (cloth_body) how far (m) the plates and iron fittings sink in along their normals, so a
// villager's knee cops, pauldron humps and boot cuffs stop standing proud of the body like
// armour under the wool; iron (knee caps, collar, bracers) sinks this much more again
uniform float plate_inset = 0.0;
uniform float iron_inset = 0.0;
// villagers' bare fingers: the base body's finger vertices carry COLOR.g 0 (Villager._hand_marked);
// without the mask (the hero, the keeper) COLOR is white and nothing changes
uniform float bare_hands = 0.0;
uniform vec3 hand_skin : source_color = vec3(0.30, 0.225, 0.19);
varying float v_finger;

float h_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float h_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h_hash(i), h_hash(i + vec2(1, 0)), f.x),
			   mix(h_hash(i + vec2(0, 1)), h_hash(i + vec2(1, 1)), f.x), f.y);
}

// The masks are set on the texture's linear values (x albedo_col 0.8): the tan plates sit at
// ~(0.46, 0.27, 0.145), lum ~0.31; the red stripes ~(0.19, 0.0, 0.0); the blue-grey fittings
// ~(0.05, 0.07, 0.07), lum 0.04-0.08; the dark chips and cloth below lum 0.05. (Thresholds set
// as if sRGB left the plates half converted -- lacquer over raw tan read pale brown-grey -- and
// never caught the stripes or the fittings, which stayed raw red and pale blue.)
float tan_of(vec3 c) {
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float warm = c.r - c.b;
	return smoothstep(0.1, 0.2, warm) * smoothstep(0.12, 0.22, lum)
			* (1.0 - smoothstep(0.3, 0.4, c.r - c.g));
}

// the plate/iron masks at vertex rate, on a blurred mip so a plate's shell sinks as one
// smooth piece and its edge tapers into the undersuit instead of tearing at the seam
void vertex() {
	v_finger = bare_hands * (1.0 - COLOR.g);
	if (cloth_body > 0.0 && plate_inset + iron_inset > 0.0) {
		float tan_v = 0.0;
		float iron_v = 0.0;
		for (int i = 0; i < 5; i++) {
			vec2 o = i == 0 ? vec2(0.0) : vec2(cos(float(i) * 1.5708), sin(float(i) * 1.5708)) * 0.006;
			vec3 c = textureLod(albedo_tex, UV + o, 3.0).rgb * albedo_col.rgb;
			float lum = dot(c, vec3(0.3, 0.59, 0.11));
			tan_v += tan_of(c) * 0.2;
			iron_v += smoothstep(0.008, 0.02, c.b - c.r) * smoothstep(0.025, 0.05, lum) * 0.2;
		}
		VERTEX -= NORMAL * cloth_body * (plate_inset * clamp(tan_v + iron_v, 0.0, 1.0) + iron_inset * iron_v);
	}
}

void fragment() {
	vec3 alb = texture(albedo_tex, UV).rgb * albedo_col.rgb;
	float rough = roughness;
	float metal = 0.0;
	float plate_spec = 0.0;
	float patch_n = h_noise(UV * 22.0) * 0.6 + h_noise(UV * 61.0) * 0.4;
	if (restyle > 0.0) {
		vec3 src = alb;
		float lum = dot(src, vec3(0.3, 0.59, 0.11));
		float warm = src.r - src.b;
		// tan plates: bright and warm; their painted chips are dark brown
		float tan_m = tan_of(src);
		float red_m = smoothstep(0.08, 0.14, src.r - src.g) * (1.0 - smoothstep(0.05, 0.1, src.g));
		float iron_m = smoothstep(0.008, 0.02, src.b - src.r) * smoothstep(0.025, 0.05, lum);
		// the chips sit inside the plates: a texel is plate if any tan lies within ~6 texels
		// (so a chip and its anti-aliased border both count, never the raw tan in between),
		// and a chip only where no tan lies within ~1.5 texels (thins the painted chips)
		vec2 tx = 1.0 / vec2(textureSize(albedo_tex, 0));
		float near = tan_m;
		float region = tan_m;
		float mid[8];
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 d = vec2(cos(a), sin(a)) * tx;
			near = max(near, tan_of(texture(albedo_tex, UV + d * 1.5).rgb * albedo_col.rgb));
			region = max(region, tan_of(texture(albedo_tex, UV + d * 6.0).rgb * albedo_col.rgb));
			mid[i] = tan_of(texture(albedo_tex, UV + d * 3.5).rgb * albedo_col.rgb);
		}
		// a chip has plate on both sides along some axis; the dark ring round a plate's outer
		// edge has plate on one side only and stays lacquer (else every plate wore a hide outline)
		float inside = 0.0;
		for (int i = 0; i < 4; i++) {
			inside = max(inside, min(mid[i], mid[i + 4]));
		}
		region *= 1.0 - red_m;
		plate_spec = region * restyle * (1.0 - cloth_body);
		// a few chips never went through the lacquer: the rest are worn down to dark hide
		float scratch = region * inside * (1.0 - near) * smoothstep(0.2, 0.45, h_noise(UV * 160.0 + 3.0));
		// raised rims and bevels (where the normal map tilts hard) are rubbed thin and polished
		vec2 nxy = texture(normal_tex, UV).xy * 2.0 - 1.0;
		float bevel = smoothstep(0.22, 0.5, length(nxy)) * region * (1.0 - scratch);
		bevel *= smoothstep(0.3, 0.7, h_noise(UV * 70.0 + 11.0)) * 0.8 + 0.2;
		// lacquer: near black, faintly mottled, a little rubbed through on raised wear
		float mott = h_noise(UV * 140.0) * 0.5 + h_noise(UV * 37.0) * 0.5;
		vec3 lac = lacquer * (0.8 + 0.45 * mott);
		lac = mix(lac, hide * 0.6, smoothstep(0.72, 0.9, h_noise(UV * 90.0 + 7.0)) * 0.5);
		// rubbed rims a step lighter than the field, so each plate's shape reads at range (at
		// 0.034 lacquer and 0.55 rub the torso read as one flat black mass at noon)
		lac = mix(lac, hide * 0.48, bevel * 0.7);
		// plate separation: the dark ring round each plate's outer edge (plate on one side
		// only) and the soft border of the grooves between sub-plates go a deep crease, and
		// the texture's baked shading on the plates carries into the lacquer -- with a flat
		// field and the grooves worn to (lighter) hide, the plates merged into one mass at 6-8 m
		float crease = clamp(region * (1.0 - tan_m) * (1.0 - inside)
				+ region * inside * clamp(near - tan_m, 0.0, 1.0), 0.0, 1.0);
		lac *= mix(1.0, pow(clamp(lum / 0.31, 0.55, 1.12), 1.5), tan_m);
		lac *= 1.0 - 0.55 * crease;
		scratch *= 1.0 - crease;
		vec3 o = src;
		float r_o = roughness;
		o = mix(o, lac, region);
		// satin, not gloss: glossy black mirrors the noon sky and reads pale grey, its bevels
		// glinting like painted outlines; rubbed rims go matter still. At 0.6 the field was
		// so matte that the plates' curvature caught no sky and the torso read as one black
		// mass at 6-8 m: a little more sheen on the field, the rims kept matte
		r_o = mix(r_o, 0.46 + 0.12 * mott + 0.26 * bevel, region);
		o = mix(o, hide * (0.32 + 0.22 * mott), scratch);
		r_o = mix(r_o, 0.8, scratch);
		o = mix(o, cinnabar * (0.75 + 0.4 * mott), red_m);
		r_o = mix(r_o, 0.45, red_m);
		vec3 iron = vec3(0.075, 0.072, 0.07) * (0.7 + 0.6 * mott) + vec3(0.06, 0.035, 0.02) * smoothstep(0.6, 0.85, mott);
		o = mix(o, iron, iron_m);
		r_o = mix(r_o, 0.55 + 0.25 * mott, iron_m);
		metal = 0.7 * iron_m;
		if (cloth_body > 0.0) {
			// woven texture: a fine twill and slubs so the plates read as cloth, not paint
			float tw = 0.5 + 0.5 * sin((UV.x + UV.y) * 1400.0);
			float slub = h_noise(UV * vec2(300.0, 40.0));
			// the plate mottle kept low: at 0.22 the sleeves read as pale camouflage blotches
			vec3 w = wool * (0.86 + 0.14 * tw + 0.09 * mott) * mix(0.9, 1.06, slub);
			vec3 ln = linen * (0.8 + 0.25 * h_noise(UV * vec2(25.0, 420.0)) + 0.1 * tw);
			// the bindings follow the fittings' blurred outline: the texel-sharp iron mask
			// left ragged pale blotches on the forearms and shins (grey camouflage at 1.5 m)
			vec3 sb = textureLod(albedo_tex, UV, 3.0).rgb * albedo_col.rgb;
			float iron_b = smoothstep(0.006, 0.022, sb.b - sb.r)
					* smoothstep(0.022, 0.05, dot(sb, vec3(0.3, 0.59, 0.11)));
			iron_m = mix(iron_m, iron_b, cloth_body);
			vec3 cl = mix(w, ln, iron_m);
			cl = mix(cl, patch_col * (0.8 + 0.4 * mott), red_m * 0.7);
			cl = mix(cl, w * 0.75, scratch * 0.5);
			float body_m = clamp(region + iron_m + red_m, 0.0, 1.0);
			// the undersuit: the same twill a few shades down, with the suit's own baked
			// folds kept faintly so the hose still wrinkle at the knee
			vec3 hs = wool * hose_shade * (0.86 + 0.14 * tw + 0.08 * mott) * mix(0.92, 1.05, slub);
			hs *= mix(0.85, 1.1, clamp(lum / 0.05, 0.0, 1.0));
			cl = mix(hs, cl, body_m);
			o = mix(o, cl, cloth_body);
			r_o = mix(r_o, 0.93, cloth_body);
			metal *= 1.0 - cloth_body;
		}
		// the visor glass (its own UV island, top left): a matte wound face cloth
		vec2 vq = (UV - vec2(0.093, 0.215)) / vec2(0.085, 0.07);
		float visor = 1.0 - smoothstep(0.85, 1.05, length(vq));
		float bands = 0.5 + 0.5 * sin((UV.y * 0.6 + UV.x * 0.15) * 900.0);
		vec3 fc = face_cloth * (0.75 + 0.35 * bands + 0.3 * h_noise(UV * 400.0));
		o = mix(o, fc, visor);
		r_o = mix(r_o, 0.95, visor);
		metal *= 1.0 - visor;
		alb = mix(src, o, restyle);
		rough = mix(roughness, r_o, restyle);
	}
	if (v_finger > 0.001) {
		// work-worn skin: ruddier at the knuckles and tips (the glove's baked shading picks
		// them out), a little grime in the creases; satin, not wool-matte
		float glum = dot(texture(albedo_tex, UV).rgb * albedo_col.rgb, vec3(0.3, 0.59, 0.11));
		float fold = clamp(glum / 0.08, 0.6, 1.15);
		vec3 sk = hand_skin * (0.9 + 0.2 * h_noise(UV * 180.0)) * fold;
		sk = mix(sk, sk * vec3(1.12, 0.92, 0.88), smoothstep(0.4, 0.8, h_noise(UV * 55.0 + 5.0)) * 0.6);
		alb = mix(alb, sk, v_finger);
		rough = mix(rough, 0.62, v_finger);
		metal *= 1.0 - v_finger;
	}
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, patch_n), 0.85);
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5 - 0.1 * plate_spec;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth * mix(1.0, cloth_normal, cloth_body * restyle);
	// meadow bounce into the shaded side, and the sun wrapping the silhouette in back light
	EMISSION = figure_fill(alb, wet_n, wet_p);
	RIM = 0.15;
	RIM_TINT = 0.55;
}
