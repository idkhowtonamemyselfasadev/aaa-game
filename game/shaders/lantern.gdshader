shader_type spatial;
render_mode cull_disabled;
// The lantern post's ironwork (world/lantern_post.gd): `part` 0 = black wrought iron
// (forge scale gone to rust in blooms, rust collecting on the upper faces where rain sits,
// soot over the cap and chimney, worn bright on the carrying ring); 1 = the tallow candle
// (creamy, translucent near the flame so it glows when `lit`).
// Object-space noise in metres; per-piece variation from `seed`.

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform float part = 0.0;
uniform float seed = 0.0;
uniform float lit = 0.0;

varying vec3 op;
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
	vec3 emit = vec3(0.0);
	if (part < 0.5) {
		float r = fbm(op * 60.0);
		float bloom = smoothstep(0.52, 0.78, r + fbm(op * 180.0) * 0.25);
		// rain sits on the upper faces: rust collects there
		bloom = max(bloom, smoothstep(0.4, 0.95, n.y) * smoothstep(0.35, 0.6, fbm(op * 90.0 + 3.0)));
		col = mix(vec3(0.042, 0.039, 0.036), vec3(0.16, 0.085, 0.045), bloom);
		col = mix(col, vec3(0.25, 0.115, 0.05), smoothstep(0.78, 0.95, r) * 0.6);
		// soot: the cap and chimney blackened from the flame below (lantern space is the
		// pivot's; its upper part is y > -0.32 in object space after the seed offset)
		float soot = smoothstep(0.5, 0.75, fbm(op * 40.0 + 7.0)) * 0.5;
		col *= 1.0 - soot * 0.4;
		metal = mix(0.65, 0.0, bloom);
		rough = mix(0.5, 0.9, bloom);
		h = bloom * 0.5 + fbm(op * 300.0) * 0.25;
		weather_wetten(col, rough, 0.2);
	} else {
		// tallow: creamy, a little dirty at the foot, glowing through near the flame
		col = mix(vec3(0.62, 0.55, 0.42), vec3(0.75, 0.69, 0.56), fbm(op * 80.0));
		rough = 0.55;
		h = fbm(op * 200.0) * 0.3;
		emit = vec3(1.0, 0.55, 0.22) * lit * 0.9;
	}
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.45;
	// bump from the noise via screen derivatives
	vec3 dpdx = dFdx(wp);
	vec3 dpdy = dFdy(wp);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	vec3 pn = normalize(abs(det) * n - grad * 0.008);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.5, clamp(n.y, 0.0, 1.0)) + emit;
}
