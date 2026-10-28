shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, skip_vertex_transform, fog_disabled;
// The warm smear a moth leaves in the candle's light over one frame's exposure (MothStreaks):
// at 3 m a 4 cm moth is a few pixels, but the eye (and a film camera) reads its dash of
// lit scales as a short bright streak. One quad per moth, stretched along the instance's z
// column (the tail vector, length = speed x shutter) and turned to face the camera.
// INSTANCE_CUSTOM: r = scale brightness (pale ermine flares), a = half span (m).

uniform vec3 lamp_pos;
uniform float lamp_lit = 0.0;

varying float v_t;
varying float v_x;
varying float v_glow;

void vertex() {
	vec3 head = MODEL_MATRIX[3].xyz;
	vec3 tail = MODEL_MATRIX[2].xyz;
	float span = INSTANCE_CUSTOM.a;
	// 0 just ahead of the head .. 1 the end of the smear
	v_t = VERTEX.y + 0.5;
	v_x = VERTEX.x * 2.0;
	vec3 to_cam = CAMERA_POSITION_WORLD - head;
	vec3 dir = length(tail) > 0.001 ? tail : vec3(0.0, -0.001, 0.0);
	vec3 side = cross(dir, to_cam);
	side = length(side) > 1e-6 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	vec3 w = head + dir * (v_t * 1.1 - 0.1) + side * v_x * span * 0.55;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
	float d = length(head - lamp_pos);
	v_glow = lamp_lit * INSTANCE_CUSTOM.r / (1.0 + d * d * 9.0);
}

void fragment() {
	float across = 1.0 - v_x * v_x;
	float along = clamp(1.0 - v_t, 0.0, 1.0);
	along = along * along * smoothstep(0.0, 0.12, v_t + 0.02);
	ALBEDO = vec3(1.0, 0.62, 0.30) * v_glow * across * along * 0.85;
}
