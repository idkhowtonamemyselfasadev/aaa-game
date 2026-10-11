// The Vale's cloud deck, shared by the sky dome (clouds.gdshader) and every lit surface that
// takes cloud shadows. The deck is a flat layer `CLOUD_DECK_H` metres up; a deck point is
// world xz + the drift the wind has blown it (world/clouds.gd pushes the globals each frame).
//   cloud_drift  : metres the deck has blown
//   cloud_cover  : 0 clear .. 1 full overcast (same as the dome's `coverage`)
//   cloud_thick  : 0 fair-weather .. 1 heavy rain deck
//   cloud_sun    : direction toward the sun (the shadow is cast along it)
//   cloud_shadow : 0 .. 1 how much a cloud's shadow darkens the land (strong in bright sun,
//                  gone under a full deck or at night, when there is no direct light to lose)
global uniform vec2 cloud_drift;
global uniform float cloud_cover;
global uniform float cloud_thick;
global uniform vec3 cloud_sun;
global uniform float cloud_shadow;

const float CLOUD_DECK_H = 1500.0;

float cs_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float cs_noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cs_hash(i), cs_hash(i + vec2(1.0, 0.0)), u.x),
			mix(cs_hash(i + vec2(0.0, 1.0)), cs_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
// `full` > `oct`: add the mean of the octaves left out of a `full`-octave sum, so a cheap
// low-octave call sits at the same level as the full one (cloud shadows line up with the
// clouds drawn in the sky)
float cs_fbm(vec2 p, int oct, int full) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < oct; i++) {
		s += a * cs_noise(p);
		p = r * p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	if (full > oct) {
		s += a * (1.0 - exp2(float(oct - full)));
	}
	return s;
}

// cloud density 0..1 at deck point p (metres, drift already added)
// oct/detail: octaves of the cell and warp/billow noise; cheap callers pass fewer and
// `pad` = true to level them with the sky's 5/3
float cloud_deck_density(vec2 p, int oct, int detail, bool pad, float cov, float thk) {
	int fo = pad ? 5 : 0;
	int fd = pad ? 3 : 0;
	// big weather cells, domain-warped so the cumulus groups in streets and clumps
	vec2 q = p / 1700.0;
	vec2 w = vec2(cs_fbm(q * 0.5 + vec2(3.1, 1.7), detail, fd),
			cs_fbm(q * 0.5 + vec2(8.3, 2.8), detail, fd));
	float n = cs_fbm(q + 0.7 * w, oct, fo);
	// fine billows eat into the edges (cauliflower outline instead of a blurred blob)
	n -= 0.2 * (1.0 - cs_fbm(p / 300.0 + w * 2.0, detail, fd)) * (1.0 - 0.6 * thk);
	float lo = mix(0.5, 0.0, cov);
	return smoothstep(lo, lo + mix(0.1, 0.38, cov), n);
}

// 1 in full sun .. down to 1 - 0.55 * cloud_shadow under a thick cloud, for world point `wp`.
// Cheap (low octaves) and smooth at the metre scale: call it per vertex.
float cloud_shade_at(vec3 wp) {
	if (cloud_shadow < 0.01) {
		return 1.0;
	}
	vec3 l = normalize(cloud_sun);
	l.y = max(l.y, 0.12);    // a grazing sun throws the shadow kilometres away: clamp it
	vec2 p = wp.xz + l.xz * ((CLOUD_DECK_H - wp.y) / l.y) + cloud_drift;
	float d = cloud_deck_density(p, 3, 2, true, cloud_cover, cloud_thick);
	// a thin cloud only veils the sun; the core blocks most of it
	float block = smoothstep(0.05, 0.75, d);
	return 1.0 - 0.55 * cloud_shadow * block;
}
