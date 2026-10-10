extends Node3D
## Harrowmere Vale slice root: builds the Environment (sky, GI, post), drives day/night,
## and places the player on the terrain.

@export var day_length_s: float = 1200.0        # 20 real minutes per day
@export var time_of_day: float = 17.25           # hours, 0..24; starts in the evening
@export var run_clock: bool = true
@export var sun_peak_deg: float = 28.0           # Long Dusk: low amber days, noon sun ~28 degrees
@export var sky_energy_scale: float = 2.6        # PhysicalSky is calibrated for a ~1.0 sun; ours is 3.0
@export var ambient_scale: float = 1.0
@export var sdfgi_allowed: bool = true            # quality setting; auto-off on software GPUs

@onready var sun: DirectionalLight3D = $Sun
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var terrain: Terrain = $Terrain
@onready var player: Player = $Player
var moon: DirectionalLight3D
var training_post: TrainingPost
var _stars: ImageTexture

func _ready() -> void:
	_build_environment()
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 150.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	_apply_time()
	var p := player.global_position
	player.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.5, p.z)
	# a practice post planted just ahead of the start: the first thing to hit with the staff
	training_post = TrainingPost.new()
	training_post.name = "TrainingPost"
	add_child(training_post)
	training_post.global_position = Vector3(p.x + 0.15, 0.0, p.z + 1.45)
	training_post.plant(terrain)

func _build_environment() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := PhysicalSkyMaterial.new()
	sm.rayleigh_coefficient = 2.4
	sm.rayleigh_color = Color(0.22, 0.40, 0.66)
	sm.mie_coefficient = 0.012
	sm.mie_eccentricity = 0.84
	sm.mie_color = Color(0.86, 0.72, 0.55)
	sm.turbidity = 7.0
	sm.sun_disk_scale = 3.0
	sm.ground_color = Color(0.1, 0.07, 0.034)
	_stars = _star_texture()
	sky.sky_material = sm
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# tonemap + exposure
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.85
	e.tonemap_white = 6.0
	# GI
	# SDFGI replaces the ambient term. On software Vulkan (lavapipe/llvmpipe, the cloud
	# screenshot box) its indirect light measures ~0 in shadow and every shadowed surface
	# renders pure black, so it stays off there; real GPUs keep it.
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	e.sdfgi_enabled = sdfgi_allowed and not (adapter.contains("llvmpipe") or adapter.contains("lavapipe"))
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
	e.fog_density = 0.0012
	e.fog_aerial_perspective = 0.5
	e.fog_sky_affect = 0.12
	e.fog_height = -10.0
	e.fog_height_density = 0.0
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.002
	e.volumetric_fog_albedo = Color(0.9, 0.8, 0.7)
	e.volumetric_fog_emission = Color(0.03, 0.02, 0.015)
	e.volumetric_fog_length = 128.0
	e.volumetric_fog_anisotropy = 0.6
	e.volumetric_fog_sky_affect = 0.1
	# grading
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.08
	env.environment = e

## Procedural star field for the PhysicalSky's night_sky (equirectangular, 2048x1024).
func _star_texture() -> ImageTexture:
	var w := 2048
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.004, 0.006, 0.012))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 4200:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h / 2 + 40)     # upper hemisphere (+ a bit below horizon)
		var b := pow(rng.randf(), 6.0) * 0.9 + 0.05
		var tint := Color(0.8, 0.85, 1.0).lerp(Color(1.0, 0.85, 0.7), rng.randf())
		img.set_pixel(x, y, tint * b)
	# a faint band for the galaxy
	for i in 26000:
		var x := rng.randi_range(0, w - 1)
		var y := int(h * 0.28 + sin(float(x) / w * TAU) * h * 0.12 + rng.randfn(0.0, 22.0))
		if y >= 0 and y < h:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c + Color(0.02, 0.022, 0.03) * rng.randf())
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	if run_clock:
		time_of_day = fposmod(time_of_day + delta * 24.0 / day_length_s, 24.0)
	_apply_time()

func _apply_time() -> void:
	# Full day: sunrise 06:00, noon peak sun_peak_deg, sunset 18:00; the moon opposes the sun.
	var t := time_of_day / 24.0
	var az := t * TAU + PI * 0.5
	var elev := deg_to_rad(sun_peak_deg) * sin((time_of_day - 6.0) / 12.0 * PI)
	sun.rotation = Vector3(-elev, az, 0.0)
	var day := clampf(sin(elev) * 5.0 + 0.35, 0.0, 1.0)       # 0 night .. 1 full day
	var low := 1.0 - clampf(sin(elev) / sin(deg_to_rad(25.0)), 0.0, 1.0)   # 1 near horizon
	sun.visible = elev > deg_to_rad(-6.0)
	sun.light_energy = lerpf(0.0, 3.0, day) * lerpf(1.0, 0.7, low)
	sun.light_color = Color(1.0, 0.93, 0.84).lerp(Color(1.0, 0.62, 0.36), low)
	if moon:
		var melev := -elev * 0.8
		moon.rotation = Vector3(-maxf(melev, deg_to_rad(8.0)), az + PI, 0.0)
		var night := 1.0 - clampf(sin(elev) * 5.0 + 1.0, 0.0, 1.0)
		moon.light_energy = 0.8 * night
		moon.visible = night > 0.01
	if env.environment:
		var sky := env.environment.sky.sky_material as PhysicalSkyMaterial
		if sky:
			# Only write the sky material when a value really changes: every write marks the
			# sky dirty and restarts its incremental radiance bake.
			var ener := snappedf(lerpf(0.35, 1.0, day) * sky_energy_scale, 0.02)
			if not is_equal_approx(sky.energy_multiplier, ener):
				sky.energy_multiplier = ener
			# PhysicalSky adds night_sky unattenuated, so only bind the stars after dusk
			var want_stars: Texture2D = _stars if day < 0.08 else null
			if sky.night_sky != want_stars:
				sky.night_sky = want_stars
		# Ambient is a time-of-day colour, not the sky radiance: sky-sourced ambient measured
		# ~0 in shadow (x4 energy changed nothing), so every shadowed surface went black.
		# Day: blue-grey skylight that warms toward dusk; night: cool moonlit blue.
		var sky_amb := Color(0.46, 0.53, 0.66).lerp(Color(0.56, 0.46, 0.42), low)
		env.environment.ambient_light_color = Color(0.13, 0.17, 0.27).lerp(sky_amb, day)
		env.environment.ambient_light_energy = lerpf(1.0, 1.15, day) * ambient_scale
		# volumetrics only for local ground haze; distance haze is the depth fog (a dense
		# volume ends at volumetric_fog_length and leaves a visible band on far ridges)
		env.environment.volumetric_fog_density = lerpf(0.0025, 0.0007, day)
		env.environment.tonemap_exposure = lerpf(1.6, 0.85, day)
		# fog takes the sky's mood: warm haze by day, dark blue at night, no self-glow at night
		env.environment.fog_light_color = Color(0.05, 0.07, 0.11).lerp(Color(0.73, 0.6, 0.5), day)
		env.environment.volumetric_fog_albedo = Color(0.6, 0.7, 0.9).lerp(Color(0.9, 0.8, 0.7), day)
		env.environment.volumetric_fog_emission = Color(0.03, 0.02, 0.015) * day
