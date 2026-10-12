shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
#include "res://shaders/bounce.gdshaderinc"
// Grass clumps for the Vale. Blades are real geometry (procedural mesh from grass.gd); this
// shader bends them with layered wind (gusts travel across the field), tints them per clump
// from dry amber to late-summer green, shades them with root occlusion and back-light
// translucency, and shrinks them into the ground at the edge of the draw distance so there
// is no pop.

#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/foliage_light.gdshaderinc"
uniform vec3 tip_dry   : source_color = vec3(0.78, 0.62, 0.30);
uniform vec3 tip_green : source_color = vec3(0.50, 0.50, 0.20);
uniform vec3 root_col  : source_color = vec3(0.16, 0.13, 0.05);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind_strength = 0.35;
uniform float gust_strength = 0.55;
uniform float fade_start = 48.0;
uniform float fade_end = 64.0;

varying float v_h;        // 0 root .. 1 tip
varying float v_var;      // per-instance variation
varying float v_ao;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

varying float v_shelter; // rain the oak crowns catch above this clump
varying float v_cloud;   // cloud shadow on this vertex (1 = full sun)

void vertex() {
	v_h = UV.y;
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_shelter = shelter_at(origin.xz);
	vec3 iw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// per-instance data: INSTANCE_CUSTOM.x variation, .y height scale (baked into transform)
	v_var = INSTANCE_CUSTOM.x;
	// distance fade: sink and thin the blade as it reaches the draw distance
	float d = distance(iw, CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, d);
	// wind: a slow large swell + travelling gusts + per-blade flutter
	vec2 wd = normalize(wind_dir);
	float t = TIME;
	float swell = sin(dot(iw.xz, wd) * 0.05 - t * 0.9) * 0.5 + 0.5;
	float gust = n2(iw.xz * 0.04 - wd * t * 1.6);
	gust = smoothstep(0.35, 0.95, gust);
	float storm = clamp(weather_wind, 0.0, 1.0);
	float flutter = sin(t * 7.0 + v_var * 40.0 + iw.x * 0.7) * 0.06 * (1.0 + 1.8 * storm);
	// a storm front combs the sward over: stronger swell, much stronger gusts
	float bend = (wind_strength * (1.0 + 0.6 * storm) * swell + gust_strength * (1.0 + 0.9 * storm) * gust) * v_h * v_h;
	vec3 wv = vec3(wd.x, 0.0, wd.y) * bend + vec3(flutter * v_h, 0.0, flutter * 0.6 * v_h);
	// bend in world space, convert back to local (instances are rotated/scaled)
	vec3 lw = (inverse(mat3(MODEL_MATRIX)) * wv);
	VERTEX += lw;
	VERTEX.y -= bend * 0.35 * v_h;   // keep blade length roughly constant when bent
	VERTEX *= vec3(1.0, fade, 1.0);
	v_ao = mix(0.35, 1.0, smoothstep(0.0, 0.6, v_h));
	// lean normals up so clumps light like a canopy, not like flat cards
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0) * mat3(MODEL_MATRIX), 0.55));
	v_cloud = cloud_shade_at((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec3 tip = mix(tip_green, tip_dry, smoothstep(0.25, 0.85, v_var));
	tip *= 0.85 + 0.3 * fract(v_var * 13.7);
	vec3 col = mix(root_col, tip, smoothstep(0.0, 0.9, v_h));
	float rough = 0.82;
	col *= v_ao;
	weather_wetten_sheltered(col, rough, 0.85, v_shelter);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	BACKLIGHT = vec3(0.85, 0.95, 0.5) * v_h;   // transmission tint (foliage_light)
	AO = v_ao;
	AO_LIGHT_AFFECT = 0.4;
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;   // (also dims the transmission: foliage_light scales by albedo)
	// blades stand upright: they catch the bounce off the meadow around them
	EMISSION = ALBEDO * bounce_light * 0.6
		* bounce_gain((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void light() {
	foliage_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL,
		BACKLIGHT, ROUGHNESS, SPECULAR_AMOUNT, 0.1, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
