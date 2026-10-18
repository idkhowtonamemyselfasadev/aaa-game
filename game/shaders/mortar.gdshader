shader_type spatial;
render_mode cull_back;
// Lime mortar in the cottage's joints (world/cottage.gd lays a recessed core behind every
// course run, so the joints read as weathered pointing, not black gaps). World-space
// noise: a buff-grey lime with sand grains, eroded and dirtier toward the foot, green
// algae in the damp low joints, darker when wet.
#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform vec3 lime : source_color = vec3(0.56, 0.53, 0.47);
uniform vec3 grime : source_color = vec3(0.3, 0.28, 0.24);
uniform vec3 algae : source_color = vec3(0.28, 0.31, 0.18);
uniform float ground_y = 0.0;

varying vec3 wp;
varying vec3 wn;
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
	v_cloud = cloud_shade_at(wp);
}

void fragment() {
	float g = fbm(wp * 18.0);
	float sand = vn(wp * 260.0);
	float low = 1.0 - smoothstep(0.0, 1.2, wp.y - ground_y);
	vec3 col = lime * mix(0.82, 1.05, g) * mix(0.9, 1.06, sand);
	col = mix(col, grime, clamp(low * 0.55 + smoothstep(0.55, 0.8, fbm(wp * vec3(4.0, 1.0, 4.0))) * 0.35, 0.0, 1.0));
	col = mix(col, algae, low * smoothstep(0.45, 0.65, fbm(wp * 7.0 + 3.0)) * 0.7);
	float rough = 0.95;
	weather_wetten(col, rough, 0.9);
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	AO = mix(0.55, 0.8, g);
	EMISSION = ALBEDO * bounce_light * 0.6 * AO;
}
