// Weather globals written by world/weather.gd every frame.
//   weather_wind: 0 the Vale's usual breeze .. 1 a storm front (each shader scales its own bend)
//   weather_wet : 0 dry .. 1 soaked (porous surfaces darken, everything turns glossier)
global uniform float weather_wind;
global uniform float weather_wet;

// darken + gloss a surface by wetness; `porous` 0 (rock, metal) .. 1 (soil, bark, dry grass)
void weather_wetten(inout vec3 albedo, inout float roughness, float porous) {
	float w = clamp(weather_wet, 0.0, 1.0);
	albedo *= mix(1.0, mix(0.82, 0.58, porous), w);
	roughness = mix(roughness, mix(0.3, 0.55, porous), w * 0.8);
}
