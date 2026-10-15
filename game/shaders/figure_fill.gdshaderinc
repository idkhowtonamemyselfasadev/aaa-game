// Shade fill for the fighters (hero body, garb, the Hollow, staff and spear). Without SDFGI
// (software Vulkan, low quality) a figure with the sun behind it got only the flat sky
// ambient and read as a black cut-out against the meadow. Like the deer and the stone, it
// takes `bounce_light` (World._apply_bounce): the sunlit meadow throws warm light up into
// the faces turned toward the ground and sideways, little into the tops. Zero under SDFGI.
#include "res://shaders/bounce.gdshaderinc"
global uniform vec3 bounce_light;

// albedo, world normal, world position -> emission to add
vec3 figure_fill(vec3 alb, vec3 wn, vec3 wp) {
	float up = clamp(wn.y, -1.0, 1.0);
	// ground lobe: strongest facing down, half facing sideways, a little on the tops
	float lobe = mix(1.35, 0.85, smoothstep(-1.0, 0.0, up)) * mix(1.0, 0.45, smoothstep(0.0, 1.0, up));
	return alb * bounce_light * 0.55 * lobe * bounce_gain(wp);
}
