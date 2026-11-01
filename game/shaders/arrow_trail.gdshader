shader_type spatial;
// Arrow flight streak: a thin, camera-facing ribbon of disturbed air behind a loosed arrow.
// UV.x = age (0 newest .. 1 oldest), UV.y = across the ribbon (0 .. 1). Soft on both edges,
// densest just behind the fletching, gone after a few metres; pale grey, never glowing.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.86, 0.85, 0.80);
uniform float strength = 0.42;

void fragment() {
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float a = COLOR.a * pow(across, 1.8) * strength;
	a *= pow(1.0 - UV.x, 1.4);
	ALBEDO = tint;
	ALPHA = clamp(a, 0.0, 1.0);
}
