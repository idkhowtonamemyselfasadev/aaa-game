shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Far mountain ring (world/horizon.gd). Seen from 0.3-3 km, so it carries macro shape only:
// near the tile edge it matches the Vale meadow, then dark conifer/oak forest on the
// foothills, bare scree and rock on steep faces, snow on the high ridges. Aerial perspective
// comes from the environment fog.

uniform vec3 meadow_a : source_color = vec3(0.30, 0.24, 0.09);
uniform vec3 meadow_b : source_color = vec3(0.55, 0.42, 0.17);
uniform vec3 forest_a : source_color = vec3(0.07, 0.09, 0.05);
uniform vec3 forest_b : source_color = vec3(0.16, 0.17, 0.08);
// dark weathered granite/schist: the old 0.36 grey went near-white under the warm haze and
// read as plaster cones; real far rock is darker than the sky behind it
uniform vec3 rock_a   : source_color = vec3(0.25, 0.235, 0.21);
uniform vec3 rock_b   : source_color = vec3(0.10, 0.095, 0.09);
// alpine turf / dwarf scrub between the treeline and the bare faces
uniform vec3 alpine   : source_color = vec3(0.17, 0.17, 0.09);
uniform vec3 snow     : source_color = vec3(0.78, 0.80, 0.84);
uniform float tile_half = 256.0;
uniform float snow_line = 470.0;
// 0 by day .. 1 at full night (world.gd). Moonlit snow and scree read as pale grey cut-outs
// against the black night sky; the far ring sinks toward a dark silhouette instead.
uniform float night = 0.0;
// Own aerial perspective (world.gd sets both from the environment fog each update). The
// scene fog (exp 0.0012, half of it sampled from the bright sky radiance) left ~90% haze at
// 1.5-2.5 km, so the massifs read as one milky flat wash. Real far ranges stay darker and
// bluer than the sky behind them, with forest and rock still breaking up their faces.
uniform vec3 haze_color = vec3(0.42, 0.48, 0.58);
uniform float haze_density = 0.0012;
// 0.5 still left ~70% haze at 2 km on a clear day and flattened the massif faces into one
// grey value; storms raise haze_density x7, so they still swallow the ring
uniform float haze_scale = 0.4;

#include "res://shaders/cloud_shadow.gdshaderinc"

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
	           mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, r = 0.0;
	for (int k = 0; k < 5; k++) { r += a * vnoise(p); p = p * 2.07 + 3.3; a *= 0.5; }
	return r;
}

// ridged value noise (sharp crests where the noise crosses 0.5)
float rnoise(vec2 x) {
	return 1.0 - abs(vnoise(x) * 2.0 - 1.0);
}
// Erosion relief the 10-40 m mesh cells cannot carry, in metres: gullies running straight
// down the fall line (narrow across it, long along it), crags at ~60 m and a rubble grain.
// `down` is the unit horizontal fall direction at the pixel, `steep` 0..1 how much bare face.
float relief(vec2 p, vec2 down, float steep) {
	vec2 across = vec2(-down.y, down.x);
	vec2 q = vec2(dot(p, across), dot(p, down));
	float gul = rnoise(q * vec2(1.0 / 26.0, 1.0 / 140.0)) * 0.65
	          + rnoise(q * vec2(1.0 / 11.0, 1.0 / 60.0) + 7.1) * 0.35;
	float crag = fbm(p * (1.0 / 60.0) + 11.0);
	float grain = vnoise(p * 0.3);
	return steep * (gul * gul * 14.0 + crag * 10.0) + crag * 4.0 + grain * 0.6;
}

void fragment() {
	vec3 n = normalize(wnrm);
	// per-pixel erosion relief: finite differences of `relief` bend the coarse mesh normal,
	// so far faces break into gullies and crags instead of reading as flat facets
	float hl = length(n.xz);
	vec2 down = hl > 1e-4 ? n.xz / hl : vec2(1.0, 0.0);
	float steep0 = smoothstep(0.15, 0.45, 1.0 - n.y);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float e = clamp(dist * 0.0015, 0.8, 4.0);                 // ~ a pixel's footprint
	float detail = 1.0 - smoothstep(2200.0, 3400.0, dist);   // fade before it aliases
	float r0 = relief(wpos.xz, down, steep0);
	float rx = relief(wpos.xz + vec2(e, 0.0), down, steep0);
	float rz = relief(wpos.xz + vec2(0.0, e), down, steep0);
	vec2 grad = vec2(rx - r0, rz - r0) / e * detail;
	n = normalize(n - vec3(grad.x, 0.0, grad.y) * 0.9);
	float crease = clamp(r0 / (2.0 + steep0 * 22.0), 0.0, 1.0);   // 0 in a gully floor
	float d = max(abs(wpos.x), abs(wpos.z)) - tile_half;     // metres outside the Vale tile
	float slope = 1.0 - n.y;
	float macro = fbm(wpos.xz * 0.004);
	float meso  = fbm(wpos.xz * 0.03);
	float fine  = fbm(wpos.xz * 0.25);
	// forest: patches that thin out with altitude and on steep ground; tree-crown speckle
	// macro face structure that survives 2-3 km (a pixel is ~2.5 m there, the gully normals fade
	// out): long couloirs down the fall line at 70-200 m, the ribs between them standing out
	// lighter, so a far face reads as rock architecture instead of one flat grey value
	vec2 acr = vec2(-down.y, down.x);
	vec2 fq = vec2(dot(wpos.xz, acr), dot(wpos.xz, down));
	float coul = rnoise(fq * vec2(1.0 / 95.0, 1.0 / 420.0) + 3.7) * 0.6
	           + rnoise(fq * vec2(1.0 / 38.0, 1.0 / 170.0) + 9.2) * 0.4;
	coul = smoothstep(0.35, 0.95, coul);                     // 1 on a rib crest, 0 in a couloir
	// forest climbs the lower flanks in tongues up the couloirs (deeper soil, shelter), thinning
	// on the ribs: tongues of dark trees break up the massif bodies under the rock
	float tl = snow_line - 170.0 + (macro - 0.5) * 120.0 + (1.0 - coul) * 70.0;
	float forest = smoothstep(0.26, 0.42, macro + meso * 0.25 - 0.1 + (1.0 - coul) * 0.12)
	             * (1.0 - smoothstep(0.5, 0.8, slope + (meso - 0.5) * 0.2 + coul * 0.1))
	             * (1.0 - smoothstep(tl - 60.0, tl + 20.0, wpos.y));
	forest *= smoothstep(20.0, 140.0, d);
	// avalanche chutes: below the treeline the couloirs are swept clear of trees, so pale
	// strips of turf and scree run down through the dark forest and break up the lower flanks
	// (the flanks read as one flat grey-blue wash at 1.5-2.5 km otherwise)
	float chute = (1.0 - smoothstep(0.1, 0.32, coul + (fine - 0.5) * 0.15))
	            * smoothstep(tl - 330.0, tl - 140.0, wpos.y + (macro - 0.5) * 90.0)
	            * smoothstep(140.0, 260.0, d);
	forest *= 1.0 - chute * 0.92;
	// cliff bands: harder beds crop out along the strike as broken dark rock steps across
	// the flanks, each with a pale talus apron fanning out below it
	float strike = dot(wpos.xz, acr) / 520.0;
	float bandv = vnoise(vec2(wpos.y / 36.0 + macro * 3.0, strike));
	float bandu = vnoise(vec2((wpos.y + 22.0) / 36.0 + macro * 3.0, strike));
	float flank = smoothstep(150.0, 260.0, d) * (1.0 - smoothstep(snow_line - 80.0, snow_line, wpos.y));
	float cliff = smoothstep(0.7, 0.78, bandv + (meso - 0.5) * 0.25) * flank;
	float scree = smoothstep(0.68, 0.78, bandu + (meso - 0.5) * 0.25) * (1.0 - cliff) * flank
	            * smoothstep(0.25, 0.6, 1.0 - coul + fine * 0.3);
	forest *= 1.0 - max(cliff, scree * 0.85);
	vec3 meadow = mix(meadow_a, meadow_b, clamp(meso * 0.8 + fine * 0.3 - 0.2, 0.0, 1.0));
	vec3 trees  = mix(forest_a, forest_b, fine * 0.7 + meso * 0.3);
	// stands of different age and species: dark spruce blocks beside lighter birch/larch
	trees *= mix(0.65, 1.55, smoothstep(0.35, 0.7, fbm(wpos.xz * 0.0016 + 21.0)));
	// rock on steep faces, with strata bands so cliffs read at distance
	float strata = vnoise(vec2(wpos.y * 0.15 + meso * 3.0, macro * 4.0));
	float rockw = smoothstep(0.3, 0.55, slope + (meso - 0.5) * 0.3);
	// the massif bodies are only ~25-30 deg overall, too gentle for the slope test, so above
	// the treeline the ribs break out as bare rock by altitude and the turf keeps the couloirs
	float above = smoothstep(tl + 10.0, tl + 130.0, wpos.y + (meso - 0.5) * 60.0);
	rockw = max(rockw, above * smoothstep(0.3, 0.65, coul + (fine - 0.5) * 0.35) * 0.95);
	vec3 rock = mix(rock_b, rock_a, strata * 0.6 + fine * 0.4);
	rock *= mix(0.45, 1.1, crease);                           // shadowed gully floors
	rock *= mix(0.55, 1.35, coul);                            // dark wet couloirs, pale ribs
	// snow: above the line, only where it can settle (flatter), streaky down gullies; it lies
	// in the gullies longer than on the ribs between them
	float snoww = smoothstep(snow_line - 30.0, snow_line + 40.0,
	                         wpos.y + (meso - 0.5) * 90.0 + (1.0 - crease) * 60.0 * steep0)
	            * (1.0 - smoothstep(0.42, 0.7, slope - fine * 0.2 - (1.0 - crease) * 0.3));
	// firn and old avalanche snow lie on in the couloirs well below the summit snowfields:
	// pale streaks down the dark rock, the strongest value break a far face has
	float gsnow = smoothstep(snow_line - 190.0, snow_line - 60.0, wpos.y + (meso - 0.5) * 70.0)
	            * (1.0 - smoothstep(0.12, 0.42, coul + (fine - 0.5) * 0.2));
	snoww = max(snoww, gsnow * 0.9);
	// above the treeline and on ribs too steep for forest: dark turf and scrub, not bare grey
	// the turf zone is the broad mid band of every massif: at 2 km the haze compresses small
	// value steps to nothing, so it needs big patches -- dark dwarf pine/juniper on the ribs,
	// pale dry grass and scree in the couloirs, sunlit meadow shelves between
	float shelf = smoothstep(0.45, 0.7, fbm(wpos.xz * 0.0025 + 5.0));
	vec3 turf = alpine * (0.75 + 0.5 * meso) * mix(0.6, 1.0, crease);
	turf = mix(turf * 0.45, turf * vec3(1.9, 1.75, 1.35), (1.0 - coul) * 0.8 + shelf * 0.5);
	vec3 col = mix(turf, meadow, 1.0 - smoothstep(60.0, 220.0, d));
	// chute floors: light grass and avalanche debris, brighter than the forest either side
	vec3 chutec = mix(alpine * 2.1, rock_a * 1.25, smoothstep(0.4, 0.75, fine + coul * 0.3));
	col = mix(col, chutec, chute * (1.0 - forest));
	col = mix(col, trees, forest);
	col = mix(col, rock_a * vec3(1.45, 1.4, 1.3) * (0.8 + 0.4 * fine), scree);
	col = mix(col, rock_b * (0.8 + 0.6 * strata), cliff * 0.95);
	col = mix(col, rock, rockw);
	col = mix(col, snow, snoww);
	col *= 0.85 + 0.3 * fine;
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.95, 0.85, rockw), 0.6, snoww);
	SPECULAR = mix(0.1, 0.35, snoww);
	// forest canopy reads lumpy under low sun
	n = normalize(n + vec3(fine - 0.5, 0.0, meso - 0.5) * 0.35 * forest);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// cloud shadows sweep the far ridges (per pixel: the ridge mesh is coarse)
	ALBEDO *= cloud_shade_at(wpos);
	// night: the ring darkens with distance into a silhouette (a dark mountain against the
	// starlit sky, as at night the land is darker than the sky glow over it); the snow fields
	// lose most of their moonlit glare, so only the nearest ribs keep a faint modelling
	float far = smoothstep(250.0, 1100.0, dist);
	ALBEDO *= mix(1.0, mix(0.7, 0.36, far), night) * mix(1.0, 0.72, night * snoww);
	SPECULAR *= 1.0 - 0.7 * night;
	FOG = vec4(haze_color, 1.0 - exp(-dist * haze_density * haze_scale));
}
