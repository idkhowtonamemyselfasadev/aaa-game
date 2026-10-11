shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Oak leaf sprig cards: atlas painted by flora.gd, alpha-tested; crown-shaped normals
// (set by the mesh) for a soft canopy, back-light translucency, flutter on top of the
// shared branch sway.
#include "res://shaders/tree_wind.gdshaderinc"

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
	float rough = 0.6;
	weather_wetten(col, rough, 0.3);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	BACKLIGHT = col * 0.7;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;
	BACKLIGHT *= v_cloud;
}
