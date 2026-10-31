shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// The Ashen Knight's armour: COLOR.r picks the layer (0 fire-blackened plate steel, 0.5 dark
// oiled leather strapping, 1 forged rivets). Plate: near-black heat-scaled steel, its ridges
// and edges rubbed back to bare grey metal, rust blooming in the low spots, soot over all,
// and a faint ember glow in the cracks that rises with `ember` (the knight's phase).
// COLOR.g = 0..1 edge factor (1 on a rim/ridge: worn bright). Pattern space: object metres.

uniform vec3 steel_dark : source_color = vec3(0.045, 0.043, 0.042);
uniform vec3 steel_bare : source_color = vec3(0.42, 0.41, 0.40);
uniform vec3 rust : source_color = vec3(0.24, 0.09, 0.035);
uniform vec3 leather : source_color = vec3(0.09, 0.055, 0.035);
uniform vec3 ember_col : source_color = vec3(1.0, 0.32, 0.06);
uniform float ember = 0.0;      // the body's ember (HollowSoldier, pulses with its tells)
uniform float heat = 0.0;       // the knight's phase: 0, 0.5, 1
uniform float dissolve = 0.0;   // crumbles with the body on death
uniform float hit_flash = 0.0;

varying float layer;
varying float edge;
varying vec3 opos;

float hash(vec3 p) {
	p = fract(p * vec3(123.34, 456.21, 789.53));
	p += dot(p, p.yzx + 45.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	layer = COLOR.r;
	edge = COLOR.g;
	opos = VERTEX;
}

void fragment() {
	vec3 alb;
	float rough;
	float metal;
	float bump;
	vec3 glow = vec3(0.0);
	if (layer < 0.25) {
		float pits = fbm(opos * 70.0);
		float scale = fbm(opos * 9.0 + 3.1);
		float wear = smoothstep(0.35, 0.95, edge + (pits - 0.5) * 0.6);
		float r = smoothstep(0.55, 0.8, fbm(opos * 14.0 + 7.7) + pits * 0.25) * (1.0 - wear);
		float dent = smoothstep(0.7, 0.9, vnoise(opos * 22.0));
		// heat scale: blue-black to a bruised brown where the fire bit hardest
		vec3 scaled = mix(steel_dark, vec3(0.075, 0.058, 0.05), scale);
		alb = mix(scaled * (0.8 + 0.4 * pits), steel_bare * (0.75 + 0.35 * pits), wear);
		alb = mix(alb, rust * (0.7 + 0.6 * pits), r);
		rough = mix(mix(0.62, 0.32, wear), 0.92, r);
		metal = mix(0.85, 0.15, r);
		bump = pits * 0.35 - dent * 0.6 + r * 0.25;
		// hairline cracks in the blackened plate show the ember behind
		float crack = 1.0 - smoothstep(0.0, 0.035, abs(fbm(opos * 6.0 + 11.0) - 0.5));
		crack *= smoothstep(0.45, 0.6, vnoise(opos * 4.0));
		glow = ember_col * crack * (0.15 + ember * 0.6) * (0.25 + heat) * 2.4;
		alb *= 1.0 - crack * 0.5;
	} else if (layer < 0.75) {
		float grain = fbm(opos * 120.0);
		float scuff = smoothstep(0.6, 0.85, fbm(opos * 18.0));
		alb = leather * (0.7 + 0.5 * grain) + vec3(0.05, 0.04, 0.03) * scuff;
		rough = mix(0.55, 0.8, scuff);
		metal = 0.0;
		bump = grain * 0.4;
	} else {
		float pits = fbm(opos * 160.0);
		alb = mix(steel_bare * 0.7, rust * 0.8, smoothstep(0.4, 0.7, pits));
		rough = 0.45;
		metal = 0.8;
		bump = pits;
	}
	if (dissolve > 0.0) {
		float d = fbm(opos * 5.0 + 1.7);
		if (d < dissolve) discard;
		glow += ember_col * (1.0 - smoothstep(0.0, 0.06, d - dissolve)) * 2.5;
	}
	glow += vec3(1.0, 0.75, 0.5) * hit_flash * 0.6;
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, vnoise(opos * 9.0)), 1.0 - metal);
	ALBEDO = alb;
	EMISSION += figure_fill(alb, wet_n, wet_p) + glow;
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
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.0025);
}
