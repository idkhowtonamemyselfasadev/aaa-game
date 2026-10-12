shader_type spatial;
#include "res://shaders/wet.gdshaderinc"
// The hero's body: the imported model's albedo + normal maps (as its StandardMaterial3D drew
// them), plus rain soaking the suit (wet.gdshaderinc, driven by world/soak.gd).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo_col : source_color = vec4(1.0);
uniform float roughness = 1.0;
uniform float normal_depth = 1.0;

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

void fragment() {
	vec3 alb = texture(albedo_tex, UV).rgb * albedo_col.rgb;
	float rough = roughness;
	float patch_n = h_noise(UV * 22.0) * 0.6 + h_noise(UV * 61.0) * 0.4;
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, patch_n), 0.85);
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}
