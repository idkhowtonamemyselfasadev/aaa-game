shader_type spatial;
render_mode cull_back;
// Weathered oak for the cottage timbers (lintels, door, frames, shutters, eaves boards).
// Object-space noise in metres (each piece has its own unscaled mesh, grain along its
// local Y): silvered grey on the weather faces with brown heartwood in the checks, open
// splits along the grain, darker end grain, a dark tarred finish where `tar` is set (door,
// shutters), wet darkening.
// INSTANCE_CUSTOM is unused; per-piece variation comes from `seed`.

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform vec3 oak_silver : source_color = vec3(0.47, 0.44, 0.4);
uniform vec3 oak_brown : source_color = vec3(0.3, 0.22, 0.15);
uniform vec3 oak_dark : source_color = vec3(0.13, 0.1, 0.08);
uniform vec3 tar_col : source_color = vec3(0.1, 0.085, 0.07);
uniform float tar = 0.0;
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

// grain height: long streaks along Y, warped, with checks (deep splits)
float grain(vec3 p) {
	vec3 q = p * vec3(1.0, 0.08, 1.0);
	float w = fbm(p * vec3(3.0, 0.4, 3.0)) * 0.8;
	float rings = sin((q.x * 70.0 + q.z * 55.0) + w * 9.0) * 0.5 + 0.5;
	float check = smoothstep(0.03, 0.0, abs(fbm(p * vec3(14.0, 0.7, 14.0)) - 0.5)) * smoothstep(0.45, 0.6, fbm(p * vec3(2.0, 0.3, 2.0)));
	return rings * 0.35 + fbm(p * vec3(40.0, 2.0, 40.0)) * 0.4 - check * 0.5;
}

void fragment() {
	float end_face = smoothstep(0.7, 0.9, abs(normalize(onrm).y));
	float g = grain(op);
	vec3 col = mix(oak_brown, oak_silver, smoothstep(0.1, 0.55, g + fbm(op * vec3(2.0, 0.25, 2.0)) * 0.3));
	col = mix(col, oak_dark, smoothstep(0.0, -0.4, g));
	col = mix(col, oak_dark * 1.3, end_face * 0.7);
	// tarred: dark film worn back to grey on the high grain and at the arrises
	float wear = smoothstep(0.55, 0.85, fbm(op * vec3(6.0, 1.2, 6.0)) + g * 0.3);
	col = mix(col, mix(tar_col, col * 0.7, wear), tar);
	col *= mix(0.9, 1.08, vn(op * 3.0));
	float rough = mix(0.86, 0.6, tar * (1.0 - wear));
	weather_wetten(col, rough, 0.8);
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	vec3 n = normalize(wn);
	float e = 0.003;
	vec3 gg = vec3(grain(op + vec3(e, 0, 0)) - g, grain(op + vec3(0, e, 0)) - g, grain(op + vec3(0, 0, e)) - g) / e;
	vec3 gw = (MODEL_MATRIX * vec4(gg, 0.0)).xyz;
	vec3 pn = normalize(n - (gw - n * dot(gw, n)) * 0.0014);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = 1.0 - smoothstep(-0.1, -0.5, g) * 0.4;
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.5, clamp(n.y, 0.0, 1.0)) * AO;
}
