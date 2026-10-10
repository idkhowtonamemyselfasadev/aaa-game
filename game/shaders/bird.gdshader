shader_type spatial;
render_mode cull_disabled;
// Rooks and kites built by birds.gd. The wings, legs and head are posed here per instance:
// INSTANCE_CUSTOM = (wing flap angle rad, leg extension 0..1, head pitch rad, wing fold 0..1).
// Mesh COLOR: r = span (0 shoulder .. 1 wing tip), g = 1 right wing / 0.5 left wing / 0 body,
// b = beak mask, a = leg mask.

uniform vec3 plumage : source_color = vec3(0.035, 0.034, 0.038);
uniform vec3 sheen : source_color = vec3(0.035, 0.03, 0.06);
uniform vec3 beak_col : source_color = vec3(0.55, 0.52, 0.47);
uniform vec3 bar_col : source_color = vec3(0.025, 0.025, 0.03);   // wing/tail bars (kites)
uniform float roughness = 0.42;

varying vec3 v_col;
varying vec3 v_local;

vec3 rot_z(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c - p.y * s, p.x * s + p.y * c, p.z); }
vec3 rot_y(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c); }
vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c); }

void vertex() {
	vec4 ic = INSTANCE_CUSTOM;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	if (COLOR.g > 0.25) {
		float side = COLOR.g > 0.75 ? 1.0 : -1.0;
		vec3 sh = vec3(0.035 * side, 0.155, -0.04);
		vec3 p = v - sh;
		float span = COLOR.r;
		float fold = ic.w;
		// fold: hand tucks (shorter), wing sweeps back along the body and turns vertical
		p.x *= 1.0 - 0.45 * fold * span;
		p = rot_y(p, -side * fold * 1.45);
		n = rot_y(n, -side * fold * 1.45);
		p = rot_z(p, side * fold * 1.25);
		n = rot_z(n, side * fold * 1.25);
		// flap: the outer wing lags/leads the arm a little so the wing bends, not a flat plank
		float a = ic.x * (0.75 + 0.55 * span) * side * (1.0 - fold);
		p = rot_z(p, a);
		n = rot_z(n, a);
		v = sh + p - vec3(0.0, 0.01, 0.0) * fold;
	}
	if (COLOR.a > 0.5) {
		// legs tuck up under the tail in flight
		v.y = mix(0.10, v.y, ic.y);
		v.z += (1.0 - ic.y) * 0.06;
	}
	float head = smoothstep(-0.07, -0.11, VERTEX.z) * (1.0 - step(0.25, COLOR.g));
	if (head > 0.0) {
		vec3 piv = vec3(0.0, 0.15, -0.075);
		vec3 hp = rot_x(v - piv, -ic.z);
		v = mix(v, piv + hp, head);
		n = mix(n, rot_x(n, -ic.z), head);
	}
	VERTEX = v;
	NORMAL = normalize(n);
	v_col = COLOR.rgb;
	v_local = VERTEX;
}

void fragment() {
	// feather streaks along the body/wing: slight value breakup so the black is not flat
	float streak = sin(v_local.x * 220.0 + sin(v_local.z * 90.0) * 2.0) * 0.5 + 0.5;
	float tipbar = smoothstep(0.75, 0.9, v_col.r) * step(0.25, v_col.g);
	vec3 col = plumage * mix(0.8, 1.2, streak);
	col = mix(col, bar_col, tipbar);
	col = mix(col, beak_col, v_col.b);
	ALBEDO = col;
	// oily blue-violet gloss of rook plumage: tinted spec via a little emission-free rim
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO += sheen * rim * (1.0 - v_col.b);
	ROUGHNESS = mix(roughness, 0.5, v_col.b);
	SPECULAR = 0.55;
	BACKLIGHT = col * 0.25 * step(0.25, v_col.g);
}
