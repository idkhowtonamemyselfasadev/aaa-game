shader_type spatial;
render_mode cull_back;
// Harrowmere's houses (world/cottage.gd). COLOR.r picks the layer: 0 oak frame, 0.25
// limewashed daub, 0.5 slate (instanced roof slates and the stone ridge), 0.75 boards
// (door, shutter, sarking, barge boards), 1 iron. COLOR.g = 1 on end grain (wood) or a
// slate's riven edge. Wood UV = (around the section m, along the grain m); daub UV = metres
// in the wall plane. UV2 = (per-piece random, height above the footing m).
// Instanced slates: INSTANCE_CUSTOM = (random, lichen seed, course 0 eave .. 1 ridge, side),
// UV = (across 0..1, head 0 .. tail 1).
#include "res://shaders/weather.gdshaderinc"
global uniform vec3 bounce_light;

uniform bool instanced = false;
uniform vec3 oak_silver : source_color = vec3(0.42, 0.4, 0.36);
uniform vec3 oak_brown : source_color = vec3(0.27, 0.2, 0.14);
uniform vec3 oak_dark : source_color = vec3(0.13, 0.1, 0.08);
uniform vec3 lime : source_color = vec3(0.66, 0.63, 0.56);
uniform vec3 daub : source_color = vec3(0.47, 0.38, 0.27);
uniform vec3 grime : source_color = vec3(0.3, 0.3, 0.23);
uniform vec3 slate_a : source_color = vec3(0.2, 0.2, 0.21);
uniform vec3 slate_b : source_color = vec3(0.21, 0.19, 0.2);
uniform vec3 slate_c : source_color = vec3(0.19, 0.2, 0.19);
uniform vec3 lichen_y : source_color = vec3(0.55, 0.5, 0.33);
uniform vec3 lichen_g : source_color = vec3(0.5, 0.53, 0.47);
uniform vec3 moss : source_color = vec3(0.26, 0.3, 0.1);
uniform vec3 iron : source_color = vec3(0.12, 0.11, 0.1);
uniform vec3 rust : source_color = vec3(0.33, 0.17, 0.08);

varying vec3 wp;
varying vec3 wn;
varying float layer;
varying float endg;
varying float rnd;
varying float hgt;
varying float course;
varying float lich;
varying float v_cloud;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = p * 2.07 + 5.3; a *= 0.5; } return r; }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	layer = COLOR.r;
	endg = COLOR.g;
	if (instanced) {
		rnd = INSTANCE_CUSTOM.r;
		lich = INSTANCE_CUSTOM.g;
		course = INSTANCE_CUSTOM.b;
		hgt = 3.0;
	} else {
		rnd = UV2.x;
		lich = fract(UV2.x * 7.3);
		course = 1.0;
		hgt = UV2.y;
	}
	v_cloud = cloud_shade_at(wp);
}

// bump the view-space normal by a height field h (screen-space derivatives)
vec3 bump(vec3 n, vec3 p, float h, float amt) {
	vec3 dpx = dFdx(p);
	vec3 dpy = dFdy(p);
	float dhx = dFdx(h) * amt;
	float dhy = dFdy(h) * amt;
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 g = sign(det) * (dhx * r1 + dhy * r2);
	return normalize(abs(det) * n - g);
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 col;
	float rough;
	float metal = 0.0;
	float h = 0.0;
	float amt = 0.0;
	float ao = 1.0;
	float porous = 1.0;
	float side = 1.0 - smoothstep(0.3, 0.7, abs(n.y));
	if (layer < 0.12 || (layer > 0.62 && layer < 0.88)) {
		// oak: weathered silver-grey where the rain reaches, brown under the eaves and on the
		// undersides; long grain, hewn ripples across it, drying checks along it
		bool boards = layer > 0.62;
		vec2 g = UV;
		float grain = fbm(vec3(g.x * 34.0, g.y * 1.4, rnd * 40.0));
		float streak = vn(vec3(g.x * 90.0, g.y * 0.5, rnd * 13.0));
		float ripple = sin(g.y * (boards ? 9.0 : 14.0) + fbm(vec3(g.x * 3.0, g.y * 2.0, rnd * 5.0)) * 5.0) * 0.5 + 0.5;
		float check = smoothstep(0.93, 0.985, vn(vec3(g.x * 16.0, g.y * 0.9, rnd * 21.0))) * (boards ? 0.4 : 1.0);
		if (endg > 0.5) {
			// end grain: growth rings round the heart, radial cracks
			float r = length(UV);
			float ring = sin(r * 220.0 + fbm(vec3(UV * 20.0, rnd)) * 3.0) * 0.5 + 0.5;
			grain = 0.4 + ring * 0.3;
			streak = 0.5;
			ripple = 0.5;
			check = smoothstep(0.9, 0.97, vn(vec3(atan(UV.y, UV.x) * 3.0, r * 4.0, rnd * 9.0)));
		}
		// exposure to the weather: top faces and the low outer frame silver, sheltered parts stay brown
		float shelter = smoothstep(1.7, 2.4, hgt) * (1.0 - smoothstep(0.4, 0.9, n.y)) + smoothstep(0.2, 0.8, -n.y);
		shelter = clamp(shelter + (boards ? 0.15 : 0.0), 0.0, 1.0);
		vec3 silver = oak_silver * (0.82 + 0.3 * grain) * (0.94 + 0.12 * rnd);
		vec3 brown = mix(oak_brown, oak_dark, 0.3 + 0.3 * rnd) * (0.8 + 0.4 * grain);
		col = mix(silver, brown, shelter * 0.75);
		if (boards) {
			col = mix(col, oak_dark * (0.8 + 0.5 * grain), 0.35);
		}
		col *= 0.88 + 0.16 * streak;
		col = mix(col, oak_dark * 0.6, check * 0.85);
		// the sill and post feet: damp, darker, a green algal film
		float damp = 1.0 - smoothstep(0.0, 0.6, hgt);
		col = mix(col, col * vec3(0.7, 0.78, 0.6), damp * 0.6);
		// lichen specks on the exposed frame
		float lic = smoothstep(0.74, 0.8, fbm(wp * 5.0 + 3.0)) * (1.0 - shelter);
		col = mix(col, lichen_g * 0.9, lic * 0.6);
		h = grain * 0.4 + ripple * 0.5 - check * 1.2 + streak * 0.2;
		amt = 0.006;
		rough = mix(0.86, 0.74, shelter) + check * 0.1;
		ao = 1.0 - check * 0.5;
	} else if (layer < 0.37) {
		// daub under limewash: lumpy hand-laid surface, the wash flaked in places to the buff
		// clay-and-straw beneath, grime and green damp rising from the sill, rain streaks
		float lump = fbm(wp * 4.0 + rnd * 9.0);
		float fine = vn(wp * 38.0);
		h = lump * 0.8 + fine * 0.15;
		amt = 0.02;
		vec3 wash = lime * (0.9 + 0.12 * lump) * (0.95 + 0.08 * rnd);
		// older and newer coats: some panels whiter, some yellowed
		wash *= mix(vec3(1.0), vec3(1.02, 0.97, 0.88), fract(rnd * 5.7));
		float flake = smoothstep(0.68, 0.72, fbm(wp * 5.0 + rnd * 17.0 + 4.0) + (1.0 - smoothstep(0.0, 0.8, hgt)) * 0.06);
		vec3 clay = daub * (0.8 + 0.4 * fbm(wp * 12.0)) ;
		float straw = smoothstep(0.82, 0.9, vn(vec3(wp.x * 40.0, wp.y * 6.0, wp.z * 40.0)));
		clay = mix(clay, vec3(0.6, 0.5, 0.3), straw * 0.5);
		col = mix(wash, mix(wash, clay, 0.6), flake);
		h -= flake * 0.4;
		float low = 1.0 - smoothstep(0.1, 0.9 + 0.3 * fbm(wp * 1.5), hgt);
		col = mix(col, grime * (0.8 + 0.3 * fine), low * 0.65);
		// streaks running down from the rail and plate above
		float st = smoothstep(0.55, 0.85, fbm(vec3(wp.x * 9.0 + wp.z * 9.0, wp.y * 0.6, rnd * 3.0)));
		col *= 1.0 - st * 0.18;
		// the wall top under the eaves stays drier and shaded
		col *= 1.0 - smoothstep(1.6, 2.2, hgt) * 0.12;
		rough = 0.93;
		ao = 0.85 + 0.15 * lump;
	} else if (layer < 0.62) {
		// slate: cool blue-grey, purple and green beds; riven cleavage ripples; yellow and
		// grey lichen crusts thick near the eaves, moss tucked in the low tails
		float bed = fract(rnd * 3.7);
		vec3 base = bed < 0.4 ? slate_a : bed < 0.7 ? slate_b : slate_c;
		base *= 0.82 + 0.38 * fract(rnd * 11.3);
		float riven = fbm(vec3(wp.x * 6.0, wp.y * 14.0, wp.z * 6.0) + rnd * 20.0);
		col = base * (0.85 + 0.3 * riven);
		h = riven * 0.6 + vn(wp * 60.0) * 0.15;
		amt = 0.004;
		// the visible tail of each slate: the head is under the next course up; shade the
		// strip just below the overlap and darken the riven edge
		if (instanced) {
			float vis = smoothstep(0.5, 0.62, UV.y);
			ao = mix(0.55, 1.0, vis);
		}
		col *= 1.0 - endg * 0.25;
		float eaves = 1.0 - smoothstep(0.0, 0.55, course);
		float l1 = smoothstep(0.74 - eaves * 0.1, 0.78 - eaves * 0.1, fbm(wp * 9.0 + lich * 30.0));
		float l2 = smoothstep(0.7 - eaves * 0.1, 0.75 - eaves * 0.1, fbm(wp * 7.0 + 50.0 + lich * 9.0));
		col = mix(col, lichen_y * (0.75 + 0.4 * vn(wp * 50.0)), l1 * 0.55);
		col = mix(col, lichen_g * (0.75 + 0.4 * vn(wp * 40.0)), l2 * 0.5);
		float ms = smoothstep(0.6, 0.75, fbm(wp * 2.0 + 9.0) + eaves * 0.25) * eaves * (instanced ? smoothstep(0.75, 1.0, UV.y) : 0.0);
		col = mix(col, moss * (0.8 + 0.4 * vn(wp * 30.0)), ms);
		h += (l1 + l2) * 0.2 + ms * 0.5;
		rough = mix(0.7, 0.88, max(max(l1, l2), ms));
		porous = 0.4;
	} else {
		// iron straps and the ring: black-brown with rust blooms
		float rs = smoothstep(0.4, 0.7, fbm(wp * 18.0));
		col = mix(iron, rust, rs);
		h = fbm(wp * 50.0);
		amt = 0.003;
		metal = mix(0.6, 0.1, rs);
		rough = mix(0.55, 0.9, rs);
		porous = 0.3;
	}
	weather_wetten(col, rough, porous);
	ALBEDO = col * v_cloud;
	ROUGHNESS = rough;
	METALLIC = metal;
	AO = ao;
	NORMAL = bump(NORMAL, VERTEX, h * amt * 1.5, 1.0);
	float facing = mix(1.0, 0.5, clamp(n.y, 0.0, 1.0));
	EMISSION = ALBEDO * bounce_light * facing * ao;
}
