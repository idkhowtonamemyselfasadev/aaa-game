shader_type spatial;
// A heel of dark bread (Keeper.crust): the SphereMesh pressed lumpy, a hard brown crust
// with scorched blisters and floury cracks, and one torn end showing the pale holed crumb.

varying vec3 v_rest;

float hash3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise3(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_rest = VERTEX;
	// lumps, a flat underside where it sat in the oven, and the torn end cut off ragged
	float lump = noise3(VERTEX * 60.0) - 0.5;
	vec3 v = VERTEX + NORMAL * lump * 0.008;
	v.y = max(v.y, -0.016);
	float tear = 0.026 + 0.006 * (noise3(VERTEX * 90.0 + 3.0) - 0.5);
	v.z = min(v.z, tear);
	VERTEX = v;
}

void fragment() {
	vec3 p = v_rest;
	float n = noise3(p * 140.0);
	float n2 = noise3(p * 420.0 + 7.0);
	// crust: rye brown, blistered darker on top, a dusting of flour in the cracks
	vec3 crust = mix(vec3(0.20, 0.10, 0.045), vec3(0.34, 0.19, 0.08), n);
	crust = mix(crust, vec3(0.08, 0.045, 0.025), smoothstep(0.65, 0.85, n2) * smoothstep(-0.01, 0.03, p.y));
	crust = mix(crust, vec3(0.52, 0.46, 0.38), smoothstep(0.82, 0.95, noise3(p * 260.0 + 1.0)) * 0.6);
	// the torn end: a grey-cream crumb full of small holes
	float crumb = smoothstep(0.021, 0.025, p.z);
	vec3 cr = mix(vec3(0.46, 0.39, 0.29), vec3(0.6, 0.53, 0.42), n2);
	cr *= mix(0.45, 1.0, smoothstep(0.25, 0.45, noise3(p * 700.0)));
	ALBEDO = mix(crust, cr, crumb);
	ROUGHNESS = mix(mix(0.62, 0.8, n2), 0.95, crumb);
	SPECULAR = 0.35;
	NORMAL_MAP = normalize(vec3(n2 - 0.5, n - 0.5, 1.6)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.8;
}
