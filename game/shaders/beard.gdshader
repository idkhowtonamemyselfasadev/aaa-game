shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/wet.gdshaderinc"
// An old man's beard and moustache on the face cloth's mesh (garb.gd `_veil`, model space: x
// across, y up, the front at +z). Coarse grey-white hair in strands that run down the jaw and
// sweep out and down from the middle of the upper lip; pepper-dark hairs mixed in, darker in
// the clumps' hollows (COLOR.r, the cloth's fold cavity, reads as the beard's clumping). The
// top edge is cut into a moustache line under the nose that rises to the cheekbones, with a
// ragged fringe so it never reads as a ruled edge.

uniform vec3 hair_col : source_color = vec3(0.50, 0.48, 0.45);
uniform vec3 dark_col : source_color = vec3(0.10, 0.092, 0.082);

varying vec3 mp;
varying float cav;

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

void vertex() {
	mp = VERTEX;
	cav = COLOR.r;
}

void fragment() {
	vec2 p = mp.xy;
	float ax = abs(p.x);
	float front = step(0.0, mp.z);
	// the moustache line: just under the nose in the middle, rising past the nostrils to the
	// cheekbones; hair tufts poke over it
	float top = 1.893 + 0.037 * smoothstep(0.016, 0.052, ax);
	float fringe = (vnoise(vec2(p.x * 900.0, 3.0)) - 0.5) * 0.004 + (hash(vec2(floor(p.x * 2600.0), 1.0)) - 0.5) * 0.002;
	if (front > 0.5 && p.y > top + fringe) {
		discard;
	}
	// strand direction: straight down the jaw; on the moustache sweeping out and down from the
	// philtrum
	float moust = smoothstep(1.86, 1.878, p.y) * (1.0 - smoothstep(0.04, 0.06, ax));
	float ang = sign(p.x) * mix(0.15, 1.05, moust) * smoothstep(0.0, 0.012, ax);
	vec2 o = p - vec2(0.0, 1.88);
	vec2 q = vec2(cos(ang) * o.x + sin(ang) * o.y, -sin(ang) * o.x + cos(ang) * o.y);
	// a little wave along each lock
	q.x += 0.0012 * sin(q.y * 140.0 + vnoise(vec2(q.x * 300.0, 0.0)) * 6.0);
	float s1 = vnoise(vec2(q.x * 2200.0, q.y * 70.0));
	float s2 = vnoise(vec2(q.x * 5200.0 + 13.0, q.y * 160.0));
	float lock = vnoise(vec2(q.x * 260.0, q.y * 18.0 + 5.0));
	float strand = s1 * 0.6 + s2 * 0.4;
	// grizzled: mostly grey-white with dark hairs through it, darker toward the roots at the
	// moustache line and in the hollows between the locks
	float pepper = step(0.72, hash(vec2(floor(q.x * 3200.0), floor(q.y * 40.0))));
	// (full dark-to-light strands read as grey bark, too little as a white plaster patch)
	vec3 alb = mix(hair_col * 0.62, hair_col, smoothstep(0.1, 0.9, strand));
	alb = mix(alb, mix(dark_col, hair_col, 0.3), pepper * 0.32);
	float hollow = mix(0.8, 1.0, smoothstep(0.25, 0.75, lock)) * mix(0.7, 1.0, cav);
	float root = mix(0.7, 1.0, smoothstep(0.0, 0.006, top - p.y));
	alb *= hollow * root;
	// stained at the lip by pipe smoke and broth
	float stain = (1.0 - smoothstep(0.0, 0.02, ax)) * smoothstep(1.86, 1.885, p.y);
	alb = mix(alb, alb * vec3(0.85, 0.72, 0.55), 0.5 * stain);
	// the lips' parting shows as a dark line under the moustache's fringe
	float lips = exp(-pow((p.y - 1.866) / 0.0015, 2.0)) * (1.0 - smoothstep(0.012, 0.022, ax));
	alb *= 1.0 - 0.6 * lips;
	float rough = mix(0.62, 0.48, strand);
	// the strands as a bump on the shading normal
	float h = strand * 0.0003 + lock * 0.0011;
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL);
	vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 1.2);
	vec3 wn = mat3(INV_VIEW_MATRIX) * NORMAL;
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet_apply(alb, rough, wet_amount(wn, wp, lock), 1.0);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	AO = hollow;
	AO_LIGHT_AFFECT = 0.5;
	// grey hair scatters a soft sheen at grazing angles and glows a little against the light
	RIM = 0.3;
	RIM_TINT = 0.6;
	BACKLIGHT = hair_col * 0.25;
}
