shader_type spatial;
render_mode cull_back;
// The carved lid over the Shrine of Binding (ShrineSeal). Dark weathered greystone; the top
// is cut with a sigil -- an outer ring of notches, eight twisted binding cords running in
// from it to a centre ring knotted with a cross -- worn shallow and half filled with grit
// and moss. Ember light breathes in the clean stretches of groove (`wake` 0..1 from
// ShrineSeal: the hero's nearness), pulsing inward along the cords.

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
#include "res://shaders/bounce.gdshaderinc"
uniform float wake = 0.0;
uniform vec3 stone_a : source_color = vec3(0.42, 0.4, 0.36);
uniform vec3 stone_b : source_color = vec3(0.27, 0.26, 0.24);
uniform vec3 moss_a : source_color = vec3(0.3, 0.34, 0.12);
uniform vec3 ember : source_color = vec3(1.0, 0.42, 0.12);

varying vec3 lp;
varying vec3 ln;
varying vec3 wp;
varying float v_cloud;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = p * 2.07 + 5.3; a *= 0.5; } return r; }

float groove(float d, float w) { return 1.0 - smoothstep(w * 0.4, w, d); }

// the sigil's cut depth 0..1 at lid-top point q (m from the centre); cords = mask of the
// cord strands only (where the ember pulse travels)
float sigil(vec2 q, out float cords) {
	float r = length(q);
	float a = atan(q.y, q.x);
	float g = 0.0;
	g = max(g, groove(abs(r - 0.70), 0.014));
	g = max(g, groove(abs(r - 0.66), 0.008));
	g = max(g, groove(abs(r - 0.30), 0.014));
	g = max(g, groove(abs(r - 0.13), 0.011));
	// notches round the outer band, every fourth one a longer stroke
	float na = fract(a * 32.0 / TAU + 0.5) - 0.5;
	float nd = abs(na) * TAU / 32.0 * r;
	float k = floor(a * 32.0 / TAU + 0.5);
	float len = mod(k, 4.0) < 0.5 ? 0.075 : 0.035;
	g = max(g, groove(nd, 0.008) * step(0.715, r) * step(r, 0.72 + len));
	// eight cords: two strands twisting round each other, swaying a little along their run
	float ca = a * 8.0 / TAU + 0.15 * sin(r * 11.0);
	float f = (fract(ca + 0.5) - 0.5) * TAU / 8.0 * r;
	float tw = 0.016 * sin(r * 70.0);
	float cd = min(abs(f - tw), abs(f + tw));
	cords = groove(cd, 0.009) * smoothstep(0.3, 0.33, r) * (1.0 - smoothstep(0.63, 0.66, r));
	g = max(g, cords);
	// the knot: a cross through the centre ring
	vec2 qr = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * q;
	float x = min(abs(qr.x), abs(qr.y));
	g = max(g, groove(x, 0.009) * (1.0 - smoothstep(0.11, 0.125, r)));
	// worn: the cuts fade where the stone wore down, grit fills them in patches
	float wear = smoothstep(0.25, 0.65, fbm(vec3(q * 6.0, 3.0)));
	return g * mix(0.35, 1.0, wear);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	// chipped rim: bites out of the upper edge
	float top = smoothstep(0.0, 0.08, VERTEX.y);
	float bite = fbm(vec3(atan(VERTEX.z, VERTEX.x) * 5.0, VERTEX.y * 8.0, 1.7));
	VERTEX.xz *= 1.0 - smoothstep(0.45, 0.8, bite) * 0.035 * (0.4 + top) * step(0.5, length(VERTEX.xz));
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_cloud = cloud_shade_at(wp);
}

void fragment() {
	bool cap = ln.y > 0.5;
	vec2 q = lp.xz;
	float r = length(q);
	float cords = 0.0;
	float cut = 0.0;
	vec3 n_obj = normalize(ln);
	if (cap) {
		cut = sigil(q, cords);
		float e = 0.0015;
		float c2;
		float hx = sigil(q + vec2(e, 0.0), c2) - cut;
		float hz = sigil(q + vec2(0.0, e), c2) - cut;
		// grooves ~6 mm deep, plus a low weathered undulation over the face
		float u = fbm(vec3(q * 9.0, 7.0));
		float ux = fbm(vec3((q + vec2(e, 0.0)) * 9.0, 7.0)) - u;
		float uz = fbm(vec3((q + vec2(0.0, e)) * 9.0, 7.0)) - u;
		n_obj = normalize(vec3((hx * 0.006 - ux * 0.004) / e, 1.0, (hz * 0.006 - uz * 0.004) / e));
	} else {
		float s = fbm(lp * vec3(14.0, 30.0, 14.0));
		n_obj = normalize(n_obj + vec3(s - 0.5) * 0.25);
	}
	vec3 wn = normalize((MODEL_MATRIX * vec4(n_obj, 0.0)).xyz);
	// stone: dark greystone, mottled, a paler crust where it weathered
	float m = fbm(lp * 6.0 + 4.0);
	vec3 col = mix(stone_b, stone_a, smoothstep(0.3, 0.75, m));
	col *= 0.85 + 0.3 * vn(lp * 45.0);
	col = mix(col, vec3(0.5, 0.49, 0.45), smoothstep(0.6, 0.8, fbm(lp * 2.5 + 9.0)) * 0.35);
	// grooves: sooty and gritty
	col *= 1.0 - cut * 0.55;
	// lichen and moss creep in from the rim and settle in the cuts
	float rim = smoothstep(0.55, 0.82, r) * (cap ? 1.0 : 0.6);
	float mossw = clamp(smoothstep(0.55, 0.8, fbm(wp * 3.0) + rim * 0.45) + cut * 0.4 * smoothstep(0.5, 0.7, fbm(wp * 9.0)), 0.0, 1.0) * 0.85;
	col = mix(col, moss_a * (0.75 + 0.5 * fbm(wp * 12.0)), mossw);
	col = mix(col, vec3(0.6, 0.6, 0.53), smoothstep(0.72, 0.78, fbm(wp * 5.0 + 17.0)) * 0.5 * (1.0 - mossw));
	float rough = mix(0.8, 0.95, mossw);
	weather_wetten(col, rough, 0.6);
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	AO = 1.0 - cut * 0.4;
	// ember: only in the clean (unmossed) cuts; breathes, and pulses run in along the cords
	float clean = cut * (1.0 - mossw);
	float breathe = 0.8 + 0.2 * sin(TIME * 0.9);
	float pulse = pow(0.5 + 0.5 * sin(TIME * 1.6 - r * 18.0), 3.0);
	float e_amt = clean * (0.05 + wake * 0.55) * breathe + cords * (1.0 - mossw) * pulse * wake * 0.7;
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.5, clamp(wn.y, 0.0, 1.0)) * AO + ember * e_amt;
}
