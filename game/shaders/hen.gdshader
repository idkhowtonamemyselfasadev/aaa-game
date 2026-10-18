shader_type spatial;
// A laying hen built by hens.gd (Hens.build_mesh), posed here from instance uniforms: a
// quick short-stepped walk with the head held still and then thrust forward each step, a
// run with the wings half out and flapping, the rake of a scratching foot, a peck (the body
// tips forward and the neck bows until the beak taps the turf), and the night settle (legs
// folded under, body down on the ground, feathers puffed, head sunk). Mesh COLOR: r leg
// (0.25 left, 0.5 right), g below the hock, b neck/head weight, a part (0 body, 0.2 wing,
// 0.35 tail, 0.5 eye, 0.65 beak, 0.8 comb/wattles, 1 toes). Rest pose faces -Z, feet at y 0.

global uniform vec3 bounce_light;
#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/bounce.gdshaderinc"

instance uniform float phase = 0.0;
instance uniform float speed = 0.0;      // m/s
instance uniform float peck = 0.0;       // 0 head up .. 1 beak on the turf
instance uniform float sit = 0.0;        // 0 standing .. 1 settled for the night
instance uniform float wing = 0.0;       // 0 folded .. 1 half out and flapping (running)
instance uniform float scratch = 0.0;    // 0..1 left foot rakes back, 1..2 the right
instance uniform float bob = 0.0;        // 0..1 head lag through a step
instance uniform float head_yaw = 0.0;   // rad, + to its left
instance uniform float fluff = 0.0;      // feathers puffed against the cold and wet

uniform vec3 body : source_color = vec3(0.36, 0.17, 0.07);
uniform vec3 dark : source_color = vec3(0.13, 0.06, 0.03);
uniform vec3 hackle : source_color = vec3(0.46, 0.25, 0.10);
uniform float pattern = 0.0;   // 0 brown, 1 black, 2 cuckoo (barred), 3 buff, 4 partridge (laced)

varying vec3 v_rest;
varying vec4 v_col;
varying vec3 v_rest_n;
varying vec3 v_world;
varying float v_cloud;

vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c); }
vec3 rot_y(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c); }
vec3 rot_z(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x * c - p.y * s, p.x * s + p.y * c, p.z); }
float hash3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
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
	float spd = speed;
	float run = smoothstep(0.9, 2.2, spd);
	float s = smoothstep(0.0, 1.0, sit);
	int leg = int(round(COLOR.r * 4.0)) - 1;
	float part = COLOR.a;
	bool is_leg = leg >= 0;
	if (is_leg) {
		vec3 hip = vec3(leg == 0 ? -0.045 : 0.045, 0.19, 0.01);
		float ph = TAU * (phase + (leg == 0 ? 0.0 : 0.5));
		float amp = mix(clamp(spd / 0.4, 0.0, 1.0) * 0.38, 0.62, run);
		float swing = amp * sin(ph);
		float lift = max(0.0, cos(ph)) * clamp(spd / 0.3, 0.0, 1.0) * mix(0.025, 0.05, run);
		// the scratch: the foot reaches forward and up, then drags back hard through the turf
		float sc = scratch - (leg == 0 ? 0.0 : 1.0);
		if (scratch > 0.0 && sc >= 0.0 && sc < 1.0) {
			swing = sc < 0.4 ? mix(0.0, 0.5, sc / 0.4) : mix(0.5, -0.6, (sc - 0.4) / 0.6);
			lift = sc < 0.4 ? 0.035 * sc / 0.4 : 0.035 * (1.0 - smoothstep(0.4, 0.55, sc));
		}
		float w = smoothstep(hip.y + 0.01, hip.y - 0.06, VERTEX.y);
		v = hip + rot_x(v - hip, swing * w);
		n = rot_x(n, swing * w);
		v.y += lift * smoothstep(0.12, 0.0, VERTEX.y);
		// settled: the legs fold up under the body
		v.y = mix(v.y, v.y * 0.18 + 0.01, s);
		v.x = mix(v.x, v.x * 0.7, s);
	}
	float b = COLOR.b;
	bool wing_part = part > 0.15 && part < 0.25;
	// puffed up: the body feathers stand off the skin
	if (!is_leg && b < 0.5 && part < 0.45) {
		vec3 c = vec3(0.0, 0.25, 0.0);
		v = c + (v - c) * (1.0 + 0.08 * fluff + 0.04 * s);
	}
	// the wings, half out from the flanks and beating as it runs
	if (wing_part) {
		float side = sign(VERTEX.x);
		vec3 pv = vec3(0.085 * side, 0.31, 0.0);
		float a = wing * (0.55 + 0.5 * sin(TAU * phase * 3.0)) * side;
		v = pv + rot_z(v - pv, a);
		n = rot_z(n, a);
		v = pv + rot_x(v - pv, -0.25 * wing);
		n = rot_x(n, -0.25 * wing);
	}
	if (b > 0.0) {
		// the head held still in space through a step, then thrust forward
		float bw = smoothstep(0.3, 0.9, b);
		v.z += 0.032 * bob * bw * (1.0 - run);
		// head turned in its sharp jerks
		vec3 nk = vec3(0.0, 0.3, -0.15);
		float yw = head_yaw * pow(b, 1.5);
		v = nk + rot_y(v - nk, yw);
		n = rot_y(n, yw);
		// pecking: the neck bows forward-down from the crop
		vec3 nb = vec3(0.0, 0.28, -0.13);
		float g = -1.3 * peck * smoothstep(0.0, 0.7, b);
		// running: neck stretched forward and low
		g -= 0.45 * run * smoothstep(0.0, 0.7, b);
		// settled: head drawn down into the shoulders
		v = mix(v, nb + (v - nb) * vec3(1.0, 0.55, 0.7), s * smoothstep(0.0, 0.8, b));
		v = nb + rot_x(v - nb, g);
		n = rot_x(n, g);
	}
	if (!is_leg) {
		// the whole body tips forward over the feet to peck, and leans into a run
		vec3 hp = vec3(0.0, 0.19, 0.02);
		float tip = -0.65 * peck - 0.28 * run;
		v = hp + rot_x(v - hp, tip);
		n = rot_x(n, tip);
		// a waddle from foot to foot at a walk
		float roll = 0.05 * sin(TAU * phase) * clamp(spd / 0.4, 0.0, 1.0) * (1.0 - run);
		v = vec3(0.0, 0.0, 0.0) + rot_z(v, roll);
		n = rot_z(n, roll);
		// settled down onto the turf
		v.y -= 0.135 * s;
	}
	VERTEX = v;
	NORMAL = normalize(n);
	v_world = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	v_cloud = cloud_shade_at(v_world);
}

void fragment() {
	vec3 p = v_rest;
	vec3 rn = normalize(v_rest_n);
	float part = v_col.a;
	float legm = step(0.01, v_col.r) * step(p.y, 0.15);
	float b = v_col.b;
	bool feather = part < 0.45 && legm < 0.5;
	vec3 col = body;
	float rough = 0.75;
	float spec = 0.32;
	float bump = 0.0;
	if (feather) {
		// feathers: overlapping scales laid back along the body in staggered rows, each
		// rounded at its tip; the patterns are drawn per feather
		float wingm = step(0.15, part) * step(part, 0.25);
		float tailm = step(0.3, part) * step(part, 0.4);
		float sz = mix(mix(62.0, 40.0, wingm), 30.0, tailm) * mix(1.0, 1.5, smoothstep(0.5, 0.95, b));
		vec2 q = vec2(p.z * sz, (p.y + abs(p.x) * 0.55) * sz * 1.25);
		float row = floor(q.y);
		q.x += row * 0.5 + hash2(vec2(row, 3.0)) * 0.3;
		vec2 cell = floor(q);
		vec2 f = fract(q);
		float rnd = hash2(cell + row);
		// distance from the feather's base (the forward edge, toward -Z, is the tip in view)
		float d = length((f - vec2(0.95, 0.5)) * vec2(0.9, 1.0));
		float rim = smoothstep(0.62, 0.92, d);
		float shaft = smoothstep(0.06, 0.0, abs(f.y - 0.5)) * 0.5;
		bump = rim;
		vec3 base = body * mix(0.85, 1.12, rnd);
		if (pattern < 0.5) {
			// brown: a warm red-brown, darker wing bows and a dark tail with chestnut edges
			col = base * mix(1.0, 0.82, shaft);
			col = mix(col, dark, wingm * smoothstep(0.1, 0.0, p.y - 0.25) * 0.6);
		} else if (pattern < 1.5) {
			// black: near black with a green-violet sheen on the hackles and the tail
			col = base;
			spec = 0.55;
			rough = 0.42;
		} else if (pattern < 2.5) {
			// cuckoo: each feather barred across in soft grey and charcoal
			float bars = smoothstep(0.35, 0.65, sin(f.x * 12.0 + rnd * 2.0) * 0.5 + 0.5);
			col = mix(base, dark, bars * 0.75);
		} else if (pattern < 3.5) {
			// buff: golden, the feather edges a shade paler
			col = mix(base, base * 1.18, rim * 0.6);
		} else {
			// partridge: each feather pencilled with concentric dark rings
			float rings = smoothstep(0.4, 0.6, sin(d * 26.0) * 0.5 + 0.5);
			col = mix(base, dark, rings * 0.55 + rim * 0.35);
		}
		// hackles: long narrow neck feathers, brighter, falling over the shoulders in streaks
		float hk = smoothstep(0.35, 0.75, b) * (1.0 - step(0.98, b) * smoothstep(-0.175, -0.19, p.z));
		float streak = vnoise(vec3(p.x * 220.0, p.y * 30.0, p.z * 220.0));
		vec3 hc = hackle * mix(0.75, 1.15, streak);
		if (pattern > 3.5) {
			hc = mix(hc, dark, smoothstep(0.55, 0.75, streak) * 0.7);
		}
		col = mix(col, hc, hk);
		// the tail: darker in most breeds
		col = mix(col, dark * mix(0.8, 1.2, rnd), tailm * (pattern < 2.5 && pattern > 1.5 ? 0.4 : 0.7));
		// paler fluff under the belly and round the vent
		float under = smoothstep(-0.25, -0.75, rn.y) * (1.0 - hk) * (1.0 - wingm);
		col = mix(col, mix(col, vec3(0.62, 0.56, 0.46), pattern < 1.5 ? 0.12 : 0.45), under);
		col *= 1.0 - rim * 0.28;
		col *= mix(0.9, 1.06, vnoise(p * 140.0));
		// face: bare red skin round the eye and down to the wattles, a pale earlobe
		float face = step(0.98, b) * smoothstep(-0.168, -0.182, p.z) * smoothstep(0.012, 0.022, abs(p.x)) * step(p.y, 0.43);
		col = mix(col, vec3(0.45, 0.07, 0.05), face * 0.9);
		float lobe = step(0.98, b) * smoothstep(0.006, 0.0, length(vec2(p.z + 0.163, p.y - 0.403))) * step(0.02, abs(p.x));
		col = mix(col, vec3(0.62, 0.5, 0.42), lobe);
	} else if (part > 0.45 && part < 0.55) {
		// eye: a bright orange iris round a black pupil, wet
		float out_ = abs(rn.x);
		col = mix(vec3(0.55, 0.26, 0.04), vec3(0.01), smoothstep(0.86, 0.92, out_));
		col = mix(col, vec3(0.05, 0.03, 0.02), smoothstep(0.55, 0.4, out_));
		rough = 0.08;
		spec = 0.7;
	} else if (part > 0.6 && part < 0.7) {
		// beak: horn, darker along the ridge and at the base
		col = mix(vec3(0.58, 0.47, 0.27), vec3(0.32, 0.26, 0.16), smoothstep(0.5, 0.95, rn.y));
		col = pattern > 0.5 && pattern < 1.5 ? col * 0.45 : col;
		rough = 0.38;
		spec = 0.45;
	} else if (part > 0.75 && part < 0.85) {
		// comb and wattles: waxy red flesh
		col = vec3(0.5, 0.055, 0.045) * mix(0.8, 1.1, vnoise(p * 300.0));
		rough = 0.45;
		spec = 0.4;
	} else {
		// shanks and toes: scaled yellow skin (slate grey on the black hen)
		vec3 sk = pattern > 0.5 && pattern < 1.5 ? vec3(0.13, 0.13, 0.13) : vec3(0.58, 0.45, 0.16);
		float scales = smoothstep(0.3, 0.7, sin(p.y * 900.0) * 0.5 + 0.5);
		col = sk * mix(0.75, 1.0, scales);
		col = mix(col, sk * 0.5, smoothstep(0.02, 0.0, p.y) * 0.5);   // toes muddy
		rough = 0.5;
		spec = 0.35;
	}
	float wet = weather_wet * (1.0 - 0.8 * shelter_at(v_world.xz));
	col *= 1.0 - 0.35 * wet;
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.35, wet);
	SPECULAR = spec;
	float rim_l = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	if (feather) {
		ALBEDO += col * rim_l * 0.25 * (1.0 - wet);
	}
	ALBEDO *= v_cloud;
	float ao = mix(0.5, 1.0, smoothstep(0.08, 0.3, p.y)) * mix(1.0, 0.7, sit);
	EMISSION = ALBEDO * bounce_light * mix(1.1, 0.6, clamp(rn.y, 0.0, 1.0)) * ao * bounce_gain(v_world);
	// light through the thin comb and wattles
	BACKLIGHT = part > 0.75 && part < 0.85 ? vec3(0.6, 0.08, 0.05) : col * 0.06;
	NORMAL_MAP = normalize(vec3(0.5, 0.5 + (0.5 - bump) * 0.35, 1.0));
}
