shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// A lightning channel (world/lightning.gd). The mesh is a camera-facing ribbon along the
// jagged channel and its branches; UV.x runs across the ribbon, COLOR.a is the branch's
// strength. A white-hot core inside a violet-blue glow, added over the flash-lit deck (an
// alpha-blended bolt read darker than the sky it lit). Kept moderate: the softlight glow
// blend works on HDR colour, c + glow * (sqrt(c) - c), so a strongly blooming pixel goes
// black (the first, ~10x bolts drew as dark dashes).
// Fog is off (a far bolt would vanish in the rain haze), so the rain's veil is `veil` instead.

uniform float brightness = 0.0;     // the flash envelope (return strokes flicker it)
uniform float veil = 1.0;           // 1 clear .. ~0.3 behind heavy rain at a few km
uniform vec3 core_col : source_color = vec3(0.92, 0.94, 1.0);
uniform vec3 glow_col : source_color = vec3(0.55, 0.6, 1.0);

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float core = exp(-x * x * 22.0);
	float glow = exp(-x * x * 3.0) * 0.3;
	float s = COLOR.a * brightness * veil;
	ALBEDO = (core_col * core * 1.6 + glow_col * glow * 0.9) * s;
	ALPHA = 1.0;
}
