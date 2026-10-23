shader_type spatial;
render_mode cull_back;
// Weathered cut stone for the watchtower ruin. World-space noise (no UVs): a buff-grey
// sandstone with bedding laminae, tooling grain and pits in the normal; worn pale arrises
// (the rounded bevels, found from the object-space normal), dark rain streaks running down
// the faces, lichen rosettes, moss on the tops and in the lower courses, damp at the foot.
// Each stone is one of a few beds of the quarry: warm buff, ochre, rust-stained, pale
// near-white or dark grey, with iron-stain blooms. The joints sink into shadow and grime
// (COLOR.r: 0 on the end/bed faces, 1 at 15 cm in from those arrises), and the low joints
// hold soil and moss.
// INSTANCE_CUSTOM: r = block's height above the ground / 8 m, g = per-block random,
// b = 1 for a stone laid in a wall course (0 for fallen blocks and rubble),
// a = 1 for the curtain wall: low, damp, longer out in the weather -- a darker grey crust,
// more lichen and moss, arrises worn dark rather than pale. a = 2: aged FIELD stone (the
// village's dry-stone walls): greyer gritstone, grey lichen rather than yellow, moss only on
// the tops and the faces turned from the noon sun (+x: the sun stands at -x at noon), muted; a above 2 also dims it greyer (the stone cottage's rubble).
// a = 4: LIMEWASHED (the white cottage): coats of white lime over the rubble, thin over the
// stone arrises, flaked in ragged patches low down, rain runs from the eaves, green algae
// and splash grime rising from the foot.
// b = 2: a STILE slab (a gritstone flag set on end through a field wall): crusted in grey-green
// and yellow lichen, and rubbed smooth, dark and faintly greasy along its arrises and top at
// hand-and-hip height where folk squeeze through.
// r below 0: a TRODDEN slab (the door stones): the top is foot-worn -- no moss or lichen on
// it, paler and smoothed, not darkened as a damp low course; moss only in its edges.

#include "res://shaders/weather.gdshaderinc"
uniform vec3 stone_a : source_color = vec3(0.7, 0.62, 0.5);
uniform vec3 stone_b : source_color = vec3(0.52, 0.47, 0.39);
uniform vec3 stone_ochre : source_color = vec3(0.64, 0.54, 0.4);
uniform vec3 stone_rust : source_color = vec3(0.55, 0.43, 0.34);
uniform vec3 stone_pale : source_color = vec3(0.72, 0.7, 0.64);
uniform vec3 stone_dark : source_color = vec3(0.43, 0.42, 0.39);
uniform vec3 iron_stain : source_color = vec3(0.5, 0.3, 0.16);
uniform vec3 joint_soil : source_color = vec3(0.22, 0.17, 0.12);
uniform vec3 limewash : source_color = vec3(0.74, 0.725, 0.67);
uniform vec3 lime_algae : source_color = vec3(0.3, 0.34, 0.2);
// sun- and sky-light thrown back by the meadow and the sunlit walls (World._apply_bounce;
// zero when SDFGI runs). Ambient-like, so it fills the shade instead of going black.
global uniform vec3 bounce_light;
// low-sun skylight on open level ground (World._apply_bounce; 0 at noon, night and with SDFGI):
// the door stones' walked tops and the wall tops get it as the terrain and grass round them do
global uniform vec3 ground_fill;
// Hesper's cookfire (Hearth): xyz = the fire's foot, w = 1 when there is one. The stones
// over and round it are smoke-blackened: a soot plume up the face behind the fire, widening
// as it climbs, and a scorched skirt on the stones near the ring.
global uniform vec4 hearth_soot;
#include "res://shaders/bounce.gdshaderinc"
uniform vec3 moss_a : source_color = vec3(0.3, 0.34, 0.12);
uniform vec3 moss_b : source_color = vec3(0.4, 0.41, 0.16);
uniform vec3 moss_dark : source_color = vec3(0.13, 0.16, 0.06);
uniform vec3 moss_dry : source_color = vec3(0.38, 0.31, 0.17);
uniform vec3 lichen_y : source_color = vec3(0.62, 0.56, 0.32);
uniform vec3 lichen_g : source_color = vec3(0.55, 0.57, 0.5);

varying vec3 wp;
varying vec3 wn;
varying float edge;
varying float above;
varying float tint;
varying float v_cloud;
varying float jnt;
varying float laid;
varying float aged;
varying float field;
varying float dim;   // a above 2: a darker, greyer face (the cottage's rubble)
varying float lw;         // 1: limewashed (a = 4)
varying float trod;       // 1: a door stone's walked top (r < 0)
varying float slab;       // 1: a stile slab (b = 2)
varying float floor_w;    // world y of the ground this stone's `above` counts from

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
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 an = abs(normalize(NORMAL));
	edge = 1.0 - smoothstep(0.86, 0.98, max(an.x, max(an.y, an.z)));
	trod = step(INSTANCE_CUSTOM.r, -0.05);
	above = max(INSTANCE_CUSTOM.r * 8.0, 0.0) + trod * 1.2;   // a trodden top is not a damp low course
	tint = INSTANCE_CUSTOM.g;
	v_cloud = cloud_shade_at(wp);
	jnt = COLOR.r;
	laid = min(INSTANCE_CUSTOM.b, 1.0);
	slab = step(1.5, INSTANCE_CUSTOM.b);
	aged = min(INSTANCE_CUSTOM.a, 1.0);
	field = step(1.5, INSTANCE_CUSTOM.a);
	dim = clamp(INSTANCE_CUSTOM.a - 2.0, 0.0, 1.0);
	lw = step(3.5, INSTANCE_CUSTOM.a);
	floor_w = MODEL_MATRIX[3].y - above;
}

float surf(vec3 p) {
	float lam = sin(p.y * 38.0 + fbm(p * vec3(2.0, 0.6, 2.0)) * 6.0) * 0.5 + 0.5;   // bedding
	float pit = smoothstep(0.7, 0.8, vn(p * 70.0));
	return fbm(p * 9.0) * 0.5 + lam * 0.18 - pit * 0.2 + vn(p * 60.0) * 0.12;
}

void fragment() {
	vec3 n = normalize(wn);
	float s = surf(wp);
	float e = 0.006;
	vec3 g = vec3(surf(wp + vec3(e, 0, 0)) - s, surf(wp + vec3(0, e, 0)) - s, surf(wp + vec3(0, 0, e)) - s) / e;
	// stone: each block its own shade, mottled
	vec3 base = mix(stone_b, stone_a, 0.15 + tint * 0.8);
	// its bed in the quarry
	float bed = fract(tint * 91.7);
	vec3 bedc = bed < 0.15 ? stone_ochre : bed < 0.23 ? stone_rust : bed < 0.35 ? stone_pale
	          : bed < 0.47 ? stone_dark : base;
	base = mix(base, bedc * (0.94 + 0.12 * fract(tint * 37.3)), 0.55);
	// iron stain blooming from the joints and through some faces, most on the rusty beds
	float iron = smoothstep(0.6, 0.85, fbm(wp * 3.1 + tint * 7.0) + (1.0 - jnt) * 0.18)
	           * (bed < 0.23 ? 0.7 : 0.3);
	base = mix(base, iron_stain, iron);
	// weathering crust: broad darker/greyer patches across a face, pale where it flaked off
	float crust = fbm(wp * 2.3 + tint * 13.0);
	base *= 0.8 + 0.35 * smoothstep(0.25, 0.75, crust);
	base = mix(base, vec3(dot(base, vec3(0.33))) * 0.8, smoothstep(0.55, 0.8, fbm(wp * 1.1 + 31.0)) * 0.5);
	base *= vec3(1.0, 0.98, 0.95) + vec3(0.04, 0.0, -0.04) * (tint - 0.5);
	// the curtain: a dark grey weathering skin over most of every face, the bed colour
	// showing through only where it flaked
	float skin = smoothstep(0.3, 0.6, fbm(wp * 1.7 + tint * 5.0 + 17.0));
	base = mix(base, vec3(dot(base, vec3(0.3, 0.4, 0.3))) * vec3(0.66, 0.66, 0.63), aged * mix(0.45, 0.8, skin));
	// field stone: a cool grey gritstone, darker, the beds only faintly showing
	// (each stone its own value, 0.5-0.98: a field wall's stones came off different fells, and
	// an even grey face reads as pale tiles on the dark joint grid)
	float fv = fract(tint * 53.1);
	base = mix(base, vec3(dot(base, vec3(0.3, 0.4, 0.3))) * vec3(0.8, 0.81, 0.8) * (0.5 + 0.48 * fv * fv * (3.0 - 2.0 * fv)), field * 0.8);
	// and a dark grey-black crust (old lichen, soot of the weather) over broad patches of its face
	float fcr = smoothstep(0.45, 0.72, fbm(wp * 2.8 + tint * 11.0 + 61.0));
	base = mix(base, vec3(dot(base, vec3(0.3, 0.4, 0.3))) * vec3(0.52, 0.53, 0.5), field * fcr * 0.7);
	base = mix(base, vec3(dot(base, vec3(0.3, 0.4, 0.3))) * 0.84, dim * 0.6);
	// rubble: each split stone its own value and a faint warm (iron) or cool (blue) cast
	base = mix(base, base * (0.72 + 0.5 * fract(tint * 91.7)) * mix(vec3(1.04, 1.0, 0.94), vec3(0.95, 0.99, 1.05), fract(tint * 17.9)), dim);
	// the ruin's dressed stones (keep and curtain): a wider value range block to block -- some
	// stones came off a darker, harder bed, some sun-bleached on the old crown -- so a face reads
	// as laid stones, not as one even buff sheet of tiles
	float ruin = (1.0 - field) * (1.0 - lw) * (1.0 - trod) * (1.0 - slab);
	float sv = fract(tint * 23.71);
	base *= mix(1.0, 0.7 + 0.48 * sv * sv * (3.0 - 2.0 * sv), ruin * 0.85);
	// spalls: frost has flaked the weathered skin off in shallow scallops, leaving fresher,
	// warmer, rougher stone a few mm down inside a sharp dark rim; most near the arrises and on
	// the faces out in the rain
	float spn = fbm(wp * 3.6 + tint * 19.0) + edge * 0.12 + (1.0 - jnt) * 0.08;
	float spall = smoothstep(0.66, 0.69, spn) * ruin * (1.0 - smoothstep(0.6, 0.9, n.y));
	float sp_rim = smoothstep(0.63, 0.665, spn) * (1.0 - smoothstep(0.665, 0.7, spn)) * ruin * (1.0 - smoothstep(0.6, 0.9, n.y));
	base = mix(base, base * vec3(1.16, 1.06, 0.92) + vec3(0.03, 0.02, 0.0), spall * 0.8);
	vec3 col = base * (0.9 + s * 0.2);
	col *= 1.0 - sp_rim * 0.35;
	// worn arrises: paler, rubbed smooth on the keep's sheltered stones; on the laid tops and
	// on the curtain they weather dark with grime instead (only the odd fresh chip stays pale)
	float fresh = smoothstep(0.72, 0.8, vn(wp * 6.0 + tint * 9.0));
	col = mix(col, base * 1.1 + 0.015, edge * 0.3 * (1.0 - dim * 0.75) * (1.0 - 0.8 * laid * smoothstep(0.2, 0.7, n.y)) * mix(1.0, fresh, aged));
	col *= 1.0 - edge * aged * (1.0 - fresh) * 0.22;
	// rain streaks down the vertical faces (long in y, narrow across)
	float side = 1.0 - smoothstep(0.3, 0.7, abs(n.y));
	float streak = smoothstep(0.55, 0.85, fbm(vec3(wp.x * 7.0, wp.y * 0.35, wp.z * 7.0) + 3.0));
	col *= 1.0 - streak * side * 0.4;
	// ...and on the ruin, black-green algae runs from under every stone's lip: water drips off
	// the course above and runs down the top of each face, fading as it dries lower down
	float lip = smoothstep(0.0, 0.5, jnt) * (1.0 - smoothstep(0.5, 1.0, jnt));
	float drip = smoothstep(0.45, 0.8, fbm(vec3(wp.x * 11.0, wp.y * 0.9, wp.z * 11.0) + tint * 5.0 + 41.0));
	float run_dn = drip * side * ruin * (0.55 + 0.45 * lip);
	col = mix(col, col * vec3(0.5, 0.52, 0.44), run_dn * 0.6);
	// lichen rosettes: yellow and grey-green crusts
	float l1 = smoothstep(0.7 - aged * 0.06, 0.76 - aged * 0.06, fbm(wp * 4.0 + 21.0));
	float l2 = smoothstep(0.68 - aged * 0.1, 0.74 - aged * 0.1, fbm(wp * 3.2 + 47.0));
	col = mix(col, lichen_y * (0.8 + 0.4 * vn(wp * 40.0)), l1 * mix(0.75, 0.3, field));
	col = mix(col, lichen_g * mix(0.8 + 0.4 * vn(wp * 35.0), 0.65 + 0.3 * vn(wp * 35.0), field), l2 * 0.6);
	// stile slab: its open faces carry more crust lichen than the coursed wall (a slab stands
	// clear of the wall's shade and drip), in clustered rosettes
	float sl1 = smoothstep(0.57, 0.63, fbm(wp * 5.5 + 71.0)) * smoothstep(0.35, 0.55, fbm(wp * 1.3 + 4.0));
	float sl2 = smoothstep(0.66, 0.7, fbm(wp * 8.0 + 13.0));
	col = mix(col, lichen_g * (0.7 + 0.45 * vn(wp * 45.0)), sl1 * 0.75 * slab);
	col = mix(col, lichen_y * (0.75 + 0.35 * vn(wp * 50.0)), sl2 * 0.65 * slab);
	col *= 1.0 - slab * side * smoothstep(0.5, 0.8, fbm(vec3(wp.x * 14.0, wp.y * 0.5, wp.z * 14.0) + 8.0)) * 0.3;
	// ...and where hands grip the top and coats and hips squeeze past the arrises it is
	// rubbed bare: smooth, darker, a faint greasy sheen, no lichen or moss
	float hab = wp.y - floor_w;
	float polish = slab * smoothstep(0.38, 0.6, hab) * (1.0 - smoothstep(1.25, 1.5, hab))
	             * max(smoothstep(0.15, 0.6, edge), smoothstep(0.55, 0.85, n.y))
	             * mix(0.6, 1.0, fbm(wp * vec3(3.0, 9.0, 3.0) + 5.0));
	col = mix(col, vec3(dot(col, vec3(0.3, 0.4, 0.3))) * vec3(1.0, 0.92, 0.8) * 0.68, polish * 0.85);
	// moss: on the tops, creeping down the lower courses and the shady joints
	float low = 1.0 - smoothstep(0.0, 2.5, above);
	// exposed bed tops of the laid courses: rain-darkened grey crust with soil and moss
	float cap = laid * smoothstep(0.25 + 0.1 * (1.0 - aged), 0.7, n.y);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.4, 0.3))) * mix(0.7, 0.55, aged), cap * mix(0.55, 0.8, aged));
	float topm = smoothstep(0.55, 0.9, n.y + (fbm(wp * 1.6) - 0.5) * 1.5 + cap * (0.25 + 0.2 * aged)) * 0.9;
	// field walls: moss on the tops only in cushions, not a green band along the whole cope;
	// about a third of the stones (later set, or turned by frost) bare grey
	float cush = smoothstep(0.42, 0.62, fbm(wp * vec3(1.1, 2.0, 1.1) + 29.0)) * step(0.33, fract(tint * 7.31));
	topm *= mix(1.0, mix(0.08, 1.0, cush), field);
	// the ruin's beds: moss in cushions and mats, thickest against the back arris and in the
	// joints where soil lodges, a few stones bare where it never took or peeled off in a dry
	// summer; the cushions' ragged edges break into separate tufts
	// (0.36-0.62 / tuft floor 0.55 / 18 % bare cut it to nothing that read in a shot)
	float mcush = smoothstep(0.25, 0.5, fbm(wp * vec3(2.6, 1.2, 2.6) + tint * 9.0 + 53.0)
	                         + (1.0 - smoothstep(0.0, 0.4, jnt)) * 0.25 + edge * 0.12);
	float tuft = smoothstep(0.25, 0.75, vn(wp * 24.0 + 3.0));
	float mbare = step(0.1, fract(tint * 13.37));
	topm *= mix(1.0, mix(0.05, 1.0, mcush * mix(0.75, 1.0, tuft)) * mix(0.1, 1.0, mbare), ruin * laid);
	float mossw = topm
	            + low * smoothstep(0.55 - aged * 0.12, 0.75 - aged * 0.1, fbm(wp * 2.2 + 5.0)) * (1.0 - edge * 0.5 * (1.0 - aged));
	// field walls: the low moss keeps to the shaded faces and the joints, not the open faces
	float shade_face = smoothstep(-0.1, 0.75, n.x) * smoothstep(0.35, 0.65, fbm(wp * 3.0 + 2.0));
	mossw *= mix(1.0, max(smoothstep(0.5, 0.85, n.y), max(shade_face, (1.0 - smoothstep(0.0, 0.35, jnt)) * 0.7)), field);
	mossw = clamp(mossw, 0.0, 1.0);
	vec3 mc = mix(moss_a, moss_b, fbm(wp * 7.0));
	// on the ruin the moss is a living pile, not a green film: fronds in a fine fibrous grain
	// (bright tips over dark stems), the thin edges of a mat and the joints a deep olive
	// shadow, the thick cushion cores yellow-green, dead brown patches burnt by the sun
	float fib = vn(wp * vec3(70.0, 40.0, 70.0)) * 0.6 + vn(wp * 150.0 + 7.0) * 0.4;
	vec3 mlive = mix(moss_dark, mix(moss_a, moss_b * 1.12, fbm(wp * 5.0 + 19.0)), smoothstep(0.2, 0.8, fib));
	mlive = mix(mlive * 0.55, mlive, smoothstep(0.05, 0.45, jnt) * smoothstep(0.15, 0.6, mcush));
	mlive = mix(mlive, moss_dry * (0.7 + 0.5 * fib), smoothstep(0.6, 0.72, fbm(wp * 6.0 + tint * 3.0 + 77.0)) * 0.8);
	mc = mix(mc, mlive, ruin);
	mc = mix(mc, vec3(dot(mc, vec3(0.3, 0.5, 0.2))) * vec3(0.95, 1.05, 0.85), field * 0.45) * mix(1.0, 0.82, field);
	// door stones: feet have worn the tops clean and a little paler and smoother; moss and
	// lichen keep to the arrises and the sunk edges
	float walked = trod * smoothstep(0.55, 0.85, n.y) * (1.0 - edge * 0.6);
	mossw *= 1.0 - walked * 0.92;
	// the walked top goes the warm buff grey of rubbed sandstone, not the cool field grey
	// (a little clouded: worn smooth here, foot-dulled and stained there)
	float rub = fbm(wp * vec3(5.0, 1.0, 5.0) + 11.0);
	col = mix(col, vec3(dot(col, vec3(0.3, 0.4, 0.3))) * vec3(1.14, 1.0, 0.8) * mix(0.92, 1.12, rub) + vec3(0.03, 0.022, 0.008), walked * mix(0.6, 0.85, rub));
	// the slab's sides and sunk edges carry the track's dirt
	col = mix(col, col * vec3(0.62, 0.52, 0.42), trod * (1.0 - smoothstep(0.35, 0.75, n.y)) * 0.7);
	mossw *= 1.0 - polish;
	col = mix(col, mc, mossw);
	col *= mix(0.72, 1.0, smoothstep(0.0, 1.2, above));       // damp lower courses
	// limewash: a white skin over everything above, the coats a little uneven
	float ab = wp.y - floor_w;     // per fragment (above is per stone)
	float coat = fbm(wp * 2.6 + 7.0);
	vec3 lwc = limewash * (0.9 + 0.12 * coat) * (0.97 + 0.05 * vn(wp * 90.0));
	lwc = mix(lwc, lwc * vec3(0.97, 0.97, 0.93), smoothstep(0.4, 0.8, fbm(wp * 0.7 + 3.0)));   // old coats yellowed
	// flaked back to the stone in ragged patches, more toward the foot and on the arrises
	// (small, and mostly low: big patches up the wall read as dark holes in the coat)
	float fn = fbm(wp * 3.4 + 13.0) + (1.0 - smoothstep(0.0, 1.2, ab)) * 0.12 + edge * 0.05
	         - smoothstep(1.0, 2.2, ab) * 0.06;
	float flake = smoothstep(0.71, 0.735, fn);
	// what shows is the stone under old coats: a warm pale grey with lime left in its pores,
	// the bare stone's moss and damp barely there; the broken coat's edge casts a thin shade
	vec3 under = mix(vec3(dot(col, vec3(0.3, 0.4, 0.3))) * vec3(1.05, 1.0, 0.92), vec3(0.47, 0.44, 0.39), 0.6);
	under = mix(under, lwc * 0.85, 0.3 * smoothstep(0.3, 0.7, vn(wp * 24.0)));
	float rim = smoothstep(0.69, 0.71, fn) * (1.0 - flake);
	vec3 lcol = mix(lwc * (1.0 - rim * 0.18), under, flake);
	// rain runs down from the eaves and under the sills: soft grey streaks
	float runs = smoothstep(0.5, 0.82, fbm(vec3(wp.x * 6.0, wp.y * 0.22, wp.z * 6.0) + 9.0)) * side;
	lcol *= 1.0 - runs * (0.08 + 0.14 * smoothstep(1.2, 2.6, ab));
	// splash grime and green algae rising from the ground, ragged at the top
	float splash = 1.0 - smoothstep(0.0, 0.45 + 0.35 * fbm(wp * vec3(2.5, 0.4, 2.5) + 1.0), ab);
	vec3 grimec = mix(vec3(0.36, 0.34, 0.29), lime_algae, smoothstep(0.4, 0.65, fbm(wp * 4.0 + 2.0)));
	lcol = mix(lcol, grimec * (0.85 + 0.3 * coat), splash * 0.8);
	col = mix(col, lcol, lw);
	mossw *= 1.0 - lw * (1.0 - splash * 0.5);
	// soot from Hesper's fire: a plume up the faces that look at it, densest low and right
	// over the fire, in billowed clouds with tide marks at the edge; the heat kept moss and
	// lichen off; the stones nearest the ring scorched dark too
	vec3 hv = wp - hearth_soot.xyz;
	float hh = hv.y;
	float hd = length(hv.xz);
	// the inner face stands ~0.55 m off the fire, so the plume core must already reach it at
	// the fire's foot (was 0.55 + 0.32/m with the core inside 0.3 m: the wall sat on its edge)
	float plume_r = 1.05 + max(hh, 0.0) * 0.42 + (fbm(wp * 2.6 + 3.0) - 0.5) * 0.45;
	float sees = smoothstep(-0.25, 0.35, dot(n, normalize(-hv + vec3(0.0, 0.4, 0.0))));
	float plume = (1.0 - smoothstep(plume_r * 0.62, plume_r, hd))
	            * smoothstep(-0.3, 0.1, hh) * (1.0 - smoothstep(2.5, 5.5, hh)) * sees;
	float skirt = (1.0 - smoothstep(0.5, 1.0, length(hv))) * mix(0.6, 1.0, sees);
	float soot = clamp(max(plume, skirt * 0.8), 0.0, 1.0) * hearth_soot.w;
	soot *= mix(0.75, 1.0, fbm(wp * 5.5 + 9.0));
	// real soot is near-black (~0.02): at half a metre from the fire anything paler still
	// reads as a lit stone, not a blackened one
	vec3 sootc = vec3(0.022, 0.019, 0.016) * (0.8 + 0.5 * vn(wp * 30.0));
	col = mix(col, sootc, soot * 0.97);
	mossw *= 1.0 - soot;
	// joints: grime and shade sinking into the gaps between the stones (the end and bed
	// faces only show through the open joints); upward faces (crown tops) stay open to the sky
	float up = smoothstep(0.5, 0.85, n.y);
	float jd = (1.0 - smoothstep(0.0, 0.55, jnt)) * mix(0.3, 1.0, laid) * (1.0 - up * 0.85);
	float deep = (1.0 - smoothstep(0.0, 0.2, jnt)) * mix(0.3, 1.0, laid) * (1.0 - up);
	// (a field wall's joints are mostly shadow already: darkening their albedo as well made
	// a near-black grid of them round pale stones)
	col *= 1.0 - (jd * 0.08 + deep * mix(0.4, 0.15, field)) * mix(1.0, 0.3, lw);   // lime fills the joints
	// soil and moss lodged in the low joints
	float lowj = deep * (1.0 - smoothstep(0.3, 1.8, above)) * smoothstep(0.35, 0.6, fbm(wp * 5.0 + 11.0));
	col = mix(col, mix(joint_soil, moss_a * 0.8, smoothstep(0.45, 0.7, fbm(wp * 9.0))), lowj * 0.9);
	mossw = max(mossw, lowj * 0.6);
	float rough = max(mix(0.82, 0.95, mossw) - edge * 0.08 - walked * 0.12 + spall * 0.05, soot * 0.97);
	rough = mix(rough, 0.48, polish);
	weather_wetten(col, rough, mix(0.4, 1.0, mossw));
	// door stones in the rain: the rubbed sandstone soaks a deep wet buff, and a skin of water
	// lies in the shallow dish feet have worn in the top -- glassy, the drops ringing it --
	// while the higher, rougher patches of the top only glisten
	float wet_top = walked * weather_wet;
	float dish = smoothstep(0.42, 0.6, rub * 0.6 + fbm(wp * vec3(2.6, 1.0, 2.6) + 41.0) * 0.6 - edge * 0.5);
	float film = wet_top * dish * smoothstep(0.3, 0.85, weather_wet);
	// under the film the stone goes deep and warm (water saturates its colour rather than
	// greying it), so the sheen is the sky's reflection on a dark wet top, not a milky haze
	col *= 1.0 - wet_top * 0.2 - film * 0.22;
	col = mix(col, col * vec3(1.08, 0.97, 0.82), film);
	rough = mix(rough, 0.05, film);
	rough = mix(rough, min(rough, 0.32), wet_top * (1.0 - film));
	ALBEDO = col;
	ROUGHNESS = rough;
	// soot is dead matte: no sheen of the fire on it; the wet top's broad glisten is held
	// down (water's own reflectance is low, ~2%) so only the glassy film catches the light
	SPECULAR = 0.4 * (1.0 - soot * 0.95) * (1.0 - wet_top * (1.0 - film) * 0.35);
	// the spall's sunk floor: tilt the normal across its rim (the gradient of the spall field) so
	// each scallop catches the light on one side and shades on the other
	float se = 0.01;
	vec3 sg = vec3(fbm((wp + vec3(se, 0, 0)) * 3.6 + tint * 19.0), fbm((wp + vec3(0, se, 0)) * 3.6 + tint * 19.0),
	               fbm((wp + vec3(0, 0, se)) * 3.6 + tint * 19.0)) - fbm(wp * 3.6 + tint * 19.0);
	sg /= se;
	float rim_w = smoothstep(0.62, 0.67, spn) * (1.0 - smoothstep(0.67, 0.72, spn)) * ruin * (1.0 - mossw);
	// the moss pile's fronds: a fibrous bump in the normal (the stone's tooling smoothed out
	// under it), so a lit mat breaks into tiny highlights and shades rather than a flat sheen
	float me = 0.004;
	vec3 mg = vec3(vn((wp + vec3(me, 0, 0)) * 70.0), vn((wp + vec3(0, me, 0)) * 70.0), vn((wp + vec3(0, 0, me)) * 70.0)) - vn(wp * 70.0);
	mg /= me;
	vec3 pn = normalize(n - (g - n * dot(g, n)) * mix(mix(0.02, 0.034, ruin), 0.006, mossw) * mix(1.0, 0.45, lw) * (1.0 - film * 0.85)
	                    + (sg - n * dot(sg, n)) * rim_w * 0.09
	                    - (mg - n * dot(mg, n)) * mossw * ruin * 0.006);
	if (film > 0.01 && weather_rain > 0.01) {
		vec2 sl = rain_ripples(wp.xz, TIME, weather_rain) * 0.05 * film;
		pn = normalize(pn + vec3(-sl.x, 0.0, -sl.y));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = clamp(0.65 + s * 0.5, 0.0, 1.0) * (1.0 - (jd * 0.3 + deep * 0.3) * mix(1.0, 0.45, field)) * (1.0 - sp_rim * 0.3)
	   * (1.0 - mossw * ruin * (1.0 - fib) * 0.35);
	ALBEDO *= v_cloud;
	// bounce: strongest on faces turned sideways/down toward the lit ground, weak on tops
	// (they see the sky, which the ambient already covers); joints and pits get less
	float facing = mix(1.0, 0.5, clamp(n.y, 0.0, 1.0));
	// inside the keep the floor stones and rubble tops face the lit inner wall
	facing *= mix(1.0, bounce_gain(wp), clamp(n.y, 0.0, 1.0));
	EMISSION = ALBEDO * bounce_light * facing * AO;
	// low sun: the open sky over a level top, unoccluded by SSAO (which crushed the door
	// stones to black in the cottage's shade while the earth round them was lifted)
	EMISSION += ALBEDO * ground_fill * smoothstep(0.5, 0.9, n.y) * AO;
}
