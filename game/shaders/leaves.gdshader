shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

global uniform vec3 bounce_light;  // shade fill without SDFGI (World._apply_bounce)
global uniform vec3 ground_fill;   // low-sun / moonlit skylight on open ground (World._apply_bounce)
// Oak leaf sprig cards: atlas painted by flora.gd, alpha-tested; crown-shaped normals
// (set by the mesh) for a soft canopy, back-light translucency, flutter on top of the
// shared branch sway.
#include "res://shaders/tree_wind.gdshaderinc"
#include "res://shaders/foliage_light.gdshaderinc"
#include "res://shaders/trample.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic;
// per-leaf tilt/fold normals painted with the oak atlas (flora.gd); 0 = off (ferns)
uniform sampler2D leaf_nrm : hint_normal, filter_linear_mipmap_anisotropic;
uniform float nmap_depth = 0.0;
// how dark the core of the crown goes (COLOR.b = depth in the crown, set by flora.gd)
uniform float crown_occ = 0.45;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float fade_dist = 380.0;
// shade fill gain: oak crowns 0.45 (inner crown); ferns on the woodland floor more (they
// catch the green light through the canopy as well as the bounce off the litter)
uniform float fill = 0.45;
uniform float crown_sky = 0.8;   // share of ground_fill the outer crown takes
// ferns (flora.gd sets 1): fronds are pushed aside by the hero's legs and spring back;
// 0 on the oak crowns
uniform float trample_gain = 0.0;
// thin-leaf transmission tint (foliage_light: a gain on the albedo). Oak leaves: yellow-green.
// Ferns (flora.gd) get a deeper, weaker tint: a frond is thicker and darker than a sunlit oak
// leaf, and the oak tint made back-lit fern cards glow lime on the grove floor.
uniform vec3 backlight = vec3(0.95, 1.1, 0.42);
// forward-scatter gain toward the sun (foliage_light); ferns (flora.gd) ~0.7
uniform float fwd_gain = 2.2;
// per-tree leaf cast strength and sunlit-skin lift (oaks 1/1; flora.gd sets ferns lower)
uniform float tree_var = 1.0;
uniform float skin_gain = 1.0;

varying float v_phase;
varying float v_occ;
varying vec3 v_inst;

varying float v_cloud;   // cloud shadow on this vertex (1 = full sun)

void vertex() {
	VERTEX += tree_wind(VERTEX, COLOR.r, MODEL_MATRIX, TIME);
	float fl = sin(TIME * 6.0 + COLOR.g * 60.0 + MODEL_MATRIX[3].x) * 0.035;
	VERTEX += vec3(fl, fl * 0.6, -fl) * COLOR.r;
	if (trample_gain > 0.0) {
		// a fern crown is ~1.4 m across: the legs brush the fronds aside (no full flattening;
		// fronds spring back quicker than grass, so only the live push + the freshest trail)
		vec3 root = MODEL_MATRIX[3].xyz;
		vec3 tl = trample_lay(root, 1.1);
		if (tl.z > 0.001) {
			vec3 rel = mat3(MODEL_MATRIX) * VERTEX;
			// fronds on the hero's side bend away most: weight by how much the frond
			// points toward the push origin
			vec2 rh = normalize(rel.xz + vec2(1e-4));
			float facing = clamp(0.5 - 0.5 * dot(rh, tl.xy), 0.0, 1.0);
			vec3 off = trample_fold(rel, tl.xy, tl.z * trample_gain * mix(0.35, 0.9, facing));
			VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
		}
	}
	v_phase = COLOR.g;
	v_occ = COLOR.b;
	v_inst = MODEL_MATRIX[3].xyz;
	v_cloud = cloud_shade_at((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	// per-instance and per-card variation so whole groves are not one colour
	float iv = fract(sin(dot(v_inst.xz, vec2(12.9898, 78.233))) * 43758.5453);
	float iv2 = fract(sin(dot(v_inst.xz, vec2(39.3468, 11.135))) * 24634.6345);
	// tree_var (oaks 1, ferns lower): each tree draws one of three leaf casts -- a deep
	// blue-green, a fresh yellow-green, an olive going bronze -- plus its own brightness,
	// so a wood reads as many crowns from 100 m, not one dark green mass
	vec3 cast_t = iv < 0.4 ? vec3(0.78, 0.95, 0.88) : (iv < 0.75 ? vec3(1.2, 1.22, 0.6) : vec3(1.32, 1.0, 0.55));
	// past ~60 m the mips and the haze average a crown toward the wood's mean, so the casts
	// open up a little more with distance to keep the crowns apart
	float far_k = 1.0 + 0.35 * smoothstep(60.0, 180.0, length(VERTEX));
	vec3 cast_v = mix(vec3(1.0), cast_t * mix(0.8, 1.14, iv2), clamp(tree_var * far_k, 0.0, 1.35));
	vec3 col = t.rgb * tint * mix(0.85, 1.15, v_phase) * cast_v;
	// sunlit skin: the outer, upward-facing leaves of the crown are young growth, paler and
	// yellower than the shaded core, which rounds the crown's top into a dome
	vec3 up_v = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float skin = (1.0 - v_occ) * smoothstep(0.05, 0.75, dot(FRONT_FACING ? NORMAL : -NORMAL, up_v)) * skin_gain;
	col *= mix(vec3(1.0), vec3(1.16, 1.14, 0.78), skin);
	ALBEDO = col;
	// alpha-tested cards thin out with distance: each mip averages the leaf alpha with the
	// gaps, so past ~40 m most texels fall under the 0.5 cut and a crown went see-through.
	// Scale alpha up by the mip level being sampled so the coverage holds (Golus).
	vec2 tsz = vec2(textureSize(leaf_tex, 0));
	vec2 ddx = dFdx(UV * tsz);
	vec2 ddy = dFdy(UV * tsz);
	float mip = max(0.0, 0.5 * log2(max(dot(ddx, ddx), dot(ddy, ddy))));
	ALPHA = t.a * (1.0 + mip * 0.25);
	NORMAL_MAP = texture(leaf_nrm, UV).rgb;
	NORMAL_MAP_DEPTH = nmap_depth;
	// inner crown: leaves under other leaves see little sky or sun (darker, a touch bluer
	// than the lit skin), so the crown reads as a volume
	col *= mix(vec3(1.0), vec3(0.88, 0.95, 1.0) * (1.0 - crown_occ), v_occ);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	float rough = 0.72;
	weather_wetten(col, rough, 0.3);
	ALBEDO = col;
	ROUGHNESS = rough;
	// Godot's Fresnel peak (f90) scales with f0 = 0.16 * SPECULAR^2: at 0.4 it clamps to 1, so
	// every sun-facing card went white at grazing angles looking toward the sun. 0.2 caps the
	// grazing sheen at ~0.3 (a waxy oak leaf, not a mirror).
	SPECULAR = 0.2;
	BACKLIGHT = backlight;
	if (!FRONT_FACING) NORMAL = -NORMAL;
	// a passing cloud takes the sun off the land
	ALBEDO *= v_cloud;   // (also dims the transmission: foliage_light scales by albedo)
	// inner crown: light scattered off the lit leaves and ground around it
	EMISSION = ALBEDO * bounce_light * fill;
	// outer crown: the same open-sky fill the ground takes, so at night the crowns stay a step above
	// the moonlit sward under them instead of sinking into it
	EMISSION += ALBEDO * ground_fill * crown_sky * (1.0 - v_occ);
}

void light() {
	foliage_light(NORMAL, LIGHT, VIEW, LIGHT_COLOR, ATTENUATION, LIGHT_IS_DIRECTIONAL,
		BACKLIGHT, fwd_gain, ROUGHNESS, SPECULAR_AMOUNT, 0.3, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
