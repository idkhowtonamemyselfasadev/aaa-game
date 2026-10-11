// Meadow wind shared by flowers and the butterflies resting on them (same field as the
// grass in grass.gdshader: a slow swell + travelling gusts + flutter), evaluated at the
// plant's root so a whole flower sways as one and a perched butterfly rides its head.
// Returns the world-space offset of a point at height weight h (0 root .. 1 head).
float mw_h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float mw_n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mw_h21(i), mw_h21(i + vec2(1, 0)), f.x), mix(mw_h21(i + vec2(0, 1)), mw_h21(i + vec2(1, 1)), f.x), f.y);
}
#include "res://shaders/weather.gdshaderinc"
vec3 meadow_wind(vec3 root, float h, float t) {
	const vec2 wd = vec2(0.8, 0.6);
	float swell = sin(dot(root.xz, wd) * 0.05 - t * 0.9) * 0.5 + 0.5;
	float gust = smoothstep(0.35, 0.95, mw_n2(root.xz * 0.04 - wd * t * 1.6));
	// flower stems are stiffer than grass: about a third of the blade's bend
	float storm = clamp(weather_wind, 0.0, 1.0);
	float bend = (0.35 * swell + 0.55 * gust) * 0.32 * (1.0 + 1.1 * storm) * h * h;
	float flutter = sin(t * 6.0 + root.x * 3.1 + root.z * 1.7) * 0.012 * (1.0 + 2.0 * storm) * h;
	float nod = sin(t * 2.3 + root.z * 2.7) * 0.006 * h;
	return vec3(wd.x * bend + flutter, -bend * 0.3, wd.y * bend + nod);
}
