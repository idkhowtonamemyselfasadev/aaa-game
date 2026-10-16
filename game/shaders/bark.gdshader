shader_type spatial;
render_mode cull_back;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
// Procedural oak bark: deep vertical furrows (stretched ridged noise along the limb),
// plated ridges, lichen/moss on the upward side and near the roots.
#include "res://shaders/tree_wind.gdshaderinc"

// (10-16 12:00) lifted from (0.14,0.1,0.07)/(0.29,0.25,0.2): the shaded bole read as a
// black column; weathered oak bark is ~0.08-0.12 linear albedo
uniform vec3 bark_dark : source_color = vec3(0.17, 0.125, 0.09);
uniform vec3 bark_light : source_color = vec3(0.35, 0.31, 0.26);
uniform vec3 lichen : source_color = vec3(0.5, 0.52, 0.44);
// two moss tones like rock.gdshader (the single dark green read black-green on the
// shaded side): olive cushions with paler yellow-green tops
uniform vec3 moss : source_color = vec3(0.2, 0.24, 0.07);
uniform vec3 moss_lit : source_color = vec3(0.34, 0.35, 0.13);

varying vec3 wn;
varying float vy;
varying float v_root;   // 1 on a surface root (Flora._build_roots)
varying float v_soil;   // root: height above the soil (m)

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
// u wraps at 2.0 around the limb: tile the noise so there is no seam
float n2w(vec2 p, float per) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	vec2 i1 = vec2(mod(i.x + 1.0, per), i.y);
	vec2 i0 = vec2(mod(i.x, per), i.y);
	return mix(mix(h21(i0), h21(i1), f.x), mix(h21(i0 + vec2(0, 1)), h21(i1 + vec2(0, 1)), f.x), f.y);
}

varying float v_cloud;   // cloud shadow on this vertex (1 = full sun)

float furrow(vec2 uv) {
	// 12 ridges around (u in 0..2 -> 24 cells per wrap), stretched 6x along the limb;
	// every term wraps at u = 2 so the displaced bole has no seam crack
	vec2 p = vec2(uv.x * 12.0, uv.y * 2.0);
	float a = n2w(p + vec2(n2w(p * vec2(0.5, 0.3), 12.0) * 1.5, 0.0), 24.0);
	float b = n2w(p * vec2(2.0, 3.0) + 3.1, 48.0);
	float r = 1.0 - abs(a * 2.0 - 1.0);
	return clamp(r * 0.75 + b * 0.25, 0.0, 1.0);
}

// old oak bark is "blocky": the plates between the furrows crack across every
// 10-20 cm (UV is ~pi*r0 m per unit; 7 rows per unit ~ 0.18 m on a 0.4 m bole).
// Each plate column gets its own crack offset and tilt, and some cracks are missing
// so the blocks have uneven lengths. Returns 1 in a cross crack.
float cracks(vec2 uv) {
	// row spacing is jittered along the limb (a slow warp of y), and cracks group
	// columns in runs of 2-3 (shared offset) so a crack crosses several plates
	vec2 q = vec2(uv.x * 12.0, uv.y * 7.0);
	float c = mod(floor(q.x), 24.0);
	float g = mod(floor((c + floor(h21(vec2(floor(q.y * 0.5), 1.3)) * 3.0)) / 2.5), 10.0);
	float y = q.y + (n2(vec2(q.y * 0.35, g * 7.0)) - 0.5) * 1.6
		+ h21(vec2(g, 3.7)) + (fract(q.x) - 0.5) * (h21(vec2(c, 9.1)) - 0.5) * 0.5
		+ (n2w(q * vec2(1.0, 0.5), 24.0) - 0.5) * 0.45;
	float keep = step(0.35, h21(vec2(c, floor(y))));
	// width varies per crack (hairline to a thumb-wide split)
	float w = mix(0.82, 0.62, h21(vec2(c + 31.0, floor(y))));
	// rounded lips: the plate edge rolls over into the split (soft shoulder) and the
	// split closes in a V, instead of a flat-bottomed dark band with hard edges
	float x = smoothstep(w - 0.1, 0.98, abs(fract(y) - 0.5) * 2.0);
	return x * x * (3.0 - 2.0 * x) * keep;
}

// fine relief on the plate tops: long fibres along the limb (~1 cm wide, 10-15 cm
// long) and raised, stepped flakes a few cm across, so a plate is never smooth.
// Both wrap at u = 2.
float bark_fine(vec2 uv) {
	float fib = n2w(uv * vec2(110.0, 8.0), 220.0) * 0.6 + n2w(uv * vec2(230.0, 20.0), 460.0) * 0.4;
	vec2 fp = uv * vec2(36.0, 20.0);
	fp.x += n2w(uv * vec2(14.0, 6.0), 28.0) * 1.5;
	float flake = smoothstep(0.45, 0.62, n2w(fp, 72.0));
	return fib * 0.45 + flake * 0.55;
}

// the full bark height field: furrows with flat plate tops (narrow furrows), cut into
// blocks by the cross cracks
// `fine` fades the plate-top texture out where it would alias (far away)
float bark_h(vec2 uv, float fine) {
	float f = smoothstep(0.12, 0.62, furrow(uv));
	float top = smoothstep(0.45, 0.9, f);
	return f * (1.0 - 0.55 * cracks(uv) * smoothstep(0.3, 0.7, f))
		+ top * (bark_fine(uv) - 0.5) * 0.24 * fine;
}

void vertex() {
	// the bole (COLOR.a < 1, Flora._tube disp) is pushed out into real plates and sunk
	// into furrows, so the bark has relief in silhouette and in the shadows, not only
	// in the normal map; 1 - COLOR.a is the relief depth in metres
	float relief = 1.0 - COLOR.a;
	if (relief > 0.0) {
		// flat plate tops and narrow furrows (the bark_h profile without the cross
		// cracks: the bole rings are 0.2 m apart, too coarse for 18 cm crack rows)
		VERTEX += NORMAL * (smoothstep(0.12, 0.62, furrow(UV)) - 0.62) * relief;
	}
	VERTEX += tree_wind(VERTEX, COLOR.r, MODEL_MATRIX, TIME);
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vy = VERTEX.y;
	v_root = COLOR.g;
	v_soil = COLOR.b;
	v_cloud = cloud_shade_at((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	// colour follows the coarse furrows; the blocky height field (cross cracks, flat
	// plate tops) only drives the normal map and the cavity shading
	float f = furrow(UV);
	float fine = 1.0 - smoothstep(0.003, 0.012, length(fwidth(UV)));
	float h = bark_h(UV, fine);
	float e = 0.003;
	float hx = bark_h(UV + vec2(e, 0.0), fine);
	float hy = bark_h(UV + vec2(0.0, e), fine);
	vec3 col = mix(bark_dark, bark_light, smoothstep(0.25, 0.85, f));
	col *= 0.85 + 0.3 * n2(UV * vec2(40.0, 10.0));
	// the raised flakes and fibres on the plates weather a little paler than the
	// grooves between them
	col *= mix(1.0, 0.8 + 0.4 * bark_fine(UV), smoothstep(0.45, 0.9, f) * fine);
	// deep in the furrows the bark is warm red-brown (fresh inner layers, no weathering)
	col = mix(col, vec3(0.2, 0.12, 0.07), (1.0 - smoothstep(0.1, 0.4, f)) * 0.6);
	// old oak bark is grey-weathered on the plate tops, with pale crustose lichen blotches
	// on the ridges (never in the furrows); the furrows stay dark brown
	float plate = smoothstep(0.55, 0.9, f);
	col = mix(col, col * vec3(1.04, 1.05, 1.06) + vec3(0.012), plate * 0.45);
	// blotches the size of a hand to a dinner plate, so they read from 5-10 m; they sit
	// on the plates and only feather into the furrow lips
	float lb = smoothstep(0.56, 0.7, n2w(UV * vec2(5.0, 1.4), 10.0) * 0.65 + n2(UV * vec2(18.0, 5.0)) * 0.35);
	float m = smoothstep(0.35, 0.8, wn.y + n2(UV * vec2(8.0, 3.0)) * 0.4 - 0.1);
	m = max(m, smoothstep(1.2, 0.0, vy) * 0.8 * n2(UV * 6.0));
	// the shaded side of the bole stays damp: moss climbs it from the foot collar in
	// streaks that run up the furrows, reaching ~2.5 m (local) on the full north face
	float shade = clamp(dot(normalize(wn.xz + vec2(1e-4)), MOSS_SHADE), 0.0, 1.0) * (1.0 - abs(wn.y));
	float reach = mix(0.3, 2.6, shade) * (0.55 + 0.9 * n2w(vec2(UV.x * 6.0, 0.0), 12.0));
	float climb = 1.0 - smoothstep(reach * 0.4, reach, vy);
	// streaks, not a sheet: the climb breaks up into tongues with bare bark between
	m = max(m, smoothstep(0.35, 0.75, climb * (0.45 + 0.6 * f) * (0.55 + 0.7 * n2(UV * vec2(10.0, 2.0)))));
	if (v_root > 0.5) {
		// surface roots: the arched tops are worn bare and paler, moss and peat fill the
		// crotches and the line where the root goes into the soil
		// roots weather paler and greyer than the bole (scuffed, sun-bleached on top)
		float top = smoothstep(0.2, 0.8, wn.y);
		col = mix(col, bark_light * vec3(1.3, 1.26, 1.22), 0.35 + top * 0.35 * f);
		float lowm = 1.0 - smoothstep(0.02, 0.14, v_soil);
		m = clamp(lowm * (0.6 + 0.6 * n2(UV * vec2(5.0, 2.0))) + top * smoothstep(0.55, 0.8, n2(UV * vec2(3.0, 1.2))) * 0.7, 0.0, 1.0);
		col *= mix(0.8, 1.0, smoothstep(0.0, 0.07, v_soil));
	}
	vec3 mc = mix(moss, moss_lit, smoothstep(0.3, 0.8, n2(UV * vec2(22.0, 7.0)) * 0.6 + f * 0.4));
	col = mix(col, mc, m * 0.75);
	// lichen grows where the moss does not (the drier bark), so it shows on every side
	col = mix(col, lichen * (0.85 + 0.2 * f), lb * mix(0.2, 1.0, plate) * 0.6 * (1.0 - m));
	// moss is a fibre mat, not a film: it stays fully matte (0.85 read as a wet sheen)
	float rough = mix(0.97, 0.95, m);
	weather_wetten(col, rough, 1.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.08;   // dry bark has almost no sheen
	// the crack lips are steep in h: unclamped, the slope tipped the normal near
	// horizontal there and every crack rim caught the sky as a bright line (the "glossy"
	// bole); soft-clamp the slope so plates stay tilted but never edge-on, and flatten
	// it under moss (a cushion fills the relief)
	vec2 sl = vec2(h - hx, h - hy) * 12.0;
	sl = sl / (1.0 + length(sl) * 0.8) * (1.0 - 0.6 * m);
	NORMAL_MAP = normalize(vec3(sl, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
	// cavity: the furrow floors and the cross cracks stay dark even in the bounce fill
	AO = mix(0.4, 1.0, smoothstep(0.05, 0.55, h));
	ALBEDO *= mix(0.82, 1.0, smoothstep(0.0, 0.3, h));
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;
	// trunks are vertical: bounce off the ground below, less in the furrows
	EMISSION = ALBEDO * bounce_light * 1.7 * AO;   // darker albedo since 10-13 20:00: more fill
}
