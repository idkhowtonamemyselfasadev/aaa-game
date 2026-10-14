shader_type spatial;
render_mode cull_back;
// Weathered cut stone for the watchtower ruin. World-space noise (no UVs): a buff-grey
// sandstone with bedding laminae, tooling grain and pits in the normal; worn pale arrises
// (the rounded bevels, found from the object-space normal), dark rain streaks running down
// the faces, lichen rosettes, moss on the tops and in the lower courses, damp at the foot.
// Each stone is one of a few beds of the quarry: warm buff, ochre, rust-stained, pale
// near-white or dark grey, with iron-stain blooms. The joints sink into shadow and grime
// (COLOR.r: 0 on the end/bed faces, 1 at 15 cm in from those arrises), and the low joints
// hold soil and moss.
// INSTANCE_CUSTOM: r = block's height above the ground / 8 m, g = per-block random,
// b = 1 for a stone laid in a wall course (0 for fallen blocks and rubble).

#include "res://shaders/weather.gdshaderinc"
uniform vec3 stone_a : source_color = vec3(0.7, 0.62, 0.5);
uniform vec3 stone_b : source_color = vec3(0.52, 0.47, 0.39);
uniform vec3 stone_ochre : source_color = vec3(0.64, 0.54, 0.4);
uniform vec3 stone_rust : source_color = vec3(0.55, 0.43, 0.34);
uniform vec3 stone_pale : source_color = vec3(0.72, 0.7, 0.64);
uniform vec3 stone_dark : source_color = vec3(0.43, 0.42, 0.39);
uniform vec3 iron_stain : source_color = vec3(0.5, 0.3, 0.16);
uniform vec3 joint_soil : source_color = vec3(0.22, 0.17, 0.12);
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
varying float jnt;
varying float laid;

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
	jnt = COLOR.r;
	laid = INSTANCE_CUSTOM.b;
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
	// its bed in the quarry
	float bed = fract(tint * 91.7);
	vec3 bedc = bed < 0.15 ? stone_ochre : bed < 0.23 ? stone_rust : bed < 0.35 ? stone_pale
	          : bed < 0.47 ? stone_dark : base;
	base = mix(base, bedc * (0.94 + 0.12 * fract(tint * 37.3)), 0.55);
	// iron stain blooming from the joints and through some faces, most on the rusty beds
	float iron = smoothstep(0.6, 0.85, fbm(wp * 3.1 + tint * 7.0) + (1.0 - jnt) * 0.18)
	           * (bed < 0.23 ? 0.7 : 0.3);
	base = mix(base, iron_stain, iron);
	// weathering crust: broad darker/greyer patches across a face, pale where it flaked off
	float crust = fbm(wp * 2.3 + tint * 13.0);
	base *= 0.8 + 0.35 * smoothstep(0.25, 0.75, crust);
	base = mix(base, vec3(dot(base, vec3(0.33))) * 0.8, smoothstep(0.55, 0.8, fbm(wp * 1.1 + 31.0)) * 0.5);
	base *= vec3(1.0, 0.98, 0.95) + vec3(0.04, 0.0, -0.04) * (tint - 0.5);
	vec3 col = base * (0.9 + s * 0.2);
	// worn arrises: paler, rubbed smooth
	// (the top arrises of the laid courses weather dark with the tops, below)
	col = mix(col, base * 1.12 + 0.02, edge * 0.35 * (1.0 - 0.7 * laid * smoothstep(0.2, 0.7, n.y)));
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
	// exposed bed tops of the laid courses: rain-darkened grey crust with soil and moss
	float cap = laid * smoothstep(0.35, 0.8, n.y);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.4, 0.3))) * 0.7, cap * 0.55);
	float mossw = smoothstep(0.55, 0.9, n.y + (fbm(wp * 1.6) - 0.5) * 1.5 + cap * 0.25) * 0.9
	            + low * smoothstep(0.55, 0.75, fbm(wp * 2.2 + 5.0)) * (1.0 - edge * 0.5);
	mossw = clamp(mossw, 0.0, 1.0);
	vec3 mc = mix(moss_a, moss_b, fbm(wp * 7.0));
	col = mix(col, mc, mossw);
	col *= mix(0.72, 1.0, smoothstep(0.0, 1.2, above));       // damp lower courses
	// joints: grime and shade sinking into the gaps between the stones (the end and bed
	// faces only show through the open joints); upward faces (crown tops) stay open to the sky
	float up = smoothstep(0.5, 0.85, n.y);
	float jd = (1.0 - smoothstep(0.0, 0.55, jnt)) * mix(0.3, 1.0, laid) * (1.0 - up * 0.85);
	float deep = (1.0 - smoothstep(0.0, 0.2, jnt)) * mix(0.3, 1.0, laid) * (1.0 - up);
	col *= 1.0 - jd * 0.08 - deep * 0.4;
	// soil and moss lodged in the low joints
	float lowj = deep * (1.0 - smoothstep(0.3, 1.8, above)) * smoothstep(0.35, 0.6, fbm(wp * 5.0 + 11.0));
	col = mix(col, mix(joint_soil, moss_a * 0.8, smoothstep(0.45, 0.7, fbm(wp * 9.0))), lowj * 0.9);
	mossw = max(mossw, lowj * 0.6);
	float rough = mix(0.82, 0.95, mossw) - edge * 0.08;
	weather_wetten(col, rough, mix(0.4, 1.0, mossw));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	vec3 pn = normalize(n - (g - n * dot(g, n)) * mix(0.02, 0.006, mossw));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = clamp(0.65 + s * 0.5, 0.0, 1.0) * (1.0 - jd * 0.3 - deep * 0.3);
	ALBEDO *= v_cloud;
	// bounce: strongest on faces turned sideways/down toward the lit ground, weak on tops
	// (they see the sky, which the ambient already covers); joints and pits get less
	float facing = mix(1.0, 0.5, clamp(n.y, 0.0, 1.0));
	// inside the keep the floor stones and rubble tops face the lit inner wall
	facing *= mix(1.0, bounce_gain(wp), clamp(n.y, 0.0, 1.0));
	EMISSION = ALBEDO * bounce_light * facing * AO;
}
