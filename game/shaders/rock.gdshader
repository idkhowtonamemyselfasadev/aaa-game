shader_type spatial;
render_mode cull_back;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
global uniform vec3 sky_floor;     // sky-dome floor for shaded faces, kept with SDFGI (World._apply_bounce)
// Mossy boulders. World-space 3D noise (no triplanar seams): strata bands, cracks and
// pitting in the normal, lichen spots, and moss on up-facing surfaces whose edge breaks
// up with noise; moss creeping up the flanks from the foot collar (moss_map), higher on
// the shaded side; a dark damp band where the stone meets the ground.

#include "res://shaders/weather.gdshaderinc"
// (0.33/0.22 sRGB is only ~0.09/0.04 linear, basalt-dark: the great stone up the fell read as a
// black slab even at noon. Weathered upland granite is ~0.15-0.2 linear.)
uniform vec3 stone_a : source_color = vec3(0.40, 0.38, 0.34);   // weathered granite, a touch warm
uniform vec3 stone_b : source_color = vec3(0.28, 0.28, 0.27);   // a cooler grey so the two tones read apart in sun
uniform vec3 streak_col : source_color = vec3(0.1, 0.09, 0.07);  // rain-carried dirt and algae
uniform vec3 moss_a : source_color = vec3(0.14, 0.17, 0.06);   // deep cushion shade (0.09 read black on the shaded flank)
uniform vec3 moss_b : source_color = vec3(0.24, 0.27, 0.09);     // sunlit tips, olive not lime
uniform vec3 moss_dry : source_color = vec3(0.23, 0.19, 0.11);   // dead, browned patches
uniform vec3 lichen : source_color = vec3(0.55, 0.52, 0.38);
uniform vec3 crust : source_color = vec3(0.56, 0.56, 0.5);     // pale grey crustose lichen on old big stones

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
	// broad tonal blotches so a bare face is not one even grey (0.85 + 0.3 left the sunlit face
	// of a meadow boulder one flat chalky sheet at 14:00), plus a hand-sized mottle on top
	col *= 0.72 + 0.5 * fbm(wp * 0.45 + 90.0);
	col *= 0.88 + 0.24 * fbm(wp * 2.6 + 44.0);
	// fissures shade the stone in a soft wide band (a weathered groove holds shadow and grime);
	// the narrow crk above drew marble veins when darkened, this one is 2-3x wider and graded
	float fis = 1.0 - smoothstep(0.0, 0.14, abs(fbm(wp * 2.2) - 0.5));
	col *= 1.0 - fis * fis * 0.3;
	// granite grain: feldspar and mica speckle, faded out where a pixel covers more than ~1 cm
	// so it never aliases into shimmer on a distant stone
	float gfade = 1.0 - smoothstep(0.004, 0.012, length(fwidth(wp)));
	col *= 1.0 + (vn(wp * 70.0) - 0.5) * 0.28 * gfade;
	// rain streaks: dark vertical runs washed down the steep faces from the moss and the
	// ledges above, strongest just under the crown and fading out toward the foot
	// (rain runs down any face it cannot pool on: a rounded boulder's lit shoulder at n.y ~0.5
	// counts, which the old 0.25-0.75 window left bare)
	float steep = 1.0 - smoothstep(0.5, 0.88, abs(n.y));
	// Thin runs are the noise's 0.5 crossings (a ridge line, stretched tall so it hangs as a
	// line down the face); broad washes sit between them. The old smoothstep on raw value noise
	// gave soft 15 cm blobs that the tonal blotches swallowed: the streaks never read.
	float ridge = 1.0 - abs(vn(vec3(wp.x * 4.5, wp.y * 0.3, wp.z * 4.5) + 4.0) * 2.0 - 1.0);
	float thin = smoothstep(0.74, 0.95, ridge) * (0.5 + 0.5 * vn(vec3(wp.x * 23.0, wp.y * 2.0, wp.z * 23.0)));
	float wash = smoothstep(0.55, 0.8, vn(vec3(wp.x * 2.6, wp.y * 0.35, wp.z * 2.6) + 17.0));
	float streak = max(thin, wash * 0.6) * steep * smoothstep(0.0, 0.6, ly) * (0.6 + 0.4 * fbm(wp * 1.1 + 33.0));
	// (0.6, upper face only: at 0.9 from ly -0.3 the runs blackened the whole shaded flank)
	col = mix(col, streak_col, streak * 0.5);
	// lichen: soft-edged rosettes broken by a fine speckle, not hard map-like blots
	float li = smoothstep(0.64, 0.84, fbm(wp * 3.0 + 11.0)) * (0.55 + 0.45 * fbm(wp * 14.0 + 3.0));
	col = mix(col, lichen, li * 0.4);
	// old big stones (the fell's great stones) carry broad pale crusts of grey lichen on the
	// faces the rain washes clean: in drifts round the crown and down the weather side, so a
	// 3 m stone reads as lichened grey granite against the turf, not a dark mass
	float old = smoothstep(1.6, 2.8, v_size);
	float cr = smoothstep(0.5, 0.68, fbm(wp * 1.6 + 71.0)) * (0.6 + 0.4 * fbm(wp * 9.0 + 5.0));
	cr *= smoothstep(-0.4, 0.3, n.y) * smoothstep(0.1, 0.5, v_above);
	col = mix(col, crust * (0.9 + 0.2 * fbm(wp * 4.0)), cr * old * 0.5);
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
	// steep faces hold at most ~60 % moss so grey stone shows between the patches (a flank
	// that was all deep moss read black in the shade)
	mossw *= mix(1.0, 0.6, smoothstep(0.5, 0.9, flank));
	// cushions: crevices between the clumps fall dark, the domed tips catch the light
	float cu = cushion(wp);
	vec3 mc = mix(moss_a, moss_b, smoothstep(0.25, 0.85, cu) * (0.6 + 0.4 * fbm(wp * 6.0)));
	mc = mix(mc, moss_dry, smoothstep(0.55, 0.8, fbm(wp * 2.1 + 40.0)) * 0.4);
	// shallower cushion darkening on steep faces (0.7 floor crushed the shaded flank)
	mc *= mix(0.7 + 0.45 * cu, 0.85 + 0.3 * cu, smoothstep(0.5, 0.9, flank));
	col = mix(col, mc, mossw);
	// damp foot: the bottom ~15 cm only (the old local-y ramp darkened half a big boulder's flank)
	col *= mix(0.55, 1.0, smoothstep(-0.05, 0.15, v_above));
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
	AO = clamp(0.6 + s * 0.6, 0.0, 1.0) * mix(1.0, 0.8 + 0.2 * cu, mossw);
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;
	// shade fill: the flank turned from the sun sees the open sky and the sunlit meadow, so it
	// gets more than the top; AO only half applies (the full AO times the dark damp foot crushed
	// the shaded flank to black). Bark takes 1.7x for the same reason.
	// The face turned from the sun looks straight into the bright half of the sky dome and the
	// sunlit meadow, so it gets the most: the fixed MOSS_SHADE side alone left a flank facing the
	// camera (and away from the sun) near-black at 15:00, darker than the shaded grass beside it.
	vec3 sl = normalize(cloud_sun);
	float away = clamp(-dot(vec3(n.x, 0.0, n.z), normalize(vec3(sl.x, 0.0, sl.z) + 1e-4)), 0.0, 1.0)
			* smoothstep(-0.05, 0.15, sl.y);
	float fill = 1.7 * mix(1.0, 0.5, clamp(n.y, 0.0, 1.0)) * (1.0 + 0.35 * shade + 1.1 * away);
	// the floor: a face turned from the sun never drops below what the open sky dome gives it
	vec3 floor_l = sky_floor * mix(1.0, 0.6, clamp(n.y, 0.0, 1.0)) * (0.6 + 0.8 * away);
	EMISSION = ALBEDO * max(bounce_light * fill, floor_l) * mix(1.0, AO, 0.5);
}
