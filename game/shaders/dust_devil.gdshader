shader_type spatial;
// A dust devil (dust_devils.gd): a skirt of dust rolling out over the grass at the foot, a
// narrow spinning funnel that widens and frays with height and leans behind its drift, and
// straw flecks whirled up it. Soft lit billboards, faded where they meet the ground.
// INSTANCE_CUSTOM: r = start angle, g = height/age phase 0..1, b = radius share, a = kind
// (< 0.25 skirt dust, < 0.75 funnel dust, < 0.9 a straw fleck, above a dead leaf or chaff clump).
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
uniform vec3 leaf_dead : source_color = vec3(0.34, 0.22, 0.11);   // last year's oak leaves
uniform vec3 leaf_green : source_color = vec3(0.27, 0.30, 0.13);  // torn grass and fresh leaf
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying float v_alpha;
varying vec3 v_col;
varying float v_kind;
varying float v_id;
varying float v_t;               // height share up the column
varying float v_streak;          // how far this billboard is smeared along its spin (1 = round)

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
		// most puffs ride the outer wall (sqrt share), so the funnel keeps an edge up high
		r = (0.6 + 3.4 * pow(t, 1.3)) * mix(0.5, 1.15, sqrt(b));
		size = mix(0.9, 2.6, t);
		alpha = mix(0.34, 0.2, t) * smoothstep(0.0, 0.06, f) * (1.0 - smoothstep(0.82, 1.0, t));
	} else {
		// flecks: straw riding the whole height; leaves and chaff clumps, heavier, ride lower
		// and are flung out of the bowl near the top of their climb
		bool leaf = kind > 0.9;
		f = fract(INSTANCE_CUSTOM.g + TIME * (leaf ? 0.11 : 0.16) + seed * 0.61);
		h = H * (leaf ? 0.8 : 1.05) * f;
		float t = h / max(H, 0.01);
		r = (0.7 + 3.0 * t) * (0.6 + 0.6 * b) + (leaf ? smoothstep(0.65, 1.0, f) * 3.5 : 0.0);
		size = leaf ? mix(0.11, 0.22, fract(kind * 29.3)) : mix(0.05, 0.1, fract(kind * 13.7));
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
	// a leaf tumbles: face-on it is broad and catches the light, edge-on a dark sliver
	float tumble = abs(sin(TIME * (3.0 + 5.0 * fract(kind * 7.1)) + a0 * 5.0));
	float pick = fract(kind * 53.1);
	vec3 leafc = pick < 0.2 ? leaf_green : mix(leaf_dead, straw * 1.15, smoothstep(0.3, 1.0, pick));
	vec3 base = kind < 0.25 ? soil : (kind < 0.75 ? mix(soil, dust, smoothstep(0.0, 2.5, h)) : (kind > 0.9 ? leafc * mix(0.55, 1.1, tumble) : straw));
	v_col = base * (0.42 + light * (0.45 + 0.4 * side)) + vec3(1.0, 0.9, 0.7) * back * light * (kind < 0.75 ? 0.45 : 0.15);
	v_alpha = alpha * env;
	v_kind = kind;
	v_id = a0;
	// spin streaks: each billboard is drawn smeared along the way it is whirling (the tangent
	// of its circle, rising a little), so the funnel reads as spinning even in a still frame.
	// The smear shortens where the motion runs toward or away from the camera.
	vec3 tang = normalize(vec3(-sin(a), kind < 0.25 ? 0.05 : 0.22, cos(a)));
	vec3 ts = tang - view * dot(tang, view);
	float tl = length(ts);
	vec3 cam_r = INV_VIEW_MATRIX[0].xyz;
	vec3 sx = tl > 0.05 ? ts / tl : cam_r;
	vec3 sy = normalize(cross(view, sx));
	// funnel dust smears most in the tight, fast throat; flecks become thin streaks
	float t_h = h / max(H, 0.01);
	float smear = kind < 0.25 ? 1.25 : (kind < 0.75 ? mix(2.2, 1.3, t_h) : (kind > 0.9 ? 1.8 : 7.0));
	float thin = kind < 0.75 ? mix(0.75, 0.9, t_h) : (kind > 0.9 ? mix(0.15, 1.0, tumble) : 0.5);
	float stretch = mix(1.0, smear, tl * env);
	v_t = t_h;
	v_streak = kind < 0.75 ? stretch : 1.0 + (stretch - 1.0) * 0.5;
	vec3 wpos = centre + (sx * VERTEX.x * stretch + sy * VERTEX.y * thin) * size;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = wpos;
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
		// the noise is combed along the smear (UV.x runs with the spin), so a smeared puff
		// shows fine striations of dust dragged round the column rather than a blob
		float comb = v_streak;
		vec2 nu = vec2(UV.x * 4.0 / comb, UV.y * 4.0 * mix(1.0, 2.2, smoothstep(1.0, 2.0, comb)));
		float n = vnoise(nu + v_id * 7.0 + vec2(TIME * 0.9, 0.0)) * 0.6
			+ vnoise(vec2(UV.x * 9.0 / comb, UV.y * 9.0 * mix(1.0, 2.6, smoothstep(1.0, 2.0, comb))) - v_id * 3.0) * 0.4;
		// puffs high up get a firmer edge (a tighter noise threshold), so the bowl holds a shape
		float firm = v_kind < 0.25 ? 0.0 : smoothstep(0.3, 0.9, v_t) * 0.17;
		a = smoothstep(1.0, 0.1, d2) * smoothstep(0.25 + firm, 0.75 - firm, n);
		// a smeared puff thins toward its trailing end, the leading edge densest
		a *= mix(1.0, smoothstep(-0.2, 0.6, q.x + 0.4), smoothstep(1.2, 2.2, comb) * 0.6);
		// soft where the puff cuts into the ground and the grass
		float dz = texture(depth_tex, SCREEN_UV).r;
		vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, dz, 1.0);
		float scene = -vp.z / vp.w;
		a *= clamp((scene + VERTEX.z) / 0.6, 0.0, 1.0);
	} else if (v_kind > 0.9) {
		// a leaf or chaff clump: a ragged, notched blot, slightly blurred along its spin
		float edge = 0.85 - 0.35 * vnoise(UV * 5.0 + v_id * 11.0);
		a = smoothstep(edge, edge - 0.15, d2) * mix(1.0, smoothstep(-1.0, 0.3, q.x), smoothstep(1.0, 1.8, v_streak) * 0.5);
	} else {
		// a fleck streaks along its spin: bright head, fading tail
		a = step(d2, 0.7) * mix(1.0, smoothstep(-1.0, 0.6, q.x), smoothstep(1.0, 2.0, v_streak));
	}
	ALBEDO = v_col;
	ALPHA = clamp(v_alpha * a, 0.0, 1.0);
}
