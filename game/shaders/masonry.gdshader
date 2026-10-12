shader_type spatial;
render_mode cull_back;
// Weathered cut stone for the watchtower ruin. World-space noise (no UVs): a buff-grey
// sandstone with bedding laminae, tooling grain and pits in the normal; worn pale arrises
// (the rounded bevels, found from the object-space normal), dark rain streaks running down
// the faces, lichen rosettes, moss on the tops and in the lower courses, damp at the foot.
// INSTANCE_CUSTOM: r = block's height above the ground / 8 m, g = per-block random.

#include "res://shaders/weather.gdshaderinc"
uniform vec3 stone_a : source_color = vec3(0.66, 0.6, 0.5);
uniform vec3 stone_b : source_color = vec3(0.48, 0.45, 0.4);
// sun- and sky-light thrown back by the meadow and the sunlit walls (World._apply_bounce;
// zero when SDFGI runs). Ambient-like, so it fills the shade instead of going black.
global uniform vec3 bounce_light;
#include "res://shaders/bounce.gdshaderinc"
uniform vec3 moss_a : source_color = vec3(0.3, 0.34, 0.12);
uniform vec3 moss_b : source_color = vec3(0.4, 0.41, 0.16);
uniform vec3 lichen_y : source_color = vec3(0.62, 0.56, 0.32);
uniform vec3 lichen_g : source_color = vec3(0.55, 0.57, 0.5);

varying vec3 wp;
varying vec3 wn;
varying float edge;
varying float above;
varying float tint;
varying float v_cloud;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = p * 2.07 + 5.3; a *= 0.5; } return r; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 an = abs(normalize(NORMAL));
	edge = 1.0 - smoothstep(0.86, 0.98, max(an.x, max(an.y, an.z)));
	above = INSTANCE_CUSTOM.r * 8.0;
	tint = INSTANCE_CUSTOM.g;
	v_cloud = cloud_shade_at(wp);
}

float surf(vec3 p) {
	float lam = sin(p.y * 38.0 + fbm(p * vec3(2.0, 0.6, 2.0)) * 6.0) * 0.5 + 0.5;   // bedding
	float pit = smoothstep(0.7, 0.8, vn(p * 70.0));
	return fbm(p * 9.0) * 0.5 + lam * 0.18 - pit * 0.2 + vn(p * 60.0) * 0.12;
}

void fragment() {
	vec3 n = normalize(wn);
	float s = surf(wp);
	float e = 0.006;
	vec3 g = vec3(surf(wp + vec3(e, 0, 0)) - s, surf(wp + vec3(0, e, 0)) - s, surf(wp + vec3(0, 0, e)) - s) / e;
	// stone: each block its own shade, mottled
	vec3 base = mix(stone_b, stone_a, 0.15 + tint * 0.8);
	// weathering crust: broad darker/greyer patches across a face, pale where it flaked off
	float crust = fbm(wp * 2.3 + tint * 13.0);
	base *= 0.8 + 0.35 * smoothstep(0.25, 0.75, crust);
	base = mix(base, vec3(dot(base, vec3(0.33))) * 0.8, smoothstep(0.55, 0.8, fbm(wp * 1.1 + 31.0)) * 0.5);
	base *= vec3(1.0, 0.98, 0.95) + vec3(0.04, 0.0, -0.04) * (tint - 0.5);
	vec3 col = base * (0.9 + s * 0.2);
	// worn arrises: paler, rubbed smooth
	col = mix(col, base * 1.12 + 0.02, edge * 0.35);
	// rain streaks down the vertical faces (long in y, narrow across)
	float side = 1.0 - smoothstep(0.3, 0.7, abs(n.y));
	float streak = smoothstep(0.55, 0.85, fbm(vec3(wp.x * 7.0, wp.y * 0.35, wp.z * 7.0) + 3.0));
	col *= 1.0 - streak * side * 0.4;
	// lichen rosettes: yellow and grey-green crusts
	float l1 = smoothstep(0.7, 0.76, fbm(wp * 4.0 + 21.0));
	float l2 = smoothstep(0.68, 0.74, fbm(wp * 3.2 + 47.0));
	col = mix(col, lichen_y * (0.8 + 0.4 * vn(wp * 40.0)), l1 * 0.75);
	col = mix(col, lichen_g * (0.8 + 0.4 * vn(wp * 35.0)), l2 * 0.6);
	// moss: on the tops, creeping down the lower courses and the shady joints
	float low = 1.0 - smoothstep(0.0, 2.5, above);
	float mossw = smoothstep(0.55, 0.9, n.y + (fbm(wp * 1.6) - 0.5) * 1.5) * 0.9
	            + low * smoothstep(0.55, 0.75, fbm(wp * 2.2 + 5.0)) * (1.0 - edge * 0.5);
	mossw = clamp(mossw, 0.0, 1.0);
	vec3 mc = mix(moss_a, moss_b, fbm(wp * 7.0));
	col = mix(col, mc, mossw);
	col *= mix(0.72, 1.0, smoothstep(0.0, 1.2, above));       // damp lower courses
	float rough = mix(0.82, 0.95, mossw) - edge * 0.08;
	weather_wetten(col, rough, mix(0.4, 1.0, mossw));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	vec3 pn = normalize(n - (g - n * dot(g, n)) * mix(0.02, 0.006, mossw));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = clamp(0.65 + s * 0.5, 0.0, 1.0);
	ALBEDO *= v_cloud;
	// bounce: strongest on faces turned sideways/down toward the lit ground, weak on tops
	// (they see the sky, which the ambient already covers); joints and pits get less
	float facing = mix(1.0, 0.5, clamp(n.y, 0.0, 1.0));
	// inside the keep the floor stones and rubble tops face the lit inner wall
	facing *= mix(1.0, bounce_gain(wp), clamp(n.y, 0.0, 1.0));
	EMISSION = ALBEDO * bounce_light * facing * AO;
}
