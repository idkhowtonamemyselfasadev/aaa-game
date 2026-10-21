shader_type spatial;
render_mode cull_back;
// The hearting of a dry-stone wall (world/dry_wall.gd): the small packing stones rammed
// between the two faces, seen only through the joints. World-space cells of fist-sized
// sandstone chips, each its own shade, with black voids between them; soil washed into the
// low joints and moss creeping in from the foot, so the gaps read as stone, earth and green
// at varying depths instead of one even dark grid.
#include "res://shaders/weather.gdshaderinc"
uniform vec3 chip_a : source_color = vec3(0.42, 0.38, 0.31);
uniform vec3 chip_b : source_color = vec3(0.3, 0.28, 0.25);
uniform vec3 soil : source_color = vec3(0.2, 0.15, 0.1);
uniform vec3 moss : source_color = vec3(0.24, 0.28, 0.1);

varying vec3 wp;
varying float hy;   // 0 at the foot of the hearting box, 1 at its top

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

// distance to the nearest chip centre and to the second nearest, and the nearest's id
vec3 chips(vec3 p) {
	vec3 i = floor(p);
	float f1 = 9.0, f2 = 9.0, id = 0.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 c = i + vec3(float(x), float(y), float(z));
		vec3 o = vec3(hash3(c), hash3(c + 17.3), hash3(c + 41.7));
		float d = length((c + o) - p);
		if (d < f1) { f2 = f1; f1 = d; id = hash3(c + 3.1); } else if (d < f2) { f2 = d; }
	}
	return vec3(f1, f2, id);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hy = VERTEX.y + 0.5;
}

void fragment() {
	// chips ~7 cm, flattened a little like bedded stone
	vec3 v = chips(wp * vec3(13.0, 18.0, 13.0));
	float gap = smoothstep(0.03, 0.16, v.y - v.x);   // 0 in the voids between chips
	vec3 col = mix(chip_b, chip_a, v.z) * mix(0.7, 1.15, fbm(wp * 30.0));
	col *= mix(0.12, 1.0, gap);
	// soil silts the lower joints (deepest at the foot, in drifts), moss grows up out of it
	float low = 1.0 - smoothstep(0.15, 0.6, hy + (fbm(wp * 4.0) - 0.5) * 0.5);
	float silt = smoothstep(0.35, 0.6, low * 0.8 + fbm(wp * 7.0 + 3.0) * 0.5);
	col = mix(col, soil * mix(0.7, 1.1, vn(wp * 40.0)), silt * mix(0.7, 1.0, 1.0 - gap));
	float m = smoothstep(0.5, 0.72, fbm(wp * 5.5 + 11.0) + low * 0.25) * (0.55 + 0.45 * gap);
	col = mix(col, moss * mix(0.6, 1.1, vn(wp * 55.0)), m * 0.85);
	float rough = 0.95;
	weather_wetten(col, rough, 0.9);
	ALBEDO = col;
	ROUGHNESS = rough;
	AO = mix(0.25, 1.0, gap);
	AO_LIGHT_AFFECT = 0.6;
}
