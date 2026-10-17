extends Node3D
## Harrowmere Vale slice root: builds the Environment (sky, GI, post), drives day/night,
## and places the player on the terrain.

@export var day_length_s: float = 1200.0        # 20 real minutes per day
@export var time_of_day: float = 17.25           # hours, 0..24; starts in the evening
@export var run_clock: bool = true
@export var sun_peak_deg: float = 28.0           # Long Dusk: low amber days, noon sun ~28 degrees
@export var sky_energy_scale: float = 2.6        # PhysicalSky is calibrated for a ~1.0 sun; ours is 3.0
@export var ambient_scale: float = 1.0
@export var cloud_light: float = 0.6             # cloud deck brightness under the light
@export var cloud_shade: float = 0.7             # cloud underside brightness from the skylight
@export var sdfgi_allowed: bool = true            # quality setting; auto-off on software GPUs

@onready var sun: DirectionalLight3D = $Sun
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var terrain: Terrain = $Terrain
@onready var player: Player = $Player
var moon: DirectionalLight3D
var sky_sun: DirectionalLight3D   # drives the PhysicalSky only; held above the horizon at twilight
var training_post: TrainingPost
var soldier: HollowSoldier
var weather: Weather
var clouds: CloudLayer
var trample: Trample
var herd: Herd
var keeper: Keeper
var hearth: Hearth
var fox: Fox
var soundscape: Soundscape
var foley: Foley
var audio_mix: AudioMix
var pause_menu: PauseMenu
var graphics: GraphicsQuality
var grade: ShaderMaterial         # final film grade + grain (ColorRect under the HUD)
var _stars: Array[ImageTexture] = []     # star field at rising brightness (twilight fade-in)
var face_shade := Color(0, 0, 0)    # shade light under the brim: feeds the hero's face fill
const STAR_LEVELS := [0.12, 0.3, 0.55, 1.0]

func _ready() -> void:
	_build_environment()
	weather = Weather.new()
	weather.name = "Weather"
	add_child(weather)
	clouds = CloudLayer.new()
	clouds.name = "Clouds"
	add_child(clouds)
	trample = Trample.new()
	trample.name = "Trample"
	trample.player = player
	add_child(trample)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 150.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	# PhysicalSky scatters only a sun above the horizon (its energy term is 1-exp(-elevation)),
	# so the sky went pure black the moment the sun set while the ground was still lit. The
	# real sun now lights the world only; this sky-only light paints the sky, and through
	# twilight it stays just above the horizon (no disc) and fades out as the sun sinks.
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sky_sun = DirectionalLight3D.new()
	sky_sun.name = "SkySun"
	sky_sun.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	sky_sun.shadow_enabled = false
	sky_sun.light_cull_mask = 0
	add_child(sky_sun)
	_build_grade()
	_apply_time()
	var p := player.global_position
	player.global_position = Vector3(p.x, terrain.height_at(p.x, p.z) + 0.5, p.z)
	# the start is the first rest point: a fallen hero wakes here
	player.respawn_point = player.global_position
	player.respawn_yaw = player.body.rotation.y
	player.respawned.connect(_on_player_respawned)
	# a practice post planted just ahead of the start: the first thing to hit with the staff
	training_post = TrainingPost.new()
	training_post.name = "TrainingPost"
	add_child(training_post)
	training_post.global_position = Vector3(p.x + 0.15, 0.0, p.z + 1.45)
	training_post.plant(terrain)
	# the first Hollow: a spear soldier keeping watch down the meadow, out of the start's way
	soldier = HollowSoldier.new()
	soldier.name = "HollowSoldier"
	soldier.position = Vector3(p.x + 6.0, 0.0, p.z + 19.0)   # world sits at the origin
	add_child(soldier)
	soldier.plant(terrain)
	soldier.face(p)
	trample.walkers.append(soldier)   # the Hollow tramples the sward and leaves prints too
	# red deer grazing the open meadow out from the start
	herd = Herd.new()
	herd.name = "Herd"
	add_child(herd)
	# Hesper, the shrine keeper living in the ruined keep, keeping her day by the clock
	keeper = Keeper.new()
	keeper.name = "Keeper"
	# enter the tree at the keep: at the origin her collider would land on the hero's start
	keeper.position = (get_node("Ruins") as Ruins).site + Vector3.UP
	add_child(keeper)
	keeper.settle(self, time_of_day)
	trample.walkers.append(keeper)
	herd.familiar = keeper
	# her cookfire on the keep floor beside her bed, kept by the clock
	hearth = Hearth.new()
	hearth.setup(self, keeper.hearth_at)
	# a fox that comes in out of the dark to sit at the edge of her firelight
	fox = Fox.new()
	fox.setup(self)
	# the mix: per-layer buses and the stone reverb inside the keep
	audio_mix = AudioMix.new()
	audio_mix.name = "AudioMix"
	audio_mix.world = self
	add_child(audio_mix)
	# the picture preset and FSR 2 render scale (after the Environment is built)
	graphics = GraphicsQuality.new()
	graphics.name = "Graphics"
	graphics.world = self
	add_child(graphics)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.mix = audio_mix
	pause_menu.graphics = graphics
	add_child(pause_menu)
	# wind, rain, birdsong, crickets, rook calls and thunder, mixed by clock and weather
	soundscape = Soundscape.new()
	soundscape.name = "Soundscape"
	soundscape.world = self
	soundscape.weather = weather
	soundscape.birds = get_node_or_null("Birds")
	add_child(soundscape)
	# staff swishes, impacts, parry clangs, dodges and footfalls
	foley = Foley.new()
	foley.name = "Foley"
	foley.world = self
	foley.weather = weather
	add_child(foley)
	foley.hook(player, [soldier], trample)
	foley.hook_herd(herd)

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
	for lv in STAR_LEVELS:
		_stars.append(_star_texture(lv))
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
	# screen-space reflections: rain pools mirror the trees, tufts and the hero
	e.ssr_enabled = true
	e.ssr_max_steps = 64
	e.ssr_fade_in = 0.15
	e.ssr_fade_out = 2.0
	e.ssr_depth_tolerance = 0.3
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

## Procedural star field for the PhysicalSky's night_sky (equirectangular, 2048x1024), scaled
## by `level`: PhysicalSky has no night-sky energy, so the fade-in swaps between a few copies.
func _star_texture(level: float) -> ImageTexture:
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
		# cool-leaning: PhysicalSky's extinction term already tints the field gold
		var tint := Color(0.7, 0.8, 1.0).lerp(Color(1.0, 0.9, 0.8), rng.randf() * 0.6)
		img.set_pixel(x, y, tint * b * level)
	# a faint band for the galaxy
	for i in 26000:
		var x := rng.randi_range(0, w - 1)
		var y := int(h * 0.28 + sin(float(x) / w * TAU) * h * 0.12 + rng.randfn(0.0, 22.0))
		if y >= 0 and y < h:
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c + Color(0.017, 0.021, 0.032) * rng.randf() * level)
	return ImageTexture.create_from_image(img)

## Film grade over the finished frame: split tone by day, scotopic blue-grey by night, vignette
## and grain. A canvas pass (after tonemap and TAA, so the grain is not smeared), under the HUD.
func _build_grade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Grade"
	layer.layer = -1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade = ShaderMaterial.new()
	grade.shader = preload("res://shaders/grade.gdshader")
	rect.material = grade
	layer.add_child(rect)
	add_child(layer)

func _process(delta: float) -> void:
	if run_clock:
		time_of_day = fposmod(time_of_day + delta * 24.0 / day_length_s, 24.0)
	_apply_time()
	_apply_clouds(delta)

## Feed the cloud deck this frame's light: the sky sun by day (it is held up through the
## afterglow, so sunset clouds glow rose), the moon by night; shadowed undersides take the
## ambient skylight, the far deck fades into the fog colour.
func _apply_clouds(delta: float) -> void:
	if clouds == null or env.environment == null:
		return
	var e := env.environment
	var sw := sky_sun.light_energy if sky_sun and sky_sun.visible else 0.0
	var mw := moon.light_energy if moon and moon.visible else 0.0
	var ldir := Vector3.UP
	var lcol := Color(0, 0, 0)
	if sw > 0.0:
		ldir = sky_sun.global_transform.basis.z
		lcol += sky_sun.light_color * sw * cloud_light
	if mw > 0.0:
		ldir = ldir.lerp(moon.global_transform.basis.z, mw / (mw + sw * 4.0 + 1e-4)).normalized()
		lcol += moon.light_color * mw * 0.35 * cloud_light
	var shade := e.ambient_light_color * e.ambient_light_energy * cloud_shade
	var haze := e.fog_light_color * e.fog_light_energy   # what the depth fog paints far ridges
	clouds.update(delta, weather.cloud if weather else 0.0, weather.wind if weather else 0.0,
			ldir, lcol, shade, haze)
	# cloud shadows sweep the land while the sun is strong; under a closing deck the whole
	# Vale is in shade already (the sun is dimmed in _apply_weather), so they fade out
	var c := weather.cloud if weather else 0.0
	var sun_e := sun.light_energy if sun.visible else 0.0
	clouds.set_shadow(sun.global_transform.basis.z,
			clampf(sun_e / 2.4, 0.0, 1.0) * (1.0 - smoothstep(0.45, 0.9, c)))
	# puddles mirror the sky: the haze colour stands in for the (mesh) cloud deck the sky
	# radiance cannot see
	var tm := terrain.material as ShaderMaterial
	if tm:
		tm.set_shader_parameter("puddle_sky", haze)

func _apply_time() -> void:
	# Full day: sunrise 06:00, noon peak sun_peak_deg, sunset 18:00; the moon opposes the sun.
	var t := time_of_day / 24.0
	var az := t * TAU + PI * 0.5
	var elev := deg_to_rad(sun_peak_deg) * sin((time_of_day - 6.0) / 12.0 * PI)
	var day := clampf(sin(elev) * 5.0 + 0.35, 0.0, 1.0)       # 0 night .. 1 full day
	var low := 1.0 - clampf(sin(elev) / sin(deg_to_rad(25.0)), 0.0, 1.0)   # 1 near horizon
	# afterglow: 1 while the sun is up .. 0 at 9 degrees below the horizon
	var afterglow := smoothstep(deg_to_rad(-9.0), deg_to_rad(0.5), elev)
	# a sun under the horizon lights nothing directly (it used to wash the dusk meadow red);
	# what stays is a faint rose glow from the sunset side, grazing from 1 deg up, dying with
	# the afterglow (without it the land under the sunset went black)
	var above := smoothstep(deg_to_rad(-1.0), deg_to_rad(1.5), elev)
	sun.rotation = Vector3(-maxf(elev, deg_to_rad(1.0)) if above < 1.0 else -elev, az, 0.0)
	sun.light_energy = lerpf(0.0, 3.0, day) * lerpf(1.0, 0.7, low) * above \
			+ 0.4 * afterglow * afterglow * (1.0 - above)
	sun.visible = sun.light_energy > 0.005
	# low sun: a warm gold, not a red wash (the red-brown ground saturates it further);
	# the rose grazing light under the horizon is a dusty mauve for the same reason
	sun.light_color = Color(1.0, 0.93, 0.84).lerp(Color(1.0, 0.76, 0.56), low) \
			.lerp(Color(0.84, 0.7, 0.72), 1.0 - above)
	if sky_sun:
		# twilight: 0 at 9 degrees below the horizon, 1 once the sun is up
		var tw := smoothstep(deg_to_rad(-9.0), deg_to_rad(0.5), elev)
		var floor_elev := deg_to_rad(2.5)
		var sky_elev := maxf(elev, floor_elev)
		sky_sun.rotation = Vector3(-sky_elev, az, 0.0)
		# PhysicalSky's sun energy is ~(1-exp(-elev)): hold the afterglow up while the light
		# sits on its floor, then let it die away into the blue hour
		var under := clampf((floor_elev - elev) / deg_to_rad(9.0), 0.0, 1.0)
		sky_sun.light_energy = 3.0 * tw * lerpf(1.0, 1.6, under)
		# the afterglow cools from amber to the blue hour as the sun sinks (ozone blue)
		sky_sun.light_color = Color(1.0, 0.93, 0.84).lerp(Color(1.0, 0.55, 0.42), low) \
				.lerp(Color(0.62, 0.64, 1.0), smoothstep(0.25, 0.9, under))
		# the disc goes when the real sun is gone; only its glow stays
		sky_sun.light_angular_distance = sun.light_angular_distance * above
		sky_sun.visible = tw > 0.0
	if moon:
		var melev := -elev * 0.8
		moon.rotation = Vector3(-maxf(melev, deg_to_rad(8.0)), az + PI, 0.0)
		var night := 1.0 - clampf(sin(elev) * 5.0 + 1.0, 0.0, 1.0)
		# a strong key against a dark ambient: moonlit grass tops and faces read silver over
		# deep blue shadow (at 0.8 over a bright ambient the meadow was one grey wash)
		moon.light_energy = 1.25 * night
		moon.visible = night > 0.01
	if env.environment:
		var sky := env.environment.sky.sky_material as PhysicalSkyMaterial
		if sky:
			# Only write the sky material when a value really changes: every write marks the
			# sky dirty and restarts its incremental radiance bake.
			var overcast := snappedf(weather.cloud, 0.02) if weather else 0.0
			var ener := snappedf(lerpf(0.35, 1.0, day) * sky_energy_scale * lerpf(1.0, 0.6, overcast), 0.02)
			if not is_equal_approx(sky.energy_multiplier, ener):
				sky.energy_multiplier = ener
			# PhysicalSky adds night_sky unattenuated, so the stars come out step by step from
			# 3 deg below the horizon (first stars) to 10 deg (full field), same at dawn
			var star_t := smoothstep(deg_to_rad(-3.0), deg_to_rad(-10.0), elev)
			var lvl := int(floor(star_t * STAR_LEVELS.size() + 0.25))
			var want_stars: Texture2D = _stars[lvl - 1] if lvl > 0 and not _stars.is_empty() else null
			if sky.night_sky != want_stars:
				sky.night_sky = want_stars
		# Ambient is a time-of-day colour, not the sky radiance: sky-sourced ambient measured
		# ~0 in shadow (x4 energy changed nothing), so every shadowed surface went black.
		# Day: blue-grey skylight that warms toward dusk; night: cool moonlit blue.
		var sky_amb := Color(0.46, 0.53, 0.66).lerp(Color(0.56, 0.46, 0.42), low)
		# the afterglow sky still lights the land through twilight
		# night ambient is a dim deep blue so the moon, not the fill, models the land
		env.environment.ambient_light_color = Color(0.075, 0.105, 0.2).lerp(sky_amb, maxf(day, 0.8 * afterglow))
		env.environment.ambient_light_energy = lerpf(1.0, 1.15, day) * ambient_scale
		# volumetrics only for local ground haze; distance haze is the depth fog (a dense
		# volume ends at volumetric_fog_length and leaves a visible band on far ridges)
		env.environment.volumetric_fog_density = lerpf(0.0025, 0.0007, day)
		env.environment.tonemap_exposure = lerpf(1.6, 0.85, day)
		# fog takes the sky's mood: warm haze by day, dark blue at night, no self-glow at night
		env.environment.fog_light_color = Color(0.05, 0.07, 0.11).lerp(Color(0.73, 0.6, 0.5), day)
		env.environment.volumetric_fog_albedo = Color(0.6, 0.7, 0.9).lerp(Color(0.9, 0.8, 0.7), day)
		env.environment.volumetric_fog_emission = Color(0.03, 0.02, 0.015) * day
		# The moonlit volumetric haze is local (128 m), so it lies in front of the sky exactly
		# as it lies in front of the far ridges: at the default 0.1 sky affect the fogged ridges
		# glowed blue as a cut-out against a black sky. Full sky affect at night, light by day.
		# Keyed to twilight depth, not `day`: day is ~0.1 right at sunset, which buried the
		# afterglow under the dark haze; the haze takes the sky over only late in twilight.
		env.environment.volumetric_fog_sky_affect = lerpf(1.0, 0.1, smoothstep(deg_to_rad(-9.0), deg_to_rad(-3.0), elev))
		if grade:
			# rods take over as the sky darkens: none at sunset, full by nautical dusk
			grade.set_shader_parameter("night", smoothstep(deg_to_rad(-2.0), deg_to_rad(-12.0), elev))
		# the far mountain ring sinks into a dark silhouette over the same twilight
		var hz := get_node_or_null("Horizon/Mesh") as MeshInstance3D
		if hz and hz.mesh and hz.mesh.surface_get_material(0) is ShaderMaterial:
			# keyed to the moon's own ramp (1 - sin*5 - 1): with the old -3..-12 deg ramp the
			# ring was still at full value at 18:50 (-5.8 deg) while the low moon (8 deg floor)
			# lit its faces head-on and the snow glowed pale over a black valley
			(hz.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("night",
					smoothstep(0.0, 1.0, 1.0 - clampf(sin(elev) * 5.0 + 1.0, 0.0, 1.0)))
		_apply_weather(day)

## A weather front over the time-of-day light: cloud swallows the sun and the sky's blue,
## the light goes flat and grey, rain haze closes the distance, colour drains.
func _apply_weather(day: float) -> void:
	var c := weather.cloud if weather else 0.0
	var e := env.environment
	if grade:
		grade.set_shader_parameter("overcast", c)
	sun.light_energy *= 1.0 - 0.82 * c
	sun.visible = sun.light_energy > 0.005
	if moon:
		moon.light_energy *= 1.0 - 0.85 * c
	if sky_sun:
		sky_sun.light_energy *= 1.0 - 0.55 * c
	var sky := e.sky.sky_material as PhysicalSkyMaterial
	if sky:
		# overcast: Mie haze everywhere (forward peak flattened), less Rayleigh blue, darker
		var cs := snappedf(c, 0.02)
		_set_sky(sky, "mie_coefficient", lerpf(0.012, 0.09, cs))
		_set_sky(sky, "mie_eccentricity", lerpf(0.84, 0.35, cs))
		_set_sky(sky, "rayleigh_coefficient", lerpf(2.4, 0.9, cs))
		_set_sky(sky, "turbidity", lerpf(7.0, 18.0, cs))
		_set_sky(sky, "mie_color", Color(0.86, 0.72, 0.55).lerp(Color(0.62, 0.64, 0.66), cs))
	# flat grey skylight replaces the sun's warmth: more ambient by day, cooler and greyer
	var grey := Color(0.46, 0.49, 0.54) * lerpf(0.3, 1.0, day)
	e.ambient_light_color = e.ambient_light_color.lerp(grey, 0.75 * c)
	e.ambient_light_energy *= 1.0 + 0.35 * c * day
	e.fog_density = lerpf(0.0012, 0.008, c)
	e.fog_light_color = e.fog_light_color.lerp(Color(0.5, 0.53, 0.57) * lerpf(0.12, 1.0, day), c)
	e.fog_sun_scatter = lerpf(0.15, 0.0, c)
	# under the deck the distance haze is lit by the cloud, not by the PhysicalSky behind it
	# (its overcast radiance is dark away from the sun and bakes in incrementally, so ridges
	# went black on one side): the aerial-perspective share goes and the fog light rises
	e.fog_aerial_perspective = lerpf(0.5, 0.05, c)
	e.fog_light_energy = lerpf(0.6, 1.0, c)
	# no sun behind the deck to scatter toward: the haze glows evenly all round
	e.volumetric_fog_anisotropy = lerpf(0.6, 0.1, c)
	e.volumetric_fog_density += 0.006 * c
	e.volumetric_fog_albedo = e.volumetric_fog_albedo.lerp(Color(0.75, 0.78, 0.82), c)
	e.volumetric_fog_emission *= 1.0 - c
	e.adjustment_saturation = lerpf(1.08, 0.82, c)
	e.adjustment_contrast = lerpf(1.06, 1.1, c)
	_apply_horizon_haze(e, day, c)
	_apply_bounce(e)

## The far ring's own haze (horizon.gdshader FOG): the scene fog's colour, pulled toward a
## cool skylight blue by clear day (what its sky-sampled aerial perspective gave, but darker
## than the sky behind the ridges so the massifs keep their value), same density.
func _apply_horizon_haze(e: Environment, day: float, c: float) -> void:
	var hz := get_node_or_null("Horizon/Mesh") as MeshInstance3D
	if not (hz and hz.mesh and hz.mesh.surface_get_material(0) is ShaderMaterial):
		return
	var mat := hz.mesh.surface_get_material(0) as ShaderMaterial
	var fog_lin := e.fog_light_color.srgb_to_linear() * e.fog_light_energy
	var sky_lin := Color(0.17, 0.23, 0.33) * lerpf(0.04, 1.0, day)
	var hc := fog_lin.lerp(sky_lin, 0.65 * (1.0 - c))
	# night: the moonlit volumetric haze in front of the ring takes the sky's colour (sky
	# affect 1.0), so a ring hazed in the dark fog colour stood black behind a glowing blue
	# band; give it the moonlit horizon blue instead, a shade darker than that band
	var nt := clampf(moon.light_energy / 1.25, 0.0, 1.0) if moon and moon.visible else 0.0
	hc = hc.lerp(Color(0.045, 0.06, 0.12), nt)   # nt already falls with cloud (moon dims)
	# under a closing deck the fog colour (lit for the near air) was brighter than the dark
	# cloud base behind the ridges, so a storm left the fully hazed ring standing as pale
	# flat cut-outs against the sky; the haze now sinks toward the deck's value with height
	# (the low rain curtain stays as bright as the valley fog in front, so no seam)
	mat.set_shader_parameter("haze_color", Vector3(hc.r, hc.g, hc.b))
	mat.set_shader_parameter("haze_top", lerpf(1.0, 0.55, smoothstep(0.35, 1.0, c)))
	mat.set_shader_parameter("haze_density", e.fog_density)

## Light the sunlit meadow and walls throw back into the shade. SDFGI does this on a real GPU;
## without it (software Vulkan, low quality) shaded stone in an enclosure got only the flat
## ambient, crushed by SSAO, and went black. Shaders that opt in (masonry) add albedo x this.
func _apply_bounce(e: Environment) -> void:
	var b := Color(0, 0, 0)
	var sun_h := maxf(sun.global_transform.basis.z.y, 0.0)
	if sun.visible:
		# a ~0.25 albedo meadow under the sun, half of it reaching a vertical face
		b += sun.light_color * sun.light_energy * (0.25 + 0.75 * sun_h) * 0.13
	if moon and moon.visible:
		# the moon key was raised for contrast (0.8 -> 1.25), not for more fill in the shade
		b += moon.light_color * moon.light_energy * 0.064
	b += e.ambient_light_color * e.ambient_light_energy * 0.12
	# the hero's face fill follows the same shade light (GI or not: SDFGI cannot see under
	# the brim at its probe size either)
	face_shade = b * 4.0
	if player and player.garb:
		player.garb.light_face(face_shade)
	if e.sdfgi_enabled:
		b = Color(0, 0, 0)
	RenderingServer.global_shader_parameter_set("bounce_light", Vector3(b.r, b.g, b.b))

## Sky material writes restart its radiance bake: only write a value that really changed.
func _set_sky(sky: PhysicalSkyMaterial, prop: String, v: Variant) -> void:
	var old = sky.get(prop)
	if v is float and is_equal_approx(old, v):
		return
	if v is Color and (old as Color).is_equal_approx(v):
		return
	sky.set(prop, v)

## The hero woke at the rest point: the Hollows still standing return to their posts, whole.
func _on_player_respawned() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.has_method("return_to_post"):
			e.return_to_post()
