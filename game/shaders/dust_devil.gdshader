shader_type spatial;
// A dust devil (dust_devils.gd): a skirt of dust rolling out over the grass at the foot, a
// narrow spinning funnel that widens and frays with height and leans behind its drift, and
// straw flecks whirled up it. Soft lit billboards, faded where they meet the ground.
// INSTANCE_CUSTOM: r = start angle, g = height/age phase 0..1, b = radius share, a = kind
// (< 0.25 skirt dust, < 0.75 funnel dust, above a fleck).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float height = 11.0;
uniform float env = 1.0;                  // 0 nothing .. 1 a full whirl
uniform vec2 tilt = vec2(0.0);            // m sideways per m up (the top lags the foot)
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float light = 1.0;
uniform float seed = 0.0;
uniform vec3 dust : source_color = vec3(0.62, 0.55, 0.44);
uniform vec3 straw : source_color = vec3(0.50, 0.42, 0.27);
uniform vec3 soil : source_color = vec3(0.40, 0.33, 0.24);   // the dense skirt: dry earth, not mist
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying float v_alpha;
varying vec3 v_col;
varying float v_kind;
varying float v_id;

void vertex() {
	float kind = INSTANCE_CUSTOM.a;
	float b = INSTANCE_CUSTOM.b;
	float H = height * mix(0.35, 1.0, env);          // the column builds and slumps
	float h;
	float r;
	float size;
	float a0 = INSTANCE_CUSTOM.r;
	float alpha;
	float f;
	if (kind < 0.25) {
		// skirt: dust rolled out of the foot, low, spreading as it ages
		f = fract(INSTANCE_CUSTOM.g + TIME * 0.35 + seed);
		r = mix(0.5, 3.6 + 1.8 * b, f);
		h = 0.2 + 1.6 * f * b;
		size = mix(1.0, 2.6, f);
		alpha = 0.34 * smoothstep(0.0, 0.12, f) * pow(1.0 - f, 0.7);
	} else if (kind < 0.75) {
		// funnel: dust spun up the column, most of it low; the funnel flares near the top
		f = fract(INSTANCE_CUSTOM.g + TIME * 0.22 + seed * 0.37);
		h = H * pow(f, 1.6);
		float t = h / max(H, 0.01);
		// a dense, opaque throat in the bottom metres, a wide frayed bowl at the top
		r = (0.6 + 3.4 * pow(t, 1.3)) * (0.55 + 0.6 * b);
		size = mix(0.9, 2.8, t);
		alpha = mix(0.34, 0.14, t) * smoothstep(0.0, 0.06, f) * pow(1.0 - t, 0.6);
	} else {
		// flecks: straw and leaf bits riding the whole height
		f = fract(INSTANCE_CUSTOM.g + TIME * 0.16 + seed * 0.61);
		h = H * 1.05 * f;
		float t = h / max(H, 0.01);
		r = (0.7 + 3.0 * t) * (0.6 + 0.6 * b);
		size = mix(0.035, 0.07, fract(kind * 13.7));
		alpha = 0.95 * smoothstep(0.0, 0.05, f) * (1.0 - smoothstep(0.8, 1.0, f));
	}
	float omega = 4.5 / max(r, 0.6);                  // faster near the core
	float a = a0 + TIME * omega + sin(TIME * 2.3 + a0 * 3.0) * 0.15;
	float wob = sin(TIME * 1.3 + h * 0.4 + seed) * 0.12 * h;   // the funnel snakes as it rises
	vec3 local = vec3(cos(a) * r + tilt.x * h + wob, h, sin(a) * r + tilt.y * h + wob * 0.6);
	vec3 centre = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	vec3 view = normalize(centre - CAMERA_POSITION_WORLD);
	// lit by hand: shade side vs sun side of the column, and dust glows with the sun behind it
	float side = 0.5 + 0.5 * dot(normalize(vec3(cos(a), 0.3, sin(a))), sun_dir);
	float back = pow(max(dot(view, sun_dir), 0.0), 4.0);
	vec3 base = kind < 0.25 ? soil : (kind < 0.75 ? mix(soil, dust, smoothstep(0.0, 2.5, h)) : straw);
	v_col = base * (0.42 + light * (0.45 + 0.4 * side)) + vec3(1.0, 0.9, 0.7) * back * light * (kind < 0.75 ? 0.45 : 0.15);
	v_alpha = alpha * env;
	v_kind = kind;
	v_id = a0;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(centre, 1.0));
	VERTEX *= size;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d2 = dot(q, q);
	if (d2 > 1.0) discard;
	float a;
	if (v_kind < 0.75) {
		// a ragged soft puff, not a disc
		float n = vnoise(UV * 4.0 + v_id * 7.0 + TIME * 0.3) * 0.6 + vnoise(UV * 9.0 - v_id * 3.0) * 0.4;
		a = smoothstep(1.0, 0.1, d2) * smoothstep(0.25, 0.75, n);
		// soft where the puff cuts into the ground and the grass
		float dz = texture(depth_tex, SCREEN_UV).r;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
		float scene = -vp.z / vp.w;
		a *= clamp((scene + VERTEX.z) / 0.6, 0.0, 1.0);
	} else {
		a = step(d2, 0.7);
	}
	ALBEDO = v_col;
	ALPHA = clamp(v_alpha * a, 0.0, 1.0);
}
