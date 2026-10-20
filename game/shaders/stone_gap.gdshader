shader_type spatial;
// The dirt-filled gap round a door stone: a thin decal quad laid on the ground under each
// slab, a little bigger than it, dark crumbled loam packed into the crack between the slab's
// edge and the turf, fading out ragged into the track's own dirt.
render_mode blend_mix, depth_draw_never, cull_disabled;

global uniform vec3 bounce_light;
uniform vec3 loam : source_color = vec3(0.13, 0.095, 0.065);
uniform vec3 loam_dry : source_color = vec3(0.24, 0.19, 0.13);

// UV: metres from the slab's centre along its own x/z; UV2: the patch's half size in metres
varying vec3 wp;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) {
	vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = p * 2.03 + 3.7; a *= 0.5; } return r; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// metres in from the quad's edge
	vec2 d = UV2 - abs(UV);
	float in_m = min(d.x, d.y);
	float rag = (fbm(wp.xz * 9.0) - 0.5) * 0.06;
	// solid from ~6 cm in (under the slab's edge) out to the rim, ragged fade beyond
	float a = smoothstep(0.0, 0.07, in_m + rag);
	float crumbs = vn(wp.xz * 60.0);
	vec3 c = mix(loam, loam_dry, smoothstep(0.45, 0.8, fbm(wp.xz * 14.0 + 2.0)) * 0.7);
	c *= 0.8 + 0.4 * crumbs;
	ALBEDO = c;
	ROUGHNESS = 0.96;
	SPECULAR = 0.3;
	ALPHA = a * 0.85;
	EMISSION = c * bounce_light * 0.4;
}
