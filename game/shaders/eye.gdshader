shader_type spatial;
// A wet eyeball: off-white sclera with faint vessels, a dark brown iris with a radial fibre
// pattern and a limbal ring, a black pupil, under a glossy tear film. The eye looks down its
// local +Z; the lids (skin.gdshader) cut the visible part.

uniform vec3 iris_col : source_color = vec3(0.16, 0.085, 0.04);
uniform float iris_r = 0.56;   // angular radius of the iris (rad): ~6 mm on a 12.5 mm ball
uniform float pupil_r = 0.2;
// the eye's side of the face: -1 at -x, 1 at +x (the nose lies toward -side in local x)
instance uniform float side = 1.0;

varying vec3 ln;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	ln = normalize(VERTEX);
}

void fragment() {
	float ang = acos(clamp(ln.z, -1.0, 1.0));
	float az = atan(ln.y, ln.x);
	vec3 sclera = vec3(0.33, 0.29, 0.26);   // a shaded eye white is grey-buff, not paper
	// faint vessels toward the corners and a little shadow under the upper lid
	float vessel = smoothstep(0.92, 1.0, hash(vec2(floor(az * 9.0), floor(ang * 30.0))));
	sclera = mix(sclera, vec3(0.6, 0.3, 0.26), 0.25 * vessel * smoothstep(0.7, 1.2, ang));
	float fib = 0.75 + 0.25 * hash(vec2(floor(az * 40.0), 1.0)) + 0.15 * sin(az * 61.0);
	vec3 iris = iris_col * fib * mix(1.4, 0.7, smoothstep(pupil_r, iris_r, ang));
	// the white falls into the lid shadow toward both corners (the lids close over the ball's
	// curve there) and the inner corner turns to the moist pink-brown caruncle
	float horiz = abs(ln.x);
	sclera *= 1.0 - 0.6 * smoothstep(0.4, 0.85, horiz);
	float inner = smoothstep(0.7, 0.9, -ln.x * side);
	// (a saturated red caruncle read as a red glint in the eye at any range)
	sclera = mix(sclera, vec3(0.25, 0.16, 0.14), 0.6 * inner);
	vec3 alb = mix(iris, sclera, smoothstep(iris_r - 0.03, iris_r + 0.03, ang));
	// limbal ring: the iris edge darkens
	alb *= 1.0 - 0.6 * (1.0 - smoothstep(0.0, 0.07, abs(ang - iris_r)));
	alb = mix(vec3(0.01), alb, smoothstep(pupil_r - 0.02, pupil_r + 0.02, ang));
	ALBEDO = alb;
	// the upper lid and the brow throw the top of the ball into shadow; the corners recede
	AO = mix(1.0, 0.35, smoothstep(-0.1, 0.45, ln.y)) * mix(1.0, 0.45, smoothstep(0.8, 1.3, ang))
			* mix(1.0, 0.5, smoothstep(0.45, 0.9, horiz));
	AO_LIGHT_AFFECT = 0.85;
	// a wet film, but in the hat's shade: a soft small glint, not a hot white dot
	ROUGHNESS = 0.14;
	SPECULAR = 0.4;
	CLEARCOAT = 0.45;
	CLEARCOAT_ROUGHNESS = 0.08;
	SSS_STRENGTH = 0.2;
}
