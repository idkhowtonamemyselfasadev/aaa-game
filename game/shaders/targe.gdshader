shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// Hollow warden's targe: COLOR.r picks the layer (0 old hide facing, tooled in rings and
// cut by blows, 0.5 pitted rusted iron, 1 bare grey plank back/edge). UV = board xy in metres.

uniform vec3 hide_a : source_color = vec3(0.24, 0.15, 0.09);
uniform vec3 hide_b : source_color = vec3(0.09, 0.055, 0.035);
uniform vec3 wood_a : source_color = vec3(0.34, 0.31, 0.27);
uniform vec3 wood_b : source_color = vec3(0.17, 0.15, 0.13);
uniform vec3 iron : source_color = vec3(0.30, 0.30, 0.31);
uniform vec3 rust : source_color = vec3(0.32, 0.14, 0.06);
uniform float ash = 0.35;       // grey ash caked over the face (the Hollows' burnt skin)
uniform float hit_flash = 0.0;

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
	vec2 p = UV;
	float r = length(p);
	float ang = atan(p.y, p.x);
	vec3 alb;
	float rough;
	float metal;
	float bump;
	if (layer < 0.25) {
		// old hide over the planks: mottled, tooled in two incised rings, scuffed bright on the
		// high dome, cut by straight gashes where blades bit, ash caked into the low places
		float mott = fbm(p * 18.0);
		float pores = vnoise(p * 260.0);
		float tool = 1.0 - smoothstep(0.0, 0.004, abs(r - 0.125)) * 0.8 - smoothstep(0.0, 0.004, abs(r - 0.205)) * 0.8;
		float knot = smoothstep(0.55, 0.0, abs(sin(ang * 8.0 + r * 40.0))) * step(0.13, r) * step(r, 0.2);
		float cut = 0.0;
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			vec2 dir = vec2(cos(fi * 2.4 + 0.7), sin(fi * 2.4 + 0.7));
			vec2 o = vec2(hash(vec2(fi, 3.1)) - 0.5, hash(vec2(fi, 7.7)) - 0.5) * 0.36;
			vec2 q = p - o;
			float along = dot(q, dir);
			float across = abs(dot(q, vec2(-dir.y, dir.x)));
			cut = max(cut, smoothstep(0.0025, 0.0, across) * smoothstep(0.07, 0.03, abs(along)));
		}
		alb = mix(hide_b, hide_a, mott * 0.8 + pores * 0.2);
		alb *= mix(1.0, 0.55, knot * 0.6);
		alb *= mix(0.45, 1.0, tool);
		alb = mix(alb, vec3(0.32, 0.22, 0.15), smoothstep(0.2, 0.0, r) * mott * 0.5);   // worn bright
		float caked = smoothstep(0.45, 0.8, fbm(p * 7.0 + 3.0)) * ash;
		alb = mix(alb, vec3(0.30, 0.29, 0.27), caked);
		alb = mix(alb, hide_b * 0.35, cut);
		rough = mix(0.62, 0.92, caked) + pores * 0.06;
		metal = 0.0;
		bump = mott * 0.25 + pores * 0.15 - (1.0 - tool) * 0.6 - cut * 0.9 - knot * 0.2;
	} else if (layer < 0.75) {
		// pitted forged iron: rust blooms in the pits, the high spots worn bright
		float pits = fbm(p * 90.0);
		float rr = smoothstep(0.42, 0.75, fbm(p * 22.0 + 1.3) + pits * 0.35);
		alb = mix(iron * (0.8 + 0.4 * pits), rust * (0.7 + 0.6 * pits), rr);
		rough = mix(0.36, 0.9, rr);
		metal = mix(0.9, 0.1, rr);
		bump = pits * 0.5 + rr * 0.3;
	} else {
		// grey plank back: vertical boards with dark seams and long grain
		float board = fract(p.x / 0.085);
		float seam = smoothstep(0.04, 0.0, min(board, 1.0 - board));
		float grain = fbm(vec2(p.x * 60.0, p.y * 4.0)) * 0.6 + vnoise(vec2(p.x * 300.0, p.y * 8.0)) * 0.4;
		alb = mix(wood_b, wood_a, grain);
		alb = mix(alb, wood_b * 0.3, seam);
		rough = 0.86;
		metal = 0.0;
		bump = grain * 0.2 - seam * 0.6;
	}
	alb = mix(alb, vec3(0.9, 0.55, 0.3), hit_flash * 0.25);
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, vnoise(p * 30.0)), 1.0 - metal);
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
