shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Far mountain ring (world/horizon.gd). Seen from 0.3-3 km, so it carries macro shape only:
// near the tile edge it matches the Vale meadow, then dark conifer/oak forest on the
// foothills, bare scree and rock on steep faces, snow on the high ridges. Aerial perspective
// comes from the environment fog.

uniform vec3 meadow_a : source_color = vec3(0.30, 0.24, 0.09);
uniform vec3 meadow_b : source_color = vec3(0.55, 0.42, 0.17);
uniform vec3 forest_a : source_color = vec3(0.07, 0.09, 0.05);
uniform vec3 forest_b : source_color = vec3(0.16, 0.17, 0.08);
uniform vec3 rock_a   : source_color = vec3(0.36, 0.34, 0.32);
uniform vec3 rock_b   : source_color = vec3(0.17, 0.16, 0.16);
uniform vec3 snow     : source_color = vec3(0.86, 0.88, 0.92);
uniform float tile_half = 256.0;
uniform float snow_line = 380.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
	           mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, r = 0.0;
	for (int k = 0; k < 5; k++) { r += a * vnoise(p); p = p * 2.07 + 3.3; a *= 0.5; }
	return r;
}

void fragment() {
	vec3 n = normalize(wnrm);
	float d = max(abs(wpos.x), abs(wpos.z)) - tile_half;     // metres outside the Vale tile
	float slope = 1.0 - n.y;
	float macro = fbm(wpos.xz * 0.004);
	float meso  = fbm(wpos.xz * 0.03);
	float fine  = fbm(wpos.xz * 0.25);
	// forest: patches that thin out with altitude and on steep ground; tree-crown speckle
	float forest = smoothstep(0.3, 0.45, macro + meso * 0.25 - 0.1)
	             * (1.0 - smoothstep(0.35, 0.6, slope))
	             * (1.0 - smoothstep(snow_line - 160.0, snow_line - 40.0, wpos.y));
	forest *= smoothstep(20.0, 140.0, d);
	vec3 meadow = mix(meadow_a, meadow_b, clamp(meso * 0.8 + fine * 0.3 - 0.2, 0.0, 1.0));
	vec3 trees  = mix(forest_a, forest_b, fine * 0.7 + meso * 0.3);
	// rock on steep faces, with strata bands so cliffs read at distance
	float strata = vnoise(vec2(wpos.y * 0.15 + meso * 3.0, macro * 4.0));
	float rockw = smoothstep(0.22, 0.45, slope + (meso - 0.5) * 0.3);
	vec3 rock = mix(rock_b, rock_a, strata * 0.6 + fine * 0.4);
	// snow: above the line, only where it can settle (flatter), streaky down gullies
	float snoww = smoothstep(snow_line - 30.0, snow_line + 40.0, wpos.y + (meso - 0.5) * 90.0)
	            * (1.0 - smoothstep(0.45, 0.75, slope - fine * 0.2));
	vec3 col = mix(meadow, trees, forest);
	col = mix(col, rock, rockw);
	col = mix(col, snow, snoww);
	col *= 0.85 + 0.3 * fine;
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.85, rockw), 0.6, snoww);
	SPECULAR = mix(0.1, 0.35, snoww);
	// forest canopy reads lumpy under low sun
	vec3 dn = vec3(fine - 0.5, 1.0, meso - 0.5);
	NORMAL_MAP = normalize(dn * vec3(0.8, 1.0, 0.8)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(1.0, 1.6, forest);
}
