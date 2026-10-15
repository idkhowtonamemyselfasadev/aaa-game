shader_type spatial;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// Hero staff: COLOR.r picks the layer (0 lacquered wood, 0.5 worn bronze, 1 cloth wrap).
// UV.x = around the shaft (0..1), UV.y = metres along it. All detail is procedural.

uniform vec3 lacquer : source_color = vec3(0.30, 0.075, 0.045);
uniform vec3 wood_under : source_color = vec3(0.42, 0.24, 0.13);
uniform vec3 bronze : source_color = vec3(0.86, 0.66, 0.34);
uniform vec3 tarnish : source_color = vec3(0.30, 0.25, 0.15);
uniform vec3 cloth : source_color = vec3(0.46, 0.38, 0.27);
uniform vec3 cloth_stain : source_color = vec3(0.20, 0.15, 0.10);

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
	// around-coordinate scaled to metres (circumference ~0.14 m) so noise is isotropic;
	// wrap seam is hidden by tiling the around axis on a whole number of cells
	float around = UV.x;
	float along = UV.y;
	vec3 alb;
	float rough;
	float metal;
	float bump = 0.0;
	if (layer < 0.25) {
		// lacquered wood: long grain streaks, lacquer worn through to the wood where hands go
		float grain = fbm(vec2(around * 24.0, along * 1.6)) * 0.6 + vnoise(vec2(around * 90.0, along * 3.0)) * 0.4;
		float wear = smoothstep(0.55, 0.8, fbm(vec2(around * 8.0, along * 7.0)) + 0.25 * (1.0 - abs(along - 0.93) * 1.6));
		alb = lacquer * (0.75 + 0.5 * grain);
		alb = mix(alb, wood_under * (0.7 + 0.5 * grain), wear * 0.6);
		rough = mix(0.22, 0.55, wear) + 0.08 * grain;
		metal = 0.0;
		bump = grain * 0.15;
	} else if (layer < 0.75) {
		// worn bronze: tarnish settles in pits, high spots polished bright
		float pits = fbm(vec2(around * 30.0, along * 140.0));
		float tar = smoothstep(0.38, 0.72, fbm(vec2(around * 10.0, along * 40.0)) + pits * 0.3);
		alb = mix(bronze, tarnish, tar * 0.75);
		rough = mix(0.25, 0.65, tar) + pits * 0.1;
		metal = mix(1.0, 0.55, tar);
		bump = pits * 0.4;
	} else {
		// cloth wrap: diagonal overlapping bands of coarse weave, darker at the overlaps
		float wrap = fract(along * 32.0 + around * 1.0);
		float edge = smoothstep(0.0, 0.12, wrap) * smoothstep(1.0, 0.82, wrap);
		float weave = vnoise(vec2(around * 380.0, along * 700.0)) * 0.5
				+ 0.5 * (sin(around * 600.0) * sin(along * 1300.0) * 0.5 + 0.5);
		float dirt = fbm(vec2(around * 6.0, along * 9.0));
		alb = mix(cloth_stain, cloth, edge * 0.8 + 0.2) * (0.8 + 0.35 * weave);
		alb = mix(alb, cloth_stain, smoothstep(0.5, 0.8, dirt) * 0.5);
		rough = 0.92;
		metal = 0.0;
		bump = edge * 0.6 + weave * 0.25;
	}
	// rain: the cloth grip and bare wood soak, the lacquer and bronze only bead a film
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float porous = layer > 0.75 ? 1.0 : (layer < 0.25 ? 0.6 : 0.0);
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, vnoise(vec2(around * 9.0, along * 5.0))), porous);
	ALBEDO = alb;
	EMISSION += figure_fill(alb, wet_n, wet_p);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = metal;
	SPECULAR = 0.5;
	// perturb the normal from the bump field's screen-space derivatives
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float bx = dFdx(bump);
	float by = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (bx * r1 + by * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.0025);
}
