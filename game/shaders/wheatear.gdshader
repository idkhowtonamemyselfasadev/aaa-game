shader_type spatial;
render_mode cull_disabled;
// The fold's wheatears (wheatears.gd): Birds' rook mesh at a third of the size, posed like
// bird.gdshader but through instance uniforms (pose = wing flap rad, leg extension, head pitch
// rad, wing fold), with a wheatear's plumage painted from the mesh's own geometry: ash-grey
// back, black mask under a white brow, apricot throat and breast fading to a white belly,
// black wings, the white rump and the black inverted T of the tail. `hen` 0 is the cock; 1 the
// hen (brown back, brown cheek, buff brow); above 1 a paler, scalier youngster.

instance uniform vec4 pose = vec4(0.0, 1.0, 0.0, 1.0);
instance uniform float hen = 0.0;

varying vec3 v_col;
varying vec3 v_local;
varying vec3 v_nrm;
varying float v_leg;

vec3 rot_z(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c - p.y * s, p.x * s + p.y * c, p.z); }
vec3 rot_y(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c); }
vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c); }

void vertex() {
	vec4 ic = pose;
	v_nrm = NORMAL;
	v_leg = COLOR.a;
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
		// a passerine's closed wing is a narrow blade along the flank, not a rook's sheet to the feet
		p.z *= 1.0 - 0.5 * fold;
		p = rot_y(p, -side * fold * 1.45);
		n = rot_y(n, -side * fold * 1.45);
		p = rot_z(p, side * fold * 1.25);
		n = rot_z(n, side * fold * 1.25);
		// flap: the outer wing lags/leads the arm a little so the wing bends, not a flat plank
		float a = ic.x * (0.75 + 0.55 * span) * side * (1.0 - fold);
		p = rot_z(p, a);
		n = rot_z(n, a);
		v = sh + p - vec3(0.0, 0.01, 0.0) * fold;
		// the shoulder sits inside the body loft: lay the folded wing out on the flank, the tips
		// closing in over the rump as the body narrows to the tail root
		v.x += side * fold * mix(0.03, 0.012, smoothstep(0.02, 0.17, v.z));
	}
	// the tail: a wider fan with a shallow tent down its middle, so it reads edge-on too
	if (COLOR.g < 0.25 && COLOR.b < 0.5 && VERTEX.z > 0.099 && VERTEX.y < 0.14 && COLOR.a < 0.5) {
		float tz = smoothstep(0.10, 0.27, VERTEX.z);
		v.x *= 1.0 + 0.4 * tz;
		v.y -= abs(v.x) * 0.3 * tz;
	}
	if (COLOR.a > 0.5) {
		// legs tuck up under the tail in flight
		v.y = mix(0.10, v.y, ic.y);
		v.z += (1.0 - ic.y) * 0.06;
	}
	// a wheatear's fine bill, not a rook's dagger
	if (COLOR.b > 0.5) {
		v.z = -0.16 + (v.z + 0.16) * 0.35;
		v.y = 0.168 + (v.y - 0.168) * 0.7;
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
	vec3 p = v_local;
	vec3 n = normalize(v_nrm);
	float h = clamp(hen, 0.0, 1.0);
	float young = clamp(hen - 1.0, 0.0, 1.0) * 2.5;
	vec3 back = mix(vec3(0.47, 0.48, 0.5), vec3(0.5, 0.42, 0.33), h);
	vec3 breast = mix(vec3(0.86, 0.68, 0.50), vec3(0.80, 0.68, 0.53), h);
	vec3 belly = vec3(0.88, 0.85, 0.79);
	vec3 wing = mix(vec3(0.13, 0.12, 0.115), vec3(0.36, 0.29, 0.22), h);
	vec3 mask = mix(vec3(0.09, 0.085, 0.08), vec3(0.42, 0.33, 0.24), h);
	vec3 brow = mix(vec3(0.9, 0.9, 0.88), vec3(0.8, 0.72, 0.6), h);
	vec3 white = vec3(0.9, 0.89, 0.86);
	vec3 col;
	if (v_col.g > 0.25) {
		// wings: blackish with paler edges to the coverts and the inner trailing feathers
		col = wing * mix(1.0, 1.9 + h, smoothstep(0.03, 0.08, abs(p.z - 0.01)) * (1.0 - smoothstep(0.4, 0.6, v_col.r)) * 0.5);
	} else if (p.z > 0.095 && p.y < 0.14 && n.y > 0.5 && v_col.b < 0.5) {
		// the tail fan: white at the base, the black bar across the end and down the middle
		float u = abs(p.x) / max(0.063 * (p.z - 0.10) / 0.17, 0.004);
		float tbar = smoothstep(0.205, 0.215, p.z);
		float mid = 1.0 - smoothstep(0.18, 0.3, u);
		col = mix(white, wing, max(tbar, mid * smoothstep(0.12, 0.14, p.z)));
	} else {
		float up = smoothstep(-0.25, 0.35, n.y);
		col = mix(mix(belly, breast, 1.0 - smoothstep(-0.05, 0.08, p.z)), back, up);
		// the rump: the white band across the back over the tail root
		col = mix(col, white, smoothstep(0.075, 0.1, p.z) * smoothstep(0.0, 0.3, n.y));
		// the head: brow stripe over a dark mask through the eye, throat paler
		float head = 1.0 - smoothstep(-0.11, -0.085, p.z);
		float sidew = smoothstep(0.35, 0.7, abs(n.x));
		float ey = p.y - 0.183;
		float m = head * sidew * (1.0 - smoothstep(0.004, 0.012, abs(ey + 0.002)));
		float bw = head * smoothstep(0.2, 0.5, abs(n.x)) * smoothstep(0.004, 0.009, ey) * (1.0 - smoothstep(0.012, 0.018, ey));
		col = mix(col, mask, m * (1.0 - 0.3 * h));
		col = mix(col, brow, bw * (1.0 - 0.5 * h));
		col = mix(col, breast * 1.12, head * (1.0 - smoothstep(-0.6, -0.2, n.y)));
	}
	// feather texture: fine streaks along the body, a scaly wash on the young one
	float streak = sin(p.x * 260.0 + sin(p.z * 110.0) * 2.0) * 0.5 + 0.5;
	float scale = sin(p.z * 420.0) * sin(p.x * 380.0);
	col *= mix(0.94, 1.04, streak) * (1.0 - young * 0.12 * step(0.0, scale));
	col = mix(col, col * 1.12 + vec3(0.03, 0.02, 0.0), young * 0.5);
	col = mix(col, vec3(0.1, 0.1, 0.1), v_col.b);   // beak
	col = mix(col, vec3(0.1, 0.095, 0.09), step(0.5, v_leg));   // legs
	// the palette above is picked in sRGB; ALBEDO is linear
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = mix(0.7, 0.45, v_col.b);
	SPECULAR = 0.4;
	BACKLIGHT = pow(col, vec3(2.2)) * 0.3 * step(0.25, v_col.g);
}
