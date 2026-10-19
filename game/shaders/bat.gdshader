shader_type spatial;
render_mode cull_disabled;
// The pipistrelle's wings (bat.gd): one PlaneMesh (x -1..1 across the span, z -0.6 front ..
// 0.6 back, hinged at x = 0), bent at the elbow (|x| 0.38) and the wrist (|x| 0.62). The
// downstroke sweeps the whole arm down; on the upstroke the hand folds at the wrist so the
// tips trail. Membrane outline (scalloped between the fingers, a tail membrane between the
// legs), finger bones and the thin dark skin that glows where the candle is behind it.

uniform float half_span = 0.12;
uniform float flap = 0.0;       // beat phase, rad
uniform float amp = 1.0;        // 1 full beat .. ~0.2 a glide
uniform float snap = 0.0;       // 1 at the scoop of a catch: wings flung forward and down
uniform vec3 lamp_pos;
uniform float lamp_lit = 0.0;

varying vec3 v_world;

void vertex() {
	float side = sign(VERTEX.x);
	float u = abs(VERTEX.x);
	float z = VERTEX.z;
	float s = sin(flap);
	// shoulder: up 55 deg .. down 50 deg; the hand lags the arm and folds on the upstroke
	float a1 = (0.05 + 0.9 * s) * amp - snap * 0.8;
	float fold = (0.5 + 0.5 * cos(flap)) * amp;            // high on the upstroke
	float a2 = a1 + (0.15 + 0.35 * sin(flap - 0.9)) * amp - snap * 0.4;
	float a3 = a2 + 0.25 * amp * sin(flap - 1.6);
	float e = 0.38, w = 0.62;
	float l1 = min(u, e);
	float l2 = clamp(u - e, 0.0, w - e);
	float l3 = max(u - w, 0.0);
	// the hand pulls in toward the body as it folds (shortened span on the upstroke)
	l3 *= 1.0 - 0.35 * fold;
	l2 *= 1.0 - 0.12 * fold;
	vec2 p = vec2(l1 * cos(a1), l1 * sin(a1));
	p += vec2(l2 * cos(a2), l2 * sin(a2));
	p += vec2(l3 * cos(a3), l3 * sin(a3));
	// the tips sweep forward on the downstroke and trail on the upstroke
	z += (0.10 * s - 0.08 * fold) * smoothstep(0.3, 1.0, u) * amp - snap * 0.25 * u;
	// the membrane bellies up between the bones under load
	float belly = (1.0 - abs(VERTEX.z) / 0.6) * smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.8, 1.0, u));
	p.y += belly * 0.05 * (0.5 - 0.5 * s);
	VERTEX = vec3(side * p.x, p.y, z) * half_span;
	NORMAL = normalize(vec3(-side * sin(a2), cos(a2), 0.0));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5);
}

// trailing edge (v grows toward the back) between the anchor points, scalloped in between
float trail(float u) {
	// body/tail, foot, finger 5, finger 4, tip (finger 3)
	vec2 k0 = vec2(0.0, 0.98), k1 = vec2(0.17, 0.62), k2 = vec2(0.46, 0.80), k3 = vec2(0.76, 0.50), k4 = vec2(1.0, -0.10);
	vec2 a = k0, b = k1;
	if (u > k1.x) { a = k1; b = k2; }
	if (u > k2.x) { a = k2; b = k3; }
	if (u > k3.x) { a = k3; b = k4; }
	float t = clamp((u - a.x) / max(b.x - a.x, 1e-3), 0.0, 1.0);
	float dip = (u < k1.x ? 0.10 : 0.16) * sin(3.14159 * t);
	return mix(a.y, b.y, t) - dip;
}

void fragment() {
	// wing space: u 0 at the body .. 1 at the tip, v -1 front .. +1 back
	float u = abs(UV.x * 2.0 - 1.0);
	float v = UV.y * 2.0 - 1.0;
	vec2 p = vec2(u, v);
	// leading edge: the forearm straight out to the wrist, then the second finger to the tip
	float lead = u < 0.46 ? -0.42 + u * 0.05 : mix(-0.40, -0.13, (u - 0.46) / 0.54);
	float te = trail(u);
	float body = step(u, 0.06) * step(-0.55, v) * step(v, 0.9);
	float inside = step(lead, v) * step(v, te);
	ALPHA = max(inside, body) * step(u, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	// bones: forearm, fingers 3/4/5 fanning from the wrist, the hind leg out to the foot
	vec2 wr = vec2(0.46, -0.40);
	float bones = min(seg(p, vec2(0.04, -0.40), wr), seg(p, wr, vec2(1.0, -0.12)));
	bones = min(bones, seg(p, wr, vec2(0.76, 0.50)));
	bones = min(bones, seg(p, wr, vec2(0.46, 0.80)));
	bones = min(bones, seg(p, vec2(0.05, 0.25), vec2(0.17, 0.62)));
	float bone = 1.0 - smoothstep(0.012, 0.024, bones);
	// thin skin: dark brown-black, wrinkled across the chord, paler and thinner near the edge
	float wr_l = 0.5 + 0.5 * sin((v * 70.0 + u * 8.0) + sin(u * 23.0) * 1.5);
	float edge = smoothstep(0.10, 0.0, min(te - v, v - lead));
	vec3 skin = vec3(0.075, 0.052, 0.042) * (0.85 + 0.25 * wr_l) * (0.9 + 0.2 * h21(floor(p * 90.0)));
	skin = mix(skin, vec3(0.11, 0.075, 0.06), edge * 0.6);
	vec3 col = mix(skin, vec3(0.13, 0.095, 0.075), bone);
	if (body > 0.5) { col = vec3(0.20, 0.14, 0.10) * (0.8 + 0.4 * h21(floor(p * 120.0))); }
	ALBEDO = col;
	ROUGHNESS = mix(0.55, 0.9, bone);
	SPECULAR = 0.35;
	// the candle through the membrane: red-orange where it is thin, the bones dark against it
	BACKLIGHT = vec3(0.9, 0.32, 0.12) * (1.0 - bone * 0.8) * (0.6 + 0.4 * edge);
	float d = length(v_world - lamp_pos);
	EMISSION = col * vec3(1.0, 0.6, 0.3) * lamp_lit * 0.6 / (1.0 + d * d * 8.0);
}
