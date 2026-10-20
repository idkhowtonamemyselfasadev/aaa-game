shader_type spatial;
// The dirt-filled gap round a door stone: a thin decal quad laid on the ground under each
// slab, a little bigger than it, dark crumbled loam packed into the crack between the slab's
// edge and the turf, fading out ragged into the track's own dirt. In rain the loam goes black
// and water lies along the slab's edges -- the trodden hollow beside a flag where feet step
// off it -- in glassy pools that the drops ring; they shrink back to damp as it dries.
render_mode blend_mix, depth_draw_never, cull_disabled;

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform vec3 loam : source_color = vec3(0.13, 0.095, 0.065);
uniform vec3 loam_dry : source_color = vec3(0.24, 0.19, 0.13);

// UV: metres from the slab's centre along its own x/z; UV2: the slab's half size in metres
// (the patch runs DoorStones.GAP + POOL past it)
varying vec3 wp;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = p * 2.03 + 3.7; a *= 0.5; } return r; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// metres out past the slab's edge (negative under it)
	vec2 d = abs(UV) - UV2;
	float out_m = max(d.x, d.y);
	float rag = (fbm(wp.xz * 9.0) - 0.5) * 0.06;
	// solid under the slab's edge out to ~7 cm past it, ragged fade beyond
	float dirt = 1.0 - smoothstep(0.0, 0.07, out_m + rag);
	float crumbs = vn(wp.xz * 60.0);
	vec3 c = mix(loam, loam_dry, smoothstep(0.45, 0.8, fbm(wp.xz * 14.0 + 2.0)) * 0.7);
	c *= 0.8 + 0.4 * crumbs;
	float rough = 0.96;
	// wet: the loam soaks near black and slick
	wetten_by(c, rough, 1.0, weather_wet);
	// pools: hug the edge, widest at the slab's long sides where feet step off, lobed by noise;
	// more of the hollow fills the wetter it is, and only once the ground is properly soaked
	float lobe = fbm(wp.xz * 4.5 + 7.0);
	float reach = mix(0.03, 0.2, smoothstep(0.35, 0.75, lobe)) * smoothstep(0.35, 0.95, weather_wet);
	float pool = (1.0 - smoothstep(reach - 0.025, reach, out_m + rag * 0.4)) * smoothstep(-0.01, 0.005, out_m)
	           * step(0.04, reach);
	// a dark wet margin round each pool
	float margin = (1.0 - smoothstep(reach, reach + 0.05, out_m + rag * 0.4)) * smoothstep(0.2, 0.6, weather_wet);
	c = mix(c, c * 0.7, margin * (1.0 - dirt));
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	// the water itself is the opaque skin under this (`stone_pool.gdshader`): leave a hole for it
	float hole = step(0.5, pool);
	ALPHA = clamp(max(dirt * 0.85, margin * 0.6), 0.0, 1.0) * (1.0 - hole);
	EMISSION = c * bounce_light * 0.4;
}
