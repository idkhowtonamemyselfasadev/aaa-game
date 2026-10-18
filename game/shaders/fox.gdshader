shader_type spatial;
// Red fox built by fox.gd (Fox.build_mesh). Posed here from instance uniforms: a diagonal
// trot that stretches into a bounding run, and a sit (haunches down, forelegs straight,
// head held level, brush curled round the haunch to the forepaws). Mesh COLOR as the deer's: r = leg
// (0.25 LF, 0.5 RF, 0.75 LH, 1 RH), g = below the wrist/hock, b = neck/head bend weight,
// a = part (0 coat, 0.5 eye, 0.75 brush, 1 ear). Rest pose faces -Z, paws at y = 0.

global uniform vec3 bounce_light;
#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/bounce.gdshaderinc"

instance uniform float phase = 0.0;
instance uniform float speed = 0.0;      // m/s
instance uniform float sit = 0.0;        // 0 standing .. 1 sat
instance uniform float head_yaw = 0.0;   // rad, + to its left
instance uniform float graze = 0.0;      // 0 head up .. 1 neck bowed, nose to the ground
instance uniform float eyeshine = 0.0;   // the fire's light thrown back by the tapetum

uniform vec3 coat : source_color = vec3(0.45, 0.215, 0.095);      // fox red, toward ginger-brown (pure red glowed flat under the fire)
uniform vec3 coat_dark : source_color = vec3(0.30, 0.14, 0.065);   // the saddle, the brush's dark band
uniform vec3 pale : source_color = vec3(0.52, 0.48, 0.41);         // throat strip, lips, cheeks: a dull cream, never snow
uniform vec3 stocking : source_color = vec3(0.045, 0.035, 0.03);   // black legs and ear backs

varying vec3 v_rest;
varying vec4 v_col;
varying vec3 v_rest_n;
varying vec3 v_world;
varying float v_along;
varying float v_cloud;

const vec3 HIP[4] = vec3[4](vec3(0.05, 0.38, -0.165), vec3(-0.05, 0.38, -0.165), vec3(0.055, 0.37, 0.22), vec3(-0.055, 0.37, 0.22));
const vec3 KNEE[4] = vec3[4](vec3(0.05, 0.12, -0.19), vec3(-0.05, 0.12, -0.19), vec3(0.055, 0.125, 0.268), vec3(-0.055, 0.125, 0.268));
// the brush's rest keys from Fox.build_mesh (z, y) and arc fraction at each, and the curve
// (x, z) its sat curl lies along on the ground, round the right haunch to the forepaws
const float TAIL_Z[7] = float[7](0.30, 0.345, 0.429, 0.541, 0.653, 0.731, 0.754);
const float TAIL_Y[7] = float[7](0.385, 0.38, 0.346, 0.29, 0.234, 0.201, 0.192);
const float TAIL_A[7] = float[7](0.0, 0.091, 0.274, 0.527, 0.780, 0.950, 1.0);
const vec2 CURL[4] = vec2[4](vec2(0.0, 0.18), vec2(0.2, 0.21), vec2(0.215, -0.09), vec2(0.09, -0.18));
// trot: diagonal pairs (LF with RH, RF with LH); run: a rotary gallop
const float TROT_OFF[4] = float[4](0.0, 0.5, 0.5, 0.0);
const float RUN_OFF[4] = float[4](0.12, 0.0, 0.58, 0.46);

vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c); }
vec3 rot_y(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c); }
float hash3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	v_rest = VERTEX;
	v_rest_n = NORMAL;
	v_col = COLOR;
	v_along = UV.y;
	float spd = speed;
	float run = smoothstep(3.2, 5.5, spd);
	float s = smoothstep(0.0, 1.0, sit);
	float pitch = 0.74 * s;                    // the body tips back onto its haunches
	int leg = int(round(COLOR.r * 4.0)) - 1;
	bool fore = leg == 0 || leg == 1;
	if (leg >= 0) {
		vec3 hip = HIP[leg];
		vec3 knee = KNEE[leg];
		float hind = fore ? 0.0 : 1.0;
		float ph = TAU * (phase + mix(TROT_OFF[leg], RUN_OFF[leg], run));
		float amp = mix(clamp(spd / 1.6, 0.0, 1.0) * 0.42, 0.75, run);
		float swing = amp * sin(ph) + run * mix(0.12, -0.15, hind);
		float fold = mix(1.0, 1.6, run) * clamp(spd / 0.8, 0.0, 1.0) * max(0.0, cos(ph));
		// sitting: the hind thigh comes forward flat along the ground, the hock folds back
		// and the long hind foot lies on the turf; the forelegs stand straight
		if (!fore) {
			swing = mix(swing, 1.57 - pitch, s);
			fold = mix(fold, 1.75, s);
		}
		vec3 p = v - knee;
		v = mix(v, knee + rot_x(p, -fold), COLOR.g);
		n = mix(n, rot_x(n, -fold), COLOR.g);
		float tw = smoothstep(hip.y + 0.02, hip.y - 0.12, VERTEX.y);
		v = hip + rot_x(v - hip, swing * tw);
		n = rot_x(n, swing * tw);
	}
	// the brush: streamed out level at a run, a slow sway at the trot (sat: see below)
	bool brush = COLOR.a > 0.6 && COLOR.a < 0.9;
	if (brush) {
		vec3 root = vec3(0.0, 0.38, 0.31);
		float along = clamp((VERTEX.z - 0.31) / 0.45, 0.0, 1.0);
		float lift = -0.35 * run - 0.12 * clamp(spd, 0.0, 1.0);
		float sway = 0.12 * sin(TAU * phase) * clamp(spd, 0.0, 1.0) * (1.0 - run);
		v = root + rot_x(v - root, lift);
		n = rot_x(n, lift);
		v = root + rot_y(v - root, sway * along);
		n = rot_y(n, sway * along);
	}
	float b = COLOR.b;
	if (b > 0.0) {
		// held level while it sits; a little low and forward at the trot
		vec3 nb = vec3(0.0, 0.40, -0.25);
		float a = (-pitch * 0.85 + 0.12 * clamp(spd, 0.0, 1.0) * (1.0 - run)) * smoothstep(0.0, 0.6, b);
		v = nb + rot_x(v - nb, a);
		n = rot_x(n, a);
		float yw = head_yaw * pow(b, 0.7);
		v = nb + rot_y(v - nb, yw);
		n = rot_y(n, yw);
		// eating off the floor: the neck bows down from the withers, nose to the ground
		vec3 wi = vec3(0.0, 0.38, -0.17);
		float g = -1.3 * graze * smoothstep(0.0, 0.6, b);
		v = wi + rot_x(v - wi, g);
		n = rot_x(n, g);
	}
	// the body pitch about the shoulders, leaving the forelegs standing
	if (!fore) {
		vec3 sh = vec3(0.0, 0.38, -0.165);
		v = sh + rot_x(v - sh, pitch);
		n = rot_x(n, pitch);
	}
	// sat, the brush lies on the ground out of the rump and curls round the haunch, its tip
	// beside the forepaws: each ring is carried from its rest frame onto a curve on the turf
	if (brush && s > 0.0) {
		float t = clamp(UV.y, 0.0, 1.0) * 6.0;
		int k = min(int(t), 5);
		float f = t - float(k);
		vec3 k0 = vec3(0.0, TAIL_Y[k], TAIL_Z[k]);
		vec3 k1 = vec3(0.0, TAIL_Y[k + 1], TAIL_Z[k + 1]);
		vec3 tr = normalize(k1 - k0);
		vec3 ur = cross(tr, vec3(1.0, 0.0, 0.0));
		vec3 d = VERTEX - mix(k0, k1, f);
		vec3 dn = NORMAL;
		float a = mix(TAIL_A[k], TAIL_A[k + 1], f);
		float u = 1.0 - a;
		vec2 c = u * u * u * CURL[0] + 3.0 * u * u * a * CURL[1] + 3.0 * u * a * a * CURL[2] + a * a * a * CURL[3];
		vec2 dc = 3.0 * u * u * (CURL[1] - CURL[0]) + 6.0 * u * a * (CURL[2] - CURL[1]) + 3.0 * a * a * (CURL[3] - CURL[2]);
		vec3 ts = normalize(vec3(dc.x, 0.0, dc.y));
		vec3 us = vec3(0.0, 1.0, 0.0);
		vec3 xs = cross(us, ts);
		// a little flattened where it lies, the underside on the ground
		float squash = 0.82;
		vec3 vs = vec3(c.x, mix(0.062, 0.05, a), c.y) + xs * d.x + us * dot(d, ur) * squash + ts * dot(d, tr);
		vec3 ns = xs * dn.x + us * dot(dn, ur) / squash + ts * dot(dn, tr);
		v = mix(v, vs, s);
		n = mix(n, normalize(ns), s);
	}
	// the run: the back flexes and the body bounds
	float rock = run * 0.08 * sin(TAU * phase + 1.2);
	vec3 mid = vec3(0.0, 0.37, 0.0);
	v = mid + rot_x(v - mid, rock);
	v.y += run * 0.035 * sin(TAU * phase * 2.0) + 0.012 * clamp(spd, 0.0, 1.5) * (1.0 - run) * sin(TAU * phase * 2.0);
	n = rot_x(n, rock);
	VERTEX = v;
	NORMAL = normalize(n);
	v_world = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	v_cloud = cloud_shade_at(v_world);
}

void fragment() {
	vec3 p = v_rest;
	vec3 rn = normalize(v_rest_n);
	float legm = step(0.01, v_col.r);
	float head = step(0.97, v_col.b);
	float tail = step(0.6, v_col.a) * step(v_col.a, 0.9);
	float ear = step(0.9, v_col.a);
	vec3 col = coat;
	// a darker grizzled saddle along the back, the flanks warmer
	col = mix(col, coat_dark, smoothstep(0.4, 0.9, rn.y) * (1.0 - head) * (1.0 - legm) * 0.7);
	// broad patches of lighter and darker fur where the coat lies differently, so it is not one flat value
	col *= mix(0.8, 1.1, vnoise(p * 9.0 + vec3(3.1, 0.0, 7.7))) * (1.0 - legm * 0.1);
	// a buff-grey belly (hidden when it sits) and only a narrow cream strip from the throat
	// down to the brisket: from the front a sitting fox is red with a pale blaze, not a white bib
	float under = smoothstep(-0.2, -0.6, rn.y) * (1.0 - legm) * (1.0 - tail) * (1.0 - ear) * (1.0 - head);
	col = mix(col, mix(coat, pale, 0.3) * 0.75, under * 0.8);   // red-buff, so a sat fox shows no grey panel
	float chest = smoothstep(-0.16, -0.26, p.z) * smoothstep(-0.05, -0.5, rn.y + rn.z * 0.6)
		* smoothstep(0.042, 0.022, abs(p.x)) * (1.0 - legm) * (1.0 - head);
	col = mix(col, pale, chest * 0.9);
	// face: white cheeks and lips under a red mask, dark streak from the eye, black nose
	col = mix(col, pale, head * smoothstep(-0.15, -0.5, rn.y) * smoothstep(-0.37, -0.43, p.z));
	// the muzzle's sides darken toward the black lips and nose; a dark tear streak from the eye
	col = mix(col, coat_dark * 0.55, head * smoothstep(-0.44, -0.52, p.z) * smoothstep(0.3, 0.8, abs(rn.x)) * step(-0.25, rn.y) * 0.8);
	col = mix(col, coat_dark * 0.45, head * smoothstep(0.012, 0.004, abs(abs(p.x) - 0.026)) * smoothstep(-0.405, -0.425, p.z) * smoothstep(-0.48, -0.45, p.z) * step(-0.1, rn.y));
	col = mix(col, vec3(0.02, 0.016, 0.014), head * smoothstep(-0.54, -0.55, p.z));
	// black stockings up the legs, a dark front line on the forelegs
	col = mix(col, stocking, legm * smoothstep(0.24, 0.13, p.y));
	col = mix(col, coat_dark * 0.5, legm * smoothstep(0.32, 0.22, p.y) * step(p.y, 0.32) * 0.6);
	// ears: black backs, pale furred insides
	if (ear > 0.5) {
		float back = smoothstep(-0.2, 0.3, rn.z);
		col = mix(mix(coat, pale, 0.4) * 0.55, stocking * 1.4, back);   // the inner fur shadowed buff, not white
		col = mix(col, stocking, smoothstep(0.64, 0.66, p.y));
	}
	// brush: red with a dark grizzled band and a white tip
	if (tail > 0.5) {
		col = mix(coat * 0.95, coat_dark * 0.8, smoothstep(0.35, 0.6, v_along) * smoothstep(0.92, 0.75, v_along) * 0.7);
		col = mix(col, pale * 1.1, smoothstep(0.82, 0.88, v_along));
	}
	// guard hairs and underfur
	float strand = vnoise(vec3(p.x * 300.0, p.y * 70.0, p.z * 70.0));
	float clump = vnoise(p * 55.0);
	col *= mix(0.78, 1.12, strand) * mix(0.88, 1.08, clump);
	// grizzle: pale-tipped guard hairs on the back and brush
	col = mix(col, pale, smoothstep(0.75, 0.95, vnoise(p * 190.0)) * 0.22 * (1.0 - legm) * (1.0 - head));
	float rough = 0.8;
	float spec = 0.3;
	if (v_col.a > 0.4 && v_col.a < 0.6) {
		col = vec3(0.06, 0.035, 0.012);   // amber-brown iris, dark and wet
		rough = 0.06;
		spec = 0.65;
	}
	float wet = weather_wet * (1.0 - 0.8 * shelter_at(v_world.xz));
	col *= 1.0 - 0.45 * wet;
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.35, wet);
	SPECULAR = spec;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO += coat * rim * 0.25 * (1.0 - wet) * (1.0 - legm * 0.7);
	ALBEDO *= v_cloud;
	float ao = mix(0.55, 1.0, smoothstep(0.05, 0.35, p.y));
	EMISSION = ALBEDO * bounce_light * mix(1.1, 0.6, clamp(rn.y, 0.0, 1.0)) * ao * bounce_gain(v_world);
	// eyeshine: the tapetum throws the firelight back toward the fire (and a lens near it)
	if (v_col.a > 0.4 && v_col.a < 0.6) {
		EMISSION += vec3(0.85, 0.9, 0.45) * eyeshine * 2.4 * pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	}
	BACKLIGHT = col * (0.08 + 0.67 * ear);
	NORMAL_MAP = normalize(vec3(0.5 + (strand - 0.5) * 0.25, 0.5 + (clump - 0.5) * 0.15, 1.0));
}
