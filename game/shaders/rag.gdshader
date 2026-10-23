shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// Hollow rags: coarse undyed hemp gone grey with ash, stiff with soot near the torn hems,
// singed at the edges where the Ember's heat leaks out. UV.x runs around/across the piece,
// UV.y from where it is fastened (0) to the hem (1). The hem is torn by discard; a few moth
// holes and burns go right through. `sway` (body space, metres) is the swing the script feeds
// from the legs and the body's motion; the cloth bends with it more the further from the seam.
// Shares `ember`, `hit_flash` and `dissolve` with hollow.gdshader so it flares and burns away
// with the body.

uniform vec3 cloth_dark : source_color = vec3(0.11, 0.10, 0.088);
uniform vec3 cloth_light : source_color = vec3(0.46, 0.42, 0.36);
uniform vec3 ember_col : source_color = vec3(1.0, 0.36, 0.08);
uniform float weave_scale = 260.0;  // threads per UV unit along x
uniform float aspect = 1.0;         // piece length / width, keeps the weave square
uniform float tear = 0.12;          // how deep the hem tears reach (UV.y)
uniform float tongues = 7.0;        // how many ragged tongues across the hem
uniform float holes = 0.0;          // 0..1 how moth-eaten
uniform float seed = 0.0;
uniform float ember = 1.0;
uniform float hit_flash = 0.0;
uniform float dissolve = 0.0;
uniform vec3 sway = vec3(0.0);
uniform float time_offset = 0.0;
uniform float soot_amt = 1.0;      // how much soot/grime darkens the hem (1 = Hollow rags)
uniform float rigid = 0.0;         // 1: a stiff piece (a straw hat): no flutter or swing
uniform float wrap_turns = 0.0;
uniform float fold_ao = 0.0;       // > 0: COLOR.r is a fold cavity term (dark in the valleys)
uniform float felt = 0.0;          // > 0: pressed felt (a hat): matte, no fibre sheen, grey-brown stains
uniform float fuzz_ratio = 0.39;    // wool fuzz grain length across / along the hang (1 = no streaks)
uniform float wool = 0.0;          // > 0: heavy fulled wool: fibre fuzz, pilling, soft creases, sheen
uniform float weathered = 0.0;     // > 0 (a hanging wool piece): faded top, damp hem, rubbed edge, mud flecks
uniform vec2 gore_swing = vec2(0.0); // a side gore: the front/back panel swings (rad) its ends follow
uniform vec2 fold2 = vec2(1000.0, 0.0); // a second, further fold (where it meets the ground)
uniform vec2 fold = vec2(1000.0, 0.0); // a panel: (distance down from the seam, angle) it bends at, over the knees
uniform float gore = 0.0;          // 1: this piece is a side gore
uniform vec2 gore_fold_f = vec2(1000.0, 0.0);  // the front panel's folds, which the gore's front end follows
uniform vec2 gore_fold_f2 = vec2(1000.0, 0.0);
uniform vec2 gore_fold_b = vec2(1000.0, 0.0);   // the back panel's fold
uniform float gore_top = 1.21;     // the gore's seam height (model space)
uniform vec4 arm_l = vec4(0.0);     // the mantle: an elbow (mesh space, w 1 = in use) the cape lifts over
uniform vec4 arm_r = vec4(0.0);
uniform float hem_band = 0.0;      // > 0: a turned and stitched hem instead of a raw edge     // > 0: a bandage tube (UV.x around): spiral strips, rides rigid

uniform float plumb = 0.0;         // > 0 (a cape): below hang_top the cloth falls toward world down, not the bone's -Y
uniform float hang_top = 1.62;     // model-space height the hang pivots at (where the cape leaves the shoulders)
uniform vec3 hang_body = vec3(0.245, 0.22, -0.015); // the torso under it (model space): x/z radii, z centre
varying float hem_w;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return s;
}

// one over-under thread pattern, slightly irregular
float weave(vec2 wv) {
	float jitter = vnoise(wv * 0.13) * 0.6;
	float warp = 0.5 + 0.5 * sin((wv.x + jitter) * 6.2832);
	float weft = 0.5 + 0.5 * sin((wv.y - jitter) * 6.2832);
	float over = step(0.5, fract(floor(wv.x) * 0.5 + floor(wv.y) * 0.5));
	return mix(warp, weft, over);
}

void fold_panel(inout vec3 v, inout vec3 n, vec2 f) {
	float fd = -v.y - f.x;
	if (fd > 0.0) {
		float fa = f.y * smoothstep(0.0, 0.07, fd);
		float cs = cos(fa);
		float sn = sin(fa);
		vec2 r = vec2(v.y + f.x, v.z);
		v.yz = vec2(r.x * cs - r.y * sn - f.x, r.x * sn + r.y * cs);
		n.yz = vec2(n.y * cs - n.z * sn, n.y * sn + n.z * cs);
	}
}

// The mantle over a raised arm: the cape's radial lines near the elbow's bearing turn up and
// out about the collar ring (y 1.72, radius 0.1485, centred z -0.045) until they pass over the
// elbow, the way heavy wool lifts and tents over an arm reached up beneath it. Must match
// HeroGarb.cape_lift() (the bots read that).
void lift_over_arm(inout vec3 v, inout vec3 n, vec4 e, float a) {
	if (e.w <= 0.0) {
		return;
	}
	vec2 eo = vec2(e.x, e.z + 0.045);
	float ae = atan(eo.x, eo.y);
	float da = mod(a - ae + PI, TAU) - PI;
	float wa = exp(-pow(da / 0.55, 2.0)) * e.w;
	float re = length(eo);
	float th = atan(re - 0.1485, 1.72 - e.y) + atan(0.07, max(length(vec2(re - 0.1485, 1.72 - e.y)), 0.1));
	float d = clamp(th - 0.5, 0.0, 1.6) * wa;
	if (d <= 0.0) {
		return;
	}
	vec3 rn = vec3(sin(a), 0.0, cos(a));
	vec3 c = vec3(0.0, 1.72, -0.045) + rn * 0.1485;
	vec3 k = vec3(-rn.z, 0.0, rn.x);
	float cs = cos(d);
	float sn = sin(d);
	vec3 p = v - c;
	v = c + p * cs + cross(k, p) * sn + k * dot(k, p) * (1.0 - cs);
	n = n * cs + cross(k, n) * sn + k * dot(k, n) * (1.0 - cs);
}

void vertex() {
	float w = UV.y * UV.y * step(wrap_turns, 0.0) * (1.0 - rigid);
	hem_w = w;
	// a robe panel folding over the knees and onto the ground: below each fold the cloth turns
	// about the panel's x axis, eased in over a few centimetres so the bend is soft; the far
	// fold first, so the near one carries it round
	fold_panel(VERTEX, NORMAL, fold2);
	fold_panel(VERTEX, NORMAL, fold);
	// a cape on a stooped or leaning chest: rigid to the bone its back flared out behind like a
	// stiff flap; below the shoulders let it fall along world down instead, each point by its
	// drop from the pivot, then rest it on the torso (an ellipse) where that would sink it in
	if (plumb > 0.0) {
		float drop = max(hang_top - VERTEX.y, 0.0);
		vec3 dn = normalize(inverse(mat3(MODEL_MATRIX)) * vec3(0.0, -1.0, 0.0));
		vec3 p = VERTEX + plumb * (dn - vec3(0.0, -1.0, 0.0)) * drop;
		vec2 q = vec2(p.x / hang_body.x, (p.z - hang_body.z) / hang_body.y);
		float e = length(q);
		vec2 q0 = vec2(VERTEX.x / hang_body.x, (VERTEX.z - hang_body.z) / hang_body.y);
		if (e < 1.0 && length(q0) >= 1.0 && e > 0.001) {
			p.x *= 1.0 / e;
			p.z = hang_body.z + (p.z - hang_body.z) / e;
		}
		VERTEX = p;
	}
	// then up over a raised elbow (the mantle only: arm_l/arm_r w is 0 on every other piece)
	float ca = mix(0.42, TAU - 0.42, UV.x);
	lift_over_arm(VERTEX, NORMAL, arm_l, ca);
	lift_over_arm(VERTEX, NORMAL, arm_r, ca);
	// a slow breathing flutter plus the fed swing; the hem lags the seam
	float tt = TIME + time_offset;
	float flutter = sin(tt * 1.7 + UV.x * 9.0 + seed) * 0.012 + sin(tt * 3.1 + UV.x * 17.0) * 0.005;
	VERTEX += NORMAL * flutter * w;
	VERTEX += sway * w;
	// a side gore's front end (UV.x 0) rides out with the front panel, its back end with the
	// back panel, the side seam between them stays put, so no gap opens at either panel's edge;
	// each end swings round like its panel and folds where the panel folds (over the knees,
	// onto the ground), walked down the drop in short steps since the bends mix
	if (gore > 0.5) {
		float drop = max(gore_top - VERTEX.y, 0.0);
		float wf = (1.0 - UV.x) * (1.0 - UV.x);
		float wb = UV.x * UV.x;
		vec2 p = vec2(0.0);
		float st = drop / 14.0;
		for (int i = 0; i < 14; i++) {
			float d = (float(i) + 0.5) * st;
			float tf = gore_swing.x - gore_fold_f.y * smoothstep(0.0, 0.07, d - gore_fold_f.x)
					- gore_fold_f2.y * smoothstep(0.0, 0.07, d - gore_fold_f2.x);
			float tb = -gore_swing.y - gore_fold_b.y * smoothstep(0.0, 0.07, d - gore_fold_b.x);
			float t = tf * wf + tb * wb;
			p += st * vec2(sin(t), -cos(t));
		}
		VERTEX.z += p.x;
		VERTEX.y += p.y + drop;
	}
}

void fragment() {
	vec2 uv = vec2(UV.x, UV.y * aspect) + seed;
	// torn hem: ragged tongues of cloth, frayed at the very edge
	float tongue = fbm(vec2(UV.x * tongues + seed, seed * 3.0)) * 1.4 - 0.2;
	// a turned, stitched hem does not fray: only a few loose fibres break its line
	float fray = vnoise(vec2(UV.x * 160.0, seed)) * 0.025 * (1.0 - 0.85 * clamp(hem_band, 0.0, 1.0));
	float edge = 1.0 - tear * clamp(tongue, 0.0, 1.0) - fray;
	float to_hem = edge - UV.y;
	if (to_hem < 0.0) discard;
	// moth holes and burns
	float hn = fbm(uv * 6.0 + 2.3);
	if (holes > 0.0 && hn > 0.78 - holes * 0.12 && UV.y > 0.12) discard;
	float burn_rim = smoothstep(0.66 - holes * 0.12, 0.78 - holes * 0.12, hn) * step(0.12, UV.y) * step(0.001, holes);
	// weave: warp and weft threads, slightly irregular
	vec2 wv = uv * weave_scale;
	// the weave fades to its average where a thread gets smaller than a pixel
	float fine = 1.0 - smoothstep(0.25, 0.6, length(fwidth(wv)));
	float thread = mix(0.5, weave(wv), fine);
	float tx = (weave(wv + vec2(0.15, 0.0)) - weave(wv)) * fine;
	float ty = (weave(wv + vec2(0.0, 0.15)) - weave(wv)) * fine;
	// bandage: each turn's edge laps over the last, with a shadowed crease under the lap
	float band = 1.0;
	if (wrap_turns > 0.0) {
		float b = fract(UV.y * wrap_turns + UV.x + vnoise(vec2(UV.x * 5.0, UV.y * 3.0) + seed) * 0.08);
		band = smoothstep(0.0, 0.08, b) * (0.85 + 0.15 * smoothstep(0.98, 0.9, b));
		ty += (smoothstep(0.92, 1.0, b) - smoothstep(0.0, 0.06, b)) * 0.6;
	}
	// turned hem: a doubled band above the edge, a shadow line where the fold-over is sewn
	// and a soft rounded lip at the very edge
	float hem_shade = 1.0;
	if (hem_band > 0.0) {
		float hb = 0.055;
		float seam = 1.0 - smoothstep(0.0, 0.006, abs(to_hem - hb));
		float lip = smoothstep(0.0, 0.02, to_hem);
		hem_shade = mix(1.0, (1.0 - 0.35 * seam) * mix(0.75, 1.0, lip), hem_band);
		ty += (seam * 0.8 - (1.0 - lip) * 0.6) * hem_band;
	}
	// fulled wool: a fuzz of loose fibres over the weave, small pills, and soft creases where
	// the cloth bunches, running mostly down the hang (UV.y); fades out with distance like the
	// weave so it never shimmers
	float fuzz = 0.0;
	float pill = 0.0;
	float crease_dark = 0.0;
	if (wool > 0.0) {
		vec2 fv = uv * weave_scale * vec2(2.3, 2.3 * fuzz_ratio);
		float wfine = 1.0 - smoothstep(0.4, 1.2, length(fwidth(fv)));
		fuzz = (vnoise(fv) - 0.5 + 0.5 * (vnoise(fv * 2.7 + 7.0) - 0.5)) * wfine;
		pill = smoothstep(0.72, 0.9, vnoise(uv * weave_scale * 0.35 + 3.0)) * wfine;
		vec2 cv = uv * vec2(9.0, 3.0) + seed;
		float c0 = fbm(cv);
		float cx = fbm(cv + vec2(0.04, 0.0)) - c0;
		float cy = fbm(cv + vec2(0.0, 0.04)) - c0;
		// a second, tighter set of rumples so the creases read at arm's length, not only as
		// broad swells
		vec2 cv2 = uv * vec2(22.0, 9.0) + seed * 1.7 + 5.0;
		float d0 = vnoise(cv2);
		float dx = vnoise(cv2 + vec2(0.05, 0.0)) - d0;
		float dy = vnoise(cv2 + vec2(0.0, 0.05)) - d0;
		tx = mix(tx * 0.6, tx * 0.6 + cx * 14.0 + dx * 5.0, wool) + fuzz * 0.25 * wool;
		ty = mix(ty * 0.6, ty * 0.6 + cy * 7.0 + dy * 3.0, wool) + fuzz * 0.25 * wool;
		crease_dark = smoothstep(0.42, 0.3, c0) * 0.25 + smoothstep(0.45, 0.25, d0) * 0.1;
		thread = mix(thread, 0.5 + (thread - 0.5) * 0.6, wool);
	}
	float slub = vnoise(vec2(uv.x * 4.0, uv.y * 140.0));
	// grime: streaks running down from the seams, soot climbing up from the hem
	float grime = fbm(uv * vec2(3.0, 0.8) + 9.1);
	float soot = (smoothstep(0.18, 0.0, to_hem) * 0.65 + burn_rim * 0.8) * soot_amt;
	// (slub runs in bands across the hang: on fulled wool it read as wood-grain rings, so wool
	// takes a blotchy, near-round mottle instead)
	float mottle = fbm(uv * vec2(7.0, 6.0) + 17.0) - 0.5;
	float tone = clamp(0.35 + 0.45 * grime + 0.2 * mix(slub, 0.5 + mottle, clamp(wool, 0.0, 1.0)), 0.0, 1.0);
	vec3 alb = mix(cloth_dark, cloth_light, tone);
	// old dye and rust stains in blotches
	float stain = smoothstep(0.55, 0.75, fbm(uv * 2.2 + 31.0));
	alb = mix(alb, alb * mix(vec3(0.78, 0.62, 0.5), vec3(0.72, 0.72, 0.71), felt), stain * 0.6);
	alb *= 0.86 + 0.14 * thread;
	alb *= 1.0 + wool * (0.22 * fuzz + 0.12 * pill);
	// worn wool: rubbed thin and faded in broad patches, darker and greasier in the crease
	// valleys, and a dusting of dry road dust where the cloth faces the sky (the shoulders)
	vec3 up_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	if (wool > 0.0) {
		float wear = smoothstep(0.5, 0.7, fbm(uv * vec2(3.5, 2.5) + 41.0));
		alb *= (1.0 + 0.18 * wear * wool) * (1.0 - crease_dark * wool);
		float dust = smoothstep(0.35, 0.85, up_n.y) * (0.45 + 0.55 * fbm(uv * 14.0 + 61.0));
		alb = mix(alb, vec3(0.30, 0.27, 0.22), clamp(dust * 0.45 * wool, 0.0, 0.5));
		// weathering broad enough to read at a few metres (the fine fuzz averages out there and
		// the cape read as one even sheet): sun-faded and greyed down the top of the hang, damp
		// and darker toward the hem, rubbed paler along the edge, and road mud flecked up from it
	}
	if (weathered > 0.0) {
		float hang = clamp(UV.y / max(edge, 0.01), 0.0, 1.0);
		float fade = (1.0 - smoothstep(0.0, 0.45, hang)) * (0.6 + 0.4 * fbm(uv * vec2(2.0, 4.0) + 71.0));
		alb = mix(alb, vec3(dot(alb, vec3(0.33))) * vec3(1.06, 1.02, 0.96) * 1.22, fade * 0.45 * weathered);
		float damp = smoothstep(0.45, 1.0, hang) * (0.55 + 0.45 * fbm(vec2(UV.x * 5.0, UV.y * 2.0) + 83.0));
		alb *= 1.0 - 0.28 * damp * weathered;
		float rub = (1.0 - smoothstep(0.0, 0.035, to_hem)) * (0.5 + 0.5 * vnoise(vec2(UV.x * 40.0, seed)));
		alb = mix(alb, alb * 1.35 + vec3(0.02), rub * 0.6 * weathered);
		float fleck = smoothstep(0.62, 0.8, vnoise(uv * vec2(55.0, 30.0) + 91.0))
				* smoothstep(0.16, 0.02, to_hem) * smoothstep(0.3, 0.6, fbm(vec2(UV.x * 6.0, 3.0) + seed));
		alb = mix(alb, vec3(0.085, 0.07, 0.05), clamp(fleck * 0.8 * weathered, 0.0, 0.8));
	}
	alb *= mix(0.45, 1.0, band) * hem_shade * mix(1.0, mix(0.7, 0.55, clamp(wool, 0.0, 1.0)) + mix(0.3, 0.45, clamp(wool, 0.0, 1.0)) * COLOR.r, fold_ao);
	alb = mix(alb, vec3(0.035, 0.03, 0.027), clamp(soot, 0.0, 0.9));
	// singed edges glow faintly where the ember's heat reaches the tear
	float singe = (1.0 - smoothstep(0.0, 0.012, to_hem)) * step(0.5, fbm(vec2(UV.x * 23.0, seed)));
	float glow = singe * 0.25 * ember + hit_flash * 0.15 * smoothstep(0.1, 0.0, to_hem);
	if (dissolve > 0.0) {
		float d = fbm(uv * 9.0) * 0.8 + 0.2 * UV.y;
		if (d < dissolve * 1.1) discard;
		glow += (1.0 - smoothstep(0.0, 0.06, d - dissolve * 1.1)) * 2.5;
	}
	if (!FRONT_FACING) alb *= 0.55;
	float rough = mix(0.93 - 0.06 * thread, 0.99, felt);
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, grime), 1.0);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = mix(0.3, 0.12, felt);
	METALLIC = 0.0;
	// thread relief: the weave catches the light at grazing angles
	NORMAL_MAP = normalize(vec3(-tx * 1.2, ty * 1.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;
	AO = mix(0.7, 1.0, thread) * mix(0.5, 1.0, band) * mix(1.0, COLOR.r, fold_ao);
	AO_LIGHT_AFFECT = 0.3;
	// a tightly plaited straw hat is opaque: no light through its underside
	BACKLIGHT = vec3(0.12, 0.10, 0.08) * (1.0 - 0.9 * rigid);
	// the meadow's warm bounce turned a near-black felt hat orange-brown: felt takes a greyer fill
	vec3 fill = figure_fill(alb, wet_n, wet_p);
	fill = mix(fill, vec3(dot(fill, vec3(0.3, 0.55, 0.15))), 0.7 * felt);
	EMISSION = ember_col * glow * 3.0 + fill * mix(1.0, COLOR.r, fold_ao);
	// wool fibres standing off the surface scatter a soft sheen at grazing angles
	RIM = mix(max(0.35 * wool, 0.1), 0.06, felt);
	RIM_TINT = 0.4;
}
