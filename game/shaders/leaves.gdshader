shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
// Oak leaf sprig cards: atlas painted by flora.gd, alpha-tested; crown-shaped normals
// (set by the mesh) for a soft canopy, back-light translucency, flutter on top of the
// shared branch sway.
#include "res://shaders/tree_wind.gdshaderinc"
#include "res://shaders/foliage_light.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float fade_dist = 380.0;

varying float v_phase;
varying vec3 v_inst;

varying float v_cloud;   // cloud shadow on this vertex (1 = full sun)

void vertex() {
	VERTEX += tree_wind(VERTEX, COLOR.r, MODEL_MATRIX, TIME);
	float fl = sin(TIME * 6.0 + COLOR.g * 60.0 + MODEL_MATRIX[3].x) * 0.035;
	VERTEX += vec3(fl, fl * 0.6, -fl) * COLOR.r;
	v_phase = COLOR.g;
	v_inst = MODEL_MATRIX[3].xyz;
	v_cloud = cloud_shade_at((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	// per-instance and per-card variation so whole groves are not one colour
	float iv = fract(sin(dot(v_inst.xz, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = t.rgb * tint * mix(0.85, 1.15, v_phase) * mix(vec3(0.9, 1.0, 0.9), vec3(1.15, 1.0, 0.8), iv);
	ALBEDO = col;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	float rough = 0.72;
	weather_wetten(col, rough, 0.3);
	ALBEDO = col;
	ROUGHNESS = rough;
	// Godot's Fresnel peak (f90) scales with f0 = 0.16 * SPECULAR^2: at 0.4 it clamps to 1, so
	// every sun-facing card went white at grazing angles looking toward the sun. 0.2 caps the
	// grazing sheen at ~0.3 (a waxy oak leaf, not a mirror).
	SPECULAR = 0.2;
	// thin leaf transmission tint (foliage_light: a gain on the albedo): yellow-green
	BACKLIGHT = vec3(0.95, 1.1, 0.42);
	if (!FRONT_FACING) NORMAL = -NORMAL;
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;   // (also dims the transmission: foliage_light scales by albedo)
	// inner crown: light scattered off the lit leaves and ground around it
	EMISSION = ALBEDO * bounce_light * 0.45;
}

void light() {
	foliage_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL,
		BACKLIGHT, ROUGHNESS, SPECULAR_AMOUNT, 0.3, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
