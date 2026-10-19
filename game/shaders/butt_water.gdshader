shader_type spatial;
render_mode cull_back;
// Rainwater standing in the water butt (world/water_butt.gd): a dark still disc that
// mirrors the sky and the eaves, a skin of pollen and a few fallen leaves drifting on it,
// rain rings when it rains (thicker than on open ground: the eaves drip lands in it too)
// and a slow shiver when the wind gets up.

#include "res://shaders/weather.gdshaderinc"
uniform vec3 sky_sheen = vec3(0.5, 0.53, 0.57);
uniform float drip = 0.0;      // 0..1 extra drops from the eaves while it rains
uniform float seed = 0.0;

varying vec3 wp;
varying vec3 ctr;
varying float rad;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn2(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ctr = MODEL_MATRIX[3].xyz;
	rad = max(length(MODEL_MATRIX[0].xyz), 0.01);
}

void fragment() {
	vec2 xz = wp.xz;
	vec2 lp = UV - 0.5;   // -0.5..0.5 across the disc
	// deep peaty rainwater: near black, a hint of tea brown where light gets in
	vec3 col = vec3(0.025, 0.022, 0.016);
	float rough = 0.03;
	// pollen and dust skin, gathered against the staves
	float edge = smoothstep(0.32, 0.5, length(lp));
	// (thin and patchy: a full skin made the whole disc read matte)
	float film = smoothstep(0.62, 0.9, vn2(xz * 22.0 + seed) * 0.8 + edge * 0.45);
	col = mix(col, vec3(0.2, 0.18, 0.1), film * 0.2);
	rough = mix(rough, 0.22, film * 0.5);
	// fallen oak/ash leaves afloat, drifting slowly round
	float ang = TIME * 0.01 + seed;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 q = rot * lp;
	float leaf = 0.0;
	vec3 leaf_col = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		vec2 c = vec2(hash2(vec2(fk, seed)) - 0.5, hash2(vec2(seed, fk + 3.0)) - 0.5) * 0.7;
		float a = hash2(vec2(fk * 7.0, seed)) * 6.283;
		vec2 d = q - c;
		d = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * d;
		// a pointed oval with a lobed edge
		float lobe = 1.0 + 0.18 * sin(atan(d.y, d.x) * 7.0);
		float r = length(d * vec2(1.0, 2.1)) / lobe;
		float m = 1.0 - smoothstep(0.045, 0.052, r);
		if (m > leaf) {
			leaf = m;
			leaf_col = mix(vec3(0.33, 0.2, 0.07), vec3(0.2, 0.17, 0.06), hash2(vec2(fk, 9.0))) * (0.8 + 0.3 * vn2(d * 160.0));
		}
	}
	col = mix(col, leaf_col, leaf);
	rough = mix(rough, 0.7, leaf);
	// rings: the rain, plus the eaves drip; a wind shiver
	float rate = clamp(weather_rain * 1.3 + drip * 0.5, 0.0, 1.0);
	vec2 rip = rain_ripples(xz * 1.6, TIME, rate) * (1.0 - leaf);
	float sh = weather_wind * 0.6 + 0.08;
	rip += vec2(vn2(xz * 30.0 + TIME * 1.3) - 0.5, vn2(xz * 30.0 - TIME * 1.1 + 4.0) - 0.5) * 0.15 * sh;
	vec3 n = normalize(vec3(-rip.x * 0.7, 1.0, -rip.y * 0.7));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 vdir = normalize(CAMERA_POSITION_WORLD - wp);
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(n, vdir), 0.0, 1.0), 5.0);
	// mirrored sky: brighter toward the zenith, cut off by the dark inside of the staves
	// near the rim on the far side (the reflection ray hits wood, not sky)
	vec3 rv = reflect(-vdir, n);
	float up = clamp(rv.y, 0.0, 1.0);
	// (the haze colour alone tinted the disc pink-brown: cool it toward a pale overcast sky)
	vec3 sky = mix(vec3(dot(sky_sheen, vec3(0.3, 0.55, 0.15))), sky_sheen, 0.35) * vec3(0.9, 0.97, 1.08);
	sky *= 0.7 + 0.6 * up;
	vec2 far_dir = normalize(-vdir.xz + vec2(1e-4));
	vec2 off = (wp.xz - ctr.xz) / rad;   // -1..1 across the disc in world space
	float rim = smoothstep(0.45, 0.95, dot(off, far_dir) + length(off) * 0.3);
	float refl = min(0.06 + fres * 4.0, 0.8) * (1.0 - rim * 0.8);
	// a thin bright meniscus where the water climbs the staves
	float men = smoothstep(0.9, 0.99, length(off)) * (1.0 - leaf);
	refl += men * 0.35;
	EMISSION = sky * refl * (1.0 - leaf) * (1.0 - film * 0.6);
}
