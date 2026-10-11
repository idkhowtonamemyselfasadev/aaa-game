// Weather globals written by world/weather.gd every frame.
//   weather_wind: 0 the Vale's usual breeze .. 1 a storm front (each shader scales its own bend)
//   weather_wet : 0 dry .. 1 soaked (porous surfaces darken, everything turns glossier)
//   weather_rain: 0 dry .. 1 downpour (raindrop ripples on standing water)
#include "res://shaders/cloud_shadow.gdshaderinc"

global uniform float weather_wind;
global uniform float weather_wet;
global uniform float weather_rain;

// darken + gloss a surface by wetness; `porous` 0 (rock, metal) .. 1 (soil, bark, dry grass)
void weather_wetten(inout vec3 albedo, inout float roughness, float porous) {
	float w = clamp(weather_wet, 0.0, 1.0);
	albedo *= mix(1.0, mix(0.82, 0.58, porous), w);
	roughness = mix(roughness, mix(0.3, 0.55, porous), w * 0.8);
}

float _drop_hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Raindrop rings on standing water at world position `xz` (metres), time `t`.
// Returns the surface slope (d height / dx, d height / dz) of all rings touching this
// point: one drop per 0.3 m cell per cycle, each ring spreading ~0.28 m and dying away.
// `rate` 0..1 thins the drops out (a few spots in drizzle, a boil in a downpour).
vec2 rain_ripples(vec2 xz, float t, float rate) {
	vec2 slope = vec2(0.0);
	for (int layer = 0; layer < 2; layer++) {
		vec2 q = xz / 0.3 + float(layer) * vec2(0.37, 0.61);
		vec2 base = floor(q);
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				vec2 cell = base + vec2(float(i), float(j));
				float h0 = _drop_hash(cell + float(layer) * 17.0);
				float h1 = _drop_hash(cell * 1.7 + 3.1);
				float h2 = _drop_hash(cell * 2.3 + 9.4);
				float period = 0.9 + 0.5 * h2;
				float cyc = t / period + h0;
				float age = fract(cyc);                        // 0..1 through this drop's life
				float alive = step(_drop_hash(cell + floor(cyc) * 0.73), rate);
				vec2 c = cell + 0.15 + 0.7 * vec2(h1, h2);
				vec2 d = q - c;
				float dist = length(d) * 0.3;                  // metres
				float rad = age * 0.28;
				float x = (dist - rad) * 60.0;                 // ~10 cm wavelength
				// a damped wave packet riding the front of the ring
				float env = exp(-x * x * 0.08) * (1.0 - age) * (1.0 - age);
				float w = cos(x) * env * alive;
				slope += normalize(d + 1e-5) * w;
			}
		}
	}
	return slope;
}
