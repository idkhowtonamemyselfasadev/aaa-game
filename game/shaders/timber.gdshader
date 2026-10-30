shader_type spatial;
render_mode cull_back;
// Weathered oak for the cottage timbers (lintels, door, frames, shutters, eaves boards).
// Object-space noise in metres (each piece has its own unscaled mesh, grain along its
// local Y): silvered grey on the weather faces with brown heartwood in the checks, open
// splits along the grain, darker end grain, a dark tarred finish where `tar` is set (door,
// shutters), wet darkening.
// INSTANCE_CUSTOM is unused; per-piece variation comes from `seed`.
// `lichen` (0..1) crusts an old field post: pale grey-green crottle rosettes all over and
// a moss film on the face toward `weather_dir` (world) and up from the turf at `foot_y`
// (the mesh's local height of the ground).

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform vec3 oak_silver : source_color = vec3(0.47, 0.44, 0.4);
uniform vec3 oak_brown : source_color = vec3(0.3, 0.22, 0.15);
uniform vec3 oak_dark : source_color = vec3(0.13, 0.1, 0.08);
uniform vec3 tar_col : source_color = vec3(0.1, 0.085, 0.07);
uniform float tar = 0.0;
uniform float seed = 0.0;
uniform float lichen = 0.0;
uniform vec3 weather_dir = vec3(0.8, 0.0, 0.6);
uniform float foot_y = -100.0;
uniform vec3 lichen_col : source_color = vec3(0.5, 0.52, 0.42);
uniform vec3 moss_col : source_color = vec3(0.16, 0.2, 0.07);

varying vec3 op;
varying vec3 onrm;
varying vec3 wn;
varying vec3 wp;
varying float v_cloud;
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
	op = VERTEX + vec3(seed * 3.1, seed * 7.7, seed * 1.3);
	onrm = NORMAL;
	ly = VERTEX.y;
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
	if (lichen > 0.0) {
		// moss: a soft film on the weather face and the bottom 25 cm, broken by the grain
		float wface = clamp(dot(wn.xz, normalize(weather_dir.xz)), 0.0, 1.0);
		float low = smoothstep(0.32, 0.0, ly - foot_y);
		float m = smoothstep(0.6, 0.85, max(wface * 0.7, low) + fbm(op * vec3(9.0, 3.0, 9.0)) * 0.6 - 0.3 + g * 0.4) * lichen;
		col = mix(col, moss_col * mix(0.7, 1.2, vn(op * 40.0)), m);
		// crottle: round crusted rosettes with pale rims, on the grey wood only
		float r = fbm(op * vec3(55.0, 30.0, 55.0)) + (fbm(op * vec3(6.0, 2.0, 6.0)) - 0.5) * 0.35;
		float crust = smoothstep(0.66, 0.69, r) * lichen * (1.0 - m * 0.8) * 0.85;
		col = mix(col, lichen_col * mix(0.75, 1.1, vn(op * 160.0)) * (1.0 - smoothstep(0.71, 0.75, r) * 0.3), crust);
		rough = mix(rough, 0.95, max(m, crust));
	}
	weather_wetten(col, rough, 0.8);
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	// silvered oak is matte: 0.35 caught the blue sky and gave the post a cool cast in shade
	SPECULAR = 0.25;
	vec3 n = normalize(wn);
	float e = 0.003;
	vec3 gg = vec3(grain(op + vec3(e, 0, 0)) - g, grain(op + vec3(0, e, 0)) - g, grain(op + vec3(0, 0, e)) - g) / e;
	vec3 gw = (MODEL_MATRIX * vec4(gg, 0.0)).xyz;
	vec3 pn = normalize(n - (gw - n * dot(gw, n)) * 0.0014);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = 1.0 - smoothstep(-0.1, -0.5, g) * 0.4;
	// the face turned from the sun sees the bright sky dome and the lit meadow (as masonry and
	// rock): the fell bell's post in the great stone's noon shade went blue-black without it
	vec3 sl = normalize(cloud_sun);
	float away = clamp(-dot(vec3(n.x, 0.0, n.z), normalize(vec3(sl.x, 0.0, sl.z) + 1e-4)), 0.0, 1.0)
			* smoothstep(-0.05, 0.15, sl.y);
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.5, clamp(n.y, 0.0, 1.0)) * (1.0 + 0.9 * away) * AO;
}
