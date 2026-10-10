// Shared tree wind: bark and leaves must move identically or leaves detach from twigs.
// COLOR.r = sway weight (0 trunk base .. 1 twig tip). Same wind_dir as the grass.
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind_sway = 0.22;

vec3 tree_wind(vec3 local_v, float sway, mat4 model, float t) {
	vec3 origin = model[3].xyz;
	vec2 wd = normalize(wind_dir);
	// gust envelope travels across the vale with the grass gusts
	float g = sin(dot(origin.xz, wd) * 0.05 - t * 0.9) * 0.5 + 0.5;
	float sway2 = sway * sway;
	float main = (0.55 + 0.45 * sin(t * 0.8 + origin.x * 0.13)) * (0.4 + g);
	float sec = sin(t * 2.1 + origin.z * 0.31 + local_v.y * 0.4) * 0.25;
	vec3 w = vec3(wd.x, 0.0, wd.y) * wind_sway * sway2 * (main + sec);
	w.y -= length(w) * 0.25;
	return inverse(mat3(model)) * w;
}
