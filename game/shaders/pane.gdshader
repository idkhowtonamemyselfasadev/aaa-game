shader_type spatial;
render_mode cull_disabled;
// Leaded window of small panes for the cottages (world/cottage.gd): old crown glass, dark
// and faintly green by day with the room's gloom behind it and a sheen of sky, lead cames
// in a diamond lattice; from dusk to bedtime the lamp inside glows warm through it, the
// panes uneven (thicker glass and bubbles) and the light breathing with the flame.
uniform float lit = 0.0;
uniform vec3 lamp : source_color = vec3(1.0, 0.6, 0.3);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// diamond quarries ~9 cm across
	vec2 q = UV * vec2(7.0, 8.0);
	vec2 d = vec2(q.x + q.y, q.x - q.y);
	vec2 f = abs(fract(d) - 0.5);
	float came = smoothstep(0.43, 0.47, max(f.x, f.y));
	vec2 cell = floor(d);
	float h = hash(cell);
	float edge = smoothstep(0.42, 0.04, min(UV.x, min(UV.y, min(1.0 - UV.x, 1.0 - UV.y))) * 10.0);
	float flick = 0.88 + 0.08 * sin(TIME * 7.3 + h) + 0.04 * sin(TIME * 13.1);
	vec3 glass = mix(vec3(0.05, 0.06, 0.055), vec3(0.08, 0.09, 0.08), h);
	vec3 glow = lamp * (0.55 + 0.45 * h) * (1.0 - 0.5 * length(fract(d) - 0.5)) * flick;
	ALBEDO = mix(glass, vec3(0.04, 0.04, 0.045), came);
	ROUGHNESS = mix(0.06 + h * 0.1, 0.6, came);
	METALLIC = came * 0.6;
	SPECULAR = 0.6;
	EMISSION = glow * lit * 2.2 * (1.0 - came) * (1.0 - edge * 0.5);
}
