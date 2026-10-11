shader_type spatial;
// Fireflies and sunlit midges: camera-facing additive glow dots on a MultiMesh.
// INSTANCE_CUSTOM: r = intensity, g = base size (m). Midge backlighting is done CPU-side.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 glow_color : source_color = vec3(0.78, 1.0, 0.32);
uniform float energy = 7.0;
uniform float min_px_angle = 0.0035;          // keeps far dots ~1.5 px instead of vanishing

varying float v_int;

void vertex() {
	v_int = INSTANCE_CUSTOM.r;
	vec3 centre = MODEL_MATRIX[3].xyz;
	float dist = length(centre - CAMERA_POSITION_WORLD);
	float size = max(INSTANCE_CUSTOM.g, dist * min_px_angle);
	// a dot that had to grow to stay visible gets dimmer by the same area ratio
	v_int *= min(1.0, pow(INSTANCE_CUSTOM.g / size, 1.2));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(centre, 1.0));
	VERTEX *= size;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d2 = dot(q, q);
	if (d2 > 1.0) discard;
	// hot core + soft halo, faded to zero at the quad edge
	float core = exp(-d2 * 14.0) + 0.28 * exp(-d2 * 3.5) * (1.0 - d2);
	ALBEDO = glow_color * energy * v_int * core;
}
