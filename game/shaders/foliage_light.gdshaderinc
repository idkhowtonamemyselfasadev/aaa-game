// Shared light() for thin foliage (oak leaves, grass blades).
// Godot multiplies DIFFUSE_LIGHT by ALBEDO after the light loop, and its stock BACKLIGHT is
// multiplied by albedo again, so a leaf albedo of ~0.1 transmitted only ~1% of the sun and a
// crown seen against the sun went black. Here BACKLIGHT is a transmission *tint* (yellow-green
// gain on the albedo), with two lobes:
//   - diffuse transmission through the blade (wraps from the unlit side),
//   - a forward-scatter lobe when the view looks toward the light (the glow of a backlit crown).
// `soft` lets transmission leak through shadow: light that reached the inner leaves through
// several layers of leaves (a binary alpha-scissor shadow map has no partial cover).
// `fwd_gain` scales the forward-scatter lobe (2.2 for thin oak leaves and grass; a thick
// fern frond scatters far less forward and glowed as a bright fan against the sun).
void foliage_light(vec3 N, vec3 L, vec3 V, vec3 light_col, float atten, bool directional,
		vec3 trans, float fwd_gain, float rough, float spec_amount, float soft,
		inout vec3 diffuse, inout vec3 specular) {
	float ndl = dot(N, L);
	vec3 lc = light_col / PI;
	diffuse += max(ndl, 0.0) * atten * lc;
	float ta = directional ? mix(atten, 1.0, soft) : atten;
	float back = clamp(-ndl * 0.7 + 0.3, 0.0, 1.0);
	float fwd = pow(clamp(dot(-V, L), 0.0, 1.0), 5.0);
	diffuse += trans * (back * 0.55 + fwd * fwd_gain) * ta * lc;
	// normalised Blinn-Phong with a capped Fresnel (waxy, never a mirror at grazing angles)
	vec3 H = normalize(V + L);
	float r2 = max(rough * rough, 0.05);
	float n = 2.0 / (r2 * r2) - 2.0;
	float vh = clamp(dot(V, H), 0.0, 1.0);
	float F = 0.02 + 0.28 * pow(1.0 - vh, 5.0);
	float s = (n + 8.0) / (8.0 * PI) * pow(clamp(dot(N, H), 0.0, 1.0), n) * F;
	specular += s * max(ndl, 0.0) * atten * light_col * spec_amount;
}
