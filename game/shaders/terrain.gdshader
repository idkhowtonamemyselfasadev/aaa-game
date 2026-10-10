shader_type spatial;
render_mode cull_back, depth_draw_opaque;
// Procedural PBR terrain: slope-blended grass / dirt / rock with triplanar detail noise.
// Textures from CC0 sources are swapped in once imported (see ASSETS.md); until then the
// surfaces are generated from noise so nothing is flat-shaded.

uniform vec3 grass_a : source_color = vec3(0.30, 0.24, 0.09);   // matted thatch under the blades
uniform vec3 grass_b : source_color = vec3(0.55, 0.42, 0.17);
uniform vec3 dirt    : source_color = vec3(0.26, 0.18, 0.11);
uniform vec3 rock_a  : source_color = vec3(0.30, 0.30, 0.31);
uniform vec3 rock_b  : source_color = vec3(0.17, 0.17, 0.19);
uniform float rock_slope_start = 0.55;
uniform float rock_slope_end = 0.78;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Procedural 3D value noise (no texture dependency; textures replace this in M1).
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
	               mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
	               mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float a = 0.5, r = 0.0;
	for (int k = 0; k < 4; k++) { r += a * vnoise(p); p = p * 2.03 + 7.1; a *= 0.5; }
	return r;
}
float tri(vec3 p, vec3 n, float s) {
	return fbm(p * s);
}

void fragment() {
	vec3 n = normalize(wnrm);
	float macro = tri(wpos, n, 0.012);
	float meso  = tri(wpos, n, 0.09);
	float micro = tri(wpos, n, 0.6);
	float slope = 1.0 - n.y;                 // 0 flat .. 1 vertical
	float rockw = smoothstep(rock_slope_start - 0.4, rock_slope_end - 0.4, slope + (meso - 0.5) * 0.25);
	float dirtw = smoothstep(0.35, 0.65, macro + (micro - 0.5) * 0.3) * (1.0 - rockw);
	// thatch: fine wind-combed streaks so the ground between clumps reads as dense dead grass
	float streak = vnoise(vec3(wpos.x * 9.0 + wpos.z * 4.0, 0.0, wpos.z * 1.2 - wpos.x * 0.6));
	vec3 grass = mix(grass_a, grass_b, clamp(meso * 0.6 + micro * 0.2 + streak * 0.45 - 0.15, 0.0, 1.0));
	vec3 rock  = mix(rock_b, rock_a, micro * 0.6 + meso * 0.4);
	vec3 col = mix(grass, dirt, dirtw);
	col = mix(col, rock, rockw);
	// darken crevices
	col *= 0.78 + 0.35 * micro;
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, rockw);
	SPECULAR = mix(0.12, 0.3, rockw);
	// fake normal detail for rock and grass tufts
	vec3 dn = vec3((micro - 0.5), 1.0, (meso - 0.5)) ;
	NORMAL_MAP = normalize(dn * vec3(0.6, 1.0, 0.6)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = mix(0.6, 1.4, rockw);
}
