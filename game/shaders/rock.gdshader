shader_type spatial;
render_mode cull_back;
// Mossy boulders. World-space 3D noise (no triplanar seams): strata bands, cracks and
// pitting in the normal, lichen spots, and moss on up-facing surfaces whose edge breaks
// up with noise; a dark damp band where the stone meets the ground.

#include "res://shaders/weather.gdshaderinc"
uniform vec3 stone_a : source_color = vec3(0.36, 0.35, 0.33);
uniform vec3 stone_b : source_color = vec3(0.19, 0.19, 0.2);
uniform vec3 moss_a : source_color = vec3(0.16, 0.2, 0.05);
uniform vec3 moss_b : source_color = vec3(0.3, 0.3, 0.1);
uniform vec3 lichen : source_color = vec3(0.55, 0.52, 0.38);

varying vec3 wp;
varying vec3 wn;
varying float ly;

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
	ly = VERTEX.y;
}

float surf(vec3 p) {
	float strata = sin(p.y * 7.0 + fbm(p * 1.5) * 4.0) * 0.5 + 0.5;
	float crack = 1.0 - smoothstep(0.0, 0.05, abs(fbm(p * 2.2) - 0.5));
	return fbm(p * 5.0) * 0.6 + strata * 0.25 - crack * 0.5;
}

void fragment() {
	vec3 n = normalize(wn);
	float s = surf(wp);
	float e = 0.02;
	vec3 g = vec3(surf(wp + vec3(e, 0, 0)) - s, surf(wp + vec3(0, e, 0)) - s, surf(wp + vec3(0, 0, e)) - s) / e;
	vec3 col = mix(stone_b, stone_a, smoothstep(0.15, 0.75, s + fbm(wp * 0.7) * 0.3));
	float li = smoothstep(0.72, 0.8, fbm(wp * 3.0 + 11.0));
	col = mix(col, lichen, li * 0.6);
	float mossw = smoothstep(0.35, 0.75, n.y + (fbm(wp * 1.3) - 0.5) * 0.9);
	vec3 mc = mix(moss_a, moss_b, fbm(wp * 6.0));
	col = mix(col, mc, mossw);
	col *= mix(0.55, 1.0, smoothstep(-0.35, 0.0, ly));    // damp foot
	float rough = mix(0.78, 0.95, mossw);
	weather_wetten(col, rough, mix(0.3, 1.0, mossw));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	// perturb the world normal with the detail gradient (less under the moss)
	vec3 pn = normalize(n - (g - n * dot(g, n)) * mix(0.05, 0.015, mossw));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = clamp(0.6 + s * 0.6, 0.0, 1.0);
}
