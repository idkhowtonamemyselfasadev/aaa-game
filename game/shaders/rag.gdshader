shader_type spatial;
render_mode cull_disabled;
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
uniform float wrap_turns = 0.0;     // > 0: a bandage tube (UV.x around): spiral strips, rides rigid

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
	float w = UV.y * UV.y * step(wrap_turns, 0.0);
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
	float fray = vnoise(vec2(UV.x * 160.0, seed)) * 0.025;
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
	float slub = vnoise(vec2(uv.x * 4.0, uv.y * 140.0));
	// grime: streaks running down from the seams, soot climbing up from the hem
	float grime = fbm(uv * vec2(3.0, 0.8) + 9.1);
	float soot = smoothstep(0.18, 0.0, to_hem) * 0.65 + burn_rim * 0.8;
	float tone = clamp(0.35 + 0.45 * grime + 0.2 * slub, 0.0, 1.0);
	vec3 alb = mix(cloth_dark, cloth_light, tone);
	// old dye and rust stains in blotches
	float stain = smoothstep(0.55, 0.75, fbm(uv * 2.2 + 31.0));
	alb = mix(alb, alb * vec3(0.78, 0.62, 0.5), stain * 0.6);
	alb *= 0.86 + 0.14 * thread;
	alb *= mix(0.45, 1.0, band);
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
	ALBEDO = alb;
	ROUGHNESS = 0.93 - 0.06 * thread;
	SPECULAR = 0.3;
	METALLIC = 0.0;
	// thread relief: the weave catches the light at grazing angles
	NORMAL_MAP = normalize(vec3(-tx * 1.2, ty * 1.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;
	AO = mix(0.7, 1.0, thread) * mix(0.5, 1.0, band);
	AO_LIGHT_AFFECT = 0.3;
	BACKLIGHT = vec3(0.12, 0.10, 0.08);
	EMISSION = ember_col * glow * 3.0;
}
