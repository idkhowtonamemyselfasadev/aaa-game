shader_type spatial;
render_mode cull_back;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
// Hesper's cookfire on the keep floor (world/hearth.gd), one shader for its three parts:
//   part 0 ring stones: weathered grey fieldstone, sooted black on the faces toward the fire
//          and over the crown, heat-reddened just above the soot line
//   part 1 wood: split oak deadwood, grey bark and pale split faces outside the ring, charred
//          to a crazed black alligator char toward the fire end, the cracks glowing ember
//   part 2 ash bed: pale grey-white ash over a black charcoal bed, with charcoal crumbs and
//          ember specks breathing in the middle, a sooty rim fading into the floor
// `glow` is the fire's level (0 cold .. 1 blazing); `centre` the fire's middle in world space.

#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/bounce.gdshaderinc"
uniform int part = 0;
uniform float glow = 0.0;
uniform vec3 centre = vec3(0.0);
uniform float ring_r = 0.36;

varying vec3 wp;
varying vec3 wn;
varying vec3 lp;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x), mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x), mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float a = 0.5, r = 0.0; for (int k = 0; k < 4; k++) { r += a * vn(p); p = p * 2.07 + 5.3; a *= 0.5; } return r; }
// cellular crack distance (F2 - F1): small near the cell borders = the char's crazing
float cells(vec3 p) {
	vec3 i = floor(p);
	float f1 = 9.0, f2 = 9.0;
	for (int z = -1; z <= 1; z++) for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec3 c = i + vec3(float(x), float(y), float(z));
		vec3 o = c + vec3(hash3(c), hash3(c + 7.1), hash3(c + 13.7));
		float d = length(p - o);
		if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
	}
	return f2 - f1;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lp = VERTEX;
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 rel = wp - centre;
	float rr = length(rel.xz);
	vec3 col;
	float rough = 0.9;
	vec3 emit = vec3(0.0);
	float bump = 0.0;
	float porous = 0.8;
	// ember colour: deep red in the dark cracks, orange-gold at the hottest
	float breathe = 0.75 + 0.25 * sin(TIME * 1.7 + fbm(wp * 6.0) * 9.0);
	if (part == 0) {
		float s = fbm(wp * 9.0);
		col = mix(vec3(0.07, 0.066, 0.062), vec3(0.17, 0.158, 0.14), smoothstep(0.25, 0.8, s + fbm(wp * 2.5) * 0.3));
		col = mix(col, vec3(0.36, 0.34, 0.28), smoothstep(0.66, 0.8, fbm(wp * 4.0 + 11.0)) * 0.3);   // lichen on the outer flank
		// soot: the faces turned to the fire and the crown, ragged-edged
		float inward = clamp(dot(n.xz, -normalize(rel.xz + 1e-4)) * 0.8 + n.y * 0.6 + 0.4, 0.0, 1.0);
		float soot = smoothstep(0.25, 0.75, inward + (fbm(wp * 7.0 + 3.0) - 0.5) * 0.7) * (1.0 - smoothstep(ring_r * 0.9, ring_r * 1.5, rr));
		col = mix(col, vec3(0.025, 0.022, 0.02), soot * 0.92);
		// heat-reddened stone at the soot's edge
		float red = soot * (1.0 - soot) * 4.0 * smoothstep(0.4, 0.7, fbm(wp * 5.0 + 9.0));
		col = mix(col, vec3(0.34, 0.17, 0.09), red * 0.45);
		rough = mix(0.88, 0.97, soot);
		bump = s;
		porous = 0.5;
	} else if (part == 1) {
		// lp.y runs along the log (0 at the fire end .. length at the outer end)
		float along = lp.y;
		float charl = 1.0 - smoothstep(0.22, 0.52, along + (fbm(wp * 6.0) - 0.5) * 0.18);
		vec3 bark = mix(vec3(0.07, 0.06, 0.05), vec3(0.2, 0.17, 0.14), fbm(vec3(wp.x * 30.0, wp.y * 6.0, wp.z * 30.0)));
		// split faces (vertex colour red marks them) show pale grain
		float split = COLOR.r;
		vec3 grain = mix(vec3(0.15, 0.115, 0.08), vec3(0.22, 0.17, 0.115), vn(vec3(wp.x * 4.0, wp.y * 60.0, wp.z * 4.0)));
		col = mix(bark, grain, split);
		float cr = cells(vec3(lp.x * 38.0, lp.y * 22.0, lp.z * 38.0));
		float crack = 1.0 - smoothstep(0.0, 0.09, cr);
		vec3 charc = mix(vec3(0.03, 0.028, 0.026), vec3(0.075, 0.07, 0.065), smoothstep(0.1, 0.5, cr));
		col = mix(col, charc, charl);
		col = mix(col, col * 0.5, smoothstep(0.42, 0.62, along) * (1.0 - smoothstep(0.62, 0.9, along)) * 0.6);   // browned
		// char has only a faint dull sheen: at 0.6 it mirrored the noon sky and the cold logs
		// read bleached white in the shaded keep
		rough = mix(0.88, 0.8, charl * (1.0 - crack));
		float hot = charl * charl * glow * breathe;
		emit = mix(vec3(0.9, 0.18, 0.03), vec3(1.6, 0.6, 0.12), hot) * crack * hot * 3.2;
		// a dying fire leaves only the ember ends glowing
		emit *= 1.0 - smoothstep(0.05, 0.2, along) * (1.0 - glow) * 0.8;
		bump = cr * charl - crack * charl * 0.4;
		porous = 0.7;
	} else {
		// ash bed: lp.xz is the bed's local plane, centred on the fire
		float t = clamp(rr / ring_r, 0.0, 2.0);
		float ash = fbm(wp * 11.0);
		col = mix(vec3(0.12, 0.115, 0.11), vec3(0.27, 0.262, 0.25), smoothstep(0.4, 0.75, ash));   // weathered cold ash, not fresh white
		float coal = smoothstep(0.52, 0.72, fbm(wp * 26.0 + 4.0)) * (1.0 - smoothstep(0.55, 0.95, t));
		col = mix(col, vec3(0.03, 0.028, 0.026), coal);
		col = mix(col, vec3(0.02), (1.0 - smoothstep(0.0, 0.45, t)) * 0.7);   // charred middle
		// sooty rim fading into the floor's earth
		float rim = smoothstep(0.85, 1.4, t + (fbm(wp * 5.0) - 0.5) * 0.4);
		col = mix(col, vec3(0.09, 0.075, 0.06), rim);
		float sp = smoothstep(0.62, 0.8, fbm(wp * 34.0 + 1.0));
		float hot = (1.0 - smoothstep(0.2, 0.75, t)) * glow * breathe;
		emit = mix(vec3(0.8, 0.14, 0.02), vec3(1.5, 0.55, 0.1), hot) * (sp * 0.7 + coal * 0.6) * (0.25 + hot) * hot * 2.6;
		rough = 0.97;
		bump = ash * 0.5 + coal * 0.3;
		porous = 1.0;
	}
	weather_wetten(col, rough, porous);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = part == 0 ? 0.3 : 0.15;   // wood char and ash: no glossy sky glint
	// a small detail bump from the pattern's gradient
	// (surface-gradient bump in view space: Mikkelsen's derivative method)
	float h = bump * 0.006;
	vec3 dpx = dFdx(VERTEX), dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL), r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	AO = 0.85;
	// shade fill with NO keep enclosure gain: the hearth is lit by almost nothing else at
	// noon (a frame with this term cut goes near black), so under the 6x gain its flanks
	// (0.8 x 6) and even its ash dome and flat stone tops (0.3 x 6) glowed cream against the
	// wall stones (13:00 10-17: sun cut -> still white; fill cut -> black)
	float facing = mix(0.8, 0.45, clamp(n.y, 0.0, 1.0));
	EMISSION = ALBEDO * bounce_light * facing * AO + emit;
}
