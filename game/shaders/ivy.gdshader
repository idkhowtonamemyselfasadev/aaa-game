shader_type spatial;
render_mode cull_disabled;
// Ivy leaf blades on the ruined keep (ivy.gd): real lobed geometry, no texture. UV = leaf space
// (x + 0.5 across, y from the petiole notch to the apex). Dark glossy green with pale palmate
// veins running from the notch to the lobe tips, a paler rim, young leaves light bronze-green.
// INSTANCE_CUSTOM: r = young (1 at a growing tip), g = random, b = age up the wall, a = tone
// (a few yellower, a few winter-bronzed red-purple, a share of dark old leathery leaves).

#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/foliage_light.gdshaderinc"
global uniform vec3 bounce_light;
#include "res://shaders/bounce.gdshaderinc"
uniform vec3 leaf_dark : source_color = vec3(0.12, 0.2, 0.07);
uniform vec3 leaf_mid : source_color = vec3(0.2, 0.29, 0.1);
uniform vec3 leaf_young : source_color = vec3(0.25, 0.31, 0.1);
uniform vec3 vein_col : source_color = vec3(0.32, 0.38, 0.19);
uniform float fill = 0.55;

varying vec3 wp;
varying float v_young;
varying float v_rand;
varying float v_cloud;
varying float v_tone;
varying float v_old;

void vertex() {
	v_young = INSTANCE_CUSTOM.r;
	v_rand = INSTANCE_CUSTOM.g;
	v_tone = INSTANCE_CUSTOM.a;
	v_old = INSTANCE_CUSTOM.b;
	// a light flutter: the tip moves, the base holds on its petiole
	vec3 ip = MODEL_MATRIX[3].xyz;
	float w = sin(TIME * 3.1 + ip.x * 7.0 + ip.y * 5.0 + v_rand * 6.0) * 0.06
		+ sin(TIME * 7.3 + ip.z * 11.0) * 0.02;
	VERTEX.z += w * VERTEX.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_cloud = cloud_shade_at(wp);
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 q = vec2(UV.x - 0.5, UV.y);
	vec2 o = vec2(0.0, 0.07);
	// palmate main veins to the apex, the lateral and the basal lobes; finer veins branch off
	float d = seg_dist(q, o, vec2(0.0, 0.97));
	d = min(d, seg_dist(vec2(abs(q.x), q.y), o, vec2(0.46, 0.5)));
	d = min(d, seg_dist(vec2(abs(q.x), q.y), o, vec2(0.4, 0.1)));
	float main_v = 1.0 - smoothstep(0.006, 0.018, d);
	float fine_d = min(seg_dist(vec2(abs(q.x), q.y), vec2(0.0, 0.5), vec2(0.28, 0.72)),
		seg_dist(vec2(abs(q.x), q.y), vec2(0.16, 0.24), vec2(0.36, 0.34)));
	float fine_v = (1.0 - smoothstep(0.003, 0.01, fine_d)) * 0.5;
	float vein = max(main_v, fine_v) * mix(0.75, 0.35, v_young);
	vec3 col = mix(leaf_dark, leaf_mid, v_rand * 0.7);
	// leaf-to-leaf tone: dark old leathery leaves (more low down on the old wood), a few
	// yellowing ones, a few bronzed red-purple by the cold; then pull saturation down a touch
	// so the mats are not one even green
	float dark_old = step(0.62, v_tone) * (1.0 - v_young) * mix(1.0, 0.6, v_old);
	col = mix(col, col * vec3(0.62, 0.66, 0.6), dark_old);
	// tone colours are linear (the source_color greens are ~0.01-0.06 linear)
	col = mix(col, vec3(0.075, 0.062, 0.012), step(v_tone, 0.07) * (1.0 - v_young) * 0.75);
	col = mix(col, vec3(0.036, 0.014, 0.009), step(0.07, v_tone) * step(v_tone, 0.13) * (1.0 - v_young) * 0.7);
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(vec3(lum), col, mix(0.72, 0.95, v_rand));
	col = mix(col, leaf_young, v_young * 0.8);
	// mottled blade: a few darker and yellower blotches leaf to leaf
	float blot = sin(q.x * 23.0 + v_rand * 40.0) * sin(q.y * 19.0 - v_rand * 17.0);
	col *= 1.0 + blot * 0.08;
	col = mix(col, vein_col, vein);
	// the rim pales a touch where the blade thins
	float r = length(q - vec2(0.0, 0.42));
	col = mix(col, col * vec3(1.15, 1.12, 0.9), smoothstep(0.3, 0.5, r) * 0.4);
	float rough = mix(0.32, 0.5, v_young) + vein * 0.2;
	weather_wetten(col, rough, 0.1);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	BACKLIGHT = vec3(0.8, 1.0, 0.35);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
		ALBEDO *= vec3(0.9, 1.05, 0.85);   // underside: paler, matt
		ROUGHNESS = 0.7;
	}
	ALBEDO *= v_cloud;
	EMISSION = ALBEDO * bounce_light * fill * bounce_gain(wp);
}

void light() {
	foliage_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL,
		BACKLIGHT, 2.2, ROUGHNESS, SPECULAR_AMOUNT, 0.2, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
