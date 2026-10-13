shader_type spatial;
render_mode cull_back;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
// Procedural oak bark: deep vertical furrows (stretched ridged noise along the limb),
// plated ridges, lichen/moss on the upward side and near the roots.
#include "res://shaders/tree_wind.gdshaderinc"

uniform vec3 bark_dark : source_color = vec3(0.07, 0.06, 0.05);
uniform vec3 bark_light : source_color = vec3(0.30, 0.27, 0.23);
uniform vec3 moss : source_color = vec3(0.17, 0.2, 0.06);

varying vec3 wn;
varying float vy;
varying float v_root;   // 1 on a surface root (Flora._build_roots)
varying float v_soil;   // root: height above the soil (m)

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
// u wraps at 2.0 around the limb: tile the noise so there is no seam
float n2w(vec2 p, float per) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	vec2 i1 = vec2(mod(i.x + 1.0, per), i.y);
	vec2 i0 = vec2(mod(i.x, per), i.y);
	return mix(mix(h21(i0), h21(i1), f.x), mix(h21(i0 + vec2(0, 1)), h21(i1 + vec2(0, 1)), f.x), f.y);
}

varying float v_cloud;   // cloud shadow on this vertex (1 = full sun)

void vertex() {
	VERTEX += tree_wind(VERTEX, COLOR.r, MODEL_MATRIX, TIME);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vy = VERTEX.y;
	v_root = COLOR.g;
	v_soil = COLOR.b;
	v_cloud = cloud_shade_at((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

float furrow(vec2 uv) {
	// 12 ridges around (u in 0..2 -> 24 cells per wrap), stretched 6x along the limb
	vec2 p = vec2(uv.x * 12.0, uv.y * 2.0);
	float a = n2w(p + vec2(n2(p * vec2(0.5, 0.3)) * 1.5, 0.0), 24.0);
	float b = n2w(p * vec2(2.0, 3.0) + 3.1, 48.0);
	float r = 1.0 - abs(a * 2.0 - 1.0);
	return clamp(r * 0.75 + b * 0.25, 0.0, 1.0);
}

void fragment() {
	float f = furrow(UV);
	float e = 0.004;
	float fx = furrow(UV + vec2(e, 0.0));
	float fy = furrow(UV + vec2(0.0, e * 4.0));
	vec3 col = mix(bark_dark, bark_light, smoothstep(0.25, 0.85, f));
	col *= 0.85 + 0.3 * n2(UV * vec2(40.0, 10.0));
	float m = smoothstep(0.35, 0.8, wn.y + n2(UV * vec2(8.0, 3.0)) * 0.4 - 0.1);
	m = max(m, smoothstep(1.2, 0.0, vy) * 0.8 * n2(UV * 6.0));
	// the shaded side of the bole stays damp: moss climbs it from the foot collar in
	// streaks that run up the furrows, reaching ~2.5 m (local) on the full north face
	float shade = clamp(dot(normalize(wn.xz + vec2(1e-4)), MOSS_SHADE), 0.0, 1.0) * (1.0 - abs(wn.y));
	float reach = mix(0.3, 2.6, shade) * (0.55 + 0.9 * n2w(vec2(UV.x * 6.0, 0.0), 12.0));
	float climb = 1.0 - smoothstep(reach * 0.4, reach, vy);
	m = max(m, smoothstep(0.2, 0.6, climb * (0.55 + 0.6 * f) * (0.7 + 0.5 * n2(UV * vec2(10.0, 2.0)))));
	if (v_root > 0.5) {
		// surface roots: the arched tops are worn bare and paler, moss and peat fill the
		// crotches and the line where the root goes into the soil
		float top = smoothstep(0.2, 0.8, wn.y);
		col = mix(col, bark_light * 1.15, top * 0.35 * f);
		float lowm = 1.0 - smoothstep(0.02, 0.14, v_soil);
		m = clamp(lowm * (0.6 + 0.6 * n2(UV * vec2(5.0, 2.0))) + top * smoothstep(0.55, 0.8, n2(UV * vec2(3.0, 1.2))) * 0.7, 0.0, 1.0);
		col *= mix(0.5, 1.0, smoothstep(0.0, 0.07, v_soil));
	}
	col = mix(col, moss * (0.8 + 0.4 * f), m * 0.85);
	float rough = mix(0.92, 0.8, m);
	weather_wetten(col, rough, 1.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
	NORMAL_MAP = normalize(vec3((f - fx) * 18.0, (f - fy) * 6.0, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.6;
	AO = mix(0.45, 1.0, f);
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;
	// trunks are vertical: bounce off the ground below, less in the furrows
	EMISSION = ALBEDO * bounce_light * 0.85 * AO;
}
