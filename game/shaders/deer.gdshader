shader_type spatial;
// Red deer built by herd.gd. Legs, neck and head are posed here per instance:
// INSTANCE_CUSTOM = (gait phase 0..1, speed m/s / 10, head down 0..1, head yaw rad).
// Mesh COLOR: r = leg (0 none, 0.25 LF, 0.5 RF, 0.75 LH, 1 RH), g = below the knee/hock
// (0..1), b = neck/head bend weight (0 body .. 1 head), a = part (0 coat, 0.25 antler,
// 0.5 eye, 1 ear). `stag` = 1 on the stag's material: dark shaggy rut mane on the neck.
// Rest pose faces -Z, hooves at y = 0.

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/bounce.gdshaderinc"

uniform vec3 coat : source_color = vec3(0.36, 0.180, 0.088);      // summer red
uniform vec3 coat_dark : source_color = vec3(0.20, 0.130, 0.086);  // neck, dorsal, lower legs
uniform vec3 belly : source_color = vec3(0.52, 0.42, 0.30);
uniform vec3 rump : source_color = vec3(0.68, 0.58, 0.42);
uniform float stag = 0.0;
uniform vec3 antler_col : source_color = vec3(0.34, 0.25, 0.16);
uniform vec3 tine_tip : source_color = vec3(0.80, 0.74, 0.62);
varying float v_along;   // 0 base .. 1 tip along an antler tube (UV.y)

varying vec3 v_rest;
varying vec4 v_col;
varying vec3 v_rest_n;
varying vec3 v_world;
varying float v_cloud;   // cloud shadow on this deer (1 = full sun)

const vec3 HIP[4] = vec3[4](vec3(0.13, 0.96, -0.40), vec3(-0.13, 0.96, -0.40), vec3(0.14, 0.98, 0.40), vec3(-0.14, 0.98, 0.40));
const vec3 KNEE[4] = vec3[4](vec3(0.11, 0.45, -0.42), vec3(-0.11, 0.45, -0.42), vec3(0.115, 0.46, 0.54), vec3(-0.115, 0.46, 0.54));
// walk: lateral sequence (LH, LF, RH, RF); gallop: rotary (LH, RH, RF, LF)
const float WALK_OFF[4] = float[4](0.25, 0.75, 0.0, 0.5);
const float GALLOP_OFF[4] = float[4](0.58, 0.46, 0.0, 0.12);

vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c); }
vec3 rot_y(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c); }

float hash3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec4 ic = INSTANCE_CUSTOM;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	v_rest = VERTEX;
	v_rest_n = NORMAL;
	v_col = COLOR;
	v_along = UV.y;
	// stag: the rut mane stands out shaggy under the throat and down the neck
	if (stag > 0.5 && COLOR.r < 0.01 && COLOR.a < 0.1) {
		float nm = smoothstep(-0.5, -0.75, v.z) * smoothstep(-1.02, -0.92, v.z);
		float shag = vnoise(vec3(v.x * 40.0, v.y * 9.0, v.z * 9.0));
		v += n * nm * (0.012 + 0.05 * shag * smoothstep(0.2, -0.6, n.y));
	}
	float spd = ic.y * 10.0;
	float gal = smoothstep(2.6, 5.0, spd);
	int leg = int(round(COLOR.r * 4.0)) - 1;
	if (leg >= 0) {
		vec3 hip = HIP[leg];
		vec3 knee = KNEE[leg];
		float ph = TAU * (ic.x + mix(WALK_OFF[leg], GALLOP_OFF[leg], gal));
		float amp = mix(clamp(spd / 1.4, 0.0, 1.0) * 0.30, 0.62, gal);
		float hind = leg >= 2 ? 1.0 : 0.0;
		// swing forward while cos > 0; the hoof folds up and back through the swing
		float swing = amp * sin(ph) + gal * mix(0.10, -0.12, hind);
		float fold = mix(0.85, 1.5, gal) * clamp(spd / 1.0, 0.0, 1.0) * max(0.0, cos(ph));
		fold = mix(fold, fold * 0.8, hind);
		float lw = COLOR.g;
		vec3 p = v - knee;
		v = mix(v, knee + rot_x(p, -fold), lw);
		n = mix(n, rot_x(n, -fold), lw);
		float tw = smoothstep(hip.y + 0.02, hip.y - 0.16, VERTEX.y);
		v = hip + rot_x(v - hip, swing * tw);
		n = rot_x(n, swing * tw);
	}
	float b = COLOR.b;
	if (b > 0.0) {
		float down = ic.z;
		// head pitch at the poll (rest space) first, then the neck swings down from its base
		// nearly rigid (a deer's grazing neck is straight, not a swan's curl)
		if (b > 0.97) {
			vec3 poll = vec3(0.0, 1.62, -1.04);
			float hb = down * 0.75;
			v = poll + rot_x(v - poll, hb);
			n = rot_x(n, hb);
		}
		vec3 nb = vec3(0.0, 0.98, -0.60);
		float a = -down * 1.75 * smoothstep(0.0, 0.6, b);
		v = nb + rot_x(v - nb, a);
		n = rot_x(n, a);
		float yw = ic.w * pow(b, 0.7);
		v = nb + rot_y(v - nb, yw);
		n = rot_y(n, yw);
	}
	// gallop: the body rocks over the shoulders and haunches
	float rock = gal * 0.07 * sin(TAU * ic.x + 1.2);
	vec3 mid = vec3(0.0, 0.95, 0.0);
	v = mid + rot_x(v - mid, rock);
	v.y += gal * 0.06 * sin(TAU * ic.x * 2.0);
	n = rot_x(n, rock);
	VERTEX = v;
	NORMAL = normalize(n);
	v_world = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	v_cloud = cloud_shade_at(v_world);
}

void fragment() {
	vec3 p = v_rest;
	vec3 rn = normalize(v_rest_n);
	float under = smoothstep(-0.25, -0.75, rn.y) * step(0.55, p.y) * step(v_col.r, 0.01);
	// coat: red body, darker greyer neck and a dark dorsal line, buff belly, cream rump
	vec3 col = coat;
	float neckm = smoothstep(-0.5, -0.8, p.z) * step(v_col.r, 0.01);
	col = mix(col, coat_dark * 1.15, neckm * 0.75);
	col = mix(col, coat_dark, smoothstep(0.6, 0.95, rn.y) * smoothstep(1.02, 1.12, p.y) * 0.5);
	col = mix(col, belly, under * 0.85);
	// inner legs pale, legs grey-brown below the knee, black hooves
	float legm = step(0.01, v_col.r);
	col = mix(col, coat_dark * 0.95, legm * v_col.g);
	col = mix(col, belly * 0.8, legm * smoothstep(0.3, 0.8, -rn.x * sign(p.x)) * (1.0 - v_col.g) * 0.6);
	col = mix(col, vec3(0.03, 0.025, 0.022), legm * smoothstep(0.065, 0.03, p.y));
	// rump patch round the tail, the tail's own dark top
	float rp = smoothstep(0.56, 0.70, p.z) * smoothstep(0.78, 0.9, p.y) * smoothstep(0.17, 0.08, abs(p.x));
	col = mix(col, rump, rp * (1.0 - legm));
	col = mix(col, coat_dark * 0.7, step(0.70, p.z) * smoothstep(0.98, 1.06, p.y) * smoothstep(0.05, 0.02, abs(p.x)));
	// head: darker face blaze, pale chin and lips, black nose
	float head = step(0.97, v_col.b);
	col = mix(col, coat_dark * 1.05, head * smoothstep(0.02, 0.06, rn.y + 0.1) * smoothstep(-1.17, -1.32, p.z) * 0.6);
	col = mix(col, belly * 1.05, head * smoothstep(-0.2, -0.7, rn.y) * smoothstep(-1.22, -1.37, p.z));
	col = mix(col, vec3(0.025, 0.02, 0.02), head * smoothstep(-1.37, -1.395, p.z) * smoothstep(1.44, 1.47, p.y));
	// ears: pale furry insides, dark rims
	if (v_col.a > 0.75) {
		col = mix(coat_dark * 1.2, belly, smoothstep(0.2, 0.7, abs(rn.z)) * 0.5);
	}
	// hair: fine strands along the body, a little coarser on the neck
	float strand = vnoise(vec3(p.x * 160.0, p.y * 38.0, p.z * 38.0));
	float clump = vnoise(p * 24.0);
	col *= mix(0.78, 1.12, strand) * mix(0.9, 1.08, clump);
	float rough = 0.78;
	float spec = 0.35;
	// stag: darker, coarser rut mane over the neck and throat
	float stm = stag * neckm * (1.0 - head);
	col = mix(col, coat_dark * 0.75 * mix(0.75, 1.2, vnoise(vec3(p.x * 50.0, p.y * 12.0, p.z * 12.0))), stm * 0.8);
	if (v_col.a > 0.15 && v_col.a < 0.35) {
		// antler: dark ridged bone (grooved lengthwise, pearled near the base), ivory polished tips
		float groove = vnoise(vec3(atan(rn.x, rn.z) * 6.0, v_along * 3.0, 0.0));
		float pearl = vnoise(p * 140.0) * smoothstep(0.5, 0.0, v_along);
		col = antler_col * mix(0.7, 1.15, groove) * mix(1.0, 0.7, pearl);
		col = mix(col, tine_tip, smoothstep(0.72, 0.97, v_along));
		rough = mix(0.62, 0.32, smoothstep(0.72, 0.97, v_along));
		spec = 0.45;
	}
	if (v_col.a > 0.4 && v_col.a < 0.6) {
		col = vec3(0.012, 0.01, 0.01);   // eye: dark and wet
		rough = 0.08;
		spec = 0.6;
	}
	// rain soaks the coat dark and glossy, less under the oak crowns
	float wet = weather_wet * (1.0 - 0.8 * shelter_at(v_world.xz));
	col *= 1.0 - 0.45 * wet;
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.35, wet);
	SPECULAR = spec;
	// hair fuzz: a soft lit rim along the silhouette
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO += coat * rim * 0.22 * (1.0 - wet);
	ALBEDO *= v_cloud;
	// light the meadow throws up into the belly, chest and the shaded flank
	float ao = mix(0.55, 1.0, smoothstep(0.1, 0.9, p.y)) * mix(1.0, 0.7, under);
	EMISSION = ALBEDO * bounce_light * mix(1.1, 0.6, clamp(rn.y, 0.0, 1.0)) * ao * bounce_gain(v_world);
	BACKLIGHT = col * (0.15 + 0.6 * step(0.75, v_col.a));
	NORMAL_MAP = normalize(vec3(0.5 + (strand - 0.5) * 0.25, 0.5 + (clump - 0.5) * 0.15, 1.0));
}
