// Rain soaking an actor's surfaces (hero, Hollows, their gear). world/soak.gd drives:
//   soak      : 0 dry .. 1 drenched (rises while it rains on the actor, dries slowly after)
//   wade_soak : 0 .. 1 how wet the legs are from wading through pools
//   wade_line : world height the pool water has soaked the legs up to
// Water fills the pores of cloth, wood and skin, so they darken and their sheen tightens;
// metal only takes a thin film (smoother, barely darker). Shoulders, crown and the tops of
// folds soak first; undersides last. Call from fragment() with the world normal/position:
//   vec3 wn = mat3(INV_VIEW_MATRIX) * NORMAL;
//   vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
uniform float soak = 0.0;
uniform float wade_soak = 0.0;
uniform float wade_line = -10000.0;

// how wet this point is, 0..1. `patch` (0..1 noise from the caller's own texture space)
// breaks the soak into blotches as it spreads, so the cloth doesn't darken in one sheet.
float wet_amount(vec3 wn, vec3 wp, float patch_n) {
	float up = clamp(wn.y, -1.0, 1.0);
	// rain lands on the up-facing parts first; undersides wick it up later
	float reach = soak * 1.5 - 0.5 * (0.5 - 0.5 * up) - 0.35 * (1.0 - patch_n);
	float w = smoothstep(0.0, 0.35, reach);
	// wading: the shins soak up to the water line, the cloth wicks a hand's width above it
	float line = wade_line + 0.06 * (patch_n - 0.5);
	w = max(w, wade_soak * (1.0 - smoothstep(line - 0.06, line + 0.04, wp.y)));
	return clamp(w, 0.0, 1.0);
}

// porous: 1 cloth/wood/skin .. 0 bare metal
void wet_apply(inout vec3 alb, inout float rough, float w, float porous) {
	// darkening: soaked cloth loses ~half its albedo (more for light cloth), metal ~10 %
	float lum = dot(alb, vec3(0.3, 0.59, 0.11));
	float dark = mix(0.9, mix(0.62, 0.45, smoothstep(0.1, 0.5, lum)), porous);
	alb *= mix(1.0, dark, w);
	// a water film: smoother; cloth never turns mirror-like (the weave breaks the film)
	rough = mix(rough, min(rough, mix(0.12, 0.42, porous)), w);
}
