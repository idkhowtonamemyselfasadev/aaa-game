shader_type spatial;
render_mode cull_disabled;
// Moths round the lantern (moths.gd): one PlaneMesh per moth (x -1..1 across the span, z -0.6
// head .. 0.6 tail, hinged at x = 0). Wings beat fast in flight; settled, they fold back
// into a flat delta over the body. Wing outline, scales and markings are drawn here.
// INSTANCE_CUSTOM: r = beat phase, g = rest (0 flying .. 1 settled), b = kind, a = half span (m).
//   kind 0 heart and dart (grey-brown, dark marks), 1 white ermine (ivory, black dots),
//   2 large yellow underwing (brown forewing, ochre hindwing with a black band)

uniform vec3 lamp_pos;          // the candle flame (world)
uniform float lamp_lit = 0.0;   // 0 out .. 1 burning

varying float v_kind;
varying vec3 v_world;

void vertex() {
	float phase = INSTANCE_CUSTOM.r;
	float rest = INSTANCE_CUSTOM.g;
	v_kind = floor(INSTANCE_CUSTOM.b + 0.01);
	// flight: a blurry fast beat (the real ~40 Hz aliases on screen, ~20 reads as a buzz)
	float beat = sin(TIME * 125.0 + phase);
	float a = mix(0.25 + 0.95 * beat, 0.06, rest);
	float side = sign(VERTEX.x);
	float u = abs(VERTEX.x);
	// settled: the wings sweep back round the root into a flat delta over the abdomen
	float sw = rest * 1.05;
	vec2 xz = vec2(u, VERTEX.z + 0.05);
	xz = vec2(xz.x * cos(sw) - xz.y * sin(sw), xz.x * sin(sw) + xz.y * cos(sw));
	u = xz.x;
	float z = xz.y - 0.05;
	VERTEX = vec3(side * u * cos(a), u * sin(a), z) * INSTANCE_CUSTOM.a;
	NORMAL = normalize(vec3(-side * sin(a), cos(a), 0.0));
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ell(vec2 p, vec2 c, vec2 r, float ang) {
	vec2 d = p - c;
	float cs = cos(ang), sn = sin(ang);
	d = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
	return length(d / r);   // < 1 inside
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5);
}

void fragment() {
	// wing space: u 0 at the body .. 1 at the tip, v -1 front .. +1 tail
	float u = abs(UV.x * 2.0 - 1.0);
	float v = UV.y * 2.0 - 1.0;
	vec2 p = vec2(u, v);
	// moth wings: a long narrow forewing with a squared tip, a small fan of hindwing behind
	float fw = ell(p, vec2(0.50, -0.20), vec2(0.54, 0.26), -0.30);
	float hw = ell(p, vec2(0.30, 0.30), vec2(0.34, 0.36), 0.35);
	float wing = min(fw, hw);
	// stout furry body: thorax and a tapering abdomen, a broad head
	float body = (u < 0.10 - max(v - 0.2, 0.0) * 0.08 && v > -0.62 && v < 0.82) ? 1.0 - u / 0.10 : 0.0;
	float head = length(vec2(u, v + 0.64) / vec2(0.11, 0.09));
	// feathery antennae swept back over the forewing edge
	float ant_v = -0.66 - u * 1.2 + u * u * 2.6;
	float ant = (u < 0.34 && abs(v - ant_v) < 0.028) ? 1.0 : 0.0;
	float mask = max(step(wing, 1.0), max(step(0.001, body), step(head, 1.0)));
	// a ragged fringe of scales round the edge
	float rag = h21(floor(vec2(atan(v, u) * 40.0, 0.0)));
	ALPHA = max(step(wing, 0.94 + rag * 0.07), max(step(0.001, body), max(step(head, 1.0), ant)));
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	bool fore = fw < 1.0;
	float grain = h21(floor(p * vec2(60.0, 40.0)));      // scale speckle
	vec3 col;
	if (v_kind == 0.0) {
		// heart and dart: grey-brown forewing, a dark kidney mark and a black dart, paler costa
		col = vec3(0.34, 0.27, 0.20);
		col = mix(col, vec3(0.47, 0.40, 0.31), smoothstep(-0.30, -0.42, v - u * 0.2) * 0.7);
		col = mix(col, vec3(0.10, 0.08, 0.06), 1.0 - smoothstep(0.7, 1.0, ell(p, vec2(0.55, -0.24), vec2(0.07, 0.05), 0.0)));
		col = mix(col, vec3(0.08, 0.06, 0.05), 1.0 - smoothstep(0.6, 1.0, ell(p, vec2(0.30, -0.12), vec2(0.13, 0.025), -0.2)));
		if (!fore) { col = vec3(0.62, 0.58, 0.50); }
	} else if (v_kind == 1.0) {
		// white ermine: ivory, peppered with small black dots, a yellow-furred abdomen
		col = vec3(0.86, 0.83, 0.74);
		vec2 g = fract(p * vec2(7.0, 6.0)) - 0.5;
		float keep = step(0.55, h21(floor(p * vec2(7.0, 6.0))));
		col = mix(col, vec3(0.05), (1.0 - smoothstep(0.08, 0.13, length(g))) * keep * (fore ? 1.0 : 0.3));
	} else {
		// large yellow underwing: dull brown forewing; the hindwing flashes ochre with a black band
		col = vec3(0.30, 0.22, 0.15) * (0.85 + 0.3 * smoothstep(0.2, 0.9, u));
		col = mix(col, vec3(0.12, 0.09, 0.07), 1.0 - smoothstep(0.7, 1.0, ell(p, vec2(0.80, -0.30), vec2(0.05, 0.05), 0.0)));
		if (!fore) {
			col = vec3(0.78, 0.55, 0.10);
			col = mix(col, vec3(0.05, 0.04, 0.03), step(0.72, hw) * step(hw, 0.88));
		}
	}
	// faint wavy cross-lines and scale speckle; a paler worn fringe
	float wave = smoothstep(0.85, 1.0, abs(sin((u * 9.0 + sin(v * 9.0) * 0.4) * 3.14159)));
	col *= (1.0 - wave * 0.18 * (fore ? 1.0 : 0.0)) * (0.88 + 0.24 * grain);
	col = mix(col, col * 1.25 + 0.06, smoothstep(0.86, 0.95, wing) * 0.6);
	if (body > 0.0 || head < 1.0 || (ant > 0.5 && mask < 0.5)) {
		vec3 fur = v_kind == 1.0 ? (v > 0.15 && head > 1.0 ? vec3(0.80, 0.62, 0.20) : vec3(0.85, 0.82, 0.74)) : vec3(0.22, 0.17, 0.12);
		col = fur * (0.75 + 0.4 * grain) * (0.8 + 0.3 * body);
	}
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	// thin scaled wings let the candle through from behind
	BACKLIGHT = col * 0.55;
	// close to the flame the dusty scales catch it warmly even off the lamp's shadow rays
	float d = length(v_world - lamp_pos);
	EMISSION = col * vec3(1.0, 0.62, 0.32) * lamp_lit * 0.9 / (1.0 + d * d * 30.0);
}
