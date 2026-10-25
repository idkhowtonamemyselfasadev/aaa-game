// The open vale as a patchwork of old fields rather than one olive sward. terrain.gdshader
// and grass.gdshader share this so the blade clumps and the ground under and past them agree.
// Fields are ~46 m warped Voronoi cells, each one kind:
//   x grazed pasture  - cropped short by the deer and the village beasts, greener and darker
//   y hay meadow      - left long, ripe straw-gold seed heads
//   z rough / fallow  - tussocky, browner, more dead thatch
// A few metres either side of a field bound all three weights fall to 0: the margin strip
// keeps the plain mixed sward. Bounds wobble ~7 m so they read as old unhedged field edges.
float fpat_h(vec2 p) { return fract(sin(dot(p, vec2(41.37, 289.11))) * 23417.531); }
float fpat_n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fpat_h(i), fpat_h(i + vec2(1, 0)), f.x), mix(fpat_h(i + vec2(0, 1)), fpat_h(i + vec2(1, 1)), f.x), f.y);
}

const float FIELD_SIZE = 46.0;

vec3 field_patch(vec2 xz) {
	vec2 w = xz + (vec2(fpat_n(xz * 0.03), fpat_n(xz * 0.03 + 17.3)) - 0.5) * 14.0
		+ (vec2(fpat_n(xz * 0.11 + 5.1), fpat_n(xz * 0.11 + 9.7)) - 0.5) * 4.0;
	vec2 c = w / FIELD_SIZE;
	vec2 i = floor(c);
	vec2 f = fract(c);
	float d1 = 9.0;
	float d2 = 9.0;
	float k = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 cell = i + o;
			vec2 r = o + 0.15 + 0.7 * vec2(fpat_h(cell), fpat_h(cell + 7.7)) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				k = fpat_h(cell + 3.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	// ~0.06 cell = 3 m: the margin strip either side of the bound
	float inner = smoothstep(0.03, 0.12, sqrt(d2) - sqrt(d1));
	vec3 t = k < 0.4 ? vec3(1.0, 0.0, 0.0) : (k < 0.72 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0));
	return t * inner;
}

// Albedo ratio for a field kind (multiplied in, so the texture detail under it survives).
// k scales the departure from the plain sward: 1 up close; the callers raise it with
// distance, since haze and the blending of many blades into one pixel wash the kinds
// together past ~60 m. Far off the kinds also part in value, not just hue (pale hay,
// dark grazed grass), which is what survives the aerial perspective.
vec3 field_tint_k(vec3 fw, float k) {
	float far = clamp(k - 1.0, 0.0, 1.0);
	vec3 past = vec3(0.80, 0.97, 0.74) * (1.0 - 0.10 * far);
	vec3 hay = vec3(1.16, 1.06, 0.84) * (1.0 + 0.10 * far);
	vec3 rough = vec3(0.88, 0.80, 0.70) * (1.0 - 0.04 * far);
	return max(vec3(0.2), vec3(1.0) + k * (fw.x * (past - 1.0) + fw.y * (hay - 1.0) + fw.z * (rough - 1.0)));
}

vec3 field_tint(vec3 fw) {
	return field_tint_k(fw, 1.0);
}
