shader_type spatial;
// Brown hare built by hare.gd (Hare.build_mesh). Posed here from instance uniforms: a
// half-bound (the hind legs reach together, the forelegs one after the other) that stretches
// into the long flat-out gallop, sitting up on the haunches to watch, head down to feed, and
// the ears laid back at a run or flat in the form. Mesh COLOR as the fox's: r = leg (0.25 LF,
// 0.5 RF, 0.75 LH, 1 RH), g = below the knee/hock, b = neck/head bend weight, a = part
// (0 coat, 0.5 eye, 0.75 scut, 1 ear). Rest pose (crouched feeding) faces -Z, feet at y = 0.

global uniform vec3 bounce_light;
#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/bounce.gdshaderinc"

instance uniform float phase = 0.0;
instance uniform float speed = 0.0;      // m/s
instance uniform float alert = 0.0;      // 0 crouched .. 1 sat up on its haunches
instance uniform float graze = 0.0;      // 0 head up .. 1 nose in the grass
instance uniform float ears_back = 0.0;  // 0 up .. 1 flat along the back
instance uniform float crouch = 0.0;     // squatting low in its form

uniform vec3 coat : source_color = vec3(0.36, 0.25, 0.15);        // tawny agouti brown
uniform vec3 coat_dark : source_color = vec3(0.13, 0.095, 0.065);  // the black-tipped guard hairs of the back
uniform vec3 buff : source_color = vec3(0.50, 0.38, 0.24);         // the rufous-buff flanks and chest
uniform vec3 pale : source_color = vec3(0.60, 0.57, 0.50);         // belly, chin, the scut's underside: dull, never snow
uniform vec3 tip : source_color = vec3(0.03, 0.025, 0.02);         // ear tips and the scut's top

varying vec3 v_rest;
varying vec4 v_col;
varying vec3 v_rest_n;
varying vec3 v_world;
varying float v_cloud;

const vec3 HIP[4] = vec3[4](vec3(0.035, 0.17, -0.095), vec3(-0.035, 0.17, -0.095), vec3(0.055, 0.2, 0.17), vec3(-0.055, 0.2, 0.17));
// the bound: hind feet land together, forefeet one after the other
const float GAIT_OFF[4] = float[4](0.0, 0.14, 0.5, 0.53);

vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c); }
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
	float run = smoothstep(0.4, 6.0, speed);
	float gal = smoothstep(4.0, 9.0, speed);
	float ph0 = TAU * phase;
	int leg = int(round(COLOR.r * 4.0)) - 1;
	bool fore = leg == 0 || leg == 1;
	float sit = smoothstep(0.0, 1.0, alert) * (1.0 - run);
	float pitch = 0.32 * sit;                 // the front lifts onto straight forelegs (0.42 read fawn-like, too upright)
	if (leg >= 0) {
		vec3 hip = HIP[leg];
		float ph = ph0 + TAU * GAIT_OFF[leg];
		// reach forward then thrust back; flat out the hinds swing right through under the
		// chest and the forelegs stretch far forward
		float amp = mix(0.55, 1.15, gal) * run;
		float swing = amp * sin(ph) + (fore ? -0.25 : 0.2) * gal;
		float tw = smoothstep(hip.y + 0.02, hip.y - 0.07, VERTEX.y);
		if (!fore) {
			// the folded hind leg opens out as it thrusts (foot leaves the ground behind)
			float open = run * max(0.0, -sin(ph)) * mix(0.5, 1.0, gal);
			vec3 st = vec3(hip.x, 0.11, 0.12);
			float low = smoothstep(0.11, 0.05, VERTEX.y);
			v = mix(v, st + rot_x(v - st, -0.9 * open), low * step(0.07, VERTEX.z));
		} else {
			// sitting up: the forelegs stretch to hold the lifted front, and stay upright
			v.y = mix(v.y, hip.y + (v.y - hip.y) * (1.0 + 0.55 * sit), tw);
			swing -= pitch;
		}
		v = hip + rot_x(v - hip, swing * tw);
		n = rot_x(n, swing * tw);
	}
	float b = COLOR.b;
	bool ear = COLOR.a > 0.9;
	if (ear) {
		// laid back along the shoulders at a run or in the form; pricked and a little
		// forward when it sits up to watch
		vec3 er = vec3(0.0, 0.288, -0.2);
		float a = 1.25 * max(ears_back, 0.7 * run) - 0.18 * sit;
		v = er + rot_x(v - er, a);
		n = rot_x(n, a);
	}
	if (b > 0.0) {
		// the head up and level when it sits; stretched forward flat out; nose down to feed
		vec3 nk = vec3(0.0, 0.2, -0.13);
		float a = (-0.75 * graze * (1.0 - sit) - 0.9 * pitch - 0.1 * gal) * smoothstep(0.0, 0.7, b);
		v = nk + rot_x(v - nk, a);
		n = rot_x(n, a);
	}
	// sitting up: the whole body tips back about the haunch, front up
	if (!(leg >= 2)) {
		vec3 hp = vec3(0.0, 0.08, 0.18);
		v = hp + rot_x(v - hp, pitch);
		n = rot_x(n, pitch);
	}
	// in the form: pressed flat into the grass
	v.y *= 1.0 - 0.28 * crouch;
	// the bound: the back arches and stretches, the body sails between footfalls
	vec3 mid = vec3(0.0, 0.2, 0.05);
	float flex = run * 0.16 * sin(ph0 + 0.8);
	v = mid + rot_x(v - mid, flex);
	n = rot_x(n, flex);
	v.z *= 1.0 + 0.08 * gal * sin(ph0 + 0.8);
	v.y += run * mix(0.03, 0.07, gal) * max(0.0, sin(ph0 + 1.4));
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
	float scut = step(0.6, v_col.a) * step(v_col.a, 0.9);
	float ear = step(0.9, v_col.a);
	vec3 col = coat;
	// warmer rufous-buff on the flanks, the neck and chest, the back darker with black-tipped hairs
	col = mix(col, buff, smoothstep(0.4, -0.3, rn.y) * (1.0 - legm) * 0.7);
	col = mix(col, buff * 1.05, smoothstep(-0.08, -0.17, p.z) * (1.0 - head) * (1.0 - legm) * 0.6);
	col = mix(col, coat_dark * 1.6, smoothstep(0.45, 0.9, rn.y) * (1.0 - head) * (1.0 - legm) * 0.45);
	// patches where the coat lies differently
	col *= mix(0.82, 1.1, vnoise(p * 14.0 + vec3(3.1, 0.0, 7.7)));
	// the belly and the inside of the legs a dull off-white
	float under = smoothstep(-0.35, -0.75, rn.y) * (1.0 - ear) * (1.0 - head) * step(-0.12, p.z);
	col = mix(col, pale, under * 0.85);
	// face: a pale ring round the eye, pale chin and lips, whisker-pad buff, dark nose leather
	float eye_ring = smoothstep(0.024, 0.016, length(vec2(abs(p.x) - 0.034, p.y - 0.272) * vec2(1.0, 1.2) + vec2(0.0, 0.0)) + abs(p.z + 0.228) * 0.8);
	col = mix(col, pale * 0.95, head * eye_ring * 0.7);
	col = mix(col, pale, head * smoothstep(-0.25, -0.7, rn.y) * smoothstep(-0.24, -0.29, p.z));
	col = mix(col, vec3(0.16, 0.10, 0.08), head * smoothstep(-0.303, -0.31, p.z) * step(-0.2, rn.y));
	// the legs a paler, sandier brown down to the feet
	col = mix(col, mix(buff, pale, 0.35), legm * smoothstep(0.12, 0.03, p.y) * 0.7);
	// ears: buff-grey backs, paler furred insides, the last third black
	if (ear > 0.5) {
		float back = smoothstep(-0.3, 0.3, rn.z);
		col = mix(mix(buff, pale, 0.5) * 0.7, mix(coat, pale, 0.3) * 0.9, back);
		col = mix(col, tip, smoothstep(0.365, 0.375, p.y));
	}
	// the scut: black on top, white beneath
	if (scut > 0.5) {
		col = mix(pale * 1.05, tip * 1.3, smoothstep(-0.2, 0.35, rn.y - rn.z * 0.4));
	}
	// guard hairs and underfur: agouti banding reads as a fine pepper of dark and light tips
	float strand = vnoise(vec3(p.x * 320.0, p.y * 80.0, p.z * 80.0));
	float clump = vnoise(p * 60.0);
	vec3 fq = legm > 0.5 ? vec3(p.x * 110.0, p.y * 18.0, p.z * 110.0) : vec3(p.x * 100.0, p.y * 100.0, p.z * 16.0);
	float flow = vnoise(fq + vec3(5.3, 1.7, 0.0));
	float tuft = vnoise(fq * vec3(2.3, 2.3, 1.4) + vec3(0.0, 9.1, 2.2));
	col *= mix(0.76, 1.12, strand) * mix(0.88, 1.08, clump) * mix(0.74, 1.12, flow * 0.6 + tuft * 0.4);
	float pepper = vnoise(p * 230.0);
	col = mix(col, coat_dark, smoothstep(0.62, 0.85, pepper) * 0.5 * (1.0 - legm) * (1.0 - ear) * (1.0 - scut) * (1.0 - under));
	col = mix(col, buff * 1.2, smoothstep(0.78, 0.95, vnoise(p * 210.0 + 4.0)) * 0.25 * (1.0 - legm) * (1.0 - ear));
	float lum = dot(col, vec3(0.3, 0.55, 0.15));
	col = mix(col, vec3(lum), 0.1);
	float rough = 0.82;
	float spec = 0.3;
	if (v_col.a > 0.4 && v_col.a < 0.6) {
		// the hare's big golden-amber eye with a dark pupil toward the front, wet
		vec3 e = normalize(p - vec3(sign(p.x) * 0.034, 0.272, -0.228));
		float pupil = smoothstep(0.75, 0.88, dot(e, normalize(vec3(sign(p.x) * 0.75, 0.05, -0.65))));
		col = mix(vec3(0.24, 0.13, 0.03), vec3(0.01, 0.008, 0.006), pupil);
		rough = 0.05;
		spec = 0.7;
	}
	float wet = weather_wet * (1.0 - 0.8 * shelter_at(v_world.xz));
	col *= 1.0 - 0.45 * wet;
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.35, wet);
	SPECULAR = spec;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO += mix(buff, pale, 0.4) * rim * 0.14 * (1.0 - wet) * (1.0 - legm * 0.7);   // the soft halo of the guard hairs
	ALBEDO *= v_cloud;
	float ao = mix(0.55, 1.0, smoothstep(0.02, 0.18, p.y));
	EMISSION = ALBEDO * bounce_light * mix(1.1, 0.6, clamp(rn.y, 0.0, 1.0)) * ao * bounce_gain(v_world);
	BACKLIGHT = col * (0.08 + 0.25 * ear);   // 0.7 made the ears a pale glowing blob
	NORMAL_MAP = normalize(vec3(0.5 + (strand - 0.5) * 0.25 + (flow - 0.5) * 0.3, 0.5 + (clump - 0.5) * 0.15 + (tuft - 0.5) * 0.2, 1.0));
}
