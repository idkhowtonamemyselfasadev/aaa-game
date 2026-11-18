shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// The Ashen Knight's armour: COLOR.r picks the layer (0 fire-blackened plate steel, 0.5 dark
// oiled leather strapping, 1 forged rivets). Plate: near-black heat-scaled steel, its ridges
// and edges rubbed back to bare grey metal, rust blooming in the low spots, soot over all,
// and a faint ember glow in the cracks that rises with `ember` (the knight's phase).
// COLOR.g = 0..1 edge factor (1 on a rim/ridge: worn bright). Pattern space: object metres.

uniform vec3 steel_dark : source_color = vec3(0.045, 0.043, 0.042);
uniform vec3 steel_bare : source_color = vec3(0.42, 0.41, 0.40);
uniform vec3 rust : source_color = vec3(0.24, 0.09, 0.035);
uniform vec3 leather : source_color = vec3(0.09, 0.055, 0.035);
uniform vec3 ember_col : source_color = vec3(1.0, 0.32, 0.06);
uniform float ember = 0.0;      // the body's ember (HollowSoldier, pulses with its tells)
uniform float heat = 0.0;       // the knight's phase: 0, 0.5, 1
uniform float dissolve = 0.0;   // crumbles with the body on death
uniform float hit_flash = 0.0;
uniform float stone = 0.0;
// (11-16 09:00) the helm's sight slit: a black cut across the eyes with the ember burning behind it,
// smouldering at rest and blazing with `ember` (the growth roar drives ember to ~7). 0 = the old helm.
uniform float slit_on = 1.0;      // 1 = carved granite (the Stone Sentinel's helm, pauldrons, glaive)

// (11-16 19:00) 1 = the slit is a thin dark-red cut that pinches shut at the keel, and the ember shows as two
// round white-hot eye points in it (the old bar burned evenly and clipped into one white stroke). 0 = before.
uniform float slit_eyes = 1.0;
// (11-16 20:00) 1 = the helm's keel is a crisp narrow line of rubbed-bright steel down the face (worn
// from the UV, no pit jitter) with soot charring its flanks; the old wear came from COLOR.g on a
// 40-column helm (the keel spans ~3 verts) plus pit noise and read as a soft grey smoke streak. 0 = before.
uniform float keel_crisp = 1.0;
// (11-18 12:00) rust only in the deep pits and seams: at 0 the rust mask (smoothstep 0.55..0.8 over a
// noise averaging ~0.6) covered over half the plate in a warm brown and the whole knight read dark red
// with no steel left. 1 = sparse, darker rust, so the fire-blackened steel and its bright rubbed edges show.
uniform float rust_sparse = 1.0;

varying float layer;
varying float edge;
varying float helm;
varying vec3 opos;

float hash(vec3 p) {
	p = fract(p * vec3(123.34, 456.21, 789.53));
	p += dot(p, p.yzx + 45.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.07;
		a *= 0.5;
	}
	return s;
}

// Distance to the nearest Voronoi cell border (F2 - F1 approximation, in cell units): thin
// polygonal seams like plate that split along its grain, not round contour blobs.
float vedge(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(hash(i + g), hash(i + g + 17.1), hash(i + g + 41.7));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return (d2 - d1) * 0.5;
}

void vertex() {
	layer = COLOR.r;
	edge = COLOR.g;
	helm = COLOR.b;
	opos = VERTEX;
}

void fragment() {
	vec3 alb;
	float rough;
	float metal;
	float bump;
	vec3 glow = vec3(0.0);
	if (layer < 0.25) {
		float pits = fbm(opos * 70.0);
		float scale = fbm(opos * 9.0 + 3.1);
		float wear = smoothstep(0.35, 0.95, edge + (pits - 0.5) * 0.6);
		float keel_soot = 0.0;
		if (helm > 0.5 && keel_crisp > 0.5 && stone < 0.5) {
			// rebuild the helm's edge factor from its UV (knight_armour.gd _helm) without the keel's
			// vertex-smeared share: the brim and the slit's upper lip keep the old jittered wear
			float ka = UV.x * 6.2831853;
			float kv = UV.y;
			float kfront = max(cos(ka), 0.0);
			float ks = abs(sin(ka));
			float brim = smoothstep(0.93, 1.0, kv);
			// the slit's upper lip: the vertex factor only grazed it (22 rows, the lip is under one), so a
			// per-fragment lip at full strength burned a white bar over the slit; keep it a faint rub
			float lip = smoothstep(0.03, 0.012, abs(kv - 0.43)) * smoothstep(0.35, 0.7, cos(ka)) * 0.35;
			float rest = smoothstep(0.35, 0.95, max(brim, lip) + (pits - 0.5) * 0.6);
			// the keel: a hard line ~1.5 cm wide, its width anti-aliased in screen space
			float kaa = fwidth(ks) + 0.002;
			float ridge = (1.0 - smoothstep(0.018, 0.018 + kaa, ks)) * kfront * smoothstep(0.12, 0.32, kv)
					* (1.0 - smoothstep(0.92, 0.97, kv));
			// rubbed brightest on the brow and chin where a gauntlet would wipe it, a touch duller between
			ridge *= 0.8 + 0.2 * (smoothstep(0.30, 0.20, kv) + smoothstep(0.6, 0.85, kv));
			wear = max(rest, ridge * 0.92);
			// the forge-black flanks either side of the ridge: soot gathers in the fold
			keel_soot = (1.0 - smoothstep(0.03, 0.14, ks)) * (1.0 - ridge) * kfront * smoothstep(0.1, 0.3, kv)
					* (1.0 - smoothstep(0.88, 0.95, kv));
		}
		float r = smoothstep(mix(0.55, 0.70, rust_sparse), mix(0.8, 0.9, rust_sparse), fbm(opos * 14.0 + 7.7) + pits * 0.25) * (1.0 - wear);
		float dent = smoothstep(0.7, 0.9, vnoise(opos * 22.0));
		// heat scale: blue-black to a bruised brown where the fire bit hardest
		vec3 scaled = mix(steel_dark, vec3(0.075, 0.058, 0.05), scale);
		alb = mix(scaled * (0.8 + 0.4 * pits), steel_bare * (0.75 + 0.35 * pits), wear);
		alb = mix(alb, rust * (0.7 + 0.6 * pits) * mix(1.0, 0.6, rust_sparse), r);
		// (11-18 12:00) a metal's albedo is its reflectance: at 0.045 the plate reflected ~4 % (less than
		// paint) and read as matte black cloth. Blackened steel still reflects ~15-20 %: brighter F0 for the
		// metal, a touch smoother, so the sky and sun slide over the plate; soot and rust stay dull.
		if (rust_sparse > 0.5 && stone < 0.5) {
			alb = mix(alb, alb * 2.6 + vec3(0.05, 0.048, 0.046), (1.0 - r) * (1.0 - wear) * 0.9);
		}
		rough = mix(mix(mix(0.62, 0.46, rust_sparse), 0.32, wear), 0.92, r);
		metal = mix(0.85, 0.15, r);
		bump = pits * 0.35 - dent * 0.6 + r * 0.25;
		alb *= 1.0 - keel_soot * 0.55;
		rough = mix(rough, 0.85, keel_soot * 0.7);
		// hairline cracks in the blackened plate show the ember behind
		// warped Voronoi seams (~10 cm cells, jagged), split into two widths: a few main seams and
		// finer hair branches, broken into patches so no closed loop ever reads as a shape
		vec3 cp = opos * 10.0 + (vec3(fbm(opos * 9.0 + 2.0), fbm(opos * 9.0 + 5.0), fbm(opos * 9.0 + 8.0)) - 0.5) * 1.6;
		float de = vedge(cp);
		float aa = fwidth(de) + 0.0015;
		// seam width tapers along each crack (hairline to ~1.5 cm), a hot core inside a dim red halo
		float taper = smoothstep(0.25, 0.85, vnoise(opos * 18.0 + 4.0));
		float w = mix(0.002, 0.011, taper);
		float main_c = 1.0 - smoothstep(w, w + aa, de);
		float halo = (1.0 - smoothstep(w, w + 0.035, de)) * taper;
		float hair = 1.0 - smoothstep(0.002, 0.002 + aa, vedge(cp * 2.3 + 7.0));
		float patch_m = smoothstep(0.55, 0.72, vnoise(opos * 5.0 + 3.0));
		float crack = max(main_c * patch_m, hair * 0.35 * smoothstep(0.68, 0.82, vnoise(opos * 9.0 + 9.0)));
		crack *= 1.0 - wear * 0.8;   // worn-bright ridges are solid metal
		halo *= patch_m * (1.0 - wear * 0.8);
		float gain = (0.15 + ember * 0.6) * (0.25 + heat);
		glow = (mix(ember_col, vec3(1.0, 0.62, 0.3), main_c * taper) * crack * 1.8 + ember_col * vec3(0.8, 0.5, 0.4) * halo * 0.35) * gain;
		alb *= 1.0 - crack * 0.5;
		if (helm > 0.5 && slit_on > 0.0) {
			// UV.x 0 = straight ahead round the helm, UV.y 0.40 = eye height (knight_armour.gd _helm)
			float a = UV.x * 6.2831853;
			float fr = smoothstep(0.35, 0.7, cos(a));
			float off_keel = smoothstep(0.08, 0.2, abs(sin(a)));
			float dv = abs(UV.y - 0.405);
			float aav = fwidth(UV.y) + 0.001;
			float cut = (1.0 - smoothstep(0.011, 0.011 + aav, dv)) * fr * off_keel;
			float bleed = (1.0 - smoothstep(0.011, 0.05, dv)) * fr * off_keel;
			// two hot points where the eyes sit, either side of the keel
			float eyes = exp(-pow((abs(sin(a)) - 0.30) / 0.10, 2.0));
			float burn = (0.35 + 0.55 * ember) * slit_on;
			if (slit_eyes > 0.5) {
				float s = abs(sin(a));
				// the cut narrows toward the keel: 0.4 of its width at the keel break, full width past the eyes
				float wv = 0.0075 * mix(0.45, 1.0, smoothstep(0.12, 0.30, s));
				cut = (1.0 - smoothstep(wv, wv + aav, dv)) * fr * smoothstep(0.10, 0.17, s);
				bleed = (1.0 - smoothstep(wv, 0.04, dv)) * fr * off_keel;
				// round hot points (in arc and in height), with a dark gap between them and the keel
				float eye_r = pow((s - 0.30) / 0.05, 2.0) + pow(dv / 0.009, 2.0);
				float eye2 = exp(-eye_r * 1.6);
				// the bar itself stays a deep, low ember so it never clips: only the eyes burn white
				float bar = cut * (0.18 + 0.3 * smoothstep(0.6, 0.0, abs(s - 0.30) / 0.3)) * min(burn, 1.2);
				alb = mix(alb, vec3(0.01), cut);
				rough = mix(rough, 1.0, cut);
				metal = mix(metal, 0.0, cut);
				glow += ember_col * vec3(0.9, 0.45, 0.35) * bar
						+ mix(ember_col, vec3(1.0, 0.82, 0.55), eye2) * eye2 * fr * (0.8 + 0.9 * burn) * 1.6
						+ ember_col * bleed * 0.12 * min(burn, 1.5);
			} else {
			alb = mix(alb, vec3(0.01), cut);
			rough = mix(rough, 1.0, cut);
			metal = mix(metal, 0.0, cut);
			glow += (mix(ember_col, vec3(1.0, 0.7, 0.35), eyes * 0.7) * cut * (0.6 + 1.4 * eyes) * 2.0
					+ ember_col * bleed * 0.25) * burn;
			}
		}
	} else if (layer < 0.75) {
		float grain = fbm(opos * 120.0);
		float scuff = smoothstep(0.6, 0.85, fbm(opos * 18.0));
		alb = leather * (0.7 + 0.5 * grain) + vec3(0.05, 0.04, 0.03) * scuff;
		rough = mix(0.55, 0.8, scuff);
		metal = 0.0;
		bump = grain * 0.4;
	} else {
		float pits = fbm(opos * 160.0);
		alb = mix(steel_bare * 0.7, rust * 0.8, smoothstep(0.4, 0.7, pits));
		rough = 0.45;
		metal = 0.8;
		bump = pits;
	}
	if (stone > 0.0) {
		float g = fbm(opos * 38.0);
		float sp = hash(floor(opos * 420.0));
		vec3 granite = mix(vec3(0.19, 0.188, 0.18), vec3(0.48, 0.47, 0.44), g) * (0.84 + 0.3 * sp);
		granite = mix(granite, vec3(0.07, 0.066, 0.062), step(0.94, sp) * 0.7);
		float lich = smoothstep(0.55, 0.76, fbm(opos * 12.0 + 2.0));
		granite = mix(granite, vec3(0.49, 0.51, 0.36) * (0.8 + 0.4 * g), lich * 0.7);
		float moss = smoothstep(0.6, 0.82, fbm(opos * 8.0 + 5.3));
		granite = mix(granite, vec3(0.085, 0.12, 0.045), moss * 0.75);
		granite = mix(granite, vec3(0.6, 0.59, 0.55), smoothstep(0.55, 0.95, edge) * 0.35);   // worn edges
		alb = mix(alb, granite, stone);
		rough = mix(rough, 0.86 + 0.08 * g, stone);
		metal = mix(metal, 0.0, stone);
		bump = mix(bump, g * 0.6 + sp * 0.15, stone);
		glow *= 1.0 - stone * 0.6;
	}
	if (dissolve > 0.0) {
		float d = fbm(opos * 5.0 + 1.7);
		if (d < dissolve) discard;
		glow += ember_col * (1.0 - smoothstep(0.0, 0.06, d - dissolve)) * 2.5;
	}
	glow += vec3(1.0, 0.75, 0.5) * hit_flash * 0.6;
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, vnoise(opos * 9.0)), 1.0 - metal);
	ALBEDO = alb;
	EMISSION += figure_fill(alb, wet_n, wet_p, CAMERA_POSITION_WORLD) + glow;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = metal;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float bx = dFdx(bump);
	float by = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (bx * r1 + by * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.0025);
}
