shader_type spatial;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// Hollow skin: the body's own albedo/normal detail turned to grey, cracked ash-stone, with
// ember light leaking from the fissures — brightest in the chest, where the Ember's grief
// burns. `ember` flares during a wind-up (the tell), `hit_flash` pulses on a hit, and
// `dissolve` crumbles the body to ash on death.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 ash_dark : source_color = vec3(0.105, 0.10, 0.095);
uniform vec3 ash_light : source_color = vec3(0.47, 0.45, 0.42);
uniform vec3 ember_col : source_color = vec3(1.0, 0.36, 0.08);
uniform float ember = 1.0;
uniform float hit_flash = 0.0;
uniform float dissolve = 0.0;
uniform vec3 root_pos;            // world position of the feet
uniform vec3 root_fwd = vec3(0.0, 0.0, 1.0);

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + 17.13));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

// distance to the nearest Voronoi cell border: the fissure network
float fissure(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 mr;
	float md = 8.0;
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 r = g + hash2(i + g) - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; }
	}
	md = 8.0;
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec2 g = vec2(float(x), float(y));
		vec2 r = g + hash2(i + g) - f;
		if (dot(mr - r, mr - r) > 1e-5)
			md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
	}
	return md;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 src = texture(albedo_tex, UV).rgb;
	float lum = dot(src, vec3(0.3, 0.59, 0.11));
	float n = fbm(UV * 38.0);
	float grime = fbm(UV * 7.0 + 3.1);
	// warp the fissure field so it reads as cracking stone, not a tiling pattern
	vec2 cuv = UV * 44.0 + vec2(fbm(UV * 9.0), fbm(UV * 9.0 + 5.2)) * 1.6;
	float e = fissure(cuv);
	float wide = fissure(UV * 14.0 + 11.0);
	float crack = 1.0 - smoothstep(0.008, 0.035, e);
	float crack_big = (1.0 - smoothstep(0.01, 0.045, wide)) * smoothstep(0.45, 0.7, fbm(UV * 5.0 + 7.7));
	// chest: a band at sternum height on the front of the torso
	vec3 rel = wpos - root_pos;
	float h = rel.y;
	vec2 flat_rel = rel.xz;
	float front = dot(normalize(flat_rel + root_fwd.xz * 0.001), root_fwd.xz);
	float torso = 1.0 - smoothstep(0.16, 0.30, length(flat_rel));
	float chest = exp(-pow((h - 1.30) / 0.17, 2.0)) * torso * smoothstep(-0.2, 0.6, front);
	vec3 alb = mix(ash_dark, ash_light, clamp(lum * 1.35 * (0.65 + 0.7 * n), 0.0, 1.0));
	alb *= mix(0.75, 1.05, grime);
	// scorched soot around the fissures and the chest
	float soot = max(crack_big * 0.5, chest * 0.5) + crack * 0.3;
	alb = mix(alb, vec3(0.05, 0.045, 0.04), clamp(soot, 0.0, 0.85));
	float fis = max(crack, crack_big * 0.85);
	// the limbs only smoulder; the ember's light pours out of the chest, and the tell
	// (ember > 1) mostly brightens the chest
	float body_glow = fis * 0.035 * (0.6 + 0.4 * ember) * crack_big;
	float chest_glow = fis * chest * 1.2 * ember + chest * 0.18 * ember * smoothstep(0.45, 0.9, n);
	float glow = body_glow + chest_glow + fis * hit_flash * 0.6;
	// ash flakes: a dissolve front that eats the body from the noise field, edges burning
	if (dissolve > 0.0) {
		float d = fbm(UV * 21.0) * 0.8 + 0.2 * (1.0 - clamp(h / 1.8, 0.0, 1.0));
		if (d < dissolve) discard;
		glow += (1.0 - smoothstep(0.0, 0.06, d - dissolve)) * 2.5;
	}
	float rough = mix(0.82, 0.95, n) - crack * 0.1;
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, grime), 1.0);
	ALBEDO = alb * (1.0 - clamp(glow, 0.0, 1.0) * 0.6);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 1.4;
	AO = 1.0 - fis * 0.5;
	AO_LIGHT_AFFECT = 0.4;
	EMISSION = ember_col * glow * 3.2 + vec3(1.0, 0.75, 0.45) * pow(clamp(glow, 0.0, 4.0), 3.0) * 0.08
			+ figure_fill(ALBEDO, wet_n, wet_p) * AO;
	// ash dust on the skin catches the sun round the silhouette
	RIM = 0.15;
	RIM_TINT = 0.5;
}
