// Shade fill for the fighters (hero body, garb, the Hollow, staff and spear). Without SDFGI
// (software Vulkan, low quality) a figure with the sun behind it got only the flat sky
// ambient and read as a black cut-out against the meadow. Like the deer and the stone, it
// takes `bounce_light` (World._apply_bounce): the sunlit meadow throws warm light up into
// the faces turned toward the ground and sideways, little into the tops. Zero under SDFGI.
#include "res://shaders/bounce.gdshaderinc"
global uniform vec3 bounce_light;
// The low-sun / moonlit skylight the open ground, grass, crowns and masonry already take
// (World._apply_bounce): without it a figure at 16:30 read near-black on a meadow lit by it.
global uniform vec3 ground_fill;

// Rim light (World._apply_bounce sets them; zero = off). With the sun behind a figure (every
// 'from behind' glide or walk toward the light) the dark wool, hat and plates got only the fill
// above and read as a black cut-out against the bright vale. Real cloth and worn metal catch
// the light at the silhouette: fibres scatter the sun that grazes past them, and the open sky
// behind the figure reflects off its edges. Both live only at grazing view angles, so the
// faces turned to the camera keep their shade and the figure keeps its form.
global uniform vec3 rim_light;   // sun (or moon) colour x energy
global uniform vec3 rim_sky;     // sky dome colour x energy
global uniform vec3 rim_dir;     // direction toward the sun (or moon)
global uniform bool figure_rim_off;  // RIM_OLD=1: the figures before the rim light

vec3 figure_rim(vec3 alb, vec3 wn, vec3 wp, vec3 cam) {
	vec3 v = normalize(cam - wp);
	float ndv = clamp(dot(wn, v), 0.0, 1.0);
	float edge = pow(1.0 - ndv, 2.0);
	vec3 l = normalize(rim_dir + vec3(0.0, 1e-4, 0.0));
	// the sun behind the figure as the camera sees it (0 with the sun at the camera's back)
	float back = smoothstep(-0.2, 0.85, dot(-v, l));
	// edges whose normals lean toward the sun catch most of it; a soft wrap round the far side
	float side = clamp((dot(wn, l) + 0.7) / 1.7, 0.0, 1.0);
	// dark cloth's fibre sheen is paler than its body colour: lift the darkest albedos
	vec3 sheen = alb * 0.75 + vec3(0.035);
	return sheen * edge * (rim_light * back * side * 1.5 + rim_sky * 0.6);
}

// albedo, world normal, world position -> emission to add
// (cam: CAMERA_POSITION_WORLD; built-ins are not visible inside shader functions)
vec3 figure_fill(vec3 alb, vec3 wn, vec3 wp, vec3 cam) {
	float up = clamp(wn.y, -1.0, 1.0);
	// ground lobe: strongest facing down, half facing sideways, a little on the tops
	float lobe = mix(1.35, 0.85, smoothstep(-1.0, 0.0, up)) * mix(1.0, 0.45, smoothstep(0.0, 1.0, up));
	// sky lobe: the open dome over a figure, full on the tops, most of it on the sides (grass:
	// 0.7; at 0.5 a standing figure, nearly all sides, stayed a stop under the meadow at 16:30)
	float sky = clamp(0.75 + 0.2 * up, 0.25, 0.95);
	return alb * (bounce_light * 0.55 * lobe * bounce_gain(wp) + ground_fill * sky)
			+ (figure_rim_off ? vec3(0.0) : figure_rim(alb, wn, wp, cam));
}
