shader_type spatial;
render_mode cull_disabled;
// Osric's bellwether's bell and its collar (world/fell_bell.gd). `part` 0 = cast bronze,
// years out on the fell: a dull brown-olive patina, verdigris crusted in the mouth and on
// the shoulders where rain stands, the lip and the clapper's strike line worn back to warm
// metal; 1 = the collar, a strap of leather gone black and cracked, curling at a torn end.
// Object-space noise in metres; per-piece variation from `seed`.

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform float part = 0.0;
uniform float seed = 0.0;

varying vec3 op;
varying vec3 onrm;
varying vec3 wn;
varying vec3 wp;
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
	op = VERTEX + vec3(seed * 3.1, seed * 7.7, seed * 1.3);
	onrm = NORMAL;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_cloud = cloud_shade_at(wp);
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 col;
	float rough;
	float metal = 0.0;
	float h;
	if (part < 0.5) {
		// UV.y runs 0 at the lip .. 1 at the crown; UV.x = 1 on the inside of the mouth
		float inside = UV.x;
		float r = fbm(op * 140.0);
		vec3 patina = mix(vec3(0.19, 0.15, 0.085), vec3(0.12, 0.105, 0.065), r);
		// verdigris: crusted in the mouth, blooming on the upper faces where wet stands
		float vg = smoothstep(0.45, 0.75, fbm(op * 90.0 + 2.0) + inside * 0.35);
		vg = max(vg, smoothstep(0.3, 0.9, n.y) * smoothstep(0.5, 0.7, fbm(op * 220.0 + 9.0)) * 0.8);
		col = mix(patina, vec3(0.2, 0.33, 0.26), vg * 0.85);
		// the lip and the strike line inside it worn back to warm bronze
		float worn = smoothstep(0.08, 0.0, UV.y) * (1.0 - inside * 0.6);
		worn = max(worn, smoothstep(0.03, 0.0, abs(UV.y - 0.16)) * inside);
		worn *= smoothstep(0.35, 0.6, fbm(op * 400.0 + 4.0) + 0.2);
		col = mix(col, vec3(0.55, 0.36, 0.17), worn);
		metal = mix(mix(0.55, 0.05, vg), 0.95, worn);
		rough = mix(mix(0.62, 0.92, vg), 0.38, worn);
		h = vg * 0.6 + fbm(op * 600.0) * 0.3 * (1.0 - worn);
		weather_wetten(col, rough, 0.3);
	} else {
		// UV.x along the strap, UV.y across it
		float g = fbm(vec3(UV.x * 40.0, UV.y * 8.0, seed));
		col = mix(vec3(0.045, 0.032, 0.024), vec3(0.085, 0.06, 0.04), g);
		// cracks across the grain where the strap was bent round the post
		float cr = smoothstep(0.82, 0.95, vn(vec3(UV.x * 220.0, UV.y * 4.0, seed)));
		col *= 1.0 - cr * 0.6;
		// the edges gone grey and furred
		float edge = smoothstep(0.3, 0.5, abs(UV.y - 0.5));
		col = mix(col, vec3(0.11, 0.1, 0.085), edge * 0.5);
		rough = mix(0.62, 0.9, max(edge, cr));
		h = g * 0.4 - cr * 0.5;
		weather_wetten(col, rough, 0.4);
	}
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.45;
	vec3 dpdx = dFdx(wp);
	vec3 dpdy = dFdy(wp);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	vec3 pn = normalize(abs(det) * n - grad * 0.004);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.5, clamp(n.y, 0.0, 1.0));
}
