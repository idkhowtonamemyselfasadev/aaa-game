shader_type spatial;
render_mode cull_disabled;
// Butterflies: one PlaneMesh per insect (x -1..1 across the span, z -0.6..0.6 head to tail,
// split at x = 0 where the wings hinge on the body). The wings beat in the vertex shader; the
// wing outline, veins, fringe and each species' pattern are drawn here, upper side on the
// front face, the duller underside on the back face (what you see when it rests wings-up).
// INSTANCE_CUSTOM: r = beat phase, g = rest (0 flying .. 1 settled),
//                  b = species + 0.5 * bask (wings held open in the sun), a = half span (m).
//   species 0 small tortoiseshell, 1 cabbage white, 2 common blue, 3 peacock

#include "res://shaders/meadow_wind.gdshaderinc"

varying float v_species;
varying float v_bask;

void vertex() {
	float phase = INSTANCE_CUSTOM.r;
	float rest = INSTANCE_CUSTOM.g;
	v_species = floor(INSTANCE_CUSTOM.b + 0.01);
	v_bask = clamp(fract(INSTANCE_CUSTOM.b + 0.001) * 2.0, 0.0, 1.0);
	// flight: ~9 Hz beat, a fast downstroke and a slower upstroke, wings nearly meet overhead
	float beat = sin(TIME * 56.0 + phase);
	beat = beat < 0.0 ? beat : pow(beat, 0.7);
	float fly_a = 0.35 + 1.0 * beat;
	// settled: wings closed overhead, slowly opening a little and closing; basking ones hold
	// them open flat and only now and then close
	float slow = 0.5 + 0.5 * sin(TIME * 1.3 + phase * 3.0);
	float shut = 1.42 - 0.22 * slow;
	float open = 0.08 + 0.08 * slow + 1.2 * smoothstep(0.93, 1.0, sin(TIME * 0.31 + phase));
	float rest_a = mix(shut, open, v_bask);
	float a = mix(fly_a, rest_a, rest);
	float side = sign(VERTEX.x);
	float u = abs(VERTEX.x);
	// the hindwing lags the forewing a touch: the trailing edge bends with the beat
	float lag = (VERTEX.z * 0.12) * (1.0 - rest) * cos(TIME * 56.0 + phase);
	float aa = a - lag;
	VERTEX = vec3(side * u * cos(aa), u * sin(aa), VERTEX.z) * INSTANCE_CUSTOM.a;
	NORMAL = normalize(vec3(-side * sin(aa), cos(aa), 0.0));
	// settled on a flower head: ride its sway (same wind field as flower.gdshader)
	vec3 root = MODEL_MATRIX[3].xyz;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * meadow_wind(root, 1.0, TIME) * rest;
}

float ell(vec2 p, vec2 c, vec2 r, float ang) {
	vec2 d = p - c;
	float cs = cos(ang), sn = sin(ang);
	d = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
	return length(d / r);   // < 1 inside
}

void fragment() {
	// wing space: u 0 at the body .. 1 at the tip, v -1 front .. +1 tail
	float u = abs(UV.x * 2.0 - 1.0);
	float v = UV.y * 2.0 - 1.0;
	vec2 p = vec2(u, v);
	float sp = v_species;
	// forewing: a long blade swept toward the tip; hindwing: a rounder lobe behind
	float fw = ell(p, vec2(0.48, -0.36), vec2(0.56, 0.30), -0.42);
	float hw = ell(p, vec2(0.30, 0.34), vec2(0.36, 0.50), 0.25);
	if (sp == 1.0) { fw = ell(p, vec2(0.47, -0.30), vec2(0.54, 0.36), -0.30); }
	float wing = min(fw, hw);
	// body: a furry dark thorax and abdomen on the hinge
	float body = (u < 0.07 && v > -0.62 && v < 0.78) ? 1.0 - u / 0.07 : 0.0;
	float head = length(vec2(u, v + 0.66) / vec2(0.09, 0.09));
	float mask = max(step(wing, 1.0), max(step(0.001, body), step(head, 1.0)));
	// antennae: two thin clubs reaching forward from the head
	float ant_v = -0.7 - u * 2.4;
	float ant = (u < 0.22 && abs(v - ant_v) < 0.03 && v > -1.0) ? 1.0 : 0.0;
	ALPHA = max(mask, ant);
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	bool upper = FRONT_FACING;
	vec3 col;
	// radial veins from the wing root, a darker margin, a pale fringe of scales at the edge
	float ang = atan(v + 0.05, u + 0.02);
	float vein = smoothstep(0.82, 1.0, abs(fract(ang * 3.6) * 2.0 - 1.0)) * smoothstep(0.08, 0.3, u);
	float margin = smoothstep(0.80, 0.93, wing);
	float fringe = smoothstep(0.95, 1.0, wing);
	if (sp == 0.0) {
		// small tortoiseshell: orange, black bars along the leading edge, a pale patch near
		// the tip, a black margin with a row of blue crescents
		col = vec3(0.78, 0.30, 0.05);
		float bars = 0.0;
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			bars = max(bars, 1.0 - smoothstep(0.7, 1.0, ell(p, vec2(0.22 + fi * 0.22, -0.56 + fi * 0.03), vec2(0.07, 0.12), 0.0)));
		}
		col = mix(col, vec3(0.03, 0.025, 0.02), bars);
		col = mix(col, vec3(0.86, 0.82, 0.66), 1.0 - smoothstep(0.6, 1.0, ell(p, vec2(0.80, -0.62), vec2(0.06, 0.05), 0.0)));
		col = mix(col, vec3(0.06, 0.04, 0.03), smoothstep(0.30, 0.0, u) * step(0.0, v) * 0.85);
		col = mix(col, vec3(0.05, 0.04, 0.03), margin);
		float lun = step(0.84, wing) * step(wing, 0.92) * step(0.5, fract(ang * 5.0));
		col = mix(col, vec3(0.10, 0.25, 0.65), lun * 0.8);
		if (!upper) { col = mix(vec3(0.18, 0.13, 0.09), vec3(0.42, 0.34, 0.24), smoothstep(-0.3, 0.6, fw - hw + v * 0.3)); }
	} else if (sp == 1.0) {
		// cabbage white: chalk white, a sooty tip on the forewing and one or two dark spots;
		// the underside of the hindwing is pale primrose
		col = vec3(0.86, 0.85, 0.80);
		col = mix(col, vec3(0.14, 0.14, 0.15), smoothstep(0.62, 0.78, u) * step(v, -0.25) * step(fw, 1.0) * 0.9);
		col = mix(col, vec3(0.12, 0.12, 0.13), 1.0 - smoothstep(0.6, 1.0, ell(p, vec2(0.52, -0.28), vec2(0.05, 0.05), 0.0)));
		col = mix(col, vec3(0.45, 0.45, 0.44), smoothstep(0.35, 0.0, u) * 0.4);
		if (!upper) { col = hw < fw ? vec3(0.80, 0.80, 0.56) : vec3(0.84, 0.84, 0.76); }
	} else if (sp == 2.0) {
		// common blue: violet-blue with a thin dark border and white fringe; grey-buff
		// underside peppered with black spots ringed in white and an orange rim
		col = mix(vec3(0.26, 0.40, 0.86), vec3(0.18, 0.24, 0.62), u);
		col = mix(col, vec3(0.08, 0.08, 0.12), smoothstep(0.88, 0.95, wing));
		if (!upper) {
			col = vec3(0.58, 0.56, 0.52);
			vec2 g = fract(p * vec2(6.0, 5.0)) - 0.5;
			float dot_ = 1.0 - smoothstep(0.10, 0.15, length(g));
			float ring = 1.0 - smoothstep(0.15, 0.22, length(g));
			float keep = step(0.5, fract(sin(dot(floor(p * vec2(6.0, 5.0)), vec2(12.9, 78.2))) * 437.5));
			col = mix(col, vec3(0.9), ring * keep);
			col = mix(col, vec3(0.04), dot_ * keep);
			col = mix(col, vec3(0.85, 0.42, 0.10), step(hw, fw) * step(0.80, wing) * step(wing, 0.9));
			col = mix(col, vec3(0.25, 0.42, 0.62), smoothstep(0.2, 0.0, u) * 0.6);
		}
	} else {
		// peacock: deep wine red with an eye on each wing tip, blue and yellow and black;
		// the underside is near black, bark-like
		col = vec3(0.50, 0.08, 0.06);
		float e1 = ell(p, vec2(0.74, -0.52), vec2(0.15, 0.13), 0.0);
		float e2 = ell(p, vec2(0.44, 0.52), vec2(0.17, 0.15), 0.0);
		float e = min(e1, e2);
		col = mix(col, vec3(0.86, 0.80, 0.55), 1.0 - smoothstep(0.85, 1.0, e));
		col = mix(col, vec3(0.04, 0.03, 0.05), 1.0 - smoothstep(0.62, 0.78, e));
		col = mix(col, vec3(0.20, 0.36, 0.70), 1.0 - smoothstep(0.32, 0.5, e));
		col = mix(col, vec3(0.06, 0.04, 0.04), margin);
		if (!upper) {
			float bark = fract(sin(dot(floor(p * vec2(30.0, 8.0)), vec2(41.3, 17.7))) * 921.7);
			col = vec3(0.06, 0.05, 0.045) + bark * 0.035;
		}
	}
	col *= 1.0 - vein * 0.35;
	col = mix(col, vec3(0.7, 0.68, 0.6), fringe * (upper ? 0.5 : 0.3));
	if (body > 0.0 || head < 1.0 || (ant > 0.5 && mask < 0.5)) {
		col = vec3(0.05, 0.04, 0.035) + vec3(0.06, 0.05, 0.03) * body;
	}
	ALBEDO = col;
	// wing scales: dusty and soft, a faint sheen on the blue; light glows through thin wings
	ROUGHNESS = sp == 2.0 && upper ? 0.45 : 0.7;
	SPECULAR = 0.35;
	BACKLIGHT = col * (sp == 1.0 ? 0.55 : 0.3);
}
