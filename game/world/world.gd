extends Node3D
## Harrowmere Vale slice root: builds the Environment (sky, GI, post), drives day/night,
## and places the player on the terrain.

@export var day_length_s: float = 1200.0        # 20 real minutes per day
@export var time_of_day: float = 17.25           # hours, 0..24; starts at the Long Dusk
@export var run_clock: bool = true

@onready var sun: DirectionalLight3D = $Sun
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var terrain: Terrain = $Terrain
@onready var player: Player = $Player

func _ready() -> void:
	_build_environment()
	_apply_time()
	var p := player.global_position
	player.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.5, p.z)

func _build_environment() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := PhysicalSkyMaterial.new()
	sm.rayleigh_coefficient = 2.4
	sm.rayleigh_color = Color(0.26, 0.41, 0.58)
	sm.mie_coefficient = 0.012
	sm.mie_eccentricity = 0.84
	sm.mie_color = Color(0.69, 0.68, 0.6)
	sm.turbidity = 12.0
	sm.sun_disk_scale = 3.0
	sm.ground_color = Color(0.1, 0.07, 0.034)
	sky.sky_material = sm
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# tonemap + exposure
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.85
	e.tonemap_white = 6.0
	# GI
	e.sdfgi_enabled = true
	e.sdfgi_use_occlusion = true
	e.sdfgi_cascades = 4
	e.sdfgi_min_cell_size = 0.3
	e.sdfgi_bounce_feedback = 0.5
	e.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	e.ssao_enabled = true
	e.ssao_radius = 1.5
	e.ssao_intensity = 2.5
	e.ssil_enabled = true
	# bloom
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_strength = 0.9
	e.glow_bloom = 0.08
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.glow_hdr_threshold = 1.0
	# fog: aerial perspective + ground volumetrics
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color(0.73, 0.6, 0.5)
	e.fog_light_energy = 0.6
	e.fog_sun_scatter = 0.15
	e.fog_density = 0.0005
	e.fog_aerial_perspective = 0.5
	e.fog_sky_affect = 0.4
	e.fog_height = -10.0
	e.fog_height_density = 0.0
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.002
	e.volumetric_fog_albedo = Color(0.9, 0.8, 0.7)
	e.volumetric_fog_emission = Color(0.03, 0.02, 0.015)
	e.volumetric_fog_length = 220.0
	e.volumetric_fog_anisotropy = 0.6
	e.volumetric_fog_sky_affect = 0.3
	# grading
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	env.environment = e

func _process(delta: float) -> void:
	if run_clock:
		time_of_day = fposmod(time_of_day + delta * 24.0 / day_length_s, 24.0)
	_apply_time()

func _apply_time() -> void:
	# The sun in Emberfall never climbs high: "Long Dusk" arc, max ~18 degrees elevation.
	var t := time_of_day / 24.0
	var az := t * TAU - PI * 0.5
	var elev := deg_to_rad(lerpf(-12.0, 18.0, 0.5 - 0.5 * cos(t * TAU)))
	sun.rotation = Vector3(-elev, az, 0.0)
	var day := clampf(sin(elev) * 6.0 + 0.5, 0.0, 1.0)
	sun.light_energy = lerpf(0.05, 3.2, day)
	sun.light_color = Color(1.0, 0.72, 0.45).lerp(Color(1.0, 0.93, 0.85), day * 0.6)
	if env.environment:
		var sky := env.environment.sky.sky_material as PhysicalSkyMaterial
		if sky:
			sky.energy_multiplier = lerpf(0.15, 1.0, day)
		env.environment.ambient_light_energy = lerpf(0.15, 1.0, day)
		env.environment.volumetric_fog_density = lerpf(0.008, 0.003, day)
