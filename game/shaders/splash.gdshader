shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, world_vertex_coords;
// A raindrop (or a footfall) hitting the ground: a crown of droplets thrown up and out from
// the impact, over a thin cup-shaped sheet that collapses in the first third of its life.
// One upright quad per particle turned about the vertical toward the camera; the particle
// age (INSTANCE_CUSTOM.y, the ParticleProcessMaterial phase) drives the whole burst, and
// the particle scale sets its size. Each splash's droplet fan is seeded by where it lands.

uniform vec3 tint : source_color = vec3(0.78, 0.8, 0.84);
uniform float brightness = 1.0;     // set by weather.gd from the light level
uniform float opacity = 0.7;
uniform float size = 0.16;          // crown width (m) at particle scale 1
uniform float near_fade = 0.35;     // fade in from (m): no blobs on the lens
uniform float far_fade = 18.0;      // gone by (m): too small to resolve further out

varying float v_fade;
varying float v_seed;
varying float v_phase;

float hash1(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz) * size;
	vec3 to_cam = CAMERA_POSITION_WORLD - c;
	float d = length(to_cam);
	vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam / max(d, 0.001)));
	// a little bigger far away so distant splashes stay a glint, not a sub-pixel flicker
	s *= 1.0 + d * 0.03;
	VERTEX = c + side * (UV.x - 0.5) * s + vec3(0.0, (1.0 - UV.y) * 0.8 * s, 0.0);
	v_fade = smoothstep(near_fade, near_fade * 3.0, d) * (1.0 - smoothstep(far_fade * 0.6, far_fade, d));
	v_seed = fract(sin(dot(c.xz, vec2(12.9898, 78.233))) * 43758.5453);
	v_phase = INSTANCE_CUSTOM.y;
}

void fragment() {
	// p: x -0.5..0.5 across, y 0..0.8 up, in crown widths
	vec2 p = vec2(UV.x - 0.5, (1.0 - UV.y) * 0.8);
	float t = v_phase;
	float a = 0.0;
	// droplets: thrown on ballistic arcs from the rim, smaller and fainter as they fall
	for (int i = 0; i < 9; i++) {
		float fi = float(i);
		float h = hash1(v_seed * 91.7 + fi * 13.1);
		float ang = (fi + h * 0.7) * 6.2832 / 9.0 + v_seed * 6.2832;
		float r = (0.22 + 0.24 * h) * sqrt(t);
		float vy = 1.4 + 1.2 * hash1(v_seed * 17.3 + fi * 5.7);
		float y = max(vy * t - 2.4 * t * t, 0.0) * 0.9;
		vec2 dp = vec2(cos(ang) * r, y + 0.02);
		float rad = 0.05 * (1.0 - 0.5 * t) * (0.6 + 0.7 * h);
		a += (1.0 - smoothstep(rad * 0.35, rad, length(p - dp))) * (0.5 + 0.5 * abs(sin(ang)));
	}
	// the crown sheet: a thin cup rim rising round the impact, gone after ~a third
	float rr = 0.1 + 0.32 * sqrt(min(t / 0.35, 1.0));
	float xn = p.x / rr;
	float cup = 0.3 * min(t / 0.15, 1.0) * xn * xn + 0.01;
	float sheet = (1.0 - smoothstep(0.012, 0.035, abs(p.y - cup))) * step(abs(xn), 1.0)
			* (0.3 + 0.7 * xn * xn) * (1.0 - smoothstep(0.2, 0.45, t));
	a = clamp(a + sheet * 0.8, 0.0, 1.0);
	ALBEDO = tint * brightness;
	ALPHA = opacity * a * v_fade * (1.0 - smoothstep(0.55, 1.0, t)) * COLOR.a;
}
