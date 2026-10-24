shader_type spatial;
render_mode cull_back, depth_draw_opaque;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
global uniform vec3 ground_fill;   // low-sun skylight on open ground (World._apply_bounce)
#include "res://shaders/bounce.gdshaderinc"
// Procedural PBR terrain for the Vale. Layers, all generated from noise (no texture yet):
//   turf    - live short sward: thousands of tiny blades lying in the sward, mixed through
//             with combed dead thatch, so the ground between the grass clumps reads as a meadow
//             floor rather than bare soil;
//   clover  - patches of white clover (trefoil leaves) in the turf;
//   moss    - velvet cushions on the cooler banks and hollows;
//   litter  - trodden earth with dead leaves, twigs and pebbles;
//   rock    - on steep slopes.
// Every layer carries a height so the shading normal is bumped per pixel (screen-space
// surface gradient), and small detail fades to its average with distance so nothing shimmers.

#include "res://shaders/weather.gdshaderinc"
#include "res://shaders/trample.gdshaderinc"
uniform vec3 turf_a   : source_color = vec3(0.20, 0.22, 0.08);   // shaded live sward
uniform vec3 turf_b   : source_color = vec3(0.46, 0.47, 0.18);   // sunlit live blade
uniform vec3 thatch_a : source_color = vec3(0.30, 0.24, 0.10);   // matted dead grass
uniform vec3 thatch_b : source_color = vec3(0.56, 0.45, 0.22);
uniform vec3 clover_c : source_color = vec3(0.17, 0.25, 0.08);
uniform vec3 moss_a   : source_color = vec3(0.10, 0.15, 0.03);
uniform vec3 moss_b   : source_color = vec3(0.33, 0.38, 0.08);
uniform vec3 soil     : source_color = vec3(0.19, 0.15, 0.11);
uniform vec3 leaf_a   : source_color = vec3(0.42, 0.24, 0.10);   // dead oak leaves
uniform vec3 leaf_b   : source_color = vec3(0.30, 0.20, 0.10);
uniform vec3 leaf_drift : source_color = vec3(0.50, 0.39, 0.25); // dry tan oak leaves under the crowns
uniform vec3 rock_a   : source_color = vec3(0.30, 0.30, 0.31);
uniform vec3 rock_b   : source_color = vec3(0.17, 0.17, 0.19);
uniform float rock_slope_start = 0.55;
uniform float rock_slope_end = 0.78;
uniform float bump_strength = 1.0;
// Puddles: rain pools where the ground lies below its surroundings (vertex colour red =
// metres below the 3-7 m ring mean, from Terrain.hollow_at). As the ground soaks, water
// first stands in the deepest dips and spreads out until every hollow deeper than
// `puddle_soaked` holds a pool.
uniform float puddle_first = 0.55;     // hollow depth that holds water first
uniform float puddle_soaked = 0.27;    // shallowest hollow that holds water when soaked
uniform float puddle_max_slope = 0.025; // 1 - normal.y; water does not stand on banks
uniform vec3 puddle_mud : source_color = vec3(0.10, 0.08, 0.05);
// the sky seen in the water (world.gd feeds the live haze colour: the cloud deck is a mesh,
// so the engine's sky reflection shows only the bare, dim PhysicalSky)
uniform vec3 puddle_sky = vec3(0.5, 0.53, 0.57);

// Wake rings where the hero's feet strike a pool: (x, z, age s, strength), pushed by
// weather.gd per footfall; strength 0 = unused slot.
global uniform vec4 wade_ring_0;
global uniform vec4 wade_ring_1;
global uniform vec4 wade_ring_2;
global uniform vec4 wade_ring_3;
global uniform vec4 wade_ring_4;
global uniform vec4 wade_ring_5;
global uniform vec4 wade_ring_6;
global uniform vec4 wade_ring_7;

// One footfall's ring train: a packet of ~3 crests running out from the foot, slowing and
// spreading as it goes, amplitude falling with age and (cylindrical spreading) with radius.
vec2 wade_ring(vec2 xz, vec4 r) {
	if (r.w <= 0.0) return vec2(0.0);
	vec2 d = xz - r.xy;
	float dist = length(d);
	float t = r.z;
	float front = 0.06 + 0.55 * pow(t, 0.6);           // ~1 m across after a second
	if (dist > front + 0.05) return vec2(0.0);
	float x = (front - dist) * 70.0;                    // ~9 cm crests behind the front
	float env = smoothstep(0.0, 1.0, x) * exp(-max(x - 1.0, 0.0) * 0.28);
	float amp = r.w * exp(-t * 1.6) * inversesqrt(max(dist, 0.08) * 6.0);
	return normalize(d + 1e-5) * sin(x) * env * amp;
}

vec2 wade_ripples(vec2 xz) {
	return wade_ring(xz, wade_ring_0) + wade_ring(xz, wade_ring_1) + wade_ring(xz, wade_ring_2)
			+ wade_ring(xz, wade_ring_3) + wade_ring(xz, wade_ring_4) + wade_ring(xz, wade_ring_5)
			+ wade_ring(xz, wade_ring_6) + wade_ring(xz, wade_ring_7);
}

// boot prints pressed by the hero and the Hollows (world/trample.gd): 64x2 RGBA float,
// row 0 (x, z, age s, depth 0..1), row 1 (heel-to-toe dir x, z); foot_box = live bounds
// moss collars round the oak boles and boulder feet: foot_moss() in weather.gdshaderinc

global uniform sampler2D foot_prints : filter_nearest, repeat_disable;
global uniform vec4 foot_box;
const int FOOT_N = 64;
const float FOOT_LIFE = 180.0;

// Signed distance (m) to a boot sole: heel pad and ball joined by a narrow waist.
// p: x along the foot (toe +), y across.
float sole_sdf(vec2 p) {
	float heel = (length((p - vec2(-0.085, 0.0)) / vec2(0.048, 0.042)) - 1.0) * 0.042;
	float ball = (length((p - vec2(0.045, 0.004)) / vec2(0.078, 0.050)) - 1.0) * 0.050;
	float k = 0.035;
	float hh = clamp(0.5 + 0.5 * (ball - heel) / k, 0.0, 1.0);
	return mix(ball, heel, hh) - k * hh * (1.0 - hh);
}

// x: how deep the ground is pressed here (0..1), y: the pushed-up rim, z: toe weight
vec3 boot_prints(vec2 xz) {
	vec3 r = vec3(0.0);
	if (xz.x < foot_box.x || xz.y < foot_box.y || xz.x > foot_box.z || xz.y > foot_box.w) {
		return r;
	}
	for (int i = 0; i < FOOT_N; i++) {
		vec4 a = texelFetch(foot_prints, ivec2(i, 0), 0);
		if (a.w <= 0.0) {
			continue;
		}
		vec2 d = xz - a.xy;
		if (dot(d, d) > 0.04) {
			continue;
		}
		vec2 f = texelFetch(foot_prints, ivec2(i, 1), 0).xy;
		vec2 lp = vec2(dot(d, f), dot(d, vec2(-f.y, f.x)));
		float sd = sole_sdf(lp);
		// fresh prints are crisp and deep; old ones slump and fade back into the ground
		float age = a.z / FOOT_LIFE;
		float keep = a.w * (1.0 - smoothstep(0.25, 1.0, age));
		float soft = 0.006 + 0.012 * age;
		float dent = (1.0 - smoothstep(-soft, soft * 0.5, sd));
		// cross-bar tread pressed into the sole (fades as the print slumps)
		float tread = smoothstep(0.3, 0.7, abs(fract(lp.x * 42.0) - 0.5) * 2.0) * (1.0 - age) * 0.25;
		dent *= 1.0 - tread * step(sd, -0.008);
		float rim = smoothstep(0.035, 0.008, sd) * step(-0.002, sd);
		float toe = smoothstep(-0.02, 0.09, lp.x);
		r.x = max(r.x, dent * keep);
		r.y = max(r.y, rim * keep * (1.0 - r.x));
		r.z = max(r.z, toe * dent * keep);
	}
	return r;
}

// cloven hoof prints pressed by the red deer (world/trample.gd add_hoof): 256x2 RGBA float,
// row 0 (x, z, age s, depth 0..1), row 1 (toe dir x, z, splay 0..1, hoof length m)
global uniform sampler2D hoof_prints : filter_nearest, repeat_disable;
global uniform vec4 hoof_box;
// the hens' garth and the worn yard path, baked by YardGround: r = (inside distance + 1) / 3,
// g = path distance / 2, b = that path's wear (village tracks fade out), over the square at yard_box.xy of side yard_box.z (0 = none)
global uniform sampler2D yard_mask : filter_linear, repeat_disable;
global uniform vec4 yard_box;
const int HOOF_N = 256;
const float HOOF_LIFE = 150.0;

// Signed distance (m) to one claw of a cloven hoof: a rounded heel bulb tapering to a
// blunt point at the toe, flat on the inner (cleft) side. p in hoof space, L hoof length.
float claw_sdf(vec2 p, float L) {
	float hl = 0.5 * L;
	float t = clamp(p.x / hl, -1.0, 1.0);
	// widest just behind the middle, narrowing to the toe
	float w = 0.21 * L * (1.0 - 0.55 * smoothstep(-0.1, 1.0, t)) * (1.0 - 0.25 * smoothstep(-0.5, -1.0, t));
	vec2 q = vec2(p.x, p.y - w * 0.85);
	float e = (length(q / vec2(hl, w)) - 1.0) * w;
	// the cleft side is cut straight
	return max(e, -p.y + 0.012 * L);
}

// same as boot_prints: x pressed depth, y pushed-up rim, z toe weight
vec3 hoof_prints_at(vec2 xz) {
	vec3 r = vec3(0.0);
	if (xz.x < hoof_box.x || xz.y < hoof_box.y || xz.x > hoof_box.z || xz.y > hoof_box.w) {
		return r;
	}
	for (int i = 0; i < HOOF_N; i++) {
		vec4 a = texelFetch(hoof_prints, ivec2(i, 0), 0);
		if (a.w <= 0.0) {
			continue;
		}
		vec2 d = xz - a.xy;
		if (dot(d, d) > 0.025) {
			continue;
		}
		vec4 f = texelFetch(hoof_prints, ivec2(i, 1), 0);
		float L = f.w;
		float splay = f.z;
		vec2 lp = vec2(dot(d, f.xy), dot(d, vec2(-f.y, f.x)));
		// the two claws, mirrored across the cleft; a gallop spreads them from the heel
		float ang = 0.05 + 0.22 * splay;
		vec2 pl = vec2(lp.x, abs(lp.y));
		vec2 hinge = vec2(-0.45 * L, 0.0);
		vec2 pr = pl - hinge;
		pr = vec2(pr.x * cos(ang) + pr.y * sin(ang), -pr.x * sin(ang) + pr.y * cos(ang)) + hinge;
		float sd = claw_sdf(pr - vec2(0.0, 0.02 * L * (1.0 + splay)), L);
		// dew claws: two small dots behind the heel where the hoof sank deep (gallop)
		float dew = (length(vec2(lp.x + 0.82 * L, pl.y - 0.3 * L)) - 0.07 * L);
		sd = min(sd, mix(1.0, dew, step(0.35, splay)));
		float age = a.z / HOOF_LIFE;
		float keep = a.w * (1.0 - smoothstep(0.3, 1.0, age));
		float soft = 0.003 + 0.008 * age;
		float dent = 1.0 - smoothstep(-soft, soft * 0.5, sd);
		float rim = smoothstep(0.03, 0.004, sd) * step(-0.001, sd);
		// the toe digs in deepest, more so at a gallop
		float toe = smoothstep(-0.3 * L, 0.45 * L, lp.x) * (0.6 + 0.4 * splay);
		r.x = max(r.x, dent * keep);
		r.y = max(r.y, rim * keep * (1.0 - r.x));
		r.z = max(r.z, toe * dent * keep);
	}
	return r;
}

varying vec3 wpos;
varying vec3 wnrm;
varying float hollow;

varying float v_cloud;   // cloud shadow on this vertex (1 = full sun)

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	hollow = COLOR.r;
	v_cloud = cloud_shade_at((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
vec3 hash23(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yxz + 33.33);
	return fract((q.xxy + q.yzz) * q.zyx);
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

// Fallen blades: one short stroke per cell at a random angle (combed loosely along `comb`).
// Returns (coverage, height, tone). Two jittered cells overlap so strokes cross.
vec3 blades(vec2 p, float scale, vec2 comb, float seed, float spread) {
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		vec2 q = p * scale + vec2(float(k) * 0.5, float(k) * 0.37) + seed;
		vec2 cell = floor(q);
		vec2 f = fract(q) - 0.5;
		vec3 r = hash23(cell + seed * 13.0);
		float ang = atan(comb.y, comb.x) + (r.x - 0.5) * spread;
		vec2 dir = vec2(cos(ang), sin(ang));
		f -= (r.yz - 0.5) * 0.3;
		float along = dot(f, dir);
		float across = dot(f, vec2(-dir.y, dir.x));
		float len = 0.38 + 0.1 * r.y;
		float taper = 1.0 - smoothstep(0.0, len, abs(along));
		float w = 0.075 * taper + 0.006;
		float s = (1.0 - smoothstep(w * 0.4, w, abs(across))) * step(abs(along), len);
		// a crease down the blade: it is a little folded, so it has a lit and a dark side
		float h = s * (0.6 + 0.4 * taper) * (0.75 + 0.25 * sign(across));
		if (h > acc.y) { acc = vec3(s, h, r.z); }
	}
	return acc;
}

// White-clover trefoils: three round leaflets round a centre, one plant per cell.
vec2 clover(vec2 p, float scale) {
	vec2 q = p * scale;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	vec3 r = hash23(cell + 71.0);
	f -= (r.xy - 0.5) * 0.4;
	float a0 = r.z * 6.2832;
	float cov = 0.0, h = 0.0;
	for (int k = 0; k < 3; k++) {
		float a = a0 + float(k) * 2.0944;
		vec2 c = vec2(cos(a), sin(a)) * 0.15;
		float d = length(f - c);
		float leaf = 1.0 - smoothstep(0.11, 0.135, d);
		// the pale chevron across each leaflet
		float chev = smoothstep(0.03, 0.0, abs(d - 0.06)) * leaf;
		cov = max(cov, leaf - chev * 0.35);
		h = max(h, leaf * (1.0 - d * 4.0));
	}
	return vec2(cov * step(0.25, r.x + r.y * 0.6), h);
}

// Litter: dead leaves (ellipses with a midrib), twigs (thin long strokes), pebbles (domes).
vec4 litter(vec2 p, float scale) {
	vec2 q = p * scale;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	vec3 r = hash23(cell + 211.0);
	float ang = r.x * 6.2832;
	vec2 dir = vec2(cos(ang), sin(ang));
	f -= (r.yz - 0.5) * 0.35;
	vec2 l = vec2(dot(f, dir), dot(f, vec2(-dir.y, dir.x)));
	float kind = r.y;
	float cov = 0.0, h = 0.0;
	if (kind < 0.34) {          // leaf (curled, uneven: lobed outline)
		float lob = 1.0 + 0.12 * sin(l.x * 40.0 + r.z * 6.0);
		float e = length(l / (vec2(0.22 + 0.14 * r.z, 0.10 + 0.06 * r.z) * lob));
		cov = 1.0 - smoothstep(0.85, 1.0, e);
		float rib = smoothstep(0.02, 0.0, abs(l.y)) * cov;
		h = cov * (0.5 + 0.5 * (1.0 - e)) - rib * 0.3;
		cov -= rib * 0.4;
	} else if (kind < 0.42) {   // twig
		cov = (1.0 - smoothstep(0.012, 0.025, abs(l.y))) * step(abs(l.x), 0.45);
		h = cov;
	} else if (kind < 0.47) {   // pebble
		float d = length(f / vec2(1.0, 0.75)) / (0.07 + 0.08 * r.z);
		cov = 1.0 - smoothstep(0.9, 1.0, d);
		h = cov * sqrt(max(0.0, 1.0 - d * d));
	}
	return vec4(cov, h, kind, r.z);
}

// Leaf bed under the crowns: every cell holds one oak leaf (lobed, midrib), so a few
// offset layers lie over each other into a full carpet. Returns (cover, height, tone).
// Gravel and stone chips on the keep floor: one angular chip per cell (a rounded polygon
// from a rotated box, faceted by a tilted plane). Returns (cover, height, tone, facet light).
vec4 grit(vec2 p, float scale, float seed, float thin) {
	vec2 q = p * scale;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	vec3 r = hash23(cell + seed);
	float ang = r.x * 6.2832;
	vec2 dir = vec2(cos(ang), sin(ang));
	f -= (r.yz - 0.5) * 0.4;
	vec2 l = vec2(dot(f, dir), dot(f, vec2(-dir.y, dir.x)));
	vec2 ab = vec2(0.16 + 0.2 * r.z, 0.11 + 0.14 * r.y);
	float d = mix(length(l / ab), max(abs(l.x) / ab.x, abs(l.y) / ab.y), 0.55);
	float cov = (1.0 - smoothstep(0.82, 1.0, d)) * step(thin, fract(r.y * 7.13 + r.x));
	float facet = dot(l / ab, vec2(cos(r.z * 9.0), sin(r.z * 9.0)));
	return vec4(cov, cov * (1.0 - d * 0.5), r.z, facet);
}

// moss cushions: a 3x3 Worley search gives each cell a rounded dome (x = dome height 0..1,
// y = crevice 0..1 where two cushions meet, z = per-cushion random tone)
vec3 cushions(vec2 p, float scale) {
	vec2 q = p * scale;
	vec2 cell = floor(q);
	float d1 = 9.0; float d2 = 9.0; float tone = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			vec3 r = hash23(c + 113.0);
			float d = length(q - c - r.xy) * (0.8 + 0.4 * r.z);
			if (d < d1) { d2 = d1; d1 = d; tone = r.z; }
			else if (d < d2) { d2 = d; }
		}
	}
	float dome = sqrt(max(0.0, 1.0 - d1 * d1 * 1.1));
	// soft, wide crevices: a thin dark line between cells read as cracked mud
	float crev = 1.0 - smoothstep(0.0, 0.32, d2 - d1);
	crev *= crev;
	return vec3(dome * (1.0 - crev * 0.5), crev, tone);
}

float fade_l_early(float fp) { return 1.0 - smoothstep(0.01, 0.05, fp); }

vec4 leafbed(vec2 p, float scale) {
	vec2 q = p * scale;
	vec2 cell = floor(q);
	vec2 f = fract(q) - 0.5;
	vec3 r = hash23(cell + 57.0);
	float ang = r.x * 6.2832;
	vec2 dir = vec2(cos(ang), sin(ang));
	f -= (r.yz - 0.5) * 0.3;
	vec2 l = vec2(dot(f, dir), dot(f, vec2(-dir.y, dir.x)));
	// each leaf its own size (a young leaf to a big flat one) so the cells do not read
	// as an even grid of cobbles
	float sz = mix(0.62, 1.12, fract(r.y * 13.7 + r.z * 3.1));
	float lob = 1.0 + 0.16 * sin(l.x * 30.0 / sz + r.z * 6.0);
	float e = length(l / (vec2(0.40, 0.21) * sz * lob));
	float cov = 1.0 - smoothstep(0.85, 1.0, e);
	float rib = smoothstep(0.025, 0.0, abs(l.y)) * cov;
	// a curled leaf: one half turned up to the light, the other rolled into its own shade
	float curl = cov * clamp(l.y / (0.21 * sz) * sign(r.z - 0.5), -1.0, 1.0);
	// the soft shadow the leaf throws on whatever lies under it
	float halo = (1.0 - smoothstep(0.95, 1.45, e)) * (1.0 - cov);
	return vec4(cov - rib * 0.3, cov * (0.4 + 0.6 * (1.0 - e)) - rib * 0.2 + curl * 0.25, r.z, halo);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec2 xz = wpos.xz;
	// pixel footprint in metres: drives the fade of small detail with distance
	float fp = max(length(dFdx(wpos)), length(dFdy(wpos))) + 1e-4;

	float macro = fbm(wpos * 0.012);
	float meso  = fbm(wpos * 0.09);
	float micro = fbm(wpos * 0.6);
	float slope = 1.0 - n.y;                 // 0 flat .. 1 vertical

	// ---- layer weights ----
	float rockw = smoothstep(rock_slope_start - 0.4, rock_slope_end - 0.4, slope + (meso - 0.5) * 0.25);
	// moss: banks facing away from the afternoon sun and wet hollows
	float aspect = clamp(dot(n.xz, vec2(-0.6, -0.8)) * 4.0, 0.0, 1.0);
	float mossw = smoothstep(0.52, 0.66, meso * 0.7 + aspect * smoothstep(0.08, 0.3, slope) * 0.5
			+ (1.0 - macro) * 0.25) * (1.0 - rockw * 0.6);
	float litw = smoothstep(0.58, 0.72, macro + (micro - 0.5) * 0.35) * (1.0 - rockw) * (1.0 - mossw);
	// the oak crowns drop a carpet of last year's leaves over the ground beneath them
	float shel = shelter_at(xz);
	float canopy = smoothstep(0.12, 0.55, shel + (meso - 0.5) * 0.25);
	litw = max(litw, canopy * 0.9 * (1.0 - rockw));
	mossw *= 1.0 - canopy * 0.5;
	float thatchw = smoothstep(0.3, 0.75, meso * 0.8 + vnoise(wpos * 0.35) * 0.4);
	float cloverw = smoothstep(0.62, 0.7, fbm(wpos * 0.22 + 31.0)) * (1.0 - litw) * (1.0 - mossw);

	// ---- turf: live blades over combed thatch ----
	vec2 comb = normalize(vec2(0.8, 0.6) + (vec2(meso, micro) - 0.5) * 1.5);
	float fade_b = 1.0 - smoothstep(0.01, 0.05, fp);   // blades are ~2 cm wide
	vec3 b1 = blades(xz, 12.0, comb, 0.0, 2.2);
	vec3 b2 = blades(xz, 17.0, comb.yx * vec2(1.0, -1.0), 5.3, 2.2);
	vec3 thatch = mix(thatch_a, thatch_b, clamp(meso * 0.5 + micro * 0.4 + b2.z * 0.3 - 0.1, 0.0, 1.0));
	vec3 live = mix(turf_a, turf_b, 0.35 + 0.5 * b1.z * micro + 0.2 * micro);
	// the sward far away: a mix of live and dead
	vec3 turf_far = mix(mix(turf_a, turf_b, 0.45), thatch, 0.35 + 0.5 * thatchw);
	// close: thatch strokes in the gaps, live blades on top
	vec3 turf_near = mix(mix(turf_a, thatch_a, 0.5) * 0.8, thatch, b2.x * (0.4 + 0.6 * thatchw));
	turf_near = mix(turf_near, mix(live, thatch, thatchw * 0.6), b1.x);
	vec3 turf = mix(turf_far, turf_near, fade_b);
	// ---- far meadow: past the blade clumps (grass.gd draws ~64 m) the sward still has to
	// read as rough grassland from the glider, not smooth olive felt: tussocks about a metre
	// across with dark gaps between, seed-heads bleaching the tops in broad drifts, and long
	// wind-combed bands. The tufts fade out by pixel size so nothing shimmers.
	float far_w = smoothstep(0.03, 0.12, fp);
	if (far_w > 0.001) {
		float tus = vnoise(wpos * 1.1 + vec3(0.0, 0.0, 7.7)) * 0.7 + vnoise(wpos * 2.6 + 4.2) * 0.3;
		float tus_fade = 1.0 - smoothstep(0.35, 0.9, fp);
		float tuft = smoothstep(0.35, 0.75, tus);
		float seed = smoothstep(0.5, 0.8, fbm(wpos * 0.045 + 13.0) + (meso - 0.5) * 0.3);
		vec3 tops = mix(mix(turf_a, turf_b, 0.6), thatch_b, 0.25 + 0.5 * seed);
		vec3 gaps = mix(turf_a, thatch_a, 0.4) * 0.55;
		vec3 far_col = mix(turf_far, mix(gaps, tops, tuft), tus_fade * 0.8);
		far_col = mix(far_col, far_col * vec3(1.1, 1.05, 0.9) + thatch_b * 0.06, seed * 0.6);
		float band = vnoise(vec3(dot(xz, vec2(0.8, 0.6)) * 0.12, 0.0, dot(xz, vec2(-0.6, 0.8)) * 0.02));
		far_col *= 0.9 + 0.2 * band;
		turf = mix(turf, far_col, far_w);
	}
	float turf_h = mix(0.5, max(b1.y, b2.y * 0.7), fade_b) * 0.004;

	// ---- trodden lane: the hero's track lays the sward flat along the walk ----
	// (the grass blades above fold over too; this is the matted layer under them, pale
	// straw and bruised green blades all combed one way, so the lane reads lighter)
	float laid = 0.0;
	if (fp < 0.05) {
		vec3 tl = trample_lay(wpos, 0.85);
		laid = tl.z * (1.0 - rockw) * (1.0 - smoothstep(0.025, 0.05, fp));
		if (laid > 0.001) {
			vec3 lb = blades(xz, 9.0, tl.xy, 2.7, 0.5);
			vec3 lb2 = blades(xz, 13.0, tl.xy, 7.1, 0.7);
			vec3 straw = mix(thatch_b, turf_b, 0.35 + 0.4 * lb.z) * (0.85 + 0.3 * micro);
			vec3 mat = mix(mix(turf_a, thatch_a, 0.5), straw * 0.8, lb2.x);
			mat = mix(mat, straw * 1.12, lb.x);
			turf = mix(turf, mat, laid * 0.9);
			turf_h = mix(turf_h, max(lb.y, lb2.y * 0.7) * 0.004, laid);
		}
	}

	// ---- clover patches ----
	float fade_c = 1.0 - smoothstep(0.008, 0.04, fp);
	vec2 cl = clover(xz, 11.0);
	turf = mix(turf, mix(clover_c, clover_c * 1.5, cl.y), cloverw * mix(0.45, cl.x, fade_c));
	turf_h += cloverw * cl.y * fade_c * 0.004;

	// ---- moss ----
	float fade_m = 1.0 - smoothstep(0.004, 0.02, fp);
	float mfine = vnoise(wpos * 90.0);
	float mcush = fbm(wpos * 7.0);
	vec3 moss = mix(moss_a, moss_b, clamp(mcush * 1.2 - 0.15 + (mfine - 0.5) * 0.4 * fade_m, 0.0, 1.0));
	float moss_h = (mcush * 0.8 + mfine * 0.2 * fade_m) * 0.006;
	// collars round the boles and boulder feet: a ragged-edged cushion, lumpier and a
	// touch brighter than the bank moss, with a few fallen oak leaves lying on it
	float fm = foot_moss(xz);
	float footw = smoothstep(0.15, 0.42, fm + (mcush - 0.5) * 0.55 + (vnoise(wpos * 2.3) - 0.5) * 0.3) * (1.0 - rockw * 0.5);
	// olive, not lime: cushion tops a dull yellow-olive (desaturated toward the dead thatch),
	// flanks a deeper green, crevices between cushions dark peaty brown, and a few cushions
	// dried brown on top; the domes give the collar real relief in the bump
	float fade_cu = 1.0 - smoothstep(0.01, 0.06, fp);
	// warped so the cushion edges wander instead of tiling into polygons (it read as
	// cracked mud up close), and the crevices only open in patches: cushions merge
	vec2 cwarp = vec2(vnoise(wpos * 1.9), vnoise(wpos * 1.9 + 17.3)) - 0.5;
	vec3 cu = cushions(xz + cwarp * 0.45, 5.5);
	float cmask = smoothstep(0.35, 0.7, vnoise(wpos * 2.7 + 3.1));
	cu.y *= cmask;
	cu.x = mix(0.55 + cu.x * 0.45, cu.x, cmask);
	vec3 olive_hi = mix(moss_b, thatch_a, 0.38) * 0.95;
	vec3 olive_lo = mix(moss_a, soil, 0.25) * 0.9;
	vec3 moss_f = mix(olive_lo, olive_hi, clamp(mix(mcush * 1.2 - 0.1, cu.x, 0.35 * fade_cu) + (mfine - 0.5) * 0.5 * fade_m, 0.0, 1.0));
	moss_f = mix(moss_f, mix(thatch_a, leaf_b, 0.4) * 0.8, step(0.86, cu.z) * smoothstep(0.4, 0.9, cu.x) * 0.6 * fade_cu);
	// each cushion its own shade of olive, crevices only a soft peaty shadow
	moss_f *= mix(1.0, 0.86 + 0.28 * cu.z, fade_cu);
	moss_f = mix(moss_f, olive_lo * 0.6, cu.y * 0.35 * fade_cu);
	float fh = (mix(mcush * 0.6, mcush * 0.45 + cu.x * 0.3, fade_cu) + vnoise(wpos * 16.0) * 0.25 + mfine * 0.1 * fade_m) * 0.018;
	if (footw > 0.001) {
		vec4 fl = leafbed(xz + vec2(11.3, 4.9), 3.3);
		float on = fl.x * fade_l_early(fp) * step(0.45, fl.z) * (1.0 - smoothstep(0.3, 0.9, fm)) * canopy;
		moss_f = mix(moss_f, mix(leaf_drift, leaf_a * 0.85, fl.z) * 0.85, on);
		fh = mix(fh, 0.004 + fl.y * 0.003, on);
	}
	moss = mix(moss, moss_f, footw);
	moss_h = mix(moss_h, fh, footw);
	mossw = max(mossw, footw);

	// ---- litter on trodden earth ----
	float fade_l = 1.0 - smoothstep(0.01, 0.05, fp);
	vec4 lt = litter(xz, 7.0);
	vec4 lt2 = litter(xz + 3.7, 12.0);
	vec3 earth = soil * (0.8 + 0.45 * micro);
	vec3 litcol = earth;
	vec3 leafc = mix(leaf_a, leaf_b, lt.w);
	// (linear colours: dark twigs, pebbles in the soil's grey-brown, no pale specks)
	if (lt.z >= 0.34 && lt.z < 0.42) { leafc = vec3(0.035, 0.025, 0.016); }
	if (lt.z >= 0.42) { leafc = vec3(0.055, 0.05, 0.042) * (0.75 + 0.4 * lt.w); }
	litcol = mix(litcol, leafc, lt.x * fade_l);
	litcol = mix(litcol, mix(leaf_a, thatch_a, lt2.w) * 0.9, lt2.x * fade_l * step(lt2.z, 0.34));
	// under the crowns the leaves lie thick: a third, denser layer of dry tan oak leaves
	// (pale and sun-bleached on top, the earth barely shows between them)
	// bottom to top: each layer covers part of the one below, the gaps show dark mould
	// the ground between the leaves is leaf mould: dark crumbled leaf, fragments and fine
	// skeletons a shade or two under the whole leaves, not a bare dark gap
	float frag = vnoise(wpos * 23.0) * 0.6 + vnoise(wpos * 61.0) * 0.4;
	// (lifted x1.2: at x1.0 the mould read near-black between the drifts)
	vec3 mould = mix(mix(earth * 0.7, leaf_b * 0.55, 0.6), leaf_a * 0.6, smoothstep(0.45, 0.8, frag) * fade_l) * 1.2;
	vec3 bed = mix(mould, mix(leaf_drift * 0.62, leaf_b * 0.9, micro * 0.6), 0.5 - 0.35 * fade_l);
	// the leaves blow together into drifts: in a drift they lie six deep and overlap, between
	// drifts a few lie scattered on the mould
	float clump = smoothstep(0.38, 0.68, fbm(wpos * 0.85 + 5.0) * 0.75 + micro * 0.35);
	float bed_h = 0.0;
	for (int k = 0; k < 6; k++) {
		float fk = float(k);
		vec4 lb = leafbed(xz + vec2(fk * 3.17, fk * 1.71), 4.2 + fk * 1.1);
		// leaf by leaf the tone wanders a little: tan, russet, dark wet brown; neighbours
		// stay close in value so the bed reads as one layer, not a mosaic of chips
		// (linear colours: the old (0.52, 0.43, 0.20) read as cream-white flecks)
		// the tan is pushed warmer (less blue/green) so the dry top leaves read russet-tan in
		// the crowns' blue sky-fill instead of greyish-pale
		vec3 tone = mix(mix(leaf_drift * vec3(0.9, 0.74, 0.5), leaf_a * 0.8, smoothstep(0.35, 0.95, lb.z)),
				vec3(0.16, 0.10, 0.026), step(0.92, fract(lb.z * 7.3)) * 0.5);
		tone = mix(tone, leaf_b * 0.55, step(0.78, fract(lb.z * 3.9 + 0.3)) * 0.6);
		// damp patches darken whole runs of the bed, not single leaves
		tone *= mix(1.0, 0.62, smoothstep(0.5, 0.75, fbm(wpos * 0.7 + 29.0)));
		tone *= 0.7 + 0.04 * fk + 0.14 * clamp(lb.y, 0.0, 1.0);   // upper leaves catch more light
		// how many leaves of this layer lie here: the lower four thin out between drifts,
		// the top two only lie in the drifts
		float dens = k < 4 ? mix(0.3 + 0.1 * fk, 1.0, clump) : clump * 0.85;
		float keep = step(fract(lb.z * 5.13 + fk * 0.37), dens);
		float c = lb.x * fade_l * keep;
		bed *= 1.0 - lb.w * 0.22 * fade_l * keep;
		bed = mix(bed, tone, c);
		bed_h = mix(bed_h, 0.3 + 0.15 * fk + lb.y, c);
	}
	// between the collars the grove floor is not bare leaves: low moss patches spread in the
	// damp shade and the leaf bed thins over them
	float gpatch = smoothstep(0.42, 0.62, fbm(wpos * 0.35 + 17.0) * 0.8 + meso * 0.35) * canopy;
	vec3 gmoss = mix(mix(moss_a, soil, 0.2), mix(moss_b, thatch_a, 0.45) * 0.85, clamp(mcush * 1.1 + (mfine - 0.5) * 0.3 * fade_m, 0.0, 1.0));
	litcol = mix(litcol, bed, canopy);
	// some sward survives in the litter (little under the crowns)
	litcol = mix(litcol, turf, smoothstep(0.55, 0.8, micro) * 0.7 * (1.0 - canopy * 0.8));
	// at range the leaves average out: tan drift under the crowns, not red-brown earth
	litcol = mix(litcol, mix(mix(earth, leaf_a * 0.8, 0.4), mix(leaf_drift * 0.6, leaf_b * 0.85, 0.45), canopy), 1.0 - fade_l);
	litcol = mix(litcol, gmoss, gpatch * (1.0 - 0.5 * smoothstep(0.55, 0.85, micro) * fade_l));
	float lit_h = max(max(lt.y, lt2.y * 0.6), bed_h * 0.35 * canopy) * fade_l * 0.006 + micro * 0.004;

	// ---- rock ----
	vec3 rock = mix(rock_b, rock_a, micro * 0.6 + meso * 0.4);
	float rock_h = micro * 0.05 + vnoise(wpos * 4.0) * 0.02;
	// lichen speckle on the rock
	rock = mix(rock, vec3(0.42, 0.42, 0.30), smoothstep(0.72, 0.8, vnoise(wpos * 3.1 + 9.0)) * 0.6);

	// ---- compose ----
	vec3 col = turf;
	float h = turf_h;
	col = mix(col, litcol, litw);      h = mix(h, lit_h, litw);
	col = mix(col, moss, mossw);       h = mix(h, moss_h, mossw);
	col = mix(col, rock, rockw);       h = mix(h, rock_h, rockw);
	// ---- the keep floor: the ruined watchtower's beaten earth floor (bounce_zone holds the
	// keep centre and its inner radius). Lime mortar dust and grit fallen from the walls,
	// angular stone chips, wind-drifted oak leaves heaped against the wall foot and in the
	// lee of the plinth, and low moss creeping out from the wall on the damp side.
	float kd = length(xz - bounce_zone.xy);
	float keepw = (1.0 - smoothstep(bounce_zone.z * 0.84, bounce_zone.z * 0.92, kd + (micro - 0.5) * 0.25))
			* step(0.5, bounce_zone.z) * (1.0 - rockw);
	if (keepw > 0.001) {
		float fade_g = 1.0 - smoothstep(0.006, 0.03, fp);
		float dust = fbm(wpos * 1.7 + 41.0);
		// beaten earth paled by mortar dust, darker damp patches
		// (colours here are linear: soil is a source_color uniform, ~0.03 linear)
		vec3 kc = mix(soil * 1.7, vec3(0.1, 0.085, 0.064), smoothstep(0.4, 0.75, dust) * 0.6);
		kc = mix(kc, soil * 1.0, smoothstep(0.55, 0.7, fbm(wpos * 0.8 + 63.0)) * 0.6);   // damp
		kc *= 0.85 + 0.3 * micro;
		float kh = micro * 0.004;
		// two sizes of chips: pea gravel and thumb-sized spalls of the wall stone
		float gdens = smoothstep(0.35, 0.7, dust + (meso - 0.5) * 0.5);
		vec4 g1 = grit(xz, 18.0, 13.0, mix(0.92, 0.55, gdens));
		vec4 g2 = grit(xz + 1.3, 9.0, 71.0, 0.55);
		vec3 stone = vec3(0.11, 0.1, 0.082);
		// pea gravel sits in the dust, close to the floor tone, its tops only a little lighter
		vec3 c1 = mix(kc, stone * (0.45 + 0.3 * g1.z), 0.4) * (0.88 + 0.08 * g1.w);
		// spalls stay in the wall stone's grey-brown: no pale pebbles that pop as white specks
		vec3 c2 = mix(stone, vec3(0.095, 0.078, 0.056), step(0.7, g2.z)) * (0.66 + 0.3 * g2.z) * (0.88 + 0.12 * g2.w);
		kc = mix(kc, c1, g1.x * fade_g);
		kh = max(kh, g1.y * 0.0035 * fade_g);
		kc = mix(kc, c2, g2.x * fade_g * gdens);
		kh = max(kh, g2.y * 0.01 * fade_g * gdens);
		// at range: a speckled grey-brown grit tone, not black
		kc = mix(kc, mix(soil * 1.3, stone * 0.85, 0.35 + 0.3 * gdens), (1.0 - fade_g) * 0.6);
		// leaves drift against the wall foot and lie loose across the floor
		float wallfoot = smoothstep(bounce_zone.z * 0.62, bounce_zone.z * 0.84, kd);
		float drift = clamp(wallfoot * 1.1 + smoothstep(0.45, 0.7, fbm(wpos * 0.9 + 5.0)) * 0.75
				+ 0.15, 0.0, 1.0);
		// three leaf sizes (big flat oak leaves, middling, small curled ones), each layer
		// clumped by its own noise so the leaves lie in heaps and windrows, not an even sprinkle
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float lsc = k == 0 ? 3.4 : (k == 1 ? 5.8 : 8.6);
			vec3 lb = leafbed(xz + vec2(fk * 2.31 + 0.7, fk * 1.13), lsc).xyz;
			vec3 tone = mix(mix(leaf_drift, leaf_a * 0.85, smoothstep(0.3, 0.95, lb.z)),
					leaf_b * 0.8, step(0.85, fract(lb.z * 5.1)));
			tone *= 0.8 + 0.07 * fk + 0.15 * lb.y;
			float clump = smoothstep(0.38, 0.62, fbm(wpos * (1.6 + fk * 0.9) + 17.0 * fk + 3.0));
			float dk = clamp(drift * (0.45 + 0.9 * clump) - fk * 0.12, 0.0, 1.0);
			float c = lb.x * fade_l * step(1.0 - dk, lb.z * 0.9 + 0.08);
			kc = mix(kc, tone, c);
			kh = mix(kh, 0.004 + 0.002 * fk + lb.y * 0.003, c);
		}
		// dead twigs blown off the oaks and the ivy: thin dark sticks, a few forked, lying
		// across the leaves near the wall foot
		{
			vec2 q = xz * 2.2;
			vec2 cell = floor(q);
			vec3 r = hash23(cell + 211.0);
			vec2 f = fract(q) - 0.5 - (r.xy - 0.5) * 0.4;
			float ang = r.z * 6.2832;
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 l = vec2(dot(f, dir), dot(f, vec2(-dir.y, dir.x)));
			float len = 0.22 + 0.2 * r.x;
			float bend = l.y - 0.08 * sin(l.x * 7.0 + r.y * 6.0) * r.y;
			float tw = (1.0 - smoothstep(0.006, 0.013 - 0.004 * (l.x / len), abs(bend)))
					* step(abs(l.x), len);
			// a side fork off the far half
			vec2 fl = l - vec2(len * 0.3, 0.0);
			vec2 fdir = normalize(vec2(1.0, 0.7 * sign(r.y - 0.5)));
			float fx = dot(fl, fdir);
			float fy = dot(fl, vec2(-fdir.y, fdir.x));
			tw = max(tw, (1.0 - smoothstep(0.004, 0.009, abs(fy))) * step(0.0, fx) * step(fx, len * 0.45) * step(0.5, r.x));
			tw *= step(1.0 - (0.25 + 0.5 * wallfoot), fract(r.x * 13.7 + r.z)) * fade_l;
			vec3 twc = mix(vec3(0.016, 0.011, 0.008), vec3(0.05, 0.04, 0.03), fract(r.y * 9.1)) * (0.8 + 0.4 * micro);
			kc = mix(kc, twc, tw);
			kh = max(kh, tw * 0.011);
		}
		kc = mix(kc, mix(leaf_drift * 0.7, leaf_b, 0.5), drift * 0.5 * (1.0 - fade_l));
		// moss creeps out from the wall foot on the north (shaded) side
		float north = clamp(-(xz.y - bounce_zone.y) / max(kd, 0.01), 0.0, 1.0);
		float km = smoothstep(0.5, 0.72, mcush * 0.7 + wallfoot * (0.25 + 0.3 * north) + (mfine - 0.5) * 0.2 * fade_m)
				* (1.0 - drift * 0.6);
		kc = mix(kc, mix(olive_lo, olive_hi, clamp(mcush * 1.2 - 0.1, 0.0, 1.0)), km);
		kh = mix(kh, mcush * 0.008, km);
		col = mix(col, kc, keepw);
		h = mix(h, kh, keepw);
		litw = max(litw, keepw);
	}
	// ---- the hens' garth and the worn path to the cottage door (YardGround) ----
	// The garth is scratched down to dry bare earth: pale dust in the open, packed darker
	// loam where the birds walk, fans of claw rakes with the dust kicked out behind them,
	// dust-bath hollows of fine pale powder with a crumbly rim, pea grit, droppings and a few
	// moulted feathers; ragged tufts of sward survive in patches and toward the wall feet.
	// The path is a beaten band of bare earth through the gateway and round to the door.
	// The village tracks across the green are the same beaten earth, narrower where fewer
	// feet go, the sward closing in over them toward the meadow (wear b).
	float bare = 0.0;
	float rut = 0.0;   // where rain stands in the trodden tracks (low packed middle, puddles below)
	vec2 yuv = (xz - yard_box.xy) / max(yard_box.z, 1e-3);
	if (yard_box.z > 0.0 && all(greaterThan(yuv, vec2(0.0))) && all(lessThan(yuv, vec2(1.0)))) {
		vec3 ym = texture(yard_mask, yuv).rgb;
		float gd = ym.r * 3.0 - 1.0;   // inside the garth's walls (m), negative outside
		float td = ym.g * 2.0;         // to the path's centre line (m)
		float rag = (meso - 0.5) * 0.6 + (micro - 0.5) * 0.3;
		float garth = smoothstep(-0.05, 0.9, gd + rag);
		float wear = smoothstep(0.05, 0.85, ym.b);
		float hw = (0.34 + 0.12 * vnoise(wpos * 0.7 + 3.0)) * mix(0.55, 1.0, wear);
		float trackw = 1.0 - smoothstep(hw * 0.55, hw * 1.35, td + rag * 0.35);
		// where it wears thin, live sward breaks it into a broken line of bare patches
		trackw *= smoothstep(0.0, 0.35, wear - (1.0 - fbm(wpos * 0.8 + 19.0)) * (1.0 - wear) * 0.9);
		bare = max(garth, trackw) * (1.0 - rockw);
		if (bare > 0.001) {
			float fade_g = 1.0 - smoothstep(0.006, 0.03, fp);
			float dusty = smoothstep(0.35, 0.7, fbm(wpos * 1.3 + 71.0));
			vec3 dry = vec3(0.19, 0.152, 0.108);      // sun-dried dust (linear)
			vec3 packed = vec3(0.118, 0.093, 0.065);  // trodden loam (dry packed soil ~0.12)
			vec3 bc = mix(packed, dry, dusty) * (0.88 + 0.24 * micro);
			float bh = micro * 0.003;
			// the path: packed hard in the middle where the feet go, dust at its shoulders
			float mid = 1.0 - smoothstep(0.0, hw * 0.7, td);
			bc = mix(bc, mix(bc, packed * 0.95, 0.6), trackw * mid * (1.0 - garth));
			// the feet wear the middle into a shallow trough, lowest in hollows scuffed out
			// at intervals along it (where the feet land on a slope, the turn at a door): a
			// 0..1 depth that the rain fills from the deepest dips outward
			float scuff = fbm(wpos * vec3(0.9, 0.0, 0.9) + 43.0);
			rut = trackw * (1.0 - smoothstep(0.0, hw * 0.85, td + rag * 0.25)) * (1.0 - garth)
				* smoothstep(0.42, 0.72, scuff + (vnoise(wpos * 2.3 + 7.0) - 0.5) * 0.18) * wear;
			// pea grit and small stones worked up out of the loam
			vec4 g1 = grit(xz, 24.0, 97.0, 0.78);
			vec4 g2 = grit(xz + 2.1, 11.0, 53.0, 0.9);
			vec3 stone = vec3(0.12, 0.112, 0.1);
			bc = mix(bc, stone * (0.6 + 0.4 * g1.z) * (0.85 + 0.15 * g1.w), g1.x * fade_g * 0.8);
			bh = max(bh, g1.y * 0.003 * fade_g);
			bc = mix(bc, stone * (0.55 + 0.35 * g2.z) * (0.8 + 0.25 * g2.w), g2.x * fade_g);
			bh = max(bh, g2.y * 0.008 * fade_g);
			// claw rakes: a fan of three short grooves, the scratched-out dust heaped behind
			{
				vec2 q = xz * 3.2;
				vec2 cell = floor(q);
				vec3 r = hash23(cell + 151.0);
				vec2 f = fract(q) - 0.5 - (r.xy - 0.5) * 0.5;
				float ang = r.z * 6.2832;
				float on = step(0.35, fract(r.x * 13.1 + r.y)) * garth;
				float groove = 0.0;
				for (int k = 0; k < 3; k++) {
					float a = ang + (float(k) - 1.0) * 0.32;
					vec2 dir = vec2(cos(a), sin(a));
					vec2 l = vec2(dot(f, dir), dot(f, vec2(-dir.y, dir.x))) / 3.2;
					float len = 0.1 + 0.05 * fract(r.y * 7.0 + float(k) * 0.3);
					groove = max(groove, (1.0 - smoothstep(0.0015, 0.005, abs(l.y)))
							* step(0.0, l.x) * (1.0 - smoothstep(len * 0.8, len, l.x)));
				}
				vec2 dir0 = vec2(cos(ang), sin(ang));
				float spill = 1.0 - smoothstep(0.5, 1.0, length((f / 3.2 - dir0 * 0.17) / vec2(0.07, 0.07)));
				groove *= on * fade_g;
				spill *= on * fade_g * (0.5 + 0.5 * dusty);
				bc = mix(bc, dry * 1.15, spill * 0.6);
				bh += spill * 0.004;
				bc = mix(bc, mix(bc, packed * 0.7, 0.5), groove);   // soft furrows, not ink
				bh -= groove * 0.004;
			}
			// dust-bath hollows: a shallow bowl of fine pale powder, crumbs heaped round its lip
			{
				vec2 q = xz * 0.55;
				vec2 cell = floor(q);
				vec3 r = hash23(cell + 37.0);
				vec2 f = (fract(q) - 0.5 - (r.xy - 0.5) * 0.4) / 0.55;
				float rad = 0.24 + 0.14 * r.z;
				// ragged scraped-out outline (a bird's wallow, not a stamped oval): low warp for the
				// lobes, fine noise for the crumbled edge
				float d = length(f * vec2(1.0, 1.15)) / rad + (vnoise(wpos * 3.1 + vec3(r.xy * 9.0, 0.0)) - 0.5) * 0.55
					+ (vnoise(wpos * 13.0) - 0.5) * 0.22;
				float on = step(0.55, r.z) * smoothstep(0.5, 0.9, garth);
				float bowl = (1.0 - smoothstep(0.55, 1.0, d)) * on;
				float lip = smoothstep(0.8, 1.0, d) * (1.0 - smoothstep(1.0, 1.3, d)) * on;
				// powder lies patchy in the bowl: drifts, with packed earth and grit showing through
				float powder = bowl * mix(0.3, 0.75, smoothstep(0.3, 0.7, vnoise(wpos * 7.0 + 3.0)));
				bc = mix(bc, dry * (1.15 + 0.15 * micro), powder);
				bc = mix(bc, mix(bc, packed, 0.4), lip * 0.5);
				bh += -0.012 * bowl * (1.0 - d * d * 0.6) + 0.004 * lip;
			}
			// droppings: small dark coils capped with white, and moulted body feathers
			{
				vec2 q = xz * 5.0;
				vec2 cell = floor(q);
				vec3 r = hash23(cell + 401.0);
				vec2 f = (fract(q) - 0.5 - (r.xy - 0.5) * 0.6) / 5.0;
				float d = length(f) / (0.012 + 0.006 * r.z);
				float on = step(0.88, fract(r.x * 17.3 + r.z)) * garth * fade_g;
				float dr = (1.0 - smoothstep(0.7, 1.0, d)) * on;
				float cap = (1.0 - smoothstep(0.2, 0.55, length(f + vec2(0.004, 0.003)) / (0.012 + 0.006 * r.z))) * dr;
				bc = mix(bc, mix(vec3(0.03, 0.026, 0.014), vec3(0.4, 0.39, 0.35), cap), dr);
				bh = max(bh, dr * 0.005);
			}
			{
				vec2 q = xz * 1.7;
				vec2 cell = floor(q);
				vec3 r = hash23(cell + 733.0);
				vec2 f = (fract(q) - 0.5 - (r.xy - 0.5) * 0.6) / 1.7;
				float ang = r.z * 6.2832;
				vec2 dir = vec2(cos(ang), sin(ang));
				vec2 l = vec2(dot(f, dir), dot(f, vec2(-dir.y, dir.x)));
				float len = 0.05 + 0.04 * r.y;
				float t = clamp(l.x / len, 0.0, 1.0);
				float ly = l.y - 0.25 * len * t * t * (r.x - 0.5);   // a gentle curve
				float wid = 0.014 * sin(3.1416 * pow(t, 0.7)) * (0.8 + 0.4 * r.x);
				float vane = (1.0 - smoothstep(wid * 0.7, wid, abs(ly))) * step(0.0, l.x) * step(l.x, len);
				float rach = (1.0 - smoothstep(0.0008, 0.0016, abs(ly))) * step(-0.012, l.x) * step(l.x, len);
				float on = step(0.82, fract(r.y * 23.7 + r.x)) * garth * fade_g;
				vec3 fc = fract(r.x * 5.3) < 0.5 ? vec3(0.32, 0.17, 0.07) : (fract(r.x * 5.3) < 0.8 ? vec3(0.42, 0.3, 0.16) : vec3(0.05, 0.045, 0.04));
				fc *= 0.8 + 0.3 * smoothstep(0.0, wid, abs(ly)) * (1.0 - t * 0.4);
				bc = mix(bc, fc, vane * on);
				bc = mix(bc, vec3(0.5, 0.46, 0.38), rach * on * 0.8);
				bh = max(bh, (vane * 0.0015 + rach * 0.002) * on);
			}
			// ragged tufts of the old sward survive in patches and along the wall feet
			float tuft = smoothstep(0.58, 0.74, fbm(wpos * 0.9 + 23.0) * 0.75 + vnoise(wpos * 3.3) * 0.25
					+ (1.0 - smoothstep(0.0, 0.6, garth)) * 0.35) * (1.0 - trackw * mid);
			bc = mix(bc, mix(turf, thatch_a * 0.9, 0.35), tuft * 0.9);
			bh = mix(bh, turf_h, tuft);
			// at range: a dusty grey-brown with the sward patches
			bc = mix(bc, mix(mix(packed, dry, 0.55), turf, 0.25), (1.0 - fade_g) * 0.5);
			col = mix(col, bc, bare);
			h = mix(h, bh, bare);
			litw = max(litw, bare);
			bare *= 1.0 - tuft;
		}
	}
	// ---- boot prints: pressed, matted and darker; deepest in soft litter, faint in turf ----
	vec3 bp = fp < 0.03 ? max(boot_prints(xz), hoof_prints_at(xz)) : vec3(0.0);
	float soft_g = (1.0 - rockw) * mix(0.75, 1.0, max(litw, mossw * 0.7));
	float pr = bp.x * soft_g * (1.0 - smoothstep(0.015, 0.03, fp));
	// the slot floor is bare pressed loam, darker and damp; the sod torn up round its lip is
	// paler, drier crumbs and bruised blades, which is what makes a track read from a few
	// metres in dark ground
	col = mix(col, mix(col, mix(earth, thatch_a, 0.35) * 0.8, 0.7) * 0.7, pr);
	vec3 crumbs = mix(earth * 1.9, thatch_a, 0.45) * (0.85 + 0.3 * micro);
	col = mix(col, max(col, crumbs), bp.y * soft_g * 0.75 * (1.0 - smoothstep(0.015, 0.03, fp)));
	h += (-0.016 - 0.008 * bp.z) * pr + 0.004 * bp.y * soft_g;
	// broad tonal variation so the field is not one flat colour from afar
	col *= 0.82 + 0.3 * macro + 0.12 * (meso - 0.5);

	// cavity darkening from the fine height
	float cav = clamp(h / 0.004, 0.0, 1.0);
	col *= mix(1.0, 0.84 + 0.16 * cav, (1.0 - rockw) * max(fade_b, canopy * litw * fade_l));
	float rough = mix(mix(0.92, 0.8, b1.x * fade_b * (1.0 - litw)), 0.75, rockw);
	rough = mix(rough, 0.96, bare);   // dry dust: no sheen at all
	// the oak crowns keep the ground beneath them drier: no pools, few drops
	float wet_here = weather_wet * (1.0 - SHELTER_DRY * shel);
	wetten_by(col, rough, 1.0 - 0.6 * rockw, wet_here);

	// ---- puddles: standing rain in the hollows ----
	// the shoreline wanders with noise so pools are not contour rings; the fine height
	// (blades, leaves) pokes through at the very edge
	float fill = smoothstep(0.35, 1.0, wet_here);
	float level = hollow + (meso - 0.5) * 0.22 + (micro - 0.5) * 0.06 + h * 6.0;
	float thr = mix(puddle_first + 0.3, puddle_soaked, fill);
	float flat_w = 1.0 - smoothstep(puddle_max_slope * 0.5, puddle_max_slope, slope);
	float pud = smoothstep(thr, thr + 0.025, level) * flat_w * (1.0 - rockw) * step(0.01, fill);
	// saturated mud ring round each pool
	float shore = smoothstep(thr - 0.12, thr, level) * flat_w * step(0.01, fill) * (1.0 - pud);
	col = mix(col, col * 0.7, shore);
	rough = mix(rough, 0.2, shore * 0.8);
	// water: dark, murky over mud, shallow edges show the floor
	float depth = clamp((level - thr) / 0.12, 0.0, 1.0);
	col = mix(col, mix(col * 0.6, puddle_mud, depth) * 0.8, pud);
	rough = mix(rough, 0.03, pud);
	// rain gathers in the boot prints: little dark mirrors along the track
	// rain holds in the trodden tracks: the scuffed dips first, then a chain of long thin
	// pools down the packed middle with a slick of mud at their edges
	float rthr = mix(0.95, 0.25, smoothstep(0.3, 0.9, wet_here));
	float rpool = smoothstep(rthr, rthr + 0.08, rut + (micro - 0.5) * 0.05) * step(0.2, wet_here);
	float rshore = smoothstep(rthr - 0.25, rthr, rut) * step(0.2, wet_here) * (1.0 - rpool);
	col = mix(col, col * 0.62, rshore);
	rough = mix(rough, 0.15, rshore * 0.9);
	col = mix(col, mix(col * 0.55, puddle_mud, 0.6) * 0.75, rpool);
	rough = mix(rough, 0.03, rpool);
	pud = max(pud, rpool);
	float hold = pr * smoothstep(0.25, 0.7, wet_here) * flat_w;
	col = mix(col, col * 0.55, hold * 0.8);
	rough = mix(rough, 0.05, hold);
	pud = max(pud, hold * 0.85);
	vec2 rip = rain_ripples(xz, TIME, clamp(weather_rain * 1.2 * (1.0 - shel), 0.0, 1.0))
			* (1.0 - smoothstep(0.004, 0.03, fp));
	if (pud > 0.0) {
		rip += wade_ripples(xz) * (1.0 - smoothstep(0.012, 0.06, fp));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(mix(0.25, 0.3, rockw), 0.25, pud);
	AO = mix(mix(0.85 + 0.15 * cav, 1.0, rockw), 1.0, pud);
	AO_LIGHT_AFFECT = 0.3;
	// the water surface is level: drop the slope and the fine bump under it
	n = normalize(mix(n, vec3(0.0, 1.0, 0.0), pud));
	h *= 1.0 - pud;

	// ---- bump: surface gradient from screen-space derivatives of the height ----
	vec3 dpdx = dFdx(wpos);
	vec3 dpdy = dFdy(wpos);
	float hx = dFdx(h);
	float hy = dFdy(h);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (hx * r1 + hy * r2);
	vec3 nb = normalize(abs(det) * n - grad * bump_strength);
	nb = normalize(nb + vec3(-rip.x, 0.0, -rip.y) * 0.8 * pud);
	NORMAL = normalize((VIEW_MATRIX * vec4(nb, 0.0)).xyz);
	// sky sheen on the water (Schlick, water F0 0.02), on top of the engine's reflection
	vec3 vdir = normalize(CAMERA_POSITION_WORLD - wpos);
	float fres = 0.02 + 0.98 * pow(1.0 - clamp(dot(nb, vdir), 0.0, 1.0), 5.0);
	EMISSION = puddle_sky * min(fres * 3.0, 0.6) * pud;
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;
	// bounce from the lit land around: walls, banks and hollows get most, open flat ground
	// little (the sky ambient covers it); skips the water skin
	// little (the sky ambient covers it); skips the water skin. Under the oak crowns the
	// floor also gets the green light through the leaves and the bounce off the trunks and
	// the litter around, so the woodland floor reads as dim, not black.
	EMISSION += ALBEDO * bounce_light * (mix(1.0, 0.35, clamp(n.y, 0.0, 1.0))
		+ canopy * 2.6 * vec3(0.85, 1.0, 0.7)) * AO * (1.0 - pud) * bounce_gain(wpos);
	// low sun: the open sky over level ground, unoccluded by SSAO (less under the crowns)
	EMISSION += ALBEDO * ground_fill * clamp(n.y, 0.0, 1.0) * (1.0 - 0.7 * canopy) * AO * (1.0 - pud);
}
