shader_type spatial;
render_mode cull_back;
// The white cottage's water butt: an old oak cask cut down under the eaves drip.
// One lathed mesh (world/water_butt.gd): UV.x runs round the cask (0..1, STAVES staves),
// UV.y up it (0 foot .. 1 rim); COLOR.r = 1 on the inside of the staves and the rim top.
// `part` 0 = the staves (silvered oak, dark seams, green algae and a wet tide line at the
// foot, rust runs under each hoop, a darker wet band where it overflows), 1 = the iron
// hoops (black iron rusted through in patches). `brim` 0..1 is the water level (wet inside
// below it); `spill` 0..1 how much it is running over the rim.

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform float part = 0.0;
uniform float staves = 18.0;
uniform float brim = 0.7;
uniform float spill = 0.0;
uniform float seed = 0.0;
uniform vec4 hoops = vec4(0.1, 0.32, 0.68, 0.9);   // hoop heights (UV.y)

varying vec3 op;
varying vec3 wn;
varying vec3 wp;
varying float v_in;
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
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_in = COLOR.r;
	v_cloud = cloud_shade_at(wp);
}

// oak grain height along a stave: long streaks up the cask, warped, with checks
float grain(vec3 p, float st) {
	vec3 q = p + vec3(st * 1.7, st * 0.37, st * 2.3);
	float w = fbm(q * vec3(3.0, 0.5, 3.0)) * 0.8;
	float streak = sin((q.x * 60.0 + q.z * 70.0) + w * 9.0) * 0.5 + 0.5;
	float check = smoothstep(0.03, 0.0, abs(fbm(q * vec3(16.0, 0.8, 16.0)) - 0.5)) * smoothstep(0.5, 0.65, fbm(q * vec3(2.0, 0.4, 2.0)));
	return streak * 0.35 + fbm(q * vec3(40.0, 3.0, 40.0)) * 0.4 - check * 0.5;
}

void fragment() {
	float u = UV.x * staves;
	float st = floor(u);
	float fu = fract(u);
	float y = UV.y;
	vec3 col;
	float rough;
	float metal = 0.0;
	float h = 0.0;
	float ao = 1.0;
	if (part < 0.5) {
		float g = grain(op, st);
		h = g;
		// each stave cut from a different board: its own tone
		float tone = hash3(vec3(st, seed, 3.0));
		vec3 silver = mix(vec3(0.27, 0.25, 0.22), vec3(0.34, 0.31, 0.27), tone);
		vec3 brown = mix(vec3(0.16, 0.11, 0.07), vec3(0.22, 0.15, 0.09), tone);
		col = mix(brown, silver, smoothstep(0.2, 0.7, g + fbm(op * vec3(2.0, 0.3, 2.0)) * 0.3));
		col = mix(col, vec3(0.1, 0.08, 0.06), smoothstep(0.0, -0.4, g));
		// the seams between staves: dark, a little open toward the dry top
		float seam = 1.0 - smoothstep(0.0, 0.05, min(fu, 1.0 - fu));
		col *= 1.0 - seam * 0.8;
		h -= seam * 0.6;
		ao -= seam * 0.4;
		rough = 0.85;
		if (v_in < 0.5) {
			// rust runs bleeding down under each hoop
			float hs[4] = float[](hoops.x, hoops.y, hoops.z, hoops.w);
			for (int k = 0; k < 4; k++) {
				float hy = hs[k];
				float below = hy - y;
				float run = smoothstep(0.0, 0.01, below) * (1.0 - smoothstep(0.0, 0.12 + 0.1 * vn(vec3(UV.x * 90.0, hy * 20.0, seed)), below));
				run *= smoothstep(0.45, 0.75, vn(vec3(UV.x * 70.0, hy * 13.0, seed + 2.0)));
				col = mix(col, vec3(0.24, 0.12, 0.06), run * 0.55);
			}
			// green algae and a black wet foot where it stands in the splash
			float foot = 1.0 - smoothstep(0.02, 0.3 + 0.15 * fbm(op * 4.0), y);
			float alg = foot * smoothstep(0.35, 0.65, fbm(op * vec3(9.0, 4.0, 9.0)));
			col = mix(col, col * 0.55, foot * 0.7);
			col = mix(col, vec3(0.11, 0.15, 0.06), alg * 0.75);
			// a water stain line from overflows, and the cask wet down its face when it spills
			float stain = smoothstep(0.55, 0.8, fbm(vec3(UV.x * 30.0, y * 2.0, seed + 5.0))) * smoothstep(0.6, 0.95, y);
			col *= 1.0 - stain * 0.25;
			float runw = spill * smoothstep(0.4, 0.6, fbm(vec3(UV.x * 24.0, y * 1.5 - TIME * 0.05, seed)));
			col *= 1.0 - runw * 0.35;
			rough = mix(rough, 0.25, runw);
		} else {
			// inside: soaked dark oak below the water, a slimy tide band at the waterline
			float under = 1.0 - smoothstep(brim - 0.01, brim + 0.02, y);
			col = mix(col, col * 0.4, under);
			float tide = 1.0 - smoothstep(0.0, 0.06, abs(y - brim - 0.03));
			col = mix(col, vec3(0.1, 0.13, 0.06), tide * 0.6);
			// rim top: end grain, darker
			col *= mix(1.0, 0.75, smoothstep(0.97, 1.0, y));
			rough = mix(rough, 0.4, max(under, tide));
		}
		col *= mix(0.9, 1.08, vn(op * 3.0));
		weather_wetten(col, rough, 0.8);
	} else {
		// iron hoop: black scale rusted through in blooms, the top edge rustiest (water sits there)
		float r = fbm(op * vec3(14.0, 30.0, 14.0));
		float bloom = smoothstep(0.5, 0.78, r + fbm(op * 50.0) * 0.25);
		col = mix(vec3(0.05, 0.045, 0.04), vec3(0.17, 0.09, 0.045), bloom);
		col = mix(col, vec3(0.26, 0.12, 0.05), smoothstep(0.75, 0.95, r) * 0.6);
		metal = mix(0.6, 0.0, bloom);
		rough = mix(0.55, 0.92, bloom);
		h = bloom * 0.4 + fbm(op * 80.0) * 0.2;
		weather_wetten(col, rough, 0.2);
	}
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.4;
	AO = ao;
	vec3 n = normalize(wn);
	// bump from the grain via screen derivatives
	vec3 dpdx = dFdx(wp);
	vec3 dpdy = dFdy(wp);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	vec3 nb = normalize(abs(det) * n - grad * 0.6);
	NORMAL = normalize((VIEW_MATRIX * vec4(nb, 0.0)).xyz);
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.5, clamp(n.y, 0.0, 1.0)) * AO;
}
