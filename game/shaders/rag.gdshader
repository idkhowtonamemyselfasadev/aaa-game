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
uniform float wool = 0.0;          // > 0: heavy fulled wool: fibre fuzz, pilling, soft creases, sheen
uniform float hem_band = 0.0;      // > 0: a turned and stitched hem instead of a raw edge     // > 0: a bandage tube (UV.x around): spiral strips, rides rigid

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

void vertex() {
	float w = UV.y * UV.y * step(wrap_turns, 0.0) * (1.0 - rigid);
	hem_w = w;
	// a slow breathing flutter plus the fed swing; the hem lags the seam
	float tt = TIME + time_offset;
	float flutter = sin(tt * 1.7 + UV.x * 9.0 + seed) * 0.012 + sin(tt * 3.1 + UV.x * 17.0) * 0.005;
	VERTEX += NORMAL * flutter * w;
	VERTEX += sway * w;
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
	if (wool > 0.0) {
		vec2 fv = uv * weave_scale * vec2(2.3, 0.9);
		float wfine = 1.0 - smoothstep(0.4, 1.2, length(fwidth(fv)));
		fuzz = (vnoise(fv) - 0.5 + 0.5 * (vnoise(fv * 2.7 + 7.0) - 0.5)) * wfine;
		pill = smoothstep(0.72, 0.9, vnoise(uv * weave_scale * 0.35 + 3.0)) * wfine;
		vec2 cv = uv * vec2(9.0, 3.0) + seed;
		float c0 = fbm(cv);
		float cx = fbm(cv + vec2(0.04, 0.0)) - c0;
		float cy = fbm(cv + vec2(0.0, 0.04)) - c0;
		tx = mix(tx * 0.6, tx * 0.6 + cx * 9.0, wool) + fuzz * 0.25 * wool;
		ty = mix(ty * 0.6, ty * 0.6 + cy * 4.0, wool) + fuzz * 0.25 * wool;
		thread = mix(thread, 0.5 + (thread - 0.5) * 0.6, wool);
	}
	float slub = vnoise(vec2(uv.x * 4.0, uv.y * 140.0));
	// grime: streaks running down from the seams, soot climbing up from the hem
	float grime = fbm(uv * vec2(3.0, 0.8) + 9.1);
	float soot = (smoothstep(0.18, 0.0, to_hem) * 0.65 + burn_rim * 0.8) * soot_amt;
	float tone = clamp(0.35 + 0.45 * grime + 0.2 * slub, 0.0, 1.0);
	vec3 alb = mix(cloth_dark, cloth_light, tone);
	// old dye and rust stains in blotches
	float stain = smoothstep(0.55, 0.75, fbm(uv * 2.2 + 31.0));
	alb = mix(alb, alb * vec3(0.78, 0.62, 0.5), stain * 0.6);
	alb *= 0.86 + 0.14 * thread;
	alb *= 1.0 + wool * (0.22 * fuzz + 0.12 * pill);
	alb *= mix(0.45, 1.0, band) * hem_shade * mix(1.0, 0.7 + 0.3 * COLOR.r, fold_ao);
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
	float rough = 0.93 - 0.06 * thread;
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, grime), 1.0);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	METALLIC = 0.0;
	// thread relief: the weave catches the light at grazing angles
	NORMAL_MAP = normalize(vec3(-tx * 1.2, ty * 1.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;
	AO = mix(0.7, 1.0, thread) * mix(0.5, 1.0, band) * mix(1.0, COLOR.r, fold_ao);
	AO_LIGHT_AFFECT = 0.3;
	// a tightly plaited straw hat is opaque: no light through its underside
	BACKLIGHT = vec3(0.12, 0.10, 0.08) * (1.0 - 0.9 * rigid);
	EMISSION = ember_col * glow * 3.0 + figure_fill(alb, wet_n, wet_p) * mix(1.0, COLOR.r, fold_ao);
	// wool fibres standing off the surface scatter a soft sheen at grazing angles
	RIM = max(0.35 * wool, 0.1);
	RIM_TINT = 0.4;
}
