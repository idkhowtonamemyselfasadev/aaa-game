shader_type spatial;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// Hollow soldier's spear: COLOR.r picks the layer (0 grey weathered ash-wood, 0.5 pitted,
// rusted iron, 1 tarred cord binding). UV.x = around (0..1), UV.y = metres along.

uniform vec3 wood_a : source_color = vec3(0.34, 0.31, 0.27);
uniform vec3 wood_b : source_color = vec3(0.17, 0.15, 0.13);
uniform vec3 iron : source_color = vec3(0.30, 0.30, 0.31);
uniform vec3 rust : source_color = vec3(0.32, 0.14, 0.06);
uniform vec3 cord : source_color = vec3(0.16, 0.10, 0.07);

varying float layer;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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

void vertex() {
	layer = COLOR.r;
}

void fragment() {
	float around = UV.x;
	float along = UV.y;
	vec3 alb;
	float rough;
	float metal;
	float bump;
	if (layer < 0.25) {
		// silvered, checked ash-wood: long grain, dark splits, grime toward the grip
		float grain = fbm(vec2(around * 26.0, along * 1.4)) * 0.6 + vnoise(vec2(around * 110.0, along * 2.5)) * 0.4;
		float split = smoothstep(0.86, 0.95, vnoise(vec2(around * 40.0, along * 0.9)));
		alb = mix(wood_b, wood_a, grain);
		alb = mix(alb, wood_b * 0.4, split);
		alb *= mix(0.65, 1.0, smoothstep(0.3, 0.9, abs(along - 0.75)));
		rough = 0.85;
		metal = 0.0;
		bump = grain * 0.2 - split * 0.5;
	} else if (layer < 0.75) {
		// pitted forged iron: rust blooms in the pits, the edges and high spots worn bright
		float pits = fbm(vec2(around * 40.0, along * 90.0));
		float r = smoothstep(0.42, 0.75, fbm(vec2(around * 9.0, along * 22.0)) + pits * 0.35);
		alb = mix(iron * (0.8 + 0.4 * pits), rust * (0.7 + 0.6 * pits), r);
		rough = mix(0.38, 0.9, r);
		metal = mix(0.9, 0.1, r);
		bump = pits * 0.5 + r * 0.3;
	} else {
		// tarred cord wound in tight turns
		float turn = fract(along * 180.0 + around * 2.0);
		float ridge = sin(turn * 3.14159);
		alb = cord * (0.6 + 0.5 * ridge) * (0.8 + 0.3 * vnoise(vec2(around * 50.0, along * 300.0)));
		rough = 0.7;
		metal = 0.0;
		bump = ridge;
	}
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, vnoise(vec2(around * 9.0, along * 5.0))), 1.0 - metal);
	ALBEDO = alb;
	EMISSION += figure_fill(alb, wet_n, wet_p);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = metal;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float bx = dFdx(bump);
	float by = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (bx * r1 + by * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.002);
}
