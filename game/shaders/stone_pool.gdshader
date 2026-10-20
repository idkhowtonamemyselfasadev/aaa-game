shader_type spatial;
// Rain lying along a door stone's edges: the trodden hollow beside a flag where feet step off
// it fills with water in pools that the drops ring. Opaque, so screen-space reflections take
// it and the pools mirror the sky and the house front instead of reading as black mud. The
// lobed pool outline is the same one `stone_gap.gdshader` cuts out of its loam (keep the two
// in step); everything outside a pool is discarded, and the whole ring while it is dry.
render_mode cull_disabled;

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform vec3 pool_floor : source_color = vec3(0.05, 0.04, 0.03);

// COLOR.r: metres out past the slab's edge / DoorStones.POOL_OUT (0.24 m)
varying vec3 wp;
varying float out_v;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = p * 2.03 + 3.7; a *= 0.5; } return r; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	out_v = COLOR.r * 0.24;
}

void fragment() {
	float out_m = out_v;
	float rag = (fbm(wp.xz * 9.0) - 0.5) * 0.06;
	float lobe = fbm(wp.xz * 4.5 + 7.0);
	float reach = mix(0.03, 0.2, smoothstep(0.35, 0.75, lobe)) * smoothstep(0.35, 0.95, weather_wet);
	float pool = (1.0 - smoothstep(reach - 0.025, reach, out_m + rag * 0.4)) * smoothstep(-0.01, 0.005, out_m)
	           * step(0.04, reach);
	if (pool < 0.5) {
		discard;
	}
	// the shallow rim shows the mud floor through the water; deeper in it is a dark mirror
	float depth = smoothstep(0.0, 0.06, reach - (out_m + rag * 0.4));
	float crumbs = vn(wp.xz * 60.0);
	vec3 c = pool_floor * (0.85 + 0.3 * crumbs) * mix(1.4, 0.8, depth);
	vec3 nw = vec3(0.0, 1.0, 0.0);
	if (weather_rain > 0.01) {
		vec2 sl = rain_ripples(wp.xz, TIME, weather_rain) * 0.05;
		nw = normalize(vec3(-sl.x, 1.0, -sl.y));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = c;
	ROUGHNESS = mix(0.14, 0.08, depth);
	SPECULAR = 0.35;
	EMISSION = c * bounce_light * 0.2;
}
