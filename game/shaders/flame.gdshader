shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// A small candle flame (world/lantern_post.gd): a camera-facing teardrop (turns about Y
// only, so it stays upright), blue at the root, a pale core, an orange skin, licking and
// leaning as it flickers. `lit` 0..1 fades it out.
uniform float lit = 0.0;

void vertex() {
	// face the camera round the local Y axis
	vec3 to_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(0.0001, 0.0, 0.0));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	VERTEX = right * VERTEX.x + vec3(0.0, VERTEX.y, 0.0);
}

void fragment() {
	float t = TIME;
	vec2 uv = UV;                     // (0,0) top-left
	float y = 1.0 - uv.y;             // 0 root .. 1 tip
	float lean = (sin(t * 5.3) * 0.5 + sin(t * 11.7) * 0.3) * 0.06 * y * y;
	float x = (uv.x - 0.5 - lean) * 2.0;
	// teardrop: widest a third of the way up, a rounded root, a pointed lick of a tip
	float stretch = 1.0 + 0.12 * sin(t * 9.0 + 1.3) * sin(t * 4.1);
	float yy = y / stretch;
	float wdt = mix(0.55, 0.0, smoothstep(0.32, 1.0, yy)) + smoothstep(0.32, 0.0, yy) * -0.1;
	wdt *= smoothstep(-0.05, 0.12, yy);
	float d = abs(x) / max(wdt, 0.001);
	float body = (1.0 - smoothstep(0.55, 1.0, d)) * step(yy, 1.0);
	float core = (1.0 - smoothstep(0.0, 0.6, d)) * smoothstep(0.05, 0.2, yy) * (1.0 - smoothstep(0.35, 0.75, yy));
	float root = smoothstep(0.25, 0.0, yy);
	vec3 col = mix(vec3(1.0, 0.42, 0.08), vec3(1.0, 0.75, 0.35), smoothstep(0.0, 0.6, 1.0 - d));
	col = mix(col, vec3(1.0, 0.95, 0.82), core);
	col = mix(col, vec3(0.15, 0.25, 0.9), root * 0.7);
	ALBEDO = col * body * lit * 3.0;
}
