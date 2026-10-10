shader_type spatial;
// Staff swing trail: a short-lived ribbon from the tip down the shaft. Densest at the tip
// edge (UV.y = 0) and the newest sample (UV.x = 0); a pale-gold smear of disturbed air.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength = 0.6;

void fragment() {
	float age = UV.x;
	float edge = pow(1.0 - UV.y, 1.6);
	float a = COLOR.a * edge * strength;
	// thin streaks along the arc
	a *= 0.7 + 0.3 * sin(UV.y * 48.0 + age * 5.0);
	ALBEDO = tint;
	ALPHA = clamp(a, 0.0, 1.0);
}
