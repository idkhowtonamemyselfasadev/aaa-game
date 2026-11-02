// Scorched turf (fx/scorch.gd): up to four live burns where the Ashen Knight's ember-hot
// glaive bit the ground. Each is (x, z, radius m, char 0..1); the plants inside them are
// burnt down: shorter, black-brown and sooted, with a ragged star edge rather than a disc.
global uniform vec4 burn_0;
global uniform vec4 burn_1;
global uniform vec4 burn_2;
global uniform vec4 burn_3;

float _burn_one(vec2 p, vec4 b) {
	if (b.w <= 0.001) return 0.0;
	vec2 d = p - b.xy;
	float r = length(d);
	if (r > b.z) return 0.0;
	// ragged star: the reach swings with angle (same lobe count as the decal's tongues)
	float a = atan(d.y, d.x);
	float reach = b.z * (0.62 + 0.22 * sin(a * 11.0 + b.x * 3.1) + 0.12 * sin(a * 5.0 - b.y * 1.7));
	// mottled: a few clumps near the edge escaped the worst of it
	float m = fract(sin(dot(floor(p * 6.0), vec2(127.1, 311.7))) * 43758.5453);
	return b.w * (1.0 - smoothstep(reach * 0.55, reach, r)) * mix(0.7, 1.0, m);
}

float burn_at(vec2 p) {
	return clamp(max(max(_burn_one(p, burn_0), _burn_one(p, burn_1)),
		max(_burn_one(p, burn_2), _burn_one(p, burn_3))), 0.0, 1.0);
}
