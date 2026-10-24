shader_type spatial;
render_mode cull_back;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// Caelum's glider: COLOR.r picks the layer (0 bamboo, 0.5 cord and grip wrap, 1 canvas).
// COLOR.g = canvas billow between ribs (0 at a rib), COLOR.b = span position 0..1,
// COLOR.a = 1 on the canvas's underside. UV = metres (canvas: across, back from the nose;
// tubes: around 0..1, along). All detail is procedural.

uniform float open = 1.0;
uniform float gust = 0.0;    // wind working the cloth: the ripple grows
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
		VERTEX.y += ripple * billow * aft * (0.012 + 0.03 * gust) * o;
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
		// plain-woven hemp: threads in both directions, slubs, oil soaked unevenly
		float weave = (sin(p.x * 900.0) * 0.5 + 0.5) * (sin(p.y * 900.0) * 0.5 + 0.5);
		float slub = vnoise(vec2(p.x * 40.0, p.y * 400.0)) * vnoise(vec2(p.x * 420.0, p.y * 35.0));
		float oil = fbm(p * 3.1);
		alb = canvas * (0.78 + 0.3 * oil) * (0.92 + 0.12 * weave) * (0.95 + 0.15 * slub);
		// seams: a doubled, stitched strip down each rib
		float rib = 1.0 - billow;
		float seam = smoothstep(0.985, 0.998, rib);
		float stitch = step(0.5, fract(p.y * 55.0)) * smoothstep(0.96, 0.99, rib) * (1.0 - seam);
		alb *= 1.0 - seam * 0.28 - stitch * 0.18;
		// patches: squares of dyed cloth sewn over old tears
		vec2 cell = floor(p * vec2(2.2, 3.0));
		vec2 f = fract(p * vec2(2.2, 3.0));
		float has = step(0.86, hash(cell + 7.0));
		float inside = has * step(0.18, f.x) * step(f.x, 0.72) * step(0.22, f.y) * step(f.y, 0.7);
		float rim = has * (1.0 - inside) * step(0.15, f.x) * step(f.x, 0.75) * step(0.19, f.y) * step(f.y, 0.73);
		alb = mix(alb, canvas_patch * (0.85 + 0.3 * oil), inside);
		alb *= 1.0 - rim * 0.3;
		// weather: soot and sun-bleach toward the tips, grime along the trailing edge
		float edge_dirt = smoothstep(0.7, 1.6, p.y) * fbm(p * 6.0);
		alb *= 1.0 - 0.35 * edge_dirt;
		alb = mix(alb, alb * vec3(1.1, 1.06, 0.98), smoothstep(0.6, 1.0, abs(span * 2.0 - 1.0)) * 0.4);
		rough = mix(0.62, 0.86, oil) - seam * 0.1;
		bump = weave * 0.25 + slub * 0.4 + seam * 0.8 + stitch * 0.4 + rim * 0.6;
		trans = 1.0;
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
