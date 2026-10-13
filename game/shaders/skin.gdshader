shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/wet.gdshaderinc"
// The hero's face band between the hood and the face cloth: weathered, sun-browned skin with
// subsurface scattering, a brow shadow and darker lids round the eyes. The eye openings are
// cut out by an almond-shaped discard (body-space, so the lids follow the mesh) and the
// eyeballs sit behind them. `eyes` holds the two eye centres (x, y) in mesh space; `eye_size`
// is the half width and the half height at the middle of the opening.

uniform vec3 skin_col : source_color = vec3(0.40, 0.29, 0.225);
uniform vec3 lid_col : source_color = vec3(0.30, 0.17, 0.13);
uniform vec4 eyes = vec4(-0.031, 1.968, 0.031, 1.968);
uniform vec2 eye_size = vec2(0.0135, 0.0042);
uniform float brow_y = 1.990;

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
	float top = eye_size.y * sh * 1.15;
	float bot = -eye_size.y * sh * 0.8;
	float inside_x = abs(d.x) - eye_size.x;
	return max(inside_x, max(d.y - top, bot - d.y));
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
	// lids: darker, slightly purple skin in a band round each opening; lash line at the edge
	float lid = 1.0 - smoothstep(0.0, 0.006, de);
	alb = mix(alb, lid_col, 0.55 * lid);
	float lash = 1.0 - smoothstep(0.0, 0.0011, de);
	// the upper lash line is heavier than the lower
	float upper = step(eyes.y - 0.001, p.y);
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
	vec3 wn = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wn, wp, n), 1.0);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	// the sockets and the brow overhang hold shadow
	AO = mix(0.55, 1.0, smoothstep(0.0, 0.009, de)) * mix(0.8, 1.0, smoothstep(0.0, 0.006, -by));
	AO_LIGHT_AFFECT = 0.6;
	SSS_STRENGTH = 0.55;
	SSS_TRANSMITTANCE_COLOR = vec4(0.9, 0.3, 0.2, 1.0);
	SSS_TRANSMITTANCE_DEPTH = 0.08;
	SSS_TRANSMITTANCE_BOOST = 0.15;
	BACKLIGHT = vec3(0.25, 0.08, 0.05);
}
