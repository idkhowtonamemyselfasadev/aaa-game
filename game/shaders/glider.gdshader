shader_type spatial;
render_mode cull_back;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// Caelum's glider: COLOR.r picks the layer (0 bamboo, 0.5 cord and grip wrap, 1 canvas).
// COLOR.g = canvas billow between ribs (0 at a rib), COLOR.b = span position 0..1,
// COLOR.a = 1 on the canvas's underside. Canvas UV2 = (chord 0..1 from the nose, span -1..1). UV = metres (canvas: across, back from the nose;
// tubes: around 0..1, along). All detail is procedural.

uniform float open = 1.0;
uniform float gust = 0.0;    // wind working the cloth: the ripple grows
uniform float fill = 1.0;    // airspeed pressing the panels full (0: slack, they sag and luff)
uniform vec3 canvas : source_color = vec3(0.50, 0.40, 0.27);   // oiled hemp, sun-browned
uniform vec3 canvas_patch : source_color = vec3(0.36, 0.22, 0.14); // ox-blood dyed repairs
uniform vec3 bamboo : source_color = vec3(0.47, 0.36, 0.20);
uniform vec3 bamboo_node : source_color = vec3(0.24, 0.17, 0.09);
uniform vec3 cord : source_color = vec3(0.33, 0.27, 0.19);

varying float layer;
varying float billow;
varying float span;
varying float under;
varying vec2 cuv;

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
	billow = COLOR.g;
	span = COLOR.b;
	under = COLOR.a;
	cuv = UV;
	// furled: everything gathers to the keel and drops onto the bar, the cloth bunching
	float s = span * 2.0 - 1.0;
	float o = smoothstep(0.0, 1.0, open);
	VERTEX.x *= mix(0.07, 1.0, o);
	VERTEX.y = mix(1.79 + (VERTEX.y - 1.79) * 0.35, VERTEX.y, o);
	VERTEX.z = mix(0.12 + (VERTEX.z - 0.12) * 0.6, VERTEX.z, o);
	if (layer > 0.75) {
		float aft = UV.y;
		// air working the panels: a travelling ripple, larger aft and mid-panel, plus the
		// slack cloth crumpling while it is gathered
		float t = TIME;
		float ripple = sin(t * 9.0 - UV.y * 7.0 + s * 4.0) * 0.6 + sin(t * 13.7 + s * 11.0) * 0.4;
		// the panels are cut to belly full at gliding speed; short of it the air lets them go
		// and they sag between the battens and luff at the trailing edge
		float c = UV2.x;
		float slack = 1.0 - clamp(fill, 0.0, 1.0);
		float puff = billow * pow(sin(3.14159 * clamp(c * 1.08, 0.0, 1.0)), 0.8);
		VERTEX.y -= puff * slack * 0.1;
		VERTEX.y += ripple * billow * aft * (0.012 + 0.03 * gust + 0.03 * slack * c) * o;
		VERTEX.y += (vnoise(vec2(s * 30.0, UV.y * 9.0)) - 0.5) * 0.08 * (1.0 - o);
	}
}

void fragment() {
	vec3 alb;
	float rough;
	float bump = 0.0;
	float trans = 0.0;
	if (layer > 0.75) {
		vec2 p = cuv;
		// each panel between two battens was cut from a different bolt: undyed replacement
		// linen, the old sun-browned hemp, a heavily oiled near-umber one
		float pi = floor(span * 8.0);
		float ph = hash(vec2(pi, 3.1));
		vec3 bolt = canvas;
		// (the linen is grey-brown with grime, not white: from below it was reading as paper)
		float linen = step(0.72, ph);
		bolt = mix(bolt, vec3(0.45, 0.38, 0.27), linen);
		bolt = mix(bolt, vec3(0.31, 0.23, 0.15), step(ph, 0.28));
		bolt *= 0.9 + 0.2 * hash(vec2(pi, 8.7));
		// plain-woven hemp: threads in both directions, slubs, oil soaked unevenly
		float weave = (sin(p.x * 900.0) * 0.5 + 0.5) * (sin(p.y * 900.0) * 0.5 + 0.5);
		float slub = vnoise(vec2(p.x * 40.0, p.y * 400.0)) * vnoise(vec2(p.x * 420.0, p.y * 35.0));
		float oil = fbm(p * 3.1);
		alb = bolt * (0.72 + 0.4 * oil) * (0.92 + 0.12 * weave) * (0.95 + 0.15 * slub);
		// old oil and rain stains: blotches with a darker tide line at their rim
		float st = fbm(p * 1.3 + vec2(pi * 0.37, 0.0));
		float blot = smoothstep(0.56, 0.6, st);
		float tide = smoothstep(0.54, 0.565, st) * (1.0 - smoothstep(0.575, 0.6, st));
		alb *= 1.0 - blot * 0.22 - tide * 0.3;
		// the cloth sags into the batten lines and is rubbed pale where it rides over each
		// batten; a doubled, stitched seam strip either side
		// (metres from the nearest batten: they sit every SPAN / 8 = 0.4125 m across)
		float d = abs(fract(p.x / 0.4125 + 0.5) - 0.5) * 0.4125;
		float ridge = 1.0 - smoothstep(0.008, 0.014, d);
		float seam = smoothstep(0.012, 0.016, d) * (1.0 - smoothstep(0.028, 0.032, d));
		float stitch = step(0.5, fract(p.y * 55.0)) * smoothstep(0.034, 0.037, d) * (1.0 - smoothstep(0.041, 0.044, d));
		alb *= mix(0.68, 1.0, smoothstep(0.01, 0.16, d));
		alb *= 1.0 - seam * 0.4 - stitch * 0.35;
		alb = mix(alb, alb * 1.55 + vec3(0.05, 0.04, 0.02), ridge * (1.0 - under));
		// the leading edge bound in a tarred hemp tape, the trailing hem turned and sewn
		float bind = 1.0 - smoothstep(0.05, 0.065, p.y);
		alb = mix(alb, vec3(0.13, 0.10, 0.07) * (0.8 + 0.4 * oil), bind);
		// patches: dyed or undyed cloth sewn over old tears, sizes vary, dark stitched rims
		vec2 cell = floor(p * vec2(2.4, 3.2));
		vec2 f = fract(p * vec2(2.4, 3.2));
		float hc = hash(cell + 7.0);
		float has = step(0.74, hc);
		vec2 lo = vec2(0.12, 0.16) + 0.14 * vec2(hash(cell + 2.0), hash(cell + 5.0));
		vec2 hi = vec2(0.6, 0.62) + 0.3 * vec2(hash(cell + 9.0), hash(cell + 4.0));
		float inside = has * step(lo.x, f.x) * step(f.x, hi.x) * step(lo.y, f.y) * step(f.y, hi.y);
		float rim = has * (1.0 - inside) * step(lo.x - 0.035, f.x) * step(f.x, hi.x + 0.035)
				* step(lo.y - 0.035, f.y) * step(f.y, hi.y + 0.035);
		vec3 pc = mix(canvas_patch, vec3(0.70, 0.62, 0.48), step(0.9, hc));
		alb = mix(alb, pc * (0.8 + 0.4 * oil), inside);
		alb *= 1.0 - rim * 0.55;
		// a sun disc in red ochre, painted long ago on the keel panels, flaking and faded
		float dr = length((p - vec2(0.0, 0.62)) * vec2(1.0, 1.15));
		float ring = smoothstep(0.035, 0.0, abs(dr - 0.36)) + smoothstep(0.2, 0.17, dr) * 0.85;
		ring *= smoothstep(0.3, 0.55, fbm(p * 9.0)) * (1.0 - under * 0.6);
		alb = mix(alb, vec3(0.42, 0.11, 0.06) * (0.8 + 0.3 * oil), ring * 0.75);
		// weather: soot and sun-bleach toward the tips, grime along the trailing edge
		float edge_dirt = smoothstep(0.7, 1.6, p.y) * fbm(p * 6.0);
		alb *= 1.0 - 0.4 * edge_dirt;
		alb = mix(alb, alb * vec3(1.12, 1.07, 0.98), smoothstep(0.6, 1.0, abs(span * 2.0 - 1.0)) * 0.45);
		rough = mix(0.58, 0.88, oil) - seam * 0.1 - ridge * 0.15 - bind * 0.2 + ring * 0.1;
		bump = weave * 0.25 + slub * 0.4 + ridge * 1.2 + seam * 0.5 + stitch * 0.5 + rim * 0.9 + bind * 0.6 + tide * 0.3;
		// thinner unoiled linen lets less of the sun's warmth through than the oiled hemp
		trans = mix(1.0, 0.55, linen) * (1.0 - bind);
		if (under > 0.5) {
			alb *= 0.82;   // the underside shows the cloth's less-oiled back
		}
	} else if (layer > 0.25) {
		// twisted hemp cord / cloth wrap
		float twist = fract(cuv.y * 60.0 + cuv.x * 2.0);
		float ply = smoothstep(0.0, 0.3, twist) * smoothstep(1.0, 0.6, twist);
		alb = cord * (0.7 + 0.45 * ply) * (0.85 + 0.3 * fbm(cuv * vec2(4.0, 30.0)));
		rough = 0.93;
		bump = ply;
	} else {
		// bamboo: long fibres, a node every 0.3 m with a raised collar, the skin worn glossy
		float along = cuv.y;
		float nd = fract(along / 0.31 + 0.37);
		float node = smoothstep(0.035, 0.0, nd) + smoothstep(0.965, 1.0, nd);
		float fibre = vnoise(vec2(cuv.x * 70.0, along * 2.0)) * 0.6 + vnoise(vec2(cuv.x * 200.0, along * 6.0)) * 0.4;
		float mottle = fbm(vec2(cuv.x * 6.0, along * 3.0));
		alb = bamboo * (0.7 + 0.35 * fibre) * (0.8 + 0.35 * mottle);
		alb = mix(alb, bamboo_node, node * 0.8);
		rough = 0.38 + 0.25 * mottle + node * 0.2;
		bump = fibre * 0.2 + node;
	}
	vec3 wet_n = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wet_p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wet_n, wet_p, vnoise(cuv * 5.0)), layer > 0.25 ? 1.0 : 0.3);
	ALBEDO = alb;
	EMISSION += figure_fill(alb, wet_n, wet_p);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.4;
	// sunlight through the oiled cloth glows warm from beneath
	BACKLIGHT = alb * vec3(1.0, 0.8, 0.55) * 0.55 * trans;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float bx = dFdx(bump);
	float by = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (bx * r1 + by * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.002);
}
