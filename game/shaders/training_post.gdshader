shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/figure_fill.gdshaderinc"
// Practice post: COLOR.r picks the layer (0 weathered oak, 0.33 rusted iron band,
// 0.66 straw bundle, 1 rope lashing). UV.x = around (0..1), UV.y = metres up (oak/straw)
// or around the rope's tube (rope). All detail is procedural. Straw stalk cards (COLOR.g 1)
// carry a per-stalk tone in COLOR.b and their layer depth in COLOR.a; UV.x across, UV.y
// metres along, UV2.x 0..1 along.

uniform vec3 oak_grey : source_color = vec3(0.44, 0.41, 0.36);
uniform vec3 oak_dark : source_color = vec3(0.17, 0.15, 0.12);
uniform vec3 iron : source_color = vec3(0.17, 0.16, 0.15);
uniform vec3 rust : source_color = vec3(0.36, 0.17, 0.08);
uniform vec3 straw_hi : source_color = vec3(0.70, 0.58, 0.34);
uniform vec3 straw_lo : source_color = vec3(0.34, 0.27, 0.16);
uniform vec3 rope_col : source_color = vec3(0.42, 0.34, 0.23);

varying float layer;
varying vec3 obj;
varying vec3 stk;   // x 1 on a stalk, y tone, z depth

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
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

void vertex() {
	layer = COLOR.r;
	obj = VERTEX;
	stk = vec3(COLOR.g, COLOR.b, COLOR.a);
}

void fragment() {
	float around = UV.x;
	float h = UV.y;
	vec3 alb;
	float rough;
	float metal = 0.0;
	float bump = 0.0;
	float ao = 1.0;
	if (layer < 0.16) {
		// weathered oak: silver-grey sun-bleached grain, deep checking cracks, darker and
		// damp near the ground with a little dark moss at the foot; the cut top shows end
		// grain (growth rings round an off-centre pith, radial checks) bleached pale
		float g = fbm(vec2(around * 30.0, h * 1.2));
		float fine = vnoise(vec2(around * 160.0, h * 4.0));
		float crack = smoothstep(0.035, 0.0, abs(fbm(vec2(around * 7.0, h * 0.5)) - 0.5)) ;
		crack *= smoothstep(0.3, 0.6, vnoise(vec2(around * 5.0, h * 2.5)));
		// long silver streaks where rain runs down the grain, browner in the hollows
		float streak = vnoise(vec2(around * 55.0, h * 0.6));
		alb = oak_grey * (0.7 + 0.5 * g) * (0.82 + 0.3 * fine) * (0.85 + 0.25 * streak);
		alb = mix(alb, alb * vec3(1.08, 0.95, 0.80), (1.0 - g) * 0.5);
		float top = smoothstep(1.68, 1.70, obj.y);
		if (top > 0.0) {
			vec2 c = obj.xz - vec2(0.012, -0.008);
			float r = length(c) + fbm(c * 40.0) * 0.012;
			float ring = smoothstep(0.25, 0.0, abs(fract(r * 140.0) - 0.5) - 0.25);
			float ang = atan(c.y, c.x);
			float chk = smoothstep(0.06, 0.0, abs(fract(ang * 1.1 + fbm(c * 25.0) * 0.4) - 0.5))
					* smoothstep(0.015, 0.06, r);
			vec3 eg = vec3(0.50, 0.47, 0.42) * (0.82 + 0.25 * fbm(c * 90.0));
			eg = mix(eg, oak_dark * 1.2, ring * 0.35);
			eg = mix(eg, oak_dark * 0.6, chk * 0.9);
			alb = mix(alb, eg, top);
			crack = mix(crack, chk, top);
			g = mix(g, ring, top);
		}
		alb = mix(alb, oak_dark, crack * 0.85);
		// rust washed down out of the iron band in streaks and runs below it
		float below = 1.56 - obj.y;
		float runs = smoothstep(0.45, 0.8, vnoise(vec2(around * 48.0, 0.3))) * (0.6 + 0.4 * fine);
		float stain = step(0.0, below) * runs * exp(-below / (0.05 + 0.18 * runs));
		stain = max(stain, step(0.0, below) * smoothstep(0.02, 0.0, below) * 0.7);
		alb = mix(alb, vec3(0.30, 0.15, 0.07), stain * 0.8);
		float damp = smoothstep(0.35, -0.05, h);
		alb = mix(alb, oak_dark * 1.3, damp * 0.6);
		float moss = smoothstep(0.62, 0.8, fbm(vec2(around * 12.0, h * 9.0)) + damp * 0.4) * smoothstep(0.5, 0.2, h);
		alb = mix(alb, vec3(0.085, 0.10, 0.045), moss * 0.75);
		rough = 0.82 + 0.1 * fine;
		bump = g * 0.5 + fine * 0.3 - crack * 1.2;
		ao = 1.0 - crack * 0.6;
	} else if (layer < 0.5) {
		// hand-forged iron band, weathered to a brown-grey oxide: flat hammer facets (planar
		// tilts per peen blow), the high spots of the facets worn back to dull grey iron by
		// staff blows, orange bloom and dark scale in the hollows and along the edges, and
		// two domed rivet heads where the strap ends overlap
		vec2 m = vec2(around * 0.66, h);     // metres round / up (circumference ~0.66 m)
		vec2 cell = m / 0.022;
		vec2 ci = floor(cell);
		float best = 9.0;
		vec2 bo = vec2(0.0);
		vec2 bid = vec2(0.0);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 id = ci + vec2(float(i), float(j));
				vec2 o = vec2(hash(id), hash(id + 17.3)) * 0.8 + 0.1;
				vec2 d = id + o - cell;
				float dd = dot(d, d);
				if (dd < best) { best = dd; bo = d; bid = id; }
			}
		}
		vec2 slope = vec2(hash(bid + 3.7), hash(bid + 9.1)) - 0.5;
		float facet = dot(-bo, slope) * 1.6;          // planar tilt inside each peen mark
		float hi = smoothstep(0.0, 0.5, facet + 0.25);  // proud part of the facet
		float edge = 1.0 - smoothstep(0.0, 0.006, min(h - 1.56, 1.62 - h)); // band edges
		float r = fbm(vec2(around * 30.0, h * 70.0));
		float pit = smoothstep(0.55, 0.75, fbm(vec2(around * 90.0, h * 160.0)));
		vec3 oxide = mix(vec3(0.20, 0.15, 0.12), vec3(0.30, 0.17, 0.09), r);
		vec3 bloom = vec3(0.44, 0.21, 0.07);
		vec3 bare = vec3(0.34, 0.31, 0.27);
		float wear = smoothstep(0.72, 0.98, hi * (0.6 + 0.6 * vnoise(vec2(around * 8.0, h * 30.0))));
		alb = mix(oxide, bloom, smoothstep(0.55, 0.8, r) * (1.0 - hi) * 0.8);
		alb = mix(alb, vec3(0.09, 0.075, 0.065), max(edge * 0.6, pit * 0.5));
		alb = mix(alb, bare, wear * (1.0 - edge));
		rough = mix(0.88, 0.58, wear) + pit * 0.08;
		metal = wear * 0.55;
		bump = facet * 0.9 + r * 0.25 - pit * 0.35;
		ao = 1.0 - edge * 0.35 - pit * 0.2;
		// rivets on the overlap (a raised dome, a dark crevice ring round it)
		for (int k = 0; k < 2; k++) {
			vec2 rc = vec2(0.31 * 0.66 + float(k) * 0.035, 1.59);
			float rd = length(m - rc) / 0.009;
			float dome = sqrt(max(1.0 - rd * rd, 0.0));
			float ring = smoothstep(0.85, 1.0, rd) * smoothstep(1.35, 1.0, rd);
			bump += dome * 2.5;
			alb = mix(alb, mix(oxide, bare, 0.35), dome > 0.0 ? 1.0 : 0.0);
			alb = mix(alb, vec3(0.06, 0.05, 0.045), ring);
			ao *= 1.0 - ring * 0.5;
		}
		// the overlapped strap end: a step and a dark seam down the band
		float seam = smoothstep(0.004, 0.0, abs(m.x - 0.31 * 0.66 - 0.055));
		alb = mix(alb, vec3(0.06, 0.05, 0.045), seam);
		bump += step(m.x, 0.31 * 0.66 + 0.055) * step(0.31 * 0.66 - 0.02, m.x) * 0.6;
	} else if (layer < 0.83 && stk.x > 0.5) {
		// one straw stalk: a hollow round culm, gold to pale wheat to grey-weathered by stalk,
		// with dark nodes, a lit ridge down the middle and darker edges where it rolls away;
		// the inner layer and the cut ends sit in the bundle's shade
		float id = stk.y;
		float x = UV.x;
		float roll = sin(x * 3.14159);
		vec3 c = mix(straw_lo, straw_hi, 0.25 + 0.75 * fract(id * 7.13));
		c = mix(c, vec3(0.31, 0.30, 0.26), smoothstep(0.7, 0.95, id) * 0.75);       // grey, weathered
		c = mix(c, vec3(0.42, 0.30, 0.15), smoothstep(0.25, 0.0, id) * 0.6);        // rusty, damp
		float streak = vnoise(vec2(x * 3.0 + id * 40.0, UV.y * 60.0));
		float node = smoothstep(0.93, 1.0, sin(UV.y * 18.0 + id * 31.0) * 0.5 + 0.5);
		// rot and grime near the lower end, where rain runs down and wicks up from the earth
		float grime = smoothstep(0.72, 0.6, obj.y) * 0.5 + smoothstep(0.3, 0.0, UV2.x) * 0.15;
		alb = c * (0.6 + 0.45 * roll) * (0.85 + 0.3 * streak) * (1.0 - node * 0.35);
		alb = mix(alb, vec3(0.13, 0.10, 0.07), grime);
		alb *= mix(0.55, 1.0, stk.z);
		rough = 0.55 + 0.3 * (1.0 - roll) + 0.1 * streak;
		bump = roll * 0.6 + node * 0.4 + streak * 0.15;
		ao = mix(0.45, 1.0, stk.z) * (0.75 + 0.25 * roll);
	} else if (layer < 0.83) {
		// straw core: long vertical stalks, each a slightly different gold/grey, dark gaps between
		float stalk = around * 260.0 + fbm(vec2(around * 8.0, h * 3.0)) * 6.0;
		float id = hash(vec2(floor(stalk), 3.1));
		float x = fract(stalk);
		float round_ = sin(x * 3.14159);
		float gap = smoothstep(0.0, 0.25, round_);
		float age = fbm(vec2(around * 14.0, h * 6.0));
		vec3 c = mix(straw_lo, straw_hi, 0.35 + 0.65 * id);
		c = mix(c, vec3(0.30, 0.29, 0.25), smoothstep(0.55, 0.8, age) * 0.6);   // grey, weathered
		// knots / nodes along the stalks
		float node = smoothstep(0.92, 1.0, sin(h * 40.0 + id * 31.0) * 0.5 + 0.5);
		alb = c * (0.45 + 0.6 * gap) * (1.0 - node * 0.25) * 0.4;   // packed shadow between stalks
		rough = 0.62 + 0.25 * (1.0 - round_);
		bump = round_ * 0.9 + node * 0.3;
		ao = 0.35 + 0.25 * gap;
	} else {
		// twisted hemp rope: three plies spiralling round the tube
		float twist = fract(around * 90.0 + h * 3.0);
		float ply = sin(twist * 3.14159);
		float fib = vnoise(vec2(around * 900.0, h * 30.0));
		alb = rope_col * (0.5 + 0.55 * ply) * (0.85 + 0.3 * fib);
		alb *= 0.8 + 0.35 * vnoise(vec2(around * 7.0, h * 2.0));   // weathered unevenly
		rough = 0.9;
		bump = ply * 0.8 + fib * 0.2;
		ao = 0.6 + 0.4 * ply;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = metal;
	AO = ao;
	AO_LIGHT_AFFECT = 0.4;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float bx = dFdx(bump);
	float by = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (bx * r1 + by * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.004);
	// meadow bounce into the shaded side, like the fighters (no black post in back light)
	EMISSION = figure_fill(alb, mat3(INV_VIEW_MATRIX) * NORMAL, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz) * ao;
}
