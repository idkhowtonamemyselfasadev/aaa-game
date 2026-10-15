shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/figure_fill.gdshaderinc"
// Practice post: COLOR.r picks the layer (0 weathered oak, 0.33 rusted iron band,
// 0.66 straw bundle, 1 rope lashing). UV.x = around (0..1), UV.y = metres up (oak/straw)
// or around the rope's tube (rope). All detail is procedural. Straw stalk cards (COLOR.g 1)
// carry a per-stalk tone in COLOR.b and their layer depth in COLOR.a; UV.x across, UV.y
// metres along, UV2.x 0..1 along.

uniform vec3 oak_grey : source_color = vec3(0.27, 0.23, 0.185);
uniform vec3 oak_dark : source_color = vec3(0.13, 0.11, 0.09);
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
		// damp near the ground with a little moss/lichen
		float g = fbm(vec2(around * 30.0, h * 1.2));
		float fine = vnoise(vec2(around * 160.0, h * 4.0));
		float crack = smoothstep(0.035, 0.0, abs(fbm(vec2(around * 7.0, h * 0.5)) - 0.5)) ;
		crack *= smoothstep(0.3, 0.6, vnoise(vec2(around * 5.0, h * 2.5)));
		alb = oak_grey * (0.55 + 0.8 * g) * (0.75 + 0.45 * fine);
		alb = mix(alb, oak_dark, crack * 0.85);
		float damp = smoothstep(0.35, 0.0, h);
		alb = mix(alb, oak_dark * 1.4, damp * 0.6);
		float moss = smoothstep(0.62, 0.78, fbm(vec2(around * 12.0, h * 9.0)) + damp * 0.35);
		alb = mix(alb, vec3(0.16, 0.20, 0.07), moss * 0.7);
		rough = 0.82 + 0.1 * fine;
		bump = g * 0.5 + fine * 0.3 - crack * 1.2;
		ao = 1.0 - crack * 0.6;
	} else if (layer < 0.5) {
		// hand-forged iron band, rusted, a few hammer facets
		float r = fbm(vec2(around * 26.0, h * 90.0));
		float flake = smoothstep(0.45, 0.7, r);
		alb = mix(iron, rust, flake);
		rough = mix(0.5, 0.95, flake);
		metal = mix(0.8, 0.1, flake);
		bump = r * 0.6 + vnoise(vec2(around * 60.0, h * 40.0)) * 0.3;
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
