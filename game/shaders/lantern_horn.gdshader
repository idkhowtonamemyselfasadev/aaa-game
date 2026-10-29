shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
// The lantern's horn panes (world/lantern_post.gd): thin scraped horn, cloudy amber with
// streaky laminations, sooted toward the top; by day a dull translucent honey, from dusk
// the candle inside glows through it, brightest level with the flame (UV.y ~0.72) and
// breathing with it (`lit` carries the flicker).
uniform float lit = 0.0;
uniform vec3 lamp : source_color = vec3(1.0, 0.62, 0.3);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	// laminations: streaks running across the pane, warped
	float w = vn(UV * vec2(3.0, 5.0)) * 2.0;
	float lam = vn(vec2(UV.x * 2.0 + w, UV.y * 26.0 + w * 3.0));
	float cloud = vn(UV * 9.0) * 0.5 + vn(UV * 23.0) * 0.25;
	float soot = smoothstep(0.45, 0.0, UV.y) * (0.6 + 0.4 * vn(UV * vec2(6.0, 3.0)));
	vec3 horn = mix(vec3(0.5, 0.36, 0.17), vec3(0.66, 0.52, 0.28), lam * 0.6 + cloud * 0.4);
	horn = mix(horn, vec3(0.05, 0.04, 0.03), soot * 0.75);
	ALBEDO = horn;
	ALPHA = mix(0.55, 0.92, soot) + lam * 0.05;
	ROUGHNESS = mix(0.35, 0.7, cloud);
	SPECULAR = 0.5;
	// candle glow through the horn, centred on the flame, a halo where the horn is clear
	vec2 c = UV - vec2(0.5, 0.74);
	float glow = exp(-dot(c * vec2(1.8, 2.2), c * vec2(1.8, 2.2)) * 3.0);
	// the laminations and clouding thin and thicken the light: at near-even 0.75-1.25 the lit
	// panes read as one flat white-orange slab, so the streaks swing it 0.35-1.45 and the
	// thick cloudy patches dim it and push it deeper amber
	float thick = cloud * 1.3;
	float thru = (0.3 + 0.7 * glow) * (1.0 - soot * 0.85) * (0.35 + 1.1 * lam) * (1.15 - 0.6 * thick);
	vec3 tint = mix(lamp, lamp * vec3(0.95, 0.62, 0.32), clamp(thick, 0.0, 1.0));
	EMISSION = tint * thru * lit * 1.9;
}
