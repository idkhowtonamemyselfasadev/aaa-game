shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, shadows_disabled, fog_disabled;
// Cloud layer for the Vale sky (world/clouds.gd). A dome riding on the camera; each pixel
// casts its view ray onto a flat deck `layer_h` metres up, so the clouds foreshorten and
// crowd toward the horizon like a real cloud base. Fair-weather cumulus on a clear day; as a
// front arrives `coverage` climbs and the gaps close into a thick grey deck with darker
// rain-bellies. Lit by one light (sun by day, moon by night): a march of a few samples toward
// it gives self-shadowed bellies and bright tops, and thin edges glow when facing the light.

uniform float coverage = 0.3;        // 0 clear .. 1 full overcast
uniform float thickness = 0.0;       // 0 fair-weather .. 1 heavy rain deck (darker bellies)
uniform vec3 light_dir = vec3(0.0, 1.0, 0.0);   // toward the light
uniform vec3 light_col : source_color = vec3(1.0);
uniform vec3 shade_col : source_color = vec3(0.4, 0.45, 0.55);
uniform vec3 haze_col : source_color = vec3(0.7, 0.72, 0.75);
uniform vec2 drift = vec2(0.0);      // metres the deck has blown (world.gd integrates wind)
uniform float layer_h = 1500.0;
uniform float haze_height = 0.1;    // sin(elevation) below which the deck sinks into the fog

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
			mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p, int oct) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));
	for (int i = 0; i < oct; i++) {
		s += a * vnoise(p);
		p = r * p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

// cloud density at deck point p (metres)
float density(vec2 p, int oct) {
	// big weather cells, domain-warped so the cumulus groups in streets and clumps
	vec2 q = p / 1700.0;
	vec2 w = vec2(fbm(q * 0.5 + vec2(3.1, 1.7), 3), fbm(q * 0.5 + vec2(8.3, 2.8), 3));
	float n = fbm(q + 0.7 * w, oct);
	// fine billows eat into the edges (cauliflower outline instead of a blurred blob)
	n -= 0.2 * (1.0 - fbm(p / 300.0 + w * 2.0, 3)) * (1.0 - 0.6 * thickness);
	float lo = mix(0.5, 0.0, coverage);
	return smoothstep(lo, lo + mix(0.1, 0.38, coverage), n);
}

void fragment() {
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 dir = normalize(wpos - ro);
	if (dir.y < 0.004) {
		discard;
	}
	float t = (layer_h - ro.y) / dir.y;
	vec2 p = ro.xz + dir.xz * t + drift;
	float d = density(p, 5);
	if (d < 0.003) {
		discard;
	}
	// light march along the deck toward the light: bellies under thick cloud go dark
	vec2 ld = normalize(light_dir.xz + vec2(1e-4));
	float lstep = mix(140.0, 60.0, smoothstep(0.1, 0.9, light_dir.y));
	float occ = 0.0;
	for (int i = 1; i <= 3; i++) {
		occ += density(p + ld * lstep * float(i), 4);
	}
	float thick = d * mix(1.0, 2.2, thickness);
	float lit = exp(-(occ * 0.9 + thick * 1.3));
	// powder term: dense cores look darker from below than their thin edges
	float powder = 1.0 - exp(-d * 3.0);
	vec3 col = shade_col * mix(1.0, 0.6, thickness * d);
	col += light_col * lit * mix(0.7, 1.0, powder);
	// forward scatter: thin edges toward the light glow (silver lining)
	float mu = max(dot(dir, normalize(light_dir)), 0.0);
	col += light_col * pow(mu, 10.0) * (1.0 - d) * 1.6 * (1.0 - thickness * 0.7);
	// aerial perspective: the far deck sinks into the horizon haze
	float far = 1.0 - exp(-t / 16000.0);
	col = mix(col, haze_col, far * 0.85);
	float a = d * smoothstep(0.004, 0.09, dir.y) * (1.0 - far * mix(0.6, 0.15, coverage));
	// under a front the low deck is lost in the rain haze: it meets the fogged mountains in
	// the fog's own colour instead of cutting their silhouette out of a dark ceiling
	float hz = 1.0 - smoothstep(0.0, haze_height, dir.y);
	col = mix(col, haze_col, hz * thickness);
	a = mix(a, 1.0, hz * thickness);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
