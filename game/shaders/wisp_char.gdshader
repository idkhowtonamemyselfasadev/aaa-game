shader_type spatial;
// Hollow Wisp: charred bone/stone shards and the burning heart they orbit. Matte charcoal
// (soot-black with ashy grey flats) split by thin ember veins and pitted with glowing pores;
// `heat` drives the veins (the tell flares them), `fill` makes the heart glow through, and
// `lump` displaces the heart's sphere into an irregular coal.
render_mode cull_back;

uniform float heat = 0.6;
uniform float fill = 0.0;
uniform float lump = 0.0;
uniform float vein_w = 0.055;
uniform float charred = 0.0;     // 1 = a dead-black charred splinter (shards), 0 = the coal
uniform vec3 seed = vec3(0.0);
uniform vec3 ember : source_color = vec3(1.0, 0.36, 0.08);

varying vec3 lp;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int k = 0; k < 4; k++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	lp = VERTEX * 9.0 + seed;
	if (lump > 0.0) {
		VERTEX += NORMAL * (fbm(lp) - 0.5) * lump;
	}
}

void fragment() {
	float n = fbm(lp * 1.7);
	float vein = 1.0 - smoothstep(0.0, vein_w, abs(n - 0.5));
	float pore = smoothstep(0.6, 0.78, fbm(lp * 4.3 + 3.1));
	float flats = fbm(lp * 6.0);
	vec3 soot = mix(vec3(0.03, 0.028, 0.026), vec3(0.13, 0.12, 0.11), flats * flats);
	// heat-scorched rims go rusty brown near the veins
	soot = mix(soot, vec3(0.16, 0.07, 0.03), vein * 0.35 * (1.0 - 0.7 * charred));
	// shards: blacker, glossier char (cracked charcoal sheen), so they read as burnt splinters
	soot *= 1.0 - 0.55 * charred;
	ALBEDO = soot;
	ROUGHNESS = 0.86 - 0.18 * pore - 0.3 * charred * flats;
	METALLIC = 0.0;
	SPECULAR = 0.35;
	float g = max(vein, pore * 0.45 * (1.0 - 0.75 * charred));
	// the fill burns through the cracks; the crust plates between stay dark, so even a hot
	// heart keeps a broken, veined face instead of a flat disc
	float crack = smoothstep(0.42, 0.66, n);
	float glow_through = mix(0.08, 1.0, crack * crack) * (1.0 - 0.6 * smoothstep(0.35, 0.7, flats));
	float flick = 0.8 + 0.2 * sin(TIME * 7.0 + n * 20.0);
	EMISSION = ember * g * heat * flick + vec3(1.0, 0.5, 0.16) * fill * glow_through * flick;
}
