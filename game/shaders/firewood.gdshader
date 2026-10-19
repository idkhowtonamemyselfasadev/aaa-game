shader_type spatial;
render_mode cull_back;
// Split oak and ash firewood, the chopping block and the chips (WhiteCottage's lean-to).
// Object space, metres: each log's original axis is the local Y axis through the origin,
// so faces whose normal points away from the axis are the bark, the flat faces are the
// split wood (pale, streaked along the grain, torn fibres) and the faces with a normal
// along Y are the sawn ends (growth rings round the axis, radial checks, darker).
// INSTANCE_CUSTOM: r = per-log tint, g = seasoning (0 fresh-split tan .. 1 weathered grey),
// b = bark kind (0 oak's grey fissured bark .. 1 ash/birch-ish smoother, paler).

#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;
uniform float exposed = 0.0;   // 1 = out under the sky (the block, the chips): wets in rain

varying vec3 op;
varying vec3 onrm;
varying vec3 wn;
varying vec4 cust;
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

void vertex() {
	cust = INSTANCE_CUSTOM;
	op = VERTEX;
	onrm = NORMAL;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_cloud = cloud_shade_at(wp);
}

void fragment() {
	vec3 n = normalize(onrm);
	vec3 sd = op + vec3(cust.r * 17.0, cust.r * 5.0, cust.r * 11.0);   // per-log noise offset
	float r = length(op.xz);
	vec2 radial = op.xz / max(r, 1e-4);
	float end_face = smoothstep(0.75, 0.92, abs(n.y));
	float bark = smoothstep(0.55, 0.8, dot(radial, n.xz)) * (1.0 - end_face);
	float split = (1.0 - bark) * (1.0 - end_face);
	float season = cust.g;
	// split faces: torn fibres in long streaks along Y, a few dark heart streaks
	float fib = fbm(sd * vec3(60.0, 2.5, 60.0));
	float streak = fbm(sd * vec3(9.0, 0.6, 9.0));
	vec3 fresh = mix(vec3(0.56, 0.43, 0.29), vec3(0.66, 0.53, 0.37), fib);
	fresh = mix(fresh, vec3(0.38, 0.27, 0.17), smoothstep(0.55, 0.75, streak) * 0.6);
	vec3 grey = mix(vec3(0.4, 0.37, 0.33), vec3(0.52, 0.49, 0.44), fib);
	vec3 wood = mix(fresh, grey, season);
	// sawn ends: growth rings round the axis, a darker heart, radial drying checks
	float ring = sin(r * 380.0 + fbm(sd * 6.0) * 6.0) * 0.5 + 0.5;
	float ang = atan(op.z, op.x);
	float check = smoothstep(0.035, 0.0, abs(fract(ang * 1.2 + fbm(sd * 3.0) * 0.6) - 0.5)) * smoothstep(0.01, 0.04, r);
	vec3 endc = mix(vec3(0.5, 0.38, 0.25), vec3(0.36, 0.25, 0.15), ring * 0.55 + smoothstep(0.05, 0.0, r) * 0.3);
	endc = mix(endc, mix(vec3(0.42, 0.38, 0.33), vec3(0.3, 0.27, 0.24), ring * 0.4), season * 0.8);
	endc = mix(endc, vec3(0.07, 0.05, 0.035), check * 0.85);
	// bark: deep fissured ridges along Y (oak) or smoother with lenticels (b)
	float fis = fbm(vec3(ang * 3.0, op.y * 2.2, cust.r * 9.0) * vec3(4.0, 3.0, 1.0));
	float ridge = smoothstep(0.42, 0.62, fis);
	vec3 barkc = mix(vec3(0.07, 0.06, 0.05), vec3(0.3, 0.29, 0.26), ridge);
	vec3 smooth_b = mix(vec3(0.34, 0.32, 0.28), vec3(0.45, 0.43, 0.38), fbm(sd * vec3(20.0, 4.0, 20.0)));
	smooth_b = mix(smooth_b, vec3(0.12, 0.1, 0.08), smoothstep(0.78, 0.84, vn(vec3(ang * 14.0, op.y * 40.0, 1.0))) * 0.8);
	barkc = mix(barkc, smooth_b, cust.b);
	// lichen and green algae on the bark of the older wood
	barkc = mix(barkc, vec3(0.3, 0.34, 0.2), smoothstep(0.6, 0.75, fbm(sd * 7.0)) * season * 0.6);
	vec3 col = wood * split + endc * end_face + barkc * bark;
	col *= mix(0.85, 1.1, cust.r);
	float rough = mix(0.82, 0.96, bark) - end_face * 0.04;
	if (exposed > 0.5) {
		weather_wetten(col, rough, 0.9);
	}
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	// relief: bark fissures and the fibres of the split faces bend the light
	float e = 0.002;
	vec3 g;
	g.x = fbm((sd + vec3(e, 0, 0)) * vec3(60.0, 2.5, 60.0)) - fib;
	g.y = 0.0;
	g.z = fbm((sd + vec3(0, 0, e)) * vec3(60.0, 2.5, 60.0)) - fib;
	g = g / e * 0.0006 * split;
	vec3 pn = normalize(n - (g - n * dot(g, n)) - vec3(radial.x, 0.0, radial.y) * (ridge - 0.5) * 0.35 * bark * (1.0 - cust.b));
	vec3 pw = normalize((MODEL_MATRIX * vec4(pn, 0.0)).xyz);
	NORMAL = normalize((VIEW_MATRIX * vec4(pw, 0.0)).xyz);
	AO = 1.0 - bark * (1.0 - ridge) * 0.4 * (1.0 - cust.b) - check * end_face * 0.5;
	EMISSION = ALBEDO * bounce_light * mix(1.0, 0.5, clamp(pw.y, 0.0, 1.0)) * AO;
}
