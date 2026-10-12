// Enclosure boost for the shade fill (`bounce_light`, set by World._apply_bounce).
// Inside a walled space (the ruined keep) the sunlit inner face throws far more light at the
// floor and rubble than open ground gets from the meadow; Ruins sets the zone:
// x, y = centre (world x, z), z = radius (m), w = extra gain inside.
global uniform vec4 bounce_zone;

float bounce_gain(vec3 p) {
	float d = length(p.xz - bounce_zone.xy);
	return 1.0 + bounce_zone.w * (1.0 - smoothstep(bounce_zone.z * 0.85, bounce_zone.z * 1.1, d));
}
