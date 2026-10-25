shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/wet.gdshaderinc"
#include "res://shaders/figure_fill.gdshaderinc"
// The hero's face band between the hood and the face cloth: weathered, sun-browned skin with
// subsurface scattering, a brow shadow and darker lids round the eyes. The eye openings are
// cut out by an almond-shaped discard (body-space, so the lids follow the mesh) and the
// eyeballs sit behind them. `eyes` holds the two eye centres (x, y) in mesh space; `eye_size`
// is the half width and the half height at the middle of the opening.

uniform vec3 skin_col : source_color = vec3(0.34, 0.255, 0.21);
uniform vec3 lid_col : source_color = vec3(0.30, 0.17, 0.13);
uniform vec4 eyes = vec4(-0.031, 1.968, 0.031, 1.968);
uniform vec2 eye_size = vec2(0.0135, 0.0037);
uniform float brow_y = 1.990;
uniform float low_tuck = 0.72;   // UV.y where the lower edge starts sinking into shade
uniform float face_fill = 1.4;  // ground bounce under the brim (the body garb gets 1.0)
uniform float age = 0.0;         // 0 a working adult .. 1 an old man: paler, greyer, liver
                                 // spots, deeper lines, the colour only in the cheeks and nose

varying vec3 mp;

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

// signed distance-ish of an almond eye opening: < 0 inside. The outer corner sits a little
// higher than the inner one, the upper lid arches more than the lower.
float almond(vec2 p, vec2 c, float side) {
	vec2 d = p - c;
	float t = clamp(d.x * side / eye_size.x, -1.0, 1.0);   // -1 inner corner .. 1 outer
	d.y -= 0.0012 * t;
	float sh = pow(max(1.0 - t * t, 0.0), 0.75);
	float top = eye_size.y * sh * 0.84;   // a relaxed, slightly heavy upper lid over the top of the iris (0.92 read wide-eyed)
	float bot = -eye_size.y * sh * 0.8;
	float inside_x = abs(d.x) - eye_size.x;
	return max(inside_x, max(d.y - top, bot - d.y));
}

// Relief of the skin in metres (negative = sunk): a coarse weathered grain, crow's feet fanning
// from the outer eye corners, a crease under each lower lid and two frown lines between the
// brows. Drawn as a bump on the shading normal; also darkens the grooves a little.
float skin_relief(vec2 p, float de) {
	float h = (vnoise(p * 420.0) - 0.5) * 0.00018 + (vnoise(p * 1300.0 + 11.0) - 0.5) * 0.00006;
	for (int i = 0; i < 2; i++) {
		float side = i == 0 ? -1.0 : 1.0;
		vec2 c = vec2(side * (abs(eyes.z) + eye_size.x + 0.0015), eyes.y + 0.0012);
		vec2 q = p - c;
		float r = length(q);
		float a = atan(q.y, q.x * side);
		float fan = (1.0 - smoothstep(0.55, 0.9, abs(a))) * smoothstep(0.0015, 0.004, r)
				* (1.0 - smoothstep(0.009, 0.016, r));
		float wob = vnoise(vec2(r * 300.0, float(i) * 5.0)) * 1.2;
		float line = pow(abs(sin(a * 9.0 + wob + float(i))), 6.0);
		h -= 0.00028 * fan * line;
	}
	// a crease running under each lower lid, ~4 mm below the lash line
	float below = step(p.y, eyes.y - 0.001);
	h -= 0.00022 * below * exp(-pow((de - 0.0045) / 0.0009, 2.0))
			* (1.0 - smoothstep(0.004, 0.012, abs(abs(p.x) - abs(eyes.z) - 0.003)));
	// two short frown lines between the brows
	float fx = abs(abs(p.x) - 0.0055);
	h -= 0.00025 * exp(-pow(fx / 0.0006, 2.0)) * smoothstep(1.972, 1.978, p.y)
			* (1.0 - smoothstep(1.988, 1.996, p.y));
	// age: everything cut deeper, and long lines across the forehead over the brows
	h *= 1.0 + 0.8 * age;
	float fy = fract((p.y - 1.998) / 0.0042 + 0.25 * vnoise(vec2(p.x * 90.0, 2.0)));
	h -= age * 0.0002 * exp(-pow((fy - 0.5) / 0.09, 2.0)) * smoothstep(1.997, 2.001, p.y)
			* (1.0 - smoothstep(0.03, 0.05, abs(p.x)));
	return h;
}

void vertex() {
	mp = VERTEX;
}

void fragment() {
	vec2 p = mp.xy;
	float dl = almond(p, eyes.xy, -1.0);
	float dr = almond(p, eyes.zw, 1.0);
	float de = min(dl, dr);
	if (de < 0.0) {
		discard;
	}
	// pores and blotches; a little ruddier on the cheekbones and nose
	float n = vnoise(p * 900.0) * 0.5 + vnoise(p * 260.0 + 7.0) * 0.5;
	float blotch = vnoise(p * 60.0 + 3.0);
	vec3 alb = skin_col * (0.86 + 0.22 * n) * (0.92 + 0.12 * blotch);
	float cheek = smoothstep(0.018, 0.04, abs(p.x)) * (1.0 - smoothstep(1.958, 1.94, p.y) * 0.0);
	alb = mix(alb, alb * vec3(1.08, 0.88, 0.85), 0.35 * cheek * smoothstep(1.962, 1.945, p.y));
	if (age > 0.0) {
		// an old face: the sun-brown drained to a paler, greyer skin with blotched patches and
		// a few liver spots; the colour stays in broken veins on the cheekbones and the nose tip
		float l = dot(alb, vec3(0.3, 0.59, 0.11));
		alb = mix(alb, vec3(l) * vec3(1.06, 0.98, 0.92), 0.45 * age);
		alb *= mix(1.0, 0.82 + 0.3 * vnoise(p * 140.0 + 21.0), 0.6 * age);
		float spot = smoothstep(0.78, 0.86, vnoise(p * 330.0 + 40.0)) * smoothstep(1.95, 1.975, p.y);
		alb = mix(alb, alb * vec3(0.72, 0.6, 0.5), 0.6 * age * spot);
		float ruddy = exp(-pow((abs(p.x) - 0.042) / 0.014, 2.0) - pow((p.y - 1.948) / 0.012, 2.0))
				+ exp(-pow(p.x / 0.012, 2.0) - pow((p.y - 1.912) / 0.012, 2.0));
		float veins = 0.6 + 0.4 * vnoise(vec2(p.x * 1500.0, p.y * 700.0));
		alb = mix(alb, alb * vec3(1.2, 0.86, 0.82), 0.4 * age * clamp(ruddy, 0.0, 1.0) * veins);
		// the form an old face has under a hat: the sockets sunk in darker, thinner skin, the
		// temples hollow, the brow bone and the cheekbones a shade lighter where they catch the
		// light (a uniform albedo read as a flat mask with no eyes at a few metres)
		float sock = 0.0;
		for (int i = 0; i < 2; i++) {
			vec2 c = i == 0 ? eyes.xy : eyes.zw;
			sock = max(sock, exp(-pow((p.x - c.x) / 0.022, 2.0) - pow((p.y - c.y + 0.002) / 0.012, 2.0)));
		}
		alb *= mix(1.0, 0.62, age * sock);
		float bone = exp(-pow((p.y - 1.993) / 0.006, 2.0)) * (1.0 - smoothstep(0.035, 0.06, abs(p.x)))
				+ exp(-pow((abs(p.x) - 0.046) / 0.012, 2.0) - pow((p.y - 1.952) / 0.008, 2.0));
		alb *= 1.0 + 0.16 * age * clamp(bone, 0.0, 1.0);
		float temple = smoothstep(0.05, 0.075, abs(p.x)) * smoothstep(1.955, 1.975, p.y);
		alb *= mix(1.0, 0.8, age * temple);
	}
	// lids: darker, slightly purple skin in a band round each opening; lash line at the edge
	float lid = 1.0 - smoothstep(0.0, 0.006, de);
	// (an old man's lids are hooded and dull, not pink: the red rims read as glinting red eyes)
	alb = mix(alb, mix(lid_col, alb * 0.7, 0.6 * age), 0.55 * lid);
	// the upper lash line is heavier and wider than the lower
	float upper = step(eyes.y - 0.001, p.y);
	float lash = 1.0 - smoothstep(0.0, mix(0.0011, 0.0017, upper), de);
	alb = mix(alb, vec3(0.03, 0.02, 0.018), lash * mix(0.5, 0.95, upper));
	// brows: coarse dark hair in an arc above each eye, thicker at the inner end
	float bx = abs(p.x) - 0.031;
	float by = p.y - (brow_y + 0.004 * (1.0 - bx * bx / 0.0004) - 0.002 * bx / 0.02);
	float brow_w = mix(0.0042, 0.0025, smoothstep(-0.016, 0.02, bx));
	float brow = (1.0 - smoothstep(brow_w * 0.6, brow_w, abs(by))) * (1.0 - smoothstep(0.016, 0.022, abs(bx + 0.002)));
	float hair = vnoise(vec2(p.x * 2200.0 + p.y * 900.0, p.y * 350.0));
	alb = mix(alb, vec3(0.035, 0.026, 0.02), brow * (0.55 + 0.45 * hair));
	float rough = mix(0.52, 0.4, lid) + 0.1 * n;
	rough = mix(rough, 0.7, brow);
	// skin relief as a bump on the view-space normal (surface-gradient bump mapping)
	float h = skin_relief(p, de);
	alb *= 1.0 + clamp(h / 0.00028, -1.0, 0.3) * 0.25;
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL);
	vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 1.6);
	// the band tucks under the hood at the top and sides and under the face cloth below: its
	// edges sink into the hood's shadow instead of ending at a lit rim (a pale mask at night)
	// (wide falloffs: the hood opening hides the band's outer third, the shadow reaches in)
	float tuck = smoothstep(0.0, 0.4, UV.x) * smoothstep(1.0, 0.6, UV.x)
			* smoothstep(-0.05, 0.5, UV.y) * smoothstep(1.0, low_tuck, UV.y);
	alb *= mix(0.72, 1.0, tuck);
	vec3 wn = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wn, wp, n), 1.0);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	// the sockets and the brow overhang hold shadow
	AO = mix(0.55, 1.0, smoothstep(0.0, 0.009, de)) * mix(0.8, 1.0, smoothstep(0.0, 0.006, -by))
			* mix(0.15, 1.0, tuck);
	AO_LIGHT_AFFECT = 0.8;
	// the meadow's bounce up under the hat brim and into the hood opening, as the garb gets
	// it: without it the face band, shaded by the brim, read darker than the body round it
	// and was lost in the hood. The sockets and tucked edges keep most of their shade.
	EMISSION = figure_fill(alb, wn, wp) * face_fill * mix(0.25, 1.0, tuck)
			* mix(0.5, 1.0, smoothstep(0.0, 0.009, de));
	SSS_STRENGTH = 0.35;
	SSS_TRANSMITTANCE_COLOR = vec4(0.9, 0.3, 0.2, 1.0);
	SSS_TRANSMITTANCE_DEPTH = 0.08;
	SSS_TRANSMITTANCE_BOOST = 0.15;
	BACKLIGHT = vec3(0.25, 0.08, 0.05);
}
