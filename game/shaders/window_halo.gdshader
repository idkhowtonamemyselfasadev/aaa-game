shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// The warm bloom of a lit cottage window seen from across the Vale (world/stone_cottage.gd).
// Close to, the pane's own emission (pane.gdshader) is the light; past ~35 m a window is a
// pixel or two and its lamp vanished, so a soft camera-facing glow fades in round it,
// growing with distance so it keeps a few pixels of halo, pulled toward the lens so the
// wall and sill never cut it, and only on the side the window faces. The night air dims it
// with distance like the fog would.
uniform float lit = 0.0;
uniform vec3 lamp : source_color = vec3(1.0, 0.58, 0.28);
instance uniform vec3 out_dir = vec3(0.0, 0.0, 1.0);   // the window's outward normal, the house's space

varying float v_k;

void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - c;
	float d = length(to_cam);
	vec3 v = to_cam / max(d, 0.001);
	float facing = smoothstep(-0.05, 0.35, dot(normalize(mat3(MODEL_MATRIX) * out_dir), v));
	float far_in = smoothstep(30.0, 90.0, d);
	// a few pixels of halo at any range: ~0.9 m across at 40 m, ~3.5 m at 250 m
	float size = clamp(d * 0.014, 0.5, 4.5);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), v));
	vec3 up = cross(v, right);
	vec3 p = c + v * min(2.5, d * 0.5) + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
	// night haze over the valley floor eats the far ones a little
	v_k = lit * facing * far_in * exp(-d * 0.0022);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	// a tight hot core and a broad soft skirt
	float g = exp(-r * r * 18.0) * 1.6 + exp(-r * r * 4.0) * 0.35;
	g *= 1.0 - smoothstep(0.85, 1.0, r);
	ALBEDO = lamp * g * v_k * 1.4;
	ALPHA = 1.0;
}
