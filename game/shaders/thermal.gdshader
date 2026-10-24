shader_type spatial;
// Chaff and thistle-down carried up a thermal (thermals.gd): each instance spirals up the
// column on its own radius and phase, leaning downwind with height, and only catches the eye
// as a sunlit glint, brightest with the sun behind it. The instance transforms are identity;
// INSTANCE_CUSTOM: r = start angle, g = height phase 0..1, b = radius share, a = kind.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float radius = 9.0;              // core radius at the ground (m)
uniform float top = 75.0;                 // the column dies here (m above the ground)
uniform float strength = 1.0;
uniform vec2 lean = vec2(0.1, 0.07);      // m sideways per m up (downwind)
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float light = 1.0;
uniform float seed = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.9, 0.7);
uniform float min_px_angle = 0.0018;

varying float v_int;

void vertex() {
	float kind = INSTANCE_CUSTOM.a;
	float rise = mix(1.1, 2.2, fract(kind * 7.31));                  // m/s
	float span = top * 0.62;
	float f = fract(INSTANCE_CUSTOM.g + TIME * rise / span + seed);
	float h = span * pow(f, 1.5) + 0.3;                               // thick low, thin high
	float r = radius * INSTANCE_CUSTOM.b * (1.0 + h / top * 0.6) * 0.85;
	float a = INSTANCE_CUSTOM.r + TIME * (0.9 / max(r, 1.5)) * 2.2 + sin(TIME * 0.7 + kind * 20.0) * 0.2;
	vec3 local = vec3(cos(a) * r + lean.x * h, h + sin(TIME * 1.9 + kind * 31.0) * 0.25,
		sin(a) * r + lean.y * h);
	vec3 centre = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	float base = mix(0.024, 0.06, step(0.85, kind));                 // chaff .. leaf flecks
	float dist = length(centre - CAMERA_POSITION_WORLD);
	float size = max(base, dist * min_px_angle);
	vec3 view = normalize(centre - CAMERA_POSITION_WORLD);
	float back = pow(max(dot(view, sun_dir), 0.0), 6.0);
	v_int = light * (0.35 + back * 4.0) * min(1.0, pow(base / size, 1.2));
	v_int *= smoothstep(0.0, 0.06, f) * (1.0 - smoothstep(0.7, 1.0, f));
	v_int *= smoothstep(0.05, 0.4, strength);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(centre, 1.0));
	VERTEX *= size;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d2 = dot(q, q);
	if (d2 > 1.0) discard;
	float core = exp(-d2 * 9.0) + 0.2 * exp(-d2 * 3.0) * (1.0 - d2);
	ALBEDO = tint * v_int * core;
}
