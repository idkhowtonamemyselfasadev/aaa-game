shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Meadow wildflowers (flowers.gd builds the meshes). COLOR.r = part (0 stem/leaf, 0.5 petal,
// 1 disc/centre), COLOR.g = along the petal (or > 0.25 on a stem part: the knapweed bract);
// UV.y = wind weight 0 root .. 1 head. INSTANCE_CUSTOM.r = variation, .g = species
// (0 ox-eye daisy, 1 buttercup, 2 knapweed, 3 yarrow).
#include "res://shaders/meadow_wind.gdshaderinc"

uniform float fade_start = 44.0;
uniform float fade_end = 58.0;

varying float v_part;
varying float v_along;
varying float v_sp;
varying float v_var;
varying float v_h;
varying vec3 v_local;

void vertex() {
	v_part = COLOR.r;
	v_along = COLOR.g;
	v_sp = floor(INSTANCE_CUSTOM.g + 0.5);
	v_var = INSTANCE_CUSTOM.r;
	v_h = UV.y;
	v_local = VERTEX;
	vec3 root = MODEL_MATRIX[3].xyz;
	vec3 iw = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = 1.0 - smoothstep(fade_start, fade_end, distance(iw, CAMERA_POSITION_WORLD));
	vec3 wv = meadow_wind(root, clamp(UV.y, 0.0, 1.0), TIME);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * wv;
	VERTEX *= vec3(1.0, fade, 1.0);
}

float h1(float x) { return fract(sin(x * 91.7) * 4375.85); }

void fragment() {
	vec3 stem = mix(vec3(0.15, 0.20, 0.07), vec3(0.22, 0.24, 0.09), v_var);
	stem *= mix(0.55, 1.0, smoothstep(0.0, 0.5, v_h));      // darker at the root
	vec3 col = stem;
	float rough = 0.7;
	float spec = 0.3;
	float back = 0.35;
	if (v_part < 0.25) {
		if (v_along > 0.25) {
			// knapweed bract bulb: dark brown-green with a scaly pattern
			float sc = fract(v_local.y * 900.0 + atan(v_local.z, v_local.x) * 2.0);
			col = mix(vec3(0.10, 0.08, 0.04), vec3(0.24, 0.22, 0.10), smoothstep(0.2, 0.8, sc));
			back = 0.05;
		}
	} else if (v_part < 0.75) {
		// petals
		if (v_sp < 0.5) {
			col = vec3(0.86, 0.86, 0.82) * mix(0.82, 1.0, smoothstep(0.0, 0.4, v_along));
			col = mix(col, vec3(0.80, 0.78, 0.55), (1.0 - smoothstep(0.0, 0.2, v_along)) * 0.5);
			back = 0.7;
		} else if (v_sp < 1.5) {
			col = mix(vec3(0.62, 0.48, 0.02), vec3(0.85, 0.68, 0.04), smoothstep(0.0, 0.6, v_along));
			rough = 0.18;     // buttercups are famously glossy
			spec = 0.7;
			back = 0.45;
		} else if (v_sp < 2.5) {
			col = mix(vec3(0.30, 0.10, 0.30), vec3(0.52, 0.20, 0.50), smoothstep(0.0, 0.8, v_along));
			col *= 0.8 + 0.4 * h1(v_var + floor(v_local.x * 4000.0));
			back = 0.4;
		} else {
			col = vec3(0.82, 0.80, 0.74) * (0.9 + 0.1 * v_var);
			back = 0.55;
		}
		col *= 0.85 + 0.15 * v_var;
	} else {
		// disc / centre
		if (v_sp < 0.5) {
			col = vec3(0.78, 0.55, 0.04) * (0.85 + 0.3 * h1(floor(v_local.x * 3000.0) + floor(v_local.z * 3000.0) * 7.0));
		} else if (v_sp < 1.5) {
			col = vec3(0.45, 0.42, 0.06);
		} else {
			col = vec3(0.62, 0.58, 0.42);
		}
		back = 0.2;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	BACKLIGHT = col * back;
	AO = mix(0.4, 1.0, smoothstep(0.0, 0.6, v_h));
	AO_LIGHT_AFFECT = 0.3;
}
