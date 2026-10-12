shader_type canvas_item;
// Final film grade over the tonemapped frame (display space, under the HUD):
// day: Wukong-style split tone (cool teal-grey shadows, warm amber highlights, mids a touch
// muted); night: scotopic vision (rods see no colour and peak in the blue-green), so a
// moonlit meadow goes blue-grey while bright things (fireflies, fire, lanterns) keep their
// colour; overcast drains further; then a soft vignette and animated film grain.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float night : hint_range(0.0, 1.0) = 0.0;     // 0 day .. 1 deep night
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float grain_amount = 0.045;
uniform float vignette = 0.28;
uniform float strength : hint_range(0.0, 1.0) = 1.0;  // quality / accessibility switch

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec3 src = texture(screen_tex, SCREEN_UV).rgb;
	vec3 c = src;
	float L = dot(c, vec3(0.2126, 0.7152, 0.0722));

	// day split tone
	float hw = smoothstep(0.05, 0.85, L);
	vec3 tint = mix(vec3(0.95, 1.0, 1.035), vec3(1.035, 1.0, 0.94), hw);
	vec3 day = mix(vec3(L), c * tint, mix(0.94, 0.85, overcast));

	// night: rod vision. Only what is dim loses colour; the colour that remains is blue.
	float rod = 1.0 - smoothstep(0.2, 0.65, L);
	vec3 scot = vec3(L * 1.08) * vec3(0.7, 0.86, 1.15);
	vec3 nc = mix(c, scot, rod * 0.88);
	// moonlit midnight-blue floor and a gentle lift so silhouettes still read
	nc = pow(max(nc, vec3(0.0)), vec3(0.9)) + vec3(0.006, 0.010, 0.020) * (1.0 - L);

	c = mix(day, nc, night);

	// vignette
	vec2 d = SCREEN_UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r2 = dot(d, d);
	c *= 1.0 - vignette * smoothstep(0.08, 0.75, r2);

	// film grain: two scales (pixel + a 2 px clump), strongest in the mid-tones,
	// a little heavier at night (faster stock), new every frame
	vec2 px = SCREEN_UV / SCREEN_PIXEL_SIZE;
	float fr = floor(TIME * 24.0);
	float g = hash12(px + fr * 37.13) - 0.5;
	g = g * 0.7 + (hash12(floor(px * 0.5) + fr * 11.7 + 91.0) - 0.5) * 0.6;
	float Lc = dot(c, vec3(0.2126, 0.7152, 0.0722));
	float mid = clamp(4.0 * Lc * (1.0 - Lc) + 0.25, 0.0, 1.0);
	c += g * grain_amount * mix(1.0, 1.5, night) * mid;

	COLOR = vec4(mix(src, clamp(c, 0.0, 1.0), strength), 1.0);
}
