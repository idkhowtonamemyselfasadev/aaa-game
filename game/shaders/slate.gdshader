shader_type spatial;
render_mode cull_back;
// Riven roofing slate for the Harrowmere cottages (world/cottage.gd). World-space noise, no UVs.
// Blue-grey to heather-purple and green-grey slates (one quarry bed per slate), the split
// face rippled along the cleavage with fine grain, the dressed tail edges chipped pale, a
// sheen when wet. Lichen rosettes (sulphur and grey) and moss cushions gather toward the
// eaves and along the tails, where water lingers; soot darkens the slates round the stack.
// INSTANCE_CUSTOM: r = 0 at the ridge .. 1 at the eaves, g = per-slate random,
// b = 1 for ridge stones (no lichen beds), a = distance from the chimney stack (m) / 4.

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform vec3 slate_blue : source_color = vec3(0.2, 0.22, 0.25);
uniform vec3 slate_purple : source_color = vec3(0.25, 0.21, 0.24);
uniform vec3 slate_green : source_color = vec3(0.23, 0.25, 0.23);
uniform vec3 slate_pale : source_color = vec3(0.36, 0.37, 0.38);
uniform vec3 lichen_y : source_color = vec3(0.6, 0.58, 0.44);
uniform vec3 lichen_g : source_color = vec3(0.55, 0.57, 0.52);
uniform vec3 moss : source_color = vec3(0.19, 0.21, 0.13);   // old dark cushion moss, not fresh green

varying vec3 wp;
varying vec3 wn;
varying vec3 lp;
varying float eave;
varying float tint;
varying float ridge;
varying float stack;
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
	lp = VERTEX;
	eave = INSTANCE_CUSTOM.r;
	tint = INSTANCE_CUSTOM.g;
	ridge = INSTANCE_CUSTOM.b;
	stack = INSTANCE_CUSTOM.a * 4.0;
	v_cloud = cloud_shade_at(wp);
}

float riven(vec3 p) {
	// the split face: broad undulations across the slate plus fine cleavage steps
	float u = fbm(p * vec3(3.0, 1.0, 3.0) + tint * 40.0);
	float steps = smoothstep(0.45, 0.55, fract(fbm(p * 2.2 + 3.0) * 5.0)) * 0.25;
	return u * 0.7 + steps + vn(p * 90.0) * 0.03;
}

void fragment() {
	vec3 n = normalize(wn);
	// per-slate quarry colour
	vec3 col = slate_blue;
	col = mix(col, slate_purple, smoothstep(0.55, 0.8, tint));
	col = mix(col, slate_green, smoothstep(0.3, 0.05, tint));
	col *= mix(0.85, 1.12, fract(tint * 7.31));
	float s = riven(wp);
	col *= mix(0.88, 1.08, s);
	// edges: the slate's sides (object-space normal mostly sideways) are dressed, paler and
	// rougher; the face near the tail edge is chipped
	vec3 on = abs(normalize((inverse(MODEL_MATRIX) * vec4(wn, 0.0)).xyz));
	float side = 1.0 - smoothstep(0.5, 0.8, on.y);
	col = mix(col, slate_pale, side * 0.35);
	// rain streaks down the slope and white calcite veins in a few slates
	float vein = smoothstep(0.015, 0.0, abs(fbm(wp * vec3(6.0, 2.0, 6.0) + tint * 13.0) - 0.5)) * step(0.82, fract(tint * 3.7));
	col = mix(col, slate_pale * 1.4, vein * 0.5);
	// lichen and moss: toward the eaves, on the exposed tails, off the ridge stones
	float wetzone = eave * (1.0 - ridge);
	// sulphur lichen: few broad soft rosettes (a coarse patch field gates a finer edge)
	float ros = fbm(wp * 2.6 + 21.0) + (fbm(wp * 9.0 + 4.0) - 0.5) * 0.12;
	// (a coarse field over the whole slope breaks up the bands along the slate tails)
	float colony = smoothstep(0.42, 0.62, fbm(wp * 0.7 + 33.0));
	float ly = smoothstep(0.68 - wetzone * 0.1, 0.76 - wetzone * 0.1, ros) * (1.0 - side) * 0.8 * colony;
	float lg = smoothstep(0.64, 0.69, fbm(wp * 11.0 + 7.0)) * (1.0 - side) * mix(0.4, 1.0, wetzone);
	col = mix(col, lichen_g, lg * 0.7);
	col = mix(col, lichen_y * mix(0.9, 1.02, vn(wp * 14.0)), ly * 0.75);
	float mz = smoothstep(0.62, 0.72, fbm(wp * 4.0 + 50.0) + wetzone * 0.18 - 0.06) * smoothstep(0.55, 1.0, eave) * (1.0 - ridge);
	col = mix(col, moss * mix(0.7, 1.1, vn(wp * 30.0)), mz * 0.85);
	// soot round the chimney stack, mostly downwind and above
	float soot = (1.0 - smoothstep(0.4, 1.8, stack)) * 0.55;
	col *= 1.0 - soot;
	float rough = mix(0.7, 0.9, side) + ly * 0.2 + mz * 0.3 + soot * 0.2;
	rough = min(rough, 0.97);
	weather_wetten(col, rough, mix(0.15, 0.9, max(mz, ly)));
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	// normal: the riven relief
	float e = 0.004;
	vec3 g = vec3(riven(wp + vec3(e, 0, 0)) - s, riven(wp + vec3(0, e, 0)) - s, riven(wp + vec3(0, 0, e)) - s) / e;
	vec3 pn = normalize(n - (g - n * dot(g, n)) * mix(0.0022, 0.001, mz));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = mix(1.0, 0.75, side);
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.4, clamp(n.y, 0.0, 1.0)) * AO;
}
