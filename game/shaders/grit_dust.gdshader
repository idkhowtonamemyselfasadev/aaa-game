shader_type spatial;
// Lit airborne puffs: the pale dust curtain a heaving standing stone sheds (GritFall) and the soot
// plume off the knight's fire columns (AshFlame). Soft particle
// billboards lit like real airborne dust: a little wrapped diffuse from the sun's side and a strong
// forward-scattering lobe, so dust between the lens and the sun glows pale gold instead of drawing
// as a black hole (a flat camera-facing quad lit from behind takes only ambient). Puffs fade out as
// they near the lens (never a smear across the frame) and where they meet the ground.
// COLOR: the particle colour ramp (rgb tint, a = life fade). INSTANCE_CUSTOM.x: spin.
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

uniform sampler2D puff_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float near_fade_start = 1.5;   // m from the lens: fully gone at this depth
uniform float near_fade_end = 5.0;     // m: fully there beyond this
uniform float ground_fade = 0.35;      // m of soft fade into whatever is behind the puff
uniform float scatter_g = 0.5;         // forward-scatter anisotropy (0 = isotropic)
uniform float scatter_gain = 0.45;     // share of the forward lobe on top of the wrapped diffuse
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying float v_depth;

void vertex() {
	// camera-facing billboard keeping the particle's scale, spun about the view axis
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]),
		normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	w = w * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0),
		vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * w;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	vec4 t = texture(puff_tex, UV);
	ALBEDO = t.rgb * pow(COLOR.rgb, vec3(2.2));   // the ramp is authored in sRGB
	ROUGHNESS = 1.0;
	float a = t.a * COLOR.a;
	// never across the lens
	a *= smoothstep(near_fade_start, near_fade_end, v_depth);
	// soft where it meets the turf or a stone
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	float scene_z = -p.z / p.w;
	a *= clamp((scene_z - (-VERTEX.z)) / ground_fade, 0.0, 1.0);
	ALPHA = a;
	NORMAL = VIEW;    // a puff is a volume, not a card: shade it as seen
}

void light() {
	// wrapped diffuse: a volume of dust is lit through, not just on its sunward face
	float wrap = clamp((dot(NORMAL, LIGHT) + 0.6) / 1.6, 0.0, 1.0);
	// Henyey-Greenstein forward lobe, normalised so isotropic = 1 (theta between light and view ray)
	float c = dot(LIGHT, -VIEW);
	float g = scatter_g;
	float hg = (1.0 - g * g) / pow(max(1.0 + g * g - 2.0 * g * c, 1e-3), 1.5);
	float lobe = min(hg, 4.0);
	// the lobe is the sun's (or moon's) through the haze; a near fire or ember light only warms the
	// puff's facing side a little, or every column by the boss turns into an orange torch
	float k = LIGHT_IS_DIRECTIONAL ? (wrap * (1.0 - scatter_gain) + lobe * scatter_gain) : wrap * 0.35;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * k / PI;
}
