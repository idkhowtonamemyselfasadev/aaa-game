shader_type spatial;
// Staff swing trail: a short-lived ribbon from the tip down the shaft. Densest at the tip
// edge (UV.y = 0) and the newest sample (UV.x = 0); a pale-gold smear of disturbed air.
// Seen edge-on (front-on to a blow in the view's plane) the ribbon collapses to a thin
// striped band that read as a light shaft hanging in the air, so it fades out as it turns
// edge-on to the camera (face normal from screen derivatives: the ImmediateMesh has none).
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength = 0.45;
uniform float edge_fade = 1.0;
uniform float age_curve = 1.0;
uniform float streak = 0.3;
uniform float soft_tip = 1.0;

void fragment() {
	float age = UV.x;
	// densest just inside the tip edge, soft at the very tip too (a hard outer edge drew the
	// ribbon as a ruled band of light in a still)
	float edge = pow(1.0 - UV.y, 1.6) * mix(1.0, smoothstep(0.0, 0.18, UV.y) * 1.35, soft_tip);
	// (11-21) older samples fade on a square, not a line: the tip of a jump attack falls 2 m in
	// 0.1 s and the linear fade held that whole run as a solid band (a light shaft in a still)
	float life = mix(COLOR.a, COLOR.a * COLOR.a, age_curve);
	float a = life * edge * strength;
	// thin streaks along the arc (0.6 = the old 0.4..1 depth; 0.3 keeps them from reading as rays)
	a *= 1.0 - streak * (0.5 - 0.5 * sin(UV.y * 48.0 + age * 5.0));
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	float facing = abs(dot(fn, normalize(VIEW)));
	a *= mix(1.0, smoothstep(0.2, 0.6, facing), edge_fade);
	ALBEDO = tint;
	ALPHA = clamp(a, 0.0, 1.0);
}
