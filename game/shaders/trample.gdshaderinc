// Plants that react to the hero (world/trample.gd writes the globals every frame).
//   trample_body : xyz the hero's feet, w 0 no hero, 1 hero airborne, 2 hero on the ground
//   trample_trail: 32x2 RGBA float texture, one column per footfall of the recent trail
//                  row 0 (x, z, age s, strength 0..1), row 1 (walk dir x, z, 0, 0)
// Grass and flowers right where the hero stands are parted aside by the legs; behind them
// the sward stays laid over along the walk and springs back over TRAMPLE_LIFE seconds.
global uniform vec4 trample_body;
global uniform sampler2D trample_trail : filter_nearest, repeat_disable;

const int TRAMPLE_N = 32;
const float TRAMPLE_LIFE = 9.0;

// Lay-over for a plant rooted at `root`: xy direction (unit-ish) * amount, z = 0..1 how
// far it is pushed over. `reach` is the radius a footfall flattens (m).
vec3 trample_lay(vec3 root, float reach) {
	if (trample_body.w < 0.5) {
		return vec3(0.0);
	}
	float grounded = step(1.5, trample_body.w);
	vec2 dh = root.xz - trample_body.xz;
	float d2 = dot(dh, dh);
	if (d2 > 484.0) {   // the trail reaches ~19 m behind the hero
		return vec3(0.0);
	}
	// the legs part the plants round the hero (only when the feet are near the ground)
	float dl = sqrt(d2);
	float near = (1.0 - smoothstep(0.5, 1.6, abs(root.y - trample_body.y))) * grounded;
	float live = (1.0 - smoothstep(0.2, reach + 0.25, dl)) * near;
	vec2 lay = (dl > 1e-3 ? dh / dl : vec2(1.0, 0.0)) * live;
	float amt = live;
	for (int i = 0; i < TRAMPLE_N; i++) {
		vec4 a = texelFetch(trample_trail, ivec2(i, 0), 0);
		if (a.w <= 0.0) {
			continue;
		}
		vec2 d = root.xz - a.xy;
		float r2 = dot(d, d);
		if (r2 > reach * reach) {
			continue;
		}
		vec2 dir = texelFetch(trample_trail, ivec2(i, 1), 0).xy;
		// fully laid within a fraction of a second, lying a few seconds, then springing
		// back up (the last tilt lingers)
		float t = a.z / TRAMPLE_LIFE;
		float rec = smoothstep(0.0, 0.08, a.z) * (1.0 - smoothstep(0.1, 1.0, t));
		float k = (1.0 - smoothstep(reach * 0.35, reach, sqrt(r2))) * rec * a.w;
		// laid along the walk, a little outward from the footprint's centre line
		vec2 side = d - dot(d, dir) * dir;
		float sl = length(side);
		vec2 out_dir = sl > 1e-3 ? side / sl : vec2(0.0);
		lay += (dir * 0.85 + out_dir * 0.5) * k;
		amt = max(amt, k);
	}
	float ll = length(lay);
	vec2 ldir = ll > 1e-3 ? lay / ll : vec2(0.0);
	return vec3(ldir, clamp(amt, 0.0, 1.0));
}

// World-space offset that tips the point `rel` (relative to the root) over by angle
// `ang` toward `dir`: a rigid fold at the root, which keeps the stem's length.
vec3 trample_fold(vec3 rel, vec2 dir, float ang) {
	float y = max(rel.y, 0.0);
	return vec3(dir.x, 0.0, dir.y) * y * sin(ang) + vec3(0.0, y * (cos(ang) - 1.0), 0.0);
}
