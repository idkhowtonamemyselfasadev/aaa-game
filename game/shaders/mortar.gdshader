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
// 1: the white cottage -- the same world-space limewash as masonry.gdshader's a = 4, so the
// coats run unbroken over stones and joints alike
uniform float wash = 0.0;
uniform vec3 limewash : source_color = vec3(0.74, 0.725, 0.67);
uniform vec3 lime_algae : source_color = vec3(0.3, 0.34, 0.2);

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
	// limewash (matches masonry.gdshader's a = 4 pattern; no flaking -- the joint behind is lime too)
	float ab = wp.y - ground_y;
	float coat = fbm(wp * 2.6 + 7.0);
	vec3 lwc = limewash * (0.9 + 0.12 * coat) * (0.97 + 0.05 * vn(wp * 90.0));
	lwc = mix(lwc, lwc * vec3(0.97, 0.97, 0.93), smoothstep(0.4, 0.8, fbm(wp * 0.7 + 3.0)));
	float side = 1.0 - smoothstep(0.3, 0.7, abs(normalize(wn).y));
	float runs = smoothstep(0.5, 0.82, fbm(vec3(wp.x * 6.0, wp.y * 0.22, wp.z * 6.0) + 9.0)) * side;
	lwc *= 1.0 - runs * (0.08 + 0.14 * smoothstep(1.2, 2.6, ab));
	float splash = 1.0 - smoothstep(0.0, 0.45 + 0.35 * fbm(wp * vec3(2.5, 0.4, 2.5) + 1.0), ab);
	vec3 grimec = mix(vec3(0.36, 0.34, 0.29), lime_algae, smoothstep(0.4, 0.65, fbm(wp * 4.0 + 2.0)));
	lwc = mix(lwc, grimec * (0.85 + 0.3 * coat), splash * 0.8);
	// on the white cottage the lime core stands a hair proud of the stone faces, so it IS the
	// wall's skin over the sunk stones: the same small flaked patches as masonry a = 4 (the
	// rubble showing grey through), and a soft trowelled undulation instead of a flat plane
	float fn = fbm(wp * 3.4 + 13.0) + (1.0 - smoothstep(0.0, 1.2, ab)) * 0.12 - smoothstep(1.0, 2.2, ab) * 0.06;
	float flake = smoothstep(0.71, 0.735, fn) * wash;
	float rim = smoothstep(0.69, 0.71, fn) * (1.0 - flake) * wash;
	vec3 under = vec3(0.45, 0.43, 0.39) * (0.85 + 0.3 * vn(wp * 30.0));
	lwc = mix(lwc * (1.0 - rim * 0.18), under, flake);
	col = mix(col, lwc, wash);
	float bump = fbm(wp * 6.0 + 4.0);
	vec3 e = vec3(0.01, 0.0, 0.0);
	vec3 gb = vec3(fbm((wp + e.xyy) * 6.0 + 4.0), fbm((wp + e.yxy) * 6.0 + 4.0), fbm((wp + e.yyx) * 6.0 + 4.0)) - bump;
	gb /= 0.01;
	vec3 nn = normalize(wn);
	vec3 pn = normalize(nn - (gb - nn * dot(gb, nn)) * 0.012 * wash);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	float rough = 0.95;
	weather_wetten(col, rough, 0.9);
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	AO = mix(mix(0.55, 0.8, g), 0.92, wash);
	EMISSION = ALBEDO * bounce_light * mix(0.6, 1.0, wash) * AO;
}
