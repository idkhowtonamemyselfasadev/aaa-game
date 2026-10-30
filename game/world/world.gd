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
var _sky_low := 0.0        # 1 with the sun near the horizon (set each _apply_time)
var _sky_glow := 1.0       # afterglow: 1 while the sun is up .. 0 at 9 deg below
var sky_sun: DirectionalLight3D   # drives the PhysicalSky only; held above the horizon at twilight
var training_post: TrainingPost
var soldier: HollowSoldier
var weather: Weather
var thermals: Thermals
var dust_devils: DustDevils
var clouds: CloudLayer
var trample: Trample
var herd: Herd
var cottage: Cottage
var stone_cottage: StoneCottage
var white_cottage: WhiteCottage
var dry_wall: DryWall
var yard_wall: YardWall
var door_stones: DoorStones
var rut_stones: RutStones
var lantern_post: LanternPost
var keeper: Keeper
var villager: Villager
var neighbour: Neighbour
var fell_bell: FellBell
var wheatears: Wheatears
var pedlar: Pedlar
var traveller: Traveller
var hearth: Hearth
var fox: Fox
var hares: Array[Hare] = []
var dog: Dog
var hens: Hens
var soundscape: Soundscape
var foley: Foley
var audio_mix: AudioMix
var music: Music
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
	# the quest log rides on the hero beside the Hud
	var quests := Quests.new()
	quests.name = "Quests"
	player.add_child(quests)
	add_child(trample)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.5, 0.6, 0.68)   # (0.62, 0.72, 1.0) washed pale walls a bright flat blue at 01:30
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
	# Harrowmere's first house, on the west edge of the green, its door toward the start
	cottage = Cottage.new()
	cottage.name = "Cottage"
	add_child(cottage)
	cottage.build(terrain, get_node("Ruins") as Ruins)
	# the first Hollow: a spear soldier keeping watch down the meadow, out of the start's way
	soldier = HollowSoldier.new()
	soldier.name = "HollowSoldier"
	soldier.position = Vector3(p.x + 6.0, 0.0, p.z + 19.0)   # world sits at the origin
	add_child(soldier)
	soldier.plant(terrain)
	soldier.face(p)
	trample.walkers.append(soldier)   # the Hollow tramples the sward and leaves prints too
	# a stone cottage across the green north of it, its door turned toward the start too
	stone_cottage = StoneCottage.new()
	stone_cottage.name = "StoneCottage"
	stone_cottage.ruins_path = NodePath("../Ruins")
	stone_cottage.terrain_path = NodePath("../Terrain")
	var sc := StoneCottage.SITE
	stone_cottage.position = Vector3(sc.x, terrain.height_at(sc.x, sc.y), sc.y)
	stone_cottage.rotation.y = StoneCottage.yaw()
	add_child(stone_cottage)
	# a limewashed cottage on the south-west of the green beside the timber house
	white_cottage = WhiteCottage.new()
	white_cottage.name = "WhiteCottage"
	white_cottage.ruins_path = NodePath("../Ruins")
	white_cottage.terrain_path = NodePath("../Terrain")
	var wc := WhiteCottage.HOME
	white_cottage.position = Vector3(wc.x, terrain.height_at(wc.x, wc.y), wc.y)
	white_cottage.rotation.y = WhiteCottage.facing()
	add_child(white_cottage)
	# the dry-stone garth wall round the yard behind it, a gateway on the east side
	dry_wall = DryWall.new()
	dry_wall.name = "DryWall"
	dry_wall.ruins_path = NodePath("../Ruins")
	dry_wall.terrain_path = NodePath("../Terrain")
	add_child(dry_wall)
	dry_wall.field_gate.watch = player
	# dry-stone walls closing the yard between the two houses, a cart gateway toward the green
	yard_wall = YardWall.new()
	yard_wall.name = "YardWall"
	yard_wall.ruins_path = NodePath("../Ruins")
	yard_wall.terrain_path = NodePath("../Terrain")
	add_child(yard_wall)
	# flat stepping stones worn into the tracks outside each house door
	door_stones = DoorStones.new()
	door_stones.name = "DoorStones"
	door_stones.ruins_path = NodePath("../Ruins")
	door_stones.terrain_path = NodePath("../Terrain")
	add_child(door_stones)
	# cobbles bared in the cart track's ruts, field stones levered out onto its verges
	rut_stones = RutStones.new()
	rut_stones.name = "RutStones"
	rut_stones.ruins_path = NodePath("../Ruins")
	rut_stones.terrain_path = NodePath("../Terrain")
	add_child(rut_stones)
	# an oak lantern post where the tracks meet on the green, lit from dusk to first light
	lantern_post = LanternPost.new()
	lantern_post.name = "LanternPost"
	lantern_post.weather = weather
	var lp := LanternPost.SITE
	lantern_post.position = Vector3(lp.x, terrain.height_at(lp.x, lp.y), lp.y)
	lantern_post.rotation.y = LanternPost.facing()
	add_child(lantern_post)
	# the bat roosts under the white cottage's woodshed eaves by day
	lantern_post.bat.roost_at = white_cottage.bat_roost()
	lantern_post.bat.door_at = white_cottage.bat_door()
	lantern_post.bat.roost_face = white_cottage.global_basis.z
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
	# two brown hares feeding either side of the road in through the south-east meadow
	for i in 2:
		var hr := Hare.new()
		hr.name = "Hare%d" % i
		hr.setup(self, 0.3 + 0.35 * i, 12.0 if i == 0 else -14.0, 4410 + i)
		hares.append(hr)
	# hens keeping the garth behind the stone cottage
	hens = Hens.new()
	hens.setup(self)
	# Edda, the cottager in the white house: water, wood, the bench, the lantern at dusk
	villager = Villager.new()
	villager.name = "Villager"
	villager.position = white_cottage.global_position + Vector3.UP
	add_child(villager)
	villager.settle(self, time_of_day)
	trample.walkers.append(villager)
	neighbour = Neighbour.new()
	neighbour.name = "Neighbour"
	neighbour.position = stone_cottage.global_position + Vector3.UP
	add_child(neighbour)
	neighbour.settle(self, time_of_day)
	trample.walkers.append(neighbour)
	# the two of them pass a word when they meet out of doors
	villager.mate = neighbour
	neighbour.mate = villager
	# the last of Osric's flock: his bellwether's bell on the old fold post up the fell
	fell_bell = FellBell.new()
	fell_bell.name = "FellBell"
	add_child(fell_bell)
	fell_bell.build(terrain, get_node("Ruins") as Ruins)
	fell_bell.player = player
	fell_bell.weather = weather
	# the fold's wheatears, bobbing on its wall tops and the post's head
	wheatears = Wheatears.new()
	wheatears.name = "Wheatears"
	add_child(wheatears)
	wheatears.build(terrain, fell_bell.perches)
	wheatears.player = player
	wheatears.weather = weather
	# Wat the pedlar, through on the fell road twice a day, a word for each of them
	pedlar = Pedlar.new()
	pedlar.name = "Pedlar"
	pedlar.position = white_cottage.global_position + Vector3(0, 1, 30)
	add_child(pedlar)
	pedlar.settle(self, time_of_day)
	trample.walkers.append(pedlar)
	# Hild the wool-wife, over the fell at 14:30 the other way: she and Wat meet on the road
	traveller = Traveller.new()
	traveller.name = "Traveller"
	traveller.position = white_cottage.global_position + Vector3(0, 1, 34)
	add_child(traveller)
	traveller.settle(self, time_of_day)
	pedlar.road_mate = traveller
	trample.walkers.append(traveller)
	# Brack, her collie: potters on the green, meets the hero, sits by her door at night
	dog = Dog.new()
	dog.setup(self)
	# the garth scratched bare and the footpath worn round to the cottage door
	YardGround.publish()
	# the mix: per-layer buses and the stone reverb inside the keep
	audio_mix = AudioMix.new()
	audio_mix.name = "AudioMix"
	audio_mix.world = self
	add_child(audio_mix)
	# the score: vale by day / by night, Hesper's hearth, the fight and its victory stinger
	music = Music.new()
	music.name = "Music"
	music.world = self
	add_child(music)
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
	# warm air rising off the keep's knoll and the sunny crags: the glider climbs in it
	thermals = Thermals.new()
	thermals.name = "Thermals"
	thermals.terrain_path = NodePath("../Terrain")
	add_child(thermals)
	# on a hot still afternoon a whirl of dust and chaff wanders over the dry meadow
	dust_devils = DustDevils.new()
	dust_devils.name = "DustDevils"
	dust_devils.terrain_path = NodePath("../Terrain")
	add_child(dust_devils)
	# staff swishes, impacts, parry clangs, dodges and footfalls
	foley = Foley.new()
	foley.name = "Foley"
	foley.world = self
	foley.weather = weather
	add_child(foley)
	foley.hook(player, [soldier], trample)
	foley.hook_herd(herd)
	foley.hook_fox(fox)
	foley.hook_dog(dog)
	foley.hook_gate(dry_wall.field_gate)
	foley.hook_villager(villager)
	foley.hook_villager(neighbour)
	foley.hook_villager(pedlar)
	foley.hook_villager(traveller)
	foley.hook_hens(hens)
	foley.hook_bat(lantern_post.bat)

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
	e.fog_density = CLEAR_FOG
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

## Exposure gain for a low sun (1.0 at noon .. 1.5): sqrt of the noon key over this hour's
## key, where key = sun energy x its height (light on level ground) + skylight luminance.
## Reads sun/ambient as _apply_time has just set them (before weather dims them: a cloudy
## frame has its own exposure lift in _apply_weather).
const NOON_KEY := 2.0
func low_sun_gain() -> float:
	var e := env.environment
	var sun_h := maxf(sun.global_transform.basis.z.y, 0.15) if sun.visible else 0.15
	var amb := e.ambient_light_color
	var key := sun.light_energy * sun_h + e.ambient_light_energy * (0.3 * amb.r + 0.59 * amb.g + 0.11 * amb.b)
	return clampf(sqrt(NOON_KEY / maxf(key, 0.05)), 1.0, 1.5)

func _apply_time() -> void:
	# Full day: sunrise 06:00, noon peak sun_peak_deg, sunset 18:00; the moon opposes the sun.
	var t := time_of_day / 24.0
	var az := t * TAU + PI * 0.5
	var elev := deg_to_rad(sun_peak_deg) * sin((time_of_day - 6.0) / 12.0 * PI)
	var day := clampf(sin(elev) * 5.0 + 0.35, 0.0, 1.0)       # 0 night .. 1 full day
	var low := 1.0 - clampf(sin(elev) / sin(deg_to_rad(25.0)), 0.0, 1.0)   # 1 near horizon
	# afterglow: 1 while the sun is up .. 0 at 9 degrees below the horizon
	var afterglow := smoothstep(deg_to_rad(-9.0), deg_to_rad(0.5), elev)
	_sky_low = low
	_sky_glow = afterglow
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
		# ((0.075, 0.105, 0.2) is ~0.007-0.03 linear: the backlit near meadow and the wood
		# line read pure black in night `valley`; lifted ~1.6x, still well under the moon key)
		env.environment.ambient_light_color = Color(0.095, 0.13, 0.24).lerp(sky_amb, maxf(day, 0.8 * afterglow))
		env.environment.ambient_light_energy = lerpf(1.0, 1.15, day) * ambient_scale
		# volumetrics only for local ground haze; distance haze is the depth fog (a dense
		# volume ends at volumetric_fog_length and leaves a visible band on far ridges)
		env.environment.volumetric_fog_density = lerpf(0.0025, 0.0007, day)
		# A camera opens up when the sun is low: 0.85 was set for noon, so at 07:00/17:00
		# (sun ~8 deg, the yard in the cottage's shade) the frame went near black under a bright
		# sky. Key = light reaching the land (sun on the ground + skylight); half-compensate
		# (sqrt) toward the noon key, capped at x1.5, faded out into the night ramp.
		env.environment.tonemap_exposure = lerpf(1.6, 0.85 * lerpf(1.0, low_sun_gain(), day), day)
		# fog takes the sky's mood: warm haze by day, moonlit blue-grey at night, no self-glow.
		# (0.05, 0.07, 0.11) was ~0.004 linear: the valley 100-300 m off sank into the black
		# sky instead of standing in a faint silver veil, so the night floor had no depth
		env.environment.fog_light_color = Color(0.17, 0.21, 0.3).lerp(Color(0.73, 0.6, 0.5), day)
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

## Clear-day depth fog. At 0.0012 the trees and hills 100-300 m off stood at full contrast
## at noon (16-30% haze), so the open meadow had no depth: 0.0024 puts ~30% on the wood
## line at 150 m and ~50% at 300 m, ~10% at 50 m, so the village yards stay crisp. (0.0016-0.002
## alone washed the valley milky in front of a darker far ring; the ring's valley-air term in
## _apply_horizon_haze is what lets the scene take this density.)
const CLEAR_FOG := 0.0024

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
	e.ambient_light_energy *= 1.0 + 0.55 * c * day
	# the eye opens under a storm deck: with the sun ~80% gone the scene sat a stop under,
	# wet yards read as murk; moody, but readable
	e.tonemap_exposure *= 1.0 + 0.24 * c * day
	e.fog_density = lerpf(CLEAR_FOG, 0.008, c)
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
	# (halved 10-26: at 0.045,0.06,0.12 the fully hazed ring read as a flat pale-blue cut-out,
	# brighter than the black hills in front of it)
	hc = hc.lerp(Color(0.02, 0.027, 0.055), nt)   # nt already falls with cloud (moon dims)
	# under a closing deck the fog colour (lit for the near air) was brighter than the dark
	# cloud base behind the ridges, so a storm left the fully hazed ring standing as pale
	# flat cut-outs against the sky; the haze now sinks toward the deck's value with height
	# (the low rain curtain stays as bright as the valley fog in front, so no seam)
	mat.set_shader_parameter("haze_color", Vector3(hc.r, hc.g, hc.b))
	# valley air over the low ring: what the scene fog paints there (its light colour plus the
	# share sampled from the bright horizon sky); clear-weather only, a storm's own dense haze
	# already swallows the foothills
	# The horizon sky keeps its brightness through sunset (a rose band, not a dimmed noon
	# beige): keyed to `day` (0.35 at sunset) the estimate fell to a third, so at 18:00 the
	# low ring stood dark grey behind the near hills, which the scene fog lit pink from the
	# real sunset sky. Warm it with the low sun and fade it with the afterglow instead.
	var sky_est := Color(0.5, 0.47, 0.37).lerp(Color(0.62, 0.48, 0.4), _sky_low) \
			* lerpf(0.04, 1.0, _sky_glow * _sky_glow)
	var vc := fog_lin.lerp(sky_est, e.fog_aerial_perspective)
	vc = vc.lerp(Color(0.01, 0.013, 0.026), nt)   # the low ring's base sinks into the night valley
	mat.set_shader_parameter("valley_color", Vector3(vc.r, vc.g, vc.b))
	mat.set_shader_parameter("valley_density", CLEAR_FOG * (1.0 - c))
	mat.set_shader_parameter("haze_top", lerpf(1.0, 0.55, smoothstep(0.35, 1.0, c)))
	# the ring keeps its own clear-day density (its haze_scale was tuned for 0.0012), the
	# denser valley air is a near-field thing
	mat.set_shader_parameter("haze_density", lerpf(0.0012, 0.008, c))
	# the volumetric haze the ring's own FOG would otherwise skip (horizon.gdshader vol_*)
	var alb := e.volumetric_fog_albedo.srgb_to_linear()
	var vs := Vector3.ZERO
	var vm := Vector3.ZERO
	if sun.visible:
		var l := sun.light_color.srgb_to_linear() * sun.light_energy * sun.light_volumetric_fog_energy * alb
		vs = Vector3(l.r, l.g, l.b)
	if moon and moon.visible:
		var l := moon.light_color.srgb_to_linear() * moon.light_energy * moon.light_volumetric_fog_energy * alb \
				* RING_VOL_MOON_GAIN
		vm = Vector3(l.r, l.g, l.b)
	var em := e.volumetric_fog_emission.srgb_to_linear() * e.volumetric_fog_emission_energy
	mat.set_shader_parameter("vol_sun", vs)
	mat.set_shader_parameter("vol_sun_dir", sun.global_transform.basis.z.normalized())
	mat.set_shader_parameter("vol_moon", vm)
	mat.set_shader_parameter("vol_moon_dir", moon.global_transform.basis.z.normalized() if moon else Vector3.UP)
	mat.set_shader_parameter("vol_emit", Vector3(em.r, em.g, em.b))
	mat.set_shader_parameter("vol_g", e.volumetric_fog_anisotropy)
	mat.set_shader_parameter("vol_alpha", 1.0 - exp(-e.volumetric_fog_density * e.volumetric_fog_length)
			if e.volumetric_fog_enabled else 0.0)

## The engine's moonlit volume came out ~20x brighter than albedo x moon x phase predicts (the
## night sky and the wood line glow blue-grey through it; 21:22 10-27 shot with gain 1 left the
## ring's cut-out edge unchanged), so the ring's copy of it is calibrated by eye. Moon only:
## by day the sun term stays physical (unverified against the engine).
const RING_VOL_MOON_GAIN := 3.0

## Light the sunlit meadow and walls throw back into the shade. SDFGI does this on a real GPU;
## without it (software Vulkan, low quality) shaded stone in an enclosure got only the flat
## ambient, crushed by SSAO, and went black. Shaders that opt in (masonry) add albedo x this.
const GROUND_FILL := 0.6
## the moonlit night sky over open ground: the moon key only lights slopes that face it, and
## SSAO crushed the flat night ambient on the near meadow to black while the mid-valley read
## moonlit (valley 21:00); this unoccluded skylight keeps the near sward and hill readable
const NIGHT_GROUND_FILL := 0.7
## share of the sky ambient a shaded rock face keeps as a floor (rock.gdshader `sky_floor`)
const SKY_FLOOR := 3.0
## hue of the light thrown up off the sunlit meadow (sky_floor's warm share)
const SKY_FLOOR_WARM := Color(0.62, 0.56, 0.38)
var night_ground_fill := NIGHT_GROUND_FILL   # shot.gd `ngfill=` overrides it for A/B tests
var sky_floor := Vector3.ZERO   # last value written to the sky_floor global
var bounce_light := Vector3.ZERO   # last value written to the bounce_light global
var ground_fill := Vector3.ZERO   # last value written to the ground_fill global
var ground_fill_far := 1.0   # share of it the ground keeps past ~120 m (ground_fill_far global)
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
	# a low sun lights level ground hardly at all, and the sky dome (not the grazing sun) is
	# what keeps the shaded yard readable at 07:00/17:00; the flat ambient under SSAO crushed
	# it near black, so open ground gets an unoccluded skylight term that grows as the sun
	# sinks (0 at 25 deg and above, fading out with the sun at twilight)
	var low_k := (1.0 - clampf(sun_h / sin(deg_to_rad(25.0)), 0.0, 1.0)) \
			* clampf(sun.light_energy / 1.5, 0.0, 1.0) if sun.visible else 0.0
	var gf := e.ambient_light_color * e.ambient_light_energy * GROUND_FILL * low_k
	var day_g := gf.g
	if moon and moon.visible:
		gf += e.ambient_light_color * e.ambient_light_energy * night_ground_fill \
				* clampf(moon.light_energy / 1.25, 0.0, 1.0)
	ground_fill = Vector3(gf.r, gf.g, gf.b)
	# the moonlit part only answers SSAO's crush on the near sward: past ~120 m it lifted the
	# mid-valley ground to the crowns' brightness and the night wood vanished into it, so the
	# ground shaders fade that share out with distance (the low-sun share stays everywhere)
	ground_fill_far = clampf(day_g / gf.g, 0.0, 1.0) if gf.g > 0.0001 else 1.0
	face_shade = b * 4.0
	if player and player.garb:
		player.garb.light_face(face_shade)
	# the shaded flank of a big stone looks into the open sky dome: SDFGI's coarse probes see
	# little of it there and the no-GI bounce alone left the rock darker than the shaded grass
	# beside it, so rock gets this floor (kept with SDFGI, unlike bounce_light)
	# (3.0: at 1.0 it stayed under the 14:00 bounce fill and changed nothing; halved with
	# SDFGI, whose own GI it adds to -- unverified on a real GPU)
	var sf := e.ambient_light_color * e.ambient_light_energy * SKY_FLOOR * (0.5 if e.sdfgi_enabled else 1.0)
	# a quarter of it comes off the lit sward, not the blue dome: at the pure sky tint the
	# shaded flanks read a touch blue beside the warm grass (SKY_FLOOR_WARM keeps the luminance)
	var sl := sf.get_luminance()
	sf = sf.lerp(SKY_FLOOR_WARM * (sl / maxf(SKY_FLOOR_WARM.get_luminance(), 0.001)), 0.25)
	sky_floor = Vector3(sf.r, sf.g, sf.b)
	RenderingServer.global_shader_parameter_set("sky_floor", sky_floor)
	if e.sdfgi_enabled:
		b = Color(0, 0, 0)
		ground_fill = Vector3.ZERO
	bounce_light = Vector3(b.r, b.g, b.b)
	RenderingServer.global_shader_parameter_set("bounce_light", bounce_light)
	RenderingServer.global_shader_parameter_set("ground_fill", ground_fill)
	RenderingServer.global_shader_parameter_set("ground_fill_far", ground_fill_far)

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
