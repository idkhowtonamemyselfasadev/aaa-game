shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
// Rain streaks for the Weather particles. Each particle's Y axis is aligned to its velocity
// (falling + wind slant); the quad is turned about that axis to face the camera, so a drop
// reads as a thin motion-blurred streak from any side. Streaks fade near the lens (no huge
// smears across the screen) and with distance (they thin into the fog).

uniform float width = 0.009;
uniform float streak_len = 0.55;
uniform vec3 tint : source_color = vec3(0.62, 0.66, 0.72);
uniform float brightness = 1.0;     // set by weather.gd from the light level
uniform float opacity = 0.42;
#include "res://shaders/weather.gdshaderinc"

varying float v_fade;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - c;
	float d = length(to_cam);
	vec3 side = normalize(cross(up, to_cam / max(d, 0.001)));
	vec2 q = vec2(UV.x - 0.5, 0.5 - UV.y);
	// a little wider far away so distant rain still resolves as a veil, not aliasing
	float w = width * (1.0 + d * 0.05);
	VERTEX = c + side * q.x * w * 2.0 + up * q.y * streak_len;
	v_fade = smoothstep(0.6, 2.5, d) * (1.0 - smoothstep(18.0, 30.0, d));
	// below an oak's leaves the crown has caught most drops: only the leak falls through
	vec2 sh = shelter_sample(c.xz);
	v_fade *= 1.0 - sh.x * smoothstep(sh.y + 0.5, sh.y - 0.5, c.y);
}

void fragment() {
	// soft across the streak, tapered at both ends, brightest toward the leading end
	float across = 1.0 - abs(UV.x - 0.5) * 2.0;
	float along = smoothstep(0.0, 0.35, 1.0 - UV.y) * smoothstep(0.0, 0.15, UV.y);
	ALBEDO = tint * brightness;
	ALPHA = opacity * across * across * along * v_fade * COLOR.a;
}
