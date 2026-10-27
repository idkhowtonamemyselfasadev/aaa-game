shader_type spatial;
render_mode cull_back;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
// Mossy boulders. World-space 3D noise (no triplanar seams): strata bands, cracks and
// pitting in the normal, lichen spots, and moss on up-facing surfaces whose edge breaks
// up with noise; moss creeping up the flanks from the foot collar (moss_map), higher on
// the shaded side; a dark damp band where the stone meets the ground.

#include "res://shaders/weather.gdshaderinc"
uniform vec3 stone_a : source_color = vec3(0.33, 0.31, 0.28);   // weathered granite, a touch warm
uniform vec3 stone_b : source_color = vec3(0.17, 0.16, 0.15);
uniform vec3 streak_col : source_color = vec3(0.1, 0.09, 0.07);  // rain-carried dirt and algae
uniform vec3 moss_a : source_color = vec3(0.09, 0.12, 0.04);   // deep cushion shade
uniform vec3 moss_b : source_color = vec3(0.24, 0.27, 0.09);     // sunlit tips, olive not lime
uniform vec3 moss_dry : source_color = vec3(0.23, 0.19, 0.11);   // dead, browned patches
uniform vec3 lichen : source_color = vec3(0.55, 0.52, 0.38);

varying vec3 wp;
varying vec3 wn;
varying float ly;
varying float v_above;   // m above the ground the boulder sits in
varying float v_size;    // boulder size (m)

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
// quintic fade: the cubic one is only C1, so the finite-difference bump (surf below) showed
// every lattice cell as a faint polygon facet under raking light
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
// moss cushions: tight domed clumps (~5 cm) with smaller tufts on them
float cushion(vec3 p) { return vn(p * 19.0) * 0.65 + vn(p * 47.0 + 3.1) * 0.35; }
// each octave turned off the lattice axes so their cell grids do not line up into a mesh
const mat3 OCT = mat3(vec3(0.0, 1.6, 1.2), vec3(-1.6, 0.72, -0.96), vec3(-1.2, -0.96, 1.28));
float fbm(vec3 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = OCT * p * 1.035 + 5.3; a *= 0.5; } return r; }

varying float v_cloud;   // cloud shadow on this vertex (1 = full sun)

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ly = VERTEX.y;
	// Flora sinks each boulder 0.3 x size into the ground (big ones only 0.2 x, world/flora.gd;
	// keeping 0.3 here lets the foot moss creep that bit higher on them, which reads better)
	v_size = length(MODEL_MATRIX[0].xyz);
	v_above = wp.y - (MODEL_MATRIX[3].y + v_size * 0.3);
	v_cloud = cloud_shade_at((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

float surf(vec3 p) {
	float strata = sin(p.y * 7.0 + fbm(p * 1.5) * 4.0) * 0.5 + 0.5;
	float crack = 1.0 - smoothstep(0.0, 0.05, abs(fbm(p * 2.2) - 0.5));
	return fbm(p * 5.0) * 0.6 + strata * 0.25 - crack * 0.5;
}

void fragment() {
	vec3 n = normalize(wn);
	float s = surf(wp);
	float e = 0.02;
	vec3 g = vec3(surf(wp + vec3(e, 0, 0)) - s, surf(wp + vec3(0, e, 0)) - s, surf(wp + vec3(0, 0, e)) - s) / e;
	// tone: a wide ramp so cracks and strata shade the stone instead of drawing lines on it
	// (the crack term stays in the bump only; in the colour it read as marble veining)
	float crk = 1.0 - smoothstep(0.0, 0.05, abs(fbm(wp * 2.2) - 0.5));
	vec3 col = mix(stone_b, stone_a, smoothstep(0.0, 0.95, s + crk * 0.4 + fbm(wp * 0.7) * 0.3));
	col *= 1.0 - crk * 0.05;
	// broad tonal blotches so a bare face is not one even grey
	col *= 0.85 + 0.3 * fbm(wp * 0.45 + 90.0);
	// rain streaks: dark vertical runs washed down the steep faces from the moss and the
	// ledges above, strongest just under the crown and fading out toward the foot
	float steep = 1.0 - smoothstep(0.25, 0.75, abs(n.y));
	float runs = vn(vec3(wp.x * 7.0, wp.y * 0.5, wp.z * 7.0)) * 0.7 + vn(vec3(wp.x * 19.0, wp.y * 1.2, wp.z * 19.0) + 4.0) * 0.3;
	float streak = smoothstep(0.5, 0.8, runs) * steep * smoothstep(-0.3, 0.5, ly) * (0.6 + 0.4 * fbm(wp * 1.1 + 33.0));
	col = mix(col, streak_col, streak * 0.55);
	// lichen: soft-edged rosettes broken by a fine speckle, not hard map-like blots
	float li = smoothstep(0.64, 0.84, fbm(wp * 3.0 + 11.0)) * (0.55 + 0.45 * fbm(wp * 14.0 + 3.0));
	col = mix(col, lichen, li * 0.4);
	float mossw = smoothstep(0.35, 0.75, n.y + (fbm(wp * 1.3) - 0.5) * 0.9);
	// moss creeping up the flanks from the foot collar: higher on the shaded side, in
	// tongues that follow the cracks and run up the damp seams, thinning to a few patches
	float shade = clamp(dot(n.xz, MOSS_SHADE), 0.0, 1.0);
	float fm = foot_moss(wp.xz);
	float creep_h = v_size * mix(0.12, 0.55, shade) * (0.6 + 0.8 * fbm(vec3(wp.xz * 1.7, 3.0)));
	float tongue = fbm(vec3(wp.x * 2.6, wp.y * 0.9, wp.z * 2.6) + 7.0);
	float creep = fm * (1.0 - smoothstep(creep_h * 0.45, creep_h, v_above + (0.5 - tongue) * v_size * 0.35));
	creep *= smoothstep(-0.75, -0.2, n.y);   // not on the overhang undersides
	mossw = max(mossw, smoothstep(0.15, 0.55, creep));
	// break the moss up: the stone's proud ridges and a ragged patch noise show through,
	// so even a fully mossed top reads as moss growing on rock, not a green cap
	float holes = fbm(wp * 3.4 + 21.0) + mossw * 0.3 - s * 0.35;
	mossw *= smoothstep(0.3, 0.52, holes);
	// on the flanks the moss grows in broad patches (~1 m) with whole faces of bare stone
	// between them, not an even speckle over every side
	float flank = 1.0 - smoothstep(0.35, 0.75, n.y);
	float patchn = fbm(wp * 0.85 + 60.0) + fm * 0.12;
	mossw *= mix(1.0, smoothstep(0.44, 0.58, patchn), flank);
	// cushions: crevices between the clumps fall dark, the domed tips catch the light
	float cu = cushion(wp);
	vec3 mc = mix(moss_a, moss_b, smoothstep(0.25, 0.85, cu) * (0.6 + 0.4 * fbm(wp * 6.0)));
	mc = mix(mc, moss_dry, smoothstep(0.55, 0.8, fbm(wp * 2.1 + 40.0)) * 0.4);
	mc *= 0.7 + 0.45 * cu;
	col = mix(col, mc, mossw);
	col *= mix(0.55, 1.0, smoothstep(-0.35, 0.0, ly));    // damp foot
	float rough = mix(0.78, 1.0, mossw);
	weather_wetten(col, rough, mix(0.3, 1.0, mossw));
	ALBEDO = col;
	ROUGHNESS = rough;
	// moss is a matte felt of leaflets: almost no sheen, or the sky rims it in blue
	SPECULAR = mix(0.25, 0.08, mossw);
	// perturb the world normal with the detail gradient; under the moss, with the
	// cushion domes instead
	float ce = 0.006;
	vec3 cg = vec3(cushion(wp + vec3(ce, 0, 0)) - cu, cushion(wp + vec3(0, ce, 0)) - cu, cushion(wp + vec3(0, 0, ce)) - cu) / ce;
	vec3 bg = mix(g * 0.05, cg * 0.02, mossw);
	vec3 pn = normalize(n - (bg - n * dot(bg, n)));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = clamp(0.6 + s * 0.6, 0.0, 1.0) * mix(1.0, 0.65 + 0.35 * cu, mossw);
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;
	// shade fill: the flank turned from the sun sees the open sky and the sunlit meadow, so it
	// gets more than the top; AO only half applies (the full AO times the dark damp foot crushed
	// the shaded flank to black). Bark takes 1.7x for the same reason.
	float fill = 1.7 * mix(1.0, 0.5, clamp(n.y, 0.0, 1.0)) * (1.0 + 0.35 * shade);
	EMISSION = ALBEDO * bounce_light * fill * mix(1.0, AO, 0.5);
}
